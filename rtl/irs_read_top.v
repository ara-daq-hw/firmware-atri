`timescale 1ns / 1ps
`include "trigger_defs.vh"
//% Top-level module for IRS readout. Maasssive amount of ports.
module irs_read_top(
		// IRS readout interfaces.
		d1_irsdat_i, d1_irssmp_o, d1_irsch_o, d1_irssmpall_o, d1_irsrd_o, d1_irsrden_o, d1_irsmode_i,
		d2_irsdat_i, d2_irssmp_o, d2_irsch_o, d2_irssmpall_o, d2_irsrd_o, d2_irsrden_o, d2_irsmode_i,
		d3_irsdat_i, d3_irssmp_o, d3_irsch_o, d3_irssmpall_o, d3_irsrd_o, d3_irsrden_o, d3_irsmode_i,
		d4_irsdat_i, d4_irssmp_o, d4_irsch_o, d4_irssmpall_o, d4_irsrd_o, d4_irsrden_o, d4_irsmode_i,
		// IRS conversion interface
		d1_start_o, d1_clr_o, d1_ramp_o,
		d2_start_o, d2_clr_o, d2_ramp_o,
		d3_start_o, d3_clr_o, d3_ramp_o,
		d4_start_o, d4_clr_o, d4_ramp_o,
		// Block buffer interface
		block_dat_i, block_empty_i, block_rd_o,
		// Trigger info interface
		trig_info_i, trig_info_addr_o, trig_info_rd_o,
		// Event FIFO interface
		event_dat_o, event_cnt_i, event_wr_o,
		// Default mask interface (from WISHBONE)
		irs_addr_o,
		irs_mask_i,
		// Free interface
		free_block_o, free_req_o, free_ack_i,
		// System clock.
		clk_i,
		// Digitizer subsystem reset.
		rst_i,
		// Reset acknowledge
		rst_ack_o,
		// Test mode (bypass inputs, replace with {STACK,CH,SMP} to make sure readout is okay)
		test_mode_i, 
		// Readout is ready and not blocked.
		readout_ready_o,
		// Error.
		readout_err_o,
		// Readout delay from first trigger
		readout_delay_i,
		// Debug
		debug_o
 );

	// FIXME MAKE THIS REAL
	parameter [5:0] DEFAULT_STATION = 6'h00;
	parameter NUM_DAUGHTERS = 4;
	localparam MAX_DAUGHTERS = 4;
	localparam NUM_L4 = `SCAL_NUM_L4;
	localparam INFO_BITS= `INFO_BITS;
	`include "clogb2.vh"
	localparam NL4_BITS = clogb2(NUM_L4-1);
	localparam NMXD_BITS = clogb2(MAX_DAUGHTERS-1);

	input [11:0] d1_irsdat_i;
	output [5:0] d1_irssmp_o;
	output [2:0] d1_irsch_o;
	output d1_irssmpall_o;
	output [9:0] d1_irsrd_o;
	output d1_irsrden_o;
	input d1_irsmode_i;
	output d1_start_o;
	output d1_clr_o;
	output d1_ramp_o;

	input [11:0] d2_irsdat_i;
	output [5:0] d2_irssmp_o;
	output [2:0] d2_irsch_o;
	output d2_irssmpall_o;
	output [9:0] d2_irsrd_o;
	output d2_irsrden_o;
	input d2_irsmode_i;
	output d2_start_o;
	output d2_clr_o;
	output d2_ramp_o;

	input [11:0] d3_irsdat_i;
	output [5:0] d3_irssmp_o;
	output [2:0] d3_irsch_o;
	output d3_irssmpall_o;
	output [9:0] d3_irsrd_o;
	output d3_irsrden_o;
	input d3_irsmode_i;
	output d3_start_o;
	output d3_clr_o;
	output d3_ramp_o;

	input [11:0] d4_irsdat_i;
	output [5:0] d4_irssmp_o;
	output [2:0] d4_irsch_o;
	output d4_irssmpall_o;
	output [9:0] d4_irsrd_o;
	output d4_irsrden_o;
	input d4_irsmode_i;
	output d4_start_o;
	output d4_clr_o;
	output d4_ramp_o;

	input [71:0] block_dat_i;
	input block_empty_i;
	output block_rd_o;
	
	input [INFO_BITS-1:0] trig_info_i;
	output [NL4_BITS-1:0] trig_info_addr_o;
	output trig_info_rd_o;
	
	output [8:0] free_block_o;
	output free_req_o;
	input free_ack_i;

	output [15:0] event_dat_o;
	input [15:0] event_cnt_i;
	output event_wr_o;

	output [NMXD_BITS-1:0] irs_addr_o;
	input [7:0] irs_mask_i;

	input clk_i;
	input rst_i;
	output rst_ack_o;
	input test_mode_i;
	output readout_ready_o;
	output [7:0] readout_err_o;
	input [7:0] readout_delay_i;

	output [52:0] debug_o;

	////////////////////////////////////////////////
	// VECTORIZE IRS INPUTS
	////////////////////////////////////////////////

	`define VECIN( name ) \
		assign name [ 0 ] = d1_``name ; 	\
		assign name [ 1 ] = d2_``name ;  \
		assign name [ 2 ] = d3_``name ;  \
		assign name [ 3 ] = d4_``name
	`define VECOUT( name ) \
		assign d1_``name = name [ 0 ];   \
		assign d2_``name = name [ 1 ];   \
		assign d3_``name = name [ 2 ];   \
		assign d4_``name = name [ 3 ]
		

	wire [11:0] irsdat_i[MAX_DAUGHTERS-1:0];
	`VECIN( irsdat_i );
	wire [5:0] irssmp_o[MAX_DAUGHTERS-1:0];
	`VECOUT( irssmp_o );
	wire [2:0] irsch_o[MAX_DAUGHTERS-1:0];
	`VECOUT( irsch_o );
	wire irssmpall_o[MAX_DAUGHTERS-1:0];
	`VECOUT( irssmpall_o );
	wire [9:0] irsrd_o[MAX_DAUGHTERS-1:0];
	`VECOUT( irsrd_o );
	wire [MAX_DAUGHTERS-1:0] irsrden_o;
	`VECOUT( irsrden_o );
	wire [MAX_DAUGHTERS-1:0] irsmode_i;
	`VECIN( irsmode_i );
	wire [MAX_DAUGHTERS-1:0] start_o;
	`VECOUT( start_o );
	wire [MAX_DAUGHTERS-1:0] clr_o;
	`VECOUT( clr_o );
	wire [MAX_DAUGHTERS-1:0] ramp_o;	
	`VECOUT( ramp_o );
	`undef VECIN
	`undef VECOUT
	
	////////////////////////////////////////////////
	// PICOBLAZE
	////////////////////////////////////////////////
	
	//% PicoBlaze event data (headers, etc.)
	wire [15:0] pb_event_dat;
	//% PicoBlaze event data write.
	wire pb_event_wr;
	//% DMA event data;
	wire [15:0] dma_event_dat;
	//% DMA event data write.
	wire dma_event_wr;
	//% DMA is active (multiplex select)
	wire dma_active;

	//% Multiplexed data.
	reg [15:0] event_data = {16{1'b0}};
	//% Event data write (muxed).
	reg event_data_wr = 0;
	
	//% PicoBlaze->DMA address
	wire [2:0] pb_dma_addr;
	//% PicoBlaze->DMA data
	wire [7:0] pb_to_dma_data;
	//% DMA->PicoBlaze data
	wire [7:0] dma_to_pb_data;
	//% PicoBlaze->DMA write strobe
	wire pb_dma_wr;
	
	//% PicoBlaze -> IRS mask data
	wire [7:0] pb_irs_mask;
	//% PicoBlaze -> IRS mask write strobe
	wire pb_irs_wr;
	//% IRS ready bitmask
	wire [MAX_DAUGHTERS-1:0] pb_irs_ready;
	//% IRS active bitmask
	wire [MAX_DAUGHTERS-1:0] pb_irs_active;
	
	// FIXME: make this real
	assign pb_irs_active = {{MAX_DAUGHTERS-NUM_DAUGHTERS{1'b0}},{NUM_DAUGHTERS{1'b1}}};
	
	//% Flag to begin IRS readout.
	wire [MAX_DAUGHTERS-1:0] pb_irs_go;

	//% DMA completion flag.
	wire dma_complete;

	//% Debug
	wire [17:0] pb_debug;
	
	irs_readout_processor rdproc(.block_dat_i(block_dat_i),
										  .block_empty_i(block_empty_i),
										  .block_rd_o(block_rd_o),
										  
										  .trig_info_i(trig_info_i),
										  .trig_info_addr_o(trig_info_addr_o),
										  .trig_info_rd_o(trig_info_rd_o),
										  
										  .event_dat_o(pb_event_dat),
										  .event_cnt_i(event_cnt_i),
										  .event_wr_o(pb_event_wr),

										  .dma_addr_o(pb_dma_addr),
										  .dma_dat_o(pb_to_dma_data),
										  .dma_dat_i(dma_to_pb_data),
										  .dma_wr_o(pb_dma_wr),
										  .dma_done_i(dma_complete),
										  // Free interface...
										  .free_block_o(free_block_o),
										  .free_req_o(free_req_o),
										  .free_ack_i(free_ack_i),
										  										  
										  .irs_addr_o(irs_addr_o),
										  .irs_mask_o(pb_irs_mask),
										  .irs_mask_i(irs_mask_i),
										  .irs_wr_o(pb_irs_wr),
										  .irs_rdy_i(pb_irs_ready),
										  .irs_active_i(pb_irs_active),
										  .irs_go_o(pb_irs_go),
										  .readout_ready_o(readout_ready_o),
										  .readout_delay_i(readout_delay_i),
										  .readout_err_o(readout_err_o),
										  .clk_i(clk_i),
										  .rst_i(rst_i),
										  .debug_o(pb_debug));

	////////////////////////////////////////////////
	// DMA CONTROLLER
	////////////////////////////////////////////////
	//% Data from each IRS.
	wire [15:0] irs_output_data[MAX_DAUGHTERS-1:0];
	//% Data valid from each IRS
	wire [MAX_DAUGHTERS-1:0] irs_output_valid;
	//% Data empty from each IRS
	wire [MAX_DAUGHTERS-1:0] irs_output_empty;
	//% Multiplexed event data.
	reg [15:0] irs_event_data = {16{1'b0}};
	//% Address of IRS selected.
	wire [NMXD_BITS-1:0] irs_event_addr;
	//% Data is valid
	reg irs_event_valid;
	//% Selected IRS is empty.
	reg irs_event_empty;
	//% Read flag
	wire irs_event_read;
	wire [31:0] dma_debug;
	irs_dma_controller #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) dma(.clk_i(clk_i),.rst_i(rst_i),
								  .addr_i(pb_dma_addr),
								  .dat_o(dma_to_pb_data),
								  .dat_i(pb_to_dma_data),
								  .wr_i(pb_dma_wr),
								  .event_dat_o(dma_event_dat),
								  .event_wr_o(dma_event_wr),
								  .active_o(dma_active),
								  .irs_dat_i(irs_event_data),
								  .irs_addr_o(irs_event_addr),
								  .irs_valid_i(irs_event_valid),
								  .irs_empty_i(irs_event_empty),
								  .irs_read_o(irs_event_read),
								  .debug_o(dma_debug));
	//% DMA completes when dma_active falls.
	SYNCEDGE #(.EDGE("FALLING"), .LATENCY(0)) dma_complete_gen(.I(dma_active),.O(dma_complete),.CLK(clk_i));


	//% Multiplex the IRS data.
	always @(posedge clk_i) begin : IRS_EVENT_DATA_LOGIC
		irs_event_data <= irs_output_data[irs_event_addr];
	end
	// Valid and empty can't be muxed like this. They need to be
	// muxed directly.
	//% And generate the valid.
	always @(*) begin : IRS_VALID_LOGIC
		irs_event_valid <= irs_output_valid[irs_event_addr];
	end
	//% and empty
	always @(*) begin : IRS_EMPTY_LOGIC
		irs_event_empty <= irs_output_empty[irs_event_addr];
	end

	////////////////////////////////////////////////
	// IRS READOUT
	////////////////////////////////////////////////

	// FIXME: make this real
	wire [5:0] station = DEFAULT_STATION;
	//% Channel mask (from PicoBlaze)
	reg [7:0] irs_ch_mask[NUM_DAUGHTERS-1:0];
	//% IRS busy output. Inverted to make IRS ready.
	wire [MAX_DAUGHTERS-1:0] irs_busy;

	// IRS ready is just !irs_busy.
	assign pb_irs_ready = ~irs_busy;

	//% IRS read strobe, from DMA controller.
	wire [MAX_DAUGHTERS-1:0] irs_read_strobe;

	//% Reset acks.
	wire [MAX_DAUGHTERS-1:0] irs_rdout_reset_ack;

	//% Remapped (physical) blocks for each IRS.
	wire [8:0] read_block_physical[MAX_DAUGHTERS-1:0];
	//% Remapped (implemented) blocks for each IRS. Not used.
	wire [8:0] read_block_implement[MAX_DAUGHTERS-1:0];
	generate
		genvar i;
		for (i=0;i<MAX_DAUGHTERS;i=i+1) begin : IL
			if (i<NUM_DAUGHTERS) begin : IRS
				initial irs_ch_mask[i] <= {8{1'b0}};
				always @(posedge clk_i)
					if (irs_addr_o == i && pb_irs_wr) irs_ch_mask[i] <= pb_irs_mask;
				assign irs_read_strobe[i] = (irs_event_read) && (irs_event_addr == i);

				// Fanout from block_dat_i is too large.
				reg [8:0] block_addr_store = {9{1'b0}};
				always @(posedge clk_i) begin
					block_addr_store <= block_dat_i;
				end
				// Fanout from irsmode_i is too high.
				reg irsmode_store = 0;
				always @(posedge clk_i) begin
					irsmode_store <= irsmode_i[i];
				end
				
				// Map the logical blocks to the physical blocks for readout.
				irs_block_write_map_v3 rdmap(.logical_i(block_addr_store),
												  .mode_i(irsmode_store),
												  .physical_o(read_block_physical[i]),
												  .impl_o(read_block_implement[i]));
				// Block readout gets read_block_physical. The only place where
				// logical blocks get used is in a pedestal address: this is why
				// it's actually cleaner to just use the automatic pedestal address advance.
				irs_block_readout_v3 #(.STACK_NUMBER(i)) 
										   rdout(.clk_i(clk_i), .rst_i(rst_i),.rst_ack_o(irs_rdout_reset_ack[i]),
												   .test_mode_i(test_mode_i),
													.station_i(station),
													.raddr_i(read_block_physical[i]),
													.raddr_stb_i(pb_irs_go[i]),
													.ch_mask_i(irs_ch_mask[i]),
													.irs_mode_i(irsmode_store),
													
													.irs_rd_o(irsrd_o[i]),
													.irs_rden_o(irsrden_o[i]),
													.irs_smp_o(irssmp_o[i]),
													.irs_ch_o(irsch_o[i]),
													.irs_smpall_o(irssmpall_o[i]),
													.irs_dat_i(irsdat_i[i]),
													.irs_start_o(start_o[i]),
													.irs_clr_o(clr_o[i]),
													.irs_ramp_o(ramp_o[i]),
													
													.irs_busy_o(irs_busy[i]),
													
													.irs_dat_o(irs_output_data[i]),
													.irs_valid_o(irs_output_valid[i]),
													.irs_empty_o(irs_output_empty[i]),
													.irs_rd_i(irs_read_strobe[i]));
			end else begin : DUM
				assign irs_read_strobe[i] = 1'b0;
				assign irs_rdout_reset_ack[i] = rst_i;
				assign irs_output_data[i] = {16{1'b0}};
				assign irs_output_valid[i] = 0;
				assign irs_output_empty[i] = 1;
				assign irs_busy[i] = 1;
				assign clr_o[i] = 0;
				assign start_o[i] = 0;
				assign irssmpall_o[i] = 0;
				assign irsch_o[i] = 0;
				assign irssmp_o[i] = 0;
				assign irsrden_o[i] = 0;
				assign irsrd_o[i] = {9{1'b0}};
			end
		end
	endgenerate

	//% Mux the PicoBlaze and DMA outputs
	always @(posedge clk_i) begin : EVENT_DATA_LOGIC
		if (dma_active) event_data <= dma_event_dat;
		else event_data <= pb_event_dat;
	end
	//% Mux the writes too
	always @(posedge clk_i) begin : EVENT_DATA_WR_LOGIC
		event_data_wr <= (dma_active && dma_event_wr) || (!dma_active && pb_event_wr);
	end

	assign event_dat_o = event_data;
	assign event_wr_o = event_data_wr;
	assign rst_ack_o = &irs_rdout_reset_ack;

	// A PicoBlaze debug needs basically:
	// 10 bit program counter
	// 8 bit inout
	// We'll delay everything by a clock to mux the ins/outs together.
	// For the remaining bits we'll grab
	// block_empty_i (1)
	// irs_go[0] (1)
	// dma_active (1)
	// dma_addr (2)
	// irs_busy (1)
	// event count (16)
	// this is 40 total

/** PicoBlaze debug. */
	assign debug_o[17:0] = pb_debug;
	assign debug_o[18] = block_empty_i;
	assign debug_o[19] = dma_active;
	assign debug_o[20 +: 16] = event_data;
	assign debug_o[36 +: 16] = dma_debug[15:0];
/** DMA debug. */
/*
	assign debug_o[31:0] = dma_debug;
	assign debug_o[32] = block_empty_i;
	assign debug_o[33] = irs_busy[0];
	assign debug_o[34] = pb_irs_go[0];
	assign debug_o[35] = event_data_wr;
	assign debug_o[36] = irs_event_valid;
	assign debug_o[37] = irs_event_empty;
	assign debug_o[39:38] = 2'b00;
	// event data is delayed by 1 clock!
*/
/** IRS debug. */
/*
	assign debug_o[0 +: 12] = d1_irsdat_i;
	assign debug_o[12 +: 6] = d1_irssmp_o;
	assign debug_o[18 +: 3] = d1_irsch_o;
	assign debug_o[21 +: 10] = d1_irsrd_o;
	assign debug_o[31] = d1_irssmpall_o;
	assign debug_o[32] = d1_irsrden_o;
	assign debug_o[33] = d1_irsmode_i;
	assign debug_o[34] = d1_start_o;
	assign debug_o[35] = d1_clr_o;
	assign debug_o[36] = d1_ramp_o;
	assign debug_o[37] = pb_irs_go[0];
*/
endmodule
