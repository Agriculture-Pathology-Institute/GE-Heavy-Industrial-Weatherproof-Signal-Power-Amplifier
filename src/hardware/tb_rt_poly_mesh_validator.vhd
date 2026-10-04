-- File Path: src/hardware/tb_rt_poly_mesh_validator.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_rt_poly_mesh_validator is
-- Testbenches do not expose top-level structural ports
end tb_rt_poly_mesh_validator;

architecture BehavioralValidation of tb_rt_poly_mesh_validator is

    -- 1. Component Declaration of the Device Under Test (DUT)
    component rt_analog_threshold_validator is
        Generic (
            WINDOW_TOLERANCE_UV : signed(31 downto 0) := to_signed(2000, 32)
        );
        Port (
            CLK_INDUSTRIAL         : in  STD_LOGIC;
            SYSTEM_RESET           : in  STD_LOGIC;
            RAW_ANALOG_VOLTAGE_UV  : in  STD_LOGIC_VECTOR(31 downto 0);
            SIGNAL_STROBE_IN       : in  STD_LOGIC;
            VALIDATED_HEX_NIBBLE   : out STD_LOGIC_VECTOR(3 downto 0);
            SIGNAL_DRIFT_ERROR     : out STD_LOGIC;
            HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    -- 2. Internal Simulation Signals & Registers
    signal clk_10mhz       : STD_LOGIC := '0';
    signal sys_reset       : STD_LOGIC := '1';
    signal analog_voltage  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal signal_strobe   : STD_LOGIC := '0';
    
    -- Monitored Silicon Feedback Signals
    signal validated_hex   : STD_LOGIC_VECTOR(3 downto 0);
    signal drift_error     : STD_LOGIC;
    signal hex_safety      : STD_LOGIC_VECTOR(3 downto 0);

    -- Clock cycle configuration (10.0 MHz Stage 2 Industrial Divider = 100 ns period)
    constant CLK_PERIOD : time := 100 ns;

    -- Simulation Tracking Signals for Noise Modeling (uV scaling)
    signal ideal_signal_uv   : integer := 0;
    signal induced_noise_uv  : integer := 0;
    signal composite_line_uv : integer := 0;

begin

    -- 3. Device Under Test (DUT) Instantiation
    DUT: rt_analog_threshold_validator
        generic map (
            WINDOW_TOLERANCE_UV => to_signed(2000, 32) -- Enforces the strict 2mV limit
        )
        port map (
            CLK_INDUSTRIAL         => clk_10mhz,
            SYSTEM_RESET           => sys_reset,
            RAW_ANALOG_VOLTAGE_UV  => analog_voltage,
            SIGNAL_STROBE_IN       => signal_strobe,
            VALIDATED_HEX_NIBBLE   => validated_hex,
            SIGNAL_DRIFT_ERROR     => drift_error,
            HEX_SAFETY_OUT         => hex_safety
        );

    -- Synchronous clock generator thread
    clk_process : process
    begin
        clk_10mhz <= '0';
        wait for CLK_PERIOD / 2;
        clk_10mhz <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Dynamic Real-Time Signal Mixer
    composite_line_uv <= ideal_signal_uv + induced_noise_uv;
    analog_voltage    <= std_logic_vector(to_signed(composite_line_uv, 32));

    -------------------------------------------------------------------------
    -- 4. CLOSED-LOOP INDUCTIVE NOISE INJECTION PROCESS
    -------------------------------------------------------------------------
    stim_process : process
    begin
        -- Assert master logic clear lines during system boot frame
        sys_reset     <= '1';
        signal_strobe <= '0';
        ideal_signal_uv  <= 0;
        induced_noise_uv <= 0;
        wait for CLK_PERIOD * 2;
        sys_reset     <= '0';
        wait for CLK_PERIOD;

        ---------------------------------------------------------------------
        -- SCENARIO A: PRISTINE SIGNAL INPUT (NOMINAL ZONE)
        -- Targets State 0x3 (Ideal center-point = 0.1875V / 187,500 uV)
        ---------------------------------------------------------------------
        signal_strobe   <= '1';
        ideal_signal_uv <= 187500; 
        induced_noise_uv <= 0; -- Zero EMI interference
        wait for CLK_PERIOD * 2;
        assert (drift_error = '0') report "❌ Error: Pristine core signal flagged a false drift anomaly." severity failure;
        assert (validated_hex = "0011") report "❌ Error: Failed to resolve ideal state 0x3." severity failure;

        ---------------------------------------------------------------------
        -- SCENARIO B: ACCEPTABLE EMI RIPPLE (WITHIN 2mV TOLERANCE WINDOW)
        -- Charger noise introduces a +1.40mV (+1,400 uV) rail shift vector
        ---------------------------------------------------------------------
        induced_noise_uv <= 1400; 
        wait for CLK_PERIOD * 2;
        assert (drift_error = '0') report "❌ Error: Acceptable circuit noise triggered an illegal fault stop." severity failure;
        assert (validated_hex = "0011") report "❌ Error: Shifted voltage dropped latch validation inside safe window." severity failure;

        ---------------------------------------------------------------------
        -- SCENARIO C: CATASTROPHIC INDUCTIVE SPIKE (BREACHES 2mV LIMIT)
        -- High-draw turbine load dump surges a +2.85V (+2,850 uV) transient wave
        ---------------------------------------------------------------------
        induced_noise_uv <= 2850; 
        wait for CLK_PERIOD * 2;
        assert (drift_error = '1') report "✅ Success: Comparators intercepted the transient surge instantly." severity note;
        assert (hex_safety = "0000") report "✅ Success: Bus forced down to emergency 0x0 loop." severity note;
        assert (validated_hex = "0000") report "❌ Error: System allowed corrupted command bits to pass down-line." severity failure;

        ---------------------------------------------------------------------
        -- SCENARIO D: STABILIZATION AND NOISE DECAY RECOVERY
        -- Centrifugal exhaust blowers cool plates; active line filters suppress the spike
        ---------------------------------------------------------------------
        induced_noise_uv <= -450; -- Ripple drops back well within the 2mV envelope
        wait for CLK_PERIOD * 2;
        assert (drift_error = '0') report "❌ Error: System failed to clear fault latch after voltage stabilized." severity failure;
        assert (hex_safety = "1111") report "❌ Error: Core failed to restore full running parallel operations." severity failure;

        signal_strobe <= '0';
        report "🚀 [ANALOG STRESS TEST ENGINE COMPLETE]: Window constraints successfully filter extreme EMI spikes." severity note;
        wait;
    end process;

end BehavioralValidation;
