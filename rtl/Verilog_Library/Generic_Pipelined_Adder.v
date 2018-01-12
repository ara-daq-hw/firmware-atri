`timescale 1ns / 1ps
/**
 * @brief Generic_Pipelined_Adder.v Contains Generic_Pipelined_Adder.
 */


//% @class Generic_Pipelined_Adder
//% @brief Generic Pipeline Tools multi-purpose adder.
//%
//% \par Module Symbol
//% @gensymbol
//% MODULE Generic_Pipelined_Adder
//% PARAMETER WIDTH 32
//% PARAMETER LATENCY 3
//% PARAMETER THROUGHPUT "FULL"
//% LPORT A input
//% LPORT B input
//% LPORT CI input
//% LPORT space
//% LPORT ADD input
//% LPORT CE input
//% LPORT CLK input
//% RPORT Q output
//% RPORT space
//% RPORT CO output
//% RPORT space
//% RPORT VALID output
//% @endgensymbol
//% \par Overview
//% A parameterizable pipelined adder. Generic_Pipelined_Adder can
//% be used in place of a simple adder anywhere pipelining may be necessary.
//% Intended to be an eventual complete replacement (and improvement upon)
//% the standard adder IP cores provided by FPGA vendors.
//% Generic_Pipelined_Adder has several advantages over those IP cores:
//% - Open source
//% - Easier to debug (internals are documented and visible)
//% - Easier to modify
//% - Portable between FPGA architectures.
//% - Parameterizable using Verilog parameters
//%
//% \n\n
//% It's currently not as feature-rich as many of those implementations.
//% That will hopefully be improved upon.
//% \n\n
//% One feature that Generic_Pipelined_Adder has that the typical IP cores
//% (e.g. the Xilinx adder) do not is an adder which lends itself to being
//% used inside a state machine with no glue logic. A design with only
//% a clock enable (CE) used for enabling/disabling addition needs to know
//% how long the latency of the calculation is <i>a priori</i>. This design,
//% with an "ADD" (begin addition) input and a "VALID" (addition complete)
//% output embeds the latency with no additional information.
//% 
//% \par Parameters
//% Generic_Pipelined_Adder currently has three parameters, and several more planned.
//% - WIDTH
//% - LATENCY
//% - THROUGHPUT
//% - ADD_IMMEDIATE (not used)
//% - DYNAMIC_SUBTRACT (not used)
//% - A_IS_CONSTANT (not used)
//% - B_IS_CONSTANT (not used)
//% - ADD_IS_CONSTANT (not used)
//% \n\n
//% WIDTH controls the width of the A, B, and Q data busses. No maximum. Defaults to 32.
//% \n\n
//% LATENCY controls the number of clock edges after assertion of
//% ADD before the data can be latched on the next positive edge. LATENCY
//% of 0 thus simplifies down to "Q=A+B". Maximum value of WIDTH-1, which
//% adds a single bit per cycle. Defaults to 3.
//% \n\n
//% THROUGHPUT controls whether a full-bandwidth or partial-bandwidth
//% adder is generated. If "FULL", the adder is capable of performing
//% 1 calculation per cycle, and there are no hold requirements on A, B, CI.
//% If "PARTIAL", the adder performs 1 calculation per LATENCY cycles, and
//% requires A, B, CI to not change from ADD assertion to VALID output.
//% A full-bandwidth adder requires dramatically more resources than a
//% partial-bandwidth adder. See interfacing notes for details.
//% \n\n
//% ADD_IMMEDIATE is not currently used. It will determine whether the Q-slice
//% resolving technique is used, or the (currently used) input hold-and-resolve
//% technique is used. It will likely default to "FULL", and only is used if
//% THROUGHPUT is TRUE.
//% \n\n
//% DYNAMIC_SUBTRACT is not currently used. It will determine whether to enable
//% dynamic subtraction - i.e. pipelining the ADD_nSUB input, when it exists.
//% Will only be used if THROUGHPUT is TRUE.
//% \n\n
//% A_IS_CONSTANT is not currently used. It defaults to FALSE and should be
//% set true by any implementation (even current ones) for which A is a constant
//% value. Eventually this will eliminate the A pipeline in the full-bandwidth
//% adder (THROUGHPUT = TRUE).
//% \n\n
//% B_IS_CONSTANT is not currently used. It defaults to FALSE and should be
//% set true by any implementation (even current ones) for which B is a constant
//% value. Eventually this will eliminate the B pipeline in the full-bandwidth
//% adder (THROUGHPUT = TRUE).
//% \n\n
//% ADD_IS_CONSTANT is not currently used. It defaults to FALSE and should be
//% set true by any implementation (even current ones) for which ADD is a constant
//% value. Eventually this will eliminate the ADD pipeline in either the full
//% or partial bandwidth case.
//% \par Operation
//% \n
//% An addition is begun by asserting ADD, and placing the values to be
//% added on A and B, with the carry input (if any) on CI. When the addition
//% finishes, VALID is asserted and Q and CO contain the result and carry
//% output.
//% \n\n
//% The outputs are <b>not</b> fully registered - for LATENCY of 0,
//% Generic_Pipelined_Adder instantiates no registers, and Q is simply "A+B"
//% using logic gates only. For higher latencies, Q is a combination of
//% registered outputs (for bits 0 through WIDTH-(WIDTH/(LATENCY+1))-1) and
//% the output of the final adder (for bits WIDTH-(WIDTH/(LATENCY+1))-1 through
//% WIDTH-1).
//% \n\n
//% Also note that for THROUGHPUT="PARTIAL", the inputs A, B are not
//% registered internally, which means that the router will have to be able
//% to connect A, B to the Q registers through a WIDTH/LATENCY-bit adder
//% in a single clock cycle.
//% \par Timing diagrams
//% \n
//% Timing diagram with LATENCY=3, THROUGHPUT="PARTIAL", WIDTH=4, assume CE=1.
//% @drawtiming
//% CLK=tick,A=X,B=X,CI=X,CO=X,Q=X,ADD=0,VALID=0.
//% ADD=1;A="12";B="10";CI="0".
//% ADD=0.
//% .
//% ADD=>Q="6";ADD=>CO="1";ADD=>VALID=1.
//% VALID=0;A=X;B=X;CI=X.
//% @enddrawtiming
//%
//% Timing diagram with LATENCY=3, THROUGHPUT="FULL", WIDTH=4, assume CE=1.
//% 
//% @drawtiming
//% CLK=tick,A=X,B=X,CI=X,CO=X,Q=X,ADD=0,VALID=0.
//% ADD=1;A="12";B="10";CI="0".
//% A="4";B="6";CI="0".
//% ADD=0;A=X;B=X;CI=X.
//% ADD=>Q="6";ADD=>CO="1";ADD=>VALID=1.
//% Q="10";CO="0".
//% VALID=0.
//% @enddrawtiming
//%
//% Note the main difference between the partial and full bandwidth
//% adders - A, B, and CI are required to be valid for LATENCY clock
//% cycles for a partial-bandwidth adder, whereas for the full bandwidth
//% adder the required valid period is simply 1 clock.
//% @par Interfacing notes
//% \n
//% The ADD input/VALID output combination allows for simple chaining
//% of Generic Pipeline Tools - for instance, a Generic_Pipelined_Adder
//% VALID output could be connected to a Generic_Pipelined_Comparator's
//% COMPARE input. In this case, changing the pipeline depth of the
//% comparator or adder would be as simple as changing the parameter
//% in the instantiation, and all functionality would remain identical.
//% \n\n
//% Interfacing with a state machine is also simple. Consider a portion
//% of a state machine where two inputs, A, B, need to be added, and the
//% latency of the operation is unimportant, and only one calculation need
//% be done at a time (thus THROUGHPUT="PARTIAL", a partial-bandwidth adder).
//% Consider three states ADD_BEGIN, ADD_WAIT, ADD_DONE. ADD_BEGIN
//% asserts ADD, moves to ADD_DONE if VALID, and otherwise ADD_WAIT.
//% ADD_WAIT moves to ADD_DONE if VALID. In the ADD_DONE state, the data
//% (which is latched if VALID) is ready and the add is complete.
//% \n\n
//% As with the chained Generic Pipeline Tools, this interface allows
//% changing the pipeline depth (and thus improving the speed) by simply
//% changing a parameter in the module - thus, the designer could start
//% off with LATENCY=0, and increase the pipelining until the design met
//% timing. Having the ADD_BEGIN state move to ADD_DONE if VALID allows
//% the design implementation to be identical regardless of the value of
//% LATENCY.
//% \n\n
//% The full-bandwidth pipeline implementation of this adder is currently
//% not ideal - it currently has a pipeline for A, B, and Q and adds
//% a portion of A, B and the carry pipe into Q and the carry pipe each
//% cycle. Because the inputs/outputs aren't registered, and portions of
//% the A, B, Q pipes aren't used (low bits of high latency A, B pipes and
//% high bits of low latency Q pipes) the register usage is
//% WIDTH*LATENCY/2 for the A, B, and Q pipes and 
//% 2*LATENCY for the carry and sequencing (ADD/VALID) pipe for a total
//% usage of (4+3*WIDTH)*(LATENCY)/2 registers.
//% \n\n
//% A better implementation (which will eventually replace this one)
//% would be to immediately add A, B in WIDTH/LATENCY chunks into a Q
//% pipe and a carry pipe, and then slowly resolve the Q pipe with the
//% carry pipe. This would require WIDTH*LATENCY registers for the Q_pipe,
//% and (LATENCY+3)*(LATENCY)/2 registers for the carry pipe,
//% and LATENCY registers for the sequencing pipe, for a total usage of
//% (2*WIDTH+LATENCY+5)*(LATENCY)/2 registers, a difference of 
//% (WIDTH-LATENCY-1) registers. Since the maximum value of LATENCY is
//% WIDTH-1, this is at worst an equivalent number of registers.
//% \n\n
//% To illustrate, consider a 4-bit pipelined add with latency 1. The
//% current, full bandwidth implementation is shown in the following
//% timing diagram (assume CE=1):
//% @drawtiming
//% CLK=0,A="3 (0011)",B="5 (0101)",ADD=0,CO=X,Q=X,VALID=0,A_0=X,B_0=X,C_0=X.
//% CLK=1.
//% CLK=0;ADD=1.
//% CLK=1;A=>A_0="3 (00xx)";B=>B_0="5 (01xx)";A,B=>Q="0 (xx00)";A,B=>C_0="0";ADD=>VALID=1.
//% CLK=0;ADD=0;A_0,B_0,C_0=>Q="8 (1000)";C_0=>CO="0".
//% CLK=1;VALID=0.
//% CLK=0.
//% @enddrawtiming
//% A_0, B_0 are the pipeline registers for A, B. Since this adder has a
//% latency of 1, the Q pipeline stage is built into the lower 2 bits of
//% the output Q. Total register usage is 8 - 6 total for the A, B, Q
//% pipes, and 2 for the carry pipe (C_0) and sequencing pipe (VALID).
//% \n\n
//% The second implementation's timing diagram would be (assume CE=1):
//% @drawtiming
//% CLK=0,A="3 (0011)",B="5 (0101)",ADD=0,CO=X,Q=X,VALID=0,Q_0=X,C_0=X.
//% CLK=1.
//% CLK=0;ADD=1.
//% CLK=1;A,B=>Q_0="4 (01xx)";A,B=>Q="0 (xx00)";A,B=>C_0="10";ADD=>VALID=1.
//% CLK=0;ADD=0;Q_0,C_0=>Q="8 (1000)";Q_0,C_0=>CO="0".
//% CLK=1;VALID=0.
//% CLK=0.
//% @enddrawtiming
//% Here, the A, B pipes are replaced by a single Q pipe, expanded to
//% WIDTH*LATENCY (here, 2 bits are in Q_0 and 2 bits are in Q simply for
//% bookkeeping) and the carry pipe expands to (LATENCY+1)*(LATENCY+1)/2
//% bits. Total register usage is 7 - 4 for the Q pipe, 2 for the carry
//% pipe, and 1 for the sequencing pipe (VALID).
//% \n\n
//% In the end, both implementations may be made available - the two route
//% very differently, with the second implementation requiring dense direct
//% connections through logic to every A, B input (through WIDTH/(LATENCY+1)
//% bit adders) and the first implementation requiring only WIDTH/(LATENCY+1)
//% bits to be connected immediately through the adders, with the remaining
//% bits being simply pipelined along, sometimes for many clock cycles before
//% they need to be used.
//% \n\n
//% The partial-bandwidth implementation in this adder is identical
//% to this strategy, with the exception that the adds are done in
//% separate clock cycles rather than all in the first.
//% @par Examples
//% \n
//% Verilog: default 32 bit full-bandwidth adder with 3 clock cycle latency,
//% with clock enable constant.
//%
//% @verbatim
//% wire [31:0] A;
//% wire [31:0] B;
//% wire ADD;
//% wire VALID;
//% wire CLK;
//% wire [31:0] Q;
//% Generic_Pipelined_Adder adder(.A(A),.B(B),.CLK(CLK),.CE(1),.ADD(ADD),.VALID(VALID),.Q(Q));
//% @endverbatim
//%
//% Verilog: 4-bit, partial bandwidth adder with 1 clock cycle latency, with clock
//% enable constant and CI input constant 0 (and ignored CO output).
//%
//% @verbatim
//% wire [3:0] A;
//% wire [3:0] B;
//% wire ADD;
//% wire VALID;
//% wire CLK;
//% wire [3:0] Q;
//% Generic_Pipelined_Adder #(.WIDTH(4),.THROUGHPUT("PARTIAL"),.LATENCY(1)) adder(.A(A),.B(B),.CLK(CLK),.CE(1),.ADD(ADD),.VALID(VALID),.Q(Q));
//% @endverbatim
//% \n
//% @par Parameter checking
//% \n\n
//% Generic_Pipelined_Adder can use the vassert Verilog assertion helper
//% modules to check parameters, if the synthesis tool allows for mixed
//% Verilog/VHDL designs. Define PARAMETER_CHECK to implement those
//% checks.
//% \n\n
//% @par To-Do List
//% \n
//% - Implement ADD_IMMEDIATE - alternative fully-pipelined strategy (Q-slice resolving).
//% - Implement A_IS_CONSTANT, B_IS_CONSTANT to turn off A or B pipelines
//% - Implement ADD_IS_CONSTANT to turn off ADD pipeline.
//% - Turn off pipeline clocking except when the appropriate ADD pipeline bit is set.
//% - Implement DYNAMIC_SUBTRACT to pipeline ADD_nSUB (and create ADD_nSUB input)
module Generic_Pipelined_Adder(
			       A,
			       B,
			       Q,
			       CI,
			       CO,
			       CLK,
			       CE,
			       ADD,
			       VALID
    );
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

   //% Width of the A, B inputs and Q output.
   parameter WIDTH = 32;
   //% Number of clock edges after ADD asserted to wait before clocking result.
   parameter LATENCY = 3;
   //% "FULL" for full-bandwidth, "PARTIAL" for partial-bandwidth.
   parameter THROUGHPUT = "FULL";

`ifdef PARAMETER_CHECK
   
   ////////////////////////////////////////////////////
   //
   // PARAMETER CHECKING
   //
   ////////////////////////////////////////////////////   

   //% Check if THROUGHPUT is a valid type
   localparam 	      THROUGHPUT_CHECK = (THROUGHPUT=="FULL") || (THROUGHPUT=="PARTIAL") ;
   
   vassert_if_less_than
     #(.LIMIT(1),
       .VALUE(WIDTH),
       .ERR("Generic_Pipelined_Adder: WIDTH must be greater than 0")) width_check();
   vassert_if_greater_than 
     #(.LIMIT(WIDTH-1),
       .VALUE(LATENCY),
       .ERR("Generic_Pipelined_Adder: Latency must be less than WIDTH")) latency_check();   
   vassert_if_not 
     #(.BOOL(THROUGHPUT_CHECK),
       .ERR("Generic_Pipelined_Adder: THROUGHPUT must be FULL or PARTIAL")) always_valid_check();
`endif

   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////
   
   //% Input operand
   input [WIDTH-1:0]  A;
   //% Input operand
   input [WIDTH-1:0]  B;
   //% Output sum of A and B ( = Q_pipe[LATENCY])
   output [WIDTH-1:0] Q;
   //% Carry input
   input 	      CI;
   //% Carry output ( = C_pipe[LATENCY])
   output 	      CO;
   //% System clock
   input 	      CLK;
   //% System clock enable
   input 	      CE;   
   //% Begin addition of values of A, B currently on bus
   input 	      ADD;
   //% Addition that began LATENCY clock cycles previous is complete ( = add_pipe[LATENCY])
   output 	      VALID;
   
   ////////////////////////////////////////////////////
   //
   // CONVENIENCE PARAMETERS
   //
   ////////////////////////////////////////////////////

   //% @brief @private Number of bits per group, rounded down
   localparam 	      NBITS = WIDTH/(LATENCY+1);
   //% @brief @private Number of groups to contain NBITS+1 bits
   localparam 	      EXTRAGROUPS = WIDTH - NBITS*(LATENCY+1);
   //% @brief @private Convenience
   localparam 	      EXTRABITS = NBITS+1;

   ////////////////////////////////////////////////////
   //    
   // LOCAL VARIABLES
   //
   ////////////////////////////////////////////////////
   
   //% @name Pipelines
   //% @{
   //% @brief @private Sequencing pipeline (ADD input, VALID output)
   reg [LATENCY:0]    add_pipe = {LATENCY+1{1'b0}};
   //% @brief @private Output pipeline (with Q=Q_pipe[LATENCY])
   reg [WIDTH-1:0]    Q_pipe[LATENCY:0];
   //% @brief @private A input pipeline (with A_pipe[0] = A)
   reg [WIDTH-1:0]    A_pipe[LATENCY:0];
   //% @brief @private B input pipeline (with B_pipe[0] = B)
   reg [WIDTH-1:0]    B_pipe[LATENCY:0];
   //% @brief @private Carry pipeline (with CO=C_pipe[LATENCY])
   reg [LATENCY:0]    C_pipe;
   //% @}
   
   //% @name Adder stage inputs/outputs
   //% @{
   //% @brief @private A input to each adder stage in the pipeline.
   wire [WIDTH-1:0]   A_stage[LATENCY:0];
   //% @brief @private B input to each adder stage in the pipeline 
   wire [WIDTH-1:0]   B_stage[LATENCY:0];
   //% @brief @private Q output from each adder stage in the pipeline
   wire [WIDTH-1:0]   Q_stage[LATENCY:0];
   //% @brief @private CI input to each adder stage in the pipeline
   wire [LATENCY:0]   CI_stage;
   //% @brief @private CO output from each adder stage in the pipeline
   wire [LATENCY:0]   CO_stage;
   //% @}
   
   ////////////////////////////////////////////////////
   //
   // ALWAYS BLOCKS
   //
   ////////////////////////////////////////////////////


   //% @brief @private Attach ADD to head of sequencing pipeline
   always @(ADD) begin : ADD_PIPELINE_HEAD
      add_pipe[0] <= ADD;
   end
   
   //% @brief @private Sequencing pipeline logic
   always @(posedge CLK) begin : ADD_PIPELINE_FEED
      if (LATENCY > 0)
	if (CE)	
	  add_pipe[LATENCY:1] <= add_pipe[LATENCY-1:0];
   end


   //% @brief @private Pipeline initialization iterator.
   integer init_iter;
   //% @brief @private Initialization of pipelines.
   initial begin : PIPE_INIT
      for (init_iter=0;init_iter<LATENCY+1;init_iter=init_iter+1) begin
	 A_pipe[init_iter] <= {WIDTH{1'b0}};
	 B_pipe[init_iter] <= {WIDTH{1'b0}};
	 Q_pipe[init_iter] <= {WIDTH{1'b0}};
	 C_pipe[init_iter] <= 1'b0;
      end
   end
   
   //% @brief @private Assignment of the various adder stage inputs.
   //%
   //% This segment attaches the stage inputs, from either the
   //% pipelines (in a full-bandwidth adder) or the data inputs
   //% (in a partial-bandwidth adder). The CI inputs are always
   //% attached to either CI or the carry pipe.
   generate
      genvar stage_iter;
      for (stage_iter=0;stage_iter<LATENCY+1;stage_iter=stage_iter+1) begin : STAGELOOP
	 if (THROUGHPUT == "FULL") begin
	    assign A_stage[stage_iter] = A_pipe[stage_iter];
	    assign B_stage[stage_iter] = B_pipe[stage_iter];
	    // Q_stage is an output
	 end else begin
	    assign A_stage[stage_iter] = A;
	    assign B_stage[stage_iter] = B;
	    // Q_stage is an output
	 end
	 if (stage_iter == 0)
	   assign CI_stage[stage_iter] = CI;
	 else
	   assign CI_stage[stage_iter] = C_pipe[stage_iter-1];
	 // CO_stage is an output
      end
   endgenerate

   //% @brief @private Attach the A inputs to the beginning of the pipeline
   always @(*) begin : A_PIPE_HEAD
     A_pipe[0] <= A;
   end
   //% @brief @private Attach the B inputs to the beginning of the pipeline
   always @(*) begin : B_PIPE_HEAD
      B_pipe[0] <= B;
   end
   
   //% @brief @private Data pipeline iterator.
   integer 	  pipe_iter;
   //% @brief @private Propagate data up the pipeline.
   always @(posedge CLK) begin : PIPE_FEED
      for (pipe_iter=1;pipe_iter<LATENCY+1;pipe_iter=pipe_iter+1) begin
			if (CE && add_pipe[pipe_iter-1]) begin
				A_pipe[pipe_iter] <= A_pipe[pipe_iter-1];
				B_pipe[pipe_iter] <= B_pipe[pipe_iter-1];
			end
      end
   end

   //% @brief @private Connections between Q pipeline stages
   wire [WIDTH-1:0] Q_feed[LATENCY:0];

   //% @brief @private Define connections between stages of the Q pipeline.
   //%
   //% While the A, B pipelines simply pass data along,
   //% the Q pipelines have to insert the results of the adders
   //% as they become available, and also fill the unavailable
   //% results (higher bits) with zeros. These bits will get
   //% trimmed away, since they're never used, but they need to
   //% be assigned so that various simulators don't freak out.
   //%
   //% Some synthesis tools (XST) have 'issues' trying to do
   //% this mapping in the same generate block as the Q_pipe
   //% logic, so what we do is we define the mappings between
   //% two stages of the Q pipeline here, and then below we
   //% have the Q pipeline clock them in.
   //%
   //% This looks godawful complicated because we have to have
   //% separate name labels for:
   //% - The loop over stages (FEEDLOOP) 
   //% - The loop over bits (BITLOOP)
   //% - A section for stages other than 0 (UPPER)
   //% - A section for stage 0 (BOTTOM) 
   //% - Sections (EXTRAUP) for normal-length stages after stage 0
   //% - Sections (NORMALUP) for extra-length stages after stage 0
   //% - Sections (EXTRABOT) for a normal-length stage 0
   //% - Sections (NORMALBOT) for an extra-length stage 0
   //% - Assignments for feeding (FEEDUP/FEEDXUP) a lower Q stage to an upper Q stage
   //% - Assigning results (RESUP/RESXUP/RESBOT/RESXBOT) to a Q stage
   //% - Assigning zero (CLEARUP/CLEARXUP/CLEARBOT/CLEARXBOT) to a Q stage
   generate
      genvar 		 ri;
      genvar 		 rj;
      for (ri=0;ri<LATENCY;ri=ri+1) begin : FEEDLOOP
	 for (rj=0;rj<WIDTH;rj=rj+1) begin : BITLOOP
	    if (ri > 0) begin : UPPER
	       if (ri < EXTRAGROUPS) begin : EXTRAUP					
		  if (rj<ri*EXTRABITS) begin : FEEDXUP
		     assign Q_feed[ri][rj] = Q_pipe[ri-1][rj];
		  end else if (rj<(ri+1)*EXTRABITS) begin : RESXUP
		     assign Q_feed[ri][rj] = Q_stage[ri][rj];
		  end else begin : CLEARXUP
		     assign Q_feed[ri][rj] = 1'b0;
		  end
	       end else begin : NORMALUP
		  if (rj<(ri*NBITS+EXTRAGROUPS)) begin : FEEDUP
		     assign Q_feed[ri][rj] = Q_pipe[ri-1][rj];
		  end else if (rj<((ri+1)*NBITS+EXTRAGROUPS)) begin : RESUP
		     assign Q_feed[ri][rj] = Q_stage[ri][rj];
		  end else begin : CLEARUP
		     assign Q_feed[ri][rj] = 1'b0;
		  end
	       end
	    end else begin : BOTTOM
	       if (ri <  EXTRAGROUPS) begin : EXTRABOT
		  if (rj<(ri+1)*EXTRABITS) begin : RESXBOT
		     assign Q_feed[ri][rj] = Q_stage[ri][rj];
		  end else begin : CLEARXBOT
		     assign Q_feed[ri][rj] = 1'b0;
		  end
	       end else begin : NORMALBOT
		  if (rj<(ri+1)*NBITS) begin : RESBOT
		     assign Q_feed[ri][rj] = Q_stage[ri][rj];
		  end else begin : CLEARBOT
		     assign Q_feed[ri][rj] = 1'b0;
		  end
	       end
	    end
	 end
      end
   endgenerate

   //% @brief @private Q output pipeline logic.
   //%
   //% This is still bad, but not as bad as the feed mappings. For a full-bandwidth
   //% adder (QRESLOOPAV), we simply pipe the data through the feed mapping by looping
   //% (QRESLOOP) over the stages.
   //% \n\n
   //% For a partial bandwidth adder (QRESLOOPNAVEXTRA/QRESLOOPNAVNORMAL) we latch
   //% only the results from each output stage in the output registers (Q_pipe[LATENCY-1]).
   //% As the carry pipe propagates upwards, the data will slowly become valid.
   //%
   generate
      genvar 		    res_iter;
      for (res_iter=0;res_iter<LATENCY;res_iter=res_iter+1) begin : QRESLOOP
		 if (THROUGHPUT=="FULL") begin : QRESLOOPAV
			 always @(posedge CLK)
				if (CE && add_pipe[res_iter])
					Q_pipe[res_iter] <= Q_feed[res_iter];
		 end // QRESLOOPAV
		 else begin : QRESLOOPNAV
			 if (res_iter < EXTRAGROUPS) begin : QRESLOOPNAVEXTRA
				always @(posedge CLK) 
					 if (CE && add_pipe[res_iter])
						Q_pipe[LATENCY-1][res_iter*EXTRABITS +: EXTRABITS] <= Q_feed[res_iter][res_iter*EXTRABITS +: EXTRABITS];
          end // QRESLOOPNAVEXTRA
			 else begin : QRESLOOPNAVNORMAL
				always @(posedge CLK) 
				if (CE && add_pipe[res_iter])
					Q_pipe[LATENCY-1][res_iter*NBITS+EXTRAGROUPS +: NBITS] <= Q_feed[res_iter][res_iter*NBITS+EXTRAGROUPS +: NBITS];
			 end // QRESLOOPNAVNORMAL
		 end // QRESLOOPNAV
      end // QRESLOOP
   endgenerate
	
   //% @brief @private Carry pipeline logic.
   generate
      genvar carry_iter;
      for (carry_iter=0;carry_iter<LATENCY+1;carry_iter=carry_iter+1) begin : CPLOOP
	 if (carry_iter==LATENCY) begin : CPFINAL
	    always @(CO_stage[carry_iter]) 
	      C_pipe[carry_iter] <= CO_stage[carry_iter];
         end else begin : CPNORMAL
	    always @(posedge CLK) 
	      if (CE && add_pipe[carry_iter])
				C_pipe[carry_iter] <= CO_stage[carry_iter];
         end
      end
   endgenerate
   
   //% @brief @private Stitch the last Q_pipe stage (the actual Q outputs) together
   generate
      genvar final_iter;
      for (final_iter=0;final_iter<WIDTH;final_iter=final_iter+1) begin : FINAL
			// The last Q_pipe stage needs to feed up everything past NBITS*LATENCY+EXTRAGROUPS
			// e.g. for 32 bits, latency 3, NBITS = 8, EXTRAGROUPS = 0, so NBITS*LATENCY+EXTRAGROUPS
			// is 24.
			// Note that this works even if latency is 0.
			// In that case EXTRAGROUPS is always 0, LATENCY is 0, so FEED_UP never gets
			// instantiated.
			if (final_iter < NBITS*LATENCY+EXTRAGROUPS) begin : FEED_UP
				always @(Q_pipe[LATENCY-1][final_iter])
						Q_pipe[LATENCY][final_iter] <= Q_pipe[LATENCY-1][final_iter];
			end 
			// The remaining bits are what this stage is calculating. This just attaches
			// the output of the last adder.
			else begin : PASS_THROUGH
				always @(Q_stage[LATENCY][final_iter])
					Q_pipe[LATENCY][final_iter] <= Q_stage[LATENCY][final_iter];
			end
		end
   endgenerate
	
   //% @brief @private Adder instantiations.
   generate
      genvar add_iter;
      for (add_iter=0;add_iter<LATENCY+1;add_iter=add_iter+1) begin : ADDERS
	 if (add_iter < EXTRAGROUPS) begin : EXTRA
	    Generic_Adder #(.WIDTH(EXTRABITS))
	      adder(.A(A_stage[add_iter][add_iter*EXTRABITS +: EXTRABITS]),
		    .B(B_stage[add_iter][add_iter*EXTRABITS +: EXTRABITS]),
		    .Q(Q_stage[add_iter][add_iter*EXTRABITS +: EXTRABITS]),
		    .CI(CI_stage[add_iter]),
		    .CO(CO_stage[add_iter]));
	 end else begin : NORMAL
	    Generic_Adder #(.WIDTH(NBITS))
	      adder(.A(A_stage[add_iter][add_iter*NBITS + EXTRAGROUPS +: NBITS]),
		    .B(B_stage[add_iter][add_iter*NBITS + EXTRAGROUPS +: NBITS]),
		    .Q(Q_stage[add_iter][add_iter*NBITS + EXTRAGROUPS +: NBITS]),
		    .CI(CI_stage[add_iter]),
		    .CO(CO_stage[add_iter]));
	 end
      end
   endgenerate

   //
   // Outputs.
   //
   
   assign Q = Q_pipe[LATENCY];
   assign CO = C_pipe[LATENCY];
   assign VALID = add_pipe[LATENCY];
endmodule
