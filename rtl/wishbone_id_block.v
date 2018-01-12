`timescale 1ns / 1ps
`include "wb_interface.vh"
// WISHBONE ID block
// Needs at least 8 addresses: 0x00-0x07 
// We also monitor the WRCLK DCM right now.
module wishbone_id_block(
		inout [`WBIF_SIZE-1:0] interface_io,
		input dcm_locked_i,
		input [2:0] dcm_status_i,
		output dcm_reset_o
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

		reg [7:0] data_to_master = {8{1'b0}};
		parameter [31:0] ID = "WBID";
		parameter [3:0] VER_BOARD = 0;
		parameter [3:0] VER_MAJOR = 0;
		parameter [3:0] VER_MINOR = 0;
		parameter [7:0] VER_REV = 0;
		parameter [3:0] VER_MONTH = 0;
		parameter [7:0] VER_DAY = 0;
		localparam [31:0] VERSION_ENCODED = 
					{VER_BOARD,VER_MONTH,VER_DAY,VER_MAJOR,VER_MINOR,VER_REV};
		// Little-endian addressing.
		// (31:24)(23:16)(15:8)(7:0)
		//    3      2     1     0
		always @(*) begin
			case (adr_i[3:0])
				0,1,2,3: data_to_master <= ID[8*adr_i[1:0] +: 8];
				4,5,6,7: data_to_master <= VERSION_ENCODED[8*adr_i[1:0] +: 8];
				8,9,10,11,12,13,14,15: data_to_master <= {4'b0000,dcm_status_i,dcm_locked_i};
			endcase
		end
		reg dcm_reset = 0;
		reg do_dcm_reset = 0;
		reg [7:0] dcm_reset_counter = {8{1'b0}};
		always @(posedge clk_i) begin
			if (cyc_i && stb_i && wr_i && adr_i[3])
				do_dcm_reset <= dat_i[7];
			else if (dcm_reset)
				do_dcm_reset <= 0;
		end
		always @(posedge clk_i) begin
			if (dcm_reset)
				dcm_reset_counter <= dcm_reset_counter + 1;
			else
				dcm_reset_counter <= {8{1'b0}};
		end
		always @(posedge clk_i) begin
			if (do_dcm_reset)
				dcm_reset <= 1;
			else if (dcm_reset_counter == 100)
				dcm_reset <= 0;
		end
		assign dat_o = data_to_master;
		assign ack_o = cyc_i && stb_i;
		assign err_o = 0;
		assign rty_o = 0;
		assign dcm_reset_o = dcm_reset;
endmodule
