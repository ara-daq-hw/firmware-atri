`timescale 1ns / 1ps
//% Write address generator. Also uses an IODELAY.
module wr_addr_gen(
		input [9:0] wraddr_i,
		input clk_i,
		input CE,
		output [9:0] wraddr_o
    );

	// We want to delay WRADDR by ~5 ns. 
	localparam WRADDR_DELAY_VAL = 64;
	localparam WIDTH = 10;
	wire [WIDTH-1:0] wraddr_to_iodelay;
	generate
		genvar i;
		for (i=0;i<WIDTH;i=i+1) begin : WRDLY
			(* IOB = "TRUE" *) (* INIT = 0 *) FDE wr_ff(.D(wraddr_i[i]),.C(clk_i),.CE(CE),.Q(wraddr_to_iodelay[i]));
			IODELAY2 #(.ODELAY_VALUE(WRADDR_DELAY_VAL),.IDELAY_TYPE("FIXED"),.DELAY_SRC("ODATAIN"))
				wraddr_delay(.ODATAIN(wraddr_to_iodelay[i]),.DOUT(wraddr_o[i]));
		end
	endgenerate

endmodule
