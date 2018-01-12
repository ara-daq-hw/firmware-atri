---------------------------------------------------------------
-- 
-- (C) 2011 Thomas Meures 
-- Universite Libre de Bruxelles
-- Service de physique des particules elementaires
-- 
-- Create Date:     
-- Design Name: 
-- Module Name:     time_stamping
-- Project Name: 
-- Target Devices:  Spartan-3AN / Spartan-6
-- Tool versions:   ISE 13.1 (Win7 64-bit)
-- Description: Provides a divided timestamp of 48bit to the different modules.
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

ENTITY time_stamping IS
PORT( clk : 					IN STD_LOGIC;									
		reset : 					IN STD_LOGIC;
		gps_pps : 				IN STD_LOGIC;										-- any standard signal, resetting the timer.
		gps_count : 			OUT STD_LOGIC_VECTOR(5 DOWNTO 0);		-- if needed the standard signal can be counted to.
		register_timestamp : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);		-- Least significant part of the timestamp, saved with the block address in the readout queue
		common_timestamp : 	OUT STD_LOGIC_VECTOR(32 DOWNTO 0)		-- Most significant part of the time stamp, provided to complete the time stamp for the readout_buffer.
		);
END time_stamping;

ARCHITECTURE behavior OF time_stamping IS

	FUNCTION increment(val : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR		--This function is used to increment the STD_LOGIC_VECTOR (mot especially needed)
	is
		-- normalize the indexing
		ALIAS input 		: STD_LOGIC_VECTOR(val'length downto 1) is val;
		VARIABLE result 	: STD_LOGIC_VECTOR(input'range) := input;
		VARIABLE carry 	: STD_LOGIC := '1';
	begin
		for i in input'low to input'high loop
			result(i) := input(i) xor carry;
			carry := input(i) and carry;
			exit when carry = '0';
		end loop;
		return result;
	end increment;

	SIGNAL xregister_timestamp : STD_LOGIC_VECTOR(14 DOWNTO 0) := ( others => '0');
	SIGNAL xgps_count : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
	SIGNAL xcommon_timestamp : STD_LOGIC_VECTOR(32 downto 0) := (others => '0');
	
BEGIN
	register_timestamp <= xregister_timestamp;
	gps_count <= xgps_count;
	common_timestamp <= xcommon_timestamp;

	PROCESS(clk, gps_pps)												-- In this process the time stamps are incremented and reset, in case a gps SIGNAL occurs.
		VARIABLE inhibit : STD_LOGIC :='0';
	BEGIN
	IF(reset = '1') THEN
		xgps_count <= (OTHERS => '0');
		xregister_timestamp <= ( OTHERS=> '0' );
		xcommon_timestamp <= ( OTHERS=> '0' );		
	ELSIF(clk'EVENT AND clk = '1') THEN
		xregister_timestamp <= increment(xregister_timestamp);
		IF (xregister_timestamp = "111111111111111") THEN
			xcommon_timestamp <= increment(xcommon_timestamp); 
		END IF;
		IF gps_pps = '1' THEN
			IF(inhibit = '0') THEN										-- Inhibit is needed to make sure that the IF statement is only true for one clock cycle.
				xgps_count <= increment(xgps_count);
				inhibit :='1';
				xregister_timestamp <= ( OTHERS=> '0' );
				xcommon_timestamp <= ( OTHERS=> '0' ); 
			END IF;			
		ELSIF(gps_pps = '0') THEN
			inhibit := '0';
		END IF;
	END IF;
	END PROCESS;

END behavior;