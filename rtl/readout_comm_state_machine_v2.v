`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Readout communication state machine, version 2.
//
// The previous state machine could get blocked for longer than 1 cycle when
// freeing a block, which would cause it to skip getting blocks from the history
// buffer.
//
// This one splits all three actions, with mini-fifos connecting them.
// When a trigger comes in, it requests a block from the history buffer, and when
// the history buffer acks it, it holds it pending.
//
// The lock interface looks at the history pending and a pending free block. When
// the history FIFO is empty (which it will be every other cycle since it has a
// max throughput of 1 block/2 cycles) then if there is a pending free block,
// we unlock it.
//
// The free interface receives "readout_done"s from the readout queue, and waits
// for the lock interface to unlock them. Then we free them from the block manager.
//
//////////////////////////////////////////////////////////////////////////////////
module readout_comm_state_machine_v2(
		clk,
		reset,
		readout_delay,
		trigger_processed,
		full_triggers,
		nprev_i_to_history_buffer,
		req_o_to_history_buffer,
		history_ack_i,
		block_o_from_history_buffer,
		lock_address_to_block_manager,
		lock_to_block_manager,
		unlock_to_block_manager, //LM added to allow simultaneous lock and unlock
		lock_strobe_to_block_manager,
		lock_ack_i,
		free_address_to_block_manager,
		free_strobe_to_block_manager,
		free_ack_i,
		register_timestamp_from_time_stamping,
		read_address_to_readout_queue,
		wea_to_readout_queue,
		readout_done,
		free_address_from_readout_queue,
		readout_ack_o
    );

	// whatever, this is 
	parameter n_triggers = 3;
	localparam TRIGGER_WIDTH = n_triggers + 1;
	//% Number of bits in a block
	localparam BLOCK_WIDTH = 9;
	//% Number of bits in the history buffer's depth (by coincidence same as block width)
	localparam HISTORY_WIDTH = 9;
	//% Registered timestamp
	localparam TIMESTAMP_WIDTH = 15;
	//% Number of bits to readout queue.
	localparam READOUT_WIDTH = TIMESTAMP_WIDTH + BLOCK_WIDTH + TRIGGER_WIDTH;

	input clk;
	input reset;
	input [BLOCK_WIDTH-1:0] readout_delay;
	input trigger_processed;
	input [TRIGGER_WIDTH-1:0] full_triggers;
	output [HISTORY_WIDTH-1:0] nprev_i_to_history_buffer;
	output req_o_to_history_buffer;
	input history_ack_i;
	input [BLOCK_WIDTH-1:0] block_o_from_history_buffer;
	output [BLOCK_WIDTH-1:0] lock_address_to_block_manager;
	output lock_to_block_manager;
	output unlock_to_block_manager; //LM added - see above
	output lock_strobe_to_block_manager;
	input lock_ack_i;
	output [BLOCK_WIDTH-1:0] free_address_to_block_manager;
	output free_strobe_to_block_manager;
	input free_ack_i;
	input [TIMESTAMP_WIDTH-1:0] register_timestamp_from_time_stamping;

	output [READOUT_WIDTH-1:0] read_address_to_readout_queue;
	output wea_to_readout_queue;
	input readout_done;
	input [BLOCK_WIDTH-1:0] free_address_from_readout_queue;
	output readout_ack_o;
	
	assign nprev_i_to_history_buffer = readout_delay;
	assign req_o_to_history_buffer = trigger_processed;

	wire free_unlock_ack;

	// process here is:
	// 1: history_ack_i = 1 comes in, we latch value and set a pending
	// 2: history_ack_i = 0 (can't be 1 twice), and history_lock_ack should be 1 (always has priority)
	// 3: history_ack_i = 1 (repeat from step 1)

	// We have to be a little careful. lock_pending gets delayed by 1 clock.
	// By the time the ack comes back, history_ack_i is asserted again. So what we need to do
	// is make the lock_strobe output be:
	// (lock_pending && !history_lock_ack)
	
	reg [BLOCK_WIDTH-1:0] lock_pending_block = {BLOCK_WIDTH{1'b0}};
	reg lock_pending = 0;
	wire history_lock_ack;
	wire history_lock_strobe = (lock_pending && !history_lock_ack);
	always @(posedge clk) begin
		if (history_ack_i) begin
			lock_pending_block <= block_o_from_history_buffer;
			lock_pending <= 1;
		end else if (history_lock_ack) begin
			lock_pending <= 0;
		end
	end

	reg [BLOCK_WIDTH-1:0] readout_pending_block = {BLOCK_WIDTH{1'b0}};
	reg [TRIGGER_WIDTH-1:0] readout_pending_triggers = {TRIGGER_WIDTH{1'b0}};
	always @(posedge clk) begin
		readout_pending_triggers <= full_triggers;
	end
	wire [TIMESTAMP_WIDTH-1:0] readout_pending_timestamp = (register_timestamp_from_time_stamping - {{6{1'b0}},readout_delay});
	assign read_address_to_readout_queue = {readout_pending_timestamp, readout_pending_triggers, readout_pending_block};
	reg readout_pending = 0;
	always @(posedge clk) begin
		if (history_ack_i)
			readout_pending_block <= block_o_from_history_buffer;
	end
	always @(posedge clk) begin
		if (readout_pending)
			readout_pending <= 0;
		else if (history_ack_i)
			readout_pending <= 1;
	end
	
	assign wea_to_readout_queue = readout_pending;
	
	// The freeing interface has a state machine, since it does two things
	// and the delay in the second isn't always the same.
	localparam FSM_BITS = 2;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] UNLOCK = 1;
	localparam [FSM_BITS-1:0] FREE = 2;
	localparam [FSM_BITS-1:0] ACK = 3;
	reg [FSM_BITS-1:0] free_state = IDLE;
	always @(posedge clk) begin
		if (reset) free_state <= IDLE;
		else begin
			case (free_state)
				IDLE: if (readout_done) free_state <= UNLOCK;
				UNLOCK: if (free_unlock_ack) free_state <= FREE;
				FREE: if (free_ack_i) free_state <= ACK;
				ACK: free_state <= IDLE;
				default: free_state <= IDLE;
			endcase
		end
	end
	wire free_lock_strobe = (free_state == UNLOCK) && !free_unlock_ack;
	assign free_strobe_to_block_manager = (free_state == FREE) && !free_ack_i;
	reg [BLOCK_WIDTH-1:0] free_address_pending = {BLOCK_WIDTH{1'b0}};
	always @(posedge clk) begin
		if (readout_done)
			free_address_pending <= free_address_from_readout_queue;
	end

	assign free_address_to_block_manager = free_address_pending;
	assign readout_ack_o = (free_state == ACK);

	assign unlock_to_block_manager = (free_lock_strobe);//LM added - see above
	
	// Multiplex the lock interface.
	assign lock_to_block_manager = (history_lock_strobe);
	assign lock_strobe_to_block_manager = (history_lock_strobe || free_lock_strobe);
	assign lock_address_to_block_manager = (history_lock_strobe) ? 
		lock_pending_block : free_address_from_readout_queue;

	// Demultiplex the lock interface's acknowledge. The lock interface always has a 1-cycle
	// delay. 
	reg lock_strobe_was_lock = 0;
	always @(posedge clk) begin
		if (lock_strobe_to_block_manager)
			lock_strobe_was_lock <= lock_to_block_manager;
	end
	assign history_lock_ack = lock_strobe_was_lock && lock_ack_i;
	assign free_unlock_ack = lock_ack_i && !lock_strobe_was_lock;

endmodule
