-- sprite_draw: colorful hardware sprite
-- Inspired By: https://projectf.io/posts/fpga-graphics/
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

-- Common constants
use work.defender_common.all;

entity sprite_draw is port(

    i_clock : in std_logic;     -- clock
    i_reset : in std_logic;     -- synchronous reset
    i_pos : in t_point_2d;      -- top left of sprite
    i_scan_pos : in t_point_2d; -- current VGA scan position
    i_draw_en : in std_logic;

    i_spr_idx : in integer range 0 to c_spr_data_slots-1;   -- Which sprite to draw?
    i_width : in integer range 0 to c_spr_data_width_pix;   -- How big is this sprite in pixels?
    i_height : in integer range 0 to c_spr_data_height_pix;
    i_scale_x : in integer range 0 to c_spr_max_scale_x;    -- How to scale the sprite data? No interpolation is used.
    i_scale_y : in integer range 0 to c_spr_max_scale_y;

    o_draw_elem : out t_spr_draw_elem := init_t_spr_draw_elem; -- Drawing signals

    -- Sprite ROM bus arbitration
    o_arb_port : out t_arb_port_in := init_t_arb_port_in;      -- Input to bus arbiter
    i_arb_port : in t_arb_port_out                             -- Output from bus arbiter

);
end entity sprite_draw;

architecture rtl of sprite_draw is

    -- Constants
    

    -- Types
    type t_state is (ST_IDLE, ST_START, ST_AWAIT_DMA, ST_READ_MEM, ST_AWAIT_POS, ST_DRAW, ST_NEXT_LINE, ST_DONE);

    -- Signals
    signal r_state : t_state := ST_IDLE;
    signal r_next_state : t_state;
    signal r_last_pixel : boolean;
    signal r_last_line : boolean;
    signal r_load_line : boolean;
    signal r_spr_line : std_logic_vector(c_spr_data_width_bits-1 downto 0); -- Local copy of sprite line
    signal r_spr_pixel_slv : std_logic_vector(c_spr_data_bits_per_pix-1 downto 0); -- Current pixel color data (palettized)
    signal r_spr_pixel_int : integer range 0 to c_palette_size-1;
    signal r_spr_base_addr : integer range 0 to c_spr_data_depth-1;
    signal r_spr_addr : integer range 0 to c_spr_data_depth-1;
    signal r_spr_addr_slv : std_logic_vector(c_spr_addr_bits-1 downto 0);

    -- CLUT
    signal r_clut_in_int : integer range 0 to c_palette_size-1;
    signal r_clut_in_slv : std_logic_vector(c_spr_data_bits_per_pix-1 downto 0);
    signal r_clut_out_slv : std_logic_vector(c_vga_color_bits-1 downto 0);
    signal r_clut_out_int : integer range 0 to c_max_color;

    -- Scale counters
    signal r_scale_cnt_x : integer range 0 to c_spr_max_scale_x-1 := 0;
    signal r_scale_cnt_y : integer range 0 to c_spr_max_scale_y-1 := 0;

    -- Position within sprite
    signal r_spr_pos_x : integer range 0 to c_spr_data_width_pix-1 := 0;
    signal r_spr_pos_y : integer range 0 to c_spr_data_height_pix-1 := 0;

    
begin

    -- Calculate sprite ROM address
    r_spr_base_addr <= i_spr_idx*c_spr_data_height_pix;
    r_spr_addr <= r_spr_base_addr + r_spr_pos_y;
    r_spr_addr_slv <= std_logic_vector(to_unsigned(r_spr_addr, r_spr_addr_slv'length));

    -- Outputs to bus arbiter
    o_arb_port.dataRequest <= (r_state = ST_AWAIT_DMA); -- Keep request high only while we are in the await DMA state
    o_arb_port.addr <= r_spr_addr_slv;
    o_arb_port.writeRequest <= false; -- We are never writing, just reading
    o_arb_port.writeData <= (others => '0');

    -- State machine
    process(i_clock)
    begin
        if rising_edge(i_clock) then
            r_state <= r_next_state;

            case r_state is
                when ST_START =>
                    r_spr_pos_y <= 0;
                    r_scale_cnt_y <= 0;

                when ST_READ_MEM => 
                    r_spr_line <= i_arb_port.data;
                
                when ST_AWAIT_POS => 
                    r_spr_pos_x <= 0;
                    r_scale_cnt_x <= 0;

                when ST_DRAW => 
                    if (i_scale_x <= 1 or r_scale_cnt_x = i_scale_x-1) then
                        r_spr_pos_x <= r_spr_pos_x + 1;
                        r_scale_cnt_x <= 0;
                    else
                        r_scale_cnt_x <= r_scale_cnt_x + 1;
                    end if;

                when ST_NEXT_LINE =>
                    if (i_scale_y <= 1 or r_scale_cnt_y = i_scale_y-1) then
                        r_spr_pos_y <= r_spr_pos_y + 1;
                        r_scale_cnt_y <= 0;
                    else
                        r_scale_cnt_y <= r_scale_cnt_y + 1;
                    end if;

                when others => 

            end case;

            if i_reset = '1' then
                r_state <= ST_IDLE;
                r_spr_pos_x <= 0;
                r_spr_pos_y <= 0;
                r_scale_cnt_x <= 0;
                r_scale_cnt_y <= 0;
                r_spr_line <= (others => '0');
            end if;

        end if;
    end process;

    -- Status signals
    r_last_pixel <= (r_spr_pos_x >= i_width-1  and r_scale_cnt_x >= i_scale_x-1);
    r_last_line <= (r_spr_pos_y >= i_height-1 and r_scale_cnt_y >= i_scale_y-1);
    r_load_line <= (r_scale_cnt_y >= i_scale_y-1); -- Is it time to load another line?
    
    -- Next state logic
    process(r_state, i_scan_pos, i_pos, r_last_pixel, r_last_line, r_load_line)
    begin
        case r_state is
            when ST_IDLE =>
                -- Get started fetching first line of data, one scanline early, since other sprites are also using the bus.
                -- Don't fetch any data if we're not enabled
                if (i_scan_pos.x = i_pos.x-1 and i_scan_pos.y = i_pos.y-1 and i_draw_en = '1') then
                    r_next_state <= ST_START;
                else
                    r_next_state <= ST_IDLE;
                end if;

            when ST_START => r_next_state <= ST_AWAIT_DMA;

            when ST_AWAIT_DMA =>
                -- Bus arbiter has brought this high, so the data is ready in the .data field
                -- It will be fetched one clock cycle later, in the next state.
                if (i_arb_port.dataWaiting) then
                    r_next_state <= ST_READ_MEM;
                else
                    r_next_state <= ST_AWAIT_DMA;
                end if;

            when ST_READ_MEM => r_next_state <= ST_AWAIT_POS;

            when ST_AWAIT_POS =>
                if (i_scan_pos.x = i_pos.x-1) then -- We are ready to draw in next clock cycle
                    r_next_state <= ST_DRAW;
                else
                    r_next_state <= ST_AWAIT_POS;
                end if;

            when ST_DRAW =>
                if (not r_last_pixel) then
                    r_next_state <= ST_DRAW;
                elsif (not r_last_line) then
                    r_next_state <= ST_NEXT_LINE;
                else
                    r_next_state <= ST_DONE;
                end if;

            when ST_NEXT_LINE =>
                -- Time to load a new line?
                if (r_load_line) then
                    r_next_state <= ST_AWAIT_DMA;
                -- Or... We are copying same line to scale Y
                else
                    r_next_state <= ST_AWAIT_POS;
                end if;


            when ST_DONE => r_next_state <= ST_IDLE;
            when others => r_next_state <= ST_IDLE;
        
        end case;
    end process;

    -- Pick out current pixel color data
    process(i_width, r_spr_pos_x, r_spr_line)
    begin
        -- Pick out 4 bits corresponding to current x value
        -- x position increases going MSB to LSB
        r_spr_pixel_slv <= r_spr_line((c_spr_data_width_pix-r_spr_pos_x)*4 - 1 downto (c_spr_data_width_pix-r_spr_pos_x-1)*4);
        r_spr_pixel_int <= to_integer(unsigned(r_spr_pixel_slv));
        r_clut_in_slv <= r_spr_pixel_slv;
    end process;


    -- Draw outputs
    process(r_state, r_spr_pixel_int, i_draw_en, r_clut_out_slv)
    begin
        if (r_state = ST_DRAW and r_spr_pixel_int /= c_transp_color_pal) then -- Are we drawing a non-transparent color?
            o_draw_elem.draw <= true;
        else
            o_draw_elem.draw <= false;
        end if;


        r_clut_out_int <= to_integer(unsigned(r_clut_out_slv));
        o_draw_elem.color <= r_clut_out_int;

        -- Override all drawing
        if (i_draw_en = '0') then
            o_draw_elem.draw <= false;
            o_draw_elem.color <= 0;
        end if;
    end process;

    -- Instantiation
    clut: entity work.async_rom_init generic map(
        numElements => c_palette_size,
        dataWidth => c_vga_color_bits,
        initFile => "../res/palette.mif"
    )
    port map(
        addrA => r_clut_in_slv,
        dataOutA => r_clut_out_slv
    );

end architecture rtl;