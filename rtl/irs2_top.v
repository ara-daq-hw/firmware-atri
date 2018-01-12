`timescale 1ns / 1ps
//% @file irs2_top.v Contains top-level IRS2 module.

`include "irswb_interface.vh"
`include "irsi2c_interface.vh"
`include "ev_interface.vh"

//% @class irs2_top 
module irs2_top( 
		WR, WRSTRB,
		RD, RDOE, RD_I, RDEN,
		SMP, CH, SMPALL, DAT,
		START, CLR, RAMP,

		TSA, TSA_CLOSE,
		
		TSTOUT, TSAOUT,
		clk_i,
		clk180_i,
		rst_i,
		KHz_clk_i,
		MHz_clk_i,
		clk_wrstrb,
		debug_CLK2X,
		debug_CLK270,
		event_interface_io,
		irsi2c_interface_io,
		irswb_interface_io,
		
		irs_refclk_en,
		power_i,
		drive_i,
		// here follow the additional signals for the trigger/readout module:
		gps_pps_signal,			//this should be a reference signal for the time stamping (to reset the 48 bit counter - has to appear within 30 days)
//		trigger_signals,			//this is a 4 bit vector (in the moment for 4 trigger inputs) with all the trigger signals (according to the names in the module, cpu-trigger should be bit1 and cal trigger should be bit0)
//		pre_trigger_blocks,    	//the number of wanted pre trigger samples in units of clock cycles, a concatenated vector of all 4 4bit numbers (most significant number corresponds to most significant trigger)		
//		trigger_delay_time		//the trigger delay time in units of clock cycles, structure same as pre trigger samples
		readout_delay_i,
		trigger_processed_i,
		full_triggers_i,

		// Event header interface...
		ebuf_addr_o,
		event_id_i,
		event_pps_count_i,
		event_cycle_count_i,
		event_sel_i,

		// Deadtime interface...
		blocks_full_o,
		deadtime_o,
		occupancy_o,
		max_occupancy_o,

		debug_o
	);

		input [8:0] readout_delay_i;
		input trigger_processed_i;
		input [3:0] full_triggers_i;

		input gps_pps_signal;			
//		input [3:0] trigger_signals;			
//		input [15:0] pre_trigger_blocks;    			
//		input [15:0]trigger_delay_time;

	parameter SENSE = "SLOW";
	parameter [1:0] STACK_NUMBER = 0;
	
	parameter EADDR_WIDTH = 9;

	output [9:0] WR;
	wire [9:0] irs_wr_o;
	wire [9:0] write_block_out;
	output WRSTRB;
	wire write_strobe_out;
	wire write_strobe_int_out;
	output [9:0] RD;
	output [9:0] RDOE;
	input [9:0] RD_I;
	wire [9:0] read_block_out;
	output RDEN;
	wire read_enable_out;
	
	output [5:0] SMP;
	wire [5:0] sample_out;
	output [2:0] CH;
	wire [2:0] channel_out;
	output SMPALL;
	wire sample_all_out;
	input [11:0] DAT;
	
	output START;
	wire start_out;
	output CLR;
	wire clear_out;
	output RAMP;
	wire ramp_out;
	
	output TSA;
	wire timing_strobe_out;
	output TSA_CLOSE;
	wire timing_strobe_close_out;
	
	input TSTOUT;
	input TSAOUT;
	
	input clk_i;
	input clk180_i;
	input rst_i;
	input KHz_clk_i;
	input MHz_clk_i;
	input clk_wrstrb;
   input debug_CLK2X;
   input debug_CLK270;  
	inout [`EVIF_SIZE-1:0] event_interface_io;
	inout [`IRSI2CIF_SIZE-1:0] irsi2c_interface_io;
	inout [`IRSWBIF_SIZE-1:0] irswb_interface_io;
	
	output irs_refclk_en;
	input power_i;
	input drive_i;

	output [EADDR_WIDTH-1:0] ebuf_addr_o;
	input [15:0] event_id_i;
	input [15:0] event_pps_count_i;
	input [31:0] event_cycle_count_i;
	input event_sel_i;

	output blocks_full_o;
	output [7:0] deadtime_o;
	output [7:0] occupancy_o;
	output [7:0] max_occupancy_o;

	output [47:0] debug_o;

	// IRS <-> I2C interface expander
	// INTERFACE_INS irsi2c irsi2c_irs RPL interface_io irsi2c_interface_io
	wire irs_clk_o;
	wire i2c_clk_i;
	wire irs_init_o;
	wire [1:0] gpio_o;
	wire [1:0] gpio_ack_i;
	irsi2c_irs irsi2cif(.interface_io(irsi2c_interface_io),
	                    .irs_clk_i(irs_clk_o),
	                    .i2c_clk_o(i2c_clk_i),
	                    .irs_init_i(irs_init_o),
	                    .gpio_i(gpio_o),
	                    .gpio_ack_o(gpio_ack_i));
	// INTERFACE_END

	// INTERFACE_INS irswb irswb_irs RPL interface_io irswb_interface_io NODECL irs_clk_o
	wire wb_clk_i;
	wire enable_i;
	wire soft_trig_en_i;
	wire [1:0] rf_trig_en_i;
	wire [7:0] tsa_mon_o;
	wire tsa_mon_update_o;
	wire tsa_mon_start_i;
	wire [9:0] wilk_mon_o;
	wire wilk_mon_update_o;
	wire wilk_mon_start_i;
	wire ped_mode_i;
	wire [8:0] ped_address_i;
	wire ped_clear_i;
	wire [7:0] ch_mask_i;
	wire irs_mode_i;
	wire irs_rst_i;
	wire [11:0] sbbias_i;
	wire [11:0] wilkcnt_i;
	irswb_irs irswbif(.interface_io(irswb_interface_io),
	                  .irs_clk_i(irs_clk_o),
	                  .wb_clk_o(wb_clk_i),
	                  .enable_o(enable_i),
	                  .soft_trig_en_o(soft_trig_en_i),
	                  .rf_trig_en_o(rf_trig_en_i),
	                  .tsa_mon_i(tsa_mon_o),
	                  .tsa_mon_update_i(tsa_mon_update_o),
	                  .tsa_mon_start_o(tsa_mon_start_i),
	                  .wilk_mon_i(wilk_mon_o),
	                  .wilk_mon_update_i(wilk_mon_update_o),
	                  .wilk_mon_start_o(wilk_mon_start_i),
	                  .ped_mode_o(ped_mode_i),
	                  .ped_address_o(ped_address_i),
	                  .ped_clear_o(ped_clear_i),
	                  .ch_mask_o(ch_mask_i),
	                  .irs_mode_o(irs_mode_i),
	                  .irs_rst_o(irs_rst_i),
	                  .sbbias_o(sbbias_i),
	                  .wilkcnt_o(wilkcnt_i));
	// INTERFACE_END
	
	assign irs_clk_o = clk_i;

	wire wilk_test_start_o;
	wire wilk_test_clear_o;
	assign gpio_o[1] = wilk_test_clear_o;
	assign gpio_o[0] = (irs_mode_i) ? 1'b0 : wilk_test_start_o;
	
	wire [8:0] lock_address;
	wire lock_strobe;
	wire lock;
	wire lock_ack;
	
	wire [8:0] free_address;
	wire free_strobe;
	wire free_ack;
	
	wire irs_dead;
	wire irs_dead_clear;
	
	// Goes high when irs_init_o has been sent out, cleared
	// when the power is shut off to the DDA.
	wire irs_is_init;
	// IRS sample monitor. This interfaces to the main clock
	// shifter, which round-robins between the various IRS modules.
/*
	irs2_sample_mon_v2 sample_monitor(.clk_i(timing_strobe_out),
											 .irs2_tsaout_i(TSAOUT),
											 .irs2_tsa_phase_o(irs_tsa_phase),
											 .present_i(1'b1),
											 .enable_i(irs_enable),
											 .done_o(irs_tsa_phase_update));
*/
	// IRS wilkinson monitor
	wire [47:0] wilk_debug;
	irs2_wilkinson_monitor wilkinson_monitor(.clk_i(clk_i),
														  .KHz_clk_i(KHz_clk_i),
														  .is_init_i(irs_is_init),
														  .enable_i(wilk_mon_start_i),
														  .present_i(1'b1),
														  .irs2_test_wilk_out_i(TSTOUT),
														  .irs2_test_wilk_start_o(wilk_test_start_o),
														  .irs2_test_wilk_clear_o(wilk_test_clear_o),
														  .irs2_wilkinson_count_done_o(wilk_mon_update_o),
														  .irs2_wilkinson_count_o(wilk_mon_o),
														  .debug_o(wilk_debug));
	
	 
	
	// Block manager.
	wire [47:0] debug_write;
	//wire debug_locked;
	irs_simple_block_manager_v3_wrapper block_man(.clk_i(clk_i),
										.rst_i(irs_rst_i),
										.clk_wrstrb(clk_wrstrb),
				//						 .clk_wrstrb(clk_i),
										  .tsa_o(timing_strobe_out),
										  .tsa_close_o(timing_strobe_close_out),
										  .block_wr_o(write_block_out),
										  // irs_wr_o goes STRAIGHT to the IOBUF. Let it get pushed in.
										  .wr_o(irs_wr_o),
										  // write_strobe_out goes STRAIGHT to the IOBUF. Let it get pushed in.
										  .wrstrb_o(write_strobe_out),
										  .wrstrb_int_o(write_strobe_int_out),
										  .lock_address_i(lock_address),
										  .lock_strobe_i(lock_strobe),
										  .lock_i(lock),
										  .unlock_i(unlock), //LM added to allow simult. lock and unlock
										  .lock_ack_o(lock_ack),
										  .free_address_i(free_address),
										  .free_strobe_i(free_strobe),
										  .free_ack_o(free_ack),
										  .dead_o(irs_dead),
										  .dead_clear_i(irs_dead_clear),
										  .enable_i(enable_i),
										  .ped_mode_i(ped_mode_i),
										  .ped_address_i(ped_address_i),
										  .ped_clear_i(ped_clear_i),
										  .locked(locked),
										  .irs_mode_i(irs_mode_i),
										  .debug_o(debug_write));

	wire [9:0] history_block;
	wire [8:0] history_nprev;
	wire history_req;
	wire history_ack;

	// History buffer.
	irs_history_buffer hist_buff(.clk_i(clk_i),
										  .rst_i(irs_rst_i),
										  .write_block_i(write_block_out),
								//		  .write_strobe_i(write_strobe_out),
										  .write_strobe_i(write_strobe_int_out),
										  .block_req_i(history_req),
										  .nprev_i(history_nprev),
										  .block_o(history_block),
										  .block_ack_o(history_ack));
	
/*
	wire [10:0] read_address;
	wire read_strobe;
	wire read_done;
	// DDAEVAL software trigger.
	wire [31:0] event_id;
*/
/*	ddaeval_soft_trig_handler soft_trig_handler(.clk_i(clk_i),
																  .soft_trig_i(irs_soft_trig),
																	.history_req_o(history_req),
																  .nprev_o(history_nprev),
																  .block_i(history_block),
																  .history_ack_i(history_ack),
																  .free_address_o(free_address),
																  .free_strobe_o(free_strobe),
																  .free_ack_i(free_ack),
																  .lock_address_o(lock_address),
																	.lock_strobe_o(lock_strobe),
																  .lock_o(lock),
																  .lock_ack_i(lock_ack),
																  .read_address_o(read_address),
																  .read_strobe_o(read_strobe),
																  .event_id_o(event_id),
																  .read_done_i(read_done));
*/
	// IRS block readout. STACK_NUMBER is output in the header, in the top bits of
	// the block number.
/*	irs_block_readout #(.STACK_NUMBER(STACK_NUMBER)) readout_handler(.clk_i(clk_i),
												 .read_address_i(read_address),
												 .event_id_i(event_id),
												 .read_strobe_i(read_strobe),
												 .read_done_o(read_done),
												 .RD(read_block_out),
												 .RDEN(read_enable_out),
												 .SMP(sample_out),
												 .CH(channel_out),
												 .SMPALL(sample_all_out),
												 .START(start_out),
												 .CLR(clear_out),
												 .RAMP(ramp_out),
												 .DAT(DAT),
												 .event_interface_io(event_interface_io));
*/

//		ebuf_addr_o,
//		event_id_i,
//		event_pps_count_i,
//		event_cycle_count_i,
//		event_sel_i,
	wire read_strobe_to_irs_block_readout;
	wire read_remaining_to_irs_block_readout;
	wire read_remaining_strobe_to_irs_block_readout;
	wire [8:0] read_block_to_irs_block_readout;
	wire [3:0] trig_pat;
	wire read_done_from_irs_block_readout;
   wire [2:0] state_rdout_queue_debug_o;
	//Trigger and readout module
	ara_trigger_readout #(.STACK_NUMBER(STACK_NUMBER)) trigger_module(
			.clock(clk_i),
			.reset(irs_rst_i),
	
			.gps_pps(gps_pps_signal),
//			.trigger_i(trigger_signals[3:2]),
//			.cpu_trigger_i(irs_soft_trig_stretch),
//			.cal_trigger_i(trigger_signals[0]),
//			.pre_trigger_length_i(pre_trigger_blocks),			
//			.trigger_delay_i(trigger_delay_time),

			.readout_delay(readout_delay_i),
			.trigger_processed(trigger_processed_i),
			.full_triggers(full_triggers_i),
			.nprev_o_to_history_buffer(history_nprev),
			.req_o_to_history_buffer(history_req),
			.block_i_from_history_buffer(history_block[8:0]),
			.lock_address_o_to_block_manager(lock_address),
			.lock_o_to_block_manager(lock),
			.unlock_o_to_block_manager(unlock),
			.lock_strobe_o_to_block_manager(lock_strobe),
			.free_address_o_to_block_manager(free_address),
			.free_strobe_o_to_block_manager(free_strobe),
			.ack_i_from_history_buffer(history_ack),
			.free_ack_i_from_block_manager(free_ack),
			.lock_ack_i_from_block_manager(lock_ack),

			.read_strobe_to_irs_block_readout(read_strobe_to_irs_block_readout),
			.read_remaining_to_irs_block_readout(read_remaining_to_irs_block_readout),
			.read_remaining_strobe_to_irs_block_readout(read_remaining_strobe_to_irs_block_readout),
			.read_address_o(read_block_to_irs_block_readout),
			.trig_pat_o(trig_pat),
			.read_done_from_irs_block_readout(read_done_from_irs_block_readout),
			.state_rdout_queue_debug_o(state_rdout_queue_debug_o)
/*
			.irs_smpall_o(sample_all_out),
			.irs_samp_o(sample_out),
			.irs_ch_o(channel_out) ,
			.irs_data_i(DAT),
			.irs_block_addr(read_block_out),
			.irs_read_ena_o(read_enable_out),
			.irs_ramp_o(ramp_out),
			.irs_tdc_start_o(start_out),
			.irs_tdc_clear_o(clear_out),
//			.irs_tsa_o(TSA_fake),

            .event_interface_io(event_interface_io)
*/
			);
	wire [8:0] debug_long_time_o;
   wire [4:0] state_debug_o;

	 // IRS readout. Now outside of the trigger/buffering modules.
	 irs_block_readout_v2 #(.STACK_NUMBER(STACK_NUMBER)) packaging(
			.clk_i(clk_i),
			.rst_i(irs_rst_i),
			//.slow_ck(KHz_clk_i), //LM to count long delay ver. 6.13
			.read_strobe_i(read_strobe_to_irs_block_readout),
			.read_remaining_i(read_remaining_to_irs_block_readout),
			.read_remaining_strobe_i(read_remaining_strobe_to_irs_block_readout),
			.ch_mask_i(ch_mask_i),
			.wilkcnt_i(wilkcnt_i),
			.read_address_i(read_block_to_irs_block_readout),
			.trig_pat_i(trig_pat),
			.read_done_o(read_done_from_irs_block_readout),
			.SMPALL(sample_all_out),
			.SMP(sample_out),
			.CH(channel_out),
			.DAT(DAT),
			.RD(read_block_out),
			.RDEN(read_enable_out),
			.RAMP(ramp_out),
			.CLR(clear_out),
			.START(start_out),
			
			.irs_mode_i(irs_mode_i),
			
			.ebuf_addr_o(ebuf_addr_o),
			.event_id_i(event_id_i),
			.event_pps_count_i(event_pps_count_i),
			.event_cycle_count_i(event_cycle_count_i),
			.event_sel_i(event_sel_i),
			
			.event_interface_io(event_interface_io),
			
			.prog_full(prog_full),
			.write_locked(locked)
			//.discard_remaining_debug_o(discard_remaining_debug_o), LM from v. 6.13
			//.old_event_debug_o(old_event_debug_o),
			//.fifo_full_debug_o(fifo_full_debug_o),
			//.state_debug_o(state_debug_o)
	 );

	wire irs_is_full;
	wire [7:0] irs_deadtime;
	wire [7:0] irs_occupancy; 
	wire [7:0] irs_max_occupancy;
	// IRS block monitor.
	irs_block_monitor #(.MAX_BLOCK_REQUESTS(1),.HYSTERESIS(200)) block_monitor(.clk_i(clk_i),.rst_i(1'b0),
//	irs_block_monitor #(.MAX_BLOCK_REQUESTS(105),.HYSTERESIS(1)) block_monitor(.clk_i(clk_i),.rst_i(1'b0),
											  .slow_ce_i(KHz_clk_i),
											  .micro_ce_i(MHz_clk_i),
											  .pps_i(gps_pps_signal),
											  .block_done_i(read_done_from_irs_block_readout),
											  .block_req_i(history_ack),
											  .irs_dead_i(prog_full), //Added from Patrick
											  .dead_o(irs_is_full),
											  .deadtime_o(irs_deadtime),
											  .occupancy_o(irs_occupancy),
											  .max_occupancy_o(irs_max_occupancy));

	irs_init_generator #(.SENSE(SENSE)) irs_init(.clk_i(clk_i),.power_i(power_i),
																.slow_ce_i(KHz_clk_i),
																.micro_ce_i(MHz_clk_i),
																.init_o(irs_init_o),
																.is_init_o(irs_is_init));

	wire irs_dac_busy;

	irs3_serial_dac_init irs3_dacinit(.clk_i(clk_i),
												 .irs_init_i(irs_is_init && drive_i),
												 .sbbias_i(sbbias_i),
												 .irs_mode_i(irs_mode_i),
												 .irs_sclk_o(irs3_sclk),
												 .irs_sin_o(irs3_sin),
												 .irs_shout_i(RD[3]),
												 .irs_regclr_o(irs3_regclr),
												 .irs_pclk_o(irs3_pclk),
												 .irs_dac_busy_o(irs_dac_busy));
	// RD is multiplexed now based on the IRS mode.
	assign RD[2:0] = read_block_out[2:0]; // These are multiplexed inside the block readout.
	assign RDOE[2:0] = 3'b111;            // These guys are always driven.

	assign RD[3] = read_block_out[3];
	assign RDOE[3] = (!(irs_mode_i || !drive_i)); // Only driven when DRIVE bit is set and not IRS3

	assign RD[4] = (irs_mode_i) ? irs3_regclr : read_block_out[4];
	assign RD[5] = (irs_mode_i) ? irs3_pclk : read_block_out[5];
	assign RD[6] = (irs_mode_i) ? (irs3_sclk || (wilk_test_start_o && !irs_dac_busy)) : read_block_out[6];
	assign RD[7] = (irs_mode_i) ? irs3_sin : read_block_out[7];
	assign RDOE[7:4] = 4'b1111;				// Always drive.

	assign RD[8] = read_block_out[8];
	assign RD[9] = read_block_out[9];												 
	assign RDOE[8] = (!(irs_mode_i || !drive_i)); // Only driven when DRIVE bit is set and not IRS3
	assign RDOE[9] = (!(irs_mode_i || !drive_i)); // Only driven when DRIVE bit is set and not IRS3

//counter for number of blocks read inside an event
reg [7:0] ev_blk_cnt; // requires 20*8!
//reg first_cycle = 1'b1;
  always @(posedge clk_i) begin
       if (trigger_processed_i) //triggered processed stays on 
													//for 20 cycles and then it is 
													//inhibited: the first read_done
													// requires much more than that....
													//no need for first_cycle!
		begin
			ev_blk_cnt <=8'b0;
//			first_cycle<=1'b0;
		end
     else if(read_done_from_irs_block_readout)
		begin
			ev_blk_cnt <= ev_blk_cnt+1;
//			if(ev_blk_cnt==159) first_cycle<=1'b1;
		end
end

reg wrstrb_tog = 0;

always @(posedge clk_wrstrb)
begin
	wrstrb_tog <= !wrstrb_tog;
end

	assign blocks_full_o = irs_is_full;
	assign deadtime_o = irs_deadtime;
	assign occupancy_o = irs_occupancy;
	assign max_occupancy_o = irs_max_occupancy;

	
	assign debug_o = debug_write;

	assign WR = irs_wr_o;
	assign WRSTRB = write_strobe_out;
	assign RDEN = read_enable_out;
	assign SMP = sample_out;
	assign SMPALL = sample_all_out;
	assign CH = channel_out;
	assign START = start_out;
	assign CLR = clear_out;
	assign RAMP = ramp_out;
	assign TSA = timing_strobe_out;
	assign TSA_CLOSE = timing_strobe_close_out;
/*
	assign WR = (drive_i) ? write_block_out : {10{1'bZ}};
	assign RD = (drive_i) ? read_block_out : {10{1'bZ}};
	assign WRSTRB = (drive_i) ? write_strobe_out : 1'bZ;
	assign RDEN = (drive_i) ? read_enable_out : 1'bZ;
	assign SMP = (drive_i) ? sample_out : {6{1'bZ}};
	assign SMPALL = (drive_i) ? sample_all_out : 1'bZ;
	assign CH = (drive_i) ? channel_out : {3{1'bZ}};
	assign START = (drive_i) ? start_out : 1'bZ;
	assign CLR = (drive_i) ? clear_out : 1'bZ;
	assign RAMP = (drive_i) ? ramp_out : 1'bZ;
	assign TSA = (drive_i) ? timing_strobe_out : 1'bZ;
	assign TSA_CLOSE = (drive_i) ? timing_strobe_close_out : 1'bZ;
*/

endmodule
