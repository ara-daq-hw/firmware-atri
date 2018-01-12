`timescale 1ns / 1ps

//% irs2 sample monitor, version 2.
//%
//% The IRS2 sample monitor determines the delay between TSA and TSAOUT
//% to monitor the overall sampling speed. Functionally this makes this
//% module a TDC.
//%
//% This is slightly complicated because TSA isn't actually a clock, it's
//% derived from a 100 MHz clock. So we shove the 100 MHz clock into a
//% divide-by-4 DCM, and then phase-shift that. 
//%
//% The complication is that we don't know the initial phase relationship 
//% between the divide-by-4 DCM and TSA. So what we do is an initial
//% search, latching *TSA*, to find the rising edge, and then switch over
//% to TSAOUT, and then report the difference between the TSA rising edge
//% phase and the TSAOUT rising edge phase.
module irs2_sample_mon_v2(
    );


endmodule
