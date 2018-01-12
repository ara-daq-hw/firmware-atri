----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:18:20 08/31/2011 
-- Design Name: 
-- Module Name:    slef_trigger_top - Behavioral 
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity self_trigger_top is
    Port ( clk : in  STD_LOGIC;
           trig_in1 : in  STD_LOGIC_VECTOR (3 downto 0);
		     trig_in2 : in  STD_LOGIC_VECTOR (3 downto 0);
	   	  trig_in3 : in  STD_LOGIC_VECTOR (3 downto 0);
			  trig_in4 : in  STD_LOGIC_VECTOR (3 downto 0);
           trig_o : out  STD_LOGIC;
           scal_trig_o : out  STD_LOGIC;
-- Version 1
--           scal_l1_o : out  STD_LOGIC_VECTOR (15 downto 0);
-- Version 2
			  scal_L2_5_o : out  STD_LOGIC_VECTOR (1 downto 0);
--           delay_o : out  STD_LOGIC_VECTOR (63 downto 0);
			  trig_info_o : out STD_LOGIC_VECTOR (31 downto 0);
			  disable_i : in STD_LOGIC;
			  L2_5_trig_debug_o : out STD_LOGIC_VECTOR (1 downto 0);
			  debug_trig_int : out STD_LOGIC;
			  debug_en_trig : out STD_LOGIC
			  );
end self_trigger_top;

architecture Behavioral of self_trigger_top is

--constant inhibit : integer := 10; -- 10 cycles * 10ns = 100 ns
--constant inhibit : integer := 100000; -- 100000 cycles * 10ns = 1 ms
		-- currently max inhibit = 1024*128 - 1.31 ms.
constant inhibit : integer := 200; -- 200 cycles * 10ns = 2 us


component self_trigger_logic is
    Port ( clk : in  STD_LOGIC;
           active : in  STD_LOGIC_VECTOR (15 downto 0);
           active_counts : in  STD_LOGIC_VECTOR (63 downto 0);
           trig_o : out  STD_LOGIC;
           scal_trig_o : out  STD_LOGIC;
-- Version 1
--           scal_l1_o : out  STD_LOGIC_VECTOR (15 downto 0);
-- Version 2
			  scal_L2_5_o : out  STD_LOGIC_VECTOR (1 downto 0);
			  L2_5_trig_debug_o : out STD_LOGIC_VECTOR (1 downto 0));
--           delay_o : out  STD_LOGIC_VECTOR (63 downto 0));
end component;
component coincidence_cnt is
	generic ( LIMIT : integer := 15);
    Port ( clk : in  STD_LOGIC;
           trig_in : in  STD_LOGIC;
           count_active : out  STD_LOGIC;
           count : out  STD_LOGIC_VECTOR (3 downto 0));
end  component;

signal  active : STD_LOGIC_VECTOR (15 downto 0);
signal  active_counts :   STD_LOGIC_VECTOR (63 downto 0);
signal  trig_int, trig_enabled : STD_LOGIC;
signal  en_trig : STD_LOGIC := '1';
signal inhibit_count : STD_LOGIC_VECTOR (16 downto 0);
begin


u0: for i in 0 to 3 generate
coincs : coincidence_cnt generic map (15) 
								port map(
							clk => clk,
           trig_in => trig_in1(i),
           count_active => active(i),
           count   => active_counts(i*4+3 downto i*4)  							
								);
end generate;

u1: for i in 0 to 3 generate
coincs : coincidence_cnt generic map (15) 
								port map(
							clk => clk,
           trig_in => trig_in2(i),
           count_active => active(i+4),
           count   => active_counts(i*4+3+16 downto i*4+16)  							
								);
end generate;
u2: for i in 0 to 3 generate
coincs : coincidence_cnt generic map (15) 
								port map(
							clk => clk,
           trig_in => trig_in3(i),
           count_active => active(i+8),
           count   => active_counts(i*4+3+32 downto i*4+32)  							
								);
end generate;
u3: for i in 0 to 3 generate
coincs : coincidence_cnt generic map (15) 
								port map(
							clk => clk,
           trig_in => trig_in4(i),
           count_active => active(i+12),
           count   => active_counts(i*4+3+48 downto i*4+48)  							
								);
end generate;
u5: self_trigger_logic port map(
	clk => clk,
   active =>active,
   active_counts => active_counts,
   trig_o => trig_int,
   scal_trig_o => scal_trig_o,
-- Version 1
--   scal_l1_o => scal_l1_o,
-- Version 2
	scal_L2_5_o => scal_L2_5_o,
	L2_5_trig_debug_o => L2_5_trig_debug_o);
--   delay_o => delay_o);

process(clk)
begin
if(clk'event and clk='1') then
	trig_enabled<='0';
	if en_trig = '1' and trig_int='1' and disable_i='0' then
		trig_enabled<='1';
		en_trig<='0';
		inhibit_count<=(others => '0');
	end if;
	if en_trig = '0' then
		if inhibit_count < inhibit then
			inhibit_count <= inhibit_count + 1;
		else
			inhibit_count<=(others => '0');
			en_trig<='1';
		end if;
	end if;
end if;
end process;
	
process(clk)
begin
if(clk'event and clk='1') then
		if(trig_enabled='1') then
			trig_info_o(15 downto 0)<=active;
			trig_info_o(31 downto 15)<=(others =>'0');
		end if;
end if;
end process;

trig_o <= trig_enabled;

debug_trig_int <=trig_int;
debug_en_trig <= en_trig;

end Behavioral;

