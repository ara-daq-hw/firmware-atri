`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////
//
// DCM_RESET: Simple module which resets a DCM 11 clock cycles after
//            startup. RESET is held for 4 clock cycles after.
//            I have no idea why DCMs don't self-reset, but whatever.
//
///////////////////////////////////////////////////////////////////////////
module DCM_RESET(
    input CLK,
    output RESET
    );

	reg xRESET;
	reg do_reset;
	reg [3:0] delay;

	initial begin
		do_reset <= 1;
		delay <= 0;
	end

	always @(posedge CLK) begin
		if (do_reset)
			delay <= delay + 1;
		else
			delay <= 0;
	end
	always @(posedge CLK) begin
		if (delay == 15)
			do_reset <= 0;
	end
	always @(posedge CLK) begin
		if (delay > 10)
			xRESET <= 1;
		else
			xRESET <= 0;
	end
	
	assign RESET = xRESET;
endmodule
