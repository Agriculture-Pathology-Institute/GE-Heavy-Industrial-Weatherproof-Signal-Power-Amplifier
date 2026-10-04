-- File Path: src/hardware/ge_univac_amplifier.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ge_univac_amplifier is
    Generic (
        SIGNAL_BOOST_FACTOR : integer := 4,
        -- Nominal 690V RMS Tri-Phase Line Input
        -- Peak Voltage Math: 690 * sqrt(2) = 975.8V Peak Baseline
        -- Absolute Maximum Dielectric Breakdown Threshold set at 1000V Peak
        MAX_PEAK_VOLTAGE_LIMIT : integer := 1000
    );
    Port (
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to 10.0 MHz Industrial Divider
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- Physical Hardware Interlock Pins
        SNAP_LATTICE_CONNECTED : in  STD_LOGIC; -- Snap matrix link monitor
        LIVE_LINE_VOLTAGE_RMS  : in  STD_LOGIC_VECTOR(15 downto 0); -- From high-speed ADC
        
        NATIVE_HEX_SIGNAL_IN   : in  STD_LOGIC_VECTOR(3 downto 0);
        SIGNAL_VALID_IN        : in  STD_LOGIC;
        
        BOOSTER_HEX_OUT        : out STD_LOGIC_VECTOR(3 downto 0);
        HIGH_CURRENT_INJECT_EN : out STD_LOGIC;
        AMPLIFIER_STATUS_HEX   : out STD_LOGIC_VECTOR(3 downto 0);
        EMERGENCY_ROLLBACK     : out STD_LOGIC
    );
end ge_univac_amplifier;

architecture PhysicsGovernedGain of ge_univac_amplifier is
    signal peak_voltage_calc : unsigned(31 downto 0) := (others => '0');
    signal safety_tripped     : STD_LOGIC := '0';
begin

    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable rms_input        : unsigned(15 downto 0);
        variable peak_estimation  : unsigned(31 downto 0);
        variable amplified_buffer : unsigned(5 downto 0);
    begin
        if SYSTEM_RESET = '1' then
            BOOSTER_HEX_OUT        <= "0000";
            HIGH_CURRENT_INJECT_EN <= '0';
            AMPLIFIER_STATUS_HEX   <= "0000";
            EMERGENCY_ROLLBACK     <= '1';
            safety_tripped         <= '0';
        elsif rising_edge(CLK_INDUSTRIAL) then
            rms_input := unsigned(LIVE_LINE_VOLTAGE_RMS);
            
            -- Peak Voltage Formula: V_peak = V_rms * 1.4142 (Scaled by 10000 to maintain integer math precision)
            peak_estimation := (rms_input * to_unsigned(14142, 16));
            peak_voltage_calc <= peak_estimation;

            -- Evaluate mathematical safety limits: Check for overvoltage arc risks
            if (peak_estimation / 10000) >= to_unsigned(MAX_PEAK_VOLTAGE_LIMIT, 32) or SNAP_LATTICE_CONNECTED = '0' then
                safety_tripped <= '1';
            else
                safety_tripped <= '0';
            end if;

            -----------------------------------------------------------------
            -- STRICTOR COVALENT INTERLOCK OVERRIDE
            -----------------------------------------------------------------
            if safety_tripped = '1' then
                BOOSTER_HEX_OUT        <= "0000"; -- Hard clamp signal to zero volts (0x0)
                HIGH_CURRENT_INJECT_EN <= '0';    -- Cut active current injection pathways
                AMPLIFIER_STATUS_HEX   <= "0000"; -- Broadcast system shutdown alert
                EMERGENCY_ROLLBACK     <= '1';    -- Initiate disaster recovery rollback sequence
            elsif SIGNAL_VALID_IN = '1' then
                EMERGENCY_ROLLBACK <= '0';
                amplified_buffer := resize(unsigned(NATIVE_HEX_SIGNAL_IN) * to_unsigned(SIGNAL_BOOST_FACTOR, 3), 6);
                
                if amplified_buffer > "1111" then
                    BOOSTER_HEX_OUT        <= "1111"; -- Clip smoothly at peak 1.0V hex rail limits (0xF)
                    HIGH_CURRENT_INJECT_EN <= '1';
                    AMPLIFIER_STATUS_HEX   <= "1111";
                else
                    BOOSTER_HEX_OUT        <= std_logic_vector(amplified_buffer(3 downto 0));
                    HIGH_CURRENT_INJECT_EN <= '1';
                    AMPLIFIER_STATUS_HEX   <= "1001"; -- Nominal boosted operation (0x9)
                end if;
            end if;
        end if;
    end process;

end PhysicsGovernedGain;
