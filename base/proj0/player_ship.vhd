-- player_ship: Logic and graphics generation
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity player_ship is
    generic (
        g_ship_color : integer := 16#F00#;

        -- Play area limits
        g_left_bound : integer := 0;
        g_right_bound : integer := 640 / 2;
        g_upper_bound : integer := 30;
        g_lower_bound : integer := 480 - 30;

        -- Update position every 1 frames
        g_frame_update_cnt : integer := 1; -- Defines "smoothness" of animation
        g_speed_scale_x : integer := 10; -- Defines the speed range for the tilt, higher value = faster ship movement for same tilt
        g_speed_scale_y : integer := 17;
        -- Hysteresis params
        g_min_speed_x : integer := 1;
        g_min_speed_y : integer := 1;
        g_accel_in_max : integer := 2**8 -- Max input value from accelerometer (absolute value)
    );
    port (
        i_clock : in std_logic;
        i_update_pulse : in std_logic;
        i_reset_pulse : in std_logic;

        -- HMI Inputs
        accel_scale_x, accel_scale_y : in integer;
        i_key_press : in std_logic_vector(1 downto 0); -- Pulse, keypress event, read on logical update

        -- Control Signals
        i_row : in integer range 0 to c_screen_height-1;
        i_column : in integer range 0 to c_screen_width-1;
        i_draw_en : in std_logic;

        -- Output State
        o_pos_x : out integer;
        o_pos_y : out integer;


        o_color : out integer range 0 to 4095;
        o_draw : out std_logic
    );
end entity player_ship;

 
architecture rtl of player_ship is
    -- Constants
    constant c_init_pos_x : integer := (g_right_bound - g_left_bound)/2;
    constant c_init_pos_y : integer := (g_lower_bound - g_upper_bound)/2;
    
    -- Types
    
    -- Signals

    -- coords of top left of object
    signal r_xPos : integer range 0 to c_screen_width-1 := c_init_pos_x;
    signal r_yPos : integer range 0 to c_screen_height-1 := c_init_pos_y;

    -- Pixels per update. Update in # of frames is set by g_frame_update_cnt
    signal r_xSpeed : integer := 0;
    signal r_ySpeed : integer := 0;
    
begin

    -- Cannon fire key event
    process(i_clock)
        -- Vars
        
    begin
        if (rising_edge(i_clock) and i_update_pulse = '1' and i_key_press(0) = '1') then

            
        end if;
    end process;
    
    -- Set draw output
    process(i_row, i_column, r_xPos, r_yPos)
        variable r_draw_tmp : std_logic := '0';
        variable r_color_tmp : integer range 0 to 4095 := 0;
    begin

        r_draw_tmp := '0';
        r_color_tmp := 0;

        -- is current pixel coordinate inside our box?
        if (i_column >= r_xPos and i_column <= r_xPos+c_ship_width and i_row >= r_yPos and i_row <= r_yPos+c_ship_height) and -- Inside Rectangle
           (i_row > ((i_column - r_xPos) * c_ship_height / c_ship_width) + r_yPos) then                                       -- Below hypotenuse of triangle

            r_draw_tmp := '1';
            r_color_tmp := g_ship_color;
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


    -- Update state
    process(i_clock)
        -- Vars
        variable r_xPos_new : integer;
        variable r_yPos_new : integer;
        variable r_frame_cnt : integer range 0 to g_frame_update_cnt := 0;
    begin
        if (rising_edge(i_clock)) then

            if (i_reset_pulse = '1') then
                r_xPos <= c_init_pos_x;
                r_yPos <= c_init_pos_y;
            
            -- Time to update state
            elsif (i_update_pulse = '1') then

                r_frame_cnt := r_frame_cnt + 1;
                -- Limit position update rate
                if (r_frame_cnt = g_frame_update_cnt) then
                    r_frame_cnt := 0;

                    r_xPos_new := r_xPos + r_xSpeed;
                    r_yPos_new := r_yPos + r_ySpeed;

                    -- Check bounds and clip

                    -- X bounds
                    if (r_xPos_new + c_ship_width > g_right_bound) then
                        r_xPos_new := g_right_bound - c_ship_width;
                    end if;
                    if (r_xPos_new < g_left_bound) then
                        r_xPos_new := g_left_bound;
                    end if;

                    -- Y bounds
                    if (r_yPos_new + c_ship_height > g_lower_bound) then
                        r_yPos_new := g_lower_bound - c_ship_height;
                    end if;
                    if (r_yPos_new < g_upper_bound) then
                        r_yPos_new := g_upper_bound;
                    end if;

                    -- Assign new values
                    r_xPos <= r_xPos_new;
                    r_yPos <= r_yPos_new;

                end if;
            end if;
        end if;
    end process;

    -- Set ship speed from user input
    process(accel_scale_x, accel_scale_y)
        -- Vars
        variable r_xSpeed_new : integer;
        variable r_ySpeed_new : integer;
    begin

        -- Scaled 0 to g_speed_scale
        r_xSpeed_new := abs(accel_scale_x) * g_speed_scale_x / g_accel_in_max;
        r_ySpeed_new := abs(accel_scale_y) * g_speed_scale_y / g_accel_in_max;

        -- Hysteresis, require a tilt of a certain steepness before any movement occurs
        if (r_xSpeed_new < g_min_speed_x) then
            r_xSpeed_new := 0;
        end if;
        if (r_ySpeed_new < g_min_speed_y) then
            r_ySpeed_new := 0;
        end if;

        -- Direction of tilt
        -- x+ : left,    x- : right
        -- y+ : forward, y- : backward

        -- Negative speed means LEFT or UP
        if (accel_scale_x > 0) then
            r_xSpeed_new := -r_xSpeed_new;
        end if;
        if (accel_scale_y < 0) then
            r_ySpeed_new := -r_ySpeed_new;
        end if;

        -- Assign new values
        r_xSpeed <= r_xSpeed_new;
        r_ySpeed <= r_ySpeed_new;
    end process;

    -- State Outputs
    o_pos_x <= r_xPos;
    o_pos_y <= r_yPos;
    
end architecture rtl;