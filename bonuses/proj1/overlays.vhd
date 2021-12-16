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
        i_scan_pos : in t_point_2d;
        i_draw_en : in std_logic;
        i_line : in std_logic; -- Start of line draw (start of blanking interval *before* line)

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
        drawElementArray : inout type_drawElementArray(0 to c_num_text_elems-1);

        -- Sprites
        spr_port_in_array : inout t_arb_port_in_array(0 to c_spr_num_elems-1);
        spr_port_out_array : inout t_arb_port_out_array(0 to c_spr_num_elems-1);
        spr_draw_array : inout t_spr_draw_elem_array(0 to c_spr_num_elems-1)

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
    constant c_start_pos_y2 : integer := 350;
    constant c_start_text_color : integer := 16#00F#;

    constant c_start_spr_num : integer := 12;
    constant c_start_spr_scale : integer := 8;
    constant c_start_spr_y1 : integer := 150;
    constant c_start_spr_y2 : integer := 250;
    constant c_start_spr_pos : t_pointArray(0 to c_start_spr_num-1) := (
        (192, c_start_spr_y1), (256, c_start_spr_y1), (320, c_start_spr_y1), (384, c_start_spr_y1),
        (64, c_start_spr_y2),  (128, c_start_spr_y2), (192, c_start_spr_y2), (256, c_start_spr_y2), (320, c_start_spr_y2), (384, c_start_spr_y2), (448, c_start_spr_y2), (512, c_start_spr_y2)
    );
    constant c_start_spr_message : t_intArray(0 to c_start_spr_num-1) := (15,25,16,10, 13,14,15,14,23,13,14,27); -- 'A' starts at sprite index (code point) 10

    -- Font colors
    constant c_colr_a     : integer := 16#202#;  -- initial colour A
    constant c_colr_inc_a : integer := 16#101#;  -- increment for colour A
    constant c_colr_b     : integer := 16#002#;  -- initial colour b
    constant c_colr_inc_b : integer := 16#001#;  -- increment for colour B
    constant c_slin_1a    : integer := 150;  -- 1st line of colour a
    constant c_slin_1b    : integer := 178;  -- 1st line of colour b
    constant c_slin_2a    : integer := 250;  -- 2nd line of colour a
    constant c_slin_2b    : integer := 278;  -- 2nd line of colour b
    constant c_line_inc   : integer := 3;      -- lines of each colour

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
    signal font_colr : integer range 0 to c_max_color;
    signal cnt_line : integer range 0 to c_line_inc;
    signal colr_sel : std_logic := '0'; -- 0 for color A, 1 for color B
	
begin
    -- Concurrent assignments	

    -- Modulate colors of start screen text ("copper bars")
    copp_bars: process(i_clock)
    begin
        if (rising_edge(i_clock)) then
            if (i_line = '1') then
                if (i_scan_pos.y = c_slin_1a or i_scan_pos.y = c_slin_2a) then
                    cnt_line <= 0;
                    font_colr <= c_colr_a;
                    colr_sel <= '0';
                elsif (i_scan_pos.y = c_slin_1b or i_scan_pos.y = c_slin_2b) then
                    cnt_line <= 0;
                    font_colr <= c_colr_b;
                    colr_sel <= '1';
                else
                    cnt_line <= cnt_line + 1;
                    if (cnt_line = c_line_inc-1) then
                        cnt_line <= 0;
                        if (colr_sel = '0') then
                            font_colr <= font_colr + c_colr_inc_a;
                        else
                            font_colr <= font_colr + c_colr_inc_b;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process copp_bars;

	 
    -- Set draw output
    process(i_scan_pos)
        variable draw_tmp : std_logic := '0';
        variable color_tmp : integer range 0 to 4095 := 0;
    begin

        draw_tmp := '0';
        color_tmp := 0;

        -- Draw sprites
        for i in 12 to 23 loop
            if spr_draw_array(i).draw then
                draw_tmp := '1';
                color_tmp := font_colr;
            end if;
        end loop;

        -- Render vgaText
        if (i_start_screen = '1') then
            -- Element 4 was removed, welcome text replaced with sprites
            for i in 3 to 3 loop
                if drawElementArray(i).pixelOn then
                    draw_tmp := '1';
                    color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
        end if;
        if (i_pause_screen = '1') then
            for i in 4 to 5 loop
                if drawElementArray(i).pixelOn then
                    draw_tmp := '1';
                    color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
        end if;
        if (i_game_over_screen = '1') then
            for i in 6 to 7 loop
                if drawElementArray(i).pixelOn then
                    draw_tmp := '1';
                    color_tmp := drawElementArray(i).rgb;
                end if;
            end loop;
        end if;

        -- Override all drawing
        if (i_draw_en = '0') then
            draw_tmp := '0';
            color_tmp := 0;
        end if;
		  
        -- Assign outputs
        o_draw <= draw_tmp;
        o_color <= color_tmp;
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

    -- Sprite slots 12-23, start screen message
    gen_spr: for i in 0 to c_start_spr_num-1 generate
        sprX: entity work.sprite_draw port map(
            i_clock => i_clock,
            i_reset => '0',
            i_pos => c_start_spr_pos(i),
            i_scan_pos => i_scan_pos,
            i_draw_en => i_start_screen,
            i_spr_idx => c_start_spr_message(i),
            i_width => 8,
            i_height => 8,
            i_scale_x => c_start_spr_scale,
            i_scale_y => c_start_spr_scale,
            o_draw_elem => spr_draw_array(12+i),
            o_arb_port => spr_port_in_array(12+i), -- Out from here, in to arbiter
            i_arb_port => spr_port_out_array(12+i)
        );
    end generate gen_spr;
	
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
		drawElement => drawElementArray(7)
	);
    
end architecture rtl;