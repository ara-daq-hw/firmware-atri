
`timescale 1ns / 1ps
module atri_i2c_rom(
		input clk,
		output [17:0] instruction,
		input [9:0] address,
		output reset,
		input jump_wr_stb,
		input [7:0] ram_data_in,
		output [7:0] ram_data_out,
		input [7:0] ram_address,
		input ram_wr_stb
    );

	wire WEA = ram_wr_stb | jump_wr_stb;
	wire [10:0] ADDRA = (jump_wr_stb) ? 11'h6FE : {3'b111,ram_address};

	RAMB16_S9_S18 #(
	`include "atrii2c_rom.vh"
		)
	bram (.CLKB(clk),.WEB(1'b0),.ENB(1'b1),.ADDRB(address),.DIPB(2'b00),.DIB(16'h0000),
			.DOB(instruction[15:0]),.DOPB(instruction[17:16]),.SSRB(1'b0),
			.CLKA(clk),.WEA(WEA),.ENA(1'b1),.ADDRA(ADDRA),.DIPA(jump_wr_stb),.DIA(ram_data_in),
			.DOA(ram_data_out), .SSRA(1'b0));
endmodule
