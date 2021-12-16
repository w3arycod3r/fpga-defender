-- Configurable n-bit clock divider (clock_div)
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library work;

ENTITY clock_div IS
    GENERIC (n : NATURAL := 8);
    PORT ( clock_in, reset  : IN  STD_LOGIC;
           divisor          : IN  STD_LOGIC_VECTOR(n DOWNTO 0);  -- divisor = 2*(max_cnt+1)
           clock_out        : OUT STD_LOGIC );
END clock_div;

ARCHITECTURE behavior OF clock_div IS
    -- Constants

    -- Types

    -- Component declarations

    -- Signal declarations
    SIGNAL count      : STD_LOGIC_VECTOR(n-1 DOWNTO 0); -- Internal counter
    SIGNAL max_cnt    : STD_LOGIC_VECTOR(n-1 DOWNTO 0);
    SIGNAL temp_clock : STD_LOGIC := '0';

BEGIN

    max_cnt <= (divisor(n DOWNTO 1) - '1'); -- Bit shift right (div by 2) then sub 1

    PROCESS (clock_in, reset) BEGIN

        -- Asynch reset
        IF (reset = '1') THEN
            count <= (OTHERS => '0');
            temp_clock <= '0';

        -- Clocked behavior
        ELSIF (clock_in'event AND clock_in = '1') THEN

            IF (count >= max_cnt) THEN
                temp_clock <= NOT temp_clock;
                count <= (OTHERS => '0');
            ELSE
                count <= count + '1';
            END IF;

        END IF;

    END PROCESS;

    -- Instantiation AND port mapping

    -- Concurrent assignments
    clock_out <= temp_clock;
    
END behavior;