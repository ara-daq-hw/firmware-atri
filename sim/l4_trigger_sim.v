`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   15:16:47 08/09/2012
// Design Name:   l4_trigger_3of8
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/l4_trigger_sim.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: l4_trigger_3of8
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module l4_trigger_sim;

	// Inputs
	reg [1:0] L3_i;
	reg L4_mask_i;
	reg clk_i;
	reg [7:0] blocks_i;
	reg rst_i;

	// Outputs
	wire L4_o;
	wire L4_scaler_o;

	// Instantiate the Unit Under Test (UUT)
	l4_trigger_3of8 uut (
		.L3_i(L3_i), 
		.L4_mask_i(L4_mask_i), 
		.L4_o(L4_o), 
		.L4_scaler_o(L4_scaler_o), 
		.clk_i(clk_i), 
		.blocks_i(blocks_i), 
		.rst_i(rst_i)
	);
	always begin
		#5 clk_i = ~clk_i;
	end

	initial begin
		// Initialize Inputs
		L3_i = 0;
		L4_mask_i = 0;
		clk_i = 0;
		blocks_i = 0;
		rst_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		@(posedge clk_i);
		blocks_i = 29;
		@(posedge clk_i);
		@(posedge clk_i);
		L3_i <= 2'b01;
		@(posedge clk_i);
		@(posedge clk_i);
		L3_i <= 2'b00;
	end
      
endmodule

