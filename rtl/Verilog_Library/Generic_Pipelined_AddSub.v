`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Adder/subtractor with parametrizable pipeline delay. See
// Generic_Pipelined_Adder, as all this does is two's complement the input and add
// the 1 (via carry-in) when nSUB is asserted.
//
//////////////////////////////////////////////////////////////////////////////////
module Generic_Pipelined_AddSub(
		A,
		B,
		Q,
		CO,
		CLK,
		nSUB,
		EVAL,
		VALID
    );

	parameter WIDTH = 32;
	parameter LATENCY = 4;
	parameter ALWAYS_VALID = "TRUE";

	input [WIDTH-1:0] A;
	input [WIDTH-1:0] B;
	output [WIDTH-1:0] Q;
	output CO;
	input CLK;
	input nSUB;
	input EVAL;
	output VALID;

	wire [WIDTH-1:0] B_addsub;
	generate
		genvar addsub_iter;
		for (addsub_iter=0;addsub_iter<WIDTH;addsub_iter=addsub_iter+1) begin : ADDSUB_LOOP
			assign B_addsub[addsub_iter] = B[addsub_iter] ^ nSUB;
		end
	endgenerate

	Generic_Pipelined_Adder #(.WIDTH(WIDTH),.LATENCY(LATENCY),.ALWAYS_VALID(ALWAYS_VALID))
		adder(.A(A),.B(B_addsub),.CI(nSUB),.CO(CO),.Q(Q),.ADD(EVAL),.VALID(VALID),.CLK(CLK));

endmodule
