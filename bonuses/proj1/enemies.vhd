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
        i_scan_pos : in t_point_2d;
        i_draw_en : in std_logic;
        i_lfsr_free_run : in std_logic; -- Allow the LFSR to free run?

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
        o_draw : out std_logic;

        -- Sprites
        spr_port_in_array : inout t_arb_port_in_array(0 to c_spr_num_elems-1);
        spr_port_out_array : inout t_arb_port_out_array(0 to c_spr_num_elems-1);
        spr_draw_array : inout t_spr_draw_elem_array(0 to c_spr_num_elems-1)
    );
end entity enemies;

architecture rtl of enemies is

    -- Types
    constant c_num_enem_variants : integer := 12;

    type t_sizeArray is array(natural range <>) of t_size_2d;

    type t_enemy is
    record
        alive: std_logic;
        pos: t_point_2d;
        speed: t_speed_2d;
        var_idx: integer range 0 to c_num_enem_variants-1;
    end record;
    constant init_t_enemy: t_enemy := ('0', (0,0), (0,0), 0);
    type t_enemyArray is array(natural range <>) of t_enemy;

    type t_fire is
    record
        alive: std_logic;
        pos: t_point_2d;
        spawn_pos: t_point_2d;
        speed: t_speed_2d;
        size: t_size_2d;
        color: integer range 0 to c_max_color;
        rand_slv: std_logic_vector(7 downto 0);
    end record;
    constant init_t_fire: t_fire := ('0', (0,0), (0,0), (0,0), (0,0), 0, (others => '0'));
    type t_fireArray is array(natural range <>) of t_fire;

    -- Constants
    constant c_max_num_enemies : integer := 6; -- Max number of enemies on screen at one time
    constant c_max_num_fire : integer := 5; -- Max number of bullets on screen at once
    constant c_max_spawn_frame_rate : integer := 120;

    -- Enemy variants
    constant c_enem_var_spr_idx : t_intArray(0 to c_num_enem_variants-1) := (2,  3,  4,  5, 6,  7,  8, 9, 7, 2, 3,  5); -- Which sprite to use for each variant
    constant c_enem_var_scale   : t_intArray(0 to c_num_enem_variants-1) := (4,  4,  5,  4, 5,  5,  7, 4, 8, 7, 2,  6); -- Which X and Y scale to use for each variant
    constant c_enem_var_points  : t_intArray(0 to c_num_enem_variants-1) := (14, 14, 21, 7, 21, 7,  7, 7, 7, 7, 21, 7); -- Number of points awarded for each enemy variant
    
    -- Generate scaled sizes for each enemy variant. These will be used for the bounding box of each enemy.
    function init_enemy_var_size return t_sizeArray is
        variable enem_var_size : t_sizeArray(0 to c_num_enem_variants-1);
    begin
        for i in enem_var_size'range loop
            -- Multiply base sprite sizes by the scale factors set for each enemy variant
            enem_var_size(i).w := c_spr_sizes(c_enem_var_spr_idx(i)).w * c_enem_var_scale(i);
            enem_var_size(i).h := c_spr_sizes(c_enem_var_spr_idx(i)).h * c_enem_var_scale(i);
        end loop;
        return enem_var_size;
    end function;

    constant c_enem_var_size : t_sizeArray(0 to c_num_enem_variants-1) := init_enemy_var_size;

    -- Fire
    constant c_fire_tracer_color : integer := 16#808#;
    constant c_fire_bullet_color : integer := 16#FFF#;
    constant c_fire_size : integer := 4;
    constant c_fire_bullet_tail_width : integer := 38; -- Fixed width of the tail on the bullet, at end of tracer
    constant c_fire_speed : integer := 7;
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
    signal w_lfsr_out_slv : std_logic_vector(20 downto 0);
    signal w_lfsr_out_int : integer range 0 to 2**21-1;
    signal lfsr_cnt_en : std_logic;

begin

    -- Set stage from score
    process(i_score)
    begin
        if i_score >= 0 and i_score < 150 then
            r_stage <= 1;
        elsif i_score >= 150 and i_score < 400 then
            r_stage <= 2;
        elsif i_score >= 400 and i_score < 700 then
            r_stage <= 3;
        elsif i_score >= 700 and i_score < 1000 then
            r_stage <= 4;
        elsif i_score >= 1000 then
            r_stage <= 5;
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
    process(i_scan_pos)
        variable draw_tmp : std_logic := '0';
        variable color_tmp : integer range 0 to c_max_color := 0;
        variable r_trace_dist : integer range 0 to 31;
        variable r_trace_idx : integer range 0 to 15;

    begin

        draw_tmp := '0';
        color_tmp := 0;

        -- Draw sprites
        for i in 6 to 11 loop
            if spr_draw_array(i).draw then
                draw_tmp := '1';
                color_tmp := spr_draw_array(i).color;
            end if;
        end loop;

        -- Render cannon tracers: Draw a random "dashed" line from spawn x to current x, with a thickness defined by the height of the fire
        for i in 0 to c_max_num_fire-1 loop

            if in_range_rect_2pt(i_scan_pos, fireArray(i).spawn_pos, (fireArray(i).pos.x, fireArray(i).pos.y+fireArray(i).size.h)) and fireArray(i).alive = '1' then

                r_trace_dist := (i_scan_pos.x - fireArray(i).spawn_pos.x) * c_fire_trace_div / (c_screen_width-c_ship_width); -- Scale distance to range 0 to c_fire_trace_div. Slice the total max distance into c_fire_trace_div pieces.
                
                -- Get a bit index 0-7 from the distance
                r_trace_idx := r_trace_dist mod 8;

                -- Pick out a bit from the random value for this cannon fire. Create the dashed tracer pattern. After half the distance, the tracer should be solid.
                if (fireArray(i).rand_slv(r_trace_idx) = '1' or fireArray(i).pos.x - i_scan_pos.x < c_fire_bullet_tail_width) then
                    draw_tmp := '1';
                    color_tmp := c_fire_tracer_color;
                end if;

            end if;
        end loop;

        -- Render bullets: Draw a square at the front of the fire tracer
        for i in 0 to c_max_num_fire-1 loop
            
            if in_range_rect(i_scan_pos, fireArray(i).pos, fireArray(i).size) and fireArray(i).alive = '1' then

                draw_tmp := '1';
                color_tmp := c_fire_bullet_color;

            end if;
        end loop;

        -- Override all drawing
        if (i_draw_en = '0') then
            draw_tmp := '0';
            color_tmp := 0;
        end if;
		  
        -- Assign outputs
        o_draw <= draw_tmp;
        o_color <= color_tmp;
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
        variable num_alive : integer range 0 to c_max_num_enemies := 0;

        variable rand_pos : t_point_2d := (0,0);
        variable rand_speed : t_speed_2d := (0,0);
        variable rand_size : t_size_2d := (0,0);
        variable rand_var_idx : integer range 0 to c_num_enem_variants-1;

        variable open_enemy_slot : integer range 0 to c_max_num_enemies-1 := 0;
        variable open_fire_slot : integer range -1 to c_max_num_fire-1 := 0;

        variable ship_collide : std_logic := '0';
        variable cannon_collide : std_logic := '0';
        variable cannon_fire : std_logic := '0';
        variable score_inc : integer range 0 to c_max_score := 0;

    begin
        if (rising_edge(i_clock)) then

            -- Capture current state of objects
            localEnemyArray := enemyArray;
            localFireArray := fireArray;

            if (i_reset_pulse = '1') then

                -- Clear enemy data
                for i in 0 to c_max_num_enemies-1 loop
                    localEnemyArray(i).alive := '0';
                end loop;

                -- Clear cannon fire data
                for i in 0 to c_max_num_fire-1 loop
                    localFireArray(i).alive := '0';
                end loop;
            
            -- Time to update state
            elsif (i_update_pulse = '1') then

                -- Handle enemy collision with ship
                ship_collide := '0';
                for i in 0 to c_max_num_enemies-1 loop

                    -- Has ship collided with this enemy?
                    if collide_rect( (i_ship_pos_x, i_ship_pos_y), (c_ship_width, c_ship_height), localEnemyArray(i).pos, c_enem_var_size(localEnemyArray(i).var_idx) ) and
                       localEnemyArray(i).alive = '1' then

                        localEnemyArray(i).alive := '0';
                        ship_collide := '1';
                    end if;
                end loop;

                -- Handle enemy collision with cannon
                cannon_collide := '0';
                for e_i in 0 to c_max_num_enemies-1 loop

                    -- Check each enemy and fire pair for collision
                    for f_i in 0 to c_max_num_fire-1 loop
                        if collide_rect( localFireArray(f_i).pos, localFireArray(f_i).size, localEnemyArray(e_i).pos, c_enem_var_size(localEnemyArray(e_i).var_idx) ) and
                           localEnemyArray(e_i).alive = '1' and localFireArray(f_i).alive = '1' then

                            -- Kill both enemy and fire
                            localEnemyArray(e_i).alive := '0';
                            localFireArray(f_i).alive := '0';

                            -- One cycle pulse caught by external logic
                            cannon_collide := '1';
                            -- Lookup number of points to award based on variant index
                            score_inc := c_enem_var_points(localEnemyArray(e_i).var_idx);
                        end if;
                    end loop;
                        
                end loop;
                
                -- Update enemy positions
                for i in 0 to c_max_num_enemies-1 loop
                    if localEnemyArray(i).alive = '1' then
                        localEnemyArray(i).pos.x := localEnemyArray(i).pos.x + localEnemyArray(i).speed.x;
                        localEnemyArray(i).pos.y := localEnemyArray(i).pos.y + localEnemyArray(i).speed.y;
                    end if;
                end loop;

                -- Update enemy alive status
                for i in 0 to c_max_num_enemies-1 loop

                    -- Is the enemy off screen?
                    if off_screen_rect( localEnemyArray(i).pos, c_enem_var_size(localEnemyArray(i).var_idx) ) then
                        localEnemyArray(i).alive := '0';
                    end if;
                end loop;

                -- Count alive enemies
                num_alive := 0;
                for i in 0 to c_max_num_enemies-1 loop
                    if localEnemyArray(i).alive = '1' then
                        num_alive := num_alive+1;
                    else
                        open_enemy_slot := i;
                    end if;
                end loop;

                -- Spawn enemies
                if r_spawn_update = '1' then

                    -- Should we spawn a new enemy?
                    if num_alive < r_num_enemy_target then
                        
                        -- 3 bits to pick variant index
                        rand_var_idx := to_integer(unsigned(w_lfsr_out_slv)) mod c_num_enem_variants;
                        rand_size := c_enem_var_size(rand_var_idx);

                        -- Pick y pos
                        rand_pos.y := w_lfsr_out_int mod c_spawn_range; -- Scale to spawn range
                        rand_pos.y := rand_pos.y + c_spawn_ylim_upper;
                        -- Too low? Fix if so
                        if rand_pos.y + rand_size.h > c_spawn_ylim_lower then
                            rand_pos.y := rand_pos.y - (rand_size.h - c_spawn_ylim_lower); -- Subtract the out of bounds difference
                        end if;
                        rand_pos.x := c_screen_width; -- Just outside of view on right side

                        -- Speed set by stage level
                        rand_speed := (-r_new_enemy_speed, 0); -- Moving left


                        localEnemyArray(open_enemy_slot).alive := '1';
                        localEnemyArray(open_enemy_slot).var_idx := rand_var_idx;
                        localEnemyArray(open_enemy_slot).pos := rand_pos;
                        localEnemyArray(open_enemy_slot).speed := rand_speed;

                    end if;
                end if;

                -- Update fire positions
                for i in 0 to c_max_num_fire-1 loop
                    if localFireArray(i).alive = '1' then
                        localFireArray(i).pos.x := localFireArray(i).pos.x + localFireArray(i).speed.x;
                        localFireArray(i).pos.y := localFireArray(i).pos.y + localFireArray(i).speed.y;
                    end if;
                end loop;

                -- Update fire alive status
                for i in 0 to c_max_num_fire-1 loop

                    -- Is the fire off screen?
                    if off_screen_rect( localFireArray(i).pos, localFireArray(i).size ) then
                        localFireArray(i).alive := '0';
                    end if;
                end loop;
                
                -- Find open fire slot
                open_fire_slot := -1;
                for i in 0 to c_max_num_fire-1 loop
                    if localFireArray(i).alive = '0' then
                        open_fire_slot := i;
                    end if;
                end loop;

                -- Spawn Cannon Fire
                cannon_fire := '0';
                if i_key_press(0) = '1' and open_fire_slot /= -1 then
                    
                    localFireArray(open_fire_slot).alive := '1';
                    -- Square
                    localFireArray(open_fire_slot).size := (c_fire_size,c_fire_size);
                    localFireArray(open_fire_slot).color := c_fire_tracer_color;
                    -- At the front of ship, at same height as the cannon on the sprite
                    localFireArray(open_fire_slot).pos := (i_ship_pos_x + c_ship_width, i_ship_pos_y + c_ship_height - c_ship_cannon_offset);
                    localFireArray(open_fire_slot).spawn_pos := localFireArray(open_fire_slot).pos;
                    -- Moving right
                    localFireArray(open_fire_slot).speed := (c_fire_speed, 0);
                    localFireArray(open_fire_slot).rand_slv := w_lfsr_out_slv(7 downto 0);

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
    lfsr_cnt_en <= i_update_pulse or i_lfsr_free_run;
    
    -- Instantiation
    
    -- Sprite slots 6-11
    -- One sprite for each enemy slot
    -- Each enemy slot is a position in the enemyArray
    gen_spr: for i in 0 to c_max_num_enemies-1 generate
        sprX: entity work.sprite_draw port map(
            i_clock => i_clock,
            i_reset => '0',
            i_pos => enemyArray(i).pos,
            i_scan_pos => i_scan_pos,
            i_draw_en => enemyArray(i).alive,
            i_spr_idx => c_enem_var_spr_idx(enemyArray(i).var_idx),
            i_width => c_spr_sizes(c_enem_var_spr_idx(enemyArray(i).var_idx)).w, -- Lookup sprite size for the sprite index corresp to selected variant
            i_height => c_spr_sizes(c_enem_var_spr_idx(enemyArray(i).var_idx)).h,
            i_scale_x => c_enem_var_scale(enemyArray(i).var_idx), -- Lookup scale size for the selected variant
            i_scale_y => c_enem_var_scale(enemyArray(i).var_idx),
            o_draw_elem => spr_draw_array(6+i),
            o_arb_port => spr_port_in_array(6+i), -- Out from here, in to arbiter
            i_arb_port => spr_port_out_array(6+i)
        );
    end generate gen_spr;
    
    prng: entity work.lfsr_n
    generic map (
        g_taps => "101000000000000000000",
        g_init_seed => std_logic_vector(to_unsigned(16#9A9A9#, 21))
    )
    port map (
        i_clock => i_clock,
        i_reset => '0',
        i_load => '0',
        i_cnt_en => lfsr_cnt_en,
        i_data => (others => '0'),
        o_value => w_lfsr_out_slv
    );
end architecture rtl;