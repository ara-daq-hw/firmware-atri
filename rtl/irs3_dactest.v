`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Simple IRS3 DAC testing module. 
//
//////////////////////////////////////////////////////////////////////////////////
module irs3_dactest(
		inout D1DDASENSE,
		output SCLK,
		output SIN,
		input SHOUT,
		output PCLK,
		output REGCLR
    );
	 
	// We use the internal 50 MHz (ish) oscillator for the autotest.
	// This is to avoid any external dependencies: we'll use 
	wire CLK;
	STARTUP_SPARTAN6 startup(.CLK(1'b0),.GSR(1'b0),.GTS(1'b0),.KEYCLEARB(1'b0),
									 .CFGMCLK(CLK));
	
	// Divides CLK by 1+CE_COUNTER_VAL
	localparam CBITS = 8;
	localparam [CBITS-1:0] CE_COUNTER_VAL = 255;
	reg [CBITS-1:0] ce_counter = {CBITS{1'b0}};
	reg ce = 0;
	
	always @(posedge CLK) begin
		if (ce_counter == CE_COUNTER_VAL)
			ce_counter <= {CBITS{1'b0}};
		else
			ce_counter <= ce_counter + 1;
	end
	always @(posedge CLK) begin
		if (ce_counter == CE_COUNTER_VAL)
			ce <= 1;
		else
			ce <= 0;
	end
	
	reg sclk_val = 0;
	always @(posedge CLK) begin
		if (ce) sclk_val <= ~sclk_val;
	end
	
	wire LOAD_SHIFT;
	wire [144:0] NEW_SHIFT_PATTERN;
	reg [144:0] shift_pattern = {145{1'b0}};
	reg do_load = 0;
	reg done_shift = 0;
	always @(posedge CLK) begin
		if (LOAD_SHIFT)
			do_load <= 1;
		else if (ce && sclk_val && do_load)
			do_load <= 0;
	end
	always @(posedge CLK) begin
		if (do_load && sclk_val && ce)
			done_shift <= 0;
		else if (bit_counter == 144 && sclk_val && ce) done_shift <= 1;
	end
	always @(posedge CLK) begin
		if (ce && sclk_val) begin
			if (do_load) shift_pattern <= NEW_SHIFT_PATTERN;
			else shift_pattern <= {shift_pattern[143:0],shift_pattern[144]};
		end
	end

	reg [7:0] bit_counter = {8{1'b0}};

	always @(posedge CLK) begin
		if (ce && sclk_val) begin
			if (do_load) bit_counter <= {8{1'b0}};
			else bit_counter <= bit_counter + 1;
		end
	end

	wire [15:0] ila_debug = {bit_counter,ce_counter[3:0],ce,SHOUT,SIN,SCLK};
	wire [145:0] vio_debug_out;
	assign NEW_SHIFT_PATTERN = vio_debug_out[144:0];
	assign LOAD_SHIFT = vio_debug_out[145];

	wire [35:0] ila_control;
	wire [35:0] vio_control;

	irs3_dactest_icon icon(.CONTROL0(ila_control),.CONTROL1(vio_control));
	irs3_dactest_ila ila(.CONTROL(ila_control),.CLK(CLK),.TRIG0(ila_debug));
	irs3_dactest_vio vio(.CONTROL(vio_control),.CLK(CLK),.SYNC_OUT(vio_debug_out));

	assign SCLK = sclk_val;
	assign SIN = shift_pattern[144];
	assign REGCLR = 0;
	assign PCLK = done_shift;
	assign D1DDASENSE = 1;
endmodule
