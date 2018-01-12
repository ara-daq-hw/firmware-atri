`timescale 1ns / 1ps
// Simple flag generator + holdoff.
module ext_trigger_generator(
    input clk_i,
    input micro_ce_i,
    input trig_i,
    output trig_o
    );

	reg [3:0] holdoff = {4{1'b0}};
	reg trigger_holdoff = 0;
	wire ext_trig_flag;
	SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"),.LATENCY(2)) ext_flag_generator(.I(trig_i),.O(ext_trig_flag),.CLK(clk_i));
	always @(posedge clk_i) begin
		if (ext_trig_flag) trigger_holdoff <= 1;
		else if (holdoff == 4'hF && micro_ce_i) trigger_holdoff <= 0;
	end
	always @(posedge clk_i) begin
		if (ext_trig_flag && !trigger_holdoff) holdoff <= holdoff + 1;
		else if (micro_ce_i && (trigger_holdoff != 4'h0)) holdoff <= holdoff + 1;
	end
	reg trigger_out = 0;
	always @(posedge clk_i) begin
		trigger_out <= ext_trig_flag && !trigger_holdoff;
	end
	assign trig_o = trigger_out;
endmodule
