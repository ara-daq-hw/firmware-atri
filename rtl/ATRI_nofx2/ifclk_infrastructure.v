`timescale 1ns / 1ps
// dumb module to generate the 48 MHz from the PCIe
// the input clock is 100 MHz, output is 48 MHz
// 100 = 2*2*5*5
// 48 =  2*2*2*2*3
// mult by 12 divide by 25

// goddamnit: pcie_clk is 62.5M, not 100M. This is
// Just What Xillybus Does.
// 62.5 = 5^4 * 100E5
//   48 = 2*2*2*2*3*2*5 * 100E5
// factoring gives
// 5*5*5
// 2*2*2*2
// 96x / 125
module ifclk_infrastructure( input pcie_clk,
									  input rst_i,
									  output rst_o,
									  output ifclk,
									  output icapclk);
	wire locked;
	assign rst_o = !locked;
	
	// clkfx is f_clkin * f_clkfx_multiple/f_clkfx_divide
	// mult by 16 divide by 25 to generate clk40
	DCM_CLKGEN #(.CLKFX_MULTIPLY(96),
					 .CLKFX_DIVIDE(125),
					 .CLKFXDV_DIVIDE(4),
					 .CLKIN_PERIOD(10.0))
					 u_clk40(.PROGEN(1'b0),
								.FREEZEDCM(1'b0),
								.RST(rst_i),
								.LOCKED(locked),
								.CLKIN(pcie_clk),
								.CLKFX(ifclk),
							   .CLKFXDV(icapclk));
endmodule									  
									  