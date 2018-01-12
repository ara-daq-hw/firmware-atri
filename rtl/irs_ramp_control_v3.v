`timescale 1ns / 1ps
/**
 * @file irs_ramp_control_v3.v Contains irs_ramp_control_v3 module.
 */
 
//% @brief IRS ramp control module.
//%
//% The IRS ramp control module. Right now the parameters are all fixed in firmware.
//% These may be modifiable in the future if we want to do a serious transfer function
//% optimization, although doing it at DC is not equivalent to doing it at AC.
//%
//% FSM logic:
//% @dot
//% digraph G {
//%    IDLE -> CLEAR [ label = "(clear_i || rst_i)" ]
//% 	 CLEAR -> CLEAR_WAIT [ label = "(counter == CLEAR_HIGH_CYCLES)" ]
//%    CLEAR_WAIT -> IDLE [ label = "((counter == CLEAR_LOW_CYCLES) && !rst_i)" ]
//%    IDLE -> RAMP [ label = "(ramp_i && !clear_i && !rst_i)" ]
//%    RAMP -> CLEAR [ label = "(rst_i)" ]
//%    RAMP -> RAMP_WAIT [ label = "(counter == RAMP_HIGH_CYCLES)" ]
//%    RAMP_WAIT -> IDLE [ label = "(counter == RAMP_LOW_CYCLES)" ]
//% 	 RAMP_WAIT -> CLEAR [ label = "(rst_i)" ]
//% }
//% @enddot
//%
//% Timing diagram for a normal ramp (clear, then ramp) is:
//%
//% @drawtiming
//% CLR=0,START=0,RAMP=0,RDEN=0.
//% CLR=1.
//% CLR -tCW> CLR=0.
//% CLR -tCR> RDEN=1.
//% RDEN -tRR> RAMP=1.
//% RAMP -tRS> START=1.
//% START -tSW> START=0.
//% .
//% .
//% .
//% .
//% .
//% RAMP=0.
//% @enddrawtiming
//%
//% The times here are controlled by:
//% t<sub>CW</sub> - Width of the CLR pulse = (clock period)*(1+CLEAR_HIGH_CYCLES)
//% t<sub>CR</sub> - Time from CLR to RDEN = (clock period)*(2+CLEAR_LOW_CYCLES)
//% t<sub>RR</sub> - Time from RDEN to RAMP = (clock period)*(1+RAMP_SETUP_CYCLES)
//% t<sub>RS</sub> - Time from RAMP to START = (clock period)*(RAMP_TO_START)
//% t<sub>SW</sub> - Width of the START pulse = (clock period)*(START_HIGH_CYCLES)
//%
//% The total RAMP width is given by (clock period)*(RAMP_HIGH_CYCLES).
//%
//% The final parameter (RAMP_LOW_CYCLES) is the time from the ramp completion
//% to when the data readout begins. Practically this is the time from RAMP
//% deassertion to SMPALL assertion, and is given by
//% t<sub>RD</sub> = (clock period)*(2+RAMP_LOW_CYCLES).
//%
//% The overall time from RAMP deassertion to data being latched
//% on the bus, however, includes delays in the irs_readout_control module
//% - with RAMP_LOW_CYCLES = 0, SMPALL_SETUP_CYCLES=0, DATA_SETUP_CYCLES=3,
//% CHANNEL_SETUP_CYCLES=0, it works out to be 8 clock cycles. Since, in the
//% readout module, the CH and SMP outputs are 0 and stable for a while previously,
//% the RAMP completion to data latch should be excessively safe. 
module irs_ramp_control_v3(
		input clk_i,							//% System clock.
		input rst_i,							//% Local reset input.
		output rst_ack_o,						//% Reset acknowledge. 
	
		input clear_i,							//% Request that CLR be asserted
		output clear_ack_o,					//% Clear has been asserted.
		
		input ramp_i,							//% Request Wilkinson ramp process
		output ramp_ack_o,					//% Wilkinson ramp has completed.

		output irs_rden_o,					//% IRS "RDEN"
		output irs_start_o,					//% IRS "START" 
		output irs_clr_o,						//% IRS "CLR"
		output irs_ramp_o						//% IRS "RAMP"
    );

	//% General purpose counter. Can handle up to 10 us ramp.
	reg [9:0] counter = {10{1'b0}};

	//% Number of cycles, minus 1, that CLR is asserted.
	localparam [9:0] CLEAR_HIGH_CYCLES = 4;
	//% Number of cycles, minus 1, between CLR deassertion and clear_ack_o.
	localparam [9:0] CLEAR_LOW_CYCLES = 0;
	//% Number of cycles, minus 1, from RDEN assertion to RAMP assertion.
	localparam [9:0] RAMP_SETUP_CYCLES = 0;
	//% Number of cycles that RAMP stays high.
	localparam [9:0] RAMP_HIGH_CYCLES = 750;
	//% Number of cycles between RAMP assertion and START assertion
	localparam [9:0] RAMP_TO_START = 125;
	//% Number of cycles between RAMP deassertion and ramp_ack_o
	localparam [9:0] RAMP_LOW_CYCLES = 50;
	//% Number of cycles that START stays high.
	localparam [9:0] START_HIGH_CYCLES = 620;

	// This means that...
	
	// CLR pulse width = (clock period)*(1 + CLEAR_HIGH_CYCLES)
	// t_(CLR_to_RDEN) = (clock period)*(1 

	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(5);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] CLEAR = 1;
	localparam [FSM_BITS-1:0] CLEAR_WAIT = 2;
	localparam [FSM_BITS-1:0] RDEN = 3;
	localparam [FSM_BITS-1:0] RAMP = 4;
	localparam [FSM_BITS-1:0] RAMP_WAIT = 5;
	reg [FSM_BITS-1:0] state = IDLE;
	
	//% Force into state CLEAR if rst_i is asserted, if not in CLEAR or CLEAR_WAIT.
	wire do_reset = (rst_i && (state != CLEAR && state != CLEAR_WAIT));

	//% Ramp request (ramp_i registered)
	wire ramp_request;
	
	//% Ramp request generator. Latency 1 decouples us from the readout state machine.
	SYNCEDGE #(.LATENCY(1)) ramp_req_gen(.I(ramp_i),.O(ramp_request),.CLK(clk_i));

	
	//% State machine logic.
	always @(posedge clk_i) begin : FSM
		if (do_reset) state <= CLEAR;
		else begin
			case (state)
				IDLE: if (clear_i) state <= CLEAR;
						else if (ramp_request) state <= RDEN;
				CLEAR: if (counter == CLEAR_HIGH_CYCLES) state <= CLEAR_WAIT;
				CLEAR_WAIT: if (counter == CLEAR_LOW_CYCLES && !rst_i) state <= IDLE;
				RDEN: if (counter == RAMP_SETUP_CYCLES) state <= RAMP;
				RAMP: if (counter == RAMP_HIGH_CYCLES) state <= RAMP_WAIT;
				RAMP_WAIT: if (counter == RAMP_LOW_CYCLES) state <= IDLE;
				default: state <= IDLE;
			endcase
		end
	end
	
	//% Counter for each state. By default most of these do absolutely nothing.
	always @(posedge clk_i) begin : COUNTER_LOGIC
		if (state == CLEAR) begin
			if (counter == CLEAR_HIGH_CYCLES) counter <= {10{1'b0}};
			else counter <= counter + 1;
		end else if (state == CLEAR_WAIT) begin
			if (counter == CLEAR_LOW_CYCLES) counter <= {10{1'b0}};
			else counter <= counter + 1;
		end else if (state == RAMP) begin
			if (counter == RAMP_HIGH_CYCLES) counter <= {10{1'b0}};
			else counter <= counter + 1;
		end else if (state == RAMP_WAIT) begin
			if (counter == RAMP_LOW_CYCLES) counter <= {10{1'b0}};
			else counter <= counter + 1;
		end else if (state == RDEN) begin
			if (counter == RAMP_SETUP_CYCLES) counter <= {10{1'b0}};
			else counter <= counter + 1;
		end
	end

	//% IRS ramp output, close to logic.
	(* equivalent_register_removal = "FALSE" *)
	(* KEEP = "YES" *)
	reg irs_ramp = 0;
	//% IRS ramp output, at IOB. (1 cycle delay)
	(* IOB = "TRUE" *)
	reg irs_ramp_iob = 0;
	
	//% IRS start output.
	(* equivalent_register_removal = "FALSE" *)
	(* KEEP = "YES" *)
	reg irs_start = 0;
	//% IRS start output, close to logic.
	(* IOB = "TRUE" *)
	reg irs_start_iob = 0;
	
	//% IRS clear output
	wire irs_clear = (state == CLEAR);
	reg irs_clear_iob = 0;
	
	//% IRS rden output
	(* equivalent_register_removal = "FALSE" *)
	(* KEEP = "YES" *)
	reg irs_rden = 0;
	//% RDEN output at IOB.
	(* IOB = "TRUE" *)
	reg irs_rden_iob;
	
	reg ramp_start = 2'b00;
	reg ramp_end = 0;
	reg start_start = 0;
	reg start_end = 0;
	
	// Flag to begin irs_ramp. 
	always @(posedge clk_i) begin
		if (state == RDEN && counter == RAMP_SETUP_CYCLES) ramp_start <= 1;
		else ramp_start <= 0;
	end
	// Flag to end irs_ramp.
	always @(posedge clk_i) begin
		if (state == RAMP && (counter == RAMP_HIGH_CYCLES - 1)) ramp_end <= 1;
		else ramp_end <= 0;
	end
	
	// Flag to start START.
	generate
		if (RAMP_TO_START > 0) begin : DLY
			always @(posedge clk_i) begin : START
				if (state == RAMP && (counter == RAMP_TO_START - 1)) start_start <= 1;
				else start_start <= 0;
			end
		end else begin : NODLY
			always @(posedge clk_i) begin : START
				if (state == RDEN && counter == RAMP_SETUP_CYCLES) start_start <= 1;
				else start_start <= 0;
			end
		end
		if (RAMP_TO_START + START_HIGH_CYCLES > RAMP_HIGH_CYCLES) begin : TOO_LONG
			// Flag to end start.
			always @(posedge clk_i) begin : START_END
				if (state == RAMP && (counter == RAMP_HIGH_CYCLES - 1)) start_end <= 1;
				else start_end <= 0;
			end
		end else begin : NORMAL
			always @(posedge clk_i) begin : START_END
				if (state == RAMP && (counter == RAMP_TO_START + START_HIGH_CYCLES - 1))
					start_end <= 1;
				else
					start_end <= 0;
			end
		end
	endgenerate
	
	//% RAMP is set after we enter the RAMP state, and cleared on rst_i or after RAMP_HIGH_CYCLES
	always @(posedge clk_i) begin : RAMP_LOGIC
		if (rst_i || ramp_end) irs_ramp <= 0;
		else if (ramp_start) irs_ramp <= 1;
	end
	//% START is 1 after RAMP_TO_START cycles in RAMP and cleared on rst_i or after START_HIGH_CYCLES
	always @(posedge clk_i) begin : START_LOGIC
		if (rst_i || start_end) irs_start <= 0;
		else if (start_start) irs_start <= 1;
	end

	//% RDEN is 1 when we are going to go to RDEN state.
	always @(posedge clk_i) begin : RDEN_LOGIC
		if (do_reset) irs_rden <= 0;
		else if (state == IDLE) begin
			if (ramp_request) irs_rden <= 1;
			else irs_rden <= 0;
		end
	end
			
	/////////////////////////////////////////////////////////////////////////////
	// IRS outputs
	/////////////////////////////////////////////////////////////////////////////
	// IOB packing. These group of 4 are all outputs from the FPGA, so
	// might as well just delay them a bunch more.
	always @(posedge clk_i) begin : IOBS
		irs_ramp_iob <= irs_ramp;
		irs_start_iob <= irs_start;
		irs_clear_iob <= irs_clear;
		irs_rden_iob <= irs_rden;
	end
	assign irs_ramp_o = irs_ramp_iob;
	assign irs_start_o = irs_start_iob;
	assign irs_clr_o = irs_clear_iob;
	assign irs_rden_o = irs_rden_iob;
	/////////////////////////////////////////////////////////////////////////////
	
	/////////////////////////////////////////////////////////////////////////////
	// Acknowledge outputs
	/////////////////////////////////////////////////////////////////////////////
	assign ramp_ack_o = (state == RAMP_WAIT && counter == RAMP_LOW_CYCLES);
	assign clear_ack_o = (state == CLEAR_WAIT && counter == CLEAR_LOW_CYCLES);
	assign rst_ack_o = (rst_i && state == CLEAR_WAIT);
	/////////////////////////////////////////////////////////////////////////////
endmodule
