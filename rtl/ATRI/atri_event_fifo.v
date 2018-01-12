`timescale 1ns / 1ps
`include "ev_interface.vh"
// Event FIFO for the ATRI. This is in the PHY so the event buffering can be larger on the ATRI.
module atri_event_fifo(
		input clk_i,
		inout [`EVIF_SIZE-1:0] interface_io
    );

	wire fifo_clk_o = clk_i;
	wire irs_clk_i;
	wire fifo_full_o;
	wire fifo_empty_o;
	wire fifo_wr_i;
	wire fifo_rd_i;
	wire [15:0] dat_i;
	wire [15:0] dat_o;
	wire [1:0] type_i;
	wire [1:0] type_o;
	wire prog_empty_o = 0;
	wire [13:0] read_data_count;
	wire [15:0] fifo_nwords_o = {{2{1'b0}},read_data_count};
	wire fifo_rst_i;
	event_interface_fifo evif(.interface_io(interface_io),
									.fifo_clk_i(fifo_clk_o),.irs_clk_o(irs_clk_i),
									.fifo_empty_i(fifo_empty_o),.fifo_full_i(fifo_full_o),
									.fifo_wr_o(fifo_wr_i),.fifo_rd_o(fifo_rd_i),
									.dat_o(dat_i),.dat_i(dat_o),
									.type_o(type_i),.type_i(type_o),
									.prog_empty_i(prog_empty_o),
									.fifo_nwords_i(fifo_nwords_o),
									.fifo_rst_o(fifo_rst_i));
	atri_event_fifo_core fifo(.wr_clk(irs_clk_i),.rd_clk(fifo_clk_o),.wr_en(fifo_wr_i),
									  .rd_en(fifo_rd_i),.din({type_i,dat_i}),.dout({type_o,dat_o}),.full(fifo_full_o),
									  .empty(fifo_empty_o),
									  .rst(fifo_rst_i),
									  .rd_data_count(read_data_count));

endmodule
