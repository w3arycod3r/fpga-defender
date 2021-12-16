-- vga_controller: inspired by digikey code and project F blog
-- Source: https://forum.digikey.com/t/vga-controller-vhdl/12794
-- Source: https://projectf.io/posts/fpga-graphics/

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;

ENTITY vga_controller IS
	GENERIC(
		H_RES	:	INTEGER := 640;		--horiztonal display width in pixels
		V_RES	:	INTEGER := 480;		--vertical display width in rows
		H_FP	:	INTEGER := 16;		--horiztonal front porch width in pixels
		H_SYNC 	:	INTEGER := 96;    	--horiztonal sync pulse width in pixels
		H_BP	:	INTEGER := 48;		--horiztonal back porch width in pixels
		V_FP	:	INTEGER := 10;			--vertical front porch width in rows
		V_SYNC 	:	INTEGER := 2;			--vertical sync pulse width in rows
		V_BP	:	INTEGER := 33;			--vertical back porch width in rows
		H_POL   :	STD_LOGIC := '0';		--horizontal sync pulse polarity (1 = positive, 0 = negative)
		V_POL	:	STD_LOGIC := '0'		--vertical sync pulse polarity (1 = positive, 0 = negative)
	);	
	PORT(
		pixel_clk	:	IN		STD_LOGIC;	--pixel clock at frequency of VGA mode being used
		reset_n		:	IN		STD_LOGIC;	--active low synchronous reset
		hsync		:	OUT	STD_LOGIC;	--horiztonal sync pulse
		vsync		:	OUT	STD_LOGIC;	--vertical sync pulse
		de	        :	OUT	STD_LOGIC;	--display enable ('1' = display time, '0' = blanking time)
		frame       :   out STD_LOGIC;  -- high at start of frame
		line        :   out STD_LOGIC;  -- high at start of active line
		sx			:	OUT	INTEGER range -(H_SYNC+H_FP+H_BP) to H_RES-1;		-- signed horizontal pixel coordinate
		sy		    :	OUT	INTEGER range -(V_SYNC+V_FP+V_BP) to V_RES-1		-- signed vertical pixel coordinate
	);
END vga_controller;

ARCHITECTURE behavior OF vga_controller IS
	-- horizontal timings
	constant H_STA  : integer := 0 - H_FP - H_SYNC - H_BP;    -- horizontal start
	constant HS_STA : integer := H_STA + H_FP;                -- sync start
	constant HS_END : integer := HS_STA + H_SYNC;             -- sync end
	constant HA_STA : integer := 0;                           -- active start
	constant HA_END : integer := H_RES - 1;                   -- active end

	-- vertical timings
	constant V_STA  : integer := 0 - V_FP - V_SYNC - V_BP;    -- vertical start
	constant VS_STA : integer := V_STA + V_FP;                -- sync start
	constant VS_END : integer := VS_STA + V_SYNC;             -- sync end
	constant VA_STA : integer := 0;                           -- active start
	constant VA_END : integer := V_RES - 1;                   -- active end

	signal x : INTEGER range -(H_SYNC+H_FP+H_BP) to H_RES-1;		-- signed horizontal pixel coordinate
	signal y : INTEGER range -(V_SYNC+V_FP+V_BP) to V_RES-1;		-- signed vertical pixel coordinate
BEGIN

	-- generate horizontal and vertical sync with correct polarity
	process(pixel_clk)
	begin
		if rising_edge(pixel_clk) then

			if (x > HS_STA and x <= HS_END) then
				hsync <= H_POL; -- Assert
			else
				hsync <= not H_POL; -- Deassert
			end if;

			-- Assert vsync
			if (y > VS_STA and y <= VS_END) then
				vsync <= V_POL; -- Assert
			else
				vsync <= not V_POL; -- Deassert
			end if;

		end if;
	end process;

	-- control signals
	process(pixel_clk)
	begin
		if rising_edge(pixel_clk) then

			if (y >= VA_STA and x >= HA_STA) then
				de <= '1';
			else
				de <= '0';
			end if;

			if (y = V_STA  and x = H_STA) then
				frame <= '1';
			else
				frame <= '0';
			end if;

			if (y >= VA_STA and x = H_STA) then
				line <= '1';
			else
				line <= '0';
			end if;


			if (reset_n = '0') then frame <= '0'; end if; -- don't assert frame in reset

		end if;
	end process;

	-- calculate horizontal and vertical screen position
	process(pixel_clk)
	begin
		if rising_edge(pixel_clk) then
			
			if (x = HA_END) then  -- last pixel on line?
				x <= H_STA;
				if (y = VA_END) then  -- last line on screen?
					y <= V_STA;
				else
					y <= y + 1;
				end if;
			else
				x <= x + 1;
			end if;

			if (reset_n = '0') then
				x <= H_STA;
				y <= V_STA;
			end if;

		end if;
	end process;

	-- delay screen position to match sync and control signals
	process(pixel_clk)
	begin
		if rising_edge(pixel_clk) then

			sx <= x;
			sy <= y;

			if (reset_n = '0') then
				sx <= H_STA;
				sy <= V_STA;
			end if;

		end if;
	end process;

END behavior;