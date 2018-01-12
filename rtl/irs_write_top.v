`timescale 1ns / 1ps
//% @brief IRS write top.
module irs_write_top(
		clk_i,
		smp_start_clk_i,
		wr_strb_clk_i,
		rst_i,
		
		hist_offset_i,
		hist_req_i,
		hist_block_o,
		hist_ack_o,
		
		lock_block_i,
		lock_req_i,
		lock_ack_o,
		
		free_block_i,
		free_req_i,
		free_ack_o,
		
		ped_mode_i,
		ped_address_i,
		ped_sample_i,

		enable_i,
		active_o,
		sampling_o,
		sampling_ce_o,
		write_strobe_o,
		block_set_o,
		
		d1_wr_o, d2_wr_o, d3_wr_o, d4_wr_o,
		d1_wrstrb_o, d2_wrstrb_o, d3_wrstrb_o, d4_wrstrb_o,
		d1_tsa_o, d2_tsa_o, d3_tsa_o, d4_tsa_o,
		d1_tsa_close_o, d2_tsa_close_o, d3_tsa_close_o, d4_tsa_close_o,
		d1_mode_i, d2_mode_i, d3_mode_i, d4_mode_i,
		d1_power_i, d2_power_i, d3_power_i, d4_power_i
    );

	parameter NUM_DAUGHTERS = 4;
	parameter MAX_DAUGHTERS = 4;

	input clk_i;
	input smp_start_clk_i;
	input wr_strb_clk_i;
	input rst_i;

	input [8:0] hist_offset_i;
	input hist_req_i;
	output [8:0] hist_block_o;
	output hist_ack_o;
	
	input [8:0] lock_block_i;
	input lock_req_i;
	output lock_ack_o;
	
	input [8:0] free_block_i;
	input free_req_i;
	output free_ack_o;
	
	input ped_mode_i;
	input [8:0] ped_address_i;
	input ped_sample_i;
	
	input enable_i;
	output [MAX_DAUGHTERS-1:0] active_o;
	output sampling_o;
	output sampling_ce_o;
	output write_strobe_o;
	output block_set_o;
	
	output [9:0] d1_wr_o;
	output [9:0] d2_wr_o;
	output [9:0] d3_wr_o;
	output [9:0] d4_wr_o;
	
	output d1_wrstrb_o;
	output d2_wrstrb_o;
	output d3_wrstrb_o;
	output d4_wrstrb_o;
	
	output d1_tsa_o;
	output d2_tsa_o;
	output d3_tsa_o;
	output d4_tsa_o;
	
	output d1_tsa_close_o;
	output d2_tsa_close_o;
	output d3_tsa_close_o;
	output d4_tsa_close_o;
	
	input d1_power_i;
	input d2_power_i;
	input d3_power_i;
	input d4_power_i;
	
	input d1_mode_i;
	input d2_mode_i;
	input d3_mode_i;
	input d4_mode_i;
	
	/// VECTORIZE IRS INPUTS

	// VECTORIZE INPUTS
	wire [9:0] wr_o [MAX_DAUGHTERS-1:0];
	wire [MAX_DAUGHTERS-1:0] wrstrb_o;
	wire [MAX_DAUGHTERS-1:0] tsa_o;
	wire [MAX_DAUGHTERS-1:0] tsa_close_o;
	wire [MAX_DAUGHTERS-1:0] power_i;
	wire [MAX_DAUGHTERS-1:0] mode_i;
	
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

	`VECOUT( wr_o );
	`VECOUT( wrstrb_o );
	`VECOUT( tsa_o );
	`VECOUT( tsa_close_o );
	`VECIN( power_i );
	`VECIN( mode_i );
	
	`undef VECIN
	`undef VECOUT

	//////////////////////////////////////////////////////
	//
	// SIGNALS
	//
	//////////////////////////////////////////////////////

	//% LOGICAL block that's written. Maps to physical in the readout module.
	wire [9:0] block_wr;

	//% Pauses the digitizer. From IRS manager to block manager.
	wire irs_pause;

	//% Debug lines from IRS manager.
	wire [7:0] debug_irs_manager;

	//% Write block, logical. From block manager.
	wire [8:0] write_block_logical;
	//% Write blocks, physical. One per DB.
	wire [8:0] write_block_physical[MAX_DAUGHTERS-1:0];
	//% Write blocks, implemented. One per DB.
	wire [8:0] write_block_implement[MAX_DAUGHTERS-1:0];

	reg block_sync = 0;
	//////////////////////////////////////////////////////
	//
	// SYNCHRONIZER
	//
	//////////////////////////////////////////////////////

	// The synchronizer keeps us in phase even through pauses/stops/starts.
	// Whenever the block write starts up again, it waits until block_sync
	// goes high. Block sync then is the 'sampling_ce_o'.
	always @(posedge clk_i or posedge rst_i) begin : SYNC_LOGIC
		if (rst_i) block_sync <= 0;
		else block_sync <= ~block_sync;
	end

	//////////////////////////////////////////////////////
	//
	// IRS HISTORY BUFFER
	//
	//////////////////////////////////////////////////////

	wire [8:0] written_block;

	irs_history_buffer 
		history_buffer(.clk_i(clk_i),.rst_i(rst_i),
							.write_block_i({1'b0,written_block}),
							.write_strobe_i(write_strobe_o),
							.block_req_i(hist_req_i),
							.nprev_i(hist_offset_i),
							.block_o(hist_block_o),
							.block_ack_o(hist_ack_o));
	
	//////////////////////////////////////////////////////
	//
	// IRS MANAGER
	//
	//////////////////////////////////////////////////////
	
	
	// This is the simplest IRS manager out there:
	// a single-buffer manager. Its lock interface and
	// free interface simply count: any lock request
	// pauses IRS sampling until the free strobes
	// count it down to 0.
	irs_single_buffer_manager_v3
			irs_manager(.clk_i(clk_i),
							.rst_i(rst_i),
							.lock_i(1'b1),

							.lock_address_i(lock_block_i),
							.lock_strobe_i(lock_req_i),
							.lock_ack_o(lock_ack_o),

							.free_address_i(free_block_i),
							.free_strobe_i(free_req_i),
							.free_ack_o(free_ack_o),

							.irs_pause_o(irs_pause),
							.debug_o(debug_irs_manager)
							);


		//////////////////////////////////////////////////////
		//
		// BLOCK MANAGER
		//
		//////////////////////////////////////////////////////
																
		irs_simple_block_manager_v3 
				block_manager(.clk_i(clk_i),
								  .rst_i(rst_i),
								  .en_i(enable_i),
								  .pause_i(irs_pause),
								  
								  .blk_phase_i(write_block_phase),
								  .blk_en_o(write_block_enable),
								  .blk_rst_o(write_block_reset),
								  .blk_o(write_block_logical),
								  .blk_ack_i(write_block_acknowledge),
								  
								  .ped_mode_i(ped_mode_i),
								  .ped_address_i(ped_address_i),
								  .ped_sample_i(ped_sample_i));	

		//////////////////////////////////////////////////////
		//
		// BLOCK MAPPING
		//
		//////////////////////////////////////////////////////

		//% Maps logic blocks to physical and implemented blocks. Physical blocks are actually unused.
		generate
			genvar mi;
			for (mi=0;mi<MAX_DAUGHTERS;mi=mi+1) begin : ML
				if (mi<NUM_DAUGHTERS) begin : MAP
					irs_block_write_map_v3 
						logical_block_map(.logical_i(write_block_logical),
												.mode_i(mode_i[mi]),
												.physical_o(write_block_physical[mi]),
												.impl_o(write_block_implement[mi]));	
				end
			end
		endgenerate

		//////////////////////////////////////////////////////
		//
		// WRITE CONTROLLER (quad)
		//
		//////////////////////////////////////////////////////

		// Write controller needs to be held in reset
		// if we're not sampling.
		
		

		irs_quad_write_controller_v6
			write_controller(.clk_i(clk_i),
								  .sync_i(block_sync),
								  .enable_i(write_block_enable),
								  .rst_i(write_block_reset),
								  .ssp_clk_i(smp_start_clk_i),
								  .wrstrb_clk_i(wr_strb_clk_i),
								  .write_strobe_o(write_strobe_o),
								  
								  .d1_block_i(write_block_implement[0]),
								  .d2_block_i(write_block_implement[1]),
								  .d3_block_i(write_block_implement[2]),
								  .d4_block_i(write_block_implement[3]),
								  .logical_block_i(write_block_logical),
								  .logical_block_o(written_block),
								  .wr_phase_o(write_block_phase),
								  .wr_ack_o(write_block_acknowledge),
								  
								  .d1_ssp_o(tsa_o[0]),
								  .d1_sst_o(tsa_close_o[0]),
								  .d1_wrstrb_o(wrstrb_o[0]),
								  .d1_wr_o(wr_o[0]),

								  .d2_ssp_o(tsa_o[1]),
								  .d2_sst_o(tsa_close_o[1]),
								  .d2_wrstrb_o(wrstrb_o[1]),
								  .d2_wr_o(wr_o[1]),

								  .d3_ssp_o(tsa_o[2]),
								  .d3_sst_o(tsa_close_o[2]),
								  .d3_wrstrb_o(wrstrb_o[2]),
								  .d3_wr_o(wr_o[2]),

								  .d4_ssp_o(tsa_o[3]),
								  .d4_sst_o(tsa_close_o[3]),
								  .d4_wrstrb_o(wrstrb_o[3]),
								  .d4_wr_o(wr_o[3]),
								  
									.dbg_wrstrb_o(wrstrb_int_o),
									.dbg_sst_o(dbg_sst_o),
									.dbg_ssp_o(dbg_ssp_o),
									.dbg_wr_o(dbg_wr_o),
									.dbg_state_o(dbg_wr_state)
								  );
	assign block_set_o = dbg_sst_o;
	assign active_o = power_i & {MAX_DAUGHTERS{enable_i}};
	// Note that this is technically incorrect when enable_i is lowered: sampling_ce_o being
	// tied high means that it very rapidly masks off triggers after sampling is disabled.
	// Who Cares.
	assign sampling_o = write_block_enable || ped_mode_i;
	assign sampling_ce_o = block_sync;
endmodule
