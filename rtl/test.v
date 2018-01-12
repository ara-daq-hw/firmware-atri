`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:42:44 07/22/2012 
// Design Name: 
// Module Name:    test 
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
module test1(
		input [15:0] A,
		output [15:0] B
    );

	parameter T2PAR1 = t2.PAR1;
	test2 t2(A, B);
	

endmodule

module test2(
		A,
		B
	 );
	parameter PAR1 = 12;
	
endmodule
