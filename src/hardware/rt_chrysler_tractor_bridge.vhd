-- File Path: src/hardware/rt_chrysler_tractor_bridge.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rt_chrysler_tractor_bridge is
    Generic (
        -- Mechanical scaling factors mapped in signed 32-bit millimeter fixed-point integers
        TRACTOR_WHEELBASE_MM   : signed(31 downto 0) := to_signed(3200, 32); -- 3.2m axle-to-axle layout center
        CHRYSLER_INERTIA_GAIN  : signed(15 downto 0) := to_signed(256, 16)   -- Fixed-point scaling multiplier (1.0 baseline)
    );
    Port (
        -- High-Speed Hardware Clock & Timing Nets
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to the 10.0 MHz industrial clock line
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- Ingested Chrysler Aerospace Monorail Kinematics Variables (32-Bit Parallel JSON Sub-net)
        MONORAIL_VELOCITY_MM_S : in  STD_LOGIC_VECTOR(31 downto 0); -- Active vehicle speed vector
        MONORAIL_CURVATURE_RADIUS : in  STD_LOGIC_VECTOR(31 downto 0); -- Intended path track radius
        MONORAIL_LEAN_ANGLE_RAD   : in  STD_LOGIC_VECTOR(31 downto 0); -- Gyroscopic roll/tilt data (Scaled 10^6)
        KINEMATICS_VALID_IN    : in  STD_LOGIC;
        
        -- Government & Master VHDL Polyhedral Border Interlock Status 
        BOUNDARY_CLAMP_ACTIVE  : in  STD_LOGIC; -- Intercepts line-clamp feedback from the polyhedral clipper
        ANALOG_DRIFT_FAULT_IN  : in  STD_LOGIC; -- High flag from the 2mV window comparator core
        
        -- Synchronized Steering Array Despatched to Hydraulic Steering Actuators
        STEERING_ANGLE_OUT     : out STD_LOGIC_VECTOR(31 downto 0); -- Target wheel turn angle (milliradians)
        SLIP_COMPENSATION_OUT  : out STD_LOGIC_VECTOR(31 downto 0); -- Dynamic differential torque displacement
        
        -- Native 16-State Hexadecimal Master Safety Bus Indicator
        HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end rt_chrysler_tractor_bridge;

architecture AerospaceTranslation of rt_chrysler_tractor_bridge is
    signal speed_signed       : signed(31 downto 0);
    signal radius_signed      : signed(31 downto 0);
    signal lean_signed        : signed(31 downto 0);
    
    -- Intermediate high-precision pipelined arithmetic registers
    signal calculated_ackermann : signed(63 downto 0) := (others => '0');
    signal dynamic_slip_offset  : signed(63 downto 0) := (others => '0');
    signal final_steering_angle : signed(31 downto 0) := (others => '0');
begin
    -- Unpack raw bus lines into mathematical signed processing channels
    speed_signed  <= signed(MONORAIL_VELOCITY_MM_S);
    radius_signed <= signed(MONORAIL_CURVATURE_RADIUS);
    lean_signed   <= signed(MONORAIL_LEAN_ANGLE_RAD);

    -------------------------------------------------------------------------
    -- KINEMATICS SYNC & ALWEG-TO-AG IMPLEMENT TRANSLATION PIPELINE
    -------------------------------------------------------------------------
    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable target_angle_mrad : signed(31 downto 0);
        variable slip_modifier     : signed(31 downto 0);
        variable compound_fault     : STD_LOGIC;
    begin
        if SYSTEM_RESET = '1' then
            calculated_ackermann <= (others => '0');
            dynamic_slip_offset  <= (others => '0');
            final_steering_angle <= (others => '0');
            STEERING_ANGLE_OUT   <= (others => '0');
            SLIP_COMPENSATION_OUT <= (others => '0');
            HEX_SAFETY_OUT       <= "0000"; -- Default to safe ground loop on startup
        elsif rising_edge(CLK_INDUSTRIAL) then
            
            -- Evaluate multi-channel hardware fault interlock triggers
            compound_fault := BOUNDARY_CLAMP_ACTIVE or ANALOG_DRIFT_FAULT_IN;

            -----------------------------------------------------------------
            -- ZERO-TRUST GOVERNMENTAL INTERLOCK BOUNDARY SAFETY OVERRIDE
            -----------------------------------------------------------------
            if compound_fault = '1' then
                -- Target has breached property boundaries or analog lines are drifting.
                -- Force absolute hardware-level shutdown inside a single clock cycle (<100ns).
                final_steering_angle  <= (others => '0');
                STEERING_ANGLE_OUT    <= (others => '0');
                SLIP_COMPENSATION_OUT <= (others => '0');
                HEX_SAFETY_OUT        <= "0000"; -- Lock all actuators down to state zero-x-zero (0x0)
            
            elsif KINEMATICS_VALID_IN = '1' then
                
                -- 1. Standard Ackermann Base steering geometry extraction
                -- Math Formula: Angle (mrad) = (Wheelbase / Radius) * 1000
                if radius_signed /= 0 then
                    calculated_ackermann <= (TRACTOR_WHEELBASE_MM * to_signed(1000, 32)) / radius_signed;
                else
                    calculated_ackermann <= (others => '0');
                end if;
                
                -- 2. Chrysler Aerospace Centripetal Slip Correction
                -- Incorporates gyroscopic lean parameters to calculate wheel slide offsets under wind load
                -- Math Formula: Slip_Offset = (Velocity * Lean) / 10000
                dynamic_slip_offset <= (speed_signed * lean_signed) / to_signed(10000, 32);

                -- Scale the aerodynamic/centripetal correction via the gain configuration parameter
                slip_modifier := resize(dynamic_slip_offset(47 downto 16) * CHRYSLER_INERTIA_GAIN / to_signed(256, 16), 32);
                target_angle_mrad := resize(calculated_ackermann, 32);

                -- 3. Composite Vector Mixing
                -- Blends ideal geometry track vectors with real-time slip stabilization offsets
                final_steering_angle <= target_angle_mrad + slip_modifier;

                -- Dispatch final processed commands straight to hydraulic steering loops
                STEERING_ANGLE_OUT    <= std_logic_vector(final_steering_angle);
                SLIP_COMPENSATION_OUT <= std_logic_vector(slip_modifier);
                
                -- Dynamic state assessment to assign 16-state hexadecimal health markers
                if final_steering_angle > to_signed(600, 32) or final_steering_angle < to_signed(-600, 32) then
                    HEX_SAFETY_OUT <= "0011"; -- Assign state 0x3 (Valve Actuation: Open 25% for tight field turns)
                else
                    HEX_SAFETY_OUT <= "1111"; -- Keep state at maximum parallel run/charging capacity (0xF)
                end if;

            end if;
        end if;
    end process;

end AerospaceTranslation;
