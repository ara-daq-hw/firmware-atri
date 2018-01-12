`timescale 1ns / 1ps
`include "ev2_interface.vh"

// V3 interface. Uses
// FLAGA = ctrl from PC
// FLAGB = ctrl to PC
// FLAGC = event to PC
// FLAGD = reset

// The V3 interface cleans up the V2 interface to make the timing targets hittable.
module atriusb_interface_v3(
		// FX2 infrastructure
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
	   phy_rst_o,
		ctrl_dat_o,
		ctrl_dat_i,
		ctrl_packet_i,
		ctrl_wr_o,
		ctrl_rd_o,
		ctrl_mostly_empty_i,
		ctrl_empty_i,
		ctrl_full_i,
		// Event interface
		ev2_if_io,
		// debug
		debug_o
    );

	parameter PINPOL = "NEGATIVE";
	parameter EVENT_FIFO = "LARGE";
	 
	//% System clock.
	input CLK;
	
	// Control data path
	//% EP2 FIFO is empty
	input FLAGA;
	//% EP4 FIFO is almost full
	input FLAGB;

	// Event data path
	//% EP6 FIFO is almost full
	input FLAGC;
	//% EP8 FIFO is empty (UNUSED - WILL BE A RESET)
	input FLAGD;
	
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

	//% Reset from the PHY (from FLAGD).
	output phy_rst_o;
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
	inout [`EV2IF_SIZE-1:0] ev2_if_io;

	//% Debug interface.
	output [52:0] debug_o;

	// INTERFACE_INS ev2 ev2_fifo RPL interface_io ev2_if_io
	wire irsclk_i;
	wire [15:0] dat_i;
	wire [15:0] count_o;
	wire wr_i;
	wire full_o;
	wire rst_i;
	wire rst_ack_o;
	ev2_fifo ev2if(.interface_io(ev2_if_io),
	               .irsclk_o(irsclk_i),
	               .dat_o(dat_i),
	               .count_i(count_o),
	               .wr_o(wr_i),
	               .full_i(full_o),
	               .rst_o(rst_i),
	               .rst_ack_i(rst_ack_o));
	// INTERFACE_END

	signal_sync reset_sync(.in_clkA(FLAGD),.out_clkB(phy_rst_o),.clkB(CLK));
	
	
	// Event readout, version 2. This version basically just
	// streams an event through the USB interface.

	//% Data to the FX2 bridge.
	wire [7:0] event_data;
	//% Request for data.
	wire event_data_req;
	//% Data for the event endpoint is pending.
	wire event_write_pending;
	//% Legacy (indicates that the event output 'FIFO' is not empty)
	wire ev_empty_i = !event_write_pending;
	//% Pause writing
	wire event_pause = 0;
	//% Event is complete (issue PKTEND).
	wire event_done;
	//% Debug.
	wire [35:0] event_debug;
	//% Event readout, version 3.
	atriusb_event_readout_v3 #(.EVENT_FIFO(EVENT_FIFO)) event_readout(.rst_req_i(rst_i),
														.rst_ack_o(rst_ack_o),
														.irs_clk_i(irsclk_i),
														.phy_clk_i(CLK),
														.fifo_dat_i(dat_i),
														.fifo_nwords_o(count_o),
														.fifo_wr_i(wr_i),
														.fifo_full_o(full_o),
														
														.bridge_dat_o(event_data),
														.bridge_rd_i(event_data_req),
														.event_pending_o(event_write_pending),
														.event_pause_i(event_pause),
														.event_done_o(event_done),
														.debug_o(event_debug)
														);
	
	// The ATRI USB interface is moderately straightforward.
	wire [7:0] fx2_fd_out;
	wire [7:0] fx2_fd_in;
	wire [7:0] fx2_fd_to_ff;
	wire [7:0] fx2_fd_q;

	// Enables. These actually go high one cycle earlier than SLRD goes.
	wire slrd_enable;
	wire pktend_enable;
	wire slwr_enable;
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

	wire ctrl_out_full_q;
	wire ctrl_in_empty_q;
	wire event_out_full_q;

	
	generate
		if (PINPOL == "POSITIVE") begin : POSITIVE
			wire slrd_to_obuf;
			wire pktend_to_obuf;
			wire slwr_to_obuf;

			IBUF ctrl_out_full_ibuf(.I(FLAGB),.O(ctrl_out_full));
			IBUF ctrl_in_empty_ibuf(.I(FLAGA),.O(ctrl_in_empty));
			IBUF event_out_full_ibuf(.I(FLAGC),.O(event_out_full));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) ctrl_out_full_ff(.D(ctrl_out_full),.CE(1'b1),.C(CLK),.Q(n_ctrl_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) ctrl_in_empty_ff(.D(ctrl_in_empty),.CE(1'b1),.C(CLK),.Q(n_ctrl_in_empty_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b1)) event_out_full_ff(.D(event_out_full),.CE(1'b1),.C(CLK),.Q(event_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) slrd_ff(.D(slrd_enable),.CE(1'b1),.C(CLK),.Q(slrd_to_obuf));
			OBUF slrd_obuf(.I(slrd_to_obuf),.O(SLRD));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) pktend_ff(.D(pktend_enable),.CE(1'b1),.C(CLK),.Q(pktend_to_obuf));
			OBUF pktend_obuf(.I(pktend_to_obuf),.O(PKTEND));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) slwr_ff(.D(slwr_enable),.CE(1'b1),.C(CLK),.Q(slwr_to_obuf));
			OBUF slwr_obuf(.I(slwr_to_obuf),.O(SLWR));

			// sloe_reg is positive logic. If PINPOL is positive, we just assign.
			assign SLOE = sloe_reg;
		end else begin : NEGATIVE
			wire n_ctrl_out_full;
			wire n_ctrl_in_empty;
			wire n_ctrl_out_full_q;
			wire n_ctrl_in_empty_q;
			wire n_event_out_full;
			wire n_event_out_full_q;
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
			assign n_slrd_enable = ~slrd_enable;
			assign n_slwr_enable = ~slwr_enable;
			assign n_pktend_enable = ~pktend_enable;
			
			IBUF ctrl_out_full_ibuf(.I(FLAGB),.O(n_ctrl_out_full));
			IBUF ctrl_in_empty_ibuf(.I(FLAGA),.O(n_ctrl_in_empty));
			IBUF event_out_full_ibuf(.I(FLAGC),.O(n_event_out_full));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) ctrl_out_full_ff(.D(n_ctrl_out_full),.CE(1'b1),.C(CLK),.Q(n_ctrl_out_full_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) ctrl_in_empty_ff(.D(n_ctrl_in_empty),.CE(1'b1),.C(CLK),.Q(n_ctrl_in_empty_q));
			(* IOB = "TRUE" *) FDE #(.INIT(1'b0)) event_out_full_ff(.D(n_event_out_full),.CE(1'b1),.C(CLK),.Q(n_event_out_full_q));
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

	reg delayed_evfull = 0;
	always @(posedge CLK) begin
		delayed_evfull <= event_out_full_q;
	end

	// Directions here are from OUR PERSPECTIVE. Endpoint names are HOST
	// PERSPECTIVE.

	//% Control FIFO endpoint, inbound (EP2OUT)
	localparam [1:0] CTRL_INBOUND = 2'b00;
	//% Control FIFO endpoint, outbound (EP4IN)
	localparam [1:0] CTRL_OUTBOUND = 2'b01;
	//% Event FIFO endpoint, outbound (EP6IN)
	localparam [1:0] EVENT_OUTBOUND = 2'b10;
	
	//% Which FIFO is selected. Default is CTRL_INBOUND.
	reg [1:0] fifo_select = CTRL_INBOUND;

	reg delayed_pktend = 0;

	//% Indicates that there is control data to write.
	wire ctrl_write_pending = !ctrl_empty_i;
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(15);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] EVWR_FIFO_ADDRESS = 1;
	localparam [FSM_BITS-1:0] EVWR_FIFO_ADDRESS_WAIT = 2;
	localparam [FSM_BITS-1:0] EVWR_WRITE = 3;
	localparam [FSM_BITS-1:0] CPWR_FIFO_ADDRESS = 4;
	localparam [FSM_BITS-1:0] CPWR_FIFO_ADDRESS_WAIT = 5;
	localparam [FSM_BITS-1:0] CPWR_WRITE = 6;
	localparam [FSM_BITS-1:0] CPWR_WRITE_PAUSE = 7;
	localparam [FSM_BITS-1:0] CPRD_FIFO_ADDRESS = 8;
	localparam [FSM_BITS-1:0] CPRD_FIFO_ADDRESS_WAIT = 9;
	localparam [FSM_BITS-1:0] CPRD_SLRD_ENABLE = 10;
	localparam [FSM_BITS-1:0] CPRD_READ_WAIT = 11;
	localparam [FSM_BITS-1:0] CPRD_READ = 12;
	localparam [FSM_BITS-1:0] CPRD_READ_PAUSE = 13;
	localparam [FSM_BITS-1:0] CPRD_READ_RESUME = 14;
	localparam [FSM_BITS-1:0] DONE = 15;
	reg [FSM_BITS-1:0] state = {FSM_BITS{1'b0}};
	
	always @(posedge CLK) begin
		if (phy_rst_o) state <= IDLE;
		else begin
			case (state)
				IDLE: if (event_write_pending && !delayed_evfull) state <= EVWR_FIFO_ADDRESS;
				 else if (ctrl_write_pending && !ctrl_out_full_q) state <= CPWR_FIFO_ADDRESS;
				 else if (!ctrl_in_empty_q && !ctrl_full_i) state <= CPRD_FIFO_ADDRESS;
				EVWR_FIFO_ADDRESS: state <= EVWR_FIFO_ADDRESS_WAIT;
				EVWR_FIFO_ADDRESS_WAIT: state <= EVWR_WRITE;
				EVWR_WRITE: if (buffer_filling || event_done) state <= DONE;
				CPWR_FIFO_ADDRESS: state <= CPWR_FIFO_ADDRESS_WAIT;
				CPWR_FIFO_ADDRESS_WAIT: state <= CPWR_WRITE;
				// NOTE NOTE NOTE: NEED TO DO SOMETHING HERE TO PREVENT TRYING TO WRITE
				// OUTBOUND PACKETS GREATER THAN 512, CUZ THEN IT JUST KEEPS TRYING TO
				// WRITE
				CPWR_WRITE: if (ctrl_empty_i && !ctrl_packet_i) state <= CPWR_WRITE_PAUSE;
						 else if (ctrl_empty_i && ctrl_packet_i) state <= DONE;
				CPWR_WRITE_PAUSE: if (!ctrl_empty_i) state <= CPWR_WRITE;
				CPRD_FIFO_ADDRESS: state <= CPRD_FIFO_ADDRESS_WAIT;
				CPRD_FIFO_ADDRESS_WAIT: state <= CPRD_SLRD_ENABLE;
				CPRD_SLRD_ENABLE: state <= CPRD_READ_WAIT;
				CPRD_READ_WAIT: state <= CPRD_READ;
				CPRD_READ: if (ctrl_in_empty_q) state <= DONE;
					   else if (ctrl_full_i) state <= CPRD_READ_PAUSE;
				CPRD_READ_PAUSE: if (!ctrl_full_i) state <= CPRD_READ_RESUME;
								else if (ctrl_write_pending) state <= IDLE;
				CPRD_READ_RESUME: state <= CPRD_READ;
				DONE: state <= IDLE;
			endcase
		end
	end

	// Who knows what's going on with the FX2.
	reg [8:0] evcounter = {9{1'b0}};
	always @(posedge CLK) begin : EV_LOGIC
		if (state == EVWR_WRITE) evcounter <= evcounter + 1;
		else evcounter <= {9{1'b0}};
	end
	wire buffer_filling = (evcounter == {9{1'b1}});
		
	//% Logic for SLOE. Directly connects to the T input of the IOBUF and SLOE's output.
	always @(posedge CLK) begin : SLOE_LOGIC
		if (state == IDLE) sloe_reg <= 1;
		else if (state == EVWR_FIFO_ADDRESS || state == CPWR_FIFO_ADDRESS) sloe_reg <= 0;
	end

	// Logic for generating PKTEND.
	wire pktend;
	reg do_pktend = 0;
	always @(posedge CLK) begin
		if (state == IDLE)
			do_pktend <= 0;
		else if ((state == EVWR_WRITE && event_done) || (state == CPWR_WRITE && ctrl_packet_i && ctrl_empty_i))
			do_pktend <= 1;
	end
	assign pktend = (do_pktend && (state == DONE));
	
	//% Clock enable for the FD inputs.
	assign fx2_fd_ce = (state == CPRD_READ_WAIT || state == CPRD_READ);
	//% Clock enable for the SLRD output.
	assign slrd_enable = (state == CPRD_SLRD_ENABLE || state == CPRD_READ_WAIT || state == CPRD_READ || state == CPRD_READ_RESUME);
	//% Clock enable for PKTEND. Only goes high when we complete a write.
	assign pktend_enable = pktend;
	//% Clock enable for SLWR.
	assign slwr_enable = (state == EVWR_WRITE && !buffer_filling && !event_done) ||
								(state == CPWR_WRITE && !ctrl_out_full_q && !ctrl_empty_i) ||
								(state == EVWR_FIFO_ADDRESS_WAIT || state == CPWR_FIFO_ADDRESS_WAIT);
	
	always @(posedge CLK) begin
		if (phy_rst_o) begin
			fifo_select <= CTRL_INBOUND;
		end else if (state == IDLE) begin
			if (!delayed_evfull && event_write_pending) begin
				fifo_select <= EVENT_OUTBOUND;
			end else if (!ctrl_in_empty_q && !ctrl_full_i) begin
				fifo_select <= CTRL_INBOUND;
			end else if (!ctrl_out_full_q && ctrl_write_pending) begin
				fifo_select <= CTRL_OUTBOUND;
			end else begin
				fifo_select <= CTRL_INBOUND;
			end
		end
	end
	assign FIFOADR = fifo_select;
	
	reg event_data_req_reg = 0;
	always @(posedge CLK) begin
		if (phy_rst_o) event_data_req_reg <= 0;
		else begin
			if ((state == IDLE) && (!delayed_evfull && event_write_pending))
				event_data_req_reg <= 1;
			else if (state == DONE || buffer_filling)
				event_data_req_reg <= 0;
		end
	end
	assign event_data_req = (event_data_req_reg && !buffer_filling);

	reg event_frame_done_reg = 0;
	always @(posedge CLK) begin
		if (state == EVWR_WRITE && (event_out_full_q || event_done))
			event_frame_done_reg <= 1;
		else
			event_frame_done_reg <= 0;
	end
	
	reg [7:0] outbound_data = {8{1'b0}};
	always @(posedge CLK) begin
		if (state == EVWR_FIFO_ADDRESS_WAIT || state == EVWR_WRITE)
			outbound_data <= event_data;
		else if (state == CPWR_FIFO_ADDRESS_WAIT || state == CPWR_WRITE)
			outbound_data <= ctrl_dat_i;
	end
	assign fx2_fd_out = outbound_data;
	
	assign ctrl_wr_o = (state == CPRD_READ && !ctrl_full_i);
	assign ctrl_rd_o = ((state == CPWR_WRITE || state == CPWR_FIFO_ADDRESS_WAIT) 
							 && !ctrl_out_full_q);
	assign ctrl_dat_o = fx2_fd_q;	
	
	// This is the bidirectional data bus, delayed by one cycle.
	assign debug_o[7:0] = (sloe_reg) ? fx2_fd_q : fx2_fd_out;
	// This is just stupidly overcomplicated.
	assign debug_o[8] = ctrl_in_empty_q;
	assign debug_o[9] = event_out_full_q;
	assign debug_o[10] = slrd_enable;
	assign debug_o[11] = slwr_enable;
	assign debug_o[12] = pktend_enable;
	assign debug_o[13 +: 4] = state;
	assign debug_o[52:17] = event_debug;
	
endmodule
 