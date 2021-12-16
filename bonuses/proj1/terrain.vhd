-- terrain: Logic and graphics generation
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity terrain is
    port (
        i_clock : in std_logic;
        i_anim_en : in std_logic;

        -- Control Signals
        i_scan_pos : in t_point_2d;
        i_draw_en : in std_logic;

        o_color : out integer range 0 to c_max_color;
        o_draw : out std_logic
    );
end entity terrain;

architecture rtl of terrain is

    -- Constants


    -- Types

    -- Signals
    signal w_sf_on : std_logic_vector(2 downto 0);
    signal w_sf_bright_0 : std_logic_vector(7 downto 0);
    signal w_sf_bright_1 : std_logic_vector(7 downto 0);
    signal w_sf_bright_2 : std_logic_vector(7 downto 0);

    
begin

    
    -- Set draw output
    process(i_scan_pos)
        variable r_draw_tmp : std_logic := '0';
        variable r_color_tmp : integer range 0 to c_max_color := 0;

    begin

        r_draw_tmp := '0';
        r_color_tmp := 0;

        -- Draw the starfields, varying levels of white
        if (w_sf_on(0) = '1') then
            r_color_tmp := to_integer(unsigned(w_sf_bright_0(7 downto 4) & w_sf_bright_0(7 downto 4) & w_sf_bright_0(7 downto 4)));
            r_draw_tmp := '1';
        end if;
        if (w_sf_on(1) = '1') then
            r_color_tmp := to_integer(unsigned(w_sf_bright_1(7 downto 4) & w_sf_bright_1(7 downto 4) & w_sf_bright_1(7 downto 4)));
            r_draw_tmp := '1';
        end if;
        if (w_sf_on(2) = '1') then
            r_color_tmp := to_integer(unsigned(w_sf_bright_2(7 downto 4) & w_sf_bright_2(7 downto 4) & w_sf_bright_2(7 downto 4)));
            r_draw_tmp := '1';
        end if;

        -- Override all drawing
        if (i_draw_en = '0') then
            r_draw_tmp := '0';
            r_color_tmp := 0;
        end if;
            
        -- Assign outputs
        o_draw <= r_draw_tmp;
        o_color <= r_color_tmp;
    end process;


    -- Instantiation
    sf0: entity work.starfield
    generic map (
        g_incr => -1,
        g_seed => std_logic_vector(to_unsigned(16#9A9A9#, 21))
    )
    port map (
        i_clock => i_clock,
        i_anim_en => i_anim_en,
        i_draw_en => i_draw_en,
        i_reset => '0',
        o_sf_on => w_sf_on(0),
        o_sf_bright => w_sf_bright_0
    );

    sf1: entity work.starfield
    generic map (
        g_incr => -2,
        g_seed => std_logic_vector(to_unsigned(16#A9A9A#, 21))
    )
    port map (
        i_clock => i_clock,
        i_anim_en => i_anim_en,
        i_draw_en => i_draw_en,
        i_reset => '0',
        o_sf_on => w_sf_on(1),
        o_sf_bright => w_sf_bright_1
    );

    sf2: entity work.starfield
    generic map (
        g_incr => -4,
        g_mask => std_logic_vector(to_unsigned(16#7FF#, 21))
    )
    port map (
        i_clock => i_clock,
        i_anim_en => i_anim_en,
        i_draw_en => i_draw_en,
        i_reset => '0',
        o_sf_on => w_sf_on(2),
        o_sf_bright => w_sf_bright_2
    );

end architecture rtl;