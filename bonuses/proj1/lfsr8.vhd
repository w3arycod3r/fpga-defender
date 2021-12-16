-- 8-Bit Linear Feedback Shift Register (lfsr8)
library IEEE;
USE IEEE.std_logic_1164.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

ENTITY lfsr8 IS
    PORT ( clock, reset, load, cnt_en : IN  STD_LOGIC;
           par_in             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- Parallel load
           value_out          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) );
END lfsr8;

ARCHITECTURE behavior OF lfsr8 IS
    -- Types

    -- Component declarations

    -- Signal declarations
    SIGNAL msb_in : STD_LOGIC;
    SIGNAL value  : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '1'); -- Internal register

BEGIN

    PROCESS (clock) BEGIN

        -- Clocked behavior
        IF (rising_edge(clock)) THEN

            -- Synch reset
            if (reset = '1') THEN
                value <= (OTHERS => '1'); -- All 1's is the start state, all 0's is the lockup state
            elsif (load = '1') THEN
                value <= par_in;
            elsif (cnt_en = '1') then
                value <= (msb_in & value(7 DOWNTO 1)); -- Shift msb_in from the left
            END IF;

        END IF;

    END PROCESS;

    -- Calculate msb_in from tapped positions
    PROCESS (value) BEGIN

        -- taps: 8 6 5 4; feedback polynomial: x^8 + x^6 + x^5 + x^4 + 1
        -- these taps correspond to bit ordering: 1 to 8, L to R
        msb_in <= (value(0) XOR value(2) XOR value(3) XOR value(4));

    END PROCESS;

    -- Instantiation AND port mapping

    -- Concurrent assignments
    value_out <= value;
    
END behavior;

