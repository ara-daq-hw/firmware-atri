---------------------------------------------------------------
-- 
-- (C) 2011 Thomas Meures 
-- Universite Libre de Bruxelles
-- Service de physique des particules elementaires
-- 
-- Create Date:     
-- Design Name: 
-- Module Name:     delay_line2
-- Project Name: 
-- Target Devices:  Spartan-3AN / Spartan-6
-- Tool versions:   ISE 13.1 (Win7 64-bit)
-- Description: 
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
	
	Library UNISIM;
use UNISIM.vcomponents.all;

ENTITY delay_line2 IS
GENERIC(n_triggers : INTEGER := 3);
PORT( clk : IN STD_LOGIC;
		trigger_signal : IN STD_LOGIC_VECTOR(n_triggers DOWNTO 0);
		matched_delay : IN VECTOR_ARRAY(0 TO n_triggers);
		delayed_signal_out : OUT STD_LOGIC_VECTOR(n_triggers DOWNTO 0)
);
END delay_line2;

ARCHITECTURE behavior OF delay_line2 IS

BEGIN

shift_register : FOR i IN 0 TO n_triggers GENERATE
   SRL16_inst : SRL16
   generic map (
      INIT => X"0000")
   port map (
      delayed_signal_out(i),       -- SRL data output
      matched_delay(i)(0),     -- Select[0] input
      matched_delay(i)(1),     -- Select[1] input
      matched_delay(i)(2),     -- Select[2] input
      matched_delay(i)(3),     -- Select[3] input
      clk,   -- Clock input
      trigger_signal(i)        -- SRL data input
   );
	END GENERATE;
	
END behavior;