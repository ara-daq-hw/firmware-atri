`timescale 1ns / 1ps
//% @file Generic_Pipeline.v Contains Generic_Pipeline module.

//% @brief Parameterizable delay pipeline.
//%
//% @par Module Symbol
//% \n
//% @gensymbol
//% MODULE Generic_Pipeline
//% PARAMETER WIDTH 32
//% PARAMETER LATENCY 2
//% LPORT I input
//% RPORT O output
//% LPORT space
//% RPORT space
//% LPORT CLK input
//% LPORT CE input
//% @endgensymbol
//% \n
//% @par Overview
//% \n
//% Generic_Pipeline is a delay pipeline with parameterizable width and
//% latency. It's helpful for interfacing various signals with
//% Generic Pipeline Tools modules - if an additional signal needs to
//% be delayed for the same amount that an add going through a
//% Generic_Pipelined_Adder would take, for instance, the latency
//% can be assigned to a local parameter in the module and assigned
//% to both the adder and the pipeline, and changed in one place.
//%
//% @par Parameters
//% \n
//% Generic_Pipeline's simple parameters are:
//% \n
//% - WIDTH (= 32)
//% - LATENCY (= 3)
//% \n
//% WIDTH defines the I input and O output widths.
//% \n\n
//% LATENCY defines the number of clock cycles from data changing on I
//% to data changing on O. LATENCY of 0 just produces wires.
//% \n
//% Generic_Pipeline's advanced parameter is:
//% \n
//% - SAVE_AREA (= "TRUE")
//% \n
//% SAVE_AREA is either TRUE or FALSE. If TRUE, this tacks on compiler-specific
//% directives to ensure that the pipeline is not converted into a lower-speed
//% shift register.
//% 
//% @par Timing diagram
//% \n
//% Generic_Pipeline with LATENCY=2:
//% \n\n
//% @drawtiming
//% CLK=tick,I=X,O=X.
//% I=DATA0.
//% I=DATA1.
//% O=DATA0.
//% O=DATA1.
//% .
//% @enddrawtiming
//%
module Generic_Pipeline(I, O, CE, CLK);

   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
   
   //% Number of clock cycles after I changes that O changes
   parameter 	      LATENCY = 2;
   //% Width of I input and O output
   parameter 	      WIDTH = 32;
	//% If "FALSE", avoid shift register extraction (to help with high-speed routing at expense of resources)
	parameter         SAVE_AREA = "TRUE";

   ////////////////////////////////////////////////////
   //
   // PORTS
   //
   ////////////////////////////////////////////////////
   
   //% Input data
   input [WIDTH-1:0]  I;
   //% Delayed output data
   output [WIDTH-1:0] O;
   //% Clock enable
   input              CE;   
   //% System clock (only used if LATENCY > 0)
   input 	      CLK;
   	
   ////////////////////////////////////////////////////
   //
   // LOCAL VARIABLES
   //
   ////////////////////////////////////////////////////


	//% Data pipeline. pipeline[0] is just I.
	(* SHREG_EXTRACT = SAVE_AREA *)
	reg [WIDTH-1:0]    pipeline[LATENCY:0];
	//% Initialization iterator
	integer 	      init_iter;
	//% Pipe stage iterator
	integer pipe_iter;

	////////////////////////////////////////////////////
	//
	// INITIAL BLOCKS
	//
	////////////////////////////////////////////////////
	
	//% Initialize pipeline.
	initial begin : PIPE_INIT
		for (init_iter=0;init_iter<LATENCY+1;init_iter=init_iter+1) begin
			pipeline[init_iter] <= {WIDTH{1'b0}};
		end
	end

	//% Attach I to pipeline head
	always @(*) begin : PIPE_HEAD
		pipeline[0] <= I;
	end
	
	
	//% Propagate pipeline
	always @(posedge CLK) begin : PIPE_BODY
		for (pipe_iter=1;pipe_iter<LATENCY+1;pipe_iter=pipe_iter+1) begin
			if (CE) pipeline[pipe_iter] <= pipeline[pipe_iter-1];
		end
	end

	////////////////////////////////////////////////////   
	//
	// ASSIGN STATEMENTS
	//
	////////////////////////////////////////////////////
	
	assign O = pipeline[LATENCY];
endmodule
