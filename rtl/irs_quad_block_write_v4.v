// IRS write controller.

//% @brief IRS quad write controller.
//%
//% @gensymbol
//% MODULE irs_write_controller_v3
//% LPORT clk_i input
//% LPORT enable_i input
//% LPORT rst_i input
//% LPORT space
//% LPORT wr_block_i input
//% LPORT wr_phase_o output
//% LPORT wr_ack_o output
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
//% This, therefore, separates the block *fetch* from the block *write*. The block
//% fetching portions are purely digital. These, however, may need to be tuned for optimal
//% timing.
//%
//% It is possible to use the irs_write_controller to write a single block. The timing
//% diagram for this is:
//% @drawtiming
//% clk_i=0,wr_phase_o=1,wr_block_i=X,enable_i=0,wr_ack_o=0,wrstrb=0,sst=0,wr=X.
//% clk_i=1,sst=1.
//% clk_i=0.
//% clk_i=1,wr_phase_o=0.
//% clk_i=0,enable_i=1,wr_block_i="0x004".
//% clk_i=1,sst=0;wr_block_i=>wr="0x000".
//% clk_i=0.
//% clk_i=1,wr_phase_o=1,wrstrb=1,wr_ack_o=1.
//% clk_i=0;wr_ack_o=>enable_i=0;wr_block_i=X.
//% clk_i=1,sst=1,wrstrb=0.
//% clk_i=0.
//% @enddrawtiming
//%
//% Here "enable_i" is just qualified by the write phase of the block write desired - 
//% with an example block of "0x000" (sample cells 0-63), this is wr_phase_o = 0.
//% enable_i is then disabled by being qualified against !wr_ack_o.
//%
//% The write block must be present by the rising clock edge after wr_phase_o first
//% changes (i.e. the third rising clock edge in the diagram above). This is when the
//% block is clocked onto the WR outputs. wr_ack_o is asserted for only one clock cycle
//% (the same clock cycle that WRSTRB is asserted).
//%
//% SSp and WRSTRB are fine-timed, primarily using IODELAY2s. The 'nominal' SSp signal
//% goes off 1 clock cycle prior to SSt going high. The IODELAY2 delay is nominally
//% around 6 ns. The 'nominal' WRSTRB signal goes off the same clock cycle that SSt
//% changes, and then the IODELAY2 delay is nominally about 5 ns.
//%
//% These two values are tweakable up to 10 ns of delay or so.
//%
//% So the base timing there was (starting from the beginning)
//% at   -4 ns: SSp goes high
//% at    0 ns: SSt goes high
//% at   15 ns: SSp goes low
//% at   20 ns: SSt goes low, WR is asserted to the appropriate block.
//% at   25 ns: WRSTRB goes high
//% at   35 ns: WRSTRB goes low
//% at   36 ns: SSp goes high
//% at   40 ns: SSt goes high, WR is asserted to the appropriate block.
//% at   45 ns: WRSTRB goes high
//% at   55 ns: WRSTRB goes low.
//% at   56 ns: SSp goes low.
//% etc.
//%
//% This module generates output signals for up to 4 IRSes. The actual blocks written to the IRS
//% can be different, since the block inputs are implemented versions, and the output of the
//% block manager are logical versions.
module irs_quad_write_controller_v4(
		// System interface
		input clk_i,					//% System clock (1/32 sampling speed).
		input sync_i,					//% Synchronizer. Keeps us on the same phase of the clock until a reset.
		input enable_i, 				//% Begin writing to the IRS.
		input rst_i,					//% System reset.
		input ssp_clk_i,				//% Clock for the SSp timing strobe. Still 4X SSt, but offset in phase.
		input wrstrb_clk_i,			//% Clock for the write strobe going high. Still 4X SSt, offset in phase.
		
		// Output indicating that a write is occuring now. This occurs continuously.
		output write_strobe_o,
		
		// Interface to the block manager.
		input [8:0] d1_block_i,		//% Block value to use for Daughter 1.
		input [8:0] d2_block_i, 	//% Block value to use for Daughter 2.
		input [8:0] d3_block_i,		//% Block value to use for Daughter 3.
		input [8:0] d4_block_i, 	//% Block value to use for Daughter 4.
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
//	`VECOUT( ssp_o );
	`VECOUT( sst_o );
	`VECOUT( wr_o );
	`VECOUT( wrstrb_o );
	
	`undef VECIN
	`undef VECOUT
	
	`include "clogb2.vh"
	// WR is latched at the transition into SAMPLE_LOW_PREP_HIGH and PREP_LOW_SAMPLE_HIGH.
	// That means that wr_phase_o needs to be '1' in TRANSFER_LOW_SAMPLE_HIGH and SAMPLE_LOW_PREP_HIGH,
	// and 0 in SAMPLE_LOW_TRANSFER_HIGH and PREP_LOW_SAMPLE_HIGH.
	// wr_phase_o is only high in SAMPLE_LOW_PREP_HIGH if the high cells have been sampled.
	//
	localparam FSM_BITS = clogb2(5);
	localparam [FSM_BITS-1:0] RESET = 0;						  //% SST=0, WRSTRB=0, WR=X.
	localparam [FSM_BITS-1:0] RESET_WAIT = 1;               //% SST=0, WRSTRB=0, WR=X.
	localparam [FSM_BITS-1:0] SAMPLE_LOW_PREP_HIGH 		= 2; //% SST=1, WRSTRB=0, WR=HIGHBLOCK.
	localparam [FSM_BITS-1:0] SAMPLE_LOW_TRANSFER_HIGH = 3; //% SST=1, WRSTRB=1, WR=HIGHBLOCK.
	localparam [FSM_BITS-1:0] PREP_LOW_SAMPLE_HIGH		= 4; //% SST=0, WRSTRB=0, WR=LOWBLOCK.
	localparam [FSM_BITS-1:0] TRANSFER_LOW_SAMPLE_HIGH = 5; //% SST=0, WRSTRB=1, WR=LOWBLOCK.
	reg [FSM_BITS-1:0] state = RESET;							  //% State variable.
	assign dbg_state_o = state;
	
	//% Synchronization flop for SSp
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg ssp1_sync = 0;
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg ssp2_sync = 0;
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg ssp3_sync = 0;
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg ssp4_sync = 0;
	
	//% Copy of SSp sync for SSt
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg sst_sync = 0;
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
	//% Registered to ssp_sync on the next SSp rising edge, and sst_sync on the next clk_i edge.
	//% SSp/Sst go high on 2nd rising clock edge after ss_enable is true.
	wire ss_enable = (state == RESET && !rst_i) || (state == RESET_WAIT) || (state == PREP_LOW_SAMPLE_HIGH || state == TRANSFER_LOW_SAMPLE_HIGH);
	//% Registered to wrstrb_sync on next wrstrb clock rising edge. 
	//% WRSTRB goes high on 2nd rising clock edge after wrstrb_enable is true.
//	wire wrstrb_enable = (state == SAMPLE_LOW_TRANSFER_HIGH || state == TRANSFER_LOW_SAMPLE_HIGH);

	always @(posedge clk_i) begin : FSM_LOGIC
		if (rst_i) state <= RESET;
		else begin
			case (state)
				RESET: if (sync_i) state <= RESET_WAIT;
				RESET_WAIT: state <= SAMPLE_LOW_PREP_HIGH;
				SAMPLE_LOW_PREP_HIGH: state <= SAMPLE_LOW_TRANSFER_HIGH;
				SAMPLE_LOW_TRANSFER_HIGH: state <= PREP_LOW_SAMPLE_HIGH;
				PREP_LOW_SAMPLE_HIGH: state <= TRANSFER_LOW_SAMPLE_HIGH;
				TRANSFER_LOW_SAMPLE_HIGH: state <= SAMPLE_LOW_PREP_HIGH;
			endcase
		end
	end

	//% Acknowledge.
	always @(posedge clk_i) begin : ACK_LOGIC
		if (wr_ack) wr_ack <= 0;
		else if (((state == SAMPLE_LOW_PREP_HIGH && high_cells_sampled) || state == PREP_LOW_SAMPLE_HIGH) && enable_i) wr_ack <= 1;
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

	//% Synchronization of SSp to ssp_clk domain
	always @(posedge clk_i) begin : SSP_SYNC_LOGIC
		ssp1_sync <= ss_enable;
		ssp2_sync <= ss_enable;
		ssp3_sync <= ss_enable;
		ssp4_sync <= ss_enable;
	end

	//% Copy of SSp sync for SSt.
	always @(posedge clk_i) begin : SST_SYNC_LOGIC
		sst_sync <= ss_enable;
	end

	//% Synchronization for WRSTRB.
	always @(posedge clk_i) begin : WRSTRB_SYNC_LOGIC
		wrstrb_sync <= {MAX_DAUGHTERS{wrstrb_enable}};
	end

	//% Enable the latching of the write address. 1 cycle before PREP stages, so WR stable in PREP.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *) 
	(* KEEP = "TRUE" *)
	(* MAX_FANOUT = 1 *)
	reg [NUM_DAUGHTERS-1:0] latch_wr_address = {NUM_DAUGHTERS{1'b0}};
	always @(posedge clk_i) begin : LATCH_WR_ADDRESS_LOGIC
	   latch_wr_address <= {NUM_DAUGHTERS{(state == SAMPLE_LOW_PREP_HIGH || state == PREP_LOW_SAMPLE_HIGH)}};
	end
	
	//% Write strobe. Same as latch_wr_address.
	wire [NUM_DAUGHTERS-1:0] wrstrb_enable;

	(* IOB = "TRUE" *) 
	(* INIT = 0 *) 
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	FDE ssp0_ff(.D(ssp1_sync),.C(ssp_clk_i),.CE(1'b1),.Q(d1_ssp_o));
	(* IOB = "TRUE" *)
	(* INIT = 0 *) 
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	FDE ssp1_ff(.D(ssp2_sync),.C(ssp_clk_i),.CE(1'b1),.Q(d2_ssp_o));
	(* IOB = "TRUE" *) 
	(* INIT = 0 *) 
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	FDE ssp2_ff(.D(ssp3_sync),.C(ssp_clk_i),.CE(1'b1),.Q(d3_ssp_o));
	(* IOB = "TRUE" *) 
	(* INIT = 0 *) 
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* KEEP = "TRUE" *)
	FDE ssp3_ff(.D(ssp4_sync),.C(ssp_clk_i),.CE(1'b1),.Q(d4_ssp_o));


	// Output registers.
	generate
		genvar d,i;
		for (d=0;d<NUM_DAUGHTERS;d=d+1) begin : DL
			assign wrstrb_enable[d] = latch_wr_address[d];
			for (i=0;i<9;i=i+1) begin : WRFF
				// Write address registers.
				(* IOB = "TRUE" *) (* INIT = 0 *) FDE wr_ff(.D(block_i[d][i]),.C(clk_i),.CE(latch_wr_address[d]),.Q(wr_o[d][i]));
				// Debug write address registers.
				if (DEBUG_DB == d) begin : DBG
					(* INIT = 0 *) FDE dbg_wr_ff(.D(block_i[d][i]),.C(clk_i),.CE(latch_wr_address[d]),.Q(dbg_wr_o[i]));
				end
			end
			// WR[9] register
			(* IOB = "TRUE" *) (* INIT = 0 *) FDE wren_ff(.D(enable_i),.C(clk_i),.CE(latch_wr_address[d]),.Q(wr_o[d][9]));
			// SSt register
			(* IOB = "TRUE" *) (* INIT = 0 *) FDE sst_ff(.D(sst_sync),.C(clk_i),.CE(1'b1),.Q(sst_o[d]));
			// WRSTRB register
//			(* IOB = "TRUE" *) (* INIT = 0 *) FDE wrstrb_ff(.D(wrstrb_sync[d]),.C(wrstrb_clk_i),.CE(1'b1),.Q(wrstrb_o[d]));
			wrstrb_generator wrstrb_gen(.clkp_i(clk_i),.strb_i(wrstrb_enable[d]),.strb_o(wrstrb_o[d]));
		end
		// These don't depend on what the daughter is.
		// Debug WR[9] register
		(* INIT = 0 *) FDE dbg_wren_ff(.D(enable_i),.C(clk_i),.CE(latch_wr_address[0]),.Q(dbg_wr_o[9]));
		// Debug versions of SSp, SSt register.
		(* INIT = 0 *) FDE dbg_ss_ff(.D(sst_sync),.C(clk_i),.CE(1'b1),.Q(dbg_sst_o));
		// Write strobe register.
		(* INIT = 0 *) FDE write_strobe_ff(.D(wrstrb_sync[0]),.C(clk_i),.CE(1'b1),.Q(write_strobe_o));
	endgenerate
	
	assign dbg_wrstrb_o = write_strobe_o;
	assign dbg_ssp_o = dbg_sst_o;
	// state == RESET_WAIT here kicks the block manager into aligning with us, enabling on the first
	// block.
	assign wr_phase_o = ((state == SAMPLE_LOW_PREP_HIGH && high_cells_sampled) ||
								(state == TRANSFER_LOW_SAMPLE_HIGH)) || ( state == RESET_WAIT );
	assign wr_ack_o = wr_ack;
endmodule

