`timescale 1ns / 1ps
//% @file wishbone_power_block.v Contains wishbone_power_block.

`include "wb_interface.vh"

//% @brief Simple 8-bit register for holding power and drive control for 4 daughterboards (2 reserved).
module wishbone_power_block(
		interface_io,
		dda_power, dda_drive,
		tda_power, tda_drive,
		drsv9_power, drsv9_drive,
		drsv10_power, drsv10_drive
    );
	 
	parameter NUM_DAUGHTERS = 4;

	inout [`WBIF_SIZE-1:0] interface_io;
	output [NUM_DAUGHTERS-1:0] dda_power;
	output [NUM_DAUGHTERS-1:0] dda_drive;
	output [NUM_DAUGHTERS-1:0] tda_power;
	output [NUM_DAUGHTERS-1:0] tda_drive;
	output [NUM_DAUGHTERS-1:0] drsv9_power;
	output [NUM_DAUGHTERS-1:0] drsv9_drive;
	output [NUM_DAUGHTERS-1:0] drsv10_power;
	output [NUM_DAUGHTERS-1:0] drsv10_drive;

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
	
	reg [7:0] power_register[NUM_DAUGHTERS-1:0];
	integer init;
	initial begin
		for (init=0;init<NUM_DAUGHTERS;init=init+1)
			power_register[init] <= {8{1'b0}};
	end
	generate
		genvar map_i;
		for (map_i=0;map_i<NUM_DAUGHTERS;map_i=map_i+1) begin : MAP
			assign dda_power[map_i] = power_register[map_i][0];
			assign tda_power[map_i] = power_register[map_i][1];
			assign drsv9_power[map_i] = power_register[map_i][2];
			assign drsv10_power[map_i] = power_register[map_i][3];
			assign dda_drive[map_i] = power_register[map_i][4];
			assign tda_drive[map_i] = power_register[map_i][5];
			assign drsv9_drive[map_i] = power_register[map_i][6];
			assign drsv10_drive[map_i] = power_register[map_i][7];
			always @(posedge clk_i) begin : REG
				if (cyc_i && stb_i && wr_i && adr_i[1:0] == map_i)
					power_register[map_i] <= dat_i;
			end
		end
	endgenerate
	
	assign dat_o = power_register[adr_i[1:0]];
	assign ack_o = cyc_i && stb_i;
	assign err_o = 0;
	assign rty_o = 0;
endmodule
