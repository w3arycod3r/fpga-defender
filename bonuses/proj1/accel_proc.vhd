-- accel_proc: Accelerometer data processing
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity accel_proc is
    generic(

        -- Top value for input range
        g_in_max_val : integer := 1;
        -- Top value for output range
        g_out_max_val : integer := 1

    );
    port (
        -- Raw data from accelerometer
        data_x      : IN STD_LOGIC_VECTOR(15 downto 0);
        data_y      : IN STD_LOGIC_VECTOR(15 downto 0);
        data_valid  : IN STD_LOGIC;

        -- Direction of tilt
        -- x+ : left,    x- : right
        -- y+ : forward, y- : backward
        accel_scale_x, accel_scale_y          : OUT integer := 0 -- A scaled version of data
    );
end accel_proc;

ARCHITECTURE behavior OF accel_proc IS

    -- Component declarations

    -- Signal declarations

BEGIN

    -- Processes
    process(data_x, data_y, data_valid)
    begin

        -- Sample new data if it's valid, or hold old data
        if (data_valid = '1') then
            accel_scale_x <= to_integer(signed(data_x))*g_out_max_val/g_in_max_val;
            accel_scale_y <= to_integer(signed(data_y))*g_out_max_val/g_in_max_val;
        end if;

    end process;

    

    -- Instantiation and port mapping

    -- Concurrent assignments
    
    

END behavior;

