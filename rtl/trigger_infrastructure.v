`timescale 1ns / 1ps
//% @file trigger_infrastructure.v Contains trigger infrastructure module.

//% @brief Contains infrastructure (IBUFs) for triggers.
module trigger_infrastructure(
		input [7:0] trig_p_i,
		input [7:0] trig_n_i,
		output [7:0] trig_o
    );

	generate
		genvar i;
		for (i=0;i<8;i=i+1) begin : TIBUF
			IBUFDS trig_ibufds(.I(trig_p_i[i]),.IB(trig_n_i[i]),.O(trig_o[i]));
		end
	endgenerate
endmodule
