`timescale 1ns / 1ps
//% @brief atriusb_event_readout. Simplified event readout. Just shoves data out the FX2.
module atriusb_event_readout_v2(
		// FIFO interface.
		input phy_clk_i,
	   input rst_req_i,
		output rst_ack_o,
		input irs_clk_i,
		input [15:0] fifo_dat_i,
		output [15:0] fifo_nwords_o,
		input fifo_wr_i,
		output fifo_full_o,
		
		// Bridge interface.
		output [7:0] bridge_dat_o,
		input bridge_rd_i,
		output event_pending_o,
		input event_pause_i,
		output event_done_o,
		
		output [26:0] debug_o
    );
	
	parameter EVENT_FIFO = "LARGE";
	
	// FIFO. Monumentally huge. Might even chain it with another FIFO half the size.
	// This FIFO is a standard FIFO, so there's a 1 cycle latency from read to data.
	wire [16:0] wr_data_count;
	wire [17:0] rd_data_count;
	assign rd_data_count[0] = 0;
	wire fifo_empty;
	wire fifo_read;
	wire [7:0] fifo_data_out;
	wire reset_flag_clk_i;
	reg [15:0] fifo_nwords = {16{1'b0}};
	generate
		if (EVENT_FIFO == "LARGE") begin : LG
			// 128x1024.
			event_fifo_large fifo(.din(fifo_dat_i),.wr_data_count(wr_data_count),.wr_en(fifo_wr_i),
										 .wr_clk(irs_clk_i),.full(fifo_full_o),
										 .dout(fifo_data_out),.rd_en(fifo_read),
										 .rst(reset_flag_clk_i),.rd_clk(phy_clk_i),
										 .rd_data_count(rd_data_count[17:1]),.empty(fifo_empty));
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
		end
	endgenerate

	always @(posedge irs_clk_i) begin
		if (!wr_data_count[16]) fifo_nwords <= {16{1'b1}};
		else fifo_nwords <= ~wr_data_count;
	end

	reg bridge_rd_delayed = 0;
	always @(posedge phy_clk_i) begin
		bridge_rd_delayed <= bridge_rd_i;
	end
	// Reset handling.
	wire reset_clk_i;
	reg reset_ack = 0;
	signal_sync reset_synchronizer(.in_clkA(rst_req_i),.out_clkB(reset_clk_i),.clkA(irs_clk_i),.clkB(phy_clk_i));
	SYNCEDGE #(.EDGE("RISING"),.LATENCY(0)) reset_flag(.I(reset_clk_i),.O(reset_flag_clk_i),.CLK(phy_clk_i));
	always @(posedge phy_clk_i) begin
		if (reset_flag_clk_i) reset_ack <= 1;
		else if (reset_ack && !reset_clk_i) reset_ack <= 0;
	end
	signal_sync reset_ack_synchronizer(.in_clkA(reset_ack),.out_clkB(rst_ack_o),.clkA(phy_clk_i),.clkB(irs_clk_i));
	
	// wr_data_count is a count of the number of words to read. We want the PicoBlaze
	// to have a count of the number of words available. If there's less than
	// 65536 words written, we just report 65536 words available. If there's more,
	// we just flip the bits.
	assign fifo_nwords_o = fifo_nwords;

	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(15);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] READ_START = 1;   		 // RD_EN goes high here...
	localparam [FSM_BITS-1:0] READ_HEADER = 2;  		 // Data shows up on the output of the FIFO
	localparam [FSM_BITS-1:0] READ_HEADER_LOW = 3;   // Read low byte.
	localparam [FSM_BITS-1:0] READ_HEADER_WAIT = 4;  // Wait, in case empty after READ_HEADER 
	localparam [FSM_BITS-1:0] READ_NWORDS = 5;  		 // Data shows up on the output of the FIFO
	localparam [FSM_BITS-1:0] READ_NWORDS_LOW = 6;   // Read high byte.
	localparam [FSM_BITS-1:0] WAIT_NWORDS = 7;		 // Wait a moment for the check operation to complete.
	localparam [FSM_BITS-1:0] CHECK_NWORDS = 8;		 // Check to see if enough words are available
	localparam [FSM_BITS-1:0] WRITE_HEADER = 9;		 // Write the header (if not written already)
	localparam [FSM_BITS-1:0] WRITE_HEADER_LOW = 10; // Write low byte
	localparam [FSM_BITS-1:0] WRITE_NWORDS = 11;      // Write number of words (if not written already)
	localparam [FSM_BITS-1:0] WRITE_NWORDS_LOW = 12 ; // Write low number of words.
	localparam [FSM_BITS-1:0] WRITE = 13;				 // Write data.
	localparam [FSM_BITS-1:0] WRITE_FIRST = 14;		// After header is written, this is the entry path for 2nd write
	localparam [FSM_BITS-1:0] END = 15;
	reg [FSM_BITS-1:0] state = IDLE;

	// First sequence is a bit odd:
	// We read 2 words from the FIFO at first: the header, and number of words
	// That's done by asserting RD in READ_START. Then at READ_HEADER, the header
	// data can be latched. In READ_HEADER, if the FIFO is empty, we wait until
	// it isn't (RD is asserted in READ_HEADER if fifo_empty is not asserted).
	// Then in READ_NWORDS, the number of words can be latched.
	// We then wait until either the number of words in the event OR at least
	// 1024 words are available (we know that we will not be able to stream more
	// than 1024 words). In check_nwords, event_pending_o is asserted if words_available
	// is asserted. Then when bridge_rd_i is asserted (indicating that a transfer is about
	// to begin, we transition to WRITE_HEADER at first. RD is asserted in CHECK_NWORDS
	// if bridge_rd_i is asserted and header_written is asserted.
	// In WRITE_HEADER we place the header on the output, then the number of words.
	// In WRITE_NWORDS we assert RD, and then transition to WRITE.
	// In WRITE, when we hit the last word to write, we move to END, and complete.
	// Otherwise we just wait for bridge_rd_i to lower (indicating that this is the last
	// transfer before the FIFO fills) and then go to CHECK_NWORDS to wait for the next
	// chunk of data to arrive.
	assign event_pending_o = (words_available && ((state == CHECK_NWORDS) ||
										(state == WRITE_HEADER) || (state == WRITE_NWORDS) ||
										(state == WRITE) || (state == WRITE_FIRST)));

	wire block_complete = (nwords_remaining == 0);
	reg block_complete_flag = 0;
	always @(posedge phy_clk_i) begin
	   if (((state == WRITE || state == WRITE_NWORDS_LOW) && bridge_rd_i) && (nwords_remaining == 1))
			block_complete_flag <= 1;
		else
			block_complete_flag <= 0;
	end
	reg block_complete_delayed = 0;
	always @(posedge phy_clk_i) begin
		block_complete_delayed <= block_complete;
	end
	reg frd = 0;
	always @(posedge phy_clk_i) begin
		if (reset_clk_i || (state == READ_NWORDS_LOW || state == CHECK_NWORDS))
		   frd <= 0;
		else if ((state == IDLE && !fifo_empty) || (state == WRITE_NWORDS || state == WRITE_FIRST))
    		frd <= 1;
	end
	reg bridge_check = 0;
	always @(posedge phy_clk_i) begin
		if ((state == WRITE_FIRST) || (state == WRITE) || (state == WRITE_NWORDS_LOW))
			bridge_check <= 1;
		else
			bridge_check <= 0;
	end
/*	always @(*) begin
		case (state)
			// Don't read at IDLE, END, WRITE_HEADER, or WAIT_NWORDS.
			IDLE,END,WRITE_HEADER,WAIT_NWORDS: frd <= 0;
			// At READ_START, fifo is guaranteed to not be empty, and have 2 words.
			// At READ_NWORDS, fifo is guaranteed to have 1 more byte.
			READ_START,READ_HEADER,READ_NWORDS: frd <= 1;
			// At READ_HEADER_LOW, if !fifo_empty, issue a read.
			READ_HEADER_LOW,READ_HEADER_WAIT: frd <= !fifo_empty;
			// At WRITE_NWORDS_LOW, we read, since there's data available.
			WRITE_NWORDS_LOW: frd <= 1;
			// We don't read at CHECK_NWORDS or WRITE_FIRST.
			CHECK_NWORDS, WRITE_FIRST: frd <= 0;
			WRITE: frd <= !(block_complete || (!bridge_rd_i));
			default: frd <= 0;
		endcase
	end
*/
	assign fifo_read = frd && (bridge_rd_i || !bridge_check) && !block_complete_flag && !fifo_empty;
		
	// We stay in reset until we clearly see the other side
	// pull out of reset. Then we can start up. The FIFO only
	// gets reset on the rising edge of reset_clk_i, though (which also
	// starts the ack back to the IRS clock domain) so the IRS-side
	// can start writing immediately when they pull out of reset. We
	// wait a little bit (2 clocks).
	always @(posedge phy_clk_i) begin
		if (reset_clk_i) state <= IDLE;
		else case (state)
			IDLE: if (!fifo_empty) state <= READ_START;
			READ_START: state <= READ_HEADER;
			READ_HEADER: state <= READ_HEADER_LOW;
			READ_HEADER_LOW: if (fifo_empty) state <= READ_HEADER_WAIT; else state <= READ_NWORDS;
			READ_HEADER_WAIT: if (!fifo_empty) state <= READ_NWORDS;
			READ_NWORDS: state <= READ_NWORDS_LOW;
			READ_NWORDS_LOW: state <= WAIT_NWORDS;
			WAIT_NWORDS: state <= CHECK_NWORDS;
			CHECK_NWORDS: if (words_available && bridge_rd_i) begin	
				if (header_written) state <= WRITE_FIRST;
				else state <= WRITE_HEADER;
			end
			WRITE_HEADER: state <= WRITE_HEADER_LOW;
			WRITE_HEADER_LOW: state <= WRITE_NWORDS;
			WRITE_NWORDS: state <= WRITE_NWORDS_LOW;
			WRITE_NWORDS_LOW: state <= WRITE;
			WRITE_FIRST: state <= WRITE;
			WRITE: if (block_complete) state <= END; 
				    else if (!bridge_rd_i) state <= CHECK_NWORDS;
			END: state <= IDLE;
		endcase
	end

	assign event_done_o = (state == END);
	
	// Demux the data that we have while waiting.
	// Then we only need to mux 2 of them on the fly.
	reg [7:0] preload_data = {8{1'b0}};
	always @(posedge phy_clk_i) begin
		if (state == CHECK_NWORDS) begin 
			if (!header_written)
				preload_data <= header[15:8];
			else
				preload_data <= first_data_store;
		end
		else if (state == WRITE_HEADER) preload_data <= header[7:0];
		else if (state == WRITE_HEADER_LOW) preload_data <= nwords[15:8];
		else if (state == WRITE_NWORDS) preload_data <= nwords[7:0];
	end
	
	assign bridge_dat_o = (state == WRITE) ? fifo_data_out : preload_data;
	
	reg words_available = 0;
	always @(posedge phy_clk_i) begin
		if (nwords_remaining < 2048)
			words_available <= !(rd_data_count < nwords_remaining);
		else
			words_available <= !(rd_data_count < 2048);
	end
	
	reg header_written = 0;
	always @(posedge phy_clk_i) begin
		if (state == IDLE) header_written <= 0;
		else if (state == WRITE_HEADER) header_written <= 1;
	end
	reg state_was_write = 0;
	always @(posedge phy_clk_i) begin
		state_was_write <= (state == WRITE);
	end

	// This holds over the first data, because we pipeline the output.
	reg [7:0] temp_data_store = {8{1'b0}};
	reg [7:0] first_data_store = {8{1'b0}};
	always @(posedge phy_clk_i) begin
		temp_data_store <= fifo_data_out;
		if (state_was_write && bridge_rd_delayed) first_data_store <= temp_data_store;
	end
	
	reg [15:0] header = {16{1'b0}};
	reg [16:0] nwords = {17{1'b0}};
	reg [16:0] nwords_remaining = {17{1'b0}};
	always @(posedge phy_clk_i) begin
		if (state == READ_HEADER) header[15:8] <= fifo_data_out;
		if (state == READ_HEADER_LOW) header[7:0] <= fifo_data_out;
	end
	always @(posedge phy_clk_i) begin
		if (state == READ_NWORDS) nwords[15:8] <= fifo_data_out;
		if (state == READ_NWORDS_LOW) nwords[7:0] <= fifo_data_out;
	end
	always @(posedge phy_clk_i) begin
		if (reset_flag_clk_i) nwords_remaining <= {17{1'b0}};
		else if (state == READ_NWORDS_LOW) nwords_remaining <= {nwords[15:8],fifo_data_out,1'b0};
		else if ((state == WRITE || state == WRITE_NWORDS_LOW) && bridge_rd_i) nwords_remaining <= nwords_remaining - 1;
	end
	assign debug_o[3:0] = state;
	assign debug_o[4] = fifo_empty;
	assign debug_o[5] = words_available;
	assign debug_o[6] = header_written;
	assign debug_o[7] = bridge_rd_delayed;
	assign debug_o[8] = block_complete;
	assign debug_o[9 +: 17] = nwords_remaining; 	 	 	 
endmodule
