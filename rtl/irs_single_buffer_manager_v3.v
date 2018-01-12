`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// This is an implementation of an IRS manager. This version is single-buffered,
// and is basically the simplest IRS manager you can have.
//
//////////////////////////////////////////////////////////////////////////////////
module irs_single_buffer_manager_v3(
		input clk_i,
		input rst_i,
		
		// Lock interface.
		// This MUST have a throughput of at least 1 lock/2 cycles.
		// Latency is arbitrary: lock_ack is used if the requestor needs to know.
		input [8:0] lock_address_i,
		input lock_i,
		input lock_strobe_i,
		output lock_ack_o,
		
		// Free interface (unused)
		// This MUST have a throughput of at least 1 free/2 cycles.
		// Latency is arbitrary: free_ack is used if the requestor needs to know.
		input [8:0] free_address_i,
		input free_strobe_i,
		output free_ack_o,
		
		// There is no free block interface since it's a single-buffered IRS
		// manager. We'll add that later.
		
		// If 1, indicates that the IRS is not
		// currently writing.
		output irs_pause_o,
		
		output [7:0] debug_o
    );
	
	// This parameter determines the number of cycles that the IRS continues
	// sampling for after a lock request with no remaining buffers (here,
	// this is single buffered, so after a lock request, we wait POST_LOCK_CYCLES
	// and lock the IRS).
	localparam POST_LOCK_CYCLES = 100;

	reg locking_buffer = 0;
	reg locked_buffer = 0;
	reg [8:0] locked_block_counter = 0;
	reg lock_acknowledge = 0;
	reg [7:0] lock_wait_counter = {8{1'b0}};

	// Modified to handle the counter being incremented/decremented by the
	// lock interface OR the free interface. Since lock_i gets tied to 1
	// if the free interface is used, this should get optimized away.
	always @(posedge clk_i) begin
		if (rst_i)
			locked_block_counter <= {9{1'b0}};
		else begin
			if ((lock_strobe_i && lock_i) && (locked_block_counter != {9{1'b1}}))
				locked_block_counter <= locked_block_counter + 1;
			else if (((lock_strobe_i && !lock_i) || (free_strobe_i)) && (locked_block_counter != {9{1'b0}}))
				locked_block_counter <= locked_block_counter - 1;
		end
	end
	
	always @(posedge clk_i) begin
		lock_acknowledge <= lock_strobe_i;
	end

	always @(posedge clk_i) begin
		if (lock_wait_counter == POST_LOCK_CYCLES || rst_i)
			locking_buffer <= 0;
		else if (lock_strobe_i && lock_i)
			locking_buffer <= 1;
	end

	always @(posedge clk_i) begin
		if (locked_block_counter == 0 || rst_i)
			locked_buffer <= 0;
		else if (locking_buffer && lock_wait_counter == POST_LOCK_CYCLES)
			locked_buffer <= 1;
	end

	always @(posedge clk_i) begin
		if (rst_i || !locking_buffer)
			lock_wait_counter <= {8{1'b0}};
		else if (locking_buffer)
			lock_wait_counter <= lock_wait_counter + 1;
	end

	// Ack the free interface.
	reg free_ack = 0;
	always @(posedge clk_i) begin
		free_ack <= free_strobe_i;
	end

	assign lock_ack_o = lock_acknowledge;
	assign irs_pause_o = locked_buffer;
	assign free_ack_o = free_ack;

	assign debug_o = locked_block_counter;
endmodule
