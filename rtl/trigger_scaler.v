`timescale 1ns / 1ps
module trigger_scaler(
		trigger i,
		power_i,
		mask_i,
		
		trig_p_o,
		trig_n_o,
		scaler_o,
		
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
	//% Number of synchronization cycles (min. trigger latency, times 10 ns).
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
	output reg trig_p_o = 0;
	//% Negative-edge synchronous trigger output
	output reg trig_n_o = 0;
	//% Scaler output (with stuck-on detection)
	output scaler_o;
	
	//% Fast clock (100 MHz, 1/2 of this determines trig. granularity)
	input fast_clk_i;
	//% Slow clock (used for stuck-on detection)
	input slow_clk_i;
	//% Very slow clock enable (used for stuck-on detection)
	input slow_ce_i;
	
	//% Input trigger bit. Only one so it pushes into the IOBUF.
	reg trig_bit = 0;

	//% Clear the positive edge path
	wire clear_p = (trig_path_p[ONE_SHOT_CYCLES-1] && !trigger_i);
	//% Clear the negative edge path
	wire clear_n = (trig_path_n[ONE_SHOT_CYCLES-1] && !trigger_i);
	//% Clear the asynchronous elements.
	wire clear = clear_p || clear_n;

	//% Latch a positive edge in the trigger. Clear when ONE_SHOT_CYCLES have occurred.
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
			trig_p_o <= 0;
		end else begin
			// Masking is done here. sync_path_p[SYNC_CYCLES-1] is used
			// for the scaler (it's a nonmasked copy)
			trig_p_o <= (!mask_i && sync_path_p[SYNC_CYCLES-2]);
			sync_path_p <= {sync_path_p[SYNC_CYCLES-2:0],trig_bit};
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
			trig_n_o <= 0;
		end else begin
			trig_n_o <= (!mask_i && sync_path_n[SYNC_CYCLES-2]);
			sync_path_n <= {sync_path_n[SYNC_CYCLES-2:0],trig_bit};
		end
	end

/*
	// Number of stuck-bit detection cycles.
	parameter STUCK_CYCLES = 4;

	// The slow_clk domain needs to know if we've seen a trigger.
	reg trig_p_seen = 0;
	wire trig_p_seen_slow_clk;

	// Now the slow_clk domain needs to tell the fast_clk domain
	// if it wants to know if there are triggers.
	reg slow_clk_had_trig_p = 0;
	wire slow_clk_saw_trig_p;

	always @(posedge fast_clk_i) begin
		if (!slow_clk_saw_trig_p && sync_path_p[SYNC_CYCLES-1])
			trig_p_seen <= 1;
		else
			trig_p_seen <= 0;
	end
	//% Indicate to the slow clock domain that the trigger was high in the + path
	signal_sync trig_p_seen_to_slow_clk(.in_clkA(trig_p_seen),.out_clkB(trig_p_seen_slow_clk),
													.clkA(slow_clk_i),.clkB(fast_clk_i));
	//% Indicate to the slow clock domain that the trigger was high in the - path
	signal_sync slow_clk_trig_p_to_fast_clk(.in_clkA(slow_clk_had_trig_p),.out_clkB(slow_clk_saw_trig_p),
														 .clkA(slow_clk_i),.clkB(fast_clk_i));
*/
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
/*
	// Stuck bit detection.

	always @(posedge slow_clk_i) begin
		if (slow_ce_i)
			slow_clk_had_trig_p <= 0;
		else if (trig_p_seen_slow_clk)
			slow_clk_had_trig_p <= 1;
	end


	wire bit_is_stuck;
	wire bit_is_stuck_fastclk_p;
	reg clear_seen_slowclk = 0;
	always @(posedge slow_clk_i) begin
		if (slow_ce_i)
			clear_seen_slowclk <= 0;
		else if (p_cleared_slowclk || n_cleared_slowclk)
			clear_seen_slowclk <= 1;
	end
	reg [STUCK_CYCLES-1:0] stuck_detect = {STUCK_CYCLES{1'b0}};
	reg stuck_fast_clk = 0;
	always @(posedge slow_clk_i) begin
		if (slow_ce_i)
			stuck_detect <= {stuck_detect[STUCK_CYCLES-2:0],!clear_seen_slowclk && slow_clk_had_trig_p};
	end
	assign bit_is_stuck = (stuck_detect == {STUCK_CYCLES{1'b1}});
	signal_sync stuck_bit_detect_sync(.clkA(slow_clk_i), .clkB(fast_clk_i),.in_clkA(bit_is_stuck), .out_clkB(bit_is_stuck_fastclk_p));
	
	// SCALER OUTPUTS, WITH STUCK ON DETECTION
	always @(posedge fast_clk_i) begin
		if (bit_is_stuck_fastclk_p)
			stuck_fast_clk <= ~stuck_fast_clk;
		else
			stuck_fast_clk <= 0;
	end

	reg scaler_flag_det = 0;
	wire [1:0] edge_p_det = {scaler_flag_det, trig_p_o};
	always @(posedge fast_clk_i) begin
		scaler_flag_det <= trig_p_o;
	end
	
	reg scaler_bit = 0;
	always @(posedge fast_clk_i) begin
		scaler_bit <= (edge_p_det == 2'b01) | stuck_fast_clk;
	end
	assign scaler_o = scaler_bit;
*/
	scaler_generator sc_gen(.trig_i(sync_path_p[SYNC_CYCLES-1]),
									.fclk_i(fast_clk_i),.sclk_i(slow_clk_i),
									.sce_i(slow_ce_i),
									.clear_sclk_i(p_cleared_slowclk || n_cleared_slowclk),
									.scaler_o(scaler_o));
endmodule
