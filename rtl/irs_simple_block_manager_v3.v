`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Simple block manager. This interfaces with the irs_write_controller_v3
// to provide a write solution for an IRS.
//
// Note that the IRS1&2/IRS3 mode swap happens upstream of this - This module
// assumes *linear block addressing* (i.e. address 1 follows address 0, address 0
// is phase 0, address 1 is phase 1). Stick
// a module between here and the write controller to remap this if needed.
//////////////////////////////////////////////////////////////////////////////////
module irs_simple_block_manager_v3(
		input clk_i,
		input rst_i,
		input en_i,
		input pause_i,
		
		input blk_phase_i,
		output blk_rst_o,
		output blk_en_o,
		output [8:0] blk_o,
		input blk_ack_i,
		
		input ped_mode_i,
		input [8:0] ped_address_i,
		input ped_sample_i
    );

	wire enable = en_i && !pause_i;

	reg [8:0] address = {9{1'b0}};
	reg blk_rst = 1;
	reg blk_en = 0;
	reg ped_mode = 0;
	reg ped_sample = 0;
	// Block increment.
	always @(posedge clk_i) begin
		if (rst_i) begin
			if (!ped_mode_i) address <= {9{1'b0}};
			else address <= ped_address_i;
		end else begin
			if (!ped_mode_i && enable) begin
				// Increment if the block phase matches the previous write.
				// This should never not be true, but whatever.
				if (blk_ack_i && (blk_phase_i == address[0]))
					address <= address + 1;
			end else begin
				address <= ped_address_i;
			end
		end
	end
	
	// Pedestal sampling.
	always @(posedge clk_i) begin
		if ((blk_ack_i && ped_mode) || rst_i) ped_sample <= 0;
		else if (ped_sample_i) ped_sample <= 1;
	end
	
	// We disable block writing when ped_mode_i first goes high, which guarantees
	// that when ped_mode becomes high (the next clock), we haven't written to a block.
	always @(posedge clk_i) begin
		if ((!enable || rst_i) || (ped_mode_i && !ped_mode)) blk_en <= 0;
		else begin
			if (ped_mode) begin
				// If we're in pedestal mode, if we're in the wrong phase,
				// we don't enable the block write.
				// enable_i needs to be high same time as the block to be presented, though,
				// so we look for the wrong phase.
				if (blk_phase_i == !address[0]) blk_en <= ped_sample;
				// So enable_i goes high for 1 cycle while blk_phase_i is wrong - that
				// cycle is when enable_i is latched, so it works.
				else blk_en <= 0;
			end else begin
				// Synchronize up with the block write. Enable once we match, then
				// stay enabled so long as actually are enabled.
				if (blk_phase_i == !address[0]) blk_en <= 1;
			end
		end
	end

	always @(posedge clk_i) begin		
		if (ped_mode_i && !rst_i) ped_mode <= ped_mode_i;
		else ped_mode <= 1'b0;
	end
	
	always @(posedge clk_i) begin
		blk_rst <= rst_i || !en_i || pause_i;
	end

	assign blk_en_o = blk_en;
	assign blk_o = address;
	assign blk_rst_o = blk_rst;
endmodule
