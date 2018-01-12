`timescale 1ns / 1ps
//
// See
// http://asicdigitaldesign.wordpress.com/2007/05/14/counting-in-gray-part-iii-putting-everything-together/
//
module Simple_Gray_Counter_Cell(
		input Q_i,
		input Z_i,
		input C,
		input up_n_dn,
		input parity,
		input enable,
		input rst,
		output Q_o,
		output Z_o
    );

	reg cell_ff = 1'b0;
	wire cell_ff_input = (enable && Q_i) && Z_i && (up_n_dn ^ parity);
	always @(posedge C or posedge rst) begin
		if (rst)
			cell_ff <= 1'b0;
		else
			cell_ff <= cell_ff_input ^ cell_ff;
	end

	assign Q_o = cell_ff;
	assign Z_o = ~Q_i && Z_i;
endmodule
