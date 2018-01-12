`timescale 1ns / 1ps
//% @file rf_trigger_top_v2.v Contains rf_trigger_top, version 2, any 3 of 8.

`include "trigger_defs.vh"

//% @brief Top-level module for the RF trigger. V2 (trigger_top version)
module rf_trigger_top_v2(
		l1_trig_p_i,
		l1_trig_n_i,
		l1_scal_i,

		l2_mask_i,
		l3_mask_i,
		l4_mask_i,
		
		l2_scaler_o,
		l3_scaler_o,
		l4_scaler_o,
		
		clk_i,
		rst_i,
		rf0_blocks_i,
		rf1_blocks_i,
		rf1_coincidence_i,
		
		trig_rf0_info_o,
		trig_rf1_info_o,
		
		l4_trig_o,
		l4_new_o,
		debug_o
    );

	////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

	localparam NUM_L1 = `SCAL_NUM_L1;
	localparam NUM_L2 = `SCAL_NUM_L2;
	localparam NUM_L3 = `SCAL_NUM_L3;
	localparam NUM_L4 = `SCAL_NUM_RF_L4;
	
	parameter INFO_BITS = 32;
	// NUM_DAUGHTERS is actually only used to determine if we remap triggers.
	parameter NUM_DAUGHTERS = 4;
	input [NUM_L1-1:0] l1_trig_p_i;
	input [NUM_L1-1:0] l1_trig_n_i;
	input [NUM_L1-1:0] l1_scal_i;
	input [NUM_L2-1:0] l2_mask_i;
	input [NUM_L3-1:0] l3_mask_i;
	input [NUM_L4-1:0] l4_mask_i;
	
	output [NUM_L2-1:0] l2_scaler_o;
	output [NUM_L3-1:0] l3_scaler_o;
	output [NUM_L4-1:0] l4_scaler_o;
	
	input clk_i;
	input rst_i;
	input [7:0] rf0_blocks_i;
	input [7:0] rf1_blocks_i;
	
	input [1:0] rf1_coincidence_i;
	
	output [INFO_BITS-1:0] trig_rf0_info_o;
	output [INFO_BITS-1:0] trig_rf1_info_o;
	
	output [NUM_L4-1:0] l4_trig_o;
	output [NUM_L4-1:0] l4_new_o;
	output [7:0] debug_o;

	wire [15:0] l1_delayed;
	wire [3:0] surf_l1_delayed;

	reg [INFO_BITS-1:0] trig_rf0_info = {INFO_BITS{1'b0}};
	reg [INFO_BITS-1:0] trig_rf1_info = {INFO_BITS{1'b0}};
	////////////////
	// IN-ICE TRIGGER
	////////////////
	
	//
	// This trigger has the same basic result as the previous design:
	// (self_trigger_top)
	// Any 3 out of 8 for D1&D2, D3&D4.
	// However it maps them differently:
	// L2, D1: L2[0] = any 1 of 4, L2[1] = any 2 of 4, L2[2] any 3 of 4
	//     D2: L2[4] = any 1 of 4, L2[5] = any 2 of 4, L2[6] any 3 of 4
	//     D3: L2[8] = any 1 of 4, L2[9] = any 2 of 4, L2[10] any 3 of 4
	//     D4: L2[12] = any 1 of 4, L2[13] = any 2 of 4, L2[14] any 3 of 4
	// Then the L3 trigger is just
	// (L2[0] & L2[5]) | (L2[1] & L2[4]) | L2[2] | L2[6] |
	// (plus add 8 to all of them)
	// The final logic works out to be exactly the same.
	// 
	// It also calculates it in a few clock cycles just to get used to a
	// multicycle trigger. 

	// BASE DELAY = 3-4 CYCLES (1.5-2 BLOCKS)

	wire [NUM_L2-1:0] l2;
	wire [NUM_L3-1:0] l3;

	wire [2:0] debug;
	
	// L2s. Note that L2[3], L2[7], L2[11], and L2[15] are all unconnected.
	// 0.3 forward: here we regroup the triggers to mix and match Vs and Hs.
	wire [3:0] L2_0_3_inputs;
	wire [3:0] L2_4_7_inputs;
	wire [3:0] L2_8_11_inputs;
	wire [3:0] L2_12_15_inputs;
	
	// DDA 1 ch1&2, DDA 2 ch1&2
	generate
		if (NUM_DAUGHTERS > 1) begin : REMAP
			assign L2_0_3_inputs[0] = l1_trig_p_i[0];
			assign L2_0_3_inputs[1] = l1_trig_p_i[1];
			assign L2_0_3_inputs[2] = l1_trig_p_i[4];
			assign L2_0_3_inputs[3] = l1_trig_p_i[5];
			
			// DDA 3 ch1&2, DDA4 ch1&2
			assign L2_4_7_inputs[0] = l1_trig_p_i[8];
			assign L2_4_7_inputs[1] = l1_trig_p_i[9];
			assign L2_4_7_inputs[2] = l1_trig_p_i[12];
			assign L2_4_7_inputs[3] = l1_trig_p_i[13];
			
			// DDA 1 ch3&4, DDA2 ch3&4
			assign L2_8_11_inputs[0] = l1_trig_p_i[2];
			assign L2_8_11_inputs[1] = l1_trig_p_i[3];
			assign L2_8_11_inputs[2] = l1_trig_p_i[6];
			assign L2_8_11_inputs[3] = l1_trig_p_i[7];

			// DDA 3 ch3&4, DDA4 ch3&4
			assign L2_12_15_inputs[0] = l1_trig_p_i[10];
			assign L2_12_15_inputs[1] = l1_trig_p_i[11];
			assign L2_12_15_inputs[2] = l1_trig_p_i[14];
			assign L2_12_15_inputs[3] = l1_trig_p_i[15];
		end else begin : NOREMAP
			assign L2_0_3_inputs[0] = l1_trig_p_i[0];
			assign L2_0_3_inputs[1] = l1_trig_p_i[1];
			assign L2_0_3_inputs[2] = l1_trig_p_i[2];
			assign L2_0_3_inputs[3] = l1_trig_p_i[3];
			
			// DDA 3 ch1&2, DDA4 ch1&2
			assign L2_4_7_inputs[0] = l1_trig_p_i[4];
			assign L2_4_7_inputs[1] = l1_trig_p_i[5];
			assign L2_4_7_inputs[2] = l1_trig_p_i[6];
			assign L2_4_7_inputs[3] = l1_trig_p_i[7];
			
			// DDA 1 ch3&4, DDA2 ch3&4
			assign L2_8_11_inputs[0] = l1_trig_p_i[8];
			assign L2_8_11_inputs[1] = l1_trig_p_i[9];
			assign L2_8_11_inputs[2] = l1_trig_p_i[10];
			assign L2_8_11_inputs[3] = l1_trig_p_i[11];

			// DDA 3 ch3&4, DDA4 ch3&4
			assign L2_12_15_inputs[0] = l1_trig_p_i[12];
			assign L2_12_15_inputs[1] = l1_trig_p_i[13];
			assign L2_12_15_inputs[2] = l1_trig_p_i[14];
			assign L2_12_15_inputs[3] = l1_trig_p_i[15];
		end
	endgenerate
	
	l2_trigger_3of8 uL2_d1(.L1_i(L2_0_3_inputs),
								 .L2_mask_i(l2_mask_i[2:0]),
								 .L2_o(l2[2:0]),
								 .L2_scaler_o(l2_scaler_o[2:0]),
								 .clk_i(clk_i),.rst_i(rst_i),
								 .debug_o(debug));
	l2_trigger_3of8 uL2_d2(.L1_i(L2_4_7_inputs),
								 .L2_mask_i(l2_mask_i[6:4]),
								 .L2_o(l2[6:4]),
								 .L2_scaler_o(l2_scaler_o[6:4]),
								 .clk_i(clk_i),.rst_i(rst_i));
	l2_trigger_3of8 uL2_d3(.L1_i(L2_8_11_inputs),
								 .L2_mask_i(l2_mask_i[10:8]),
								 .L2_o(l2[10:8]),
								 .L2_scaler_o(l2_scaler_o[10:8]),
								 .clk_i(clk_i),.rst_i(rst_i));
	l2_trigger_3of8 uL2_d4(.L1_i(L2_12_15_inputs),
								 .L2_mask_i(l2_mask_i[14:12]),
								 .L2_o(l2[14:12]),
								 .L2_scaler_o(l2_scaler_o[14:12]),
								 .clk_i(clk_i),.rst_i(rst_i));
	// L3s...
	l3_trigger_3of8 uL3_d12(.L2A_i(l2[2:0]),.L2B_i(l2[6:4]),
									.L2A_scal_i(l2_scaler_o[2:0]),.L2B_scal_i(l2_scaler_o[6:4]),
								  .L3_mask_i(l3_mask_i[0]),.L3_o(l3[0]),
								  .L3_scaler_o(l3_scaler_o[0]),.clk_i(clk_i),.rst_i(rst_i));
	l3_trigger_3of8 uL3_d34(.L2A_i(l2[10:8]),.L2B_i(l2[14:12]),
									.L2A_scal_i(l2_scaler_o[2:0]),.L2B_scal_i(l2_scaler_o[6:4]),
									.L3_mask_i(l3_mask_i[1]),.L3_o(l3[1]),
								  .L3_scaler_o(l3_scaler_o[1]),.clk_i(clk_i),.rst_i(rst_i));
	// and the L4 trigger
	l4_trigger_3of8 uL4(.L3_i(l3[1:0]),
							  .L3_scal_i(l3_scaler_o[1:0]),
								.L4_mask_i(l4_mask_i[0]),.L4_o(l4_trig_o[0]),.L4_new_o(l4_new_o[0]),.L4_scaler_o(l4_scaler_o[0]),
								.blocks_i(rf0_blocks_i),
							  .clk_i(clk_i),.rst_i(rst_i));
	// The L4 info is just the pattern of 16 L1s. So we just delay the L1s by 3 clocks
	// (1 for L2, 1 for L3, 1 for L4).
	Generic_Pipeline #(.LATENCY(3),.WIDTH(16)) L4_info_RF0(.I(l1_trig_p_i[15:0]),.O(l1_delayed),.CE(1'b1), .CLK(clk_i));
	////////////////
	// SURFACE TRIGGER
	////////////////
	
	l4rf1_trigger uL4RF1(.L1_i(l1_trig_p_i[19:16]), .coincidence_i(rf1_coincidence_i),
								.L4_mask_i(l4_mask_i[1]),.L4_scaler_o(l4_scaler_o[1]),.L4_o(l4_trig_o[1]),
								.L4_new_o(l4_new_o[1]),.clk_i(clk_i),.rst_i(rst_i),
								.blocks_i(rf1_blocks_i));
	// 2 clock delay.
	Generic_Pipeline #(.LATENCY(3),.WIDTH(4)) L4_info_RF1(.I(l1_trig_p_i[19:16]),.O(surf_l1_delayed),.CE(1'b1), .CLK(clk_i));
	always @(posedge clk_i) begin
		if (l4_new_o[0]) trig_rf0_info <= l1_delayed;
	end
	always @(posedge clk_i) begin
		if (l4_new_o[1]) trig_rf1_info <= surf_l1_delayed;
	end
	assign trig_rf0_info_o = trig_rf0_info;
	assign trig_rf1_info_o = trig_rf1_info;
	
//	assign l4_trig_o[1] = 0;
//	assign l4_new_o[1] = 0;
//	assign trig_rf1_info_o = {32{1'b0}};
	assign debug_o = {1'b0,l1_scal_i[4:0],debug};
endmodule

module l4rf1_trigger(input [3:0] L1_i,
						   input [1:0] coincidence_i,
							input L4_mask_i,
							output L4_scaler_o,
							output L4_o,
							output L4_new_o,
							input [7:0] blocks_i,
							input clk_i,
							input rst_i);
	
	wire [2:0] L1_sum = L1_i[0]+L1_i[1]+L1_i[2]+L1_i[3];
	reg [1:0] coincidence = 2'b10;
	reg [7:0] nblocks = {8{1'b0}};
	reg [8:0] block_counter = {9{1'b0}};
	wire [2:0] L1_compare = {1'b0,coincidence};
	reg coincidence_exceeded = 0;
	reg l4_reg = 0;
	reg l4_hold = 1'b0;
	reg l4_scal = 1'b0;
	always @(posedge clk_i) coincidence <= coincidence_i;
	always @(posedge clk_i) coincidence_exceeded <= (L1_sum > L1_compare);
	always @(posedge clk_i) begin
		if (rst_i) l4_reg <= 0;
		else if (!L4_mask_i)
			l4_reg <= coincidence_exceeded;
		else
			l4_reg <= 0;
	end

	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l4_hold <= 0;
		else begin
			if (l4_reg) l4_hold <= 1;
			else if (block_counter[8:1] >= nblocks) l4_hold <= 0;
		end
	end

	// Register blocks_i into the fast clock domain.
	// Note: the block count, etc. should never be changed while the trigger is active!
	always @(posedge clk_i) nblocks <= blocks_i;
	// A block occurs in 2 clock cycles. We just divide down the counter by 2.
	// Note that the instant that a new trigger comes in, it extends the previous.
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) block_counter <= {9{1'b0}};
		else begin
			if (l4_reg) block_counter <= {9{1'b0}};
			else if (l4_hold) begin
				block_counter <= block_counter + 1;
			end
		end
	end
	
	// Scaler generation. Like the L4 trigger, but nonmasked, and doesn't cause an actual readout.
	SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"),.LATENCY(0)) l4_scal_gen(.I(coincidence_exceeded),.O(L4_scaler_o),.CLK(clk_i));
	// L4 new flag generation. Needs to be 2 clocks long.
	reg l4_new_extend = 0;
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l4_new_extend <= 0;
		else l4_new_extend <= l4_reg;
	end

	assign L4_o = l4_reg | l4_hold;
	assign L4_new_o = l4_reg | l4_new_extend;
			
endmodule

//% @brief L4 trigger for the 3 of 8 trigger. Generates scalers, and prolonged output to go to delay match.
module l4_trigger_3of8(
		input [1:0] L3_i,
		input [1:0] L3_scal_i,
		input L4_mask_i,
		output L4_o,
		output L4_new_o,
		output L4_scaler_o,
		input clk_i,
		input [7:0] blocks_i,
		input rst_i
);
	reg [7:0] nblocks = {8{1'b0}};
	reg [8:0] block_counter = {9{1'b0}};
	reg l4_reg = 1'b0;
	reg l4_hold = 1'b0;
	reg l4_scal = 1'b0;
	reg [1:0] l3_reg = {2{1'b0}};
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l3_reg <= 2'b00;
		else l3_reg <= L3_i;
	end
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l4_reg <= 1'b0;
		else begin
			if (!L4_mask_i)
				// Rising edge of L3.
				l4_reg <= (|L3_i) && (l3_reg == 2'b00);
			else
				l4_reg <= 1'b0;
		end
	end
	
	// Prolonged output.
	// When l4_reg occurs, the block counter resets.
	// clock 0: l4_reg = 1, l4_hold = 0, block_counter -> X block0A
	// clock 1: l4_reg = 0, l4_hold = 1, block_counter -> 0 block0B
	// clock 2: l4_reg = 0, l4_hold = 1, block_counter -> 1 block1A <-- ONE BLOCK REQUESTED. IF NBLOCKS=0, DONE HERE
	// clock 3: l4_reg = 0, l4_hold = 1, block_counter -> 2 block1B
	// clock 4: l4_reg = 0, l4_hold = 1, block_counter -> 3 <-- TWO BLOCKS REQUESTED. IF NBLOCKS=1, DONE HERE
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l4_hold <= 0;
		else begin
			if (l4_reg) l4_hold <= 1;
			else if (block_counter[8:1] >= nblocks) l4_hold <= 0;
		end
	end
	
	// Register blocks_i into the fast clock domain.
	// Note: the block count, etc. should never be changed while the trigger is active!
	always @(posedge clk_i) nblocks <= blocks_i;
	
	// A block occurs in 2 clock cycles. We just divide down the counter by 2.
	// Note that the instant that a new trigger comes in, it extends the previous.
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) block_counter <= {9{1'b0}};
		else begin
			if (l4_reg) block_counter <= {9{1'b0}};
			else if (l4_hold) begin
				block_counter <= block_counter + 1;
			end
		end
	end
	
	// Scaler generation. Like the L4 trigger, but nonmasked, and doesn't cause an actual readout.
	SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"),.LATENCY(0)) l4_scal_gen(.I(|L3_scal_i),.O(L4_scaler_o),.CLK(clk_i));
	// L4 new flag generation. Needs to be 2 clocks long.
	reg l4_new_extend = 0;
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l4_new_extend <= 0;
		else l4_new_extend <= l4_reg;
	end

	assign L4_o = l4_reg | l4_hold;
	assign L4_new_o = l4_reg | l4_new_extend;
endmodule

module l3_trigger_3of8(
		input [2:0] L2A_i,
		input [2:0] L2B_i,
		input [2:0] L2A_scal_i,
		input [2:0] L2B_scal_i,
		output L3_o,
		input L3_mask_i,
		output L3_scaler_o,
		input clk_i,
		input rst_i
);
	wire l3_raw;
	wire l3_scal_raw;
	reg l3_trig = 1'b0;
	reg l3_scal = 1'b0;
	wire A_count_1 = L2A_i[0];
	wire A_count_2 = L2A_i[1];
	wire A_count_3 = L2A_i[2];
	wire B_count_1 = L2B_i[0];
	wire B_count_2 = L2B_i[1];
	wire B_count_3 = L2B_i[2];
	assign l3_raw = (A_count_1 && B_count_2) || (A_count_2 && B_count_1) || A_count_3 || B_count_3;
//	assign l3_scal_raw = (L2A_scal_i[0] && L2B_scal_i[1]) || (L2A_scal_i[1] && L2B_scal_i[0]) ||
//								(L2A_scal_i[2]) || (L2B_scal_i[2]);
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l3_trig <= 1'b0;
		else begin
			if (!L3_mask_i) l3_trig <= l3_raw;
			else l3_trig <= 1'b0;
		end
	end
	// NO MORE FLAGS
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) l3_scal <= 1'b0;
		else l3_scal <= l3_raw;
	end
	
	assign L3_o = l3_trig;
	assign L3_scaler_o = l3_scal;
endmodule

module l2_popcount(input [3:0] val,
						 output [2:0] count);
	assign count[0] = |val;
	// (01 02 03) or (12 13) or (23)
	assign count[1] = (val[0] & (val[1] | val[2] | val[3])) |
							(val[1] & (val[2] | val[3])) |
							(val[2] & val[3]);
	// (012 or 013) or (023 or 123)
	assign count[2] = (val[0] & val[1] & (val[2] | val[3])) |
							(val[2] & val[3] & (val[0] | val[1]));
endmodule

module l2_trigger_3of8(
		input [3:0] L1_i,
		input [2:0] L2_mask_i,
		output [2:0] L2_o,
		output [2:0] L2_scaler_o,
		input clk_i,
		input rst_i,
		output [2:0] debug_o
);

	wire [2:0] l2_encode;
	wire [2:0] l2_scal_encode;
	reg [2:0] l2_reg = {3{1'b0}};
	reg [2:0] l2_scal = {3{1'b0}};
	l2_popcount l2(.val(L1_i),.count(l2_encode));
								 
	integer i;
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i)
			l2_reg <= {3{1'b0}};
		else begin
			for (i=0;i<3;i=i+1) begin
				if (!L2_mask_i[i])
					l2_reg[i] <= l2_encode[i];
				else
					l2_reg[i] <= 0;
			end
		end
	end

	// Scalers are unmaskable.
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i)
			l2_scal <= {3{1'b0}};
		else begin
			l2_scal <= l2_encode;
		end
	end
	
	// Flag generation.
	// NO MORE FLAGS. Scalers are just count-derived.
	assign L2_o = l2_reg;
	assign L2_scaler_o = l2_scal;
	assign debug_o = l2_scal_encode;
endmodule
