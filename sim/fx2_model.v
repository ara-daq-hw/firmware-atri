`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:24:25 08/27/2012 
// Design Name: 
// Module Name:    fx2_model 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module fx2_model(
		input [7:0] PA,
		inout [7:0] PB,
		inout [7:0] PC,
		inout [7:0] PD,
		inout [7:0] PE,
		input SLRD,
		input SLWR,
		output FLAGA,
		output FLAGB,
		output FLAGC,
		output IFCLK
	);
	parameter [7:0] IFCONFIG = 8'h80;
	parameter [7:0] EP2CFG = 8'h00;
	parameter [7:0] EP4CFG = 8'h00;
	parameter [7:0] EP6CFG = 8'h00;
	parameter [7:0] EP8CFG = 8'h00;
	
	localparam ifconfig_period = (IFCONFIG[6]) ? 10.415 : 16.66;
	
	reg ifclk_reg = 0;
	
	always begin
		#ifconfig_period ifclk_reg = ~ifclk_reg;
	end
	wire ifclk_pol = (IFCONFIG[4]) ? ~ifclk_pol : ifclk_pol;
	assign IFCLK = (IFCONFIG[5]) ? ifclk_pol : 1'bZ;
	
	// blah, muck with this later
	reg [7:0] ep2[1:0][511:0];
	reg [7:0] ep6[1:0][511:0];
	integer i,j;
	initial begin
		for (i=0;i<2;i=i+1)
			for (j=0;j<512;j=j+1) begin
				ep2[i][j] <= {8{1'b0}};
				ep6[i][j] <= {8{1'b0}};
			end
	end
	
	wire [1:0] fifoadr = PA[5:4];
	wire FLAGD;
	assign PA[7] = FLAGD;
	wire PKTEND = PA[6];
	wire SLOE = PA[2];
		
	
endmodule
