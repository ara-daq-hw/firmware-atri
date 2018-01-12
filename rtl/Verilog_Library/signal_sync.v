`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Signal synchronizer.
//
// Blatantly stolen from fpga4fun.com/CrossClockDomain1.html.
//
//////////////////////////////////////////////////////////////////////////////////
module signal_sync(
    input clkA,
    input clkB,
    input in_clkA,
    output out_clkB
    );

	reg [1:0] SyncA_clkB = {2{1'b0}};
	always @(posedge clkB) SyncA_clkB[0] <= in_clkA;
	always @(posedge clkB) SyncA_clkB[1] <= SyncA_clkB[0];
	
	assign out_clkB = SyncA_clkB[1];
endmodule
