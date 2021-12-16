-- hud (heads-up display): Logic and graphics generation for UI elements
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity hud is
    generic (

        -- Colors
        g_bar_color : integer := 16#000#;
        g_ship_color : integer := 16#F00#;
        g_score_color : integer := 16#000#
        

        

    );
    port (
        i_clock : in std_logic;

        -- Control signals
        i_update_pulse : in std_logic;
        i_row : in integer range 0 to c_screen_height-1;
        i_column : in integer range 0 to c_screen_width-1;
        i_draw_en : in std_logic;

        -- Game status
        i_num_lives : in integer range 0 to c_max_lives;
        i_score : in integer range 0 to c_max_score;
        o_score_bcd : out std_logic_vector(23 downto 0);

        o_color : out integer range 0 to c_max_color;
        o_draw : out std_logic;

        -- vgaText
        inArbiterPortArray : inout type_inArbiterPortArray(0 to c_num_text_elems-1);
        outArbiterPortArray : inout type_outArbiterPortArray(0 to c_num_text_elems-1);
        drawElementArray : inout type_drawElementArray(0 to c_num_text_elems-1)

    );
end entity hud;

architecture rtl of hud is
    -- Constants

    -- Position and size of elements
    
	 
    constant c_ship_spacing_x : integer := 10;
    constant c_ship_pos_y   : integer := c_upper_bar_pos/2 - c_ship_height/2;
    constant c_ship_pos_x1  : integer := 20;
    constant c_ship_pos_x2  : integer := c_ship_pos_x1 + 1*(c_ship_width + c_ship_spacing_x);
    constant c_ship_pos_x3  : integer := c_ship_pos_x1 + 2*(c_ship_width + c_ship_spacing_x);
    constant c_ship_pos_x4  : integer := c_ship_pos_x1 + 3*(c_ship_width + c_ship_spacing_x);
    constant c_ship_pos_x5  : integer := c_ship_pos_x1 + 4*(c_ship_width + c_ship_spacing_x);

    constant c_char_width   : integer := 8;
    constant c_char_height  : integer := 16;
    constant c_score_right_offset : integer := 8;
    constant c_num_score_digits : integer := 6;
    constant c_score_pos_x : integer := c_screen_width - c_num_score_digits*(c_char_width) - c_score_right_offset;
    constant c_score_pos_y  : integer := c_upper_bar_pos/2 - c_char_height/2 + 1;

    -- Logo
    constant c_logo_text : string := "TNTECH ECE";
    constant c_logo_length : integer := c_logo_text'LENGTH;
    constant c_logo_pos_x : integer := c_screen_width/2 - (c_logo_length*c_char_width/2);
    constant c_logo_pos_y : integer := (c_lower_bar_pos+c_bar_height) + c_bar_offset/2 - c_char_height/2 - 1;
    constant c_logo_color : integer := 16#00F#;
	 
    -- Components
	
    -- Signals
    signal w_ship1_draw : std_logic;
    signal w_ship2_draw : std_logic;
    signal w_ship3_draw : std_logic;
    signal w_ship4_draw : std_logic;
    signal w_ship5_draw : std_logic;

    signal r_score_slv : std_logic_vector(19 downto 0) := (others => '0');
    signal w_score_bcd : std_logic_vector(23 downto 0);
    signal r_score_str : string(1 to 6) := "      ";
    signal r_start_bcd_conv : std_logic := '0';
    signal w_bcd_conv_busy : std_logic;

    signal r_fontDrawReset : std_logic := '0';

	 
begin
    -- Concurrent assignments
    r_score_slv <= std_logic_vector(to_unsigned(i_score, r_score_slv'length));
    r_fontDrawReset <= w_bcd_conv_busy; -- Bring font draw out of reset when bcd finishes conversion
    o_score_bcd <= w_score_bcd;

    -- Score bcd to string
    process(w_score_bcd)
    begin
        for i in 0 to 5 loop
            r_score_str((5-i)+1) <= character'val(to_integer(unsigned(w_score_bcd((i+1)*4 - 1 downto i*4))) + 16#30#); -- Pick out 4 bits of BCD, add 0x30 to get to ASCII values for digits, then store in the string
        end loop;
    end process;
	 
	 
    -- Set draw output
    process(i_row, i_column)
        variable r_draw_tmp : std_logic := '0';
        variable r_color_tmp : integer range 0 to 4095 := 0;
    begin

        r_draw_tmp := '0';
        r_color_tmp := 0;

        -- Bars
        if (i_row > c_upper_bar_pos and i_row < c_upper_bar_pos + c_bar_height) or
           (i_row > c_lower_bar_pos and i_row < c_lower_bar_pos + c_bar_height) then

            r_draw_tmp := '1';
            r_color_tmp := g_bar_color;
        end if;

        -- Lives
        if (i_num_lives >= 1 and w_ship1_draw='1') or (i_num_lives >= 2 and w_ship2_draw='1') or (i_num_lives >= 3 and w_ship3_draw='1') or (i_num_lives >= 4 and w_ship4_draw='1') or (i_num_lives >= 5 and w_ship5_draw='1') then
            r_draw_tmp := '1';
            r_color_tmp := g_ship_color;
        end if;

        -- Render vgaText
        for i in 0 to 1 loop
            if drawElementArray(i).pixelOn then
                r_draw_tmp := '1';
                r_color_tmp := drawElementArray(i).rgb;
            end if;
        end loop;

        -- Override all drawing
        if (i_draw_en = '0') then
            r_draw_tmp := '0';
            r_color_tmp := 0;
        end if;
		  
        -- Assign outputs
        o_draw <= r_draw_tmp;
        o_color <= r_color_tmp;
    end process;

    -- Update for next frame
    process(i_clock)
        -- Vars
    begin
        if (rising_edge(i_clock)) then

            -- Time to update state
            if (i_update_pulse = '1') then
                r_start_bcd_conv <= '1';
            else
                r_start_bcd_conv <= '0';
            end if;
        end if;

    end process;

    -- Instantiation
    ship1 : entity work.triangle port map (i_row => i_row, i_column => i_column, i_xPos => c_ship_pos_x1, i_yPos => c_ship_pos_y, o_draw => w_ship1_draw);
    ship2 : entity work.triangle port map (i_row => i_row, i_column => i_column, i_xPos => c_ship_pos_x2, i_yPos => c_ship_pos_y, o_draw => w_ship2_draw);
    ship3 : entity work.triangle port map (i_row => i_row, i_column => i_column, i_xPos => c_ship_pos_x3, i_yPos => c_ship_pos_y, o_draw => w_ship3_draw);
    ship4 : entity work.triangle port map (i_row => i_row, i_column => i_column, i_xPos => c_ship_pos_x4, i_yPos => c_ship_pos_y, o_draw => w_ship4_draw);
    ship5 : entity work.triangle port map (i_row => i_row, i_column => i_column, i_xPos => c_ship_pos_x5, i_yPos => c_ship_pos_y, o_draw => w_ship5_draw);
	     
	bcdconv : entity work.binary_to_bcd generic map( bits => 20, digits => 6 ) port map (
        clk  => i_clock,
        reset_n => '1',
        ena  => r_start_bcd_conv,
        binary => r_score_slv,
        busy => w_bcd_conv_busy,
        
        bcd => w_score_bcd -- result is latched here when done with conversion
    );

    -- vgaText, slots 0 and 1
    text0: entity work.text_line
	generic map (
		textPassageLength => c_logo_length
	)
	port map(
		clk => i_clock,
		reset => r_fontDrawReset,
		textPassage => c_logo_text,
		position => (c_logo_pos_x, c_logo_pos_y),
		colorMap => (c_logo_length-1 downto 0 => c_logo_color),
		inArbiterPort => inArbiterPortArray(0),
		outArbiterPort => outArbiterPortArray(0),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(0)
	);

    text1: entity work.text_line
	generic map (
		textPassageLength => c_num_score_digits
	)
	port map(
		clk => i_clock,
		reset => r_fontDrawReset,
		textPassage => r_score_str,
		position => (c_score_pos_x, c_score_pos_y),
		colorMap => (c_num_score_digits-1 downto 0 => g_score_color),
		inArbiterPort => inArbiterPortArray(1),
		outArbiterPort => outArbiterPortArray(1),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(1)
	);
    
end architecture rtl;