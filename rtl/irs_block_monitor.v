`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// IRS block monitor. Pays attention to the number of locked blocks versus
// the number of free blocks, and inhibits future block requests (triggers)
// if it exceeds a predetermined number. Nominally this is 105, since we only
// have 128 free blocks available. This is roughly number of free blocks minus
// maximum trigger block request.
//////////////////////////////////////////////////////////////////////////////////
module irs_block_monitor(
		input clk_i,
		input rst_i,
		input slow_ce_i,
		input micro_ce_i,
		input pps_i,
		input block_done_i,
		input block_req_i,
		input irs_dead_i,
		output dead_o,
		output [7:0] deadtime_o,
		output [7:0] occupancy_o,
		output [7:0] max_occupancy_o
    );

	parameter MAX_BLOCK_REQUESTS = 105;
	parameter HYSTERESIS = 1;
        `include "clogb2.vh"
        localparam 	  HYST_BITS = clogb2(HYSTERESIS);
   
	reg [7:0] block_request_counter = {8{1'b0}};
	always @(posedge clk_i) begin
		if (rst_i)
			block_request_counter <= {8{1'b0}};
		// If both or neither are asserted, do nothing.
		else if (block_req_i && !block_done_i)
			block_request_counter <= block_request_counter + 1;
		else if (block_done_i && !block_req_i)
			block_request_counter <= block_request_counter - 1;
	end
	
	// Deadtime counter maxes out at ~0xF4 = 244.
	reg [19:0] deadtime_counter = {20{1'b0}};
	reg [7:0] deadtime_latch = {8{1'b0}};
	always @(posedge clk_i) begin
		if (pps_i)
			deadtime_counter <= {20{1'b0}};
		else if (dead_o && micro_ce_i)
			deadtime_counter <= deadtime_counter + 1;
	end
	always @(posedge clk_i) begin
		if (pps_i)
			deadtime_latch <= deadtime_counter[19:12];
	end
	assign deadtime_o = deadtime_latch;
	// Occupancy counter.
	reg [3:0] millisecond_counter = {4{1'b0}};
	wire measure_occupancy = (millisecond_counter == 4'hF && slow_ce_i);
	always @(posedge clk_i) begin
		if (measure_occupancy)
			millisecond_counter <= {4{1'b0}};
		else if (slow_ce_i)
			millisecond_counter <= millisecond_counter + 1;
	end
	reg [11:0] occupancy_counter = {12{1'b0}};
	reg [7:0] occupancy_latch = {8{1'b0}};
	always @(posedge clk_i) begin
		if (measure_occupancy)
			occupancy_counter <= {12{1'b0}};
		else if (slow_ce_i)
			occupancy_counter <= occupancy_counter + block_request_counter;
	end
	always @(posedge clk_i) begin
		if (measure_occupancy)
			occupancy_latch <= occupancy_counter[11:4];
	end
	assign occupancy_o = occupancy_latch;

	reg [7:0] max_occupancy = {8{1'b0}};
	reg [7:0] max_occupancy_latch = {8{1'b0}};
	always @(posedge clk_i) begin
		if (pps_i)
			max_occupancy <= {8{1'b0}};
		else if (block_request_counter > max_occupancy)
			max_occupancy <= block_request_counter;
	end
	always @(posedge clk_i) begin
		if (pps_i)
			max_occupancy_latch <= max_occupancy;
	end
	assign max_occupancy_o = max_occupancy_latch;

	reg dead = 0;
	reg [HYST_BITS-1:0] hysteresis_counter = {HYST_BITS{1'b0}};
	always @(posedge clk_i) begin
		if (dead_o && (block_request_counter < MAX_BLOCK_REQUESTS))
			hysteresis_counter <= hysteresis_counter + 1;
		else
			hysteresis_counter <= {HYST_BITS{1'b0}};
	end
	always @(posedge clk_i) begin
		if (block_request_counter >= MAX_BLOCK_REQUESTS)
			dead <= 1;
		else if (dead && hysteresis_counter == HYSTERESIS)
			dead <= 0;
	end
	
	assign dead_o = dead || irs_dead_i;
endmodule
