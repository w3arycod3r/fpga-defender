-- Source: https://forum.digikey.com/t/binary-to-bcd-converter-vhdl/12530

--------------------------------------------------------------------------------
--
--   FileName:         binary_to_bcd_digit.vhd
--   Dependencies:     none
--   Design Software:  Quartus II 64-bit Version 13.1.0 Build 162 SJ Web Edition
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 6/15/2017 Scott Larson
--     Initial Public Release
--    
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
library work;

ENTITY binary_to_bcd_digit IS
  PORT(
    clk     : IN      STD_LOGIC;                      --system clock
    reset_n : IN      STD_LOGIC;                      --active low asynchronous reset
    ena     : IN      STD_LOGIC;                      --activate operation
    binary  : IN      STD_LOGIC;                      --bit shifted into digit
    c_out   : BUFFER  STD_LOGIC;                      --carry out shifted to next larger digit
    bcd     : BUFFER  STD_LOGIC_VECTOR(3 DOWNTO 0));  --resulting BCD output
END binary_to_bcd_digit;

ARCHITECTURE logic OF binary_to_bcd_digit IS
  SIGNAL prev_ena : STD_LOGIC;  --keeps track of the previous enable to identify when enable is first asserted
BEGIN

  c_out <= bcd(3) OR (bcd(2) AND bcd(1)) OR (bcd(2) AND bcd(0)); --assert carry out when register value exceeds 4

  PROCESS(reset_n, clk)
  BEGIN
    IF(reset_n = '0') THEN                --asynchronous reset asserted
      prev_ena <= '0';                      --clear ena history
      bcd <= "0000";                        --clear output
    ELSIF(clk'EVENT AND clk = '1') THEN   --rising edge of system clock
      prev_ena <= ena;                      --keep track of last enable
      IF(ena = '1') THEN                    --operation activated
        IF(prev_ena = '0') THEN               --first cycle of activation
          bcd <= "0000";                        --initialize the register
        ELSIF(c_out = '1') THEN               --register value exceeds 4
          bcd(0) <= binary;                     --shift new bit into first register
          bcd(1) <= NOT bcd(0);                 --set second register to adjusted value
          bcd(2) <= NOT (bcd(1) XOR bcd(0));    --set third register to adjusted value
          bcd(3) <= bcd(3) AND bcd(0);          --set fourth register to adjusted value
        ELSE                                  --register value does not exceed 4
          bcd <= bcd(2 DOWNTO 0) & binary;      --shift register values up and shift in new bit
        END IF;
      END IF;
    END IF;
  END PROCESS;

END logic;
