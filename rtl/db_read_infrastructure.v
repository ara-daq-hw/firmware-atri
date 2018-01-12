`timescale 1ns / 1ps
// Should be replaced by the IRS infrastructure module.
module db_read_infrastructure(
		input [9:0] OE,
		input [9:0] I,
		inout [9:0] IO,
		output [9:0] O
    );

	generate
		genvar i;
		for (i=0;i<10;i=i+1) begin : IOBUF_RD
			IOBUF rd_iobuf(.I(I[i]),.O(O[i]),.IO(IO[i]),.T(!OE[i]));
		end
	endgenerate
endmodule
