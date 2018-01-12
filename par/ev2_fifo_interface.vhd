----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:56:22 11/11/2015 
-- Design Name: 
-- Module Name:    ev2_fifo_interface - Behavioral 
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ev2_fifo_interface is
generic
  (
	 EV2IF_SIZE								  : integer		:= 37
  );
    Port ( interface_io : inout  STD_LOGIC_VECTOR (EV2IF_SIZE-1 downto 0);
           irsclk_o : out  STD_LOGIC;
           dat_o : out  STD_LOGIC_VECTOR (15 downto 0);
           count_i : in  STD_LOGIC_VECTOR (15 downto 0);
           wr_o : out  STD_LOGIC;
           full_i : in  STD_LOGIC;
           rst_o : out  STD_LOGIC;
           rst_ack_i : in  STD_LOGIC);
end ev2_fifo_interface;

architecture Behavioral of ev2_fifo_interface is

begin

	 irsclk_o <= interface_io(0);
	 dat_o <= interface_io(16 downto 1);
	 interface_io(32 downto 17) <= count_i;
	 wr_o <= interface_io(33);
	 interface_io(34) <= full_i;
	 rst_o <= interface_io(35);
	 interface_io(36) <= rst_ack_i;

end Behavioral;

