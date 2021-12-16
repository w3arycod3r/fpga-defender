-- image_gen: Render frames "just-in-time" and handle game logic
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE IEEE.NUMERIC_STD.ALL;
library work;

-- For vgaText library
use work.commonPak.all;
-- Common constants
use work.defender_common.all;

ENTITY image_gen IS
    port(
        -- Control and pixel clock
        pixel_clk:  IN  STD_LOGIC;

        -- VGA controller inputs
        disp_en  :  IN  STD_LOGIC;  --display enable ('1' = display time, '0' = blanking time)
        i_scan_pos : in t_point_2d;
        frame : in std_logic;
        line : in std_logic;

        -- Color outputs to VGA
        red      :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --red magnitude output to DAC
        green    :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --green magnitude output to DAC
        blue     :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --blue magnitude output to DAC

        -- HMI Inputs
        accel_scale_x, accel_scale_y : integer;
        KEY_state, KEY_down, KEY_up  : IN STD_LOGIC_VECTOR(1 DOWNTO 0); -- Synch to pixel_clk domain
        SW_state                           : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        -- HMI Outputs
        o_buzzPin : out std_logic;
        HEX5, HEX4, HEX3, HEX2, HEX1, HEX0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        LEDR                               : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)

    );
END image_gen;

ARCHITECTURE behavior OF image_gen IS
    -- Components

    -- Constants
    
    -- Types
    type t_state is (ST_START, ST_NEW_GAME, ST_PLAY, ST_PAUSE, ST_GAME_OVER);

    -- Signals
    signal r_logic_update : std_logic := '0'; -- Pulse
    signal r_key_d : std_logic_vector(1 downto 0);
    signal r_key_press : std_logic_vector(1 downto 0); -- Pulse, keypress event, on logic_update

    -- Draw outputs from game elements
    signal w_playShipDraw : std_logic;
    signal w_playShipColor: integer range 0 to 4095;

    signal w_hudDraw : std_logic;
    signal w_hudColor: integer range 0 to 4095;

    signal w_overlaysDraw : std_logic;
    signal w_overlaysColor: integer range 0 to 4095;

    signal w_enemiesDraw : std_logic;
    signal w_enemiesColor: integer range 0 to 4095;

    signal w_terrainDraw : std_logic;
    signal w_terrainColor: integer range 0 to 4095;

    signal w_spriteDraw : std_logic;
    signal w_spriteColor: integer range 0 to c_max_color;

    signal r_num_lives : integer range 0 to c_max_lives := c_initial_lives;
    signal r_score : integer range 0 to c_max_score := 0;
    signal w_score_bcd : std_logic_vector(23 downto 0);

    signal r_game_state : t_state := ST_START;
    signal r_next_state : t_state;
    signal r_game_paused : std_logic := '0';
    signal r_game_wait_start : std_logic := '0';
    signal r_game_over : std_logic := '0';
    signal r_game_over_pulse : std_logic := '0';
    signal r_game_active : std_logic := '0';
    signal r_extra_life_award : std_logic := '0';

    signal r_obj_update : std_logic := '0';
    signal r_obj_reset : std_logic := '0';

    signal w_ship_pos_x : integer;
    signal w_ship_pos_y : integer;
    signal w_ship_collide : std_logic;
    signal w_cannon_collide : std_logic;
    signal w_cannon_fire : std_logic;
    signal w_score_inc : integer;

    signal r_terrain_anim_en : std_logic; -- Should the starfields be animated?
    
    -- vgaText
    signal inArbiterPortArray: type_inArbiterPortArray(0 to c_num_text_elems-1) := (others => init_type_inArbiterPort);
    signal outArbiterPortArray: type_outArbiterPortArray(0 to c_num_text_elems-1) := (others => init_type_outArbiterPort);
    signal drawElementArray: type_drawElementArray(0 to c_num_text_elems-1) := (others => init_type_drawElement);

    -- Sprite ROM arb and draw arrays
    signal spr_port_in_array: t_arb_port_in_array(0 to c_spr_num_elems-1) := (others => init_t_arb_port_in);    -- In to arbiter, out from sprites
    signal spr_port_out_array: t_arb_port_out_array(0 to c_spr_num_elems-1) := (others => init_t_arb_port_out); -- Out from arbiter, in to sprites
    signal spr_draw_array: t_spr_draw_elem_array(0 to c_spr_num_elems-1) := (others => init_t_spr_draw_elem);   -- Draw outputs from sprites

    signal r_spr_sel : integer range 0 to c_spr_data_slots-1 := 0;

    -- Sound effects
    signal r_effectSel : std_logic_vector(2 downto 0);
    signal r_effectTrig : std_logic := '0';

    signal w_effectPlaying : std_logic;
    signal w_currEffect : std_logic_vector(2 downto 0);

BEGIN

    -- KEY falling edge
    r_key_d <= KEY_state when rising_edge(pixel_clk) and r_logic_update='1'; -- DFF, value of keys at last logical update
    r_key_press <= not r_key_d and KEY_state;   -- One-cycle strobe, for next logical update

    -- Debug sprites
    process(pixel_clk)
    begin   
        if rising_edge(pixel_clk) and r_logic_update = '1' then

            -- Debug
            if SW_state(9) = '1' and r_key_press(0) = '1' then
                if r_spr_sel < c_spr_data_slots_used-1 then
                    r_spr_sel <= r_spr_sel+1;
                else
                    r_spr_sel <= 0;
                end if;

            end if;
            
        end if;
    end process;

    -- Drive LEDs
    process(r_num_lives)
    begin
        LEDR <= (others => '0');
        if r_num_lives >= 1 then
            LEDR(9) <= '1';
        end if;
        if r_num_lives >= 2 then
            LEDR(8) <= '1';
        end if;
        if r_num_lives >= 3 then
            LEDR(7) <= '1';
        end if;
        if r_num_lives >= 4 then
            LEDR(6) <= '1';
        end if;
        if r_num_lives >= 5 then
            LEDR(5) <= '1';
        end if;
    end process;

    -- Handle lives
    process(pixel_clk)
        variable last_score : integer range 0 to c_max_score := 0;
        variable last_score_mult : integer range 0 to c_max_score/c_extra_life_score_mult := 0;
        variable curr_score_mult : integer range 0 to c_max_score/c_extra_life_score_mult := 0;
    begin   
        if rising_edge(pixel_clk) and r_logic_update = '1' then
            last_score_mult := last_score / c_extra_life_score_mult;
            curr_score_mult := r_score / c_extra_life_score_mult;
            r_extra_life_award <= '0';

            if r_obj_reset = '1' then
                r_num_lives <= c_initial_lives;
            elsif w_ship_collide = '1' then
                r_num_lives <= r_num_lives-1;

            -- Award extra lives at certain score multiples. Did we just pass a multiple?
            elsif (curr_score_mult = last_score_mult+1 and r_num_lives < c_max_lives) then
                r_num_lives <= r_num_lives+1;
                r_extra_life_award <= '1';

            -- Debug
            elsif SW_state(9) = '1' and r_key_press(0) = '1' and r_num_lives < c_max_lives then
                r_num_lives <= r_num_lives+1;
            end if;
            
            last_score := r_score;
        end if;
    end process;

    -- Handle score
    process(pixel_clk)
        variable new_score : integer range 0 to 2*c_max_score := 0;
    begin
        if rising_edge(pixel_clk) and r_logic_update = '1' then
            if r_obj_reset = '1' then
                new_score := 0;
            elsif w_cannon_collide = '1' then
                new_score := r_score+w_score_inc;
            -- Debug
            elsif SW_state(9) = '1' and r_key_press(1) = '1' then
                new_score := r_score+100;
            elsif SW_state(7) = '1' and r_key_press(1) = '1' then
                new_score := c_max_score-100;
            end if;

            -- Clip the score count at the maximum
            if (new_score >= c_max_score) then
                new_score := c_max_score;
            end if;

            r_score <= new_score;
            
        end if;
    end process;

    -- Drive sound block
    process(pixel_clk)
        variable effectSel : std_logic_vector(2 downto 0);
        variable effectTrig : std_logic := '0';
    begin
        if rising_edge(pixel_clk) then
            effectTrig := '0'; -- Bring trigger low on next clock cycle

            -- Play a sound once per frame
            if r_logic_update = '1' then
                
                -- Play player fire sound
                if (w_cannon_fire = '1') then
                    effectSel := c_sound_player_fire;
                    effectTrig := '1';
                end if;
                -- Play enemy destroy sound
                if w_cannon_collide = '1' then
                    effectSel := c_sound_enemy_destroy;
                    effectTrig := '1';
                end if;
                -- Play "life lost" sound
                if w_ship_collide = '1' and r_num_lives > 1 then
                    effectSel := c_sound_player_hit;
                    effectTrig := '1';
                end if;
                -- Play extra life sound
                if r_extra_life_award = '1' then
                    effectSel := c_sound_game_start;
                    effectTrig := '1';
                end if;
                -- Play start sound
                if r_obj_reset = '1' then
                    effectSel := c_sound_game_start;
                    effectTrig := '1'; -- Bring trigger high
                end if;
                -- Play game over sound
                if r_game_over_pulse = '1' then
                    effectSel := c_sound_game_over;
                    effectTrig := '1';
                end if;

                -- Handle sound collisions
                if w_effectPlaying = '1' and effectTrig = '1' then

                    -- Which sound are we trying to play?
                    case effectSel is

                        -- Can override all
                        when c_sound_game_start =>
                            
                        -- Can only override another player fire
                        when c_sound_player_fire => 
                            if (w_currEffect /= c_sound_player_fire) then
                                effectTrig := '0';
                            end if;

                        -- Can't override game start, game over, or player hit
                        when c_sound_enemy_destroy => 
                            if (w_currEffect = c_sound_game_start or w_currEffect = c_sound_game_over or w_currEffect = c_sound_player_hit) then
                                effectTrig := '0';
                            end if;
                            
                        -- Can't override game start, game over
                        when c_sound_player_hit => 
                            if (w_currEffect = c_sound_game_start or w_currEffect = c_sound_game_over) then
                                effectTrig := '0';
                            end if;
                            
                        -- Can override all
                        when c_sound_game_over => 
                            
                        when others =>
        
                    end case;
                end if;
            end if;

            -- Debug switch sound override
            if (SW_state(8) = '1') then
                effectTrig := '0';
            end if;

            -- Variables to signals
            r_effectSel <= effectSel;
            r_effectTrig <= effectTrig;
        end if;
    end process;

    -- Main game FSM
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) and r_logic_update = '1' then
            r_game_state <= r_next_state;

            case r_game_state is

                when ST_NEW_GAME => 

                when ST_GAME_OVER => 
                    
                when others =>
                    
            end case;
        end if;
    end process;

    -- FSM status signals

    -- FSM next state logic
    process(r_game_state, r_key_press, r_num_lives, SW_state)
    begin
        case r_game_state is
            when ST_START =>
                if (r_key_press(1) = '1') then -- Start button pressed
                    r_next_state <= ST_NEW_GAME;
                else
                    r_next_state <= ST_START;
                end if;

            when ST_NEW_GAME => r_next_state <= ST_PLAY;

            when ST_PLAY =>

                if (r_key_press(1) = '1') then -- Pause button pressed
                    r_next_state <= ST_PAUSE;
                elsif (r_num_lives = 0) then   -- Game over condition
                    r_next_state <= ST_GAME_OVER;
                else
                    r_next_state <= ST_PLAY;
                end if;

            when ST_PAUSE =>

                if (r_key_press(1) = '1') then
                    r_next_state <= ST_PLAY;  -- Pause button pressed
                else
                    r_next_state <= ST_PAUSE;
                end if;

            when ST_GAME_OVER =>

                if (r_key_press(1) = '1') then
                    r_next_state <= ST_START;    -- Go back to start screen
                else
                    r_next_state <= ST_GAME_OVER;
                end if;

            when others => r_next_state <= ST_START;
        
        end case;
    end process;


    -- FSM outputs
    process(r_game_state, r_next_state)
    begin
        if r_next_state = ST_NEW_GAME then
            r_obj_reset <= '1'; -- Prepare all objects to reset upon transition to ST_NEW_GAME
        else
            r_obj_reset <= '0';
        end if;

        if r_next_state = ST_GAME_OVER and r_game_state /= ST_GAME_OVER then
            r_game_over_pulse <= '1';
        else
            r_game_over_pulse <= '0';
        end if;

        if r_game_state = ST_PAUSE then
            r_game_paused <= '1';
        else
            r_game_paused <= '0';
        end if;

        if r_game_state = ST_START then
            r_game_wait_start <= '1';
        else
            r_game_wait_start <= '0';
        end if;

        if r_game_state = ST_GAME_OVER then
            r_game_over <= '1';
        else
            r_game_over <= '0';
        end if;

        if (r_game_state /= ST_START) then
            r_game_active <= '1';
        else
            r_game_active <= '0';
        end if;
    end process;

    -- Combi-Logic, draw each pixel for current frame
    PROCESS(disp_en, i_scan_pos)

        -- Variables
        variable pix_color_tmp  : integer range 0 to 4095 := 0;
        variable pix_color_slv  : std_logic_vector(11 downto 0) := (others => '0');

    BEGIN

        -- Display time
        IF(disp_en = '1') THEN

            -- Background
            pix_color_tmp := c_bg_color;

            -- Render each object
            if (w_terrainDraw = '1') then
                pix_color_tmp := w_terrainColor;
            end if;
            if (w_hudDraw = '1') then
                pix_color_tmp := w_hudColor;
            end if;
            if (w_enemiesDraw = '1') then
                pix_color_tmp := w_enemiesColor;
            end if;
            if (w_playShipDraw = '1') then
                pix_color_tmp := w_playShipColor;
            end if;
            if (r_game_paused = '1' or r_game_over = '1') then
                pix_color_tmp := darken(pix_color_tmp, 5);
            end if;
            if (w_overlaysDraw = '1') then
                pix_color_tmp := w_overlaysColor;
            end if;

            
        -- Blanking time
        ELSE                           
            pix_color_tmp := 0;
        END IF;

        -- Assign from variables into real signals
        pix_color_slv := STD_LOGIC_VECTOR(TO_UNSIGNED(pix_color_tmp, pix_color_slv'LENGTH));
        red <= pix_color_slv(11 downto 8);
        green <= pix_color_slv(7 downto 4);
        blue <= pix_color_slv(3 downto 0);
        
    END PROCESS;

    -- Update game state at end of each frame
    process(pixel_clk)

    begin
        if (rising_edge(pixel_clk)) then

            -- Just finished drawing frame, command a logical update
            if (frame = '1') then
                r_logic_update <= '1';
            else
                r_logic_update <= '0';
            end if;

        end if;
    end process;

    -- Object update signals
    r_obj_update <= r_logic_update and not r_game_paused and not r_game_over and not r_game_wait_start;
    r_terrain_anim_en <= not r_game_paused and not r_game_over;

    -- Game objects
    player: entity work.player_ship port map(
        i_clock => pixel_clk,
        i_update_pulse => r_obj_update,
        i_reset_pulse => r_obj_reset,
        accel_scale_x => accel_scale_x, accel_scale_y => accel_scale_y,
        i_key_press => r_key_press,
        i_scan_pos => i_scan_pos,
        i_draw_en => r_game_active,
        o_pos_x => w_ship_pos_x,
        o_pos_y => w_ship_pos_y,
        o_color => w_playShipColor,
        o_draw => w_playShipDraw,
        spr_port_in_array => spr_port_in_array,
        spr_port_out_array => spr_port_out_array,
        spr_draw_array => spr_draw_array
    );

    enemies: entity work.enemies port map(
        i_clock => pixel_clk,
        i_update_pulse => r_obj_update,
        i_reset_pulse => r_obj_reset,
        -- Allow the main LFSR to be freely clocked while on start screen. This will ensure the game starts at a random point in the sequence each time.
        i_lfsr_free_run => r_game_wait_start,
        i_scan_pos => i_scan_pos,
        i_draw_en => r_game_active,
        i_key_press => r_key_press,
        i_score => r_score,
        i_ship_pos_x => w_ship_pos_x,
        i_ship_pos_y => w_ship_pos_y,

        o_ship_collide => w_ship_collide,
        o_cannon_collide => w_cannon_collide,
        o_cannon_fire => w_cannon_fire,
        o_score_inc => w_score_inc,
        o_color => w_enemiesColor,
        o_draw => w_enemiesDraw,
        spr_port_in_array => spr_port_in_array,
        spr_port_out_array => spr_port_out_array,
        spr_draw_array => spr_draw_array
    );

    hud: entity work.hud port map(
        i_clock => pixel_clk,
        i_update_pulse => r_logic_update,
        i_scan_pos => i_scan_pos,
        i_draw_en => r_game_active,
        i_num_lives => r_num_lives,
        i_score => r_score,
        o_score_bcd => w_score_bcd,
        o_color => w_hudColor,
        o_draw => w_hudDraw,
        inArbiterPortArray => inArbiterPortArray,
        outArbiterPortArray => outArbiterPortArray,
        drawElementArray => drawElementArray,
        spr_port_in_array => spr_port_in_array,
        spr_port_out_array => spr_port_out_array,
        spr_draw_array => spr_draw_array
    );

    -- Terrain
    terrain: entity work.terrain port map(
        i_clock => pixel_clk,
        i_anim_en => r_terrain_anim_en,
        i_scan_pos => i_scan_pos,
        i_draw_en => '1',
        o_color => w_terrainColor,
        o_draw => w_terrainDraw
    );

    overlays: entity work.overlays port map(
        i_clock => pixel_clk,
        i_update_pulse => r_logic_update,
        i_scan_pos => i_scan_pos,
        i_draw_en => '1',
        i_line => line,
        i_score => r_score,
        i_start_screen => r_game_wait_start,
        i_pause_screen => r_game_paused,
        i_game_over_screen => r_game_over,
        o_color => w_overlaysColor,
        o_draw => w_overlaysDraw,
        inArbiterPortArray => inArbiterPortArray,
        outArbiterPortArray => outArbiterPortArray,
        drawElementArray => drawElementArray,
        spr_port_in_array => spr_port_in_array,
        spr_port_out_array => spr_port_out_array,
        spr_draw_array => spr_draw_array
    
    );

    -- vgaText
    fontLibraryArbiter: entity work.blockRamArbiter
	generic map(
		numPorts => c_num_text_elems
	)
	port map(
		clk => pixel_clk,
		reset => '0',
		inPortArray => inArbiterPortArray,
		outPortArray => outArbiterPortArray
	);

    -- Sprites
    spr_rom_arb: entity work.spr_rom_arb
	generic map(
		numPorts => c_spr_num_elems
	)
	port map(
		clk => pixel_clk,
		reset => '0',
		inPortArray => spr_port_in_array,
		outPortArray => spr_port_out_array
	);

    -- Sound effects
    soundfx: entity work.effect_gen port map (
        i_clock => pixel_clk,
        i_reset_n => '1',
        i_effectSel => r_effectSel,
        i_effectTrig => r_effectTrig,
        o_buzzPin => o_buzzPin,
        o_playing => w_effectPlaying,
        o_currEffect => w_currEffect
    );

    -- 7Seg Decoders
    hex5_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(23 downto 20), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX5 );
    hex4_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(19 downto 16), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX4 );
    hex3_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(15 downto 12), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX3 );
    hex2_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(11 downto 8 ), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX2 );
    hex1_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(7  downto 4 ), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX1 );
    hex0_dec : entity work.bin2seg7  PORT MAP ( inData => w_score_bcd(3  downto 0 ), blanking => '0', dispHex => '1', dispPoint => '0', dispDash => '0', outSegs => HEX0 );

END behavior;
