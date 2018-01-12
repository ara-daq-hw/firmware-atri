`timescale 1ns / 1ps
// Model for an IRS2.
//
// Right now all this does is output TSTOUT and TSA_OUT based on Vdly and Vadj values,
// assuming a 0-2.5V full-scale value in 16 bits.
//
// Maybe change this eventually to accept some sort of a float or a string.
module irs2_model(
		input [15:0] vdly,
		input [15:0] vadj,
		input POWER,
		input TSTCLR,
		input TSTST,
		output TSTOUT,
		input TSA,
		output TSAOUT,
		input [5:0] SMP,
		input [2:0] CH,
		output [11:0] DAT
    );

	// Give ourselves some data to latch.
	assign DAT = {{3{1'b0}},CH,SMP};


	reg wilkinson_enable = 0;
	always @(posedge TSTCLR or posedge TSTST) begin
		if (TSTST)
			wilkinson_enable = 1;
		else if (TSTCLR)
			wilkinson_enable = 0;
	end

	// delay for wilkinson
	// from goofy previous mesurements
	// 2.5V = 180 kHz = 5.6 us
	// 2.0V = 170 kHz = 5.9 us
	// 1.4V = 160 kHz = 6.2 us
	// 1.1V = 135 kHz = 7.4 us
	// 1.0V = 125 kHz = 8 us
	// linearizing (horrible approximation) we get 2.4 us/1.5V
	// delay in ns = 9600 - (dac value)*(2500 mV/65535)*(2400/1500)
	/// = 9600 - 0.061*(dac value)
	// or, much simpler = 9600 - (dac_value)/16
	// so the half-time is 4800 - (dac_value)/32
	// this output is in nanoseconds
	function [15:0] vdly_to_delay;
		input [15:0] vdly;
		reg [31:0] tmp;
		begin
			tmp = 153600 - vdly;
			// now divide by 32
			vdly_to_delay = tmp[20:5];
		end
	endfunction
	
	reg test_out_reg = 0;
	reg [15:0] wilkinson_delay;
	always @(vdly) begin
		wilkinson_delay = vdly_to_delay(vdly);
	end
	always @(posedge test_out_reg) begin
		#wilkinson_delay test_out_reg = 0;
	end
	always @(negedge test_out_reg) begin
		if (wilkinson_enable)
			#wilkinson_delay test_out_reg = 1;
	end
	always @(posedge wilkinson_enable) begin
		#wilkinson_delay test_out_reg = 1;
	end
	assign TSTOUT = test_out_reg;

	function [15:0] vadj_to_delay;
		input [15:0] vadj;
		reg [31:0] tmp;
		begin
			tmp = vadj - 18350;
			vadj_to_delay = 20 - tmp[27:12];
		end
	endfunction

	reg [15:0] tsa_delay;
	always @(vadj) begin
		tsa_delay = vadj_to_delay(vadj);
	end

	reg tsa_out_reg = 0;
	always @(posedge TSA)
		#tsa_delay tsa_out_reg = 1;		
	always @(negedge TSA)
		#tsa_delay tsa_out_reg = 0;
		
	assign TSAOUT = tsa_out_reg;

endmodule
