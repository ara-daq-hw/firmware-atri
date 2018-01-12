`timescale 1ns / 1ps

				//% @file Generic_Gray_to_Binary.v Contains Generic_Gray_to_Binary module

//% @brief Generic Pipeline Tools multi-purpose Gray to Binary converter.
//%			
//% @par Module Symbol
//% @gensymbol
//% MODULE Generic_Gray_to_Binary
//% PARAMETER WIDTH 32
//% PARAMETER LATENCY 4
//% PARAMETER THROUGHPUT "FULL"
//% LPORT G_in input
//% RPORT B_out output
//% LPORT space
//% RPORT space
//% LPORT CONVERT input
//% RPORT VALID output
//% LPORT CE input
//% LPORT CLK input
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% Generic_Gray_to_Binary is a parameterized, pipelineable multipurpose
//% Gray to Binary converter. Binary-to-Gray conversion is trivial and requires
//% very little work - a simple downshift and XOR, and the conversion is
//% complete - each output bit is merely the XOR of two bits.
//% \n\n
//% Gray-to-Binary conversion, however, is quite different - the input to
//% bit 0, for instance, is the XOR of the Gray bit 0 and the <b>binary</b>
//% bit 1 ... which is the XOR of the Gray bit 1 and the <b>binary</b> bit
//% 2... etc. An N-bit Gray counter thus requires a path through N-1 XOR
//% gates. Thus, pipelining is often required for wide Gray code conversion.
//% \n\n
//% @par Parameters
//% \n\n
//% Generic_Gray_to_Binary's simple parameters are:
//% \n\n
//% - WIDTH (= 32)
//% - LATENCY (= 4)
//% - THROUGHPUT (= "FULL")
//% \n\n
//% WIDTH defines the data width. No maximum, minimum of 2.
//% \n\n
//% THROUGHPUT can be "FULL" or "PARTIAL". It defines whether a partial 
//% or full-bandwidth converter is generated. A full-bandwidth converter
//% can convert 1 Gray code to binary every sample, while a partial
//% bandwidth converter can convert 1 Gray code every LATENCY samples.
//% \n\n
//% LATENCY defines the number of clock cycles before the data is valid.
//% A value of 0 means no pipelining. Maximum value is WIDTH-1. However,
//% note that values greater than ceil(log2(WIDTH)) may just result in
//% delaying the output data for a "FULL" throughput decoder.
//% \n\n
//% The advanced parameters are:
//% \n\n
//% - STRATEGY (= "OPTIMAL")
//% - HEAVY_WEIGHT (= "LATE")
//% - AVOID_ENDS (= "TRUE")
//% \n\n
//% STRATEGY can be "OPTIMAL", "LOG2", or "SIMPLE". "OPTIMAL" right now 
//% selects the best strategy simply based on THROUGHPUT - "LOG2" for 
//% THROUGHPUT="FULL" and "SIMPLE" for THROUGHPUT="PARTIAL". "OPTIMAL"
//% selects primarily on speed considerations - for pure area
//% considerations, "SIMPLE" is preferable regardless of THROUGHPUT
//% by almost a factor of 2. A Log2-based decoder with THROUGHPUT="PARTIAL"
//% tends to almost universally be worse than other options unless the
//% architecture in question is logic-rich and flipflop-poor.
//% \n\n
//% HEAVY_WEIGHT is a delay-weighting guideline. For
//% certain combinations of WIDTH and LATENCY, not all pipeline stages
//% will have an equivalent amount of logic. For instance, with the Log2
//% strategy, a 32-bit conversion takes 5 stages. If LATENCY=2, then those
//% stages must be done in 3 clocks - therefore, 2 clocks will have 2 stages
//% and 1 clock will have 1 stage. HEAVY_WEIGHT="LATE" will place the
//% clock cycles with 2 stages at the end of the conversion.
//% HEAVY_WEIGHT="EARLY" will place those clock cycles at the beginning of
//% the conversion. For the Simple strategy, the same idea applies, except
//% now it's number of bits rather than stages.
//% \n\n
//% Likewise, AVOID_ENDS is another delay-weighting guideline. Since the
//% inputs to Generic_Gray_to_Binary are not immediately registered (they
//% go through logic first) and the outputs are not registered (they are the
//% outputs of logic) placing the clock cycles with extra logic at the
//% beginning or end can limit the speed of external logic. By default,
//% AVOID_ENDS="TRUE", and the clock cycles with extra logic are preferentially
//% placed away from the first and last clock cycles if at all possible.
//% \n\n
//% @par Conversion strategy
//% \n\n
//% Generic_Gray_to_Binary has two possible strategies to convert Gray
//% to Binary: Log2 and Simple.
//% \n\n
//% The Simple strategy (Generic_Gray_to_Binary_Simple) converts chunks
//% of bits of the Gray code input each cycle, and the remaining bits are
//% simply passed. Thus, a LATENCY=3, WIDTH=32 conversion would give
//% @verbatim
//% Clock 0: G_in = 0x80000000 : B_out = 0xFF000000
//% Clock 1: G_in = 0x80000000 : B_out = 0xFFFF0000
//% Clock 2: G_in = 0x80000000 : B_out = 0xFFFFFF00
//% Clock 3: G_in = 0x80000000 : B_out = 0xFFFFFFFF
//% @endverbatim
//% \n\n
//% In this case, each cycle has a critical path of 7 XORs in the lowest
//% bit in the chunk. Note, however, that in each cycle, only 8 bits have
//% this path - the remaining 24 are simply delayed.
//% \n\n
//% The Log2 strategy (Generic_Gray_to_Binary_Log2) progressively converts
//% the input Gray code by shifting and xoring the last stage's result by
//% increasing powers of 2. This has a huge advantage of reducing the
//% critical path very quickly. It has slightly higher resource usage
//% than the Simple strategy.
//% \n\n
//% Thus, a LATENCY=4, WIDTH=32 conversion would give
//% @verbatim
//% Clock 0: G_in = 0x80000000 : B_out = 0xC0000000
//% Clock 1: G_in = 0x80000000 : B_out = 0xF0000000
//% Clock 2: G_in = 0x80000000 : B_out = 0xFF000000
//% Clock 3: G_in = 0x80000000 : B_out = 0xFFFF0000
//% Clock 4: G_in = 0x80000000 : B_out = 0xFFFFFFFF
//% @endverbatim
//% \n\n
//% The Log2 strategy, with a latency of 4, reduces the critical path on
//% each cycle to the minimum - an xor between 2 bits. However, all 32 of
//% the bits have this path in each stage.
//% \n\n
//% The Simple strategy has one advantage over the Log2 strategy - the
//% inputs for any given stage are given entirely by G_in, plus 1 bit from
//% the previous conversion. This means that a partial-bandwidth converter
//% can be reduced to the minimum critical path with zero additional
//% resources. If high-throughput is not required and a long latency
//% is acceptable, the Simple strategy is extremely useful.
//% \n\n
//% The Simple strategy also has another benefit: only WIDTH/(LATENCY+1)-1
//% bits have an input path that goes through logic. For the Log2 strategy,
//% WIDTH-1 bits must pass through logic before being registered. There may
//% be applications where this is preferable even though the critical
//% path is much greater for the Simple strategy at a given latency.
//% \n\n
//% <b>Note</b>: the Log2 strategy has a maximum conversion latency
//% (1 stage per clock) of ceil(log2(WIDTH)), however, the Simple strategy
//% has a maximum conversion latency of WIDTH. <i>For convenience,
//% Generic_Gray_to_Binary has a maximum conversion latency of WIDTH.</i>
//% <b>For latencies greater than ceil(log2(WIDTH))</b>, if the Log2
//% strategy is used, the output is simply delayed LATENCY-ceil(log2(WIDTH))
//% cycles.
//% \n\n
//% @par Resource usage
//% \n\n
//% All numbers are based on a Spartan-3 XC3S2000-4, 32-bits with latency 4.
//% \n
//% @verbatim
//% Log2:
//% THROUGHPUT="FULL", SAVE_AREA="FALSE": 74 slices, 132 FFs, 83 LUTs, Fmax = 371.747 MHz
//% THROUGHPUT="FULL", SAVE_AREA="TRUE": 78 slices, 125 FFs, 89 LUTs, Fmax = 294.291 MHz
//% THROUGHPUT="PARTIAL": 91 slices, 42 FFs, 166 LUTs, Fmax = 184.911 MHz
//% Simple:
//% THROUGHPUT="FULL", SAVE_AREA="FALSE": 77 slices, 132 FFs, 40 LUTs, Fmax = 233.590 MHz
//% THROUGHPUT="FULL", SAVE_AREA="TRUE": 48 slices, 84 FFs, 72 LUTs, Fmax = 294.291 MHz
//% THROUGHPUT="PARTIAL", SAVE_AREA="FALSE": 24 slices, 24 FFs, 42 LUTs, Fmax = 365.631 MHz
//% THROUGHPUT="PARTIAL", SAVE_AREA="TRUE": 26 slices, 26 FFs, 43 LUTs, Fmax = 294.291 MHz
//% @endverbatim
//%
//% Note that in general, the resource usage when SAVE_AREA="FALSE" grows dramatically
//% with large LATENCY with THROUGHPUT="FULL".
//%
//% For the Log2 implementation, a 32-bit latency 4 Gray to Binary converter
//% with THROUGHPUT="FULL" uses 78 slices on a Spartan-3 - 125 flipflops and
//% 89 LUTs with an Fmax (with SAVE_AREA="FALSE") of 370 MHz. A THROUGHPUT="PARTIAL" 
//% implementation uses 91 slices - 42 flipflops and 166 LUTs, and has a
//% nominal Fmax of 185 MHz.
//% \n\n
//% For the Simple implementation, a 32-bit latency 4 Gray to Binary converter
//% with THROUGHPUT="FULL" uses 48 slices - 84 FFs and 72 LUTs. Note that
//% the resource usage is much lower than the Log2 implementation. However, 
//% the Log2 implementation is easier to route at very high frequency than
//% the Simple implementation. A THROUGHPUT="PARTIAL" implementation uses
//% only 26 slices - 26 FFs and 43 LUTs.
//% \n\n
//% @par Parameter checking
//% \n\n
//% Generic_Gray_to_Binary can use the vassert Verilog assertion helper
//% modules to check parameters, if the synthesis tool allows for mixed
//% Verilog/VHDL designs. Define PARAMETER_CHECK to implement those
//% checks.
//% 
module Generic_Gray_to_Binary(G_in, B_out, CLK, CE, CONVERT, VALID);
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Gray code input width
   parameter 	      WIDTH = 32;	
   //% Latency from CONVERT assertion to VALID assertion
   parameter 	      LATENCY = 4;
   //% Throughput control, either FULL or PARTIAL.
   parameter 	      THROUGHPUT = "PARTIAL";
   //% Conversion strategy, either OPTIMAL, LOG2, or SIMPLE.
   parameter 	      STRATEGY = "SIMPLE";
   //% Excess logic delay distribution weight - either "LATE" or "EARLY"   
   parameter 	      HEAVY_WEIGHT = "LATE";
   //% Avoid placing excess logic at beginning or end of conversion
   parameter 	      AVOID_ENDS = "TRUE";
	//% If "FALSE", avoid shift register extraction (to help with high-speed routing at expense of resources)
	parameter         SAVE_AREA = "TRUE";
	

`ifdef PARAMETER_CHECK
   
   ////////////////////////////////////////////////////
   //
   // PARAMETER CHECKING
   //
   ////////////////////////////////////////////////////   

   //% Check if THROUGHPUT is a valid type
   localparam 	      THROUGHPUT_CHECK = (THROUGHPUT=="FULL") || (THROUGHPUT=="PARTIAL") ;
   //% Check if HEAVY_WEIGHT is a valid type
   localparam 	      HEAVY_WEIGHT_CHECK = (HEAVY_WEIGHT=="EARLY") || (HEAVY_WEIGHT=="LATE");
   //% Check if AVOID_ENDS is a valid type
   localparam 	      AVOID_ENDS_CHECK = (AVOID_ENDS=="FALSE") || (AVOID_ENDS=="TRUE");
   //% Check if STRATEGY is a valid type
   localparam         STRATEGY_CHECK = (STRATEGY=="OPTIMAL") || (STRATEGY=="LOG2") || (STRATEGY == "SIMPLE");
   
   vassert_if_less_than
     #(.LIMIT(2),
       .VALUE(WIDTH),
       .ERR("Generic_Gray_to_Binary: WIDTH must be greater than 1")) width_check();
   vassert_if_greater_than 
     #(.LIMIT(WIDTH-1),
       .VALUE(LATENCY),
       .ERR("Generic_Gray_to_Binary: Latency must be less than WIDTH")) latency_check();   
   vassert_if_not
     #(.BOOL(STRATEGY_CHECK),
       .ERR("Generic_Gray_to_Binary: STRATEGY must be OPTIMAL, LOG2, or SIMPLE")) strategy_check();
   
   vassert_if_not 
     #(.BOOL(THROUGHPUT_CHECK),
       .ERR("Generic_Gray_to_Binary: THROUGHPUT must be FULL or PARTIAL")) always_valid_check();
   vassert_if_not
     #(.BOOL(HEAVY_WEIGHT_CHECK),
       .ERR("Generic_Gray_to_Binary: HEAVY_WEIGHT must be EARLY or LATE")) heavy_weight_check();
   vassert_if_not
     #(.BOOL(AVOID_ENDS_CHECK),
       .ERR("Generic_Gray_to_Binary: AVOID_ENDS must be TRUE or FALSE")) avoid_ends_check();   
`endif

   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////

   //% Gray code input
   input [WIDTH-1:0]  G_in;
   //% Binary code output
   output [WIDTH-1:0] B_out;

   //% System clock (used for LATENCY > 0)
   input 	      CLK;
   //% Clock enable
   input 	      CE;   
   //% Begin conversion
   input 	      CONVERT;
   //% Conversion is complete
   output 	      VALID;	
   
   ////////////////////////////////////////////////////
   //
   // CONVENIENCE PARAMETERS
   //
   ////////////////////////////////////////////////////

   //% Gray to Binary implementation
   localparam IMPLEMENTATION = (STRATEGY != "OPTIMAL") ?
	      STRATEGY : ((THROUGHPUT == "FULL") ? "LOG2" : "SIMPLE");

   ////////////////////////////////////////////////////
   //
   // GENERATE BLOCKS
   //
   ////////////////////////////////////////////////////

`ifdef DOXYGEN
   // These are here for Doxygen's dependency graph.
   // They are NOT included in normal synthesis.

   // VALID output from the Log2-strategy converter
   wire 	      LOG2_VALID;
   // Data output from the Log2-strategy converter
   wire [WIDTH-1:0]   LOG2_BOUT;

   //% @brief <b>LOG2.u_Log2</b>: Log2 implementation. Instantiated when IMPLEMENTATION == "LOG2"
   //%
   //% The actual gray-to-binary converter, using the Log2 conversion strategy.
   //% This module is only instantiated if IMPLEMENTATION == "LOG2" (if
   //% STRATEGY == "LOG2" or STRATEGY == "OPTIMAL" and THROUGHPUT == "FULL")
   //% and has a proper name of <b>LOG2.u_Log2</b>. Its name is given here
   //% as u_Log2 due to Doxygen limitations.
   Generic_Gray_to_Binary_Log2 #(.WIDTH(WIDTH),
				 .LATENCY(LOG2_LATENCY),
				 .THROUGHPUT(THROUGHPUT),
				 .HEAVY_WEIGHT(HEAVY_WEIGHT),
				 .AVOID_ENDS(AVOID_ENDS))
   u_Log2(.G_in(G_in),.B_out(LOG2_BOUT),.CLK(CLK),
	  .CE(CE),.CONVERT(CONVERT),.VALID(LOG2_VALID));

   //% @brief <b>LOG2.LOG2DELAY.u_Log2_VALID_delay</b>: Delayed VALID output for some Log2 implementations.
   //%
   //% This module delays VALID if LATENCY exceeds ceil(log2(WIDTH)), and is only
   //% instantiated for Log2 cases. Its proper name is <b>LOG2.LOG2DELAY.u_Log2_VALID_delay</b>.
   //% Its name is given here as u_Log2_VALID_delay due to Doxygen limitations.
   Generic_Pipeline #(.WIDTH(1),.LATENCY(LATENCY-MAX_LOG2_LATENCY))
   u_Log2_VALID_delay(.I(LOG2_VALID),.O(VALID),.CLK(CLK));

   //% @brief <b>LOG2.LOG2DELAY.u_Log2_BOUT_delay</b>: Delayed B_out output for some Log2 implementations.
   //%
   //% This module delays B_out if LATENCY exceeds (ceil(log2(WIDTH)), and is only
   //% instantiated for Log2 cases. Its proper name is <b>LOG2.LOG2DELAY.u_Log2_BOUT_delay</b>.
   //% Its name is given here as u_Log2_BOUT_delay due to Doxygen limitations.
   Generic_Pipeline #(.WIDTH(WIDTH),.LATENCY(LATENCY-MAX_LOG2_LATENCY))
   u_Log2_BOUT_delay(.I(LOG2_BOUT),.O(B_out),.CLK(CLK),.CE(CE));

   //% @brief <b>SIMPLE.u_Simple</b>: Simple implementation. Instantiated when IMPLEMENTATION=="SIMPLE".
   //%
   //% 
   //% The actual gray-to-binary converter, using the Simple conversion strategy.
   //% This module is only instantiated if IMPLEMENTATION == "SIMPLE" (if
   //% STRATEGY == "SIMPLE" or STRATEGY == "OPTIMAL" and THROUGHPUT == "PARTIAL")
   //% and has a proper name of <b>SIMPLE.u_Simple</b>. Its name is given here
   //% as u_Simple due to Doxygen limitations.
   Generic_Gray_to_Binary_Simple #(.WIDTH(WIDTH),
				   .LATENCY(LATENCY),
				   .THROUGHPUT(THROUGHPUT),
				   .HEAVY_WEIGHT(HEAVY_WEIGHT),
				   .AVOID_ENDS(AVOID_ENDS))
   u_Simple(.G_in(G_in),.B_out(B_out),.CLK(CLK),.CE(CE),
	    .CONVERT(CONVERT),.VALID(VALID),.CE(CE));
`endif   
   
`include "clogb2.vh"
   //% Maximum latency in the Log2 strategy
   localparam MAX_LOG2_LATENCY = clogb2(WIDTH)-1;
   //% Latency to pass to the Log2 implementation
   localparam LOG2_LATENCY = (LATENCY > MAX_LOG2_LATENCY) ? MAX_LOG2_LATENCY :
	      LATENCY;
   
   generate
      if (IMPLEMENTATION == "LOG2") begin : LOG2
	 // VALID output from the Log2-strategy converter
	 wire LOG2_VALID;
	 // Data output from the Log2-strategy converter
	 wire [WIDTH-1:0] LOG2_BOUT;
	 Generic_Gray_to_Binary_Log2 #(.WIDTH(WIDTH),
				       .LATENCY(LOG2_LATENCY),
				       .THROUGHPUT(THROUGHPUT),
				       .HEAVY_WEIGHT(HEAVY_WEIGHT),
				       .AVOID_ENDS(AVOID_ENDS),
						 .SAVE_AREA(SAVE_AREA))
	   u_Log2(.G_in(G_in),.B_out(LOG2_BOUT),.CLK(CLK),
		  .CE(CE),.CONVERT(CONVERT),.VALID(LOG2_VALID));
	 if (LATENCY > MAX_LOG2_LATENCY) begin : LOG2DELAY
	    Generic_Pipeline #(.WIDTH(1),.LATENCY(LATENCY-MAX_LOG2_LATENCY),.SAVE_AREA(SAVE_AREA))
	      u_Log2_VALID_delay(.I(LOG2_VALID),.O(VALID),.CLK(CLK),.CE(CE));
	    Generic_Pipeline #(.WIDTH(WIDTH),.LATENCY(LATENCY-MAX_LOG2_LATENCY),.SAVE_AREA(SAVE_AREA))
	      u_Log2_BOUT_delay(.I(LOG2_BOUT),.O(B_out),.CLK(CLK),.CE(CE));
	 end else begin : LOG2NODELAY
	    assign VALID = LOG2_VALID;
	    assign B_out = LOG2_BOUT;
	 end
      end // block: LOG2
      else begin : SIMPLE
	 Generic_Gray_to_Binary_Simple #(.WIDTH(WIDTH),
					 .LATENCY(LATENCY),
					 .THROUGHPUT(THROUGHPUT),
					 .HEAVY_WEIGHT(HEAVY_WEIGHT),
					 .AVOID_ENDS(AVOID_ENDS),
					 .SAVE_AREA(SAVE_AREA))
	   u_Simple(.G_in(G_in),.B_out(B_out),.CLK(CLK),.CE(CE),
		    .CONVERT(CONVERT),.VALID(VALID));
      end // block : SIMPLE
   endgenerate
endmodule
			      
//% @brief Simple implementation of Gray to Binary converter.
//% 
//% Generic_Gray_to_Binary_Simple implements a simple, dumb version of
//% a Gray to Binary converter. It processes WIDTH/LATENCY bits per cycle.
//% \n\n
//% This is less efficient than the other implementation implemented in
//% the Generic_Gray_to_Binary_Log2 module. However, this converter still
//% has an advantage when implemented as a partial-throughput converter.
//% Since Generic_Gray_to_Binary_Log2 requires building up the result in
//% stages, it needs to mux the latching of its output registers, and that
//% muxing slows things down dramatically.
//% \n\n
//% It also is required for a LATENCY=0 implementation, since the Log2 module
//% doesn't work in that case.
//% \n\n
//% Generic_Gray_to_Binary_Simple simply converts the input piece-by-piece.
//% Therefore, for a partial bandwidth implementation, this module, with
//% higher latencies, can achieve a very low resource pipelined conversion
//% with very high clock speed.
module Generic_Gray_to_Binary_Simple(G_in, B_out, CLK, CE, CONVERT, VALID );
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Gray code input width
   parameter 	      WIDTH = 32;	
   //% Latency from CONVERT assertion to VALID assertion
   parameter 	      LATENCY = 5;
   //% Throughput control, either FULL or PARTIAL.
   parameter 	      THROUGHPUT = "PARTIAL";
	//% Extra bit weighting, either EARLY or LATE.
	parameter         HEAVY_WEIGHT = "LATE";
	//% Preferentially place extra bit stages away from ends, "TRUE" or "FALSE"
	parameter         AVOID_ENDS = "TRUE";
	//% If "FALSE", avoid shift register extraction (to help with high-speed routing at expense of resources)
	parameter         SAVE_AREA = "TRUE";
	

   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////

   //% Gray code input
   input [WIDTH-1:0]  G_in;
   //% Binary code output
   output [WIDTH-1:0] B_out;

   //% System clock (used for LATENCY > 0)
   input 	      CLK;
   //% Clock enable
   input 	      CE;   
   //% Begin conversion
   input 	      CONVERT;
   //% Conversion is complete
   output 	      VALID;	
   
   ////////////////////////////////////////////////////
   //
   // CONVENIENCE PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Number of bits per chunk
   localparam 	      NBITS = WIDTH/(LATENCY+1);
   //% Number of chunks that require an extra bit
   localparam 	      EXTRAGROUPS = WIDTH - NBITS*(LATENCY+1);
   //% Number of bits in an chunk that requires an extra bit.
   localparam 	      EXTRABITS = NBITS + 1;
	//% Disable register balancing if save area is off
	localparam        FORCE_NO_BALANCE = "YES";

   ////////////////////////////////////////////////////
   //    
   // LOCAL VARIABLES
   //
   ////////////////////////////////////////////////////
   
   //% Sequencing pipeline (CONVERT -> VALID). convert_pipe[0] is just CONVERT.
	(* SHREG_EXTRACT = SAVE_AREA *)
	(* REGISTER_BALANCING = FORCE_NO_BALANCE *)
	reg [LATENCY:0]  convert_pipe = {LATENCY+1{1'b0}};

   //% Data storage pipeline. binary_pipe[0] is just G_in, binary_pipe[LATENCY+1] is just B_out
	(* SHREG_EXTRACT = SAVE_AREA *)
	(* REGISTER_BALANCING = FORCE_NO_BALANCE *) 
   reg [WIDTH-1:0]    binary_pipe[LATENCY+1:0];
   
   //% Outputs from each Gray conversion stage.
   wire [WIDTH-1:0]   binary_value[LATENCY:0];
   
   //% Partial throughput connection between last Gray stage and output
   wire [NBITS-1:0]   binary_partial;
   
   //% Iterator to initialize the binary pipeline.
   integer 	      init_iter;

   ////////////////////////////////////////////////////
   //
   // INITIAL BLOCKS
   //
   ////////////////////////////////////////////////////   

   initial begin
      for (init_iter=0;init_iter<=LATENCY+1;init_iter=init_iter+1) begin
	 binary_pipe[init_iter] <= {WIDTH{1'b0}};
      end
   end
   
`ifdef DOXYGEN
	// These are only here to help Doxygen's inheritance graph.
	
	//% @brief G2BLOOP[i].G2BEXTRA.extra_converter : Gray-to-binary converter (chain-xor) of EXTRABITS bits out of WIDTH bits
	//%
	//% Convert a chunk of bits for a stage with EXTRABITS bits. If LATENCY does not divide evenly into WIDTH,
	//% some stages have to have WIDTH/(LATENCY+1) + 1 bits. These converters are placed in those stages.
	//% The full name of this instance is <b>G2BLOOP[i].G2BEXTRA.extra_converter</b>, with i ranging from 0 to LATENCY-1
	//% (each G2BLOOP iteration has either a G2BEXTRA.extra_converter or a G2BNORMAL.converter). It is listed here
   //% as extra_converter due to Doxygen limitations. 	
	Generic_Gray_to_Binary_Simple_Converter #(.WIDTH(WIDTH),.START(WIDTH-st_iter*EXTRABITS-EXTRABITS),.STOP(WIDTH-st_iter*EXTRABITS-1))
	      extra_converter(.G_in(gray_in),.B_out(binary_value[st_iter]));
	
	//% @brief G2BLOOP[i].G2BNORMAL.converter : Gray-to-binary converter (chain-xor) of NBITS bits out of WIDTH bits
	//%
	//% Convert a chunk of bits for a stage with NBITS bits.
	//% The full name of this instance is <b>G2BLOOP[i].G2BNORMAL.converter</b> with i ranging from 0 to LATENCY-1
	//% (each G2BLOOP interation has either a G2BEXTRA.extra_converter or a G2BNORMAL.converter). It is listed here
	//% as converter due to Doxygen limitations.
	Generic_Gray_to_Binary_Simple_Converter #(.WIDTH(WIDTH),.START(WIDTH-st_iter*NBITS-EXTRAGROUPS-NBITS),.STOP(WIDTH-st_iter*NBITS-EXTRAGROUPS-1))
	      converter(.G_in(gray_in),.B_out(binary_value[st_iter]));
`endif

   ////////////////////////////////////////////////////
   //
   // GENERATE BLOCKS
   //
   ////////////////////////////////////////////////////
      
   generate
      genvar st_iter;
      genvar bit_iter;
      // All stages.
      for (st_iter = 0;st_iter < LATENCY+1;st_iter=st_iter+1) begin : G2BLOOP
	 wire [WIDTH-1:0] gray_in;
	 if (THROUGHPUT=="FULL") begin : FULLBANDWIDTH
	    assign gray_in = binary_pipe[st_iter];
	 end else begin : PARTIALBANDWIDTH
	    for (bit_iter=0;bit_iter<WIDTH;bit_iter=bit_iter+1) begin : PARTIALBITLOOP
	       if (st_iter < EXTRAGROUPS) begin
		  if (bit_iter > WIDTH-st_iter*EXTRABITS-1)
		    assign gray_in[bit_iter] = binary_pipe[LATENCY+1][bit_iter];
		  else
		    assign gray_in[bit_iter] = binary_pipe[0][bit_iter];
	       end else begin
		  if (bit_iter > WIDTH-st_iter*NBITS-EXTRAGROUPS-1)
		    assign gray_in[bit_iter] = binary_pipe[LATENCY+1][bit_iter];
		  else
		    assign gray_in[bit_iter] = binary_pipe[0][bit_iter];
	       end
	    end
	 end
	 if (st_iter < EXTRAGROUPS) begin : G2BEXTRA
	    Generic_Gray_to_Binary_Simple_Converter #(.WIDTH(WIDTH),.START(WIDTH-st_iter*EXTRABITS-EXTRABITS),.STOP(WIDTH-st_iter*EXTRABITS-1))
	      extra_converter(.G_in(gray_in),.B_out(binary_value[st_iter]));
	 end else begin : G2BNORMAL
	    Generic_Gray_to_Binary_Simple_Converter #(.WIDTH(WIDTH),.START(WIDTH-st_iter*NBITS-EXTRAGROUPS-NBITS),.STOP(WIDTH-st_iter*NBITS-EXTRAGROUPS-1))
	      converter(.G_in(gray_in),.B_out(binary_value[st_iter]));
	 end
      end
   endgenerate

	//% Attachment stage:
	//%
	//% The outputs here aren't registered - they're just assigned via
	//% always blocks. A "FULL" bandwidth converter has the complete
	//% data stored in each pipeline stage, so the output of the
	//% next-to-last pipeline stage, through the last Gray-to-Binary
	//% converter, is the output you want. So you just assign
	//% binary_value (the output of the last converter).
	//%
	//% The data for a "PARTIAL" bandwidth converter is stored partly
	//% in each converter stage. So here you just assign the bits
	//% corresponding to the last converter. The remaining bits
	//% are assigned in the next block (which, for a full bandwidth
	//% converter, is the pipeline feed forward block).
   generate
		//% Attach the last converter to the output stage directly.
		if (THROUGHPUT=="FULL") begin : FULL_ATTACH
		 //% Full-bandwidth: fully assign the outputs to the output
		 //% of the last converter.
		 always @(binary_value[LATENCY]) begin
			 binary_pipe[LATENCY+1] <= binary_value[LATENCY];
		 end
		end else begin : PARTIAL_ATTACH
		 //% Partial-bandwidth: assign only the outputs of the 
		 //% last converter stage.
//		 wire [NBITS-1:0] tmp = binary_value[LATENCY][NBITS-1:0];
		 always @(binary_value[LATENCY][NBITS-1:0]) begin
			 binary_pipe[LATENCY+1][NBITS-1:0] <= binary_value[LATENCY][NBITS-1:0];
		 end
		end
   endgenerate

	//% Pipeline feed loops.
	//%
	//% Note that this section does NOT assign the actual outputs
	//% since the loop only assigns binary_pipe[1] to binary_pipe[LATENCY].
	//% The outputs are binary_pipe[LATENCY+1].
	//% binary_pipe[0] are the inputs.
   generate
		genvar pipe_iter;
		//% Loop over the pipeline stages and connect the binary pipeline appropriately.
		for (pipe_iter=0;pipe_iter<LATENCY;pipe_iter=pipe_iter+1) begin : PIPELOOP
		 //% "FULL" bandwidth: feed the outputs of the converter stages to the
		 //% next pipeline registers.
		 if (THROUGHPUT=="FULL") begin : FULL_FEED
			 always @(posedge CLK) begin
				 if (CE)
					 binary_pipe[pipe_iter+1] <= binary_value[pipe_iter];
			 end
		 end 
		 //% "PARTIAL" bandwidth: assign the outputs of the converter stages to
		 //% the outputs.
		 else begin : PARTIAL_FEED
			 if (pipe_iter < EXTRAGROUPS) begin 
				 always @(posedge CLK) begin
					if (CE)
						binary_pipe[LATENCY+1][WIDTH-pipe_iter*EXTRABITS-EXTRABITS +: EXTRABITS] <= binary_value[pipe_iter][WIDTH-pipe_iter*EXTRABITS-EXTRABITS +: EXTRABITS];
				 end
			 end else begin
			  always @(posedge CLK) begin
				 if (CE)
					binary_pipe[LATENCY+1][WIDTH-pipe_iter*NBITS-NBITS-EXTRAGROUPS +: NBITS] <= binary_value[pipe_iter][WIDTH-pipe_iter*NBITS-NBITS-EXTRAGROUPS +: NBITS];
			  end
			 end
		 end
		end
   endgenerate
      
   ////////////////////////////////////////////////////
   //
   // ALWAYS BLOCKS
   //
   ////////////////////////////////////////////////////

   
   //% Attach CONVERT to convert_pipe pipeline head			      
   always @(CONVERT) begin : CONVERT_HEAD
     convert_pipe[0] <= CONVERT;
   end
   //% Connect remainder of convert_pipe
	generate
		if (LATENCY > 0) begin : CONVERT_BODY
			always @(posedge CLK) begin : CONVERT_BODY_LOGIC
				if (CE)
					convert_pipe[LATENCY:1] <= convert_pipe[LATENCY-1:0];
			end
		end
	endgenerate
   //% Attach G_in to binary pipeline head
   always @(*) begin : BINARY_HEAD
      binary_pipe[0] <= G_in;
   end

   ////////////////////////////////////////////////////
   //
   // ASSIGN STATEMENTS
   //
   ////////////////////////////////////////////////////
   
   assign VALID = convert_pipe[LATENCY];
   assign B_out = binary_pipe[LATENCY+1];

endmodule

//% @brief Simple module to convert a portion of an input as Gray to Binary
//%
//% Generic_Gray_to_Binary_Simple_Converter is just a helper module
//% for Generic_Gray_to_Binary_Simple which converts a chunk of an
//% input as a Gray to Binary conversion. The bits outside of
//% G_in[STOP-1:START] are simply passed along.
//%
module Generic_Gray_to_Binary_Simple_Converter(G_in, B_out);
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Width of the input and outputs.
   parameter 	      WIDTH = 32;
   //% Bit to start conversion with. By default, start of input.
   parameter 	      START = 0;
   //% Bit to stop conversion before. By default, end of input.
   parameter 	      STOP = WIDTH;

   //% Input to convert
   input [WIDTH-1:0]  G_in;
   //% Converted output
   output [WIDTH-1:0] B_out;

   ////////////////////////////////////////////////////
   //
   // GENERATE BLOCKS
   //
   ////////////////////////////////////////////////////

   generate
      genvar 	      it;
      // Loop over the incoming bits: either assign or chain-XOR them.
      for (it=1;it<WIDTH;it=it+1) begin : XOR_LOOP
	 if (WIDTH-it-1 > STOP || WIDTH-it-1 < START) begin : CASE_ASSIGN
	    assign B_out[WIDTH-it-1] = G_in[WIDTH-it-1];
	 end else begin : CASE_XOR
	    assign B_out[WIDTH-it-1] = B_out[WIDTH-it]^G_in[WIDTH-it-1];
	 end
      end
   endgenerate
   
   ////////////////////////////////////////////////////
   //
   // ASSIGN STATEMENTS
   //
   ////////////////////////////////////////////////////
   
   assign 	   B_out[WIDTH-1] = G_in[WIDTH-1];
endmodule

//% @brief Log2 implementation of a Gray to Binary converter.
//%
//% The Log2 implementation progressively shifts and xors the input
//% ceil(log2(WIDTH)) times, spreading out those shift-xor stages
//% over LATENCY+1 clock cycles. The FULL throughput version produces
//% a very resource efficient and extremely fast converter. The PARTIAL
//% bandwidth version saves a bit of resources, but actually ends up
//% being fairly slow, since the assumption that the data is constant
//% over the conversion period does not help the conversion at all.
//% 
module Generic_Gray_to_Binary_Log2(G_in, B_out, CONVERT, VALID, CE, CLK);
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Gray code input width
   parameter 	      WIDTH = 32;	
   //% Latency from CONVERT assertion to VALID assertion
   parameter 	      LATENCY = 5;
   //% Throughput control, either FULL or PARTIAL.
   parameter 	      THROUGHPUT = "FULL";
   //% Excess logic delay distribution weight - either "LATE" or "EARLY"   
   parameter 	      HEAVY_WEIGHT = "LATE";
   //% Avoid placing excess logic at beginning or end of conversion
   parameter 	      AVOID_ENDS = "TRUE";
 	//% If "FALSE", avoid shift register extraction (to help with high-speed routing at expense of resources)
	parameter         SAVE_AREA = "TRUE";
  
   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////

   //% Gray code input
   input [WIDTH-1:0]  G_in;
   //% Binary code output
   output [WIDTH-1:0] B_out;

   //% System clock (used for LATENCY > 0)
   input 	      CLK;
   //% Clock enable
   input 	      CE;   
   //% Begin conversion
   input 	      CONVERT;
   //% Conversion is complete
   output 	      VALID;	

   ////////////////////////////////////////////////////
   //
   // CONVENIENCE PARAMETERS
   //
   ////////////////////////////////////////////////////

`include "clogb2.vh"   
   //% Maximum number of stages needed.
   localparam 	      NSTAGES = clogb2(WIDTH);   
   //% Width that we're actually going to use
   localparam 	      GWIDTH = (1<<NSTAGES);
   //% Number of shift stages, or bits processed, per clock
   localparam 	      SHIFTS_PER_CLOCK = NSTAGES/(LATENCY+1);
   //% Number of shift stages, or bits processed, needed in a heavy stage
   localparam         HEAVY_SHIFTS_PER_CLOCK = SHIFTS_PER_CLOCK+1;
   //% Number of stages that will be heavy (have SHIFTS_PER_CLOCK+1 shifts/bits processed)
   localparam         HEAVY_STAGES = NSTAGES % (LATENCY+1);

   //% @brief First early heavy stage when ends are avoided.
   //% \n\n
   //% Start of early heavy stage computation. Here assume HEAVY_WEIGHT=="EARLY"
   //% and AVOID_ENDS=="TRUE"
   //% If there are heavy stages, then LATENCY is clearly greater than 0, and
   //% NSTAGES is clearly greater than 2 (b/c NSTAGES=2 has a max lat of 1 and
   //% 2 % 2 is zero).
   //% if LATENCY=1, and WIDTH=5, NSTAGES = 3, HEAVY_STAGES=1. Here HEAVY_STAGES
   //% is not less than LATENCY (LATENCY+1-1), so we have to put a heavy stage
   //% in the earliest possible slot (0). Otherwise, if HEAVY_STAGES is less than
   //% LATENCY, we can put heavy stages completely in the middle, and since we're
   //% weighting early, we put it at 1.
   localparam         FIRST_EARLY_AVOID_HEAVY_STAGE = (HEAVY_STAGES) ? 
		      (HEAVY_STAGES < LATENCY ? 1 : 0) : NSTAGES;
   //% @brief First early heavy stage when ends aren't avoided.
   localparam         FIRST_EARLY_NOAVOID_HEAVY_STAGE = (HEAVY_STAGES) ?
		      0 : NSTAGES;
   //% @brief First early heavy stage.
   localparam         FIRST_EARLY_HEAVY_STAGE = (AVOID_ENDS == "TRUE") ? 
		      FIRST_EARLY_AVOID_HEAVY_STAGE : FIRST_EARLY_NOAVOID_HEAVY_STAGE;
   //% @brief Last late heavy stage when ends are avoided.
   localparam         LAST_LATE_AVOID_HEAVY_STAGE = (HEAVY_STAGES) ? 
		      (HEAVY_STAGES < LATENCY ? LATENCY-1 : LATENCY) : NSTAGES;
   //% @brief Last late heavy stage when ends aren't avoided.
   localparam         LAST_LATE_NOAVOID_HEAVY_STAGE = LATENCY;
   //% @brief Last late heavy stage.
   localparam         LAST_LATE_HEAVY_STAGE = (AVOID_ENDS == "TRUE") ?
		      LAST_LATE_AVOID_HEAVY_STAGE : LAST_LATE_NOAVOID_HEAVY_STAGE;
   
   //% Last early heavy stage.
   localparam         LAST_EARLY_HEAVY_STAGE = FIRST_EARLY_HEAVY_STAGE + HEAVY_STAGES - 1;
   //% Last late heavy stage.
   localparam         FIRST_LATE_HEAVY_STAGE = LAST_LATE_HEAVY_STAGE - HEAVY_STAGES + 1;
   
   //% First heavy stage.
   localparam         FIRST_HEAVY_STAGE = (HEAVY_WEIGHT=="EARLY") ? 
		      FIRST_EARLY_HEAVY_STAGE : FIRST_LATE_HEAVY_STAGE;
   //% Last heavy stage.
   localparam         LAST_HEAVY_STAGE = (HEAVY_WEIGHT=="EARLY") ? 
		      LAST_EARLY_HEAVY_STAGE : LAST_LATE_HEAVY_STAGE;
      
   //% G_pipe is LATENCY wide - the head is just G_in
	(* SHREG_EXTRACT = SAVE_AREA *)
   reg [GWIDTH-1:0]   G_pipe[LATENCY:0];

   //% The input to a pipe
   wire [GWIDTH-1:0]  G_pipe_in[LATENCY:0];

   //% The input to a partial throughput stage
   wire [GWIDTH-1:0]  G_partial = (LATENCY > 0) ? G_pipe[1] : G_pipe[0];   

   //% Convert_pipe is LATENCY wide - the head is just CONVERT.
	(* SHREG_EXTRACT = SAVE_AREA *)
   reg [LATENCY:0]    Convert_pipe = {LATENCY+1{1'b0}};

   //% G_feed are the outputs of the Shift_Xors
   wire [GWIDTH-1:0]   G_feed[NSTAGES-1:0];

   ////////////////////////////////////////////////////
   //
   // INITIAL BLOCKS
   //
   ////////////////////////////////////////////////////   
	
   //% Initialization iterator.
   integer 	       init;

   initial begin
      for (init=0;init<LATENCY+1;init=init+1)
	G_pipe[init] <= {GWIDTH{1'b0}};
   end
	
`ifdef DOXYGEN
	// These are only here to help Doxygen's inheritance graph.
	//% @brief <b>PARTIAL.MUX[i].MUXBODY.gmux</b> : Multiplexer to select stage results for output registers for partial bandwidth converter
	//%
	//% The partial-bandwidth converter requires that the input to the output registers be muxed between the shift-xor
	//% stages depending on the Convert pipe - the Generic_Gray_to_Binary_partial_mux does that. The outputs are chained together
	//% through all of the stages (which slows down the partial bandwidth converter).
	//% 
	//% The full name of this instance is <b>PARTIAL.MUX[i].MUXBODY.gmux</b> with i ranging from 1 to LATENCY. It is listed
	//% here as gmux due to Doxygen limitations.
	Generic_Gray_to_Binary_partial_mux #(.WIDTH(GWIDTH)) gmux(.I0(G_partial_chain[p_i-1]),.I1(G_pipe_in[p_i]),.SEL(Convert_pipe[p_i-1]),.O(G_partial_chain[p_i]));
	
	//% @brief <b>SL[i].sx</b> : Shift-xor module. Equivalent to I ^ I>>RSHIFT.
	//%
	//% The full name of this instance is <b>SL[i].sx</b> with i ranging from 0 to NSTAGES-1. It is listed here as
	//% sx due to Doxygen limitations.
	Generic_Gray_to_Binary_shift_xor #(.WIDTH(GWIDTH),.RSHIFT(1<<s_i)) sx(.I(tmp),.O(G_feed[s_i]));
`endif
	

   ////////////////////////////////////////////////////
   //
   // GENERATE BLOCKS
   //
   ////////////////////////////////////////////////////   
   
   generate
      genvar s_i;      
      // One way or another, we're going to have to have NSTAGES shift_xors.
      // So we loop over NSTAGES first, and then later loop over LATENCY
      // to attach things to registers.
      for (s_i=0;s_i<NSTAGES;s_i=s_i+1) begin : SL
	 // Now we need to find what to attach the input of this shift_xor.
	 // So we have an absolute TON of case statements. Great.
	 wire [GWIDTH-1:0] tmp;
	 // Are we before the first heavy stage?
	 if (s_i < FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK) begin : A
	    // If so, what portion of the stage are we in?
	    // If 0, we're the beginning, so we take the pipe as input
	    if (!(s_i % SHIFTS_PER_CLOCK)) begin : AA
	       if (THROUGHPUT=="FULL") begin : FULL
		  assign tmp = G_pipe[s_i/SHIFTS_PER_CLOCK];
	       end else begin : PARTIAL
		  if (s_i == 0) begin : HEAD
		     assign tmp = G_pipe[s_i];
		  end else begin : BODY
		     assign tmp = G_partial;
		  end
	       end
	    end else begin : AB
	       // Else, we're in the middle, so we take the last feed as input
	       assign tmp = G_feed[s_i-1];
	    end
	    // Are we at the end of the stage?
	    if (s_i != NSTAGES-1) begin : ACOND
	       if (!((s_i+1) % SHIFTS_PER_CLOCK)) begin : AEND
		  assign G_pipe_in[(s_i+1)/SHIFTS_PER_CLOCK] = G_feed[s_i];
	       end
	    end
	 end 
	 // Sigh, we're not - are we in a heavy stage?
	 else if (s_i < FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK+HEAVY_STAGES*HEAVY_SHIFTS_PER_CLOCK) begin : B
	    if (!((s_i - FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK) % HEAVY_SHIFTS_PER_CLOCK)) begin : BA
	       if (THROUGHPUT=="FULL") begin : FULL
		  assign tmp = G_pipe[FIRST_HEAVY_STAGE+(s_i-FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK)/HEAVY_SHIFTS_PER_CLOCK];
	       end else begin : PARTIAL
		  assign tmp = G_partial;
	       end
	    end else begin : BB
	       assign tmp = G_feed[s_i-1];
	    end
	    if (s_i != NSTAGES-1) begin : BCOND
	       if (!((s_i - FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK + 1) % HEAVY_SHIFTS_PER_CLOCK)) begin : BEND
		  assign G_pipe_in[FIRST_HEAVY_STAGE+(s_i-FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK+1)/HEAVY_SHIFTS_PER_CLOCK] = G_feed[s_i];
	       end
	    end
	 end
	 // OK, we're in the last stages.
	 else begin : C
	    if (!((s_i-FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK-HEAVY_STAGES*HEAVY_SHIFTS_PER_CLOCK) % SHIFTS_PER_CLOCK)) begin : CA
	       if (THROUGHPUT=="FULL") begin : FULL
		  assign tmp = G_pipe[LAST_HEAVY_STAGE+(s_i-FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK-HEAVY_STAGES*HEAVY_SHIFTS_PER_CLOCK)/SHIFTS_PER_CLOCK];
	       end else begin : PARTIAL
		  assign tmp = G_partial;
	       end
	    end else begin : CB
	       assign tmp = G_feed[s_i-1];
	    end
	    // final G_pipe_in...
	    if (s_i != NSTAGES-1) begin : CCOND
	       if (!((s_i - FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK-HEAVY_STAGES*HEAVY_SHIFTS_PER_CLOCK+1) % SHIFTS_PER_CLOCK)) begin : CEND
		  assign G_pipe_in[LAST_HEAVY_STAGE+(s_i-FIRST_HEAVY_STAGE*SHIFTS_PER_CLOCK-HEAVY_STAGES*HEAVY_SHIFTS_PER_CLOCK+1)/SHIFTS_PER_CLOCK] = G_feed[s_i];
	       end
	    end
	 end
	 Generic_Gray_to_Binary_shift_xor #(.WIDTH(GWIDTH),.RSHIFT(1<<s_i)) sx(.I(tmp),.O(G_feed[s_i]));
      end
   endgenerate
   
   generate
      genvar 		 g_i;
      genvar 		 p_i;
      // Attach stage outputs to registers.
      //
      // The sole difference between the full and partial decoder is that
      // the full bandwidth has WIDTH*LATENCY registers,
      // and the partial bandwidth has WIDTH registers and LATENCY muxes.
      if (THROUGHPUT=="PARTIAL") begin : PARTIAL
	 wire [GWIDTH-1:0] G_partial_chain[LATENCY:1];
	 for (p_i=1;p_i<LATENCY+1;p_i=p_i+1) begin : MUX
	    if (p_i == 1) begin : MUX_HEAD
	       assign G_partial_chain[p_i] = G_pipe_in[p_i];
	    end else begin : MUX_BODY
	       Generic_Gray_to_Binary_partial_mux #(.WIDTH(GWIDTH)) gmux(.I0(G_partial_chain[p_i-1]),.I1(G_pipe_in[p_i]),.SEL(Convert_pipe[p_i-1]),.O(G_partial_chain[p_i]));
	    end
	    always @(posedge CLK) begin
		    if (CE) Convert_pipe[p_i] <= Convert_pipe[p_i-1];
	    end
         end
	 if (LATENCY > 0) begin : PARTIAL_REGS
	    always @(posedge CLK) begin
	       if (CE) G_pipe[1] <= G_partial_chain[LATENCY];
	    end
         end
      end else begin : FULL
	 for (g_i=1;g_i<LATENCY+1;g_i=g_i+1) begin : PIPE
	    always @(posedge CLK) begin
	       if (CE) G_pipe[g_i] <= G_pipe_in[g_i];
	    end
            always @(posedge CLK) begin
	       if (CE) Convert_pipe[g_i] <= Convert_pipe[g_i-1];
	    end
         end
      end
   endgenerate

   ////////////////////////////////////////////////////
   //
   // ALWAYS BLOCKS
   //
   ////////////////////////////////////////////////////   

   //% Attach G-pipe head
   always @(*) begin : GRAY_PIPE_HEAD
      G_pipe[0][WIDTH-1:0] <= G_in;
   end
   //% Attach Convert_pipe head 
   always @(*) begin : CONVERT_PIPE_HEAD
      Convert_pipe[0] <= CONVERT;
   end      

   ////////////////////////////////////////////////////
   //
   // ASSIGN STATEMENTS
   //
   ////////////////////////////////////////////////////   
   
   assign B_out = G_feed[NSTAGES-1][WIDTH-1:0];
   assign VALID = Convert_pipe[LATENCY];
endmodule   

//% @brief Helper module for the partial-bandwidth Log2 Gray to Binary converter
//%
//% This is just a small helper module for the Log2 Gray to Binary converter.
//% It makes the RTL view of the Log2 converter very easy to interpret, since
//% it collects the various busses.

module Generic_Gray_to_Binary_partial_mux(I0, I1, O, SEL);
   ////////////////////////////////////////////////////   
   //
   // PARAMETERS
   //      
   ////////////////////////////////////////////////////      

   //% Input width of I0, I1, O.
   parameter 	     WIDTH=32;

   ////////////////////////////////////////////////////
   //
   // PORTS
   //
   ////////////////////////////////////////////////////      

   //% First input (feed up from previous stage)
   input [WIDTH-1:0] I0;
   //% Second input (output from stage)
   input [WIDTH-1:0] I1;
   //% Output
   output [WIDTH-1:0] O;
   //% Select I1 if 1, I0 if 0
   input 	      SEL;

   ////////////////////////////////////////////////////
   //
   // ASSIGN STATEMENTS
   //
   ////////////////////////////////////////////////////      
   
   assign 	      O = SEL ? I1 : I0;

endmodule

//% @brief Helper module for the Log2 Gray to Binary converter.
//%
//% This is a small helper module for the Log2 Gray to Binary converter
//% which takes an input, and shifts it via a parameterized value before
//% xoring it with the input again. It makes the RTL view of the Log2
//% converter very easy to interpret.
module Generic_Gray_to_Binary_shift_xor(I, O);

   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////      
   
   //% Width of the input and output
   parameter 	      WIDTH = 32;
   //% Number of bits to shift input by before XORing
   parameter 	      RSHIFT = 4;

   ////////////////////////////////////////////////////
   //
   // PORTS
   //
   ////////////////////////////////////////////////////

   //% Input to shift and xor
   input [WIDTH-1:0]  I;   
   //% Output after shift and xor
   output [WIDTH-1:0] O;

   ////////////////////////////////////////////////////
   //
   // GENERATE BLOCKS
   //
   ////////////////////////////////////////////////////
   
   generate
      genvar 	      i;
      // Loop over the bits and decide whether to pass or XOR
      for (i=0;i<WIDTH;i=i+1) begin : SX
	 if (i<WIDTH-RSHIFT) begin : XOR
	    assign O[i] = I[i+RSHIFT] ^ I[i];
	 end else begin : SHIFT
	    assign O[i] = I[i];
	 end
      end
   endgenerate

endmodule
