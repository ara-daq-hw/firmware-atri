`timescale 1ns / 1ps
module trigger_scaler_v2(
		trigger_i,
		power_i,
		mask_i,
		
		trig_p_o,
		trig_n_o,
		scaler_o,
				
		fast_clk_i,
		slow_clk_i,
		slow_ce_i
    );

   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

	//% Number of cycles that the trigger will stay up in *each path* (10 ns/each).
	parameter ONE_SHOT_LENGTH = 3;
	//% Number of bits needed in the one-shot path
	localparam ONE_SHOT_CYCLES = ONE_SHOT_LENGTH - 1;
	//% Number of synchronization cycles (min. trigger latency, times 10 ns). Min 1.
	parameter SYNC_CYCLES = 2;
	
   ////////////////////////////////////////////////////
   //
	// PORTS
	//
   ////////////////////////////////////////////////////
	
	//% Output of IBUFDS
	input trigger_i;
	//% 1 if this trigger is powered
	input power_i;
	//% 1 if this trigger is masked
	input mask_i;
	
	//% Positive-edge synchronous trigger output
	output trig_p_o;
	//% Negative-edge synchronous trigger output
	output trig_n_o;
	//% Scaler output (with stuck-on detection)
	output scaler_o;
	
	//% Fast clock (100 MHz, 1/2 of this determines trig. granularity)
	input fast_clk_i;
	//% Slow clock (used for stuck-on detection)
	input slow_clk_i;
	//% Very slow clock enable (used for stuck-on detection)
	input slow_ce_i;
	
	//% Input trigger bit.
	reg trig_bit = 0;

	//% Output trigger bit, positive edge.
	reg trig_p = 0;
	
	//% Output trigger bit, negative edge.
	reg trig_n = 0;

	//% Clear the positive edge path
	wire clear_p = (trig_path_p[ONE_SHOT_CYCLES-1] && !trigger_i);
	//% Clear the negative edge path
	wire clear_n = (trig_path_n[ONE_SHOT_CYCLES-1] && !trigger_i);
	//% Clear the asynchronous elements.
	wire clear = clear_p || clear_n;

	//% Positive edge trigger path.
	reg [ONE_SHOT_CYCLES-1:0] trig_path_p = {ONE_SHOT_CYCLES{1'b0}};
	//% Negative edge trigger path.
	reg [ONE_SHOT_CYCLES-1:0] trig_path_n = {ONE_SHOT_CYCLES{1'b0}};
	//% Positive edge sync path.
	reg [SYNC_CYCLES-1:0] sync_path_p = {SYNC_CYCLES{1'b0}};
	//% Negative edge sync path.
	reg [SYNC_CYCLES-1:0] sync_path_n = {SYNC_CYCLES{1'b0}};
	
	//% This forms the full sync path for the positive edge.
	wire [SYNC_CYCLES:0] full_sync_p = {sync_path_p,trig_bit};
	//% This forms the full sync path for the negative edge.
	wire [SYNC_CYCLES:0] full_sync_n = {sync_path_n,trig_bit};

	//% Latch a positive edge in the trigger. Clear when ONE_SHOT_CYCLES have occurred. Polarity inverted.
	always @(posedge trigger_i or posedge clear) begin : TRIG_BIT_LOGIC
		if (trigger_i)
			trig_bit <= 1;
		else if (clear)
			trig_bit <= 0;
	end

	//% One shot generator, for the positive edge path.
	always @(posedge fast_clk_i) begin : ONESHOT_P
		if (clear_p)
			trig_path_p[ONE_SHOT_CYCLES-1:0] <= {ONE_SHOT_CYCLES{1'b0}};
		else
			trig_path_p[ONE_SHOT_CYCLES-1:0] <= {trig_path_p[ONE_SHOT_CYCLES-2:0],trig_bit};
	end

	//% Synchronize the trigger bit into the +edge of fast clock
	always @(posedge fast_clk_i) begin : SYNC_P
		// No-power killing is done here.
		if (!power_i) begin
			sync_path_p <= {SYNC_CYCLES{1'b0}};
			trig_p <= 0;
		end else begin
			// Masking is done here. sync_path_p[SYNC_CYCLES-1] is used
			// for the scaler (it's a nonmasked copy)
			trig_p <= (!mask_i && full_sync_p[SYNC_CYCLES-1]);
			sync_path_p <= full_sync_p[SYNC_CYCLES-1:0];
		end
	end

	//% One shot generator, for the negative edge path.
	always @(negedge fast_clk_i) begin : ONESHOT_N
		if (clear_n)
			trig_path_n[ONE_SHOT_CYCLES-1:0] <= {ONE_SHOT_CYCLES{1'b0}};
		else
			trig_path_n[ONE_SHOT_CYCLES-1:0] <= {trig_path_n[ONE_SHOT_CYCLES-2:0],trig_bit};
	end
	
	//% Synchronize the trigger bit to the -edge of fast clock
	always @(negedge fast_clk_i) begin : SYNC_N
		if (!power_i) begin
			sync_path_n <= {SYNC_CYCLES{1'b0}};
			trig_n <= 0;
		end else begin
			trig_n <= (!mask_i && full_sync_n[SYNC_CYCLES-1]);
			sync_path_n <= full_sync_n[SYNC_CYCLES-1:0];
		end
	end

	//// Clear signal for the scaler generator.

	//% Indicates that the flag is still traversing the synchronizer.
	wire busy_p, busy_n;
	//% Flags in the slow clock domain for the +/- edge clear flags. Both on +edge of slowclk.
	wire p_cleared_slowclk, n_cleared_slowclk;
	//% Flag generator to inform slow clock that positive edge chain has seen a clear.
	flag_sync clear_p_flag(.clkA(fast_clk_i),.clkB(slow_clk_i),.in_clkA(clear_p && !busy_p),
									.out_clkB(p_cleared_slowclk),.busy_clkA(busy_p));
	//% Flag generator to inform slow clock that negative edge chain has seen a clear.
	flag_sync #(.CLKA("NEGEDGE")) clear_n_flag(.clkA(fast_clk_i),.clkB(slow_clk_i),.in_clkA(clear_n && !busy_n),
									.out_clkB(n_cleared_slowclk),.busy_clkA(busy_n));

	//% Generates a scaler output, with stuck-on detection. No higher level trigger needs this.
	scaler_generator sc_gen(.trig_i(sync_path_p[SYNC_CYCLES-1]),
									.fclk_i(fast_clk_i),.sclk_i(slow_clk_i),
									.sce_i(slow_ce_i),
									.clear_sclk_i(p_cleared_slowclk || n_cleared_slowclk),
									.scaler_o(scaler_o));

	assign trig_p_o = trig_p;
	assign trig_n_o = trig_n;
endmodule
