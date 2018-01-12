`timescale 1ns / 1ps
//% @file wishbone_scaler_block_v2.v Contains wishbone_scaler_block, version 2

//% @brief WISHBONE scaler block, version 2.
//%
//% @par Module Symbol
//% @gensymbol
//% MODULE wishbone_scaler_block_v2
//% ENDMODULE
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% wishbone_scaler_block_v2 is a massively-cleaned up implementation of the
//% WISHBONE scaler block.
//%

`include "wb_interface.vh"
`include "trigger_defs.vh"

module wishbone_scaler_block_v2(
		interface_io,
		l1_scal_i,
		l2_scal_i,
		l3_scal_i,
		l4_scal_i,
		t1_scal_i,
		
		ext_gate_i,
		fclk_i,
		pps_flag_fclk_i
    );

	////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

	///// These are contained within trigger_defs.vh. DO NOT change here!
	// These are all local params.
	
	`include "clogb2.vh"	
	//% Number of L1 scalers.
	localparam NUM_L1 = `SCAL_NUM_L1;
	localparam NUM_L1_BITS = clogb2(NUM_L1);
	//% Number of L2 scalers.
	localparam NUM_L2 = `SCAL_NUM_L2;
	localparam NUM_L2_BITS = clogb2(NUM_L2);
	//% Number of L3 scalers.
	localparam NUM_L3 = `SCAL_NUM_L3;
	localparam NUM_L3_BITS = clogb2(NUM_L3);
	//% Number of L4 scalers.
	localparam NUM_L4 = `SCAL_NUM_L4;
	localparam NUM_L4_BITS = clogb2(NUM_L4);
	//% Number of RF L4 triggers.
	localparam NUM_RF_L4 = `SCAL_NUM_RF_L4;
	localparam NUM_RF_L4_BITS = clogb2(NUM_RF_L4);
	
	//  Only 1 T1 scaler
	localparam NUM_T1_BITS = 1;
	
	//% Number of output bits.
	localparam OUTPUT_BITS = 16;

   ////////////////////////////////////////////////////
   //
   // PRESCALING
   //   
   ////////////////////////////////////////////////////

	//% These determine the L1 prescaling. Can be done on scaler-by-scaler basis.
	function integer L1_PRESCALE_BITS;
		input [NUM_L1_BITS-1:0] scaler;
		begin
			case(scaler)
				default: L1_PRESCALE_BITS = 5;
			endcase
		end
	endfunction
	
	//% These determine the L2 prescaling. Can be done on scaler-by-scaler basis.
	function integer L2_PRESCALE_BITS;
		input [NUM_L2_BITS-1:0] scaler;
		begin
			case(scaler)
				0,4,8,12: L2_PRESCALE_BITS = 6;
				default: L2_PRESCALE_BITS = 0;
			endcase
		end
	endfunction

	//% These determine the L3 prescaling. Can be done on scaler-by-scaler basis.
	function integer L3_PRESCALE_BITS;
		input [NUM_L3_BITS-1:0] scaler;
		begin
			case(scaler)
				default: L3_PRESCALE_BITS = 0;
			endcase
		end
	endfunction

	//% These determine the L4 prescaling. Can be done on scaler-by-scaler basis.
	function integer L4_PRESCALE_BITS;
		input [NUM_L4_BITS-1:0] scaler;
		begin
			case(scaler)
				default: L4_PRESCALE_BITS = 0;
			endcase
		end
	endfunction

	//% These determine the T1 prescaling.
	function integer T1_PRESCALE_BITS;
		input [NUM_T1_BITS-1:0] scaler;
		begin
			case(scaler)
				default: T1_PRESCALE_BITS = 0;
			endcase
		end
	endfunction
	
   ////////////////////////////////////////////////////
   //
   // PORTS
   //   
   ////////////////////////////////////////////////////
	
	//% WISHBONE interface
	inout [`WBIF_SIZE-1:0] interface_io;

	//% L1 scalers
	input [NUM_L1-1:0] l1_scal_i;
	//% L2 scalers
	input [NUM_L2-1:0] l2_scal_i;
	//% L3 scalers
	input [NUM_L3-1:0] l3_scal_i;
	//% L4 scalers
	input [NUM_L4-1:0] l4_scal_i;
	//% T1 scaler
	input t1_scal_i;

	//% External gate (for gated scalers)
	input ext_gate_i;
		
	//% Fast clock (counting domain)
	input fclk_i;
	//% PPS flag in fast clock
	input pps_flag_fclk_i;
	
	// INTERFACE_INS wb wb_slave RPL clk_i wb_clk_i
	wire wb_clk_i;
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
	              .clk_o(wb_clk_i),
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
   // LOGIC
   //   
   ////////////////////////////////////////////////////	
	
	//% 16-bit multiplexed data output.
	reg [15:0] muxed_register_out = {16{1'b0}};

	//% Acknowledge for the WISHBONE cycle.
	reg wb_ack = 0;
	
	//% Register array. We have 128 16-bit registers.
	wire [15:0] scaler_registers[127:0];

	//% L1 scalers.
	wire [15:0] L1[NUM_L1-1:0];
	//% L2 scalers.
	wire [15:0] L2[NUM_L2-1:0];
	//% L3 scalers.
	wire [15:0] L3[NUM_L3-1:0];
	//% L4 scalers.
	wire [15:0] L4[NUM_L4-1:0];
	//% T1 scaler.
	wire [15:0] T1;
	//% Blockrate scaler.
	wire [15:0] blockrate;
	
	//% L1 scaler gated with the external trigger.
	wire [15:0] L1_and_ext;
	//% L2 scaler gated with the external trigger.
	wire [15:0] L2_and_ext;
	//% L3 scaler gated with the external trigger.
	wire [15:0] L3_and_ext;
	//% L4 scaler gated with the external trigger.
	wire [15:0] L4_and_ext;

	//% Gated L1 select.
	reg [NUM_L1_BITS-1:0] l1ext_sel_i = {NUM_L1_BITS{1'b0}};
	//% Gated L2 select
	reg [NUM_L2_BITS-1:0] l2ext_sel_i = {NUM_L2_BITS{1'b0}};
	//% Gated L3 select
	reg [NUM_L3_BITS-1:0] l3ext_sel_i = {NUM_L3_BITS{1'b0}};
	//% Gated L4 select
	reg [NUM_RF_L4_BITS-1:0] l4ext_sel_i = {NUM_RF_L4_BITS{1'b0}};

	localparam [7:0] EXT_GATE_DEFAULT = 100;

	reg ext_gate = 0;
	reg [7:0] ext_gate_count_max = EXT_GATE_DEFAULT;
	reg [7:0] ext_gate_count_max_sync = EXT_GATE_DEFAULT;
	reg [7:0] ext_gate_counter = {8{1'b0}};
	reg ext_gate_count_update = 0;
	wire ext_gate_count_update_fclk;

	reg [7:0] scal_ctl = {8{1'b0}};
	
	wire [15:0] ext_gate_count_max_and_scal_ctl = {scal_ctl,ext_gate_count_max};
	
	always @(posedge fclk_i) begin
		if (ext_gate_i) ext_gate <= 1;
		else if (ext_gate_counter == ext_gate_count_max_sync) ext_gate <= 0;
	end
	always @(posedge fclk_i) begin
		if (ext_gate) ext_gate_counter <= ext_gate_counter + 1;
		else ext_gate_counter <= {8{1'b0}};
	end

	flag_sync update_sync(.in_clkA(ext_gate_count_update),.out_clkB(ext_gate_count_update_fclk),
								 .clkA(wb_clk_i),.clkB(fclk_i));
	always @(posedge fclk_i) begin
		if (ext_gate_count_update_fclk) ext_gate_count_max_sync <= ext_gate_count_max;
	end
	
	//% Enables for the gated L1 scalers.
	reg [NUM_L1-1:0] L1ext_en = {20{1'b0}};
	wire [NUM_L1-1:0] L1ext_en_sync;

	//% Enables for the gated L2 scalers.
	reg [NUM_L2-1:0] L2ext_en = {16{1'b0}};
	wire [NUM_L2-1:0] L2ext_en_sync;
	//% Enables for the gated L3 scalers.
	reg [NUM_L3-1:0] L3ext_en = {8{1'b0}};
	wire [NUM_L3-1:0] L3ext_en_sync;
	//% Enables for the gated L4 scalers.
	reg [NUM_RF_L4-1:0] L4ext_en = {2{1'b0}};
	wire [NUM_RF_L4-1:0] L4ext_en_sync;
	
	integer L1en_i, L2en_i, L3en_i, L4en_i;
	always @(posedge wb_clk_i) begin
		for (L1en_i = 0;L1en_i<NUM_L1;L1en_i=L1en_i+1) begin
			L1ext_en[L1en_i] <= (l1ext_sel_i == L1en_i);
		end
		for (L2en_i = 0;L2en_i<NUM_L2;L2en_i=L2en_i+1) begin
			L2ext_en[L2en_i] <= (l2ext_sel_i == L2en_i);
		end
		for (L3en_i = 0;L3en_i<NUM_L3;L3en_i=L3en_i+1) begin
			L3ext_en[L3en_i] <= (l3ext_sel_i == L3en_i);
		end
		for (L4en_i = 0;L4en_i<NUM_RF_L4;L4en_i=L4en_i+1) begin
			L4ext_en[L4en_i] <= (l4ext_sel_i == L4en_i);
		end
	end
	generate
		genvar si,sj,sk,sl;
		for (si=0;si<NUM_L1;si=si+1) begin : L1EN_SYNC
			signal_sync l1ensync(.clkA(wb_clk_i),.clkB(fclk_i),.in_clkA(L1ext_en[si]),.out_clkB(L1ext_en_sync[si]));
		end
		for (sj=0;sj<NUM_L2;sj=sj+1) begin : L2EN_SYNC
			signal_sync l2ensync(.clkA(wb_clk_i),.clkB(fclk_i),.in_clkA(L2ext_en[sj]),.out_clkB(L2ext_en_sync[sj]));
		end
		for (sk=0;sk<NUM_L3;sk=sk+1) begin : L3EN_SYNC
			signal_sync l3ensync(.clkA(wb_clk_i),.clkB(fclk_i),.in_clkA(L3ext_en[sk]),.out_clkB(L3ext_en_sync[sk]));
		end
		for (sl=0;sl<NUM_RF_L4;sl=sl+1) begin : L4EN_SYNC
			signal_sync l4ensync(.clkA(wb_clk_i),.clkB(fclk_i),.in_clkA(L4ext_en[sl]),.out_clkB(L4ext_en_sync[sl]));
		end
	endgenerate
	
	reg [NUM_L1-1:0] l1ext = {NUM_L1{1'b0}};
	reg [NUM_L2-1:0] l2ext = {NUM_L2{1'b0}};
	reg [NUM_L3-1:0] l3ext = {NUM_L3{1'b0}};
	reg [NUM_RF_L4-1:0] l4ext = {NUM_RF_L4{1'b0}};
	always @(posedge fclk_i) begin
		if (ext_gate) begin
			l1ext <= L1ext_en_sync & l1_scal_i;
			l2ext <= L2ext_en_sync & l2_scal_i;
			l3ext <= L3ext_en_sync & l3_scal_i;
			l4ext <= L4ext_en_sync & l4_scal_i[NUM_RF_L4-1:0];
		end else begin
			l1ext <= {NUM_L1{1'b0}};
			l2ext <= {NUM_L2{1'b0}};
			l3ext <= {NUM_L3{1'b0}};
			l4ext <= {NUM_RF_L4{1'b0}};
		end
	end
	reg l1ext_scal = 0;
	reg l1ext_pipe = 0;
	
	reg l2ext_scal = 0;
	reg l2ext_pipe = 0;
	
	reg l3ext_scal = 0;
	reg l3ext_pipe = 0;
	
	reg l4ext_scal = 0;
	reg l4ext_pipe = 0;
	always @(posedge fclk_i) begin
		l1ext_pipe <= |l1ext;
		l1ext_scal <= l1ext_pipe;
		l2ext_pipe <= |l2ext;
		l2ext_scal <= l2ext_pipe;
		l3ext_pipe <= |l3ext;
		l3ext_scal <= l3ext_pipe;
		
		l4ext_pipe <= |l4ext;
		l4ext_scal <= l4ext_pipe;
	end
	
	//% Convenience function to convert a WISHBONE scaler address to the internal address space.
	function [6:0] BASE;
		input [15:0] bar_value;
		begin
			BASE[6:0] = bar_value[7:1];
		end
	endfunction

	always @(posedge wb_clk_i) begin
		if (cyc_i && stb_i && wr_i) begin
			if (adr_i[7:1] == BASE( 16'h01C0 ))
				l1ext_sel_i <= dat_i;
			if (adr_i[7:1] == BASE( 16'h01C2 ))
				l2ext_sel_i <= dat_i;
			if (adr_i[7:1] == BASE( 16'h01C4 ))
				l3ext_sel_i <= dat_i;
			if (adr_i[7:1] == BASE( 16'h01C6 ))
				l4ext_sel_i <= dat_i;
			if (adr_i[7:1] == BASE( 16'h01C8 ) && !adr_i[0]) begin
				ext_gate_count_update <= 1;
				ext_gate_count_max <= dat_i;
			end else begin
				ext_gate_count_update <= 0;
			end
			if (adr_i[7:1] == BASE( 16'h01C8) && adr_i[0])
				scal_ctl <= dat_i;
		end
	end
			
	

`define WISHBONE_ADDRESS(  addr , signal ) assign scaler_registers[ BASE( addr ) ] = signal
   ////////////////////////////////////////////////////
   //
   // WISHBONE REGISTER MAP (we have 0x100-0x1FF)
   //   
   ////////////////////////////////////////////////////

	`WISHBONE_ADDRESS( 16'h0100 , L1[0] );
	`WISHBONE_ADDRESS( 16'h0102 , L1[1] );
	`WISHBONE_ADDRESS( 16'h0104 , L1[2] );
	`WISHBONE_ADDRESS( 16'h0106 , L1[3] );
	`WISHBONE_ADDRESS( 16'h0108 , L1[4] );
	`WISHBONE_ADDRESS( 16'h010A , L1[5] );
	`WISHBONE_ADDRESS( 16'h010C , L1[6] );
	`WISHBONE_ADDRESS( 16'h010E , L1[7] );
	`WISHBONE_ADDRESS( 16'h0110 , L1[8] );
	`WISHBONE_ADDRESS( 16'h0112 , L1[9] );
	`WISHBONE_ADDRESS( 16'h0114 , L1[10] );
	`WISHBONE_ADDRESS( 16'h0116 , L1[11] );
	`WISHBONE_ADDRESS( 16'h0118 , L1[12] );
	`WISHBONE_ADDRESS( 16'h011A , L1[13] );
	`WISHBONE_ADDRESS( 16'h011C , L1[14] );
	`WISHBONE_ADDRESS( 16'h011E , L1[15] );
	`WISHBONE_ADDRESS( 16'h0120 , L1[16] );
	`WISHBONE_ADDRESS( 16'h0122 , L1[17] );
	`WISHBONE_ADDRESS( 16'h0124 , L1[18] );
	`WISHBONE_ADDRESS( 16'h0126 , L1[19] );	

	`WISHBONE_ADDRESS( 16'h0128 , L1[4] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h012A , L1[5] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h012C , L1[6] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h012E , L1[7] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0130 , L1[8] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0132 , L1[9] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0134 , L1[10] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h0136 , L1[11] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h0138 , L1[12] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h013A , L1[13] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h013C , L1[14] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h013E , L1[15] ); // SHADOW

	`WISHBONE_ADDRESS( 16'h0140 , L2[0] );
	`WISHBONE_ADDRESS( 16'h0142 , L2[1] );
	`WISHBONE_ADDRESS( 16'h0144 , L2[2] );
	`WISHBONE_ADDRESS( 16'h0146 , L2[3] );
	`WISHBONE_ADDRESS( 16'h0148 , L2[4] );
	`WISHBONE_ADDRESS( 16'h014A , L2[5] );
	`WISHBONE_ADDRESS( 16'h014C , L2[6] );
	`WISHBONE_ADDRESS( 16'h014E , L2[7] );
	`WISHBONE_ADDRESS( 16'h0150 , L2[8] );
	`WISHBONE_ADDRESS( 16'h0152 , L2[9] );
	`WISHBONE_ADDRESS( 16'h0154 , L2[10] );
	`WISHBONE_ADDRESS( 16'h0156 , L2[11] );
	`WISHBONE_ADDRESS( 16'h0158 , L2[12] );
	`WISHBONE_ADDRESS( 16'h015A , L2[13] );
	`WISHBONE_ADDRESS( 16'h015C , L2[14] );
	`WISHBONE_ADDRESS( 16'h015E , L2[15] );	
	`WISHBONE_ADDRESS( 16'h0160 , L2[0] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0162 , L2[1] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0164 , L2[2] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0166 , L2[3] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0168 , L2[4] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h016A , L2[5] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h016C , L2[6] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h016E , L2[7] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0170 , L2[8] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0172 , L2[9] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0174 , L2[10] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h0176 , L2[11] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h0178 , L2[12] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h017A , L2[13] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h017C , L2[14] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h017E , L2[15] ); // SHADOW

	`WISHBONE_ADDRESS( 16'h0180 , L3[0] );
	`WISHBONE_ADDRESS( 16'h0182 , L3[1] );
	`WISHBONE_ADDRESS( 16'h0184 , L3[2] );
	`WISHBONE_ADDRESS( 16'h0186 , L3[3] );
	`WISHBONE_ADDRESS( 16'h0188 , L3[4] );
	`WISHBONE_ADDRESS( 16'h018A , L3[5] );
	`WISHBONE_ADDRESS( 16'h018C , L3[6] );
	`WISHBONE_ADDRESS( 16'h018E , L3[7] );
	`WISHBONE_ADDRESS( 16'h0190 , L3[0] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0192 , L3[1] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0194 , L3[2] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0196 , L3[3] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h0198 , L3[4] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h019A , L3[5] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h019C , L3[6] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h019E , L3[7] );  // SHADOW

	`WISHBONE_ADDRESS( 16'h01A0 , L4[0] );  
	`WISHBONE_ADDRESS( 16'h01A2 , L4[1] );  
	`WISHBONE_ADDRESS( 16'h01A4 , L4[2] );  
	`WISHBONE_ADDRESS( 16'h01A6 , L4[3] );  
	`WISHBONE_ADDRESS( 16'h01A8 , L4[4] ); 
	`WISHBONE_ADDRESS( 16'h01AA , L4[1] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01AC , L4[2] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01AE , L4[3] );  // SHADOW

	`WISHBONE_ADDRESS( 16'h01B0 , T1 );  
	`WISHBONE_ADDRESS( 16'h01B2 , T1 );     // SHADOW
	`WISHBONE_ADDRESS( 16'h01B4 , T1 );     // SHADOW
	`WISHBONE_ADDRESS( 16'h01B6 , T1 );     // SHADOW
	`WISHBONE_ADDRESS( 16'h01B8 , blockrate );
	`WISHBONE_ADDRESS( 16'h01BA , blockrate );     // SHADOW
	`WISHBONE_ADDRESS( 16'h01BC , blockrate );     // SHADOW
	`WISHBONE_ADDRESS( 16'h01BE , blockrate );     // SHADOW
	
	`WISHBONE_ADDRESS( 16'h01C0 , L1_and_ext );
	`WISHBONE_ADDRESS( 16'h01C2 , L2_and_ext );
	`WISHBONE_ADDRESS( 16'h01C4 , L3_and_ext );
	`WISHBONE_ADDRESS( 16'h01C6 , L4_and_ext );
	`WISHBONE_ADDRESS( 16'h01C8 , ext_gate_count_max_and_scal_ctl );
	`WISHBONE_ADDRESS( 16'h01CA , L2[5] );
	`WISHBONE_ADDRESS( 16'h01CC , L2[6] );
	`WISHBONE_ADDRESS( 16'h01CE , L2[7] );
	`WISHBONE_ADDRESS( 16'h01D0 , L2[8] );
	`WISHBONE_ADDRESS( 16'h01D2 , L2[9] );
	`WISHBONE_ADDRESS( 16'h01D4 , L2[10] );
	`WISHBONE_ADDRESS( 16'h01D6 , L2[11] );
	`WISHBONE_ADDRESS( 16'h01D8 , L2[12] );
	`WISHBONE_ADDRESS( 16'h01DA , L2[13] );
	`WISHBONE_ADDRESS( 16'h01DC , L2[14] );
	`WISHBONE_ADDRESS( 16'h01DE , L2[15] );	
	`WISHBONE_ADDRESS( 16'h01E0 , L2[0] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01E2 , L2[1] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01E4 , L2[2] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01E6 , L2[3] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01E8 , L2[4] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01EA , L2[5] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01EC , L2[6] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01EE , L2[7] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01F0 , L2[8] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01F2 , L2[9] );  // SHADOW
	`WISHBONE_ADDRESS( 16'h01F4 , L2[10] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h01F6 , L2[11] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h01F8 , L2[12] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h01FA , L2[13] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h01FC , L2[14] ); // SHADOW
	`WISHBONE_ADDRESS( 16'h01FE , L2[15] ); // SHADOW
`undef WISHBONE_ADDRESS
   ////////////////////////////////////////////////////
   //
   // SCALERS
   //   
   ////////////////////////////////////////////////////

	// Basic scaler macro.
`define SCALERLOOP(name,max,in,out)                                                                \
	generate                                                                                        \
		genvar name``_i;                                                                             \
		for (name``_i=0;name``_i < max ; name``_i = name``_i + 1) begin : name``LOOP                 \
			par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS( name``_PRESCALE_BITS( name``_i ))) \
				name``_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),          \
								  .in_clkA_i( in``[ name``_i ] ),                                          \
								  .out_clkB_o( out``[ name``_i ] ));                                       \
		end                                                                                          \
	endgenerate

`define VARSCALERLOOP(name,max,in,out)                                                                \
	generate                                                                                        \
		genvar name``_i;                                                                             \
		for (name``_i=0;name``_i < max ; name``_i = name``_i + 1) begin : name``LOOP                 \
			par_and_var_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS( name``_PRESCALE_BITS( name``_i ))) \
				name``_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),          \
								  .prescale_i(!scal_ctl[0]),																\
								  .in_clkA_i( in``[ name``_i ] ),                                          \
								  .out_clkB_o( out``[ name``_i ] ));                                       \
		end                                                                                          \
	endgenerate


	`VARSCALERLOOP( L1 , NUM_L1 , l1_scal_i , L1 )
	`SCALERLOOP( L2 , NUM_L2 , l2_scal_i , L2 )
	`SCALERLOOP( L3 , NUM_L3 , l3_scal_i , L3 )
	`SCALERLOOP( L4 , NUM_L4 , l4_scal_i , L4 )

	wire t1_scaler_edge;
	SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"),.LATENCY(1)) t1_scal_gen(.I(t1_scal_i),.O(t1_scaler_edge),.CLK(fclk_i));

	//% T1 scaler (new event rate)
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(T1_PRESCALE_BITS(0)))
		t1_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
					 .in_clkA_i(t1_scaler_edge),
					 .out_clkB_o(T1));

	//% Block rate scaler. Prescale by 1 because we need to divide by 2 (1 block/2 cycles).
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(1))
		br_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
					 .in_clkA_i(t1_scal_i),
					 .out_clkB_o(blockrate));

	//% Gated EXT scalers.
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(0))
		l1ext_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
						 .in_clkA_i(l1ext_scal),
						 .out_clkB_o(L1_and_ext));
						 
	//% Gated EXT scalers.
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(0))
		l2ext_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
						 .in_clkA_i(l2ext_scal),
						 .out_clkB_o(L2_and_ext));

	//% Gated EXT scalers.
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(0))
		l3ext_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
						 .in_clkA_i(l3ext_scal),
						 .out_clkB_o(L3_and_ext));

	//% Gated EXT scalers.
	par_scaler #(.OUTPUT_BITS(OUTPUT_BITS),.PRESCALE_BITS(0))
		l4ext_scaler(.clkA_i(fclk_i),.clkB_i(wb_clk_i),.latch_clkA_i(pps_flag_fclk_i),
						 .in_clkA_i(l4ext_scal),
						 .out_clkB_o(L4_and_ext));

`undef SCALERLOOP
	

   ////////////////////////////////////////////////////
   //
   // WISHBONE LOGIC
   //   
   ////////////////////////////////////////////////////

					 
	//% WISHBONE acknowledge logic. We have 1 cycle of latency. 
	always @(posedge wb_clk_i) begin : WB_ACK_LOGIC
		if (!wb_ack)
			wb_ack <= cyc_i && stb_i;
		else
			wb_ack <= 0;
	end
	
	//% Demultiplexing. Synthesis should hopefully pick up the reduced logic levels.
	always @(posedge wb_clk_i) begin : DEMUX_LOGIC
		if (cyc_i && stb_i) begin
			muxed_register_out <= scaler_registers[adr_i[7:1]];
		end
	end

	//% WISHBONE acknowledge
	assign ack_o = wb_ack;
	//% No retry.
	assign rty_o = 1'b0;
	//% No errors.
	assign err_o = 1'b0;
	
	//% Demux the 16-bit output to an 8 bit output.
	assign dat_o = (adr_i[0]) ? muxed_register_out[15:8] : muxed_register_out[7:0];
	
	// And we're done. That was easy!
endmodule
