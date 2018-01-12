`timescale 1ns / 1ps
//% @file par_scaler.v Contains par_scaler parameterized scaler module.

//% @brief Parameterized scaler.
//%
//% @par Module Symbol
//% @gensymbol
//% MODULE par_scaler
//% ENDMODULE
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% Simple parameterized scaler. Number of bits and prescaling are parameterizable.
//% Note: stuck-on detection is not done here. That must be done upstream. Synchronization
//% across clock domains can be done by feeding in "clkB" and using "count_clkB" as the
//% output. The "latch" flag must be in the clkA domain.
//% \n\n
//% Note: the input to count must be a flag (single-cycle high). latch_clkA_i must be
//% protected against occurring too fast for clkB to update.
//% \n\n
//% To Do:
//% - Use Generic_Pipelined_Adder to allow for high frequency, high width scalers.
//% - Add dedicated resets in the two domains.
//%
module par_scaler(
		clkA_i,
		clkB_i,
		in_clkA_i,
		latch_clkA_i,
		out_clkA_o,
		out_clkB_o		
    );

   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //   
   ////////////////////////////////////////////////////

	parameter OUTPUT_BITS = 16;
	parameter PRESCALE_BITS = 0;
	localparam COUNT_BITS = OUTPUT_BITS+PRESCALE_BITS;
	
	////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////
	
	//% Clock domain of the flag that we're counting.
	input clkA_i;
	
	//% Flag to count.
	input in_clkA_i;
	
	//% Flag to indicate that we should latch our value (and place it on out_clkA_o/out_clkB_o).
	input latch_clkA_i;

	//% Signal that the clkA domain has latched its value.
	reg clkA_has_latched = 0;
	
	//% Counted value, in the clkA domain.
	output [OUTPUT_BITS-1:0] out_clkA_o;
	
	//% Clock domain of the output value (using out_clkB_o).
	input clkB_i;
	
	//% Counted value, in the clkB domain.
	output [OUTPUT_BITS-1:0] out_clkB_o;
	
	////////////////////////////////////////////////////
   //
   // SIGNALS
   //   
   ////////////////////////////////////////////////////
	
	//% Count in progress (resets at latch_clkA_i)
	reg [COUNT_BITS-1:0] counter_clkA = {COUNT_BITS{1'b0}};
	//% Set in a counting period when we are about to overflow the counter.
	reg overflow_clkA = 0;
	//% Last counted value in clkA domain (updated at latch_clkA_i)
	reg [OUTPUT_BITS-1:0] value_clkA = {OUTPUT_BITS{1'b0}};
	//% Last counted value in clkB domain (updated at latch_clkA_i passed to clkB domain)
	reg [OUTPUT_BITS-1:0] value_clkB = {OUTPUT_BITS{1'b0}};
	//% Flag to tell value_clkB to update.
	wire latch_clkB;
	
	//% Simple counter.
	always @(posedge clkA_i) begin : COUNTER_LOGIC
		if (latch_clkA_i) counter_clkA <= {COUNT_BITS{1'b0}};
		else begin
			if (!overflow_clkA && in_clkA_i) counter_clkA <= counter_clkA + 1;
		end
	end
	
	//% Overflow protection. Sets when the counter counts up to the max value.
	always @(posedge clkA_i) begin : OVERFLOW_LOGIC
		if (latch_clkA_i) overflow_clkA <= 0;
		else if (in_clkA_i && (counter_clkA == {{COUNT_BITS-1{1'b1}},1'b0}))
			overflow_clkA <= 1;
	end
	
	//% Latch the value when the flag comes in.
	always @(posedge clkA_i) begin : LATCH_LOGIC
		if (latch_clkA_i) value_clkA <= counter_clkA[PRESCALE_BITS +: OUTPUT_BITS];
	end	

	//% Indicates that clkA has latched value.
	always @(posedge clkA_i) begin : CLKA_HAS_LATCHED_LOGIC
		clkA_has_latched <= latch_clkA_i;
	end

	//% Generate the clkB latch flag.
	flag_sync clkB_flag_gen(.clkA(clkA_i),.clkB(clkB_i),.in_clkA(clkA_has_latched),.out_clkB(latch_clkB));
	
	//% Latch the value in the clkB domain.
	always @(posedge clkB_i) begin : LATCH_CLKB_LOGIC
		if (latch_clkB) value_clkB <= value_clkA;
	end
	
	assign out_clkA_o = value_clkA;
	assign out_clkB_o = value_clkB;
endmodule
