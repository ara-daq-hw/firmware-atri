`timescale 1ns / 1ps

//% @brief Synchronous rising edge detector with latency 1.
//%
//% Convenience module based on SYNCEDGE. Rising edge detector.
//% @gensymbol
//% MODULE SYNCEDGE_R
//% LPORT I input
//% LPORT CLK input
//% RPORT O output
//% @endgensymbol

module SYNCEDGE_R(
		  I,
		  O,
		  CLK
		  );
   input I;
   output O;
   input  CLK;

   SYNCEDGE #(.EDGE("RISING"),.POLARITY("POSITIVE"),.LATENCY(1),.CLKEDGE("RISING")) edge_detector(.I(I),.O(O),.CLK(CLK));

endmodule // SYNCEDGE_R