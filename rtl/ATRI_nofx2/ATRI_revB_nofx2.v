`timescale 1ns / 1ps

`include "ev2_interface.vh"

//////////////////////////////////////////////////////////////////////////////////
// 
// ATRI rev B top-level module. atri_core based design, no FX2 chip.
//
//////////////////////////////////////////////////////////////////////////////////
module ATRI_revB_nofx2(
		output [9:0] D4WR,
		output D4WRSTRB,
		inout [9:0] D4RD,
		output D4RDEN,
		output [5:0] D4SMP,
		output D4SMPALL,
		output [2:0] D4CH,
		input [11:0] D4DAT,
		output D4TSA,
		input D4TSAOUT,
		output D4TSA_CLOSE,
		output D4RAMP,
		output D4START,
		output D4CLR,
		input D4TSTOUT,
		input [7:0] D4TRG_P,
		input [7:0] D4TRG_N,
		inout D4DDASENSE,
		inout D4TDASENSE,
		inout D4SDA,
		inout D4SCL,
		inout [10:9] D4DRSV,
		output [2:0] D4DRSV_P,
		output [2:0] D4DRSV_N,
		inout [0:0] D4ARSV,
		input [2:1] D4CRSV_P,
		input [2:1] D4CRSV_N,

		output [9:0] D3WR,
		output D3WRSTRB,
		inout [9:0] D3RD,
		output D3RDEN,
		output [5:0] D3SMP,
		output D3SMPALL,
		output [2:0] D3CH,
		input [11:0] D3DAT,
		output D3TSA,
		input D3TSAOUT,
		output D3TSA_CLOSE,
		output D3RAMP,
		output D3START,
		output D3CLR,
		input D3TSTOUT,
		input [7:0] D3TRG_P,
		input [7:0] D3TRG_N,
		inout D3DDASENSE,
		inout D3TDASENSE,
		inout D3SDA,
		inout D3SCL,
		inout [10:9] D3DRSV,
		output [2:0] D3DRSV_P,
		output [2:0] D3DRSV_N,
		inout [0:0] D3ARSV,
		input [2:1] D3CRSV_P,
		input [2:1] D3CRSV_N,

		output [9:0] D2WR,
		output D2WRSTRB,
		inout [9:0] D2RD,
		output D2RDEN,
		output [5:0] D2SMP,
		output D2SMPALL,
		output [2:0] D2CH,
		input [11:0] D2DAT,
		output D2TSA,
		input D2TSAOUT,
		output D2TSA_CLOSE,
		output D2RAMP,
		output D2START,
		output D2CLR,
		input D2TSTOUT,
		input [7:0] D2TRG_P,
		input [7:0] D2TRG_N,
		inout D2DDASENSE,
		inout D2TDASENSE,
		inout D2SDA,
		inout D2SCL,
		inout [10:9] D2DRSV,
		output [2:0] D2DRSV_P,
		output [2:0] D2DRSV_N,
		inout [0:0] D2ARSV,
		input [2:1] D2CRSV_P,
		input [2:1] D2CRSV_N,

		output [9:0] D1WR,
		output D1WRSTRB,
		inout [9:0] D1RD,
		output D1RDEN,
		output [5:0] D1SMP,
		output D1SMPALL,
		output [2:0] D1CH,
		input [11:0] D1DAT,
		output D1TSA,
		input D1TSAOUT,
		output D1TSA_CLOSE,
		output D1RAMP,
		output D1START,
		output D1CLR,
		input D1TSTOUT,
		input [7:0] D1TRG_P,
		input [7:0] D1TRG_N,
		inout D1DDASENSE,
		inout D1TDASENSE,
		inout D1SDA,
		inout D1SCL,
		inout [10:9] D1DRSV,
		output [2:0] D1DRSV_P,
		output [2:0] D1DRSV_N,
		inout [0:0] D1ARSV,
		input [2:1] D1CRSV_P,
		input [2:1] D1CRSV_N,

		input FPGA_REFCLK_P,
		input FPGA_REFCLK_N,

		inout [15:0] FD,
		input FLAGA,
		input FLAGB,
		input FLAGC,
		input FLAGD,
		output SLOE,
		output SLRD,
		output SLWR,
		output [1:0] FIFOADR,
		output PKTEND,

		inout [5:0] GPIO,
		input IFCLK,
		
		input PPS_IN,
		input FPTRIG_IN,
		
		inout [17:0] BRSV,
		output CRSV0_P,
		output CRSV0_N,
		
		input sys_reset_n,
		input sys_clk_p,
		input sys_clk_n,
		output pci_exp_txp,
		output pci_exp_txn,
		input pci_exp_rxp,
		input pci_exp_rxn	


		
    );
	 
	////////////////////////////////////////////////////////////////
	//             TOP-LEVEL CONFIGURATION PARAMETERS             //
	////////////////////////////////////////////////////////////////

	//% "YES": multiplexed IRS/TRIG. "PC": debug=PC. "I2C": I2C controller. "IRS": IRS. "PCIE": PCIE interface. "NONE": no cores.
	parameter DEBUG = "PC";
	//% IFCLK phase shift. For behavioral simulations, set this to 0.
	parameter IFCLK_PS = -80;
	//% Determines whether or not daughterboard sensing happens slow (ms) or fast (ns)
	parameter SENSE = "SLOW";
	//% Number of daughterboards
	parameter NUM_DAUGHTERS = 4;
//	//% Include the PCIe placeholder (turn off for debugging)
//	parameter PCIE = "YES";		//FIXME: PCIE is always active
	//% Size of the event FIFO. Needs to be MEDIUM or smaller for miniATRI.
	parameter EVENT_FIFO = "LARGE";
	//% Tristate the reserved pins, or drive them.
	parameter BRSV_TRISTATE = "YES";
	//% Single ended or differential CRSV0.
	parameter CRSV0_TYPE = "LVDS";
	//% Whether or not to implement reserved pins.
	parameter IMPLEMENT_RESERVED = "YES";

	
	//BOARD_ID = "ATR0" for ARA02, "ATRI" otherwise.
	parameter [31:0] BOARD_ID = "ATRI";
	parameter [3:0] VER_BOARD = 1;
	parameter [3:0] VER_MONTH = 12;
	parameter [7:0] VER_DAY = 4;
	parameter [3:0] VER_MAJOR = 0;
	parameter [3:0] VER_MINOR = 15;
	parameter [7:0] VER_REV = 111;

	localparam MAX_DAUGHTERS = 4;


	/////////////////////////////////////////////////////////////////
	// PHY GOES HERE
	/////////////////////////////////////////////////////////////////
	wire pcie_clk;
	// generate the clock
	wire xIFCLK;
	wire icapclk;
	// clock reset
	// we have to mangle things here b/c of
	// clock crossings.
	wire phy_rst;
	reg [1:0] quiesce_rereg_ifclk = {2{1'b0}};
	wire ifclk_rst;
	
	// originally had this as quiesce && !icap_not_empty_pcieclk
	// but that doesn't work, since it kills the icap clk before
	// everything completes.
	// instead we need to set a register when icap becomes not empty
	// and ONLY reset it on icap.
	(* KEEP = "TRUE" *)
	reg icap_busy_sync_pcieclk = 0;
	(* KEEP = "TRUE" *)
	reg icap_busy_pcieclk = 0;
	reg icap_busy = 0;
   wire  quiesce;
	// we want to reset the clock when the system is reset, so
	// we can use quiesce. But we can't use quiesce when the ICAP is
	// not empty, because that's our trigger to reprogram ourselves.
	ifclk_infrastructure u_ifclk(.pcie_clk(pcie_clk),
										  .rst_i(quiesce && !icap_busy_pcieclk),
										  .rst_o(ifclk_rst),
										  .icapclk(icapclk),
										  .ifclk(xIFCLK));


	wire [52:0] pcie_debug;
	
	// INTERFACE_INS ev2 ev2_fifo RPL interface_io ev2_if_io
	wire ev2_irsclk;
	wire [15:0] ev2_dat;
	wire [15:0] ev2_count;
	wire ev2_wr;
	wire ev2_full;
	wire ev2_rst;
	wire ev2_rst_ack;
	wire [`EV2IF_SIZE-1:0] event_interface;
	
	ev2_fifo ev2if(.interface_io(event_interface),
	               .irsclk_o(ev2_irsclk),
	               .dat_o(ev2_dat),
	               .count_i(ev2_count),
	               .wr_o(ev2_wr),
	               .full_i(ev2_full),
	               .rst_o(ev2_rst),
	               .rst_ack_i(ev2_rst_ack));
	// INTERFACE_END	
	
	//% IRS clock infrastructure.
	atri_clock_generator irs_clock_gen(.FPGA_REFCLK_P(FPGA_REFCLK_P),.FPGA_REFCLK_N(FPGA_REFCLK_N),
											 .irs_sys_clk(irs_sys_clk),.irs_sys_clk180(irs_sys_clk180));

	wire MHz_CE;
	wire KHz_CE;	

	//% Slow clock infrastructure
	atri_slow_clock_generator slow_clock_gen(.clk_i(xIFCLK),.KHz_CE_o(KHz_CE),.MHz_CE_o(MHz_CE), .reset_i(1'b0));

	wire pps_flag;
	wire pps_async;
	wire pps_output;
	//% PPS flag generator. This debounces the PPS, but its leading edge is still async to everything else.
	atri_pps_flag_generator pps_flag_gen(.clk_i(xIFCLK),
													 .KHz_CE_i(KHz_CE),
													 .PPS_IN(PPS_IN),
													 .pps_o(pps_output),
													 .pps_async_o(pps_async),.pps_flag_o(pps_flag));
	
	wire [52:0] debug;
	wire [52:0] bridge_debug;
	
	wire [7:0] phy_to_pc;
	wire [7:0] phy_from_pc;
	wire phy_wr;
	wire phy_rd;
	wire to_phy_empty;
	wire from_phy_full;	

	(* KEEP = "TRUE" *)
	reg phy_rst_sync_pcie = 0;
	(* KEEP = "TRUE" *)
	reg phy_rst_pcie = 0;

	reg [19:0] bridge_debug_reg = {20{1'b0}};
	always @(posedge pcie_clk) begin
		icap_busy_sync_pcieclk <= icap_busy;
		icap_busy_pcieclk <= icap_busy_sync_pcieclk;
		
		phy_rst_sync_pcie <= phy_rst;
		phy_rst_pcie <= phy_rst_sync_pcie;
		
		bridge_debug_reg[0 +: 8] <= phy_to_pc;
		bridge_debug_reg[8 +: 8] <= phy_from_pc;
		bridge_debug_reg[16] <= phy_wr;
		bridge_debug_reg[17] <= phy_rd;
		bridge_debug_reg[18] <= to_phy_empty;
		bridge_debug_reg[19] <= from_phy_full;
	end
	assign bridge_debug[0 +: 20] = bridge_debug_reg;
	assign bridge_debug[21] = ifclk_rst;
	assign bridge_debug[22] = phy_rst_pcie;
/*	
	assign bridge_debug[0 +: 8] = phy_to_pc;
	assign bridge_debug[8 +: 8] = phy_from_pc;
	assign bridge_debug[16] = phy_wr;
	assign bridge_debug[17] = phy_rd;
	assign bridge_debug[18] = to_phy_empty;
	assign bridge_debug[19] = from_phy_full;
	*/
	// xillybus
	assign bridge_debug[23] = quiesce;
	// we need to datapath only restrict quiesce -> quiesce_rereg_ifclk*
	always @(posedge xIFCLK) begin
		quiesce_rereg_ifclk <= {quiesce_rereg_ifclk[0], quiesce};
	end
	wire phy_rst_delay;
	SRLC32E u_phyrst_delay(.D(phy_rst),.CLK(xIFCLK),.CE(1'b1),.Q31(phy_rst_delay));
	// if quiesce synced -> reset = 1
	// otherwise if phy_rst_delay is not 1 -> 1
	// otherwise 0
	// but we get preset by ifclk_rst	
	wire reset_in = (quiesce_rereg_ifclk[1] || (phy_rst && !phy_rst_delay));
	FDPE u_phyrst(.PRE(ifclk_rst),.D(reset_in),.CE(1'b1),.C(xIFCLK),.Q(phy_rst));
	
	wire [15:0] user_icap_in_data;
	wire user_icap_in_wren;
	wire user_icap_in_full;
	wire icap_in_open;
	reg  icap_open_rereg = 0;
	wire [15:0] icap_fifo_data;
	wire icap_fifo_valid;
	wire icap_fifo_empty;

	reg icap_reset = 0;
	wire icap_start_reset = (icap_in_open && !icap_open_rereg);
	wire icap_start_reset_icapclk;
	flag_sync u_icapstart(.in_clkA(icap_start_reset),.out_clkB(icap_start_reset_icapclk),
								 .clkA(pcie_clk),.clkB(icapclk));
	wire icap_reset_delay;
	SRLC32E u_rstdelay(.D(icap_open_rereg),.CLK(pcie_clk),.CE(1'b1),.Q31(icap_reset_delay));
	reg icap_fifo_do_read = 0;
	reg [1:0] quiesce_rereg = 2'b00;
	wire icap_fifo_read = icap_fifo_do_read && icap_fifo_valid;
	
	xilly_infifo16 u_icapfifo(.wr_clk(pcie_clk),
									  .rd_clk(icapclk),
									  .rst(icap_reset),
									  .din(user_icap_in_data),
									  .wr_en(user_icap_in_wren),
									  .full(user_icap_in_full),
									  .dout(icap_fifo_data),
									  .valid(icap_fifo_valid),
									  .empty(icap_fifo_empty),
									  .rd_en(icap_fifo_read));

	// the ICAP can't actually run at pcie_clk speed, so we jump down
	// to xIFCLK speed.
	
	// these stupidly named ports are both active low for what they say they do
	ICAP_SPARTAN6 u_icap(.CLK(icapclk),
								.CE(~icap_fifo_read),
								.WRITE(~icap_fifo_read),
								.I(icap_fifo_data));
								
	// oh dear lord, this was stupidly backwards in 0.15.100
	// you always reset when you __open__ icap, not when you __close__
	// it, because you close it before you quiesce!!
	// there's an obvious race here but it's sooo small it shouldn't
	// be an issue.
	always @(posedge pcie_clk) begin
		// start the reset when icap_in_open rises, and then when the delay
		// rises 32 cycles later, close it.
		if (icap_reset_delay) icap_reset <= 1'b0;
		else if (!icap_open_rereg && icap_in_open) icap_reset <= 1'b1;
		
		icap_open_rereg <= icap_in_open;
	end
	// in the bootloader this is (improperly) in pcie_clk land
	always @(posedge icapclk) begin
	   quiesce_rereg <= {quiesce_rereg[0], quiesce};
		icap_fifo_do_read <= icap_fifo_valid && !icap_fifo_empty && quiesce_rereg[1];

		if (icap_start_reset_icapclk) icap_busy <= 0;
		else if (!icap_fifo_empty) icap_busy <= 1;
	end
/*
						 .phy_dat_i(phy_to_pc),
						 .phy_dat_o(phy_from_pc),
						 .phy_packet_o(phy_packet),
						 .phy_wr_i(phy_wr),
						 .phy_rd_i(phy_rd),
						 .phy_out_empty_o(to_phy_empty),
						 .phy_out_mostly_empty_o(to_phy_mostly_empty),
						 .phy_in_full_o(from_phy_full),
*/
/*
module nofx2_event_buffer( input wr_clk,
			   input [15:0] dat_i,
			   input wr_i,
			   output full_o,
			   output [15:0] count_o,
			   input rst_i,
			   output rst_ack_o,

			   input rd_clk,
			   output [31:0] dat_o,
			   input rd_i,
			   output empty_o);
	wire ev2_irsclk;
	wire [15:0] ev2_dat;
	wire [15:0] ev2_count;
	wire ev2_wr;
	wire ev2_full;
	wire ev2_rst;
	wire ev2_rst_ack;
				*/
	wire user_ev_rden;
	wire user_ev_empty;
	wire [31:0] user_ev_data;
	wire user_ev_open; // who knows, maybe reset some'n
	
	wire [52:0] event_debug;
	
	// LET'S GIVE IT A WHIRL
	nofx2_event_buffer u_evbuf(.wr_clk(ev2_irsclk),
										.dat_i(ev2_dat),
									   .wr_i(ev2_wr),
										.full_o(ev2_full),
										.count_o(ev2_count),
										.rst_i(ev2_rst),
										.rst_ack_o(ev2_rst_ack),
										.rd_clk(pcie_clk),
										.dat_o(user_ev_data),
										.rd_i(user_ev_rden),
										.empty_o(user_ev_empty),
										.debug_o(event_debug));
	
	
	xillybus u_xillybus( .PCIE_TX0_P( pci_exp_txp ),
								.PCIE_TX0_N( pci_exp_txn ),
								.PCIE_RX0_P( pci_exp_rxp ),
								.PCIE_RX0_N( pci_exp_rxn ),
								.PCIE_250M_P( sys_clk_p ),
								.PCIE_250M_N( sys_clk_n ),
								.PCIE_PERST_B_LS( sys_reset_n ),
								.bus_clk(pcie_clk),
								.quiesce(quiesce),
								.user_w_icap_in_full(user_icap_in_full),
								.user_w_icap_in_wren(user_icap_in_wren),
								.user_w_icap_in_data(user_icap_in_data),
								.user_w_icap_in_open(icap_in_open),
								
								.user_w_pkt_in_wren(phy_wr),
								.user_w_pkt_in_full(from_phy_full),
								.user_w_pkt_in_data(phy_to_pc),
								.user_w_pkt_in_open(),
								
								.user_r_pkt_out_rden(phy_rd),
								.user_r_pkt_out_empty(to_phy_empty),
								.user_r_pkt_out_data(phy_from_pc),
								.user_r_pkt_out_eof(1'b0),
								.user_r_pkt_out_open(),
								// TEMPORARY
								.user_r_ev_out_rden(user_ev_rden),
								.user_r_ev_out_empty(user_ev_empty),
								.user_r_ev_out_data(user_ev_data),
								.user_r_ev_out_eof(1'b0),
								.user_r_ev_out_open(user_ev_open));
								
	
	////////////////////////////////////////////////////////////////////
	// END PHY
	////////////////////////////////////////////////////////////////////

	wire wrclk;
	wire [3:0] gpio_debug;
	// ATRI core
	atri_core #(.NUM_DAUGHTERS(NUM_DAUGHTERS),
					.DEBUG(DEBUG),
					.SENSE(SENSE),
					.BOARD_ID(BOARD_ID),
					.IMPLEMENT_RESERVED(IMPLEMENT_RESERVED),
					.OUTBOUND_FWFT("NO"),
					.VER_BOARD(VER_BOARD),.VER_MAJOR(VER_MAJOR),.VER_MINOR(VER_MINOR),.VER_REV(VER_REV),
					.VER_MONTH(VER_MONTH),.VER_DAY(VER_DAY))
				u_atri(
						 .D1RD(D1RD),.D1RDEN(D1RDEN),.D1WR(D1WR),.D1WRSTRB(D1WRSTRB),
						 .D1TSA(D1TSA),.D1TSA_CLOSE(D1TSA_CLOSE),.D1TSAOUT(D1TSAOUT),.D1TSTOUT(D1TSTOUT),
						 .D1RAMP(D1RAMP),.D1START(D1START),.D1CLR(D1CLR),
						 .D1SMPALL(D1SMPALL),.D1SMP(D1SMP),.D1CH(D1CH),.D1DAT(D1DAT),
						 .D1TRG_P(D1TRG_P),.D1TRG_N(D1TRG_N),
						 .D1DDASENSE(D1DDASENSE),.D1TDASENSE(D1TDASENSE),.D1SDA(D1SDA),.D1SCL(D1SCL),
						 .D1DRSV(D1DRSV),.D1DRSV_P(D1DRSV_P),.D1DRSV_N(D1DRSV_N),
						 .D1CRSV_P(D1CRSV_P),.D1CRSV_N(D1CRSV_N),.D1ARSV(D1ARSV),
					
						 .D2RD(D2RD),.D2RDEN(D2RDEN),.D2WR(D2WR),.D2WRSTRB(D2WRSTRB),
						 .D2TSA(D2TSA),.D2TSA_CLOSE(D2TSA_CLOSE),.D2TSAOUT(D2TSAOUT),.D2TSTOUT(D2TSTOUT),
						 .D2RAMP(D2RAMP),.D2START(D2START),.D2CLR(D2CLR),
						 .D2SMPALL(D2SMPALL),.D2SMP(D2SMP),.D2CH(D2CH),.D2DAT(D2DAT),
						 .D2TRG_P(D2TRG_P),.D2TRG_N(D2TRG_N),
						 .D2DDASENSE(D2DDASENSE),.D2TDASENSE(D2TDASENSE),.D2SDA(D2SDA),.D2SCL(D2SCL),
						 .D2DRSV(D2DRSV),.D2DRSV_P(D2DRSV_P),.D2DRSV_N(D2DRSV_N),
						 .D2CRSV_P(D2CRSV_P),.D2CRSV_N(D2CRSV_N),.D2ARSV(D2ARSV),

						 .D3RD(D3RD),.D3RDEN(D3RDEN),.D3WR(D3WR),.D3WRSTRB(D3WRSTRB),
						 .D3TSA(D3TSA),.D3TSA_CLOSE(D3TSA_CLOSE),.D3TSAOUT(D3TSAOUT),.D3TSTOUT(D3TSTOUT),
						 .D3RAMP(D3RAMP),.D3START(D3START),.D3CLR(D3CLR),
						 .D3SMPALL(D3SMPALL),.D3SMP(D3SMP),.D3CH(D3CH),.D3DAT(D3DAT),
						 .D3TRG_P(D3TRG_P),.D3TRG_N(D3TRG_N),
						 .D3DDASENSE(D3DDASENSE),.D3TDASENSE(D3TDASENSE),.D3SDA(D3SDA),.D3SCL(D3SCL),
						 .D3DRSV(D3DRSV),.D3DRSV_P(D3DRSV_P),.D3DRSV_N(D3DRSV_N),
						 .D3CRSV_P(D3CRSV_P),.D3CRSV_N(D3CRSV_N),.D3ARSV(D3ARSV),

						 .D4RD(D4RD),.D4RDEN(D4RDEN),.D4WR(D4WR),.D4WRSTRB(D4WRSTRB),
						 .D4TSA(D4TSA),.D4TSA_CLOSE(D4TSA_CLOSE),.D4TSAOUT(D4TSAOUT),.D4TSTOUT(D4TSTOUT),
						 .D4RAMP(D4RAMP),.D4START(D4START),.D4CLR(D4CLR),
						 .D4SMPALL(D4SMPALL),.D4SMP(D4SMP),.D4CH(D4CH),.D4DAT(D4DAT),
						 .D4TRG_P(D4TRG_P),.D4TRG_N(D4TRG_N),
						 .D4DDASENSE(D4DDASENSE),.D4TDASENSE(D4TDASENSE),.D4SDA(D4SDA),.D4SCL(D4SCL),
						 .D4DRSV(D4DRSV),.D4DRSV_P(D4DRSV_P),.D4DRSV_N(D4DRSV_N),
						 .D4CRSV_P(D4CRSV_P),.D4CRSV_N(D4CRSV_N),.D4ARSV(D4ARSV),

						 .ext_trig_i(FPTRIG_IN),

						 .phy_clk_i(xIFCLK),
						 .phy_ifclk_i(pcie_clk),
						 .phy_rst_i(phy_rst),
						 .slow_ce_i(KHz_CE),
						 .micro_ce_i(MHz_CE),
						 .irs_clk_i(irs_sys_clk),
						 .irs_clk180_i(irs_sys_clk180),
						 .wrclk_o(wrclk),
						 .pps_i(pps_async),
						 .pps_flag_i(pps_flag),
						 
						 .phy_dat_i(phy_to_pc),
						 .phy_dat_o(phy_from_pc),
						 .phy_packet_o(phy_packet),
						 .phy_wr_i(phy_wr),
						 .phy_rd_i(phy_rd),
						 .phy_out_empty_o(to_phy_empty),
						 .phy_out_mostly_empty_o(to_phy_mostly_empty),
						 .phy_in_full_o(from_phy_full),
						 .ev_interface_io(event_interface),
						 .phy_debug_i(event_debug),
						 .phy_debug_clk_i(ev2_irsclk),
						 .gpio_debug_o(gpio_debug),
						 .pcie_debug_clk_i(pcie_clk),
						 .pcie_debug_i(pcie_debug1)
						 );
	

	generate
		if (BRSV_TRISTATE == "YES") begin : BT
			assign BRSV = {18{1'bZ}};
		end else begin : BD
			assign BRSV = {18{1'b0}};
		end
	endgenerate
	wire [0:0] CRSV = {1'b0};
	// aaaaugh
	generate
		if (CRSV0_TYPE == "LVDS") begin : CRSV0
			OBUFDS crsv0_obuf(.I(CRSV[0]),.O(CRSV0_P),.OB(CRSV0_N));
		end else begin
			assign CRSV0_P = CRSV[0];
			assign CRSV0_N = ~CRSV[0];
		end
	endgenerate

	// these are now garbage
	assign SLOE = 1'b0;
	assign SLRD = 1'b0;
	assign SLWR = 1'b0;
	assign FIFOADR = 2'b00;
	assign PKTEND = 1'b0;
	
//	assign FD[12:8] = {D1TSTOUT,D2TSTOUT,D3TSTOUT,D4TSTOUT};
	assign FD[8] = quiesce;
//	assign FD[9] = pcie_clk;
	assign FD[15:9] = {6{1'b0}};
	assign BRSV[17:0] = {18{1'b0}};
	assign GPIO[0] = pps_output;
	assign GPIO[1] = pps_output;
	assign GPIO[3:2] = gpio_debug[1:0];
endmodule
