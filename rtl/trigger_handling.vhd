---------------------------------------------------------------
-- 
-- (C) 2011 Thomas Meures 
-- Universite Libre de Bruxelles
-- Service de physique des particules elementaires
-- 
-- Create Date:     
-- Design Name: 
-- Module Name:     trigger_handling 
-- Project Name: 
-- Target Devices:  Spartan-3AN / Spartan-6
-- Tool versions:   ISE 13.1 (Win7 64-bit)
-- Description: This module receives all trigger signals, delays them properly and
--						combines the delayed signals to an "OR" of all triggers. 
--        			(for more details, see the documentation).
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
---------------------------------------------------------------

Library ieee;
	USE ieee.std_logic_1164.all;
	USE ieee.std_logic_unsigned.all;
	USE ieee.std_logic_arith.all;
	USE work.new_data_types.all;

Library UNISIM;
use UNISIM.vcomponents.all;


ENTITY trigger_handling IS
	GENERIC( NUM_L4 : INTEGER := 4;
				NUM_L4_RF : INTEGER := 2;
				DELAY_BITS : INTEGER := 4;
				PRETRG_BITS : INTEGER := 4);
	PORT( clk : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			physics_trigger_in : IN STD_LOGIC_VECTOR (NUM_L4_RF-1 DOWNTO 0);
			cal_trigger_in : IN STD_LOGIC;
			cpu_trigger_in : IN STD_LOGIC;
			pre_trigger_length_i : IN STD_LOGIC_VECTOR( (NUM_L4)*PRETRG_BITS-1 DOWNTO 0);			
			trigger_delay_i :  IN STD_LOGIC_VECTOR( (NUM_L4)*DELAY_BITS-1 DOWNTO 0);
			trigger_combined : OUT STD_LOGIC;
			full_triggers_o : OUT STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
			trigger_delay_o : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			debug_o			 : OUT STD_LOGIC_VECTOR(7 downto 0)
	);
END trigger_handling;
	
ARCHITECTURE behavior OF trigger_handling IS

	SIGNAL complete_delay : VECTOR_ARRAY(0 TO NUM_L4-1);
	SIGNAL full_triggers : STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
	SIGNAL trigger_in_temp : STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
	SIGNAL trigger_high : STD_LOGIC;
	CONSTANT zero : STD_LOGIC_VECTOR (NUM_L4-1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL matched_delay1 : VECTOR_ARRAY(0 TO NUM_L4-1);
	SIGNAL max_delay : STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
	SIGNAL pre_trigger_length : VECTOR_ARRAY(0 TO NUM_L4-1);
	SIGNAL trigger_delay : VECTOR_ARRAY(0 TO NUM_L4-1);

COMPONENT delay_matching IS
GENERIC(n_triggers : INTEGER := 3);
PORT( clk : IN STD_LOGIC;
		trigger_delay_i : IN VECTOR_ARRAY(0 TO NUM_L4-1);
		max_delay_o : OUT STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
		matched_delay_o : OUT VECTOR_ARRAY(0 TO NUM_L4-1)
);
END COMPONENT;

COMPONENT delay_line2 IS
GENERIC(n_triggers : INTEGER := 3);
PORT( clk : IN STD_LOGIC;
		trigger_signal : IN STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0);
		matched_delay : IN VECTOR_ARRAY(0 TO NUM_L4-1);
		delayed_signal_out : OUT STD_LOGIC_VECTOR(NUM_L4-1 DOWNTO 0)
);
END COMPONENT;

BEGIN

	configuration_set : FOR i IN 0 TO n_triggers GENERATE 
		pre_trigger_length(i) <=pre_trigger_length_i((i+1)*4-1 DOWNTO i*4);			
		trigger_delay(i) <=trigger_delay_i((i+1)*4-1 DOWNTO i*4);
	END GENERATE;

	trigger_history : FOR i in 0 TO n_triggers GENERATE
		complete_delay(i) <= pre_trigger_length(i) + trigger_delay(i);
	END GENERATE;

	trigger_in_temp <= physics_trigger_in & cal_trigger_in & cpu_trigger_in;
	trigger_delay_o <= "00000" & max_delay;
	
	delay_calc : delay_matching PORT MAP( clk, complete_delay, max_delay, matched_delay1);
	delay_l : delay_line2 PORT MAP( clk, trigger_in_temp,	matched_delay1, full_triggers);
	
	debug_o <= full_triggers & trigger_in_temp;

	PROCESS(clk)
	BEGIN
		IF(clk'EVENT and clk='1') THEN
			IF (full_triggers /= zero) THEN
				trigger_combined <= '1';
				trigger_high <='1';		
			ELSIF (full_triggers = zero) THEN
				trigger_combined <= '0';
				trigger_high <='0';
			END IF;
			full_triggers_o <= full_triggers;
		END IF;
	END PROCESS;
	
END behavior;