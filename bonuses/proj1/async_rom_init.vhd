-- async_rom_init: asynchronous ROM with initial values.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defender_common.all;

entity async_rom_init is
	generic(
		numElements: integer := 128;
		dataWidth: integer := 8;
		initFile: string := "ram.mif"
	);
	port(
		addrA: in std_logic_vector(ceil_log2(numElements)-1 downto 0);
		dataOutA: out std_logic_vector(dataWidth-1 downto 0)
	);
end async_rom_init;

architecture Behavioral of async_rom_init is
	type rom_type is array (0 to numElements-1) of std_logic_vector(dataWidth-1 downto 0);
	signal ROM: rom_type;
	attribute ram_init_file : string;
	attribute ram_init_file of ROM : signal is initFile;

begin
	dataOutA <= ROM(to_integer(unsigned(addrA)));
end Behavioral;

