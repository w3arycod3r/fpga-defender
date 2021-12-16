-- Buzzer effect tester
-- Top level entity
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity effect_test_top is
    PORT( 
        KEY                                : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        SW                                 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
        MAX10_CLK1_50                      : IN STD_LOGIC; -- 50 MHz clock input
        LEDR                               : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
        ARDUINO_IO                         : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        HEX5, HEX4, HEX3, HEX2, HEX1, HEX0 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        -- Accelerometer I/O
        GSENSOR_CS_N          : OUT   STD_LOGIC;
        GSENSOR_SCLK          : OUT   STD_LOGIC;
        GSENSOR_SDI           : INOUT STD_LOGIC;
        GSENSOR_SDO           : INOUT STD_LOGIC;
        
        -- VGA I/O  
        VGA_HS		         :	OUT	 STD_LOGIC;	-- horizontal sync pulse
        VGA_VS		         :	OUT	 STD_LOGIC;	-- vertical sync pulse 
        
        VGA_R                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- red magnitude output to DAC
        VGA_G                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');  -- green magnitude output to DAC
        VGA_B                 :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0')   -- blue magnitude output to DAC
    );
end effect_test_top;

architecture top_level of effect_test_top is

    -- Component declarations
    component effect_gen is
        port (
            i_clock : in std_logic;
            i_reset_n : in std_logic;

            i_effectSel : in std_logic_vector(2 downto 0);
            i_effectTrig : in std_logic;
            o_buzzPin : out std_logic
        );
    end component;

    -- Signal declarations
    signal KEY_b : std_logic_vector(1 downto 0) ;

begin
    -- Concurrent assignments
    KEY_b <= not KEY;

    -- Clear displays
    HEX5 <= (OTHERS => '1');
    HEX4 <= (OTHERS => '1');
    HEX3 <= (OTHERS => '1');
    HEX2 <= (OTHERS => '1');
    HEX1 <= (OTHERS => '1');
    HEX0 <= (OTHERS => '1');


    -- Instantiation and port mapping
    U1 : effect_gen port map (
        i_clock => MAX10_CLK1_50,
        i_reset_n => KEY(0),

        i_effectSel => SW(2 downto 0),
        i_effectTrig => KEY_b(1),

        o_buzzPin => ARDUINO_IO(12)
    );

end top_level;