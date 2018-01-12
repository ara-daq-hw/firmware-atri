`timescale 1ns / 1ps
/**
 * @file SYNCEDGE.v Contains parameterized synchronous edge detector SYNCEDGE.
 */

//% @brief Generic Pipeline Tools parameterized synchronous edge detector.
//%
//% @gensymbol
//% MODULE SYNCEDGE
//% PARAMETER EDGE "RISING"
//% PARAMETER CLKEDGE "RISING"
//% PARAMETER POLARITY "POSITIVE"
//% PARAMETER LATENCY 1
//% LPORT I input
//% LPORT CLK input
//% RPORT O output
//% RPORT PIPE[LATENCY:0] output
//% @endgensymbol
//%
//% SYNCEDGE is a generic multi-purpose synchronous edge detector. It is
//% parametrizable in terms of clock polarity (positive/negative edge), 
//% input polarity (rising or falling edge detection),
//% output polarity (positive or negative) and latency.
//% 
//% A synchronous edge detector looks for a '01' or '10' (rising/falling resp.)
//% pattern from a registered history of an incoming signal. The registers
//% used to store the history of the incoming signal are also available as
//% an output (PIPE). PIPE has width LATENCY+1.
//% 
//% Timing diagram with EDGE="RISING", CLKEDGE="RISING", POLARITY="POSITIVE",
//% and LATENCY=1.
//% 
//% @drawtiming
//% CLK=0,I=0,O=0,PIPE="00".
//% CLK=1;I=0.
//% CLK=0;I=1.
//% CLK=1;I=>PIPE="01".
//% CLK=0.
//% CLK=1;I=>PIPE="11";PIPE=>O=1.
//% CLK=0.
//% CLK=1.
//% @enddrawtiming
//% 
//% Note that the minimum latency is 0 - in this case, PIPE is a single-bit
//% registered version of the input signal, and O is just "I && !PIPE[0]".
//% (for EDGE="RISING" and POLARITY="POSITIVE").
//% 
//% Latency is typically helpful in reducing routing delays due to a signal
//% being heavily used. The latency convention here is identical to that in
//% the rest of the Generic Pipeline Tools: LATENCY specifies the number of clock
//% edges after the input is valid that must pass before the value can be
//% latched on the next clock edge.
//% 
//% In this case latency is also helpful for synchronizing into a new clock
//% domain. Note that LATENCY=1 implies that the timing of \ref O is defined
//% by the timing of \ref I. <b>If \ref I is asynchronous to \ref CLK, LATENCY=2
//% should be the absolute minimum used.</b> LATENCY=0 would result in \ref O
//% being asynchronous to \ref CLK (since \ref I is asynchronous to \ref CLK).
//% 
//% LATENCY=1 is insufficient for an asynchronous signal because the first
//% registered component (PIPE[0]) could be metastable, which would propagate
//% to the output since with LATENCY=1, the output is derived from PIPE[1] and
//% PIPE[0]. LATENCY=2 is a 2-register synchronizer with the output derived
//% from PIPE[2] and PIPE[1]. PIPE[1] also contains the synchronized version
//% of the input signal.
//% 
//% For a signal which is synchronous to CLK but not on its rising edge,
//% LATENCY=1 is most likely preferable to isolate the shortened setup time
//% to a single register (PIPE[0]) and to guarantee O is valid for a full clock
//% cycle. For instance, consider a case where the input signal is synchronous
//% to CLK on its falling edge, but the output is desired on the rising edge.
//% In that case, LATENCY=0 would result in a setup time of "CLK period/2" 
//% for both the pipe register (PIPE[0]) and <b>any</b> registered components
//% depending on \ref O. In addition, \ref O would only be true for 1/2 of
//% a clock cycle. With LATENCY=1, the setup time of "CLK period/2" 
//% applies only to PIPE[0], and \ref O would be true for the full CLK period.
//%
//% @tparam EDGE "RISING" or "FALLING". Specifies input polarity (rising/falling edge). Defaults to "RISING".
//% @tparam POLARITY "POSITIVE" or "NEGATIVE". Specifies output signal polarity. Defaults to "POSITIVE".
//% @tparam LATENCY Number of clock cycles from I changing state to O true. Defaults to 0.
//% @tparam CLKEDGE "RISING" or "FALLING". Specifies edge of clock to use. 
//% @param [in] I Input signal.
//% @param [out] O Output signal. Polarity depends on \ref POLARITY.
//% @param [in] CLK System clock. Edge used depends on CLKEDGE.
//% @param [out] PIPE[LATENCY:0]. Registered history of input signal.
//% 
module SYNCEDGE(
		I,
		O,
		CLK,
		PIPE
		);
   //% Number of clock edges required before output is true when condition met.
   parameter LATENCY = 1;
   //% Edge detector type - "RISING" or "FALLING".
   parameter EDGE = "RISING";
   //% Output signal "true" polarity - "POSITIVE" or "NEGATIVE"
   parameter POLARITY = "POSITIVE";
   //% Clock edge to use - "RISING" or "FALLING"
   parameter CLKEDGE = "RISING";

   localparam [1:0] match_value = {(EDGE == "FALLING"),(EDGE=="RISING")};
      
   //% Input signal.
   input I; 
   //% Flag when edge is detected.
   output O;
   //% System clock.
   input  CLK;
   //% Output registered history of input signal.
   output [LATENCY:0] PIPE;

   //% Input signal (I_pipe[0]) and registered history
	reg [LATENCY+1:0]    I_pipe;
   //% 1 of value has been matched, 0 if not
   wire 	      EDGE_DETECTED = (I_pipe[LATENCY+1:LATENCY] == match_value);   
      
   generate
      genvar i;      
		for (i=0;i<=LATENCY+1;i=i+1) begin : LOOP
			if (i==0) begin : HEAD
				initial I_pipe[i] <= I;
				if (CLKEDGE == "RISING") begin : CLKRISE
					always @(*) I_pipe[i] <= I;
				end else begin : CLKFALL
					always @(*) I_pipe[i] <= I;
				end
			end else begin : TAIL
				initial I_pipe[i] <= 0;
				if (CLKEDGE == "RISING") begin : CLKRISE
					always @(posedge CLK) I_pipe[i] <= I_pipe[i-1];
				end else begin : CLKFALL
					always @(negedge CLK) I_pipe[i] <= I_pipe[i-1];
				end
			end
		end
   endgenerate

   assign O = EDGE_DETECTED ? POLARITY=="POSITIVE" : POLARITY=="NEGATIVE";
 
endmodule // SYNCEDGE