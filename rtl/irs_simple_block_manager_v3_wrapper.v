`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Small wrapper to use the _v3-style modules, which separate the manager, the
// block manager, and the block write.
//////////////////////////////////////////////////////////////////////////////////
module irs_simple_block_manager_v3_wrapper(
		input clk_i,								// system clock
		input rst_i,								// reset
		input clk_wrstrb,							// writestrobe clock
		
		output tsa_o,								// SSp
		output tsa_close_o,						// SSt

		output [9:0] block_wr_o,				// Block output.

		output [9:0] wr_o,						// WR outputs (to IOB)
		output wrstrb_o,							// WRSTRB output (to IOB)
		output wrstrb_int_o, 					//synchronized with clk_i

		input [8:0] lock_address_i,			// Block to lock.
		input lock_i,								// 1 if block is to be locked, 0 if to be unlocked.
		input unlock_i,							// Who knows what the hell this is for.
		input lock_strobe_i,						// When 1, perform action indicated by lock_i.
		output lock_ack_o,						// Acknowledge lock action.

		input [8:0] free_address_i,			// Block to be freed.
		input free_strobe_i,						// Perform free action.
		output free_ack_o,						// Acknowledge free action.

		output dead_o,								// Indicates IRS is not available for readout.
		input dead_clear_i,						// Clear the dead status.

		input enable_i,							// General enable.
		input ped_mode_i,							// Pedestal mode.
		input [8:0] ped_address_i,				// Pedestal address.
		input ped_clear_i,						// Pedestal clear (repeat single-block sample)

		input irs_mode_i,							// IRS mode (IRS2 or IRS3)
		
		output locked,								// block manager locked (?!)
		output [47:0] debug_o					// debug
    );

	// Connections between block manager and write controller.
	wire write_block_phase;			   // Current block phase (i.e. top half or bottom half of sample cells)
	wire [8:0] write_block_logical;	// Logical (linear address) block address
	wire [8:0] write_block_physical;	// Physical(i.e. after IRS2/IRS3 switch) block address
	wire [8:0] write_block_implement;// Implemented (i.e. what gets put on WR[8:0]) block address
	wire write_block_enable;			// Enable the write controller.
	wire write_block_acknowledge;		// Acknowledge from the write controller.

	// Pedestal acknowledge.
	wire ped_ack;

	// Pause block manager.
	wire irs_pause;

	// IRS single-buffer manager.
	wire [7:0] debug_irs_manager;
	irs_single_buffer_manager_v3
			irs_manager(.clk_i(clk_i),
							.lock_i(lock_i),
							.lock_strobe_i(lock_strobe_i),
							.lock_ack_o(lock_ack_o),
							.free_address_i(free_address_i),
							.free_strobe_i(free_strobe_i),
							.free_ack_o(free_ack_o),
							.irs_pause_o(irs_pause),
							.debug_o(debug_irs_manager)
							);

	// Luca added a "lock_i" and "unlock_i" interface, which doesn't really
	// make much sense (it's a race condition) in a more intelligent
	// block manager/IRS manager.
	// Thankfully if you look at the Verilog it doesn't matter.
	
		
	// IRS simple block manager.
	irs_simple_block_manager_v3 
			block_manager(.clk_i(clk_i),
							  .rst_i(rst_i),
							  .en_i(enable_i),
							  .pause_i(irs_pause),
							  
							  .blk_phase_i(write_block_phase),
							  .blk_en_o(write_block_enable),
							  .blk_o(write_block_logical),
							  .blk_ack_i(write_block_acknowledge),
							  
							  .ped_mode_i(ped_mode_i),
							  .ped_address_i(ped_address_i),
							  .ped_ack_o(ped_ack));
	
	// Logical -> physical block map.
	irs_block_write_map_v3 
		logical_block_map(.logical_i(write_block_logical),
								.mode_i(irs_mode_i),
								.physical_o(write_block_physical),
								.impl_o(write_block_implement));

	// IRS write controller.
	wire dbg_ssp;
	wire dbg_sst;
	wire [9:0] dbg_wr_o;
	wire [3:0] dbg_wr_state;
	// Because the clocks get mucked with, the write controller needs
	// to be reset when we first enable it. Future disables don't need
	// to reset it.
	reg seen_first_enable = 0;
	always @(posedge clk_i) begin
		if (enable_i)
			seen_first_enable <= 1;
	end

	irs_write_controller_v3
		write_controller(.clk_i(clk_i),
							  .enable_i(write_block_enable),
							  .rst_i(!seen_first_enable),
							  .ssp_clk_i(~clk_i),
							  .wrstrb_clk_i(clk_wrstrb),
							  
							  .wr_block_i(write_block_implement),
							  .wr_phase_o(write_block_phase),
							  .wr_ack_o(write_block_acknowledge),
							  
							  .ssp_o(tsa_o),
							  .sst_o(tsa_close_o),
							  .wrstrb_o(wrstrb_o),
							  .wr_o(wr_o),
								.dbg_wrstrb_o(wrstrb_int_o),
								.dbg_sst_o(dbg_sst_o),
								.dbg_ssp_o(dbg_ssp_o),
								.dbg_wr_o(dbg_wr_o),
								.dbg_state_o(dbg_wr_state)
							  );
	
	assign block_wr_o = write_block_physical;

	assign debug_o[0] = enable_i;
	assign debug_o[1] = irs_pause;
	assign debug_o[2] = lock_strobe_i;
	assign debug_o[3] = lock_i;
	assign debug_o[4] = lock_ack_o;
	assign debug_o[5] = free_strobe_i;
	assign debug_o[6] = free_ack_o;
	assign debug_o[7] = write_block_phase;
	assign debug_o[8] = write_block_enable;
	assign debug_o[9] = write_block_acknowledge;
	assign debug_o[18:10] = write_block_physical;
	assign debug_o[26:19] = debug_irs_manager;
	assign debug_o[27] = wrstrb_int_o;
	assign debug_o[28] = dbg_ssp;
	assign debug_o[29] = dbg_sst;
	assign debug_o[39:30] = dbg_wr_o;
	assign debug_o[43:40] = dbg_wr_state;
	assign locked = irs_pause;
endmodule
