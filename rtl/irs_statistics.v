`timescale 1ns / 1ps
`include "wb_interface.vh"
//////////////////////////////////////////////////////////////////////////////////
// Deadtime, occupancy, max occupancy statistics block. Space for one more,
// dunno what it would be used for. Maybe average block lock time.
//////////////////////////////////////////////////////////////////////////////////
module irs_statistics(
		inout [`WBIF_SIZE-1:0] interface_io,

		input [7:0] d1_deadtime,
		input [7:0] d1_occupancy,
		input [7:0] d1_max_occupancy,

		input [7:0] d2_deadtime,
		input [7:0] d2_occupancy,
		input [7:0] d2_max_occupancy,

		input [7:0] d3_deadtime,
		input [7:0] d3_occupancy,
		input [7:0] d3_max_occupancy,

		input [7:0] d4_deadtime,
		input [7:0] d4_occupancy,
		input [7:0] d4_max_occupancy
);

	parameter NUM_DAUGHTERS = 4;
	parameter MAX_DAUGHTERS = 4;

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
	
	wire [7:0] statistics_map[15:0];
	assign statistics_map[0] = d1_deadtime;
	assign statistics_map[1] = d2_deadtime;
	assign statistics_map[2] = d3_deadtime;
	assign statistics_map[3] = d4_deadtime;
	assign statistics_map[4] = d1_occupancy;
	assign statistics_map[5] = d2_occupancy;
	assign statistics_map[6] = d3_occupancy;
	assign statistics_map[7] = d4_occupancy;
	assign statistics_map[8] = d1_max_occupancy;
	assign statistics_map[9] = d2_max_occupancy;
	assign statistics_map[10] = d3_max_occupancy;
	assign statistics_map[11] = d4_max_occupancy;
	assign statistics_map[12] = {8{1'b0}};
	assign statistics_map[13] = {8{1'b0}};
	assign statistics_map[14] = {8{1'b0}};
	assign statistics_map[15] = {8{1'b0}};
	
	assign dat_o = statistics_map[adr_i[3:0]];
	assign ack_o = (cyc_i && stb_i);
	assign err_o = 0;
	assign rty_o = 0;
endmodule
