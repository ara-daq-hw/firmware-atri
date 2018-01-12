`timescale 1ns / 1ps
//% @file wishbone_trigctrl_block.v Contains wishbone_trigctrl_block module.

`include "wb_interface.vh"
`include "trigger_defs.vh"
`include "vassert.vh"

//% @brief WISHBONE trigger control block.
//% @par Module Symbol
//% @gensymbol
//% MODULE wishbone_trigctrl_block
//% ENDMODULE
//% @endgensymbol
//% @par Overview
//% \n\n
//% wishbone_trigctrl_block contains the registers for controlling
//% the trigger module inside trigger_top.
module wishbone_trigctrl_block(
		interface_io,
		rsv_trig_db_o,
		rf1_coincidence_o,
		//%FIXME: addition from Patrick's patch: 4 lines
		l1_delay_o,
		l1_delay_i,
		l1_delay_addr_o,
		l1_delay_stb_o,
		l1_mask_o,
		l2_mask_o,
		l3_mask_o,
		l4_mask_o,
		T1_mask_o,
		l4_rf0_blocks_o,
		l4_rf0_pretrigger_o,
		l4_rf1_blocks_o,
		l4_rf1_pretrigger_o,
		l4_cpu_blocks_o,
		l4_cpu_pretrigger_o,
		l4_cal_blocks_o,
		l4_cal_pretrigger_o,
		l4_ext_blocks_o,
		l4_ext_pretrigger_o,
		l1_oneshot_o,
		rst_o
    );

	////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////
	
	parameter [3:0] VER_TYPE = 0;
	parameter [3:0] VER_MONTH = 0;
	parameter [7:0] VER_DAY = 0;
	parameter [3:0] VER_MAJOR = 0;
	parameter [3:0] VER_MINOR = 0;
	parameter [7:0] VER_REV = 0;
	
	//%FIXME: addition from Patrick's patch: 1 line
	`include "clogb2.vh"
	
	//% Number of L1 scalers.
	localparam NUM_L1 = `SCAL_NUM_L1;
	//%Number of bits to address l1_scalers.
	localparam NUM_L1_BITS = clogb2(NUM_L1);
	//% Number of L2 scalers.
	localparam NUM_L2 = `SCAL_NUM_L2;
	//% Number of L3 scalers.
	localparam NUM_L3 = `SCAL_NUM_L3;
	//% Number of L4 scalers.
	localparam NUM_L4 = `SCAL_NUM_L4;
	//  Only 1 T1 scaler
	localparam NUM_T1_BITS = 1;
	
	localparam TRIG_DELAY_VAL_BITS = `TRIG_DELAY_VAL_BITS;
	localparam NBLOCK_BITS = `NBLOCK_BITS;
	localparam PRETRG_BITS = `PRETRG_BITS;
	localparam TRIG_ONESHOT_BITS = `TRIG_ONESHOT_BITS;
	
	localparam [NBLOCK_BITS-1:0] L4RF0_BLOCKS_DEFAULT = `TRIG_RF0_NUM_BLOCKS;
	localparam [PRETRG_BITS-1:0] L4RF0_PRETRIGGER_DEFAULT = `TRIG_RF0_PRETRIGGER;
	localparam [NBLOCK_BITS-1:0] L4RF1_BLOCKS_DEFAULT = `TRIG_RF1_NUM_BLOCKS;
	localparam [PRETRG_BITS-1:0] L4RF1_PRETRIGGER_DEFAULT = `TRIG_RF1_PRETRIGGER;
	localparam [NBLOCK_BITS-1:0] L4CPU_BLOCKS_DEFAULT = `TRIG_CPU_NUM_BLOCKS;
	localparam [PRETRG_BITS-1:0] L4CPU_PRETRIGGER_DEFAULT = `TRIG_CPU_PRETRIGGER;
	localparam [NBLOCK_BITS-1:0] L4CAL_BLOCKS_DEFAULT = `TRIG_CAL_NUM_BLOCKS;
	localparam [PRETRG_BITS-1:0] L4CAL_PRETRIGGER_DEFAULT = `TRIG_CAL_PRETRIGGER;
	localparam [NBLOCK_BITS-1:0] L4EXT_BLOCKS_DEFAULT = `TRIG_EXT_NUM_BLOCKS;
	localparam [PRETRG_BITS-1:0] L4EXT_PRETRIGGER_DEFAULT = `TRIG_EXT_PRETRIGGER;
	
	localparam [TRIG_ONESHOT_BITS-1:0] L1_ONESHOT_DEFAULT = `L1_ONESHOT_DEFAULT;
	
	localparam [NUM_L4-1:0] L4_MASK_DEFAULT = `L4_MASK_DEFAULT;
	
	//// This module is 'built' assuming NUM_L1 is between 17-24,
	//// NUM_L2 is 8-16, NUM_L3 is 0-8, and NUM_L4 is 0-8. If this is
	//// different, throw a warning and hope someone sees it.
	`VA_WARN_LESS( a_l1lt, NUM_L1 , 17 , "WISHBONE Trigger Control: Register mapping assumes NUM_L1 between 17-24!");
	`VA_WARN_GREATER( a_l1gt, NUM_L1, 24, "WISHBONE Trigger Control: Register mapping assumes NUM_L1 between 17-24!");
	`VA_WARN_LESS( a_l2lt, NUM_L2, 8, "WISHBONE Trigger Control: Register mapping assumes NUM_L2 between 8-16!");
	`VA_WARN_GREATER( a_l2gt, NUM_L2, 16, "WISHBONE Trigger Control: Register mapping assumes NUM_L2 between 8-16!");
	`VA_WARN_GREATER( a_l3lt, NUM_L3, 8, "WISHBONE Trigger Control: Register mapping assumes NUM_L3 between 0-8!");
	`VA_WARN_GREATER( a_l4lt, NUM_L4, 8, "WISHBONE Trigger Control: Register mapping asusmes NUM_L4 between 0-8!");	
	
	////////////////////////////////////////////////////
   //
   // PORTS
   //
   ////////////////////////////////////////////////////
	
	//% WISHBONE interface
	inout [`WBIF_SIZE-1:0] interface_io;
	
	//% Indicates which daughter the L1[19:16] map to.
	output [1:0] rsv_trig_db_o;
	
	//% Indicates the coincidence level of the L4[1] (L4RF1) trigger.
	output [1:0] rf1_coincidence_o;
	
	//%FIXME: addition from Patrick's patch: 11 lines.
 	//% Multiplexed L1 delay value output
 	output [TRIG_DELAY_VAL_BITS-1:0] l1_delay_o;
 
 	//% Multiplexed L1 delay value input
 	input [TRIG_DELAY_VAL_BITS-1:0] l1_delay_i;
 	
 	//% Address of the L1 delay that is being selected.
 	output [NUM_L1_BITS-1:0] l1_delay_addr_o;
 	
 	//% Strobe for writing the L1 delay.
 	output l1_delay_stb_o;
	
	
	//% Mask for L1 triggers.
	output [NUM_L1-1:0] l1_mask_o;
	
	//% Mask for L2 triggers.
	output [NUM_L2-1:0] l2_mask_o;
	
	//% Mask for L3 triggers
	output [NUM_L3-1:0] l3_mask_o;
	
	//% Mask for L4 triggers
	output [NUM_L4-1:0] l4_mask_o;
	
	//% Number of RF0 blocks to be read out.
	output [NBLOCK_BITS-1:0] l4_rf0_blocks_o;

	//% Number of pretrigger RF0 blocks.
	output [PRETRG_BITS-1:0] l4_rf0_pretrigger_o;
	
	//% Number of RF1 blocks to be read out.
	output [NBLOCK_BITS-1:0] l4_rf1_blocks_o;
	
	//% Number of pretrigger RF1 blocks.
	output [PRETRG_BITS-1:0] l4_rf1_pretrigger_o;
	
	//% Number of CPU blocks to be read out.
	output [NBLOCK_BITS-1:0] l4_cpu_blocks_o;
	
	//% Number of pretrigger CPU blocks.
	output [PRETRG_BITS-1:0] l4_cpu_pretrigger_o;
	
	//% Number of Cal blocks to be read out.
	output [NBLOCK_BITS-1:0] l4_cal_blocks_o;
	
	//% Number of pretrigger Cal blocks.
	output [PRETRG_BITS-1:0] l4_cal_pretrigger_o;
	
	//% Number of Ext blocks to be read out.
	output [NBLOCK_BITS-1:0] l4_ext_blocks_o;
	
	//% Number of pretrigger Ext blocks.
	output [PRETRG_BITS-1:0] l4_ext_pretrigger_o;
	
	//% Number of cycles in an L1 oneshot.
	output [TRIG_ONESHOT_BITS-1:0] l1_oneshot_o;
	
	//% Mask for T1 triggers (i.e. 'stop all triggers').
	output T1_mask_o;

	//% Trigger subsystem reset.
	output rst_o;

	//// WISHBONE interface expansion.
	// INTERFACE_INS wb wb_slave 
	wire clk_i;
	wire rst_i;
	wire cyc_i;
	wire wr_i;
	wire stb_i;
	wire ack_o;
	wire err_o;
	wire rty_o;
	wire [15:0] adr_i;
	wire [7:0] dat_i;
	wire [7:0] dat_o;
	wb_slave wbif(.interface_io(interface_io),
	              .clk_o(clk_i),
	              .rst_o(rst_i),
	              .cyc_o(cyc_i),
	              .wr_o(wr_i),
	              .stb_o(stb_i),
	              .ack_i(ack_o),
	              .err_i(err_o),
	              .rty_i(rty_o),
	              .adr_o(adr_i),
	              .dat_o(dat_i),
	              .dat_i(dat_o));
	// INTERFACE_END
	
	////////////////////////////////////////////////////
   //
   // SIGNALS
   //
   ////////////////////////////////////////////////////
	
	///// WISHBONE address space
	wire [7:0] wishbone_registers[31:0];
	
	//% Reserve trigger DB register (by default 4).
	reg [1:0] rsv_trig_db = {2{1'b1}};
	
	//% RF1 coincidence level (by default 3).
	reg [1:0] rf1_coincidence = 2'b10;
	
	
	//%Delay pointer.
	reg [NUM_L1_BITS-1:0] l1_delay_pointer = {NUM_L1_BITS{1'b0}};
	
	
	//% L1 mask.
	reg [NUM_L1-1:0] l1_mask = {NUM_L1{1'b0}};
	//% L2 mask
	reg [NUM_L2-1:0] l2_mask = {NUM_L2{1'b0}};
	//% L3 mask
	reg [NUM_L3-1:0] l3_mask = {NUM_L3{1'b0}};
	//% L4 mask
	reg [NUM_L4-1:0] l4_mask = L4_MASK_DEFAULT;
	//% T1 mask. Starts up disabled.
	reg T1_mask = 1;
	//% L4 RF0 number of blocks to read out.
	reg [NBLOCK_BITS-1:0] l4_rf0_blocks = L4RF0_BLOCKS_DEFAULT;
	//% L4 RF0 number of pretrigger cycles.
	reg [PRETRG_BITS-1:0] l4_rf0_pretrigger = L4RF0_PRETRIGGER_DEFAULT;
	//% L4 RF1 number of blocks to read out.
	reg [NBLOCK_BITS-1:0] l4_rf1_blocks = L4RF1_BLOCKS_DEFAULT;
	//% L4 RF1 number of pretrigger cycles.
	reg [PRETRG_BITS-1:0] l4_rf1_pretrigger = L4RF1_PRETRIGGER_DEFAULT;
	//% L4 Soft trigger number of blocks to read out.
	reg [NBLOCK_BITS-1:0] l4_cpu_blocks = L4CPU_BLOCKS_DEFAULT;
	//% L4 Soft trigger number of pretrigger cycles.
	reg [PRETRG_BITS-1:0] l4_cpu_pretrigger = L4CPU_PRETRIGGER_DEFAULT;
	//% L4 Cal trigger number of blocks to read out.
	reg [NBLOCK_BITS-1:0] l4_cal_blocks = L4CAL_BLOCKS_DEFAULT;
	//% L4 Cal number of pretrigger cycles.
	reg [PRETRG_BITS-1:0] l4_cal_pretrigger = L4CAL_PRETRIGGER_DEFAULT;
	//% L4 Ext number of blocks to readout.
	reg [NBLOCK_BITS-1:0] l4_ext_blocks = L4EXT_BLOCKS_DEFAULT;
	//% L4 Ext number of pretrigger cycles.
	reg [PRETRG_BITS-1:0] l4_ext_pretrigger = L4EXT_PRETRIGGER_DEFAULT;
	
	//% Length of L1 oneshot.
	reg [TRIG_ONESHOT_BITS-1:0] l1_trig_oneshot = L1_ONESHOT_DEFAULT;
	
	//% Trigger subsystem reset.
	reg rst = 0;
	
	//% Muxed output.
	reg [7:0] muxed_output = {8{1'b0}};
	//% WISHBONE acknowledge
	reg wb_ack = 0;
	
	//% Convenience function to convert a WISHBONE scaler address to the internal address space.
	function [4:0] BASE;
		input [15:0] bar_value;
		begin
			BASE = bar_value[4:0];
		end
	endfunction	
	
	// WISHBONE assignment macros
	// Note missing ; at end of each assign. Intentional.
	`define FLAG( addr, x , bitnum , dummy) 					    \
		always @(posedge clk_i) begin 								 \
			if (cyc_i && stb_i && (adr_i[4:0] == addr) && wr_i) \
				x <= dat_i bitnum ;								    \
			else																 \
				x <= 0;														 \
		end																	 \
		assign wishbone_registers[addr] bitnum  = 0				 \
		
	`define SIGNAL(addr, x , range, dummy)						 \
		always @(posedge clk_i) begin									 \
			if (cyc_i && stb_i && (adr_i[4:0] == addr) && wr_i) \
				x <= dat_i range ;						 \
		end																	 \
		assign wishbone_registers[addr] range  = x  \

	`define SIGNALRESET(addr, x, range, resetval) 						\
		always @(posedge clk_i) begin				    						\
			if (rst) x <= resetval ;					 						\
			else if (cyc_i && stb_i && (adr_i[4:0] == addr) && wr_i) \
				x <= dat_i range ;												\
		end																			\
		assign wishbone_registers[addr] range  = x	 					\
	
	`define OUTPUT(addr, x, range, dummy)						 \
		assign wishbone_registers[addr] range = x
		
	//FIXME: addition from Patrick's patch: 4 lines
 	`define SELECT(addr, x, addrrange, dummy)          \
 		wire x;														\
 		localparam [4:0] addr_``x = addr;				   \
 		assign x = (cyc_i && stb_i && wr_i && ack_o && (adr_i addrrange == addr_``x addrrange))
		
		
	`define WISHBONE_ADDRESS( addr , name , TYPE, par1, par2) \
		`TYPE(BASE(addr), name, par1, par2)

	//// WISHBONE registers.
	// Note that these guys don't really have the expansion space that
	// the scalers do. 

	// ID registers.
	`WISHBONE_ADDRESS(16'h0060, VER_REV, OUTPUT, [7:0] , 0);

	`WISHBONE_ADDRESS(16'h0061, VER_MINOR, OUTPUT, [3:0] , 0);
	`WISHBONE_ADDRESS(16'h0061, VER_MAJOR, OUTPUT, [7:4] , 0);

	`WISHBONE_ADDRESS(16'h0062, VER_DAY, OUTPUT, [7:0] , 0);

	`WISHBONE_ADDRESS(16'h0063, VER_MONTH, OUTPUT, [3:0] , 0);
	`WISHBONE_ADDRESS(16'h0063, VER_TYPE, OUTPUT, [7:4] , 0);

	// L1 mask.
	`WISHBONE_ADDRESS(16'h0064, l1_mask[7:0], SIGNALRESET, [7:0] , 8'h00);
	`WISHBONE_ADDRESS(16'h0065, l1_mask[15:8], SIGNALRESET, [7:0] , 8'h00);
	`WISHBONE_ADDRESS(16'h0066, l1_mask[NUM_L1-1:16], SIGNALRESET, [0 +: NUM_L1-16], {NUM_L1-16{1'b0}});
	`WISHBONE_ADDRESS(16'h0067, {8{1'b0}}, OUTPUT, [7:0], 0);

	// L2 mask.
	`WISHBONE_ADDRESS(16'h0068, l2_mask[7:0], SIGNALRESET, [7:0], 8'h00);
	`WISHBONE_ADDRESS(16'h0069, l2_mask[15:8], SIGNALRESET, [7:0], 8'h00);
	`WISHBONE_ADDRESS(16'h006A, {8{1'b0}}, OUTPUT, [7:0], 8'h00);
	`WISHBONE_ADDRESS(16'h006B, {8{1'b0}}, OUTPUT, [7:0], 8'h00);

	// L3 mask
	`WISHBONE_ADDRESS(16'h006C, l3_mask[7:0], SIGNALRESET, [7:0], 8'h00);
	`WISHBONE_ADDRESS(16'h006D, {8{1'b0}}, OUTPUT, [7:0], 0);
	
	// L4 mask
	`WISHBONE_ADDRESS(16'h006E, l4_mask[NUM_L4-1:0], SIGNALRESET, [0 +: NUM_L4], {NUM_L4{1'b0}});
	`WISHBONE_ADDRESS(16'h006F, {8{1'b0}}, OUTPUT, [7:0], 0);
	
	// Number of blocks to record for an RF (in-ice) trigger.
	`WISHBONE_ADDRESS(16'h0070, l4_rf0_blocks, SIGNALRESET, [NBLOCK_BITS-1:0], L4RF0_BLOCKS_DEFAULT);
	// Number of pretrigger cycles. This actually determines
	// how far back we go from the trigger when we begin the readout.
	`WISHBONE_ADDRESS(16'h0071, l4_rf0_pretrigger, SIGNALRESET, [PRETRG_BITS-1:0], L4RF0_PRETRIGGER_DEFAULT);	

	`WISHBONE_ADDRESS(16'h0072, l4_rf1_blocks, SIGNALRESET, [NBLOCK_BITS-1:0], L4RF1_BLOCKS_DEFAULT);
	`WISHBONE_ADDRESS(16'h0073, l4_rf1_pretrigger, SIGNALRESET, [PRETRG_BITS-1:0], L4RF1_PRETRIGGER_DEFAULT);	

	`WISHBONE_ADDRESS(16'h0074, l4_cpu_blocks, SIGNALRESET, [NBLOCK_BITS-1:0], L4CPU_BLOCKS_DEFAULT);
	`WISHBONE_ADDRESS(16'h0075, l4_cpu_pretrigger, SIGNALRESET, [PRETRG_BITS-1:0], L4CPU_PRETRIGGER_DEFAULT);	

	`WISHBONE_ADDRESS(16'h0076, l4_cal_blocks, SIGNALRESET, [NBLOCK_BITS-1:0], L4CAL_BLOCKS_DEFAULT);
	`WISHBONE_ADDRESS(16'h0077, l4_cal_pretrigger, SIGNALRESET, [PRETRG_BITS-1:0], L4CAL_PRETRIGGER_DEFAULT);	
	
	`WISHBONE_ADDRESS(16'h0078, l4_ext_blocks, SIGNALRESET, [NBLOCK_BITS-1:0], L4EXT_BLOCKS_DEFAULT);
	`WISHBONE_ADDRESS(16'h0079, l4_ext_pretrigger, SIGNALRESET, [NBLOCK_BITS-1:0], L4EXT_PRETRIGGER_DEFAULT);
	
	//%FIXME: addition from Patrick's patch: 4 lines
 	// L1 delay pointer. This selects which delay value 0x7B reads out/writes to.
 	`WISHBONE_ADDRESS(16'h007A, l1_delay_pointer, SIGNALRESET, [NUM_L1_BITS-1:0], {NUM_L1_BITS{1'b0}});
 	`WISHBONE_ADDRESS(16'h007B, l1_delay_i, OUTPUT, [TRIG_DELAY_VAL_BITS-1:0], 0);
 	`WISHBONE_ADDRESS(16'h007B, l1_delay_value_stb, SELECT, [4:0], 0);
	
	
	
	`WISHBONE_ADDRESS(16'h007C, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h007D, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h007E, l1_trig_oneshot, SIGNALRESET, [TRIG_ONESHOT_BITS-1:0], L1_ONESHOT_DEFAULT);
	// Master trigger control.
	`WISHBONE_ADDRESS(16'h007F, rsv_trig_db, SIGNAL, [1:0], 0);
	`WISHBONE_ADDRESS(16'h007F, rf1_coincidence, SIGNAL, [3:2], 0);
	`WISHBONE_ADDRESS(16'h007F, T1_mask, SIGNALRESET, [4], 1'b1);
	`WISHBONE_ADDRESS(16'h007F, {2{1'b0}}, OUTPUT, [6:5], 0);
	`WISHBONE_ADDRESS(16'h007F, rst, FLAG, [7], 0);

	`undef WISHBONE_ADDRESS
	`undef SIGNAL
	`undef SIGNALRESET
	`undef FLAG
	`undef OUTPUT

	// 1 cycle of latency.
	always @(posedge clk_i) begin
		if (!wb_ack && cyc_i && stb_i) wb_ack <= 1;
		else wb_ack <= 0;
	end

	always @(posedge clk_i) begin
		if (cyc_i && stb_i && !wr_i)
			muxed_output <= wishbone_registers[adr_i[4:0]];
	end
	
	assign dat_o = muxed_output;
	assign ack_o = wb_ack;
	assign err_o = 1'b0;
	assign rty_o = 1'b0;

	assign l1_mask_o = l1_mask;
	assign l2_mask_o = l2_mask;
	assign l3_mask_o = l3_mask;
	assign l4_mask_o = l4_mask;
	assign T1_mask_o = T1_mask;
	assign rst_o = rst;
	assign rsv_trig_db_o = rsv_trig_db;
	assign rf1_coincidence_o = rf1_coincidence;
	assign l4_rf0_blocks_o = l4_rf0_blocks;
	assign l4_rf0_pretrigger_o = l4_rf0_pretrigger;
	assign l4_rf1_blocks_o = l4_rf1_blocks;
	assign l4_rf1_pretrigger_o = l4_rf1_pretrigger;
	assign l4_cpu_blocks_o = l4_cpu_blocks;
	assign l4_cpu_pretrigger_o = l4_cpu_pretrigger;
	assign l4_cal_blocks_o = l4_cal_blocks;
	assign l4_cal_pretrigger_o = l4_cal_pretrigger;
	assign l4_ext_blocks_o = l4_ext_blocks;
	assign l4_ext_pretrigger_o = l4_ext_pretrigger;
	assign l1_oneshot_o = l1_trig_oneshot;
	//FIXME: addition from Patrick's patch: 3 lines
 	assign l1_delay_o = dat_i[TRIG_DELAY_VAL_BITS-1:0];
 	assign l1_delay_addr_o = l1_delay_pointer;
 	assign l1_delay_stb_o = l1_delay_value_stb;
endmodule
