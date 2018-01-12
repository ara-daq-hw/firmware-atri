`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Replacement for the disaster of a trigger infrastructure in the previous
// firmware.
//////////////////////////////////////////////////////////////////////////////////

//% @file trigger_top_v2.v Contains trigger_top_v2: Top level trigger module.

//% @brief Top-level trigger module.
//%
//% @par Module Symbol
//% @gensymbol
//% MODULE trigger_top_v2
//% ENDMODULE
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% trigger_top_v2 is a top-level module for all of the triggering infrastructure
//% in the ATRI firmware. This module replaces a large amount of the poorly-organized
//% modules in atri_core.
//% \n\n
//% trigger_top_v2 does *not* contain the trigger infrastructure. This is assumed
//% to be generated outside this module. That is, the input lines to this module
//% are simply an array of single-bit signals that contain the triggering information
//% from each antenna.
//% 

`include "wb_interface.vh"
`include "trigger_defs.vh"

module trigger_top_v2(d1_trig_i, d2_trig_i, d3_trig_i, d4_trig_i,
							 d1_pwr_i, d2_pwr_i, d3_pwr_i, d4_pwr_i, 
							 fclk_i, sclk_i, sce_i, pps_flag_fclk_i,
							 
							 l4_ext_i,
							 
							 scal_wbif_io,
							 trig_wbif_io,

							 readout_ready_i,
							 disable_i,
							 disable_ce_i,
							 
							 mask_i,
							 
							 trig_o,
							 trig_l4_o,
							 trig_l4_new_o,
							 trig_delay_o,
							 trig_rf0_info_o,
							 trig_rf1_info_o,
							 debug_o);

   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

	//% Number of implemented daughters.
	parameter NUM_DAUGHTERS = 4;
	//% Maximum number of daughters (= number of input trigger ports).
	localparam MAX_DAUGHTERS = 4;
	//% Number of trigger bits per daughter (= number of TRG_P/N pairs per daughter)
	localparam NUM_TRIG = 8;
	//% Number of bits for the trigger info output.
	parameter INFO_BITS = 32;

	///// These are contained within scaler_defs.vh. DO NOT change here!
	
	//% Number of L1 scalers.
	parameter NUM_L1 = `SCAL_NUM_L1;
	//% Number of L2 scalers.
	parameter NUM_L2 = `SCAL_NUM_L2;
	//% Number of L3 scalers.
	parameter NUM_L3 = `SCAL_NUM_L3;
	//% Number of L4 scalers.
	parameter NUM_L4 = `SCAL_NUM_L4;
	//  Only 1 T1 scaler.
	
	//% Number of external L4 triggers
	parameter NUM_EXT_L4 = `SCAL_NUM_EXT_L4;
	
	///// Version parameters. These are local to this module. Change when the
	///// RF trigger top version changes, or a different module is used, etc.

	// Change these in trigger_defs.vh
	localparam [3:0] VER_TYPE   = `TRIG_VER_TYPE;
	localparam [3:0] VER_MONTH  = `TRIG_VER_MONTH;
	localparam [7:0] VER_DAY    = `TRIG_VER_DAY;
	localparam [3:0] VER_MAJOR  = `TRIG_VER_MAJOR;
	localparam [3:0] VER_MINOR  = `TRIG_VER_MINOR;
	localparam [7:0] VER_REV    = `TRIG_VER_REV;

	localparam NBLOCK_BITS = `NBLOCK_BITS;
	localparam PRETRG_BITS = `PRETRG_BITS;
	localparam DELAY_BITS = `DELAY_BITS;
	localparam TRIG_ONESHOT_BITS = `TRIG_ONESHOT_BITS;
	//%FIXME: addition from Patricks Patch: 3 lines
 	localparam TRIG_DELAY_VAL_BITS = `TRIG_DELAY_VAL_BITS;
 	`include "clogb2.vh"
 	localparam NUM_L1_BITS = clogb2(NUM_L1);
   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////

	////////// Trigger bits
	
	//% Daughter 1 trigger bits.
	input [NUM_TRIG-1:0] d1_trig_i;
	//% Daughter 2 trigger bits.
	input [NUM_TRIG-1:0] d2_trig_i;
	//% Daughter 3 trigger bits;
	input [NUM_TRIG-1:0] d3_trig_i;
	//% Daughter 4 trigger bits;
	input [NUM_TRIG-1:0] d4_trig_i;

	////////// Power infrastructure
	
	//% Indicate which Daughter 1 trigger bits come from boards with power
	input [NUM_TRIG-1:0] d1_pwr_i;
	//% Indicate which Daughter 2 trigger bits come from boards with power
	input [NUM_TRIG-1:0] d2_pwr_i;
	//% Indicate which Daughter 3 trigger bits come from boards with power
	input [NUM_TRIG-1:0] d3_pwr_i;
	//% Indicate which Daughter 4 trigger bits come from boards with power
	input [NUM_TRIG-1:0] d4_pwr_i;
	
	////////// External trigger inputs (non-RF)
	
	//% Non-RF trigger inputs. Cal and CPU currently.
	input [NUM_EXT_L4-1:0] l4_ext_i;
	
	////////// Clock infrastructure
	
	//% Fast clock (trigger-level clock)
	input fclk_i;
	//% Slow clock (interface clock)
	input sclk_i;
	//% Slow clock enable : this is used to update scalers/stuck-on detection. Nom. 1 kHz.
	input sce_i;
	//% PPS flag in the fclk domain
	input pps_flag_fclk_i;
	
	////////// WISHBONE interface
	
	//% Scaler interface.
	inout [`WBIF_SIZE-1:0] scal_wbif_io;
	//% Trigger control interface.
	inout [`WBIF_SIZE-1:0] trig_wbif_io;

	////////// Trigger interface
	
	//% Readout can handle a new trigger.
	input readout_ready_i;
	
	//% Disable triggers for this block.
	input disable_i;
	//% Disable clock enable: disable_i is only valid when disable_ce_i is asserted.
	input disable_ce_i;
	
	//% General-purpose external mask (from firmware). ORed with the T1 mask from WISHBONE.
	input mask_i;
	
	//% Output global trigger.
	output trig_o;
	//% Specifies which triggers are active.
	output [NUM_L4-1:0] trig_l4_o;
	//% Specifies which triggers have new info.
	output [NUM_L4-1:0] trig_l4_new_o;
	//% Trigger delay output. Number of cycles from the actual trigger to the trigger output.
	output [8:0] trig_delay_o;
	//% Output trigger information for RF0 trigger.
	output [INFO_BITS-1:0] trig_rf0_info_o;
	//% Output trigger information for RF1 trigger.
	output [INFO_BITS-1:0] trig_rf1_info_o;

	// Trigger debug.
	output [52:0] debug_o;

   ////////////////////////////////////////////////////
   //
	// TRIGGER CONTROL
	//
	////////////////////////////////////////////////////
	
	////// Interface signals from the trigger control interface.

	// The trigger control interface has a 16 byte address space.
	// The first 4 bytes are a trigger ID/version/date, exactly
	// like the firmware version.
	//
	// 0x00-0x03: id/version/date. Note: remaining registers *may*
	//            change based on this.
	// 0x04/0x05/0x06/0x07: L1 trigger mask.
	// 0x08/0x09/0x0A/0x0B: L2 trigger mask
	// 0x0C/0x0D: L3 trigger mask
	// 0x0E: L4 trigger mask.
	// 0x0F: Master trigger control (T1 mask, trigger subsystem reset, rsv db).
	//% Indicates which daughterboard stack should be used.
	wire [1:0] rsv_trig_db;
	//% Indicates the coincidence level of the RF1 trigger.
	wire [1:0] rf1_coincidence;
	
	//% L1 trigger mask.
	wire [NUM_L1-1:0] l1_mask;
	//% L2 trigger mask.
	wire [NUM_L2-1:0] l2_mask;
	//% L3 trigger mask.
	wire [NUM_L3-1:0] l3_mask;
	//% L4 mask (PPS/timed, random, surface RF, deep RF)
	wire [NUM_L4-1:0] l4_mask;
	
	////////////
	// Number of blocks/pretrigger wires.
	////////////
	// Note: the number of blocks is passed to whatever generates the trigger.
	// They do the stretching based on this. This is done because the object
	// generating the trigger might want to do something clever.
	//
	// The "number of pretrigger blocks" is actually the offset, from the trigger,
	// to the first block read out. So if "l4rf0_pretrigger" is, say, 30, and we
	// read out only 20 blocks, that doesn't screw things up. It just means when
	// a trigger occurs, you read out data from 30 blocks previous to 10 blocks
	// previous.
	//
	// Pretrigger blocks *are not* passed to the object generating the trigger.
	// They're passed to the trigger handling module, which does the delay-line-thingies.
	// Assuming it actually works, that is.
	
	//% L4RF0, number of blocks.
	wire [NBLOCK_BITS-1:0] l4rf0_num_blocks;
	//% L4RF0, number of pretrigger blocks.
	wire [PRETRG_BITS-1:0] l4rf0_pretrigger;
	//% L4RF1, number of blocks.
	wire [NBLOCK_BITS-1:0] l4rf1_num_blocks;
	//% L4RF1, number of pretrigger blocks.
	wire [PRETRG_BITS-1:0] l4rf1_pretrigger;
	//% L4CPU, number of blocks.
	wire [NBLOCK_BITS-1:0] l4cpu_num_blocks;
	//% L4CPU, number of pretrigger blocks.
	wire [PRETRG_BITS-1:0] l4cpu_pretrigger;
	//% L4CAL, number of blocks.
	wire [NBLOCK_BITS-1:0] l4cal_num_blocks;
	//% L4CAL, number of pretrigger blocks.
	wire [PRETRG_BITS-1:0] l4cal_pretrigger;
	//% L4EXT, number of blocks.
	wire [NBLOCK_BITS-1:0] l4ext_num_blocks;
	//% L4EXT, number of pretrigger blocks.
	wire [PRETRG_BITS-1:0] l4ext_pretrigger;
	
	//% Master trigger disable (T1 mask)
	wire T1_mask;
	//% Trigger subsystem reset.
	wire rst;

	////////// Signal definitions.
	
	//// Scalers. Following DocDB naming convention.
	
	//% L2 scalers: 16 total.
	wire [NUM_L2-1:0] l2_scaler;
	
	//% L3 scalers: 8 total (6 for TDAs, 2 for surface)
	wire [NUM_L3-1:0] l3_scaler;
	
	//% L4 scalers: 4 total (1 for TDA, 1 for surface, 1 for cpu, 1 for cal)
	wire [NUM_L4-1:0] l4_scaler;

	//% T1 scaler: 1 total (global trigger).
	wire T1_scaler;

	//% L1 triggers, registered on rising edge of fclk_i
	wire [NUM_L1-1:0] l1_trig_p;
	//% L1 triggers, registered on falling edge of fclk_i
	wire [NUM_L1-1:0] l1_trig_n;

	//% L1 scalers: 20 total (4 per TDA, 1 for surface).
	wire [NUM_L1-1:0] l1_scaler;	

	//% Mask of just the RF triggers
	wire [1:0] l4_rf_mask = l4_mask[1:0];

	//% All L4 trigger outputs. 1 & 0 are RF triggers.
	wire [NUM_L4-1:0] l4_trigger;
	
	//% Indicates if an L4 trigger has new data.
	wire [NUM_L4-1:0] l4_new;
	
	//% Ext trigger.
	wire l4_ext_trigger = l4_ext_i[2];
	
	//% Cal trigger from cal trigger module. Just a flag.
	wire l4_cal_trigger = l4_ext_i[1];

	//% Cpu trigger from soft trigger module. Just a flag.
	wire l4_cpu_trigger = l4_ext_i[0];
	
	//% Oneshot length
	wire [TRIG_ONESHOT_BITS-1:0] l1_oneshot;


	//%FIXME: addition from Patricks patch: 11 lines
 	//% Delay value to update to.
 	wire [TRIG_DELAY_VAL_BITS-1:0] l1_delay;
 	
 	//% Delay value for currently pointed-to L1.
 	wire [TRIG_DELAY_VAL_BITS-1:0] l1_delay_out;
 	
 	//% Delay value pointer
 	wire [NUM_L1_BITS-1:0] l1_delay_addr;
 
 	//% Delay update strobe.
 	wire l1_delay_stb;


	//% Trigger control WISHBONE module.
	wishbone_trigctrl_block 
			#(.VER_TYPE(VER_TYPE),
			  .VER_MONTH(VER_MONTH),
			  .VER_DAY(VER_DAY),
			  .VER_MAJOR(VER_MAJOR),
			  .VER_MINOR(VER_MINOR),
			  .VER_REV(VER_REV))	
			wb_trigctrl(.interface_io(trig_wbif_io),
													.rsv_trig_db_o(rsv_trig_db),
													.rf1_coincidence_o(rf1_coincidence),
													//%FIXME: addition from Patrick's patch: 4 lines
 													.l1_delay_o(l1_delay),
 													.l1_delay_i(l1_delay_out),
 													.l1_delay_addr_o(l1_delay_addr),
 													.l1_delay_stb_o(l1_delay_stb),
													.l1_mask_o(l1_mask),
													.l2_mask_o(l2_mask),
													.l3_mask_o(l3_mask),
													.l4_mask_o(l4_mask),
													.T1_mask_o(T1_mask),
													.l4_rf0_blocks_o(l4rf0_num_blocks),
													.l4_rf0_pretrigger_o(l4rf0_pretrigger),
													.l4_rf1_blocks_o(l4rf1_num_blocks),
													.l4_rf1_pretrigger_o(l4rf1_pretrigger),
													.l4_cpu_blocks_o(l4cpu_num_blocks),
													.l4_cpu_pretrigger_o(l4cpu_pretrigger),
													.l4_cal_blocks_o(l4cal_num_blocks),
													.l4_cal_pretrigger_o(l4cal_pretrigger),
													.l4_ext_blocks_o(l4ext_num_blocks),
													.l4_ext_pretrigger_o(l4ext_pretrigger),
													.l1_oneshot_o(l1_oneshot),
													.rst_o(rst));

   ////////////////////////////////////////////////////
	//
	// EXTERNAL TRIGGER GENERATION
	//
	////////////////////////////////////////////////////
	
	// External triggers are just flags coming into this
	// module. The number of blocks (and the pretrigger
	// delay) are all handled in the trigger_top module.
	
	//% Extend and mask the software trigger and its scaler (L4[2])
	l4_ext_generator cpu_generator(.l4_i(l4_ext_i[0]),
											 .mask_i(l4_mask[2]),
											 .blocks_i(l4cpu_num_blocks),
											 .l4_o(l4_trigger[2]),
											 .l4_new_o(l4_new[2]),
											 .l4_scaler_o(l4_scaler[2]),
											 .clk_i(fclk_i),
											 .rst_i(rst));
	
	//% Extend and mask the timed trigger and its scaler (L4[3])
	l4_ext_generator cal_generator(.l4_i(l4_ext_i[1]),
											 .mask_i(l4_mask[3]),
											 .blocks_i(l4cal_num_blocks),
											 .l4_o(l4_trigger[3]),
											 .l4_new_o(l4_new[3]),
											 .l4_scaler_o(l4_scaler[3]),
											 .clk_i(fclk_i),
											 .rst_i(rst));

	//% Extend and mask the external trigger and its scaler (L4[4])
	l4_ext_generator ext_generator(.l4_i(l4_ext_i[2]),
											 .mask_i(l4_mask[4]),
											 .blocks_i(l4ext_num_blocks),
											 .l4_o(l4_trigger[4]),
											 .l4_new_o(l4_new[4]),
											 .l4_scaler_o(l4_scaler[4]),
											 .clk_i(fclk_i),
											 .rst_i(rst));

   ////////////////////////////////////////////////////
   //
	// L1 TRIGGER/SCALER GENERATION AND MAPPING
	//
	////////////////////////////////////////////////////

	//% @brief x4 version of the trigger_scaler_map in previous ATRI firmware. With mapping.
	//% trigger_scaler_map takes the input signals from the
	//% triggering daughterboards and generates fclk_i domain
	//% trigger signals (both positive and negative edge versions, so effectively 200 MHz).
	//% These are the L1 scalers, so it outputs the L1 scaler array and takes in the
	//% L1 mask. Masked triggers still generate scaler counts (but obviously no upstream
	//% triggers will count!).
	//% The scaler pulses are all single-cycle flag outputs, with stuck-on detection
	//% inside them.
	//% Trigger_scalar_map ignores unpowered daughterboards, and it maps the reserved
	//% triggers to L1[19:16] based on rsv_trig_db.
	trigger_scaler_map_v2 #(.NUM_DAUGHTERS(NUM_DAUGHTERS))
								 daughter_map(.d1_trig_i(d1_trig_i),.d1_pwr_i(d1_pwr_i),
												  .d2_trig_i(d2_trig_i),.d2_pwr_i(d2_pwr_i),
												  .d3_trig_i(d3_trig_i),.d3_pwr_i(d3_pwr_i),
												  .d4_trig_i(d4_trig_i),.d4_pwr_i(d4_pwr_i),

													.l1_trig_p_o(l1_trig_p),
													.l1_trig_n_o(l1_trig_n),
													.l1_scaler_o(l1_scaler),

												  .rsv_trig_db_i(rsv_trig_db),
												  .l1_mask_i(l1_mask),
												  .l1_oneshot_i(l1_oneshot),
													//%FIXME: addition from Patrick's patch: 4 lines
 												  .l1_delay_i(l1_delay),
 												  .l1_delay_o(l1_delay_out),
 												  .l1_delay_addr_i(l1_delay_addr),
 												  .l1_delay_stb_i(l1_delay_stb),

												  .fclk_i(fclk_i),.sclk_i(sclk_i),.sce_i(sce_i));


   ////////////////////////////////////////////////////
   //
	// L2/3/4 TRIGGER/SCALER GENERATION
	//
	////////////////////////////////////////////////////

	wire [7:0] rf_debug;

	rf_trigger_top_v2 #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) rf_top(.l1_trig_p_i(l1_trig_p),
									 .l1_trig_n_i(l1_trig_n),
									 .l1_scal_i(l1_scaler),
									 .l2_mask_i(l2_mask),
									 .l3_mask_i(l3_mask),
									 .l4_mask_i(l4_rf_mask),
									 .l2_scaler_o(l2_scaler),
									 .l3_scaler_o(l3_scaler),
									 .l4_scaler_o(l4_scaler[1:0]),
									 
									 .clk_i(fclk_i),
									 .rst_i(rst),
									 .trig_rf0_info_o(trig_rf0_info_o),
									 .trig_rf1_info_o(trig_rf1_info_o),
									 .rf0_blocks_i(l4rf0_num_blocks),							 
									 .rf1_blocks_i(l4rf1_num_blocks),							 
									 .l4_trig_o(l4_trigger[1:0]),
									 .l4_new_o(l4_new[1:0]),
									 .rf1_coincidence_i(rf1_coincidence),

									 .debug_o(rf_debug)
									 );
		
   ////////////////////////////////////////////////////
   //
	// TRIGGER HANDLING
	//
	////////////////////////////////////////////////////

	wire [NUM_L4*PRETRG_BITS-1:0] pretrigger_vector;
	wire [NUM_L4*DELAY_BITS-1:0] delay_vector;
	
	delay_vectorizer u_delay_vect(.l4_rf0_pretrigger(l4rf0_pretrigger),
											.l4_rf1_pretrigger(l4rf1_pretrigger),
											.l4_cpu_pretrigger(l4cpu_pretrigger),
											.l4_cal_pretrigger(l4cal_pretrigger),
											.l4_ext_pretrigger(l4ext_pretrigger),
											.pretrigger_vector(pretrigger_vector),
											.l4_rf0_delay(`TRIG_RF0_DELAY),
											.l4_rf1_delay(`TRIG_RF1_DELAY),
											.l4_cpu_delay(`TRIG_CPU_DELAY),
											.l4_cal_delay(`TRIG_CAL_DELAY),
											.l4_ext_delay(`TRIG_EXT_DELAY),
											.delay_vector(delay_vector));
	
	// The trigger handler combines all of the triggers,
	// delays them by whatever's needed to align all of them,
	// and then tells the readout firmware what blocks to read out.

	// This module automatically handles any size L4 based on trigger_defs.vh.

	wire T1_mask_and_ready;
	assign T1_mask_and_ready = T1_mask || !readout_ready_i;
	trigger_handling_v2 trig_processor(
		.pretrigger_vector_i(pretrigger_vector), 
		.delay_vector_i(delay_vector), 
		.disable_i(disable_i),
		.disable_ce_i(disable_ce_i),
		.l4_i(l4_trigger), 
		.l4_new_i(l4_new),
		.l4_matched_o(trig_l4_o),
		.l4_new_o(trig_l4_new_o),
		.T1_mask_i(T1_mask_and_ready), 
		.T1_o(trig_o), 
		.T1_scaler_o(T1_scaler), 
		.T1_offset_o(trig_delay_o), 
		.clk_i(fclk_i), 
		.rst_i(rst)
	);

   ////////////////////////////////////////////////////
   //
   // SCALER LOGIC
   //   
   ////////////////////////////////////////////////////
	
	//% Scaler block.	
	wishbone_scaler_block_v2 wb_scal(.interface_io(scal_wbif_io),
												.l1_scal_i(l1_scaler),
												.l2_scal_i(l2_scaler),
												.l3_scal_i(l3_scaler),
												.l4_scal_i(l4_scaler),
												.t1_scal_i(T1_scaler),
							
												.ext_gate_i(l4_ext_i[2]),
							
												.fclk_i(fclk_i),
												.pps_flag_fclk_i(pps_flag_fclk_i));


	reg [31:0] trig_debug = {32{1'b0}};
	always @(posedge fclk_i) begin
		trig_debug[15:0] <= l1_trig_p[15:0];
		trig_debug[16] <= l4_trigger[0];
		// 15 more scalers. Pick up the 12 L2s and the 2 L3s.
		trig_debug[19:17] <= l2_scaler[2:0];
		trig_debug[22:20] <= l2_scaler[6:4];
		trig_debug[25:23] <= l2_scaler[10:8];
		trig_debug[28:26] <= l2_scaler[14:12];
		trig_debug[29] <= l3_scaler[0];
		trig_debug[30] <= l3_scaler[1];
		trig_debug[31] <= l4_scaler[0];
	end
	
	assign debug_o[31:0] = trig_debug;
	assign debug_o[32] = rst;
	assign debug_o[33] = disable_i;
	assign debug_o[42:34] = trig_delay_o;
	assign debug_o[50:43] = rf_debug;
	assign debug_o[52:51] = {2{1'b0}};
endmodule
