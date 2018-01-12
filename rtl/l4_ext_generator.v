`timescale 1ns / 1ps

`include "trigger_defs.vh"

//% @brief Generates an L4 maskable trigger and scaler of variable block length upon reception of a flag.
module l4_ext_generator(
		l4_i,
		mask_i,
		blocks_i,
		l4_o,
		l4_new_o,
		l4_scaler_o,
		clk_i,
		rst_i
    );

	//% Number of bits in the blocks_i field.
	localparam NBLOCK_BITS = `NBLOCK_BITS;

	//% Flag to start L4 trigger.
	input l4_i;
	//% Mask of L4 trigger. This prevents an L4 trigger, but the scaler will still occur.
	input mask_i;
	//% Number of blocks to read out. The trigger mask should be applied before this is changed.
	input [NBLOCK_BITS-1:0] blocks_i;
	//% L4 output.
	output l4_o;
	//% L4 new info output
	output l4_new_o;
	//% Scaler output (always active, regardless of mask).
	output l4_scaler_o;
	//% System clock (100 MHz).
	input clk_i;
	//% Trigger subsystem reset.
	input rst_i;
	
	//% Number of blocks to read out, in our domain.
	reg [NBLOCK_BITS-1:0] nblocks = {NBLOCK_BITS{1'b0}};
	//% Number of blocks counted in the current L4 trigger.
	reg [NBLOCK_BITS:0] block_counter = {NBLOCK_BITS+1{1'b0}};
	//% L4 hold register.
	reg l4_hold = 0;
	//% Maskable L4 register.
	reg l4_reg = 0;
	
	//% Copy number of blocks into our domain.
	always @(posedge clk_i) begin : NBLOCKS_LOGIC
		nblocks <= blocks_i;
	end
	
	//% Masking logic.
	always @(posedge clk_i or posedge rst_i) begin : MASK_LOGIC
		if (rst_i) l4_reg <= 0;
		else begin
			if (mask_i) l4_reg <= 0;
			else l4_reg <= l4_i;
		end
	end
	//% Prolonged output logic.
	always @(posedge clk_i or posedge rst_i) begin : HOLD_LOGIC
		if (rst_i) l4_hold <= 0;
		else begin
			if (l4_reg) l4_hold <= 1;
			else if (block_counter[8:1] >= nblocks) l4_hold <= 0;
		end
	end
	//% Block counter logic.
	always @(posedge clk_i or posedge rst_i) begin : COUNTER_LOGIC
		if (rst_i) block_counter <= {9{1'b0}};
		else begin
			if (l4_reg) block_counter <= {9{1'b0}};
			else if (l4_hold) block_counter <= block_counter + 1;
		end
	end
	
	//% l4_new_o needs to be 2 clocks long. So we extend it by 1 here.
	reg l4_new_extend = 0;
	always @(posedge clk_i) l4_new_extend <= l4_reg;
	
	assign l4_o = (l4_reg || l4_hold);
	assign l4_new_o = (l4_reg || l4_new_extend);
	assign l4_scaler_o = l4_i;
	
endmodule
