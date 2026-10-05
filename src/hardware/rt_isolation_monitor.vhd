-- File Path: src/hardware/rt_isolation_monitor.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rt_isolation_monitor is
    Generic (
        -- Maximum allowable analog reference rail drift before isolation fault
        -- Scaled in microvolts (uV). 50,000 uV = 0.050V (50mV) Critical Threshold
        MAX_LEAKAGE_THRESHOLD_UV : signed(31 downto 0) := to_signed(50000, 32);
        IDEAL_REF_RAIL_UV        : signed(31 downto 0) := to_signed(500000, 32) -- 0.5V Reference
    );
    Port (
        -- High-Speed Timing and Reset Lines
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to 10.0 MHz Industrial Clock
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- High-Precision ADC Ingestion Channel Monitoring Reference Rail potential
        MEASURED_REF_RAIL_UV   : in  STD_LOGIC_VECTOR(31 downto 0);
        CHASSIS_GROUND_LEAK_UV : in  STD_LOGIC_VECTOR(31 downto 0);
        SENSOR_STROBE_IN       : in  STD_LOGIC;
        
        -- Physical Output Drivers Hooked to High-Voltage Contactor Relays
        GALVANIC_ISOLATION_OK  : out STD_LOGIC; -- Held HIGH to energize safety contacts
        CATASTROPHIC_TRIP_OUT  : out STD_LOGIC; -- Strobed high to blow emergency backup fuses
        
        -- Master 16-State Hexadecimal Bus Status Indicator
        HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end rt_isolation_monitor;

architecture HeavyDutyProtection of rt_isolation_monitor is
    signal ref_drift           : signed(31 downto 0) := (others => '0');
    signal leakage_potential   : signed(31 downto 0) := (others => '0');
    signal isolation_failed    : STD_LOGIC := '1'; -- Default to safe isolated state on boot
begin

    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable current_ref  : signed(31 downto 0);
        variable current_leak : signed(31 downto 0);
    begin
        if SYSTEM_RESET = '1' then
            GALVANIC_ISOLATION_OK <= '0'; -- Open contacts mechanically on reset
            CATASTROPHIC_TRIP_OUT <= '0';
            HEX_SAFETY_OUT        <= "0000"; -- Force emergency ground state loop (0x0)
            isolation_failed      <= '1';
            ref_drift             <= (others => '0');
            leakage_potential     <= (others => '0');
        elsif rising_edge(CLK_INDUSTRIAL) then
            if SENSOR_STROBE_IN = '1' then
                current_ref  := signed(MEASURED_REF_RAIL_UV);
                current_leak := signed(CHASSIS_GROUND_LEAK_UV);
                
                -- Calculate absolute voltage anomalies relative to ideal centerlines
                ref_drift         <= abs(current_ref - IDEAL_REF_RAIL_UV);
                leakage_potential <= abs(current_leak);

                -- MATHEMATICAL BREAKDOWN SAFETY GATE
                -- Trigger an absolute hardware shutdown if rail potential drifts or chassis leaks current
                if abs(current_ref - IDEAL_REF_RAIL_UV) >= MAX_LEAKAGE_THRESHOLD_UV or abs(current_leak) >= MAX_LEAKAGE_THRESHOLD_UV then
                    isolation_failed <= '1';
                else
                    isolation_failed <= '0';
                end if;

                -------------------------------------------------------------
                -- HARDWARE ISOLATION FAST DISPATCH ROUTER
                -------------------------------------------------------------
                if isolation_failed = '1' then
                    GALVANIC_ISOLATION_OK <= '0';    -- De-energize primary contactor coils immediately
                    CATASTROPHIC_TRIP_OUT <= '1';    -- Shoot high pulse to trigger crowbar circuit/blow input lines
                    HEX_SAFETY_OUT        <= "0000"; -- Collapse output state to state zero-x-zero (0x0)
                else
                    GALVANIC_ISOLATION_OK <= '1';    -- Maintain active closed-circuit power loop
                    CATASTROPHIC_TRIP_OUT <= '0';
                    HEX_SAFETY_OUT        <= "1111"; -- Maintain normal full parallel capacity run state (0xF)
                end if;
                
            end if;
        end if;
    end process;

end HeavyDutyProtection;
