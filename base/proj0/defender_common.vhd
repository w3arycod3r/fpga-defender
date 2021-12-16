-- defender_common: Package containing common code for FPGA defender
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package defender_common is

    -- Constants
    constant c_num_text_elems: integer := 8;
    constant c_screen_width : integer := 640;
    constant c_screen_height : integer := 480;
    constant c_bar_height : integer := 3;
    constant c_bar_offset : integer := 30;
    constant c_upper_bar_pos : integer := c_bar_offset - c_bar_height;
    constant c_lower_bar_pos : integer := c_screen_height - c_bar_offset;

    constant c_ship_width : integer := 30;
    constant c_ship_height : integer := 20;

    -- Initial conditions
    constant c_initial_lives : integer := 3;

    -- Game parameters
    constant c_extra_life_score_mult : integer := 500; -- After how many points should we award an extra life?

    -- Integer ranges
    constant c_max_color : integer := 4095;
    constant c_max_speed : integer := 20;
    constant c_max_size  : integer := 100;
    constant c_min_x : integer := -c_max_size;
    constant c_max_x : integer := c_screen_width+c_max_size;
    constant c_min_y : integer := -c_max_size;
    constant c_max_y : integer := c_screen_height+c_max_size;
    constant c_max_score : integer := 999999;
    constant c_max_lives : integer := 5;

    -- Sounds
    constant c_sound_game_start : std_logic_vector(2 downto 0) := "000";
    constant c_sound_player_fire : std_logic_vector(2 downto 0) := "001";
    constant c_sound_enemy_fire : std_logic_vector(2 downto 0) := "010";
    constant c_sound_enemy_destroy : std_logic_vector(2 downto 0) := "011";
    constant c_sound_player_hit : std_logic_vector(2 downto 0) := "011";
    constant c_sound_game_over : std_logic_vector(2 downto 0) := "100";

    -- Types
    type t_point_2d is
    record
        x : integer range c_min_x to c_max_x;
        y : integer range c_min_y to c_max_y;
    end record;

    type t_size_2d is
    record
        w : integer range 0 to c_max_size;
        h : integer range 0 to c_max_size;
    end record;

    type t_speed_2d is
    record
        x : integer range -c_max_speed to c_max_speed;
        y : integer range -c_max_speed to c_max_speed;
    end record;
    
    -- Functions
    function darken(color : integer; shift_val : integer) return integer;

    -- Is the current scan position in range of the rectangle? Provide one point and a size
    function in_range_rect(scan_pos : t_point_2d; obj_pos : t_point_2d; obj_size : t_size_2d) return boolean;
    -- Provide two points
    function in_range_rect_2pt(scan_pos : t_point_2d; top_left : t_point_2d; bott_right : t_point_2d) return boolean;
    -- Are the two rectangles intersecting? o1 should be smaller than o2
    function collide_rect(o1_pos : t_point_2d; o1_size : t_size_2d; o2_pos : t_point_2d; o2_size : t_size_2d) return boolean;
    -- Is the rectangle off screen?
    function off_screen_rect(o1_pos : t_point_2d; o1_size : t_size_2d) return boolean;

end defender_common;

package body defender_common is

	function darken(color : integer; shift_val : integer) return integer is
        variable red : integer := 0;
        variable green : integer := 0;
        variable blue : integer := 0;
        variable color_uns : unsigned(11 downto 0);
        variable color_out : integer;
	begin
        color_uns := to_unsigned(color, color_uns'LENGTH);
        red := to_integer(color_uns(11 downto 8));
        green := to_integer(color_uns(7 downto 4));
        blue := to_integer(color_uns(3 downto 0));

        red := red - shift_val;
        green := green - shift_val;
        blue := blue - shift_val;

        if (red < 0) then
            red := 0;
        end if;
        if (green < 0) then
            green := 0;
        end if;
        if (blue < 0) then
            blue := 0;
        end if;

        color_uns := (to_unsigned(red, 4) & to_unsigned(green, 4) & to_unsigned(blue, 4));
        color_out := to_integer(color_uns);

        return color_out;
	end function;

    function in_range_rect(scan_pos : t_point_2d; obj_pos : t_point_2d; obj_size : t_size_2d) return boolean is
    begin
        if (scan_pos.x >= obj_pos.x and scan_pos.x < obj_pos.x + obj_size.w) and  -- Inside X
           (scan_pos.y >= obj_pos.y and scan_pos.y < obj_pos.y + obj_size.h) then -- Inside Y

            return true;
        else
            return false;
        end if;
    end function;

    function in_range_rect_2pt(scan_pos : t_point_2d; top_left : t_point_2d; bott_right : t_point_2d) return boolean is
    begin
        if (scan_pos.x >= top_left.x and scan_pos.x < bott_right.x) and  -- Inside X
           (scan_pos.y >= top_left.y and scan_pos.y < bott_right.y) then -- Inside Y

            return true;
        else
            return false;
        end if;
    end function;


    function collide_rect(o1_pos : t_point_2d; o1_size : t_size_2d; o2_pos : t_point_2d; o2_size : t_size_2d) return boolean is
    begin
        if ( ((o1_pos.x >= o2_pos.x and o1_pos.x <= o2_pos.x + o2_size.w - 1) or (o1_pos.x + o1_size.w - 1 >= o2_pos.x and o1_pos.x + o1_size.w - 1 <= o2_pos.x + o2_size.w - 1)) and
             ((o1_pos.y >= o2_pos.y and o1_pos.y <= o2_pos.y + o2_size.h - 1) or (o1_pos.y + o1_size.h - 1 >= o2_pos.y and o1_pos.y + o1_size.h - 1 <= o2_pos.y + o2_size.h - 1)) ) then

            return true;
        else
            return false;
        end if;
    end function;

    function off_screen_rect(o1_pos : t_point_2d; o1_size : t_size_2d) return boolean is
    begin
        if (o1_pos.x + o1_size.w - 1 < 0) or (o1_pos.x > c_screen_width - 1) or (o1_pos.y + o1_size.h - 1 < 0) or (o1_pos.y > c_screen_height - 1) then
            return true;
        else
            return false;
    end if;
    end function;


    

end defender_common;
