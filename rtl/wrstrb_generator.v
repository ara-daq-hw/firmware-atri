`timescale 1ns / 1ps
//% Write strobe generator module. Takes an input, delays it (and possibly shortens it).
module wrstrb_generator(
		input clkp_i,
		input clkn_i,
		input strb_i,
		output strb_o
    );

	// Can be "SINGLE" or "DUAL". If it's DUAL, then clk_p and clk_n have to be different:
	// they should probably be at least 2.5 ns away from each other. This determines the
	// pulse width. Note that in dual-clock mode, strb_i determines when the strobe goes high:
	// it goes low when the next edge of clkn_i goes high.
	parameter CLOCKS = "SINGLE";
	// Architecture parameter. We only have a Spartan-6 implementation right now.
	parameter ARCH = "SPARTAN6";
	// This is an architecture-specific value.
	parameter DELAY_VAL = 25;
	
	generate
		if (ARCH == "SPARTAN6") begin : S6
			wire strb_to_iodelay;
			if (CLOCKS == "SINGLE") begin : SINGLE
				// Single clock, so we just use a FDCE.
				(* IOB = "TRUE" *)
				FDRE #(.INIT(1'b0)) wrstrb_ff(.D(strb_i),.CE(1'b1),.C(clkp_i),.R(1'b0),.Q(strb_to_iodelay));
			end else begin : DUAL
				// Two clocks: so we use an ODDR2.
				ODDR2 #(.DDR_ALIGNMENT("C0"),.INIT(1'b0),.SRTYPE("SYNC")) 
					wrstrb_ff(.D0(strb_i),.D1(1'b0),.C0(clkp_i),.C1(clkn_i),.CE(1'b1),.R(1'b0),.S(1'b0),
								 .Q(strb_to_iodelay));
			end
			// IODELAY. Fixed output delay. Tap8 is 424 ps max, so we use 11 tap8s, and a tap7.
			// This is a value of 95. If this is too much variation, we can replace it with a calibrated
			
			// Try 25. This should be a delay of around 2 ns. 

			// IODELAY2 in variable-delay mode, but then it becomes harder to shorten the pulse.
			IODELAY2 #(.ODELAY_VALUE(DELAY_VAL),.IDELAY_TYPE("FIXED"),.DELAY_SRC("ODATAIN"))
				wrstrb_delay(.ODATAIN(strb_to_iodelay),.DOUT(strb_o));
		end
	endgenerate

endmodule
