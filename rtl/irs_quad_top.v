						`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Massive reorganization of the IRS section. Now instead of 4 top-level IRS
// modules, we have *one* module, which can handle up to 4 DDAs.
//
// We only have *one* block manager for all IRSs. Trigger modules send out a
// single combined trigger. They also have a matched version of their triggers
// in a NUM_L4 vector, and also a NUM_L4 vector of flags indicating when a new
// info block is available.
//
// This means that our block buffer needs to store:
// -- 9 BITS FOR THE BLOCK TO READOUT
// -- 4 BITS FOR THE L4 VECTOR CONTRIBUTING TO THIS BLOCK
// -- 4 BITS FOR THE L4 NEW INFO FLAGS
// -- 32 BITS FOR THE CYCLE COUNT
// -- 16 BITS FOR THE PPS
// -- 1 BIT INDICATING NEW EVENT
// This is 66 bits, leaving 10 additional bits (so up to 5 more triggers) since
// we're using a 72-bit FIFO (2x 36 bit block RAMs).
//
// Thankfully the PicoBlaze has a bajillion years to output info for one block.
// 6.2 us at 100 MHz is 620 cycles, or 360 instructions.
//
//////////////////////////////////////////////////////////////////////////////////
`include "wb_interface.vh"
`include "ev2_interface.vh"
`include "irs_interface.vh"
`include "irsi2c_interface.vh"
`include "irswb_interface.vh"
`include "trigger_defs.vh"
module irs_quad_top(
		/////////////////////////////////////////////////////////
		// Interfaces                                          //
		/////////////////////////////////////////////////////////
		irs1_if_io,					//% 1st IRS interface
		irs2_if_io,					//% 2nd IRS interface
		irs3_if_io,					//% 3rd IRS interface
		irs4_if_io,					//% 4th IRS interface
		
		ev2_if_io, 							//% single, combined event interface
		
		irsi2c1_if_io,						//% 1st IRS<->I2C interface
		irsi2c2_if_io,						//% 2nd IRS<->I2C interface
		irsi2c3_if_io,						//% 3rd IRS<->I2C interface
		irsi2c4_if_io,						//% 4th IRS<->I2C interface
		
		irs_wbif_io,						//% WISHBONE IRS control
		evrd_wbif_io,						//% WISHBONE event readout statistics/control
		clk_i,								//% IRS system clock (100 MHz)
		clk180_i,							//% IRS system clock, 180 deg out of phase
		clk_shift_i,						//% Shifted IRS system clock, for write strobe.
		KHz_clk_i,							//% 1 KHz clock enable
		MHz_clk_i,							//% 1 MHz clock enable
		pps_i,								//% Fast PPS signal
		rst_o,
		
		// Clock interface
		pps_counter_i,						//% 16-bit PPS counter
		cycle_counter_i,					//% 32-bit cycle counter

		// Trigger interface.
		trig_i,								//% Input, combined trigger
		trig_offset_i,						//% Input trigger offset, in blocks.
		trig_l4_i,							//% Which triggers contributed to this 
		trig_l4_new_i,						//% Which triggers have new info

		// Trigger info interface
		trig_info_i,						//% 32-bit trigger info.
		trig_info_addr_o,					//% Which info is being selected
		trig_info_rd_o,					//% Read flag
		
		// Software trigger start
		soft_trig_o,
		soft_trig_info_o,
		// Deadtime signals.
		// Active when we are sampling. This is for the CURRENT cycle.
		sampling_o,
		// Clock enable for sampling. Sampling only valid when ce is high.
		sampling_ce_o,
		// Asserted if the readout system can handle a new block.
		readout_rdy_o,
		// Asserted if the readout event FIFO is full.
		readout_full_o,
		debug_o,
		debug_sel_i
    );

	parameter NUM_DAUGHTERS = 4;
	localparam MAX_DAUGHTERS = 4;
	localparam NUM_L4 = `SCAL_NUM_L4;
	localparam INFO_BITS= `INFO_BITS;
	`include "clogb2.vh"
	localparam NL4_BITS = clogb2(NUM_L4-1);
	localparam NMXD_BITS = clogb2(MAX_DAUGHTERS-1);
	parameter SENSE = "SLOW";

	inout [`IRSIF_SIZE-1:0] irs1_if_io;					//% 1st IRS interface
	inout [`IRSIF_SIZE-1:0] irs2_if_io;					//% 2nd IRS interface
	inout [`IRSIF_SIZE-1:0] irs3_if_io;					//% 3rd IRS interface
	inout [`IRSIF_SIZE-1:0] irs4_if_io;					//% 4th IRS interface
	
	inout [`EV2IF_SIZE-1:0] ev2_if_io; 		//% single, combined event interface
	
	inout [`IRSI2CIF_SIZE-1:0] irsi2c1_if_io;			//% 1st IRS<->I2C interface
	inout [`IRSI2CIF_SIZE-1:0] irsi2c2_if_io;			//% 2nd IRS<->I2C interface
	inout [`IRSI2CIF_SIZE-1:0] irsi2c3_if_io;			//% 3rd IRS<->I2C interface
	inout [`IRSI2CIF_SIZE-1:0] irsi2c4_if_io;			//% 4th IRS<->I2C interface

	inout [`WBIF_SIZE-1:0] 	irs_wbif_io;				//% single, combined WB interface
	inout [`WBIF_SIZE-1:0]  evrd_wbif_io;				//% event readout WISHBONE interface
	input clk_i;								//% IRS system clock (100 MHz)
	input clk180_i;							//% IRS system clock, 180 deg out of phase
	input clk_shift_i;						//% Shifted IRS system clock (for write strobe)
	input KHz_clk_i;							//% 1 KHz clock enable
	input MHz_clk_i;							//% 1 MHz clock enable
	input pps_i;								//% Fast PPS signal
	output rst_o;								//% Our reset signal.
	
	input [15:0] pps_counter_i;			//% 16-bit PPS counter.
	input [31:0] cycle_counter_i;			//% 32 bit cycle counter.

	// Trigger interface.
	input trig_i;
	input [8:0] trig_offset_i;
	input [NUM_L4-1:0] trig_l4_i;
	input [NUM_L4-1:0] trig_l4_new_i;
	// Trig info interface.
	input [INFO_BITS-1:0] trig_info_i;
	output [NL4_BITS-1:0] trig_info_addr_o;
	output trig_info_rd_o;

	// Software trigger start
	output soft_trig_o;
	output [7:0] soft_trig_info_o;
	
	output sampling_o;
	output sampling_ce_o;
	output readout_rdy_o;
	output readout_full_o;
	
	// Debug
	output [52:0] debug_o;
	input [3:0] debug_sel_i;
	
	// IRS interface expansion.
	//% Data lines for IRS.
	wire [11:0] irs_dat[MAX_DAUGHTERS-1:0];
	//% Sample select lines for IRS.
	wire [5:0] irs_smp[MAX_DAUGHTERS-1:0];
	//% Channel select for IRS.
	wire [2:0] irs_ch[MAX_DAUGHTERS-1:0];
	//% Sample enable for IRS.
	wire [MAX_DAUGHTERS-1:0] irs_smpall;
	//% Ramp control.
	wire [MAX_DAUGHTERS-1:0] irs_ramp;
	//% Start Wilkinson.
	wire [MAX_DAUGHTERS-1:0] irs_start;
	//% Clear Wilkinson.
	wire [MAX_DAUGHTERS-1:0] irs_clear;
	//% WR[9:0] lines: Write block.
	wire [9:0] irs_wr[MAX_DAUGHTERS-1:0];
	//% Write strobe.
	wire [MAX_DAUGHTERS-1:0] irs_wrstrb;
	//% RD[9:0] lines (inputs only).
	wire [9:0] irs_rd[MAX_DAUGHTERS-1:0];
	//% RD[9:0] lines (outputs only).
	wire [9:0] irs_rdo[MAX_DAUGHTERS-1:0];
	//% RD[9:0] output enable
	wire [9:0] irs_rdoe[MAX_DAUGHTERS-1:0];
	//% Read enable.
	wire [MAX_DAUGHTERS-1:0] irs_rden;
	//% Timing strobe.
	wire [MAX_DAUGHTERS-1:0] irs_tsa;
	//% Timing strobe close.
	wire [MAX_DAUGHTERS-1:0] irs_tsa_close;
	//% Timing strobe output.
	wire [MAX_DAUGHTERS-1:0] irs_tsaout;
	//% Wilkinson test output.
	wire [MAX_DAUGHTERS-1:0] irs_tstout;
	//% IRS power indicator.
	wire [MAX_DAUGHTERS-1:0] irs_power;
	//% IRS drive indicator.
	wire [MAX_DAUGHTERS-1:0] irs_drive;

	// VECTORIZE IRS INTERFACE
	wire [`IRSIF_SIZE-1:0] irs_if[MAX_DAUGHTERS-1:0];
	irs_infra_reassign d1_reassign(.A_i(irs1_if_io),.B_o(irs_if[0]));
	irs_infra_reassign d2_reassign(.A_i(irs2_if_io),.B_o(irs_if[1]));
	irs_infra_reassign d3_reassign(.A_i(irs3_if_io),.B_o(irs_if[2]));
	irs_infra_reassign d4_reassign(.A_i(irs4_if_io),.B_o(irs_if[3]));

	generate
		genvar ii;
		for (ii=0;ii<MAX_DAUGHTERS;ii=ii+1) begin : IRSIF
			// FIXME : use automatic insertion
			irs_ctrl daughter(.interface_io(irs_if[ii]),
						 .dat_o(irs_dat[ii]),
						 .smp_i(irs_smp[ii]),
						 .ch_i(irs_ch[ii]),
						 .smpall_i(irs_smpall[ii]),
						 .ramp_i(irs_ramp[ii]),
						 .start_i(irs_start[ii]),
						 .clr_i(irs_clear[ii]),
						 .wr_i(irs_wr[ii]),
						 .wrstrb_i(irs_wrstrb[ii]),
						 .rd_o(irs_rd[ii]),
						 .rdo_i(irs_rdo[ii]),
						 .rdoe_i(irs_rdoe[ii]),
						 .rden_i(irs_rden[ii]),
						 .tsa_i(irs_tsa[ii]),
						 .tsa_close_i(irs_tsa_close[ii]),
						 .tsaout_o(irs_tsaout[ii]),
						 .tstout_o(irs_tstout[ii]),
						 .power_o(irs_power[ii]),
						 .drive_o(irs_drive[ii]));
		end
	endgenerate

	// INTERFACE_INS ev2 ev2_irs RPL interface_io ev2_interface_io RPL dat_o evdat_o RPL count_i evcount_i RPL wr_o evwr_o RPL full_i evfull_i RPL rst_ack_i evrst_ack_i
	wire irsclk_o;
	wire [15:0] evdat_o;
	wire [15:0] evcount_i;
	wire evwr_o;
	wire evfull_i;
	wire rst_o;
	wire evrst_ack_i;
	ev2_irs ev2if(.interface_io(ev2_if_io),
	              .irsclk_i(irsclk_o),
	              .dat_i(evdat_o),
	              .count_o(evcount_i),
	              .wr_i(evwr_o),
	              .full_o(evfull_i),
	              .rst_i(rst_o),
	              .rst_ack_o(evrst_ack_i));
	// INTERFACE_END
	assign irsclk_o = clk_i;

	// DIGITIZER SUBSYSTEM RESET
	// Reset is issued by the WISHBONE interface. The entire subsystem is held
	// in reset until everyone (IRS readout, event FIFO) acknowledges the reset,
	// so we can start cleanly.
	wire rst;
	assign rst_o = rst;
	wire irs_rst_ack;
	wire rst_ack_all = (irs_rst_ack && evrst_ack_i);

	
	// We have to perform two separate actions: controlling the IRS sampling,
	// and controlling the IRS readout. These are partitioned into
	// irs_read_top and irs_write_top.
	
	// There is also an IRS event controller, which essentially goes between
	// the two, fetching the block which was written to 'offset' cycles ago,
	// and informing the write controller when readout has completed.

	//////////////////////////////////////////////////////
	//
	// IRS WRITE TOP
	//
	//////////////////////////////////////////////////////
	
	// irs_write_top has a history, lock, and free interface, as well as an
	// output indicating that sampling is active, and a strobe indicating
	// when a block is written to (for anything that needs to know what
	// phase things are).
	wire [8:0] irshst_offset;
	wire irshst_req;
	wire [8:0] irshst_block;
	wire irshst_ack;
	
	wire [8:0] irslck_block;
	wire irslck_req;
	wire irslck_ack;
	
	wire [8:0] irsfree_block;
	wire irsfree_req;
	wire irsfree_ack;
	
	wire irs_write_enable;
	wire [MAX_DAUGHTERS-1:0] irs_active;
	wire irs_block_strobe;
	wire irs_block_set;
	wire [MAX_DAUGHTERS-1:0] irs_mode;
	
	//% Pedestal mode.
	wire ped_mode;
	//% Block to write to in pedestal mode.
	wire [8:0] ped_address;
	//% Sample in pedestal mode (write to a block).
	wire ped_sample;
	//% Digitizer is currently sampling
	wire irs_sampling;
	irs_write_top #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) 
		writectl(.clk_i(clk_i),.smp_start_clk_i(clk180_i),.wr_strb_clk_i(clk_shift_i),.rst_i(rst),
								  .hist_offset_i(irshst_offset),
								  .hist_req_i(irshst_req),
								  .hist_block_o(irshst_block),
								  .hist_ack_o(irshst_ack),
								  .lock_block_i(irslck_block),
								  .lock_req_i(irslck_req),
								  .lock_ack_o(irslck_ack),
								  .free_block_i(irsfree_block),
								  .free_req_i(irsfree_req),
								  .free_ack_o(irsfree_ack),
								  
								  .ped_mode_i(ped_mode),
								  .ped_address_i(ped_address),
								  .ped_sample_i(ped_sample),
								  
								  .enable_i(irs_write_enable),
								  .active_o(irs_active),
								  .sampling_o(irs_sampling),
								  .sampling_ce_o(sampling_ce_o),
								  .write_strobe_o(irs_block_strobe),
								  .block_set_o(irs_block_set),
								  .d1_wr_o(irs_wr[0]),.d2_wr_o(irs_wr[1]),.d3_wr_o(irs_wr[2]),.d4_wr_o(irs_wr[3]),
								  .d1_wrstrb_o(irs_wrstrb[0]),.d2_wrstrb_o(irs_wrstrb[1]),
								  .d3_wrstrb_o(irs_wrstrb[2]),.d4_wrstrb_o(irs_wrstrb[3]),
								  .d1_tsa_o(irs_tsa[0]),.d2_tsa_o(irs_tsa[1]),.d3_tsa_o(irs_tsa[2]),.d4_tsa_o(irs_tsa[3]),
								  .d1_tsa_close_o(irs_tsa_close[0]),.d2_tsa_close_o(irs_tsa_close[1]),
								  .d3_tsa_close_o(irs_tsa_close[2]),.d4_tsa_close_o(irs_tsa_close[3]),
								  .d1_mode_i(irs_mode[0]),.d2_mode_i(irs_mode[1]),.d3_mode_i(irs_mode[2]),.d4_mode_i(irs_mode[3]),
								  .d1_power_i(irs_power[0]),.d2_power_i(irs_power[1]),
								  .d3_power_i(irs_power[2]),.d4_power_i(irs_power[3]));

	// sampling_o is active when the IRS is sampling.
	// The trigger interface looks back in a shift register to see if the IRS was sampling
	// when a trigger request comes in: if it was not, no T1 is generated.
	assign sampling_o = irs_sampling;
	
	//////////////////////////////////////////////////////
	//
	// IRS EVENT CONTROLLER
	//
	//////////////////////////////////////////////////////
	
	wire [71:0] irs_buffer_block;
	wire irs_buffer_empty;
	wire irs_buffer_read;
	wire bb_full;
	wire [8:0] bb_count;
	irs_event_controller_v3 irs_controller(.clk_i(clk_i),
														 .rst_i(rst),
														 // Timing interface
														 .pps_counter_i(pps_counter_i),
														 .cycle_counter_i(cycle_counter_i),
														 // Trigger interface
														 .trig_i(trig_i),
														 .trig_offset_i(trig_offset_i),
														 .trig_l4_i(trig_l4_i),
														 .trig_l4_new_i(trig_l4_new_i),
														 // IRS write strobe
														 .irs_wrstrb_i(irs_block_strobe),
														 // History buffer interface
														 .hist_offset_o(irshst_offset),
														 .hist_req_o(irshst_req),
														 .hist_block_i(irshst_block),
														 .hist_ack_i(irshst_ack),
														 // Lock interface...
														 .lock_block_o(irslck_block),
														 .lock_req_o(irslck_req),
														 .lock_ack_i(irslck_ack),
														 // And buffer interface
														 .irs_buff_dat_o(irs_buffer_block),
														 .irs_buff_empty_o(irs_buffer_empty),
														 .irs_buff_read_i(irs_buffer_read),
														 // Block buffer full.
														 .block_buffer_full_o(bb_full),
														 .block_buffer_count_o(bb_count)
														 );

	//////////////////////////////////////////////////////
	//
	// IRS READ TOP
	//
	//////////////////////////////////////////////////////

	wire [9:0] irs_read_rdo[MAX_DAUGHTERS-1:0];
	wire [NMXD_BITS-1:0] irsmask_addr;
	wire [7:0] irsmask;
	wire [51:0] irs_read_debug;
	wire irs_test_mode;
	wire readout_ready;
	wire [7:0] readout_delay;
	wire [7:0] readout_err;
	
	irs_read_top #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) irs_readout(
			.d1_irsdat_i(irs_dat[0]),.d2_irsdat_i(irs_dat[1]),.d3_irsdat_i(irs_dat[2]),.d4_irsdat_i(irs_dat[3]),
			.d1_irssmp_o(irs_smp[0]),.d2_irssmp_o(irs_smp[1]),.d3_irssmp_o(irs_smp[2]),.d4_irssmp_o(irs_smp[3]),
			.d1_irsch_o(irs_ch[0]),.d2_irsch_o(irs_ch[1]),.d3_irsch_o(irs_ch[2]),.d4_irsch_o(irs_ch[3]),
			.d1_irssmpall_o(irs_smpall[0]),.d2_irssmpall_o(irs_smpall[1]),
			.d3_irssmpall_o(irs_smpall[2]),.d4_irssmpall_o(irs_smpall[3]),
			.d1_irsrd_o(irs_read_rdo[0]),.d2_irsrd_o(irs_read_rdo[1]),.d3_irsrd_o(irs_read_rdo[2]),.d4_irsrd_o(irs_read_rdo[3]),
			.d1_irsrden_o(irs_rden[0]),.d2_irsrden_o(irs_rden[1]),.d3_irsrden_o(irs_rden[2]),.d4_irsrden_o(irs_rden[3]),
			.d1_start_o(irs_start[0]),.d2_start_o(irs_start[1]),.d3_start_o(irs_start[2]),.d4_start_o(irs_start[3]),
			.d1_clr_o(irs_clear[0]),.d2_clr_o(irs_clear[1]),.d3_clr_o(irs_clear[2]),.d4_clr_o(irs_clear[3]),
			.d1_ramp_o(irs_ramp[0]),.d2_ramp_o(irs_ramp[1]),.d3_ramp_o(irs_ramp[2]),.d4_ramp_o(irs_ramp[3]),
			.d1_irsmode_i(irs_mode[0]),.d2_irsmode_i(irs_mode[1]),.d3_irsmode_i(irs_mode[2]),.d4_irsmode_i(irs_mode[3]),
			.block_dat_i(irs_buffer_block),
			.block_empty_i(irs_buffer_empty),
			.block_rd_o(irs_buffer_read),
			
			.trig_info_i(trig_info_i),
			.trig_info_addr_o(trig_info_addr_o),
			.trig_info_rd_o(trig_info_rd_o),
			
			.event_dat_o(evdat_o),
			.event_cnt_i(evcount_i),
			.event_wr_o(evwr_o),
			
			// Free interface...
			.free_block_o(irsfree_block),
			.free_req_o(irsfree_req),
			.free_ack_i(irsfree_ack),

			// Mask interface
			.irs_addr_o(irsmask_addr),
			.irs_mask_i(irsmask),
			
			// Ready.
			.readout_ready_o(readout_ready),
			// Error.
			.readout_err_o(readout_err),
			
			// Readout delay
			.readout_delay_i(readout_delay),

			.clk_i(clk_i),
			.rst_i(rst),
			.test_mode_i(irs_test_mode),
			.rst_ack_o(irs_rst_ack),
			.debug_o(irs_read_debug));

	assign readout_rdy_o = !bb_full && readout_ready;


	//////////////////////////////////////////////////////
	//
	// IRS READ OUTPUT MODE COMPATIBILITY
	//
	//////////////////////////////////////////////////////

	wire [MAX_DAUGHTERS-1:0] irs_init_busy;
	wire [MAX_DAUGHTERS-1:0] irs_init;
	wire [MAX_DAUGHTERS-1:0] irs_wilk_start;
	wire [11:0] irs3_sbbias;
	// The IRS mode compatibility module handles the
	// differences between the IRS2/IRS3 RD[9:0] pins.
	generate
		genvar rci;
		for (rci=0;rci<MAX_DAUGHTERS;rci=rci+1) begin : CL
			if (rci<NUM_DAUGHTERS) begin : COMPAT
				irs_read_mode_compat read_compat(.clk_i(clk_i),
															.rst_i(rst),
															.rdout_rd_i(irs_read_rdo[rci]),
															.irs_rdo_o(irs_rdo[rci]),
															.irs_rd_i(irs_rd[rci]),
															.irs_rdoe_o(irs_rdoe[rci]),
															.power_i(irs_power[rci]),
															.drive_i(irs_drive[rci]),
															.init_i(irs_init[rci]),
															.mode_i(irs_mode[rci]),
															.sbbias_i(irs3_sbbias),
															.wilk_start_i(irs_wilk_start[rci]),
															.busy_o(irs_init_busy[rci]));
			end else begin : DUM
				assign irs_rdo[rci] = {10{1'b0}};
				assign irs_rdoe[rci] = {10{1'b1}};
				assign irs_init_busy[rci] = 1'b0;
			end
		end
	endgenerate

	//////////////////////////////////////////////////////
	//
	// IRS WISHBONE V4
	//
	//////////////////////////////////////////////////////
	
	// The V4 IRS WISHBONE module contains all of the monitoring
	// logic internally (as well as the I2C interface). Its only 
	// outputs to the IRS are pedestal mode control, enable, and
	// initialization complete.
	wire [52:0] sampling_debug;
	irs_wishbone_v4 #(.SENSE(SENSE)) irswb(.interface_io(irs_wbif_io),
								 .d1_i2cif_io(irsi2c1_if_io),
								 .d2_i2cif_io(irsi2c2_if_io),
								 .d3_i2cif_io(irsi2c3_if_io),
								 .d4_i2cif_io(irsi2c4_if_io),
								 .clk_i(clk_i),
								 .MHz_CE_i(MHz_clk_i),
								 .KHz_CE_i(KHz_clk_i),
								 .rst_o(rst),
								 .rst_ack_i(rst_ack_all),
								 .enable_o(irs_write_enable),
								 .test_mode_o(irs_test_mode),

								 .ped_mode_o(ped_mode),
								 .ped_addr_o(ped_address),
								 .ped_sample_o(ped_sample),

								 .tstout_i(irs_tstout),
								 .tsaout_i(irs_tsaout),
								 .wilk_start_o(irs_wilk_start),

								 .irsmode_o(irs_mode),
								 .sbbias_o(irs3_sbbias),
								 .init_o(irs_init),
								 .initbusy_i(irs_init_busy),
								 
								 .maskaddr_i(irsmask_addr),
								 .mask_o(irsmask),
								 .power_i(irs_power),
								 
								 .soft_trig_o(soft_trig_o),
								 .soft_trig_info_o(soft_trig_info_o),
								 
								 .readout_delay_o(readout_delay),
								 .sync_i(sampling_ce_o),
								 .sst_i(irs_block_set),
								 .sample_debug_o(sampling_debug));

	evrd_wishbone evrdwb(.interface_io(evrd_wbif_io),
								.clk_i(clk_i),
								.evcount_i(evcount_i),
								.blkcount_i(bb_count),
								.evrd_err_i(readout_err),
								.readout_ready_i(readout_rdy_o),
								.sampling_i(irs_sampling),
								.sampling_ce_i(sampling_ce_o),
								.pps_i(pps_i),
								.KHz_CE_i(KHz_clk_i),
								.MHz_CE_i(MHz_clk_i));
								
								 
	assign rst_o = rst;

	reg [52:0] sampling_debug_reg = {53{1'b0}};
	reg [52:0] read_debug_reg = {53{1'b0}};
	reg [52:0] mux_debug_reg = {53{1'b0}};
	always @(posedge clk_i) begin
		if (debug_sel_i[0]) sampling_debug_reg <= sampling_debug;
		if (!debug_sel_i[0]) read_debug_reg <= irs_read_debug;
		if (debug_sel_i[0])
			mux_debug_reg <= sampling_debug_reg;
		else
			mux_debug_reg <= read_debug_reg;
	end
	
	assign debug_o = mux_debug_reg;
//	assign debug_o[0 +: 26] = sampling_debug;
//	assign debug_o[52:26] = irs_read_debug[0 +: 27];
//	assign debug_o[52:0] = irs_read_debug;
/*
	assign debug_o[40] = trig_i;
	assign debug_o[41] = irshst_ack;
	assign debug_o[42] = rst;
	assign debug_o[43] = rst_ack_all;
	assign debug_o[44] = irs_start[0];
	assign debug_o[45] = irs_rden[0];
	assign debug_o[46] = sampling_o;
	assign debug_o[47] = evwr_o;
*/
endmodule
