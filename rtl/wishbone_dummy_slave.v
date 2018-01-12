`timescale 1ns / 1ps
// Just acks all reads/writes to it and puts 0xFF on the bus.
`include "wb_interface.vh"
module wishbone_dummy_slave(
		inout [`WBIF_SIZE-1:0] interface_io
    );

	// INTERFACE_INS wb wb_slave
	wire clk_i;
	wire rst_i;
	wire cyc_i;
	wire wr_i;
	wire stb_i;
	wire ack_o;
	wire err_o;
	wire rty_o;
	wire [15:0] adr_i;
	wire [7:0] dat_i;
	wire [7:0] dat_o;
	wb_slave wbif(.interface_io(interface_io),
	              .clk_o(clk_i),
	              .rst_o(rst_i),
	              .cyc_o(cyc_i),
	              .wr_o(wr_i),
	              .stb_o(stb_i),
	              .ack_i(ack_o),
	              .err_i(err_o),
	              .rty_i(rty_o),
	              .adr_o(adr_i),
	              .dat_o(dat_i),
	              .dat_i(dat_o));
	// INTERFACE_END
	
	assign dat_o = 8'hFF;
	assign ack_o = cyc_i && stb_i;
	assign err_o = 0;
	assign rty_o = 0;
	
endmodule
