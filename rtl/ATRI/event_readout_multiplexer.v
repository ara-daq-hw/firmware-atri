`timescale 1ns / 1ps
`include "ev_interface.vh"

//% @brief Multiplexes 4 event readout interfaces.
//%
//% event_readout_multiplexer takes the 4 event readouts from the irs_tops and
//% multiplexes them into a single stream. This is all done outside of the atri_core
//% module because event readout is part of the PHY interface: the atri_core irs_tops
//% just have an event_interface_io bus, and it's the PHY's job to get the data out.
module event_readout_multiplexer(
		inout [`EVIF_SIZE-1:0] d1_interface_io,
		inout [`EVIF_SIZE-1:0] d2_interface_io,
		inout [`EVIF_SIZE-1:0] d3_interface_io,
		inout [`EVIF_SIZE-1:0] d4_interface_io,
		inout [`EVIF_SIZE-1:0] mx_interface_io,
		output [47:0] debug_o
    );

	parameter NUM_DAUGHTERS = 4;
	wire [3:0] fifo_clk_i;
	wire [3:0] irs_clk_i;
	wire [3:0] fifo_empty_i;
	wire [3:0] fifo_rd_o;
	wire [15:0] dat_i[3:0];
	wire [1:0] type_i[3:0];
	wire [3:0] rst_req_i;
	wire [3:0] rst_ack_o;
	wire [3:0] prog_empty;
	wire [15:0] fifo_nwords[3:0];
	wire [3:0] fifo_block_done_o = {4{1'b0}};
	wire [`EVIF_SIZE-1:0] ev_interface[3:0];
	event_interface_fifo_reassign d1(d1_interface_io, ev_interface[0]);
	event_interface_fifo_reassign d2(d2_interface_io, ev_interface[1]);
	event_interface_fifo_reassign d3(d3_interface_io, ev_interface[2]);
	event_interface_fifo_reassign d4(d4_interface_io, ev_interface[3]);
	
	generate
		genvar i;
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin : MX_IF
			event_interface_rdout evif(.interface_io(ev_interface[i]),
										.fifo_clk_o(fifo_clk_i[i]),.irs_clk_o(irs_clk_i[i]),
										.fifo_empty_o(fifo_empty_i[i]),.prog_empty_o(prog_empty[i]),
										.fifo_rd_i(fifo_rd_o[i]),
										.fifo_block_done_i(fifo_block_done_o[i]),
										.fifo_nwords_o(fifo_nwords[i]),
										.dat_o(dat_i[i]),
										.type_o(type_i[i]),
										.rst_req_o(rst_req_i[i]),
										.rst_ack_i(rst_ack_o[i]));
//			flag_sync read_sync(.clkA(irs_clk_i[i]),.clkB(fifo_clk_i[i]),.in_clkA(read_done_i[i]),
//										.out_clkB(read_done_fifo_clk[i]));
		end 
	endgenerate

	// assigned from daughter 1 (all the same anyway)
	wire mx_fifo_clk_o;
	// unused
	wire mx_irs_clk_i;
	// unused
	wire mx_full_o = 0;
	// multiplexed based on fifo select
	wire mx_empty_o;
	// unused
	wire mx_wr_i;
	// demuxed based on fifo select
	wire mx_rd_i;
	// commoned to all
	wire mx_rst_ack_i;
	// unused
	wire [15:0] mx_dat_i;
	wire [1:0] mx_type_i;
	// muxed based on fifo select
	wire [15:0] mx_dat_o;
	wire [1:0] mx_type_o;
	wire [15:0] mx_fifo_nwords_o;
	wire mx_rst_req_o;			// this is muxed, but they all occur at the same time.

	// used to determine multiplexer switching
	wire mx_block_done_i;
	reg mx_block_done_hold = 0;

	// insert the IRS-side signals to the muxed interface
	wire mxirs_fifo_clk_i;
	wire mxirs_irs_clk_o = 0;
	wire mxirs_fifo_full_i;
	wire mxirs_fifo_wr_o = 0;
	wire mxirs_prog_empty_o;
	wire [15:0] mxirs_dat_o = {16{1'b0}};
	wire [1:0] mxirstype_o = {2{1'b0}};
	event_interface_irs evif(.interface_io(mx_interface_io),
								  .irs_clk_i(mxirs_irs_clk_o),
								  .fifo_full_o(mxirs_fifo_full_i),
								  .fifo_wr_i(mxirs_fifo_wr_o),
								  .type_i(mxirstype_o),
								  .dat_i(mxirs_dat_o),
								  .rst_ack_o(mx_rst_ack_i),
								  .rst_req_i(mx_rst_req_o));

	event_interface_fifo mx_if(.interface_io(mx_interface_io),
									.fifo_clk_i(mx_fifo_clk_o),.irs_clk_o(mx_irs_clk_i),
									.fifo_empty_i(mx_empty_o),.fifo_full_i(mx_full_o),
									.prog_empty_i(mxirs_prog_empty_o),
									.fifo_wr_o(mx_wr_i),.fifo_rd_o(mx_rd_i),
									.dat_o(mx_dat_i),.dat_i(mx_dat_o),
									.fifo_nwords_i(mx_fifo_nwords_o),
									.type_o(mx_type_i),.type_i(mx_type_o),
									.fifo_block_done_o(mx_block_done_i));
	
	wire clk_i = fifo_clk_i[0];
	assign mx_fifo_clk_o = clk_i;

	wire mx_block_done_hold_clear;

	always @(posedge clk_i) begin
		if (mx_block_done_hold_clear)
			mx_block_done_hold <= 0;
		else if (mx_block_done_i)
			mx_block_done_hold <= 1;
	end

	wire [3:0] read_acknowledge;
/*	
	reg [3:0] read_pending = {4{1'b0}};
	integer j;
	always @(posedge clk_i) begin
		for (j=0;j<NUM_DAUGHTERS;j=j+1) begin
			if (read_acknowledge[j])
				read_pending[j] <= 0;
			else if (read_done_fifo_clk[j])
				read_pending[j] <= 1;
		end
	end
*/
	
	localparam FSM_BITS = 4;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] FIFO_SELECT_D1 = 1;
	localparam [FSM_BITS-1:0] FIFO_SELECT_D2 = 2;
	localparam [FSM_BITS-1:0] FIFO_SELECT_D3 = 3;
	localparam [FSM_BITS-1:0] FIFO_SELECT_D4 = 4;
	localparam [FSM_BITS-1:0] ACK_D1 = 5;
	localparam [FSM_BITS-1:0] ACK_D2 = 6;
	localparam [FSM_BITS-1:0] ACK_D3 = 7;
	localparam [FSM_BITS-1:0] ACK_D4 = 8;
	reg [FSM_BITS-1:0] state = IDLE;
	
	assign read_acknowledge[0] = (state == ACK_D1);
	assign read_acknowledge[1] = (state == ACK_D2);
	assign read_acknowledge[2] = (state == ACK_D3);
	assign read_acknowledge[3] = (state == ACK_D4);
	// This doesn't really act like prog_empty...
	assign mxirs_prog_empty_o = !(read_acknowledge != {4{1'b0}});
	
	reg [15:0] muxed_nwords = {16{1'b0}};
	reg [15:0] muxed_data = {16{1'b0}};
	reg [1:0] muxed_type = {2{1'b0}};
	reg muxed_empty = 0;
	reg muxed_reset_request = 0;
	// For the default case, the "empty" being 1 is important.
	// It means that empty is only reported to the readout AFTER
	// we are in the correct mux state. Otherwise Odd Things Happen.
	always @(*) begin
		if (state == FIFO_SELECT_D1) begin
			muxed_data <= dat_i[0];
			muxed_type <= type_i[0];
			muxed_empty <= fifo_empty_i[0];
			muxed_nwords <= fifo_nwords[0];
			muxed_reset_request <= rst_req_i[0];
		end else if (state == FIFO_SELECT_D2) begin
			muxed_data <= dat_i[1];
			muxed_type <= type_i[1];
			muxed_empty <= fifo_empty_i[1];
			muxed_nwords <= fifo_nwords[1];
			muxed_reset_request <= rst_req_i[1];
		end else if (state == FIFO_SELECT_D3) begin
			muxed_data <= dat_i[2];
			muxed_type <= type_i[2];
			muxed_empty <= fifo_empty_i[2];
			muxed_nwords <= fifo_nwords[2];
			muxed_reset_request <= rst_req_i[2];
		end else if (state == FIFO_SELECT_D4) begin
			muxed_data <= dat_i[3];
			muxed_type <= type_i[3];
			muxed_empty <= fifo_empty_i[3];
			muxed_nwords <= fifo_nwords[3];
			muxed_reset_request <= rst_req_i[3];
		end else begin
			muxed_data <= dat_i[0];
			muxed_type <= type_i[0];
			muxed_empty <= 1'b1;
			muxed_nwords <= fifo_nwords[0];
			muxed_reset_request <= rst_req_i[0];
		end
	end
	assign mx_empty_o = muxed_empty;
	assign mx_dat_o = muxed_data;
	assign mx_type_o = muxed_type;
	assign mx_fifo_nwords_o = muxed_nwords;
	assign mx_rst_req_o = muxed_reset_request;
	
	assign fifo_rd_o[0] = (state == FIFO_SELECT_D1) && mx_rd_i;
	assign fifo_rd_o[1] = (state == FIFO_SELECT_D2) && mx_rd_i;
	assign fifo_rd_o[2] = (state == FIFO_SELECT_D3) && mx_rd_i;
	assign fifo_rd_o[3] = (state == FIFO_SELECT_D4) && mx_rd_i;

	assign rst_ack_o = {mx_rst_ack_i,mx_rst_ack_i,mx_rst_ack_i,mx_rst_ack_i};
	
	always @(posedge clk_i) begin
		if (mx_rst_ack_i)
			state <= IDLE;
		else begin
			case (state)
				IDLE: begin
					if (!fifo_empty_i[0]) state <= ACK_D1;
	/*
					else if (read_pending[1]) state <= ACK_D2;
					else if (read_pending[2]) state <= ACK_D3;
					else if (read_pending[3]) state <= ACK_D4;
	*/
				end
				FIFO_SELECT_D1: begin
					if (mx_block_done_i || mx_block_done_hold) begin
						if (NUM_DAUGHTERS > 1) begin
							if (!fifo_empty_i[1]) state <= ACK_D2;
						end
	/*
						else if (read_pending[2]) state <= ACK_D3;
						else if (read_pending[3]) state <= ACK_D4;
						else if (read_pending[0]) state <= ACK_D1;
	*/
						else state <= IDLE;
					end
				end
				FIFO_SELECT_D2: begin
					if (mx_block_done_i || mx_block_done_hold) begin
						if (NUM_DAUGHTERS > 2) begin
							if (!fifo_empty_i[2]) state <= ACK_D3;
						end
	/*
						else if (read_pending[3]) state <= ACK_D4;
						else if (read_pending[0]) state <= ACK_D1;
						else if (read_pending[1]) state <= ACK_D2;
	*/
						else state <= IDLE;
					end
				end
				FIFO_SELECT_D3: begin
					if (mx_block_done_i || mx_block_done_hold) begin
						if (NUM_DAUGHTERS > 3) begin
							if (!fifo_empty_i[3]) state <= ACK_D4;
						end
	/*
						else if (read_pending[0]) state <= ACK_D1;
						else if (read_pending[1]) state <= ACK_D2;
						else if (read_pending[2]) state <= ACK_D3;
	*/
						else state <= IDLE;
					end
				end
				FIFO_SELECT_D4: begin
					if (mx_block_done_i || mx_block_done_hold) begin
	/*
						if (read_pending[0]) state <= ACK_D1;
						else if (read_pending[1]) state <= ACK_D2;
						else if (read_pending[2]) state <= ACK_D3;
						else if (read_pending[3]) state <= ACK_D4;
						else 
	*/
						state <= IDLE;
					end
				end
				ACK_D1: state <= FIFO_SELECT_D1;
				ACK_D2: state <= FIFO_SELECT_D2;
				ACK_D3: state <= FIFO_SELECT_D3;
				ACK_D4: state <= FIFO_SELECT_D4;
				default: state <= IDLE;
			endcase
		end
	end
	
	assign mx_block_done_hold_clear = (state == ACK_D1 || state == ACK_D2 || state == ACK_D3 || state == ACK_D4);

	assign debug_o[3:0] = state;
	assign debug_o[7:4] = fifo_empty_i;
	assign debug_o[15:8] = muxed_nwords[13:6];
endmodule
