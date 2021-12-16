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
        g_bar_color : integer := 16#FFF#;
        g_ship_color : integer := 16#F00#;
        g_score_color : integer := 16#FFF#
        

        

    );
    port (
        i_clock : in std_logic;

        -- Control signals
        i_update_pulse : in std_logic;
        i_scan_pos : in t_point_2d;
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
        drawElementArray : inout type_drawElementArray(0 to c_num_text_elems-1);

        -- Sprites
        spr_port_in_array : inout t_arb_port_in_array(0 to c_spr_num_elems-1);
        spr_port_out_array : inout t_arb_port_out_array(0 to c_spr_num_elems-1);
        spr_draw_array : inout t_spr_draw_elem_array(0 to c_spr_num_elems-1)

    );
end entity hud;

architecture rtl of hud is
    -- Constants

    -- Position and size of elements
    
	-- Using smaller ship sprite (idx 1) to draw lives display
    constant c_hud_ship_spacing_x : integer := 10;
    constant c_hud_ship_scale : integer := 3;
    constant c_hud_ship_width : integer := c_hud_ship_scale*c_spr_sizes(1).w;
    constant c_hud_ship_height : integer := c_hud_ship_scale*c_spr_sizes(1).h;

    constant c_hud_ship_pos_y   : integer := c_upper_bar_pos/2 - c_hud_ship_height/2;
    constant c_hud_ship_pos_x1  : integer := 20;
    constant c_hud_ship_pos_x2  : integer := c_hud_ship_pos_x1 + 1*(c_hud_ship_width + c_hud_ship_spacing_x);
    constant c_hud_ship_pos_x3  : integer := c_hud_ship_pos_x1 + 2*(c_hud_ship_width + c_hud_ship_spacing_x);
    constant c_hud_ship_pos_x4  : integer := c_hud_ship_pos_x1 + 3*(c_hud_ship_width + c_hud_ship_spacing_x);
    constant c_hud_ship_pos_x5  : integer := c_hud_ship_pos_x1 + 4*(c_hud_ship_width + c_hud_ship_spacing_x);

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
    signal r_lives_draw_en : std_logic_vector(1 to 5);

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

    -- Lives draw enable
    process(i_num_lives)
        variable lives_draw_en : std_logic_vector(1 to 5);
    begin
        lives_draw_en := (others => '0');

        if (i_num_lives >= 1) then
            lives_draw_en(1) := '1';
        end if;
        if (i_num_lives >= 2) then
            lives_draw_en(2) := '1';
        end if;
        if (i_num_lives >= 3) then
            lives_draw_en(3) := '1';
        end if;
        if (i_num_lives >= 4) then
            lives_draw_en(4) := '1';
        end if;
        if (i_num_lives >= 5) then
            lives_draw_en(5) := '1';
        end if;

        r_lives_draw_en <= lives_draw_en;
    end process;
	 
	 
    -- Set draw output
    process(i_scan_pos)
        variable draw_tmp : std_logic := '0';
        variable color_tmp : integer range 0 to 4095 := 0;
    begin

        draw_tmp := '0';
        color_tmp := 0;

        -- Bars
        if (i_scan_pos.y > c_upper_bar_pos and i_scan_pos.y < c_upper_bar_pos + c_bar_height) or
           (i_scan_pos.y > c_lower_bar_pos and i_scan_pos.y < c_lower_bar_pos + c_bar_height and c_lower_bar_draw_en) then

            draw_tmp := '1';
            color_tmp := g_bar_color;
        end if;

        -- Sprites
        for i in 1 to 5 loop
            if spr_draw_array(i).draw then
                draw_tmp := '1';
                color_tmp := spr_draw_array(i).color;
            end if;
        end loop;

        -- Render vgaText

        -- Logo
        if drawElementArray(0).pixelOn and c_logo_draw_en then
            draw_tmp := '1';
            color_tmp := drawElementArray(0).rgb;
        end if;

        -- Score
        if drawElementArray(1).pixelOn then
            draw_tmp := '1';
            color_tmp := drawElementArray(1).rgb;
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
                r_start_bcd_conv <= '1';
            else
                r_start_bcd_conv <= '0';
            end if;
        end if;

    end process;

    -- Instantiation

    -- Sprite slots 1-5
    -- Index 1: small ship
    spr1: entity work.sprite_draw port map(
        i_clock => i_clock,
        i_reset => '0',
        i_pos => (c_hud_ship_pos_x1, c_hud_ship_pos_y),
        i_scan_pos => i_scan_pos,
        i_draw_en => r_lives_draw_en(1),
        i_spr_idx => 1,
        i_width => c_spr_sizes(1).w,
        i_height => c_spr_sizes(1).h,
        i_scale_x => c_hud_ship_scale,
        i_scale_y => c_hud_ship_scale,
        o_draw_elem => spr_draw_array(1),
        o_arb_port => spr_port_in_array(1), -- Out from here, in to arbiter
        i_arb_port => spr_port_out_array(1)
    );
    spr2: entity work.sprite_draw port map(
        i_clock => i_clock,
        i_reset => '0',
        i_pos => (c_hud_ship_pos_x2, c_hud_ship_pos_y),
        i_scan_pos => i_scan_pos,
        i_draw_en => r_lives_draw_en(2),
        i_spr_idx => 1,
        i_width => c_spr_sizes(1).w,
        i_height => c_spr_sizes(1).h,
        i_scale_x => c_hud_ship_scale,
        i_scale_y => c_hud_ship_scale,
        o_draw_elem => spr_draw_array(2),
        o_arb_port => spr_port_in_array(2), -- Out from here, in to arbiter
        i_arb_port => spr_port_out_array(2)
    );
    spr3: entity work.sprite_draw port map(
        i_clock => i_clock,
        i_reset => '0',
        i_pos => (c_hud_ship_pos_x3, c_hud_ship_pos_y),
        i_scan_pos => i_scan_pos,
        i_draw_en => r_lives_draw_en(3),
        i_spr_idx => 1,
        i_width => c_spr_sizes(1).w,
        i_height => c_spr_sizes(1).h,
        i_scale_x => c_hud_ship_scale,
        i_scale_y => c_hud_ship_scale,
        o_draw_elem => spr_draw_array(3),
        o_arb_port => spr_port_in_array(3), -- Out from here, in to arbiter
        i_arb_port => spr_port_out_array(3)
    );
    spr4: entity work.sprite_draw port map(
        i_clock => i_clock,
        i_reset => '0',
        i_pos => (c_hud_ship_pos_x4, c_hud_ship_pos_y),
        i_scan_pos => i_scan_pos,
        i_draw_en => r_lives_draw_en(4),
        i_spr_idx => 1,
        i_width => c_spr_sizes(1).w,
        i_height => c_spr_sizes(1).h,
        i_scale_x => c_hud_ship_scale,
        i_scale_y => c_hud_ship_scale,
        o_draw_elem => spr_draw_array(4),
        o_arb_port => spr_port_in_array(4), -- Out from here, in to arbiter
        i_arb_port => spr_port_out_array(4)
    );
    spr5: entity work.sprite_draw port map(
        i_clock => i_clock,
        i_reset => '0',
        i_pos => (c_hud_ship_pos_x5, c_hud_ship_pos_y),
        i_scan_pos => i_scan_pos,
        i_draw_en => r_lives_draw_en(5),
        i_spr_idx => 1,
        i_width => c_spr_sizes(1).w,
        i_height => c_spr_sizes(1).h,
        i_scale_x => c_hud_ship_scale,
        i_scale_y => c_hud_ship_scale,
        o_draw_elem => spr_draw_array(5),
        o_arb_port => spr_port_in_array(5), -- Out from here, in to arbiter
        i_arb_port => spr_port_out_array(5)
    );
	     
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
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
		hCount => i_scan_pos.x,
		vCount => i_scan_pos.y,
		drawElement => drawElementArray(1)
	);
    
end architecture rtl;