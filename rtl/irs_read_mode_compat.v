`timescale 1ns / 1ps

//% Compatibility module for IRS2/IRS3. Handles serial DAC init, etc.
module irs_read_mode_compat(
		clk_i,
		rst_i,
		rdout_rd_i,
		irs_rd_i,
		irs_rdo_o,
		irs_rdoe_o,
		power_i,
		drive_i,
		init_i,
		mode_i,
		sbbias_i,
		wilk_start_i,
		busy_o
    );

	input clk_i;
	input rst_i;
	input [9:0] rdout_rd_i;
	output [9:0] irs_rdo_o;
	input [9:0] irs_rd_i;
	output [9:0] irs_rdoe_o;
	input power_i;
	input drive_i;
	input init_i;
	input mode_i;
	input [11:0] sbbias_i;
	input wilk_start_i;
	output busy_o;
	
	wire irs3_regclr;
	wire irs3_pclk;
	wire irs3_sclk;
	wire irs3_sin;
	wire irs3_init_busy;
	
	wire irs3_rdo6 = (irs3_sclk || (wilk_start_i && !irs3_init_busy));
	
	// RD[2:0] are always handled in the block readout, and always driven.
	assign irs_rdo_o[2:0] = rdout_rd_i[2:0];
	assign irs_rdoe_o[2:0] = 3'b111;
	// RD[3] is SHOUT on an IRS3. Only driven when DRIVE is set and not in IRS3 mode.
	assign irs_rdo_o[3] = rdout_rd_i[3];
	assign irs_rdoe_o[3] = !(mode_i || !drive_i);
	// RD[7:4] are handled by block readout on IRS2, and serial init on IRS3.
	assign irs_rdo_o[4] = (mode_i) ? irs3_regclr : rdout_rd_i[4];
	assign irs_rdo_o[5] = (mode_i) ? irs3_pclk : rdout_rd_i[5];
	assign irs_rdo_o[6] = (mode_i) ? irs3_rdo6 : rdout_rd_i[6];
	assign irs_rdo_o[7] = (mode_i) ? irs3_sin : rdout_rd_i[7];
	assign irs_rdoe_o[7:4] = {4{1'b1}};
	// RD[9:8] are undriven on an IRS3.
	assign irs_rdo_o[9:8] = rdout_rd_i[9:8];
	assign irs_rdoe_o[9:8] = {2{!(mode_i || !drive_i)}};
	
	irs3_serial_dac_init irs3_dacinit(.clk_i(clk_i),
												 .irs_init_i(init_i && drive_i),
												 .sbbias_i(sbbias_i),
												 .irs_mode_i(mode_i),
												 .irs_sclk_o(irs3_sclk),
												 .irs_sin_o(irs3_sin),
												 .irs_shout_i(irs_rd_i[3]),
												 .irs_regclr_o(irs3_regclr),
												 .irs_pclk_o(irs3_pclk),
												 .irs_dac_busy_o(irs3_init_busy));

	assign busy_o = (mode_i) ? irs3_init_busy : 1'b0;
endmodule
