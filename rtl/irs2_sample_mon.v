`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// IRS2 sampling-speed monitor. We monitor the IRS2's sampling speed using
// Xilinx's Digital Clock Manager. This is possibly only for the DDA_EVAL -
// we may be able to use the Spartan-6's built in phase detector to figure
// out the TSA-to-TSAOUT delay.
//
// Basically, we phase shift the TSA clock to its minimum value, and latch TSAOUT 
// on both the rising and falling edges of the phase-shifted clock. We then
// increase the phase shift, looking for a 0->1 transition in the latched value.
// If it occurs on the falling edge, we add 128 to the value. 
//
// Because we're scanning so slowly across the range (~80 ps) there's always
// a possibility that we get a false edge on the falling edge - heck, there
// could be a slight bounce, after all.
//
// This method measures up to 1/256th of the TSA period. The TSA strobe defines
// 64X the sampling period, so if the fixed delays are known, we should be able
// to hold the sampling speed to a quarter of a sample period.
//
//////////////////////////////////////////////////////////////////////////////////
module irs2_sample_mon(
		input clk_i,
		input irs2_tsaout_i,
		output [7:0] irs2_tsa_phase_o,
		input present_i,
		input enable_i,
		output done_o,
		output [35:0] debug_o
    );

	// Clocks
	wire tsa_strobe = clk_i;
	wire tsa_strobe_180;
	wire tsa_strobe_feedback;
	wire tsa_strobe_delayed;
	wire tsa_strobe_delayed_180;

	// Phase detect enable synchronizer.
	// phase_detect_enable is a flag, so we need to be safe about it.
	reg phase_detect_enable = 0;
	wire do_phase_detect;
	flag_sync phase_detect_enable_sync(.clkA(tsa_strobe),.clkB(tsa_strobe_delayed),
													.in_clkA(phase_detect_enable),.out_clkB(do_phase_detect));

	// Phase detect done synchronizer.
	wire phase_detect_done;
	flag_sync phase_detect_done_sync(.clkA(tsa_strobe_delayed),.clkB(tsa_strobe),.in_clkA(do_phase_detect),.out_clkB(phase_detect_done));

	// Phase detections, and previous measurement values
	wire phase_detect_tsaout_P;
	wire phase_detect_tsaout_N;
	reg [1:0] phase_last_P = 2'b00;
	reg [1:0] phase_last_N = 2'b00;
	wire [2:0] phase_edge_P = {phase_last_P, phase_detect_tsaout_P};
	wire [2:0] phase_edge_N = {phase_last_N, phase_detect_tsaout_N};
	
	// Working and finished measurements.
	reg [7:0] working_phase = {8{1'b0}};
	reg [7:0] finished_phase = {8{1'b0}};

	// DCM controls/outputs
	wire [7:0] dcm_status;
	wire dcm_reset;
	wire dcm_is_locked;
	wire phase_shift_done;
	wire phase_shift_enable;
	wire phase_shift_inc_n_dec;
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(17);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] RST_1 = 1;
	localparam [FSM_BITS-1:0] RST_2 = 2;
	localparam [FSM_BITS-1:0] RST_3 = 3;
	localparam [FSM_BITS-1:0] WAIT_LOCK = 4;
	localparam [FSM_BITS-1:0] REWIND = 5;
	localparam [FSM_BITS-1:0] REWIND_WAIT = 6;
	localparam [FSM_BITS-1:0] BEGIN_FIRST = 7;
	localparam [FSM_BITS-1:0] WAIT_FIRST = 8;
	localparam [FSM_BITS-1:0] PS_INC = 9;
	localparam [FSM_BITS-1:0] PS_INC_WAIT = 10;
	localparam [FSM_BITS-1:0] BEGIN_DELAY = 11;
	localparam [FSM_BITS-1:0] WAIT_DELAY = 12;
	localparam [FSM_BITS-1:0] DONE = 13;
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge clk_i) begin
		if (!present_i)
			state <= IDLE;
		else begin
			case (state)
				IDLE: if (enable_i) state <= RST_1;
				RST_1: state <= RST_2;
				RST_2: state <= RST_3;
				RST_3: state <= WAIT_LOCK;
				WAIT_LOCK: if (dcm_is_locked) state <= REWIND;
				REWIND: state <= REWIND_WAIT;
				REWIND_WAIT: if (phase_shift_done) if (dcm_status[0]) state <= BEGIN_FIRST;
															  else state <= REWIND;
				BEGIN_FIRST: state <= WAIT_FIRST;
				WAIT_FIRST: if (phase_detect_done) state <= PS_INC;
				PS_INC: state <= PS_INC_WAIT;
				PS_INC_WAIT: if (phase_shift_done) state <= BEGIN_DELAY;
				BEGIN_DELAY: state <= WAIT_DELAY;
				WAIT_DELAY: if (phase_detect_done) begin
					if (phase_edge_P == 3'b001) state <= DONE;
					else if (phase_edge_N == 3'b001) state <= DONE;
					else if (!dcm_status[0]) state <= PS_INC;
					else state <= REWIND; // sigh, try again
				end
				DONE: state <= IDLE;
			endcase
		end
	end
	
	// DCM: Digital Clock Manager Circuit
   //      Spartan-3
   // Xilinx HDL Language Template, version 12.3

   DCM #(
      .SIM_MODE("SAFE"),  // Simulation: "SAFE" vs. "FAST", see "Synthesis and Simulation Design Guide" for details
      .CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
      .CLKIN_PERIOD(10),  // Specify period of input clock
      .CLKOUT_PHASE_SHIFT("VARIABLE"), // Specify phase shift of NONE, FIXED or VARIABLE
      .CLK_FEEDBACK("1X"),  // Specify clock feedback of NONE, 1X or 2X
      .DESKEW_ADJUST("SOURCE_SYNCHRONOUS"), // SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
                                            //   an integer from 0 to 15
      .DFS_FREQUENCY_MODE("LOW"),  // HIGH or LOW frequency mode for frequency synthesis
      .DLL_FREQUENCY_MODE("LOW"),  // HIGH or LOW frequency mode for DLL
      .DUTY_CYCLE_CORRECTION("TRUE"), // Duty cycle correction, TRUE or FALSE
      .FACTORY_JF(16'hC080),   // FACTORY JF values
      .PHASE_SHIFT(0),     // Amount of fixed phase shift from -255 to 255
      .STARTUP_WAIT("FALSE"),   // Delay configuration DONE until DCM LOCK, TRUE/FALSE
		.CLKFX_MULTIPLY(2),
		.CLKFX_DIVIDE(8)
   ) DCM_inst (
      .CLK0(tsa_strobe_feedback),     // 0 degree DCM CLK output
//		.CLK180(tsa_strobe_180), // 180 degree DCM CLK output
//      .CLK270(CLK270), // 270 degree DCM CLK output
//      .CLK2X(CLK2X),   // 2X DCM CLK output
//      .CLK2X180(CLK2X180), // 2X, 180 degree DCM CLK out
//      .CLK90(CLK90),   // 90 degree DCM CLK output
//      .CLKDV(tsa_strobe),   // Divided DCM CLK out (CLKDV_DIVIDE)
      .CLKFX(tsa_strobe_ps),   // DCM CLK synthesis out (M/D)
      .CLKFX180(tsa_strobe_ps180), // 180 degree CLK synthesis out
      .LOCKED(dcm_is_locked), // DCM LOCK status output
      .PSDONE(phase_shift_done), // Dynamic phase adjust done output
      .CLKFB(tsa_strobe_feedback),   // DCM clock feedback
      .CLKIN(tsa_strobe),   // Clock input (from IBUFG, BUFG or DCM)
      .PSCLK(tsa_strobe),   // Dynamic phase adjust clock input
      .PSEN(phase_shift_enable),     // Dynamic phase adjust enable input
      .PSINCDEC(phase_shift_inc_n_dec), // Dynamic phase adjust increment/decrement
		.STATUS(dcm_status),
      .RST(dcm_reset)        // DCM asynchronous reset input
   );

	BUFG delayed_tsa_strobe_BUFG(.I(tsa_strobe_ps),.O(tsa_strobe_delayed));
	BUFG delayed_tsa_strobe_180_BUFG(.I(tsa_strobe_ps180),.O(tsa_strobe_delayed_180));
	// Phase detection.
	IFDDRRSE phase_detection_ff(.D(irs2_tsaout_i),.CE(do_phase_detect),
										 .C0(tsa_strobe_delayed), .C1(tsa_strobe_delayed_180),
										 .Q0(phase_detect_tsaout_P),
										 .Q1(phase_detect_tsaout_N));
	always @(posedge clk_i) begin
		if (phase_detect_done) begin
			if (state == WAIT_FIRST)
				phase_last_P <= {phase_detect_tsaout_P,phase_detect_tsaout_P};
			else if (state == WAIT_DELAY)
				phase_last_P <= {phase_last_P[0],phase_detect_tsaout_P};
		end
	end
	always @(posedge clk_i) begin
		if (phase_detect_done) begin
			if (state == WAIT_FIRST)
				phase_last_N <= {phase_detect_tsaout_N,phase_detect_tsaout_N};
			else if (state == WAIT_DELAY)
				phase_last_N <= {phase_last_N[0],phase_detect_tsaout_N};
		end
	end
	
	always @(posedge clk_i) begin
		phase_detect_enable <= (state == BEGIN_FIRST || state == BEGIN_DELAY);
	end
	
	assign phase_shift_inc_n_dec = (state == PS_INC);
	assign phase_shift_enable = (state == PS_INC || state == REWIND);
	assign dcm_reset = (state == RST_1 || state == RST_2 || state == RST_3);
	
	always @(posedge clk_i) begin
		if (state == REWIND) begin
			working_phase <= {8{1'b0}};
		end else begin
			if (state == PS_INC) working_phase <= working_phase + 1;
		end
	end
	always @(posedge clk_i) begin
		if (state == DONE) begin
			if (phase_edge_P == 3'b011)
				finished_phase <= working_phase;
			else if (phase_edge_N == 3'b011)
				finished_phase <= working_phase + 128;
		end
	end
	assign done_o = (state == DONE);
	assign irs2_tsa_phase_o = finished_phase;
	assign debug_o[7:0] = working_phase;
	assign debug_o[15:8] = finished_phase;
	assign debug_o[19:16] = state;
	assign debug_o[20] = dcm_reset;
	assign debug_o[21] = phase_shift_inc_n_dec;
	assign debug_o[22] = phase_shift_enable;
	assign debug_o[23] = phase_detect_tsaout_P;
	assign debug_o[24] = phase_detect_tsaout_N;
	assign debug_o[25] = phase_detect_done;
	assign debug_o[26] = phase_shift_done;
	assign debug_o[35:27] = {9{1'b0}};
endmodule
