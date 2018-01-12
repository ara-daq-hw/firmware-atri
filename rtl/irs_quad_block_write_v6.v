// IRS write controller.

//% @brief IRS quad write controller.
//%
//% @gensymbol
//% MODULE irs_quad_write_controller_v6
//% LPORT clk_i input
//% LPORT sync_i input
//% LPORT enable_i input
//% LPORT rst_i input
//% LPORT space
//% LPORT ssp_clk_i input
//% LPORT wrstrb_clk_i input
//% LPORT space
//% LPORT d1_block_i input
//% LPORT d2_block_i input
//% LPORT d3_block_i input
//% LPORT d4_block_i input
//% LPORT block_i input
//% LPORT space
//% LPORT wr_phase_o output
//% LPORT wr_ack_o output
//% LPORT block_o output
//% LPORT block_wr_o output
//% RPORT ssp_o output
//% RPORT sst_o output
//% RPORT wrstrb_o output
//% RPORT wr_o output
//% @endgensymbol
//%
//% This module outputs a phase (via wr_phase_o) which indicates whether the top half
//% of the sampling cells are being written to, or the bottom half.
//% It also outputs a wr_ack_o signal which indicates that the block which is presented
//% on wr_block_i has been written to.
//%
//% The block write is pipelined by one: when wr_ack_o is asserted, the block will actually be
//% written to on the next sample (2 clocks later).
//%
//% This, therefore, separates the block *fetch* from the block *write*. The block
//% fetching portions are purely digital. These, however, may need to be tuned for optimal
//% timing.
module irs_quad_write_controller_v6(
		// System interface
		input clk_i,					//% System clock (1/32 sampling speed).
		input sync_i,					//% Synchronizer. Keeps us on the same phase of the clock until a reset.
		input enable_i, 				//% Begin writing to the IRS.
		input rst_i,					//% System reset.
		input ssp_clk_i,				//% Clock for the SSp timing strobe. Still 4X SSt, but offset in phase.
		input wrstrb_clk_i,			//% Clock for the write strobe going high. Still 4X SSt, offset in phase.
				
		// Interface to the block manager.
		input [8:0] d1_block_i,		//% Block value to use for Daughter 1.
		input [8:0] d2_block_i, 	//% Block value to use for Daughter 2.
		input [8:0] d3_block_i,		//% Block value to use for Daughter 3.
		input [8:0] d4_block_i, 	//% Block value to use for Daughter 4.
		input [8:0] logical_block_i,			//% Logical block value (common to all daughters).
		output [8:0] logical_block_o,		//% Logical block value output (to history buffer)
		// Output indicating that a write is occuring now. This occurs continuously.
		output write_strobe_o,

		output wr_phase_o,			//% '1' if we need a block for sample cells 64-128, 0 for 0-63
		output wr_ack_o,				//% Block has been written to.
				
		// Interface to the IRS. Connect straight to the IOBUFs for proper timing.
		output d1_ssp_o,					//% Start timing strobe.
		output d1_sst_o,					//% Stop timing strobe.
		output d1_wrstrb_o,				//% Write strobe.
		output [9:0] d1_wr_o,			//% Write lines.

		output d2_ssp_o,					//% Start timing strobe.
		output d2_sst_o,					//% Stop timing strobe.
		output d2_wrstrb_o,				//% Write strobe.
		output [9:0] d2_wr_o,			//% Write lines.

		output d3_ssp_o,					//% Start timing strobe.
		output d3_sst_o,					//% Stop timing strobe.
		output d3_wrstrb_o,				//% Write strobe.
		output [9:0] d3_wr_o,			//% Write lines.

		output d4_ssp_o,					//% Start timing strobe.
		output d4_sst_o,					//% Stop timing strobe.
		output d4_wrstrb_o,				//% Write strobe.
		output [9:0] d4_wr_o,			//% Write lines.

		// Debug outputs. Equivalent to the IRS outputs, except ssp/wrstrb are in clk_i domain.
		output dbg_ssp_o,				//% Debug start timing strobe.
		output dbg_sst_o,				//% Debug stop timing strobe.
		output dbg_wrstrb_o,			//% Debug write strobe.
		output [9:0] dbg_wr_o,		//% Debug write address.
		output [3:0] dbg_state_o	//% Debug state.
		);

	localparam MAX_DAUGHTERS = 4;
	parameter NUM_DAUGHTERS = 4;
	
	localparam [1:0] D1 = 2'b00; 	//% daughter 1
	localparam [1:0] D2 = 2'b01;	//% daughter 2
	localparam [1:0] D3 = 2'b10;  //% daughter 3
	localparam [1:0] D4 = 2'b11;  //% daughter 4

	//% Determines which daughterboard's debug outputs are connected. Note that they only change
	//% if one of the daughterboards is an IRS2 and one is an IRS3.
	localparam [1:0] DEBUG_DB = D1; // can be D1, D2, D3, or D4

	// VECTORIZE INPUTS
	wire [8:0] block_i[MAX_DAUGHTERS-1:0];
	wire [MAX_DAUGHTERS-1:0] ssp_o;
	wire [MAX_DAUGHTERS-1:0] sst_o;
	wire [9:0] wr_o[MAX_DAUGHTERS-1:0];
	wire [MAX_DAUGHTERS-1:0] wrstrb_o;
	
	`define VECIN( x ) \
		assign x [0] = d1_``x ; \
		assign x [1] = d2_``x ; \
		assign x [2] = d3_``x ; \
		assign x [3] = d4_``x
	`define VECOUT( x ) \
		assign d1_``x = x [0] ;		 \
		assign d2_``x = x [1] ;		 \
		assign d3_``x = x [2] ;     \
		assign d4_``x = x [3]

	`VECIN( block_i );
	`VECOUT( ssp_o );
	`VECOUT( sst_o );
	`VECOUT( wr_o );
	`VECOUT( wrstrb_o );
	
	`undef VECIN
	`undef VECOUT
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(7);
	localparam [FSM_BITS-1:0] RESET = 0;						  //% SST=0, WRSTRB=0, WR=X.
	localparam [FSM_BITS-1:0] RESET_SYNC = 1;					  //% SST=0, WRSTRB=0, WR=X.
	localparam [FSM_BITS-1:0] RESET_WAIT = 2;               //% SST=0, WRSTRB=0, WR=X.
	localparam [FSM_BITS-1:0] RESET_WAIT_2 = 3;				  //% SST=0, WRSTRB=0, WR=X
	localparam [FSM_BITS-1:0] SAMPLE_LOW_PREP_HIGH 		= 4; //% SST=1, WRSTRB=0, WR=HIGHBLOCK.
	localparam [FSM_BITS-1:0] SAMPLE_LOW_TRANSFER_HIGH = 5; //% SST=1, WRSTRB=1, WR=HIGHBLOCK.
	localparam [FSM_BITS-1:0] PREP_LOW_SAMPLE_HIGH		= 6; //% SST=0, WRSTRB=0, WR=LOWBLOCK.
	localparam [FSM_BITS-1:0] TRANSFER_LOW_SAMPLE_HIGH = 7; //% SST=0, WRSTRB=1, WR=LOWBLOCK.
	reg [FSM_BITS-1:0] state = RESET;							  //% State variable.
	assign dbg_state_o = state;

	//% Flop that connects to the SSp clock domain.
	reg ssp_en_sync = 0;
	//% Flop *in* the clock domain, passes to OLOGIC.
	reg ssp_enable = 0;
	//% Flop that connects to the OLOGIC for SSt
	reg sst_enable = 0;
	
	//% Synchronization flop for WRSTRB
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg [MAX_DAUGHTERS-1:0] wrstrb_sync = {MAX_DAUGHTERS{1'b0}};
	//% Acknowledge that a block has been written.
	reg wr_ack = 0;
	
	//% 1 if the high cells have been sampled to, 0 otherwise. (Used after reset).
	reg high_cells_sampled = 0;
	//% 1 if the low cells have been sampled to, 0 otherwise. Unused, here for completeness.
	reg low_cells_sampled = 0;

	//% sst_enable feeds to the OLOGIC for SSt. It needs to go high 2 clocks before SST goes high.
	always @(posedge clk_i) begin : SST_SYNC_LOGIC
		sst_enable <= ((state == RESET_WAIT) || (state == RESET_WAIT_2)) || 
						  ((state == PREP_LOW_SAMPLE_HIGH) || (state == TRANSFER_LOW_SAMPLE_HIGH));
	end
	//% ssp_en_sync passes over to the SSp clock domain, which is registered there and passed to OLOGIC.
	always @(posedge clk_i) begin : SSP_EN_SYNC_LOGIC
		ssp_en_sync <= ((state == RESET_SYNC && !sync_i) || (state == RESET_WAIT)) ||
							((state == SAMPLE_LOW_TRANSFER_HIGH) || (state == PREP_LOW_SAMPLE_HIGH));
	end
	//% ssp_enable is in the SSp clock domain. It passes to OLOGIC.
	always @(posedge ssp_clk_i) begin : SSP_SYNC_LOGIC
		ssp_enable <= ssp_en_sync;
	end
	
	always @(posedge clk_i) begin : FSM_LOGIC
		if (rst_i) state <= RESET;
		else begin
			case (state)
				RESET: state <= RESET_SYNC;
				RESET_SYNC: if (!sync_i) state <= RESET_WAIT;
				RESET_WAIT: state <= RESET_WAIT_2;								//% SST enable will go high next cycle...
				RESET_WAIT_2: state <= SAMPLE_LOW_PREP_HIGH;					//% 0 SST enable goes high:
				SAMPLE_LOW_PREP_HIGH: state <= SAMPLE_LOW_TRANSFER_HIGH; //% 0 SST=1. Latch/ack block for phase 0. WR=block for phase 1 (if high cells sampled).
				SAMPLE_LOW_TRANSFER_HIGH: state <= PREP_LOW_SAMPLE_HIGH; //% 1 SST=1. write_strobe (indicates block has been written) = 1 (flag) if high cells sampled.
				PREP_LOW_SAMPLE_HIGH: state <= TRANSFER_LOW_SAMPLE_HIGH; //% 1 SST=0. Latch/ack block for phase 1. WR=block for phase 0.
				TRANSFER_LOW_SAMPLE_HIGH: state <= SAMPLE_LOW_PREP_HIGH; //% 0 SST=0. write_strobe (indicates block has been written) = 1.
			endcase
		end
	end

	//% Acknowledge. Occurs after RESET_WAIT/SLPH/PLSH (at RESET_WAIT_2/SLTH/TLSH). Block is grabbed then.
	//% The IOBUF then latches it at SLPH/PLSH. It's delayed slightly (to ensure a hold time on WRSTRB) and out it goes.
	always @(posedge clk_i) begin : ACK_LOGIC
		if (wr_ack) wr_ack <= 0;
		else if (((state == RESET_WAIT) || state == SAMPLE_LOW_PREP_HIGH || state == PREP_LOW_SAMPLE_HIGH)
					 && enable_i) wr_ack <= 1;
	end

	//% High/low cell sampling indicator logic.
	always @(posedge clk_i) begin : CELLS_SAMPLED_LOGIC
		if (rst_i) begin
			high_cells_sampled <= 0;
			low_cells_sampled <= 0;
		end else begin
			if (state == SAMPLE_LOW_TRANSFER_HIGH) low_cells_sampled <= 1;
			if (state == TRANSFER_LOW_SAMPLE_HIGH) high_cells_sampled <= 1;
		end
	end

	//% Synchronization for WRSTRB.
	always @(posedge clk_i) begin : WRSTRB_SYNC_LOGIC
		wrstrb_sync <= {MAX_DAUGHTERS{wrstrb_enable}};
	end

	//% Flops to capture the write address.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	(* S = "YES" *)
	reg [8:0] write_address[MAX_DAUGHTERS-1:0];

	//% Flops to capture logical_block_i (logical version of block).
	reg [8:0] block_address = {9{1'b0}};

	//% Block is grabbed when wr_ack is asserted.
	always @(posedge clk_i) begin
		if (wr_ack_o)
			block_address <= logical_block_i;
	end

	//% Flops to pass over to the history buffer. Same logic as output flops.
	reg [8:0] current_block = {9{1'b0}};
	//% Latch of current block.
	always @(posedge clk_i) begin
		if ((state == SAMPLE_LOW_PREP_HIGH && high_cells_sampled) || state == PREP_LOW_SAMPLE_HIGH) begin
			current_block <= block_address;
		end
	end
	
	integer wa_i;
	initial begin
		for (wa_i=0;wa_i<MAX_DAUGHTERS;wa_i=wa_i+1) begin
			write_address[wa_i] <= {9{1'b0}};
		end
	end
	
	//% Flops for enable.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	(* S = "YES" *)
	reg [MAX_DAUGHTERS-1:0] wr_enable = {MAX_DAUGHTERS{1'b0}};
	//% Enable grabbed at same time as block is.
	always @(posedge clk_i) begin : ENABLE_LOGIC
		if (wr_ack_o)
			wr_enable <= {MAX_DAUGHTERS{enable_i}};
	end

	integer wa_j;
	//% Capture the block passed from the block manager.
	always @(posedge clk_i) begin : WRITE_ADDRESS_LOGIC
		if (wr_ack_o) begin
			for (wa_j=0;wa_j<MAX_DAUGHTERS;wa_j=wa_j+1) begin
				write_address[wa_j] <= block_i[wa_j];
			end
		end
	end

	//% Enable the latching of the write address. We want latch_wr_address valid in SLPH/PLSH, so
	//% we register it a clock before. Note that there is no need to worry about high_cells_sampled because
	//% the intrinsic delay already does that.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *) 
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	(* S = "YES" *)
	reg [NUM_DAUGHTERS-1:0] latch_wr_address = {NUM_DAUGHTERS{1'b0}};
	always @(posedge clk_i) begin : LATCH_WR_ADDRESS_LOGIC
	   latch_wr_address <= {NUM_DAUGHTERS{(state == RESET_WAIT_2 || state == SAMPLE_LOW_TRANSFER_HIGH || state == TRANSFER_LOW_SAMPLE_HIGH)}};
	end
	
	// do_write_strobe goes high in SLPH and PLSH. It
	// takes 2 clocks to get there, so no worries about high cells sampling.
	
	(* S = "YES" *)
	wire do_write_strobe = ((state == SAMPLE_LOW_PREP_HIGH) || state == PREP_LOW_SAMPLE_HIGH);
	(* S = "YES" *)
	wire xdo_write_strobe;
	BUF xwrstrb(.I(do_write_strobe),.O(xdo_write_strobe));
	
	//% Write strobe. Same as latch_wr_address.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	(* S = "YES" *)
	reg [NUM_DAUGHTERS-1:0] wrstrb_enable = {NUM_DAUGHTERS{1'b0}};
	always @(posedge clk_i) begin : WRSTRB_ENABLE_LOGIC
		wrstrb_enable <= {NUM_DAUGHTERS{xdo_write_strobe}};
	end
	// Output registers.
	generate
		genvar d,i;
		for (d=0;d<NUM_DAUGHTERS;d=d+1) begin : DL
			wr_addr_gen wraddr(.wraddr_i({wr_enable[d],write_address[d]}),.CE(latch_wr_address[d]),.clk_i(clk_i),.wraddr_o(wr_o[d]));
			for (i=0;i<9;i=i+1) begin : WRFF
				// Debug write address registers.
				if (DEBUG_DB == d) begin : DBG
					(* INIT = 0 *) FDE dbg_wr_ff(.D(block_i[d][i]),.C(clk_i),.CE(latch_wr_address[d]),.Q(dbg_wr_o[i]));
				end
			end
			// WR[9] register
//			(* IOB = "TRUE" *) (* INIT = 0 *) FDE wren_ff(.D(wr_enable[d]),.C(clk_i),.CE(latch_wr_address[d]),.Q(wr_o[d][9]));
			// SSt register
			(* IOB = "TRUE" *) (* INIT = 0 *) FDE sst_ff(.D(sst_enable),.C(clk_i),.CE(1'b1),.Q(sst_o[d]));
			// SSp register
			(* IOB = "TRUE" *) (* INIT = 0 *) FDE ssp_ff(.D(ssp_enable),.C(ssp_clk_i),.CE(1'b1),.Q(ssp_o[d]));
			wrstrb_generator wrstrb_gen(.clkp_i(clk_i),.strb_i(wrstrb_enable[d]),.strb_o(wrstrb_o[d]));
		end
		// These don't depend on what the daughter is.
		// Debug WR[9] register
		(* INIT = 0 *) FDE dbg_wren_ff(.D(enable_i),.C(clk_i),.CE(latch_wr_address[0]),.Q(dbg_wr_o[9]));
		// Debug versions of SSp, SSt register.
		(* INIT = 0 *) FDE dbg_ss_ff(.D(sst_enable),.C(clk_i),.CE(1'b1),.Q(dbg_sst_o));
		// Write strobe register.
		(* INIT = 0 *) FDE write_strobe_ff(.D(wrstrb_sync[0]),.C(clk_i),.CE(1'b1),.Q(write_strobe_o));
	endgenerate
	
	assign dbg_wrstrb_o = write_strobe_o;
	assign dbg_ssp_o = dbg_sst_o;
	// state == RESET_WAIT here kicks the block manager into aligning with us, enabling on the first
	// block. Otherwise we want phase = 1 in SLTH/PLSH: SLTH is where the ack goes out.
	assign wr_phase_o = (state == RESET_SYNC && !sync_i) || 
								( state == SAMPLE_LOW_TRANSFER_HIGH || state == PREP_LOW_SAMPLE_HIGH);
	assign wr_ack_o = wr_ack;

	assign logical_block_o = current_block;
endmodule

