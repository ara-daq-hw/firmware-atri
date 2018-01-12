`timescale 1ns / 1ps
//% @brief irs_init_generator watches for the DDA power toggling to generate irs_init.
module irs_init_generator(
		clk_i,
		slow_ce_i,
		micro_ce_i,
		power_i,
		init_o,
		is_init_o
    );
	input clk_i;
	input slow_ce_i;
	input micro_ce_i;
	input power_i;
	output init_o;
	output is_init_o;
	
	parameter SENSE = "SLOW";
	parameter SENSE_WAIT = 50;
	wire sense_ce = (SENSE == "SLOW") ? slow_ce_i : micro_ce_i;
	
	reg [5:0] counter = {6{1'b0}};
	
	reg power_is_on = 0;
	reg irs_is_initialized = 0;
	always @(posedge clk_i) begin
		if (!power_i || power_is_on)
			counter <= {6{1'b0}};
		else if (sense_ce)
			counter <= counter + 1;
	end
	always @(posedge clk_i) begin
		if (!power_i)
			power_is_on <= 0;
		else if ((counter == (SENSE_WAIT-1)) && sense_ce)
			power_is_on <= 1;
	end
	
	SYNCEDGE_R flag_generator(.I(power_is_on),.O(init_o),.CLK(clk_i));
	always @(posedge clk_i) begin
		if (!power_i)
			irs_is_initialized <= 0;
		if (init_o)
			irs_is_initialized <= 1;
	end
	assign is_init_o = irs_is_initialized;
endmodule
