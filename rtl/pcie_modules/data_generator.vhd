----------------------------------------------------------------------------------
-- Company: WIPAC
-- Engineer: Thomas Meures (meures@icecube.wisc.edu)
-- 
-- Create Date:    09:51:34 10/07/2015 
-- Design Name: 	
-- Module Name:    data_generator - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: This is used to set up and debug the PCIE interface for the ATRI core. 
--					 The module generates data and should look like the ev_interface_io signal to the pcie interface.
--					 The module should be excluded from the design once the debugging stage is surpassed.
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity data_generator is
    Port ( clk_i : in  STD_LOGIC;
           reset_i : in  STD_LOGIC;
           wr_en_o : out  STD_LOGIC;
           data_o : out  STD_LOGIC_VECTOR (15 downto 0);
           fifo_full_i : in  STD_LOGIC;
			  wr_count : in STD_LOGIC_VECTOR(15 DOWNTO 0);
			  ev_length_cpu_i : in STD_LOGIC_VECTOR (31 DOWNTO 0)
			  );
end data_generator;







architecture Behavioral of data_generator is

TYPE data_state_type is (RESET, IDLE, WRITE_HEADER1, WRITE_HEADER2, WRITE_HEADER3, WRITE_HEADER4, GENERATING);

SIGNAL data_state : data_state_type;
SIGNAL start_generating : STD_LOGIC;
SIGNAL counter : INTEGER;
SIGNAL nwords : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL timer : INTEGER := 0;
begin


	gen_data : process(clk_i, reset_i)
	VARIABLE timer : INTEGER := 0;
	VARIABLE limit : INTEGER;
	VARIABLE wr_count_i : INTEGER := 0;
	VARIABLE even_odd : INTEGER := 0;
	
	begin
			IF(reset_i='0') THEN
				counter <= 0;
				wr_en_o <= '0';
				data_state <= RESET;
				time_limit := 4096;
				wr_count_i := 0;				
			ELSIF(rising_edge(clk_i)) THEN

				wr_count_i := to_integer(unsigned(wr_count));
				
				CASE data_state IS
				WHEN RESET =>
						counter <= 0;
						timer <= 0;
						data_state <= IDLE;
						start_generating <='0';
						limit := 64;
						time_limit := 1024;						
				WHEN IDLE =>
				
						counter <= 0;
				
						timer <= timer + 1;
						IF(timer = time_limit) THEN
							start_generating <='1';
							IF( ev_length_cpu_i = (31 DOWNTO 0 =>'0') )  THEN
								time_limit := 10000000;
							ELSE
								time_limit := to_integer(unsigned(ev_length_cpu_i) );
							END IF;
						END IF;
						
						IF(start_generating='1') THEN
--							IF( ev_length_cpu_i = (31 DOWNTO 0 =>'0') )  THEN
								limit := 1256;
--							ELSE
--								limit := to_integer(unsigned(ev_length_cpu_i) );
--							END IF;
							nwords <= std_logic_vector(to_unsigned(limit + 4, 32));
							data_state <= WRITE_HEADER1;
						ELSE
							data_state <= IDLE;
						END IF;
				WHEN WRITE_HEADER1 =>
					IF(wr_count_i < 65000 - limit) THEN					
						data_o <= ( 0 =>'1', OTHERS =>'0');
						wr_en_o <= '1';
						data_state <= WRITE_HEADER2;
					ELSE
						data_state <= WRITE_HEADER1;
					END IF;
				WHEN WRITE_HEADER2 =>
					data_o <= ( 0 =>'1', OTHERS =>'0');
					wr_en_o <= '1';
					data_state <= WRITE_HEADER3;						
				WHEN WRITE_HEADER3 =>
					data_o <= nwords(31 DOWNTO 16);
					wr_en_o <= '1';
					data_state <= WRITE_HEADER4;
				WHEN WRITE_HEADER4 =>
					data_o <= nwords(15 DOWNTO 0);
					wr_en_o <= '1';
					data_state <= GENERATING;
				WHEN GENERATING =>
					start_generating <= '0';
					timer := 0;
						IF(counter<limit) THEN
							IF(fifo_full_i = '0') THEN
								data_o <= std_logic_vector(to_unsigned(counter, 16));
								counter <= counter + 1;
								wr_en_o <= '1';
							ELSE
								wr_en_o <='0';
							END IF;
						ELSE
							wr_en_o <= '0';
							data_state <= IDLE;
						END IF;
				END CASE;
			END IF;
	end process gen_data;








end Behavioral;

