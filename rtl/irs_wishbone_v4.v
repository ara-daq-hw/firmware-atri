`timescale 1ns / 1ps
//% @brief Integrated IRS WISHBONE module.
`include "wb_interface.vh"
`include "irsi2c_interface.vh"
module irs_wishbone_v4(
		interface_io,
		d1_i2cif_io,
		d2_i2cif_io,
		d3_i2cif_io,
		d4_i2cif_io,
		
		clk_i,
		MHz_CE_i,
		KHz_CE_i,
		rst_o,
		rst_ack_i,
		
		enable_o,
		test_mode_o,
		
		ped_mode_o,
		ped_addr_o,
		ped_sample_o,
		
		tstout_i,
		wilk_start_o,

		tsaout_i,

		initbusy_i,
		sbbias_o,
		init_o,
		irsmode_o,
		maskaddr_i,
		mask_o,
		power_i,
		soft_trig_o,
		soft_trig_info_o,
		readout_delay_o,

		sync_i,
		sst_i,
		sample_debug_o
    );

	parameter NUM_DAUGHTERS = 4;
	parameter MAX_DAUGHTERS = 4;
	parameter SENSE = "SLOW";

	// Delay from new event to readout. This is a counter that the PicoBlaze counts down,
	// so it's roughly units of 4 clocks (40 ns). There's also an additional overhead of
	// something like 4 instructions (80 ns).
	//
	// This is *NOT* the lookback delay! That's set in the trigger control module. This is
	// just to guarantee that, in a single-buffered setup, that the first block is read out
	// well after the sampling ends.
	parameter [7:0] READOUT_DELAY_DEFAULT = 8'd18;

	`include "clogb2.vh"
	localparam NMXD_BITS = clogb2(MAX_DAUGHTERS-1);
	
	inout [`WBIF_SIZE-1:0] interface_io;
	inout [`IRSI2CIF_SIZE-1:0] d1_i2cif_io;
	inout [`IRSI2CIF_SIZE-1:0] d2_i2cif_io;
	inout [`IRSI2CIF_SIZE-1:0] d3_i2cif_io;
	inout [`IRSI2CIF_SIZE-1:0] d4_i2cif_io;
	
	input clk_i;
	input MHz_CE_i;
	input KHz_CE_i;
	output rst_o;
	input rst_ack_i;
	output enable_o;
	output test_mode_o;

	output ped_mode_o;
	output [8:0] ped_addr_o;
	output ped_sample_o;
	
	input [MAX_DAUGHTERS-1:0] tstout_i;
	output [MAX_DAUGHTERS-1:0] wilk_start_o;
	input [MAX_DAUGHTERS-1:0] tsaout_i;
	
	input [MAX_DAUGHTERS-1:0] initbusy_i;
	output [11:0] sbbias_o;
	output [MAX_DAUGHTERS-1:0] init_o;
	output [MAX_DAUGHTERS-1:0] irsmode_o;
	
	input [NMXD_BITS-1:0] maskaddr_i;
	output [7:0] mask_o;
	
	input [MAX_DAUGHTERS-1:0] power_i;
	
	output soft_trig_o;
	output [7:0] soft_trig_info_o;

	output [7:0] readout_delay_o;

	input sync_i;
	input sst_i;
	output [52:0] sample_debug_o;
	
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
	
	// Vectorize the IRSI2C interfaces.
	wire [`IRSI2CIF_SIZE-1:0] i2cif_io[MAX_DAUGHTERS-1:0];
	irsi2c_i2c_reassign d1re(.A_i(d1_i2cif_io),.B_o(i2cif_io[0]));
	irsi2c_i2c_reassign d2re(.A_i(d2_i2cif_io),.B_o(i2cif_io[1]));
	irsi2c_i2c_reassign d3re(.A_i(d3_i2cif_io),.B_o(i2cif_io[2]));
	irsi2c_i2c_reassign d4re(.A_i(d4_i2cif_io),.B_o(i2cif_io[3]));
	wire [MAX_DAUGHTERS-1:0] v_i2c_clk_i;
	wire [MAX_DAUGHTERS-1:0] v_irs_init_o;
	wire [1:0] v_gpio_o[MAX_DAUGHTERS-1:0];
	wire [1:0] v_gpio_ack_i[MAX_DAUGHTERS-1:0];

	// All the I2C clocks are the same.
	wire i2cclk = v_i2c_clk_i[0];
	// Expand the IRSI2C interfaces, and generate the IRS init generator.
	generate
		genvar ci;
		for (ci=0;ci<MAX_DAUGHTERS;ci=ci+1) begin : I2CIF
			// INTERFACE_INS irsi2c irsi2c_irs RPL interface_io i2cif_io[ci] NODECL irs_clk_o RPL irs_clk_o clk_i
			wire i2c_clk_i;
			wire irs_init_o;
			wire [1:0] gpio_o;
			wire [1:0] gpio_ack_i;
			irsi2c_irs irsi2cif(.interface_io(i2cif_io[ci]),
			                    .irs_clk_i(clk_i),
			                    .i2c_clk_o(i2c_clk_i),
			                    .irs_init_i(irs_init_o),
			                    .gpio_i(gpio_o),
			                    .gpio_ack_o(gpio_ack_i));
			// INTERFACE_END
			assign v_i2c_clk_i[ci] = i2c_clk_i;
			assign gpio_o = v_gpio_o[ci];
			assign v_gpio_ack_i[ci] = gpio_ack_i;

			irs_init_generator #(.SENSE(SENSE)) 
					irs_init(.clk_i(clk_i),.power_i(power_i[ci]),
								.slow_ce_i(KHz_CE_i),
								.micro_ce_i(MHz_CE_i),
								.init_o(irs_init_o),
								.is_init_o(init_o[ci]));
			// Goes high when the power has been on for a while.
			// Off when the ack has been received.
			reg do_start = 0;
			// Goes on and stays on once init is done.
			reg did_start = 0;
			// Indicates that GPIO1 (TSTCLR) has fired.
			reg gpio1_done = 0;
			always @(posedge clk_i) begin : DO_START
				if (!power_i[ci] || did_start) do_start <= 0;
				else if (init_o[ci] && !did_start) do_start <= 1;
			end
			always @(posedge clk_i) begin : DID_START
				if (!power_i[ci]) did_start <= 0;
				else if (gpio_ack_i[0]) did_start <= 1;
			end
			always @(posedge clk_i) begin : GPIO1_DONE
				if (!power_i[ci]) gpio1_done <= 0;
				else if (gpio_ack_i[1]) gpio1_done <= 1;
			end
			// These need to be FLAGS
			// First flag GPIO1 (TSTCLR)
			wire do_gpio1 = do_start && !gpio1_done && !gpio_ack_i[1];
			SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"))
				gpio1_req(.I(do_gpio1),.O(v_gpio_o[ci][1]),.CLK(clk_i));
			// Then flag GPIO0 (TSTST)
			wire do_gpio0 = do_start && gpio1_done && !gpio_ack_i[0];
			SYNCEDGE #(.EDGE("RISING"),.CLKEDGE("RISING"))
				gpio0_req(.I(do_gpio0),.O(v_gpio_o[ci][0]),.CLK(clk_i));
		end
	endgenerate

	///////////////////////////////////////////////////////
	// REGISTERS                                         //
	///////////////////////////////////////////////////////

	//% IRS control register.
	reg [15:0] irsctl = {16{1'b0}};
	
	//% Output of the irsctl register. Unlinked ones will be trimmed.
	wire [15:0] irsctl_out;
	
	//% IRS pedestal mode control register. Only 4 bits.
	reg [3:0] pedctl = {4{1'b0}};
	
	//% IRS pedestal mode address.
	reg [8:0] pedaddr = {16{1'b0}};
	
	//% IRS mask pointer.
	reg [NMXD_BITS-1:0] maskptr = {NMXD_BITS{1'b0}};

	//% IRS masks.
	reg [7:0] irsmask[NUM_DAUGHTERS-1:0];

	//% IRS mask outputs. Dummy ones never get connected so the registers
	//% should be optimized away.
	wire [7:0] irsmask_out[MAX_DAUGHTERS-1:0];
	
	//% Software trigger control.
	reg [7:0] softtrigctl = {8{1'b0}};
	
	//% Software trigger info.
	reg [7:0] softtriginfo = {8{1'b0}};

	//% Sbbias. This will be expanded to an IRS register pointer/value.
	reg [11:0] sbbias = {12{1'b0}};
	
	//% Sbbias output.
	wire [15:0] sbbias_out = {{3{1'b0}},initbusy_i,sbbias};

	//% Readout delay output. This is the delay, in blocks (20 ns), from new event->readout
	reg [7:0] readout_delay = READOUT_DELAY_DEFAULT;
	
	//% Wilkinson counter values.
	wire [15:0] wilkinson_counter[MAX_DAUGHTERS-1:0];
	wire [15:0] d1wilk = wilkinson_counter[0];
	wire [15:0] d2wilk = wilkinson_counter[1];
	wire [15:0] d3wilk = wilkinson_counter[2];
	wire [15:0] d4wilk = wilkinson_counter[3];
	
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
		
	`WISHBONE_ADDRESS(16'h0020, irsctl_wr, SELECT, [4:1], 0);
	`WISHBONE_ADDRESS(16'h0020, irsctl_out[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0021, irsctl_out[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0022, readout_delay, SIGNALRESET, [7:0], READOUT_DELAY_DEFAULT);
	`WISHBONE_ADDRESS(16'h0023, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0024, irspedctl_wr, SELECT, [4:1], 0);
	`WISHBONE_ADDRESS(16'h0024, pedctl[3:0], OUTPUT, [4:0], 0);
	`WISHBONE_ADDRESS(16'h0024, {4{1'b0}}, OUTPUT, [7:4], 0);
	`WISHBONE_ADDRESS(16'h0025, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0026, irspedaddr_wr, SELECT, [4:1], 0);
	`WISHBONE_ADDRESS(16'h0026, pedaddr[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0027, pedaddr[8], OUTPUT, [0], 0);
	`WISHBONE_ADDRESS(16'h0027, {7{1'b0}}, OUTPUT, [7:1], 0);
	`WISHBONE_ADDRESS(16'h0028, maskptr, SIGNALRESET, [NMXD_BITS-1:0], {NMXD_BITS{1'b0}});
	`WISHBONE_ADDRESS(16'h0028, {8-NMXD_BITS{1'b0}}, OUTPUT, [7 -: (8-NMXD_BITS)], 0);
	`WISHBONE_ADDRESS(16'h0029, mask_wr, SELECT, [4:0], 0);
	`WISHBONE_ADDRESS(16'h0029, irsmask_out[maskaddr_i], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h002A, softtrig_wr, SELECT, [4:0], 0);
	`WISHBONE_ADDRESS(16'h002A, softtrigctl, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h002B, softtriginfo, SIGNALRESET, [7:0], {8{1'b0}});
	`WISHBONE_ADDRESS(16'h002C, d1wilk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h002D, d1wilk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h002E, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h002F, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0030, d2wilk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0031, d2wilk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0032, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0033, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0034, d3wilk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0035, d3wilk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0036, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0037, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0038, d4wilk[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h0039, d4wilk[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003A, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003B, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003C, sbbias_wr, SELECT, [4:1], 0);
	`WISHBONE_ADDRESS(16'h003C, sbbias_out[7:0], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003D, sbbias_out[15:8], OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003E, {8{1'b0}}, OUTPUT, [7:0], 0);
	`WISHBONE_ADDRESS(16'h003F, {8{1'b0}}, OUTPUT, [7:0], 0);

	`undef OUTPUT
	`undef SELECT
	`undef SIGNAL_RESET
	`undef WISHBONE_ADDRESS

	// Synchronize the irsctl register.
	//% irsctl rising edge.
	wire irsctl_edge_wr;
	//% irsctl wr flag in irsclk domain.
	wire irsctl_irsclk_wr;

	//% Generate flag in wb_clk domain.
	SYNCEDGE #(.EDGE("FALLING"),.LATENCY(0)) irsctl_wr_edge(.I(irsctl_wr),.O(irsctl_edge_wr),.CLK(wb_clk_i));
	//% Pass over to IRS clock domain.
	flag_sync irsctl_sync(.in_clkA(irsctl_edge_wr),.out_clkB(irsctl_irsclk_wr),.clkA(wb_clk_i),.clkB(clk_i));
	//% irsctl in irsclk domain.
	reg [15:0] irsctl_irsclk = {16{1'b0}};
	//% irsctl output: bit 2 is a pure output.
	assign irsctl_out = {irsctl[15:3],rst_ack_i,irsctl[1:0]};
	// Soft trig control.
	always @(posedge wb_clk_i) begin
		if (rst_o) softtrigctl <= {8{1'b0}};
		else begin
			if (softtrig_wr) softtrigctl <= dat_i;
			else if (softtrigctl[0]) softtrigctl[0] <= 0;
		end
	end
	// Softtrigctl needs to be passed to our little soft trig generator module.
	// Will do that soon...
	
	// This SHOULD generate a dual-port RAM from distributed RAM.
	assign mask_o = irsmask_out[maskaddr_i];
	
	always @(posedge wb_clk_i) begin
		if (rst_o) begin
			pedctl <= {4{1'b0}};
		end else begin
			if (irspedctl_wr && !adr_i[0]) begin
				pedctl <= dat_i[3:0];
			end else begin
				pedctl[3] <= 0;
			end
		end
	end
	// FIXME this is NOT in the right clock domain! Qualify it off the acknowledge
	// flag synced back to wb_clk_i
	wire ped_flag_advance = (pedctl[3] && pedctl[1]);
	wire ped_flag_advance_delayed;
	// Delay the advance flag a while.
	Generic_Pipeline #(.LATENCY(16)) 
		ped_flag_delay(.I(ped_flag_advance),.O(ped_flag_advance_delayed),.CLK(wb_clk_i));
	always @(posedge wb_clk_i) begin
		if (rst_o) pedaddr <= {9{1'b0}};
		else if (irspedaddr_wr) begin
			if (!adr_i[0])
				pedaddr[7:0] <= dat_i[7:0];
			else
				pedaddr[8] <= dat_i[0];
		end else if (ped_flag_advance_delayed) begin
			pedaddr <= pedaddr + 1;
		end
	end

	wire pedsofttrig = (pedctl[2] && pedctl[3]);
	wire pedsofttrig_irsclk;
	signal_sync pedmode_sync(.in_clkA(pedctl[0]),.out_clkB(ped_mode_o),.clkA(wb_clk_i),.clkB(clk_i));
	flag_sync pedsample_sync(.in_clkA(pedctl[3]),.out_clkB(ped_sample_o),.clkA(wb_clk_i),.clkB(clk_i));
	flag_sync pedtrig_sync(.in_clkA(pedsofttrig),.out_clkB(pedsofttrig_irsclk),.clkA(wb_clk_i),.clkB(clk_i));

	assign ped_addr_o = pedaddr;
	
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
	// Software trigger crap
	wire soft_trig_flag;
	wire soft_trig_flag_irsclk;
	SYNCEDGE #(.EDGE("RISING")) soft_trig_gen(.I(softtrigctl[0]),.O(soft_trig_flag),.CLK(wb_clk_i));
	flag_sync soft_trig_sync(.in_clkA(soft_trig_flag),.out_clkB(soft_trig_flag_irsclk),.clkA(wb_clk_i),.clkB(clk_i));
	assign soft_trig_o = soft_trig_flag_irsclk | pedsofttrig_irsclk;
	assign soft_trig_info_o = softtriginfo;

	always @(posedge wb_clk_i) begin
		if (irsctl_wr) begin
			if (!adr_i[0]) irsctl[7:0] <= dat_i;
			else irsctl[15:8] <= dat_i;
		end
	end
	always @(posedge clk_i) begin
		if (irsctl_irsclk_wr)
			irsctl_irsclk <= irsctl;
	end

	// IRS mask generation.
	generate
		genvar mdi;
		for (mdi=0;mdi<MAX_DAUGHTERS;mdi=mdi+1) begin : ML
			if (mdi < NUM_DAUGHTERS) begin : MASK
				initial begin : INIT
					irsmask[mdi] <= {8{1'b0}};
				end
				always @(posedge wb_clk_i) begin : LOGIC
					if (mask_wr && maskptr == mdi) irsmask[mdi] <= dat_i;
				end
				assign irsmask_out[mdi] = irsmask[mdi];
			end else begin : DUM
				assign irsmask_out[mdi] = {8{1'b1}};
			end
		end
	endgenerate

	// Wilkinson monitor generation
	generate
		genvar wilki;
		for (wilki=0;wilki<MAX_DAUGHTERS;wilki=wilki+1) begin : WL
			if (wilki < NUM_DAUGHTERS) begin : WILK_MON
				wire [15:0] counter;
				irs_wilkinson_monitor wilk_mon(.clk_i(wb_clk_i),.rst_i(irsctl[1]),.TSTOUT(tstout_i[wilki]),
														 .count_o(counter));
				assign wilkinson_counter[wilki] = counter;
			end else begin : DUMMY
				assign wilkinson_counter[wilki] = {16{1'b0}};
			end
		end
	endgenerate
	// Sample monitor.
	wire [7:0] irs_smon[3:0];
	atri_sample_monitor smon(.clk_i(clk_i),.rst_i(rst_o),.en_i(enable_o),.sync_i(sync_i),.sst_i(sst_i),
									 .sample_mon_i(tsaout_i),
									 .irs1_mon_o(irs_smon[0]),
									 .irs2_mon_o(irs_smon[1]),
									 .irs3_mon_o(irs_smon[2]),
									 .irs4_mon_o(irs_smon[3]),
									 .debug_o(sample_debug_o));


	always @(posedge wb_clk_i) begin
		if (sbbias_wr) begin
			if (!adr_i[0]) sbbias[7:0] <= dat_i;
			else sbbias[11:8] <= dat_i[3:0];
		end
	end
	// IRSCTL[0] = enable
	// IRSCTL[1] = reset
	// IRSCTL[2] = reset_ack
	// IRSCTL[15:12] = irsmode

	assign enable_o = irsctl_irsclk[0];
	assign rst_o = irsctl_irsclk[1];
	assign test_mode_o = irsctl_irsclk[3];
	assign sbbias_o = sbbias;
	assign irsmode_o = irsctl[15:12];
	assign wilk_start_o = {MAX_DAUGHTERS{1'b1}};
	assign readout_delay_o = readout_delay;
endmodule
