---------------------------------------------------------------
-- 
-- (C) 2011 Thomas Meures 
-- Universite Libre de Bruxelles
-- Service de physique des particules elementaires
-- 
-- Create Date:     
-- Design Name: 
-- Module Name:     ara_trigger_readout
-- Project Name: 
-- Target Devices:  Spartan-3AN / Spartan-6
-- Tool versions:   ISE 13.1 (Win7 64-bit)
-- Description:  		This module is the top level entity, bringing 
--							together different functionalities. It processes 
--							all incoming trigger signals, communicates with
--					 		the history-buffer and the block-manager, to 
--							lock/free the needed blocks and handles the actual 
--							digitization and readout of the data.
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
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE work.all;
USE work.new_data_types.all;

ENTITY ara_trigger_readout IS
	GENERIC (n_triggers : INTEGER := 3; 
				STACK_NUMBER : INTEGER := 0;
				EADDR_WIDTH : INTEGER := 9);
	PORT(	SIGNAL clock : IN STD_LOGIC;
			SIGNAL reset : IN STD_LOGIC;
			SIGNAL gps_pps : IN STD_LOGIC;

			SIGNAL readout_delay : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL trigger_processed : IN STD_LOGIC;
			SIGNAL full_triggers : IN STD_LOGIC_VECTOR(n_triggers DOWNTO 0);
			
--	The following signals have to be provided by the system configuration and the 
-- different triggers/filters in the ARA hardware/firmware.
--			SIGNAL trigger_i : IN STD_LOGIC_VECTOR(n_triggers-2 DOWNTO 0) :="00";				-- any physics-trigger signal
--			SIGNAL cpu_trigger_i : IN STD_LOGIC := '0';													-- a cpu/software trigger
--			SIGNAL cal_trigger_i : IN STD_LOGIC := '0';													-- a trigger for calibration measurements
--			SIGNAL pre_trigger_length_i : IN STD_LOGIC_VECTOR( (n_triggers+1)*4-1 DOWNTO 0);			
--			SIGNAL trigger_delay_i :  IN STD_LOGIC_VECTOR( (n_triggers+1)*4-1 DOWNTO 0);

-- These signals are for communication with the HISTORY_BUFFER and the BLOCK_MANAGER
			SIGNAL nprev_o_to_history_buffer : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL req_o_to_history_buffer : OUT STD_LOGIC;
			SIGNAL block_i_from_history_buffer : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL lock_address_o_to_block_manager : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL lock_o_to_block_manager : OUT STD_LOGIC;
			SIGNAL unlock_o_to_block_manager : OUT STD_LOGIC;--LM added to allow sim. lock and unlock
			SIGNAL lock_strobe_o_to_block_manager : OUT STD_LOGIC;
			SIGNAL free_address_o_to_block_manager : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL free_strobe_o_to_block_manager : OUT STD_LOGIC;
			ack_i_from_history_buffer : IN STD_LOGIC;
			free_ack_i_from_block_manager : IN STD_LOGIC;
			lock_ack_i_from_block_manager : IN STD_LOGIC;			

			SIGNAL read_address_o : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			SIGNAL trig_pat_o : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			SIGNAL read_strobe_to_irs_block_readout : OUT STD_LOGIC;
			SIGNAL read_remaining_to_irs_block_readout : OUT STD_LOGIC;
			SIGNAL read_remaining_strobe_to_irs_block_readout : OUT STD_LOGIC;
			read_done_from_irs_block_readout : IN STD_LOGIC;
		   state_rdout_queue_debug_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0)
	  		
-- These signals are for the actual data digitization/readout from the chip:			
--			SIGNAL irs_samp_o        : out std_logic_vector(5 downto 0);
--			SIGNAL irs_smpall_o        : out std_logic;
--			SIGNAL irs_ch_o          : out std_logic_vector(2 downto 0);
--			SIGNAL irs_data_i        : in std_logic_vector(11 downto 0);
--			SIGNAL irs_block_addr	: out std_logic_vector(9 downto 0);
--			SIGNAL irs_read_ena_o    : out std_logic;
--			SIGNAL irs_ramp_o        : out std_logic;
--			SIGNAL irs_tdc_start_o   : out std_logic;
--			SIGNAL irs_tdc_clear_o   : out std_logic;

--       event_interface_io       : inout std_logic_vector(43 downto 0)
			);
END ara_trigger_readout;
  
ARCHITECTURE behavior OF ara_trigger_readout IS

--SIGNAL xpre_trigger_length : VECTOR_ARRAY(0 TO n_triggers);			
--SIGNAL xtrigger_delay : VECTOR_ARRAY(0 TO n_triggers);

--SIGNAL readout_delay : STD_LOGIC_VECTOR(8 DOWNTO 0);
--SIGNAL trigger_processed : STD_LOGIC;
--SIGNAL full_triggers : STD_LOGIC_VECTOR(n_triggers DOWNTO 0);
--SIGNAL priority_trigger1 : INTEGER RANGE -1 TO n_triggers;
--SIGNAL readout_samples : STD_LOGIC_VECTOR(4 DOWNTO 0);
SIGNAL read_address : STD_LOGIC_VECTOR((15 + n_triggers + 1 + 8) DOWNTO 0);
SIGNAL write_to_readout_queue : STD_LOGIC;


--SIGNAL ena : STD_LOGIC;
SIGNAL regcea : STD_LOGIC;
SIGNAL wea : STD_LOGIC_VECTOR(0 DOWNTO 0);
SIGNAL addra : STD_LOGIC_VECTOR(8 DOWNTO 0);
SIGNAL dina : STD_LOGIC_VECTOR(35 DOWNTO 0);
SIGNAL douta : STD_LOGIC_VECTOR(35 DOWNTO 0);

--SIGNAL enb : STD_LOGIC;
SIGNAL regceb : STD_LOGIC;
SIGNAL web : STD_LOGIC_VECTOR(0 DOWNTO 0);
SIGNAL addrb : STD_LOGIC_VECTOR(8 DOWNTO 0);
SIGNAL dinb : STD_LOGIC_VECTOR(35 DOWNTO 0);
SIGNAL doutb : STD_LOGIC_VECTOR(35 DOWNTO 0);
SIGNAL xgps_count : STD_LOGIC_VECTOR(5 DOWNTO 0);
SIGNAL xregister_timestamp : STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL xcommon_timestamp : STD_LOGIC_VECTOR(32	DOWNTO 0);
SIGNAL free_address_to_readout_comm : STD_LOGIC_VECTOR(8 DOWNTO 0);
SIGNAL block_time : STD_LOGIC_VECTOR(47 DOWNTO 0);

SIGNAL read_block_to_irs_block_readout : STD_LOGIC_VECTOR(34 DOWNTO 0);

SIGNAL readout_ack : STD_LOGIC;

SIGNAL roll_over : INTEGER RANGE 0 TO 1;


--SIGNAL fifo_clock : STD_LOGIC;
--SIGNAL event_clkout : STD_LOGIC;
--SIGNAL fifo_write : STD_LOGIC;
--SIGNAL fifo_full : STD_LOGIC;
--SIGNAL event_write_done : STD_LOGIC;
--SIGNAL fifo_data : STD_LOGIC_VECTOR(15 downto 0);
--SIGNAL fifo_unused : STD_LOGIC_VECTOR(18 downto 0);
--	COMPONENT trigger_handling IS
--	GENERIC( n_triggers : INTEGER :=3);
--	PORT( clk : IN STD_LOGIC;
--			reset : IN STD_LOGIC;
--			physics_trigger_in : IN STD_LOGIC_VECTOR (n_triggers-2 DOWNTO 0);
--			cal_trigger_in : IN STD_LOGIC;
--			cpu_trigger_in : IN STD_LOGIC;
--			pre_trigger_length : IN VECTOR_ARRAY(0 TO n_triggers);
--			trigger_delay : IN VECTOR_ARRAY(0 TO n_triggers);			
----			readout_length : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
--			trigger_combined : OUT STD_LOGIC;
--			trigger_in : OUT STD_LOGIC_VECTOR(n_triggers DOWNTO 0);
--			trigger_delay_o : OUT STD_LOGIC_VECTOR(8 DOWNTO 0)
----			priority_trigger : BUFFER INTEGER RANGE -1 TO n_triggers
--	);
--	END COMPONENT;

COMPONENT readout_comm_state_machine_v2 IS
	GENERIC( n_triggers : INTEGER := 3);
PORT(
			clk : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			readout_delay : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			trigger_processed : IN STD_LOGIC;
			full_triggers : IN STD_LOGIC_VECTOR(n_triggers DOWNTO 0);

			nprev_i_to_history_buffer : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			req_o_to_history_buffer : OUT STD_LOGIC;
			history_ack_i : IN STD_LOGIC;
			block_o_from_history_buffer : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			lock_address_to_block_manager : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			lock_to_block_manager : OUT STD_LOGIC;
			unlock_to_block_manager : OUT STD_LOGIC; --LM added - see above
			lock_strobe_to_block_manager : OUT STD_LOGIC;
			lock_ack_i : IN STD_LOGIC;
			free_address_to_block_manager : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			free_strobe_to_block_manager : OUT STD_LOGIC;
			free_ack_i : IN STD_LOGIC;

			register_timestamp_from_time_stamping : IN STD_LOGIC_VECTOR(14 DOWNTO 0);			

			read_address_to_readout_queue : OUT STD_LOGIC_VECTOR( (15 + n_triggers + 1 + 8) DOWNTO 0);
			wea_to_readout_queue : OUT STD_LOGIC;
			readout_done : IN STD_LOGIC;
			free_address_from_readout_queue : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			readout_ack_o : OUT STD_LOGIC
);
END COMPONENT;

COMPONENT readout_queue_frame_v2 IS
	GENERIC( n_triggers : INTEGER := 3);
PORT( clk: IN STD_LOGIC;
		reset : IN STD_LOGIC;
		read_address_from_readout_comm : IN STD_LOGIC_VECTOR( (15 + n_triggers + 1 + 8) DOWNTO 0);
		wea_from_readout_comm : IN STD_LOGIC;
		read_block_to_irs_block_readout : OUT STD_LOGIC_VECTOR(34 DOWNTO 0);
		read_strobe_to_irs_block_readout : OUT STD_LOGIC;
		read_remaining_to_irs_block_readout : OUT STD_LOGIC;
		read_remaining_strobe_to_irs_block_readout : OUT STD_LOGIC;
		read_done_from_irs_block_readout : IN STD_LOGIC;
		free_address_to_irs_block_manager : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
		state_rdout_queue_debug_o : OUT STD_LOGIC_VECTOR(2 DOWNTO 0)

--		readout_ack_i : IN STD_LOGIC
		);
END COMPONENT;

COMPONENT time_stamping IS
PORT( clk : IN STD_LOGIC;
		reset : IN STD_LOGIC;
		gps_pps : IN STD_LOGIC;
		gps_count : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
		register_timestamp : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
		common_timestamp : OUT STD_LOGIC_VECTOR(32 DOWNTO 0)
		);
END COMPONENT;

--COMPONENT event_interface_irs is
--	port (
--      interface_io       : inout std_logic_vector(39 downto 0);
--		fifo_clk_o			 : out std_logic;
--		irs_clk_i			 : in std_logic;
--		fifo_full_o			 : out std_logic;
--		fifo_wr_i			 : in std_logic;
--		read_done_i			 : in std_logic;
--		dat_i					 : in std_logic_vector(15 downto 0);
--		unused_o				 : out std_logic_vector(18 downto 0)
--	);
--END COMPONENT;

--COMPONENT irs_block_readout_v2 is
--	 generic (
--	     STACK_NUMBER    : integer
--	 );
--    port (
--       -- System environment
--        clk_i           : in  std_logic;
--		  rst_i				: in  std_logic;
--        read_strobe_i	: in  std_logic;                        -- Start-of-readout signal 
--		  read_remaining_i : in std_logic;                        -- 1 if more blocks remain
--		  read_remaining_strobe_i : in std_logic;						 -- 1 if read_remaining_i is valid
--		  ch_mask_i			: in  std_logic_vector(7 downto 0);     -- Indicate which channels to read out (if 1, read out)
--        read_address_i	: in  std_logic_vector(8 downto 0);     -- IRS2 block addr from the history buffer
--        t0_i            : in  std_logic_vector(47 downto 0);    -- System clock
--        trig_pat_i      : in  std_logic_vector(3 downto 0);     -- Trigger pattern to be stored in readout
--        read_done_o     : out std_logic;                        -- done signal
--
--        -- IRS2 I/O signals
--        SMPALL				: out std_logic;
--        SMP					: out std_logic_vector(5 downto 0);
--        CH					: out std_logic_vector(2 downto 0);
--        DAT					: in std_logic_vector(11 downto 0);
--  		  RD					: out std_logic_vector(9 downto 0);
--        RDEN				: out std_logic;
--        RAMP				: out std_logic;
--        START				: out std_logic;
--        CLR					: out std_logic;
--        
--        -- EVENT interface I/O
--		  event_interface_io : inout std_logic_vector(43 downto 0)
--    );
--end COMPONENT;

BEGIN

-- Event interface expander.
--	evif : event_interface_irs PORT MAP(
--		interface_io => event_interface_io,
--		fifo_clk_o => fifo_clock,
--		irs_clk_i => event_clkout,
--		fifo_full_o => fifo_full,
--		read_done_i => event_write_done,
--		dat_i => fifo_data,
--		unused_o => fifo_unused,
--		fifo_wr_i => fifo_write
--	);

--	readout_samples <= "10100";
	regcea <='1';
	regceb <='1';
 
 
--	configuration_set : FOR i IN 0 TO n_triggers GENERATE 
--		xpre_trigger_length(i) <=pre_trigger_length_i((i+1)*4-1 DOWNTO i*4);			
--		xtrigger_delay(i) <=trigger_delay_i((i+1)*4-1 DOWNTO i*4);
--	END GENERATE;
 
		time_count : time_stamping PORT MAP( 
			clock,
			reset,
			gps_pps,
			xgps_count,
			xregister_timestamp,
			xcommon_timestamp
		);
 
--		trg_hndl : trigger_handling PORT MAP( 
--		  clock,
--			reset,
--			trigger_i,
--			cal_trigger_i,
--			cpu_trigger_i,
--			xpre_trigger_length,
--			xtrigger_delay,
----			readout_length=>readout_length,
--			trigger_processed,
--			full_triggers,
--			readout_delay
--			
----			priority_trigger=>priority_trigger1			
--		);
	
	readout : readout_comm_state_machine_v2 
	PORT MAP(
			clock,
			reset,
			readout_delay,
--			readout_samples,
			trigger_processed,
			full_triggers,
--			priority_trigger1,

			nprev_o_to_history_buffer,
			req_o_to_history_buffer,
			ack_i_from_history_buffer,
			block_i_from_history_buffer,
			
			lock_address_o_to_block_manager,
			lock_o_to_block_manager,
			unlock_o_to_block_manager, --LM added - see above
			lock_strobe_o_to_block_manager,
			lock_ack_i_from_block_manager,
			free_address_o_to_block_manager,
			free_strobe_o_to_block_manager,
			free_ack_i_from_block_manager,
			
			xregister_timestamp,			
			
			read_address,
			write_to_readout_queue,
			read_done_from_irs_block_readout,
			
			free_address_to_readout_comm,
			readout_ack
);

  
    readout_queue : readout_queue_frame_v2 PORT MAP( 
		clk => clock,
		reset => reset,			
		read_address_from_readout_comm => read_address,
		wea_from_readout_comm => write_to_readout_queue,
		read_block_to_irs_block_readout => read_block_to_irs_block_readout,
		read_strobe_to_irs_block_readout => read_strobe_to_irs_block_readout,
		read_remaining_to_irs_block_readout => read_remaining_to_irs_block_readout,
		read_remaining_strobe_to_irs_block_readout => read_remaining_strobe_to_irs_block_readout,
		read_done_from_irs_block_readout => read_done_from_irs_block_readout,
		free_address_to_irs_block_manager => free_address_to_readout_comm,
		state_rdout_queue_debug_o => state_rdout_queue_debug_o
--		readout_ack
		); 
 
	--combining the correct timestamp:
	--including a roll-over check
	roll_over <= 0 WHEN ( read_block_to_irs_block_readout( (15 + n_triggers + 1 + 8) DOWNTO (n_triggers + 2 + 8)) < xregister_timestamp ) ELSE
					 1 WHEN ( read_block_to_irs_block_readout( (15 + n_triggers + 1 + 8) DOWNTO (n_triggers + 2 + 8)) > xregister_timestamp ) ELSE
					 0;
	block_time <= ( xcommon_timestamp + roll_over ) & read_block_to_irs_block_readout( (15 + n_triggers + 1 + 8) DOWNTO (n_triggers + 2 + 8));


	read_address_o <= read_block_to_irs_block_readout(8 downto 0);
	trig_pat_o <= read_block_to_irs_block_readout( (n_triggers + 1 + 8) DOWNTO (1 + 8) );
	

END behavior;