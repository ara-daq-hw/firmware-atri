`timescale 1ns / 1ps
//% @brief atriusb_event_readout Frames the event data for USB output.
module atriusb_event_readout(
	   input rst_req_i,
		output rst_ack_o,
		input [15:0] fifo_dat_i,
		input [15:0] fifo_nwords_i,
		input [1:0] fifo_type_i,
		output [7:0] bridge_dat_o,
		output event_pending_o,
		output event_empty_o,
		input event_ready_i,
		input fifo_empty_i,
		input fifo_clk_i,
		output fifo_rd_o,
		input event_rd_i,
		input frame_done_i,
		output block_done_o
    );

	reg in_rst = 0;

	reg [15:0] bytes_remaining = {16{1'b0}};
	reg [7:0] frame_number = {8{1'b0}};
	
	reg [7:0] bridge_dat_muxed = {8{1'b0}};
	
	// BTYPE_ONLY is BTYPE_FIRST|BTYPE_LAST
	localparam [1:0] BTYPE_FIRST = 2'b01;
	localparam [1:0] BTYPE_MIDDLE = 2'b00;
	localparam [1:0] BTYPE_LAST = 2'b10;
	localparam [1:0] BTYPE_ONLY = 2'b11;	
	reg [1:0] block_type = BTYPE_ONLY;

	
	localparam [6:0] FRAME_START_FIRST = 7'b1000101;   	// 0x45
	localparam [6:0] FRAME_START_MIDDLE = 7'b1000010;    // 0x42
	localparam [6:0] FRAME_START_LAST = 7'b1000110;      // 0x46
	localparam [6:0] FRAME_START_ONLY = 7'b1001111;      // 0x4F
	reg [6:0] frame_header_byte = FRAME_START_ONLY;
	always @(block_type) begin
		case (block_type)
			BTYPE_FIRST: frame_header_byte <= FRAME_START_FIRST;
			BTYPE_MIDDLE: frame_header_byte <= FRAME_START_MIDDLE;
			BTYPE_LAST: frame_header_byte <= FRAME_START_LAST;
			BTYPE_ONLY: frame_header_byte <= FRAME_START_ONLY;
		endcase
	end

	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(8);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] READ_NWORDS = 1;
	localparam [FSM_BITS-1:0] FRAME_START = 2;
	localparam [FSM_BITS-1:0] FRAME_NUMBER = 3;
	localparam [FSM_BITS-1:0] FRAME_REMAINING_LOW = 4;
	localparam [FSM_BITS-1:0] FRAME_REMAINING_HIGH = 5;
	localparam [FSM_BITS-1:0] FRAME_EVENT = 6;
	localparam [FSM_BITS-1:0] FRAME_DONE = 7;
	localparam [FSM_BITS-1:0] FIFO_WAIT_FOR_WORDS = 8;
	reg [FSM_BITS-1:0] state = IDLE;

	// Reset handling. The reset logic is straightforward:
	// synchronize the input request, then assert the acknowledge.
	// Then when the input request (synchronized) goes low, deassert the
	// acknowledge.
	// We hold ourselves in reset so long as "in_rst" is high. Therefore
	// we stay in reset longer than the IRS portion does, but this is fine.
	// NOTE: The FIFO should be reset ONLY by the IRS portion!
	wire rst_req_fifo_clk;
	signal_sync reset_req_sync(.in_clkA(rst_req_i),.clkB(fifo_clk_i),.out_clkB(rst_req_fifo_clk));
	always @(posedge fifo_clk_i) begin
		if (rst_req_fifo_clk && (state == IDLE || state == FRAME_DONE))
			in_rst <= 1;
		else if (!rst_req_fifo_clk)
			in_rst <= 0;
	end
	assign rst_ack_o = in_rst;
			
	reg event_sel_high = 0;
//	reg event_is_ready = 0;
	reg event_first_frame = 0;

	reg [7:0] nwords_for_frame = {8{1'b0}};
	localparam [7:0] MAX_FRAME_WORDS = 8'd254;
	wire [14:0] words_remaining = bytes_remaining[15:1];
	wire [14:0] max_frame_words_extended = {{7{1'b0}},MAX_FRAME_WORDS};
	wire [15:0] nwords_for_frame_extended = {{8{1'b0}}, nwords_for_frame};
	// The minus one here is because the read data count underreports
	// by 2. Why? I have no idea. No need to reset since it begins OK at the beginning of frame.
	always @(posedge fifo_clk_i) begin
		if (state == READ_NWORDS) nwords_for_frame <= MAX_FRAME_WORDS - 2;
		else if (state == FRAME_DONE) begin
			if (words_remaining > max_frame_words_extended)
				nwords_for_frame <= MAX_FRAME_WORDS - 2;
			else if (words_remaining >= 2)
				nwords_for_frame <= words_remaining[7:0] - 2;
			else
				nwords_for_frame <= {8{1'b0}};
		end
	end
	
/*
	always @(posedge fifo_clk_i) begin
		if (event_ready_i) event_is_ready <= 1;
		else if (state == READ_NWORDS) event_is_ready <= 0;
	end
*/
	always @(posedge fifo_clk_i) begin
		if (in_rst) state <= IDLE;
		else begin
			case (state)
				IDLE: if (event_ready_i) state <= READ_NWORDS;
				READ_NWORDS: state <= FIFO_WAIT_FOR_WORDS;
				FIFO_WAIT_FOR_WORDS: 
					if (fifo_nwords_i >= nwords_for_frame_extended) 
						state <= FRAME_START;
				FRAME_START: if (event_rd_i) state <= FRAME_NUMBER;
				FRAME_NUMBER: if (event_rd_i) state <= FRAME_REMAINING_LOW;
				FRAME_REMAINING_LOW: if (event_rd_i) state <= FRAME_REMAINING_HIGH;
				FRAME_REMAINING_HIGH: if (event_rd_i) state <= FRAME_EVENT;
				FRAME_EVENT: if (frame_done_i) state <= FRAME_DONE;
				FRAME_DONE: if (bytes_remaining == {16{1'b0}}) state <= IDLE; else state <= FIFO_WAIT_FOR_WORDS;
				default: state <= IDLE;
			endcase
		end
	end
	always @(posedge fifo_clk_i) begin
		if (state == IDLE || in_rst)
			frame_number <= 0;
		else if (state == FRAME_DONE)
			frame_number <= frame_number + 1;
	end
	assign event_empty_o = (bytes_remaining == {16{1'b0}}) || fifo_empty_i;
	always @(posedge fifo_clk_i) begin
		if (state == FRAME_NUMBER || in_rst)
			event_first_frame <= 0;
		else if (state == READ_NWORDS)
			event_first_frame <= 1;
	end
	always @(posedge fifo_clk_i) begin
		if (state == READ_NWORDS || in_rst)
			event_sel_high <= 0;
		else if (state == FRAME_EVENT && event_rd_i)
			event_sel_high <= ~event_sel_high;
	end	
	always @(posedge fifo_clk_i) begin
		if (state == READ_NWORDS || in_rst)
			bytes_remaining <= {fifo_dat_i[14:0],1'b0}; // upshift by 1
		else if (state == FRAME_EVENT && event_rd_i && !fifo_empty_i && (bytes_remaining != {16{1'b0}}))
			bytes_remaining <= bytes_remaining - 1'b1;
	end
	always @(posedge fifo_clk_i) begin
		if (state == READ_NWORDS || in_rst)
			block_type <= fifo_type_i;
	end
	
	// ASCII capitalization is bit 5.
	wire [6:0] frame_header = {frame_header_byte[6],event_first_frame,frame_header_byte[4:0]};

	always @(*) begin
		if (state == FRAME_START)
			bridge_dat_muxed <= {1'b0, frame_header} ;
		else if (state == FRAME_NUMBER)
			bridge_dat_muxed <= frame_number;
		else if (state == FRAME_REMAINING_LOW)
			bridge_dat_muxed <= bytes_remaining[7:0];
		else if (state == FRAME_REMAINING_HIGH)
			bridge_dat_muxed <= bytes_remaining[15:8];
		else begin
			if (event_sel_high)
				bridge_dat_muxed <= fifo_dat_i[15:8];
			else
				bridge_dat_muxed <= fifo_dat_i[7:0];
		end
	end
	assign fifo_rd_o = (state == READ_NWORDS) || (((state == FRAME_EVENT && event_rd_i && !fifo_empty_i)) && event_sel_high);
	assign bridge_dat_o = bridge_dat_muxed;
	assign event_pending_o = (bytes_remaining != {16{1'b0}}) && !((state == FIFO_WAIT_FOR_WORDS) || (state == FRAME_DONE));
	assign block_done_o = (state == FRAME_DONE && bytes_remaining == {16{1'b0}});
endmodule
