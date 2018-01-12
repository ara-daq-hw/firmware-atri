`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   13:37:02 08/14/2012
// Design Name:   trigger_top_v2
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/trigger_top_test.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: trigger_top_v2
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

`include "wb_interface.vh"

module trigger_top_test;

	// Inputs
	reg [7:0] d1_trig_i;
	reg [7:0] d2_trig_i;
	reg [7:0] d3_trig_i;
	reg [7:0] d4_trig_i;
	reg [7:0] d1_pwr_i;
	reg [7:0] d2_pwr_i;
	reg [7:0] d3_pwr_i;
	reg [7:0] d4_pwr_i;
	reg fclk_i;
	reg sclk_i;
	reg sce_i;
	reg pps_flag_fclk_i;
	reg [2:0] l4_ext_i;
	reg disable_i;

	// Outputs
	wire trig_o;
	wire [3:0] trig_l4_o;
	wire [8:0] trig_delay_o;
	wire [31:0] trig_info_o;

	// Bidirs
	wire [`WBIF_SIZE-1:0] scal_wbif_io;
	wire [`WBIF_SIZE-1:0] trig_wbif_io;

	// Instantiate the Unit Under Test (UUT)
	trigger_top_v2 uut (
		.d1_trig_i(d1_trig_i), 
		.d2_trig_i(d2_trig_i), 
		.d3_trig_i(d3_trig_i), 
		.d4_trig_i(d4_trig_i), 
		.d1_pwr_i(d1_pwr_i), 
		.d2_pwr_i(d2_pwr_i), 
		.d3_pwr_i(d3_pwr_i), 
		.d4_pwr_i(d4_pwr_i), 
		.fclk_i(fclk_i), 
		.sclk_i(sclk_i), 
		.sce_i(sce_i), 
		.pps_flag_fclk_i(pps_flag_fclk_i), 
		.l4_ext_i(l4_ext_i), 
		.scal_wbif_io(scal_wbif_io), 
		.trig_wbif_io(trig_wbif_io), 
		.disable_i(disable_i), 
		.trig_o(trig_o), 
		.trig_l4_o(trig_l4_o), 
		.trig_delay_o(trig_delay_o), 
		.trig_info_o(trig_info_o)
	);

	initial begin
		// Initialize Inputs
		d1_trig_i = 0;
		d2_trig_i = 0;
		d3_trig_i = 0;
		d4_trig_i = 0;
		d1_pwr_i = 0;
		d2_pwr_i = 0;
		d3_pwr_i = 0;
		d4_pwr_i = 0;
		fclk_i = 0;
		sclk_i = 0;
		sce_i = 0;
		pps_flag_fclk_i = 0;
		l4_ext_i = 0;
		disable_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

