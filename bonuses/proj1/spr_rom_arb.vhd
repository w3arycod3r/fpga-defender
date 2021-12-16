-- spr_rom_arb: Sprite ROM arbitration master
-- Inspired By: https://github.com/MadLittleMods/FP-V-GA-Text
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library work;
use work.defender_common.all;

entity spr_rom_arb is
	generic(
		numPorts: integer := 2
	);
	port(
		clk: in std_logic;
		reset: in std_logic;
		inPortArray: in t_arb_port_in_array(0 to numPorts-1); -- Give us the address and whether you request it now
		outPortArray: out t_arb_port_out_array(0 to numPorts-1) := (others => init_t_arb_port_out) -- We give you data in this array
	);
end spr_rom_arb;

architecture Behavioral of spr_rom_arb is
	-- Holds the address we intend to use/used
	signal addrReg: std_logic_vector(c_spr_addr_bits-1 downto 0) := (others => '0');
	-- Holds the most recent data we just got
	signal dataOutReg: std_logic_vector(c_spr_data_width_bits-1 downto 0) := (others => '0');
	
	signal writeEnableReg: std_logic := '0';
	signal dataInReg: std_logic_vector(c_spr_data_width_bits-1 downto 0) := (others => '0');
	
begin

	-- This is the basically the database
	-- Accessed by address
	spr_mem: entity work.sync_ram_init generic map(
        numElements => c_spr_data_depth,
        dataWidth => c_spr_data_width_bits,
        initFile => "../res/sprite_data.mif"
    )
    port map(
        clkA => clk,
        writeEnableA => writeEnableReg,
        addrA => addrReg,
        dataOutA => dataOutReg,
        dataInA => dataInReg
    );
	
	arbiter: process(clk)
		-- Stores the current index as we roll through `inPortArray` and store the data in `outPortArray`
		variable currPortIndex: integer range 0 to numPorts-1 := 0;
		variable nextPortIndex: integer := -1;
		
		type type_arbiterLoopState is (state_updateRomAddr, state_waitForRomData, state_presentData, state_getNextPort);
		variable currState: type_arbiterLoopState := state_updateRomAddr;
	begin
		if rising_edge(clk) then
			
			if reset = '1' then
				-- Reset the array
				outPortArray <= (others => init_t_arb_port_out);
				
				currPortIndex := 0;
				nextPortIndex := -1;
				
				
				addrReg <= (others => '0');
				writeEnableReg <= '0';
				dataInReg <= (others => '0');
				
				-- Reset State
				currState := state_updateRomAddr;
			else
			
				
				case currState is
					when state_updateRomAddr =>
						
						-- Start the read request
						------------------------------
						if inPortArray(currPortIndex).dataRequest then
							-- If they are making a new request then we have no data waiting yet
							outPortArray(currPortIndex).dataWaiting <= false;
						
							-- Change the address so that on the next cycle,
							-- we have some corresponding data in `dataOutReg`
							addrReg <= inPortArray(currPortIndex).addr;
							
							-- Change State
							currState := state_waitForRomData;
							
						end if;
						
						-- Start the write request
						-----------------------------
						if inPortArray(currPortIndex).writeRequest then
							addrReg <= inPortArray(currPortIndex).addr;
							
							dataInReg <= inPortArray(currPortIndex).writeData; -- Put the data in the ram register
							writeEnableReg <= '1'; -- Tell the ram we are ready
							
							outPortArray(currPortIndex).dataWritten <= false; -- Tell the outside, that we haven't wrote it yet
						
							-- Change State
							currState := state_waitForRomData;
						end if;
						
						-- If we are not doing anything, 
						-- then we should go find another port
						if not inPortArray(currPortIndex).dataRequest and not inPortArray(currPortIndex).writeRequest then
							-- If the current port doesn't want data, find one, that does
							-- Change State
							currState := state_getNextPort;
						end if;
						
						
					-- Wait for the data to be ready
					-- This could be read, write, or both
					when state_waitForRomData =>
						if inPortArray(currPortIndex).dataRequest or inPortArray(currPortIndex).writeRequest then
							-- Change State
							currState := state_presentData;
						else
							-- If the current port doesn't want data, find one, that does
							-- Change State
							currState := state_getNextPort;
						end if;
					
					-- Put the data in the array for use
					when state_presentData =>
				
						-- If they want the data, then give it
						if inPortArray(currPortIndex).dataRequest then
							outPortArray(currPortIndex).data <= dataOutReg;
							outPortArray(currPortIndex).dataWaiting <= true;
							
						-- If they don't want the data, we have no data waiting
						else
							outPortArray(currPortIndex).dataWaiting <= false;
						end if;
						
						-- We wrote to the ram, so tell them
						if inPortArray(currPortIndex).writeRequest then
							dataInReg <= (others => '0'); 
							writeEnableReg <= '0';
							
							outPortArray(currPortIndex).dataWritten <= true; -- Tell the outside, we wrote it!
						end if;
						
						
						-- We go to find a new port no matter what...
						-- Change State
						currState := state_getNextPort;
						
					when state_getNextPort =>
						-- Roll to the next port
						--------------------------
						
						-- Move to the next port that has a request
						nextPortIndex := -1;
						for i in 0 to inPortArray'length-1 loop
							if i > currPortIndex and (inPortArray(i).dataRequest or inPortArray(i).writeRequest) then
								nextPortIndex := i;
								exit;
							else
								outPortArray(i).dataWaiting <= false;
								outPortArray(i).dataWritten <= false;
							end if;
						end loop;
						-- If we didn't find the next port from the loop above
						-- Then start at the beginning and go to the where we are
						if nextPortIndex <= 0 then
							for i in 0 to inPortArray'length-1 loop
								if i <= currPortIndex then
									if inPortArray(i).dataRequest or inPortArray(i).writeRequest then
										nextPortIndex := i;
										exit;
									else
										outPortArray(i).dataWaiting <= false;
										outPortArray(i).dataWritten <= false;
									end if;
								else
									exit;
								end if;
							end loop;
						end if;
						
						-- Change State
						-- We are stuck here until we find
						if nextPortIndex >= 0 then
							currPortIndex := nextPortIndex;
							currState := state_updateRomAddr;
						end if;
						
				end case;
				
			end if;
		end if;
	
	end process;
	
	

end Behavioral;

