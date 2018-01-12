`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// miniATRI: single-daughter ATRI version
//
// Note: the D1CRSV[2:1] inputs and D1CRSV[0] are fake. They go to no-connects (mostly,
// one differential input goes to an address line on memory).
//////////////////////////////////////////////////////////////////////////////////
module miniATRI(
		output [9:0] D1WR,
		output D1WRSTRB,
		inout [9:0] D1RD,
		output D1RDEN,
		output [5:0] D1SMP,
		output D1SMPALL,
		output [2:0] D1CH,
		input [11:0] D1DAT,
		output D1TSA,
		input D1TSAOUT,
		output D1TSA_CLOSE,
		output D1RAMP,
		output D1START,
		output D1CLR,
		input D1TSTOUT,
		input [7:0] D1TRG_P,
		input [7:0] D1TRG_N,
		inout D1DDASENSE,	
		inout D1TDASENSE,
		inout D1SDA,
		inout D1SCL,
		inout [10:9] D1DRSV,
		inout [0:0] D1ARSV,
		output CRSV0_P,
		output CRSV0_N,

		input FPGA_REFCLK_P,
		input FPGA_REFCLK_N,

		inout [15:0] FD,
		input FLAGA,
		input FLAGB,
		input FLAGC,
		input FLAGD,
		output SLOE,
		output SLRD,
		output SLWR,
		output [1:0] FIFOADR,
		output PKTEND,

		inout [2:0] GPIO,
		input IFCLK,
		
		input PPS_IN,
		input FPTRIG_IN		
    );

	parameter DEBUG = "IRSRAW";
	parameter SENSE = "SLOW";
	parameter [31:0] BOARD_ID = "MATR";

	ATRI_revB #(.BOARD_ID(BOARD_ID),.SENSE(SENSE),.DEBUG(DEBUG),.NUM_DAUGHTERS(1),.PCIE("NO"),
				   .CRSV0_TYPE("SINGLE_ENDED"),.EVENT_FIFO("MEDIUM"),.BRSV_TRISTATE("NO"),.IMPLEMENT_RESERVED("NO"))
		atri(.D1WR(D1WR),.D1WRSTRB(D1WRSTRB),
			  .D1RD(D1RD),.D1RDEN(D1RDEN),
			  .D1DAT(D1DAT),
			  .D1CH(D1CH),.D1SMP(D1SMP),.D1SMPALL(D1SMPALL),
			  .D1START(D1START),.D1CLR(D1CLR),.D1RAMP(D1RAMP),
			  .D1TSA(D1TSA),.D1TSAOUT(D1TSAOUT),.D1TSA_CLOSE(D1TSA_CLOSE),.D1TSTOUT(D1TSTOUT),
			  .D1TRG_P(D1TRG_P),.D1TRG_N(D1TRG_N),
			  .D1DDASENSE(D1DDASENSE),.D1TDASENSE(D1TDASENSE),.D1SDA(D1SDA),.D1SCL(D1SCL),
			  .D1DRSV(D1DRSV),.D1ARSV(D1ARSV),
			  .D1CRSV_P(D1CRSV_P),.CRSV0_P(CRSV0_P),
			  .D1CRSV_N(D1CRSV_N),.CRSV0_N(CRSV0_N),
			  .FPGA_REFCLK_P(FPGA_REFCLK_P),.FPGA_REFCLK_N(FPGA_REFCLK_N),
			  .FD(FD),.FLAGA(FLAGA),.FLAGB(FLAGB),.FLAGC(FLAGC),.FLAGD(FLAGD),
			  .SLOE(SLOE),.SLWR(SLWR),.SLRD(SLRD),.PKTEND(PKTEND),.FIFOADR(FIFOADR),
			  .GPIO(GPIO),.IFCLK(IFCLK),.PPS_IN(PPS_IN),.FPTRIG_IN(FPTRIG_IN));

endmodule
