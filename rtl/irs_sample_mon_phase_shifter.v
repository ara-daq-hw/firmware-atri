	`timescale 1ns / 1ps

`include "wb_interface.vh"
//% @brief Phase shifter for sample monitor. Lives in atri_core, one DCM for all.
module irs_sample_mon_phase_shifter #(
		parameter NUM_DAUGHTERS = 4
		)
	 (
		inout [`WBIF_SIZE-1:0] interface_io,
		input [NUM_DAUGHTERS-1:0] tsa_i,
		input [NUM_DAUGHTERS-1:0] tsaout_i,
		input clk_i,
		input fast_clk_i,
		input rst_i
    );

	localparam MAX_DAUGHTERS = 4;
	localparam [7:0] SHIFT_COUNT_BEGIN_BACK = 8'd001;
	// Super-simple version.
	// We get a TSA from one daughter and use it completely.

	// INTERFACE_INS wb wb_slave RPL clk_i wb_clk_i RPL rst_i wb_rst_i
	wire wb_clk_i;
	wire wb_rst_i;
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
	              .clk_o(wb_clk_i),
	              .rst_o(wb_rst_i),
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
	
	// Shift done, to daughters (to inform them to latch)
	wire ps_shift;
	// Shift all done
	wire ps_complete;
	// Delayed TSA strobe
	wire ps_tsa_delayed;
	// Begin cycle
	wire ps_begin;
	// Phase shift done
	wire phase_shift_done;
	// DCM has locked
	wire dcm_is_locked;
	// DCM status (to sense phase shift limit)
	wire [7:0] dcm_status;
	
	wire [7:0] daughter_dat[MAX_DAUGHTERS-1:0];
	
	assign dat_o = daughter_dat[adr_i[6:5]];
	assign ack_o = cyc_i && stb_i;
	assign err_o = 0;
	assign rty_o = 0;
	
	generate
		genvar i;
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin : DAUGHTER_REGS
			irs_sample_mon_register 
				sample_register(.clk_i(clk_i),.adr_i(adr_i[4:0]),.dat_o(daughter_dat[i]),
									 .tsa_delayed_i(ps_tsa_delayed),
									 .tsaout_i(tsaout_i[i]),
									 .shift_i(ps_shift),
									 .begin_i(ps_begin),
									 .complete_i(ps_complete));
		end
	endgenerate
	
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(16);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] RESET_START = 1;
	localparam [FSM_BITS-1:0] RESET_WAIT = 15;
	localparam [FSM_BITS-1:0] RESET_DONE = 16;
	localparam [FSM_BITS-1:0] WAIT_LOCK = 2;
	localparam [FSM_BITS-1:0] REWIND = 3;
	localparam [FSM_BITS-1:0] REWIND_WAIT = 4;
	localparam [FSM_BITS-1:0] SHIFT_START = 5;
	localparam [FSM_BITS-1:0] SHIFT_WAIT = 6;
	localparam [FSM_BITS-1:0] SHIFT_DONE = 7;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_1 = 8;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_2 = 9;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_3 = 10;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_4 = 11;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_5 = 12;
	localparam [FSM_BITS-1:0] SHIFT_DONE_WAIT_6 = 13;
	localparam [FSM_BITS-1:0] WAIT = 14;
	reg [FSM_BITS-1:0] state = IDLE;

	wire start_reset;
	flag_sync start_reset_flag(.in_clkA(state == RESET_START),.out_clkB(start_reset),
										.clkA(clk_i),.clkB(fast_clk_i));
	reg do_reset = 0;
	reg [1:0] dcm_reset_counter = {2{1'b0}};

	always @(posedge fast_clk_i) begin
		if (start_reset)
			do_reset <= 1;
		else if (dcm_reset_counter == 2'b11)
			do_reset <= 0;
	end
	
	reg tsa_hold = 0;
	always @(posedge fast_clk_i) begin
		tsa_hold <= tsa_i[0];
	end
	always @(posedge fast_clk_i) begin
		if (do_reset && (tsa_i[0] && !tsa_hold))
			dcm_reset_counter <= dcm_reset_counter + 1;
		else if (!do_reset)
			dcm_reset_counter <= {2{1'b0}};
	end
	wire done_reset;
	flag_sync done_reset_flag(.in_clkA(dcm_reset_counter == 2'b11),
									  .out_clkB(done_reset),
									  .clkA(fast_clk_i),.clkB(clk_i));
									  
	reg [7:0] shift_counter = {8{1'b0}};
	always @(posedge clk_i) begin
		if (state == WAIT_LOCK || (state == REWIND_WAIT && shift_counter == SHIFT_COUNT_BEGIN_BACK && phase_shift_done))
			shift_counter <= {8{1'b0}};
		else if (state == SHIFT_DONE_WAIT_6 || state == REWIND)
			shift_counter <= shift_counter + 1;
	end
	

	always @(posedge clk_i) begin
		if (rst_i)
			state <= IDLE;
		else begin
			case (state)
				IDLE: state <= RESET_START;
				RESET_START: state <= RESET_WAIT;
				RESET_WAIT: if (done_reset) state <= WAIT_LOCK;
				WAIT_LOCK: if (dcm_is_locked) state <= REWIND;
				REWIND: state <= REWIND_WAIT;
				REWIND_WAIT: if (phase_shift_done) begin
					if (shift_counter == SHIFT_COUNT_BEGIN_BACK) state <= SHIFT_START;
					else state <= REWIND;
				end
				SHIFT_START: state <= SHIFT_WAIT;
				SHIFT_WAIT: if (phase_shift_done) state <= SHIFT_DONE;
				SHIFT_DONE: state <= SHIFT_DONE_WAIT_1;
				SHIFT_DONE_WAIT_1: state <= SHIFT_DONE_WAIT_2;
				SHIFT_DONE_WAIT_2: state <= SHIFT_DONE_WAIT_3;
				SHIFT_DONE_WAIT_3: state <= SHIFT_DONE_WAIT_4;
				SHIFT_DONE_WAIT_4: state <= SHIFT_DONE_WAIT_5;
				SHIFT_DONE_WAIT_5: state <= SHIFT_DONE_WAIT_6;
				SHIFT_DONE_WAIT_6: if (shift_counter != 8'hFF) state <= SHIFT_START; else state <= WAIT;
				// maybe slow something here...
				WAIT: state <= IDLE;
			endcase
		end
	end

	assign ps_shift = (state == SHIFT_DONE_WAIT_6);
	assign ps_complete = (state == WAIT);
	assign ps_begin = (state == IDLE);

	wire phase_shift_enable = (state == REWIND) || (state == SHIFT_START);
	wire phase_shift_inc_n_dec = (state == SHIFT_START);	

	wire tsa_to_dcm;
	BUFG daughter_one_tsa_to_dcm_buf(.I(tsa_i[0]),.O(tsa_to_dcm));
	
	wire tsa_feed_through_bufg;
	
   DCM #(
      .SIM_MODE("SAFE"),  // Simulation: "SAFE" vs. "FAST", see "Synthesis and Simulation Design Guide" for details
      .CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
      .CLKIN_PERIOD(50),  // Specify period of input clock
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
		.CLKFX_DIVIDE(2)
   ) DCM_inst (
      .CLK0(tsa_strobe_feedback),     // 0 degree DCM CLK output
//		.CLK180(tsa_strobe_180), // 180 degree DCM CLK output
      .CLK270(tsa_strobe_probe), // 270 degree DCM CLK output
//      .CLK2X(CLK2X),   // 2X DCM CLK output
//      .CLK2X180(CLK2X180), // 2X, 180 degree DCM CLK out
//      .CLK90(CLK90),   // 90 degree DCM CLK output
//      .CLKDV(tsa_strobe),   // Divided DCM CLK out (CLKDV_DIVIDE)
//      .CLKFX(tsa_strobe_ps),   // DCM CLK synthesis out (M/D)
 //     .CLKFX180(tsa_strobe_ps180), // 180 degree CLK synthesis out
      .LOCKED(dcm_is_locked), // DCM LOCK status output
      .PSDONE(phase_shift_done), // Dynamic phase adjust done output
      .CLKFB(tsa_feed_through_bufg),   // DCM clock feedback
      .CLKIN(tsa_to_dcm),   // Clock input (from IBUFG, BUFG or DCM)
      .PSCLK(clk_i),   // Dynamic phase adjust clock input
      .PSEN(phase_shift_enable),     // Dynamic phase adjust enable input
      .PSINCDEC(phase_shift_inc_n_dec), // Dynamic phase adjust increment/decrement
		.STATUS(dcm_status),
      .RST(do_reset)        // DCM asynchronous reset input
   );
	
	BUFG feed_BUFG(.I(tsa_strobe_feedback),.O(tsa_feed_through_bufg));
	BUFG delayed_tsa_strobe_BUFG(.I(tsa_strobe_probe),.O(ps_tsa_delayed));
	
endmodule
