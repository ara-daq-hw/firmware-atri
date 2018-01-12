`timescale 1ns / 1ps
//% @brief Transfers a fixed number of words from the IRS readout buffers to the event FIFO.
//% 
//% The DMA engine ends up being extremely simple. We just write the number of words that we're
//% going to read out into it, and it just burns through them, only counting down whenever it
//% sees 'valid'.
//% We don't even use the empty signal - it doesn't matter. Valid is good enough. It's basically
//% just a streaming FIFO.
module irs_dma_controller(
		clk_i,
		rst_i,
		addr_i,
		dat_o,
		dat_i,
		wr_i,
		
		event_dat_o,
		event_wr_o,
		active_o,
		
		irs_dat_i,
		irs_addr_o,
		irs_valid_i,
		irs_empty_i,
		irs_read_o,
		debug_o
    );

	parameter MAX_DAUGHTERS = 4;
	parameter NUM_DAUGHTERS = 4;
	`include "clogb2.vh"
	parameter NMXD_BITS = clogb2(MAX_DAUGHTERS-1);

	input clk_i;
	input rst_i;
	input [2:0] addr_i;
	output [7:0] dat_o;
	input [7:0] dat_i;
	input wr_i;
	
	output [15:0] event_dat_o;
	output event_wr_o;
	output active_o;
	
	input [15:0] irs_dat_i;
	output [NMXD_BITS-1:0] irs_addr_o;
	input irs_valid_i;
	input irs_empty_i;
	output irs_read_o;

	output [31:0] debug_o;

	reg dma_active = 0;
	reg dma_irs_change = 0;

	reg [NMXD_BITS-1:0] irs_addr = {NMXD_BITS{1'b0}};
	
	wire [7:0] dmacsr = {{7{1'b0}}, dma_active};

	wire [9:0] dma_count_full[MAX_DAUGHTERS-1:0];
	//% Maximum number of words is 513 (512+header). So we need 10 bits.
	reg [9:0] dma_count[MAX_DAUGHTERS-1:0];
	generate
		genvar di;
		for (di=0;di<MAX_DAUGHTERS;di=di+1) begin : DL
			if (di < NUM_DAUGHTERS) begin : COUNT
				assign dma_count_full[di] = dma_count[di];
				initial dma_count[di] <= {10{1'b0}};
				always @(posedge clk_i) begin : DMA_COUNT_LOGIC
					if (!addr_i[2] && addr_i[1:0] == di && wr_i)
						// Upshift by 6 (multiply by 64). We actually read one past this number.
						dma_count[di] <= {dat_i[3:0],{6{1'b0}}};
					else if (irs_addr_o[1:0] == di && irs_valid_i && dma_active && !dma_irs_change)
						dma_count[di] <= dma_count[di] - 1;
				end
			end else begin : DUM
				assign dma_count_full[di] = {10{1'b0}};
			end
		end
	endgenerate

	always @(posedge clk_i) begin
		if (addr_i[2] && wr_i && dat_i[0])
			dma_active <= 1;
		else if ((irs_addr == NUM_DAUGHTERS-1 && (dma_count_full[irs_addr] == {10{1'b0}}) && irs_valid_i) || rst_i)
			dma_active <= 0;
	end

	// sigh. The reason why dma_irs_done goes high here is because irs_valid, and the data,
	// is delayed by a clock. 

	wire dma_irs_done = (dma_count[irs_addr] == {10{1'b0}} && irs_valid_i);

	// DMA count actually drops to 1FF for all of these guys counting through.
	always @(posedge clk_i) begin
		if (addr_i[2] && wr_i && dat_i[0])
			irs_addr <= {NMXD_BITS{1'b0}};
		else if (dma_irs_done && !dma_irs_change)
			irs_addr <= irs_addr + 1;
	end
	
	// dma_irs_change lets the pipeline transfer us to the new IRS's data/valid/emptys.
	always @(posedge clk_i) begin
		if (dma_irs_done && !dma_irs_change)
			dma_irs_change <= 1;
		else
			dma_irs_change <= 0;
	end

	// We have to pipeline the event write by one, because the
	// data is also pipelined by externally.
	reg event_wr = 0;
	always @(posedge clk_i) begin
		event_wr <= dma_active && irs_valid_i && !dma_irs_change;
	end
	
	// We also have to pipeline dma_active by one.
	reg active = 0;
	always @(posedge clk_i) begin
		active <= dma_active;
	end

	assign event_wr_o = event_wr;
	assign event_dat_o = irs_dat_i;
	assign active_o = active;
	// We don't want to read past the last entry. When dma_irs_done is
	// valid, the last sample is on the bus. 
	assign irs_read_o = dma_active && !dma_irs_change && !dma_irs_done;
	assign irs_addr_o = irs_addr;
	assign dat_o = dmacsr;

	assign debug_o[9:0] = dma_count[irs_addr];
	assign debug_o[11:10] = irs_addr;
	assign debug_o[12] = dma_irs_change;
	assign debug_o[13] = irs_read_o;
	assign debug_o[14] = event_wr;
	assign debug_o[15] = irs_empty_i;
	assign debug_o[16 +: 16] = event_dat_o;
endmodule
