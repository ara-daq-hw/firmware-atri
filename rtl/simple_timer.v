`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Timer peripheral for a picoblaze.
//////////////////////////////////////////////////////////////////////////////////
module simple_timer(
			CLK,
			CE,
			CLR,
			OUT
    );

	parameter COUNT = 0;
	input CLK;
	input CE;
	input CLR;
	output OUT;
	
	`include "clogb2.vh"
	localparam COUNT_BITS = clogb2(COUNT);
	reg [COUNT_BITS-1:0] counter = {COUNT_BITS{1'b0}};
	
	wire timer_not_done = (counter < COUNT);
	
	always @(posedge CLK) begin
		if (CLR)
			counter <= {COUNT_BITS{1'b0}};
		else if (timer_not_done && CE)
			counter <= counter + 1;
	end
	
	assign OUT = !timer_not_done;
endmodule
