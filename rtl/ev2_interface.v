// Automatically generated by interface_generator.pl
// Interface name: ev2
// Interface definition: ev2_interface.def
// Generation date/time: Sun Aug 19, 2012 19:29:24

/*
 * Event interface, version 2.
 * 
 * This interface describes a FIFO connection from the IRS
 * to the PHY. The FIFO is 16-bits, and asynchronous (independent
 * clocks on both sides) and contains a data count to the IRS.
 * 
 * Unlike the previous versions, this version only connects the
 * IRS to the FIFO. It does not connect the readout logic
 * to the FIFO as well: the FIFO is presumed to be in the PHY
 * logic.
*/

`include "ev2_interface.vh"
// BEGIN ev2 ev2_fifo DATE Sun Aug 19, 2012 19:29:24
// 
// wire irsclk_i;
// wire [15:0] dat_i;
// wire [15:0] count_o;
// wire wr_i;
// wire full_o;
// wire rst_i;
// wire rst_ack_o;
// ev2_fifo ev2if(.interface_io(interface_io),
//                .irsclk_o(irsclk_i),
//                .dat_o(dat_i),
//                .count_i(count_o),
//                .wr_o(wr_i),
//                .full_i(full_o),
//                .rst_o(rst_i),
//                .rst_ack_i(rst_ack_o));
//
// END ev2 ev2_fifo DATE Sun Aug 19, 2012 19:29:24

module ev2_fifo(
		inout [`EV2IF_SIZE-1:0] interface_io,
		output  irsclk_o,
		output  [15:0]  dat_o,
		input  [15:0]  count_i,
		output  wr_o,
		input  full_i,
		output  rst_o,
		input  rst_ack_i
		);

	assign irsclk_o = interface_io[0];
	assign dat_o = interface_io[16:1];
	assign interface_io[32:17] = count_i;
	assign wr_o = interface_io[33];
	assign interface_io[34] = full_i;
	assign rst_o = interface_io[35];
	assign interface_io[36] = rst_ack_i;

endmodule


//% Reassigns a ev2 interface from a ev2_fifo on A_i
module ev2_fifo_reassign( A_i, B_o );
	inout [`EV2IF_SIZE-1:0] A_i;
	inout [`EV2IF_SIZE-1:0] B_o;

	assign A_i[0] = B_o[0];
	assign A_i[16:1] = B_o[16:1];
	assign B_o[32:17] = A_i[32:17];
	assign A_i[33] = B_o[33];
	assign B_o[34] = A_i[34];
	assign A_i[35] = B_o[35];
	assign B_o[36] = A_i[36];
endmodule

// BEGIN ev2 ev2_irs DATE Sun Aug 19, 2012 19:29:24
// 
// wire irsclk_o;
// wire [15:0] dat_o;
// wire [15:0] count_i;
// wire wr_o;
// wire full_i;
// wire rst_o;
// wire rst_ack_i;
// ev2_irs ev2if(.interface_io(interface_io),
//               .irsclk_i(irsclk_o),
//               .dat_i(dat_o),
//               .count_o(count_i),
//               .wr_i(wr_o),
//               .full_o(full_i),
//               .rst_i(rst_o),
//               .rst_ack_o(rst_ack_i));
//
// END ev2 ev2_irs DATE Sun Aug 19, 2012 19:29:24

module ev2_irs(
		inout [`EV2IF_SIZE-1:0] interface_io,
		input  irsclk_i,
		input  [15:0]  dat_i,
		output  [15:0]  count_o,
		input  wr_i,
		output  full_o,
		input  rst_i,
		output  rst_ack_o
		);

	assign interface_io[0] = irsclk_i;
	assign interface_io[16:1] = dat_i;
	assign count_o = interface_io[32:17];
	assign interface_io[33] = wr_i;
	assign full_o = interface_io[34];
	assign interface_io[35] = rst_i;
	assign rst_ack_o = interface_io[36];

endmodule


//% Reassigns a ev2 interface from a ev2_irs on A_i
module ev2_irs_reassign( A_i, B_o );
	inout [`EV2IF_SIZE-1:0] A_i;
	inout [`EV2IF_SIZE-1:0] B_o;

	assign B_o[0] = A_i[0];
	assign B_o[16:1] = A_i[16:1];
	assign A_i[32:17] = B_o[32:17];
	assign B_o[33] = A_i[33];
	assign A_i[34] = B_o[34];
	assign B_o[35] = A_i[35];
	assign A_i[36] = B_o[36];
endmodule

// BEGIN ev2 ev2_debug DATE Sun Aug 19, 2012 19:29:24
// 
// wire irsclk_i;
// wire [15:0] dat_i;
// wire [15:0] count_i;
// wire wr_i;
// wire full_i;
// wire rst_i;
// wire rst_ack_i;
// ev2_debug ev2if(.interface_io(interface_io),
//                 .irsclk_o(irsclk_i),
//                 .dat_o(dat_i),
//                 .count_o(count_i),
//                 .wr_o(wr_i),
//                 .full_o(full_i),
//                 .rst_o(rst_i),
//                 .rst_ack_o(rst_ack_i));
//
// END ev2 ev2_debug DATE Sun Aug 19, 2012 19:29:24

module ev2_debug(
		inout [`EV2IF_SIZE-1:0] interface_io,
		output  irsclk_o,
		output  [15:0]  dat_o,
		output  [15:0]  count_o,
		output  wr_o,
		output  full_o,
		output  rst_o,
		output  rst_ack_o
		);

	assign irsclk_o = interface_io[0];
	assign dat_o = interface_io[16:1];
	assign count_o = interface_io[32:17];
	assign wr_o = interface_io[33];
	assign full_o = interface_io[34];
	assign rst_o = interface_io[35];
	assign rst_ack_o = interface_io[36];

endmodule


