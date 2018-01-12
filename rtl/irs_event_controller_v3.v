`timescale 1ns / 1ps

`include "trigger_defs.vh"

//% @brief IRS event controller. This interfaces between the IRS write top and IRS read top and trigger input.
//%
//% The IRS event controller is pretty much the main module which receives triggers,
//% determines which blocks that corresponds to from the IRS history buffer, locks
//% the block, then stores that block and its associated information into the readout buffer.
//%
module irs_event_controller_v3(
		// System
		clk_i,
		rst_i,
		
		// Clock interface
		pps_counter_i,						//% 16-bit PPS counter
		cycle_counter_i,					//% 32-bit cycle counter

		// Trigger interface.
		trig_i,								//% Input, combined trigger
		trig_offset_i,						//% Input trigger offset, in blocks.
		trig_l4_i,							//% Which triggers contributed to this 
		trig_l4_new_i,						//% Which triggers have new info

		// IRS write strobe. To align in time.
		irs_wrstrb_i,

		// History interface
		hist_offset_o,
		hist_req_o,
		hist_block_i,
		hist_ack_i,
		
		// Lock interface
		lock_block_o,
		lock_req_o,
		lock_ack_i,
				
		irs_buff_dat_o,
		irs_buff_empty_o,
		irs_buff_read_i,
		
		block_buffer_full_o,
		block_buffer_count_o
    );

	parameter NUM_L4 = `SCAL_NUM_L4;

	input clk_i;
	input rst_i;
	input [15:0] pps_counter_i;
	input [31:0] cycle_counter_i;
	
	input trig_i;
	input [8:0] trig_offset_i;
	input [NUM_L4-1:0] trig_l4_i;
	input [NUM_L4-1:0] trig_l4_new_i;
	
	input irs_wrstrb_i;
	
	output [8:0] hist_offset_o;
	output hist_req_o;
	input [8:0] hist_block_i;
	input hist_ack_i;
	
	output [8:0] lock_block_o;
	output lock_req_o;
	input lock_ack_i;
		
	output [71:0] irs_buff_dat_o;
	output irs_buff_empty_o;
	input irs_buff_read_i;

	output [8:0] block_buffer_count_o;
	output block_buffer_full_o;

	// We forward the trigger and offset over to the history buffer
	assign hist_req_o = trig_i;
	assign hist_offset_o = trig_offset_i;
	
	// Then we watch for hist_ack_i coming back.	
	// The trigger data can only change once every 2 cycles,
	// so we're fine if we just latch it on the IRS write strobe.
	// The history buffer responds the next cycle after a write strobe:
	// this means we need to store the data before writing it into the
	// block buffer.
	reg [NUM_L4-1:0] trig_l4_reg;
	reg [NUM_L4-1:0] trig_l4_new;
	always @(posedge clk_i) begin
		if (irs_wrstrb_i) begin
			trig_l4_reg <= trig_l4_i;
			trig_l4_new <= trig_l4_new_i;
		end
	end
	wire new_event_flag;
	SYNCEDGE #(.EDGE("RISING"),.LATENCY(0)) new_event_flag_gen(.I(trig_i),.O(new_event_flag),.CLK(clk_i));
	reg new_event = 0;
	always @(posedge clk_i) begin
		if (hist_ack_i) new_event <= 0;
		else if (new_event_flag) new_event <= 1;
	end	

	// As soon as the history ack comes in, we forward it over to the IRS controller.
	reg [8:0] block_to_lock = {9{1'b0}};
	reg lock_req = 0;
	always @(posedge clk_i) begin
		if (hist_ack_i) begin
			lock_req <= 1;
			block_to_lock <= hist_block_i;
		end else begin
			lock_req <= 0;
		end
	end
	assign lock_block_o = block_to_lock;
	assign lock_req_o = lock_req;
	// We don't care about the lock acknowledge: if the lock generation
	// takes longer than 2 cycles the IRS manager has to pipeline the data,
	// not us.

	// We don't have the free interface: that's handled in the readout.
	
	// The trigger time needs to be latched right away, but it can't
	// change for at least 4 more clock cycles (up, and down, then up again)
	reg [31:0] trig_cycles = {32{1'b0}};
	reg [15:0] trig_second = {16{1'b0}};
	always @(posedge clk_i) begin
		if (new_event_flag) begin
			trig_cycles <= cycle_counter_i;
			trig_second <= pps_counter_i;
		end
	end
	
	// This should be set to a programmable full level,
	// and then block off additional triggers.
	wire block_buffer_full;
	wire [71:0] block_info_data;
	assign block_info_data[8:0] = hist_block_i;
	assign block_info_data[9] = new_event;
	assign block_info_data[13:10] = trig_l4_reg;
	assign block_info_data[15:14] = {2{1'b0}}; // reserved for 2 more triggers
	assign block_info_data[19:16] = trig_l4_new;
	assign block_info_data[23:20] = {4{1'b0}}; // reserved for 2 more triggers and 2 additional reserve bits
	assign block_info_data[39:24] = trig_second;
	assign block_info_data[71:40] = trig_cycles;
	wire bb_prog_full;
	wire [8:0] bb_count;
	block_info_buffer buffer(.din(block_info_data),.wr_en(hist_ack_i),.full(block_buffer_full),
									 .dout(irs_buff_dat_o),.empty(irs_buff_empty_o),.rd_en(irs_buff_read_i),
									 .clk(clk_i),.srst(rst_i), .prog_full(bb_prog_full), .data_count(bb_count));
									 
	assign block_buffer_full_o = bb_prog_full;
	assign block_buffer_count_o = bb_count;
endmodule
