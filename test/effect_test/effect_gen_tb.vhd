-- Testbench for effect_gen
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY effect_gen_tb IS
END effect_gen_tb;

ARCHITECTURE behavior OF effect_gen_tb IS

    -- Component declarations
    component effect_gen is
        port (
            i_clock : in std_logic;
            i_reset_n : in std_logic;
    
            i_launch : in std_logic;
            i_playerFire : in std_logic;
            i_enemyFire : in std_logic;
            i_enemyDestroy : in std_logic;
            i_playerDestroy : in std_logic;
    
            o_buzzPin : out std_logic
        );
    end component;

    -- Constants
    CONSTANT clock_period: TIME := 20 ns; -- 50 MHz

    -- Signal declarations
    signal reset_n : std_logic;
    SIGNAL test_clk    : STD_LOGIC;
    signal effect_cmd : std_logic_vector(4 downto 0);
    signal buzz_out : std_logic;

BEGIN

    -- Instantiation and port mapping
    UUT : effect_gen port map (
        i_clock => test_clk,
        i_reset_n => reset_n,

        i_launch => effect_cmd(0),
        i_playerFire => effect_cmd(1),
        i_enemyFire => effect_cmd(2),
        i_enemyDestroy => effect_cmd(3),
        i_playerDestroy => effect_cmd(4),

        o_buzzPin => buzz_out
    );


    clock_process: PROCESS
    BEGIN
        test_clk <= '0';
        WAIT FOR clock_period/2;
        test_clk <= '1';
        WAIT FOR clock_period/2;
    END PROCESS;    
    
    vectors: PROCESS
    BEGIN
        reset_n <= '0';
        WAIT FOR 20 ns;     
        reset_n <= '1';
        effect_cmd <= "00001";
        wait for 100 ns;
        WAIT;
    END PROCESS;
   

END;
