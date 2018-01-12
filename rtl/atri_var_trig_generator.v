`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Generates a soft trigger output based on the inputs given
// (from WISHBONE module).
//
// "s_" inputs/outputs are in the slow_clk domain. "f_" inputs/outputs
// are in the fast clock domain.
//////////////////////////////////////////////////////////////////////////////////
module atri_var_trig_generator #(
			parameter COUNTER_WIDTH=4,
			parameter INFO_WIDTH=4
		)
		(
		input slow_clk_i,
		input fast_clk_i,
		input s_rst_i,
		input f_rst_i,
		input [COUNTER_WIDTH-1:0] s_nblk_new_i,
		output [COUNTER_WIDTH-1:0] s_nblk_o,
		input s_nblk_write_i,
		input s_start_i,
		input s_clr_info_i,
		output [INFO_WIDTH-1:0] s_info_o,
		output [INFO_WIDTH-1:0] f_info_o,
		output f_trig_o,
		input disable_i
    );

	reg soft_trig_fastclk = 0;
	wire start_fastclk;
	wire soft_trig_start_fastclk = (start_fastclk && !soft_trig_fastclk && !f_rst_i && !disable_i);

	// Updating the number of blocks requires:
	// 1: we are not soft triggering currently
	// 2: we have already synced the previous change.
	wire nblk_sync_busy;
	reg [COUNTER_WIDTH-1:0] nblk_slow_clk = {COUNTER_WIDTH{1'b0}};
	reg [COUNTER_WIDTH-1:0] nblk_fast_clk = {COUNTER_WIDTH{1'b0}};
	always @(posedge slow_clk_i) begin
		if (s_rst_i)
			nblk_slow_clk <= {COUNTER_WIDTH{1'b0}};
		else if (s_nblk_write_i && !nblk_sync_busy)
			nblk_slow_clk <= s_nblk_new_i;
	end

	wire nblk_write_fastclk;
	wire nblk_ack_fastclk;
	task_sync write_sync(.req_clkA(s_nblk_write_i),.busy_clkA(nblk_sync_busy),
								.req_clkB(nblk_write_fastclk),.ack_clkB(nblk_ack_fastclk),
								.clkA(slow_clk_i),.clkB(fast_clk_i));
	reg nblk_write_pending = 0;
	reg in_reset = 0;
	always @(posedge fast_clk_i) begin
		if (f_rst_i)
			in_reset <= 1;
		else if (!soft_trig_fastclk)
			in_reset <= 0;
	end
	// We ack when we're not in reset, when there's no soft trigger going on,
	// and when there's a write pending.
	assign nblk_ack_fastclk = 
		(nblk_write_pending && !soft_trig_start_fastclk && !soft_trig_fastclk && !(in_reset || f_rst_i));
	always @(posedge fast_clk_i) begin
		if (nblk_ack_fastclk)
			nblk_write_pending <= 0;
		else if (nblk_write_fastclk) 
			nblk_write_pending <= 1;
	end
	// We reset when the soft trigger has finished.
	always @(posedge fast_clk_i) begin
		if (in_reset && !soft_trig_fastclk)
			nblk_fast_clk <= {COUNTER_WIDTH{1'b0}};
		else if (nblk_ack_fastclk)
			nblk_fast_clk <= nblk_slow_clk;
	end
								
	reg [COUNTER_WIDTH:0] nblk_counter = {COUNTER_WIDTH+1{1'b0}};

	flag_sync trig_sync(.in_clkA(s_start_i),.out_clkB(start_fastclk),
							  .clkA(slow_clk_i),.clkB(fast_clk_i));

	// nothing after here resets with f_rst_i

	wire [COUNTER_WIDTH:0] nblk_fast_clk_upshift = {nblk_fast_clk,1'b0};
	wire soft_trig_fastclk_clr = (nblk_counter > nblk_fast_clk_upshift);
	always @(posedge fast_clk_i) begin
		if (soft_trig_fastclk_clr)
			nblk_counter <= {COUNTER_WIDTH+1{1'b0}};
		else if (soft_trig_fastclk || soft_trig_start_fastclk)
			nblk_counter <= nblk_counter + 1;
	end	
	always @(posedge fast_clk_i) begin
		if (soft_trig_start_fastclk)
			soft_trig_fastclk <= 1;
		else if (soft_trig_fastclk_clr)
			soft_trig_fastclk <= 0;
	end

	wire soft_info_clr_fastclk;
	flag_sync clr_sync(.in_clkA(s_clr_info_i),.out_clkB(soft_info_clr_fastclk),
							 .clkA(slow_clk_i),.clkB(fast_clk_i));

	reg [3:0] soft_trig_info = {3{1'b0}};
	always @(posedge fast_clk_i) begin
		if (soft_info_clr_fastclk || f_rst_i)
			soft_trig_info <= {4{1'b0}};
		else if (soft_trig_fastclk_clr)
			soft_trig_info <= soft_trig_info + 1;
	end

	wire soft_info_fastclk_update = 
		(soft_info_clr_fastclk || f_rst_i || soft_trig_fastclk_clr);

	reg soft_info_fastclk_update_reg = 0;
	always @(posedge fast_clk_i) begin
		soft_info_fastclk_update_reg <= soft_info_fastclk_update;
	end
	wire soft_info_slowclk_update;
	wire soft_info_slowclk_busy_fastclk;
	reg [INFO_WIDTH-1:0] soft_trig_info_fastclk_slow_update = {4{1'b0}};
	reg [INFO_WIDTH-1:0] soft_trig_info_slowclk = {4{1'b0}};
	flag_sync update_sync(.in_clkA(soft_info_fastclk_update_reg),.out_clkB(soft_info_slowclk_update),
								 .busy_clkA(soft_info_slowclk_busy_fastclk),
								 .clkA(fast_clk_i),.clkB(slow_clk_i));
	always @(posedge fast_clk_i) begin
		if (!soft_info_slowclk_busy_fastclk)
			soft_trig_info_fastclk_slow_update <= soft_trig_info;
	end
	always @(posedge fast_clk_i) begin
		if (soft_info_slowclk_update)
			soft_trig_info_slowclk <= soft_trig_info_fastclk_slow_update;
	end

	reg trigger = 0;
	always @(posedge fast_clk_i) begin
		trigger <= (soft_trig_fastclk || soft_trig_start_fastclk);
	end

	assign s_info_o = soft_trig_info_slowclk;
	assign f_trig_o = trigger;
	assign f_info_o = soft_trig_info;
	assign s_nblk_o = nblk_slow_clk;
endmodule
