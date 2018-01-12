`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Massively cleaned up version of the IRS block readout.
//
// The IRS block readout *only* handles the data readout from an IRS.
// It is partitioned into several sections: the read block selection,
// Wilkinson conversion, and then data readout. 
//
// The output data is just a 1024-word FIFO interface.
//////////////////////////////////////////////////////////////////////////////////
module irs_block_readout_v3(
		input clk_i,						//% Clock input
		input rst_i,						//% Reset input.
		output rst_ack_o,					//% Reset acknowledgement.
		input test_mode_i,				//% Bypass data inputs (replace with STACK,CH,SMP)

		input [5:0] station_i,			//% Station ID. Programmable by WISHBONE.
		
		input [8:0] raddr_i, 			//% Read address input
		input raddr_stb_i,				//% Read address strobe (to begin readout)
		output raddr_ack_o,				//% Read address acknowledge (not readout complete)
		
		input [7:0] ch_mask_i, 			//% Readout channel mask.
		input irs_mode_i,					//% IRS readout mode. (IRS1-2 or IRS3)
		
		output [15:0] irs_dat_o,		//% Data output (FIFO).
		output irs_valid_o,				//% Data output is valid.
		output irs_empty_o,				//% FIFO empty.
		input  irs_rd_i,					//% Read strobe.
		output irs_err_o, 				//% Error has occurred (FIFO full). Shouldn't happen.
		
		output [9:0] irs_rd_o, 			//% IRS1-2 RD lines. IRS3 control signals.
		output irs_rden_o,				//% Read enable.
		output [5:0] irs_smp_o,			//% Sample select.
		output [2:0] irs_ch_o,			//% Channel select.
		output irs_smpall_o,				//% Output enable.
		input  [11:0] irs_dat_i,		//% Data from IRS.
		
		output irs_start_o,				//% Wilkinson counter start.
		output irs_clr_o,					//% Wilkinson counter clear.
		output irs_ramp_o,				//% Wilkinson counter ramp control.

		// State outputs.
		output irs_address_sel_o,		//% Block readout in address selection
		output irs_ramping_o,			//% Block readout in Wilkinson ramp
		output irs_readout_o,			//% Block readout in data readout stage
		output irs_busy_o,				//% Set when we receive an strobe, cleared when we're done writing.
		output [47:0] debug_o			//% Debugging outputs.
    );

	parameter [1:0] STACK_NUMBER = 0;

	`include "clogb2.vh"
	localparam FSM_BITS = clogb2(7);
	//% In reset.
	localparam [FSM_BITS-1:0] RESET = 0;
	//% Out of reset, waiting for acknowledgement from ramp and address select modules.
	localparam [FSM_BITS-1:0] RESET_WAIT  = 1;
	//% Idle.
	localparam [FSM_BITS-1:0] IDLE = 2;
	//% Received "raddr_stb_i". Waiting for address selector module to acknowledge.
	localparam [FSM_BITS-1:0] ADDRESS = 3;
	//% Received address selected acknowledgement. Waiting for clear acknowledgement from Ramp module.
	localparam [FSM_BITS-1:0] CLEAR = 4;
	//% Received clear acknowledgement. Waiting for ramp complete acknowledgement.
	localparam [FSM_BITS-1:0] RAMP = 5;
	//% Received ramp complete acknowledgement. Wait for readout complete acknowledgement.
	localparam [FSM_BITS-1:0] READOUT = 6;
	//% Block readout is done.
	localparam [FSM_BITS-1:0] DONE = 7;
	//% State variable.
	reg [FSM_BITS-1:0] state = IDLE;

	//////////////////////////////////////////////////////////////
	//                                                          //
	// IRS Read Address control interface.                      //
	//                                                          //
	//////////////////////////////////////////////////////////////
	
	//% Signal from read address module that address has been reached.
	wire irs_raddr_ack;
	//% Signal to read address module that ramp has completed.
	wire irs_raddr_ramp_done;
	SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"),.LATENCY(1)) 
		irs_raddr_ramp_done_gen(.I(state == READOUT),.O(irs_raddr_ramp_done),.CLK(clk_i));
	//% Signal to read address module that a reset is requested.
	wire irs_raddr_reset = (state == RESET || state == RESET_WAIT);
	//% Signal from read address module that a reset is acknowledged.
	wire irs_raddr_reset_ack;
	//% IRS address outputs. Need to be remapped for IRS3.
	wire [8:0] irs_raddr_rd;

	//////////////////////////////////////////////////////////////
	//                                                          //
	// IRS Ramp Control module interface.                       //
	//                                                          //
	//////////////////////////////////////////////////////////////

	//% Signal to ramp control module to issue CLR.
	wire irs_ramp_clear = (state == CLEAR);
	//% Signal from ramp control module that CLR has been issued.
	wire irs_ramp_clear_ack;
	//% Signal to ramp control module to begin Wilkinson ramp.
	wire irs_ramp_start = (state == RAMP);
	//% Signal from ramp control module that ramp has completed.
	wire irs_ramp_ack;
	//% Signal to ramp module to reset.
	wire irs_ramp_reset = (state == RESET || state == RESET_WAIT);
	//% Signal from ramp control module that reset has been completed.
	wire irs_ramp_reset_ack;

	//////////////////////////////////////////////////////////////
	//                                                          //
	// IRS Readout module interface.                            //
	//                                                          //
	//////////////////////////////////////////////////////////////
		
	//% Header information.
	reg [15:0] header = {16{1'b0}};
	
	//% Write header.
	wire header_write;
	
	//% Block that is currently being converted and read out.
	reg [8:0] cur_block_address = {9{1'b0}};
	//% Mask for the current block.
	reg [7:0] cur_ch_mask = {8{1'b0}};

	//% Signal to readout module to begin the readout.
	wire irs_rdout_start = (state == READOUT);
	//% Signal from readout module that readout has completed.
	wire irs_rdout_ack;
	//% Signal to readout module to reset. No ack needed.
	wire irs_rdout_reset = (state == RESET);

	//% FSM logic. Note that we do NOT reset during a readout.
	always @(posedge clk_i) begin : FSM
		case (state)
			IDLE: if (rst_i) state <= RESET; else if (raddr_stb_i) state <= ADDRESS;
			ADDRESS: if (rst_i) state <= RESET; else if (irs_raddr_ack) state <= CLEAR;
			CLEAR: if (rst_i) state <= RESET; else if (irs_ramp_clear_ack) state <= RAMP;
			RAMP: if (rst_i) state <= RESET; else if (irs_ramp_ack) state <= READOUT;
			READOUT: if (irs_rdout_ack) state <= IDLE;
			RESET: state <= RESET_WAIT;
			RESET_WAIT: if (irs_ramp_reset_ack && irs_raddr_reset_ack && !rst_i) state <= IDLE;
			default: state <= IDLE;
		endcase
	end
	
	//% Header logic.
	always @(posedge clk_i) begin : HEADER_LOGIC
		if (state == CLEAR)
			header <= {station_i,STACK_NUMBER,~cur_ch_mask};
	end

	//% Generate the flag to write the header. No real reason why it's written at clear, mind you.
	SYNCEDGE #(.EDGE("RISING"),.LATENCY(1)) header_write_gen(.I(state==CLEAR),.O(header_write),.CLK(clk_i));
	
	//% Block address for *readout* is latched at ADDRESS.
	always @(posedge clk_i) begin : CUR_BLOCK_ADDRESS_LOGIC
		if (state == RESET) cur_block_address <= {9{1'b0}};
		else if (state == ADDRESS) cur_block_address <= raddr_i;
	end

	//% Channel mask for readout is latched at ADDRESS.
	always @(posedge clk_i) begin : CUR_CH_MASK_LOGIC
		if (state == RESET) cur_ch_mask <= {8{1'b0}};
		else if (state == ADDRESS) cur_ch_mask <= ch_mask_i;
	end

	//% Busy - a block conversion is in process.
	reg irs_busy = 0;
	
	//% Busy logic.
	always @(posedge clk_i) begin : BUSY_LOGIC
		if ((state == RESET) || irs_rdout_ack) irs_busy <= 0;
		else if (raddr_stb_i) irs_busy <= 1;
	end
	
	//////////////////////////////////////////////////////////////
	//                                                          //
	// Modules																	//
	//                                                          //
	//////////////////////////////////////////////////////////////

	//% Address selector module.
	irs_block_readout_addr_v3 address_selector(.clk_i(clk_i),
															 .rst_i(irs_raddr_reset),
															 .rst_ack_o(irs_raddr_reset_ack),
															 
															 .irs_mode_i(irs_mode_i),
															 .raddr_i(raddr_i),
															 .raddr_stb_i(raddr_stb_i),
															 .raddr_ack_o(raddr_ack_o),
															 .ramp_done_i(irs_raddr_ramp_done),
															 .raddr_reached_o(irs_raddr_ack),
															 
															 .irs_rd_o(irs_raddr_rd));
	
	//% Ramp controller module.
	irs_ramp_control_v3 ramp_controller(.clk_i(clk_i),
													.rst_i(irs_ramp_reset),
													.rst_ack_o(irs_ramp_reset_ack),
													
													.clear_i(irs_ramp_clear),
													.clear_ack_o(irs_ramp_clear_ack),
													
													.ramp_i(irs_ramp_start),
													.ramp_ack_o(irs_ramp_ack),
													
													.irs_start_o(irs_start_o),
													.irs_clr_o(irs_clr_o),
													.irs_ramp_o(irs_ramp_o),
													.irs_rden_o(irs_rden_o));

	//% Data from the readout control.
	wire [11:0] block_data;
	wire block_valid;
	
	//% Readout control module. It wants a channel select, so we invert it.
	irs_readout_control_v3 #(.STACK_NUMBER(STACK_NUMBER)) readout_controller( .clk_i(clk_i),
															 .rst_i(irs_rdout_reset),
															 .test_mode_i(test_mode_i),
															 .start_i(irs_rdout_start),
															 
															 .dat_o(block_data),
															 .valid_o(block_valid),
															 .done_o(irs_rdout_ack),
															 
															 .ch_sel_i(~cur_ch_mask),
															 
															 .irs_smp_o(irs_smp_o),
															 .irs_ch_o(irs_ch_o),
															 .irs_smpall_o(irs_smpall_o),
															 .irs_dat_i(irs_dat_i));

	//% Write to the FIFO.
	reg fifo_write = 0;

	//% Data to the FIFO.
	reg [15:0] fifo_data = {16{1'b0}};

	//% Error has occurred.
	reg error = 0;

	//% FIFO is full. Used for error catching.
	wire fifo_full;

	//% FIFO write logic.
	always @(posedge clk_i) begin : FIFO_WRITE_LOGIC
		if (irs_rdout_reset)
			fifo_write <= 0;
		else
			fifo_write <= (header_write || block_valid);
	end

	//% FIFO data logic.
	always @(posedge clk_i) begin : FIFO_DATA_LOGIC
		if (header_write)
			fifo_data <= header;
		else if (block_valid)
			fifo_data <= {{4{1'b0}},block_data};
	end

	//% Error logic.
	always @(posedge clk_i) begin : ERROR_LOGIC
		if (state == RESET || state == RESET_WAIT) error <= 0;
		else if (fifo_full) error <= 1;
	end
	
	//% Readout FIFO.
	irs_readout_fifo fifo(.din(fifo_data),.wr_en(fifo_write),
								 .dout(irs_dat_o),.valid(irs_valid_o),.empty(irs_empty_o),.full(fifo_full),
								 .rd_en(irs_rd_i),.clk(clk_i),.rst(irs_rdout_reset));

	assign irs_err_o = error;
	assign irs_busy_o = irs_busy;
	
	// irs_rd_o[9:3] get remapped in the pass through irs_infrastructure. Here they're just outputs.
	assign irs_rd_o[1:0] = irs_raddr_rd[1:0];
	assign irs_rd_o[2] = (irs_mode_i) ? irs_smpall_o : irs_raddr_rd[2];
	assign irs_rd_o[8:3] = irs_raddr_rd[8:3];
	assign irs_rd_o[9] = irs_rden_o;
	
	assign irs_address_sel_o = (state == ADDRESS);
	assign irs_ramping_o = (state == RAMP);
	assign irs_readout_o = (state == READOUT);
	
	assign rst_ack_o = (state == RESET_WAIT && irs_ramp_reset_ack && irs_raddr_reset_ack);

endmodule
