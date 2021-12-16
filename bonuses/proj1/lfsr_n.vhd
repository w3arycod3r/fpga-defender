-- lfsr_n: Generic Linear Feedback Shift Register
-- Inspired By: https://projectf.io/posts/fpga-graphics/
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- Common constants
use work.defender_common.all;

ENTITY lfsr_n IS
    generic (
        g_taps : std_logic_vector := "10111000"; -- Use taps that give maximal length period
        g_init_seed : std_logic_vector := X"FF" -- Must be non-zero
    );
    PORT (
        i_clock  : in std_logic;
        i_reset  : in std_logic;  -- Synch reset
        i_load   : in std_logic;  -- Synch load. Register loads value on i_data when asserted.
        i_cnt_en : IN  STD_LOGIC; -- Count enable.
        i_data   : IN  STD_LOGIC_VECTOR(g_taps'length-1 DOWNTO 0); -- Parallel load
        o_value  : OUT STD_LOGIC_VECTOR(g_taps'length-1 DOWNTO 0)  -- Output of the LFSR
    );
END lfsr_n;

ARCHITECTURE behavior OF lfsr_n IS
    -- Types

    -- Component declarations

    -- Signal declarations
    SIGNAL sreg  : STD_LOGIC_VECTOR(g_taps'length-1 DOWNTO 0) := g_init_seed; -- Internal register

BEGIN

    PROCESS (i_clock) BEGIN

        -- Clocked behavior
        IF (rising_edge(i_clock)) THEN

            -- Generate next number in the sequence
            if (i_cnt_en = '1') then
                if (sreg(0) = '1') then
                    sreg <= ('0' & sreg(g_taps'length-1 downto 1)) xor g_taps;
                else
                    sreg <= ('0' & sreg(g_taps'length-1 downto 1));
                end if;
            end if;
            -- Load external value
            if (i_load = '1') then
                sreg <= i_data;
            end if;
            -- Reset to initial seed
            if (i_reset = '1') then
                sreg <= g_init_seed;
            end if;

        END IF;

    END PROCESS;

    -- Instantiation AND port mapping

    -- Concurrent assignments
    o_value <= sreg;
    
END behavior;

