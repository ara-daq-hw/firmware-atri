`timescale 1ns / 1ps
//% @file atri_pps_flag_generator.v Contains atri_pps_flag_generator module.

//% @brief atri_pps_flag_generator Generates debounced PPS and PPS flag.
//%
//% What this should do:
//%
//% This should generate a PPS_PULSE_WIDTH-cycle long pulse whenever PPS_IN goes high.
//% It then holds off the PPS for 2^PPS_DEBOUNCE_BITS KHz_CE_i pulses.
//% It also outputs a single-cycle flag (synchronous to clk_i) for the PPS. The flag
//% occurs after the pps_async_o pulse goes low.
module atri_pps_flag_generator(
		input clk_i,
		input PPS_IN,
		input KHz_CE_i,
		output pps_o,
		output pps_async_o,
		output pps_flag_o
    );

	reg pps_flag = 0;
	wire PPS_IN_to_LATCH;
	reg PPS_IN_EN = 1;
	wire PPS_IN_CLR;
	
	parameter PPS_PULSE_WIDTH = 4;
	parameter PPS_DEBOUNCE_BITS = 8;

	reg [PPS_PULSE_WIDTH-1:0] pps_in_shreg = {PPS_PULSE_WIDTH{1'b0}};
	reg [PPS_DEBOUNCE_BITS-1:0] pps_in_debounce = {PPS_DEBOUNCE_BITS{1'b0}};
	wire PPS_LATCH;
	IBUF pps_in_ibuf(.I(PPS_IN), .O(PPS_IN_to_LATCH));
	(* IOB = "TRUE" *) LDCE #(.INIT(1'b0)) pps_in_latch(.D(1'b1),.G(PPS_IN_to_LATCH),.GE(PPS_IN_EN),
	                                                    .CLR(PPS_IN_CLR),.Q(PPS_LATCH));
	assign pps_o = PPS_IN_to_LATCH;

	always @(posedge clk_i) begin
		pps_in_shreg <= {pps_in_shreg[PPS_PULSE_WIDTH-2:0],PPS_LATCH};
	end

	assign PPS_IN_CLR = pps_in_shreg[PPS_PULSE_WIDTH-1];
	
	always @(posedge clk_i) begin
		if ((pps_in_shreg[PPS_PULSE_WIDTH-1] && pps_in_debounce == {PPS_DEBOUNCE_BITS{1'b0}}) || (pps_in_debounce != {PPS_DEBOUNCE_BITS{1'b0}} && KHz_CE_i))
			pps_in_debounce <= pps_in_debounce + 1;
	end
	always @(posedge clk_i) begin
		if (pps_in_shreg[PPS_PULSE_WIDTH-1])
			PPS_IN_EN <= 0;
		else if (pps_in_debounce == {PPS_DEBOUNCE_BITS{1'b0}})
			PPS_IN_EN <= 1;
	end

	always @(posedge clk_i) begin
		if (pps_flag)
			pps_flag <= 0;
		else if (pps_in_shreg[PPS_PULSE_WIDTH-1] && PPS_IN_EN)
			pps_flag <= 1;
	end

	assign pps_async_o = PPS_LATCH;
	assign pps_flag_o = pps_flag;
endmodule
