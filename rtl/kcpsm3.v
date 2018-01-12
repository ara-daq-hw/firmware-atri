////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2004 Xilinx, Inc.
// All Rights Reserved
////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: 1.30
//  \   \         Filename: kcpsm3.v
//  /   /         Date Last Modified:  August 5 2004
// /___/   /\     Date Created: May 19 2003
// \   \  /  \
//  \___\/\___\
//
//Device:  	Xilinx
//Purpose: 	
// Constant (K) Coded Programmable State Machine for Spartan-3 Devices.
// Also suitable for use with Virtex-II and Virtex-IIPRO devices.
//
// Includes additional code for enhanced verilog simulation. 
//
// Instruction disassembly concept inspired by the work of Prof. Dr.-Ing. Bernhard Lang.
// University of Applied Sciences, Osnabrueck, Germany.
//
// Format of this file.
//	--------------------
// This file contains the definition of KCPSM3 as one complete module This 'flat' 
// approach has been adopted to decrease 
// the time taken to load the module into simulators and the synthesis process.
//
// The module defines the implementation of the logic using Xilinx primitives.
// These ensure predictable synthesis results and maximise the density of the implementation. 
//
//Reference:
// 	None
//Revision History:
//    Rev 1.00 - kc -  Start of design entry,  May 19 2003.
//    Rev 1.20 - njs - Converted to verilog,  July 20 2004.
// 		Verilog version creation supported by Chip Lukes, 
//		Advanced Electronic Designs, Inc.
//		www.aedbozeman.com,
// 		chip.lukes@aedmt.com
//	Rev 1.21 - sus - Added text to adhere to HDL standard, August 4 2004. 
//	Rev 1.30 - njs - Updated as per VHDL version 1.30 August 5 2004. 
// Rev 1.30psa - psa - Changed to allow parameterized instantiation of scratchpad RAM. 1/6/2011
// Rev 1.30psa2 - psa - Changed to use only Verilog # for parameters (no defparams). 6/24/2011
// Rev 1.30psa3 - psa - Changed to allow mapping SPRAM to port access so that "in/out" can also
//                      be used.
//
////////////////////////////////////////////////////////////////////////////////
// Contact: e-mail  picoblaze@xilinx.com
//////////////////////////////////////////////////////////////////////////////////
//
// Disclaimer: 
// LIMITED WARRANTY AND DISCLAIMER. These designs are
// provided to you "as is". Xilinx and its licensors make and you
// receive no warranties or conditions, express, implied,
// statutory or otherwise, and Xilinx specifically disclaims any
// implied warranties of merchantability, non-infringement, or
// fitness for a particular purpose. Xilinx does not warrant that
// the functions contained in these designs will meet your
// requirements, or that the operation of these designs will be
// uninterrupted or error free, or that defects in the Designs
// will be corrected. Furthermore, Xilinx does not warrant or
// make any representations regarding use or the results of the
// use of the designs in terms of correctness, accuracy,
// reliability, or otherwise.
//
// LIMITATION OF LIABILITY. In no event will Xilinx or its
// licensors be liable for any loss of data, lost profits, cost
// or procurement of substitute goods or services, or for any
// special, incidental, consequential, or indirect damages
// arising from the use or operation of the designs or
// accompanying documentation, however caused and on any theory
// of liability. This limitation will apply even if Xilinx
// has been advised of the possibility of such damage. This
// limitation shall apply not-withstanding the failure of the 
// essential purpose of any limited remedies herein. 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1 ps / 1ps

module kcpsm3(
 	address,
 	instruction,
 	port_id,
 	write_strobe,
 	out_port,
 	read_strobe,
 	in_port,
 	interrupt,
 	interrupt_ack,
 	reset,
 	clk,
	spram_data,
	spram_port_en
	) ;
 
output 	[9:0]	address ;
input 	[17:0]	instruction ;
output 	[7:0]	port_id ;
output 		write_strobe, read_strobe, interrupt_ack ;
output 	[7:0]	out_port ;
input 	[7:0]	in_port ;
output   [7:0] spram_data ;
input	   spram_port_en ;
input		interrupt, reset, clk ;

////////////////////////////////////////////////////////////////////////////////////
//
// Parameters. Initialize scratchpad RAM and interrupt vector.
//
////////////////////////////////////////////////////////////////////////////////////

parameter [7:0] RAM_00 = {8{1'b0}};
parameter [7:0] RAM_01 = {8{1'b0}};
parameter [7:0] RAM_02 = {8{1'b0}};
parameter [7:0] RAM_03 = {8{1'b0}};
parameter [7:0] RAM_04 = {8{1'b0}};
parameter [7:0] RAM_05 = {8{1'b0}};
parameter [7:0] RAM_06 = {8{1'b0}};
parameter [7:0] RAM_07 = {8{1'b0}};
parameter [7:0] RAM_08 = {8{1'b0}};
parameter [7:0] RAM_09 = {8{1'b0}};
parameter [7:0] RAM_0A = {8{1'b0}};
parameter [7:0] RAM_0B = {8{1'b0}};
parameter [7:0] RAM_0C = {8{1'b0}};
parameter [7:0] RAM_0D = {8{1'b0}};
parameter [7:0] RAM_0E = {8{1'b0}};
parameter [7:0] RAM_0F = {8{1'b0}};

parameter [7:0] RAM_10 = {8{1'b0}};
parameter [7:0] RAM_11 = {8{1'b0}};
parameter [7:0] RAM_12 = {8{1'b0}};
parameter [7:0] RAM_13 = {8{1'b0}};
parameter [7:0] RAM_14 = {8{1'b0}};
parameter [7:0] RAM_15 = {8{1'b0}};
parameter [7:0] RAM_16 = {8{1'b0}};
parameter [7:0] RAM_17 = {8{1'b0}};
parameter [7:0] RAM_18 = {8{1'b0}};
parameter [7:0] RAM_19 = {8{1'b0}};
parameter [7:0] RAM_1A = {8{1'b0}};
parameter [7:0] RAM_1B = {8{1'b0}};
parameter [7:0] RAM_1C = {8{1'b0}};
parameter [7:0] RAM_1D = {8{1'b0}};
parameter [7:0] RAM_1E = {8{1'b0}};
parameter [7:0] RAM_1F = {8{1'b0}};

parameter [7:0] RAM_20 = {8{1'b0}};
parameter [7:0] RAM_21 = {8{1'b0}};
parameter [7:0] RAM_22 = {8{1'b0}};
parameter [7:0] RAM_23 = {8{1'b0}};
parameter [7:0] RAM_24 = {8{1'b0}};
parameter [7:0] RAM_25 = {8{1'b0}};
parameter [7:0] RAM_26 = {8{1'b0}};
parameter [7:0] RAM_27 = {8{1'b0}};
parameter [7:0] RAM_28 = {8{1'b0}};
parameter [7:0] RAM_29 = {8{1'b0}};
parameter [7:0] RAM_2A = {8{1'b0}};
parameter [7:0] RAM_2B = {8{1'b0}};
parameter [7:0] RAM_2C = {8{1'b0}};
parameter [7:0] RAM_2D = {8{1'b0}};
parameter [7:0] RAM_2E = {8{1'b0}};
parameter [7:0] RAM_2F = {8{1'b0}};

parameter [7:0] RAM_30 = {8{1'b0}};
parameter [7:0] RAM_31 = {8{1'b0}};
parameter [7:0] RAM_32 = {8{1'b0}};
parameter [7:0] RAM_33 = {8{1'b0}};
parameter [7:0] RAM_34 = {8{1'b0}};
parameter [7:0] RAM_35 = {8{1'b0}};
parameter [7:0] RAM_36 = {8{1'b0}};
parameter [7:0] RAM_37 = {8{1'b0}};
parameter [7:0] RAM_38 = {8{1'b0}};
parameter [7:0] RAM_39 = {8{1'b0}};
parameter [7:0] RAM_3A = {8{1'b0}};
parameter [7:0] RAM_3B = {8{1'b0}};
parameter [7:0] RAM_3C = {8{1'b0}};
parameter [7:0] RAM_3D = {8{1'b0}};
parameter [7:0] RAM_3E = {8{1'b0}};
parameter [7:0] RAM_3F = {8{1'b0}};

parameter [9:0] INTERRUPT_VECTOR = 10'h3FF;

localparam [63:0] RAM_INIT_0 = {
RAM_3F[0],RAM_3E[0],RAM_3D[0],RAM_3C[0],RAM_3B[0],RAM_3A[0],RAM_39[0],RAM_38[0],
RAM_37[0],RAM_36[0],RAM_35[0],RAM_34[0],RAM_33[0],RAM_32[0],RAM_31[0],RAM_30[0],
RAM_2F[0],RAM_2E[0],RAM_2D[0],RAM_2C[0],RAM_2B[0],RAM_2A[0],RAM_29[0],RAM_28[0],
RAM_27[0],RAM_26[0],RAM_25[0],RAM_24[0],RAM_23[0],RAM_22[0],RAM_21[0],RAM_20[0],
RAM_1F[0],RAM_1E[0],RAM_1D[0],RAM_1C[0],RAM_1B[0],RAM_1A[0],RAM_19[0],RAM_18[0],
RAM_17[0],RAM_16[0],RAM_15[0],RAM_14[0],RAM_13[0],RAM_12[0],RAM_11[0],RAM_10[0],
RAM_0F[0],RAM_0E[0],RAM_0D[0],RAM_0C[0],RAM_0B[0],RAM_0A[0],RAM_09[0],RAM_08[0],
RAM_07[0],RAM_06[0],RAM_05[0],RAM_04[0],RAM_03[0],RAM_02[0],RAM_01[0],RAM_00[0]};
localparam [63:0] RAM_INIT_1 = {
RAM_3F[1],RAM_3E[1],RAM_3D[1],RAM_3C[1],RAM_3B[1],RAM_3A[1],RAM_39[1],RAM_38[1],
RAM_37[1],RAM_36[1],RAM_35[1],RAM_34[1],RAM_33[1],RAM_32[1],RAM_31[1],RAM_30[1],
RAM_2F[1],RAM_2E[1],RAM_2D[1],RAM_2C[1],RAM_2B[1],RAM_2A[1],RAM_29[1],RAM_28[1],
RAM_27[1],RAM_26[1],RAM_25[1],RAM_24[1],RAM_23[1],RAM_22[1],RAM_21[1],RAM_20[1],
RAM_1F[1],RAM_1E[1],RAM_1D[1],RAM_1C[1],RAM_1B[1],RAM_1A[1],RAM_19[1],RAM_18[1],
RAM_17[1],RAM_16[1],RAM_15[1],RAM_14[1],RAM_13[1],RAM_12[1],RAM_11[1],RAM_10[1],
RAM_0F[1],RAM_0E[1],RAM_0D[1],RAM_0C[1],RAM_0B[1],RAM_0A[1],RAM_09[1],RAM_08[1],
RAM_07[1],RAM_06[1],RAM_05[1],RAM_04[1],RAM_03[1],RAM_02[1],RAM_01[1],RAM_00[1]};
localparam [63:0] RAM_INIT_2 = {
RAM_3F[2],RAM_3E[2],RAM_3D[2],RAM_3C[2],RAM_3B[2],RAM_3A[2],RAM_39[2],RAM_38[2],
RAM_37[2],RAM_36[2],RAM_35[2],RAM_34[2],RAM_33[2],RAM_32[2],RAM_31[2],RAM_30[2],
RAM_2F[2],RAM_2E[2],RAM_2D[2],RAM_2C[2],RAM_2B[2],RAM_2A[2],RAM_29[2],RAM_28[2],
RAM_27[2],RAM_26[2],RAM_25[2],RAM_24[2],RAM_23[2],RAM_22[2],RAM_21[2],RAM_20[2],
RAM_1F[2],RAM_1E[2],RAM_1D[2],RAM_1C[2],RAM_1B[2],RAM_1A[2],RAM_19[2],RAM_18[2],
RAM_17[2],RAM_16[2],RAM_15[2],RAM_14[2],RAM_13[2],RAM_12[2],RAM_11[2],RAM_10[2],
RAM_0F[2],RAM_0E[2],RAM_0D[2],RAM_0C[2],RAM_0B[2],RAM_0A[2],RAM_09[2],RAM_08[2],
RAM_07[2],RAM_06[2],RAM_05[2],RAM_04[2],RAM_03[2],RAM_02[2],RAM_01[2],RAM_00[2]};
localparam [63:0] RAM_INIT_3 = {
RAM_3F[3],RAM_3E[3],RAM_3D[3],RAM_3C[3],RAM_3B[3],RAM_3A[3],RAM_39[3],RAM_38[3],
RAM_37[3],RAM_36[3],RAM_35[3],RAM_34[3],RAM_33[3],RAM_32[3],RAM_31[3],RAM_30[3],
RAM_2F[3],RAM_2E[3],RAM_2D[3],RAM_2C[3],RAM_2B[3],RAM_2A[3],RAM_29[3],RAM_28[3],
RAM_27[3],RAM_26[3],RAM_25[3],RAM_24[3],RAM_23[3],RAM_22[3],RAM_21[3],RAM_20[3],
RAM_1F[3],RAM_1E[3],RAM_1D[3],RAM_1C[3],RAM_1B[3],RAM_1A[3],RAM_19[3],RAM_18[3],
RAM_17[3],RAM_16[3],RAM_15[3],RAM_14[3],RAM_13[3],RAM_12[3],RAM_11[3],RAM_10[3],
RAM_0F[3],RAM_0E[3],RAM_0D[3],RAM_0C[3],RAM_0B[3],RAM_0A[3],RAM_09[3],RAM_08[3],
RAM_07[3],RAM_06[3],RAM_05[3],RAM_04[3],RAM_03[3],RAM_02[3],RAM_01[3],RAM_00[3]};
localparam [63:0] RAM_INIT_4 = {
RAM_3F[4],RAM_3E[4],RAM_3D[4],RAM_3C[4],RAM_3B[4],RAM_3A[4],RAM_39[4],RAM_38[4],
RAM_37[4],RAM_36[4],RAM_35[4],RAM_34[4],RAM_33[4],RAM_32[4],RAM_31[4],RAM_30[4],
RAM_2F[4],RAM_2E[4],RAM_2D[4],RAM_2C[4],RAM_2B[4],RAM_2A[4],RAM_29[4],RAM_28[4],
RAM_27[4],RAM_26[4],RAM_25[4],RAM_24[4],RAM_23[4],RAM_22[4],RAM_21[4],RAM_20[4],
RAM_1F[4],RAM_1E[4],RAM_1D[4],RAM_1C[4],RAM_1B[4],RAM_1A[4],RAM_19[4],RAM_18[4],
RAM_17[4],RAM_16[4],RAM_15[4],RAM_14[4],RAM_13[4],RAM_12[4],RAM_11[4],RAM_10[4],
RAM_0F[4],RAM_0E[4],RAM_0D[4],RAM_0C[4],RAM_0B[4],RAM_0A[4],RAM_09[4],RAM_08[4],
RAM_07[4],RAM_06[4],RAM_05[4],RAM_04[4],RAM_03[4],RAM_02[4],RAM_01[4],RAM_00[4]};
localparam [63:0] RAM_INIT_5 = {
RAM_3F[5],RAM_3E[5],RAM_3D[5],RAM_3C[5],RAM_3B[5],RAM_3A[5],RAM_39[5],RAM_38[5],
RAM_37[5],RAM_36[5],RAM_35[5],RAM_34[5],RAM_33[5],RAM_32[5],RAM_31[5],RAM_30[5],
RAM_2F[5],RAM_2E[5],RAM_2D[5],RAM_2C[5],RAM_2B[5],RAM_2A[5],RAM_29[5],RAM_28[5],
RAM_27[5],RAM_26[5],RAM_25[5],RAM_24[5],RAM_23[5],RAM_22[5],RAM_21[5],RAM_20[5],
RAM_1F[5],RAM_1E[5],RAM_1D[5],RAM_1C[5],RAM_1B[5],RAM_1A[5],RAM_19[5],RAM_18[5],
RAM_17[5],RAM_16[5],RAM_15[5],RAM_14[5],RAM_13[5],RAM_12[5],RAM_11[5],RAM_10[5],
RAM_0F[5],RAM_0E[5],RAM_0D[5],RAM_0C[5],RAM_0B[5],RAM_0A[5],RAM_09[5],RAM_08[5],
RAM_07[5],RAM_06[5],RAM_05[5],RAM_04[5],RAM_03[5],RAM_02[5],RAM_01[5],RAM_00[5]};
localparam [63:0] RAM_INIT_6 = {
RAM_3F[6],RAM_3E[6],RAM_3D[6],RAM_3C[6],RAM_3B[6],RAM_3A[6],RAM_39[6],RAM_38[6],
RAM_37[6],RAM_36[6],RAM_35[6],RAM_34[6],RAM_33[6],RAM_32[6],RAM_31[6],RAM_30[6],
RAM_2F[6],RAM_2E[6],RAM_2D[6],RAM_2C[6],RAM_2B[6],RAM_2A[6],RAM_29[6],RAM_28[6],
RAM_27[6],RAM_26[6],RAM_25[6],RAM_24[6],RAM_23[6],RAM_22[6],RAM_21[6],RAM_20[6],
RAM_1F[6],RAM_1E[6],RAM_1D[6],RAM_1C[6],RAM_1B[6],RAM_1A[6],RAM_19[6],RAM_18[6],
RAM_17[6],RAM_16[6],RAM_15[6],RAM_14[6],RAM_13[6],RAM_12[6],RAM_11[6],RAM_10[6],
RAM_0F[6],RAM_0E[6],RAM_0D[6],RAM_0C[6],RAM_0B[6],RAM_0A[6],RAM_09[6],RAM_08[6],
RAM_07[6],RAM_06[6],RAM_05[6],RAM_04[6],RAM_03[6],RAM_02[6],RAM_01[6],RAM_00[6]};
localparam [63:0] RAM_INIT_7 = {
RAM_3F[7],RAM_3E[7],RAM_3D[7],RAM_3C[7],RAM_3B[7],RAM_3A[7],RAM_39[7],RAM_38[7],
RAM_37[7],RAM_36[7],RAM_35[7],RAM_34[7],RAM_33[7],RAM_32[7],RAM_31[7],RAM_30[7],
RAM_2F[7],RAM_2E[7],RAM_2D[7],RAM_2C[7],RAM_2B[7],RAM_2A[7],RAM_29[7],RAM_28[7],
RAM_27[7],RAM_26[7],RAM_25[7],RAM_24[7],RAM_23[7],RAM_22[7],RAM_21[7],RAM_20[7],
RAM_1F[7],RAM_1E[7],RAM_1D[7],RAM_1C[7],RAM_1B[7],RAM_1A[7],RAM_19[7],RAM_18[7],
RAM_17[7],RAM_16[7],RAM_15[7],RAM_14[7],RAM_13[7],RAM_12[7],RAM_11[7],RAM_10[7],
RAM_0F[7],RAM_0E[7],RAM_0D[7],RAM_0C[7],RAM_0B[7],RAM_0A[7],RAM_09[7],RAM_08[7],
RAM_07[7],RAM_06[7],RAM_05[7],RAM_04[7],RAM_03[7],RAM_02[7],RAM_01[7],RAM_00[7]};


//
////////////////////////////////////////////////////////////////////////////////////
//
// Start of Main Architecture for KCPSM3
//
////////////////////////////////////////////////////////////////////////////////////
//
// Signals used in KCPSM3
//
////////////////////////////////////////////////////////////////////////////////////
//
// Fundamental control and decode signals
//	 
wire 		t_state ;
wire 		not_t_state ;
wire 		internal_reset ;
wire 		reset_delay ;
wire 		move_group ;
wire 		condition_met ;
wire 		normal_count ;
wire 		call_type ;
wire 		push_or_pop_type ;
wire 		valid_to_move ;
//
// Flag signals
// 
wire 		flag_type ;
wire 		flag_write ;
wire 		flag_enable ;
wire 		zero_flag ;
wire 		sel_shadow_zero ;
wire 		low_zero ;
wire 		high_zero ;
wire 		low_zero_carry ;
wire 		high_zero_carry ;
wire 		zero_carry ;
wire 		zero_fast_route ;
wire 		low_parity ;
wire 		high_parity ;
wire 		parity_carry ;
wire 		parity ;
wire 		carry_flag ;
wire 		sel_parity ;
wire 		sel_arith_carry ;
wire 		sel_shift_carry ;
wire 		sel_shadow_carry ;
wire 	[3:0]	sel_carry ;
wire 		carry_fast_route ;
//
// Interrupt signals
// 
wire 		active_interrupt ;
wire 		int_pulse ;
wire 		clean_int ;
wire 		shadow_carry ;
wire 		shadow_zero ;
wire 		int_enable ;
wire 		int_update_enable ;
wire 		int_enable_value ;
wire 		interrupt_ack_internal ;
//
// Program Counter signals
//
wire 	[9:0]	pc ;
wire 	[9:0]	pc_vector ;
wire 	[8:0]	pc_vector_carry ;
wire 	[9:0]	inc_pc_vector ;
wire 	[9:0]	pc_value ;
wire 	[8:0]	pc_value_carry ;
wire 	[9:0]	inc_pc_value ;
wire 		pc_enable ;
//
// Data Register signals
//
wire 	[7:0]	sx ;
wire 	[7:0]	sy ;
wire 		register_type ;
wire 		register_write ;
wire 		register_enable ;
wire 	[7:0]	second_operand ;
//
// Scratch Pad Memory signals
//
wire 	[7:0]	memory_data ;
wire 	[7:0]	store_data ;
wire 		memory_type ;
wire 		memory_write ;
wire 		memory_enable ;
//
// Stack signals
//
wire 	[9:0]	stack_pop_data ;
wire 	[9:0]	stack_ram_data ;
wire 	[4:0]	stack_address ;
wire 	[4:0]	half_stack_address ;
wire 	[3:0]	stack_address_carry ;
wire 	[4:0]	next_stack_address ;
wire 		stack_write_enable ;
wire 		not_active_interrupt ;
//
// ALU signals
//
wire 	[7:0]	logical_result ;
wire 	[7:0]	logical_value ;
wire 		sel_logical ;
wire 	[7:0]	shift_result ;
wire 	[7:0]	shift_value ;
wire 		sel_shift ;
wire 		high_shift_in ;
wire 		low_shift_in ;
wire 		shift_in ;
wire 		shift_carry ;
wire 		shift_carry_value ;
wire 	[7:0]	arith_result ;
wire 	[7:0]	arith_value ;
wire 	[7:0]	half_arith ;
wire 	[7:0]	arith_internal_carry ;
wire 		sel_arith_carry_in ;
wire 		arith_carry_in ;
wire 		invert_arith_carry ;
wire 		arith_carry_out ;
wire 		sel_arith ;
wire 		arith_carry ;
//
// ALU multiplexer signals
//
wire 		input_fetch_type ;
wire 		sel_group ;
wire 	[7:0]	alu_group ;
wire 	[7:0]	input_group ;
wire 	[7:0]	alu_result ;
//
// read and write strobes 
//
wire 		io_initial_decode ;
wire 		write_active ;
wire 		read_active ;

////////////////////////////////////////////////////////////////////////////////////
//
// Start of KCPSM3 circuit description
//
////////////////////////////////////////////////////////////////////////////////////
//
// Fundamental Control
//
// Definition of T-state and internal reset
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT1 #(.INIT(2'h1)) t_state_lut( 
 .I0(t_state),
 .O(not_t_state));

 FDR toggle_flop ( 
 .D(not_t_state),
 .Q(t_state),
 .R(internal_reset),
 .C(clk));

 FDS reset_flop1 ( 
 .D(1'b0),
 .Q(reset_delay),
 .S(reset),
 .C(clk));

 FDS reset_flop2 ( 
 .D(reset_delay),
 .Q(internal_reset),
 .S(reset),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// Interrupt input logic, Interrupt enable and shadow Flags.
//	
// Captures interrupt input and enables the shadow flags.
// Decodes instructions which set and reset the interrupt enable flip-flop. 
//
////////////////////////////////////////////////////////////////////////////////////
//
 // Interrupt capture

 FDR int_capture_flop ( 
 .D(interrupt),
 .Q(clean_int),
 .R(internal_reset),
 .C(clk));

 LUT4 #(.INIT(16'h0080)) int_pulse_lut ( 
 .I0(t_state),
 .I1(clean_int),
 .I2(int_enable),
 .I3(active_interrupt),
 .O(int_pulse ));
 
 FDR int_flop ( 
 .D(int_pulse),
 .Q(active_interrupt),
 .R(internal_reset),
 .C(clk));

 FD ack_flop ( 
 .D(active_interrupt),
 .Q(interrupt_ack_internal),
 .C(clk));

 assign interrupt_ack = interrupt_ack_internal ;

 // Shadow flags

 FDE shadow_carry_flop ( 
 .D(carry_flag),
 .Q(shadow_carry),
 .CE(active_interrupt),
 .C(clk));

 FDE shadow_zero_flop ( 
 .D(zero_flag),
 .Q(shadow_zero),
 .CE(active_interrupt),
 .C(clk));

 // Decode instructions that set or reset interrupt enable

 LUT4 #(.INIT(16'hEAAA)) int_update_lut( 
 .I0(active_interrupt),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(int_update_enable) );
 
 LUT3 #(.INIT(8'h04)) int_value_lut ( 
 .I0(active_interrupt),
 .I1(instruction[0]),
 .I2(interrupt_ack_internal),
 .O(int_enable_value ));
 
 FDRE int_enable_flop ( 
 .D(int_enable_value),
 .Q(int_enable),
 .CE(int_update_enable),
 .R(internal_reset),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// Decodes for the control of the program counter and CALL/RETURN stack
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT4 #(.INIT(16'h7400)) move_group_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(move_group));
 
 LUT4 #(.INIT(16'h5A3C)) condition_met_lut ( 
 .I0(carry_flag),
 .I1(zero_flag),
 .I2(instruction[10]),
 .I3(instruction[11]),
 .O(condition_met));
 
 LUT3 #(.INIT(8'h2F)) normal_count_lut ( 
 .I0(instruction[12]),
 .I1(condition_met),
 .I2(move_group),
 .O(normal_count ));
 
 LUT4 #(.INIT(16'h1000)) call_type_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(call_type ));
 
 LUT4 #(.INIT(16'h5400)) push_pop_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(push_or_pop_type));
 
 LUT2 #(.INIT(4'hD)) valid_move_lut ( 
 .I0(instruction[12]),
 .I1(condition_met),
 .O(valid_to_move ));
//
////////////////////////////////////////////////////////////////////////////////////
//
// The ZERO and CARRY Flags
//
////////////////////////////////////////////////////////////////////////////////////
//
 // Enable for flags

 LUT4 #(.INIT(16'h41FC)) flag_type_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(flag_type ));
 
 FD flag_write_flop ( 
 .D(flag_type),
 .Q(flag_write),
 .C(clk));

 LUT2 #(.INIT(4'h8)) flag_enable_lut ( 
 .I0(t_state),
 .I1(flag_write),
 .O(flag_enable));
 
 // Zero Flag

 LUT4 #(.INIT(16'h0001)) low_zero_lut ( 
 .I0(alu_result[0]),
 .I1(alu_result[1]),
 .I2(alu_result[2]),
 .I3(alu_result[3]),
 .O(low_zero ));
 
 LUT4 #(.INIT(16'h0001)) high_zero_lut ( 
 .I0(alu_result[4]),
 .I1(alu_result[5]),
 .I2(alu_result[6]),
 .I3(alu_result[7]),
 .O(high_zero ));
 
 MUXCY low_zero_muxcy ( 
 .DI(1'b0),
 .CI(1'b1),
 .S(low_zero),
 .O(low_zero_carry));

 MUXCY high_zero_cymux ( 
 .DI(1'b0),
 .CI(low_zero_carry),
 .S(high_zero),
 .O(high_zero_carry));

 LUT3 #(.INIT(8'h3F)) sel_shadow_zero_lut ( 
 .I0(shadow_zero),
 .I1(instruction[16]),
 .I2(instruction[17]),
 .O(sel_shadow_zero ));
 
 MUXCY zero_cymux ( 
 .DI(shadow_zero),
 .CI(high_zero_carry),
 .S(sel_shadow_zero),
 .O(zero_carry ));

 XORCY zero_xor( 
 .LI(1'b0),
 .CI(zero_carry),
 .O(zero_fast_route));
             
 FDRE zero_flag_flop ( 
 .D(zero_fast_route),
 .Q(zero_flag),
 .CE(flag_enable),
 .R(internal_reset),
 .C(clk));

 // Parity detection

 LUT4 #(.INIT(16'h6996)) low_parity_lut ( 
 .I0(logical_result[0]),
 .I1(logical_result[1]),
 .I2(logical_result[2]),
 .I3(logical_result[3]),
 .O(low_parity ));
 
 LUT4 #(.INIT(16'h6996)) high_parity_lut ( 
 .I0(logical_result[4]),
 .I1(logical_result[5]),
 .I2(logical_result[6]),
 .I3(logical_result[7]),
 .O(high_parity ));
 
 MUXCY parity_muxcy ( 
 .DI(1'b0),
 .CI(1'b1),
 .S(low_parity),
 .O(parity_carry) );

 XORCY parity_xor ( 
 .LI(high_parity),
 .CI(parity_carry),
 .O(parity));

 // CARRY flag selection

 LUT4 #(.INIT(16'hF3FF)) sel_parity_lut ( 
 .I0(parity),
 .I1(instruction[13]),
 .I2(instruction[15]),
 .I3(instruction[16]),
 .O(sel_parity ));
 
 LUT3 #(.INIT(8'hF3)) sel_arith_carry_lut ( 
 .I0(arith_carry),
 .I1(instruction[16]),
 .I2(instruction[17]),
 .O(sel_arith_carry ));
 
 LUT2 #(.INIT(4'hC)) sel_shift_carry_lut ( 
 .I0(shift_carry),
 .I1(instruction[15]),
 .O(sel_shift_carry ));
 
 LUT2 #(.INIT(4'h3)) sel_shadow_carry_lut ( 
 .I0(shadow_carry),
 .I1(instruction[17]),
 .O(sel_shadow_carry ));
 
 MUXCY sel_shadow_muxcy ( 
 .DI(shadow_carry),
 .CI(1'b0),
 .S(sel_shadow_carry),
 .O(sel_carry[0]) );

 MUXCY sel_shift_muxcy ( 
 .DI(shift_carry),
 .CI(sel_carry[0]),
 .S(sel_shift_carry),
 .O(sel_carry[1]) );

 MUXCY sel_arith_muxcy ( 
 .DI(arith_carry),
 .CI(sel_carry[1]),
 .S(sel_arith_carry),
 .O(sel_carry[2]) );

 MUXCY sel_parity_muxcy ( 
 .DI(parity),
 .CI(sel_carry[2]),
 .S(sel_parity),
 .O(sel_carry[3]) );

 XORCY carry_xor(
 .LI(1'b0),
 .CI(sel_carry[3]),
 .O(carry_fast_route));
             
 FDRE carry_flag_flop ( 
 .D(carry_fast_route),
 .Q(carry_flag),
 .CE(flag_enable),
 .R(internal_reset),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// The Program Counter
//
// Definition of a 10-bit counter which can be loaded from two sources
//
////////////////////////////////////////////////////////////////////////////////////
//	

 INV invert_enable(// Inverter should be implemented in the CE to flip flops
 .I(t_state),
 .O(pc_enable)); 
 
 // pc_loop

 LUT3 #(.INIT(8'hE4)) vector_select_mux_0 ( 
 .I0(instruction[15]),
 .I1(instruction[0]),
 .I2(stack_pop_data[0]), 
 .O(pc_vector[0]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_0(
 .I0(normal_count),
 .I1(inc_pc_vector[0]),
 .I2(pc[0]),
 .O(pc_value[0]));
 
 MUXCY pc_vector_muxcy_0 ( 
 .DI(1'b0),
 .CI(instruction[13]),
 .S(pc_vector[0]),
 .O(pc_vector_carry[0]));

 XORCY pc_vector_xor_0 ( 
 .LI(pc_vector[0]),
 .CI(instruction[13]),
 .O(inc_pc_vector[0]));

 MUXCY pc_value_muxcy_0 ( 
 .DI(1'b0),
 .CI(normal_count),
 .S(pc_value[0]),
 .O(pc_value_carry[0]));

 XORCY pc_value_xor_0 ( 
 .LI(pc_value[0]),
 .CI(normal_count),
 .O(inc_pc_value[0]));

 LUT3 #(.INIT(8'hE4)) vector_select_mux_1 ( 
 .I0(instruction[15]),
 .I1(instruction[1]),
 .I2(stack_pop_data[1]), 
 .O(pc_vector[1]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_1(
 .I0(normal_count),
 .I1(inc_pc_vector[1]),
 .I2(pc[1]),
 .O(pc_value[1]));
 
 MUXCY pc_vector_muxcy_1 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[0]),
 .S(pc_vector[1]),
 .O(pc_vector_carry[1]));

 XORCY pc_vector_xor_1 ( 
 .LI(pc_vector[1]),
 .CI(pc_vector_carry[0]),
 .O(inc_pc_vector[1]));

 MUXCY pc_value_muxcy_1 ( 
 .DI(1'b0),
 .CI(pc_value_carry[0]),
 .S(pc_value[1]),
 .O(pc_value_carry[1]));

 XORCY pc_value_xor_1 ( 
 .LI(pc_value[1]),
 .CI(pc_value_carry[0]),
 .O(inc_pc_value[1]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_2 ( 
 .I0(instruction[15]),
 .I1(instruction[2]),
 .I2(stack_pop_data[2]), 
 .O(pc_vector[2]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_2(
 .I0(normal_count),
 .I1(inc_pc_vector[2]),
 .I2(pc[2]),
 .O(pc_value[2]));
 

 MUXCY pc_vector_muxcy_2 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[1]),
 .S(pc_vector[2]),
 .O(pc_vector_carry[2]));

 XORCY pc_vector_xor_2 ( 
 .LI(pc_vector[2]),
 .CI(pc_vector_carry[1]),
 .O(inc_pc_vector[2]));

 MUXCY pc_value_muxcy_2 ( 
 .DI(1'b0),
 .CI(pc_value_carry[1]),
 .S(pc_value[2]),
 .O(pc_value_carry[2]));

 XORCY pc_value_xor_2 ( 
 .LI(pc_value[2]),
 .CI(pc_value_carry[1]),
 .O(inc_pc_value[2]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_3 ( 
 .I0(instruction[15]),
 .I1(instruction[3]),
 .I2(stack_pop_data[3]), 
 .O(pc_vector[3]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_3(
 .I0(normal_count),
 .I1(inc_pc_vector[3]),
 .I2(pc[3]),
 .O(pc_value[3]));
 
 MUXCY pc_vector_muxcy_3 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[2]),
 .S(pc_vector[3]),
 .O(pc_vector_carry[3]));

 XORCY pc_vector_xor_3 ( 
 .LI(pc_vector[3]),
 .CI(pc_vector_carry[2]),
 .O(inc_pc_vector[3]));

 MUXCY pc_value_muxcy_3 ( 
 .DI(1'b0),
 .CI(pc_value_carry[2]),
 .S(pc_value[3]),
 .O(pc_value_carry[3]));

 XORCY pc_value_xor_3 ( 
 .LI(pc_value[3]),
 .CI(pc_value_carry[2]),
 .O(inc_pc_value[3]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_4 ( 
 .I0(instruction[15]),
 .I1(instruction[4]),
 .I2(stack_pop_data[4]), 
 .O(pc_vector[4]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_4(
 .I0(normal_count),
 .I1(inc_pc_vector[4]),
 .I2(pc[4]),
 .O(pc_value[4]));

 MUXCY pc_vector_muxcy_4 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[3]),
 .S(pc_vector[4]),
 .O(pc_vector_carry[4]));

 XORCY pc_vector_xor_4 ( 
 .LI(pc_vector[4]),
 .CI(pc_vector_carry[3]),
 .O(inc_pc_vector[4]));

 MUXCY pc_value_muxcy_4 ( 
 .DI(1'b0),
 .CI(pc_value_carry[3]),
 .S(pc_value[4]),
 .O(pc_value_carry[4]));

 XORCY pc_value_xor_4 ( 
 .LI(pc_value[4]),
 .CI(pc_value_carry[3]),
 .O(inc_pc_value[4]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_5 ( 
 .I0(instruction[15]),
 .I1(instruction[5]),
 .I2(stack_pop_data[5]), 
 .O(pc_vector[5]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_5(
 .I0(normal_count),
 .I1(inc_pc_vector[5]),
 .I2(pc[5]),
 .O(pc_value[5]));
 

 MUXCY pc_vector_muxcy_5 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[4]),
 .S(pc_vector[5]),
 .O(pc_vector_carry[5]));

 XORCY pc_vector_xor_5 ( 
 .LI(pc_vector[5]),
 .CI(pc_vector_carry[4]),
 .O(inc_pc_vector[5]));

 MUXCY pc_value_muxcy_5 ( 
 .DI(1'b0),
 .CI(pc_value_carry[4]),
 .S(pc_value[5]),
 .O(pc_value_carry[5]));

 XORCY pc_value_xor_5 ( 
 .LI(pc_value[5]),
 .CI(pc_value_carry[4]),
 .O(inc_pc_value[5]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_6 ( 
 .I0(instruction[15]),
 .I1(instruction[6]),
 .I2(stack_pop_data[6]), 
 .O(pc_vector[6]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_6(
 .I0(normal_count),
 .I1(inc_pc_vector[6]),
 .I2(pc[6]),
 .O(pc_value[6]));
 

 MUXCY pc_vector_muxcy_6 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[5]),
 .S(pc_vector[6]),
 .O(pc_vector_carry[6]));

 XORCY pc_vector_xor_6 ( 
 .LI(pc_vector[6]),
 .CI(pc_vector_carry[5]),
 .O(inc_pc_vector[6]));

 MUXCY pc_value_muxcy_6 ( 
 .DI(1'b0),
 .CI(pc_value_carry[5]),
 .S(pc_value[6]),
 .O(pc_value_carry[6]));

 XORCY pc_value_xor_6 ( 
 .LI(pc_value[6]),
 .CI(pc_value_carry[5]),
 .O(inc_pc_value[6]));
     
 LUT3 #(.INIT(8'hE4)) vector_select_mux_7 ( 
 .I0(instruction[15]),
 .I1(instruction[7]),
 .I2(stack_pop_data[7]), 
 .O(pc_vector[7]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_7(
 .I0(normal_count),
 .I1(inc_pc_vector[7]),
 .I2(pc[7]),
 .O(pc_value[7]));
 

 MUXCY pc_vector_muxcy_7 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[6]),
 .S(pc_vector[7]),
 .O(pc_vector_carry[7]));

 XORCY pc_vector_xor_7 ( 
 .LI(pc_vector[7]),
 .CI(pc_vector_carry[6]),
 .O(inc_pc_vector[7]));

 MUXCY pc_value_muxcy_7 ( 
 .DI(1'b0),
 .CI(pc_value_carry[6]),
 .S(pc_value[7]),
 .O(pc_value_carry[7]));

 XORCY pc_value_xor_7 ( 
 .LI(pc_value[7]),
 .CI(pc_value_carry[6]),
 .O(inc_pc_value[7]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_8 ( 
 .I0(instruction[15]),
 .I1(instruction[8]),
 .I2(stack_pop_data[8]), 
 .O(pc_vector[8]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_8(
 .I0(normal_count),
 .I1(inc_pc_vector[8]),
 .I2(pc[8]),
 .O(pc_value[8]));
 

 MUXCY pc_vector_muxcy_8 ( 
 .DI(1'b0),
 .CI(pc_vector_carry[7]),
 .S(pc_vector[8]),
 .O(pc_vector_carry[8]));

 XORCY pc_vector_xor_8 ( 
 .LI(pc_vector[8]),
 .CI(pc_vector_carry[7]),
 .O(inc_pc_vector[8]));

 MUXCY pc_value_muxcy_8 ( 
 .DI(1'b0),
 .CI(pc_value_carry[7]),
 .S(pc_value[8]),
 .O(pc_value_carry[8]));

 XORCY pc_value_xor_8 ( 
 .LI(pc_value[8]),
 .CI(pc_value_carry[7]),
 .O(inc_pc_value[8]));
 
 LUT3 #(.INIT(8'hE4)) vector_select_mux_9 ( 
 .I0(instruction[15]),
 .I1(instruction[9]),
 .I2(stack_pop_data[9]), 
 .O(pc_vector[9]));
 
 LUT3 #(.INIT(8'hE4)) value_select_mux_9(
 .I0(normal_count),
 .I1(inc_pc_vector[9]),
 .I2(pc[9]),
 .O(pc_value[9]));
 
 XORCY pc_vector_xor_high ( 
 .LI(pc_vector[9]),
 .CI(pc_vector_carry[8]),
 .O(inc_pc_vector[9]));

 XORCY pc_value_xor_high ( 
 .LI(pc_value[9]),
 .CI(pc_value_carry[8]),
 .O(inc_pc_value[9]));

	// PSA: allow parameterized interrupt vector.
	generate
		genvar i;
		for (i=0;i<10;i=i+1) begin : PC
			if (INTERRUPT_VECTOR[i]) begin : SET
			 FDRSE pc_loop_register_bit ( 
			 .D(inc_pc_value[i]),
			 .Q(pc[i]),
			 .R(internal_reset),
			 .S(active_interrupt),
			 .CE(pc_enable),
			 .C(clk));
			end else begin : RESET
			 FDRE pc_loop_register_bit ( 
			 .D(inc_pc_value[i]),
			 .Q(pc[i]),
			 .R(internal_reset || active_interrupt),
			 .CE(pc_enable),
			 .C(clk));
			end
		end
	endgenerate
 //end pc_loop;
 			
 assign address = pc;
//
////////////////////////////////////////////////////////////////////////////////////
//
// Register Bank and second operand selection.
//
// Definition of an 8-bit dual port RAM with 16 locations 
// including write enable decode.
//
// Outputs are assigned to PORT_ID and OUT_PORT.
//
////////////////////////////////////////////////////////////////////////////////////
//	
 // Forming decode signal

 LUT4 #(.INIT(16'h0145)) register_type_lut ( 
 .I0(active_interrupt),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(register_type ));
 
 FD register_write_flop ( 
 .D(register_type),
 .Q(register_write),
 .C(clk));

 LUT2 #(.INIT(4'h8)) register_enable_lut ( 
 .I0(t_state),
 .I1(register_write),
 .O(register_enable));
 
 //reg_loop

 generate
	genvar reg_loop_i;
	for (reg_loop_i=0;reg_loop_i<8;reg_loop_i=reg_loop_i+1) begin : REG_LOOP
		RAM16X1D #(.INIT(16'h0000)) reg_loop_register_bit_0 ( 
		 .D(alu_result[reg_loop_i]),
		 .WE(register_enable),
		 .WCLK(clk),
		 .A0(instruction[8]),
		 .A1(instruction[9]),
		 .A2(instruction[10]),
		 .A3(instruction[11]),
		 .DPRA0(instruction[4]),
		 .DPRA1(instruction[5]),
		 .DPRA2(instruction[6]),
		 .DPRA3(instruction[7]),
		 .SPO(sx[reg_loop_i]),
		 .DPO(sy[reg_loop_i]));
	end
 endgenerate
 
 generate
	genvar operand_select_mux_i;
	for (operand_select_mux_i=0;operand_select_mux_i<8;operand_select_mux_i=operand_select_mux_i+1) begin : OPERAND_SELECT_MUX_LOOP
		LUT3 #(.INIT(8'hE4)) operand_select_mux_0 ( 
		 .I0(instruction[12]),
		 .I1(instruction[operand_select_mux_i]),
		 .I2(sy[operand_select_mux_i]),
		 .O(second_operand[operand_select_mux_i]));
	end
 endgenerate
     
 assign out_port = sx;
 assign port_id = second_operand;
//
////////////////////////////////////////////////////////////////////////////////////
//
// Store Memory
//
// Definition of an 8-bit single port RAM with 64 locations 
// including write enable decode.
//
////////////////////////////////////////////////////////////////////////////////////
//	
 // Forming decode signal

 LUT4 #(.INIT(16'h0400)) memory_type_lut ( 
 .I0(active_interrupt),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(memory_type ));
 
 FD memory_write_flop ( 
 .D(memory_type),
 .Q(memory_write),
 .C(clk));

 LUT4 #(.INIT(16'h8000)) memory_enable_lut ( 
 .I0(t_state),
 .I1(instruction[13]),
 .I2(instruction[14]),
 .I3(memory_write),
 .O(memory_enable ));
 
 // store_loop

// super hack to map to port space
 // 
 // If you don't connect spram_port_en, this all gets optimized away, and everything
 // goes back to normal. 
 // If you want to map to 0xC0-0xFF, for instance, do
 // assign spram_port_en = (port_id[7:6] == 2'b11) && (read_strobe || write_strobe);
 // and mux spram_data onto in_port when (port_id[7:6] == 2'b11)
 wire memory_enable_or_port = (memory_enable || (spram_port_en && write_strobe));
 wire [7:0] d_in = (write_strobe && spram_port_en) ? out_port : sx;
 wire [5:0] memory_addr = (spram_port_en) ? port_id[5:0] : second_operand;
 assign spram_data = memory_data;
 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_0)) memory_bit_0 ( 
 .D(d_in[0]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[0]));

 FD store_flop_0 ( 
 .D(memory_data[0]),
 .Q(store_data[0]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_1)) memory_bit_1 ( 
 .D(d_in[1]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[1]));

 FD store_flop_1 ( 
 .D(memory_data[1]),
 .Q(store_data[1]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_2)) memory_bit_2 ( 
 .D(d_in[2]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[2]));

 FD store_flop_2 ( 
 .D(memory_data[2]),
 .Q(store_data[2]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_3)) memory_bit_3 ( 
 .D(d_in[3]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[3]));

 FD store_flop_3 ( 
 .D(memory_data[3]),
 .Q(store_data[3]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_4)) memory_bit_4 ( 
 .D(d_in[4]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[4]));

 FD store_flop_4 ( 
 .D(memory_data[4]),
 .Q(store_data[4]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_5)) memory_bit_5 ( 
 .D(d_in[5]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[5]));
 
 FD store_flop_5 ( 
 .D(memory_data[5]),
 .Q(store_data[5]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_6)) memory_bit_6 ( 
 .D(d_in[6]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[6]));

 FD store_flop_6 ( 
 .D(memory_data[6]),
 .Q(store_data[6]),
 .C(clk));

 // synthesis translate_off 
 // synthesis translate_on 
 RAM64X1S #(.INIT(RAM_INIT_7)) memory_bit_7 ( 
 .D(d_in[7]),
 .WE(memory_enable_or_port),
 .WCLK(clk),
 .A0(memory_addr[0]),
 .A1(memory_addr[1]),
 .A2(memory_addr[2]),
 .A3(memory_addr[3]),
 .A4(memory_addr[4]),
 .A5(memory_addr[5]),
 .O(memory_data[7]));
 
 FD store_flop_7 ( 
 .D(memory_data[7]),
 .Q(store_data[7]),
 .C(clk));
      
//
////////////////////////////////////////////////////////////////////////////////////
//
// Logical operations
//
// Definition of AND, OR, XOR and LOAD functions which also provides TEST.
// Includes pipeline stage used to form ALU multiplexer including decode.
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT4 #(.INIT(16'hFFE2)) sel_logical_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(sel_logical ));
 
 // logical_loop
 generate
	genvar logical_i;
	for (logical_i=0;logical_i<8;logical_i=logical_i+1) begin : LOGICAL_LOOP
		LUT4 #(.INIT(16'h6E8A)) logical_lut ( 
		 .I0(second_operand[logical_i]),
		 .I1(sx[logical_i]),
		 .I2(instruction[13]),
		 .I3(instruction[14]),
		 .O(logical_value[logical_i]));
	end
 endgenerate
 
 FDR logical_flop_0 ( 
 .D(logical_value[0]),
 .Q(logical_result[0]),
 .R(sel_logical),
 .C(clk));
 
 FDR logical_flop_1 ( 
 .D(logical_value[1]),
 .Q(logical_result[1]),
 .R(sel_logical),
 .C(clk));
 
 FDR logical_flop_2 ( 
 .D(logical_value[2]),
 .Q(logical_result[2]),
 .R(sel_logical),
 .C(clk));
 
 FDR logical_flop_3 ( 
 .D(logical_value[3]),
 .Q(logical_result[3]),
 .R(sel_logical),
 .C(clk));

 FDR logical_flop_4 ( 
 .D(logical_value[4]),
 .Q(logical_result[4]),
 .R(sel_logical),
 .C(clk));

 FDR logical_flop_5 ( 
 .D(logical_value[5]),
 .Q(logical_result[5]),
 .R(sel_logical),
 .C(clk));

 FDR logical_flop_6 ( 
 .D(logical_value[6]),
 .Q(logical_result[6]),
 .R(sel_logical),
 .C(clk));

 FDR logical_flop_7 ( 
 .D(logical_value[7]),
 .Q(logical_result[7]),
 .R(sel_logical),
 .C(clk));
     
//
////////////////////////////////////////////////////////////////////////////////////
//
// Shift and Rotate operations
//
// Includes pipeline stage used to form ALU multiplexer including decode.
//
////////////////////////////////////////////////////////////////////////////////////
//
 INV sel_shift_inv( // Inverter should be implemented in the reset to flip flops
 .I(instruction[17]),
 .O(sel_shift)); 

 // Bit to input to shift register

 LUT3 #(.INIT(8'hE4)) high_shift_in_lut ( 
 .I0(instruction[1]),
 .I1(sx[0]),
 .I2(instruction[0]),
 .O(high_shift_in ));
 
 LUT3 #(.INIT(8'hE4)) low_shift_in_lut ( 
 .I0(instruction[1]),
 .I1(carry_flag),
 .I2(sx[7]),
 .O(low_shift_in));
 
 MUXF5 shift_in_muxf5 ( 
 .I1(high_shift_in),
 .I0(low_shift_in),
 .S(instruction[2]),
 .O(shift_in )); 

 // Forming shift carry signal

 LUT3 #(.INIT(8'hE4)) shift_carry_lut ( 
 .I0(instruction[3]),
 .I1(sx[7]),
 .I2(sx[0]),
 .O(shift_carry_value ));
 					 
 FD pipeline_bit ( 
 .D(shift_carry_value),
 .Q(shift_carry),
 .C(clk));

// shift_loop

 // synthesis translate_off 
// defparam shift_mux_lut_0.INIT = 8'hE4;
 // synthesis translate_on 
 generate
	genvar shift_i;
	for (shift_i=0;shift_i<8;shift_i=shift_i+1) begin : SHIFT_LOOP
		if (shift_i == 0) begin : SHIFT_BEGIN
			 LUT3 #(.INIT(8'hE4)) shift_mux_lut ( 
			 .I0(instruction[3]),
			 .I1(shift_in),
			 .I2(sx[shift_i+1]),
			 .O(shift_value[shift_i]));
		end else if (shift_i == 7) begin : SHIFT_END
			 LUT3 #(.INIT(8'hE4)) shift_mux_lut ( 
			 .I0(instruction[3]),
			 .I1(sx[shift_i-1]),
			 .I2(shift_in),
			 .O(shift_value[shift_i]) );
		end else begin : SHIFT_NORMAL
			 LUT3 #(.INIT(8'hE4)) shift_mux_lut_1 ( 
			 .I0(instruction[3]),
			 .I1(sx[shift_i-1]),
			 .I2(sx[shift_i+1]),
			 .O(shift_value[shift_i]));
		end 
	end
 endgenerate
 
 FDR shift_flop_0 ( 
 .D(shift_value[0]),
 .Q(shift_result[0]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_1 ( 
 .D(shift_value[1]),
 .Q(shift_result[1]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_2 ( 
 .D(shift_value[2]),
 .Q(shift_result[2]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_3 ( 
 .D(shift_value[3]),
 .Q(shift_result[3]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_4 ( 
 .D(shift_value[4]),
 .Q(shift_result[4]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_5 ( 
 .D(shift_value[5]),
 .Q(shift_result[5]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_6 ( 
 .D(shift_value[6]),
 .Q(shift_result[6]),
 .R(sel_shift),
 .C(clk));
 FDR shift_flop_7 ( 
 .D(shift_value[7]),
 .Q(shift_result[7]),
 .R(sel_shift),
 .C(clk));

//
////////////////////////////////////////////////////////////////////////////////////
//
// Arithmetic operations
//
// Definition of ADD, ADDCY, SUB and SUBCY functions which also provides COMPARE.
// Includes pipeline stage used to form ALU multiplexer including decode.
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT3 #(.INIT(8'h1F)) sel_arith_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .O(sel_arith));
 
 //arith_loop 

 LUT3 #(.INIT(8'h6C)) arith_carry_in_lut ( 
 .I0(instruction[13]),
 .I1(instruction[14]),
 .I2(carry_flag),
 .O(sel_arith_carry_in ));
 
 MUXCY arith_carry_in_muxcy ( 
 .DI(1'b0),
 .CI(1'b1),
 .S(sel_arith_carry_in),
 .O(arith_carry_in));

 MUXCY arith_muxcy_0 ( 
 .DI(sx[0]),
 .CI(arith_carry_in),
 .S(half_arith[0]),
 .O(arith_internal_carry[0]));
 
 XORCY arith_xor_0 ( 
 .LI(half_arith[0]),
 .CI(arith_carry_in),
 .O(arith_value[0]));

 generate
	genvar arith_loop_i;
	for (arith_loop_i=0;arith_loop_i<8;arith_loop_i=arith_loop_i+1) begin : ARITH_LOOP
	 LUT3 #(.INIT(8'h96)) arith_lut ( 
	 .I0(sx[arith_loop_i]),
	 .I1(second_operand[arith_loop_i]),
	 .I2(instruction[14]),
	 .O(half_arith[arith_loop_i]));
	end
 endgenerate
 
 FDR arith_flop_0 ( 
 .D(arith_value[0]),
 .Q(arith_result[0]),
 .R(sel_arith),
 .C(clk)); 
 MUXCY arith_muxcy_1 ( 
 .DI(sx[1]),
 .CI(arith_internal_carry[0]),
 .S(half_arith[1]),
 .O(arith_internal_carry[1]));

 XORCY arith_xor_1 ( 
 .LI(half_arith[1]),
 .CI(arith_internal_carry[0]),
 .O(arith_value[1]));
 
 FDR arith_flop_1 ( 
 .D(arith_value[1]),
 .Q(arith_result[1]),
 .R(sel_arith),
 .C(clk));
 
 MUXCY arith_muxcy_2 ( 
 .DI(sx[2]),
 .CI(arith_internal_carry[1]),
 .S(half_arith[2]),
 .O(arith_internal_carry[2]));

 XORCY arith_xor_2 ( 
 .LI(half_arith[2]),
 .CI(arith_internal_carry[1]),
 .O(arith_value[2]));

 FDR arith_flop_2 ( 
 .D(arith_value[2]),
 .Q(arith_result[2]),
 .R(sel_arith),
 .C(clk));
  
 MUXCY arith_muxcy_3 ( 
 .DI(sx[3]),
 .CI(arith_internal_carry[2]),
 .S(half_arith[3]),
 .O(arith_internal_carry[3]));

 XORCY arith_xor_3 ( 
 .LI(half_arith[3]),
 .CI(arith_internal_carry[2]),
 .O(arith_value[3]));

 FDR arith_flop_3 ( 
 .D(arith_value[3]),
 .Q(arith_result[3]),
 .R(sel_arith),
 .C(clk));
 
 MUXCY arith_muxcy_4 ( 
 .DI(sx[4]),
 .CI(arith_internal_carry[3]),
 .S(half_arith[4]),
 .O(arith_internal_carry[4]));

 XORCY arith_xor_4 ( 
 .LI(half_arith[4]),
 .CI(arith_internal_carry[3]),
 .O(arith_value[4]));

 FDR arith_flop_4 ( 
 .D(arith_value[4]),
 .Q(arith_result[4]),
 .R(sel_arith),
 .C(clk));
  
 MUXCY arith_muxcy_5 ( 
 .DI(sx[5]),
 .CI(arith_internal_carry[4]),
 .S(half_arith[5]),
 .O(arith_internal_carry[5]));

 XORCY arith_xor_5 ( 
 .LI(half_arith[5]),
 .CI(arith_internal_carry[4]),
 .O(arith_value[5])); 	 
 
 FDR arith_flop_5 ( 
 .D(arith_value[5]),
 .Q(arith_result[5]),
 .R(sel_arith),
 .C(clk));
 
 MUXCY arith_muxcy_6 ( 
 .DI(sx[6]),
 .CI(arith_internal_carry[5]),
 .S(half_arith[6]),
 .O(arith_internal_carry[6]));

 XORCY arith_xor_6 ( 
 .LI(half_arith[6]),
 .CI(arith_internal_carry[5]),
 .O(arith_value[6]));
 
 FDR arith_flop_6 ( 
 .D(arith_value[6]),
 .Q(arith_result[6]),
 .R(sel_arith),
 .C(clk));
 
 MUXCY arith_muxcy_7 ( 
 .DI(sx[7]),
 .CI(arith_internal_carry[6]),
 .S(half_arith[7]),
 .O(arith_internal_carry[7]));

 XORCY arith_xor_7 ( 
 .LI(half_arith[7]),
 .CI(arith_internal_carry[6]),
 .O(arith_value[7]));

 LUT1 #(.INIT(2'h2)) arith_carry_out_lut ( 
 .I0(instruction[14]),
 .O(invert_arith_carry ));
 
 XORCY arith_carry_out_xor ( 
 .LI(invert_arith_carry),
 .CI(arith_internal_carry[7]),
 .O(arith_carry_out));
 
 FDR arith_flop_7 ( 
 .D(arith_value[7]),
 .Q(arith_result[7]),
 .R(sel_arith),
 .C(clk));
 
 FDR arith_carry_flop ( 
 .D(arith_carry_out),
 .Q(arith_carry),
 .R(sel_arith),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// ALU multiplexer
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT4 #(.INIT(16'h0002)) input_fetch_type_lut ( 
 .I0(instruction[14]),
 .I1(instruction[15]),
 .I2(instruction[16]),
 .I3(instruction[17]),
 .O(input_fetch_type ));
 
 FD sel_group_flop ( 
 .D(input_fetch_type),
 .Q(sel_group),
 .C(clk));
 
 //alu_mux_loop 

 LUT3 #(.INIT(8'hFE)) or_lut_0 ( 
 .I0(logical_result[0]),
 .I1(arith_result[0]),
 .I2(shift_result[0]),
 .O(alu_group[0]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_0 ( 
 .I0(instruction[13]),
 .I1(in_port[0]),
 .I2(store_data[0]),
 .O(input_group[0]));
 
 MUXF5 shift_in_muxf5_0 ( 
 .I1(input_group[0]),
 .I0(alu_group[0]),
 .S(sel_group),
 .O(alu_result[0]) ); 

 LUT3 #(.INIT(8'hFE)) or_lut_1 ( 
 .I0(logical_result[1]),
 .I1(arith_result[1]),
 .I2(shift_result[1]),
 .O(alu_group[1]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_1 ( 
 .I0(instruction[13]),
 .I1(in_port[1]),
 .I2(store_data[1]),
 .O(input_group[1]));
 
 MUXF5 shift_in_muxf5_1 ( 
 .I1(input_group[1]),
 .I0(alu_group[1]),
 .S(sel_group),
 .O(alu_result[1]) ); 

 LUT3 #(.INIT(8'hFE)) or_lut_2 ( 
 .I0(logical_result[2]),
 .I1(arith_result[2]),
 .I2(shift_result[2]),
 .O(alu_group[2]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_2 ( 
 .I0(instruction[13]),
 .I1(in_port[2]),
 .I2(store_data[2]),
 .O(input_group[2]));
 
 MUXF5 shift_in_muxf5_2 ( 
 .I1(input_group[2]),
 .I0(alu_group[2]),
 .S(sel_group),
 .O(alu_result[2]) ); 

 LUT3 #(.INIT(8'hFE)) or_lut_3 ( 
 .I0(logical_result[3]),
 .I1(arith_result[3]),
 .I2(shift_result[3]),
 .O(alu_group[3]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_3 ( 
 .I0(instruction[13]),
 .I1(in_port[3]),
 .I2(store_data[3]),
 .O(input_group[3]));
 
 MUXF5 shift_in_muxf5_3 ( 
 .I1(input_group[3]),
 .I0(alu_group[3]),
 .S(sel_group),
 .O(alu_result[3]) ); 
  
 LUT3 #(.INIT(8'hFE)) or_lut_4 ( 
 .I0(logical_result[4]),
 .I1(arith_result[4]),
 .I2(shift_result[4]),
 .O(alu_group[4]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_4 ( 
 .I0(instruction[13]),
 .I1(in_port[4]),
 .I2(store_data[4]),
 .O(input_group[4]));
 
 MUXF5 shift_in_muxf5_4 ( 
 .I1(input_group[4]),
 .I0(alu_group[4]),
 .S(sel_group),
 .O(alu_result[4]) ); 
 
 LUT3 #(.INIT(8'hFE)) or_lut_5 ( 
 .I0(logical_result[5]),
 .I1(arith_result[5]),
 .I2(shift_result[5]),
 .O(alu_group[5]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_5 ( 
 .I0(instruction[13]),
 .I1(in_port[5]),
 .I2(store_data[5]),
 .O(input_group[5]));
 
 MUXF5 shift_in_muxf5_5 ( 
 .I1(input_group[5]),
 .I0(alu_group[5]),
 .S(sel_group),
 .O(alu_result[5]) ); 

 LUT3 #(.INIT(8'hFE)) or_lut_6 ( 
 .I0(logical_result[6]),
 .I1(arith_result[6]),
 .I2(shift_result[6]),
 .O(alu_group[6]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_6 ( 
 .I0(instruction[13]),
 .I1(in_port[6]),
 .I2(store_data[6]),
 .O(input_group[6]));
 
 MUXF5 shift_in_muxf5_6 ( 
 .I1(input_group[6]),
 .I0(alu_group[6]),
 .S(sel_group),
 .O(alu_result[6]) ); 
  
 LUT3 #(.INIT(8'hFE)) or_lut_7 ( 
 .I0(logical_result[7]),
 .I1(arith_result[7]),
 .I2(shift_result[7]),
 .O(alu_group[7]));
 
 LUT3 #(.INIT(8'hE4)) mux_lut_7 ( 
 .I0(instruction[13]),
 .I1(in_port[7]),
 .I2(store_data[7]),
 .O(input_group[7]));
 
 MUXF5 shift_in_muxf5_7 ( 
 .I1(input_group[7]),
 .I0(alu_group[7]),
 .S(sel_group),
 .O(alu_result[7]) );   
 //
////////////////////////////////////////////////////////////////////////////////////
//
// Read and Write Strobes
//
////////////////////////////////////////////////////////////////////////////////////
//
 LUT4 #(.INIT(16'h0010)) io_decode_lut ( 
 .I0(active_interrupt),
 .I1(instruction[13]),
 .I2(instruction[14]),
 .I3(instruction[16]),
 .O(io_initial_decode ));
 
 LUT4 #(.INIT(16'h4000)) write_active_lut ( 
 .I0(t_state),
 .I1(instruction[15]),
 .I2(instruction[17]),
 .I3(io_initial_decode),
 .O(write_active ));
 
 FDR write_strobe_flop ( 
 .D(write_active),
 .Q(write_strobe),
 .R(internal_reset),
 .C(clk));

 LUT4 #(.INIT(16'h0100)) read_active_lut ( 
 .I0(t_state),
 .I1(instruction[15]),
 .I2(instruction[17]),
 .I3(io_initial_decode),
 .O(read_active ));
 
 FDR read_strobe_flop ( 
 .D(read_active),
 .Q(read_strobe),
 .R(internal_reset),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// Program CALL/RETURN stack
//
// Provided the counter and memory for a 32 deep stack supporting nested 
// subroutine calls to a depth of 31 levels.
//
////////////////////////////////////////////////////////////////////////////////////
//
 // Stack memory is 32 locations of 10-bit single port.
 
 INV stack_ram_inv ( // Inverter should be implemented in the WE to RAM
 .I(t_state),
 .O(stack_write_enable)); 
 
 //stack_ram_loop 
 
 RAM32X1S #(.INIT(32'h00000000)) stack_bit_0 ( 
 .D(pc[0]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[0]));
 
 FD stack_flop_0 ( 
 .D(stack_ram_data[0]),
 .Q(stack_pop_data[0]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_1 ( 
 .D(pc[1]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[1]));
 
 FD stack_flop_1 ( 
 .D(stack_ram_data[1]),
 .Q(stack_pop_data[1]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_2 ( 
 .D(pc[2]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[2]));
 
 FD stack_flop_2 ( 
 .D(stack_ram_data[2]),
 .Q(stack_pop_data[2]),
 .C(clk));
 
 RAM32X1S #(.INIT(32'h00000000)) stack_bit_3 ( 
 .D(pc[3]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[3]));
 
 FD stack_flop_3 ( 
 .D(stack_ram_data[3]),
 .Q(stack_pop_data[3]),
 .C(clk));
 
 RAM32X1S #(.INIT(32'h00000000)) stack_bit_4 ( 
 .D(pc[4]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[4]));
 
 FD stack_flop_4 ( 
 .D(stack_ram_data[4]),
 .Q(stack_pop_data[4]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_5 ( 
 .D(pc[5]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[5]));
 
 FD stack_flop_5 ( 
 .D(stack_ram_data[5]),
 .Q(stack_pop_data[5]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_6 ( 
 .D(pc[6]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[6]));
 
 FD stack_flop_6 ( 
 .D(stack_ram_data[6]),
 .Q(stack_pop_data[6]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_7 ( 
 .D(pc[7]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[7]));
 
 FD stack_flop_7 ( 
 .D(stack_ram_data[7]),
 .Q(stack_pop_data[7]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_8 ( 
 .D(pc[8]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[8]));
 
 FD stack_flop_8 ( 
 .D(stack_ram_data[8]),
 .Q(stack_pop_data[8]),
 .C(clk));

 RAM32X1S #(.INIT(32'h00000000)) stack_bit_9 ( 
 .D(pc[9]),
 .WE(stack_write_enable),
 .WCLK(clk),
 .A0(stack_address[0]),
 .A1(stack_address[1]),
 .A2(stack_address[2]),
 .A3(stack_address[3]),
 .A4(stack_address[4]),
 .O(stack_ram_data[9]));

 FD stack_flop_9 ( 
 .D(stack_ram_data[9]),
 .Q(stack_pop_data[9]),
 .C(clk));
       
 // Stack address pointer is a 5-bit counter

 INV stack_count_inv( // Inverter should be implemented in the CE to the flip-flops
 .I(active_interrupt),
 .O(not_active_interrupt)); 

 //stack_count_loop 

 LUT4 #(.INIT(16'h6555)) count_lut_0 ( 
 .I0(stack_address[0]),
 .I1(t_state),
 .I2(valid_to_move),
 .I3(push_or_pop_type),
 .O(half_stack_address[0]) );
 
 MUXCY count_muxcy_0 ( 
 .DI(stack_address[0]),
 .CI(1'b0),
 .S(half_stack_address[0]),
 .O(stack_address_carry[0]));
 
 XORCY count_xor_0 ( 
 .LI(half_stack_address[0]),
 .CI(1'b0),
 .O(next_stack_address[0]));

 FDRE stack_count_loop_register_bit_0 ( 
 .D(next_stack_address[0]),
 .Q(stack_address[0]),
 .R(internal_reset),
 .CE(not_active_interrupt),
 .C(clk)); 				 					 

 LUT4 #(.INIT(16'hA999)) count_lut_1 ( 
 .I0(stack_address[1]),
 .I1(t_state),
 .I2(valid_to_move),
 .I3(call_type),
 .O(half_stack_address[1]) );
 
 MUXCY count_muxcy_1 ( 
 .DI(stack_address[1]),
 .CI(stack_address_carry[0]),
 .S(half_stack_address[1]),
 .O(stack_address_carry[1]));
 
 XORCY count_xor_1 ( 
 .LI(half_stack_address[1]),
 .CI(stack_address_carry[0]),
 .O(next_stack_address[1]));
 				 					 
 FDRE stack_count_loop_register_bit_1 ( 
 .D(next_stack_address[1]),
 .Q(stack_address[1]),
 .R(internal_reset),
 .CE(not_active_interrupt),
 .C(clk)); 	

 LUT4 #(.INIT(16'hA999)) count_lut_2 ( 
 .I0(stack_address[2]),
 .I1(t_state),
 .I2(valid_to_move),
 .I3(call_type),
 .O(half_stack_address[2]) );
 
 MUXCY count_muxcy_2 ( 
 .DI(stack_address[2]),
 .CI(stack_address_carry[1]),
 .S(half_stack_address[2]),
 .O(stack_address_carry[2]));
 
 XORCY count_xor_2 ( 
 .LI(half_stack_address[2]),
 .CI(stack_address_carry[1]),
 .O(next_stack_address[2]));
 				 					 
 FDRE stack_count_loop_register_bit_2 ( 
 .D(next_stack_address[2]),
 .Q(stack_address[2]),
 .R(internal_reset),
 .CE(not_active_interrupt),
 .C(clk)); 

 LUT4 #(.INIT(16'hA999)) count_lut_3 ( 
 .I0(stack_address[3]),
 .I1(t_state),
 .I2(valid_to_move),
 .I3(call_type),
 .O(half_stack_address[3]) );
 
 MUXCY count_muxcy_3 ( 
 .DI(stack_address[3]),
 .CI(stack_address_carry[2]),
 .S(half_stack_address[3]),
 .O(stack_address_carry[3]));
 
 XORCY count_xor_3 ( 
 .LI(half_stack_address[3]),
 .CI(stack_address_carry[2]),
 .O(next_stack_address[3]));
 				 					 
 FDRE stack_count_loop_register_bit_3 ( 
 .D(next_stack_address[3]),
 .Q(stack_address[3]),
 .R(internal_reset),
 .CE(not_active_interrupt),
 .C(clk)); 

 LUT4 #(.INIT(16'hA999)) count_lut_4 ( 
 .I0(stack_address[4]),
 .I1(t_state),
 .I2(valid_to_move),
 .I3(call_type),
 .O(half_stack_address[4]) );
 
 XORCY count_xor_4 ( 
 .LI(half_stack_address[4]),
 .CI(stack_address_carry[3]),
 .O(next_stack_address[4]));

 FDRE stack_count_loop_register_bit_4 ( 
 .D(next_stack_address[4]),
 .Q(stack_address[4]),
 .R(internal_reset),
 .CE(not_active_interrupt),
 .C(clk));
//
////////////////////////////////////////////////////////////////////////////////////
//
// End of description for KCPSM3 macro.
//
////////////////////////////////////////////////////////////////////////////////////
//
//**********************************************************************************
// Code for simulation purposes only after this line
//**********************************************************************************
//
////////////////////////////////////////////////////////////////////////////////////
//
// Code for simulation.
//
// Disassemble the instruction codes to form a text string for display.
// Determine status of reset and flags and present in the form of a text string.
// Provide local variables to simulate the contents of each register and scratch 
// pad memory location.
//
////////////////////////////////////////////////////////////////////////////////////
//
 //All of this section is ignored during synthesis.
 //synthesis translate_off
 //
 //complete instruction decode
 //
 reg 	[1:152] kcpsm3_opcode ;
 //
 //Status of flags and processor
 //
 reg 	[1:104] kcpsm3_status ;
 //
 //contents of each register
 //
 reg 	[7:0]	s0_contents ;
 reg 	[7:0]	s1_contents ;
 reg  	[7:0]	s2_contents ;
 reg  	[7:0]	s3_contents ;
 reg  	[7:0]	s4_contents ;
 reg  	[7:0]	s5_contents ;
 reg  	[7:0]	s6_contents ;
 reg  	[7:0]	s7_contents ;
 reg  	[7:0]	s8_contents ;
 reg  	[7:0]	s9_contents ;
 reg  	[7:0]	sa_contents ;
 reg  	[7:0]	sb_contents ;
 reg  	[7:0]	sc_contents ;
 reg  	[7:0]	sd_contents ;
 reg  	[7:0]	se_contents ;
 reg  	[7:0]	sf_contents ;
 //
 //contents of each scratch pad memory location
 // 
 reg 	[7:0] 	spm00_contents = RAM_00;
 reg 	[7:0] 	spm01_contents = RAM_01;
 reg 	[7:0] 	spm02_contents = RAM_02;
 reg 	[7:0] 	spm03_contents = RAM_03;
 reg 	[7:0] 	spm04_contents = RAM_04;
 reg 	[7:0] 	spm05_contents = RAM_05;
 reg 	[7:0] 	spm06_contents = RAM_06;
 reg 	[7:0] 	spm07_contents = RAM_07;
 reg 	[7:0] 	spm08_contents = RAM_08;
 reg 	[7:0] 	spm09_contents = RAM_09;
 reg 	[7:0] 	spm0a_contents = RAM_0A;
 reg 	[7:0] 	spm0b_contents = RAM_0B;
 reg 	[7:0] 	spm0c_contents = RAM_0C;
 reg 	[7:0] 	spm0d_contents = RAM_0D;
 reg 	[7:0] 	spm0e_contents = RAM_0E;
 reg 	[7:0] 	spm0f_contents = RAM_0F;
 reg 	[7:0] 	spm10_contents = RAM_10;
 reg 	[7:0] 	spm11_contents = RAM_11;
 reg 	[7:0] 	spm12_contents = RAM_12;
 reg 	[7:0] 	spm13_contents = RAM_13;
 reg 	[7:0] 	spm14_contents = RAM_14;
 reg 	[7:0] 	spm15_contents = RAM_15;
 reg 	[7:0] 	spm16_contents = RAM_16;
 reg 	[7:0] 	spm17_contents = RAM_17;
 reg 	[7:0] 	spm18_contents = RAM_18;
 reg 	[7:0] 	spm19_contents = RAM_19;
 reg 	[7:0] 	spm1a_contents = RAM_1A;
 reg 	[7:0] 	spm1b_contents = RAM_1B;
 reg 	[7:0] 	spm1c_contents = RAM_1C;
 reg 	[7:0] 	spm1d_contents = RAM_1D;
 reg 	[7:0] 	spm1e_contents = RAM_1E;
 reg 	[7:0] 	spm1f_contents = RAM_1F;
 reg 	[7:0] 	spm20_contents = RAM_20;
 reg 	[7:0] 	spm21_contents = RAM_21;
 reg 	[7:0] 	spm22_contents = RAM_22;
 reg 	[7:0] 	spm23_contents = RAM_23;
 reg 	[7:0] 	spm24_contents = RAM_24;
 reg 	[7:0] 	spm25_contents = RAM_25;
 reg 	[7:0] 	spm26_contents = RAM_26;
 reg 	[7:0] 	spm27_contents = RAM_27;
 reg 	[7:0] 	spm28_contents = RAM_28;
 reg 	[7:0] 	spm29_contents = RAM_29;
 reg 	[7:0] 	spm2a_contents = RAM_2A;
 reg 	[7:0] 	spm2b_contents = RAM_2B;
 reg 	[7:0] 	spm2c_contents = RAM_2C;
 reg 	[7:0] 	spm2d_contents = RAM_2D;
 reg 	[7:0] 	spm2e_contents = RAM_2E;
 reg 	[7:0] 	spm2f_contents = RAM_2F;
 reg 	[7:0] 	spm30_contents = RAM_30;
 reg 	[7:0] 	spm31_contents = RAM_31;
 reg 	[7:0] 	spm32_contents = RAM_32;
 reg 	[7:0] 	spm33_contents = RAM_33;
 reg 	[7:0] 	spm34_contents = RAM_34;
 reg 	[7:0] 	spm35_contents = RAM_35;
 reg 	[7:0] 	spm36_contents = RAM_36;
 reg 	[7:0] 	spm37_contents = RAM_37;
 reg 	[7:0] 	spm38_contents = RAM_38;
 reg 	[7:0] 	spm39_contents = RAM_39;
 reg 	[7:0] 	spm3a_contents = RAM_3A;
 reg 	[7:0] 	spm3b_contents = RAM_3B;
 reg 	[7:0] 	spm3c_contents = RAM_3C;
 reg 	[7:0] 	spm3d_contents = RAM_3D;
 reg 	[7:0] 	spm3e_contents = RAM_3E;
 reg 	[7:0] 	spm3f_contents = RAM_3F;
  
 // initialise the values 
 initial begin
 kcpsm3_status = "NZ, NC, Reset";

 s0_contents = 8'h00 ;
 s1_contents = 8'h00 ;
 s2_contents = 8'h00 ;
 s3_contents = 8'h00 ;
 s4_contents = 8'h00 ;
 s5_contents = 8'h00 ;
 s6_contents = 8'h00 ;
 s7_contents = 8'h00 ;
 s8_contents = 8'h00 ;
 s9_contents = 8'h00 ;
 sa_contents = 8'h00 ;
 sb_contents = 8'h00 ;
 sc_contents = 8'h00 ;
 sd_contents = 8'h00 ;
 se_contents = 8'h00 ;
 sf_contents = 8'h00 ;

// spm00_contents = 8'h00 ;
// spm01_contents = 8'h00 ;
// spm02_contents = 8'h00 ;
// spm03_contents = 8'h00 ;
// spm04_contents = 8'h00 ;
// spm05_contents = 8'h00 ;
// spm06_contents = 8'h00 ;
// spm07_contents = 8'h00 ;
// spm08_contents = 8'h00 ;
// spm09_contents = 8'h00 ;
// spm0a_contents = 8'h00 ;
// spm0b_contents = 8'h00 ;
// spm0c_contents = 8'h00 ;
// spm0d_contents = 8'h00 ;
// spm0e_contents = 8'h00 ;
// spm0f_contents = 8'h00 ;
// spm10_contents = 8'h00 ;
// spm11_contents = 8'h00 ;
// spm12_contents = 8'h00 ;
// spm13_contents = 8'h00 ;
// spm14_contents = 8'h00 ;
// spm15_contents = 8'h00 ;
// spm16_contents = 8'h00 ;
// spm17_contents = 8'h00 ;
// spm18_contents = 8'h00 ;
// spm19_contents = 8'h00 ;
// spm1a_contents = 8'h00 ;
// spm1b_contents = 8'h00 ;
// spm1c_contents = 8'h00 ;
// spm1d_contents = 8'h00 ;
// spm1e_contents = 8'h00 ;
// spm1f_contents = 8'h00 ;
// spm20_contents = 8'h00 ;
// spm21_contents = 8'h00 ;
// spm22_contents = 8'h00 ;
// spm23_contents = 8'h00 ;
// spm24_contents = 8'h00 ;
// spm25_contents = 8'h00 ;
// spm26_contents = 8'h00 ;
// spm27_contents = 8'h00 ;
// spm28_contents = 8'h00 ;
// spm29_contents = 8'h00 ;
// spm2a_contents = 8'h00 ;
// spm2b_contents = 8'h00 ;
// spm2c_contents = 8'h00 ;
// spm2d_contents = 8'h00 ;
// spm2e_contents = 8'h00 ;
// spm2f_contents = 8'h00 ;
// spm30_contents = 8'h00 ;
// spm31_contents = 8'h00 ;
// spm32_contents = 8'h00 ;
// spm33_contents = 8'h00 ;
// spm34_contents = 8'h00 ;
// spm35_contents = 8'h00 ;
// spm36_contents = 8'h00 ;
// spm37_contents = 8'h00 ;
// spm38_contents = 8'h00 ;
// spm39_contents = 8'h00 ;
// spm3a_contents = 8'h00 ;
// spm3b_contents = 8'h00 ;
// spm3c_contents = 8'h00 ;
// spm3d_contents = 8'h00 ;
// spm3e_contents = 8'h00 ;
// spm3f_contents = 8'h00 ;
 end
 //
 //
 wire	[1:16] 	sx_decode ; //sX register specification
 wire 	[1:16]  sy_decode ; //sY register specification
 wire 	[1:16]	kk_decode ; //constant value specification
 wire 	[1:24]	aaa_decode ; //address specification
 //
 ////////////////////////////////////////////////////////////////////////////////
 //
 // Function to convert 4-bit binary nibble to hexadecimal character
 //
 ////////////////////////////////////////////////////////////////////////////////
 //
 function [1:8] hexcharacter ;
 input 	[3:0] nibble ;
 begin
 case (nibble)
 4'b0000 : hexcharacter = "0" ;
 4'b0001 : hexcharacter = "1" ;
 4'b0010 : hexcharacter = "2" ;
 4'b0011 : hexcharacter = "3" ;
 4'b0100 : hexcharacter = "4" ;
 4'b0101 : hexcharacter = "5" ;
 4'b0110 : hexcharacter = "6" ;
 4'b0111 : hexcharacter = "7" ;
 4'b1000 : hexcharacter = "8" ;
 4'b1001 : hexcharacter = "9" ;
 4'b1010 : hexcharacter = "A" ;
 4'b1011 : hexcharacter = "B" ;
 4'b1100 : hexcharacter = "C" ;
 4'b1101 : hexcharacter = "D" ;
 4'b1110 : hexcharacter = "E" ;
 4'b1111 : hexcharacter = "F" ;
 endcase
 end
 endfunction
  /*
 //
 ////////////////////////////////////////////////////////////////////////////////
 //
 begin
 */
 // decode first register
 assign sx_decode[1:8] = "s" ;
 assign sx_decode[9:16] = hexcharacter(instruction[11:8]) ; 

 // decode second register
 assign sy_decode[1:8] = "s";
 assign sy_decode[9:16] = hexcharacter(instruction[7:4]); 

 // decode constant value
 assign kk_decode[1:8] = hexcharacter(instruction[7:4]);
 assign kk_decode[9:16] = hexcharacter(instruction[3:0]);

 // address value
 assign aaa_decode[1:8] = hexcharacter({2'b00, instruction[9:8]});
 assign aaa_decode[9:16] = hexcharacter(instruction[7:4]);
 assign aaa_decode[17:24] = hexcharacter(instruction[3:0]);

 // decode instruction
 always @ (instruction or kk_decode or sy_decode or sx_decode or aaa_decode) 
 begin
 case (instruction[17:12]) 
 6'b000000 : begin kcpsm3_opcode <= {"LOAD ", sx_decode, ",", kk_decode, " "} ; end 
 6'b000001 : begin kcpsm3_opcode <= {"LOAD ", sx_decode, ",", sy_decode, " "} ; end
 6'b001010 : begin kcpsm3_opcode <= {"AND  ", sx_decode, ",", kk_decode, " "} ; end 
 6'b001011 : begin kcpsm3_opcode <= {"AND  ", sx_decode, ",", sy_decode, " "} ; end 
 6'b001100 : begin kcpsm3_opcode <= {"OR   ", sx_decode, ",", kk_decode, " "} ; end 
 6'b001101 : begin kcpsm3_opcode <= {"OR   ", sx_decode, ",", sy_decode, " "} ; end 
 6'b001110 : begin kcpsm3_opcode <= {"XOR  ", sx_decode, ",", kk_decode, " "} ; end 
 6'b001111 : begin kcpsm3_opcode <= {"XOR  ", sx_decode, ",", sy_decode, " "} ; end 
 6'b010010 : begin kcpsm3_opcode <= {"TEST ", sx_decode, ",", kk_decode, " "} ; end 
 6'b010011 : begin kcpsm3_opcode <= {"TEST ", sx_decode, ",", sy_decode, " "} ; end 
 6'b011000 : begin kcpsm3_opcode <= {"ADD  ", sx_decode, ",", kk_decode, " "} ; end 
 6'b011001 : begin kcpsm3_opcode <= {"ADD  ", sx_decode, ",", sy_decode, " "} ; end 
 6'b011010 : begin kcpsm3_opcode <= {"ADDCY", sx_decode, ",", kk_decode, " "} ; end 
 6'b011011 : begin kcpsm3_opcode <= {"ADDCY", sx_decode, ",", sy_decode, " "} ; end 
 6'b011100 : begin kcpsm3_opcode <= {"SUB  ", sx_decode, ",", kk_decode, " "} ; end 
 6'b011101 : begin kcpsm3_opcode <= {"SUB  ", sx_decode, ",", sy_decode, " "} ; end 
 6'b011110 : begin kcpsm3_opcode <= {"SUBCY", sx_decode, ",", kk_decode, " "} ; end 
 6'b011111 : begin kcpsm3_opcode <= {"SUBCY", sx_decode, ",", sy_decode, " "} ; end 
 6'b010100 : begin kcpsm3_opcode <= {"COMPARE ", sx_decode, ",", kk_decode, " "} ; end 
 6'b010101 : begin kcpsm3_opcode <= {"COMPARE ", sx_decode, ",", sy_decode, " "} ; end  
 6'b100000 : begin
   case (instruction[3:0])
     4'b0110 : begin kcpsm3_opcode <= {"SL0 ", sx_decode, " "}; end
     4'b0111 : begin kcpsm3_opcode <= {"SL1 ", sx_decode, " "}; end
     4'b0100 : begin kcpsm3_opcode <= {"SLX ", sx_decode, " "}; end
     4'b0000 : begin kcpsm3_opcode <= {"SLA ", sx_decode, " "}; end
     4'b0010 : begin kcpsm3_opcode <= {"RL ", sx_decode, " "}; end
     4'b1110 : begin kcpsm3_opcode <= {"SR0 ", sx_decode, " "}; end
     4'b1111 : begin kcpsm3_opcode <= {"SR1 ", sx_decode, " "}; end
     4'b1010 : begin kcpsm3_opcode <= {"SRX ", sx_decode, " "}; end
     4'b1000 : begin kcpsm3_opcode <= {"SRA ", sx_decode, " "}; end
     4'b1100 : begin kcpsm3_opcode <= {"RR ", sx_decode, " "}; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end
 6'b101100 : begin kcpsm3_opcode <= {"OUTPUT ", sx_decode, ",", kk_decode, " "}; end
 6'b101101 : begin kcpsm3_opcode <= {"OUTPUT ", sx_decode, ",(", sy_decode, ") "}; end
 6'b000100 : begin kcpsm3_opcode <= {"INPUT ", sx_decode, ",", kk_decode, " "}; end
 6'b000101 : begin kcpsm3_opcode <= {"INPUT ", sx_decode, ",(", sy_decode, ") "}; end
 6'b101110 : begin kcpsm3_opcode <= {"STORE ", sx_decode, ",", kk_decode, " "}; end
 6'b101111 : begin kcpsm3_opcode <= {"STORE ", sx_decode, ",(", sy_decode, ") "}; end
 6'b000110 : begin kcpsm3_opcode <= {"FETCH ", sx_decode, ",", kk_decode, " "}; end
 6'b000111 : begin kcpsm3_opcode <= {"FETCH ", sx_decode, ",(", sy_decode, ") "}; end
 6'b110100 : begin kcpsm3_opcode <= {"JUMP ", aaa_decode, " "}; end
 6'b110101 : begin
   case (instruction[11:10])
     2'b00   : begin kcpsm3_opcode <= {"JUMP Z,", aaa_decode, " "}; end
     2'b01   : begin kcpsm3_opcode <= {"JUMP NZ,", aaa_decode, " "}; end
     2'b10   : begin kcpsm3_opcode <= {"JUMP C,", aaa_decode, " "}; end
     2'b11   : begin kcpsm3_opcode <= {"JUMP NC,", aaa_decode, " "}; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end
 6'b110000 : begin kcpsm3_opcode <= {"CALL ", aaa_decode, " "}; end
 6'b110001 : begin
   case (instruction[11:10])
     2'b00   : begin kcpsm3_opcode <= {"CALL Z,", aaa_decode, " "}; end
     2'b01   : begin kcpsm3_opcode <= {"CALL NZ,", aaa_decode, " "}; end
     2'b10   : begin kcpsm3_opcode <= {"CALL C,", aaa_decode, " "}; end
     2'b11   : begin kcpsm3_opcode <= {"CALL NC,", aaa_decode, " "}; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end
 6'b101010 : begin kcpsm3_opcode <= "RETURN "; end
 6'b101011 : begin
 case (instruction[11:10])
     2'b00   : begin kcpsm3_opcode <= "RETURN Z "; end
     2'b01   : begin kcpsm3_opcode <= "RETURN NZ "; end
     2'b10   : begin kcpsm3_opcode <= "RETURN C "; end
     2'b11   : begin kcpsm3_opcode <= "RETURN NC "; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end  
 6'b111000 : begin
   case (instruction[0])
     1'b0    : begin kcpsm3_opcode <= "RETURNI DISABLE "; end
     1'b1    : begin kcpsm3_opcode <= "RETURNI ENABLE "; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end
 6'b111100 : begin
   case (instruction[0])
     1'b0    : begin kcpsm3_opcode <= "DISABLE INTERRUPT "; end
     1'b1    : begin kcpsm3_opcode <= "ENABLE INTERRUPT "; end
     default : begin kcpsm3_opcode <= "Invalid Instruction"; end
   endcase
 end
 default : begin kcpsm3_opcode <= "Invalid Instruction"; end
 endcase
 end
 
 //reset and flag status information
 always @ (posedge clk) begin
   if (reset==1'b1 || reset_delay==1'b1) begin
     kcpsm3_status = "NZ, NC, Reset";
   end 
   else begin
     kcpsm3_status[65:104] <= "       ";
     if (flag_enable == 1'b1) begin
       if (zero_carry == 1'b1) begin
         kcpsm3_status[1:32] <= " Z, ";
       end
       else begin
         kcpsm3_status[1:32] <= "NZ, ";
       end
       if (sel_carry[3] == 1'b1) begin
         kcpsm3_status[33:48] <= " C";
       end
       else begin
         kcpsm3_status[33:48] <= "NC";
       end
     end
   end
 end
 //simulation of register contents
 always @ (posedge clk) begin
   if (register_enable == 1'b1) begin
     case (instruction[11:8])
       4'b0000 : begin s0_contents <= alu_result; end
       4'b0001 : begin s1_contents <= alu_result; end
       4'b0010 : begin s2_contents <= alu_result; end
       4'b0011 : begin s3_contents <= alu_result; end
       4'b0100 : begin s4_contents <= alu_result; end
       4'b0101 : begin s5_contents <= alu_result; end
       4'b0110 : begin s6_contents <= alu_result; end
       4'b0111 : begin s7_contents <= alu_result; end
       4'b1000 : begin s8_contents <= alu_result; end
       4'b1001 : begin s9_contents <= alu_result; end
       4'b1010 : begin sa_contents <= alu_result; end
       4'b1011 : begin sb_contents <= alu_result; end
       4'b1100 : begin sc_contents <= alu_result; end
       4'b1101 : begin sd_contents <= alu_result; end
       4'b1110 : begin se_contents <= alu_result; end
       default : begin sf_contents <= alu_result; end
     endcase
   end
 end
 //simulation of scratch pad memory contents
 always @ (posedge clk) begin
   if (memory_enable==1'b1) begin
     case (second_operand[5:0])
       6'b000000 : begin spm00_contents <= sx ; end
       6'b000001 : begin spm01_contents <= sx ; end
       6'b000010 : begin spm02_contents <= sx ; end
       6'b000011 : begin spm03_contents <= sx ; end
       6'b000100 : begin spm04_contents <= sx ; end
       6'b000101 : begin spm05_contents <= sx ; end
       6'b000110 : begin spm06_contents <= sx ; end
       6'b000111 : begin spm07_contents <= sx ; end
       6'b001000 : begin spm08_contents <= sx ; end
       6'b001001 : begin spm09_contents <= sx ; end
       6'b001010 : begin spm0a_contents <= sx ; end
       6'b001011 : begin spm0b_contents <= sx ; end
       6'b001100 : begin spm0c_contents <= sx ; end
       6'b001101 : begin spm0d_contents <= sx ; end
       6'b001110 : begin spm0e_contents <= sx ; end
       6'b001111 : begin spm0f_contents <= sx ; end
       6'b010000 : begin spm10_contents <= sx ; end
       6'b010001 : begin spm11_contents <= sx ; end
       6'b010010 : begin spm12_contents <= sx ; end
       6'b010011 : begin spm13_contents <= sx ; end
       6'b010100 : begin spm14_contents <= sx ; end
       6'b010101 : begin spm15_contents <= sx ; end
       6'b010110 : begin spm16_contents <= sx ; end
       6'b010111 : begin spm17_contents <= sx ; end
       6'b011000 : begin spm18_contents <= sx ; end
       6'b011001 : begin spm19_contents <= sx ; end
       6'b011010 : begin spm1a_contents <= sx ; end
       6'b011011 : begin spm1b_contents <= sx ; end
       6'b011100 : begin spm1c_contents <= sx ; end
       6'b011101 : begin spm1d_contents <= sx ; end
       6'b011110 : begin spm1e_contents <= sx ; end
       6'b011111 : begin spm1f_contents <= sx ; end
       6'b100000 : begin spm20_contents <= sx ; end
       6'b100001 : begin spm21_contents <= sx ; end
       6'b100010 : begin spm22_contents <= sx ; end
       6'b100011 : begin spm23_contents <= sx ; end
       6'b100100 : begin spm24_contents <= sx ; end
       6'b100101 : begin spm25_contents <= sx ; end
       6'b100110 : begin spm26_contents <= sx ; end
       6'b100111 : begin spm27_contents <= sx ; end
       6'b101000 : begin spm28_contents <= sx ; end
       6'b101001 : begin spm29_contents <= sx ; end
       6'b101010 : begin spm2a_contents <= sx ; end
       6'b101011 : begin spm2b_contents <= sx ; end
       6'b101100 : begin spm2c_contents <= sx ; end
       6'b101101 : begin spm2d_contents <= sx ; end
       6'b101110 : begin spm2e_contents <= sx ; end
       6'b101111 : begin spm2f_contents <= sx ; end
       6'b110000 : begin spm30_contents <= sx ; end
       6'b110001 : begin spm31_contents <= sx ; end
       6'b110010 : begin spm32_contents <= sx ; end
       6'b110011 : begin spm33_contents <= sx ; end
       6'b110100 : begin spm34_contents <= sx ; end
       6'b110101 : begin spm35_contents <= sx ; end
       6'b110110 : begin spm36_contents <= sx ; end
       6'b110111 : begin spm37_contents <= sx ; end
       6'b111000 : begin spm38_contents <= sx ; end
       6'b111001 : begin spm39_contents <= sx ; end
       6'b111010 : begin spm3a_contents <= sx ; end
       6'b111011 : begin spm3b_contents <= sx ; end
       6'b111100 : begin spm3c_contents <= sx ; end
       6'b111101 : begin spm3d_contents <= sx ; end
       6'b111110 : begin spm3e_contents <= sx ; end
       default   : begin spm3f_contents <= sx ; end
     endcase
   end
 end
//**********************************************************************************
// End of simulation code.
//**********************************************************************************
 //synthesis translate_on
////////////////////////////////////////////////////////////////////////////////////
//
// END OF FILE KCPSM3.V
//
////////////////////////////////////////////////////////////////////////////////////
//
endmodule