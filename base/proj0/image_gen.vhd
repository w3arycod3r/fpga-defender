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
    generic (

        -- RGB, 4 bits each
        g_bg_color : integer := 16#FFF#;
        g_text_color : integer := 16#000#

    );
    port(
        -- Control and pixel clock
        pixel_clk:  IN  STD_LOGIC;

        -- VGA controller inputs
        disp_en  :  IN  STD_LOGIC;  --display enable ('1' = display time, '0' = blanking time)
        row : in integer range 0 to c_screen_height-1;
        column : in integer range 0 to c_screen_width-1;

        -- Color outputs to VGA
        red      :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --red magnitude output to DAC
        green    :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --green magnitude output to DAC
        blue     :  OUT STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  --blue magnitude output to DAC

        -- HMI Inputs
        accel_scale_x, accel_scale_y : integer;
        KEY                          : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SW                           : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

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
    SIGNAL KEY_b       : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal r_disp_en_d : std_logic := '0';   -- Registered disp_en input
    signal r_disp_en_fe : std_logic;         -- Falling edge of disp_en input
    signal r_logic_update : std_logic := '0'; -- Pulse
    signal r_key_d : std_logic_vector(1 downto 0);
    signal r_key_press : std_logic_vector(1 downto 0); -- Pulse, keypress event

    signal w_playShipDraw : std_logic;
    signal w_playShipColor: integer range 0 to 4095;

    signal w_hudDraw : std_logic;
    signal w_hudColor: integer range 0 to 4095;

    signal w_overlaysDraw : std_logic;
    signal w_overlaysColor: integer range 0 to 4095;

    signal w_enemiesDraw : std_logic;
    signal w_enemiesColor: integer range 0 to 4095;

    signal r_num_lives : integer range 0 to c_max_lives := c_initial_lives;
    signal r_score : integer range 0 to c_max_score := 0;
    signal w_score_bcd : std_logic_vector(23 downto 0);

    signal r_game_state : t_state := ST_START;
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
    
    -- vgaText
    signal inArbiterPortArray: type_inArbiterPortArray(0 to c_num_text_elems-1) := (others => init_type_inArbiterPort);
    signal outArbiterPortArray: type_outArbiterPortArray(0 to c_num_text_elems-1) := (others => init_type_outArbiterPort);
    signal drawElementArray: type_drawElementArray(0 to c_num_text_elems-1) := (others => init_type_drawElement);

    -- Sound effects
    signal r_effectSel : std_logic_vector(2 downto 0);
    signal r_effectTrig : std_logic := '0';

    signal w_effectPlaying : std_logic;
    signal w_currEffect : std_logic_vector(2 downto 0);

BEGIN

    -- Concurrent assignments
    KEY_b <= NOT KEY;

    -- disp_en falling edge
    r_disp_en_d <= disp_en when rising_edge(pixel_clk); -- DFF
    r_disp_en_fe <= r_disp_en_d and not disp_en;   -- One-cycle strobe

    -- KEY falling edge
    r_key_d <= KEY when rising_edge(pixel_clk) and r_logic_update='1'; -- DFF, value of keys at last logical update
    r_key_press <= r_key_d and not KEY;   -- One-cycle strobe, for next logical update

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
            elsif SW(9) = '1' and r_key_press(0) = '1' and r_num_lives < c_max_lives then
                r_num_lives <= r_num_lives+1;
            end if;
            
            last_score := r_score;
        end if;
    end process;

    -- Handle score
    process(pixel_clk)
    begin   
        if rising_edge(pixel_clk) and r_logic_update = '1' then
            if r_obj_reset = '1' then
                r_score <= 0;
            elsif w_cannon_collide = '1' then
                r_score <= r_score+w_score_inc;

            -- Debug
            elsif SW(9) = '1' and r_key_press(1) = '1' and r_score < c_max_score then
                r_score <= r_score+100;
            end if;
            
        end if;
    end process;

    -- Drive sound block
    process(pixel_clk)
        variable effectSel : std_logic_vector(2 downto 0);
        variable effectTrig : std_logic := '0';
    begin   
        if rising_edge(pixel_clk) and r_logic_update = '1' then
            if r_obj_reset = '1' then
                -- Play start sound
                effectSel := c_sound_game_start;
                effectTrig := '1';
            elsif (w_cannon_fire = '1') then
                -- Play player fire sound
                effectSel := c_sound_player_fire;
                effectTrig := '1';
            elsif w_cannon_collide = '1' then
                -- Play enemy destroy sound
                effectSel := c_sound_enemy_destroy;
                effectTrig := '1';
            elsif r_extra_life_award = '1' then
                -- Play extra life sound
                effectSel := c_sound_game_start;
                effectTrig := '1';
            elsif w_ship_collide = '1' and r_num_lives > 1 then
                -- Play "life lost" sound
                effectSel := c_sound_player_hit;
                effectTrig := '1';
            elsif r_game_over_pulse = '1' then
                -- Play game over sound
                effectSel := c_sound_game_over;
                effectTrig := '1';
            else
                effectTrig := '0';
			end if;

            -- Override
            -- Cannon fire sound will not override "special" sounds
            if (effectSel = c_sound_player_fire and w_effectPlaying = '1' and w_currEffect /= c_sound_player_fire) then
                effectTrig := '0';
            end if;

            -- Do not interrupt "game start" sound
            if (w_effectPlaying = '1' and w_currEffect = c_sound_game_start) then
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

            case r_game_state is
                when ST_START =>
                    if r_key_press(1) = '1' then
                        r_game_state <= ST_NEW_GAME;
                    else
                        r_game_state <= ST_START;
                    end if;

                -- Prepare for new game
                when ST_NEW_GAME => 
                    r_game_state <= ST_PLAY;
                when ST_PLAY => 
                    if r_key_press(1) = '1' then
                        r_game_state <= ST_PAUSE;
                    elsif (r_num_lives = 0) then
                        r_game_state <= ST_GAME_OVER;
                        r_game_over_pulse <= '1';
                    else
                        r_game_state <= ST_PLAY;
                    end if;
                when ST_PAUSE => 
                    if r_key_press(1) = '1' then
                        r_game_state <= ST_PLAY;
                    else
                        r_game_state <= ST_PAUSE;
                    end if;
                when ST_GAME_OVER => 
                    r_game_over_pulse <= '0';
                    if r_key_press(1) = '1' then
                        r_game_state <= ST_NEW_GAME;
                    else
                        r_game_state <= ST_GAME_OVER;
                    end if;
                when others =>
                    r_game_state <= ST_START;
            
            end case;
        end if;
    end process;

    -- FSM outputs
    process(r_game_state)
    begin
        if r_game_state = ST_NEW_GAME then
            r_obj_reset <= '1'; -- Prepare all objects to reset upon transition to ST_PLAY
        else
            r_obj_reset <= '0';
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
    PROCESS(disp_en, row, column)

        -- Variables
        variable pix_color_tmp  : integer range 0 to 4095 := 0;
        variable pix_color_slv  : std_logic_vector(11 downto 0) := (others => '0');

    BEGIN

        -- Display time
        IF(disp_en = '1') THEN

            -- Background
            pix_color_tmp := g_bg_color;

            -- Render each object
            if (w_enemiesDraw = '1') then
                pix_color_tmp := w_enemiesColor;
            end if;
            if (w_playShipDraw = '1') then
                pix_color_tmp := w_playShipColor;
            end if;
            if (w_hudDraw = '1') then
                pix_color_tmp := w_hudColor;
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
            if (r_disp_en_fe = '1' AND row >= c_screen_height-1 AND column >= c_screen_width-1) then
                r_logic_update <= '1';
            else
                r_logic_update <= '0';
            end if;

        end if;
    end process;

    -- Object update signals
    r_obj_update <= r_logic_update and not r_game_paused and not r_game_over and not r_game_wait_start;

    -- Game objects
    player: entity work.player_ship port map(
        i_clock => pixel_clk,
        i_update_pulse => r_obj_update,
        i_reset_pulse => r_obj_reset,

        accel_scale_x => accel_scale_x, accel_scale_y => accel_scale_y,
        i_key_press => r_key_press,

        i_row => row,
        i_column => column, 
        i_draw_en => r_game_active,

        o_pos_x => w_ship_pos_x,
        o_pos_y => w_ship_pos_y,

        o_color => w_playShipColor,
        o_draw => w_playShipDraw
    );

    enemies: entity work.enemies port map(
        i_clock => pixel_clk,
        i_update_pulse => r_obj_update,
        i_reset_pulse => r_obj_reset,
        i_row => row,
        i_column => column,
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
        o_draw => w_enemiesDraw
    );

    hud: entity work.hud port map(
        i_clock => pixel_clk,
        i_update_pulse => r_logic_update,
        i_row => row,
        i_column => column,
        i_draw_en => r_game_active,
        i_num_lives => r_num_lives,
        i_score => r_score,
        o_score_bcd => w_score_bcd,
        o_color => w_hudColor,
        o_draw => w_hudDraw,
        inArbiterPortArray => inArbiterPortArray,
        outArbiterPortArray => outArbiterPortArray,
        drawElementArray => drawElementArray
    );

    overlays: entity work.overlays port map(
        i_clock => pixel_clk,
        i_update_pulse => r_logic_update,
        i_row => row,
        i_column => column,
        i_draw_en => '1',
        i_score => r_score,
        i_start_screen => r_game_wait_start,
        i_pause_screen => r_game_paused,
        i_game_over_screen => r_game_over,
        o_color => w_overlaysColor,
        o_draw => w_overlaysDraw,
        inArbiterPortArray => inArbiterPortArray,
        outArbiterPortArray => outArbiterPortArray,
        drawElementArray => drawElementArray
    
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
