
`timescale 1ns / 1ps
module atri_readout_rom(
		input clk,
		output [17:0] instruction,
		input [9:0] address
    );

	wire [31:0] doa;
	wire [3:0] dopa;

	RAMB16BWER #( .DATA_WIDTH_A(18),.DATA_WIDTH_B(0),
	`include "atrireadout_rom.vh"
		)
	bram (.CLKA(clk),.WEA(1'b0),.ENA(1'b1),.ADDRA({address,4'b0}),.DOA(doa),.DOPA(dopa),.RSTA(1'b0));
	assign instruction[15:0] = doa[15:0];
	assign instruction[17:16] = dopa[1:0];
endmodule
