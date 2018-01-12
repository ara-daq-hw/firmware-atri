`timescale 1ns / 1ps
`include "ev_interface.vh"

module atriusb_interface(
		// FX2 infrastructure
		RESET,
		CLK,
		FLAGA,
		FLAGB,
		FLAGC,
		FLAGD,
		SLOE,
		SLRD,
		SLWR,
		FIFOADR,
		PKTEND,
		FD,
		// Control interface
		ctrl_dat_o,
		ctrl_dat_i,
		ctrl_packet_i,
		ctrl_wr_o,
		ctrl_rd_o,
		ctrl_mostly_empty_i,
		ctrl_empty_i,
		ctrl_full_i,
		// Event interface
		event_interface_io,
		// debug
		debug_o
    );

	parameter PINPOL = "NEGATIVE";
	 
	//% System reset.
	input RESET;
	//% System clock.
	input CLK;
	
	// Control data path
	//% EP2 FIFO is empty
	input FLAGA;
	//% EP6 FIFO is almost full
	input FLAGD;

	// Event data path
	//% EP4 FIFO is empty
	input FLAGB;
	//% EP8 FIFO is almost full
	input FLAGC;
	
	//% Output enable.
	output SLOE;
	//% Read from FX2.
	output SLRD;
	//% Write to FX2.
	output SLWR;
	//% Select which FIFO we're addressing
	output [1:0] FIFOADR;
	//% Force packet end.
	output PKTEND;
	
	//% Bidir data.
	inout [7:0] FD;
	
	//% Control data out
	output [7:0] ctrl_dat_o;
	//% Control data in
	input [7:0] ctrl_dat_i;
	//% Control data packet end.
	input ctrl_packet_i;
	//% Control FIFO write.
	output ctrl_wr_o;
	//% Control FIFO read.
	output ctrl_rd_o;
	//% Control FIFO is empty.
	input ctrl_empty_i;
	//% Control FIFO mostly empty.
	input ctrl_mostly_empty_i;
	//% Control FIFO is full.
	input ctrl_full_i;
	
	//% Event interface.
	inout [`EVIF_SIZE-1:0] event_interface_io;

	//% Debug interface.
	output [47:0] debug_o;


   // Expand the event interface.
	wire fifo_clk_i;
	wire irs_clk_i;
	wire fifo_empty_i;
	wire prog_empty_i;
	wire [15:0] fifo_nwords_i;
	wire fifo_rd_o;
	wire [15:0] dat_i;
	wire [1:0] type_i;
	wire fifo_block_done_o;
	wire rst_req_i;
	wire rst_ack_o;
	event_interface_rdout evif(.interface_io(event_interface_io),
									.fifo_clk_o(fifo_clk_i),.irs_clk_o(irs_clk_i),
									.fifo_empty_o(fifo_empty_i),.prog_empty_o(prog_empty_i),
									.fifo_nwords_o(fifo_nwords_i),
									.fifo_rd_i(fifo_rd_o),
									.dat_o(dat_i),.type_o(type_i),
									.fifo_block_done_i(fifo_block_done_o),
									.rst_req_o(rst_req_i),
									.rst_ack_i(rst_ack_o));
	wire ev_rd_o;
	
	// OK, so we're still going to wrap the event interface
	// with the frame interface from the DDA_EVAL. The idea then
	// is that the readout module can just assert "read_done_i"
	// immediately after the FIRST word is written. The state machine
	// then reads it out, and begins the framed readout.
	wire [7:0] event_data;
	wire event_frame_done;
	wire event_write_pending;
	wire ev_empty_i;
	atriusb_event_readout event_readout(.rst_req_i(rst_req_i),
	                                    .rst_ack_o(rst_ack_o),
													.fifo_dat_i(dat_i),
													.fifo_type_i(type_i),
													.fifo_nwords_i(fifo_nwords_i),
													.bridge_dat_o(event_data),
													.event_ready_i(!fifo_empty_i),
													.event_pending_o(event_write_pending),
													.event_empty_o(ev_empty_i),
													.fifo_empty_i(fifo_empty_i),
													.fifo_clk_i(fifo_clk_i),
													.fifo_rd_o(fifo_rd_o),
													.event_rd_i(ev_rd_o),
													.frame_done_i(event_frame_done),
													.block_done_o(fifo_block_done_o));
													
	
	// The ATRI USB interface is moderately straightforward.
	wire [7:0] fx2_fd_out;
	wire [7:0] fx2_fd_in;
	wire [7:0] fx2_fd_to_ff;
	wire [7:0] fx2_fd_q;

	// sloe_reg is *always* positive logic, indicating that the FX2 is driving the data bus.
	reg sloe_reg = 1;
	
	wire fx2_fd_ce;
	
	generate
		genvar fd_i;
		for (fd_i=0;fd_i<8;fd_i=fd_i+1) begin : FD_INFRA
			// sloe_reg is positive logic for the FX2 driving the databus.
			// That means it's negative logic for us, which is what the Xilinx IOBUF wants.
			IOBUF fd_iobuf(.IO(FD[fd_i]),.O(fx2_fd_to_ff[fd_i]),.I(fx2_fd_out[fd_i]),.T(sloe_reg));
			(* IOB = "TRUE" *) FDE fd_ff(.D(fx2_fd_to_ff[fd_i]),.CE(fx2_fd_ce),.C(CLK),.Q(fx2_fd_q[fd_i]));
		end
	endgenerate

	// Flag inputs. We never need the out_full raws: that's why we
	// switched to "almost full."
	wire ctrl_out_full;
	wire ctrl_in_empty;
	wire event_out_full;
	wire event_in_empty;

	wire ctrl_out_full_q;
	wire ctrl_in_empty_q;
	wire event_out_full_q;
	wire event_in_empty_q;

	// Enables. These actually go high one cycle earlier than SLRD goes.
	wire slrd_enable;
	wire pktend_enable;
	wire slwr_enable;
	
	generate
		if (PINPOL == "POSITIVE") begin : POSITIVE
			wire slrd_to_obuf;
			wire pktend_to_obuf;
			wire slwr_to_obuf;

			IBUF ctrl_out_full_ibuf(.I(FLAGD),.O(ctrl_out_full));
			IBUF ctrl_in_empty_ibuf(.I(FLAGA),.O(ctrl_in_empty));
			IBUF event_out_full_ibuf(.I(FLAGC),.O(event_out_full));
			IBUF event_in_empty_ibuf(.I(FLAGB),.O(event_in_empty));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) ctrl_out_full_ff(.D(ctrl_out_full),.CE(1'b1),.C(CLK),.Q(n_ctrl_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) ctrl_in_empty_ff(.D(ctrl_in_empty),.CE(1'b1),.C(CLK),.Q(n_ctrl_in_empty_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) event_out_full_ff(.D(event_out_full),.CE(1'b1),.C(CLK),.Q(event_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) event_in_empty_ff(.D(event_in_empty),.CE(1'b1),.C(CLK),.Q(event_in_empty_q));
			(* IOB = "TRUE" *) FDE slrd_ff(.D(slrd_enable),.CE(1'b1),.C(CLK),.Q(slrd_to_obuf));
			OBUF slrd_obuf(.I(slrd_to_obuf),.O(SLRD));
			(* IOB = "TRUE" *) FDE pktend_ff(.D(pktend_enable),.CE(1'b1),.C(CLK),.Q(pktend_to_obuf));
			OBUF pktend_obuf(.I(pktend_to_obuf),.O(PKTEND));
			(* IOB = "TRUE" *) FDE slwr_ff(.D(slwr_enable),.CE(1'b1),.C(CLK),.Q(slwr_to_obuf));
			OBUF slwr_obuf(.I(slwr_to_obuf),.O(SLWR));

			// sloe_reg is positive logic. If PINPOL is positive, we just assign.
			assign SLOE = sloe_reg;
		end else begin : NEGATIVE
			wire n_ctrl_out_full;
			wire n_ctrl_in_empty;
			wire n_ctrl_out_full_q;
			wire n_ctrl_in_empty_q;
			wire n_event_out_full;
			wire n_event_in_empty;
			wire n_event_out_full_q;
			wire n_event_in_empty_q;
			wire n_slrd_enable;
			wire n_slwr_enable;
			wire n_pktend_enable;
				
			wire n_slrd_to_obuf;
			wire n_slwr_to_obuf;
			wire n_pktend_to_obuf;

			assign ctrl_out_full = ~n_ctrl_out_full;
			assign ctrl_out_full_q = ~n_ctrl_out_full_q;
			assign ctrl_in_empty = ~n_ctrl_in_empty;
			assign ctrl_in_empty_q = ~n_ctrl_in_empty_q;
			assign event_out_full = ~n_event_out_full;
			assign event_out_full_q = ~n_event_out_full_q;
			assign event_in_empty = ~n_event_in_empty;
			assign event_in_empty_q = ~n_event_in_empty_q;
			assign n_slrd_enable = ~slrd_enable;
			assign n_slwr_enable = ~slwr_enable;
			assign n_pktend_enable = ~pktend_enable;
			
			IBUF ctrl_out_full_ibuf(.I(FLAGD),.O(n_ctrl_out_full));
			IBUF ctrl_in_empty_ibuf(.I(FLAGA),.O(n_ctrl_in_empty));
			IBUF event_out_full_ibuf(.I(FLAGC),.O(n_event_out_full));
			IBUF event_in_empty_ibuf(.I(FLAGB),.O(n_event_in_empty));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) ctrl_out_full_ff(.D(n_ctrl_out_full),.CE(1'b1),.C(CLK),.Q(n_ctrl_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) ctrl_in_empty_ff(.D(n_ctrl_in_empty),.CE(1'b1),.C(CLK),.Q(n_ctrl_in_empty_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) event_out_full_ff(.D(n_event_out_full),.CE(1'b1),.C(CLK),.Q(n_event_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) event_in_empty_ff(.D(n_event_in_empty),.CE(1'b1),.C(CLK),.Q(n_event_in_empty_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) slrd_ff(.D(n_slrd_enable),.CE(1'b1),.C(CLK),.Q(n_slrd_to_obuf));
			OBUF slrd_obuf(.I(n_slrd_to_obuf),.O(SLRD));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) pktend_ff(.D(n_pktend_enable),.CE(1'b1),.C(CLK),.Q(n_pktend_to_obuf));
			OBUF pktend_obuf(.I(n_pktend_to_obuf),.O(PKTEND));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) slwr_ff(.D(n_slwr_enable),.CE(1'b1),.C(CLK),.Q(n_slwr_to_obuf));
			OBUF slwr_obuf(.I(n_slwr_to_obuf),.O(SLWR));

			// sloe_reg is positive logic for the FX2 driving the databus. So with negative logic,
			// we invert its output here.
			assign SLOE = ~sloe_reg;
	
		end
	endgenerate

	// Write counter. We only ever write a maximum of 512 bytes.
	localparam WRITE_MAX = 511; // == 9'h1FF as well.
	localparam WRITE_COUNTER_BITS = 9;
	reg [WRITE_COUNTER_BITS-1:0] write_counter = {WRITE_COUNTER_BITS{1'b0}};
	
	localparam [1:0] CTRL_INBOUND = 2'b00;
	localparam [1:0] EVENT_INBOUND = 2'b01;
	localparam [1:0] CTRL_OUTBOUND = 2'b10;
	localparam [1:0] EVENT_OUTBOUND = 2'b11;
	
	reg [1:0] fifo_select = EVENT_INBOUND;

	localparam TXN_WRITE = 1;
	localparam TXN_READ = 0;
	reg transaction_type = TXN_READ;

	reg delayed_pktend = 0;
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(10);
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% First thing we do is assert FIFO, since it takes 25 ns to set up. Also SLOE if needed.
	localparam [FSM_BITS-1:0] ASSERT_FIFO_ADDRESS = 1;
	//% Now we wait one clock for the FIFO address to settle.
	localparam [FSM_BITS-1:0] ASSERT_FIFO_ADDRESS_WAIT = 2;
	//% Read: we assert SLRD enable. Data is still not OK to latch.
	localparam [FSM_BITS-1:0] ASSERT_SLRD_ENABLE = 3;
	//% Write.
	localparam [FSM_BITS-1:0] WRITE = 4;
	//% First read transfer. SLRD is on, data will be on FD_Q on next cycle
	localparam [FSM_BITS-1:0] READ_WAIT = 5;
	//% Remaining reads.
	localparam [FSM_BITS-1:0] READ = 6;
	//% Deassertion of SLOE/SLRD/FIFO_ADDRESS/etc.
	localparam [FSM_BITS-1:0] DONE = 7;
	//% Pause due to output FIFO full
	localparam [FSM_BITS-1:0] READ_PAUSE = 8;
	//% Resume after output FIFO empties
	localparam [FSM_BITS-1:0] READ_RESUME = 9;
	//% Wait until more data is in the inbound FIFO
	localparam [FSM_BITS-1:0] WRITE_WAIT = 10;
	reg [FSM_BITS-1:0] state = IDLE;
	
	// temp
	wire ctrl_write_pending = !ctrl_empty_i;
	// This is for inbound data on the event port.
	// We'll probably make a very simple command protocol for that
	// data path: one that can reset the event readout and the packet controller.	
	wire ev_full_i = 0;
	wire read_complete = (fifo_select[0]) ? event_in_empty : ctrl_in_empty;
	wire read_complete_q = (fifo_select[0]) ? event_in_empty_q : ctrl_in_empty_q;
	wire read_output_fifo_full = (fifo_select[0]) ? ev_full_i : ctrl_full_i;
	wire write_input_fifo_empty = (fifo_select[0]) ? ev_empty_i : ctrl_empty_i;
	// These use the registered FULL flags because the flags go high one cycle early.
	// Therefore when event_out_full_q goes high, it actually is full.
	wire write_output_fifo_full = (fifo_select[0]) ? event_out_full_q : ctrl_out_full_q;
	// This determines whether or not we pause a write, or we just go to DONE.
	wire write_pause = (fifo_select[0]) ? 1'b0 : !ctrl_packet_i;
	
	assign fx2_fd_ce = (state == READ_WAIT || state == READ);
	assign slrd_enable = (state == ASSERT_SLRD_ENABLE || state == READ_WAIT || state == READ || state == READ_RESUME);
	assign pktend_enable = (state == WRITE && ((write_input_fifo_empty && !write_pause) || write_output_fifo_full)) || delayed_pktend;

	// Hack to assert PKTEND at the write point - one cycle after WRITE_MAX occurs.
	always @(posedge CLK) begin
		if (state == WRITE && (write_counter == WRITE_MAX))
			delayed_pktend <= 1;
		else
			delayed_pktend <= 0;
	end

	// We assert slwr_enable in ASSERT_FIFO_ADDRESS_WAIT if it's a TXN_WRITE,
	// so that SLWR goes high on the first data write. We turn it off if
	// the inbound FIFO empties, or if the outbound FIFO's full, and we
	// turn it back on during a WRITE_WAIT if the inbound FIFO is no
	// longer empty.
	assign slwr_enable = (state == WRITE && !write_input_fifo_empty && !write_output_fifo_full) || 
								(state == ASSERT_FIFO_ADDRESS_WAIT && transaction_type == TXN_WRITE);
//								(state == WRITE_WAIT && !write_input_fifo_empty);
//	assign SLWR = (state == WRITE && !write_input_fifo_empty);
	always @(posedge CLK) begin
		if (state == IDLE) begin
			//% FLAGA, FLAGC are 'empty'
			if (!event_out_full_q && event_write_pending) begin
				transaction_type <= TXN_WRITE;
				fifo_select <= EVENT_OUTBOUND;
			end else if (!event_in_empty_q) begin
				transaction_type <= TXN_READ;
				fifo_select <= EVENT_INBOUND;
			end else if (!ctrl_in_empty_q && !ctrl_full_i) begin
				transaction_type <= TXN_READ;
				fifo_select <= CTRL_INBOUND;
			end else if (!ctrl_out_full_q && ctrl_write_pending) begin
				transaction_type <= TXN_WRITE;
				fifo_select <= CTRL_OUTBOUND;
			end else begin
				fifo_select <= EVENT_INBOUND;
			end
		end
	end
	assign FIFOADR = fifo_select;
	always @(posedge CLK) begin
		if (state == IDLE) sloe_reg <= 1;
		else if (state == ASSERT_FIFO_ADDRESS && transaction_type == TXN_WRITE) sloe_reg <= 0;
	end
	
	// when read output fifo full goes high, SLRD is disabled on the next clock and the data latch
	// is disabled on the input buffer. So the FD_Q outputs contain the next data to be written,
	// and the FD outputs contain the next data to write. That's why we need a READ_RESUME
	// state.


	always @(posedge CLK) begin
		case (state)
			IDLE: if ((!event_in_empty_q && !ev_full_i) || (!ctrl_in_empty_q && !ctrl_full_i) || (!ctrl_out_full_q && ctrl_write_pending) || (!event_out_full_q && event_write_pending)) state <= ASSERT_FIFO_ADDRESS;
			ASSERT_FIFO_ADDRESS: state <= ASSERT_FIFO_ADDRESS_WAIT;
			ASSERT_FIFO_ADDRESS_WAIT: if (transaction_type == TXN_WRITE) state <= WRITE; else state <= ASSERT_SLRD_ENABLE;
			ASSERT_SLRD_ENABLE: state <= READ_WAIT;
			READ_WAIT: state <= READ;
			// Read path. When the read empties, we move to DONE. If we can't write anymore,
			// we move to READ_PAUSE, and wait for the output fifo to empty a little.
			READ: if (read_complete) state <= DONE; else if (read_output_fifo_full) state <= READ_PAUSE;
			READ_PAUSE: if (!read_output_fifo_full) state <= READ_RESUME; else if (ctrl_write_pending) state <= IDLE; 
			READ_RESUME: state <= READ;
			DONE: state <= IDLE;
			// Write path.
			WRITE: begin
				if (write_output_fifo_full || write_counter == WRITE_MAX) state <= DONE;
				else if (write_input_fifo_empty) begin
					if (write_pause) state <= WRITE_WAIT;
					else state <= DONE;
				end
			end
			WRITE_WAIT: if (!write_input_fifo_empty) state <= WRITE;
			default: state <= IDLE;
		endcase
	end

	// slwr_enable goes high one cycle early, so this counter goes
	// Byte0 Byte1 Byte2 Byte3
	//   1     2     3     4  
	// etc.: but WRITE_MAX is 511, and SLWR turns off one cycle late, so at the end
	// Byte number:   Byte510 Byte511 
	// State:         WRITE   DONE
	// write_counter: 511     0
	// slwr_enable:   0       0
	// SLWR           1       0
	always @(posedge CLK) begin
		if (slwr_enable)
			write_counter <= write_counter + 1;
		else
			write_counter <= {WRITE_COUNTER_BITS{1'b0}};
	end
	
	assign event_frame_done = (state == DONE && fifo_select == EVENT_OUTBOUND); 
	
	reg [7:0] outbound_data = {8{1'b0}};
	always @(posedge CLK) begin
		if (transaction_type == TXN_WRITE) begin
			if (state == ASSERT_FIFO_ADDRESS_WAIT || state == WRITE) begin
				if (fifo_select == CTRL_OUTBOUND)
					outbound_data <= ctrl_dat_i;
				else if (fifo_select == EVENT_OUTBOUND)
					outbound_data <= event_data;
			end
		end
	end
	assign fx2_fd_out = outbound_data;
	
	assign ctrl_wr_o = (state == READ && fifo_select == CTRL_INBOUND && !read_output_fifo_full);
	assign ctrl_rd_o = (state == WRITE || state == ASSERT_FIFO_ADDRESS_WAIT) && (fifo_select == CTRL_OUTBOUND) && !write_output_fifo_full;
	assign ctrl_dat_o = fx2_fd_q;

	// ev_rd goes when we're writing. if the FIFO is full, it will exit out of state == WRITE
	// on the next cycle, because FIFO FULL goes high 1 cycle early.
	assign ev_rd_o = 	(state == WRITE || state == ASSERT_FIFO_ADDRESS_WAIT) && (fifo_select == EVENT_OUTBOUND);
	
	// screw it, we'll prevent ourselves from sending more than 512 in one packet.
	
	
	// This is the bidirectional data bus, delayed by one cycle.
	assign debug_o[7:0] = (sloe_reg) ? fx2_fd_q : fx2_fd_out;
	assign debug_o[8] = ctrl_in_empty_q;
	assign debug_o[9] = event_in_empty_q;
	assign debug_o[10] = ctrl_out_full_q;
	assign debug_o[11] = event_out_full_q;
	assign debug_o[12] = slrd_enable;
	assign debug_o[13] = sloe_reg;
	assign debug_o[14] = read_complete_q;
	assign debug_o[15] = read_output_fifo_full;
	assign debug_o[16] = write_input_fifo_empty;
	assign debug_o[17] = ctrl_write_pending;
	assign debug_o[18] = event_write_pending;
	assign debug_o[19] = ctrl_wr_o;
	assign debug_o[20] = ctrl_rd_o;
	assign debug_o[24:21] = state;
	assign debug_o[25] = pktend_enable;
	assign debug_o[26] = slwr_enable;
	assign debug_o[27] = fifo_select[0];
	assign debug_o[28] = fifo_select[1];
	assign debug_o[29] = ctrl_packet_i;
	assign debug_o[30] = ev_rd_o;
	assign debug_o[40:31] = write_counter;
endmodule
 