-- overlays: Logic and graphics generation for text overlays
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity overlays is
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
        i_score : in integer;
        i_start_screen : in std_logic;
        i_pause_screen : in std_logic;
        i_game_over_screen : in std_logic;

        o_color : out integer range 0 to 4095;
        o_draw : out std_logic;

        -- vgaText
        inArbiterPortArray : inout type_inArbiterPortArray(0 to c_num_text_elems-1);
        outArbiterPortArray : inout type_outArbiterPortArray(0 to c_num_text_elems-1);
        drawElementArray : inout type_drawElementArray(0 to c_num_text_elems-1)

    );
end entity overlays;

architecture rtl of overlays is
    -- Constants

    -- Position and size of elements
    constant c_char_width   : integer := 8;
    constant c_char_height  : integer := 16;

    -- Start Screen
    constant c_start_text1 : string := "Welcome to FPGA Defender";
    constant c_start_text2 : string := "Press Key 1 to Start";
    constant c_start_length1 : integer := c_start_text1'LENGTH;
    constant c_start_length2 : integer := c_start_text2'LENGTH;
    constant c_start_pos_x1 : integer := c_screen_width/2 - (c_start_length1*c_char_width)/2;
    constant c_start_pos_x2 : integer := c_screen_width/2 - (c_start_length2*c_char_width)/2;
    constant c_start_pos_y1 : integer := c_screen_height/2 - (c_char_height);
    constant c_start_pos_y2 : integer := c_screen_height/2;
    constant c_start_text_color : integer := 16#00F#;

    -- Pause Screen
    constant c_pause_text1 : string := "Game Paused";
    constant c_pause_text2 : string := "Press Key 1 to Resume";
    constant c_pause_length1 : integer := c_pause_text1'LENGTH;
    constant c_pause_length2 : integer := c_pause_text2'LENGTH;
    constant c_pause_pos_x1 : integer := c_screen_width/2 - (c_pause_length1*c_char_width)/2;
    constant c_pause_pos_x2 : integer := c_screen_width/2 - (c_pause_length2*c_char_width)/2;
    constant c_pause_pos_y1 : integer := c_screen_height/2 - (c_char_height);
    constant c_pause_pos_y2 : integer := c_screen_height/2;
    constant c_pause_text_color : integer := 16#00F#;

    -- Game Over Screen
    constant c_over_text1 : string := "Game Over!";
    constant c_over_text2 : string := "Press Key 1 to Play Again";
    constant c_over_length1 : integer := c_over_text1'LENGTH;
    constant c_over_length2 : integer := c_over_text2'LENGTH;
    constant c_over_pos_x1 : integer := c_screen_width/2 - (c_over_length1*c_char_width)/2;
    constant c_over_pos_x2 : integer := c_screen_width/2 - (c_over_length2*c_char_width)/2;
    constant c_over_pos_y1 : integer := c_screen_height/2 - (c_char_height);
    constant c_over_pos_y2 : integer := c_screen_height/2;
    constant c_over_text_color : integer := 16#00F#;
	
    -- Components
    
    -- Signals

	 
begin
    -- Concurrent assignments	 
	 
    -- Set draw output
    process(i_row, i_column)
        variable r_draw_tmp : std_logic := '0';
        variable r_color_tmp : integer range 0 to 4095 := 0;
    begin

        r_draw_tmp := '0';
        r_color_tmp := 0;

        -- Render vgaText
        if (i_start_screen = '1') then
            for i in 2 to 3 loop
                if drawElementArray(i).pixelOn then
                    r_draw_tmp := '1';
                    r_color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
        end if;
        if (i_pause_screen = '1') then
            for i in 4 to 5 loop
                if drawElementArray(i).pixelOn then
                    r_draw_tmp := '1';
                    r_color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
        end if;
        if (i_game_over_screen = '1') then
            for i in 6 to 7 loop
                if drawElementArray(i).pixelOn then
                    r_draw_tmp := '1';
                    r_color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
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

    -- Update for next frame
    process(i_clock)
        -- Vars
    begin
        if (rising_edge(i_clock)) then

            -- Time to update state
            if (i_update_pulse = '1') then
                
            else
                
            end if;
        end if;

    end process;

    -- Instantiation
	
    -- vgaText, slots 2-7:

    -- Start screen
    text2: entity work.text_line
	generic map (
		textPassageLength => c_start_length1
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_start_text1,
		position => (c_start_pos_x1, c_start_pos_y1),
		colorMap => (c_start_length1-1 downto 0 => c_start_text_color),
		inArbiterPort => inArbiterPortArray(2),
		outArbiterPort => outArbiterPortArray(2),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(2)
	);

    text3: entity work.text_line
	generic map (
		textPassageLength => c_start_length2
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_start_text2,
		position => (c_start_pos_x2, c_start_pos_y2),
		colorMap => (c_start_length2-1 downto 0 => c_start_text_color),
		inArbiterPort => inArbiterPortArray(3),
		outArbiterPort => outArbiterPortArray(3),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(3)
	);

    -- Pause screen
    text4: entity work.text_line
	generic map (
		textPassageLength => c_pause_length1
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_pause_text1,
		position => (c_pause_pos_x1, c_pause_pos_y1),
		colorMap => (c_pause_length1-1 downto 0 => c_pause_text_color),
		inArbiterPort => inArbiterPortArray(4),
		outArbiterPort => outArbiterPortArray(4),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(4)
	);

    text5: entity work.text_line
	generic map (
		textPassageLength => c_pause_length2
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_pause_text2,
		position => (c_pause_pos_x2, c_pause_pos_y2),
		colorMap => (c_pause_length2-1 downto 0 => c_pause_text_color),
		inArbiterPort => inArbiterPortArray(5),
		outArbiterPort => outArbiterPortArray(5),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(5)
	);

    -- Game over screen
    text6: entity work.text_line
	generic map (
		textPassageLength => c_over_length1
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_over_text1,
		position => (c_over_pos_x1, c_over_pos_y1),
		colorMap => (c_over_length1-1 downto 0 => c_over_text_color),
		inArbiterPort => inArbiterPortArray(6),
		outArbiterPort => outArbiterPortArray(6),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(6)
	);

    text7: entity work.text_line
	generic map (
		textPassageLength => c_over_length2
	)
	port map(
		clk => i_clock,
		reset => '0',
		textPassage => c_over_text2,
		position => (c_over_pos_x2, c_over_pos_y2),
		colorMap => (c_over_length2-1 downto 0 => c_over_text_color),
		inArbiterPort => inArbiterPortArray(7),
		outArbiterPort => outArbiterPortArray(7),
		hCount => i_column,
		vCount => i_row,
		drawElement => drawElementArray(7)
	);
    
end architecture rtl;