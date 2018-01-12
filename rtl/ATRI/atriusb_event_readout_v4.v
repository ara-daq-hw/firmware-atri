`timescale 1ns / 1ps
module atriusb_event_readout_v4(
		input phy_clk_i,
		input rst_req_i,
		output rst_ack_o,
		input irs_clk_i,
		input [15:0] fifo_dat_i,
		output [15:0] fifo_nwords_o,
		input fifo_wr_i,
		output fifo_full_o,

		// v4 bridge interface is simplified, with the 'pushing' direction reversed:
		// that is:
		// 1: we request bridge access
		// 2: when bridge access is granted, we can push up to 512 bytes out the
		//    interface. If we want to access less we assert bridge_end_o.
		//    There is no handshaking between: we *have* to stop at 512 bytes ourselves,
		//    and then rerequest the bridge. The data is *always* the 4th
		//    clock after grant is asserted. Valid is only used for debugging.
		//
		// The v4 bridge then consists of 3 'modules' which can each request access
		// to read or write to the bridge.
		//
		// nwords_remaining *always* decrements when fifo_read is asserted. This guarantees
		// that we can *never* get stuck unless the data does not have the proper header.
		//
		// When we request bridge access, we also read 1 word from the FIFO to 'prime' the
		// data. This is because in the normal case (not when we're writing the header!)
		// we only go from BRIDGE_WAIT->BRIDGE_GRANT->READ_AND_WRITE. So when 'read' goes
		// high in BRIDGE_GRANT, the new data shows up at READ_AND_WRITE... which means
		// we have to *already have data* to WRITE. So we issue the request, *and* read 1
		// word.
		//
		// FIXME: This may cause a problem if the last word is the only word to write! This
		// is not currently a problem as the only frames written have 30 extra and 12 extra
		// words to write past a multiple of 512.
		output [7:0] bridge_dat_o,
		output bridge_valid_o,
		output bridge_request_o,
		input bridge_grant_i,
		output bridge_end_o,
		
		output [34:0] debug_o
    );

	parameter EVENT_FIFO = "LARGE";

	//% Read from FIFO.
	reg fifo_read = 0;

	//% Number of words remaining
	reg [16:0] nwords_remaining = {17{1'b0}};

	//% Frame header is available
	reg frame_header_available = 0;

	//% This is the next to last read.
	reg next_to_last_read = 0;

	//% This is the next to last write.
	reg next_to_last_write = 0;

	//% Transaction counter.
	reg [8:0] transaction_counter = {9{1'b0}};

	//% Demultiplexed data.
	reg [7:0] bridge_data = {8{1'b0}};

	//% Request bridge access.
	reg bridge_req = 0;

	//% Header has been written.
	reg header_written = 0;
	
	//% Frame type.
	reg [7:0] frame_type = {8{1'b0}};
	
	//% Frame number
	reg [7:0] frame_number = {8{1'b0}};
	
	//% Number of words in this transfer.
	reg [15:0] nwords = {16{1'b0}};

	//% Number of words remaining in FIFO (to pass back).
	reg [15:0] fifo_nwords = {16{1'b0}};
	
	//% Write data count, from FIFO.
	wire [16:0] wr_data_count;
	
	//% Read data count, from FIFO.
	wire [17:0] rd_data_count;
	//% Read data count is in shorts, we want it in bytes.
	assign rd_data_count[0] = 0;
	//% Data from FIFO
	wire [7:0] fifo_data_out;

	//% FIFO is empty.
	wire fifo_empty;

	//% Reset in phy_clk domain
	wire reset_clk_i;
	
	//% Reset flag in phy clock domain.
	wire reset_flag_clk_i;
	
	//% Reset acknowledge.
	reg reset_ack = 0;

	//% Flag packet end.
	reg bridge_end = 0;

	//% FIFO not empty
	wire fifo_not_empty;

	//% Words are available to read.
	reg words_available = 0;

	//% The frame is complete.
	reg frame_completed = 0;
	
	//% Increment transaction counter
	reg transaction_counter_increment = 0;
	

/// RESET MODULES

	signal_sync reset_synchronizer(.in_clkA(rst_req_i),.out_clkB(reset_clk_i),.clkA(irs_clk_i),.clkB(phy_clk_i));

	SYNCEDGE #(.EDGE("RISING"),.LATENCY(0)) reset_flag(.I(reset_clk_i),.O(reset_flag_clk_i),.CLK(phy_clk_i));

	always @(posedge phy_clk_i) begin
		if (reset_flag_clk_i) reset_ack <= 1;
		else if (reset_ack && !reset_clk_i) reset_ack <= 0;
	end

	signal_sync reset_ack_synchronizer(.in_clkA(reset_ack),.out_clkB(rst_ack_o),.clkA(phy_clk_i),.clkB(irs_clk_i));

/// FIFO  
	generate
		if (EVENT_FIFO == "LARGE") begin : LG
			// 128x1024.
			event_fifo_large fifo(.din(fifo_dat_i),.wr_data_count(wr_data_count),.wr_en(fifo_wr_i),
										 .wr_clk(irs_clk_i),.full(fifo_full_o),
										 .dout(fifo_data_out),.rd_en(fifo_read),
										 .rst(reset_flag_clk_i),.rd_clk(phy_clk_i),
										 .rd_data_count(rd_data_count[17:1]),.empty(fifo_empty));
			// Generate the number of words remaining in the FIFO. More or less.
			always @(posedge irs_clk_i) begin : LG_REMAIN
				if (!wr_data_count[16]) fifo_nwords <= {16{1'b1}};
				else fifo_nwords <= ~wr_data_count;
			end
		end else begin : MD
			// An LX25 has 52 BRAMs. We sucked up 128 in the full ATRI version, so the medium
			// sized version uses 32. This is likely to use most of the BRAMs on the device.
			// This will generate a 15-bit data count (down from 17-bit).
			event_fifo_medium fifo(.din(fifo_dat_i),.wr_data_count(wr_data_count[14:0]),.wr_en(fifo_wr_i),
										  .wr_clk(irs_clk_i),.full(fifo_full_o),
										  .dout(fifo_data_out),.rd_en(fifo_read),
										  .rst(reset_flag_clk_i),.rd_clk(phy_clk_i),
										  .rd_data_count(rd_data_count[15:1]),.empty(fifo_empty));
			assign rd_data_count[17:16] = {2{1'b0}};
			assign wr_data_count[16:15] = {2{1'b0}};
			always @(posedge irs_clk_i) begin : MD_REMAIN
				fifo_nwords[15] <= 0;
				fifo_nwords[14:0] <= ~wr_data_count[14:0];
			end
		end
	endgenerate
	
	assign fifo_not_empty = !fifo_empty;
	

	localparam FSM_BITS = 5;
	//% Event readout interface is idle.
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% Block is now available. Read asserts on event FIFO.
	localparam [FSM_BITS-1:0] FRAME_AVAILABLE = 1;
	//% First header byte (frame type) is available.
	localparam [FSM_BITS-1:0] FRAME_TYPE = 2;
	//% Second header byte (frame number) is available.
	localparam [FSM_BITS-1:0] FRAME_NUMBER = 3;
	//% Number of bytes remaining, most significant byte.
	localparam [FSM_BITS-1:0] NWORDS_MSB = 4;
	//% Number of bytes remaining, least significant byte.
	localparam [FSM_BITS-1:0] NWORDS_LSB = 5;
	//% Wait for remaining words (entry to loop)
	localparam [FSM_BITS-1:0] WAIT_FOR_DATA = 6;
	//% Request bridge. Also issue 1 read to prime.
	localparam [FSM_BITS-1:0] BRIDGE_REQUEST_AND_READ = 7;
	//% Now wait.
	localparam [FSM_BITS-1:0] BRIDGE_WAIT = 8;
	//% Bridge access is granted. Issue a read if it's not the first branch.
	localparam [FSM_BITS-1:0] BRIDGE_GRANT = 9;
	//% Initial branch which reads frame type/frame number/nwords first.
	localparam [FSM_BITS-1:0] WRITE_FRAME_TYPE  = 10;
	localparam [FSM_BITS-1:0] WRITE_FRAME_NUMBER = 11;
	localparam [FSM_BITS-1:0] WRITE_NWORDS_MSB = 12;
	localparam [FSM_BITS-1:0] READ_AND_WRITE_NWORDS_LSB = 13;
	//% Main branch.
	localparam [FSM_BITS-1:0] READ_AND_WRITE = 14;
	//% Transaction counter has hit 511, or read count done. If more, loop back to WAIT_FOR_DATA.
	localparam [FSM_BITS-1:0] WRITE = 15;
	//% State variable.
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge phy_clk_i) begin
		if (reset_clk_i) state <= IDLE;
		else begin case (state)
				IDLE: if (frame_header_available) state <= FRAME_AVAILABLE;
				FRAME_AVAILABLE: state <= FRAME_TYPE;
				FRAME_TYPE: state <= FRAME_NUMBER;
				FRAME_NUMBER: state <= NWORDS_MSB;
				NWORDS_MSB: state <= NWORDS_LSB;
				NWORDS_LSB: state <= WAIT_FOR_DATA;
				WAIT_FOR_DATA: if (words_available) state <= BRIDGE_REQUEST_AND_READ;
				BRIDGE_REQUEST_AND_READ: state <= BRIDGE_WAIT;
				BRIDGE_WAIT: if (bridge_grant_i) state <= BRIDGE_GRANT;
				BRIDGE_GRANT: if (!header_written) state <= WRITE_FRAME_TYPE;
								else state <= READ_AND_WRITE;
				WRITE_FRAME_TYPE: state <= WRITE_FRAME_NUMBER;
				WRITE_FRAME_NUMBER: state <= WRITE_NWORDS_MSB;
				WRITE_NWORDS_MSB: state <= READ_AND_WRITE_NWORDS_LSB;
				READ_AND_WRITE_NWORDS_LSB: state <= READ_AND_WRITE;
				READ_AND_WRITE: if (next_to_last_write) state <= WRITE;
				WRITE: if (!frame_completed) state <= WAIT_FOR_DATA;
					  else state <= IDLE;
				default: state <= IDLE;
			endcase
		end
	end
	
	//% Determine if enough words are available.
	always @(posedge phy_clk_i) begin
		if (nwords_remaining < 512)
			words_available <= !(rd_data_count < nwords_remaining);
		else
			words_available <= !(rd_data_count < 512);
	end

	//% Determine if enough words are available for a frame header (4)
	always @(posedge phy_clk_i) begin
		frame_header_available <= (rd_data_count > 3) ;
	end
	
	always @(posedge phy_clk_i) begin
		if (rst_req_i) fifo_read <= 0;
		// Go high in FRAME_AVAILABLE, so new data in FRAME_TYPE.
		else if (state == IDLE && frame_header_available) fifo_read <= 1;
		// Go low in NWORDS_LSB, as that's the last one we want.
		else if (state == NWORDS_MSB) fifo_read <= 0;
		// Go high in WRITE_NWORDS_MSB, so new data in READ_AND_WRITE_NWORDS_LSB.
		else if (state == WRITE_NWORDS_MSB) fifo_read <= 1;
		// Go high in BRIDGE_GRANT if we're in the initial branch.
		else if (state == BRIDGE_REQUEST_AND_READ) fifo_read <= 1;
		else if (state == BRIDGE_WAIT) begin
			if (bridge_grant_i && header_written) fifo_read <= 1;
			else fifo_read <= 0;
		end
		// Go low in READ_AND_WRITE_NWORDS_LSB if we're done.
		else if (state == READ_AND_WRITE && next_to_last_read) fifo_read <= 0;
	end

	// Request bridge access at BRIDGE_REQUEST. End bridge access at WRITE.
	always @(posedge phy_clk_i) begin
		if (state == WRITE || reset_clk_i) bridge_req <= 0;
		else if (state == WAIT_FOR_DATA && words_available) bridge_req <= 1;
	end

	// Header is written after we write NWORDS_LSB.
	always @(posedge phy_clk_i) begin
		if (reset_clk_i || state == IDLE) header_written <= 0;
		else if (state == READ_AND_WRITE_NWORDS_LSB) header_written <= 1;
	end
	
	// Read count always goes down when fifo_read is asserted (unless it's NWORDS_LSB).
	// It gets reset to the read count in NWORDS_LSB.
	always @(posedge phy_clk_i) begin
		if (reset_clk_i) nwords_remaining <= {17{1'b0}};
		else if (state == NWORDS_LSB) begin
			nwords_remaining[8:1] <= fifo_data_out;
			nwords_remaining[16:9] <= nwords[15:8];
			nwords_remaining[0] <= 0;
		end else if (fifo_read) begin
			nwords_remaining <= nwords_remaining - 1;
		end
	end
	
	// When next_to_last_write is high, we move to WRITE next cycle
	// (last write).
	always @(posedge phy_clk_i) begin
		next_to_last_write <= ((transaction_counter == 509) ||
									 (nwords_remaining == 1));
	end
	
	// This determines when fifo_read turns off. When next_to_last_read goes off,
	// fifo_read goes off next cycle. This is 1 cycle before next_to_last_write.
	always @(posedge phy_clk_i) begin
		next_to_last_read <= ((transaction_counter == 508) || (nwords_remaining == 2));
	end
	
	// We begin incrementing the transaction counter after BRIDGE_GRANT, so turn it on here.
	always @(posedge phy_clk_i) begin
		if (state == WAIT_FOR_DATA || reset_clk_i) transaction_counter_increment <= 0;
		else if (state == BRIDGE_GRANT) transaction_counter_increment <= 1;
	end
	
	// Increment transaction counter.
	always @(posedge phy_clk_i) begin
		if (reset_clk_i || state == WAIT_FOR_DATA) transaction_counter <= {9{1'b0}};
		else if (transaction_counter_increment)
			transaction_counter <= transaction_counter + 1;
	end
	
	// Grab the frame type, number, nbytes MSB, nbytes LSB
	always @(posedge phy_clk_i) begin
		if (state == FRAME_TYPE) frame_type <= fifo_data_out;
		if (state == FRAME_NUMBER) frame_number <= fifo_data_out;
		if (state == NWORDS_MSB) nwords[15:8] <= fifo_data_out;
		if (state == NWORDS_LSB) nwords[7:0] <= fifo_data_out;
	end

	// Demux the data.
	always @(posedge phy_clk_i) begin
		if (state == BRIDGE_GRANT && !header_written) bridge_data <= frame_type;
		else if (state == WRITE_FRAME_TYPE) bridge_data <= frame_number;
		else if (state == WRITE_FRAME_NUMBER) bridge_data <= nwords[15:8];
		else if (state == WRITE_NWORDS_MSB) bridge_data <= nwords[7:0];
		else bridge_data <= fifo_data_out;
	end

	reg do_bridge_end = 0;
	// Flag packet end.
	always @(posedge phy_clk_i) begin
		do_bridge_end <= (state == WRITE && frame_completed);
	end

	always @(posedge phy_clk_i) begin
		bridge_end <= do_bridge_end;
	end

	// Frame completed. High when nwords_remaining = 0.
	always @(posedge phy_clk_i) begin
		if (state == WAIT_FOR_DATA || state == IDLE || reset_clk_i) frame_completed <= 0;
		else if (nwords_remaining == 1) frame_completed <= 1;
	end

	assign bridge_request_o = bridge_req;
	assign bridge_dat_o = bridge_data;
	assign bridge_valid_o = 0;
	assign bridge_end_o = bridge_end;
	assign fifo_nwords_o = fifo_nwords;

	// Debug. Have 35 bits
	// 4 for state
	// 1 for bridge req
	// 1 for bridge grant
	// 1 for frame_header_available/words_available mux
	// 17 for words remaining
	// 1 for next_to_last_read
	// = 26 total so far
	// 9 for transaction counter
	wire available_mux = (state == IDLE ) ? frame_header_available : words_available;
	
	assign debug_o[3:0] = state;
	assign debug_o[4] = available_mux;
	assign debug_o[5] = bridge_req;
	assign debug_o[6] = bridge_grant_i;
	assign debug_o[7] = next_to_last_read;
	assign debug_o[8] = header_written;
	assign debug_o[9 +: 17] = nwords_remaining;
	assign debug_o[26 +: 9] = transaction_counter;
endmodule
