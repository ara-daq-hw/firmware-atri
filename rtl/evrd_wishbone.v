`timescale 1ns / 1ps
`include "wb_interface.vh"

module evrd_wishbone(
		interface_io,
		clk_i,
		evcount_i,
		blkcount_i,
		evrd_err_i,
		pps_i,
		readout_ready_i,
		sampling_i,
		sampling_ce_i,
		KHz_CE_i,
		MHz_CE_i
    );

	inout [`WBIF_SIZE-1:0] interface_io;
	input clk_i;
	input [15:0] evcount_i;
	input [8:0] blkcount_i;
	input [7:0] evrd_err_i;
	input pps_i;
	input readout_ready_i;
	input sampling_i;
	input sampling_ce_i;
	input KHz_CE_i;
	input MHz_CE_i;
	
	// INTERFACE_INS wb wb_slave RPL clk_i wb_clk_i
	wire wb_clk_i;
	wire rst_i;
	wire cyc_i;
	wire wr_i;
	wire stb_i;
	wire ack_o;
	wire err_o;
	wire rty_o;
	wire [15:0] adr_i;
	wire [7:0] dat_i;
	wire [7:0] dat_o;
	wb_slave wbif(.interface_io(interface_io),
	              .clk_o(wb_clk_i),
	              .rst_o(rst_i),
	              .cyc_o(cyc_i),
	              .wr_o(wr_i),
	              .stb_o(stb_i),
	              .ack_i(ack_o),
	              .err_i(err_o),
	              .rty_i(rty_o),
	              .adr_o(adr_i),
	              .dat_o(dat_i),
	              .dat_i(dat_o));
	// INTERFACE_END
	assign err_o = 0;
	assign rty_o = 0;

	reg pps_local = 0;
	reg evcount_min_update = 0;
	reg blkcount_max_update = 0;
	
	reg [15:0] evcount_dly = {16{1'b0}};
	reg [8:0] blkcount_dly = {9{1'b0}};
	always @(posedge clk_i) begin
		evcount_dly <= evcount_i;
		blkcount_dly <= blkcount_i;
	end
	
	// We average the event count, read out every millisecond (KHz).
	// Each is maximum 65535, so we need 26 bits of space.
	reg [25:0] evcount_avg_irsclk = {18{1'b0}};
	reg [15:0] evcount_avg_latched = {16{1'b0}};
	reg [15:0] evcount_avg = {16{1'b0}};
	reg [15:0] evcount_min_irsclk = {16{1'b0}};
	reg [15:0] evcount_min_latched = {16{1'b0}};
	reg [15:0] evcount_min = {16{1'b0}};
	
	// Block count is max 256, so we need 18 bits of space.
	reg [17:0] blkcount_avg_irsclk = {18{1'b0}};
	reg [8:0] blkcount_avg_latched = {9{1'b0}};
	reg [8:0] blkcount_max_irsclk = {9{1'b0}};
	reg [8:0] blkcount_max_latched = {9{1'b0}};
	reg [8:0] blkcount_max = {9{1'b0}};
	reg [8:0] blkcount_avg = {9{1'b0}};

	// Deadtime is counted as:
	// If we were dead at all in the last microsecond (MHz_CE)
	// then we add 1 to the deadtime counter. This gives
	// a maximum of around 1M, which is 20 bits, so we prescale
	// by 4. Thus '5% deadtime' gives a value around 3125.
	wire [15:0] deadtime_latched_wbclk;
	
	wire [15:0] notready_latched_wbclk;
	wire [15:0] totdead_latched_wbclk;

	wire pps_flag_wbclk;

	always @(posedge clk_i) begin
		pps_local <= pps_i;
	end

	// Check minimum every cycle, but register it.
	always @(posedge clk_i) begin
		evcount_min_update <= (evcount_i < evcount_min_irsclk);
	end
	// Update mins. 
	always @(posedge clk_i) begin
		if (pps_local)
			evcount_min_irsclk <= {16{1'b1}};
		else begin
			if (evcount_min_update)
				evcount_min_irsclk <= evcount_dly;
		end
	end
	// Latch minimum.
	always @(posedge clk_i) begin
		if (pps_local) 
			evcount_min_latched <= evcount_min_irsclk;
	end

	// Update max every cycle
	always @(posedge clk_i) begin
		blkcount_max_update <= (blkcount_i > blkcount_max_irsclk);
	end	
	always @(posedge clk_i) begin
		if (pps_local)
			blkcount_max_irsclk <= {9{1'b0}};
		else begin
			if (blkcount_max_update) begin
				blkcount_max_irsclk <= blkcount_dly;
			end
		end
	end
	always @(posedge clk_i) begin
		if (pps_local) 
			blkcount_max_latched <= blkcount_max_irsclk;
	end


	// Averaging.
	always @(posedge clk_i) begin
		if (pps_local) 
			blkcount_avg_irsclk <= {11{1'b0}};
		else if (KHz_CE_i) begin
			blkcount_avg_irsclk <= blkcount_avg_irsclk + blkcount_dly;
		end
	end
	always @(posedge clk_i) begin
		if (pps_local)
			blkcount_avg_latched <= blkcount_avg_irsclk[17:9];
	end
	
	always @(posedge clk_i) begin
		if (pps_local) evcount_avg_irsclk <= {18{1'b0}};
		else if (KHz_CE_i) begin
			evcount_avg_irsclk <= evcount_avg_irsclk + evcount_dly;
		end
	end
	always @(posedge clk_i) begin
		if (pps_local) evcount_avg_latched <= evcount_avg_irsclk[25:10];
	end
	
	flag_sync update_sync(.in_clkA(pps_local),.out_clkB(pps_flag_wbclk),.clkA(clk_i),.clkB(wb_clk_i));
	always @(posedge wb_clk_i) begin
		if (pps_flag_wbclk) begin
			evcount_min <= evcount_min_latched;
			blkcount_max <= blkcount_max_latched;
			evcount_avg <= evcount_avg_latched;
			blkcount_avg <= blkcount_avg_latched;
		end
	end



	reg [7:0] evread_error_sync = {8{1'b0}};
	always @(posedge wb_clk_i) evread_error_sync <= evrd_err_i;
	
	reg [7:0] evread_error = {8{1'b0}};
	always @(posedge wb_clk_i) evread_error <= evread_error_sync;

	periodic_stat_counter #(.COUNTER_WIDTH(20), .VALUE_WIDTH(16))
		deadtime_counter(.count_i(!sampling_i && sampling_ce_i),.count_ce_i(MHz_CE_i),
							  .pps_i(pps_local),.value_o(deadtime_latched_wbclk),
							  .clk_count_i(clk_i),.clk_val_i(wb_clk_i));

	periodic_stat_counter #(.COUNTER_WIDTH(20), .VALUE_WIDTH(16))
		notready_counter(.count_i(!readout_ready_i),.count_ce_i(MHz_CE_i),
							  .pps_i(pps_local),.value_o(notready_latched_wbclk),
							  .clk_count_i(clk_i),.clk_val_i(wb_clk_i));

	periodic_stat_counter #(.COUNTER_WIDTH(20), .VALUE_WIDTH(16))
		totdead_counter(.count_i((!sampling_i && sampling_ce_i) || !readout_ready_i),
							  .count_ce_i(MHz_CE_i),
							  .pps_i(pps_local),.value_o(totdead_latched_wbclk),
							  .clk_count_i(clk_i),.clk_val_i(wb_clk_i));
							  
	wire [7:0] wishbone_registers[31:0];

	function [4:0] BASE;
		input [15:0] bar_value;
		begin
			BASE = bar_value[4:0];
		end
	endfunction		

	`define OUTPUT(addr, x, range, dummy) 					\
		assign wishbone_registers[ addr ] range = x
	`define SELECT(addr, x, addrrange, dummy)          \
		wire x;														\
		localparam [4:0] addr_``x = addr;				   \
		assign x = (cyc_i && stb_i && wr_i && ack_o && (adr_i addrrange == addr_``x addrrange))
	`define SIGNALRESET(addr, x, range, resetval) 						\
		always @(posedge clk_i) begin				    						\
			if (rst_o) x <= resetval ;					 						\
			else if (cyc_i && stb_i && (adr_i[3:0] == addr) && wr_i) \
				x <= dat_i range ;												\
		end																			\
		assign wishbone_registers[addr] range  = x	 					
	`define WISHBONE_ADDRESS( addr, name, TYPE, par1, par2) \
		`TYPE(BASE(addr), name, par1, par2)
		
	`WISHBONE_ADDRESS(16'h0080, evread_error, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0081, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0082, evcount_avg[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0083, evcount_avg[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0084, evcount_min[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0085, evcount_min[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0086, blkcount_avg[7:0], OUTPUT, [7:0], 0);
	
	`WISHBONE_ADDRESS(16'h0087, blkcount_avg[8], OUTPUT, [0], 0);
	`WISHBONE_ADDRESS(16'h0087, {7{1'b0}}, OUTPUT, [7:1], 0);
	`WISHBONE_ADDRESS(16'h0088, blkcount_max[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0089, blkcount_max[8], OUTPUT, [0], 0);
	`WISHBONE_ADDRESS(16'h0089, {7{1'b0}}, OUTPUT, [7:1], 0);
	
	`WISHBONE_ADDRESS(16'h008A, deadtime_latched_wbclk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h008B, deadtime_latched_wbclk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h008C, notready_latched_wbclk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h008D, notready_latched_wbclk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h008E, totdead_latched_wbclk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h008F, totdead_latched_wbclk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0090, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0091, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0092, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0093, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0094, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0095, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0096, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0097, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0098, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0099, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009A, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009B, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009C, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009D, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009E, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h009F, {8{1'b0}}, OUTPUT, [7:0], 0);

	`undef OUTPUT
	`undef SELECT
	`undef SIGNAL_RESET
	`undef WISHBONE_ADDRESS

	reg wb_ack = 0;
	assign ack_o = wb_ack;
	reg [7:0] data_muxed = {8{1'b0}};
	// 1 cycle of latency.
	always @(posedge wb_clk_i) begin
		if (!wb_ack)
			wb_ack <= cyc_i && stb_i;
		else
			wb_ack <= 0;
	end
	always @(posedge wb_clk_i) 
		if (cyc_i && stb_i) data_muxed <= wishbone_registers[adr_i[4:0]];
	assign dat_o = data_muxed;

endmodule
