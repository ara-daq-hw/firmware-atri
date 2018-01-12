`timescale 1ns / 1ps
//% @file atri_core.v Contains ATRI core support module.

`include "ev2_interface.vh"
`include "wb_interface.vh"
`include "irsi2c_interface.vh"
`include "irs_interface.vh"
`include "trigger_defs.vh"
//% @brief atri_core This is the core ATRI module.
//%
//% atri_core is the final combined ATRI PHY-independent architecture.
//% 
//% This version supports up to 4 daughterboards. 
//%
//% This version uses:
//% - the ev2_interface rather than ev_interface
//% - irs_quad_top rather than 4 irs2_tops / irs_wb (irs WB interface is inside irs_quad_top)
//% - trigger_top rather than a large-scale disaster
//% - irs interfaces
//% - debug_top to collect the debug interfaces in one place
module atri_core(
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

		// External trigger.
		input ext_trig_i,

		// Clocking interface
		output wrclk_o,
		input phy_clk_i,				//% PHY interface clock
		input phy_rst_i,				//% PHY reset
		input slow_ce_i,				//% Slow clock enable (nominally 1 millisecond)
		input micro_ce_i,				//% Semi-slow clock enable (nominally 1 microsecond)
		input irs_clk_i,				//% IRS system clock
		input irs_clk180_i,			//% IRS system clock, 180 deg. phase shift
		// PPS interface
		input pps_i,
		input pps_flag_i,
		// PHY interface
		input [7:0] phy_dat_i,
		output [7:0] phy_dat_o,
		output phy_packet_o,
		input phy_wr_i,
		input phy_rd_i,
		output phy_out_empty_o,
		output phy_out_mostly_empty_o,
		output phy_in_full_o,
		inout [`EV2IF_SIZE-1:0] ev_interface_io,
		input reset_i,
		// Misc/debug
		input [52:0] phy_debug_i,
		input phy_debug_clk_i,
		inout REG1_SCL,
		inout REG1_SDA,
		output refclk_en_o,
		output [3:0] gpio_debug_o,
		input pcie_debug_clk_i,
		input [52:0] pcie_debug_i
    );

	`include "clogb2.vh"

	////////////////////////////////////////////////////////////////
	//             TOP-LEVEL CONFIGURATION PARAMETERS             //
	////////////////////////////////////////////////////////////////

	//% "YES" (=PC), "I2C", "IRS", "NONE", or "TRIG"
	parameter DEBUG = "YES";
	//% IFCLK phase shift. For behavioral simulations, set this to 0.
	parameter IFCLK_PS = -98;
	//% WRSTRB phase shift.
	parameter WRSTRB_PHASE_SHIFT = 0;
	//% Determines whether or not daughterboard sensing happens slow (ms) or fast (ns)
	parameter SENSE = "SLOW";
	//% Number of daughterboards
	parameter NUM_DAUGHTERS = 4;
	//% Maximum number of daughterboards (for interfaces)
	parameter MAX_DAUGHTERS = 4;
	
	//% Number of L4 triggers
	parameter NUM_L4 = `SCAL_NUM_L4;
	//% Number of bits in the trigger info field
	parameter INFO_BITS = `INFO_BITS;
	//% Number of L4 bits required in an address
	parameter NL4_BITS = clogb2(NUM_L4-1);

	parameter [31:0] BOARD_ID = "ATRI";
	parameter [3:0] VER_BOARD = 1;
	parameter [3:0] VER_MONTH = 8;
	parameter [7:0] VER_DAY = 22;
	parameter [3:0] VER_MAJOR = 0;
	parameter [3:0] VER_MINOR = 9;
	parameter [7:0] VER_REV = 0;
	
	parameter VCCAUX_I2C = "NO";
	parameter IMPLEMENT_RESERVED = "YES";
	////////////////////////////////////////////////////////////////
	// COMBINE DAUGHTERBOARD SIGNALS INTO ARRAYS                  //
	////////////////////////////////////////////////////////////////

	`define VECIN( x ) \
		assign x [ 0 ] = D1``x ; \
		assign x [ 1 ] = D2``x ; \
		assign x [ 2 ] = D3``x ; \
		assign x [ 3 ] = D4``x
	`define VECINRANGE( x , range) \
		assign x [ 0 ] range = D1``x range ; \
		assign x [ 1 ] range = D2``x range ; \
		assign x [ 2 ] range = D3``x range ; \
		assign x [ 3 ] range = D4``x range
	`define VECOUT( x ) \
		assign D1``x = x [ 0 ] ; \
		assign D2``x = x [ 1 ] ; \
		assign D3``x = x [ 2 ] ; \
		assign D4``x = x [ 3 ]
	//% WR output to IRS2
	wire [9:0] WR[MAX_DAUGHTERS-1:0];
	//% RD output to IRS2
	wire [9:0] RD_O[MAX_DAUGHTERS-1:0];
	//% RD output enables
	wire [9:0] RD_OE[MAX_DAUGHTERS-1:0];
	//% RD inputs (for SHOUT)
	wire [9:0] RD_I[MAX_DAUGHTERS-1:0];	
	//% SMP output to IRS2
	wire [5:0] SMP[MAX_DAUGHTERS-1:0];
	//% CH output to IRS2
	wire [2:0] CH[MAX_DAUGHTERS-1:0];
	//% DAT input from IRS2
	wire [11:0] DAT[MAX_DAUGHTERS-1:0];
	//% Trigger inputs from TDA, negative
	wire [7:0] TRG_N[MAX_DAUGHTERS-1:0];
	//% Trigger inputs from TDA, positive
	wire [7:0] TRG_P[MAX_DAUGHTERS-1:0];

	//% RDEN output to IRS2
	wire [MAX_DAUGHTERS-1:0] RDEN;
	//% WRSTRB output to IRS2
	wire [MAX_DAUGHTERS-1:0] WRSTRB;
	//% SMPALL output to IRS2
	wire [MAX_DAUGHTERS-1:0] SMPALL;
	//% START output to IRS2
	wire [MAX_DAUGHTERS-1:0] START;
	//% CLR output to IRS2
	wire [MAX_DAUGHTERS-1:0] CLR;
	//% RAMP output to IRS2
	wire [MAX_DAUGHTERS-1:0] RAMP;
	//% TSA output to IRS2
	wire [MAX_DAUGHTERS-1:0] TSA;
	//% TSA_CLOSE output to IRS2
	wire [MAX_DAUGHTERS-1:0] TSA_CLOSE;
	//% TSAOUT input from IRS2
	wire [MAX_DAUGHTERS-1:0] TSAOUT;
	//% TSTOUT input from IRS2
	wire [MAX_DAUGHTERS-1:0] TSTOUT;
	//% Reserved
	wire [0:0] ARSV[MAX_DAUGHTERS-1:0];
	//% D-section reserved differential, raw positive
	wire [2:0] DRSV_P[MAX_DAUGHTERS-1:0];
	//% D-section reserved differential, raw negative
	wire [2:0] DRSV_N[MAX_DAUGHTERS-1:0];
	//% C-section reserved differential, raw positive
	wire [2:1] CRSV_P[MAX_DAUGHTERS-1:0];
	//% C-section reserved differential, raw negative
	wire [2:1] CRSV_N[MAX_DAUGHTERS-1:0];
	//% D-section reserved differential, merged
	wire [2:0] DRSV_DIFF[MAX_DAUGHTERS-1:0];
	//% C-section reserved differential, merged
	wire [2:1] CRSV_DIFF[MAX_DAUGHTERS-1:0];

	// These are all true inouts, so we need all three

	//% I2C SCL input
	wire [MAX_DAUGHTERS-1:0] SCL_I;
	//% I2C SCL output
	wire [MAX_DAUGHTERS-1:0] SCL_O;
	//% I2C SCL output enable
	wire [MAX_DAUGHTERS-1:0] SCL_OE;
	//% I2C SDA input
	wire [MAX_DAUGHTERS-1:0] SDA_I;
	//% I2C SDA output
	wire [MAX_DAUGHTERS-1:0] SDA_O;
	//% I2C SDA output enable
	wire [MAX_DAUGHTERS-1:0] SDA_OE;
	//% DDASENSE input
	wire [MAX_DAUGHTERS-1:0] DDASENSE_I;
	//% DDASENSE output
	wire [MAX_DAUGHTERS-1:0] DDASENSE_O;
	//% DDASENSE outpute enable
	wire [MAX_DAUGHTERS-1:0] DDASENSE_OE;
	//% TDASENSE input
	wire [MAX_DAUGHTERS-1:0] TDASENSE_I;
	//% TDASENSE output
	wire [MAX_DAUGHTERS-1:0] TDASENSE_O;
	//% TDASENSE output enable
	wire [MAX_DAUGHTERS-1:0] TDASENSE_OE;
	//% DRSVSENSE inputs
	wire [10:9] DRSV_I[MAX_DAUGHTERS-1:0];
	//% DRSVSENSE outputs
	wire [10:9] DRSV_O[MAX_DAUGHTERS-1:0];
	//% DRSVSENSE output enables
	wire [10:9] DRSV_OE[MAX_DAUGHTERS-1:0];
	
	//% Indicates which daughter's outputs should be driven.
	wire [3:0] DBDRIVE[NUM_DAUGHTERS-1:0];
	//% Indicates which daughterboards are present.
	wire [3:0] DBPRESENT[NUM_DAUGHTERS-1:0];
	//% Indicates which daughterboards have power.
	wire [3:0] DBPOWER[NUM_DAUGHTERS-1:0];
	//% Indicates which daughterboards have updated their status.
	wire [3:0] DBUPDATE[NUM_DAUGHTERS-1:0];
	//% Daughterboard status.
	wire [7:0] DBSTATUS[MAX_DAUGHTERS-1:0];

	
	//% IRS interfaces.
	wire [`IRSIF_SIZE-1:0] irs_interface[MAX_DAUGHTERS-1:0];

	// Vectorization.
	`VECOUT( WR );
	`VECOUT( SMP );
	`VECOUT( CH );
	`VECIN( DAT );
	`VECIN( TRG_P );
	`VECIN( TRG_N );
	`VECOUT( RDEN );
	`VECOUT( WRSTRB );
	`VECOUT( SMPALL );
	`VECOUT( START );
	`VECOUT( CLR );
	`VECOUT( RAMP );
	`VECOUT( TSA );
	`VECOUT( TSA_CLOSE );
	`VECIN( TSAOUT );
	`VECIN( TSTOUT );
	`VECOUT( ARSV );
	`VECOUT( DRSV_P );
	`VECOUT( DRSV_N );
	`VECINRANGE( CRSV_P , [2:1] );
	`VECINRANGE( CRSV_N , [2:1] );
	`undef VECIN
	`undef VECOUT
	`undef VECINRANGE
	// Now handle the special cases.
	generate
		// Set up macros for the cased loop so we don't
		// have to avoid screwing something up.
		`define db_read_infrastructure( x , num ) \
			db_read_infrastructure x``rd(.OE(RD_OE[ num ]), .O(RD_I[ num ]), .I(RD_O[ num ]), .IO(x``RD))
		`define db_infrastructure( x , num ) \
			db_infrastructure #(.IMPLEMENT_RESERVED(IMPLEMENT_RESERVED)) x ( x``SCL, SCL_I[ num ] , SCL_O[ num ], SCL_OE[ num ],  \
										x``SDA, SDA_I[ num ], SDA_O[ num ], SDA_OE[ num ],																 \
										x``DDASENSE, DDASENSE_I[ num ], DDASENSE_O[ num ], DDASENSE_OE[ num ],									 \
										x``TDASENSE, TDASENSE_I[ num ], TDASENSE_O[ num ], TDASENSE_OE[ num ],									 \
										x``DRSV[9], DRSV_I[ num ][9], DRSV_O[ num ][9], DRSV_OE[ num ][9],										 \
										x``DRSV[10], DRSV_I[ num ][10], DRSV_O[ num ][10], DRSV_OE[ num ][10])
		`define dummy( x , num ) \
			assign DDASENSE_I[ num ] = 1; \
			assign TDASENSE_I[ num ] = 1; \
			assign DRSV_I[ num ][9] = 1; \
			assign DRSV_I[ num ][10] = 1; \
			assign SDA_I[ num ] = 1; \
			assign SCL_I[ num ] = 1
		`define irs_infrastructure( x , num ) \
			irs_infra x``infra(.interface_io(irs_interface[ num ] ),	\
									 .dat_i( DAT[ num ]),						\
									 .smp_o( SMP[ num ]),						\
									 .ch_o( CH[ num ]),							\
									 .smpall_o( SMPALL[ num ]),				\
									 .ramp_o( RAMP[ num ] ),					\
									 .start_o( START[ num ] ),					\
									 .clr_o( CLR[ num ]),						\
									 .wr_o( WR[ num ]),							\
									 .wrstrb_o( WRSTRB[ num ]),				\
									 .rd_i( RD_I[ num ]),						\
									 .rdo_o( RD_O[ num ]),						\
									 .rdoe_o( RD_OE[ num ]),					\
									 .rden_o( RDEN[ num ]),					\
									 .tsa_o( TSA[ num ]),						\
									 .tsa_close_o( TSA_CLOSE[ num ]),		\
									 .tsaout_i( TSAOUT[ num ]),				\
									 .tstout_i( TSTOUT[ num ]),				\
									 .power_i( DBPOWER[ num ][0] ),			\
									 .drive_i( DBDRIVE[ num ][0] ))    			
			`define irs_dummy( x , num ) \
				irs_infra x``dummy( .interface_io(irs_interface[ num ] ),	\
										  .dat_i( {12{1'b0}} ),							\
										  .rd_i( {10{1'b0}}),							\
										  .tsaout_i( 1'b0 ),								\
										  .tstout_i( 1'b0 ),								\
										  .power_i( 1'b0 ),								\
										  .drive_i( 1'b0 ))
		if (NUM_DAUGHTERS > 0) begin : D1
			`db_read_infrastructure( D1 , 0 );
			`db_infrastructure( D1 , 0 );
			`irs_infrastructure( D1 , 0 );
		end else begin : D1DUM
			`dummy( D1 , 0 );
			`irs_dummy( D1 , 0);
		end
		if (NUM_DAUGHTERS > 1) begin : D2
			`db_read_infrastructure( D2 , 1 );
			`db_infrastructure( D2 , 1 );
			`irs_infrastructure( D2 , 1 );
		end else begin : D2DUM
			`dummy( D2 , 1);
			`irs_dummy( D2 , 1);
		end
		if (NUM_DAUGHTERS > 2) begin : D3
			`db_read_infrastructure( D3 , 2 );
			`db_infrastructure( D3 , 2 );
			`irs_infrastructure( D3 , 2 );
		end else begin : D3DUM
			`dummy( D3 , 2);
			`irs_dummy( D3 , 2);
		end
		if (NUM_DAUGHTERS > 3) begin : D4
			`db_read_infrastructure( D4 , 3 );
			`db_infrastructure( D4 , 3 );
			`irs_infrastructure( D4 , 3 );
		end else begin : D4DUM
			`dummy( D4 , 3);
			`irs_dummy( D4 , 3);
		end
		`undef db_read_infrastructure
		`undef db_infrastructure
		`undef irs_infrastructure
		`undef dummy
		`undef irs_dummy
	endgenerate	
	
	////////////////////////////////////////////////////////////////////
	// DAUGHTERBOARD DETECT/POWER CONTROL										//
	////////////////////////////////////////////////////////////////////
	generate
		genvar db_det_i;
		genvar db_stat_i;
		for (db_det_i=0;db_det_i<NUM_DAUGHTERS;db_det_i=db_det_i+1) begin : DB_DET
			db_detect_and_power_control_v2 #(.SENSE_SPEED(SENSE))
					dda_sense(.SENSE_I(DDASENSE_I[db_det_i]),
								 .SENSE_O(DDASENSE_O[db_det_i]),
								 .SENSE_OE(DDASENSE_OE[db_det_i]),
								 .CLK(phy_clk_i),.SCLK(slow_ce_i),
								 .POWER(DBPOWER[db_det_i][0]),.PRESENT(DBPRESENT[db_det_i][0]),.UPDATE(DBUPDATE[db_det_i][0]));
			db_detect_and_power_control_v2 #(.SENSE_SPEED(SENSE))
					tda_sense(.SENSE_I(TDASENSE_I[db_det_i]),
								 .SENSE_O(TDASENSE_O[db_det_i]),
								 .SENSE_OE(TDASENSE_OE[db_det_i]),
								 .CLK(phy_clk_i),.SCLK(slow_ce_i),
								 .POWER(DBPOWER[db_det_i][1]),.PRESENT(DBPRESENT[db_det_i][1]),.UPDATE(DBUPDATE[db_det_i][1]));
			db_detect_and_power_control_v2 #(.SENSE_SPEED(SENSE))
					drsv9_sense(.SENSE_I(DRSV_I[db_det_i][9]),
					            .SENSE_O(DRSV_O[db_det_i][9]),
									.SENSE_OE(DRSV_OE[db_det_i][9]),
									.CLK(phy_clk_i),.SCLK(slow_ce_i),
								 .POWER(DBPOWER[db_det_i][2]),.PRESENT(DBPRESENT[db_det_i][2]),.UPDATE(DBUPDATE[db_det_i][2]));
			db_detect_and_power_control_v2 #(.SENSE_SPEED(SENSE))
					drsv10_sense(.SENSE_I(DRSV_I[db_det_i][10]),
								    .SENSE_O(DRSV_O[db_det_i][10]),
									 .SENSE_OE(DRSV_OE[db_det_i][10]),
									 .CLK(phy_clk_i),.SCLK(slow_ce_i),
								 .POWER(DBPOWER[db_det_i][3]),.PRESENT(DBPRESENT[db_det_i][3]),.UPDATE(DBUPDATE[db_det_i][3]));
		end
		for (db_stat_i=0;db_stat_i<MAX_DAUGHTERS;db_stat_i=db_stat_i+1) begin : DB_STAT
			if (db_stat_i < NUM_DAUGHTERS) begin : REAL
				assign DBSTATUS[db_stat_i] = {DBPOWER[db_stat_i][3],DBPRESENT[db_stat_i][3],
														DBPOWER[db_stat_i][2],DBPRESENT[db_stat_i][2],
														DBPOWER[db_stat_i][1],DBPRESENT[db_stat_i][1],
														DBPOWER[db_stat_i][0],DBPRESENT[db_stat_i][0]};
			end else begin : ZERO
				assign DBSTATUS[db_stat_i] = {8{1'b0}};
			end
		end
	endgenerate
	reg status_change = 0;
	wire [NUM_DAUGHTERS-1:0] stack_status_change;
	wire status_change_any = | stack_status_change;
	wire status_change_ack;
	generate
		genvar stc_i;
		for (stc_i=0;stc_i<NUM_DAUGHTERS;stc_i=stc_i+1) begin : STACK_OR
			assign stack_status_change[stc_i] = | DBUPDATE[stc_i];
		end
	endgenerate
	always @(posedge phy_clk_i) begin
		if (status_change_any)
			status_change <= 1;
		else if (status_change_ack)
			status_change <= 0;
	end

	////////////////////////////////////////////////////////////////////
	// DEBUG                             										//
	////////////////////////////////////////////////////////////////////

	wire [52:0] pc_debug;
	wire [52:0] i2c_debug[MAX_DAUGHTERS-1:0];
	wire [52:0] irs_debug;
	wire [52:0] trigger_debug;
	wire [52:0] irsraw_debug;
	assign irsraw_debug[0 +: 12] = D1DAT;
	assign irsraw_debug[12 +: 6] = D1SMP;
	assign irsraw_debug[18 +: 3] = D1CH;
	assign irsraw_debug[21 +: 10] = RD_O[0];
	assign irsraw_debug[31] = D1SMPALL;
	assign irsraw_debug[32] = D1RDEN;
	assign irsraw_debug[33] = RD_OE[0][9];
	assign irsraw_debug[34] = D1START;
	assign irsraw_debug[35] = D1CLR;
	assign irsraw_debug[36] = D1RAMP;
	reg [1:0] counter = 0;
	always @(posedge irs_clk_i) begin
		if (D1SMPALL)
			counter <= counter + 1;
		else
			counter <= {2{1'b0}};
	end
	assign irsraw_debug[38:37] = counter;
	assign irsraw_debug[47:39] = RD_OE[0][8:0];
	assign irsraw_debug[52:48] = {5{1'b0}};
	wire [3:0] debug_sel;
	debug_core #(.DEBUG(DEBUG)) dbg(.phy_clk_i(phy_clk_i),
											  .phy_debug_clk_i(phy_debug_clk_i),
											  .irs_clk_i(irs_clk_i),
											  .pcie_clk_i(pcie_debug_clk_i),
											  .phy_debug_i(phy_debug_i),
											  .pc_debug_i(pc_debug),
											  .pcie_debug_i(pcie_debug_i),
											  .i2c_debug_i(i2c_debug[0]),
											  .irs_debug_i(irs_debug),
											  .irsraw_debug_i(irsraw_debug),
											  .trig_debug_i(trigger_debug),
											  .vio_debug_o(debug_sel));

	////////////////////////////////////////////////////////////////////
	// PPS                                                            //
	////////////////////////////////////////////////////////////////////
	
	// core_pps_flag_phy_clk is a single-cycle flag on phy_clk. It might be
	// externally generated or internally generated.
	wire core_pps_flag_phy_clk;
	// core_pps_flag_sys_clk is a single cycle flag on irs_sys_clk. It might
	// be externally generated or internally generated.
	wire core_pps_flag_sys_clk;

	////////////////////////////////////////////////////////////////////
	// PACKET CONTROLLER                 										//
	////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////
	// FIFOS FROM/TO PACKET CONTROLLER   										//
	////////////////////////////////////////////////////////////////////

	// the 9th bit is packet_o, indicating a completed packet
	wire [8:0] outbound_fifo_data_in;
	wire [8:0] outbound_fifo_data_out;
	wire [8:0] inbound_fifo_data_in;
	wire [8:0] inbound_fifo_data_out;

	wire [7:0] pc_to_fifo;
	wire pc_packet_to_fifo;
	wire [7:0] pc_from_fifo;
	
	assign pc_from_fifo = inbound_fifo_data_out[7:0];
	assign outbound_fifo_data_in = {pc_packet_to_fifo, pc_to_fifo};
	assign inbound_fifo_data_in = {1'b0, phy_dat_i};
	assign phy_dat_o = outbound_fifo_data_out[7:0];
	assign phy_packet_o = outbound_fifo_data_out[8];
	
	wire pc_wr;
	wire pc_rd;
	wire pc_fifo_full;
	wire pc_fifo_empty;

	// These were shrunk in v0.9 to a 9x1024 FIFO so that they
	// use 9k BRAMs rather than an 18k BRAM. The FIFO depth is
	// way larger than is needed in any case.
	atri_outbound_packet_buffer outbound_fifo(.rst(phy_rst_i),
															.wr_clk(phy_clk_i),
															.rd_clk(phy_clk_i),
															.din(outbound_fifo_data_in),
															.dout(outbound_fifo_data_out),
															.wr_en(pc_wr),
															.rd_en(phy_rd_i),
															.full(pc_fifo_full),
															.empty(phy_out_empty_o),
															.prog_empty(phy_out_mostly_empty_o));
	atri_outbound_packet_buffer inbound_fifo(.rst(phy_rst_i),
														 .wr_clk(phy_clk_i),
														 .rd_clk(phy_clk_i),
														 .din(inbound_fifo_data_in),
														 .dout(inbound_fifo_data_out),
														 .wr_en(phy_wr_i),
														 .rd_en(pc_rd),
														 .full(phy_in_full_o),
														 .empty(pc_fifo_empty));
	wire [1:0] i2c_adr;
	wire [7:0] pc_to_i2c;
	wire [7:0] pc_from_i2c;
	wire [7:0] i2c_count;
	wire [3:0] i2c_packet;
	wire [3:0] i2c_packet_ack;
	wire i2c_rd;
	wire i2c_wr;

	// wb_master[7:0] = data to master
	// wb_master[15:8] = data from master
	// wb_master[31:16] = adr
	// wb_master[32] = cyc
	// wb_master[33] = stb
	// wb_master[34] = wr
	// wb_master[35] = ack
	// wb_master[36] = err
	// wb_master[37] = rty
	// wb_master[38] = clock
	// wb_master[39] = reset
	wire [`WBIF_SIZE-1:0] wb_master;
	wire [5:0] pc_state;
	atri_packet_controller pc(.clk_i(phy_clk_i),
									  .reset_i(phy_rst_i),
									  .dat_i(pc_from_fifo),
									  .dat_o(pc_to_fifo),
									  .packet_o(pc_packet_to_fifo),
									  .empty_i(pc_fifo_empty),
									  .full_i(pc_fifo_full),
									  .rd_o(pc_rd),
									  .wr_o(pc_wr),
									  .D1_status_i(DBSTATUS[0]),
									  .D2_status_i(DBSTATUS[1]),
									  .D3_status_i(DBSTATUS[2]),
									  .D4_status_i(DBSTATUS[3]),
									  .status_change_i(status_change),
									  .status_change_ack_o(status_change_ack),
									  .wb_interface_io(wb_master),
										// I2C
									  .i2c_adr_o(i2c_adr),
									  .i2c_dat_i(pc_from_i2c),
									  .i2c_dat_o(pc_to_i2c),
									  .i2c_count_i(i2c_count),
									  .i2c_packet_i(i2c_packet),
									  .i2c_packet_ack_o(i2c_packet_ack),
									  .i2c_rd_o(i2c_rd),
									  .i2c_wr_o(i2c_wr),
									  .state_o(pc_state)
									  );
		
		assign pc_debug[7:0] = pc_from_fifo;
		assign pc_debug[15:8] = pc_to_fifo;
		assign pc_debug[16] = pc_fifo_empty;
		assign pc_debug[17] = pc_fifo_full;
		assign pc_debug[18] = pc_rd;
		assign pc_debug[19] = pc_wr;
		assign pc_debug[25:20] = pc_state;
		assign pc_debug[47:26] = {23{1'b0}};
		assign pc_debug[52:48] = {5{1'b0}};
	////////////////////////////////////////////////////////////////////
	// END PACKET CONTROLLER             										//
	////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////
	// I2C                               										//
	////////////////////////////////////////////////////////////////////

		// I2C clock rename.
		// Nominally, I2C clock and PHY clock should be thought
		// of as distinct, but they are currently identical.
		wire i2c_clk = phy_clk_i;
		
		wire [20:0] i2c_daughter[MAX_DAUGHTERS-1:0];
		wire [`IRSI2CIF_SIZE-1:0] irsi2c_daughter[MAX_DAUGHTERS-1:0];
		// These use 2 BRAMs total: each FIFO is 1024x8. This might be
		// shrinkable to 512x8 by using a 9k BRAM.
		
		atri_i2c_mux_and_fifo i2c_mux(.pc_clk_i(phy_clk_i),
												.i2c_clk_i(i2c_clk),
												.rst_i(phy_rst_i),
												.i2c_adr_i(i2c_adr),
												.i2c_dat_o(pc_from_i2c),
												.i2c_dat_i(pc_to_i2c),
												.i2c_count_o(i2c_count),
												.i2c_packet_o(i2c_packet),
												.i2c_packet_ack_i(i2c_packet_ack),
												.i2c_rd_i(i2c_rd),
												.i2c_wr_i(i2c_wr),
												.i2c_daughter_1(i2c_daughter[0]),
												.i2c_daughter_2(i2c_daughter[1]),
												.i2c_daughter_3(i2c_daughter[2]),
												.i2c_daughter_4(i2c_daughter[3]));
		generate
			genvar i2c_i;
			for (i2c_i=0;i2c_i<NUM_DAUGHTERS;i2c_i=i2c_i+1) begin : I2C_CONTROL 
				if (i2c_i == 0 && VCCAUX_I2C == "YES") begin : DDAEVAL
					atri_i2c_controller_v2 #(.VCCAUX_I2C(VCCAUX_I2C))
								       daughter(.clk_i(i2c_clk),
													 .KHz_CE_i(slow_ce_i),
													 .MHz_CE_i(micro_ce_i),
													 .sda_i(SDA_I[i2c_i]),
													 .sda_o(SDA_O[i2c_i]),
													 .sda_oe(SDA_OE[i2c_i]),
													 .scl_i(SCL_I[i2c_i]),
													 .scl_o(SCL_O[i2c_i]),
													 .scl_oe(SCL_OE[i2c_i]),
													 .rst_i(phy_rst_i),
													 .pps_i(pps_flag),
													 .db_status_i(DBSTATUS[i2c_i]),
													 .i2c_interface(i2c_daughter[i2c_i]),
													 .irsi2c_interface(irsi2c_daughter[i2c_i]),
													 // DDAEVAL only
													 .regsda_io(REG1_SDA),
													 .regscl_io(REG1_SCL),
													 .debug_o(i2c_debug[i2c_i])
													 );
				end else begin : ATRI
					atri_i2c_controller_v2
								       daughter(.clk_i(i2c_clk),
													 .KHz_CE_i(slow_ce_i),
													 .MHz_CE_i(micro_ce_i),
													 .sda_i(SDA_I[i2c_i]),
													 .sda_o(SDA_O[i2c_i]),
													 .sda_oe(SDA_OE[i2c_i]),
													 .scl_i(SCL_I[i2c_i]),
													 .scl_o(SCL_O[i2c_i]),
													 .scl_oe(SCL_OE[i2c_i]),
													 .rst_i(phy_rst_i),
													 .pps_i(pps_flag),
													 .db_status_i(DBSTATUS[i2c_i]),
													 .i2c_interface(i2c_daughter[i2c_i]),
													 .irsi2c_interface(irsi2c_daughter[i2c_i]),
													 .debug_o(i2c_debug[i2c_i])
													 );				
				end
			end
		endgenerate
		
	////////////////////////////////////////////////////////////////////
	// END I2C                            										//
	////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////
	// WISHBONE                          										//
	////////////////////////////////////////////////////////////////////

		// WISHBONE clock rename.
		// Nominally, WISHBONE clock and PHY clock should be thought
		// of as distinct, but they are currently identical.
		wire wb_clk = phy_clk_i;

		// WISHBONE arbiter and syscon (bus mux/demux + clock/reset distribution)
		//
		// To add a WISHBONE slave:
		// Increase this number.
		// Add a port in atri_wishbone_bus for the new slave interface.
		// Add a reassign inside atri_wishbone_bus to map the new interface.
		// Map the slave_select and slave_address lines inside atri_wishbone_bus.
		localparam NUM_WB_SLAVES = 9;
		wire [`WBIF_SIZE-1:0] wb_slave[NUM_WB_SLAVES-1:0];
		reg wb_rst = 0;
		atri_wishbone_bus #(.NUM_SLAVES(NUM_WB_SLAVES)) wb_arb(.clk_i(wb_clk),.rst_i(wb_rst),
										 .master_interface_io(wb_master),
										 .slave0_interface_io(wb_slave[0]),
										 .slave1_interface_io(wb_slave[1]),
										 .slave2_interface_io(wb_slave[2]),
										 .slave3_interface_io(wb_slave[3]),
										 .slave4_interface_io(wb_slave[4]),
										 .slave5_interface_io(wb_slave[5]),
										 .slave6_interface_io(wb_slave[6]),
										 .slave7_interface_io(wb_slave[7]),
										 .slave8_interface_io(wb_slave[8]));
		// Dummy slaves (placeholders) - only 5 and 9 currently
		wishbone_dummy_slave sl5(.interface_io(wb_slave[4]));
		wishbone_dummy_slave sl9(.interface_io(wb_slave[8]));

		// ID and DCM control block.
		wire wrclk_reset;
		wire [7:0] wrclk_status;
		wire wrclk_locked;

		wishbone_id_block #(.ID(BOARD_ID),
								  .VER_BOARD(VER_BOARD),
								  .VER_MAJOR(VER_MAJOR),
								  .VER_MINOR(VER_MINOR),
								  .VER_REV(VER_REV),
								  .VER_MONTH(VER_MONTH),.VER_DAY(VER_DAY)) id(.interface_io(wb_slave[0]),
									.dcm_status_i(wrclk_status[2:0]),
									.dcm_locked_i(wrclk_locked),
									.dcm_reset_o(wrclk_reset));

		wire [NUM_DAUGHTERS-1:0] dda_power;
		wire [NUM_DAUGHTERS-1:0] dda_drive;
		wire [NUM_DAUGHTERS-1:0] tda_power;
		wire [NUM_DAUGHTERS-1:0] tda_drive;
		wire [NUM_DAUGHTERS-1:0] drsv9_power;
		wire [NUM_DAUGHTERS-1:0] drsv9_drive;
		wire [NUM_DAUGHTERS-1:0] drsv10_power;
		wire [NUM_DAUGHTERS-1:0] drsv10_drive;
		generate
			genvar db_i;
			for (db_i=0;db_i<NUM_DAUGHTERS;db_i=db_i+1) begin : DB_DRIVE_POWER				
				assign DBPOWER[db_i][0] = dda_power[db_i];
				assign DBDRIVE[db_i][0] = dda_drive[db_i];

				assign DBPOWER[db_i][1] = tda_power[db_i];
				assign DBDRIVE[db_i][1] = tda_drive[db_i];

				assign DBPOWER[db_i][2] = drsv9_power[db_i];
				assign DBDRIVE[db_i][2] = drsv9_drive[db_i];

				assign DBPOWER[db_i][3] = drsv10_power[db_i];
				assign DBDRIVE[db_i][3] = drsv10_drive[db_i];
			end
		endgenerate
		
		wishbone_power_block #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) 
									power_ctrl(.interface_io(wb_slave[1]),
												  .dda_power(dda_power),
												  .dda_drive(dda_drive),
												  .tda_power(tda_power),
												  .tda_drive(tda_drive),
												  .drsv9_power(drsv9_power),
												  .drsv9_drive(drsv9_drive),
												  .drsv10_power(drsv10_power),
												  .drsv10_drive(drsv10_drive));

	////////////////////////////////////////////////////////////////////
	// END WISHBONE                      										//
	////////////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////
	// IRS2 TOP MODULES                  										//
	////////////////////////////////////////////////////////////////////


	// Flag sync the slow_ce_i into the irs_clk_i domain
	wire slow_ce_irs_clk;
	flag_sync slow_irs_flag_sync(.in_clkA(slow_ce_i),.out_clkB(slow_ce_irs_clk),.clkA(phy_clk_i),
										  .clkB(irs_clk_i));
	// Flag sync the micro_ce_i into the irs_clk_i domain
	wire micro_ce_irs_clk;
	flag_sync micro_irs_flag_sync(.in_clkA(micro_ce_i),.out_clkB(micro_ce_irs_clk),.clkA(phy_clk_i),
										  .clkB(irs_clk_i));

	////////////////////////////////////
	// WRITE STROBE CLOCK GENERATION	 //
	////////////////////////////////////
	
	wire 	clk_wrstrb;
	wire wr_strobe_feedback;
	wire wr_strobe_probe;
	wire dcm_is_locked;
	wire phase_shift_enable;//unused
	wire phase_shift_inc_n_dec; 
	wire phase_shift_done; 

	assign  phase_shift_enable = 1'b0; //no phase control for now
	assign  phase_shift_inc_n_dec = 1'b0;
  
	wire debug_CLK2X;
	wire debug_CLK270;

	DCM #(
      .SIM_MODE("SAFE"),  // Simulation: "SAFE" vs. "FAST", see "Synthesis and Simulation Design Guide" for details
      .CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
      .CLKIN_PERIOD(10),  // Specify period of input clock
      .CLKOUT_PHASE_SHIFT("FIXED"), // Specify phase shift of NONE, FIXED or VARIABLE
      .CLK_FEEDBACK("1X"),  // Specify clock feedback of NONE, 1X or 2X
      .DESKEW_ADJUST("SOURCE_SYNCHRONOUS"), // SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
                                            //   an integer from 0 to 15
      .DFS_FREQUENCY_MODE("LOW"),  // HIGH or LOW frequency mode for frequency synthesis
      .DLL_FREQUENCY_MODE("LOW"),  // HIGH or LOW frequency mode for DLL
      .DUTY_CYCLE_CORRECTION("TRUE"), // Duty cycle correction, TRUE or FALSE
      .PHASE_SHIFT(WRSTRB_PHASE_SHIFT),     // Amount of fixed phase shift from -255 to 255
      .STARTUP_WAIT("FALSE"),   // Delay configuration DONE until DCM LOCK, TRUE/FALSE
      .CLKFX_MULTIPLY(2),
      .CLKFX_DIVIDE(2)
   ) clk_wrstrb_gen (
      .CLK0(wr_strobe_feedback),     // 0 degree DCM CLK output
		.CLK180(wr_strobe_probe), 
      .CLK2X(debug_CLK2X),   // 2X DCM CLK output
      .CLK90(debug_CLK270),   // 90 degree DCM CLK output
      .LOCKED(wrclk_locked), // DCM LOCK status output
      .PSDONE(phase_shift_done), // Dynamic phase adjust done output
      .CLKFB(wr_feed_through_bufg),   // DCM clock feedback
      .CLKIN(irs_clk_i),   // Clock input (from IBUFG, BUFG or DCM)
      .PSCLK(1'b0),   // Dynamic phase adjust clock input -- use irs system clock -- possibly change
      .PSEN(1'b0),     // Dynamic phase adjust enable input
      .PSINCDEC(1'b0), // Dynamic phase adjust increment/decrement
      .STATUS(wrclk_status),
      .RST(wrclk_reset)        // DCM asynchronous reset input
   );
        
   BUFG feed_BUFG(.I(wr_strobe_feedback),.O(wr_feed_through_bufg));
   BUFG delayed_wr_strobe_BUFG(.I(wr_strobe_probe),.O(clk_wrstrb));

	////////////////////////////////////////////////////////////////////
	// IRS QUAD TOP																	//
	////////////////////////////////////////////////////////////////////

	wire T1_trigger;
	wire [NUM_L4-1:0] L4_trigger;
	wire [NUM_L4-1:0] L4_new_info;
	wire [8:0] T1_offset;
	
	wire [INFO_BITS-1:0] trigger_info;
	wire [NL4_BITS-1:0] trigger_address;
	wire trigger_info_read;

	// The software trigger start is stupidly in the IRS WISHBONE module
	// for idiotic historical reasons. Note that the *timing*
	// and *number of blocks* are in the trigger address space, where they should be.
	wire soft_trig;
	// soft trig info is only 8 bits.
	wire [7:0] soft_trig_info;
	wire irs_reset;
	
	wire [15:0] pps_counter;
	wire [31:0] cycle_counter;
	
	// irs_sampling/irs_sampling_ce: determines if the IRS is taking data
	wire irs_sampling;
	wire irs_sampling_ce;
	// irs_readout_ready: determines if the IRS can readout data
	wire irs_readout_ready;
	// irs_readout_full: asserted if the event buffer is full.
	wire irs_readout_full;
	irs_quad_top #(.NUM_DAUGHTERS(NUM_DAUGHTERS), .SENSE(SENSE)) 
		u_irs( .irs1_if_io(irs_interface[0]),
				 .irs2_if_io(irs_interface[1]),
				 .irs3_if_io(irs_interface[2]),
				 .irs4_if_io(irs_interface[3]),
				 .ev2_if_io(ev_interface_io),
				 .irsi2c1_if_io(irsi2c_daughter[0]),
				 .irsi2c2_if_io(irsi2c_daughter[1]),
				 .irsi2c3_if_io(irsi2c_daughter[2]),
				 .irsi2c4_if_io(irsi2c_daughter[3]),
				 .irs_wbif_io(wb_slave[2]),
				 .evrd_wbif_io(wb_slave[7]),
				 .clk_i(irs_clk_i),
				 .clk180_i(~irs_clk_i),
				 .clk_shift_i(clk_wrstrb),
				 .KHz_clk_i(slow_ce_irs_clk),
				 .MHz_clk_i(micro_ce_irs_clk),
				 .pps_i(core_pps_flag_sys_clk),
				 .pps_counter_i(pps_counter),
				 .cycle_counter_i(cycle_counter),
				 .trig_i(T1_trigger),
				 .trig_l4_i(L4_trigger),
				 .trig_l4_new_i(L4_new_info),
				 .trig_offset_i(T1_offset),
				 .trig_info_i(trigger_info),
				 .trig_info_addr_o(trigger_address),
				 .trig_info_rd_o(trigger_info_read),
				 .soft_trig_o(soft_trig),
				 .soft_trig_info_o(soft_trig_info),
				 .rst_o(irs_reset),
				 .sampling_o(irs_sampling),
				 .sampling_ce_o(irs_sampling_ce),
				 .readout_rdy_o(irs_readout_ready),
				 .readout_full_o(irs_readout_full),
				 .debug_o(irs_debug),
				 .debug_sel_i(debug_sel)
		);

	////////////////////////////////////////////////////////////////////
	// TRIGGERS																			//
	////////////////////////////////////////////////////////////////////

	// The monumental mess that was here now goes completely away.
	// Now we just have a nice, simple, top level trigger module.
	//% Single ended trigger lines.
	wire [7:0] trigger[MAX_DAUGHTERS-1:0];
	//% 1 if the associated trigger has power, 0 otherwise
	wire [7:0] trigger_power[MAX_DAUGHTERS-1:0];
	// Trigger infrastructure.
	generate
		genvar tr_i;
		for (tr_i=0;tr_i<MAX_DAUGHTERS;tr_i=tr_i+1) begin : TR
			if (tr_i<NUM_DAUGHTERS) begin : INFRA
				trigger_infrastructure trig_infra(.trig_p_i(TRG_P[tr_i]),.trig_n_i(TRG_N[tr_i]),
														 .trig_o(trigger[tr_i]));
				assign trigger_power[tr_i][3:0] = {DBPOWER[tr_i][1],DBPOWER[tr_i][1],DBPOWER[tr_i][1],DBPOWER[tr_i][1]};
				assign trigger_power[tr_i][7:4] = {DBPOWER[tr_i][2],DBPOWER[tr_i][2],DBPOWER[tr_i][2],DBPOWER[tr_i][2]};
			end else begin : DUMMY
				assign trigger[tr_i] = {8{1'b0}};
				assign trigger_power[tr_i] = {8{1'b0}};
			end
		end
	endgenerate
	wire [31:0] rf0_trig_info;
	wire [31:0] rf1_trig_info;

	wire ext_trig_flag;
	wire timed_trig_flag;
	wire [`SCAL_NUM_EXT_L4-1:0] l4_ext;
	assign l4_ext[0] = soft_trig;
	assign l4_ext[1] = timed_trig_flag;
	assign l4_ext[2] = ext_trig_flag;

	ext_trigger_generator ext_trigger(.clk_i(irs_clk_i),
												 .micro_ce_i(micro_ce_irs_clk),
												 .trig_i(ext_trig_i),
												 .trig_o(ext_trig_flag));


	trigger_top_v2 #(.NUM_DAUGHTERS(NUM_DAUGHTERS)) u_trig(.d1_trig_i(trigger[0]), .d1_pwr_i(trigger_power[0]),
								 .d2_trig_i(trigger[1]), .d2_pwr_i(trigger_power[1]),
								 .d3_trig_i(trigger[2]), .d3_pwr_i(trigger_power[2]),
								 .d4_trig_i(trigger[3]), .d4_pwr_i(trigger_power[3]),
								 .l4_ext_i(l4_ext),
								 .fclk_i(irs_clk_i),
								 .sclk_i(phy_clk_i),
								 .sce_i(micro_ce_i),
								 .pps_flag_fclk_i(core_pps_flag_sys_clk),
								 .scal_wbif_io(wb_slave[6]),
								 .trig_wbif_io(wb_slave[5]),
								 .readout_ready_i(irs_readout_ready),
								 .disable_i(!irs_sampling),
								 .disable_ce_i(irs_sampling_ce),
								 .trig_o(T1_trigger),
								 .trig_delay_o(T1_offset),
								 .trig_l4_o(L4_trigger),
								 .trig_l4_new_o(L4_new_info),
								 .trig_rf0_info_o(rf0_trig_info),
								 .trig_rf1_info_o(rf1_trig_info),
								 .debug_o(trigger_debug));

	assign gpio_debug_o[0] = trigger_debug[0];
	assign gpio_debug_o[1] = trigger_debug[4];
	
	wire [INFO_BITS-1:0] L4_info[NUM_L4-1:0];
	assign L4_info[0] = rf0_trig_info;
	assign L4_info[1] = rf1_trig_info;
	assign L4_info[2] = soft_trig_info;
	assign L4_info[3] = {32{1'b0}};
	assign L4_info[4] = {32{1'b0}};
	wire [INFO_BITS*NUM_L4-1:0] trigger_info_vec;

	generate
		genvar ti;
		for (ti=0;ti<NUM_L4;ti=ti+1) begin : TIVEC
			assign trigger_info_vec[ INFO_BITS*ti +: INFO_BITS ] = L4_info[ti];
		end
	endgenerate
	
	trigger_info_fifo tinfo_fifo(.clk_i(irs_clk_i),
										  .info_i(trigger_info_vec),
										  .wr_i(L4_new_info),
										  .wr_ce_i(irs_sampling_ce),
										  .addr_i(trigger_address),
										  .info_o(trigger_info),
										  .rd_i(trigger_info_read),
										  .rst_i(irs_reset));
	// PPS WISHBONE block
	wire pps_sel;
	
	wishbone_pps_block wb_pps(.interface_io(wb_slave[3]),
									  .pps_i(pps_i),
									  .pps_flag_i(pps_flag_i),
									  .pps_flag_o(core_pps_flag_phy_clk),
									  .pps_flag_fast_clk_o(core_pps_flag_sys_clk),
									  .slow_ce_i(slow_ce_i),
									  .fast_clk_i(irs_clk_i),
									  .cycle_count_o(cycle_counter),
									  .pps_count_o(pps_counter),
									  .timed_trigger_o(timed_trig_flag)
									  );
	
	generate
		genvar rsvd_i, rsvd_j;
		if (IMPLEMENT_RESERVED == "YES") begin
			for (rsvd_i=0;rsvd_i<NUM_DAUGHTERS;rsvd_i=rsvd_i+1) begin : RSVD
				for (rsvd_j=0;rsvd_j<3;rsvd_j=rsvd_j+1) begin : DLOOP
					assign DRSV_DIFF[rsvd_i][rsvd_j] = 1'b0;
					OBUFDS drsv_obuf(.I(DRSV_DIFF[rsvd_i][rsvd_j]),.O(DRSV_P[rsvd_i][rsvd_j]),.OB(DRSV_N[rsvd_i][rsvd_j]));
				end
				IBUFDS crsv1_ibuf(.I(CRSV_P[rsvd_i][1]),.IB(CRSV_N[rsvd_i][1]),.O(CRSV_DIFF[rsvd_i][1]));
				IBUFDS crsv2_ibuf(.I(CRSV_P[rsvd_i][2]),.IB(CRSV_N[rsvd_i][2]),.O(CRSV_DIFF[rsvd_i][2]));
			end
		end
	endgenerate

	
	assign wrclk_o = clk_wrstrb;

endmodule
