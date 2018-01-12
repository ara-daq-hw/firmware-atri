`timescale 1ns / 1ps
// A simple counter that counts infrequently, and latches the value at PPS.
module periodic_stat_counter(
		count_i,
		count_ce_i,
		pps_i,
		value_o,
		clk_count_i,
		clk_val_i
    );

	parameter VALUE_WIDTH = 16;
	parameter COUNTER_WIDTH = 20;
	
	input count_i;
	input count_ce_i;
	input pps_i;
	output [VALUE_WIDTH-1:0] value_o;
	input clk_count_i;
	input clk_val_i;
	
	reg count_seen = 0;
	reg [COUNTER_WIDTH-1:0] stat_counter = {COUNTER_WIDTH{1'b0}};
	reg [VALUE_WIDTH-1:0] stat_counter_latched = {VALUE_WIDTH{1'b0}};
	reg [VALUE_WIDTH-1:0] stat_counter_valclk = {VALUE_WIDTH{1'b0}};
	wire latch_valclk;
	
	// Have we seen the value we're supposed to be sampling?
	always @(posedge clk_count_i) begin
		if (count_ce_i) count_seen <= 0;
		else if (count_i) count_seen <= 1;
	end
	// Counter.
	always @(posedge clk_count_i) begin
		if (pps_i) stat_counter <= {COUNTER_WIDTH{1'b0}};
		else if (count_ce_i && count_seen) stat_counter <= stat_counter + 1;
	end
	// Latch
	always @(posedge clk_count_i) begin
		if (pps_i) stat_counter_latched <= stat_counter[COUNTER_WIDTH-1:COUNTER_WIDTH-VALUE_WIDTH];
	end
	// Transfer
	flag_sync pps_sync(.in_clkA(pps_i),.out_clkB(latch_valclk),.clkA(clk_count_i),.clkB(clk_val_i));
	always @(posedge clk_val_i) begin
		if (latch_valclk) stat_counter_valclk <= stat_counter_latched;
	end
	
	assign value_o = stat_counter_valclk;

endmodule
