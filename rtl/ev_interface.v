`timescale 1ns / 1ps

`include "ev_interface.vh"

// The event interface path goes from IRS -> FIFO -> readout

// Event interface now has a 16-bit data count.
// The FIFO isn't actually that wide, but who cares.

// wire fifo_clk_i;
// wire irs_clk_o;
// wire fifo_full_i;
// wire fifo_wr_i;
// wire [15:0] dat_o;
// wire [1:0] type_o;
// wire rst_req_o;
// wire rst_ack_i;
// event_interface_irs evif(.interface_io(interface_io),
//                          .irs_clk_i(irs_clk_o),
//                          .fifo_full_o(fifo_full_i),
//                          .fifo_wr_i(fifo_wr_o),
//                          .dat_i(dat_o),
//                          .type_i(type_o),
//                          .rst_req_i(rst_req_o),
//                          .rst_ack_i(rst_ack_o)
//                          );
module event_interface_irs(
		inout [`EVIF_SIZE-1:0] interface_io,
		output fifo_clk_o,
		input irs_clk_i,
		output fifo_full_o,
		input fifo_wr_i,
//		input read_done_i,
		input [15:0] dat_i,
		input [1:0] type_i,
		input rst_req_i,
		output rst_ack_o,
		input fifo_rst_i,
		// unused ports
		output [37:0] unused_o
    );

	assign fifo_clk_o = interface_io[0];
	assign interface_io[1] = irs_clk_i;
	assign fifo_full_o = interface_io[2];
	assign unused_o[0] = interface_io[3];
	assign interface_io[4] = fifo_wr_i;
	assign unused_o[1] = interface_io[5];
// this is now prog_empty
//	assign interface_io[6] = read_done_i;
	assign interface_io[22:7] = dat_i[15:0];
	assign unused_o[20:2] = interface_io[41:23];
	assign unused_o[21] = interface_io[6];
	assign interface_io[43:42] = type_i;
	assign unused_o[37:22] = interface_io[59:44];
   assign interface_io[60] = rst_req_i;
   assign rst_ack_o = interface_io[61];
	assign interface_io[62] = fifo_rst_i;
endmodule

// wire fifo_clk_o;
// wire irs_clk_i;
// wire fifo_full_o;
// wire fifo_empty_o;
// wire fifo_wr_i;
// wire fifo_rd_i;
// wire [15:0] dat_i;
// wire [15:0] dat_o;
// wire prog_full_o;
// wire [15:0] fifo_nwords_o;
// event_interface_fifo evif(.interface_io(interface_io),
//                           .fifo_clk_i(fifo_clk_o),.irs_clk_o(irs_clk_i),
//                           .fifo_empty_i(fifo_empty_o),.fifo_full_i(fifo_full_o),
//                           .fifo_wr_o(fifo_wr_i),.fifo_rd_o(fifo_rd_i),
//                           .fifo_nwords_i(fifo_nwords_o),
//                           .dat_o(dat_i),.dat_i(dat_o),
//                           .prog_full_i(prog_full_o));
module event_interface_fifo(
	inout [`EVIF_SIZE-1:0] interface_io,
	input fifo_clk_i,
	output irs_clk_o,
	input fifo_full_i,
	input fifo_empty_i,
	output fifo_wr_o,
	output fifo_rd_o,
	output [15:0] dat_o,
	output [1:0] type_o,
	input [15:0] dat_i,
	input [1:0] type_i,
	input prog_empty_i,
	input [15:0] fifo_nwords_i,
	output fifo_block_done_o,
	output fifo_rst_o,
	// unused ports
	output [1:0] unused_o
	);
	assign interface_io[0] = fifo_clk_i;
	assign irs_clk_o = interface_io[1];
	assign interface_io[2] = fifo_full_i;
	assign interface_io[3] = fifo_empty_i;
	assign fifo_wr_o = interface_io[4];
	assign fifo_rd_o = interface_io[5];
	assign interface_io[6] = prog_empty_i;
	assign dat_o = interface_io[22:7];
	assign interface_io[38:23] = dat_i;
	assign fifo_block_done_o = interface_io[39];
	assign type_o = interface_io[43:42];
	assign interface_io[41:40] = type_i;
	assign interface_io[59:44] = fifo_nwords_i;
   // rst_req and rst_ack
   assign unused_o[1:0] = interface_io[61:60];
	assign fifo_rst_o = interface_io[62];
endmodule

// wire fifo_clk_i;
// wire irs_clk_i;
// wire fifo_empty_i;
// wire prog_full_i;
// wire fifo_rd_o;
// wire [15:0] dat_i;
// wire fifo_block_done_o;
// wire rst_req_i;
// wire rst_ack_o;
// event_interface_rdout evif(.interface_io(interface_io),
//                           .fifo_clk_o(fifo_clk_i),.irs_clk_o(irs_clk_i),
//                           .fifo_empty_o(fifo_empty_i),.prog_full_o(prog_full_i),
//                           .fifo_rd_i(fifo_rd_o),
//                           .fifo_block_done_i(fifo_block_done_o),
//                           .dat_o(dat_i),
//                           .rst_req_o(rst_req_i),
//                           .rst_ack_i(rst_ack_o)
//                           );
module event_interface_rdout(
	inout [`EVIF_SIZE-1:0] interface_io,
	output fifo_clk_o,
	output irs_clk_o,
	output fifo_empty_o,
	input fifo_rd_i,
	output prog_empty_o,
	output [15:0] fifo_nwords_o,
	input fifo_block_done_i,
	output [15:0] dat_o,
	output [1:0] type_o,
	output rst_req_o,
	input rst_ack_i,
	// unused ports
	output [20:0] unused_o
	);
	assign fifo_clk_o = interface_io[0];
	assign irs_clk_o = interface_io[1];
	assign unused_o[0] = interface_io[2];
	assign fifo_empty_o = interface_io[3];
	assign unused_o[1] = interface_io[4];
	assign interface_io[5] = fifo_rd_i;
	assign prog_empty_o = interface_io[6];
	assign unused_o[17:2] = interface_io[22:7];
	assign dat_o = interface_io[38:23];
	assign interface_io[39] = fifo_block_done_i;
	assign type_o = interface_io[41:40];
	assign unused_o[19:18] = interface_io[43:42];
	assign fifo_nwords_o = interface_io[59:44];
   assign rst_req_o = interface_io[60];
   assign interface_io[61] = rst_ack_i;

	assign unused_o[20] = interface_io[62];
endmodule
//% reassigns event interface coming FROM an IRS (on A_i) (TO a FIFO on B_o)
module event_interface_irs_reassign( A_i, B_o );
	inout [`EVIF_SIZE-1:0] A_i;
	inout [`EVIF_SIZE-1:0] B_o;

	// bit 0: FIFO clock: to IRS
	assign A_i[0] = B_o[0];
	// bit 1: IRS clock: from IRS
	assign B_o[1] = A_i[1];
	// bit 2: FIFO full: to IRS
	assign A_i[2] = B_o[2];
	// bit 3: FIFO empty: to IRS (unused)
	assign A_i[3] = B_o[3];
	// bit 4: FIFO write: from IRS
	assign B_o[4] = A_i[4];
	// bit 5: FIFO read: to IRS (unused)
	assign A_i[5] = B_o[5];
	// bit 6: prog empty: to IRS (unused)
	assign A_i[6] = B_o[6];
	// bit 22:7 : data to FIFO : from IRS
	assign B_o[22:7] = A_i[22:7];
	// bit 38:23 : data from FIFO : to IRS (unused)
	assign A_i[38:23] = B_o[38:23];
	// bit 39 : data from readout : to IRS (unused
	assign A_i[39] = B_o[39];
	// bit 41:40 : data from FIFO : to IRS (unused)
	assign A_i[41:40] = B_o[41:40];
	// bit 43:42 : data to FIFO : from IRS
	assign B_o[43:42] = A_i[43:42];
	// bit 59:44 : data from FIFO : to IRS (unused)
	assign A_i[59:44] = B_o[59:44];
   // bit 60 : reset request from IRS : to readout
   assign B_o[60] = A_i[60];
   // bit 61 : reset ack to IRS : from readout
   assign A_i[61] = B_o[61];
	// bit 62 : fifo reset : from IRS to FIFO
	assign B_o[62] = A_i[62];
endmodule

//% reassigns event interface coming FROM a FIFO on A_i (TO a readout on B_o)
module event_interface_fifo_reassign( A_i, B_o );
	inout [`EVIF_SIZE-1:0] A_i;
	inout [`EVIF_SIZE-1:0] B_o;
	// bit 0: FIFO clock: from FIFO side
	assign B_o[0] = A_i[0];
	// bit 1: IRS clock: from FIFO side (from IRS)
	assign B_o[1] = A_i[1];
	// bit 2: FIFO full: from FIFO side
	assign B_o[2] = A_i[2];
	// bit 3: FIFO empty: from FIFO side
	assign B_o[3] = A_i[3];
	// bit 4: FIFO write: from FIFO side (from IRS)
	assign B_o[4] = A_i[4];
	// bit 5: FIFO read: to FIFO side
	assign A_i[5] = B_o[5];
	// bit 6: prog empty: from FIFO side
	assign B_o[6] = A_i[6];
	// bit 22:7 : data to FIFO : from FIFO side (from IRS)
	assign B_o[22:7] = A_i[22:7];
	// bit 38:23 : data from FIFO : from FIFO side
	assign B_o[38:23] = A_i[38:23];
	// bit 39 : block done to FIFO
	assign A_i[39] = B_o[39];
	// bit 40:41 : data from FIFO : to readout
	assign B_o[41:40] = A_i[41:40];
	// bit 43:42 : data to FIFO : from FIFO side (from IRS)
	assign B_o[43:42] = A_i[43:42];
	// bit 59:44 : data from FIFO : to readout
	assign B_o[59:44] = A_i[59:44];
   // bit 60 : reset request to readout : from FIFO side (from IRS)
   assign B_o[60] = A_i[60];
   // bit 61 : reset ack to IRS : from readout
   assign A_i[61] = B_o[61];
	// bit 62 : FIFO reset : from FIFO : to readout (unused)
	assign B_o[62] = A_i[62];
endmodule
