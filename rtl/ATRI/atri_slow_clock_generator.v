`timescale 1ns / 1ps
//% @file atri_slow_clock_generator.v Contains atri_slow_clock_generator module.

//% @brief atri_slow_clock_generator Generates MHz, KHz clocks on an ATRI. Part of ATRI PHY.
module atri_slow_clock_generator(
		input clk_i,
		input pps_i,
		input reset_i,
		output KHz_CE_o,
		output MHz_CE_o
    );

	parameter MHZ_CLK_DIV = 48;
	localparam KHZ_CLK_DIV = 1000;
	`include "clogb2.vh"
	
	localparam NBITS_DIV = clogb2(48);
	reg [NBITS_DIV-1:0] mhz_count = {NBITS_DIV{1'b0}};
	localparam NBITS_KHZ_DIV = clogb2(1000);
	reg [NBITS_KHZ_DIV-1:0] khz_count = {NBITS_KHZ_DIV{1'b0}};
	reg mhz_flag = 1;
	reg khz_flag = 1;
	always @(posedge clk_i) begin
		if (mhz_count == MHZ_CLK_DIV - 1 || reset_i)
			mhz_count <= {NBITS_DIV{1'b0}};
		else
			mhz_count <= mhz_count + 1;
	end
	always @(posedge clk_i) begin
		if (mhz_count == MHZ_CLK_DIV - 1 || reset_i)
			mhz_flag <= 1;
		else
			mhz_flag <= 0;
	end
	always @(posedge clk_i) begin
		if (mhz_count == MHZ_CLK_DIV - 1 || reset_i) begin
			if (khz_count == KHZ_CLK_DIV - 1 || reset_i)
				khz_count <= {NBITS_KHZ_DIV{1'b0}};
			else
				khz_count <= khz_count + 1;
		end
	end
	always @(posedge clk_i) begin
		if ((khz_count == KHZ_CLK_DIV - 1 && mhz_flag) || reset_i)
			khz_flag <= 1;
		else
			khz_flag <= 0;
	end
	
	assign KHz_CE_o = khz_flag;
	assign MHz_CE_o = mhz_flag;
endmodule
