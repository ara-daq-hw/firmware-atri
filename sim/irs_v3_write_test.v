`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:01:22 04/02/2012
// Design Name:   irs_write_controller_v3
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim//irs_v3_write_test.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: irs_write_controller_v3
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module irs_v3_write_test;

	// Inputs
	reg clk_i;
	wire enable_i;
	reg rst_i;
	reg ssp_clk_i;
	reg wrstrb_clk_i;
	wire [8:0] wr_block_i;

	// Outputs
	wire wr_phase_o;
	wire wr_ack_o;
	wire ssp_o;
	wire sst_o;
	wire wrstrb_o;
	wire [9:0] wr_o;
	wire dbg_ssp_o;
	wire dbg_sst_o;
	wire dbg_wrstrb_o;
	wire [9:0] dbg_wr_o;

	reg ped_mode = 0;
	reg blockman_en = 0;
	reg [8:0] ped_address = {9{1'b0}};
	wire ped_ack;

	// Block manager.
	irs_simple_block_manager_v3 bm(.clk_i(clk_i),.rst_i(rst_i),.en_i(blockman_en),
											.blk_phase_i(wr_phase_o),.blk_en_o(enable_i),
											.blk_o(wr_block_i),.blk_ack_i(wr_ack_o),
											.ped_mode_i(ped_mode),.ped_address_i(ped_address),
											.ped_ack_o(ped_ack));
	// Write controller.
	irs_write_controller_v3 uut (
		.clk_i(clk_i), 
		.enable_i(enable_i), 
		.rst_i(rst_i), 
		.ssp_clk_i(ssp_clk_i), 
		.wrstrb_clk_i(wrstrb_clk_i), 
		.wr_block_i(wr_block_i), 
		.wr_phase_o(wr_phase_o), 
		.wr_ack_o(wr_ack_o), 
		.ssp_o(ssp_o), 
		.sst_o(sst_o), 
		.wrstrb_o(wrstrb_o), 
		.wr_o(wr_o), 
		.dbg_ssp_o(dbg_ssp_o), 
		.dbg_sst_o(dbg_sst_o), 
		.dbg_wrstrb_o(dbg_wrstrb_o), 
		.dbg_wr_o(dbg_wr_o)
	);

	// 
	always begin
		#2.5 wrstrb_clk_i = 1;
		#2.5 clk_i = 1; ssp_clk_i = 0;
		#2.5 wrstrb_clk_i = 0;
		#2.5 clk_i = 0; ssp_clk_i = 1;
	end

	initial begin
		// Initialize Inputs
		clk_i = 0;
		rst_i = 0;
		ssp_clk_i = 1;
		wrstrb_clk_i = 0;
	
		// Wait 100 ns for global reset to finish
		#500;
        
		// Add stimulus here
		@(posedge clk_i) rst_i = 1;
		@(posedge clk_i);
		@(posedge clk_i) rst_i = 0;
		@(posedge clk_i);
		@(posedge clk_i) blockman_en = 1;
	end
      
endmodule

