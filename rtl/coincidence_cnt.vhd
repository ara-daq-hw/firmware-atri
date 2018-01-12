----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:07:17 08/31/2011 
-- Design Name: 
-- Module Name:    coincidence_cnt - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity coincidence_cnt is
	generic ( LIMIT : integer := 15);
    Port ( clk : in  STD_LOGIC;
           trig_in : in  STD_LOGIC;
           count_active : out  STD_LOGIC;
           count : out  STD_LOGIC_VECTOR (3 downto 0));
end coincidence_cnt;

architecture Behavioral of coincidence_cnt is

signal count_active_int : std_logic := '0';
signal count_int : std_logic_vector(3 downto 0) := (others => '0');
begin

process(clk)
begin
if clk'event and clk='1' then
	if trig_in='1' then
		count_int<= (others => '0');
		count_active_int<='1';
	elsif count_active_int = '1' then
		count_int<=count_int+1;
	end if;
	if count_int = LIMIT then
		count_active_int<='0';
	end if;
end if;
end process;
count<=count_int;
count_active<=count_active_int;

end Behavioral;

