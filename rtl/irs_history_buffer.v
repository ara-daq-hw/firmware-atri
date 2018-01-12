`timescale 1ns / 1ps
module irs_history_buffer(
		input clk_i,
		input rst_i,
		input [9:0] write_block_i,
		input write_strobe_i,
		input block_req_i,
		input [8:0] nprev_i,
		output [9:0] block_o,
		output block_ack_o
    );

	// Simple circular buffer containing blocks that were written to by the irs2_block_manager.

	// I'd like to make it such that when a block is requested by nprev_i here, it sets a
	// high bit on that block in the circular buffer. Then if it's requested again, it gets
	// an indicator that it's already queued for read out. That's the easiest way to do it.
	
	reg [8:0] hb_wr_pointer = {9{1'b0}};
	reg [8:0] hb_rd_pointer = {9{1'b0}};
	
	reg [1:0] ack = 2'b00;
	
	always @(posedge clk_i) begin
		if (write_strobe_i && block_req_i) begin
			hb_rd_pointer <= hb_wr_pointer - nprev_i;
		end
	end
	always @(posedge clk_i) begin
		if (rst_i)
			hb_wr_pointer <= {9{1'b0}};
		else if (write_strobe_i)
			hb_wr_pointer <= hb_wr_pointer + 1;
	end
	
	always @(posedge clk_i) begin
		ack <= {ack[0],write_strobe_i && block_req_i};
	end
	
	assign block_ack_o = ack[1];
	
	wire [9:0] cb_addrA = {1'b0, hb_wr_pointer};
	wire [9:0] cb_addrB = {1'b0, hb_rd_pointer};
	wire [15:0] cb_dinA = {{6{1'b0}},write_block_i};
	wire [15:0] cb_doutB;
	assign block_o = cb_doutB[9:0];
	
	RAMB16_S18_S18 hb(.CLKA(clk_i),.ADDRA(cb_addrA),.ENA(write_strobe_i),.WEA(1'b1),.DIA(cb_dinA),.DIPA(2'b00),.SSRA(1'b0),
							.CLKB(clk_i),.ADDRB(cb_addrB),.ENB(ack[0]),.WEB(1'b0),.DIB({16{1'b0}}),.DIPB(2'b00),.SSRB(1'b0),
							.DOB(cb_doutB));

endmodule
