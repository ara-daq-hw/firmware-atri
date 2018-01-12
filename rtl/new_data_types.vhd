LIBRARY ieee;
	USE ieee.std_logic_1164.all;

PACKAGE new_data_types IS
	TYPE integer_array IS ARRAY (NATURAL RANGE <>) OF INTEGER;
	TYPE vector_array IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(3 DOWNTO 0);
	TYPE small_integer_array IS ARRAY (NATURAL RANGE <>) OF INTEGER RANGE 0 TO 63;
	
	    -- 48-bit system clock on 100 MHz give 32-day wraparound time
    SUBTYPE timestamp is std_logic_vector(47 downto 0);
	
END new_data_types;