`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Dummy block manager. If irs_statistics has the max block lock count to 1,
// this should work fine as a block manager, I think.
//////////////////////////////////////////////////////////////////////////////////
module irs_simple_block_manager(
		// System clock. Should be 4X intended TSA speed (2X intended block write speed)
		input clk_i,
		// Reset.
		input rst_i,
		// wrstrb clock - phase delayed and possibly DC !=50% in a controlled way
		input clk_wrstrb,
		// IRS2 write interface.
		output tsa_o,
		output tsa_close_o,
		// This is the actual block output.
		output [9:0] block_wr_o,
		// These are the actual WR outputs.
		output [9:0] wr_o,
		output wrstrb_o,
		output wrstrb_int_o, //synchronized with clk_i
		// Block locking interface.
		input [8:0] lock_address_i,
		input lock_i,
		input unlock_i, //LM added so that we can take into account
							 //lock and unlock at the same time - note that with a real
							 //manager that physically frees the block there is leakage!
		input lock_strobe_i,
		output lock_ack_o,
		// Block freeing interface.
		input [8:0] free_address_i,
		input free_strobe_i,
		output free_ack_o,
		// IRS2 has at least one dead block. 
		output dead_o,
		// clear dead status
		input dead_clear_i,
		// Enable the block manager.
		input enable_i,
		// Pedestal mode
		input ped_mode_i,
		input [8:0] ped_address_i,
		input ped_clear_i,

		// Sense for DDArD routing or DDArA-C routing
		input irs_mode_i,
		
		output locked,
		output [47:0] debug_o
    );

	//% Registered WR output.
	(* IOB = "TRUE" *)
	reg [9:0] wr = {10{1'b0}};
	//% Block output registers. No DDArD swizzling.
	reg [9:0] block_wr = {10{1'b0}};
	
	//% If 1, we have taken one trip through the state machine. If 0, this is the first time.
	reg first_pass_complete = 0;
	//% Enable for TSA.
	reg tsa_enable = 0;
	//% Registered TSA output.
	(* IOB = "TRUE" *)
	reg tsa = 0;
	//% Registered TSA close output.
	(* IOB = "TRUE" *)
	reg tsa_close = 0;
	//% Registered write strobe output.
	(* IOB = "TRUE" *)
	reg wrstrb = 0;
	reg wrstrb_int = 0;
	//% Temporary block storage
	reg [8:0] tmp_1 = {9{1'b0}};
	//% Temporary block storage
	reg [8:0] tmp_2 = {9{1'b0}};
	//% Temporary block storage
	reg [8:0] tmp_3 = {9{1'b0}};

	//% Simple address counter.
	reg [7:0] address_counter = {8{1'b0}};
	//% Holds the number of clock cycles we're waiting for after a lock request.
	reg [7:0] lock_wait_counter = {8{1'b0}};

	// Buffer is going to lock when we hit LOCK_WAIT_CYCLES
	reg locking_buffer = 0;
	// Buffer is locked
	reg locked_buffer = 0;
	// Number of lock requests that we've seen (number of blocks being read out)
	reg [8:0] locked_block_counter = {9{1'b0}};

	
	//% Pedestal mode: block phase.
	wire ped_phase;
	//% Pedestal mode: the requested block has been read
	reg ped_done = 0;	
	//% Pedestal mode: pedestal enable (actually write the block)
	wire ped_en;

	//% Block that will be issued for the first clock in the 3-block path
	reg [9:0] block_1 = {10{1'b0}};
	//% Block that will be issued for the second clock in the 3-block path
	reg [9:0] block_2 = {10{1'b0}};
	//% Block that will be issued for the third clock in the 3-block path
	reg [9:0] block_3 = {10{1'b0}};

	// Dummy stuff.
	wire free_empty = 0;
	wire [8:0] free_block_head = {9{1'b0}};
	
	
	// Number of cycles to wait after a lock request comes in before we
	// stop sampling.
	localparam LOCK_WAIT_CYCLES = 100; //LM was 200 see if it "moves" 

	always @(posedge clk_i) begin
		if (lock_wait_counter == LOCK_WAIT_CYCLES)
			locking_buffer <= 0;
		else if (lock_i && lock_strobe_i)
			locking_buffer <= 1;
	end
	
	always @(posedge clk_i) begin
//		if (lock_i && lock_strobe_i && locked_block_counter < {9{1'b1}} && !lock_ack_o) // original
		if (lock_i && !unlock_i && lock_strobe_i && locked_block_counter < {9{1'b1}} && !lock_ack_o) //LM changed so simultaneous lock and unlock are counted correctly 
			locked_block_counter <= locked_block_counter + 1;
//		else if ((!lock_i  && lock_strobe_i && locked_block_counter > 0) && !lock_ack_o) // original 
		else if ((!lock_i && unlock_i && lock_strobe_i && locked_block_counter > 0) && !lock_ack_o) //LM changed so simultaneous lock and unlock are counted correctly 
			locked_block_counter <= locked_block_counter - 1;
	end
	
	always @(posedge clk_i) begin
		if (locking_buffer)
			lock_wait_counter <= lock_wait_counter + 1;
		else
			lock_wait_counter <= {8{1'b0}};
	end
	always @(posedge clk_i) begin
		if (lock_wait_counter == LOCK_WAIT_CYCLES && locking_buffer)
			locked_buffer <= 1;
		else if (locked_block_counter == 0)
			locked_buffer <= 0;
	end
	
	reg lock_ack = 0;
	always @(posedge clk_i) lock_ack <= lock_strobe_i && !lock_ack;
	assign lock_ack_o = lock_ack;
	reg free_ack = 0;
	always @(posedge clk_i) free_ack <= free_strobe_i;
	assign free_ack_o = free_ack;
	
	assign dead_o = 0;
	
	wire block_is_locked = 0;
	// in pass 0, not read 1, read 2, not read 3
	// in pass 1, read 1, not read 2, read 3
	wire block_phase;
	
	localparam [3:0] IDLE = 0;			          		//% Not operating. (cb_address = X)
	localparam [3:0] PRIME = 1;							//% Clock 0. (cb_address = active_read_ptr)
	localparam [3:0] READ_1 = 2;							//% Clock 1. (cb_address = active_read_ptr)
	localparam [3:0] READ_2 = 3;							//% Clock 2. (cb_address = active_read_ptr)
	localparam [3:0] CHECK_1_READ_3 = 4;				//% Clock 3. (cb_address = active_read_ptr_C)
	localparam [3:0] CHECK_2 = 5;							//% Clock 4, if block_1 is unlocked. (cb_address = active_read_ptr_B)
	localparam [3:0] CHECK_3 = 6;							//% Clock 5, if block_2 is unlocked. (cb_address = active_read_ptr)
	localparam [3:0] NOP = 7;								//% Clock 6, if block_3 is unlocked. (cb_address = X)
	localparam [3:0] PED_1 = 8; 							//% Clock 1, pedestal mode
	localparam [3:0] PED_2 = 9;							//% Clock 2, pedestal mode
	localparam [3:0] PED_3 = 10;							//% Clock 3, pedestal mode
	localparam [3:0] PED_4 = 11;							//% Clock 4, pedestal mode
	localparam [3:0] PED_5 = 12;							//% Clock 5, pedestal mode
	localparam [3:0] PED_6 = 13;							//% Clock 6, pedestal mode
	reg [3:0] state = IDLE;
	localparam PASS_0 = 0;
	localparam PASS_1 = 1;
	
	//% State machine. Obviously braindead simple.
	always @(posedge clk_i) begin : STATE_LOGIC
		if (!enable_i) state <= IDLE;
		else begin
			case (state)
				IDLE: state <= PRIME;
				PRIME: if (ped_mode_i) state <= PED_1; else state <= READ_1;
				READ_1: state <= READ_2;
				READ_2: state <= CHECK_1_READ_3;
				CHECK_1_READ_3: state <= CHECK_2;
				CHECK_2: state <= CHECK_3;
				CHECK_3: state <= NOP;
				NOP: if (ped_mode_i) state <= PED_1; else state <= READ_1;
				// Pedestal path.
				PED_1: state <= PED_2; //% equivalent of READ_1
				PED_2: state <= PED_3; //% equivalent of READ_2
				PED_3: state <= PED_4; //% equivalent of CHECK_1_READ_3
				PED_4: state <= PED_5; //% equivalent of CHECK_2
				PED_5: state <= PED_6; //% equivalent of CHECK_3
				PED_6: if (!ped_mode_i) state <= READ_1; else state <= PED_1; //% equivalent of NOP
				default: state <= IDLE;
			endcase
		end
	end
	//% A full write cycle is actually two passes through the state machine. This indicates which pass we're on.
	reg pass_number = PASS_0;

	//% We begin in PASS_0 logic, and then each time we are in NOP or PED_6, we switch to PASS_1 logic.
	always @(posedge clk_i) begin : PASS_LOGIC
		if (!enable_i) pass_number <= PASS_0;
		else if (state == NOP || state == PED_6) begin
			if (pass_number == PASS_0) pass_number <= PASS_1;
			else pass_number <= PASS_0;
		end
	end
	
	// Block phase.
	assign block_phase = 
		((pass_number == PASS_0) && (state == READ_2)) || ((pass_number == PASS_1) && (state == READ_1 || state == CHECK_1_READ_3));
	// IRS1-2 use WR[2] as the LSB, so it needs to toggle each phase.
	// IRS3 uses WR[3] as the LSB, so it toggles each phase.
	wire [8:0] cb_block_out_irs12 = {address_counter[7:2],block_phase,address_counter[1:0]};	
	wire [8:0] cb_block_out_irs3 = {address_counter[7:0],block_phase};
	//% Store the block buffer outputs in a temporary register while we check if they're OK.
	always @(posedge clk_i) begin : TMP_LOGIC
		if (state == READ_1)
			tmp_1 <= (irs_mode_i) ? cb_block_out_irs3 : cb_block_out_irs12;
		if (state == READ_2)
			tmp_2 <= (irs_mode_i) ? cb_block_out_irs3 : cb_block_out_irs12;
		if (state == CHECK_1_READ_3)
			tmp_3 <= (irs_mode_i) ? cb_block_out_irs3 : cb_block_out_irs12;
	end

	//% Increment
	always @(posedge clk_i) begin
		if (pass_number == PASS_1) begin
			if (state == READ_1 || state == CHECK_1_READ_3)
				address_counter <= address_counter + 1;
		end else if (pass_number == PASS_0) begin
			if (state == READ_2)
				address_counter <= address_counter + 1;
		end
	end

	//% Decide between the temporary register and the free block head for block 1.
	always @(posedge clk_i) begin : BLOCK_1_LOGIC
		if (state == CHECK_1_READ_3) begin
			if (block_is_locked && !free_empty)
				block_1 <= {1'b1,free_block_head};
			else
		//		block_1 <= {!locked_buffer,tmp_1};
			  if (locked_buffer) 
				block_1 <= {10{1'b0}};
			  else
				block_1 <= {1'b1,tmp_1};
		end
	end
	//% Decide between the temporary register and the free block head for block 2.
	always @(posedge clk_i) begin
		if (state == CHECK_2) begin : BLOCK_2_LOGIC
			if (block_is_locked && !free_empty)
				block_2 <= {1'b1,free_block_head};
			else
	//			block_2 <= {!locked_buffer, tmp_2};
			  if (locked_buffer) 
				block_2 <= {10{1'b0}};
			  else
				block_2 <= {1'b1,tmp_2};
		end
	end
	//% Decide between the temporary register and the free block head for block 3.
	always @(posedge clk_i) begin : BLOCK_3_LOGIC
		if (state == CHECK_3) begin
			if (block_is_locked && !free_empty)
				block_3 <= {1'b1,free_block_head};
			else
		//		block_3 <= {!locked_buffer,tmp_3};
			 if (locked_buffer) 
				block_3 <= {10{1'b0}};
			  else
				block_3 <= {1'b1,tmp_3};
		end
	end

	// END NON-PED_MODE LOGIC
	//% Indicates if the first trip through the state machine has happened yet.
	always @(posedge clk_i) begin : FIRST_PASS_COMPLETE_LOGIC
		if (!enable_i) first_pass_complete <= 0;
		else if (state == NOP || state == PED_6) first_pass_complete <= 1;
	end

	always @(posedge clk_i) begin
		if (!enable_i) tsa_enable <= 0;
		else begin
			if (state == READ_1 || state == CHECK_3 || state == PED_1 || state == PED_5)
				tsa_enable <= !pass_number;
			else if (state == CHECK_1_READ_3 || state == PED_3)
				tsa_enable <= pass_number;
		end
	end
	always @(negedge clk_i) begin
		tsa <= tsa_enable;
	end
	always @(posedge clk_i) begin
		tsa_close <= tsa_enable;
	end
	
	wire [9:0] block_1_remap = {block_1[9:4],block_1[0],block_1[1],block_1[2],block_1[3]};
	wire [9:0] block_2_remap = {block_2[9:4],block_2[0],block_2[1],block_2[2],block_2[3]};
	wire [9:0] block_3_remap = {block_3[9:4],block_3[0],block_3[1],block_3[2],block_3[3]};
	wire [9:0] ped_address_remap = {ped_en,ped_address_i[8:4],ped_address_i[0],ped_address_i[1],ped_address_i[2],ped_address_i[3]};

	//% Actual block output logic.
	always @(posedge clk_i) begin
		if (state == CHECK_2)
			wr <= (irs_mode_i) ? block_1_remap : block_1;
		else if (state == NOP)
			wr <= (irs_mode_i) ? block_2_remap : block_2;
		else if (state == READ_2 && first_pass_complete)
			wr <= (irs_mode_i) ? block_3_remap : block_3;
		else if (state == PED_4 || state == PED_6 || (state == PED_2 && first_pass_complete))
			// The write output is only actually enabled (wr[9] high)
			// if we're in the correct ped_phase
			wr <= (irs_mode_i) ? ped_address_remap : {ped_en,ped_address_i};
	end

	//% Identical logic as before, but no remap. For remainder of logic.
	always @(posedge clk_i) begin
		if (state == CHECK_2)
			block_wr <= block_1;
		else if (state == NOP)
			block_wr <= block_2;
		else if (state == READ_2 && first_pass_complete)
			block_wr <= block_3;
		else if (state == PED_4 || state == PED_6 || (state == PED_2 && first_pass_complete))
			// The write output is only actually enabled (wr[9] high)
			// if we're in the correct ped_phase
			block_wr <= {ped_en,ped_address_i};
	end


	// in pass 0, ped_2 and ped_6 need ped_phase high (ped_4 is low)
	// in pass 1, ped_4 needs ped_phase high
	assign ped_phase = 
		(pass_number == PASS_1 && state == PED_4) || (pass_number == PASS_0 && (state == PED_2 || state == PED_6));

	// This logic only works for the IRS1-2, where address 2 has to map to the phase.
	// For the IRS3, the ped address bit 3 has to map to the phase.
	//assign ped_en = (ped_phase == ped_address_i[2]) && !ped_done;
	wire ped_address_phase_match = (irs_mode_i) ? ped_address_i[0] : ped_address_i[2];
	assign ped_en = (ped_phase == ped_address_phase_match) && !ped_done;

	//% Pedestal mode: ped_done logic
	always @(posedge clk_i) begin
		if (!ped_mode_i || ped_clear_i)
			ped_done <= 0;
		else if (state == PED_4 || state == PED_6 || (state == PED_2 && first_pass_complete))
			if (ped_phase == ped_address_phase_match)
				ped_done <= 1;
	end

	//% Write strobe logic. Mimics write block output logic, but delayed an half cycle.
//	always @(negedge clk_i) begin //LM changed to anticipate write strobe - 
											//make sure it anticipates it and does not delay it
	// This isn't needed if WRSTRB goes straight to an IOB.
	always @(posedge clk_i) begin //LM changed to fine tune write strobe - 
		if (  (state == CHECK_3 || state == PED_5))
	//		wrstrb <= 1;
			wrstrb <= !locked_buffer; //to turn off the strobe as well in case locked
		else if ((state == CHECK_1_READ_3 || state == PED_3) && first_pass_complete)
	//		wrstrb <= 1;
			wrstrb <= !locked_buffer;
		else if ((state == READ_1 || state == PED_1) && first_pass_complete)
	//		wrstrb <= 1;
			wrstrb <= !locked_buffer;
		else
			wrstrb <= 0;
	end
	
	always @(negedge clk_i) begin //LM added to generate "proper" wrstrb for internal purposes
		if (  (state == CHECK_3 || state == PED_5))
			wrstrb_int <= !locked_buffer; //to turn off the strobe as well in case locked
		else if ((state == CHECK_1_READ_3 || state == PED_3) && first_pass_complete)
			wrstrb_int <= !locked_buffer;
		else if ((state == READ_1 || state == PED_1) && first_pass_complete)
			wrstrb_int <= !locked_buffer;
		else
			wrstrb_int <= 0;
	end
	
	assign locked = locked_buffer;

	// The DDA rev D accidentally remapped the WR bits such that
	// WR[0] -> WR[3]
	// WR[1] -> WR[2]
	// WR[2] -> WR[1]
	// WR[3] -> WR[0]
	// So we unscramble them here.
	// NOOOOOO this makes it MONUMENTALLY slow.
	// Better to register it 'wrong' in wr.
	// wire [9:0] wr_remap = { wr[9:4], wr[0], wr[1], wr[2], wr[3] };
	assign block_wr_o = block_wr;
	assign wr_o = wr;
	assign tsa_o = tsa;
	assign tsa_close_o = tsa_close;
	assign wrstrb_o = wrstrb;
	assign wrstrb_int_o = wrstrb_int;
	assign debug_locked = locked_buffer;
		assign  debug_o[3:0] = state;
endmodule
