`timescale 1ns / 1ps
//% @file scaler_generator.v Contains scaler generator module.

//% @brief Generates a flag (with stuck on detection) that can be used as a scaler.
module scaler_generator(
		trig_i,
		fclk_i,
		sclk_i,
		sce_i,
		clear_sclk_i,
		sync_i,
		scaler_o
    );

   ////////////////////////////////////////////////////
   //
	// PARAMETERS
	//
   ////////////////////////////////////////////////////
	
	//% Number of sce_i flags seen before bit is considered stuck.
	parameter STUCK_CYCLES = 10;

   ////////////////////////////////////////////////////
   //
	// PORTS
	//
   ////////////////////////////////////////////////////

	//% Trigger input. In fclk_i domain.
	input trig_i;
	//% Fast clock.
	input fclk_i;
	//% Slow clock. Used for determining stuck bit.
	input sclk_i;
	//% Slow clock enable. Used to determine how long to wait before stuck-on.
	input sce_i;
	//% Clear indicator. Used to clear stuck-on detection. In sclk_i domain.
	input clear_sclk_i;
	//% Scaler output. In fast clock domain.
	output scaler_o;
	//% Synchronize stuck-on detection.
	input sync_i;
	
   ////////////////////////////////////////////////////
   //
	// INTERNAL SIGNALS
	//
   ////////////////////////////////////////////////////

	// Signals which start stuck-on detection.

	//% Set to 1 when a trigger occurs and slow clock has not acknowledged seeing one.
	reg trig_seen = 0;
	//% trig_seen passed to the slow clock domain.
	wire trig_seen_slow_clk;
	//% Set to 1 when slow clock has seen the trig_seen signal.
	reg slow_clk_had_trig = 0;
	//% Same as slow_clk_had_trig in slow_clk domain.
	wire slow_clk_saw_trig;
	
	// Signals which indicate a clear has occurred.

	//% clear_p flag, passed to the slow clock domain
	wire p_cleared_slowclk;
	//% clear_n flag, passed to the slow clock domain
	wire n_cleared_slowclk;
	//% clear_p flag is passing to the slow clock domain
	wire busy_p;
	//% clear_n flag is passing to the slow clock domain
	wire busy_n;
	
	//% Bit is currently stuck high.
	wire bit_is_stuck;
	//% bit_is_stuck passed to fast clock domain
	wire bit_is_stuck_fastclk_p;
	//% Clear has been seen, in the slow clock domain.
	reg clear_seen_slowclk = 0;
	
	//% Stuck detection pipeline.
	reg [STUCK_CYCLES-1:0] stuck_detect = {STUCK_CYCLES{1'b0}};
	//% Bit is stuck, in the fast clock domain.
	reg stuck_fast_clk = 0;

	//% Edge detected on trig_i
	wire trig_posedge_flag;
	
	//% Actual scaler output bit.
	reg scaler_bit = 0;

   ////////////////////////////////////////////////////
   //
	// LOGIC
	//
   ////////////////////////////////////////////////////
	
   //// Flags/signals indicating trigger has occurred and trigger has cleared.
	
	//// Trigger has been seen:
	
	//// Fast clock domain
	//% trig_seen: inform slow clock domain a trigger has occurred
	always @(posedge fclk_i) begin : TRIG_SEEN_LOGIC
		if (!slow_clk_saw_trig && trig_i)
			trig_seen <= 1;
		else
			trig_seen <= 0;
	end

	//// Clock boundary.
	//% Pass trig_seen to slow clock domain
	signal_sync trig_seen_to_slow_clk(.in_clkA(trig_seen),.out_clkB(trig_seen_slow_clk),
													.clkA(sclk_i),.clkB(fclk_i));
	//% Pass back the fast clock domain that the slow clock has received (and latched) trig_p_seen.
	signal_sync slow_clk_trig_to_fast_clk(.in_clkA(slow_clk_had_trig),.out_clkB(slow_clk_saw_trig),
														 .clkA(sclk_i),.clkB(fclk_i));
	
	//// Slow clock domain.
	
	//% In each sce_i time slice, indicates whether trig_p has been seen.
	always @(posedge sclk_i) begin : SLOW_CLOCK_HAD_TRIG_LOGIC
		if (sce_i)
			slow_clk_had_trig <= 0;
		else if (trig_seen_slow_clk)
			slow_clk_had_trig <= 1;
	end
	
	//// Clear has been seen is just clear_sclk_i
	
	//% Clear has been seen in the slow clock domain.
   always @(posedge sclk_i) begin : CLEAR_SEEN_SLOWCLK_LOGIC
		if (sce_i)
			clear_seen_slowclk <= 0;
		else if (clear_sclk_i)
			clear_seen_slowclk <= 1;
	end

	//// Stuck bit detection

	// The 'maximum' trigger rate is something like 10 MHz, so we actually want stuck bit detection
	// to start kicking in below 5 MHz. Probably more like 2 MHz, which is actually the highest that the
	// scalers can count in any case.


	//// Slow clock domain (detect if a bit is stuck)
	//% Bits are stuck if we have seen a trigger, but no clear.
	always @(posedge sclk_i) begin : STUCK_DETECT_LOGIC
		if (sce_i)
			stuck_detect <= {stuck_detect[STUCK_CYCLES-2:0],!clear_seen_slowclk && slow_clk_had_trig};
	end
	
	//% Bit is stuck if stuck_detect has been high for STUCK_CYCLES
	assign bit_is_stuck = (stuck_detect == {STUCK_CYCLES{1'b1}});

	//// CLOCK BOUNDARY
	//% Module to pass bit_is_stuck back to fclk_i domain
	signal_sync stuck_bit_detect_sync(.clkA(sclk_i), .clkB(fclk_i),.in_clkA(bit_is_stuck), .out_clkB(bit_is_stuck_fastclk_p));

	//// Fast clock domain (toggle the scaler)
	
	//% If a bit is stuck, toggle stuck_fast_clk every cycle
	always @(posedge fclk_i) begin : STUCK_TOGGLE
		if (bit_is_stuck_fastclk_p && sync_i)
			stuck_fast_clk <= 1;
		else
			stuck_fast_clk <= 0;
	end

	//% Edge detect the trigger signal.
	SYNCEDGE #(.LATENCY(0)) scaler_flag_generator(.I(trig_i),.O(trig_posedge_flag),
																 .CLK(fclk_i));
	//% Output is either the flag, or the stuck detection bit.
	always @(posedge fclk_i) begin : SCALER_BIT_LOGIC
		scaler_bit <= trig_posedge_flag | stuck_fast_clk;
	end
	
	//% This is our scaler.
	assign scaler_o = scaler_bit;
endmodule
