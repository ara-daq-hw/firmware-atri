`timescale 1ns / 1ps

`include "wb_interface.vh"

// ATRI WISHBONE bus arbiter and system controller.
// Injects the clock/reset into all interfaces, and also does the address mapping
// between slaves.
module atri_wishbone_bus(
		input clk_i, input rst_i,
		inout [`WBIF_SIZE-1:0] master_interface_io,
		inout [`WBIF_SIZE-1:0] slave0_interface_io,
		inout [`WBIF_SIZE-1:0] slave1_interface_io,
		inout [`WBIF_SIZE-1:0] slave2_interface_io,
		inout [`WBIF_SIZE-1:0] slave3_interface_io,
		inout [`WBIF_SIZE-1:0] slave4_interface_io,
		inout [`WBIF_SIZE-1:0] slave5_interface_io,
		inout [`WBIF_SIZE-1:0] slave6_interface_io,
		inout [`WBIF_SIZE-1:0] slave7_interface_io,
		inout [`WBIF_SIZE-1:0] slave8_interface_io
    );

	parameter NUM_SLAVES = 8;
	localparam NUM_INTERFACES = NUM_SLAVES + 1;
	wire [`WBIF_SIZE-1:0] interfaces[NUM_INTERFACES-1:0];
	
	// Renaming interfaces to store them in the above 2D array.
	// Interfaces are bidirectional, so we can't just do an "assign".
	// Convenience modules allow renaming.
	
	// Rename an interface *from* a master
	wb_master_reassign rnm0(.A_i(master_interface_io),.B_o(interfaces[0]));
	// Rename an interface *from* a slave
	wb_slave_reassign rnm1(.A_i(slave0_interface_io),.B_o(interfaces[1]));
	// Rename an interface *from* a slave
	wb_slave_reassign rnm2(.A_i(slave1_interface_io),.B_o(interfaces[2]));
	// Rename an interface *from* a slave
	wb_slave_reassign rnm3(.A_i(slave2_interface_io),.B_o(interfaces[3]));
	// 
	wb_slave_reassign rnm4(.A_i(slave3_interface_io),.B_o(interfaces[4]));
	//
	wb_slave_reassign rnm5(.A_i(slave4_interface_io),.B_o(interfaces[5]));
	//
	wb_slave_reassign rnm6(.A_i(slave5_interface_io),.B_o(interfaces[6]));
	//
	wb_slave_reassign rnm7(.A_i(slave6_interface_io),.B_o(interfaces[7]));
	//
	wb_slave_reassign rnm8(.A_i(slave7_interface_io),.B_o(interfaces[8]));
	//
	wb_slave_reassign rnm9(.A_i(slave8_interface_io),.B_o(interfaces[9]));

	wire [NUM_SLAVES-1:0] slave_select;
	wire [15:0] slave_address[NUM_SLAVES-1:0];
	wire [7:0] slave_dat[NUM_SLAVES-1:0];
	wire [NUM_SLAVES-1:0] slave_ack;
	wire [NUM_SLAVES-1:0] slave_err;
	wire [NUM_SLAVES-1:0] slave_rty;
	
	wire [15:0] master_address;
	wire master_cyc;
	wire master_stb;
	wire master_wr;
	wire [7:0] master_dat;

	// Multiplexed signals.
	wire [7:0] slave_dat_mux;
	wire slave_ack_mux;
	wire slave_rty_mux;
	wire slave_err_mux;
	
	
	// The interface expanders are currently manually instantiated. Will update this
	// eventually.
	generate
		genvar sl_i;
		for (sl_i=0;sl_i<NUM_INTERFACES;sl_i=sl_i+1) begin : CLK_RESET
			// Distribute clocks and reset.
			wb_syscon syscon(.interface_io(interfaces[sl_i]),.clk_i(clk_i),.rst_i(rst_i));
			if (sl_i > 0) begin : SLAVES
				// Create one demultiplexed master for each slave.
				wb_master demuxed_master(.interface_io(interfaces[sl_i]),
												 .dat_i(master_dat),
												 .cyc_i(master_cyc),
												 .stb_i(slave_select[sl_i-1]),
												 .wr_i(master_wr),
												 .adr_i(slave_address[sl_i-1]),
												 .dat_o(slave_dat[sl_i-1]),
												 .ack_o(slave_ack[sl_i-1]),
												 .rty_o(slave_rty[sl_i-1]),
												 .err_o(slave_err[sl_i-1]));
			end else begin : MASTER
				// Create one multiplexed slave for the master.
				wb_slave muxed_slave(.interface_io(interfaces[0]),
											.cyc_o(master_cyc),
											.stb_o(master_stb),
											.wr_o(master_wr),
											.dat_o(master_dat),
											.adr_o(master_address),
											.ack_i(slave_ack_mux),
											.rty_i(slave_rty_mux),
											.err_i(slave_err_mux),
											.dat_i(slave_dat_mux));
			end
		end
	endgenerate
	
	generate
		genvar slm_i;
		for (slm_i=0;slm_i<NUM_SLAVES;slm_i=slm_i+1) begin : SL_LOOP
			if (slm_i==0) begin : SLAVE_0
				assign slave_dat_mux = (slave_select[slm_i]) ? slave_dat[slm_i] : {8{1'bZ}};
				assign slave_err_mux = (slave_select[slm_i]) ? slave_err[slm_i] : 1'bZ;
				assign slave_rty_mux = (slave_select[slm_i]) ? slave_rty[slm_i] : 1'bZ;
				assign slave_ack_mux = (slave_select[slm_i]) ? slave_ack[slm_i] : 1'bZ;
			end else begin : SLAVES
				assign slave_dat_mux = (slave_select[slm_i] && (slave_select[slm_i-1:0] == {slm_i{1'b0}})) ?
											  slave_dat[slm_i] : {8{1'bZ}};
				assign slave_err_mux = (slave_select[slm_i] && (slave_select[slm_i-1:0] == {slm_i{1'b0}})) ?
											  slave_err[slm_i] : 1'bZ;
				assign slave_rty_mux = (slave_select[slm_i] && (slave_select[slm_i-1:0] == {slm_i{1'b0}})) ?
											  slave_rty[slm_i] : 1'bZ;
				assign slave_ack_mux = (slave_select[slm_i] && (slave_select[slm_i-1:0] == {slm_i{1'b0}})) ?
											  slave_ack[slm_i] : 1'bZ;
			end
		end
		assign slave_dat_mux = (slave_select == {NUM_SLAVES{1'b0}}) ? {8{1'b1}} : {8{1'bZ}};
		assign slave_err_mux = (slave_select == {NUM_SLAVES{1'b0}}) ? 1'b0 : 1'bZ;
		assign slave_rty_mux = (slave_select == {NUM_SLAVES{1'b0}}) ? 1'b0 : 1'bZ;
		assign slave_ack_mux = (slave_select == {NUM_SLAVES{1'b0}}) ? master_cyc : 1'bZ;
	endgenerate
	
	/*
	always @(slave_select or slave_dat[0]) begin
		if (slave_select[0]) begin
			slave_dat_mux <= slave_dat[0];
		end else if (slave_select[1]) begin
			slave_dat_mux <= slave_dat[1];
		end else begin // this might want to change to pick a default slave
			slave_dat_mux <= {8{1'b0}};
		end
	end
	always @(slave_select or slave_err[0]) begin
		if (slave_select[0]) begin
			slave_err_mux <= slave_err[0];
		end else begin
			slave_err_mux <= 0;
		end
	end
	always @(slave_select or slave_rty[0]) begin
		if (slave_select[0]) begin
			slave_rty_mux <= slave_rty[0];
		end else begin
			slave_rty_mux <= 0;
		end
	end
	always @(slave_select or slave_ack[0]) begin
		if (slave_select[0]) begin
			slave_ack_mux <= slave_ack[0];
		end else begin
			slave_ack_mux <= 0;
		end
	end
	*/
	// Address mapping.
	// Slave 1: ID block, 16 addresses
	// The first slave gets 16 addresses from 0x00-0x0F (15:4 == 12'h000)
	assign slave_select[0] =  master_stb && master_address[15:4] == 12'h000;
	assign slave_address[0] = {{12{1'b0}},master_address[3:0]}; 			
	// Slave 2: Power control, 16 addresses
	// Second slave gets 16 addresses from 0x10-0x1F (15:4 == 12'h001)
	assign slave_select[1] =  master_stb && master_address[15:4] == 12'h001;
	assign slave_address[1] = {{12{1'b0}},master_address[3:0]};
	// Slave 3: IRS control, 32 addresses
	// Third slave gets 32 addresses from 0x20-0x3F (15:4 == 12'h002 or 12'h003)
	assign slave_select[2] = master_stb && (master_address[15:4] == 12'h002 
													 || master_address[15:4] == 12'h003);
	assign slave_address[2] = {{11{1'b0}},master_address[4:0]};
	// Slave 4: PPS/timing, 16 addresses
	// Fourth slave gets 16 addresses from 0x40-0x4F (15:4 == 12'h004)
	assign slave_select[3] = master_stb && master_address[15:4] == 12'h004;
	assign slave_address[3] = {{12{1'b0}},master_address[3:0]};
	// Slave 5: Scaler period definitions
	// Fifth slave gets 16 addresses from 0x50-0x5F (15:4 == 12'h005)
	assign slave_select[4] = master_stb && master_address[15:4] == 12'h005;
	assign slave_address[4] = {{12{1'b0}},master_address[3:0]};
	// Slave 6: Trigger control.
	// Sixth slave gets 16 addresses from 0x60-0x7F (15:4 == 12'h006/12'h007)
	assign slave_select[5] = master_stb && (master_address[15:4] == 12'h006 || master_address[15:4]==12'h007);
	assign slave_address[5] = {{11{1'b0}},master_address[4:0]};
	// Right now, more slaves can be inserted from 0x80-0xFF (blocks 8-15).
	// Those can still be added AFTER slave 7 here. The order of the slave
	//	to address mapping is unimportant.
	// Slave 7: Scalers.
	// Seventh slave gets 256 addresses from 0x0100-0x01FF (15:8 == 8'h01)
	assign slave_select[6] = master_stb && master_address[15:8] == 8'h01;
	assign slave_address[6] = {{8{1'b0}},master_address[7:0]};
	// Slave 8: Deadtime statistics block.
	// Slave 8 gets 16 addresses from 0x80-0x8F (15:4 = 12'h007)
	assign slave_select[7] = master_stb && master_address[15:4] == 12'h008;
	assign slave_address[7] = {{12{1'b0}},master_address[3:0]};
	// Slave 9: IRS phase shift data.
	// Slave 9 gets 256 addresses from 0x0200-0x02FF (15:8 = 8'h02)
	assign slave_select[8] = master_stb && master_address[15:8] == 8'h02;
	assign slave_address[8] = {{8{1'b0}},master_address[7:0]};
	
endmodule
