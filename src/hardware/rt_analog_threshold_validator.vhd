-- File Path: src/hardware/rt_analog_threshold_validator.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rt_analog_threshold_validator is
    Generic (
        -- Enforces a strict +/- 2mV hardware tolerance window
        -- Mapped as fixed-point microvolts (uV) for precision tracking
        WINDOW_TOLERANCE_UV : signed(31 downto 0) := to_signed(2000, 32)
    );
    Port (
        -- System Clock Network
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Driven by 10.0 MHz clock line
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- High-Precision Analog Voltage Intake Line (Scaled: 1,000,000 = 1.0000V)
        RAW_ANALOG_VOLTAGE_UV  : in  STD_LOGIC_VECTOR(31 downto 0);
        SIGNAL_STROBE_IN       : in  STD_LOGIC;
        
        -- Outputs dispatched directly to Tractor Steering & Tool Actuators
        VALIDATED_HEX_NIBBLE   : out STD_LOGIC_VECTOR(3 downto 0);
        SIGNAL_DRIFT_ERROR     : out STD_LOGIC; -- High flag blocks hardware execution
        
        -- Native 16-State Master Interlock Rail Code
        HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end rt_analog_threshold_validator;

architecture ThresholdEnforcement of rt_analog_threshold_validator is
    -- 16 Native Ideal Voltage Centerpoints mapped in microvolts (0.0625V increments)
    type voltage_matrix is array (0 to 15) of signed(31 downto 0);
    constant IDEAL_RAILS : voltage_matrix := (
        0  => to_signed(0, 32),       1  => to_signed(62500, 32),   2  => to_signed(125000, 32),  3  => to_signed(187500, 32),
        4  => to_signed(250000, 32),  5  => to_signed(312500, 32),  6  => to_signed(375000, 32),  7  => to_signed(437500, 32),
        8  => to_signed(500000, 32),  9  => to_signed(562500, 32),  10 => to_signed(625000, 32),  11 => to_signed(687500, 32),
        12 => to_signed(750000, 32),  13 => to_signed(812500, 32),  14 => to_signed(875000, 32),  15 => to_signed(1000000, 32)
    );

    signal input_voltage : signed(31 downto 0);
    signal matched_index : integer range 0 to 15 := 0;
    signal drift_detected: STD_LOGIC := '0';
begin
    input_voltage <= signed(RAW_ANALOG_VOLTAGE_UV);

    -------------------------------------------------------------------------
    -- PARALLEL SYSTOLIC ANALOG WINDOW ASSESSOR
    -------------------------------------------------------------------------
    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable absolute_delta : signed(31 downto 0);
        variable current_closest : integer range 0 to 15;
        variable min_delta       : signed(31 downto 0);
        variable fault_accum     : STD_LOGIC;
    begin
        if SYSTEM_RESET = '1' then
            VALIDATED_HEX_NIBBLE <= "0000";
            SIGNAL_DRIFT_ERROR   <= '1';
            HEX_SAFETY_OUT       <= "0000"; -- Ground clamp state (0x0)
            drift_detected       <= '1';
            matched_index        <= 0;
        elsif rising_edge(CLK_INDUSTRIAL) then
            if SIGNAL_STROBE_IN = '1' then
                
                current_closest := 0;
                min_delta := to_signed(1000000, 32);
                fault_accum := '1';

                -- Unrolled search checking input voltage against all 16 target intervals
                for i in 0 to 15 loop
                    absolute_delta := abs(input_voltage - IDEAL_RAILS(i));
                    if absolute_delta < min_delta then
                        min_delta := absolute_delta;
                        current_closest := i;
                    end if;
                end loop;

                matched_index <= current_closest;

                -- Enforce the strict 2mV hardware tolerance validation window
                if min_delta <= WINDOW_TOLERANCE_UV then
                    fault_accum := '0'; -- Signal falls perfectly inside a valid state window
                else
                    fault_accum := '1'; -- Signal is stuck in intermediate drift space
                end if;

                drift_detected <= fault_accum;

                -------------------------------------------------------------
                -- HARDWARE INTERLOCK ACTION ROUTER
                -------------------------------------------------------------
                if fault_accum = '1' then
                    SIGNAL_DRIFT_ERROR   <= '1';
                    HEX_SAFETY_OUT       <= "0000"; -- Force immediate hardware-level E-Stop (0x0)
                    VALIDATED_HEX_NIBBLE <= "0000";
                else
                    SIGNAL_DRIFT_ERROR   <= '0';
                    HEX_SAFETY_OUT       <= "1111"; -- Maintain normal run state (0xF)
                    VALIDATED_HEX_NIBBLE <= std_logic_vector(to_unsigned(current_closest, 4));
                end if;

            end if;
        end if;
    end process;

end ThresholdEnforcement;
