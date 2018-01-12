`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Monitor for the IRS2's Wilkinson test counter.
//
// Basic procedure is:
// when IRS enabled,
// wait until the ring counter is done
// 
// This counts number of TSTOUT rising edges in 69636 clock cycles. This is 17*16*16*16+4,
// because the first ring counter has an extra flop in the ring and the others are delayed
// by a cycle. This could be tweaked by setting A0/A1/A2/A3 = 1110 in the first ring counter
// and using Q instead of Q15. That'd give 65539 cycles. But I don't care about the number.
//
// The ring counter here resets each time, so there's no worry about timing jitter killing
// the ring, and the number of cycles is exactly the same each time.
//////////////////////////////////////////////////////////////////////////////////
module irs2_wilkinson_monitor(
		input clk_i,
		input KHz_clk_i,
		input enable_i,
		input present_i,
		input is_init_i,
		input irs2_test_wilk_out_i,
		output irs2_test_wilk_start_o,
		output irs2_test_wilk_clear_o,
		output irs2_wilkinson_count_done_o,
		output [9:0] irs2_wilkinson_count_o,
		output [47:0] debug_o
    );

	wire wilk_count_flag;
	SYNCEDGE #(.EDGE("RISING"),.POLARITY("POSITIVE"),.LATENCY(4),.CLKEDGE("RISING")) wilk_edge_detect(.I(irs2_test_wilk_out_i),.O(wilk_count_flag),.CLK(clk_i));

	reg [9:0] wilkinson_count = {10{1'b0}};
	reg [9:0] wilkinson_count_latch = {10{1'b0}};
	always @(posedge clk_i) begin
		if (irs2_test_wilk_start_o)
			wilkinson_count <= {10{1'b0}};
		else if (wilk_count_flag)
			wilkinson_count <= wilkinson_count + 1;
	end

	// Ring delay.


	wire wilk_delayc_1;
	wire wilk_delay_1_set;
	wire wilk_delay_1_enable;
/*
	reg wilk_delay_1_start = 0;
	always @(posedge clk_i) begin
		if (wilk_delay_1_set || (wilk_delayc_1 && wilk_delay_1_enable))
			wilk_delay_1_start <= 1;
		else
			wilk_delay_1_start <= 0;
	end
	SRLC16 #(.INIT(16'h0000)) wilk_delay_1(.D(wilk_delay_1_start),.CLK(clk_i),.Q15(wilk_delayc_1));
	wire wilk_delayc_2_feedback;
	wire wilk_delayc_2 = (wilk_delayc_2_feedback && wilk_delay_1_enable) || wilk_delay_1_set;
	reg wilk_delay_2_enable = 0;
	// Enable the second ring counter if
	// 1: we preload (wilk_delay_1_set)
	// 2: the first ring counter completes (wilk_delayc_1)
	// 3: no ring counter is enabled (wilk_delay_1_enable)
	// The last one flushes each ring buffer after about 32 cycles.
	always @(posedge clk_i) begin
		if (wilk_delay_2_enable)
			wilk_delay_2_enable <= 0;
		else if (wilk_delayc_1 || (!wilk_delay_1_enable && !wilk_delay_1_set))
			wilk_delay_2_enable <= 1;
	end
	SRLC16E #(.INIT(16'h0000)) wilk_delay_2(.D(wilk_delayc_2),.CE(wilk_delay_2_enable || wilk_delay_1_set),
														 .CLK(clk_i),.Q15(wilk_delayc_2_feedback));
	wire wilk_delayc_3_feedback;
	wire wilk_delayc_3 = (wilk_delayc_3_feedback && wilk_delay_1_enable) || wilk_delay_1_set;
	reg wilk_delay_3_enable = 0;
	always @(posedge clk_i) begin
		if (wilk_delay_3_enable)
			wilk_delay_3_enable <= 0;
		else if ((wilk_delay_2_enable && wilk_delayc_2) || (!wilk_delay_1_enable && !wilk_delay_1_set))
			wilk_delay_3_enable <= 1;
	end
	SRLC16E #(.INIT(16'h0000)) wilk_delay_3(.D(wilk_delayc_3),.CE(wilk_delay_3_enable || wilk_delay_1_set),.CLK(clk_i),.Q15(wilk_delayc_3_feedback));
	wire wilk_delayc_4_feedback;
	wire wilk_delayc_4 = (wilk_delayc_4_feedback && wilk_delay_1_enable) || wilk_delay_1_set;
	reg wilk_delay_4_enable = 0;
	always @(posedge clk_i) begin
		if (wilk_delay_4_enable)
			wilk_delay_4_enable <= 0;
		else if ((wilk_delay_3_enable && wilk_delayc_3) || (!wilk_delay_1_enable && !wilk_delay_1_set))
			wilk_delay_4_enable <= 1;
	end
	SRLC16E #(.INIT(16'h0000)) wilk_delay_4(.D(wilk_delayc_4),.CE(wilk_delay_4_enable || wilk_delay_1_set),.CLK(clk_i),.Q15(wilk_delayc_4_feedback));
	reg wilk_delay_5_enable = 0;
	always @(posedge clk_i) begin
		if (wilk_delay_5_enable)
			wilk_delay_5_enable <= 0;
		else if (wilk_delay_4_enable && wilk_delayc_4_feedback && wilk_delay_1_enable)
			wilk_delay_5_enable <= 1;
	end
	wire wilk_delay_done = wilk_delay_5_enable;
*/
	reg [16:0] wilk_counter = {17{1'b0}};
	localparam [16:0] wilk_delay = 69636;
	wire wilk_count_enable;
	always @(posedge clk_i) begin
		if (wilk_count_enable)	
			wilk_counter <= wilk_counter + 1;
		else
			wilk_counter <= {17{1'b0}};
	end
	assign wilk_delay_done = (wilk_counter == wilk_delay);
	
	localparam		[3:0] IRS2_NOT_PRESENT = 0;
	localparam		[3:0] IRS2_TSTCLR = 1;
	localparam 		[3:0] IRS2_TSTST = 2;
	localparam		[3:0] IRS2_TST_WAIT = 3;
	localparam		[3:0] IRS2_COUNT_START = 4;
	localparam		[3:0] IRS2_COUNTING = 5;
	localparam		[3:0] IRS2_DONE = 6;
	localparam  	[3:0] IRS2_LATCH = 7;
	localparam		[3:0] IRS2_LATCH_DONE = 8;
	localparam 		[3:0] IRS2_WAIT = 9;
	localparam		[3:0] IDLE_WAIT = 10;
	reg [3:0] state = IRS2_NOT_PRESENT;

	reg first_time_done = 0;
	reg [3:0] wait_counter = {4{1'b0}};
	wire wait_done = (wait_counter == 4'b1111 && KHz_clk_i);
	assign wilk_count_enable = (state == IRS2_COUNTING);
	
	// Basic state machine:
	// When first enabled, issue a test counter start, then
	// wait for the first toggle on TSTST. When that happens, begin the
	// ring counter. When the ring counter finishes, latch the number of
	// TSTST toggles.
	always @(posedge clk_i) begin
		if (!present_i || !enable_i) state <= IRS2_NOT_PRESENT;
		else begin
			case (state)
				IRS2_NOT_PRESENT: if (enable_i && is_init_i) state <= IRS2_TSTCLR;
				IRS2_TSTCLR: if (!first_time_done) state <= IRS2_TSTST; else state <= IDLE_WAIT;
				IRS2_TSTST: state <= IRS2_TST_WAIT;
				IRS2_TST_WAIT: if (irs2_test_wilk_out_i) state <= IRS2_COUNT_START;
				IRS2_COUNT_START: state <= IRS2_COUNTING;
				IRS2_COUNTING: if (wilk_delay_done) state <= IRS2_DONE;
				IRS2_DONE: state <= IRS2_LATCH;
				IRS2_LATCH: state <= IRS2_LATCH_DONE;
				IRS2_LATCH_DONE: state <= IRS2_TSTCLR;
				IDLE_WAIT: if (wait_done) state <= IRS2_TSTST;
			endcase
		end
	end
	// Fire off TSTCLR if enable_i falls.
	wire counter_disable;
	SYNCEDGE #(.EDGE("FALLING")) dis_flag(.I(enable_i),.O(counter_disable),.CLK(clk_i));
	assign irs2_test_wilk_start_o = (state == IRS2_TSTST);
	assign irs2_test_wilk_clear_o = (state == IRS2_TSTCLR) || counter_disable;
	assign wilk_delay_1_set = (state == IRS2_COUNT_START);
	assign wilk_delay_1_enable = (state == IRS2_COUNTING);
	always @(posedge clk_i) begin
		if (state == IRS2_NOT_PRESENT || (state == IDLE_WAIT && wait_done))
			wilkinson_count_latch <= {16{1'b0}};
		else if (state == IRS2_LATCH)
			wilkinson_count_latch <= wilkinson_count;
	end
	
	always @(posedge clk_i) begin
		if (!enable_i || !present_i)
			first_time_done <= 0;
		else if (state == IRS2_LATCH_DONE)
			first_time_done <= 1;
	end
	
	always @(posedge clk_i) begin
		if (state == IDLE_WAIT) begin
			if (KHz_clk_i)
				wait_counter <= wait_counter + 1;
		end else
			wait_counter <= {4{1'b0}};
	end
	
	
	assign irs2_wilkinson_count_o = wilkinson_count_latch;
	assign irs2_wilkinson_count_done_o = (state == IRS2_LATCH_DONE);

	assign debug_o[3:0] = state;
	assign debug_o[7:4] = wait_counter;
	assign debug_o[8] = irs2_test_wilk_start_o;
	assign debug_o[9] = irs2_test_wilk_clear_o;
	assign debug_o[10] = is_init_i;
	assign debug_o[11] = enable_i;
	assign debug_o[12] = first_time_done;
	assign debug_o[13] = wilk_delay_done;
	assign debug_o[23:14] = irs2_wilkinson_count_o;
	assign debug_o[24] = irs2_wilkinson_count_done_o;
	assign debug_o[25] = KHz_clk_i;
endmodule
