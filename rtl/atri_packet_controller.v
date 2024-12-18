`timescale 1ns / 1ps
/** @file atri_packet_controller.v Contains atri_packet_controller module. */

`include "wb_interface.vh"

module atri_packet_controller(
		// Main interface
		input clk_i,
		input reset_i,
		
		input [7:0] dat_i,
		output [7:0] dat_o,
		// asserted when a packet completes.
		output packet_o,
		input empty_i,
		input full_i,
		output rd_o,
		output wr_o,
		// Daughterboard interface
		input [7:0] D1_status_i,
		input [7:0] D2_status_i,
		input [7:0] D3_status_i,
		input [7:0] D4_status_i,
		input status_change_i,
		output status_change_ack_o,
		// WISHBONE interface
		inout [`WBIF_SIZE-1:0] wb_interface_io,
		// I2C interface
		output [1:0] i2c_adr_o,
		output [7:0] i2c_dat_o,
		input [7:0] i2c_dat_i,
		input [7:0] i2c_count_i,
		input [3:0] i2c_packet_i,
		output [3:0] i2c_packet_ack_o,
		output i2c_rd_o,
		output i2c_wr_o,
		output [5:0] state_o
    );

	// WISHBONE interface.
	// INTERFACE_INS wb wb_master RPL interface_io wb_interface_io RPL dat_i wb_dat_i RPL dat_o wb_dat_o RPL clk_i wb_clk_i RPL rst_i wb_rst_i RPL wr_o wb_wr_o
	wire wb_clk_i;
	wire wb_rst_i;
	wire cyc_o;
	wire wb_wr_o;
	wire stb_o;
	wire ack_i;
	wire err_i;
	wire rty_i;
	wire [15:0] adr_o;
	wire [7:0] wb_dat_o;
	wire [7:0] wb_dat_i;
	wb_master wbif(.interface_io(wb_interface_io),
	               .clk_o(wb_clk_i),
	               .rst_o(wb_rst_i),
	               .cyc_i(cyc_o),
	               .wr_i(wb_wr_o),
	               .stb_i(stb_o),
	               .ack_o(ack_i),
	               .err_o(err_i),
	               .rty_o(rty_i),
	               .adr_i(adr_o),
	               .dat_i(wb_dat_o),
	               .dat_o(wb_dat_i));
	// INTERFACE_END
	
	// There are 54 total states.
	`include "clogb2.vh"
	
	localparam FSM_BITS = clogb2(56);
	localparam [FSM_BITS-1:0] RESET = 0;
	localparam [FSM_BITS-1:0] WRITE_RESET_SOF = 1;
	localparam [FSM_BITS-1:0] WRITE_RESET_SRC = 2;
	localparam [FSM_BITS-1:0] WRITE_RESET_PKTNO = 3;
	localparam [FSM_BITS-1:0] WRITE_RESET_PKTLEN = 4;
	localparam [FSM_BITS-1:0] WRITE_RESET = 5;
	localparam [FSM_BITS-1:0] WRITE_RESET_EOF = 6;
	localparam [FSM_BITS-1:0] IDLE = 7;
	localparam [FSM_BITS-1:0] READ_SOF = 8;
	localparam [FSM_BITS-1:0] READ_DESTINATION = 9;
	localparam [FSM_BITS-1:0] WRITE_ERR_SOF = 10;
	localparam [FSM_BITS-1:0] WRITE_ERR_SRC = 11;
	localparam [FSM_BITS-1:0] WRITE_ERR_PKTNO = 12;
	localparam [FSM_BITS-1:0] WRITE_ERR_PKTLEN = 13;
	localparam [FSM_BITS-1:0] WRITE_ERR_ERR = 14;
	localparam [FSM_BITS-1:0] WRITE_ERR_EOF = 15;
	localparam [FSM_BITS-1:0] REQ_DB_STATUS_PKTNO = 16;
	localparam [FSM_BITS-1:0] REQ_DB_STATUS_EOF = 17;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_SOF = 18;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_SRC = 19;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_PKTNO = 20;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_PKTLEN = 21;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS = 22;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_2 = 23;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_3 = 24;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_4 = 25;
	localparam [FSM_BITS-1:0] WRITE_DB_STATUS_EOF = 26;
	localparam [FSM_BITS-1:0] I2C_PACKET_PKTNO = 27;
	localparam [FSM_BITS-1:0] I2C_PACKET_PKTLEN = 28;
	localparam [FSM_BITS-1:0] I2C_PACKET_CHECK = 29;
	localparam [FSM_BITS-1:0] I2C_PACKET_FORWARD_PKTNO = 30;
	localparam [FSM_BITS-1:0] I2C_PACKET_FORWARD_PKTLEN = 31;
	localparam [FSM_BITS-1:0] I2C_PACKET_FORWARD = 32;
	localparam [FSM_BITS-1:0] I2C_PACKET_EOF = 33;
	localparam [FSM_BITS-1:0] WB_PACKET_PKTNO = 34;
	localparam [FSM_BITS-1:0] WB_PACKET_PKTLEN = 35;
	localparam [FSM_BITS-1:0] WB_PACKET_TYPE = 36;
	localparam [FSM_BITS-1:0] WB_PACKET_ADDRH = 37;
	localparam [FSM_BITS-1:0] WB_PACKET_ADDRL = 38;
	localparam [FSM_BITS-1:0] WB_PACKET_TXN_LENGTH = 39;
	localparam [FSM_BITS-1:0] WB_PACKET_EOF = 40;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_SOF = 41;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_SRC = 42;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_PKTNO = 43;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_PKTLEN = 44;
	localparam [FSM_BITS-1:0] WB_PACKET_CYC = 45;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_NBYTES = 46;
	localparam [FSM_BITS-1:0] WB_PACKET_WRITE_EOF = 47;
	localparam [FSM_BITS-1:0] WRITE_I2C_SOF = 48;
	localparam [FSM_BITS-1:0] WRITE_I2C_SRC = 49;
	localparam [FSM_BITS-1:0] WRITE_I2C_PRIME1 = 50;
	localparam [FSM_BITS-1:0] WRITE_I2C_PKTNO = 51;
	localparam [FSM_BITS-1:0] WRITE_I2C_PKTLEN = 52;
	localparam [FSM_BITS-1:0] WRITE_I2C_PACKET = 53;
	localparam [FSM_BITS-1:0] WRITE_I2C_EOF = 54;
	localparam [FSM_BITS-1:0] WRITE_I2C_PRIME2 = 55;
	localparam [FSM_BITS-1:0] WRITE_I2C_PRIME3 = 56;
	(* FSM_ENCODING = "USER" *)
	reg [FSM_BITS-1:0] state = RESET;
	
	localparam [3:0] CONTROLLER = 0;
	localparam [3:0] WISHBONE = 1;
	localparam [3:0] DBSTATUS = 2;
	localparam [3:0] I2C_DAUGHTER_1 = 3;
	localparam [3:0] I2C_DAUGHTER_2 = 4;
	localparam [3:0] I2C_DAUGHTER_3 = 5;
	localparam [3:0] I2C_DAUGHTER_4 = 6;
	
	// Write packet number.
	reg [7:0] write_packet_number = {8{1'b0}};
	// Write packet length.
	reg [7:0] write_packet_length = {8{1'b0}};
	// Write packet source.
	reg [7:0] write_packet_src = {8{1'b0}};
	// Write packet data (when we can store it ahead of time)
	reg [7:0] write_packet_data = {8{1'b0}};

	// Data out mux.
	reg [7:0] data_out = {8{1'b0}};

	// General-purpose counter.
	reg [7:0] counter = {8{1'b0}};
	
	// Packet length.
	reg [7:0] packet_length = {8{1'b0}};
	always @(posedge clk_i) begin
		if (state == I2C_PACKET_PKTLEN || state == WB_PACKET_PKTLEN)
			packet_length <= dat_i;
	end
	// Packet number
	reg [7:0] packet_number = {8{1'b0}};
	always @(posedge clk_i) begin
		if (state == I2C_PACKET_PKTNO || state == WB_PACKET_PKTNO || state == REQ_DB_STATUS_PKTNO)
			packet_number <= dat_i;
	end
	
	localparam [1:0] DAUGHTER_1 = 2'b00;
	localparam [1:0] DAUGHTER_2 = 2'b01;
	localparam [1:0] DAUGHTER_3 = 2'b10;
	localparam [1:0] DAUGHTER_4 = 2'b11;
	reg [1:0] i2c_channel = DAUGHTER_1;
	
	reg this_i2c_too_full = 0;
	
	localparam WB_READ = 0;
	localparam WB_WRITE = 1;
	reg this_wb_txn = WB_READ;
	reg [7:0] this_wb_txn_length = {8{1'b0}};
	reg [15:0] this_wb_addr = {16{1'b0}};
	
	// Error value.
	localparam [7:0] ERR_RESET = 8'h00;
	localparam [7:0] ERR_BAD_PACKET = 8'hFF;
	localparam [7:0] ERR_BAD_DEST = 8'hFE;
	localparam [7:0] ERR_I2C_FULL = 8'hFD;
	reg [7:0] last_err = ERR_RESET;
	
	// SOF and EOF
	localparam [7:0] SOF = "<";
	localparam [7:0] EOF = ">";
	
	// Error handling.
	always @(posedge clk_i) begin
		// Reset
		if (state == RESET)
			last_err <= ERR_RESET;
		// States which check SOF
		else if (state == READ_SOF) begin
			if (dat_i != SOF)
				last_err <= ERR_BAD_PACKET;
		end
		// This state ignores everything to EOF.
		else if (state == REQ_DB_STATUS_EOF) begin
			if (dat_i != EOF && empty_i)
				last_err <= ERR_BAD_PACKET;
		end
		// States which check EOF.
		else if (state == I2C_PACKET_EOF || state == WB_PACKET_EOF) begin
			if (dat_i != EOF || empty_i)
				last_err <= ERR_BAD_PACKET;
		end
		// States which check destination
		else if (state == READ_DESTINATION) begin
			if (dat_i == {8{1'b0}} || dat_i > 6)
				last_err <= ERR_BAD_DEST;
			else if (empty_i)
				last_err <= ERR_BAD_PACKET;
		end 
		// States which need data
		else if (state == WB_PACKET_PKTNO || state == WB_PACKET_PKTLEN ||
						 state == WB_PACKET_TYPE || state == WB_PACKET_ADDRH || state == WB_PACKET_ADDRL ||
						 state == I2C_PACKET_PKTNO || state == I2C_PACKET_PKTLEN || state == I2C_PACKET_FORWARD ||
						 state == REQ_DB_STATUS_EOF) begin
			if (empty_i)
				last_err <= ERR_BAD_PACKET;
		end 
		// I2C error states
		else if (state == I2C_PACKET_CHECK) begin
			if (this_i2c_too_full)
				last_err <= ERR_I2C_FULL;
		end
	end
		
	// Data mux.
	always @(*) begin
		case (state)
			WRITE_RESET_SOF, WRITE_ERR_SOF, WRITE_DB_STATUS_SOF, WB_PACKET_WRITE_SOF, WRITE_I2C_SOF:
				data_out <= SOF;
			WRITE_RESET_EOF, WRITE_ERR_EOF, WRITE_DB_STATUS_EOF, WB_PACKET_WRITE_EOF, WRITE_I2C_EOF:
				data_out <= EOF;
			WRITE_RESET_SRC, WRITE_ERR_SRC, WRITE_DB_STATUS_SRC, WB_PACKET_WRITE_SRC, WRITE_I2C_SRC:
				data_out <= write_packet_src;
			WRITE_RESET_PKTNO, WRITE_ERR_PKTNO, WRITE_DB_STATUS_PKTNO, WB_PACKET_WRITE_PKTNO, WRITE_I2C_PKTNO:
				data_out <= write_packet_number;
			WRITE_RESET_PKTLEN, WRITE_ERR_PKTLEN, WRITE_DB_STATUS_PKTLEN, WB_PACKET_WRITE_PKTLEN, WRITE_I2C_PKTLEN:
				data_out <= write_packet_length;
			WRITE_ERR_ERR, WRITE_RESET:
				data_out <= last_err;
			WRITE_DB_STATUS, WRITE_DB_STATUS_2, WRITE_DB_STATUS_3, WRITE_DB_STATUS_4,
			WRITE_I2C_PACKET:
				data_out <= write_packet_data;
			WB_PACKET_CYC:
				data_out <= wb_dat_i;
			WB_PACKET_WRITE_NBYTES:
				data_out <= counter;
			default:
				data_out <= wb_dat_i;
		endcase
	end
	
	always @(posedge clk_i) begin
		if (reset_i)
			state <= RESET;
		else begin
			case (state)
			RESET: state <= WRITE_RESET_SOF;
			// These could probably just be merged with the WRITE_ERR path
			WRITE_RESET_SOF: if (full_i == 0) state <= WRITE_RESET_SRC;
			WRITE_RESET_SRC: if (full_i == 0) state <= WRITE_RESET_PKTNO;
			WRITE_RESET_PKTNO: if (full_i == 0) state <= WRITE_RESET_PKTLEN;
			WRITE_RESET_PKTLEN: if (full_i == 0) state <= WRITE_RESET;
			WRITE_RESET: if (full_i == 0) state <= WRITE_RESET_EOF;
			WRITE_RESET_EOF: if (full_i == 0) state <= IDLE;
			IDLE: if (i2c_packet_i != 4'b0000) state <= WRITE_I2C_SOF;
					else if (status_change_i) state <= WRITE_DB_STATUS_SOF;
					else if (!empty_i) state <= READ_SOF;
			READ_SOF: if (dat_i != SOF || empty_i) state <= WRITE_ERR_SOF;
						 else state <= READ_DESTINATION;
			READ_DESTINATION: if (empty_i || dat_i == 0 || dat_i > 6) state <= WRITE_ERR_SOF;
					else if (dat_i == 2) state <= REQ_DB_STATUS_PKTNO;
					else if (dat_i == 1) state <= WB_PACKET_PKTNO;
					else state <= I2C_PACKET_PKTNO;
			REQ_DB_STATUS_PKTNO: if (empty_i) state <= WRITE_ERR_SOF;
					else state <= REQ_DB_STATUS_EOF;
			REQ_DB_STATUS_EOF: if (dat_i == EOF) state <= WRITE_DB_STATUS_SOF;
					else if (empty_i) state <= WRITE_ERR_SOF;
			WRITE_DB_STATUS_SOF: if (!full_i) state <= WRITE_DB_STATUS_SRC;
			WRITE_DB_STATUS_SRC: if (!full_i) state <= WRITE_DB_STATUS_PKTNO;
			WRITE_DB_STATUS_PKTNO: if (!full_i) state <= WRITE_DB_STATUS_PKTLEN;
			WRITE_DB_STATUS_PKTLEN: if (!full_i) state <= WRITE_DB_STATUS;
			WRITE_DB_STATUS: if (!full_i) state <= WRITE_DB_STATUS_2;
			WRITE_DB_STATUS_2: if (!full_i) state <= WRITE_DB_STATUS_3;
			WRITE_DB_STATUS_3: if (!full_i) state <= WRITE_DB_STATUS_4;
			WRITE_DB_STATUS_4: if (!full_i) state <= WRITE_DB_STATUS_EOF;
			WRITE_DB_STATUS_EOF: if (!full_i) state <= IDLE;
			WRITE_ERR_SOF: if (!full_i) state <= WRITE_ERR_SRC;
			WRITE_ERR_SRC: if (!full_i) state <= WRITE_ERR_PKTNO;
			WRITE_ERR_PKTNO: if (!full_i) state <= WRITE_ERR_PKTLEN;
			WRITE_ERR_PKTLEN: if (!full_i) state <= WRITE_ERR_ERR;
			WRITE_ERR_ERR: if (!full_i) state <= WRITE_ERR_EOF;
			WRITE_ERR_EOF: if (!full_i) state <= IDLE;
			I2C_PACKET_PKTNO: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= I2C_PACKET_PKTLEN;
			I2C_PACKET_PKTLEN: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= I2C_PACKET_CHECK;
			I2C_PACKET_CHECK: if (this_i2c_too_full) state <= WRITE_ERR_SOF;
				else state <= I2C_PACKET_FORWARD_PKTNO;
			I2C_PACKET_FORWARD_PKTNO: state <= I2C_PACKET_FORWARD_PKTLEN;
			I2C_PACKET_FORWARD_PKTLEN: state <= I2C_PACKET_FORWARD;
			I2C_PACKET_FORWARD: if (empty_i) state <= WRITE_ERR_SOF;
				else if (counter == packet_length - 1) state <= I2C_PACKET_EOF;
			I2C_PACKET_EOF: if (dat_i != EOF || empty_i) state <= WRITE_ERR_SOF; 
				else state <= IDLE;
			WB_PACKET_PKTNO: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= WB_PACKET_PKTLEN;
			WB_PACKET_PKTLEN: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= WB_PACKET_TYPE;
			WB_PACKET_TYPE: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= WB_PACKET_ADDRH;
			WB_PACKET_ADDRH: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= WB_PACKET_ADDRL;
			WB_PACKET_ADDRL: if (empty_i) state <= WRITE_ERR_SOF;
				else if (this_wb_txn == WB_READ) state <= WB_PACKET_TXN_LENGTH;
				else begin // WB_WRITE
					if (this_wb_txn_length == {8{1'b0}}) state <= WB_PACKET_WRITE_SOF;
					else state <= WB_PACKET_CYC;
				end
			WB_PACKET_TXN_LENGTH: if (empty_i) state <= WRITE_ERR_SOF;
				else state <= WB_PACKET_EOF;
			WB_PACKET_EOF: if (dat_i != EOF || empty_i) state <= WRITE_ERR_SOF;
				else if (this_wb_txn == WB_READ) state <= WB_PACKET_WRITE_SOF;
				else state <= IDLE;
			WB_PACKET_WRITE_SOF: if (!full_i) state <= WB_PACKET_WRITE_SRC;
			WB_PACKET_WRITE_SRC: if (!full_i) state <= WB_PACKET_WRITE_PKTNO;
			WB_PACKET_WRITE_PKTNO: if (!full_i) state <= WB_PACKET_WRITE_PKTLEN;
			WB_PACKET_WRITE_PKTLEN: if (!full_i) begin
				if (this_wb_txn == WB_READ) begin // WB_READ
					if (this_wb_txn_length == {8{1'b0}}) state <= WB_PACKET_WRITE_EOF;
					else state <= WB_PACKET_CYC;
				end // WB_WRITE
					else state <= WB_PACKET_WRITE_NBYTES;
			end
			WB_PACKET_WRITE_NBYTES: if (!full_i) state <= WB_PACKET_WRITE_EOF;
			WB_PACKET_WRITE_EOF: if (!full_i) begin
				if (this_wb_txn == WB_READ) state <= IDLE;
				else state <= WB_PACKET_EOF;
			end
			WB_PACKET_CYC: if (ack_i && counter == this_wb_txn_length-1) begin
				if (this_wb_txn == WB_READ) state <= WB_PACKET_WRITE_EOF;
				else state <= WB_PACKET_WRITE_SOF;
			end
			WRITE_I2C_SOF: if (!full_i) state <= WRITE_I2C_SRC;
			WRITE_I2C_SRC: if (!full_i) state <= WRITE_I2C_PRIME1;
			WRITE_I2C_PRIME1: state <= WRITE_I2C_PKTNO;
			WRITE_I2C_PKTNO: if (!full_i) state <= WRITE_I2C_PRIME2;
			WRITE_I2C_PRIME2: state <= WRITE_I2C_PKTLEN;
			WRITE_I2C_PKTLEN: if (!full_i) state <= WRITE_I2C_PRIME3;
			WRITE_I2C_PRIME3: state <= WRITE_I2C_PACKET;
			WRITE_I2C_PACKET: if (!full_i && counter == write_packet_length-1) state <= WRITE_I2C_EOF;
									else if (!full_i) state <= WRITE_I2C_PRIME3;
			WRITE_I2C_EOF: if (!full_i) state <= IDLE;
			endcase
		end
	end
	
	// Source...
	always @(posedge clk_i) begin
		if (state == WRITE_ERR_SOF || state == RESET)
			write_packet_src <= CONTROLLER;
		else if (state == WRITE_DB_STATUS_SOF)
			write_packet_src <= DBSTATUS;
		else if (state == WB_PACKET_WRITE_SOF)
			write_packet_src <= WISHBONE;
		else if (state == WRITE_I2C_SOF) begin
			if (i2c_channel == DAUGHTER_1)
				write_packet_src <= I2C_DAUGHTER_1;
			else if (i2c_channel == DAUGHTER_2)
				write_packet_src <= I2C_DAUGHTER_2;
			else if (i2c_channel == DAUGHTER_3)
				write_packet_src <= I2C_DAUGHTER_3;
			else if (i2c_channel == DAUGHTER_4)
				write_packet_src <= I2C_DAUGHTER_4;
		end
	end

	// Packet length...
	always @(posedge clk_i) begin
		if (state == WRITE_ERR_SOF || state == WRITE_RESET_SOF)
			write_packet_length <= 1;
		else if (state == WRITE_DB_STATUS_SOF)
			write_packet_length <= 4;
		else if (state == WB_PACKET_WRITE_SOF)
			if (this_wb_txn == WB_WRITE)
				write_packet_length <= 1;	  // 1 for number of bytes written.
			else
				write_packet_length <= this_wb_txn_length;
		else if (state == WRITE_I2C_PRIME2) // I2C packet length is read 1 cycle ahead
			write_packet_length <= i2c_dat_i;
	end

	// Packet number...
	always @(posedge clk_i) begin
		if (state == IDLE)
			write_packet_number <= {8{1'b0}}; // Broadcast packets are all packet #0
		else if (state == REQ_DB_STATUS_EOF ||
			 state == WB_PACKET_WRITE_SOF)
			write_packet_number <= packet_number;
		else if (state == WRITE_I2C_SRC) // I2C packet number is read 1 cycle ahead
			write_packet_number <= i2c_dat_i;
	end
	// (Pipelined) packet data
	always @(posedge clk_i) begin
		if (state == WRITE_DB_STATUS_PKTLEN)
			write_packet_data <= D1_status_i;
		else if (state == WRITE_DB_STATUS)
			write_packet_data <= D2_status_i;
		else if (state == WRITE_DB_STATUS_2)
			write_packet_data <= D3_status_i;
		else if (state == WRITE_DB_STATUS_3)
			write_packet_data <= D4_status_i;
		else if (state == WRITE_I2C_PRIME3) // I2C data is read 1 ahead
			write_packet_data <= i2c_dat_i;
	end

	// Counter
	always @(posedge clk_i) begin
		if (state == WRITE_I2C_SOF || state == I2C_PACKET_PKTNO || state == WB_PACKET_PKTNO)
			counter <= {8{1'b0}};
		else begin
			if ((state == WRITE_I2C_PACKET && !full_i) ||
				 (state == WB_PACKET_CYC && ack_i) ||
				 (state == I2C_PACKET_FORWARD))
				 counter <= counter + 1;
		end
	end
	
	// WB transaction type
	always @(posedge clk_i) begin
		if (state == WB_PACKET_TYPE)
			this_wb_txn <= dat_i[0];
	end
	// WB address
	always @(posedge clk_i) begin
		if (state == WB_PACKET_ADDRL)
			this_wb_addr[7:0] <= dat_i;
		else if (state == WB_PACKET_ADDRH)
			this_wb_addr[15:8] <= dat_i;
		else if (state == WB_PACKET_CYC && ack_i && cyc_o)
			this_wb_addr <= this_wb_addr + 1;
	end
	always @(posedge clk_i) begin
		if (state == WB_PACKET_PKTLEN)
			this_wb_txn_length <= dat_i - 3;
		else if (state == WB_PACKET_TXN_LENGTH)
			this_wb_txn_length <= dat_i;
	end

	// I2C address
	always @(posedge clk_i) begin
		if (state == READ_DESTINATION) begin
			if (dat_i == I2C_DAUGHTER_1)
				i2c_channel <= DAUGHTER_1;
			else if (dat_i == I2C_DAUGHTER_2)
				i2c_channel <= DAUGHTER_2;
			else if (dat_i == I2C_DAUGHTER_3)
				i2c_channel <= DAUGHTER_3;
			else if (dat_i == I2C_DAUGHTER_4)
				i2c_channel <= DAUGHTER_4;
		end else if (state == IDLE) begin
			if (i2c_packet_i[0])
				i2c_channel <= DAUGHTER_1;
			else if (i2c_packet_i[1])
				i2c_channel <= DAUGHTER_2;
			else if (i2c_packet_i[2])
				i2c_channel <= DAUGHTER_3;
			else if (i2c_packet_i[3])
				i2c_channel <= DAUGHTER_4;
		end
	end
	always @(posedge clk_i) begin
		if (state == I2C_PACKET_PKTLEN &&
			 i2c_count_i < packet_length)
			this_i2c_too_full <= 1;
		else if (state == IDLE)
			this_i2c_too_full <= 0;
	end

	reg i2c_read_data = 0;
	reg i2c_write_data = 0;
	reg read_data = 0;
	reg write_data = 0;
	reg wb_cyc = 0;
	
	assign rd_o = read_data;
	assign wr_o = write_data;
	assign cyc_o = wb_cyc;
	assign stb_o = wb_cyc;

	// State outputs.
   always @(*) begin
      case (state)
         RESET: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WRITE_RESET_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_RESET_SRC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_RESET_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_RESET_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_RESET: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_RESET_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         IDLE: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 0;
            wb_cyc <= 0;
         end
         READ_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= !empty_i;
            write_data <= 0;
            wb_cyc <= 0;
         end
         READ_DESTINATION: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= !empty_i;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WRITE_ERR_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_ERR_SRC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_ERR_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_ERR_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_ERR_ERR: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_ERR_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         REQ_DB_STATUS_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= !empty_i;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_SRC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_2: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_3: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_4: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_DB_STATUS_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         I2C_PACKET_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         I2C_PACKET_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 0;
            wb_cyc <= 0;
         end
         I2C_PACKET_CHECK: begin
				i2c_read_data <= 0;
				i2c_write_data <= 0;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
			I2C_PACKET_FORWARD_PKTNO: begin
				i2c_read_data <= 0;
				i2c_write_data <= 1;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
			I2C_PACKET_FORWARD_PKTLEN: begin
				i2c_read_data <= 0;
				i2c_write_data <= 1;
				read_data <= 1;
				write_data <= 0;
				wb_cyc <= 0;
			end
			I2C_PACKET_FORWARD: begin
            i2c_read_data <= 0;
            i2c_write_data <= 1;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         I2C_PACKET_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_TYPE: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_ADDRH: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_ADDRL: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_TXN_LENGTH: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 1;
            write_data <= 0;
            wb_cyc <= 0;
         end
         WB_PACKET_WRITE_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WB_PACKET_WRITE_SRC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WB_PACKET_WRITE_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WB_PACKET_WRITE_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
			// When we assert wb_cyc, we assert read_data
			// if we need more data. This happens if ack_i is true. So that part is fine.
			//
			// For writing, however, we write when the data is valid (ack_i)
			// and we have space in the FIFO (!full_i). When the FIFO fills,
			// it asserts full_i after the last valid read, which deasserts
			// wb_cyc, and prevents write_data from going. So that part should also be fine.
         WB_PACKET_CYC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= (this_wb_txn == WB_WRITE) && ack_i;
            write_data <= (this_wb_txn == WB_READ) && ack_i && !full_i;
            wb_cyc <= (!full_i && this_wb_txn == WB_READ) || (this_wb_txn == WB_WRITE);
         end
         WB_PACKET_WRITE_NBYTES: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WB_PACKET_WRITE_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_I2C_SOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
			// I2C fifo has 1 cycle latency on read for us.
			WRITE_I2C_PRIME1: begin
				i2c_read_data <= 1;
				i2c_write_data <= 0;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
			WRITE_I2C_PRIME2: begin
				i2c_read_data <= 1;
				i2c_write_data <= 0;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
			WRITE_I2C_PRIME3: begin
				i2c_read_data <= 1;
				i2c_write_data <= 0;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
         WRITE_I2C_SRC: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_I2C_PKTNO: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_I2C_PKTLEN: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_I2C_PACKET: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
         WRITE_I2C_EOF: begin
            i2c_read_data <= 0;
            i2c_write_data <= 0;
            read_data <= 0;
            write_data <= 1;
            wb_cyc <= 0;
         end
			default:	begin
				i2c_read_data <= 0;
				i2c_write_data <= 0;
				read_data <= 0;
				write_data <= 0;
				wb_cyc <= 0;
			end
      endcase
   end
	reg [7:0] i2c_data = {8{1'b0}};
	always @(*) begin
		if (state == I2C_PACKET_FORWARD_PKTNO)
			i2c_data <= packet_number;
		else if (state == I2C_PACKET_FORWARD_PKTLEN)
			i2c_data <= packet_length;
		else
			i2c_data <= dat_i;
	end
	assign i2c_adr_o = i2c_channel;
	assign i2c_rd_o = i2c_read_data;
	assign i2c_wr_o = i2c_write_data;
	assign dat_o = data_out;
	assign adr_o = this_wb_addr;
	assign wb_dat_o = dat_i;
	assign i2c_dat_o = i2c_data;
	assign wb_wr_o = (this_wb_txn == WB_WRITE);
	// ack a status change when we enter the status change chain
	assign status_change_ack_o = (state == WRITE_DB_STATUS_SOF && status_change_i);
	// ack an I2C packet when we write the EOF
	assign i2c_packet_ack_o[0] = (state == WRITE_I2C_EOF && i2c_channel == DAUGHTER_1);
	assign i2c_packet_ack_o[1] = (state == WRITE_I2C_EOF && i2c_channel == DAUGHTER_2);
	assign i2c_packet_ack_o[2] = (state == WRITE_I2C_EOF && i2c_channel == DAUGHTER_3);
	assign i2c_packet_ack_o[3] = (state == WRITE_I2C_EOF && i2c_channel == DAUGHTER_4);

	assign state_o = state;

	assign packet_o = (state == WRITE_RESET_EOF || state == WRITE_I2C_EOF || 
							 state == WB_PACKET_WRITE_EOF || state == WRITE_DB_STATUS_EOF ||
							 state == WRITE_ERR_EOF);
endmodule
