`timescale 1ns / 1ps
/**
 * @file irs_block_readout_addr_v3.v Contains irs_block_readout_addr_v3 module.
 */

//% @brief Module for selecting the IRS block readout address.
//%
//% The IRS read address interface begins when raddr_stb_i   
//% is asserted. For the IRS1-2, this places "raddr_i" on RD 
//% and then issues raddr_reached_o.                           
//%
//% For the IRS3, this begins operating the read address    
//% counter. Once the read address has been reached,
//% raddr_reached_o is asserted.                              
//% 
//% Because this could take a long time, for multiple       
//% blocks, the read address module can acknowledge an      
//% address independently: 'raddr_ack_o' is asserted
//% when 'raddr_reached_o' is asserted and 'ramp_done_i'
//% is asserted, indicating that the address has been
//% converted, and the next block address can be received.
//%
//% The timing diagram for this (in the parent module) is (note that 'state' here
//% refers to the parent module's state)
//% @drawtiming{-w30 -f16}
//% raddr_i=X, raddr_stb_i=0, raddr_ack_o=0, state="IDLE", RD0=0, RD1=0,current_block=X,irs_raddr_ack=0.
//% raddr_i=4.
//% raddr_stb_i=1.
//% state="ADDRESS",current_block=4,RD0=1.
//% RD0=0.
//% RD0=1.
//% RD0=0.
//% RD0=1.
//% RD0=0.
//% RD0=1.
//% RD0=0,irs_raddr_ack=1.
//% state="CLEAR".
//% state="CLEAR".
//% state="RAMP".
//% state="RAMP".
//% state="READOUT",irs_raddr_ack=0,raddr_ack_o=1.
//% raddr_stb_i=0.
//% raddr_i=5,raddr_ack_o=0.
//% raddr_stb_i=1.
//% RD0=1.
//% RD0=0,irs_raddr_ack=1.
//% state="A..",current_block=5.
//% state="CLEAR".
//% state="CLEAR".
//% state="RAMP".
//% state="RAMP".
//% state="READOUT",irs_raddr_ack=0,raddr_ack_o=1.
//% raddr_stb_i=0,raddr_i=X,raddr_ack_o=0.
//% @enddrawtiming
//%
//% Notes: "raddr_stb_i" is not checked until the clock cycle after raddr_ack_o is
//%        asserted. 
module irs_block_readout_addr_v3(
		input clk_i, 							//% System clock.
		input rst_i,							//% Local reset.
		output rst_ack_o,						//% Reset acknowledge.

		input irs_mode_i,						//% If '1', this is an IRS3. If '0' this is an IRS1-2.

		input [8:0] raddr_i,					//% Address that we're selecting.
		input raddr_stb_i,					//% If '1', go to "raddr_i" address
		output raddr_ack_o,					//% If '1', we have reached and done Wilkinson on "raddr_i"
		input ramp_done_i,					//% If '1', Wilkinson ramp completed
		output raddr_reached_o,				//% If '1', we have reached "raddr_i" (but no Wilkinson)

		output [8:0] irs_rd_o				//% RD[8:0] outputs.
    );

	//% Indicates an IRS3.
	localparam IRS3 = 1;

	//% Latch the value of the address.
	reg [8:0] irs_address_target = {9{1'b0}};
	
	always @(posedge clk_i) begin
		if (rst_i)
			irs_address_target <= {9{1'b0}};
		else if (raddr_stb_i && state == IDLE)
			irs_address_target <= raddr_i;
	end
	
	//% IRS3 address counter.
	reg [8:0] irs_address_counter = {9{1'b0}};
	
	//% General-purpose waiting counter.
	reg [7:0] counter = {8{1'b0}};

	//% Indicates whether or not ramp_done_i was seen
	reg ramp_done_seen = 0;
	
	//% Number of cycles, minus 1, from red address on RD[8:0] to raddr_reached_o asserted.
	localparam [7:0] ASSERT_SETUP = 0;
	//% Number of cycles, minus 1, that RD_ADDR_ADV is high.
	localparam [7:0] RD_ADDR_ADV_HIGH = 0;
	//% Number of cycles, minus 1, that RD_ADDR_ADV is low.
	localparam [7:0] RD_ADDR_ADV_LOW = 0;
	//% Number of cycles, minus 1, that RD_ADDR_RST is high.
	localparam [7:0] RD_ADDR_RST_HIGH = 0;
	//% Number of cycles, minus 1, that RD_ADDR_RST is low.
	localparam [7:0] RD_ADDR_RST_LOW = 0;
	
	`include "clogb2.vh"
	//% Number of bits in the state machine.
	localparam FSM_BITS = clogb2(8);
	//% State machine is idle.
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% Received a strobe.
	localparam [FSM_BITS-1:0] STROBE = 1;
	//% Check the address.
	localparam [FSM_BITS-1:0] CHECK = 2;
	//% State machine has asserted RD_ADDR_ADV
	localparam [FSM_BITS-1:0] COUNTING = 3;
	//% State machine has deasserted RD_ADDR_ADV and is waiting to assert it again.
	localparam [FSM_BITS-1:0] COUNT_WAIT = 4;
	//% State machine has asserted RD_ADDR_RST
	localparam [FSM_BITS-1:0] RESETTING = 5;
	//% State machine has deasserted RD_ADDR_RST
	localparam [FSM_BITS-1:0] RESET_WAIT = 6;
	//% State machine has asserted RD[8:0]
	localparam [FSM_BITS-1:0] ASSERT = 7;
	//% State machine has reached the destination address.
	localparam [FSM_BITS-1:0] REACHED = 8;
	//% State variable. Begins in IDLE.
	reg [FSM_BITS-1:0] state = IDLE;
	
	wire do_reset = (rst_i && (state != RESETTING && state != RESET_WAIT));
	reg in_reset = 0;
	
	reg last_count = 0;
	always @(posedge clk_i) begin
		last_count <= (irs_address_counter == (irs_address_target - 1));
	end
	
	reg target_address_reached = 0;
	always @(posedge clk_i) begin
		if ((irs_address_counter == irs_address_target) ||
			 ((state == COUNTING && counter == RD_ADDR_ADV_HIGH) && last_count))
			target_address_reached <= 1;
		else
			target_address_reached <= 0;			
	end
	
	//% FSM logic. For the IRS3 this resets the counter and advances each time. Will improve later.
	always @(posedge clk_i) begin : FSM
		if (do_reset) state <= RESETTING;
		else begin
			case(state)
				IDLE: if (raddr_stb_i) state <= STROBE;
				STROBE: state <= CHECK;
				CHECK: begin
					if (target_address_reached) state <= REACHED;
					else if (irs_mode_i) state <= RESETTING;
					else state <= ASSERT;
				end
				ASSERT: if (counter == ASSERT_SETUP) state <= REACHED;
				RESETTING: if (counter == RD_ADDR_RST_HIGH) state <= RESET_WAIT;
				RESET_WAIT: if (counter == RD_ADDR_RST_LOW) begin
					if (in_reset) begin
						if (!rst_i) state <= IDLE;
					end else begin
						if (target_address_reached) state <= REACHED;
						else state <= COUNTING;
					end
				end
				COUNTING: if (counter == RD_ADDR_ADV_HIGH) state <= COUNT_WAIT;
				COUNT_WAIT: if (target_address_reached) state <= REACHED;
							   else if (counter == RD_ADDR_ADV_LOW) state <= COUNTING;
				REACHED: if (ramp_done_seen) state <= IDLE;
				default: state <= IDLE;
			endcase
		end
	end
	
	//% @brief Reset logic. in_reset=1 when rst_i is high, 0 when in RESET_WAIT and rst_i is low.
	always @(posedge clk_i) begin : IN_RESET_LOGIC
		if (do_reset) in_reset <= 1;
		else if (!rst_i && (state == RESET_WAIT)) in_reset <= 0;
   end
	
	//% @brief Counter logic. Counts up to the various delays.
	always @(posedge clk_i) begin : COUNTER_LOGIC
		if (state == ASSERT) begin
			if (counter == ASSERT_SETUP) counter <= {8{1'b0}};
			else counter <= counter + 1;
		end else if (state == COUNTING) begin
			if (counter == RD_ADDR_ADV_HIGH) counter <= {8{1'b0}};
			else counter <= counter + 1;
		end else if (state == COUNTING) begin
			if (counter == RD_ADDR_ADV_LOW) counter <= {8{1'b0}};
			else counter <= counter + 1;
		end else if (state == RESETTING) begin
			if (counter == RD_ADDR_RST_HIGH) counter <= {8{1'b0}};
			else counter <= counter + 1;
		end else if (state == RESET_WAIT) begin
			if (counter == RD_ADDR_RST_LOW) counter <= {8{1'b0}};
			else counter <= counter + 1;
		end else 
			counter <= {8{1'b0}};
	end
	
	//% @brief Address logic. Latched in ASSERT, reset in RESETTING and count up in COUNTING.
	always @(posedge clk_i) begin : ADDRESS_LOGIC
		if (state == ASSERT)
			irs_address_counter <= irs_address_target;
		else if (state == COUNTING && counter == RD_ADDR_ADV_HIGH)
			irs_address_counter <= irs_address_counter + 1;
		else if (state == RESETTING && counter == RD_ADDR_RST_HIGH)
			irs_address_counter <= {9{1'b0}};
	end
		
	//% ramp_done rising edge flag
	wire ramp_done_flag;
	
	//% ramp_done_i rising edge detector.
	SYNCEDGE #(.EDGE("RISING"),.LATENCY(0),.POLARITY("POSITIVE"),.CLKEDGE("RISING"))
		ramp_done_det(.I(ramp_done_i),.O(ramp_done_flag),.CLK(clk_i));

	//% Ramp done seen logic.
	always @(posedge clk_i) begin : RAMP_DONE_SEEN_LOGIC
		if (state == IDLE) ramp_done_seen <= 0;
		else if (ramp_done_flag) ramp_done_seen <= 1;
	end
	
	assign raddr_reached_o = (state == REACHED);
	assign raddr_ack_o = (state == REACHED && ramp_done_seen);	
	assign rst_ack_o = (state == RESET_WAIT);

	assign irs_rd_o[0] = (irs_mode_i == IRS3) ? (state == COUNTING) : irs_address_counter[0];
	assign irs_rd_o[1] = (irs_mode_i == IRS3) ? (state == RESETTING) : irs_address_counter[1];
	assign irs_rd_o[8:2] = irs_address_counter[8:2];
endmodule
