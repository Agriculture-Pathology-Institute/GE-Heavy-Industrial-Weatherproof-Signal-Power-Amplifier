-- File Path: src/hardware/rt_serial_parity_checker.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rt_serial_parity_checker is
    Port (
        -- High-Speed Timing & Control Networks
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to 10.0 MHz Stage 2 Divider
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- Parallel Input Nibble & Parity Bit from Tractor Connector Interfaces
        -- Q_BUS_IN maps directly to the parallel outputs of the Micrel SY10E445 chip
        Q_BUS_IN               : in  STD_LOGIC_VECTOR(3 downto 0);
        RECEIVED_PARITY_BIT    : in  STD_LOGIC;
        DATA_STROBE_IN         : in  STD_LOGIC;
        
        -- Safely Verified Data Output Routed to Polyhedral Clipping Controllers
        VERIFIED_HEX_OUT       : out STD_LOGIC_VECTOR(3 downto 0);
        DATA_SYNTAX_VALID      : out STD_LOGIC; -- Strobed low if bit slips occur
        
        -- Native 16-State Hexadecimal Master Interlock Bus
        HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end rt_serial_parity_checker;

architecture BitwiseEnforcement of rt_serial_parity_checker is
    signal computed_parity : STD_LOGIC := '0';
    signal internal_fault  : STD_LOGIC := '0';
    signal latched_hex     : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
begin

    -------------------------------------------------------------------------
    -- COMBINATORIAL ODD PARITY MATH CONSTANT MATRIX
    -- Formula: Odd Parity = NOT (Q0 XOR Q1 XOR Q2 XOR Q3)
    -------------------------------------------------------------------------
    computed_parity <= not (Q_BUS_IN(0) xor Q_BUS_IN(1) xor Q_BUS_IN(2) xor Q_BUS_IN(3));

    -------------------------------------------------------------------------
    -- INDUSTRIAL SYNCHRONOUS PARITY AUDITING PIPELINE
    -------------------------------------------------------------------------
    process(CLK_INDUSTRIAL, SYSTEM_RESET)
    begin
        if SYSTEM_RESET = '1' then
            latched_hex       <= (others => '0');
            VERIFIED_HEX_OUT  <= (others => '0');
            DATA_SYNTAX_VALID <= '0';
            internal_fault    <= '1'; -- Default to safe isolated state on boot
            HEX_SAFETY_OUT    <= "0000"; -- Force emergency ground state loop (0x0)
        elsif rising_edge(CLK_INDUSTRIAL) then
            if DATA_STROBE_IN = '1' then
                
                -- Verify real-time signal syntax consistency against incoming hardware bit
                if computed_parity /= RECEIVED_PARITY_BIT then
                    -- Bit slip or electrical noise injection caught in transit
                    internal_fault    <= '1';
                    DATA_SYNTAX_VALID <= '0';
                    HEX_SAFETY_OUT    <= "0000"; -- Instantly drop safety rail to ground (0x0)
                    VERIFIED_HEX_OUT  <= "0000"; -- Truncate data payload to zero command state
                else
                    -- Data packet matches physics constraints perfectly
                    internal_fault    <= '0';
                    DATA_SYNTAX_VALID <= '1';
                    HEX_SAFETY_OUT    <= "1111"; -- Maintain normal run/charging authorization (0xF)
                    latched_hex       <= Q_BUS_IN;
                    VERIFIED_HEX_OUT  <= Q_BUS_IN;
                end if;
                
            end if;
        end if;
    end process;

end BitwiseEnforcement;
