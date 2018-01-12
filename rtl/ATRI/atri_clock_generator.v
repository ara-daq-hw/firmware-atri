`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Infrastructure for generating the IRS system clock on an ATRI board.
//
//////////////////////////////////////////////////////////////////////////////////
module atri_clock_generator(
		input FPGA_REFCLK_P,
		input FPGA_REFCLK_N,
		output irs_sys_clk,
		output irs_sys_clk180
    );

	wire REFCLK_to_BUFG;
	wire nREFCLK_to_BUFG;
	wire xCLK;
	wire nxCLK;
	IBUFGDS_DIFF_OUT refclk_ibufgds(.I(FPGA_REFCLK_P),.IB(FPGA_REFCLK_N),.O(REFCLK_to_BUFG),
											  .OB(nREFCLK_to_BUFG));
	BUFG xclk_bufg(.I(REFCLK_to_BUFG),.O(irs_sys_clk));
	BUFG nxclk_bufg(.I(nREFCLK_to_BUFG),.O(irs_sys_clk180));
	

endmodule
