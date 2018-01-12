`timescale 1ns / 1ps

//% @brief trigger_scaler_map Takes the raw trigger inputs and one-shots them.
module trigger_scaler_map(
		fast_clk_i,
		slow_clk_i,
		slow_ce_i,
		trigger_i,
		tda_power_i,
		tda_trig_p_o,
		tda_trig_n_o,
		tda_scal_o,
		rsvd_trig_p_o,
		rsvd_trig_n_o,
		rsvd_scal_o
    );
	
	input fast_clk_i;
	input slow_clk_i;
	input slow_ce_i;
	input [7:0] trigger_i;
	input tda_power_i;
	output [3:0] tda_trig_p_o;
	output [3:0] tda_trig_n_o;
	output [3:0] tda_scal_o;
	output [3:0] rsvd_trig_p_o;
	output [3:0] rsvd_trig_n_o;
	output [3:0] rsvd_scal_o;
	
	generate
		genvar i;
		for (i=0;i<4;i=i+1) begin : CHLOOP
			trigger_scaler tda_ts(.power_i(tda_power_i),.trigger_i(trigger_i[i]),.trig_p_o(tda_trig_p_o[i]),.trig_n_o(tda_trig_n_o[i]),
										 .scaler_o(tda_scal_o[i]),.fast_clk_i(fast_clk_i),.slow_clk_i(slow_clk_i),
										 .slow_ce_i(slow_ce_i));
			trigger_scaler rsvd_ts(.power_i(1'b1),.trigger_i(trigger_i[4+i]),.trig_p_o(rsvd_trig_p_o[i]),.trig_n_o(rsvd_trig_n_o[i]),
										 .scaler_o(rsvd_scal_o[i]),.fast_clk_i(fast_clk_i),.slow_clk_i(slow_clk_i),
										 .slow_ce_i(slow_ce_i));
		end
	endgenerate
	
endmodule
