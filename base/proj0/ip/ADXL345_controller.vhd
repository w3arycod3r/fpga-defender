-- Component for interfacing with the ADXL345 accelerometer. This is really just a wrapper for a verilog controller that actually does the work. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ADXL345_controller is

	port (
	
		reset_n     : IN STD_LOGIC;
		clk         : IN STD_LOGIC;
		data_valid  : OUT STD_LOGIC;
		data_x      : OUT STD_LOGIC_VECTOR(15 downto 0);
		data_y      : OUT STD_LOGIC_VECTOR(15 downto 0);
		data_z      : OUT STD_LOGIC_VECTOR(15 downto 0);
		SPI_SDI     : OUT STD_LOGIC;
		SPI_SDO     : IN STD_LOGIC;
		SPI_CSN     : OUT STD_LOGIC;
		SPI_CLK     : OUT STD_LOGIC
	
	);
	
end ADXL345_controller;

architecture ADXL345_controller_structural of ADXL345_controller is

	component gsensor is port (
	
		reset_n     : IN STD_LOGIC;
		clk         : IN STD_LOGIC;
		data_valid  : OUT STD_LOGIC;
		data_x      : OUT STD_LOGIC_VECTOR(15 downto 0);
		data_y      : OUT STD_LOGIC_VECTOR(15 downto 0);
		data_z      : OUT STD_LOGIC_VECTOR(15 downto 0);
		SPI_SDI     : OUT STD_LOGIC;
		SPI_SDO     : IN STD_LOGIC;
		SPI_CSN     : OUT STD_LOGIC;
		SPI_CLK     : OUT STD_LOGIC
		
    );
	
	end component;
	
	begin
	
	U0 : gsensor port map(reset_n, clk, data_valid, data_x, data_y, data_z, SPI_SDI, SPI_SDO, SPI_CSN, SPI_CLK);

end ADXL345_controller_structural;

