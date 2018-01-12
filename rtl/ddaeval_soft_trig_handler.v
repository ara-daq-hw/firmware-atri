`timescale 1ns / 1ps

`include "ev_interface.vh"

module ddaeval_soft_trig_handler(
		input clk_i,
		input soft_trig_i,

		output history_req_o,
		input history_ack_i,
		output [8:0] nprev_o,
		input [9:0] block_i,
		
		output [8:0] free_address_o,
		output free_strobe_o,
		input free_ack_i,

		output [8:0] lock_address_o,
		output lock_strobe_o,
		output lock_o,
		input lock_ack_i,

		output [10:0] read_address_o,
		output read_strobe_o,
		output [31:0] event_id_o,
		input read_done_i
    );

	reg [9:0] readout_block = {10{1'b0}};
	reg [31:0] event_id = {32{1'b0}};
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(6);
	localparam	[FSM_BITS-1:0] IDLE = 0;
	localparam	[FSM_BITS-1:0] REQ_BLOCK = 1;
	localparam  [FSM_BITS-1:0] LOCK_BLOCK = 2;
	localparam  [FSM_BITS-1:0] READ_BLOCK = 3;
	localparam	[FSM_BITS-1:0] UNLOCK_BLOCK = 4;
	localparam  [FSM_BITS-1:0] FREE_BLOCK = 5;
	localparam  [FSM_BITS-1:0] INCREMENT_ID = 6;
	reg [FSM_BITS-1:0] state = IDLE;
	
	wire id_increment = (state == IDLE && soft_trig_i);
	
	always @(posedge clk_i) begin
		case (state)
			IDLE: if (soft_trig_i) state <= REQ_BLOCK;
			REQ_BLOCK: if (history_ack_i) state <= LOCK_BLOCK;
			LOCK_BLOCK: if (lock_ack_i) state <= READ_BLOCK;
			READ_BLOCK: if (read_done_i) state <= UNLOCK_BLOCK;
			UNLOCK_BLOCK: if (lock_ack_i) state <= FREE_BLOCK;
			FREE_BLOCK: if (free_ack_i) state <= INCREMENT_ID;
			INCREMENT_ID: state <= IDLE;
		endcase
	end
	wire [31:0] new_event_id;
	// We don't use VALID since the delay from the add issuing and being latched is huge.
	Generic_Pipelined_Adder #(.LATENCY(3),.THROUGHPUT("PARTIAL"),.WIDTH(32)) 
			event_id_adder(.A(event_id),.B(32'd1),.Q(new_event_id),.CI(1'b0),.CLK(clk_i),.CE(1'b1),
							   .ADD(id_increment));
	
	always @(posedge clk_i) begin
		if (history_ack_i)
			readout_block <= block_i;
	end
	reg history_request = 0;
	always @(posedge clk_i) begin
		if (soft_trig_i && state == IDLE)
			history_request <= 1;
		else if (history_ack_i)
			history_request <= 0;
	end

	assign lock_address_o = (state == REQ_BLOCK) ? block_i : readout_block;
	assign read_address_o = {1'b0,readout_block};
	assign free_address_o = readout_block;
	
	assign history_req_o = (history_request || (soft_trig_i && state == IDLE)) && !history_ack_i;
	assign lock_strobe_o = history_ack_i || read_done_i;
	assign read_strobe_o = (lock_ack_i && state == LOCK_BLOCK);
	assign lock_o = (state == REQ_BLOCK);

	assign free_strobe_o = (state == FREE_BLOCK);

	// look up from two cycles prior
	assign nprev_o = 9'h002;
	always @(posedge clk_i) begin
		if (state == INCREMENT_ID)
			event_id <= new_event_id;
	end
	assign event_id_o = event_id;
endmodule
