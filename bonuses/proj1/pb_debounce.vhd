-- pb_debounce: Synchronize and debounce pushbuttons
-- Inspired By: https://projectf.io/posts/fpga-graphics/
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pb_debounce is
    generic (
        g_pol : std_logic := '0'; -- PB polarity: 0 for active low, 1 for active high
        g_clk_freq_in : integer := 25175000; -- 25.175 MHz;
        g_delay_msec : integer := 10
    );
    port (
        i_clk : in std_logic;
        i_pb : in std_logic;

        o_pb_state : out std_logic; -- "clean" output state of PB, active high
        o_pb_down : out std_logic; -- One clock cycle pulse for "down" event
        o_pb_up : out std_logic -- One clock cycle pulse for "up" event
        
    );
end entity pb_debounce;

architecture rtl of pb_debounce is
    -- Constants
    constant c_clks_per_msec : integer := (g_clk_freq_in)/(1e3);

    -- Signals
    signal pb_sync_0, pb_sync_1, pb_sync_2, pb_inv : std_logic;
    signal cnt_clks : integer range 0 to c_clks_per_msec-1 := 0;
    signal cnt_msec : integer range 0 to g_delay_msec-1 := 0;
    signal pb_state, pb_down, pb_up : std_logic := '0';
    signal idle, clks_max, msec_max : std_logic;

begin
    -- Synchronizer
    pb_sync_0 <= i_pb when rising_edge(i_clk);
    pb_sync_1 <= pb_sync_0 when rising_edge(i_clk);
    pb_sync_2 <= pb_sync_1 when rising_edge(i_clk);
    
    pb_inv <= pb_sync_2 when g_pol = '1' else not pb_sync_2; -- Only use pb_inv in below clocked logic

    -- Status signals
    idle <= '1' when (pb_state = pb_inv) else '0'; -- Has the PB input has changed from our current output?
    clks_max <= '1' when (cnt_clks = c_clks_per_msec-1) else '0'; -- Clock counter has reached max
    msec_max <= '1' when (cnt_msec = g_delay_msec-1) else '0'; -- msec delay counter has reached max
    pb_down <= '1' when (idle = '0' and msec_max = '1' and pb_state = '0') else '0'; -- State is about to switch high
    pb_up <= '1' when (idle = '0' and msec_max = '1' and pb_state = '1') else '0'; -- State is about to switch low

    -- Update counters
    cnt: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if idle = '1' then
                cnt_clks <= 0;
                cnt_msec <= 0;
            else
                cnt_clks <= cnt_clks+1;

                -- A msec has passed
                if clks_max = '1' then
                    cnt_clks <= 0;
                    cnt_msec <= cnt_msec+1;
                end if;

                -- Total duration has elapsed
                if msec_max = '1' then
                    pb_state <= not pb_state; -- Invert output, should now match the input
                end if;
            end if;
        end if;
    end process cnt;

    -- Outputs
    o_pb_state <= pb_state;
    o_pb_down <= pb_down;
    o_pb_up <= pb_up;
    
end architecture rtl;