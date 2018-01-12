`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:14:59 08/10/2012
// Design Name:   trigger_handling_v2
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/trigger_handling_testbench.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: trigger_handling_v2
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

`include "trigger_defs.vh"

module trigger_handling_testbench;

	// Inputs
	reg [`PRETRG_BITS-1:0] pretrigger[`SCAL_NUM_L4-1:0];
	reg [`DELAY_BITS-1:0] delay[`SCAL_NUM_L4-1:0];
	reg [`SCAL_NUM_L4-1:0] l4_i;
	reg T1_mask_i;
	reg clk_i;
	reg rst_i;
	localparam PRETRG_BITS = `PRETRG_BITS;
	localparam DELAY_BITS = `DELAY_BITS;
	localparam NUM_L4 = `SCAL_NUM_L4;
	localparam INTERNAL_DELAY = 2;
	localparam BASE_OFFSET = `BASE_OFFSET + INTERNAL_DELAY;
	wire [PRETRG_BITS * NUM_L4 - 1 :0] pretrigger_vector_i;
	wire [DELAY_BITS * NUM_L4 - 1 :0] delay_vector_i;
	
	generate
		genvar i;
		for (i=0;i<NUM_L4;i=i+1) begin : VECTORIZE
			assign pretrigger_vector_i[PRETRG_BITS * i +: PRETRG_BITS] = pretrigger[i];
			assign delay_vector_i[DELAY_BITS * i +: DELAY_BITS] = delay[i];
		end
   endgenerate

	// Outputs
	wire T1_o;
	wire T1_scaler_o;
	wire [8:0] T1_offset_o;
	wire [NUM_L4-1:0] l4_matched_o;


	// Instantiate the Unit Under Test (UUT)
	trigger_handling_v2 uut (
		.pretrigger_vector_i(pretrigger_vector_i), 
		.delay_vector_i(delay_vector_i), 
		.l4_i(l4_i), 
		.l4_matched_o(l4_matched_o),
		.T1_mask_i(T1_mask_i), 
		.T1_o(T1_o), 
		.T1_scaler_o(T1_scaler_o), 
		.T1_offset_o(T1_offset_o), 
		.clk_i(clk_i), 
		.rst_i(rst_i)
	);
	
	always begin
		#5 clk_i = ~clk_i;
	end
	// Generate the block counter.
	reg block_counter_ce = 0;
	reg [8:0] block_counter = {9{1'b0}};
	always @(posedge clk_i) begin
		block_counter_ce <= ~block_counter_ce;
	end
	always @(posedge clk_i) begin
		if (block_counter_ce) block_counter <= block_counter + 1;
	end
	initial begin
		// Initialize Inputs
		pretrigger[0] = `TRIG_RF0_PRETRIGGER;
		pretrigger[1] = `TRIG_RF1_PRETRIGGER;
		pretrigger[2] = `TRIG_CPU_PRETRIGGER;
		pretrigger[3] = `TRIG_CAL_PRETRIGGER;
		delay[0] = `TRIG_RF0_DELAY;
		delay[1] = `TRIG_RF1_DELAY;
		delay[2] = `TRIG_CPU_DELAY;
		delay[3] = `TRIG_CAL_DELAY;
		l4_i = 0;
		T1_mask_i = 0;
		clk_i = 0;
		rst_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		#250;
		// Add stimulus here
		@(posedge clk_i);
		#1 l4_i = 4'b0101;
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		#1 l4_i = 4'b0001;
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		@(posedge clk_i);
		#1 l4_i = 0;
	end
   // Look for the rising edge of L4.
	reg [NUM_L4-1:0] l4_i_latched = {NUM_L4{1'b0}};
	always @(posedge clk_i) l4_i_latched <= l4_i;
	reg [NUM_L4-1:0] l4_o_latched = {NUM_L4{1'b0}};
	always @(posedge clk_i) l4_o_latched <= l4_matched_o;
	reg [8:0] l4_trigger_block[NUM_L4-1:0];
	reg [8:0] l4_block_out[NUM_L4-1:0];
	integer l4tbi;
	initial begin
		for (l4tbi=0;l4tbi<NUM_L4;l4tbi=l4tbi+1) begin
			l4_trigger_block[l4tbi] <= {9{1'b0}};
			l4_block_out[l4tbi] <= {9{1'b0}};
		end
	end
	integer l4bi;
	reg [NUM_L4-1:0] check = {NUM_L4{1'b0}};
	always @(posedge clk_i) begin
		for (l4bi=0;l4bi<NUM_L4;l4bi=l4bi+1) begin
			if (l4_i[l4bi] == 1 && l4_i_latched[l4bi] == 0)
				l4_trigger_block[l4bi] <= block_counter - `BASE_OFFSET - pretrigger[l4bi] + delay[l4bi];
			if (l4_matched_o[l4bi]==1 && l4_o_latched[l4bi] == 0) begin
				l4_block_out[l4bi] <= block_counter - T1_offset_o;
				#1 check[l4bi] <= 1;
			end else begin
				#1 check[l4bi] <= 0;
			end
		end
	end
	// The verification test for the trigger_handling module is that when a trigger output occurs (l4_matched_o
	// goes high), l4_block_out matches l4_trigger_block.
	// l4_trigger_block is latched when l4_i goes high. We subtract off the "base_offset" (8 blocks),
	// add the delay (delay[l4bi]), and subtract the pretrigger (pretrigger[l4bi]). This is what block
	// the trigger is requesting.
	// l4_block_out is latched when l4_matched_o goes high. It is equal to the block counter minus
	// the T1_offset_o. This is the block that the trigger handler is requesting.
	integer vi;
	always @(posedge clk_i) begin
		for (vi=0;vi<NUM_L4;vi=vi+1) begin
			if (check[vi]) begin
				$display("L4 #%d trigger has begun. Block %d requested (wanted %d)\n",
							vi, l4_block_out[vi],l4_trigger_block[vi]);
				if (l4_block_out[vi	] != l4_trigger_block[vi]) begin
					$display("BLOCK REQUEST/RECEIVE MISMATCH: VERIFICATION FAILED\n");
					$stop;
				end
			end
		end
	end
endmodule

