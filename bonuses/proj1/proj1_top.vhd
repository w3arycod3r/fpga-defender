-- proj1: "FPGA Defender" game with bonuses
-- Authors: Garrett Carter & Tyler McCormick
-- Top level entity
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity proj1_top is
    PORT( 
        KEY                                : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SW                                 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        MAX10_CLK1_50                      : IN STD_LOGIC; -- 50 MHz clock input
        LEDR                               : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        ARDUINO_IO                         : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        HEX5, HEX4, HEX3, HEX2, HEX1, HEX0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        -- Accelerometer I/O
        GSENSOR_CS_N          : OUT   STD_LOGIC;
        GSENSOR_SCLK          : OUT   STD_LOGIC;
        GSENSOR_SDI           : INOUT STD_LOGIC;
        GSENSOR_SDO           : INOUT STD_LOGIC;
        
        -- VGA I/O  
        VGA_HS		         :	OUT	 STD_LOGIC;	-- horizontal sync pulse
        VGA_VS		         :	OUT	 STD_LOGIC;	-- vertical sync pulse 
        
        VGA_R                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- red magnitude output to DAC
        VGA_G                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- green magnitude output to DAC
        VGA_B                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0')   -- blue magnitude output to DAC
    );
end proj1_top;

architecture top_level of proj1_top is

    -- Constants

    -- Component declarations
    component vga_pll_25_175 is 
        port(
            inclk0		:	IN  STD_LOGIC := '0';  -- Input clock that gets divided (50 MHz for max10)
            c0			:	OUT STD_LOGIC          -- Output clock for vga timing (25.175 MHz)
        );
    end component;

    COMPONENT ADXL345_controller IS
        PORT( reset_n     : IN  STD_LOGIC;
              clk         : IN  STD_LOGIC;
              data_valid  : OUT STD_LOGIC;
              data_x      : OUT STD_LOGIC_VECTOR(15 downto 0);
              data_y      : OUT STD_LOGIC_VECTOR(15 downto 0);
              data_z      : OUT STD_LOGIC_VECTOR(15 downto 0);
              SPI_SDI     : OUT STD_LOGIC;
              SPI_SDO     : IN  STD_LOGIC;
              SPI_CSN     : OUT STD_LOGIC;
              SPI_CLK     : OUT STD_LOGIC );
    END COMPONENT;

    COMPONENT accel_proc is
        port (
            -- Raw data from accelerometer
            data_x      : IN STD_LOGIC_VECTOR(15 downto 0);
            data_y      : IN STD_LOGIC_VECTOR(15 downto 0);
            data_valid  : IN STD_LOGIC;
    
            -- Direction of tilt
            -- x+ : left,    x- : right
            -- y+ : forward, y- : backward
            accel_scale_x, accel_scale_y          : OUT integer := 0 -- A scaled version of data
		);
    end COMPONENT;

    component dual_boot is
		port (
			clk_clk       : in std_logic := 'X'; -- clk
			reset_reset_n : in std_logic := 'X'  -- reset_n
		);
	end component;
    
    -- Signal declarations
    signal clk_25_175_MHz, disp_en : STD_LOGIC;
    signal scan_pos : t_point_2d;
    signal frame : std_logic;
    signal line : std_logic;
    signal KEY_state, KEY_down, KEY_up : std_logic_vector(1 downto 0);
    signal SW_state, SW_down, SW_up : std_logic_vector(9 downto 0);

    -- Accelerometer
    signal data_x, data_y                   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    signal data_valid : STD_LOGIC;
    signal accel_scale_x, accel_scale_y     : integer;
    
begin

    -- Concurrent assignments

    -- Instantiation and port mapping

    sw_deb: for i in 0 to 9 generate
        sw_deb_x : entity work.pb_debounce
        generic map (
            g_pol => '1'
        )
        port map (
            i_clk => clk_25_175_MHz,
            i_pb => SW(i),
            o_pb_state => SW_state(i),
            o_pb_down => SW_down(i),
            o_pb_up => SW_up(i)
        );
    end generate sw_deb;

    pb_deb: for i in 0 to 1 generate
        pb_deb_x : entity work.pb_debounce port map (
            i_clk => clk_25_175_MHz,
            i_pb => KEY(i),
            o_pb_state => KEY_state(i),
            o_pb_down => KEY_down(i),
            o_pb_up => KEY_up(i)
        );
    end generate pb_deb;

    -- Dual boot
    U7 : dual_boot port map ( clk_clk => MAX10_CLK1_50, reset_reset_n => '1' );

    -- VGA
    U8 : vga_pll_25_175 port map (
        inclk0 => MAX10_CLK1_50,
        c0 => clk_25_175_MHz
    );

    U9 : entity work.vga_controller port map (
        pixel_clk => clk_25_175_MHz,
        reset_n => '1',
        hsync => VGA_HS,
        vsync => VGA_VS,
        de => disp_en,
        frame => frame,
        line => line,
        sx => scan_pos.x,
        sy => scan_pos.y
    );

    -- Accel
    U10 : ADXL345_controller PORT MAP (reset_n => '1', clk => MAX10_CLK1_50, data_valid => data_valid, data_x => data_x,  data_y => data_y, data_z => open, SPI_SDI => GSENSOR_SDI, SPI_SDO => GSENSOR_SDO, SPI_CSN => GSENSOR_CS_N, SPI_CLK => GSENSOR_SCLK );
    U11 : accel_proc  PORT MAP ( data_x => data_x, data_y => data_y, data_valid => data_valid, accel_scale_x => accel_scale_x, accel_scale_y => accel_scale_y );
    
    -- Game Logic
    U12	: entity work.image_gen port map (
        pixel_clk => clk_25_175_MHz,
        disp_en => disp_en,
        i_scan_pos => scan_pos,
        frame => frame,
        line => line,
        red => VGA_R, 
        green => VGA_G, 
        blue => VGA_B,

        accel_scale_x => accel_scale_x,
        accel_scale_y => accel_scale_y,
        KEY_state => KEY_state,
        KEY_down => KEY_down,
        KEY_up => KEY_up,
        SW_state => SW_state,

        o_buzzPin => ARDUINO_IO(12),
        HEX5 => HEX5, HEX4 => HEX4, HEX3 => HEX3, HEX2 => HEX2, HEX1 => HEX1, HEX0 => HEX0,
        LEDR => LEDR
    );

end top_level;