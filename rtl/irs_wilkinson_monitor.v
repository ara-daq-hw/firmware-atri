`timescale 1ns / 1ps
//
// This is the Wilkinson monitor. Works purely in the WISHBONE clock domain.
// 
module irs_wilkinson_monitor(
		clk_i,
		rst_i,
		TSTOUT,
		count_o
    );

	input clk_i;
	input rst_i;
	input TSTOUT;
	output [15:0] count_o;
	
	wire tstout_flag;
	SYNCEDGE_R tstout_flag_gen(.I(TSTOUT),.O(tstout_flag),.CLK(clk_i));
	// TSTOUT nominally has a period somewhere around 6 microseconds.
	// This is ~312 clocks. We therefore count the number of cycles it
	// takes to count 64 TSTOUT cycles. 
	
	// Counts number of cycles.
	reg [15:0] tstout_counter = {16{1'b0}};
	// Counts TSTOUT flags.
	reg [5:0] tstout_flag_counter = {6{1'b0}};
	// Latches number of cycles.
	reg [15:0] tstout_latch = {16{1'b0}};
	// Clears the counter.
	reg reset_counter = 0;
	
	always @(posedge clk_i) begin
		if (rst_i) tstout_flag_counter <= {6{1'b0}};
		else if (tstout_flag) tstout_flag_counter <= tstout_flag_counter + 1;
	end
	
	always @(posedge clk_i) begin
		if (tstout_flag_counter == {6{1'b1}} && tstout_flag)
			reset_counter <= 1;
		else
			reset_counter <= 0;
	end
	
	always @(posedge clk_i) begin
		if (rst_i || reset_counter) tstout_counter <= {16{1'b0}};
		else if (tstout_counter != {16{1'b1}}) tstout_counter <= tstout_counter + 1;
	end

	always @(posedge clk_i) begin
		if (rst_i) tstout_latch <= {16{1'b0}};
		else if (reset_counter) tstout_latch <= tstout_counter;
	end
	
	assign count_o = tstout_latch;
	
endmodule
