`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// IRS v3 controller: Write Block Implementation
//
// This module controls the mapping of the 'logical' block (linear addressing,
// even blocks = cells 0-63, odd blocks = cells 64-127) to the 'physical' block
// (which needs to be recorded for readout) and the 'implemented' block address
// (the value to be put on the WR[8:0] outputs).
//
// mode_i selects either an IRS1/2 implementation (bit2=bit0, bit0=bit1, bit1=bit2)
// if low, and an IRS3 implementation (straight encoding) if high.
//
// This module goes between a block manager (which outputs logical blocks) and
// a write controller (which accepts implemented block addresses) and a history
// buffer (which accepts physical block addresses).
//
// Again:
//     logical block address: sequential addressing in time
//     physical block address: addressing in time determined by IRS
//     implemented block address: actual values to be put on WR[9:0].
//////////////////////////////////////////////////////////////////////////////////
module irs_block_write_map_v3(
    input [8:0] logical_i,
    input mode_i,
    output [8:0] physical_o,
	 output [8:0] impl_o
    );

	// Logical->physical mapping. Logical addressing goes
	// 0, 1, 2, 3, 4, 5, 6... etc. (in time)
	// Physical addressing for an IRS2 goes
	// 0, 4, 1, 5, 2, 6, 3... etc. (in time)
	assign physical_o[2:0] = (mode_i) ? logical_i[2:0] : {logical_i[0],logical_i[2],logical_i[1]};
	assign physical_o[8:3] = logical_i[8:3];
	
	// Physical->implemented mapping. In the DDA revD, WR[3:0] were reversed, so
	// for an IRS3, this maps them back.
	assign impl_o[3:0] = (mode_i) ? {physical_o[0],physical_o[1],physical_o[2],physical_o[3]} :
											  physical_o[3:0];
	assign impl_o[8:4] = physical_o[8:4];

endmodule
