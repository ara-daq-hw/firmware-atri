`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Generates flags whenever an event occurs and whenever a new trigger occurs.
//
// An event occurs by definition at the rising edge of the combined trigger.
// A new trigger occurs by definition at the rising edge of each trigger bit.
//////////////////////////////////////////////////////////////////////////////////
module event_and_trigger_flag_generator #(parameter NUM_TRIGGERS = 4)
	(
		input g_trigger_i,
		input [NUM_TRIGGERS-1:0] triggers_i,
		input clk_i,
		input rst_i,
		output event_flag_o,
		output [NUM_TRIGGERS-1:0] trig_flag_o
    );

	reg g_trigger_latched = 0;
	reg [NUM_TRIGGERS-1:0] trig_latched = {NUM_TRIGGERS{1'b0}};

	always @(posedge clk_i) begin
		g_trigger_latched <= g_trigger_i;
	end
	always @(posedge clk_i) begin
		trig_latched <= triggers_i;
	end
	
	assign event_flag_o = (g_trigger_i && !g_trigger_latched);
	generate
		genvar i;
		for (i=0;i<NUM_TRIGGERS;i=i+1) begin : LOOP
			assign trig_flag_o[i] = (triggers_i && !trig_latched[i]);
		end
	endgenerate

endmodule
