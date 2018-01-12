`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:59:19 03/01/2012
// Design Name:   irs3_serial_dac_init
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim//irs3_serial_dac_init_tb.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: irs3_serial_dac_init
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module irs3_serial_dac_init_tb;

	// Inputs
	reg clk_i;
	reg irs_init_i;
	reg irs_mode_i;
	reg irs_shout_i;

	// Outputs
	wire irs_sclk_o;
	wire irs_sin_o;
	wire irs_regclr_o;
	wire irs_pclk_o;

	// Instantiate the Unit Under Test (UUT)
	irs3_serial_dac_init uut (
		.clk_i(clk_i), 
		.irs_init_i(irs_init_i), 
		.irs_mode_i(irs_mode_i), 
		.irs_sclk_o(irs_sclk_o), 
		.irs_sin_o(irs_sin_o), 
		.irs_shout_i(irs_shout_i), 
		.irs_regclr_o(irs_regclr_o), 
		.irs_pclk_o(irs_pclk_o)
	);

	always begin
		#5 clk_i = ~clk_i;
	end

	initial begin
		// Initialize Inputs
		clk_i = 0;
		irs_init_i = 0;
		irs_mode_i = 0;
		irs_shout_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		@(posedge clk_i);
		irs_mode_i = 1;
		@(posedge clk_i);
		irs_init_i = 1;
	end
      
	reg [144:0] irs_shift_reg = {145{1'b0}};
	reg [144:0] irs_dac_reg = {145{1'b0}};
	wire sgn = irs_dac_reg[ 0 +: 1 ];
	wire [11:0] TRGbias = irs_dac_reg[ 1 +: 12];
	wire [11:0] TBbias = irs_dac_reg[ 13 +: 12];
	wire [11:0] ch8thr = irs_dac_reg[ 25 +: 12];
	wire [11:0] ch7thr = irs_dac_reg[ 37 +: 12];
	wire [11:0] ch6thr = irs_dac_reg[ 49 +: 12];
	wire [11:0] ch5thr = irs_dac_reg[ 61 +: 12];
	wire [11:0] ch4thr = irs_dac_reg[ 73 +: 12];
	wire [11:0] ch3thr = irs_dac_reg[ 85 +: 12];
	wire [11:0] ch2thr = irs_dac_reg[ 97 +: 12];
	wire [11:0] ch1thr = irs_dac_reg[109 +: 12];
	wire [11:0] TRGthref = irs_dac_reg[121 +: 12];
	wire [11:0] SBbias = irs_dac_reg[133 +: 12];
	always @(posedge irs_regclr_o) begin
		irs_shift_reg <= {145{1'b0}};
		irs_dac_reg <= {145{1'b0}};
	end
	always @(posedge irs_pclk_o) begin
		irs_dac_reg = irs_shift_reg;
		#1;
		$display("sgn: %d", sgn);
		$display("TRGbias: %d", TRGbias);
		$display("TBbias: %d", TBbias);
		$display("thresh: %d %d %d %d %d %d %d %d", ch1thr, ch2thr, ch3thr, ch4thr, ch5thr, ch6thr, ch7thr, ch8thr);
		$display("TRGthref: %d", TRGthref);
		$display("SBbias: %d", SBbias);
	end
	always @(posedge irs_sclk_o) begin
		irs_shift_reg <= {irs_shift_reg[144:0],irs_sin_o};
	end
	
		
endmodule

