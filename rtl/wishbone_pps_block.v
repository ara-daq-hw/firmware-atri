`timescale 1ns / 1ps
`include "wb_interface.vh"

//% @brief WISHBONE PPS block.
//%
//% The wishbone_pps_block counts fast_clk_i cycles per PPS.
//% It also can generate a PPS-ish flag if no external PPS exists.
//%
//% NOTE: cycle_count_o, pps_count_o, and pps_flag_fast_clk_o are in the
//% 		 fast clock domain.
module wishbone_pps_block(
			interface_io,
			slow_ce_i,
			fast_clk_i,
			pps_i,
			pps_flag_i,
			pps_flag_fast_clk_o,
			pps_flag_o,
			cycle_count_o,
			pps_count_o,
			timed_trigger_o
    );

	//% WISHBONE interface
	inout [`WBIF_SIZE-1:0] interface_io;
	//% 1 kHz clock enable (single cycle flag every millisecond)
	input slow_ce_i;
	//% Fast clock (IRS clock) - nominally 100 MHz
	input fast_clk_i;
	//% Asynchronous PPS input.
	input pps_i;
	//% Synchronous PPS flag input (from PHY).
	input pps_flag_i;
	//% Synchronous PPS flag in the fast_clk domain (either from pps_i or internal).
	output pps_flag_fast_clk_o;
	//% Synchronous PPS flag output (either internal or from PHY).
	output pps_flag_o;

	output [31:0] cycle_count_o;
	output [15:0] pps_count_o;
	output timed_trigger_o;
	
	// WISHBONE interface expander.
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
	
	// Cycle count registers.
	
	//% Current number of cycles this second, in Gray.
	wire [27:0] clock_count_gray;
	//% Reset the clock counter.
	wire clock_count_reset;
	//% Latched number of cycles this second, in Gray.
	reg [27:0] cur_sec_gray = {28{1'b0}};
	//% Latched number of cycles this second, in binary.
	wire [27:0] cur_sec_bin;
	//% Flag to begin the Gray to Binary conversion.
	reg begin_gray_convert = 0;
	//% Flag indicating that the Gray conversion is done.
	wire gray_convert_done;
	//% Latched number of cycles this second, in binary, in WISHBONE clock domain.
	reg [27:0] cur_sec_bin_wbclk = {28{1'b0}};
	//% Flag indicating that the Gray conversion is done, in WISHBONE clock domain.
	wire gray_convert_done_wbclk;
	
	//% Flag indicating a PPS has occurred, in fast_clk_i domain.
	wire pps_flag_fastclk;
	
	// Internal PPS generation registers.
	
	//% If 1, the pps_flag_o output is an internally generated PPS.
	reg pps_select_internal = 0;
	//% Counter for the internal PPS.
	reg [9:0] pps_internal_counter = {10{1'b0}};
	//% Internally generated PPS flag.
	reg pps_internal = 0;
	//% Internally generated PPS flag in fast_clk_i domain.
	wire pps_internal_fastclk;

	// Current second count registers.
	//% Current second in the fast clock domain
	reg [31:0] sec_cnt_fastclk = {32{1'b0}};
	//% Reset current second count, in fast clock domain
	wire reset_sec_cnt_fastclk;
	//% Current second in WISHBONE clock domain
	reg [31:0] sec_cnt_wbclk = {32{1'b0}};
	//% Update WISHBONE clock domain second count
	wire update_sec_cnt_wbclk;


	// Control registers.

	//% Control register data output. Right now just the internal PPS.
	wire [7:0] pps_control_register = {{7{1'b0}}, pps_select_internal};
	//% Multiplexed WISHBONE data output.
	reg [7:0] dat_out_muxed = {8{1'b0}};

	reg [15:0] target65536 = {16{1'b0}};
	reg [7:0] target256 = {8{1'b0}};
	reg [1:0] timed_trig_ctrl_reg = {2{1'b0}};
	wire [7:0] timed_trig_ctrl = {{6{1'b0}}, timed_trig_ctrl_reg};

	//////////////////////////////////////////////////////////
	// WISHBONE REGISTERS											  //
	//////////////////////////////////////////////////////////

	wire [7:0] wishbone_registers[15:0];

	function [3:0] BASE;
		input [15:0] bar_value;
		begin
			BASE = bar_value[3:0];
		end
	endfunction		
	`define OUTPUT(addr, x, range, dummy) 					\
		assign wishbone_registers[ addr ] range = x
	`define SELECT(addr, x, addrrange, dummy)          \
		wire x;														\
		localparam [3:0] addr_``x = addr;					\
		assign x = (cyc_i && stb_i && wr_i && ack_o && (adr_i addrrange == addr_``x addrrange))
	`define WISHBONE_ADDRESS( addr, name, TYPE, par1, par2) \
		`TYPE(BASE(addr), name, par1, par2)
	
	`WISHBONE_ADDRESS(16'h0040, reset_sec_cnt_wbclk, SELECT, [3:2], 0);
	`WISHBONE_ADDRESS(16'h0040, cur_sec_bin_wbclk[7:0] , OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0041, cur_sec_bin_wbclk[15:8] , OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0042, cur_sec_bin_wbclk[23:16], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0043, {{4{1'b0}},cur_sec_bin_wbclk[27:24]}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0044, sec_cnt_wbclk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0045, sec_cnt_wbclk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0046, sec_cnt_wbclk[23:16], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0047, sec_cnt_wbclk[31:24], OUTPUT, [7:0], 0);
	// PPS control is shadowed at 10xx.
	`WISHBONE_ADDRESS(16'h0048, sel_pps_control_register, SELECT, [3:2], 0);
	`WISHBONE_ADDRESS(16'h0048, pps_control_register, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0049, pps_control_register, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h004A, pps_control_register, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h004B, pps_control_register, OUTPUT, [7:0], 0);
	// Timed trigger stuff.
	`WISHBONE_ADDRESS(16'h004C, sel_timed_trigger_registers, SELECT, [3:2], 0);
	`WISHBONE_ADDRESS(16'h004C, target65536[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h004D, target65536[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h004E, target256, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h004F, timed_trig_ctrl, OUTPUT, [7:0], 0);

	`undef OUTPUT
	`undef SELECT
	`undef WISHBONE_ADDRESS


	//////////////////////////////////////////////////////////
	// MODULES AND LOGIC                                    //
	//////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////
	// CYCLE COUNTER                                        //
	//////////////////////////////////////////////////////////
	
	//% Simple, unpipelined Gray counter.
	Simple_Gray_Counter #(.WIDTH(28)) counter(.CLK(fast_clk_i),.CE(1'b1),.RST(clock_count_reset),
								 .Q(clock_count_gray));

	//% Latch cur_sec_gray on pps_i's rising edge. It's a Gray counter, so async. latching is safe.
	always @(posedge pps_i) begin
		cur_sec_gray <= clock_count_gray;
	end

	//////////////////////////////////////////////////////////
	// END CYCLE COUNTER                                    //
	//////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////
	// GRAY TO BINARY CONVERSION                            //
	//////////////////////////////////////////////////////////
	
	//% Parametrizable Gray to binary converter. We don't need high throughput or speed.
	Generic_Gray_to_Binary #(.WIDTH(28), .LATENCY(6), .THROUGHPUT("PARTIAL"))
			counter_convert(.CLK(fast_clk_i),.CE(1'b1),.G_in(cur_sec_gray),.B_out(cur_sec_bin),
								 .CONVERT(begin_gray_convert),.VALID(gray_convert_done));

	//% Pass the gray_convert_done signal to WISHBONE clock domain.
	flag_sync convert_done(.clkA(fast_clk_i),.clkB(clk_i),.in_clkA(gray_convert_done),
								  .out_clkB(gray_convert_done_wbclk));

	//% When gray_convert_done signal goes in WISHBONE clock domain, latch cur_sec_bin.
	always @(posedge clk_i) begin
		if (gray_convert_done_wbclk)
			cur_sec_bin_wbclk = cur_sec_bin;
	end

	//% Generate a flag in fast_clk_i domain from when pps_i goes high.
	SYNCEDGE_R pps_flag_fastclk_gen(.I(pps_i),.O(pps_flag_fastclk),.CLK(fast_clk_i));

	//% Reset the clock counter when pps_flag_fastclk occurs.
	assign clock_count_reset = pps_flag_fast_clk_o;

	//% Begin the binary to Gray conversion after the Gray count is reset.
	always @(posedge fast_clk_i) begin
		if (begin_gray_convert)
			begin_gray_convert <= 0;
		else if (clock_count_reset)
			begin_gray_convert <= 1;
	end

	//////////////////////////////////////////////////////////
	// END GRAY TO BINARY CONVERSION                        //
	//////////////////////////////////////////////////////////


	//////////////////////////////////////////////////////////
	// INTERNAL PPS GENERATION                              //
	//////////////////////////////////////////////////////////

	//% If internal PPS is selected, count up once each slow_ce_i
	always @(posedge clk_i) begin
		if (!pps_select_internal || pps_internal_counter == 1000)
			pps_internal_counter <= {10{1'b0}};
		else if (slow_ce_i)
			pps_internal_counter <= pps_internal_counter + 1;
	end

	//% Generate a flag when pps_internal_counter hits 1000.
	always @(posedge clk_i) begin
		pps_internal <= (pps_internal_counter == 1000);
	end

	//% Generate fast_clk_i-domain pps_internal flag.
	flag_sync internal_fastclk_flag(.clkA(clk_i),.clkB(fast_clk_i),
												.in_clkA(pps_internal),
												.out_clkB(pps_internal_fastclk));

	//% WISHBONE data input.
	always @(posedge clk_i) begin
		if (sel_pps_control_register)
			pps_select_internal <= dat_i[0];
	end

	//////////////////////////////////////////////////////////
	// END INTERNAL PPS GENERATION                          //
	//////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////
	// PPS COUNTER														  //
	//////////////////////////////////////////////////////////


	//% Pass the flag over to the fast clock domain
	flag_sync reset_sec_cnt_sync(.in_clkA(reset_sec_cnt_wbclk),.out_clkB(reset_sec_cnt_fastclk),
										  .clkA(clk_i),.clkB(fast_clk_i));

	//% Second counter, in fast clock domain
	always @(posedge fast_clk_i) begin
		if (reset_sec_cnt_fastclk)
			sec_cnt_fastclk <= {32{1'b0}};
		else if (pps_flag_fastclk)
			sec_cnt_fastclk <= sec_cnt_fastclk + 1;
	end

	//% Pass the update flag back to the wb_clk domain
	flag_sync update_sec_cnt_sync(.in_clkA(pps_flag_fast_clk_o),.out_clkB(update_sec_cnt_wbclk),
											.clkA(fast_clk_i),.clkB(clk_i));
	//% Latch in the wb_clk domain
	always @(posedge clk_i) begin
		if (update_sec_cnt_wbclk)
			sec_cnt_wbclk <= sec_cnt_fastclk;
	end

	//////////////////////////////////////////////////////////
	// END PPS COUNTER												  //
	//////////////////////////////////////////////////////////

	// If we want to be able to trigger on *any* clock, we need 27 bits to count it.
	// We don't actually care *that* much, so we'll use 24 bits: which gives us the
	// ability to trigger in any 80 ns window.
	// First we count every 8 clocks, and fire a flag. That counts up to 256, and generates
	//	a flag (20.48 us). That flag is used to count up to a maximum of 48828 (which corresponds to 
	// t=t0+0.99999744s.
	// If the 16-bit counter matches the current 20.48us counter, a register is set.
	// Then if a clock counter matches the current 256-cycle counter, a register is set.
	// If both of those two are valid, we fire the trigger. Note that if you set a value past the
	// end of the second, it will never fire. Also note that you might get *two* triggers (which...
	// won't do anything right now) if you set a time *very* near the end of the second, and the
	// clock is significantly slower than 100 MHz, since the 256-cycle counter free-runs. But this
	// isn't ever really the case.
	reg [2:0] flag_divide_by_8 = {3{1'b0}};
	reg pre_flag_80ns = 0;
	reg flag_80ns = 0;
	reg flag_20480ns = 0;
	reg counter_max_reached = 0;
	reg [7:0] counter256 = {8{1'b0}};
	reg [15:0] counter65536 = {16{1'b0}};
	always @(posedge fast_clk_i) begin
		if (pps_flag_fast_clk_o) flag_divide_by_8 <= {3{1'b0}};
		else flag_divide_by_8 <= flag_divide_by_8 + 1;
	end
	// Make sure none of the flags go at pps_flag_fast_clk_o.

	always @(posedge fast_clk_i) begin
		pre_flag_80ns <= (flag_divide_by_8 == 6);
	end
	always @(posedge fast_clk_i) begin
		flag_80ns <= pre_flag_80ns;
	end
	always @(posedge fast_clk_i) begin
		if (pps_flag_fast_clk_o) counter256 <= {8{1'b0}};
		else if (flag_80ns) counter256 <= counter256 + 1;
	end
	// This guarantees that flag_20480ns goes at the same time as
	// flag_20480ns.
	always @(posedge fast_clk_i) begin
		flag_20480ns <= (counter256 == 255 && pre_flag_80ns);
	end
	always @(posedge fast_clk_i) begin
		if (pps_flag_fast_clk_o) counter65536 <= {16{1'b0}};
		else if (!counter_max_reached && flag_20480ns) begin
			counter65536 <= counter65536 + 1;
		end
	end
	reg match_256 = 0;
	reg match_65536 = 0;
	always @(posedge fast_clk_i) begin
		match_256 <= (counter256 == target256);
	end
	always @(posedge fast_clk_i) begin
		match_65536 <= (counter65536 == target65536);
	end
	// Both of the above two can go metastable since target256/target65536 are in the
	// wrong clock domain, and then the AND of the two can go metastable as well.
	// So we register them twice, so they'll settle.
	wire matched = match_256 && match_65536;
	reg [1:0] matched_sync = {2{1'b0}};
	always @(posedge fast_clk_i) begin
		matched_sync <= {matched_sync[0],matched};
	end
	wire timed_trigger_flag;
	reg timed_trigger = 0;
	wire timed_trigger_enable_fastclk;
	signal_sync timed_enable_sync(.in_clkA(timed_trig_ctrl_reg[0]),.out_clkB(timed_trigger_enable_fastclk),
											.clkA(clk_i), .clkB(fast_clk_i));
	always @(posedge fast_clk_i) begin
		timed_trigger <= (matched_sync[1] && timed_trigger_enable_fastclk);
	end
	SYNCEDGE #(.CLKEDGE("RISING"),.EDGE("RISING"),.LATENCY(0)) 
			timed_trigger_flag_gen(.I(timed_trigger),.O(timed_trigger_flag),.CLK(fast_clk_i));
				
	wire timed_trigger_fired_wbclk;
	wire timed_trigger_busy;
	flag_sync timed_trigger_flag_sync(.in_clkA(timed_trigger_flag && !timed_trigger_busy),.out_clkB(timed_trigger_fired_wbclk),
												 .busy_clkA(timed_trigger_busy),.clkA(fast_clk_i),.clkB(clk_i));
	always @(posedge clk_i) begin
		if (sel_timed_trigger_registers) begin
			case (adr_i[1:0])
				2'b00: target65536[7:0] <= dat_i;
				2'b01: target65536[15:8] <= dat_i;
				2'b10: target256 <= dat_i;
				2'b11: timed_trig_ctrl_reg <= dat_i[1:0];
			endcase
		end else begin
			if (timed_trigger_fired_wbclk) begin
				// If bit 1 is set, rearm trigger. Else disable trigger.
				timed_trig_ctrl_reg[0] <= timed_trig_ctrl_reg[1];
			end
		end
	end
		
	//% assign WISHBONE ack output whenever we are addressed (zero-cycle latency)
	assign ack_o = (cyc_i && stb_i);

	//% no WISHBONE errors
	assign err_o = 0;
	
	//% no WISHBONE retries
	assign rty_o = 0;

	//% assign WISHBONE data output to multiplexed data
	assign dat_o = wishbone_registers[ adr_i[3:0] ];

	//% assign pps_flag_o to either the original pps flag, or the internal pps flag
	assign pps_flag_o = (pps_select_internal) ? pps_internal : pps_flag_i;

	//% assign pps_flag_fast_clk_o to either the internally generated flag or our derived flag
	assign pps_flag_fast_clk_o = (pps_select_internal) ? pps_internal_fastclk : pps_flag_fastclk;

	//% Cycle counter is just the Gray counter's output.
	assign cycle_count_o = clock_count_gray;

	//% PPS counter
	assign pps_count_o = sec_cnt_fastclk;
	
	//% Timed trigger
	assign timed_trigger_o = timed_trigger_flag;

endmodule
