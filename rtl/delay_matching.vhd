---------------------------------------------------------------
-- 
-- (C) 2011 Thomas Meures 
-- Universite Libre de Bruxelles
-- Service de physique des particules elementaires
-- 
-- Create Date:     
-- Design Name: 
-- Module Name:     delay_matching
-- Project Name: 
-- Target Devices:  Spartan-3AN / Spartan-6
-- Tool versions:   ISE 13.1 (Win7 64-bit)
-- Description: 		Compares the delay of different trigger inputs and calculates the difference 
--							to the biggest delay for each trigger input.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
---------------------------------------------------------------
LIBRARY ieee;
	USE ieee.std_logic_1164.all;
--	USE ieee.std_logic_signed.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.std_logic_arith.all;
	USE work.new_data_types.all;
	
ENTITY delay_matching IS
GENERIC(n_triggers : INTEGER := 3);
PORT( clk : IN STD_LOGIC;
		trigger_delay_i: IN VECTOR_ARRAY(0 TO n_triggers);
		max_delay_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		matched_delay_o : OUT VECTOR_ARRAY(0 TO n_triggers)
);
END delay_matching;

ARCHITECTURE behavior OF delay_matching IS
BEGIN

	PROCESS(trigger_delay_i)
		VARIABLE matching : VECTOR_ARRAY(0 TO n_triggers);
		VARIABLE highest_d : STD_LOGIC_VECTOR(3 DOWNTO 0);
		VARIABLE difference : STD_LOGIC_VECTOR(3 DOWNTO 0);
		VARIABLE zero : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
		VARIABLE increment : INTEGER;
		VARIABLE go : STD_LOGIC;
	BEGIN
		matching := trigger_delay_i;
		highest_d := matching(0);
		FOR i in 0 TO n_triggers LOOP
			IF (highest_d < matching(i)) THEN
				highest_d := matching(i);
			END IF;
			IF i = 3 THEN
				go :='1';
			ELSE
				go :='0';
			END IF;
		END LOOP;
		FOR i in 0 TO n_triggers LOOP
			IF go = '1' THEN
				matched_delay_o(i) <= highest_d - matching(i);
				max_delay_o <= highest_d;
			END IF;
		END LOOP;
	END PROCESS;
	
END behavior;