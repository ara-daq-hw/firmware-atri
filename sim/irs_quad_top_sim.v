`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   12:52:06 08/21/2012
// Design Name:   irs_quad_top
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/irs_quad_top_sim.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: irs_quad_top
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

`include "irsi2c_interface.vh"
`include "wb_interface.vh"
`include "irs_interface.vh"
`include "trigger_defs.vh"
`include "ev2_interface.vh"

module irs_quad_top_sim;

	parameter MAX_DAUGHTERS = 4;
	parameter NUM_L4 = `SCAL_NUM_L4;
	`include "clogb2.vh"
	parameter NL4_BITS = clogb2(NUM_L4-1);
	parameter INFO_BITS = `INFO_BITS;
	// Inputs
	reg clk_i;
	reg clk180_i;
	reg clk_shift_i;
	wire KHz_clk_i;
	wire MHz_clk_i;
	reg pps_i;
	reg [15:0] pps_counter_i;
	reg [31:0] cycle_counter_i;
	reg trig_i;
	reg [8:0] trig_offset_i;
	reg [NUM_L4-1:0] trig_l4_i;
	reg [NUM_L4-1:0] trig_l4_new_i;
	reg [INFO_BITS-1:0] trig_info_i;

	// Outputs
	wire [NL4_BITS-1:0] trig_info_addr_o;
	wire trig_info_rd_o;

	// Bidirs
	wire [`IRSIF_SIZE-1:0] irs1_if_io;
	wire [`IRSIF_SIZE-1:0] irs2_if_io;
	wire [`IRSIF_SIZE-1:0] irs3_if_io;
	wire [`IRSIF_SIZE-1:0] irs4_if_io;
	wire [`EV2IF_SIZE-1:0] ev2_if_io;
	wire [`IRSI2CIF_SIZE-1:0] irsi2c1_if_io;
	wire [`IRSI2CIF_SIZE-1:0] irsi2c2_if_io;
	wire [`IRSI2CIF_SIZE-1:0] irsi2c3_if_io;
	wire [`IRSI2CIF_SIZE-1:0] irsi2c4_if_io;
	wire [`WBIF_SIZE-1:0] irs_wbif_io;

	// Instantiate the Unit Under Test (UUT)
	irs_quad_top #(.SENSE("FAST")) uut (
		.irs1_if_io(irs1_if_io), 
		.irs2_if_io(irs2_if_io), 
		.irs3_if_io(irs3_if_io), 
		.irs4_if_io(irs4_if_io), 
		.ev2_if_io(ev2_if_io), 
		.irsi2c1_if_io(irsi2c1_if_io), 
		.irsi2c2_if_io(irsi2c2_if_io), 
		.irsi2c3_if_io(irsi2c3_if_io), 
		.irsi2c4_if_io(irsi2c4_if_io), 
		.irs_wbif_io(irs_wbif_io), 
		.clk_i(clk_i), 
		.clk180_i(clk180_i), 
		.clk_shift_i(clk_shift_i), 
		.KHz_clk_i(KHz_clk_i), 
		.MHz_clk_i(MHz_clk_i), 
		.pps_i(pps_i), 
		.pps_counter_i(pps_counter_i), 
		.cycle_counter_i(cycle_counter_i), 
		.trig_i(trig_i), 
		.trig_offset_i(trig_offset_i), 
		.trig_l4_i(trig_l4_i), 
		.trig_l4_new_i(trig_l4_new_i), 
		.trig_info_i(trig_info_i), 
		.trig_info_addr_o(trig_info_addr_o), 
		.trig_info_rd_o(trig_info_rd_o)
	);

	// Expand the interfaces.
	// WISHBONE
	reg wb_clk = 0;
	// INTERFACE_INS wb wb_syscon RPL wbif wbsyscon RPL interface_io irs_wbif_io RPL clk_o wb_clk NODECL clk_o
	wire rst_o;
	wb_syscon wbsyscon(.interface_io(irs_wbif_io),
	               .clk_i(wb_clk),
	               .rst_i(rst_o));
	// INTERFACE_END

	// INTERFACE_INS wb wb_master RPL wbif wbmaster RPL interface_io irs_wbif_io RPL clk_i wb_clk_i_out RPL adr_o wb_adr_o RPL dat_o wb_dat_o RPL dat_i wb_dat_i
	wire wb_clk_i_out;
	wire rst_i;
	wire cyc_o;
	wire wr_o;
	wire stb_o;
	wire ack_i;
	wire err_i;
	wire rty_i;
	wire [15:0] wb_adr_o;
	wire [7:0] wb_dat_o;
	wire [7:0] wb_dat_i;
	wb_master wbmaster(.interface_io(irs_wbif_io),
	               .clk_o(wb_clk_i_out),
	               .rst_o(rst_i),
	               .cyc_i(cyc_o),
	               .wr_i(wr_o),
	               .stb_i(stb_o),
	               .ack_o(ack_i),
	               .err_o(err_i),
	               .rty_o(rty_i),
	               .adr_i(wb_adr_o),
	               .dat_i(wb_dat_o),
	               .dat_o(wb_dat_i));
	// INTERFACE_END

	reg wb_clk_i = 0;
	reg [15:0] wb_adr = {16{1'b0}};
	assign wb_adr_o = wb_adr;
	reg [7:0] wb_dat = {8{1'b0}};
	assign wb_dat_o = wb_dat;
	reg wb_cyc = 0;
	reg wb_wr = 0;
	assign cyc_o = wb_cyc;
	assign stb_o = wb_cyc;
	assign wr_o = wb_wr;
	assign rst_o = 0;
	
	// IRS->I2C, IRS
	// Vectorize first.
	wire [`IRSI2CIF_SIZE-1:0] i2cif[MAX_DAUGHTERS-1:0];
	irsi2c_irs_reassign D1re(.A_i(irsi2c1_if_io),.B_o(i2cif[0]));
	irsi2c_irs_reassign D2re(.A_i(irsi2c2_if_io),.B_o(i2cif[1]));
	irsi2c_irs_reassign D3re(.A_i(irsi2c3_if_io),.B_o(i2cif[2]));
	irsi2c_irs_reassign D4re(.A_i(irsi2c4_if_io),.B_o(i2cif[3]));
	wire [`IRSIF_SIZE-1:0] irsif[MAX_DAUGHTERS-1:0];
	irs_ctrl_reassign D1ire(.A_i(irs1_if_io),.B_o(irsif[0]));
	irs_ctrl_reassign D2ire(.A_i(irs2_if_io),.B_o(irsif[1]));
	irs_ctrl_reassign D3ire(.A_i(irs3_if_io),.B_o(irsif[2]));
	irs_ctrl_reassign D4ire(.A_i(irs4_if_io),.B_o(irsif[3]));
	
	wire KHz_wbclk;
	wire MHz_wbclk;
	atri_slow_clock_generator scgen(.clk_i(wb_clk),.reset_i(1'b0),.KHz_CE_o(KHz_wbclk),.MHz_CE_o(MHz_wbclk));
	flag_sync khz(.in_clkA(KHz_wbclk),.out_clkB(KHz_clk_i),.clkA(wb_clk),.clkB(clk_i));
	flag_sync mhz(.in_clkA(MHz_wbclk),.out_clkB(MHz_clk_i),.clkA(wb_clk),.clkB(clk_i));

	wire [11:0] irsdat[MAX_DAUGHTERS-1:0];
	wire [MAX_DAUGHTERS-1:0] irststout;
	wire [MAX_DAUGHTERS-1:0] irstsaout;
	reg [MAX_DAUGHTERS-1:0] power = {MAX_DAUGHTERS{1'b0}};
	reg [MAX_DAUGHTERS-1:0] drive = {MAX_DAUGHTERS{1'b0}};
	generate
		genvar ii,j;
		for (ii=0;ii<4;ii=ii+1) begin : I2C
			// INTERFACE_INS irsi2c irsi2c_i2c RPL interface_io i2cif[ii] RPL i2c_clk_o wb_clk NODECL i2c_clk_o
			wire irs_clk_i;
			wire irs_init_i;
			wire [1:0] gpio_i;
			wire [1:0] gpio_ack_o;
			irsi2c_i2c irsi2cif(.interface_io(i2cif[ii]),
			                    .irs_clk_o(irs_clk_i),
			                    .i2c_clk_i(wb_clk),
			                    .irs_init_o(irs_init_i),
			                    .gpio_o(gpio_i),
			                    .gpio_ack_i(gpio_ack_o));
			// INTERFACE_END
			assign gpio_ack_o[0] = gpio_i[0];
			assign gpio_ack_o[1] = gpio_i[1];			
			// INTERFACE_INS irs irs_infra RPL interface_io irsif[ii] RPL power_o power[ii] NODECL power_o RPL drive_o drive[ii] NODECL drive_o RPL dat_o irsdat[ii] NODECL dat_o RPL tstout_o irststout[ii] NODECL tstout_o RPL tsaout_o irstsaout[ii] NODECL tsaout_o
			wire [5:0] smp_i;
			wire [2:0] ch_i;
			wire smpall_i;
			wire ramp_i;
			wire start_i;
			wire clr_i;
			wire [9:0] wr_i;
			wire wrstrb_i;
			wire [9:0] rd_o;
			wire [9:0] rdo_i;
			wire [9:0] rdoe_i;
			wire rden_i;
			wire tsa_i;
			wire tsa_close_i;
			irs_infra irsif(.interface_io(irsif[ii]),
			                .dat_i(irsdat[ii]),
			                .smp_o(smp_i),
			                .ch_o(ch_i),
			                .smpall_o(smpall_i),
			                .ramp_o(ramp_i),
			                .start_o(start_i),
			                .clr_o(clr_i),
			                .wr_o(wr_i),
			                .wrstrb_o(wrstrb_i),
			                .rd_i(rd_o),
			                .rdo_o(rdo_i),
			                .rdoe_o(rdoe_i),
			                .rden_o(rden_i),
			                .tsa_o(tsa_i),
			                .tsa_close_o(tsa_close_i),
			                .tsaout_i(irstsaout[ii]),
			                .tstout_i(irststout[ii]),
			                .power_i(power[ii]),
			                .drive_i(drive[ii]));
			// INTERFACE_END
			// RDOE is positive logic (backwards from IOBUF's T input!)
			for (j=0;j<10;j=j+1) begin : RDIO
				assign rd_o[j] = (!rdoe_i[j]) ? 1'bZ : rdo_i[j];
			end
		end
	endgenerate

	// Event interface
	// INTERFACE_INS ev2 ev2_fifo RPL interface_io ev2_if_io RPL dat_o evdat_o RPL count_i evcnt_i RPL rst_ack_i evrst_ack RPL wr_i evwr_i RPL full_o evfull_o RPL rst_i evrst_i
	wire irsclk_i;
	wire [15:0] dat_i;
	wire [15:0] count_o;
	wire evwr_i;
	wire evfull_o;
	wire evrst_i;
	wire rst_ack_o;
	ev2_fifo ev2if(.interface_io(ev2_if_io),
	               .irsclk_o(irsclk_i),
	               .dat_o(dat_i),
	               .count_i(count_o),
	               .wr_o(evwr_i),
	               .full_i(evfull_o),
	               .rst_o(evrst_i),
	               .rst_ack_i(rst_ack_o));
	// INTERFACE_END
	
	// fake the output count.
	assign count_o = {16{1'b1}};
	assign evfull_o = 1'b0;
	assign rst_ack_o = evrst_i;
	
	always begin
		#5 clk_i = ~clk_i;
	end
	always @(clk_i) clk180_i <= ~clk_i;
	always @(clk_i) #2.5 clk_shift_i <= clk_i;

	always begin
		#10.42 wb_clk = ~wb_clk;
	end

	always @(posedge clk_i) begin
		cycle_counter_i[27:0] <= cycle_counter_i[27:0] + 1;
	end
	
	

	initial begin
		// Initialize Inputs
		clk_i = 0;
		clk180_i = 0;
		clk_shift_i = 0;
		pps_i = 0;
		pps_counter_i = 0;
		cycle_counter_i = 0;
		trig_i = 0;
		trig_offset_i = 0;
		trig_l4_i = 0;
		trig_l4_new_i = 0;
		trig_info_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

		power = {MAX_DAUGHTERS{1'b1}};
		drive = {MAX_DAUGHTERS{1'b1}};
		// wait a while

		// Just a simple enable. Let's see what this does.
		@(posedge wb_clk);
		wb_adr = 16'h0020;
		wb_dat = 8'h01;
		wb_cyc = 1;
		wb_wr = 1;
		#1;
		while (!ack_i) @(posedge wb_clk);
		wb_cyc = 0;
		wb_wr = 0;
		#1000;
		// Now let's try actually triggering.
		@(posedge clk_i);
		trig_i = 1;
		trig_l4_i = 4'hF;
		trig_l4_new_i = 4'hF;
		@(posedge clk_i);
		@(posedge clk_i);
		trig_i = 0;
		trig_l4_i = 4'h0;
		trig_l4_new_i = 4'h0;
		
		end

	reg [15:0] evcount = {16{1'b0}};

	always @(posedge clk_i) begin
		if (evwr_i) 
			evcount <= evcount + 1;
	end
	
endmodule

