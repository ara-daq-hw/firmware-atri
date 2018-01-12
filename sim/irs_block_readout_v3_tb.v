`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   13:30:08 03/05/2012
// Design Name:   irs_block_readout_v3
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/irs_block_readout_v3_tb.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: irs_block_readout_v3
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module irs_block_readout_v3_tb;

	// Inputs
	reg clk_i;
	reg rst_i;
	reg [8:0] raddr_i;
	reg raddr_stb_i;
	reg [7:0] ch_mask_i;
	reg irs_mode_i;
	reg [11:0] irs_dat_i;

	// Outputs
	wire rst_ack_o;
	wire raddr_ack_o;
	wire [8:0] block_addr_o;
	wire [11:0] block_dat_o;
	wire block_start_o;
	wire block_valid_o;
	wire block_done_o;
	wire [7:0] block_mask_o;
	wire [9:0] irs_rd_o;
	wire irs_rden_o;
	wire [5:0] irs_smp_o;
	wire [2:0] irs_ch_o;
	wire irs_smpall_o;
	wire irs_start_o;
	wire irs_clr_o;
	wire irs_ramp_o;
	wire irs_address_sel_o;
	wire irs_ramping_o;
	wire irs_readout_o;
	wire [47:0] debug_o;

	// Instantiate the Unit Under Test (UUT)
	irs_block_readout_v3 uut (
		.clk_i(clk_i), 
		.rst_i(rst_i), 
		.rst_ack_o(rst_ack_o), 
		.raddr_i(raddr_i), 
		.raddr_stb_i(raddr_stb_i), 
		.raddr_ack_o(raddr_ack_o), 
		.ch_mask_i(ch_mask_i), 
		.irs_mode_i(irs_mode_i), 
		.block_addr_o(block_addr_o), 
		.block_dat_o(block_dat_o), 
		.block_start_o(block_start_o), 
		.block_valid_o(block_valid_o), 
		.block_done_o(block_done_o), 
		.block_mask_o(block_mask_o), 
		.irs_rd_o(irs_rd_o), 
		.irs_rden_o(irs_rden_o), 
		.irs_smp_o(irs_smp_o), 
		.irs_ch_o(irs_ch_o), 
		.irs_smpall_o(irs_smpall_o), 
		.irs_dat_i(irs_dat_i), 
		.irs_start_o(irs_start_o), 
		.irs_clr_o(irs_clr_o), 
		.irs_ramp_o(irs_ramp_o), 
		.irs_address_sel_o(irs_address_sel_o), 
		.irs_ramping_o(irs_ramping_o), 
		.irs_readout_o(irs_readout_o), 
		.debug_o(debug_o)
	);

	always begin
		#5 clk_i = ~clk_i;
	end

	initial begin
		// Initialize Inputs
		clk_i = 0;
		rst_i = 0;
		raddr_i = 0;
		raddr_stb_i = 0;
		ch_mask_i = 8'hFF;
		irs_mode_i = 0;
		irs_dat_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Assert reset_i, see if that works..
		@(posedge clk_i) rst_i = 1;
		@(posedge clk_i);
		while (!rst_ack_o) @(posedge clk_i);
		rst_i = 0;
		@(posedge clk_i);
		// Try out IRS3 mode.
		irs_mode_i = 1;
		@(posedge clk_i);
		// Assert a read address, and strobe it.
		raddr_i = 9'h000;
		raddr_stb_i = 1;
		@(posedge clk_i);
		while (!raddr_ack_o) @(posedge clk_i);
		raddr_stb_i = 0;
		@(posedge clk_i);
		raddr_i = 9'h001;
		raddr_stb_i = 1;
		@(posedge clk_i);
		while (!raddr_ack_o) @(posedge clk_i);
		raddr_stb_i = 0;		
		
	end
      
endmodule

