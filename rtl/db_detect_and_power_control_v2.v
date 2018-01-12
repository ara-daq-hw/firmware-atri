`timescale 1ns / 1ps

/**
 * @file db_detect_and_power_control.v Contains db_detect_and_power_control module.
 */
 
//% @brief Daughterboard detection and power control (version 2).
//%
//% @gensymbol
//% MODULE db_detect_and_power_control
//% LPORT SENSE inout
//% LPORT space
//% LPORT POWER input
//% LPORT space
//% LPORT CLK input
//% LPORT SCLK input
//% RPORT PRESENT
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% The ARA ATRI daughterboard detection mechanism relies on a single SENSE
//% line per daughterboard (e.g. DDASENSE, TDASENSE). The SENSE line is directly
//% connected to the hot-swap controller's ON pin, and is pulled up weakly on the
//% ATRI motherboard (52.3k) and pulled down stronger (7.5k) on the daughterboards.
//% This means that the SENSE line idles at ~0.4V, which is healthily away from the
//% low end of the threshold (1.26V) and the FPGA's low threshold (0.8V). Without
//% the daughterboard plugged in, the 52.3k pullup idles the line at ~3.3V to 2.8V,
//% well above the high input level of 2.0V. 
//% \n\n
//% Before a daughterboard has been detected, the SENSE line at the FPGA is
//% set to be an input. When a daughterboard is connected, the pulldown will
//% drag the SENSE line down pretty quickly. The input capacitance is ~10 pF,
//% and so after idling at ~3.3V, it should drop to ground in ~75 ns. The FPGA
//% watches for the line going low and staying low for a while (~8 ms nominally).
//% This serves as the indicator that the daughterboard is present.
//% \n\n
//% When software then decides to turn the daughterboard on, the SENSE line is
//% then switched to an output and driven high. This turns on the hot-swap controller.
//% \n\n
//% Periodically (every 8 ms nominally) the FPGA turns SENSE back to an input for 10
//% clock cycles. With a system clock of 40 MHz, this is ~3 time constants (250 ns), 
//% and the input should be at ~0.5V, again, well below the nominal low value. If
//% SENSE is low after 250 ns, it redrives the line high. With a 3 us filter on the
//% ON inputs, this should be easily sufficient for the hot swap controller to ignore
//% it.
module db_detect_and_power_control_v2(
		SENSE_I,
		SENSE_O,
		SENSE_OE,
		CLK,
		SCLK,
		POWER,
		PRESENT,
		UPDATE,
		debug
    );

	//% Determine if we use CLK or SCLK for sensing. For debug. If "SLOW", use SCLK, else use CLK.
	parameter SENSE_SPEED = "SLOW";

	//% Daughterboard's sense line input.
	input SENSE_I;
	//% Daughterboard's sense line output.
	output SENSE_O;
	//% Daughterboard's sense line output enable.
	output SENSE_OE;

	//% System clock.
	input CLK;
	//% Slow clock (period over which presence will be checked, typ. 1 kHz).
	input SCLK;
	//% Power switch for daughterboard.
	input POWER;
	//% Indicates if a daughterboard is present.
	output PRESENT;
	//% Single-cycle flag to indicate that status (power or presence) has changed.
	output UPDATE;		 
	//% Debug output for ChipScope.
	output [7:0] debug;

	//% Number of slow_clock_valids before input considered stable.
	parameter [31:0] SENSE_INPUT_FILTER_MS = 8;
	//% Number of slow_clock_valids between presence checks.
	parameter [31:0] SENSE_CHECK_MS = 8;
	//% Number of clocks to wait after sense line lowered before daughter is considered missing.
	parameter [31:0] SENSE_OUTPUT_WAIT_CLOCKS = 75;
	//% FIXME: should be max(clogb2(SENSE_INPUT_FILTER_MS),clogb2(SENSE_OUTPUT_WAIT_CLOCKS)).
	localparam TIMER_BITS = 6;

	//% If SENSE_SPEED = "SLOW", this is SCLK. Else, this is 1.
	wire slow_clock_valid;
	generate
		if (SENSE_SPEED == "SLOW") begin : slow_clock_SCLK
			assign slow_clock_valid = SCLK;
		end else begin : slow_clk_CLK
			assign slow_clock_valid = 1'b1;
		end
	endgenerate
	
	//% 1 if a daughterboard has been successfully detected.
	reg daughterboard_is_present = 0;
	//% Output enable for SENSE.
	reg sense_output_enable = 0;
	//% Deglitch timing filter and presence detect time filter.
	reg [TIMER_BITS-1:0] timer = {TIMER_BITS{1'b0}};

	/*
	 * There are four bits which essentially form a "state" for the module:
	 * daughterboard_is_present, SENSE, sense_output_enable, POWER.
	 *
	 * if (!daughterboard_is_present && !SENSE): (sense_output_enable = don't care but = 0, POWER = don't care)
	 *    Daughterboard is detected. Count each slow_clock_valid: when timer == SENSE_INPUT_FILTER_MS,
	 *    daughterboard_is_present <= 1;
	 * if (!daughterboard_is_present && SENSE) : (sense_output_enable = don't care but 0, POWER = don't care)
	 *    Reset presence detect timer.
	 * if (daughterboard_is_present && sense_output_enable = 0 && SENSE && !POWER)
	 *    Daughterboard removed, reset presence detect timer.
	 *    daughterboard_is_present <= 0;
	 * if (daughterboard_is_present && sense_output_enable = 0 && !SENSE && !POWER)
	 *    Daughterboard is present and unpowered. Do nothing.
	 * if (daughterboard_is_present && sense_output_enable = 1 && POWER)
    *    Daughterboard is present and powered. Count each slow_clock_valid: when timer == SENSE_CHECK_MS,
    *    sense_output_enable = 0.
	 * if (daughterboard_is_present && sense_output_enable = 0 && POWER && SENSE)
	 *    Daughterboard is present and in a check cycle. Count every clock cycle.
	 *    When timer == SENSE_OUTPUT_WAIT_CLOCKS, if SENSE, daughterboard_is_present <= 0;
	 * if (daughterboard_is_present && sense_output_enable = 0 && POWER && !SENSE)
	 *    Power on requested (or check passed): sense_output_enable <= 1, reset timer.
	 */	

	//% Daughterboard has appeared.
	wire DB_DETECTED = (!daughterboard_is_present && !SENSE_I);
	//% Daughterboard is not present.
	wire DB_NOT_PRESENT = (!daughterboard_is_present && SENSE_I && !POWER);
	//% Daughterboard was removed while unpowered.
	wire DB_COLD_REMOVED = (daughterboard_is_present && !sense_output_enable && SENSE_I && !POWER);
	//% Daughterboard is present and cold.
	wire DB_COLD_PRESENT = (daughterboard_is_present && !sense_output_enable && !SENSE_I && !POWER);
	//% Daughterboard is present and hot.
	wire DB_HOT_PRESENT = (daughterboard_is_present && sense_output_enable && POWER);
	//% Daughterboard is present and a check cycle is occurring.
	wire DB_HOT_CHECK = (daughterboard_is_present && !sense_output_enable && SENSE_I && POWER);
	//% Daughterboard power on is requested, or check cycle has passed.
	wire DB_POWER_ON = (daughterboard_is_present && !sense_output_enable && !SENSE_I && POWER);
	//% Daughterboard was removed while unpowered.
	wire DB_HOT_REMOVED = (!daughterboard_is_present && SENSE_I && POWER);

	always @(posedge CLK) begin : TIMER_LOGIC
		if (DB_NOT_PRESENT || DB_COLD_REMOVED || DB_COLD_PRESENT || DB_POWER_ON || DB_HOT_REMOVED)
			timer <= {TIMER_BITS{1'b0}};
		else if (DB_DETECTED && slow_clock_valid)
			timer <= timer + 1;
		else if (DB_HOT_PRESENT && slow_clock_valid) begin
			if (timer == SENSE_CHECK_MS)
				timer <= {TIMER_BITS{1'b0}};
			else
				timer <= timer + 1;
		end else if (DB_HOT_CHECK)
			timer <= timer + 1;
	end
	
	always @(posedge CLK) begin : DAUGHTERBOARD_PRESENT_LOGIC
		if (DB_DETECTED && slow_clock_valid && timer == SENSE_INPUT_FILTER_MS)
			daughterboard_is_present <= 1;
		else if (DB_COLD_REMOVED)
			daughterboard_is_present <= 0;
		else if (DB_HOT_CHECK && timer == SENSE_OUTPUT_WAIT_CLOCKS)
			daughterboard_is_present <= 0;
	end
	
	always @(posedge CLK) begin : DAUGHTERBOARD_SENSE_LOGIC
		if (DB_POWER_ON)
			sense_output_enable <= 1;
		else if ((DB_HOT_PRESENT && timer == SENSE_CHECK_MS && slow_clock_valid) || (!POWER))
			sense_output_enable <= 0;
	end
	
	//% update storage register. Used to generate flag for UPDATE.
	reg [1:0] update_tmp;
	
	always @(posedge CLK) begin : UPDATE_LOGIC
		update_tmp[1:0] <= {POWER && daughterboard_is_present, daughterboard_is_present};
	end
	
	assign UPDATE = (update_tmp[1] != POWER && daughterboard_is_present) ||
						 (update_tmp[0] != daughterboard_is_present);
	assign SENSE_O = POWER;
	// OEs are all negative logic.
	assign SENSE_OE = ~sense_output_enable;
	
	assign PRESENT = daughterboard_is_present;
	assign debug[0] = daughterboard_is_present;
	assign debug[1] = sense_output_enable;
	assign debug[2] = slow_clock_valid;
	assign debug[3] = SENSE_I;
	assign debug[7:4] = timer;
endmodule
