-- sync_ram_init: Synchronous block RAM with initial values. Can be used as a rom
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.defender_common.all;

entity sync_ram_init is
	generic(
		numElements: integer := 128;
		dataWidth: integer := 8;
		initFile: string := "ram.mif"
	);
	port(
		clkA: in std_logic;
		writeEnableA: in std_logic;
		addrA: in std_logic_vector(ceil_log2(numElements)-1 downto 0);
		dataOutA: out std_logic_vector(dataWidth-1 downto 0);
		dataInA: in std_logic_vector(dataWidth-1 downto 0)
	);
end sync_ram_init;

architecture Behavioral of sync_ram_init is
	type rom_type is array (0 to numElements-1) of std_logic_vector(dataWidth-1 downto 0);
	signal RAM: rom_type;
	attribute ram_init_file : string;
	attribute ram_init_file of RAM : signal is initFile;

begin
	-- addr register to infer block RAM
	setRegA: process (clkA)
	begin
		if rising_edge(clkA) then
			-- Write to rom
			if(writeEnableA = '1') then
				RAM(to_integer(unsigned(addrA))) <= dataInA;
			end if;
			-- Read from it
			dataOutA <= RAM(to_integer(unsigned(addrA)));
		end if;
	end process;
end Behavioral;

