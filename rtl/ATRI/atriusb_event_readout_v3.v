`timescale 1ns / 1ps
//% @brief atriusb_event_readout. Simplified event readout. Just shoves data out the FX2.
//% The V3 version of the module registers bridge_rd_i, storing 2 extra bytes of data.
module atriusb_event_readout_v3(
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
		
		output [35:0] debug_o
    );
	
	parameter EVENT_FIFO = "LARGE";

///////////////////////////////////////////////////////////
// SIGNALS
///////////////////////////////////////////////////////////

	// Latched version of bridge_rd_i. 1 cycle delayed.
	reg bridge_read = 0;
	// Number of words to read. Bytes 2 and 3 (starting from 0).
	reg [16:0] nwords = {17{1'b0}};
	// Actually number of bytes remaining to read from FIFO.
	reg [16:0] nwords_remaining = {17{1'b0}};

// FIFO SIGNALS

	// Number of words written into the FIFO.
	wire [16:0] wr_data_count;
	// Number of *bytes* available to read in FIFO. Shifted up from the FIFO output.
	wire [17:0] rd_data_count;
	// Bit 0 is always *1* here.
	assign rd_data_count[0] = 1;
	// FIFO is empty
	wire fifo_empty;
	// Read from FIFO
	wire fifo_read;
	// Data output from FIFO
	wire [7:0] fifo_data_out;
	// Reset flag, in the PHY clk domain.
	wire reset_flag_clk_i;
	// Number of words available to write (to pass back to IRS).
	reg [15:0] fifo_nwords = {16{1'b0}};

/// RESET SIGNALS

	// Reset, in the PHY clk domain.
	wire reset_clk_i;
	// Acknowledge, passed back to IRS clock domain.
	reg reset_ack = 0;

/// CONTROL SIGNALS

	// Temporary data storage for the header, and later the last two words read.
	// when the FIFO filled.
	reg [15:0] tmp_data_storage = {16{1'b0}};
	// Event is ready, and pending USB readout.
	reg ev_pending = 0;
	// Block is complete.
	wire block_complete = (nwords_remaining == 0);
	// Flag indicating block is complete.
	reg block_complete_flag = 0;
	// Registered FIFO read.
	reg frd = 0;

	// Register bridge read. It comes from the edge of the chip
	// (through event full) so it takes a long time to get here. Like, nanoseconds.
	always @(posedge phy_clk_i) begin
		bridge_read <= bridge_rd_i;
	end
	
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


/// RESET MODULES

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

// STATE MACHINE

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
	localparam [FSM_BITS-1:0] WRITE_FIRST = 9;		 // Write the header or first stored byte
	localparam [FSM_BITS-1:0] WRITE_SECOND = 10; 	 // Write the header or second stored byte
	localparam [FSM_BITS-1:0] WRITE_NWORDS = 11;      // Write number of words (if not written already)
	localparam [FSM_BITS-1:0] WRITE_NWORDS_LOW = 12 ; // Write low number of words.
	localparam [FSM_BITS-1:0] WRITE = 13;				 // Write data.
	localparam [FSM_BITS-1:0] END = 14;					 // Block done.
	localparam [FSM_BITS-1:0] WAIT_TO_CHECK = 15;
	reg [FSM_BITS-1:0] state = IDLE;

	// We start off by reading 2 words from the FIFO: header, and number of words.
	
	always @(posedge phy_clk_i) begin : EV_PENDING_LOGIC
		if (reset_clk_i || (state == WRITE && !bridge_read) || block_complete_flag) ev_pending <= 0;
		else if (state == CHECK_NWORDS && words_available) ev_pending <= 1;
	end
	
	assign event_pending_o = ev_pending;

	// FIFO read.
	// bridge_rd_i = 1 bridge_rd = 1 frd = 1 FD=D[0], outbound_data=D[1], fifo_data_out=D[2]
	// bridge_rd_i = 0 bridge_rd = 1 frd = 1 FD=D[1], outbound_data=D[2], fifo_data_out=D[3] (tmp_data_store[15:8])
	// bridge_rd_i = 0 bridge_rd = 0 frd = 1 FD=D[2], outbound_data=D[3], fifo_data_out=D[4] (tmp_data_store[7:0])
	// bridge_rd_i = 0 bridge_rd = 0 frd = 0 FD= X  , outbound_data=X,    fifo_data_out=D[5]
	always @(posedge phy_clk_i) begin
		if (reset_clk_i || (state == READ_NWORDS || state == CHECK_NWORDS) || (state == WRITE && !bridge_read) || block_complete_flag)
		   frd <= 0;
		else if ((state == IDLE && !fifo_empty) || (state == WRITE_NWORDS || (state == WRITE_SECOND && header_written)))
    		frd <= 1;
	end

	always @(posedge phy_clk_i) begin
		if (frd && (state == WRITE || state == WRITE_NWORDS_LOW || (state == WRITE_SECOND && header_written)) && (nwords_remaining==2))
			block_complete_flag <= 1;
		else
			block_complete_flag <= 0;
	end
	reg block_complete_delayed = 0;
	always @(posedge phy_clk_i) begin
		block_complete_delayed <= block_complete;
	end

	assign fifo_read = frd && !fifo_empty;
//	assign fifo_read = frd && (bridge_rd_i || !bridge_check) && !block_complete_flag && !fifo_empty;
		
	reg wait_for_readcount = 0;
	always @(posedge phy_clk_i) begin
		wait_for_readcount <= (state == WAIT_TO_CHECK);
	end
		
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
			// We have to know when to *start*, right away. So we have to use
			// bridge_rd_i here.
			CHECK_NWORDS: if (words_available && bridge_rd_i) state <= WRITE_FIRST;
			WRITE_FIRST: state <= WRITE_SECOND;
			WRITE_SECOND: if (header_written) state <= WRITE; else state <= WRITE_NWORDS;
			WRITE_NWORDS: state <= WRITE_NWORDS_LOW;
			WRITE_NWORDS_LOW: state <= WRITE;
			WRITE: if (block_complete) state <= END; 
				    else if (!bridge_read) state <= WAIT_TO_CHECK;
			END: state <= IDLE;
			// We wait 1 clock cycle, because frd is asserted up through WRITE, AND
			// the read data count has a 1 cycle latency in decrementing. So we 
			// delay ourselves one clock here.
			WAIT_TO_CHECK: if (wait_for_readcount) state <= CHECK_NWORDS;
		endcase
	end

	assign event_done_o = (state == END);
	
	// Demux the data that we have while waiting.
	// Then we only need to mux 2 of them on the fly.
	reg [7:0] preload_data = {8{1'b0}};
	always @(posedge phy_clk_i) begin
		if (state == CHECK_NWORDS) preload_data <= tmp_data_storage[15:8];
		else if (state == WRITE_FIRST) preload_data <= tmp_data_storage[7:0]; 
		else if (state == WRITE_SECOND && !header_written) preload_data <= nwords[15:8];
		else if (state == WRITE_NWORDS) preload_data <= nwords[7:0];
	end
	
	assign bridge_dat_o = (state == WRITE) ? fifo_data_out : preload_data;
	
	reg words_available = 0;
	always @(posedge phy_clk_i) begin
		if (nwords_remaining < 512)
			words_available <= !(rd_data_count < nwords_remaining);
		else
			words_available <= !(rd_data_count < 512);
	end
	
	reg header_written = 0;
	always @(posedge phy_clk_i) begin
		if (state == IDLE) header_written <= 0;
		else if (state == WRITE_NWORDS) header_written <= 1;
	end

	always @(posedge phy_clk_i) begin
		if (state == READ_HEADER) tmp_data_storage[15:8] <= fifo_data_out;
		else if (state == READ_HEADER_LOW) tmp_data_storage[7:0] <= fifo_data_out;
		else if (state == WRITE) begin
			tmp_data_storage[15:8] <= tmp_data_storage[7:0];
			tmp_data_storage[7:0] <= fifo_data_out;
		end
	end

	always @(posedge phy_clk_i) begin
		if (state == READ_NWORDS) nwords[15:8] <= fifo_data_out;
		if (state == READ_NWORDS_LOW) nwords[7:0] <= fifo_data_out;
	end

	always @(posedge phy_clk_i) begin
		if (reset_flag_clk_i) nwords_remaining <= {17{1'b0}};
		else if (state == READ_NWORDS_LOW) nwords_remaining <= {nwords[15:8],fifo_data_out,1'b0};
		else if (frd && (state == WRITE || state == WRITE_NWORDS_LOW || (state == WRITE_SECOND && header_written)))
			nwords_remaining <= nwords_remaining - 1;
	end
	assign debug_o[3:0] = state;
	assign debug_o[4] = frd;
	assign debug_o[5 +: 17] = rd_data_count[17:1]; 	 	 	 
	assign debug_o[35:22] = nwords_remaining[13:0];
endmodule
