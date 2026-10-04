-- File Path: src/hardware/ge_univac_amplifier.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ge_univac_amplifier is
    Generic (
        -- Amplification gain multiplier step calibrated for long-distance industrial antenna arrays
        -- Represented in signed fixed-point scaling thresholds
        SIGNAL_BOOST_FACTOR : integer := 4;
        MAX_DRIVE_PA        : signed(31 downto 0) := to_signed(150, 32) -- Structural load protection limit
    );
    Port (
        -- High-Speed Timing & Control Rails
        CLK_INDUSTRIAL       : in  STD_LOGIC; -- Synchronized to 10.0 MHz Stage 2 Divider
        SYSTEM_RESET         : in  STD_LOGIC;
        
        -- Gold Snap-Circuit Latch Matrix Hardware Interface Pins
        SNAP_LATTICE_CONNECTED : in  STD_LOGIC; -- Driven low if mechanical covalent bridge fractures
        REMOTE_SUB_NODE_ID     : in  integer range 0 to 99; -- Identifies which of the 100 breakout lines is live
        
        -- Low-Power Inbound Telemetry Signals (0.0V to 1.0V in 0.0625V intervals)
        NATIVE_HEX_SIGNAL_IN   : in  STD_LOGIC_VECTOR(3 downto 0);
        SIGNAL_VALID_IN        : in  STD_LOGIC;
        
        -- Weatherproof High-Draw Output Drivers (Piped directly to GE Power Output Stages)
        BOOSTER_HEX_OUT        : out STD_LOGIC_VECTOR(3 downto 0);
        HIGH_CURRENT_INJECT_EN : out STD_LOGIC; -- Triggers the secondary high-voltage power rail dump
        AMPLIFIER_STATUS_HEX   : out STD_LOGIC_VECTOR(3 downto 0);
        
        -- Disaster Recovery Reverse-Injection Interlock Loop
        EMERGENCY_ROLLBACK     : out STD_LOGIC -- Dispatched on immediate lattice isolation events
    );
end ge_univac_amplifier;

architecture HeavyDutyGain of ge_univac_amplifier is
    signal raw_hex_reg       : unsigned(3 downto 0) := (others => '0');
    signal internal_boost_en : STD_LOGIC := '0';
    signal internal_rollback : STD_LOGIC := '0';
begin

    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable amplified_buffer : unsigned(5 downto 0);
    begin
        if SYSTEM_RESET = '1' then
            raw_hex_reg        <= (others => '0');
            BOOSTER_HEX_OUT    <= (others => '0');
            HIGH_CURRENT_INJECT_EN <= '0';
            AMPLIFIER_STATUS_HEX   <= "0000"; -- Isolated / Offline (0x0)
            EMERGENCY_ROLLBACK <= '1';
            internal_boost_en  <= '0';
            internal_rollback  <= '1';
        elsif rising_edge(CLK_INDUSTRIAL) then
            
            -- Strict Snap-Circuit Zero-Trust Disconnection Interlock Verification
            if SNAP_LATTICE_CONNECTED = '0' then
                -- The gold lattice is fractured. Drop the drive system to safe mode inside <100ns
                BOOSTER_HEX_OUT        <= "0000"; -- Force hard ground clamp (0x0)
                HIGH_CURRENT_INJECT_EN <= '0';    -- Disengage high-draw wind turbine current injection
                AMPLIFIER_STATUS_HEX   <= "0000"; -- System fault E-Stop code
                internal_rollback      <= '1';    -- Trigger immediate corporate IP isolation rollback
                EMERGENCY_ROLLBACK     <= '1';
            
            elsif SIGNAL_VALID_IN = '1' then
                raw_hex_reg       <= unsigned(NATIVE_HEX_SIGNAL_IN);
                internal_rollback <= '0';
                EMERGENCY_ROLLBACK <= '0';

                -- Execute high-speed signal boosting calculations across unrolled parallel steps
                amplified_buffer := resize(unsigned(NATIVE_HEX_SIGNAL_IN) * to_unsigned(SIGNAL_BOOST_FACTOR, 3), 6);
                
                if amplified_buffer > "1111" then
                    BOOSTER_HEX_OUT        <= "1111"; -- Saturate smoothly at peak 1.0V hex rail limits (0xF)
                    HIGH_CURRENT_INJECT_EN <= '1';    -- Force auxiliary power stage engage
                    AMPLIFIER_STATUS_HEX   <= "1111"; -- Full output saturation indicator
                else
                    BOOSTER_HEX_OUT        <= std_logic_vector(amplified_buffer(3 downto 0));
                    HIGH_CURRENT_INJECT_EN <= '1';
                    AMPLIFIER_STATUS_HEX   <= "1001"; -- Normal high-throughput boosted run state (0x9)
                end if;
                
            end if;
        end if;
    process;

end HeavyDutyGain;
