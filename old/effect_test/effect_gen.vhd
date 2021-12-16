-- Effect program (8 effect slots):
-- n = # of steps (128 max)
-- Step 0...n-1 : freq (hz) and duration (msec) (9 bits each)
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity effect_gen is
    port (
        -- 50 MHz clock expected
        i_clock : in std_logic;
        -- Active low reset
        i_reset_n : in std_logic;

        -- 0: Launch
        -- 1: Player fire
        -- 2: Enemy fire
        -- 3: Enemy destroy
        -- 4: Player destroy
        i_effectSel : in std_logic_vector(2 downto 0);

        -- Rising edge will trigger selected effect to play once, overriding any currently playing effect
        i_effectTrig : in std_logic;

        -- Square wave (50% DC) output for buzzer
        o_buzzPin : out std_logic
    );
end entity effect_gen;

architecture rtl of effect_gen is
    -- Constants
    CONSTANT	effect_size	:	integer := 128; -- Size of each effect "slot" in words
    CONSTANT    word_size   :   integer := 12; -- Word size of the ROM
    CONSTANT    clks_per_msec : integer := (50e6)/(1e3); -- 50 MHz clk input
    -- CONSTANT    clks_per_msec : integer := 1; -- 50 MHz clk input

    -- Components
    component effect_mem is
        port
        (
            address		: in std_logic_vector (9 downto 0);  -- registered
            clock		: in std_logic  := '1';
            q		    : out std_logic_vector (11 downto 0)  -- NOT registered
        );
    end component;

    component clock_div IS
        GENERIC (n : NATURAL := 8);
        PORT ( clock_in, reset  : IN  STD_LOGIC;
            divisor          : IN  STD_LOGIC_VECTOR(n DOWNTO 0);  -- divisor = 2*(max_cnt+1), size = n+1 bits
            clock_out        : OUT STD_LOGIC );
    END component;

    -- Types
    TYPE state_type IS (S_INIT, S_IDLE, S_START, S_LOAD_N_PRE, S_LOAD_N, S_LOAD_FREQ_PRE,
                        S_LOAD_FREQ, S_LOAD_DUR_PRE, S_LOAD_DUR, S_WAIT_DUR, S_NEXT_STEP, S_COMP);

    -- Signals
    signal r_state : state_type;
    signal r_romAddr : std_logic_vector(9 downto 0);
    signal r_buzzDivisor : std_logic_vector(27 downto 0);
    signal r_buzzDisable : std_logic;
    signal r_effectTrig_d : std_logic := '0';   -- Registered trigger input
    signal r_effectTrig_re : std_logic;         -- Rising edge of trigger input

    signal w_romData : std_logic_vector(word_size-1 downto 0);
    
begin
    -- Get rising edge of the trigger input
    r_effectTrig_d <= i_effectTrig when rising_edge(i_clock); -- DFF
    r_effectTrig_re <= not r_effectTrig_d and i_effectTrig;   -- One-cycle strobe

    process(i_clock, i_reset_n)
        -- Variables
        variable v_romAddr : integer range 0 to 1023;
        variable v_numSteps : integer range 0 to 2**word_size - 1 := 0;
        variable v_freq : integer range 0 to 2**word_size - 1 := 0;
        variable v_duration_msec : integer range 0 to 2**word_size - 1 := 0;
        variable v_clkCounter : integer range 0 to clks_per_msec := 0;
    begin

        if (i_reset_n = '0') then
            r_state <= S_INIT;
            r_buzzDisable <= '1';

        elsif rising_edge(i_clock) then
            case r_state is
                when S_INIT =>
                    r_state <= S_IDLE;
                    r_buzzDisable <= '1';

                when S_IDLE => 

                    -- Wait for trigger
                    if (r_effectTrig_re = '1') then
                        r_state <= S_START;
                    else
                        r_state <= S_IDLE;
                    end if;

                when S_START =>

                    -- Set starting ROM addr
                    case i_effectSel is
                        when "000" =>
                            v_romAddr := 0*effect_size;
                        when "001" => 
                            v_romAddr := 1*effect_size;
                        when "010" => 
                            v_romAddr := 2*effect_size;
                        when "011" => 
                            v_romAddr := 3*effect_size;
                        when "100" => 
                            v_romAddr := 4*effect_size;
                        when others =>
                            v_romAddr := 0*effect_size;
                    end case;

                    r_state <= S_LOAD_N_PRE;

                -- One extra clock cycle is needed to latch in the ROM address
                when S_LOAD_N_PRE => 
                    r_state <= S_LOAD_N;
                when S_LOAD_N => 
                    v_numSteps := to_integer(unsigned(w_romData));
                    v_romAddr := v_romAddr + 1;
                    r_state <= S_LOAD_FREQ_PRE;

                when S_LOAD_FREQ_PRE => 
                    r_state <= S_LOAD_FREQ;
                when S_LOAD_FREQ => 
                    v_freq := to_integer(unsigned(w_romData));
                    -- Check for zero, this means no freq (a simple delay in the program)
                    if (v_freq = 0) then
                        r_buzzDivisor <= (others => '0');
                        r_buzzDisable <= '1';
                    else
                        r_buzzDivisor <= STD_LOGIC_VECTOR(TO_UNSIGNED(50e6 / v_freq, r_buzzDivisor'LENGTH));
                        r_buzzDisable <= '0';
                    end if;
                    v_romAddr := v_romAddr + 1;
                    r_state <= S_LOAD_DUR_PRE;

                when S_LOAD_DUR_PRE => 
                    r_state <= S_LOAD_DUR;
                when S_LOAD_DUR => 
                    v_duration_msec := to_integer(unsigned(w_romData));
                    v_clkCounter := 0;
                    v_romAddr := v_romAddr + 1;
                    r_state <= S_WAIT_DUR;

                when S_WAIT_DUR => 
                    -- Still waiting
                    if (v_duration_msec > 0) then
                        v_clkCounter := v_clkCounter + 1;

                        -- Count msec
                        if (v_clkCounter = clks_per_msec) then
                            v_clkCounter := 0;
                            v_duration_msec := v_duration_msec - 1;
                        end if;

                        r_state <= S_WAIT_DUR;
                    -- Duration complete
                    else
                        r_state <= S_NEXT_STEP;
                    end if;

                when S_NEXT_STEP => 
                    v_numSteps := v_numSteps - 1; -- Decr step counter

                    if (v_numSteps = 0) then
                        r_state <= S_COMP;
                    else
                        r_state <= S_LOAD_FREQ_PRE;
                    end if;
                
                -- Sequence complete
                when S_COMP => 
                    r_state <= S_INIT;
                when others =>
                    r_state <= S_INIT;
            end case;

            -- Override current sequence when new trigger is receieved
            if (r_effectTrig_re = '1') then
                r_state <= S_START;
            end if;
        end if;

        -- Var to signal
        r_romAddr <= STD_LOGIC_VECTOR(TO_UNSIGNED(v_romAddr, r_romAddr'LENGTH));

    end process;

    -- Instantiation and port mapping
    U1 : effect_mem port map (
        address => r_romAddr,
        clock => i_clock,
        q => w_romData
    );

    U2 : clock_div generic map (
        n => 27
    ) port map (
        clock_in => i_clock,
        reset => r_buzzDisable,
        divisor => r_buzzDivisor,
        clock_out => o_buzzPin
    );

end rtl;