`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Generic adder with carry-out and parametrized data width. Used in the
// Generic_Pipelined_Adder.
//
//////////////////////////////////////////////////////////////////////////////////
module Generic_Adder(
		A,
		B,
		Q,
		CI,
		CO
    );

	parameter WIDTH = 32;
	input [WIDTH-1:0] A;
	input [WIDTH-1:0] B;
	output [WIDTH-1:0] Q;
	input CI;
	output CO;
	
	// xA, xB are A, B expanded by 1 bit to handle carry.
	// xQ is the sum of xA, xB
	wire [WIDTH:0] xA;
	assign xA[WIDTH-1:0] = A;
	assign xA[WIDTH] = 0;
	wire [WIDTH:0] xB;
	assign xB[WIDTH-1:0] = B;
	assign xB[WIDTH] = 0;
	
	wire [WIDTH:0] xQ;
	assign xQ = xA + xB + CI;
	assign Q = xQ[WIDTH-1:0];
	assign CO = xQ[WIDTH];
endmodule
