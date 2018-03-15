`timescale 1ns / 1ps
`include "trigger_defs.vh"

//% @brief Replacement for the trigger_handling module. This one can actually take variable pretrigger values.
//% Trigger handler. This is version 3, which integrates with 0.12+ firmware that has trigger info FIFOs.
//% It has an additional "discarded L4 new" output. This is used with the trigger_info_fifo_v2 module,
//% which has *2* FIFOs: one to capture the trigger info immediately at the trigger to hold until it's presented
//% to the readout module, and 
//%
//% The point of the second trigger info FIFO is that the triggers don't know how long it will take for
//% the actual trigger handling to occur, so they need to buffer their trigger info. They write in
//% for *every* L4 new they send out. If it's masked off, l4_new_discard_o is eventually asserted,
//% which causes a read from the trigger's FIFO, but no write into the readout FIFO.
//% If it's not masked off, l4_new_o is asserted, causing a write into the readout FIFO.
module trigger_handling_v3(
		pretrigger_vector_i,
		delay_vector_i,
		l4_i,
		l4_new_i,
		T1_mask_i,
		l4_matched_o,
		l4_new_o,
		l4_new_discard_o,
		T1_o,
		T1_scaler_o,
		T1_offset_o,
		clk_i,
		rst_i,
		disable_i,
		disable_ce_i
    );

// The previous trigger handler was a cute idea, but basically was a preprocessor. It couldn't work
// on the fly because the math required was too large.
//
// Basically, the idea is this: we've got a number of input triggers (4 nominally, may add an external trig).
// Each of them output 2 numbers: a delay, and a pretrigger number.
// The start of the readout should occur at:
// t_trig - pretrigger + delay.
// So if pretrigger is 10, and delay is 2, then we start reading out 8 clocks prior to t_trig.
// With multiple input triggers, to combine them, you just choose the one with the most negative
// pretrigger+delay, and use that value as the delay to output to the IRS (max_negative_offset)
// Then you just delay the other signals by (pretrigger+delay-max_negative_offset).
// You actually do this a bit stupider: you delay each signal by 'delay' (which can be up to 32 clocks).
// And then you just look for the one with the biggest pretrigger value (which can be up to 32 blocks).
// And then you delay the other triggers the difference in the pretrigger values.

	//% Number of L4 triggers.
	parameter NUM_L4 = `SCAL_NUM_L4;
	parameter DELAY_BITS = `DELAY_BITS;
	parameter PRETRG_BITS = `PRETRG_BITS;

	//% Concatenated vector of pretrigger counts.
	input [NUM_L4*PRETRG_BITS-1:0] pretrigger_vector_i;
	//% Concatenated vector of delays.
	input [NUM_L4*DELAY_BITS-1:0] delay_vector_i;
	//% Input L4 triggers.
	input [NUM_L4-1:0] l4_i;
	//% Input L4 new trigger info
	input [NUM_L4-1:0] l4_new_i;
	//% Mask of T1 output.
	input T1_mask_i;
	//% T1 output.
	output T1_o;
	//% L4 output, matched to the T1 output.
	output [NUM_L4-1:0] l4_matched_o;
	//% L4 new info output, matched to T1 output
	output [NUM_L4-1:0] l4_new_o;
	//% Scaler (unmasked) T1 output.
	output T1_scaler_o;
	//% Offset of the T1 output to the desired readout (in blocks (2x clocks))
	output [8:0] T1_offset_o;
	//% System clock.
	input clk_i;
	//% Trigger subsystem reset.
	input rst_i;
	//% IRS disable input. This is for the CURRENT cycle.
	input disable_i;
	//% Clock enable for the disable input.
	input disable_ce_i;
	
	//% Internal delay. We delay everything by 4 clocks, minimum, so the total delay is 2 blocks.
	localparam INTERNAL_DELAY = 2;
	localparam BASE_OFFSET = INTERNAL_DELAY + `BASE_OFFSET;
	
	//% Array of L4 delays (devectorized from input vector).
	wire [DELAY_BITS-1:0] l4_delay[NUM_L4-1:0];
	//% Array of L4 pretrigger counts (devectorized from input vector).
	wire [PRETRG_BITS-1:0] l4_pretrig[NUM_L4-1:0];
	//% Array of offsets from the maximum pretrigger count (for delay matching).
	reg [PRETRG_BITS-1:0] l4_offset[NUM_L4-1:0];
	//% Maximum offset of all of the L4 offsets.
	wire [PRETRG_BITS-1:0] max_offset;
	
	//% Delayed L4 triggers.
	wire [NUM_L4-1:0] l4_delayed;
	//% Delayed L4 new info.
	wire [NUM_L4-1:0] l4_delayed_new_info;
	//% Matched L4 triggers (but not aligned to T1).
	wire [NUM_L4-1:0] l4_matched;
	//% Matched L4 new info.
	wire [NUM_L4-1:0] l4_matched_new_info;
	//% T1 scaler output.
	reg T1 = 0;
	//% Actual trigger output, to start the readout.
	reg T1_masked = 0;
	//% Offset, in number of *blocks*, from T1 going high to what the block readout desired is.
	reg [8:0] T1_offset = {9{1'b0}};
	////
	// COMPARE TREE. Here we have to figure out the maximum offset of the l4_pretrig array.
	////
	// The compare tree probably doesn't have to be fully pipelined, but
	// par_compare_tree doesn't have partial pipelining yet and we probably
	// have the resources to spare.
	par_compare_tree #(.WIDTH(PRETRG_BITS),.ELEMENTS(NUM_L4))
		pretrig_maximizer(.vector_i(pretrigger_vector_i),
								.max_o(max_offset),
								.clk_i(clk_i));

	// 2 CLOCK DELAY IN THE DELAY+MATCH BLOCK HERE
	generate
		genvar l4;
		for (l4=0;l4<NUM_L4;l4=l4+1) begin : LP
			// Devectorize.
			assign l4_delay[l4] = delay_vector_i[DELAY_BITS*l4 +: DELAY_BITS];
			assign l4_pretrig[l4] = pretrigger_vector_i[DELAY_BITS*l4 +: DELAY_BITS];
			// Now delay.
			if (DELAY_BITS <= 4) begin : SD
				SRLC32E #(.INIT(32'h00000000)) delay(.D(l4_i[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4],1'b0}),																			 
																				 .Q(l4_delayed[l4]));
				SRLC32E #(.INIT(32'h00000000)) delayN(.D(l4_new_i[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4],1'b0}),																			 
																				 .Q(l4_delayed_new_info[l4]));
			end else begin : DD
				wire l4_delay_short, l4_delay_long, l4_delay_chain;
				wire l4_new_delay_short, l4_new_delay_long, l4_new_delay_chain;
				SRLC32E #(.INIT(32'h00000000)) delayS(.D(l4_i[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4][3:0],1'b0}),
																				 .Q31(l4_delay_chain),
																				 .Q(l4_delay_short));
				SRLC32E #(.INIT(32'h00000000)) delayL(.D(l4_delay_chain),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4][3:0],1'b0}),
																				 .Q(l4_delay_long));

				assign l4_delayed[l4] = (l4_delay[l4][4]) ? l4_delay_long : l4_delay_short;

				SRLC32E #(.INIT(32'h00000000)) delayNS(.D(l4_new_i[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4][3:0],1'b0}),
																				 .Q31(l4_new_delay_chain),
																				 .Q(l4_new_delay_short));
				SRLC32E #(.INIT(32'h00000000)) delayNL(.D(l4_new_delay_chain),.CE(1'b1),.CLK(clk_i),.A({l4_delay[l4][3:0],1'b0}),
																				 .Q(l4_new_delay_long));
				assign l4_delayed_new_info[l4] = (l4_delay[l4][4]) ? l4_new_delay_long : l4_new_delay_short;
			end
			// And match.
			if (PRETRG_BITS <= 4) begin : SM
				SRLC32E #(.INIT(32'h00000000)) match(.D(l4_delayed[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4],1'b0}),
																					 .Q(l4_matched[l4]));
				SRLC32E #(.INIT(32'h00000000)) matchN(.D(l4_delayed_new_info[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4],1'b0}),
																					 .Q(l4_matched_new_info[l4]));
			end else if (PRETRG_BITS == 5) begin : DM
				wire l4_match_short, l4_match_long, l4_match_chain;
				wire l4_new_match_short, l4_new_match_long, l4_new_match_chain;
				SRLC32E #(.INIT(32'h00000000)) matchS(.D(l4_delayed[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																						  .Q(l4_match_short),
																						  .Q31(l4_match_chain));
				SRLC32E #(.INIT(32'h00000000)) matchL(.D(l4_match_chain),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																						  .Q(l4_match_long));
				assign l4_matched[l4] = (l4_offset[l4][4]) ? l4_match_long : l4_match_short;

				SRLC32E #(.INIT(32'h00000000)) matchNS(.D(l4_delayed_new_info[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																						  .Q(l4_new_match_short),
																						  .Q31(l4_new_match_chain));
				SRLC32E #(.INIT(32'h00000000)) matchNL(.D(l4_new_match_chain),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																						  .Q(l4_new_match_long));
				assign l4_matched_new_info[l4] = (l4_offset[l4][4]) ? l4_new_match_long : l4_new_match_short;
			end else if (PRETRG_BITS == 6) begin : QM
				// quad-length match
				wire [3:0] l4_match_intermediate;
				wire [2:0] l4_match_chain;
				wire [3:0] l4_new_match_intermediate;
				wire [3:0] l4_new_match_chain;
				SRLC32E #(.INIT(32'h00000000)) matchA(.D(l4_delayed[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[0]),
																  .Q31(l4_match_chain[0]));
				SRLC32E #(.INIT(32'h00000000)) matchB(.D(l4_match_chain[0]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[1]),
																  .Q31(l4_match_chain[1]));
				SRLC32E #(.INIT(32'h00000000)) matchC(.D(l4_match_chain[1]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[2]),
																  .Q31(l4_match_chain[2]));
				SRLC32E #(.INIT(32'h00000000)) matchD(.D(l4_match_chain[2]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[3]));

				SRLC32E #(.INIT(32'h00000000)) newmatchA(.D(l4_delayed_new_info[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[0]),
																  .Q31(l4_new_match_chain[0]));
				SRLC32E #(.INIT(32'h00000000)) newmatchB(.D(l4_new_match_chain[0]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[1]),
																  .Q31(l4_new_match_chain[1]));
				SRLC32E #(.INIT(32'h00000000)) newmatchC(.D(l4_new_match_chain[1]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[2]),
																  .Q31(l4_new_match_chain[2]));
				SRLC32E #(.INIT(32'h00000000)) newmatchD(.D(l4_new_match_chain[2]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[3]));
				assign l4_matched[l4] = l4_match_intermediate[l4_offset[l4][5:4]];
				assign l4_matched_new_info[l4] = l4_new_match_intermediate[l4_offset[l4][5:4]];
			end else begin : OM
				wire [7:0] l4_match_intermediate;
				wire [6:0] l4_match_chain;
				wire [7:0] l4_new_match_intermediate;
				wire [6:0] l4_new_match_chain;
				SRLC32E #(.INIT(32'h00000000)) matchA(.D(l4_delayed[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[0]),
																  .Q31(l4_match_chain[0]));
				SRLC32E #(.INIT(32'h00000000)) matchB(.D(l4_match_chain[0]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[1]),
																  .Q31(l4_match_chain[1]));
				SRLC32E #(.INIT(32'h00000000)) matchC(.D(l4_match_chain[1]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[2]),
																  .Q31(l4_match_chain[2]));
				SRLC32E #(.INIT(32'h00000000)) matchD(.D(l4_match_chain[2]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[3]),
																  .Q31(l4_match_chain[3]));
				SRLC32E #(.INIT(32'h00000000)) matchE(.D(l4_match_chain[3]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[4]),
																  .Q31(l4_match_chain[4]));
				SRLC32E #(.INIT(32'h00000000)) matchF(.D(l4_match_chain[4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[5]),
																  .Q31(l4_match_chain[5]));
				SRLC32E #(.INIT(32'h00000000)) matchG(.D(l4_match_chain[5]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[6]),
																  .Q31(l4_match_chain[6]));
				SRLC32E #(.INIT(32'h00000000)) matchH(.D(l4_match_chain[6]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_match_intermediate[7]));

				SRLC32E #(.INIT(32'h00000000)) newmatchA(.D(l4_delayed_new_info[l4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[0]),
																  .Q31(l4_new_match_chain[0]));
				SRLC32E #(.INIT(32'h00000000)) newmatchB(.D(l4_new_match_chain[0]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[1]),
																  .Q31(l4_new_match_chain[1]));
				SRLC32E #(.INIT(32'h00000000)) newmatchC(.D(l4_new_match_chain[1]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[2]),
																  .Q31(l4_new_match_chain[2]));
				SRLC32E #(.INIT(32'h00000000)) newmatchD(.D(l4_new_match_chain[2]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[3]),
																  .Q31(l4_new_match_chain[3]));
				SRLC32E #(.INIT(32'h00000000)) newmatchE(.D(l4_new_match_chain[3]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[4]),
																  .Q31(l4_new_match_chain[4]));
				SRLC32E #(.INIT(32'h00000000)) newmatchF(.D(l4_new_match_chain[4]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[5]),
																  .Q31(l4_new_match_chain[5]));
				SRLC32E #(.INIT(32'h00000000)) newmatchG(.D(l4_new_match_chain[5]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[6]),
																  .Q31(l4_new_match_chain[6]));
				SRLC32E #(.INIT(32'h00000000)) newmatchH(.D(l4_new_match_chain[6]),.CE(1'b1),.CLK(clk_i),.A({l4_offset[l4][3:0],1'b0}),
																  .Q(l4_new_match_intermediate[7]));
				assign l4_matched[l4] = l4_match_intermediate[l4_offset[l4][6:4]];
				assign l4_matched_new_info[l4] = l4_new_match_intermediate[l4_offset[l4][6:4]];
			end
			// Calculate the offset.
			always @(posedge clk_i) begin : CALC_OFFSET
				l4_offset[l4] <= max_offset - l4_pretrig[l4];
			end
		end
	endgenerate

	// DISABLE DELAY
	// The disable_i input also needs to be delayed to match up with the trigger to make sure that they're
	// aligned correctly. Thankfully, it's "only" 16 SRLC32E's long, because disable_ce_i makes sure that
	// disable_i is aligned correctly to block transitions (which is why we can't do this for the trigger,
	// which isn't aligned. Might make things easier if we *did* think of a way to align the trigger to
	// block transitions...
	
	// Last one is unused, but kept to allow the loop to be uniform.
	wire [16:0] disable_chain;
	wire [15:0] disable_vect;
	wire [8:0] disable_addr;
	wire disable_mask;
	assign disable_chain[0] = disable_i;
	generate
		genvar dis_i;
		for (dis_i=0;dis_i<16;dis_i=dis_i+1) begin : DISABLE_DELAY_LOOP
			SRLC32E #(.INIT({32{1'b0}})) SR_dis(.D(disable_chain[dis_i]),.CE(disable_ce_i),.CLK(clk_i),.A(disable_addr[4:0]),
															.Q(disable_vect[dis_i]),.Q31(disable_chain[dis_i+1]));
		end
	endgenerate
	assign disable_addr = T1_offset;
	assign disable_mask = (disable_vect[disable_addr[8:5]]);
		
	reg wr_ce = 0;
	// We have to prolong the disable after it deasserts, until we see any L4NEW.
	// This marks the start of a new event.
	reg disable_hold = 0;
	// If any of the l4_matched_new_info is asserted, kill disable_hold.
	// When this happens, T1 goes high the same time as disable_hold deasserts
	// (since it's just an or of l4_matched), and then T1_masked will assert,
	// since the disable_or_hold isn't asserted anymore.
	wire disable_or_hold = (disable_hold || disable_mask);
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) disable_hold <= 0;
		else if (disable_mask) disable_hold <= 1;
		else if (|l4_matched_new_info) disable_hold <= 0;
	end
	
	// ANOTHER 2 CLOCK DELAY IN THE GENERATION/MASK HERE
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) T1 <= 0;
		else begin
			T1 <= |l4_matched;
		end
	end
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i) T1_masked <= 1'b0;
		else begin
			if (!T1_mask_i && !disable_or_hold) T1_masked <= T1;
			else T1_masked <= 1'b0;
		end
	end
	// Match the L4 outputs to the T1 outputs.
	Generic_Pipeline #(.WIDTH(NUM_L4),.LATENCY(2)) l4_match_pipe(.I(l4_matched),.O(l4_matched_o),.CE(1'b1),.CLK(clk_i));
	// Match the L4 new info outputs to the T1 outputs.
	wire [NUM_L4-1:0] l4new_delayed;
	reg [NUM_L4-1:0] l4new_masked_out = {NUM_L4{1'b0}};
	reg [NUM_L4-1:0] l4new_discarded_out = {NUM_L4{1'b0}};
	Generic_Pipeline #(.WIDTH(NUM_L4),.LATENCY(1)) l4new_match_pipe(.I(l4_matched_new_info),.O(l4new_delayed),.CE(1'b1),.CLK(clk_i));
	// We have to mask the L4NEW outputs because they ONLY are valid if a T1 is generated.
	always @(posedge clk_i) begin
		if (!T1_mask_i && !disable_or_hold)
			l4new_masked_out <= l4new_delayed;
		else
			l4new_masked_out <= {NUM_L4{1'b0}};
		
		// original is !A && !B, we want !(!A && !B) this is !!(A || B) = (A || B).
		if (T1_mask_i || disable_or_hold)
			l4new_discarded_out <= l4_new_delayed;
		else
			l4new_discarded_out <= {NUM_L4{1'b0}};
	end
	
	always @(posedge clk_i) begin
		T1_offset <= max_offset + BASE_OFFSET;
	end
	assign l4_new_discard_o = l4new_discarded_out;
	assign l4_new_o = l4new_masked_out;
	assign T1_o = T1_masked;
	assign T1_scaler_o = T1;
	assign T1_offset_o = T1_offset;
endmodule
