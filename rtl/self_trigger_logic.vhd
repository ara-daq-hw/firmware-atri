----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:18:57 08/31/2011 
-- Design Name: 
-- Module Name:    self_trigger_top - Behavioral 
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
-- Version 1: 4 out of 3 for each DB : L2 scalers 1 per configuration
-- Version 2: 3 out of 8 for each couple : L2 scalers not connected, "L2.5" scalers
--														one for DB pair
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity self_trigger_logic is
    Port ( clk : in  STD_LOGIC;
           active : in  STD_LOGIC_VECTOR (15 downto 0);
           active_counts : in  STD_LOGIC_VECTOR (63 downto 0);
           trig_o : out  STD_LOGIC;
           scal_trig_o : out  STD_LOGIC;
-- Version q only
--           scal_l1_o : out  STD_LOGIC_VECTOR (15 downto 0);
-- Version 2 only
			  scal_L2_5_o : out STD_LOGIC_VECTOR (1 downto 0);
			  L2_5_trig_debug_o : out STD_LOGIC_VECTOR(1 downto 0));
     --      delay_o : out  STD_LOGIC_VECTOR (63 downto 0));
end self_trigger_logic;

architecture Behavioral of self_trigger_logic is
type arr_counts is array(0 to 15) of std_logic_vector(3 downto 0);
signal int_count, int_delay_o : arr_counts;
-- Version 1
--signal L1_trig, L1_trig_delayed : std_logic_vector(15 downto 0); -- for now only
	-- triggers from the single TDA are combined in a 3 out of for.
-- Version 2
signal L1_trig : std_logic_vector(111 downto 0); 
signal L2_trig, L2_trig_delayed, L2_trig_one_hot: std_logic; 
-- Version 2 only
signal L2_5_trig, L2_5_trig_delayed, L2_5_trig_one_hot: std_logic_vector(1 downto 0); 

begin

separate_counts: process(active_counts)
begin
for i in 0 to 15 loop
	int_count(i)<=active_counts( i*4+3 downto i*4);
end loop;
end process;
-- Version 1
--L1_trig(0) <= active(0) and active(1) and active(2);
--L1_trig(1) <= active(0) and active(1) and active(3);
--L1_trig(2) <= active(0) and active(2) and active(3);
--L1_trig(3) <= active(1) and active(2) and active(3);
--
--L1_trig(4) <= active(4) and active(5) and active(6);
--L1_trig(5) <= active(4) and active(5) and active(7);
--L1_trig(6) <= active(4) and active(6) and active(7);
--L1_trig(7) <= active(5) and active(6) and active(7);
--
--L1_trig(8) <= active(8) and active(9) and active(10);
--L1_trig(9) <= active(8) and active(9) and active(11);
--L1_trig(10) <= active(8) and active(10) and active(11);
--L1_trig(11) <= active(9) and active(10) and active(11);
--
--L1_trig(12) <= active(12) and active(13) and active(14);
--L1_trig(13) <= active(12) and active(13) and active(15);
--L1_trig(14) <= active(12) and active(14) and active(15);
--L1_trig(15) <= active(13) and active(14) and active(15);
--
--L2_trig<= L1_trig(0) or 
--L1_trig(1) or
--L1_trig(2) or
--L1_trig(3) or
--L1_trig(4) or
--L1_trig(5) or
--L1_trig(6) or
--L1_trig(7) or
--L1_trig(8) or
--L1_trig(9) or
--L1_trig(10) or
--L1_trig(11) or
--L1_trig(12) or
--L1_trig(13) or
--L1_trig(14) or
--L1_trig(15);
-- End Version 1

-- Version 2

--DB 1 & 2

L1_trig(0) <= active(0) and active(1) and active(2);
L1_trig(1) <= active(0) and active(1) and active(3);
L1_trig(2) <= active(0) and active(1) and active(4);
L1_trig(3) <= active(0) and active(1) and active(5);
L1_trig(4) <= active(0) and active(1) and active(6);
L1_trig(5) <= active(0) and active(1) and active(7);
L1_trig(6) <= active(0) and active(2) and active(3);
L1_trig(7) <= active(0) and active(2) and active(4);
L1_trig(8) <= active(0) and active(2) and active(5);
L1_trig(9) <= active(0) and active(2) and active(6);
L1_trig(10) <= active(0) and active(2) and active(7);
L1_trig(11) <= active(0) and active(3) and active(4);
L1_trig(12) <= active(0) and active(3) and active(5);
L1_trig(13) <= active(0) and active(3) and active(6);
L1_trig(14) <= active(0) and active(3) and active(7);
L1_trig(15) <= active(0) and active(4) and active(5);
L1_trig(16) <= active(0) and active(4) and active(6);
L1_trig(17) <= active(0) and active(4) and active(7);
L1_trig(18) <= active(0) and active(5) and active(6);
L1_trig(19) <= active(0) and active(5) and active(7);
L1_trig(20) <= active(0) and active(6) and active(7);
L1_trig(21) <= active(1) and active(2) and active(3);
L1_trig(22) <= active(1) and active(2) and active(4);
L1_trig(23) <= active(1) and active(2) and active(5);
L1_trig(24) <= active(1) and active(2) and active(6);
L1_trig(25) <= active(1) and active(2) and active(7);
L1_trig(26) <= active(1) and active(3) and active(4);
L1_trig(27) <= active(1) and active(3) and active(5);
L1_trig(28) <= active(1) and active(3) and active(6);
L1_trig(29) <= active(1) and active(3) and active(7);
L1_trig(30) <= active(1) and active(4) and active(5);
L1_trig(31) <= active(1) and active(4) and active(6);
L1_trig(32) <= active(1) and active(4) and active(7);
L1_trig(33) <= active(1) and active(5) and active(6);
L1_trig(34) <= active(1) and active(5) and active(7);
L1_trig(35) <= active(1) and active(6) and active(7);
L1_trig(36) <= active(2) and active(3) and active(4);
L1_trig(37) <= active(2) and active(3) and active(5);
L1_trig(38) <= active(2) and active(3) and active(6);
L1_trig(39) <= active(2) and active(3) and active(7);
L1_trig(40) <= active(2) and active(4) and active(5);
L1_trig(41) <= active(2) and active(4) and active(6);
L1_trig(42) <= active(2) and active(4) and active(7);
L1_trig(43) <= active(2) and active(5) and active(6);
L1_trig(44) <= active(2) and active(5) and active(7);
L1_trig(45) <= active(2) and active(6) and active(7);
L1_trig(46) <= active(3) and active(4) and active(5);
L1_trig(47) <= active(3) and active(4) and active(6);
L1_trig(48) <= active(3) and active(4) and active(7);
L1_trig(49) <= active(3) and active(5) and active(6);
L1_trig(50) <= active(3) and active(5) and active(7);
L1_trig(51) <= active(3) and active(6) and active(7);
L1_trig(52) <= active(4) and active(5) and active(6);
L1_trig(53) <= active(4) and active(5) and active(7);
L1_trig(54) <= active(4) and active(6) and active(7);
L1_trig(55) <= active(5) and active(6) and active(7);

--DB 3 & 4

L1_trig(56) <= active(8) and active(9) and active(10);
L1_trig(57) <= active(8) and active(9) and active(11);
L1_trig(58) <= active(8) and active(9) and active(12);
L1_trig(59) <= active(8) and active(9) and active(13);
L1_trig(60) <= active(8) and active(9) and active(14);
L1_trig(61) <= active(8) and active(9) and active(15);
L1_trig(62) <= active(8) and active(10) and active(11);
L1_trig(63) <= active(8) and active(10) and active(12);
L1_trig(64) <= active(8) and active(10) and active(13);
L1_trig(65) <= active(8) and active(10) and active(14);
L1_trig(66) <= active(8) and active(10) and active(15);
L1_trig(67) <= active(8) and active(11) and active(12);
L1_trig(68) <= active(8) and active(11) and active(13);
L1_trig(69) <= active(8) and active(11) and active(14);
L1_trig(70) <= active(8) and active(11) and active(15);
L1_trig(71) <= active(8) and active(12) and active(13);
L1_trig(72) <= active(8) and active(12) and active(14);
L1_trig(73) <= active(8) and active(12) and active(15);
L1_trig(74) <= active(8) and active(13) and active(14);
L1_trig(75) <= active(8) and active(13) and active(15);
L1_trig(76) <= active(8) and active(14) and active(15);
L1_trig(77) <= active(9) and active(10) and active(11);
L1_trig(78) <= active(9) and active(10) and active(12);
L1_trig(79) <= active(9) and active(10) and active(13);
L1_trig(80) <= active(9) and active(10) and active(14);
L1_trig(81) <= active(9) and active(10) and active(15);
L1_trig(82) <= active(9) and active(11) and active(12);
L1_trig(83) <= active(9) and active(11) and active(13);
L1_trig(84) <= active(9) and active(11) and active(14);
L1_trig(85) <= active(9) and active(11) and active(15);
L1_trig(86) <= active(9) and active(12) and active(13);
L1_trig(87) <= active(9) and active(12) and active(14);
L1_trig(88) <= active(9) and active(12) and active(15);
L1_trig(89) <= active(9) and active(13) and active(14);
L1_trig(90) <= active(9) and active(13) and active(15);
L1_trig(91) <= active(9) and active(14) and active(15);
L1_trig(92) <= active(10) and active(11) and active(12);
L1_trig(93) <= active(10) and active(11) and active(13);
L1_trig(94) <= active(10) and active(11) and active(14);
L1_trig(95) <= active(10) and active(11) and active(15);
L1_trig(96) <= active(10) and active(12) and active(13);
L1_trig(97) <= active(10) and active(12) and active(14);
L1_trig(98) <= active(10) and active(12) and active(15);
L1_trig(99) <= active(10) and active(13) and active(14);
L1_trig(100) <= active(10) and active(13) and active(15);
L1_trig(101) <= active(10) and active(14) and active(15);
L1_trig(102) <= active(11) and active(12) and active(13);
L1_trig(103) <= active(11) and active(12) and active(14);
L1_trig(104) <= active(11) and active(12) and active(15);
L1_trig(105) <= active(11) and active(13) and active(14);
L1_trig(106) <= active(11) and active(13) and active(15);
L1_trig(107) <= active(11) and active(14) and active(15);
L1_trig(108) <= active(12) and active(13) and active(14);
L1_trig(109) <= active(12) and active(13) and active(15);
L1_trig(110) <= active(12) and active(14) and active(15);
L1_trig(111) <= active(13) and active(14) and active(15);

process(L1_trig)
variable temp1, temp2 : STD_LOGIC;
begin
temp1:=L1_trig(0);
temp2:=L1_trig(56);
for i in 1 to 55 loop
temp1:= L1_trig(i) or temp1;
temp2:= L1_trig(i+56) or temp2;
end loop;
L2_5_trig(0)<= temp1;
L2_5_trig(1)<= temp2;
end process;

L2_trig<= L2_5_trig(0) or L2_5_trig(1);
-- End Version 2

delay_trig : process(clk)
begin
	if clk'event and clk='1' then
		L2_trig_delayed<=L2_trig;
-- Version 1 only
--		L1_trig_delayed<=L1_trig;
		L2_5_trig_delayed<=L2_5_trig;
	end if;
end process;

generate_trig_L2_onehot : process(L2_trig_delayed,L2_trig)
begin
		if L2_trig_delayed='0' and L2_trig ='1' then
			L2_trig_one_hot<='1';
		else
			L2_trig_one_hot<='0';
	end if;
end process;


generate_trig_L2_5_onehot : process(L2_5_trig_delayed,L2_5_trig)
begin
for i in 0 to 1 loop
		if L2_5_trig_delayed(i)='0' and L2_5_trig(i) ='1' then
			L2_5_trig_one_hot(i)<='1';
		else
			L2_5_trig_one_hot(i)<='0';
	end if;
end loop;
end process;

--
--latch_delays: process(clk)
--begin
--	if clk'event and clk='1' then
--		if(L2_trig_one_hot='1') then
--			for i in 0 to 15 loop
--				int_delay_o(i)<=int_count(i);
--			end loop;
--		end if;
--	end if;
--end process;
--aggregate_delays: process(active_counts)
--begin
--for i in 0 to 15 loop
--	delay_o( i*4+3 downto i*4)<=int_delay_o(i);
--end loop;
--
--end process;

-- scalers: right now simply a 1-shot version of L2 and global triggers.

scal_trig_o<=L2_trig_one_hot;
trig_o<=L2_trig_one_hot; -- now the trigger is identical with the one-hot


scal_L2_5_o<=L2_5_trig_one_hot;
-- Version 1 only : intermediate scalers
--generate_trig_L1_onehot: process(L1_trig_delayed, L1_trig)
--begin
--for i in 0 to 15 loop
--if L1_trig_delayed(i)='0' and L1_trig(i) ='1' then
--			scal_l1_o(i)<='1';
--		else
--			scal_l1_o(i)<='0';
--	end if;
--end loop;
--
--end process;
-- End Version 1

end Behavioral;

