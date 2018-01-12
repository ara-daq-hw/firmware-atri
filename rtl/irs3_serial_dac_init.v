`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:18:58 03/01/2012 
// Design Name: 
// Module Name:    irs3_serial_dac_init 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

//	irs3_serial_dac_init irs3_dacinit(.clk_i(clk_i),
//												 .irs_init_i(irs_is_init),
//												 .irs_mode_i(irs_mode),
//												 .irs_sclk_o(irs3_sclk),
//												 .irs_sin_o(irs3_sin),
//												 .irs_shout_i(RD[3]),
//												 .irs_regclr_o(irs3_regclr),
//												 .irs_pclk_o(irs3_pclk));
module irs3_serial_dac_init(
		input clk_i,
		input irs_init_i,
		input irs_mode_i,
		input [11:0] sbbias_i,
		output irs_sclk_o,
		output irs_sin_o,
		input irs_shout_i,
		output irs_regclr_o,
		output irs_pclk_o,
		output irs_dac_busy_o
    );

	// Convert millivolts to the value to shift in.
	// This needs to be tweaked, the actual DAC can't go rail-to-rail.
	function [11:0] irs3_dac_shift_value;
		// Value can't exceed 2500, so this is 12 bits.
		input [11:0] millivolts;
		// Then to convert to the DAC value, we
		// need to multiply by 16384, then divide by 10,000.
		reg [25:0] millivolts_times_16384;
		reg [11:0] raw_dac_value;
		begin
			millivolts_times_16384 = {millivolts,{14{1'b0}}};
			raw_dac_value = millivolts_times_16384/10000;
			irs3_dac_shift_value = raw_dac_value;
		end
	endfunction

	// SBbias is fed in externally now.
	localparam [11:0] IRS3_SBBIAS = 12'h7FF;
	// 24 bits
	localparam [11:0] IRS3_TRGTHREF = 12'h7FF;
	// 36 bits
	localparam [11:0] IRS3_TRIG1 = 12'h800;
	// 48 bits
	localparam [11:0] IRS3_TRIG2 = irs3_dac_shift_value(0);
	// 60 bits
	localparam [11:0] IRS3_TRIG3 = irs3_dac_shift_value(0);
	// 72 bits
	localparam [11:0] IRS3_TRIG4 = irs3_dac_shift_value(0);
	// 84 bits
	localparam [11:0] IRS3_TRIG5 = irs3_dac_shift_value(0);
	// 96 bits
	localparam [11:0] IRS3_TRIG6 = irs3_dac_shift_value(0);
	// 108 bits
	localparam [11:0] IRS3_TRIG7 = irs3_dac_shift_value(0);
	// 120 bits
	localparam [11:0] IRS3_TRIG8 = irs3_dac_shift_value(0);
	// 132 bits
	localparam [11:0] IRS3_TBBIAS = 12'h7FF;
	// 144 bits
	localparam [11:0] IRS3_TRGBIAS = irs3_dac_shift_value(0);
	// 145 bits
	localparam IRS3_SGN = 1'b0;
	localparam IRS3_NBITS = 145;
	wire [IRS3_NBITS-1:0] IRS3_DAC_VALUE = {sbbias_i,IRS3_TRGTHREF,
											 IRS3_TRIG1,IRS3_TRIG2,IRS3_TRIG3,IRS3_TRIG4,
											 IRS3_TRIG5,IRS3_TRIG6,IRS3_TRIG7,IRS3_TRIG8,
											 IRS3_TBBIAS,IRS3_TRGBIAS,IRS3_SGN};
	reg [IRS3_NBITS-1:0] irs3_shift_reg = {IRS3_NBITS{1'b0}};
	reg [7:0] irs3_counter = {8{1'b0}};
	localparam CE_NBITS = 4;
	localparam [CE_NBITS-1:0] CE_COUNT = 15;
	reg [CE_NBITS-1:0] ce_counter = {CE_NBITS{1'b0}};
	reg ce = 1'b0; // run at 1/2 IRS clock frequency
	
	wire irs3_dac_begin;
	SYNCEDGE_R irs3_dac_init(.I(irs_init_i && irs_mode_i),.O(irs3_dac_begin),.CLK(clk_i));
	
	localparam FSM_BITS = 3;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] RESET = 1;
	localparam [FSM_BITS-1:0] LOAD = 2;
	localparam [FSM_BITS-1:0] SHIFT = 3;
	localparam [FSM_BITS-1:0] DONE = 4;
	reg [FSM_BITS-1:0] state = IDLE;

	always @(posedge clk_i) begin
		ce_counter <= ce_counter + 1;
	end

	always @(posedge clk_i) begin
		ce <= (ce_counter == CE_COUNT);
	end

	always @(posedge clk_i) begin
		if (irs3_dac_begin) state <= RESET;
		else if (ce) begin
			case(state)
				IDLE: state <= IDLE;
				RESET: state <= LOAD;
				LOAD: state <= SHIFT;
				SHIFT: if (irs3_counter == IRS3_NBITS) state <= DONE; else state <= LOAD;
				DONE: state <= IDLE;
				default: state <= IDLE;
			endcase
		end
	end
	always @(posedge clk_i) begin
		if (state == RESET) irs3_counter <= {8{1'b0}};
		else if (ce && state == LOAD) irs3_counter <= irs3_counter + 1;
	end
	always @(posedge clk_i) begin
		if (state == RESET) irs3_shift_reg <= IRS3_DAC_VALUE;
		else if (ce && state == SHIFT) irs3_shift_reg <= {irs3_shift_reg[IRS3_NBITS-2:0],1'b0};
	end
	assign irs_sin_o = irs3_shift_reg[IRS3_NBITS-1];
	assign irs_sclk_o = (state == SHIFT);
	assign irs_pclk_o = (state == DONE);
	// Ditch regclr, it doesn't do anything.
	assign irs_regclr_o = 1'b0;
	assign irs_dac_busy_o = (state != IDLE);
endmodule
