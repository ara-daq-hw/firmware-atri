`timescale 1ns / 1ps
// I2C mux (4-to-1) and FIFOs
module atri_i2c_mux_and_fifo(
		input i2c_clk_i,
		input pc_clk_i,
		input rst_i,
		// to atri_packet_controller
		input [1:0] i2c_adr_i,
		input [7:0] i2c_dat_i, // PC -> I2C
		output [7:0] i2c_dat_o, // I2C -> PC
		output [7:0] i2c_count_o, // minimum # of available words for i2c_adr'd I2C
		output [3:0] i2c_packet_o, // a packet is pending on a daughter
		input [3:0] i2c_packet_ack_i, // acknowledgement of a packet read
		input i2c_rd_i,
		input i2c_wr_i,
		// I2C PicoBlaze bus interface.
		inout [20:0] i2c_daughter_1,
		inout [20:0] i2c_daughter_2,
		inout [20:0] i2c_daughter_3,
		inout [20:0] i2c_daughter_4
    );

	// I2C PicoBlaze bus interface remap.
	// They are passed as a 21-bit inout array for clarity in the wiring.
	// i2c_daughter_X[7:0] = data to FIFO from I2C (really an INPUT)
	// i2c_daughter_X[15:8] = data from FIFO to I2C (really an OUTPUT)
	// i2c_daughter_X[16] = outbound FIFO full (really an OUTPUT)
	// i2c_daughter_X[17] = inbound FIFO empty (really an OUTPUT)
	// i2c_daughter_X[18] = read from FIFO (really an INPUT)
	// i2c_daughter_X[19] = write to FIFO (really an INPUT) 
	// i2c_daughter_X[20] = outbound packet strobe (really an INPUT)
	wire [7:0] data_from_i2c[3:0];
	wire [7:0] data_to_i2c[3:0];
	wire [3:0] i2c_read_from_fifo;
	wire [3:0] i2c_write_to_fifo;
	wire [3:0] outbound_FIFO_full;
	wire [3:0] inbound_FIFO_empty;
	wire [3:0] i2c_packet_strobe;

	wire [20:0] i2c_interfaces[3:0];
	// These are interfaces from daughters, so we use i2c_daughter_reassign.
	i2c_reassign_daughter rnm1(.A_i(i2c_daughter_1),.B_o(i2c_interfaces[0]));
	i2c_reassign_daughter rnm2(.A_i(i2c_daughter_2),.B_o(i2c_interfaces[1]));
	i2c_reassign_daughter rnm3(.A_i(i2c_daughter_3),.B_o(i2c_interfaces[2]));
	i2c_reassign_daughter rnm4(.A_i(i2c_daughter_4),.B_o(i2c_interfaces[3]));
	
	// Now since everything's in an array, we can just loop.
	generate
		genvar i2c_iter;
		for (i2c_iter=0;i2c_iter<4;i2c_iter=i2c_iter+1) begin : I2C_INTERFACE
			i2c_controller io(.interface_io(i2c_interfaces[i2c_iter]),
									.dat_i(data_to_i2c[i2c_iter]),.dat_o(data_from_i2c[i2c_iter]),
									.full_i(outbound_FIFO_full[i2c_iter]),.empty_i(inbound_FIFO_empty[i2c_iter]),
									.rd_o(i2c_read_from_fifo[i2c_iter]),.wr_o(i2c_write_to_fifo[i2c_iter]),
									.packet_o(i2c_packet_strobe[i2c_iter]));
		end
	endgenerate
	
	wire [7:0] i2c_count_12;
	wire [7:0] i2c_count_34;
	reg [7:0] i2c_count_out = {8{1'b0}};
	always @(*) begin
		if (i2c_adr_i[1])
			i2c_count_out <= i2c_count_34;
		else
			i2c_count_out <= i2c_count_12;
	end
	assign i2c_count_o = i2c_count_out;
	
	wire i2c_empty_12;
	wire i2c_full_12;
	wire i2c_empty_34;
	wire i2c_full_34;
	wire [7:0] i2c_dat_12;
	wire [7:0] i2c_dat_34;
	reg [7:0] i2c_dat_out = {8{1'b0}};
	always @(*) begin
		if (i2c_adr_i[1])
			i2c_dat_out <= i2c_dat_34;
		else
			i2c_dat_out <= i2c_dat_12;
	end
	assign i2c_dat_o = i2c_dat_out;
	
	// We use 2 block RAMs for 4 I2C instances, based on the
	// dual_async_bidir_buffer module.
	dual_async_bidir_buffer daughter_1_and_2_buffer(
					.rst_i(rst_i),
					.clk_AB_i(i2c_clk_i),
					.A_dat_i(data_from_i2c[0]),
					.A_dat_o(data_to_i2c[0]),
					.A_rd_i(i2c_read_from_fifo[0]),
					.A_wr_i(i2c_write_to_fifo[0]),
					.A_empty_o(inbound_FIFO_empty[0]),
					.A_full_o(outbound_FIFO_full[0]),

					.B_dat_i(data_from_i2c[1]),
					.B_dat_o(data_to_i2c[1]),
					.B_rd_i(i2c_read_from_fifo[1]),
					.B_wr_i(i2c_write_to_fifo[1]),
					.B_empty_o(inbound_FIFO_empty[1]),
					.B_full_o(outbound_FIFO_full[1]),
					
					.clk_Y_i(pc_clk_i),
					.Y_sel_i(i2c_adr_i[0]),
					.Y_dat_i(i2c_dat_i),
					.Y_dat_o(i2c_dat_12),
					.Y_rd_i(i2c_rd_i && !i2c_adr_i[1]),
					.Y_wr_i(i2c_wr_i && !i2c_adr_i[1]),
					.Y_empty_o(i2c_empty_12),
					.Y_full_o(i2c_full_12),
					.Y_count_o(i2c_count_12)
					);

	dual_async_bidir_buffer daughter_3_and_4_buffer(
					.rst_i(rst_i),
					.clk_AB_i(i2c_clk_i),
					.A_dat_i(data_from_i2c[2]),
					.A_dat_o(data_to_i2c[2]),
					.A_rd_i(i2c_read_from_fifo[2]),
					.A_wr_i(i2c_write_to_fifo[2]),
					.A_empty_o(inbound_FIFO_empty[2]),
					.A_full_o(outbound_FIFO_full[2]),

					.B_dat_i(data_from_i2c[3]),
					.B_dat_o(data_to_i2c[3]),
					.B_rd_i(i2c_read_from_fifo[3]),
					.B_wr_i(i2c_write_to_fifo[3]),
					.B_empty_o(inbound_FIFO_empty[3]),
					.B_full_o(outbound_FIFO_full[3]),
					
					.clk_Y_i(pc_clk_i),
					.Y_sel_i(i2c_adr_i[0]),
					.Y_dat_i(i2c_dat_i),
					.Y_dat_o(i2c_dat_34),
					.Y_rd_i(i2c_rd_i && i2c_adr_i[1]),
					.Y_wr_i(i2c_wr_i && i2c_adr_i[1]),
					.Y_empty_o(i2c_empty_34),
					.Y_full_o(i2c_full_34),
					.Y_count_o(i2c_count_34)
					);
	
	// We don't really use i2c_full_12/i2c_empty_12 because the packet strobes and i2c_count's do this.
	// A packet is minimally
	// pktno
	// pktlen
	// type
	// txnlen
	// address
	// 5 bytes, so we need 7 bits.
	wire [7:0] packet_counters[3:0];
	// packet_ack in the i2c_clk_i domain
	wire [3:0] packet_ack_sync;
	
	wire [3:0] i2c_full = {
			(packet_counters[3] == {8{1'b1}}),
			(packet_counters[2] == {8{1'b1}}),
			(packet_counters[1] == {8{1'b1}}),
			(packet_counters[0] == {8{1'b1}})};
	wire [3:0] i2c_empty = {
			(packet_counters[3] == {8{1'b0}}),
			(packet_counters[2] == {8{1'b0}}),
			(packet_counters[1] == {8{1'b0}}),
			(packet_counters[0] == {8{1'b0}})};
	
	generate
		genvar pc_i;
		for (pc_i=0;pc_i<4;pc_i=pc_i+1) begin : CL
			atri_i2c_packet_counter cnt(.clk_i(pc_clk_i),.rst_i(rst_i),
												 .strobe_i(i2c_packet_strobe[pc_i]),
												 .ack_i(packet_ack_sync[pc_i]),
												 .counter_o(packet_counters[pc_i]),
												 .full_i(i2c_full[pc_i]),
												 .empty_i(i2c_empty[pc_i]));
		end
	endgenerate
	
//	initial begin
//		packet_counters[0] <= {8{1'b0}};
//		packet_counters[1] <= {8{1'b0}};
//		packet_counters[2] <= {8{1'b0}};
//		packet_counters[3] <= {8{1'b0}};
//	end
//	integer pc_i;
//	always @(posedge i2c_clk_i or posedge rst_i) begin
//		for (pc_i=0;pc_i<4;pc_i=pc_i+1) begin
//			if (rst_i) begin
//				packet_counters[pc_i] <= {8{1'b0}};
//			end else begin
//				if (i2c_packet_strobe[pc_i] && packet_counters[pc_i] != {8{1'b1}})
//					packet_counters[pc_i] <= packet_counters[pc_i] + 1;
//				else if (packet_ack_sync[pc_i] && packet_counters[pc_i] != {8{1'b0}})
//					packet_counters[pc_i] <= packet_counters[pc_i] - 1;
//			end
//		end
//	end

	wire [3:0] packet_out_pcclk;
	wire [3:0] i2c_packet;
	// how did this ever WORK before?
	assign i2c_packet[0] = (!i2c_empty[0]) && !packet_ack_sync[0];
	assign i2c_packet[1] = (!i2c_empty[1]) && !packet_ack_sync[1];
	assign i2c_packet[2] = (!i2c_empty[2]) && !packet_ack_sync[2];
	assign i2c_packet[3] = (!i2c_empty[3]) && !packet_ack_sync[3];
	wire [3:0] packet_out_sync;
	signal_sync ps0(.clkA(i2c_clk_i),.clkB(pc_clk_i),.in_clkA(i2c_packet[0]),
						 .out_clkB(packet_out_pcclk[0]));
	signal_sync ps1(.clkA(i2c_clk_i),.clkB(pc_clk_i),.in_clkA(i2c_packet[1]),
						 .out_clkB(packet_out_pcclk[1]));
	signal_sync ps2(.clkA(i2c_clk_i),.clkB(pc_clk_i),.in_clkA(i2c_packet[2]),
						 .out_clkB(packet_out_pcclk[2]));
	signal_sync ps3(.clkA(i2c_clk_i),.clkB(pc_clk_i),.in_clkA(i2c_packet[3]),
						 .out_clkB(packet_out_pcclk[3]));
	reg [3:0] packet_out_hold = {4{1'b0}};
	wire [3:0] packet_back_sync;

	integer h_i;
	always @(posedge pc_clk_i) begin
		for (h_i=0;h_i<4;h_i=h_i+1) begin
			if (i2c_packet_ack_i[h_i])
				packet_out_hold[h_i] <= 1;
			else if (packet_back_sync[h_i])
				packet_out_hold[h_i] <= 0;
		end
	end
	assign i2c_packet_o[0] = packet_out_pcclk[0] && !packet_out_hold[0];
	assign i2c_packet_o[1] = packet_out_pcclk[1] && !packet_out_hold[1];
	assign i2c_packet_o[2] = packet_out_pcclk[2] && !packet_out_hold[2];
	assign i2c_packet_o[3] = packet_out_pcclk[3] && !packet_out_hold[3];

	generate
		genvar ack_i;
		for (ack_i=0;ack_i<4;ack_i=ack_i+1) begin : ACK_SYNC_LOOP
			// sync A to B: pc_clk_i -> i2c_clk_i
			flag_sync ack_sync(.clkA(pc_clk_i),.clkB(i2c_clk_i),.in_clkA(i2c_packet_ack_i[ack_i]),
									 .out_clkB(packet_ack_sync[ack_i]));
			// sync B to A: i2c_clk_i -> pc_clk_i
			flag_sync ack_back_sync(.clkA(i2c_clk_i),.in_clkA(packet_ack_sync[ack_i]),
											.clkB(pc_clk_i),.out_clkB(packet_back_sync[ack_i]));
		end
	endgenerate
	
endmodule

module atri_i2c_packet_counter(
	input clk_i,
	input rst_i,
	input strobe_i,
	input ack_i,
	input full_i,
	input empty_i,
	output [7:0] counter_o
);

	reg [7:0] packet_counter = {8{1'b0}};
	always @(posedge clk_i or posedge rst_i) begin
		if (rst_i)
			packet_counter <= {8{1'b0}};
		else begin
			if (strobe_i && !full_i) packet_counter <= packet_counter + 1;
			else if (ack_i && !empty_i) packet_counter <= packet_counter - 1;
		end
	end
	assign counter_o = packet_counter;
endmodule

	