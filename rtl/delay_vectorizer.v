`timescale 1ns / 1ps
//% @brief Utility module to combine trigger timing inputs.

`include "trigger_defs.vh"
module delay_vectorizer(
		l4_rf0_pretrigger,
		l4_rf1_pretrigger,
		l4_cpu_pretrigger,
		l4_cal_pretrigger,
		l4_ext_pretrigger,
		pretrigger_vector,
		l4_rf0_delay,
		l4_rf1_delay,
		l4_cpu_delay,
		l4_cal_delay,
		l4_ext_delay,
		delay_vector
    );

	localparam PRETRG_BITS = `PRETRG_BITS;
	localparam DELAY_BITS = `DELAY_BITS;
	localparam NUM_L4 = `SCAL_NUM_L4;
	input [PRETRG_BITS-1:0] l4_rf0_pretrigger;
	input [PRETRG_BITS-1:0] l4_rf1_pretrigger;
	input [PRETRG_BITS-1:0] l4_cpu_pretrigger;
	input [PRETRG_BITS-1:0] l4_cal_pretrigger;
	input [PRETRG_BITS-1:0] l4_ext_pretrigger;
	output [PRETRG_BITS*NUM_L4-1:0] pretrigger_vector;

	assign pretrigger_vector = {l4_ext_pretrigger,l4_cal_pretrigger,l4_cpu_pretrigger,l4_rf1_pretrigger,l4_rf0_pretrigger};

	input [DELAY_BITS-1:0] l4_rf0_delay;
	input [DELAY_BITS-1:0] l4_rf1_delay;
	input [DELAY_BITS-1:0] l4_cpu_delay;
	input [DELAY_BITS-1:0] l4_cal_delay;
	input [DELAY_BITS-1:0] l4_ext_delay;
	output [DELAY_BITS*NUM_L4-1:0] delay_vector;
	assign delay_vector = {l4_ext_delay,l4_cal_delay,l4_cpu_delay,l4_rf1_delay,l4_rf0_delay};

endmodule
