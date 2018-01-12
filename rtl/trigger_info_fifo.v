`timescale 1ns / 1ps

`include "trigger_defs.vh"
// Trigger info FIFO. One for each trigger. This is massive overkill but the BRAMs are cheaper
// than distributed RAM.
module trigger_info_fifo(
			clk_i,
			rst_i,
			info_i,
			wr_i,
			wr_ce_i,
			addr_i,
			info_o,
			rd_i			
    );

	localparam INFO_BITS = `INFO_BITS;
	localparam NUM_L4 = `SCAL_NUM_L4;
	`include "clogb2.vh"
	localparam NL4_BITS = clogb2(NUM_L4-1);
	input clk_i;
	input rst_i;
	input [INFO_BITS*NUM_L4-1:0] info_i;
	input wr_ce_i;
	input [NUM_L4-1:0] wr_i;
	input [NL4_BITS-1:0] addr_i;
	output [INFO_BITS-1:0] info_o;
	input rd_i;
	
	wire [INFO_BITS-1:0] info_in[NUM_L4-1:0];
	wire [INFO_BITS-1:0] info_out[NUM_L4-1:0];
	generate
		genvar ii;
		for (ii=0;ii<NUM_L4;ii=ii+1) begin : VEC
			assign info_in[ii] = info_i[INFO_BITS*ii +: INFO_BITS];
			wire rd_en = (rd_i && addr_i == ii);
			// These are 256 deep. This puts them as 9K BRAMs.
			trigger_info_buffer info_buf(.clk(clk_i),.srst(rst_i),.din(info_in[ii]),.wr_en(wr_i[ii] && wr_ce_i),
												  .dout(info_out[ii]),.rd_en(rd_en));
		end
	endgenerate
	
	reg [INFO_BITS-1:0] info_out_reg = {INFO_BITS{1'b0}};
	always @(posedge clk_i) begin
		info_out_reg <= info_out[addr_i];
	end
	assign info_o = info_out_reg;
endmodule
