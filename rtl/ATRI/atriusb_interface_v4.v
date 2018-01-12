`timescale 1ns / 1ps

`include "ev2_interface.vh"
module atriusb_interface_v4(
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
	
	
	// Event readout, version 4. This version basically just
	// streams an event through the USB interface.

	//% Data to the FX2 bridge.
	wire [7:0] event_data;
	//% Access request.
	wire event_write_request;
	//% Access grant.
	reg event_write_grant = 0;
	//% Event write end.
	wire event_write_end;
	//% Event write packet end.
	reg event_write_pktend = 0;
	//% Event write packet end seen.
	reg event_write_pktend_seen = 0;
	//% Event SLWR.
	reg event_slwr_enable = 0;
	//% Debug.
	wire [34:0] event_debug;
	
	
	
	//% Event readout, version 4.  //FIXME: This is replaced by the PCIE interface.
//	atriusb_event_readout_v4 #(.EVENT_FIFO(EVENT_FIFO)) event_readout(.rst_req_i(rst_i),
//														.rst_ack_o(rst_ack_o),
//														.irs_clk_i(irsclk_i),
//														.phy_clk_i(CLK),
//														.fifo_dat_i(dat_i),
//														.fifo_nwords_o(count_o),
//														.fifo_wr_i(wr_i),
//														.fifo_full_o(full_o),
//														
//														.bridge_dat_o(event_data),
//														.bridge_request_o(event_write_request),
//														.bridge_grant_i(event_write_grant),
//														.bridge_end_o(event_write_end),
//
//														.debug_o(event_debug)
//														);
	
	// The ATRI USB interface is moderately straightforward.
	wire [7:0] fx2_fd_out;
	wire [7:0] fx2_fd_in;
	wire [7:0] fx2_fd_to_ff;
	wire [7:0] fx2_ff_to_fd;
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

			// Use both ILOGIC and OLOGIC to make the timing rigid.
			(* IOB = "TRUE" *) FDE fdo_ff(.D(fx2_fd_out[fd_i]),.CE(1'b1),.C(CLK),.Q(fx2_ff_to_fd[fd_i]));
			IOBUF fd_iobuf(.IO(FD[fd_i]),.O(fx2_fd_to_ff[fd_i]),.I(fx2_ff_to_fd[fd_i]),.T(sloe_reg));
			(* IOB = "TRUE" *) FDE fdi_ff(.D(fx2_fd_to_ff[fd_i]),.CE(fx2_fd_ce),.C(CLK),.Q(fx2_fd_q[fd_i]));
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

	reg ctrl_packet_done = 0;
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(26);
	//% Nothing to do.
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% Event write requested, space available. After grant we have 3 more clocks to wait for data.
	localparam [FSM_BITS-1:0] EVWR_GRANT = 1;
	//% Wait 1.
	localparam [FSM_BITS-1:0] EVWR_WAIT_1 = 2;
	//% Wait 2.
	localparam [FSM_BITS-1:0] EVWR_WAIT_2 = 3;
	//% Now data is valid. Latch it into the demux, and assert FIFO address.
	localparam [FSM_BITS-1:0] EVWR_FIFO_ADDRESS = 4;
	//% Wait for the FIFO address to settle. Demux data to IOB is valid. Input to SLWR IOB is valid.
	localparam [FSM_BITS-1:0] EVWR_FIFO_ADDRESS_WAIT = 5;
	//% And now data appears on FD.
	localparam [FSM_BITS-1:0] EVWR_WRITE = 6;
	//% Write is finishing, 1. Input to SLWR IOB is 0.
	localparam [FSM_BITS-1:0] EVWR_FINISH_1 = 7;
	//% Write is finishing, 2. SLWR is 0. pktend_enable is 1.
	localparam [FSM_BITS-1:0] EVWR_FINISH_2 = 8;
	//% Write is complete. Assert PKTEND if it was seen.
	localparam [FSM_BITS-1:0] EVWR_FINISH_3 = 9;
	localparam [FSM_BITS-1:0] CPWR_FIFO_ADDRESS = 10;
	localparam [FSM_BITS-1:0] CPWR_FIFO_ADDRESS_WAIT = 11;
	localparam [FSM_BITS-1:0] CPWR_WRITE = 12;
	localparam [FSM_BITS-1:0] CPWR_WRITE_PAUSE = 13;
	localparam [FSM_BITS-1:0] CPRD_FIFO_ADDRESS = 14;
	localparam [FSM_BITS-1:0] CPRD_FIFO_ADDRESS_WAIT = 15;
	localparam [FSM_BITS-1:0] CPRD_SLRD_ENABLE = 16;
	localparam [FSM_BITS-1:0] CPRD_READ_WAIT = 17;
	localparam [FSM_BITS-1:0] CPRD_READ = 18;
	localparam [FSM_BITS-1:0] CPRD_READ_PAUSE = 19;
	localparam [FSM_BITS-1:0] CPRD_READ_RESUME = 20;
	localparam [FSM_BITS-1:0] CPWR_FINISH_1 = 21;
	localparam [FSM_BITS-1:0] DONE = 22;
	localparam [FSM_BITS-1:0] WAIT_PKTEND_1 = 23;
	localparam [FSM_BITS-1:0] WAIT_PKTEND_2 = 24;
	reg [FSM_BITS-1:0] state = {FSM_BITS{1'b0}};
	
	always @(posedge CLK) begin
		if (phy_rst_o) state <= IDLE;
		else begin
			case (state)
				IDLE: if (!event_out_full_q && event_write_request) state <= EVWR_GRANT;
				 else if (ctrl_write_pending && !ctrl_out_full_q) state <= CPWR_FIFO_ADDRESS;
				 else if (!ctrl_in_empty_q && !ctrl_full_i) state <= CPRD_FIFO_ADDRESS;
				EVWR_GRANT: state <= EVWR_WAIT_1;
				EVWR_WAIT_1: state <= EVWR_WAIT_2;
				EVWR_WAIT_2: state <= EVWR_FIFO_ADDRESS;
				EVWR_FIFO_ADDRESS: state <= EVWR_FIFO_ADDRESS_WAIT;
				EVWR_FIFO_ADDRESS_WAIT: state <= EVWR_WRITE;
				// At this point, event_write_request has been low for 1 cycle.
				// That means we currently have the next-to-last data on FD.
				// So SLWR_ENABLE needs to be LOW in EVWR_FINISH_1.
				EVWR_WRITE: if (!event_write_request) state <= EVWR_FINISH_1;
				EVWR_FINISH_1: state <= EVWR_FINISH_2;
				EVWR_FINISH_2: state <= EVWR_FINISH_3;
				EVWR_FINISH_3: state <= IDLE;
				// Latch data into outbound_data here.
				CPWR_FIFO_ADDRESS: state <= CPWR_FIFO_ADDRESS_WAIT;
				CPWR_FIFO_ADDRESS_WAIT: state <= CPWR_WRITE;
				// NOTE NOTE NOTE: NEED TO DO SOMETHING HERE TO PREVENT TRYING TO WRITE
				// OUTBOUND PACKETS GREATER THAN 512, CUZ THEN IT JUST KEEPS TRYING TO
				// WRITE

				// OKAY SCREW THIS CRAP. We're going to stay in CPWR_WRITE until we're told to leave.
				// CPWR's SLWR enable will get set by ctrl_rd_o. When ctrl_rd_o is asserted,
				// data gets latched to outbound_data at next clock edge. So slwr_enable goes high
				// next clock edge, and then outbound data gets latched to FD on next clock edge,
				// and SLWR goes high same clock edge. When ctrl_rd_o goes low, it's because empty was
				// asserted in the previous cycle. New data is still available. 
				// rd ctrldat 				slwr_en slwr outbound fd
				// 1  <0>     					0       1    X        X
				// 1  <1>     					1       1    <0>      X
				// 1  <2>     					1       0    <1>      <0>
				// 0  <2>     					1       0    <2>      <1>
				// 0  <3>     					0       0    <2>      <2>
				// 1  <3>			         0 		  1    <2>      X
				// 1  <4>						1		  1    <3>      X
				// 1  <5>                  1		  0	 <4>      <3>
				//
				// The worst case, a single-cycle drop, is
				// rd ctrldat 				slwr_en slwr outbound fd
				// 1  <0>     					0       1    X        X
				// 1  <1>     					1       1    <0>      X
				// 1  <2>     					1       0    <1>      <0>
				// 0  <3>     					1       0    <2>      <1>
				// 1  <3>     					0       0    <2>      <2>
				// 1  <4>						1		  1    <3>      X
				// 1  <5>                  1		  0	 <4>      <3>
				// Then packet end is signaled by:
				// rd ctrldat 	cpdone	slwr_en slwr outbound fd     packet_i
				// 1  <0>     		0			0       1    X        X   0  WRITE
				// 1  <1>     		0			1       1    <0>      X   0  WRITE
				// 1  <2>     		0			1       0    <1>      <0> 1  WRITE
				// 0  <2>			1			1		  0    <2>		 <1> 0  WRITE
				// 0  <2>         1        0       0    x        <2> 0  WRITE_FINISH_1
				// 0  <2>         1        0       1    x        X   0  DONE (cpwr_pktend goes high, cpdone clears)
				CPWR_WRITE: if (ctrl_packet_done) state <= CPWR_FINISH_1;
				CPRD_FIFO_ADDRESS: state <= CPRD_FIFO_ADDRESS_WAIT;
				CPRD_FIFO_ADDRESS_WAIT: state <= CPRD_SLRD_ENABLE;
				CPRD_SLRD_ENABLE: state <= CPRD_READ_WAIT;
				CPRD_READ_WAIT: state <= CPRD_READ;
				CPRD_READ: if (ctrl_in_empty_q) state <= DONE;
					   else if (ctrl_full_i) state <= CPRD_READ_PAUSE;
				CPRD_READ_PAUSE: if (!ctrl_full_i) state <= CPRD_READ_RESUME;
								else if (ctrl_write_pending) state <= IDLE;
				CPRD_READ_RESUME: state <= CPRD_READ;
				CPWR_FINISH_1: state <= DONE;
				DONE: state <= WAIT_PKTEND_1;
				// pktend gets asserted in DONE: so we wait two clocks to allow it to
				// be asserted. Otherwise FIFOADR jumps back to 0 and we never see the PKTEND
				// because it's set for CTRL_INBOUND.
				WAIT_PKTEND_1: state <= WAIT_PKTEND_2;
				WAIT_PKTEND_2: state <= IDLE;
			endcase
		end
	end

	always @(posedge CLK) begin : EVWR_GRANT_LOGIC
		if (!event_write_request) event_write_grant <= 0;
		else if (state == EVWR_GRANT) event_write_grant <= 1;
	end
	
	always @(posedge CLK) begin
		if (state == EVWR_GRANT) event_write_pktend_seen <= 0;
		else if (event_write_end) event_write_pktend_seen <= 1;
	end
	
	// Flag packet end in EVWR_FINISH_1: it then becomes 1 in EVWR_FINISH_2
	always @(posedge CLK) begin
		event_write_pktend <= (state == EVWR_FINISH_1 && (event_write_pktend_seen || event_write_end));
	end
	
	always @(posedge CLK) begin
		if (phy_rst_o || (state == EVWR_WRITE && !event_write_request)) event_slwr_enable <= 0;
		else if (state == EVWR_FIFO_ADDRESS) event_slwr_enable <= 1;
	end
	
	//% Logic for SLOE. Directly connects to the T input of the IOBUF and SLOE's output.
	always @(posedge CLK) begin : SLOE_LOGIC
		if (state == IDLE) sloe_reg <= 1;
		else if (state == EVWR_FIFO_ADDRESS || state == CPWR_FIFO_ADDRESS) sloe_reg <= 0;
	end

	// Logic for generating PKTEND.
	wire pktend;

	reg cpwr_pktend = 0;
	always @(posedge CLK) begin
		if (state == DONE) ctrl_packet_done <= 0;
		else if (ctrl_empty_i && ctrl_packet_i && ctrl_read) ctrl_packet_done <= 1;
	end
	always @(posedge CLK) begin 
		cpwr_pktend <= (state == DONE) && ctrl_packet_done;
	end
	assign pktend = cpwr_pktend || event_write_pktend;
	
	// Logic for generating control packet SLWR.
	reg cpwr_slwr_enable = 0;
	always @(posedge CLK) begin
		cpwr_slwr_enable <= ctrl_rd_o;
/*
		if (phy_rst_o || (state == CPWR_WRITE && ctrl_empty_i)) cpwr_slwr_enable <= 0;
		// Goes high in CPWR_RESUME, so SLWR high again in CPWR_WRITE
		else if (state == CPWR_FIFO_ADDRESS || (state == CPWR_WRITE_PAUSE && !ctrl_empty_i)) 
			cpwr_slwr_enable <= 1;
*/
	end
	//% Clock enable for the FD inputs.
	assign fx2_fd_ce = (state == CPRD_READ_WAIT || state == CPRD_READ);
	//% Clock enable for the SLRD output.
	assign slrd_enable = (state == CPRD_SLRD_ENABLE || state == CPRD_READ_WAIT || state == CPRD_READ || state == CPRD_READ_RESUME);
	//% Clock enable for PKTEND. Only goes high when we complete a write.
	assign pktend_enable = pktend;
	//% Clock enable for SLWR.
	assign slwr_enable = event_slwr_enable || cpwr_slwr_enable;
		
	always @(posedge CLK) begin
		if (phy_rst_o) begin
			fifo_select <= CTRL_INBOUND;
		end else if (state == IDLE) begin
			if (!event_out_full_q && event_write_request) begin
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
	
	reg [7:0] outbound_data = {8{1'b0}};
	always @(posedge CLK) begin
		if (state == EVWR_FIFO_ADDRESS || state == EVWR_FIFO_ADDRESS_WAIT || state == EVWR_WRITE)
			outbound_data <= event_data;
		else 
			outbound_data <= ctrl_dat_i;
	end
	reg ctrl_read = 0;
	always @(posedge CLK) begin
		if (state == IDLE) begin
			if ((ctrl_write_pending && !ctrl_out_full_q) && !((!event_out_full_q && event_write_request)))
				ctrl_read <= 1;
		end else if (ctrl_empty_i && ctrl_packet_i) ctrl_read <= 0;
	end			 
	
	assign fx2_fd_out = outbound_data;
	
	assign ctrl_wr_o = (state == CPRD_READ && !ctrl_full_i);
	assign ctrl_rd_o = ctrl_read && !ctrl_empty_i;
	assign ctrl_dat_o = fx2_fd_q;	
	
	// This is the bidirectional data bus, delayed by one cycle.
	assign debug_o[7:0] = (sloe_reg) ? fx2_fd_q : fx2_fd_out;
	// This is just stupidly overcomplicated.
	assign debug_o[8] = ctrl_in_empty_q;
	assign debug_o[9] = event_out_full_q;
	assign debug_o[10] = slrd_enable;
	assign debug_o[11] = slwr_enable;
	assign debug_o[12] = pktend_enable;
	assign debug_o[13 +: 5] = state;
//	assign debug_o[52:18] = event_debug;	//THM: comment
//Modified by THM to understand the mechanism:
	assign debug_o[52:37] = dat_i;
	assign debug_o[36:21] = count_o;
	assign debug_o[20] = wr_i;
	assign debug_o[19] = full_o;
	assign debug_o[18] = rst_ack_o;
//	assign debug_o[17] = rst_i;
	

endmodule
