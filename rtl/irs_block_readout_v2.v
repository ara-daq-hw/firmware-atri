`timescale 1ns / 1ps

`include "ev_interface.vh"

// This is an attempt to include Kael's goofy header stuff, which will probably have to
// be expanded at some point. The "readout_buffer.vhdl" just doesn't work, and it's 10:30 PM.
module irs_block_readout_v2 #(
	parameter [1:0] STACK_NUMBER = 0,
	parameter [5:0] STATION_ID = 0,
	parameter EADDR_WIDTH = 9
)(
		input clk_i,
		input rst_i,
		input [8:0] read_address_i,
		input read_strobe_i,
		input read_remaining_i,
		input read_remaining_strobe_i,

		input [7:0] ch_mask_i,
		input [11:0] wilkcnt_i,

		input [47:0] t0_i,
		input [3:0] trig_pat_i,
		output read_done_o,
		output [9:0] RD,
		output RDEN,
		output [5:0] SMP,
		output SMPALL,
		output [2:0] CH,
		output START,
		output CLR,
		output RAMP,
		input [11:0] DAT,

		// irs_mode_i is 0 if it's an IRS1/2, and 1 if it's an IRS3
		input irs_mode_i,

		output [EADDR_WIDTH-1:0] ebuf_addr_o,
		input [15:0] event_id_i,
		input [15:0] event_pps_count_i,
		input [31:0] event_cycle_count_i,
		input event_sel_i,

		inout [`EVIF_SIZE-1:0] event_interface_io,
		
		output prog_full, //LM export the prog_full to veto triggers
		input write_locked //LM to completely avoid reading during writing
    );

	
	wire fifo_clk_i;
	wire irs_clk_o = clk_i;
	wire fifo_full_i;
	wire fifo_wr_o;
//	wire read_done_o; 			// - duplicated to pass to trigger handler
	wire [15:0] dat_o;
	wire [1:0] type_o;
	wire rst_req_o;
	wire rst_ack_i;
	wire fifo_rst_o;
	event_interface_irs evif(.interface_io(event_interface_io),
								  .irs_clk_i(irs_clk_o),
								  .fifo_full_o(fifo_full_i),
								  .fifo_wr_i(fifo_wr_o),
//								  .read_done_i(read_done_o),
								  .dat_i(dat_o),
								  .type_i(type_o),
								  .rst_ack_o(rst_ack_i),
								  .rst_req_i(rst_req_o),
								  .fifo_rst_i(fifo_rst_o));

	reg [5:0] sample_counter = {6{1'b0}};
	reg [2:0] channel_counter = {3{1'b0}};
	reg [11:0] wilkinson_counter = {12{1'b0}};
	reg [11:0] wilkinson_sync = {12{1'b0}};
	reg [11:0] wilkinson_max = {12{1'b0}};
	reg wilkinson_done = 0;
	
	reg [9:0] wait_before_wilk = {10{1'b0}};
	
	reg [4:0] latch_wait_cnt = 5'h3;
	
	reg [8:0] read_address = {9{1'b0}};
	reg [8:0] read_address_int = {9{1'b0}};

	reg [15:0] data_out = {16{1'b0}};

	reg doing_event_header = 0;
	wire writing_event_header;
	
	reg [4:0] clear_wait = {5{1'b0}};

	// IRS3 read address counter
	reg [8:0] irs3_read_address_counter = {9{1'b0}};
	reg [3:0] irs3_read_address_wait_counter = {4{1'b0}};
	// 0x008 -> 0x001
	// 0x000 -> 0x000
	// 0x001 -> 0x002
	// 0x002 -> 0x004
	wire [8:0] irs3_read_address_fix = {read_address_int[8:4],read_address_int[2:0],read_address_int[3]};
	localparam [3:0] IRS3_COUNT_WAIT = 3;

	// DEBUG ONLY DEBUG ONLY DEBUG ONLY
/*
	reg [4:0] hold_block_counter = {5{1'b0}};
	
	always @(posedge clk_i) begin
		if (read_strobe_i && hold_block_counter != 5'd29)
			hold_block_counter <= hold_block_counter + 1;
		else if (read_strobe_i)
			hold_block_counter <= {5{1'b0}};
	end
*/
	
	// BTYPE_ONLY is BTYPE_FIRST|BTYPE_LAST
	localparam [1:0] BTYPE_FIRST = 2'b01;
	localparam [1:0] BTYPE_MIDDLE = 2'b00;
	localparam [1:0] BTYPE_LAST = 2'b10;
	localparam [1:0] BTYPE_ONLY = 2'b11;
	reg [1:0] block_type = BTYPE_ONLY;
	reg [1:0] last_block_type = BTYPE_ONLY;
	always @(posedge clk_i) begin
		if (rst_i)
			block_type <= BTYPE_ONLY;
		else if (read_remaining_strobe_i) begin
			case (last_block_type)
				BTYPE_ONLY,BTYPE_LAST: if (read_remaining_i) block_type <= BTYPE_FIRST;
								else block_type <= BTYPE_ONLY;
				BTYPE_FIRST,BTYPE_MIDDLE: if (!read_remaining_i) block_type <= BTYPE_LAST;
								else block_type <= BTYPE_MIDDLE;
			endcase
		end
	end
	always @(posedge clk_i) begin
		if (rst_i)
			last_block_type <= BTYPE_ONLY;
		else if (read_done_o)
			last_block_type <= block_type;
	end
	// This is fed in externally now.
//	localparam [9:0] wilkinson_time = 620; // 6.2 microseconds
	localparam [4:0] before_wilk_time = 10; // 6.2 microseconds
	localparam [4:0] LATCH_WAIT_CYCLES = 7; // 7+3=10 cycles : 100ns

	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(21);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] CLEAR = 16;
	localparam [FSM_BITS-1:0] WAIT_WRITE_HOLD = 17;
	localparam [FSM_BITS-1:0] CLEAR_RAMP = 18;
	localparam [FSM_BITS-1:0] WAIT_TO_CLEAR = 1;
	localparam [FSM_BITS-1:0] ASSERT_READ_ADDRESS = 2;
	localparam [FSM_BITS-1:0] ASSERT_READ_EN = 3;
	localparam [FSM_BITS-1:0] ASSERT_READ_EN_WAIT = 4;
	localparam [FSM_BITS-1:0] ASSERT_READ_EN_WAIT_2 = 5;
	localparam [FSM_BITS-1:0] BEGIN_WILKINSON = 6;
	localparam [FSM_BITS-1:0] DONE_WILKINSON = 7;
	localparam [FSM_BITS-1:0] ASSERT_SMPALL = 8;
	localparam [FSM_BITS-1:0] READ_WAIT = 9;
	localparam [FSM_BITS-1:0] READ_WAIT_2 = 10;
	localparam [FSM_BITS-1:0] READ_WAIT_3 = 11;
	localparam [FSM_BITS-1:0] READ_WAIT_4 = 12;
	localparam [FSM_BITS-1:0] LATCH_DATA = 13;
	localparam [FSM_BITS-1:0] CHANGE_ADDRESS = 14; //LM new state to decouple address change from data latching
	localparam [FSM_BITS-1:0] READ_DONE = 15;
	localparam [FSM_BITS-1:0] IRS3_READ_ADDRESS_START = 19;
	localparam [FSM_BITS-1:0] IRS3_READ_ADDRESS_WAIT = 20;
	localparam [FSM_BITS-1:0] IRS3_READ_ADDRESS_COUNT = 21;
	reg [FSM_BITS-1:0] state = IDLE;
//"Original" state machine: 5 states per sample readout
//	always @(posedge clk_i) begin
//		if (rst_i)
//			state <= IDLE;
//		else begin 
//			case (state)
//				IDLE: if (read_strobe_i) state <= WAIT_TO_CLEAR;
//				WAIT_TO_CLEAR: if (clear_wait == {5{1'b1}}) state <= ASSERT_READ_ADDRESS;
//				ASSERT_READ_ADDRESS: state <= ASSERT_READ_EN;
//				ASSERT_READ_EN: state <= ASSERT_READ_EN_WAIT;
//				ASSERT_READ_EN_WAIT: if (wait_before_wilk >= before_wilk_time) state <= BEGIN_WILKINSON;
//			//	ASSERT_READ_EN_WAIT_2: state <= BEGIN_WILKINSON;
//				BEGIN_WILKINSON: if (wilkinson_counter >= wilkinson_time) state <= DONE_WILKINSON;
//				DONE_WILKINSON: if (!doing_event_header) state <= ASSERT_SMPALL;
//				ASSERT_SMPALL: state <= READ_WAIT;
//				READ_WAIT: state <= READ_WAIT_2;
//				READ_WAIT_2: if (!fifo_full_i) state <= READ_WAIT_3; //original Patrick
//		//		READ_WAIT_2: if (!fifo_full_i) state <= READ_WAIT_4; //LM to recover 5 states per cycle
//				READ_WAIT_3: state <= READ_WAIT_4;
//				READ_WAIT_4: state <= LATCH_DATA;
//				LATCH_DATA: state <= CHANGE_ADDRESS;
//				CHANGE_ADDRESS: begin
//					if (sample_counter == {6{1'b1}} && channel_counter == {3{1'b1}})
//						state <= READ_DONE;
//					else
//						state <= READ_WAIT;
//				end
//				READ_DONE: state <= IDLE;
//			endcase
//		end
//	end

//New state machine: 6 states per sample readout

		always @(posedge clk_i) begin
		if (rst_i)
			state <= IDLE;
		else begin 
			case (state)
	//			IDLE: if (read_strobe_i) state <= WAIT_TO_CLEAR;
				IDLE: if (read_strobe_i) state <= WAIT_WRITE_HOLD; //LM added intermediate CLEAR state to issue CLR
				WAIT_WRITE_HOLD: if (write_locked) state <= CLEAR_RAMP; //LM wait for all write to be performed
				CLEAR_RAMP: if (clear_wait== {5{1'b1}}) state <= CLEAR; //LM added intermediate CLEAR_RAMP state to stop RAMP before CLR
				CLEAR: if (clear_wait== {5{1'b1}}) state <= WAIT_TO_CLEAR; //LM added to guarantee a minimum of 32 cycles to clear
				WAIT_TO_CLEAR: if (clear_wait == {5{1'b1}}) begin
					if (!irs_mode_i)
						state <= ASSERT_READ_ADDRESS;
					else
						state <= IRS3_READ_ADDRESS_START;
				end
				ASSERT_READ_ADDRESS: state <= ASSERT_READ_EN;
				ASSERT_READ_EN: state <= ASSERT_READ_EN_WAIT;
				ASSERT_READ_EN_WAIT: if (wait_before_wilk >= before_wilk_time) state <= BEGIN_WILKINSON;
			//	ASSERT_READ_EN_WAIT_2: state <= BEGIN_WILKINSON;
				BEGIN_WILKINSON: if (wilkinson_done) state <= DONE_WILKINSON;
				DONE_WILKINSON: if (!doing_event_header) state <= ASSERT_SMPALL;
		// Now try:
		// Assert SMPALL.
		// Wait for data to settle.
		// Latch it.
		// Deassert SMPALL.
		// Change address.
		// SMPALL for:
		// ASSERT_SMPALL->READ_WAIT->READ_WAIT_2 (variable length)->LATCH_DATA->READ_WAIT_3
		// Then no SMPALL for:
		// CHANGE ADDRESS->READ_WAIT_4
		// Then back to ASSERT_SMPALL.
				ASSERT_SMPALL: state <= READ_WAIT;
				READ_WAIT: state <= READ_WAIT_2;
		//		READ_WAIT_2: if (!fifo_full_i && latch_wait_cnt== LATCH_WAIT_CYCLES) state <= LATCH_DATA; 
				READ_WAIT_2: if (latch_wait_cnt== LATCH_WAIT_CYCLES) state <= LATCH_DATA;  //LM no more blocking in the middle of an event
				LATCH_DATA: state <= READ_WAIT_3;
				READ_WAIT_3: state <= CHANGE_ADDRESS;
				READ_WAIT_4: state <= ASSERT_SMPALL;
				CHANGE_ADDRESS: begin
					if (sample_counter == {6{1'b1}} && channel_counter == {3{1'b1}})
						state <= READ_DONE;
					else
						state <= READ_WAIT_4;
				end
				READ_DONE: state <= IDLE;
				IRS3_READ_ADDRESS_START: if (irs3_read_address_wait_counter == IRS3_COUNT_WAIT) state <= IRS3_READ_ADDRESS_WAIT;
				IRS3_READ_ADDRESS_WAIT: if (irs3_read_address_counter == irs3_read_address_fix) state <= ASSERT_READ_ADDRESS;
												else if (irs3_read_address_wait_counter == IRS3_COUNT_WAIT) state <= IRS3_READ_ADDRESS_COUNT;
				IRS3_READ_ADDRESS_COUNT: if (irs3_read_address_wait_counter == IRS3_COUNT_WAIT) state <= IRS3_READ_ADDRESS_WAIT;
			endcase
		end
	end
	always @(posedge clk_i) begin
		if (state == IRS3_READ_ADDRESS_WAIT || state == IRS3_READ_ADDRESS_COUNT || state == IRS3_READ_ADDRESS_START) begin
			if (irs3_read_address_wait_counter == IRS3_COUNT_WAIT) irs3_read_address_wait_counter <= {4{1'b0}};
			else irs3_read_address_wait_counter <= irs3_read_address_wait_counter + 1;
		end else
			irs3_read_address_wait_counter <= {4{1'b0}};
	end

	always @(posedge clk_i) begin
		if (state == IRS3_READ_ADDRESS_START)
			irs3_read_address_counter <= {9{1'b0}};
		else if (state == IRS3_READ_ADDRESS_COUNT && irs3_read_address_wait_counter == IRS3_COUNT_WAIT)
			irs3_read_address_counter <= irs3_read_address_counter + 1;
	end
	wire irs3_read_addr_adv = (state == IRS3_READ_ADDRESS_COUNT);
	wire irs3_read_addr_rst = (state == IRS3_READ_ADDRESS_START);
	// DOE stays asserted the entire time.
	wire irs3_data_enable = (state == ASSERT_SMPALL || state == READ_WAIT || state == READ_WAIT_2
									 || state == LATCH_DATA || state == READ_WAIT_3 || state == READ_WAIT_4
									 || state == CHANGE_ADDRESS);
        // Holdoff from end of writing to sampling.
	always @(posedge clk_i) begin
	//	if (state == WAIT_TO_CLEAR) 
		if ((state == WAIT_TO_CLEAR) || (state == CLEAR) || (state == CLEAR_RAMP)) //LM changed to clr only immediately before
			clear_wait <= clear_wait + 1;
		else
			clear_wait <= {5{1'b0}};
	end

	
	always @(posedge clk_i) begin
		if (state == IDLE && read_strobe_i) //&& hold_block_counter == {5{1'b0}})
			read_address_int <= read_address_i; //LM now latched internally, but shanged only after
															//write is over
	end
	
	
	always @(posedge clk_i) begin //LM when write is interrupted
		if (state == WAIT_WRITE_HOLD && write_locked) 
			read_address <= read_address_int;
	end
	
	assign RDEN = (state == ASSERT_READ_EN || state == ASSERT_READ_EN_WAIT ||
						state == ASSERT_READ_EN_WAIT_2 || state == BEGIN_WILKINSON);
	// RD is now special if it's an IRS3.
	assign RD[0] = (irs_mode_i) ? irs3_read_addr_adv : read_address[0];
	assign RD[1] = (irs_mode_i) ? irs3_read_addr_rst : read_address[1];
	assign RD[2] = (irs_mode_i) ? irs3_data_enable : read_address[2];
	assign RD[7:3] = (irs_mode_i) ? state : read_address[7:3];
	assign RD[8] = read_address[8];
	assign RD[9] = RDEN;
	
	// RD[9:3] are multiplexed upstream.
	
	assign START = (state == BEGIN_WILKINSON);
//	assign RAMP = (state == BEGIN_WILKINSON);
	assign RAMP = (state != CLEAR) && //LM now RAMP always on besides
												 //immediately before Wilkinson 
					(state != CLEAR_RAMP) &&//LM added to avoid RAMP and CLR on at the same time
					(state != WAIT_TO_CLEAR) && 
					(state != ASSERT_READ_ADDRESS) && 
					(state != ASSERT_READ_EN) && 
					(state != ASSERT_READ_EN_WAIT) &&
					(state != IRS3_READ_ADDRESS_START) &&
					(state != IRS3_READ_ADDRESS_COUNT) &&
					(state != IRS3_READ_ADDRESS_WAIT);
//	assign CLR = (state == IDLE && !read_strobe_i); //LM clear only after IDLE
	assign CLR = (state == CLEAR);
	assign SMP = sample_counter;
	assign CH = channel_counter;
	// SMPALL only stays asserted through the read of a sample, not when they're changing.
	// Avoid multiple ADC registers clashing on the internal mux.
	// So not on CHANGE_ADDRESS and READ_WAIT_4.
	assign SMPALL = (state == ASSERT_SMPALL || state == READ_WAIT ||
						  state == READ_WAIT_2 || state == READ_WAIT_3 || state == LATCH_DATA); 
	assign read_done_o = (state == READ_DONE);

	always @(posedge clk_i) begin
		if (state == ASSERT_READ_EN_WAIT)
			wait_before_wilk <= wait_before_wilk + 1;
		else
			wait_before_wilk <= {5{1'b0}};
	end
	
	always @(posedge clk_i) begin
		if (state == BEGIN_WILKINSON)
			wilkinson_counter <= wilkinson_counter + 1;
		else
			wilkinson_counter <= {10{1'b0}};
	end
	
	always @(posedge clk_i) begin
		wilkinson_done <= (wilkinson_counter >= wilkinson_max);
	end
	
	always @(posedge clk_i) begin
		wilkinson_sync <= wilkcnt_i;
		wilkinson_max <= wilkinson_sync;
	end
	
	always @(posedge clk_i) begin
		if (state == IDLE)
			sample_counter <= {6{1'b0}};
//		else if (state == LATCH_DATA) original from Patrick
		else if (state == CHANGE_ADDRESS) //LM to decouple address increment and data latching
			sample_counter <= sample_counter + 1;
	end
	always @(posedge clk_i) begin
		if (state == IDLE)
			channel_counter <= {3{1'b0}};
	//	else if (state == LATCH_DATA && sample_counter == {6{1'b1}}) original from Patrick
		else if (state == CHANGE_ADDRESS & sample_counter == {6{1'b1}}) //LM to decouple address increment and data latching
			channel_counter <= channel_counter + 1;
	end
	
	always @(posedge clk_i) begin
		if (state == READ_WAIT_2)
			if(latch_wait_cnt<LATCH_WAIT_CYCLES) latch_wait_cnt <= latch_wait_cnt + 1;
		else
			latch_wait_cnt <= {5{1'b0}};
	end
	// This is all header and event stuff.
	// This should be moved into its own module, it's cluttering
	// the hell out of this one.
	/*
	output [EADDR_WIDTH-1:0] ebuf_addr_o;
	input [15:0] event_id_i;
	input [15:0] event_pps_count_i;
	input [31:0] event_cycle_count_i;
	input event_sel_i;
	*/
	
	reg wr = 0;
	// length is always 64*8*2 = 1024+4 = 1028 for now, I guess
	localparam HD_BITS = clogb2(12);
	// Every block has a length: needed for event interface
	localparam [HD_BITS-1:0] HEADER_START = 0;
	localparam [HD_BITS-1:0] HEADER_LEN_CALC = 1;
	localparam [HD_BITS-1:0] HEADER_LEN = 2;
	// This is the event header path
	localparam [HD_BITS-1:0] EVHEADER_VER = 3;
	localparam [HD_BITS-1:0] EVHEADER_WAIT = 4;
	localparam [HD_BITS-1:0] EVHEADER_PPS_COUNT = 5;
	localparam [HD_BITS-1:0] EVHEADER_CYCLE_COUNT_LOW = 6;
	localparam [HD_BITS-1:0] EVHEADER_CYCLE_COUNT_HIGH = 7;
	localparam [HD_BITS-1:0] EVHEADER_ID = 8;
	localparam [HD_BITS-1:0] EVHEADER_DONE = 9;
	// This is the block header path
	localparam [HD_BITS-1:0] BLKHEADER_BLKIDPAT = 10;
	localparam [HD_BITS-1:0] BLKHEADER_IDS_MASK = 11;
	localparam [HD_BITS-1:0] HEADER_DONE = 12;
	reg [HD_BITS-1:0] event_header_state = HEADER_START;

	reg [EADDR_WIDTH-1:0] event_buffer = {EADDR_WIDTH{1'b0}};
	assign ebuf_addr_o = event_buffer;
	reg [15:0] event_id = {16{1'b0}};
	reg [15:0] event_pps_count = {16{1'b0}};
	reg [31:0] event_cycle_count = {32{1'b0}};
	
	always @(posedge clk_i) begin
		if (rst_i)
			event_buffer <= {EADDR_WIDTH{1'b0}};
		else if (event_header_state == EVHEADER_DONE) 
			event_buffer <= event_buffer + 1;
	end
	always @(posedge clk_i) begin
		if (event_header_state == EVHEADER_WAIT) begin
			if (event_sel_i) begin
				event_id <= event_id_i;
				event_pps_count <= event_pps_count_i;
				event_cycle_count <= event_cycle_count_i;
			end
		end
	end

	
	reg header_has_data = 0;
	always @(event_header_state) begin
		case (event_header_state)
			HEADER_START,HEADER_LEN_CALC,EVHEADER_WAIT,EVHEADER_DONE,HEADER_DONE:
				header_has_data <= 0;
			default:
				header_has_data <= 1;
		endcase
	end

	assign writing_event_header = doing_event_header && header_has_data;
	
	/// block length when we read out a block, plus header (4 words = 8 bytes)
	// This needs to be calculated based on the channel mask. LOVELY!
	localparam [15:0] data_length = 16'd512;
	// Event header info.
	localparam [15:0] event_header_version = 1;
	localparam [15:0] event_header_length_v0 = 1;
	localparam [15:0] event_header_length_v1 = 5;
	localparam [15:0] event_header_length = event_header_length_v1;
		
	// Block header info.
	localparam [15:0] block_header_length = 16'd2;
	wire [15:0] blkheader_ids_and_mask = {STATION_ID,STACK_NUMBER,ch_mask_i};
	wire [15:0] blkheader_id_pattern = {3'b000,trig_pat_i,read_address};

	reg [15:0] block_length = {16{1'b0}};
	always @(posedge clk_i) begin
		if (event_header_state == HEADER_LEN_CALC) begin
			if (block_type == BTYPE_FIRST || block_type == BTYPE_ONLY)
				block_length <= data_length + event_header_length + block_header_length;
			else
				block_length <= data_length + block_header_length;
		end
	end


	always @(posedge clk_i) begin
		if (rst_i)
			doing_event_header <= 0;
		else if (state == ASSERT_READ_ADDRESS)
			doing_event_header <= 1;
		else if (event_header_state == HEADER_DONE)
			doing_event_header <= 0;
	end

	always @(posedge clk_i) begin
		if (rst_i)
			event_header_state <= HEADER_START;
		else if (doing_event_header) begin
			case (event_header_state)
				HEADER_START: event_header_state <= HEADER_LEN_CALC;
				HEADER_LEN_CALC: event_header_state <= HEADER_LEN;
 		//		HEADER_LEN: if (!fifo_full_i) begin
 				HEADER_LEN: //LM no more blocking in the middle of an event -- also for all lines marked with *
									if (block_type == BTYPE_FIRST || block_type == BTYPE_ONLY) 
										event_header_state <= EVHEADER_VER;
									else
										event_header_state <= BLKHEADER_BLKIDPAT;
		//						end
		//		*EVHEADER_VER: if (!fifo_full_i) event_header_state <= EVHEADER_WAIT;
				EVHEADER_VER: event_header_state <= EVHEADER_WAIT;
				EVHEADER_WAIT: if (event_sel_i) event_header_state <= EVHEADER_PPS_COUNT;
		//		*EVHEADER_PPS_COUNT: if (!fifo_full_i) event_header_state <= EVHEADER_CYCLE_COUNT_LOW;
				EVHEADER_PPS_COUNT: event_header_state <= EVHEADER_CYCLE_COUNT_LOW;
		//		*EVHEADER_CYCLE_COUNT_LOW: if (!fifo_full_i) event_header_state <= EVHEADER_CYCLE_COUNT_HIGH;
				EVHEADER_CYCLE_COUNT_LOW: event_header_state <= EVHEADER_CYCLE_COUNT_HIGH;
		//		*EVHEADER_CYCLE_COUNT_HIGH: if (!fifo_full_i) event_header_state <= EVHEADER_ID;
				EVHEADER_CYCLE_COUNT_HIGH: event_header_state <= EVHEADER_ID;
		//		*EVHEADER_ID: if (!fifo_full_i) event_header_state <= EVHEADER_DONE;
				EVHEADER_ID: event_header_state <= EVHEADER_DONE;
				EVHEADER_DONE: event_header_state <= BLKHEADER_BLKIDPAT;
		//		*BLKHEADER_BLKIDPAT: if (!fifo_full_i) event_header_state <= BLKHEADER_IDS_MASK;
				BLKHEADER_BLKIDPAT: event_header_state <= BLKHEADER_IDS_MASK;
		//		*BLKHEADER_IDS_MASK: if (!fifo_full_i) event_header_state <= HEADER_DONE;
				BLKHEADER_IDS_MASK:  event_header_state <= HEADER_DONE;
				HEADER_DONE: event_header_state <= HEADER_LEN_CALC;
				default: event_header_state <= HEADER_START;
			endcase
		end
	end
	
	always @(posedge clk_i) begin
	//	wr <= (state == LATCH_DATA || writing_event_header); original from Patrick
		wr <= (state == CHANGE_ADDRESS || writing_event_header); //LM ?why?
	end
	
	always @(posedge clk_i) begin
		if (writing_event_header) begin
			case (event_header_state)
				HEADER_LEN: data_out <= block_length;
				EVHEADER_VER: data_out <= event_header_version;
				EVHEADER_PPS_COUNT: data_out <= event_pps_count;
				EVHEADER_CYCLE_COUNT_LOW: data_out <= event_cycle_count[15:0];
				EVHEADER_CYCLE_COUNT_HIGH: data_out <= event_cycle_count[31:16];
				EVHEADER_ID: data_out <= event_id;
				BLKHEADER_BLKIDPAT: data_out <= blkheader_id_pattern;
				BLKHEADER_IDS_MASK: data_out <= blkheader_ids_and_mask;
			endcase
		end
		else if (state == LATCH_DATA)
			data_out <= {{4'b0},DAT};
	end

	reg in_reset = 0;
	always @(posedge clk_i) begin
		if (rst_i)
			in_reset <= 1;
		else if (rst_ack_i)
			in_reset <= 0;
	end
	assign fifo_rst_o = (rst_ack_i && in_reset);
	assign rst_req_o = in_reset;

	assign type_o = block_type;
	assign dat_o = data_out;
	assign fifo_wr_o = wr;
	assign prog_full = fifo_full_i || in_reset;
endmodule
