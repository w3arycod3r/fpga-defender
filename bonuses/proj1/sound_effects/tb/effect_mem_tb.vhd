-- Testbench for effect_mem
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

ENTITY effect_mem_tb IS
END effect_mem_tb;

ARCHITECTURE behavior OF effect_mem_tb IS

    -- Component declarations
    component effect_mem is
        port
        (
            address		: in std_logic_vector (9 downto 0);
            clock		: in std_logic  := '1';
            q		: out std_logic_vector (8 downto 0)
        );
    end component;

    -- Constants
    CONSTANT clock_period: TIME := 20 ns; -- 50 MHz

    -- Signal declarations
    signal reset_n : std_logic;
    SIGNAL test_clk    : STD_LOGIC;
    signal mem_addr : std_logic_vector(9 downto 0);
    signal mem_data : std_logic_vector(8 downto 0);

BEGIN

    -- Instantiation and port mapping
    UUT : effect_mem port map (
        address => mem_addr,
        clock => test_clk,

        q => mem_data

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
        mem_addr <= "00" & X"00";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"01";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"02";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"03";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"04";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"05";
        WAIT FOR 80 ns;     
        mem_addr <= "00" & X"06";
        WAIT FOR 80 ns;     

        WAIT;
    END PROCESS;
   

END;
