`timescale 1ns / 1ps

`include "wb_interface.vh"
`include "irswb_interface.vh"

//% IRS WISHBONE interface, version 2. This one has interfaces to up to 4 daughters.
//% Expanding this is trivial, though.

// IRS wishbone interface:
// bit 0: irs_clk_i (assigned in top level interconnect)
// bit 1: wb_clk_i (assign in top level interconnect)
// bit 2: enable
// bit 3: software trigger enable
// bit [11:4]: TSA monitor value
// bit 12: tsa monitor update
// bit 13: start TSA monitoring
// bit [23:14]: wilkinson monitor value
// bit [24]: wilkinson monitor update
// bit [25]: start wilkinson monitoring
// bit [26]: IRS pedestal mode
// bit [35:27]: IRS pedestal address
// bit [36]: IRS pedmode clear
//
// NOTE: TRIGGER ENABLES WERE REMOVED FROM HERE.
// They are now in the trigger control wishbone block, under trigger_top.
//
// NOTE: The masks don't actually work yet.
module irs_wishbone_v2(
		inout [`WBIF_SIZE-1:0] wb_interface_io,
	
		inout [`IRSWBIF_SIZE-1:0] irswb_interface1_io,
		inout [`IRSWBIF_SIZE-1:0] irswb_interface2_io,
		inout [`IRSWBIF_SIZE-1:0] irswb_interface3_io,
		inout [`IRSWBIF_SIZE-1:0] irswb_interface4_io,
		// Global software trigger. An irs2_top will ignore this
		// trigger if its enable is not high.
		output soft_trig_o,
		input soft_trig_dis_i,
		// Software trigger info. This is just a 16-bit counter, reset
		// by writing 1 to bit 1 of SOFTTRIG[15:0]
		output [31:0] soft_trig_info_o,
		output refclk_en_o
    );

	parameter NUM_DAUGHTERS = 4;
	parameter MAX_DAUGHTERS = 4;
	
	// WISHBONE interface expander
	// INTERFACE_INS wb wb_slave RPL interface_io wb_interface_io
	wire clk_i;
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
	wb_slave wbif(.interface_io(wb_interface_io),
	              .clk_o(clk_i),
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
	assign rty_o = 0;
	assign err_o = 0;

	reg [7:0] dat_o_mux = {8{1'b0}};
	assign dat_o = dat_o_mux;

	////////////////////////////////////////////////////////////////////////////
	// REGISTERS
	////////////////////////////////////////////////////////////////////////////
	reg irs_enable = 0;
	reg n_refclk_en = 0;
	reg [NUM_DAUGHTERS-1:0] irs_daughter_enable = {NUM_DAUGHTERS{1'b1}};
	reg ped_mode_en = 0;
	reg [NUM_DAUGHTERS-1:0] ped_mode_daughter_en = {NUM_DAUGHTERS{1'b1}};

	reg [8:0] ped_address = {9{1'b0}};
	
	wire ped_clear;
	
	wire soft_trig;
	wire soft_trig_info_reset;
	reg [NUM_DAUGHTERS-1:0] soft_trig_daughter_en = {NUM_DAUGHTERS{1'b1}};
	// Soft trig generator
	wire [3:0] soft_trig_nblk;
	wire [3:0] soft_trig_info;
	wire soft_trig_write_nblk;

	// IRS reset, in WB clock domain
	reg irs_rst_wbclk = 0;
	
	reg [3:0] soft_trig_extra_blocks = {4{1'b0}};
	// Internal register for soft trig counter.
	reg [15:0] soft_trig_counter = {16{1'b0}};
	
	reg [NUM_DAUGHTERS-1:0] tsa_mon_en = {NUM_DAUGHTERS{1'b0}};

	reg [NUM_DAUGHTERS-1:0] wilk_mon_en = {NUM_DAUGHTERS{1'b0}};
	
	// Selects IRS1-2 behavior or IRS3 behavior.
	reg [NUM_DAUGHTERS-1:0] irs_mode = {NUM_DAUGHTERS{1'b0}};
	
	reg [9:0] wilk_monitor_wbclk[NUM_DAUGHTERS-1:0];
	reg [7:0] tsa_monitor_wbclk[NUM_DAUGHTERS-1:0];
	reg [7:0] daughter_chmask[NUM_DAUGHTERS-1:0];
	integer init_i;
	initial begin
		for (init_i=0;init_i<NUM_DAUGHTERS;init_i=init_i+1) begin
			wilk_monitor_wbclk[init_i] <= {10{1'b0}};
			tsa_monitor_wbclk[init_i] <= {10{1'b0}};
			daughter_chmask[init_i] <= {8{1'b1}};
		end
	end

	reg [7:0] trigger_daughter_en = {8{1'b1}};
	wire [NUM_DAUGHTERS-1:0] trigger_den[1:0];
	generate
		genvar te_i;
		for (te_i=0;te_i<NUM_DAUGHTERS;te_i=te_i+1) begin : TRIG_EN_LOOP
			assign trigger_den[0][te_i] = trigger_daughter_en[te_i];
			assign trigger_den[1][te_i] = trigger_daughter_en[4+te_i];
		end
	endgenerate

	reg [11:0] sbbias = 12'h7FF;
	reg [11:0] wilkcnt = 12'd620;
				
	////////////////////////////////////////////////////////////////////////////
	// IRSWB INTERFACES
	////////////////////////////////////////////////////////////////////////////

	wire [`IRSWBIF_SIZE-1:0] irswb_interfaces[MAX_DAUGHTERS-1:0];
	irswb_irs_reassign a_d1(irswb_interface1_io, irswb_interfaces[0]);
	irswb_irs_reassign a_d2(irswb_interface2_io, irswb_interfaces[1]);
	irswb_irs_reassign a_d3(irswb_interface3_io, irswb_interfaces[2]);
	irswb_irs_reassign a_d4(irswb_interface4_io, irswb_interfaces[3]);

	wire [7:0] tsa_mon_i[NUM_DAUGHTERS-1:0];
	wire [NUM_DAUGHTERS-1:0] tsa_mon_update_i;
	wire [NUM_DAUGHTERS-1:0] tsa_mon_update_wbclk;
	wire [9:0] wilk_mon_i[NUM_DAUGHTERS-1:0];
	wire [NUM_DAUGHTERS-1:0] wilk_mon_update_i;
	wire [NUM_DAUGHTERS-1:0] wilk_mon_update_wbclk;

	wire [NUM_DAUGHTERS-1:0] irs_clk_i;
	generate
		genvar i;
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin : IRSWB
// NOTE: If an irs2_top is not enabled, it will not do anything on a trigger
// except update its event and trigger pointers. It won't read anything out.
// Obviously for the current format you just need to 'know' that the daughters
// are disabled. Maybe in a future version we'll have something which says
// which daughters are masked off in the event data stream. 
			wire enable_wbclk = irs_daughter_enable[i] && irs_enable;
			wire ped_mode_wbclk = ped_mode_daughter_en[i] && ped_mode_en;
// PSA, changes for 0.6.0: Soft trig is generated here, and gated by an irs_top.
// NOTE: This doesn't actually do anything yet.
//			wire strig_wbclk = soft_trig && soft_trig_daughter_en[i];
			wire enable;
			wire ped_mode;
			wire strigen;
			wire [1:0] trigen;
			wire tsamonstart;
			wire wilkmonstart;
			wire irs_rst;
			wire irsmode;
			signal_sync enable_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(enable_wbclk),
											.out_clkB(enable));
			signal_sync pedmode_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(ped_mode_wbclk),
											 .out_clkB(ped_mode));
			signal_sync tsamonstart_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(tsa_mon_en[i]),
											 .out_clkB(tsamonstart));
			signal_sync wilkmonstart_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(wilk_mon_en[i]),
											.out_clkB(wilkmonstart));
			signal_sync irsmode_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(irs_mode[i]),
											 .out_clkB(irsmode));
// PSA: No actual daughterboard soft trig only disables yet.
//			signal_sync en_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(soft_trig_daughter_en[i]),
//										.out_clkB(strigen));
// PSA: No actual daughterboard rf trig only disables yet.
//			signal_sync tren0_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(trigger_den[0][i]),
//                              .out_clkB(trigen[0]));
//			signal_sync tren1_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(trigger_den[1][i]),
//                              .out_clkB(trigen[1]));
//
			flag_sync irsrst_sync(.clkA(clk_i),.clkB(irs_clk_i[i]),.in_clkA(irs_rst_wbclk),
										 .out_clkB(irs_rst));
			irswb_wb irsif(.interface_io(irswb_interfaces[i]),
								.irs_clk_o(irs_clk_i[i]),
								.wb_clk_i(clk_i),
								.enable_i(enable),

// PSA: No actual daughterboard soft trig only disables yet.
								.soft_trig_en_i(1'b1),
// PSA: No actual daughterboard RF trig only disables yet.
								.rf_trig_en_i(2'b11),
								
								.tsa_mon_o(tsa_mon_i[i]),
								.tsa_mon_update_o(tsa_mon_update_i[i]),
								.tsa_mon_start_i(tsamonstart),
								.wilk_mon_o(wilk_mon_i[i]),
								.wilk_mon_update_o(wilk_mon_update_i[i]),
								.wilk_mon_start_i(wilkmonstart),
								.ped_mode_i(ped_mode),
								.ped_address_i(ped_address),
								.ped_clear_i(ped_clear),
								.ch_mask_i(daughter_chmask[i]),
								.irs_mode_i(irsmode),
								.irs_rst_i(irs_rst),
								.sbbias_i(sbbias),
								.wilkcnt_i(wilkcnt));								
			flag_sync tsa_update_flag_sync(.clkA(irs_clk_i[i]),.clkB(clk_i),
													 .in_clkA(tsa_mon_update_i[i]),
													 .out_clkB(tsa_mon_update_wbclk[i]));
			flag_sync wilk_update_flag_sync(.clkA(irs_clk_i[i]),.clkB(clk_i),
													  .in_clkA(wilk_mon_update_i[i]),
													  .out_clkB(wilk_mon_update_wbclk[i]));
			always @(posedge clk_i) begin
				if (tsa_mon_update_wbclk[i])
					tsa_monitor_wbclk[i] <= tsa_mon_i[i];
			end
			always @(posedge clk_i) begin
				if (wilk_mon_update_wbclk[i])
					wilk_monitor_wbclk[i] <= wilk_mon_i[i];
			end	
		end
	endgenerate
	
	// WISHBONE REGISTERS
	// IRSEN[15:0]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0000)
			irs_enable <= dat_i[0];
	end
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0000)
			n_refclk_en <= dat_i[2];
	end
	always @(posedge clk_i) begin
		if (irs_rst_wbclk)
			irs_rst_wbclk <= 0;
		else if (cyc_i && stb_i && wr_i && adr_i == 16'h0000)
			irs_rst_wbclk <= dat_i[3];
	end

	// IRS daughter enable is IRSEN[11:8]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0001)
			irs_daughter_enable <= dat_i[NUM_DAUGHTERS-1:0];
	end
	// IRS modes are IRSEN[15:12]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0001)
			irs_mode <= dat_i[ 4 +: NUM_DAUGHTERS ];
	end

	// TSAMONEN[7:0]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0002)
			tsa_mon_en <= dat_i[NUM_DAUGHTERS-1:0];
	end
	// WILKMONEN[7:0]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0003)
			wilk_mon_en <= dat_i[NUM_DAUGHTERS-1:0];
	end

	// IRSPEDEN[15:0]
	assign ped_clear = (cyc_i && stb_i && wr_i && adr_i == 16'h0004) && (dat_i[1]);
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0004)
			ped_mode_en <= dat_i[0];
	end
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0005)
			ped_mode_daughter_en <= dat_i[NUM_DAUGHTERS-1:0];
	end
	// IRSPED[15:0]
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0006)
			ped_address[7:0] <= dat_i;
	end
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0007)
			ped_address[8] <= dat_i[0];
	end
	// SOFTTRIG[15:0]
	assign soft_trig = dat_i[0] && (adr_i == 16'h000A) && cyc_i && stb_i && wr_i;
	assign soft_trig_info_reset = (|dat_i[7:4]) && (adr_i == 16'h000A) && cyc_i && stb_i && wr_i;
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h000B)
			soft_trig_daughter_en <= dat_i[NUM_DAUGHTERS-1:0];
	end
	assign soft_trig_write_nblk = (adr_i == 16'h000B) && cyc_i && stb_i && wr_i;
	atri_var_trig_generator #(.COUNTER_WIDTH(4),.INFO_WIDTH(4))
		soft_gen(.slow_clk_i(clk_i),.fast_clk_i(irs_clk_i[0]),
					.s_rst_i(1'b0),.f_rst_i(1'b0),
					.s_nblk_new_i(dat_i[7:4]),
					.s_nblk_o(soft_trig_nblk),
					.s_nblk_write_i(soft_trig_write_nblk),
					.s_start_i(soft_trig),
					.s_clr_info_i(soft_trig_info_reset),
					.s_info_o(soft_trig_info),
					.f_info_o(soft_trig_info_o[3:0]),
					.f_trig_o(soft_trig_o),
					.disable_i(soft_trig_dis_i)
					);

	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && adr_i == 16'h0009)
			trigger_daughter_en <= dat_i;
	end

	// DxCHMASK[7:0]
	integer chmask_i;
	always @(posedge clk_i) begin
		for (chmask_i=0;chmask_i<NUM_DAUGHTERS;chmask_i=chmask_i+1) begin
			// This is 16'h000C + daughter number.
			if (cyc_i && stb_i && wr_i && adr_i[15:4] == 12'h000 && adr_i[3:2] == 2'b11 && adr_i[1:0] == chmask_i)
				daughter_chmask[chmask_i] <= dat_i;
		end
	end	
	
	// SBBIAS/WILKCNT
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && (adr_i[15:0] == 16'd28 || adr_i[15:0] == 16'd29)) begin
			if (!adr_i[0]) sbbias[7:0] <= dat_i[7:0];
			if (adr_i[0]) sbbias[11:8] <= dat_i[3:0];
		end
	end
	always @(posedge clk_i) begin
		if (cyc_i && stb_i && wr_i && (adr_i[15:0] == 16'd30 || adr_i[15:0] == 16'd31)) begin
			if (!adr_i[0]) wilkcnt[7:0] <= dat_i[7:0];
			if (adr_i[0]) wilkcnt[11:8] <= dat_i[3:0];
		end
	end
	
	// ACK GENERATION
	assign ack_o = cyc_i && stb_i;

	// WISHBONE data out registers. There are 32 total registers available.
	wire [7:0] wb_register[31:0];
	assign wb_register[0] = {{5{1'b0}},n_refclk_en,1'b0,irs_enable};
	assign wb_register[1] = {{8-NUM_DAUGHTERS{1'b0}},irs_daughter_enable};
	assign wb_register[2] = {{8-NUM_DAUGHTERS{1'b0}},tsa_mon_en};
	assign wb_register[3] = {{8-NUM_DAUGHTERS{1'b0}},wilk_mon_en};
	assign wb_register[4] = {{7{1'b0}},ped_mode_en};
	assign wb_register[5] = {{8-NUM_DAUGHTERS{1'b0}},ped_mode_daughter_en};
	assign wb_register[6] = ped_address[7:0];
	assign wb_register[7] = {{7{1'b0}},ped_address[8]};
	// 8,9 are trigger enables
	assign wb_register[8] = {8{1'b0}};
	assign wb_register[9] = {8{1'b0}};
	assign wb_register[10] = {soft_trig_info,{4{1'b0}}};
	assign wb_register[11][7:4] = soft_trig_nblk;
	assign wb_register[11][NUM_DAUGHTERS-1:0] = soft_trig_daughter_en;
	assign wb_register[28] = sbbias[7:0];
	assign wb_register[29] = {4'b0000,sbbias[11:8]};
	assign wb_register[30] = wilkcnt[7:0];
	assign wb_register[31] = {4'b0000,wilkcnt[11:8]};
	
	// 12,13, 16,17, 20,21, 24,25 are Wilkinson monitors
	// 14,15, 18,19, 22,23, 26,27 are TSA monitors
	generate
		genvar r_i;
		for (r_i=0;r_i<MAX_DAUGHTERS;r_i=r_i+1) begin : REGS
			if (r_i < NUM_DAUGHTERS) begin : DAUGHTER
				assign wb_register[12 + 4*r_i] = wilk_monitor_wbclk[r_i][7:0];
				assign wb_register[12 + 4*r_i + 1] = {{6{1'b0}},wilk_monitor_wbclk[r_i][9:8]};
				assign wb_register[12 + 4*r_i + 2] = tsa_monitor_wbclk[r_i][7:0];
				assign wb_register[12 + 4*r_i + 3] = {8{1'b0}};
			end else begin : EMPTY
				assign wb_register[12 + 4*r_i] = {8{1'b0}};
				assign wb_register[12 + 4*r_i + 1] = {8{1'b0}};
				assign wb_register[12 + 4*r_i + 2] = {8{1'b0}};
				assign wb_register[12 + 4*r_i + 3] = {8{1'b0}};
			end
		end
	endgenerate

	// DATA OUT MULTIPLEX
	wire [7:0] wb_register_demux = wb_register[adr_i[4:0]];
	
	always @(dat_o_mux or wb_register_demux) begin
		dat_o_mux <= wb_register_demux;
	end
	
	assign refclk_en_o = !n_refclk_en;
endmodule
