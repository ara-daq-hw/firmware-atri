`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:04:05 01/12/2018
// Design Name:   trigger_handling_v2
// Module Name:   C:/cygwin/home/barawn/repositories/github/firmware-atri/sim/trig_processor_tb.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: trigger_handling_v2
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////
`include "../rtl/trigger_defs.vh"

module trig_processor_tb;
	parameter NUM_L4 = `SCAL_NUM_L4;
	parameter DELAY_BITS = `DELAY_BITS;
	parameter PRETRG_BITS = `PRETRG_BITS;

	// Inputs
	reg [PRETRG_BITS-1:0] pretrigger[NUM_L4-1:0];
	reg [DELAY_BITS-1:0] delays[NUM_L4-1:0];
	
	wire [NUM_L4*PRETRG_BITS-1:0] pretrigger_vector_i;
	wire [NUM_L4*DELAY_BITS-1:0] delay_vector_i;
	generate
		genvar i;
		for (i=0;i<NUM_L4;i=i+1) begin : LP
			assign pretrigger_vector_i[i*PRETRG_BITS +: PRETRG_BITS] = pretrigger[i];
			assign delay_vector_i[i*DELAY_BITS +: DELAY_BITS] = delays[i];
		end
	endgenerate
	
	reg [NUM_L4-1:0] l4_i;
	reg [NUM_L4-1:0] l4_new_i;
	reg T1_mask_i;
	reg clk_i;
	reg rst_i;
	reg disable_i;
	reg disable_ce_i;

	always begin
		#5 clk_i = ~clk_i;
	end
	

	// Outputs
	wire [NUM_L4-1:0] l4_matched_o;
	wire [NUM_L4-1:0] l4_new_o;
	wire T1_o;
	wire T1_scaler_o;
	wire [8:0] T1_offset_o;

	// Instantiate the Unit Under Test (UUT)
	trigger_handling_v2 uut (
		.pretrigger_vector_i(pretrigger_vector_i), 
		.delay_vector_i(delay_vector_i), 
		.l4_i(l4_i), 
		.l4_new_i(l4_new_i), 
		.T1_mask_i(T1_mask_i), 
		.l4_matched_o(l4_matched_o), 
		.l4_new_o(l4_new_o), 
		.T1_o(T1_o), 
		.T1_scaler_o(T1_scaler_o), 
		.T1_offset_o(T1_offset_o), 
		.clk_i(clk_i), 
		.rst_i(rst_i), 
		.disable_i(disable_i), 
		.disable_ce_i(disable_ce_i)
	);

	always @(posedge clk_i) begin
		disable_ce_i <= ~disable_ce_i;
	end

	initial begin
		// Initialize Inputs
		pretrigger[0] = 53;
		pretrigger[1] = 0;
		pretrigger[2] = 0;
		pretrigger[3] = 0;
		pretrigger[4] = 0;
		delays[0] = 0;
		delays[1] = 0;
		delays[2] = 0;
		delays[3] = 0;
		delays[4] = 0;
		
		l4_i = 0;
		l4_new_i = 0;
		T1_mask_i = 0;
		clk_i = 0;
		rst_i = 0;
		disable_i = 0;
		disable_ce_i = 0;

		#100;
		@(posedge clk_i);
		while (disable_ce_i) @(posedge clk_i);
		disable_i = 1;
		// Wait 100 ns for global reset to finish
		#2000;
		while (disable_ce_i) @(posedge clk_i);
		disable_i = 0;
      
		// first set of triggers. These won't work.
		@(posedge clk_i);
		l4_i[0] = 1;
		l4_new_i[0] = 1;
		l4_i[1] = 1;
		l4_new_i[1] = 1;
		@(posedge clk_i);
		l4_new_i[0] = 0;
		l4_new_i[1] = 0;
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		l4_i[0] = 0;
		l4_i[1] = 0;		

		#1000;

		// next set. these will.
		@(posedge clk_i);
		l4_i[0] = 1;
		l4_new_i[0] = 1;
		l4_i[1] = 1;
		l4_new_i[1] = 1;
		@(posedge clk_i);
		l4_new_i[0] = 0;
		l4_new_i[1] = 0;
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		l4_i[0] = 0;
		l4_i[1] = 0;		


	end
endmodule

