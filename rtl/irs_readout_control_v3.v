`timescale 1ns / 1ps
/**
 * @file irs_readout_control_v3.v Contains irs_readout_control_v3 module.
 */

//% @brief IRS readout control module.
//%
//% IRS readout control module. This module handles the readout of data
//% (and *only* the readout of data) from an IRS. The various timing parameters
//% for data settling are contained here as well.
module irs_readout_control_v3(
		input clk_i, 							//% System clock
		input rst_i, 							//% Local reset
		input test_mode_i,					//% Bypass input data, replace with test pattern (STACK,CH,SMP)
		input start_i,							//% Signal to begin readout.

		output [11:0] dat_o,					//% The output data
		output valid_o,						//% Output data is valid
		output done_o,							//% Output data is complete (asserted with valid_o on last data)
		
		input [7:0] ch_sel_i,		   	//% Channel select for this block readout.
		
		output [5:0] irs_smp_o,				//% SMP[5:0] outputs
		output [2:0] irs_ch_o,				//% CH[2:0] outputs
		output irs_smpall_o,					//% Data output enable.
		input [11:0] irs_dat_i				//% DAT[11:0] inputs
    );
	
	parameter [1:0] STACK_NUMBER = 2'b00;
	
	// These parameters should be tuned to be the minimum needed for stable data.
	// This can easily be checked by reading out the same data with these parameters
	// changed inbetween.

	localparam COUNTER_WIDTH = 4;

	// N.B.: The sample and channel counters are reregistered to allow for
	//       propagation time across the chip. This means that we increase DATA_SETUP_CYCLES
	//       by 1 and decrease DATA_HOLD_CYCLES by 1, because they take an extra cycle to
	//       propagate now.
	localparam [COUNTER_WIDTH-1:0] PIPELINE_DELAY = 1;

	//% Number of cycles, minus 1, between assertion of SMP/CH and latching data
	localparam [COUNTER_WIDTH-1:0] DATA_SETUP_CYCLES = 3 + PIPELINE_DELAY;
	//% Number of hold cycles after latching data before changing address (this should be zero).
	localparam [COUNTER_WIDTH-1:0] DATA_HOLD_CYCLES = 1 - PIPELINE_DELAY;
	//% Number of additional cycles, minus 1, needed when asserting SMPALL before latching data
	localparam [COUNTER_WIDTH-1:0] SMPALL_SETUP_CYCLES = 0;
	//% Number of additional cycles, minus 1, needed when changing CH.
	localparam [COUNTER_WIDTH-1:0] CHANNEL_SETUP_CYCLES = 0;

	//% General-purpose counter.
	reg [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}}; 
	//% Sample counter.
	reg [5:0] sample_counter = {6{1'b0}};
	//% Sample counter, latched. This is packed in the IOB.
	(* IOB = "TRUE" *)
	reg [5:0] sample_latched = {6{1'b0}};
	//% Channel pointer.
	reg [2:0] channel_counter = {3{1'b0}};
	//% Channel pointer, latched. This is packed in the IOB.
	(* IOB = "TRUE" *)
	reg [2:0] channel_latched = {3{1'b0}};
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(4);
	localparam [FSM_BITS-1:0] IDLE = 0;				//% Readout is idle.
	localparam [FSM_BITS-1:0] SMPALL_SETUP = 1; 	//% Asserting SMPALL.
	localparam [FSM_BITS-1:0] DATA_SETUP = 2;		//% Waiting for data to settle.
	localparam [FSM_BITS-1:0] CH_SETUP = 3;		//% Switching channels.
	localparam [FSM_BITS-1:0] COMPLETE = 4;      //% Done.
	reg [FSM_BITS-1:0] state = IDLE;					//% FSM variable.
	
	//% Indicates that this channel readout is the last.
	reg is_last_channel = 0;
	
	//% is_last_channel goes high when all bits in ch_sel_i above channel_counter are 0 (or at 7)
	always @(*) begin	: IS_LAST_CHANNEL_LOGIC
		case (channel_counter)
			3'd0: is_last_channel <= (ch_sel_i[7:1] == {7{1'b0}});
			3'd1: is_last_channel <= (ch_sel_i[7:2] == {6{1'b0}});
			3'd2: is_last_channel <= (ch_sel_i[7:3] == {5{1'b0}});
			3'd3: is_last_channel <= (ch_sel_i[7:4] == {4{1'b0}});
			3'd4: is_last_channel <= (ch_sel_i[7:5] == {3{1'b0}});
			3'd5: is_last_channel <= (ch_sel_i[7:6] == {2{1'b0}});
			3'd6: is_last_channel <= (ch_sel_i[7] == 1'b0);
			3'd7: is_last_channel <= 1;
		endcase
	end
	
	//% State machine logic.
	always @(posedge clk_i) begin : FSM
		if (rst_i) state <= IDLE;
		else begin
			case (state)
				IDLE: if (start_i) state <= SMPALL_SETUP;
				SMPALL_SETUP: if (counter == SMPALL_SETUP_CYCLES) state <= CH_SETUP;
				DATA_SETUP: if (counter == DATA_SETUP_CYCLES + DATA_HOLD_CYCLES) begin
					if (sample_counter == {6{1'b1}}) begin
						if (is_last_channel) state <= COMPLETE;
						else state <= CH_SETUP;
					end
				end
				CH_SETUP: if (ch_sel_i[channel_counter]) begin
					if (counter == CHANNEL_SETUP_CYCLES) state <= DATA_SETUP;
				end
				COMPLETE: if (!start_i) state <= IDLE;
			endcase
		end
	end
	
	reg channel_done;
	always @(posedge clk_i) begin
		channel_done <= (sample_counter == {6{1'b1}});
	end
		
	//% Increment sample counter.
	reg sample_counter_incr = 0;
	
	generate
		if (DATA_SETUP_CYCLES + DATA_HOLD_CYCLES == 0) begin : NODLY
			always @(posedge clk_i) begin : CNT
				if (rst_i || sample_counter == {6{1'b1}})
					sample_counter_incr <= 0;
				else if (state == CH_SETUP && counter == CHANNEL_SETUP_CYCLES)
					sample_counter_incr <= 1;
			end
		end else begin : DLY
			always @(posedge clk_i) begin
				if (state == DATA_SETUP && (counter == DATA_SETUP_CYCLES + DATA_HOLD_CYCLES - 1))
					sample_counter_incr <= 1;
				else
					sample_counter_incr <= 0;
			end
		end
	endgenerate
					
	//% Sample counter reset;
	reg sample_counter_rst = 0;
	
	always @(posedge clk_i) begin
		sample_counter_rst <= (state == IDLE);
	end
	
	//% Sample counter increments after setup cycles + hold cycles.
	always @(posedge clk_i) begin : SAMPLE_COUNTER_LOGIC
		if (sample_counter_rst)
			sample_counter <= {6{1'b0}};
		else if (sample_counter_incr)
			sample_counter <= sample_counter + 1;
	end
	
	//% Channel counter increments after last sample, or when we skip a channel.
	always @(posedge clk_i) begin : CHANNEL_COUNTER_LOGIC
		if (state == IDLE)
			channel_counter <= {3{1'b0}};
		else if (state == DATA_SETUP) begin
			if (sample_counter_incr && channel_done)
				 channel_counter <= channel_counter + 1;
		end else if (state == CH_SETUP) begin
			if (!ch_sel_i[channel_counter])
				channel_counter <= channel_counter + 1;
		end
	end
	
	//% General purpose counter logic
	always @(posedge clk_i) begin : COUNTER_LOGIC
		if (state == SMPALL_SETUP) begin
			if (counter == SMPALL_SETUP_CYCLES) counter <= {COUNTER_WIDTH{1'b0}};
			else counter <= counter + 1;
		end else if (state == DATA_SETUP) begin
			if (counter == DATA_SETUP_CYCLES + DATA_HOLD_CYCLES) counter <= {COUNTER_WIDTH{1'b0}};
			else counter <= counter + 1;
		end else if (state == CH_SETUP && ch_sel_i[channel_counter]) begin
			if (counter == CHANNEL_SETUP_CYCLES) counter <= {COUNTER_WIDTH{1'b0}};
			else counter <= counter + 1;
		end
	end
	
	//% Latched data from the IRS.
	reg [11:0] latched_data = {12{1'b0}};
	//% Data valid indicator.
	reg latched_data_valid = 0;
	//% Data done indicator.
	reg latched_data_done = 0;

	//% Data is latched during DATA_SETUP after DATA_SETUP_CYCLES have completed.
	always @(posedge clk_i) begin : LATCHED_DATA_LOGIC
		if (state == DATA_SETUP && counter == DATA_SETUP_CYCLES) begin
			if (!test_mode_i)
				latched_data <= irs_dat_i;
			else
				latched_data <= {1'b0,STACK_NUMBER,channel_counter,sample_counter};
		end
	end
	//% Flag indicating data is valid and should be latched.
	always @(posedge clk_i) begin : LATCHED_DATA_VALID_LOGIC
		if (state == DATA_SETUP && counter == DATA_SETUP_CYCLES)
			latched_data_valid <= 1;
		else
			latched_data_valid <= 0;
	end
	//% Flag indicating this data is the last one.
	always @(posedge clk_i) begin : LATCHED_DATA_DONE_LOGIC
		if (state == DATA_SETUP && counter == DATA_SETUP_CYCLES 
			 && (sample_counter == {6{1'b1}}) && is_last_channel)
			latched_data_done <= 1;
		else
			latched_data_done <= 0;
	end

	always @(posedge clk_i) begin : SAMPLE_LATCHED_LOGIC
		sample_latched <= sample_counter;
	end
	
	always @(posedge clk_i) begin : CHANNEL_LATCHED_LOGIC
		channel_latched <= channel_counter;
	end

	assign dat_o = latched_data;
	assign valid_o = latched_data_valid;
	assign done_o = latched_data_done;

	assign irs_smp_o = sample_latched;
	assign irs_ch_o = channel_latched;
	assign irs_smpall_o = (state != IDLE);
	
endmodule
