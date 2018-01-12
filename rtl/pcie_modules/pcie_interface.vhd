----------------------------------------------------------------------------------
-- Company: WIPAC
-- Engineer: Thomas Meures
-- 
-- Create Date:    15:44:42 09/08/2015 
-- Design Name: ATRI
-- Module Name:    pcie_interface - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: This module provides an interface between the ATRI event data output and a PCIexpress BMD (Bus Master Device). The input from the ATRI consists 
--						of data, write signals to the FIFO and reset signals. As return it requires the count of free words in the FIFO and reset 
--						ackknowledge signals in case of a reset. All data coming from the ATRI is written to a FIFO in frames of 16 bit words when enough space is available.
--						The frame structure is:
--						Word 0 - 1: 	header: 	Word 0, bits 15-8: Frame type: 0x45, 0x42, 0x46 or 0x4F (for description see includes/araSoft.h)
--														Word 0, bits 7 - 0: Frame count (unused in this module)
--														Word 1: frame length in words (excluding header)
--						Word 2 - ... : data

--						In the FIFO data is packed into 32 bit Dwords. On the readout side the frame header is buffered whenever available and the frame size is recorded. Furthermore
--						a multiplexer of chifted buffers ensures that Word 0 is always in the most significant part of the 32 bit Dword. Whenever a frame is nearly complete in the FIFO
--						and the PCIE line is available for transfer, a state machine "data_pending_state" communicates to the BMD that data is ready to be transferred. It further handles 
--						the communication with the BMD. This transfer is performed in PCIE Transfer Layer Packages of 32 Dwords until a full frame is shipped out. 

--						When a full transfer is completed, several registers are written to, to reset the BMD and to send an interrupt to the DMA on the CPU side of the PCIE bus. The 
--						register write is handled with the "reg_wr_state"The DMA will then proceed to read the data buffer and package it into useful event data.
-- 
--						
--
-- Dependencies: 
--
-- Revision: 1.3
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use IEEE.std_logic_arith.all;

library std;
use std.textio.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
--use IEEE.NUMERIC_BIT.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity pcie_interface is
    Port ( 

				--communication with pcie modules, concerning transfer of the data in the fifo.
				pcie_clk_i 					: in STD_LOGIC;
				pcie_rst_i 					: in STD_LOGIC;
				pcie_ready_for_data_i	: in STD_LOGIC;								--
				tx_to_atri_data_request_i	: in STD_LOGIC;
				data_pending_o 			: out STD_LOGIC;								--wr_en_atri
--				DW_available_o 			: out STD_LOGIC_VECTOR(10 DOWNTO 0);	
				data_to_pcie_o 			: out STD_LOGIC_VECTOR(31 DOWNTO 0);		--mwr_data_atri
				bmd_REG_ADDR_DSRT_o 		: out STD_LOGIC_VECTOR(10 DOWNTO 0);			--req_addr_atri
				bmd_REG_DATA_DSRT_o		: out STD_LOGIC_VECTOR(31 DOWNTO 0);
				bmd_REG_BE_DSRT_o			: out STD_LOGIC_VECTOR(7 DOWNTO 0);
				bmd_REG_wr_en_o			: out STD_LOGIC;
				mwr_len_atri_o			: out STD_LOGIC_VECTOR(31 DOWNTO 0);
				mwr_count_atri_o		: out STD_LOGIC_VECTOR(31 DOWNTO 0);
				mwr_done_to_atri_i	: in STD_LOGIC;
				cur_wr_count_to_atri_i : in STD_LOGIC_VECTOR(15 DOWNTO 0);
				--only for debugging:
				cpld_data_i				: in STD_LOGIC_VECTOR(31 DOWNTO 0);
				debug_o					: out STD_LOGIC_VECTOR(52 downto 0);
				debug_o2					: out STD_LOGIC_VECTOR(52 downto 0);
		ev2_irsclk_i : IN STD_LOGIC;
		ev2_dat_i : IN STD_LOGIC_VECTOR(15 downto 0);
		ev2_count_o : OUT STD_LOGIC_VECTOR(15 downto 0);
		ev2_wr_i : IN STD_LOGIC;
		ev2_full_o : OUT STD_LOGIC;
		ev2_rst_i : IN STD_LOGIC;
		ev2_rst_ack_o : OUT STD_LOGIC
				);
end pcie_interface;

architecture Behavioral of pcie_interface is


--In this component data is imported from interface_io, to be transported to storage over the pcie link.
--Furthermore, data (the number of words, written to the event raedout fifo) is returned to the IP-core.
--COMPONENT ev2_fifo_interface is
--  generic
--  (
--	 EV2IF_SIZE								  : integer		:= 37
--  );
--	PORT(
--		interface_io : INOUT STD_LOGIC_VECTOR(EV2IF_SIZE-1 DOWNTO 0);
--		irsclk_o : OUT STD_LOGIC;
--		count_i : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--		wr_o : OUT STD_LOGIC;
--		dat_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--		full_i : IN STD_LOGIC;
--		rst_o : OUT STD_LOGIC;
--		rst_ack_i : IN STD_LOGIC
--	);
--END COMPONENT;


COMPONENT data_generator is
    Port ( clk_i : in  STD_LOGIC;
           reset_i : in  STD_LOGIC;
           wr_en_o : out  STD_LOGIC;
           data_o : out  STD_LOGIC_VECTOR (15 downto 0);
           fifo_full_i : in  STD_LOGIC;
			  wr_count : in STD_LOGIC_VECTOR(15 DOWNTO 0);
			  ev_length_cpu_i : in STD_LOGIC_VECTOR (31 DOWNTO 0)
			  );
end COMPONENT;

--In this component, the 16bit words from the atri-core are transformed into 32 bit words for the pcie transfer.
--It also monitors the number of words, written to the fifo, to be passed back to the atri core.
COMPONENT data_fifo_to_pcie is
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    rd_data_count : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_data_count : OUT STD_LOGIC_VECTOR(16 DOWNTO 0)
  );
END COMPONENT;


--TYPE data_state_type is (RESET, IDLE, GENERATING);
TYPE data_pending_state_type is (IDLE, BUFFERING_0, BUFFERING_1, BUFFERING_2, RECOVER_START,
											ASSIGN_COUNT, PENDING, PENDING2, SINGLE_TLP_PENDING, MULTIPLE_TLPS_PENDING,
											HOLD1, WRITEREG);

TYPE register_access is (IDLE, WRITE_DMACSR_START, 
											WAIT1, 
											WAIT2, WAIT3, WAIT4, WAIT5, WAIT6, WAIT7, 
											WRITE_DMACSR_DONE, 
											WRITE_DMATLPSIZE, WRITE_DMA_EXTRA_TLPSIZE, WRITE_DMATLPCOUNT);
											
SIGNAL reg_wr_state : register_access;

SIGNAL data_pending_state : data_pending_state_type := IDLE;
SIGNAL data_pending_state_hold : data_pending_state_type := IDLE;

SIGNAL irs_clk : STD_LOGIC;
SIGNAL data : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL wr : STD_LOGIC;
SIGNAL fifo_full : STD_LOGIC;
SIGNAL rst : STD_LOGIC;
SIGNAL rst_ack : STD_LOGIC;
SIGNAL rd_data_count : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL fifo_empty : STD_LOGIC;
SIGNAL fifo_reset : STD_LOGIC;
SIGNAL rd_en : STD_LOGIC;
SIGNAL fifo_data : STD_LOGIC_VECTOR(31 DOWNTO 0);

SIGNAL data_pending : STD_LOGIC;
SIGNAL wr_registers : STD_LOGIC;

SIGNAL mwr_length : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL mwr_count : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL mwr_length_debug : STD_LOGIC_VECTOR(31 DOWNTO 0);

SIGNAL full_rd_count : STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL max_TLP_size : INTEGER;

SIGNAL DW_buf0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DW_buf1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DWodd_buf0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DWodd_buf1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DW_buf_mux : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL DWhalf_buf1 : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL block_rd : STD_LOGIC;

SIGNAL frame_type : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL frame_count : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL nwords : STD_LOGIC_VECTOR(31 DOWNTO 0);
SIGNAL nDWords : STD_LOGIC_VECTOR(31 DOWNTO 0);

SIGNAL shipped_data_counter : INTEGER := 0;
SIGNAL wr_reg_ack : STD_LOGIC;

SIGNAL odd_event_count : STD_LOGIC;	--This counts how many odd events have been transferred.
SIGNAL ev_length_evodd : STD_LOGIC; --This checks, if an evenet has an even number of nowrds or an odd number.

SIGNAL debug1 : STD_logic;
SIGNAL debug2 : STD_logic;

SIGNAL test_buf0 : STD_LOGIC_VECTOR(31 downto 0);
SIGNAL test_buf1 : STD_LOGIC_VECTOR(31 downto 0);

	--First test with still no real connections.
--		SIGNAL ev2_irsclk_o : STD_LOGIC;
--		SIGNAL ev2_count_i : STD_LOGIC_VECTOR(15 DOWNTO 0);
		SIGNAL fifo_wr_count : STD_LOGIC_VECTOR(16 DOWNTO 0);
--		SIGNAL ev2_wr_o : STD_LOGIC;
--		SIGNAL ev2_dat_o : STD_LOGIC_VECTOR(15 DOWNTO 0);
--		SIGNAL fifo_full : STD_LOGIC;
--		SIGNAL ev2_rst_o : STD_LOGIC;
		SIGNAL ev2_rst_ack : STD_LOGIC;


		SIGNAL reset_ack : STD_LOGIC;
		SIGNAL reset_clk_i : STD_LOGIC;
		SIGNAL reset_flag_clk_i : STD_LOGIC;
		SIGNAL PIPE : STD_LOGIC_VECTOR(0 downto 0);
		SIGNAL timeout_reset : STD_LOGIC;

	COMPONENT signal_sync is
		PORT(
			clkA : IN STD_LOGIC;
			clkB : IN STD_LOGIC;
			in_clkA : IN STD_LOGIC;
			out_clkB : OUT STD_LOGIC
		);
		END COMPONENT;
		
		COMPONENT SYNCEDGE is
		GENERIC(
			LATENCY : INTEGER := 1
		);
		PORT(
			I : IN STD_LOGIC;
			O : OUT STD_LOGIC;
			CLK : IN STD_LOGIC;
			PIPE : OUT STD_LOGIC_VECTOR(LATENCY DOWNTO 0)
		);
		END COMPONENT;


begin

   data_pending_o <= data_pending;
	full_rd_count <= rd_data_count(14 downto 0) + ( (14 DOWNTO 2 => '0') & "10" );
	max_TLP_size <= 32;


	irs_clk <= pcie_clk_i;
	




-- RESET MODULES: Copied from phy_bridge/event_readout:

	reset_synchronizer : signal_sync
	PORT MAP(in_clkA => ev2_rst_i,	out_clkB => reset_clk_i,	clkA => ev2_irsclk_i,	clkB => pcie_clk_i	);

	reset_flag : SYNCEDGE
	GENERIC MAP(	LATENCY => 0	)
		PORT MAP(	I => reset_clk_i,	O => reset_flag_clk_i,	CLK => pcie_clk_i, PIPE => PIPE	);

	
	PROCESS(pcie_clk_i)
	variable hold : std_logic:='0';
	BEGIN
		IF(rising_edge(pcie_clk_i) ) THEN
			if (reset_flag_clk_i = '1') THEN 
				reset_ack <= '1';
				hold :='1';
			elsif (reset_ack ='1' and reset_clk_i='0') THEN
				if(hold='1') THEN
					hold :='0';
				else
					reset_ack <= '0';
				end if;
			END IF;
		END IF;
	END PROCESS;
	
	--reset_ack <='1';

	reset_ack_synchronizer : signal_sync
	PORT MAP( in_clkA => reset_ack,	out_clkB => ev2_rst_ack,	clkA => pcie_clk_i,	clkB => ev2_irsclk_i	);

	ev2_rst_ack_o <= ev2_rst_ack;
	ev2_count_o <= not fifo_wr_count(15 downto 0) when fifo_wr_count(16) = '1' else
						"1111111111111111";

----Interface module	
--	ev2_interface_to_pcie : ev2_fifo_interface
--	generic map( EV2IF_SIZE	=> EV2IF_SIZE)
--	PORT MAP(
--		interface_io => ev2_if_io,
--		irsclk_o => ev2_irsclk_o,
--		dat_o => ev2_dat_o,
--		count_i => ev2_count_i,
--		wr_o => ev2_wr_o,
--		full_i => ev2_full_i,
--		rst_o => ev2_rst_o,
--		rst_ack_i => ev2_rst_ack_i
--	);

ev2_full_o <= fifo_full;

--debug_o(52 DOWNTO 37) <= ev2_dat_i;
--debug_o(36 downto 20) <= fifo_wr_count(16 downto 0);
--debug_o(3) <= fifo_full;
--debug_o(2) <= fifo_empty;
--debug_o(1) <= ev2_wr_i;
----
--
--
debug_o2(52 DOWNTO 25) <= DW_buf_mux(27 downto 0);
debug_o2(21) <= ev2_rst_ack;
debug_o2(19) <= pcie_ready_for_data_i;
debug_o2(18) <= data_pending;
debug_o2(24) <= ev2_wr_i;
debug_o2(20) <= fifo_reset;
debug_o2(22) <= reset_ack;
debug_o2(23) <= rd_en;
debug_o2(17 downto 12) <= mwr_length_debug(5 downto 0);
debug_o2(11 downto 0) <= nDWords(11 DOWNTO 0); --- + ( nDWords(16 DOWNTO 1) ) + ( '0' & nDWords(16 DOWNTO 2) ) - cpld_data_i(15 downto 0) );




	fifo_reset <= reset_flag_clk_i or (not pcie_rst_i) or timeout_reset;  --not pcie_rst_i;
	--This component generates data for debugging. It should look like the ev_interface_io.
--	DEBUG_INTERFACE : data_generator
--    PORT MAP ( clk_i => irs_clk,
--           reset_i => pcie_rst_i,
--           wr_en_o => wr,
--           data_o => data,
--           fifo_full_i =>fifo_full,
--			  wr_count => fifo_wr_count,
--			  ev_length_cpu_i => cpld_data_i
--			  );


	DW_buf_mux <= DW_buf0 when odd_event_count = '0' else
					  DWodd_buf0;



	
	--FIXME: A problem with this constellation: This only works with an even number of input words. Otherwise the last word will be stuck and read for the next event!
	--1) Either add a "0" word, in case an uneven number has been written
	--2) Loos the last word...
	U0 : data_fifo_to_pcie
	PORT MAP (
		rst => fifo_reset,					--fifo_reset,
		wr_clk => ev2_irsclk_i,						--irs_clk,
		rd_clk => pcie_clk_i,
		din => ev2_dat_i,								--data,
		wr_en => ev2_wr_i,							--wr,
		rd_en => ((rd_en or tx_to_atri_data_request_i) and not block_rd),    --tx_to_atri_data_request_i,
--		dout(31 DOWNTO 24) => data_to_pcie_o(7 DOWNTO 0),
--		dout(23 DOWNTO 16) => data_to_pcie_o(15 DOWNTO 8),
--		dout(15 DOWNTO 8) => data_to_pcie_o(23 DOWNTO 16),
--		dout(7 DOWNTO 0) => data_to_pcie_o(31 DOWNTO 24),
		dout => fifo_data,
		full => fifo_full,							--fifo_full,
		empty => fifo_empty,
		rd_data_count => rd_data_count,
		wr_data_count => fifo_wr_count				--wr_count
	);

	--Manage the data pending status and send out the right TLP size/count to the TX engine. 
	--Then, if it is the last TLP, assert writing to the registers (another process).
	PROCESS(fifo_reset, pcie_clk_i)
		VARIABLE rd_count_wait : INTEGER := 0;
		VARIABLE check_rd_count : INTEGER := 0;
		VARIABLE wr_ack_buffer : STD_LOGIC;
		VARIABLE timeout_counter1 : INTEGER := 0;
		VARIABLE timeout_counter2 : INTEGER := 0;
--		VARIABLE shipped_data_counter : INTEGER := 0;
	BEGIN
		IF(fifo_reset='1') THEN
			timeout_reset <='0';
			data_pending <= '0';
			wr_registers <='0';
			data_pending_state <= IDLE;
			mwr_length <= (OTHERS =>'0');
			mwr_count <= (OTHERS =>'0'); 
			rd_en <='0';
			shipped_data_counter <= 0;
			DW_buf1 <= (others=>'0');
			DW_buf0 <= (others=>'0');
			DWodd_buf0 <= (others=>'0');
			DWhalf_buf1 <= (others=>'0');
			nwords <= (others=>'0');
			nDWords <=(others=>'0');
			block_rd <= '0';
			odd_event_count <= '0';
			ev_length_evodd <= '0';
			debug1 <='0';
			wr_ack_buffer := '0';
--			rd_count_wait := 0;
		ELSIF(rising_edge(pcie_clk_i) ) THEN
			--We want the rounded up half wr_count. Ok to use for now, since nothing has been read yet. We might have to change that to the read count, in case things become more complicated.
			--This has the advantage that we save a few clock cycles, which we had to wait for the rd_count to complete do to the difference in size of din and dout at the FIFO.
			--FIXME: The above is obsolete, since odd numbers of 16 bit words are not read properly.
			--FIXME: wr_count is two counts short due to the first word fall through.


			if(wr_reg_ack='1') THEN
				wr_ack_buffer := '1';
			END IF;


			data_to_pcie_o(7 DOWNTO 0) <= DW_buf_mux(31 DOWNTO 24);
			data_to_pcie_o(15 DOWNTO 8) <= DW_buf_mux(23 DOWNTO 16);
			data_to_pcie_o(23 DOWNTO 16) <= DW_buf_mux(15 DOWNTO 8);
			data_to_pcie_o(31 DOWNTO 24) <= DW_buf_mux(7 DOWNTO 0);

			IF( (rd_en = '1' or tx_to_atri_data_request_i = '1') and not (block_rd = '1') ) THEN
				DW_buf1 <= fifo_data;
				DW_buf0 <= DW_buf1;			
				DWhalf_buf1 <= fifo_data(15 Downto 0);
				DWodd_buf1 <= DWhalf_buf1 & fifo_data(31 downto 16);
				DWodd_buf0 <= DWodd_buf1;
			END IF;

			
			CASE data_pending_state IS
			when IDLE =>
				timeout_counter1 := timeout_counter1+1;
				IF(timeout_counter1 = 1000000) THEN
					timeout_counter2 := timeout_counter2+1;
					timeout_counter1 :=0;
				END IF;
				wr_ack_buffer :='0';
				shipped_data_counter <= 0;
				IF(fifo_empty='0' and ( full_rd_count > "000000000000011" ) ) THEN			--just not empty and at least the header information! Probably the rd_count  more than : this is relatively random for now...	
					rd_en <='1';
					data_pending_state <= BUFFERING_0;
				ELSIF(timeout_counter2=500) THEN
					timeout_reset <='1';
					timeout_counter2 :=0;
				ELSE
					data_pending_state <= IDLE;
				END IF;
				data_pending <='0';
				wr_registers <='0';
				block_rd <= '0';
				ev_length_evodd <= '0';
--			when WAITING_FOR_FIFO =>
----				if(  (DW_buf1(31 downto 28)="0100" or DWodd_buf1(31 downto 28)="0100") ) THEN --FIXME:this is new
----					rd_en <='0';--FIXME:this is new
--					data_pending_state <= BUFFERING_0;
----				END IF;--FIXME:this is new
				
			when BUFFERING_0 =>
				test_buf0 <= DW_buf_mux;
				test_buf1 <= test_buf0;
				IF( (odd_event_count='0' and not ( DW_buf1 = (31 downto 0 =>'0') ) ) or (odd_event_count='1' and not ( DWodd_buf1 = (31 downto 0 =>'0') ) )  ) THEN
					rd_en <= '0';
					data_pending_state <= BUFFERING_1;
				ELSE
					rd_en <= '1';
					data_pending_state <= BUFFERING_0;
				END IF;
				
			when RECOVER_START =>
					rd_en <='0';
					data_pending_state <= BUFFERING_1;
				
			when BUFFERING_1 =>
				data_pending_state <= BUFFERING_2;

			when BUFFERING_2 =>
				data_pending_state <= ASSIGN_COUNT;
				
			when ASSIGN_COUNT =>
				IF( ( DW_buf_mux(31 downto 24) = "01000101" ) or ( DW_buf_mux(31 downto 24) = "01000010" ) or ( DW_buf_mux(31 downto 24) = "01000110" ) or ( DW_buf_mux(31 downto 24) = "01001111" ) ) THEN
					wr_ack_buffer :='0';
					shipped_data_counter <= 0;
					frame_type <= (7 downto 0 =>'0') & DW_buf_mux(31 Downto 24);
					frame_count <= (7 downto 0 =>'0') & DW_buf_mux(23 Downto 16);
					nwords <= ( (15 DOWNTO 0 =>'0') & DW_buf_mux(15 DOWNTO 0) ) + ( (29 DOWNTO 0 =>'0') & "10" );
					nDWords <= ( (15 DOWNTO 0 =>'0') & '0' & DW_buf_mux(15 DOWNTO 1) ) + ( (30 DOWNTO 0 =>'0') & '1' );
					ev_length_evodd <= DW_buf_mux(0);
					mwr_length <= (31 DOWNTO 5 =>'0') & ( DW_buf_mux(5 DOWNTO 1) + ("00001") + ("0000" & DW_buf_mux(0)) );			--This goes at max to 31
					mwr_count <=  (31 DOWNTO 10 =>'0') & (DW_buf_mux(15 DOWNTO 6) + "0000000001");
					mwr_count_atri_o <=  (31 DOWNTO 10 =>'0') & (DW_buf_mux(15 DOWNTO 6) + "0000000001");
					check_rd_count := to_integer( unsigned(nDWords) );
					IF(pcie_ready_for_data_i='1') THEN
						data_pending_state <= PENDING;
					ELSE
						data_pending_state <= ASSIGN_COUNT;					
					END IF;
				ELSE
					rd_en <='1';
					data_pending_state <= RECOVER_START;
				END IF;
			when PENDING =>
				IF( mwr_count > ((31 DOWNTO 1 => '0') &'1') ) THEN
					mwr_len_atri_o <= (5 =>'1', OTHERS =>'0');
					mwr_length_debug <= (5 =>'1', OTHERS =>'0');
				ELSE
					mwr_len_atri_o <= (31 DOWNTO 6 =>'0') & nDWords(5 DOWNTO 0);
					mwr_length_debug <= (31 DOWNTO 6 =>'0') & nDWords(5 DOWNTO 0);
				END IF;

				IF(fifo_wr_count > ( nDWords(16 DOWNTO 0) + ('0' & nDWords(16 DOWNTO 1) ) + ( "00" & nDWords(16 DOWNTO 2) ) - cpld_data_i(16 downto 0) ) ) THEN
					data_pending_state <=PENDING2;
				ELSE
					data_pending_state <= PENDING;				
				END IF;



			when PENDING2 =>
					data_pending <='1';
					IF( mwr_count > ((31 DOWNTO 1 => '0') &'1') ) THEN
						data_pending_state <= MULTIPLE_TLPS_PENDING;
					ELSE
						data_pending_state <= SINGLE_TLP_PENDING;
					END IF;
				

			when SINGLE_TLP_PENDING =>
				data_pending <='0';
				wr_registers <='1';
				if(tx_to_atri_data_request_i = '1') THEN
					shipped_data_counter <= shipped_data_counter + 1;
				END IF;
				data_pending_state <= WRITEREG;
			

			when MULTIPLE_TLPS_PENDING =>
				data_pending <='1';
				if(tx_to_atri_data_request_i = '1') THEN
					shipped_data_counter <= shipped_data_counter + 1;
				END IF;

				IF(tx_to_atri_data_request_i='1' and cur_wr_count_to_atri_i = mwr_count(15 DOWNTO 0) - "0000000000000010") THEN
					IF( mwr_length(4 DOWNTO 0) = "00000") THEN
						mwr_len_atri_o <= (5 =>'1', OTHERS =>'0');
						mwr_length_debug  <= (5 =>'1', OTHERS =>'0');
					ELSE
						mwr_len_atri_o <= mwr_length;
						mwr_length_debug <= mwr_length;
					END IF;
				END IF;

				IF(tx_to_atri_data_request_i='0' and cur_wr_count_to_atri_i = mwr_count(15 DOWNTO 0) - "0000000000000001") THEN
					data_pending_state <= SINGLE_TLP_PENDING;
				END IF;	
				
			when WRITEREG =>
				wr_registers <='0';
				if(tx_to_atri_data_request_i = '1') THEN
					shipped_data_counter <= shipped_data_counter + 1;
				END IF;

				IF(shipped_data_counter = (to_integer( unsigned(nDWords) ) - 1) ) THEN
					IF(ev_length_evodd='1' and odd_event_count='1') THEN
						block_rd <='1';
					END IF;
					data_pending_state <= WRITEREG;
				ELSIF(shipped_data_counter = to_integer( unsigned(nDWords) ) ) THEN
					odd_event_count <= ev_length_evodd XOR odd_event_count;
					block_rd <='0';
					data_pending_state <= HOLD1;
				ELSE
					data_pending_state <= WRITEREG;
				END IF;			

			when HOLD1 =>		
				if(wr_ack_buffer='1') THEN
					IF(fifo_empty = '0') THEN -- and (DWodd_buf0(31 downto 28) = "0100" or DW_buf0(31 downto 28) = "0100")) THEN  --FIXME:this is new
						data_pending_state <= RECOVER_START; --ASSIGN_COUNT;	--FIXME: This is a test!
					ELSE
						data_pending_state <= IDLE;
						debug1 <='1';
					END IF;
					wr_ack_buffer :='0';
				ELSE
					data_pending_state <= HOLD1;
				END IF;

				
			END CASE;
		END IF;
	END PROCESS;




	PROCESS(fifo_reset, pcie_clk_i)
		VARIABLE wait_counter : INTEGER;
		VARIABLE mwr_done_buffer : STD_LOGIC;
		VARIABLE mwr_reg_buffer : STD_LOGIC;
	BEGIN
		IF(fifo_reset='1') THEN
			reg_wr_state <= IDLE;
			bmd_REG_ADDR_DSRT_o 	<= (OTHERS =>'0');
			bmd_REG_DATA_DSRT_o 	<= (OTHERS => '0');
			bmd_REG_BE_DSRT_o 	<= (OTHERS =>'0');
			bmd_REG_wr_en_o <='0';
			wait_counter := 0;
			mwr_done_buffer := '0';
			mwr_reg_buffer := '0';
			wr_reg_ack <='0';
		ELSIF(rising_edge(pcie_clk_i) ) THEN
		
			if(mwr_done_to_atri_i = '1') THEN
				mwr_done_buffer :='1';
			END if;
		
			if(wr_registers='1') THEN
				mwr_reg_buffer :='1';
				wr_reg_ack <='0';
			END IF;
		
			CASE reg_wr_state IS
			when IDLE =>
				bmd_REG_wr_en_o <='0';
				wait_counter := 0;
				wr_reg_ack <='0';
				if(mwr_reg_buffer='1') THEN
					--writing DMA write_start low, the TLP-size and the TLP-count
					bmd_REG_ADDR_DSRT_o 	<= (0 =>'1', OTHERS =>'0');
					bmd_REG_DATA_DSRT_o 	<= (OTHERS => '0');
					bmd_REG_BE_DSRT_o 	<= (0 => '1', OTHERS =>'0');
					reg_wr_state <= WRITE_DMACSR_START;
				ELSIF(mwr_done_buffer = '1') THEN
					--writing DMA write_done high
					bmd_REG_ADDR_DSRT_o 	<= (0 =>'1', OTHERS =>'0');
					bmd_REG_DATA_DSRT_o 	<= (16 =>'1', OTHERS => '0');
					bmd_REG_BE_DSRT_o 	<= (1 => '1', OTHERS =>'0');
					reg_wr_state <= WRITE_DMACSR_DONE;
				END IF;
				
			when WRITE_DMACSR_DONE =>
					bmd_REG_wr_en_o <='1';
					mwr_done_buffer := '0';
					reg_wr_state <= WAIT1;			
			when WAIT1 =>
					wait_counter := wait_counter +1;
					if(wait_counter = 3) THEN
						bmd_REG_wr_en_o <='0';
						reg_wr_state <= IDLE;
					END IF;					
			when WRITE_DMACSR_START =>
					bmd_REG_wr_en_o <='1';
					mwr_reg_buffer := '0';
					wait_counter := wait_counter +1;
					if(wait_counter = 3) THEN
						reg_wr_state <= WAIT2;
					END IF;
			when WAIT2 =>
					bmd_REG_wr_en_o <='0';
					wait_counter := 0;
					reg_wr_state <= WRITE_DMATLPSIZE;
			when WRITE_DMATLPSIZE =>
					--Write TLP size to register
					IF(mwr_count > ((31 DOWNTO 1 => '0') &'1') ) THEN
						bmd_REG_DATA_DSRT_o 	<= "00100000" & "00000000" & "00000000" & "00000000"; --This is 32 in the necessary byte order
					ELSE
						bmd_REG_DATA_DSRT_o 	<= mwr_length(7 DOWNTO 0) & mwr_length(15 DOWNTO 8) & mwr_length(23 DOWNTO 16) & mwr_length(31 DOWNTO 24);
					END IF;
					bmd_REG_ADDR_DSRT_o 	<= (0 =>'1', 1=>'1', OTHERS =>'0');
					bmd_REG_BE_DSRT_o 	<= (0 => '1', 1 =>'1', OTHERS =>'0');
					reg_wr_state <= WAIT3;
					
			when WAIT3 =>
					bmd_REG_wr_en_o<='1';
					wait_counter := wait_counter +1;
					if(wait_counter = 3) THEN					
						reg_wr_state <= WAIT4;
					END IF;
			when WAIT4 =>
					bmd_REG_wr_en_o <='0';
					wait_counter := 0;
					reg_wr_state <= WRITE_DMA_EXTRA_TLPSIZE;
			when WRITE_DMA_EXTRA_TLPSIZE =>
					--Write size of last TLP to register:
					bmd_REG_ADDR_DSRT_o 	<= (0 =>'1', 2 =>'1', OTHERS =>'0');
					bmd_REG_DATA_DSRT_o 	<= nwords(7 DOWNTO 0) & nwords(15 DOWNTO 8) & nwords(23 DOWNTO 16) & nwords(31 DOWNTO 24);
					bmd_REG_BE_DSRT_o 	<= (0 => '1', 1 =>'1', OTHERS =>'1');
					reg_wr_state <= WAIT5;
					
			when WAIT5 =>
					bmd_REG_wr_en_o<='1';
					wait_counter := wait_counter +1;
					if(wait_counter = 3) THEN
						
						reg_wr_state <= WAIT6;
					END IF;
			when WAIT6 =>
					bmd_REG_wr_en_o <='0';
					wait_counter := 0;
					reg_wr_state <= WRITE_DMATLPCOUNT;
			when WRITE_DMATLPCOUNT =>
					--Write the TLP count to register
					bmd_REG_ADDR_DSRT_o 	<= (2 =>'1', OTHERS =>'0');
					bmd_REG_DATA_DSRT_o 	<= mwr_count(7 DOWNTO 0) & mwr_count(15 DOWNTO 8) & mwr_count(23 DOWNTO 16) & mwr_count(31 DOWNTO 24);
					bmd_REG_BE_DSRT_o 	<= (0 => '1', 1 =>'1', OTHERS =>'0');
					reg_wr_state <= WAIT7;
			when WAIT7 =>
					bmd_REG_wr_en_o <='1';
					wait_counter := wait_counter +1;
					if(wait_counter = 3) THEN
						reg_wr_state <= IDLE;
						wr_reg_ack <='1';
					END IF;
			END CASE;
		END IF;
	END PROCESS;
				
end Behavioral;

