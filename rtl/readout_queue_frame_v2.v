`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Replacement readout queue frame.
//////////////////////////////////////////////////////////////////////////////////
module readout_queue_frame_v2
#(
		parameter n_triggers = 3,
		parameter TRIG_WIDTH = n_triggers + 1,
		parameter BLOCK_WIDTH = 9,
		parameter TIMESTAMP_WIDTH = 15,
		parameter RADDR_WIDTH = TIMESTAMP_WIDTH + BLOCK_WIDTH + TRIG_WIDTH,
		parameter RB_WIDTH = 35
)
    (
		input clk,
		input reset,
		input [RADDR_WIDTH-1:0] read_address_from_readout_comm,
		input wea_from_readout_comm,
		output [RB_WIDTH-1:0] read_block_to_irs_block_readout,
		output read_strobe_to_irs_block_readout,
		output read_remaining_to_irs_block_readout,
		output read_remaining_strobe_to_irs_block_readout,
		input read_done_from_irs_block_readout,
		output [BLOCK_WIDTH-1:0] free_address_to_irs_block_manager,
		output [2:0] state_rdout_queue_debug_o
    );
 
	localparam BRAM_ADDR_WIDTH = 9;
	localparam BRAM_DATA_WIDTH = 36;

	reg [BRAM_ADDR_WIDTH-1:0] address_a = {BRAM_ADDR_WIDTH{1'b0}};
	reg [BRAM_ADDR_WIDTH-1:0] address_b = {BRAM_ADDR_WIDTH{1'b0}};	
	reg [RADDR_WIDTH-1:0] read_address_hold = {RADDR_WIDTH{1'b0}};

	wire [BRAM_DATA_WIDTH-1:0] dout_a;
	wire [BRAM_DATA_WIDTH-1:0] dout_b;

	assign read_block_to_irs_block_readout = dout_b[RB_WIDTH-1:0];
	assign free_address_to_irs_block_manager = dout_b[BLOCK_WIDTH-1:0];
	// RADDR_WIDTH is 28 currently
	// 36-1-28 = 7
	// so 28 bits + 7 filler bits + 1 bit is 36 bits
	wire [BRAM_DATA_WIDTH:0] din_a = {1'b1, wea_from_readout_comm, {36-2-RADDR_WIDTH{1'b0}}, read_address_hold}; //possibly error: BRAM_DATA_WIDTH-1!
	wire [BRAM_DATA_WIDTH:0] din_b = {36{1'b0}};

	reg [1:0] wea_from_readout_comm_delayed = 0;
	always @(posedge clk) begin
		wea_from_readout_comm_delayed <= {wea_from_readout_comm_delayed[0], wea_from_readout_comm};
	end
	wire we_a = wea_from_readout_comm_delayed[1];
	wire we_b;

	always @(posedge clk) begin
		if (wea_from_readout_comm)
			read_address_hold <= read_address_from_readout_comm;
	end

	// Stop collisions.
	wire port_b_holdoff = (address_a == address_b) && we_a;
	
	RAMB16_S36_S36 simple_buffer(
					.DIA(din_a[31:0]),
					.DIPA(din_a[35:32]),
					.DOA(dout_a[31:0]),
					.DOPA(dout_a[35:32]),
					.DOB(dout_b[31:0]),
					.DOPB(dout_b[35:32]),
					.DIB(din_b[31:0]),
					.DIPB(din_b[35:32]),
					.ENA(1'b1),
					.ENB(!port_b_holdoff),
					.WEA(we_a),
					.WEB(we_b),
					.SSRA(1'b0),
					.SSRB(1'b0),
					.CLKA(clk),
					.CLKB(clk),
					.ADDRA(address_a),
					.ADDRB(address_b));
	
	always @(posedge clk) begin
		if (reset) begin
			address_a <= {BRAM_ADDR_WIDTH{1'b0}};
		end else if (we_a) begin
			address_a <= address_a + 1;
		end 
	end

	reg was_reset = 0;
	always @(posedge clk) begin
		was_reset <= reset;
	end
	
	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(4);
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] STROBE = 1;
	localparam [FSM_BITS-1:0] WAIT = 2;
	localparam [FSM_BITS-1:0] CLR_AND_INCREMENT = 3;
	localparam [FSM_BITS-1:0] READ_DELAY = 4;
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge clk) begin
		if (reset || was_reset)
			state <= IDLE;
		else begin
			case (state)
				IDLE: if (dout_b[35]) state <= STROBE;
				STROBE: state <= WAIT;
				WAIT: if (read_done_from_irs_block_readout) state <= CLR_AND_INCREMENT;
				CLR_AND_INCREMENT: state <= READ_DELAY;
				READ_DELAY: state <= IDLE;
				default: state <= IDLE;
			endcase
		end
	end
	

	assign we_b = (state == CLR_AND_INCREMENT) || was_reset;
	assign read_strobe_to_irs_block_readout = (state == STROBE);
	assign read_remaining_strobe_to_irs_block_readout = (state == STROBE);
	assign read_remaining_to_irs_block_readout = (dout_b[34]);

	always @(posedge clk) begin
		if (reset)
			address_b <= {BRAM_ADDR_WIDTH{1'b0}};
		else if (state == CLR_AND_INCREMENT) 
			address_b <= address_b + 1;
	end
	assign state_rdout_queue_debug_o = state;
	
endmodule
