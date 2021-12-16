-- enemies: Logic and graphics generation
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

entity enemies is
    port (
        i_clock : in std_logic;
        i_update_pulse : in std_logic;
        i_reset_pulse : in std_logic;

        -- Control Signals
        i_row : in integer range 0 to c_screen_height-1;
        i_column : in integer range 0 to c_screen_width-1;
        i_draw_en : in std_logic;

        -- HMI Inputs
        i_key_press : in std_logic_vector(1 downto 0); -- Pulse, keypress event, read on logical update

        -- Game state
        i_score : in integer range 0 to c_max_score;
        i_ship_pos_x : in integer range c_min_x to c_max_x;
        i_ship_pos_y : in integer range c_min_y to c_max_y;

        o_ship_collide : out std_logic;
        o_cannon_collide : out std_logic;
        o_cannon_fire : out std_logic;
        o_score_inc : out integer range 0 to c_max_score;

        o_color : out integer range 0 to c_max_color;
        o_draw : out std_logic
    );
end entity enemies;

architecture rtl of enemies is

    -- Types
    constant c_num_enemy_sizes : integer := 3;
    constant c_num_enemy_colors : integer := 8;

    type t_sizeArray is array(0 to c_num_enemy_sizes-1) of integer range 0 to c_max_size;
    type t_colorArray is array(0 to c_num_enemy_colors-1) of integer range 0 to c_max_color;
    type t_pointsArray is array(0 to c_num_enemy_sizes-1) of integer range 0 to c_max_score;

    type t_enemy is
    record
        alive: boolean;
        pos: t_point_2d;
        speed: t_speed_2d;
        size_idx: integer range 0 to c_num_enemy_sizes-1;
        size: t_size_2d;
        color: integer range 0 to c_max_color;
    end record;
    constant init_t_enemy: t_enemy := (false, (0,0), (0,0), 0, (0,0), 0);
    type t_enemyArray is array(natural range <>) of t_enemy;

    type t_fire is
    record
        alive: boolean;
        pos: t_point_2d;
        spawn_pos: t_point_2d;
        speed: t_speed_2d;
        size: t_size_2d;
        color: integer range 0 to c_max_color;
        rand_slv: std_logic_vector(7 downto 0);
    end record;
    constant init_t_fire: t_fire := (false, (0,0), (0,0), (0,0), (0,0), 0, (others => '0'));
    type t_fireArray is array(natural range <>) of t_fire;

    -- Constants
    constant c_max_num_enemies : integer := 6;
    constant c_max_num_fire : integer := 5;
    constant c_max_spawn_frame_rate : integer := 120;

    constant c_enemy_size : t_sizeArray := (20, 40, 60);
    constant c_enemy_points : t_pointsArray := (21, 14, 7); -- Number of points awarded for each enemy size
    constant c_enemy_color : t_colorArray := (16#F90#, 16#0F0#, 16#00F#, 16#FF0#, 16#F0F#, 16#0FF#, 16#880#, 16#808#);
    
    constant c_fire_tracer_color : integer := 16#808#;
    constant c_fire_bullet_color : integer := 16#F0F#;
    constant c_fire_size : integer := 4;
    constant c_fire_bullet_tail_width : integer := 38; -- Fixed width of the tail on the bullet, at end of tracer
    constant c_fire_speed : integer := 6;
    constant c_fire_trace_div : integer := 64; -- Number of divisions of max path length of a bullet. Defines the minimum dash size in the tracer pattern. Higher values result in smaller dashes.

    constant c_spawn_ylim_upper : integer := c_upper_bar_pos + c_bar_height;
    constant c_spawn_ylim_lower : integer := c_lower_bar_pos;
    constant c_spawn_range : integer := c_spawn_ylim_lower - c_spawn_ylim_upper;

    constant c_num_stages : integer := 6;

    -- Signals
    signal fireArray : t_fireArray(0 to c_max_num_fire-1) := (others => init_t_fire);
    signal enemyArray : t_enemyArray(0 to c_max_num_enemies-1) := (others => init_t_enemy);
    signal r_stage : integer range 0 to c_num_stages := 0; -- Which stage (difficulty level) are we on?
    signal r_num_enemy_target : integer range 0 to c_max_num_enemies := 0; -- How many enemies should we have on screen?
    signal r_new_enemy_speed : integer range -c_max_speed to c_max_speed := 0; -- How fast should new enemies go?
    signal r_spawn_frame_rate : integer range 0 to c_max_spawn_frame_rate := 0; -- How often should we spawn enemies (in # of frames)
    signal r_spawn_update : std_logic := '0'; -- Time to update spawn? (Possibly spawn a new enemy)
    signal w_lfsr_out_slv : std_logic_vector(7 downto 0);
    signal w_lfsr_out_int : integer range 0 to 2**8-1;

begin

    -- Set stage from score
    process(i_score)
    begin
        if i_score >= 0 and i_score < 100 then
            r_stage <= 1;
        elsif i_score >= 100 and i_score < 300 then
            r_stage <= 2;
        elsif i_score >= 300 and i_score < 500 then
            r_stage <= 3;
        elsif i_score >= 500 and i_score < 700 then
            r_stage <= 4;
        elsif i_score >= 700 and i_score < 900 then
            r_stage <= 5;
        elsif i_score >= 900 then
            r_stage <= 6;
        else
            r_stage <= 0;
        end if;
    end process;

    -- Set enemy count target from stage
    process(r_stage)
    begin
        case r_stage is
            when 1 =>
                r_num_enemy_target <= 3;
            when 2 => 
                r_num_enemy_target <= 4;
            when 3 => 
                r_num_enemy_target <= 5;
            when 4 => 
                r_num_enemy_target <= 6;
            when 5 => 
                r_num_enemy_target <= 6;
            when 6 => 
                r_num_enemy_target <= 6;
            when others =>
                r_num_enemy_target <= 0;
        end case;
    end process;

    -- Set enemy speed and spawn rate from stage
    process(r_stage)
    begin
        case r_stage is
            when 1 =>
                r_new_enemy_speed <= 1;
                r_spawn_frame_rate <= 80;
            when 2 => 
                r_new_enemy_speed <= 2;
                r_spawn_frame_rate <= 30;
            when 3 => 
                r_new_enemy_speed <= 3;
                r_spawn_frame_rate <= 30;
            when 4 => 
                r_new_enemy_speed <= 4;
                r_spawn_frame_rate <= 30;
            when 5 => 
                r_new_enemy_speed <= 5;
                r_spawn_frame_rate <= 20;
            when 6 => 
                r_new_enemy_speed <= 6;
                r_spawn_frame_rate <= 20;
            when others =>
                r_new_enemy_speed <= 0;
                r_spawn_frame_rate <= 0;
        end case;
    end process;
    
    
    -- Set draw output
    process(i_row, i_column)
        variable r_draw_tmp : std_logic := '0';
        variable r_color_tmp : integer range 0 to c_max_color := 0;
        variable r_trace_dist : integer range 0 to 31;
        variable r_trace_idx : integer range 0 to 15;

    begin

        r_draw_tmp := '0';
        r_color_tmp := 0;

        -- Scan each enemy and render (using rectangle shape)
        for i in 0 to c_max_num_enemies-1 loop
            if in_range_rect((i_column, i_row), enemyArray(i).pos, enemyArray(i).size) and enemyArray(i).alive then

                r_draw_tmp := '1';
                r_color_tmp := enemyArray(i).color;

            end if;
        end loop;

        -- Render cannon tracers: Draw a random "dashed" line from spawn x to current x, with a thickness defined by the height of the fire
        for i in 0 to c_max_num_fire-1 loop

            if in_range_rect_2pt((i_column, i_row), fireArray(i).spawn_pos, (fireArray(i).pos.x, fireArray(i).pos.y+fireArray(i).size.h)) and fireArray(i).alive then

                r_trace_dist := (i_column - fireArray(i).spawn_pos.x) * c_fire_trace_div / (c_screen_width-c_ship_width); -- Scale distance to range 0 to c_fire_trace_div. Slice the total max distance into c_fire_trace_div pieces.
                
                -- Get a bit index 0-7 from the distance
                r_trace_idx := r_trace_dist mod 8;

                -- Pick out a bit from the random value for this cannon fire. Create the dashed tracer pattern. After half the distance, the tracer should be solid.
                if (fireArray(i).rand_slv(r_trace_idx) = '1' or fireArray(i).pos.x - i_column < c_fire_bullet_tail_width) then
                    r_draw_tmp := '1';
                    r_color_tmp := c_fire_tracer_color;
                end if;

            end if;
        end loop;

        -- Render bullets: Draw a square at the front of the fire tracer
        for i in 0 to c_max_num_fire-1 loop
            
            if in_range_rect((i_column, i_row), fireArray(i).pos, fireArray(i).size) and fireArray(i).alive then

                r_draw_tmp := '1';
                r_color_tmp := c_fire_bullet_color;

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

    -- Spawn update clock
    process(i_clock)
        variable spawn_frame_cnt : integer range 0 to c_max_spawn_frame_rate := 0;
    begin
        if rising_edge(i_clock) and i_update_pulse = '1' then
            r_spawn_update <= '0';

            spawn_frame_cnt := spawn_frame_cnt+1;
            if spawn_frame_cnt >= r_spawn_frame_rate then
                spawn_frame_cnt := 0;
                r_spawn_update <= '1'; -- One cycle pulse
            end if;
        end if;
    end process;

    -- Update state
    process(i_clock)
        -- Vars
        variable localEnemyArray : t_enemyArray(0 to c_max_num_enemies-1) := (others => init_t_enemy);
        variable localFireArray : t_fireArray(0 to c_max_num_fire-1) := (others => init_t_fire);
        -- Enemy and Player
        variable x, p_x : integer range c_min_x to c_max_x := 0;
        variable y, p_y : integer range c_min_y to c_max_y := 0;
        variable w, p_w : integer range 0 to c_max_size := 0;
        variable h, p_h : integer range 0 to c_max_size := 0;

        variable num_alive : integer range 0 to c_max_num_enemies := 0;
        variable rand_pos : t_point_2d := (0,0);
        variable rand_pos_y : integer range c_min_y to c_max_y := 0;
        variable rand_speed : t_speed_2d := (0,0);
        variable rand_size : t_size_2d := (0,0);
        variable rand_size_idx : integer range 0 to c_num_enemy_sizes-1;
        variable rand_size_int : integer range 0 to c_max_size := 0;
        variable rand_color : integer range 0 to c_max_color := 0;
        variable open_enemy_slot : integer range 0 to c_max_num_enemies-1 := 0;
        variable open_fire_slot : integer range -1 to c_max_num_fire-1 := 0;
        variable ship_collide : std_logic := '0';
        variable cannon_collide : std_logic := '0';
        variable cannon_fire : std_logic := '0';
        variable score_inc : integer range 0 to c_max_score := 0;

    begin
        if (rising_edge(i_clock) and i_update_pulse = '1') then

            -- Capture current state of objects
            localEnemyArray := enemyArray;
            localFireArray := fireArray;

            if (i_reset_pulse = '1') then

                -- Clear enemy data
                for i in 0 to c_max_num_enemies-1 loop
                    localEnemyArray(i).alive := false;
                end loop;

                -- Clear cannon fire data
                for i in 0 to c_max_num_fire-1 loop
                    localFireArray(i).alive := false;
                end loop;
            
            -- Time to update state
            else

                -- Handle enemy collision with ship
                ship_collide := '0';
                for i in 0 to c_max_num_enemies-1 loop

                    -- Has ship collided with this enemy?
                    if collide_rect( (i_ship_pos_x, i_ship_pos_y), (c_ship_width, c_ship_height), localEnemyArray(i).pos, localEnemyArray(i).size ) and
                       localEnemyArray(i).alive then

                        localEnemyArray(i).alive := false;
                        ship_collide := '1';
                    end if;
                end loop;

                -- Handle enemy collision with cannon
                cannon_collide := '0';
                for e_i in 0 to c_max_num_enemies-1 loop

                    -- Check each enemy and fire pair for collision
                    for f_i in 0 to c_max_num_fire-1 loop
                        if collide_rect( localFireArray(f_i).pos, localFireArray(f_i).size, localEnemyArray(e_i).pos, localEnemyArray(e_i).size ) and
                           localEnemyArray(e_i).alive and localFireArray(f_i).alive then

                            -- Kill both enemy and fire
                            localEnemyArray(e_i).alive := false;
                            localFireArray(f_i).alive := false;

                            -- One cycle pulse caught by external logic
                            cannon_collide := '1';
                            -- Lookup number of points to award
                            score_inc := c_enemy_points(localEnemyArray(e_i).size_idx);
                        end if;
                    end loop;
                        
                end loop;
                
                -- Update enemy positions
                for i in 0 to c_max_num_enemies-1 loop
                    if localEnemyArray(i).alive then
                        localEnemyArray(i).pos.x := localEnemyArray(i).pos.x + localEnemyArray(i).speed.x;
                        localEnemyArray(i).pos.y := localEnemyArray(i).pos.y + localEnemyArray(i).speed.y;
                    end if;
                end loop;

                -- Update enemy alive status
                for i in 0 to c_max_num_enemies-1 loop

                    -- Is the enemy off screen?
                    if off_screen_rect( localEnemyArray(i).pos, localEnemyArray(i).size ) then
                        localEnemyArray(i).alive := false;
                    end if;
                end loop;

                -- Count alive enemies
                num_alive := 0;
                for i in 0 to c_max_num_enemies-1 loop
                    if localEnemyArray(i).alive then
                        num_alive := num_alive+1;
                    else
                        open_enemy_slot := i;
                    end if;
                end loop;

                -- Spawn enemies
                if r_spawn_update = '1' then

                    -- Should we spawn a new enemy?
                    if num_alive < r_num_enemy_target then
                        
                        -- 2 bits to pick size
                        rand_size_idx := to_integer(unsigned(w_lfsr_out_slv(7 downto 6))) mod c_num_enemy_sizes;
                        rand_size_int := c_enemy_size(rand_size_idx);
                        rand_size := (rand_size_int, rand_size_int);
                        -- 3 bits to pick color
                        rand_color := c_enemy_color(to_integer(unsigned(w_lfsr_out_slv(5 downto 3))));

                        -- Pick y pos
                        rand_pos_y := w_lfsr_out_int * c_spawn_range / 255; -- Scale to spawn range
                        rand_pos_y := rand_pos_y + c_spawn_ylim_upper;
                        -- Too low? Fix if so
                        if rand_pos_y+rand_size_int > c_spawn_ylim_lower then
                            rand_pos_y := rand_pos_y - ((rand_pos_y+rand_size_int)-c_spawn_ylim_lower); -- Subtract the out of bounds difference
                        end if;
                        rand_pos := (c_screen_width, rand_pos_y); -- Just outside of view on right side

                        -- Speed set by stage level
                        rand_speed := (-r_new_enemy_speed, 0); -- Moving left


                        localEnemyArray(open_enemy_slot).alive := true;
                        localEnemyArray(open_enemy_slot).size := rand_size;
                        localEnemyArray(open_enemy_slot).size_idx := rand_size_idx;
                        localEnemyArray(open_enemy_slot).color := rand_color;
                        localEnemyArray(open_enemy_slot).pos := rand_pos;
                        localEnemyArray(open_enemy_slot).speed := rand_speed;

                    end if;
                end if;

                -- Update fire positions
                for i in 0 to c_max_num_fire-1 loop
                    if localFireArray(i).alive then
                        localFireArray(i).pos.x := localFireArray(i).pos.x + localFireArray(i).speed.x;
                        localFireArray(i).pos.y := localFireArray(i).pos.y + localFireArray(i).speed.y;
                    end if;
                end loop;

                -- Update fire alive status
                for i in 0 to c_max_num_fire-1 loop

                    -- Is the fire off screen?
                    if off_screen_rect( localFireArray(i).pos, localFireArray(i).size ) then
                        localFireArray(i).alive := false;
                    end if;
                end loop;
                
                -- Find open fire slot
                open_fire_slot := -1;
                for i in 0 to c_max_num_fire-1 loop
                    if not localFireArray(i).alive then
                        open_fire_slot := i;
                    end if;
                end loop;

                -- Spawn Cannon Fire
                cannon_fire := '0';
                if i_key_press(0) = '1' and open_fire_slot /= -1 then
                    
                    localFireArray(open_fire_slot).alive := true;
                    -- Square
                    localFireArray(open_fire_slot).size := (c_fire_size,c_fire_size);
                    localFireArray(open_fire_slot).color := c_fire_tracer_color;
                    -- Just at the front of ship
                    localFireArray(open_fire_slot).pos := (i_ship_pos_x + c_ship_width, i_ship_pos_y + c_ship_height - c_fire_size + 1);
                    localFireArray(open_fire_slot).spawn_pos := localFireArray(open_fire_slot).pos;
                    -- Moving right
                    localFireArray(open_fire_slot).speed := (c_fire_speed, 0);
                    localFireArray(open_fire_slot).rand_slv := w_lfsr_out_slv;

                    cannon_fire := '1';
                end if;


            end if;

            -- Update objects
            enemyArray <= localEnemyArray;
            fireArray <= localFireArray;

            -- Update outputs
            o_ship_collide <= ship_collide;
            o_cannon_collide <= cannon_collide;
            o_cannon_fire <= cannon_fire;
            o_score_inc <= score_inc;
        end if;

    end process;

    -- Concurrent assignments
    w_lfsr_out_int <= to_integer(unsigned(w_lfsr_out_slv));
    
    -- Instantiation
    prng: entity work.lfsr8 port map (
        clock => i_clock,
        reset => '0',
        load => '0',
        cnt_en => '1',
        par_in => (others => '0'),
        value_out => w_lfsr_out_slv
    );
end architecture rtl;