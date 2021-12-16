-- triangle: A circuit to render a triangle
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity triangle is
    generic (
        g_width : integer := 30;
        g_height : integer := 20
    );
    port (
        i_row : in integer range 0 to c_screen_height-1;
        i_column : in integer range 0 to c_screen_width-1;
        i_xPos : in integer;
        i_yPos : in integer;

        o_draw : out std_logic
    );
end entity triangle;

architecture rtl of triangle is
    
begin
    -- Set draw output
    process(i_row, i_column, i_xPos, i_yPos)
    begin

        if (i_column >= i_xPos and i_column <= i_xPos+g_width and i_row >= i_yPos and i_row <= i_yPos+g_height) and -- Inside Rectangle
           (i_row > ((i_column - i_xPos) * g_height / g_width) + i_yPos) then                                       -- Below hypotenuse of triangle
            
            o_draw <= '1';
        else
            o_draw <= '0';
        end if;
    end process;
end architecture rtl;