-- starfield: Generate an animated starfield using a LFSR
-- Inspired By: https://projectf.io/posts/fpga-graphics/
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

use work.defender_common.all;


entity starfield is
    generic (
        g_width : integer := 800;
        g_height : integer := 525;
        g_incr : integer := -1; -- Larger negative numbers will increase speed of animation
        g_seed : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(16#1FFFFF#, 21)); -- Seed for the LFSR
        g_mask : std_logic_vector(20 downto 0) := std_logic_vector(to_unsigned(16#FFF#, 21))    -- More ones will increase the density
    );
    port (
        i_clock : in std_logic;
        i_anim_en : in std_logic; -- Animation Enable
        i_draw_en : in std_logic; -- Draw Enable
        i_reset : in std_logic;

        o_sf_on : out std_logic; -- Star on
        o_sf_bright : out std_logic_vector(7 downto 0) -- Star brightness
    );
end entity starfield;

architecture rtl of starfield is

    -- Constants
    constant c_reset_cnt : integer := g_width * g_height + g_incr - 1; -- counter starts at zero, so sub 1
    constant c_reset_cnt_pause : integer := g_width * g_height - 1; -- Reset count to show a "paused" starfield

    -- Signals
    signal sf_reg : std_logic_vector(20 downto 0);
    signal sf_cnt : integer range 0 to 2**21-1 := 0;
    signal lfsr_rst : std_logic;
    
begin

    process(i_clock)
    begin  
        if rising_edge(i_clock) then

            sf_cnt <= sf_cnt + 1;
            if (sf_cnt = c_reset_cnt and i_anim_en = '1') then
                sf_cnt <= 0;
            elsif (sf_cnt = c_reset_cnt_pause and i_anim_en = '0') then
                sf_cnt <= 0;
            end if;

            if (i_reset = '1') then
                sf_cnt <= 0;
            end if;
        end if;
    end process;

    -- select some bits to form stars
    process(sf_reg, i_draw_en)
    begin
        if ((sf_reg or g_mask) = "111111111111111111111") then
            o_sf_on <= '1';
        else
            o_sf_on <= '0';
        end if;
        o_sf_bright <= sf_reg(7 downto 0);

        if i_draw_en = '0' then
            o_sf_on <= '0';
            o_sf_bright <= (others => '0');
        end if;
    end process;

    lfsr_rst <= '1' when (sf_cnt = 0) else '0';
    
    -- Instantiation
    prng: entity work.lfsr_n
    generic map (
        g_taps => "101000000000000000000",
        g_init_seed => g_seed
    )
    port map (
        i_clock => i_clock,
        i_reset => lfsr_rst,
        i_load => '0',
        i_cnt_en => '1',
        i_data => (others => '0'),
        o_value => sf_reg
    );
    
end architecture rtl;