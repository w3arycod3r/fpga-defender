-- bin2seg7: Binary to 7-segment decoder, active low outputs for DE10-Lite
library IEEE;
use IEEE.std_logic_1164.all;
library work;

-- Your block has a four bit input inData(3 downto 0), 
-- a blanking bit input (no segments illuminated, or blank, WHEN blanking is high), 
-- a dispHex bit input (show 0-0xF WHEN dispHex is high, else show only 0-9 blanking for 0xA-0xF), 
-- and dispPoint bit input (illuminate the "decimal point" WHEN high).
-- Your block has eight output bits. Seven bits segA, segB, ..., segG correspond to a segment on the display, while segPoint controls the corresponding "decimal point".
ENTITY bin2seg7 IS
    PORT ( inData        : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
           blanking      : IN  STD_LOGIC;
           dispHex       : IN  STD_LOGIC;
           dispPoint     : IN  STD_LOGIC;
           dispDash      : IN  STD_LOGIC;

           -- DP, G, F, E, D, C, B, A
           outSegs       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) );
END bin2seg7;

ARCHITECTURE behavior OF bin2seg7 IS

    -- Component declarations

    -- Signal declarations
    SIGNAL outSegsTmp : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -- Processes
    PROCESS (inData, blanking, dispHex, dispPoint, dispDash) IS
    BEGIN

        -- Decimal digits
        IF (dispHex = '0') THEN 
            CASE inData IS
            --  inData  |  DP, G, F, E, D, C, B, A
            WHEN "0000" => outSegsTmp <= "00111111";
            WHEN "0001" => outSegsTmp <= "00000110";
            WHEN "0010" => outSegsTmp <= "01011011";
            WHEN "0011" => outSegsTmp <= "01001111";
            WHEN "0100" => outSegsTmp <= "01100110";
            WHEN "0101" => outSegsTmp <= "01101101";
            WHEN "0110" => outSegsTmp <= "01111101";
            WHEN "0111" => outSegsTmp <= "00000111";
            WHEN "1000" => outSegsTmp <= "01111111";
            WHEN "1001" => outSegsTmp <= "01100111";

            WHEN "1010" => outSegsTmp <= "00000000";
            WHEN "1011" => outSegsTmp <= "00000000";
            WHEN "1100" => outSegsTmp <= "00000000";
            WHEN "1101" => outSegsTmp <= "00000000";
            WHEN "1110" => outSegsTmp <= "00000000";
            WHEN "1111" => outSegsTmp <= "00000000";

            WHEN OTHERS => outSegsTmp <= "00000000";
            END CASE;

        -- Hex digits
        ELSE
            CASE inData IS
            --  inData  |  DP, G, F, E, D, C, B, A
            WHEN "0000" => outSegsTmp <= "00111111";
            WHEN "0001" => outSegsTmp <= "00000110";
            WHEN "0010" => outSegsTmp <= "01011011";
            WHEN "0011" => outSegsTmp <= "01001111";
            WHEN "0100" => outSegsTmp <= "01100110";
            WHEN "0101" => outSegsTmp <= "01101101";
            WHEN "0110" => outSegsTmp <= "01111101";
            WHEN "0111" => outSegsTmp <= "00000111";
            WHEN "1000" => outSegsTmp <= "01111111";
            WHEN "1001" => outSegsTmp <= "01100111";

            WHEN "1010" => outSegsTmp <= "01110111";
            WHEN "1011" => outSegsTmp <= "01111100";
            WHEN "1100" => outSegsTmp <= "00111001";
            WHEN "1101" => outSegsTmp <= "01011110";
            WHEN "1110" => outSegsTmp <= "01111001";
            WHEN "1111" => outSegsTmp <= "01110001";

            WHEN OTHERS => outSegsTmp <= "00000000";
            END CASE;
        END IF;

        -- Handle decimal point
        IF (dispPoint = '1') THEN
            outSegsTmp(7) <= '1';
        ELSE
            outSegsTmp(7) <= '0';
        END IF;

        -- Handle dash
        IF (dispDash = '1') THEN
            outSegsTmp <= "01000000"; -- g only
        END IF;

        -- Handle blanking
        IF (blanking = '1') THEN
            outSegsTmp <= "00000000";
        END IF;

    END PROCESS;

    -- Instantiation and port mapping

    -- Concurrent assignments
    outSegs <= (NOT outSegsTmp); -- Active low segment outputs
    

END behavior;

