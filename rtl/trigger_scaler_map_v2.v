`timescale 1ns / 1ps

//% @file trigger_scaler_map_v2.v Contains trigger_scaler_map_v2

`include "trigger_defs.vh"

//% @brief trigger_scaler_map, version 2.
//%
//% @par Module Symbol
//% @gensymbol
//% MODULE trigger_scaler_map_v2
//% LPORT d1_trig_i

//% trigger_scaler_map takes the input trigger lines (after the IBUFDS
//% to make them single-ended) and maps them to L1 triggers. 
//% Delays are also applied in this module.


module trigger_scaler_map_v2(
		d1_trig_i, d1_pwr_i, d2_trig_i, d2_pwr_i,
		d3_trig_i, d3_pwr_i, d4_trig_i, d4_pwr_i,
		
		l1_trig_p_o,
		l1_trig_n_o,
		l1_scaler_o,
		
		rsv_trig_db_i,
		l1_mask_i,
		l1_oneshot_i,
		//%FIXME: addition from Patrick's patch
 		l1_delay_i,
 		l1_delay_o,
 		l1_delay_addr_i,
 		l1_delay_stb_i,
		
		fclk_i,
		sclk_i,
		sce_i
	);
	//%FIXME: Addition from Patrick's patch.
	`include "clogb2.vh"
   ////////////////////////////////////////////////////
   //
   // PARAMETERS
   //
   ////////////////////////////////////////////////////

	//% Number of implemented daughters.
	parameter NUM_DAUGHTERS = 4;
	//% Maximum number of daughters (= number of input trigger ports).
	localparam MAX_DAUGHTERS = 4;
	//% Number of trigger bits per daughter stack (= number of TRG_P/N pairs per daughter)
	localparam NUM_TRIG = 8;
	//% Number of L1 scalers
	localparam NUM_L1 = `SCAL_NUM_L1;
	//%FIXME: addition from Patrick's patch.
 	//% Number of bits to address the L1 scalers
 	localparam NUM_L1_BITS = clogb2(NUM_L1);	
	//% Number of daughterboards that trigger...
	localparam NUM_DB = 2;
	//% Number of triggers per daughterboard
	localparam DBTRIG = NUM_TRIG/2;
	//% Number of bits in the oneshot length field
	localparam TRIG_ONESHOT_BITS = `TRIG_ONESHOT_BITS;
	//%FIXME: addition from Patrick's patch: 4 lines
 	//% Number of bits in the trigger delay field
 	localparam TRIG_DELAY_VAL_BITS = `TRIG_DELAY_VAL_BITS;
 	//% Default value of trigger delay.
 	localparam [TRIG_DELAY_VAL_BITS-1:0] TRIG_DELAY_DEFAULT = `TRIG_DELAY_DEFAULT;
	
   ////////////////////////////////////////////////////
   //
	// PORTS
	//
   ////////////////////////////////////////////////////
	
	//% Daughter 1 triggers
	input [NUM_TRIG-1:0] d1_trig_i;
	//% Daughter 1 power
	input [NUM_TRIG-1:0] d1_pwr_i;

	//% Daughter 2 triggers
	input [NUM_TRIG-1:0] d2_trig_i;
	//% Daughter 2 power
	input [NUM_TRIG-1:0] d2_pwr_i;


	//% Daughter 3 triggers
	input [NUM_TRIG-1:0] d3_trig_i;
	//% Daughter 3 power
	input [NUM_TRIG-1:0] d3_pwr_i;


	//% Daughter 4 triggers
	input [NUM_TRIG-1:0] d4_trig_i;
	//% Daughter 4 power
	input [NUM_TRIG-1:0] d4_pwr_i;
	
	//% L1 triggers, registered on rising edge
	output [NUM_L1-1:0] l1_trig_p_o;
	//% L1 triggers, registered on falling edge
	output [NUM_L1-1:0] l1_trig_n_o;
	//% L1 scaler outputs, with stuck-on detection.
	output [NUM_L1-1:0] l1_scaler_o;
	
	//% Indicates which daughterboard should map to L1[19:16] (dynamically settable)
	input [1:0] rsv_trig_db_i;
	//% Mask for the L1 triggers. Scalers still generated.
	input [NUM_L1-1:0] l1_mask_i;
	//% Length of oneshot.
	input [TRIG_ONESHOT_BITS-1:0] l1_oneshot_i;
	
	//%FIXME: addition from Patrick's patch.
 	//% Input delay value
 	input [TRIG_DELAY_VAL_BITS-1:0] l1_delay_i;
 	//% Output delay value
 	input [TRIG_DELAY_VAL_BITS-1:0] l1_delay_o;
 	//% Input delay address
 	input [NUM_L1_BITS-1:0] l1_delay_addr_i;
 	//% Input delay value strobe
 	input l1_delay_stb_i;
 
	
	
	
	//% Fast clock.
	input fclk_i;
	//% Slow clock
	input sclk_i;
	//% Slow clock enable (on sclk): used for stuck-on detection, nom. 1 MHz.
	input sce_i;

   ////////////////////////////////////////////////////
   //
	// SIGNALS
	//
   ////////////////////////////////////////////////////

	reg stuck_sync = 0;
	// This synchronizes all the stuck bit toggling.
	always @(posedge fclk_i) begin
		stuck_sync <= ~stuck_sync;
	end
	
	//// Collect input signals.
	wire [NUM_TRIG-1:0] tr_power[MAX_DAUGHTERS-1:0];
	wire [NUM_TRIG-1:0] tr_trig[MAX_DAUGHTERS-1:0];
	
	assign tr_power[0] = d1_pwr_i;
	assign tr_trig[0] = d1_trig_i;
	assign tr_power[1] = d2_pwr_i;
	assign tr_trig[1] = d2_trig_i;
	assign tr_power[2] = d3_pwr_i;
	assign tr_trig[2] = d3_trig_i;
	assign tr_power[3] = d4_pwr_i;
	assign tr_trig[3] = d4_trig_i;

	//%FIXME: addition from Patrick's patch: 19 lines
 	// Here the delays are assigned to a vector, as they come in via the I2C bus.
 	reg [TRIG_DELAY_VAL_BITS-1:0] trig_delays[NUM_L1-1:0];
 	reg [TRIG_DELAY_VAL_BITS-1:0] trig_delay_out = {TRIG_DELAY_VAL_BITS{1'b0}};
 	integer td_i;
 	initial begin
 		for (td_i=0;td_i<NUM_L1;td_i=td_i+1) begin
 			trig_delays[td_i] <= TRIG_DELAY_DEFAULT;
 		end
 	end
 
 	integer ds_i;
 	always @(posedge sclk_i) begin
 		for (ds_i=0;ds_i<NUM_L1;ds_i=ds_i+1) begin
 			if (l1_delay_stb_i && (l1_delay_addr_i == ds_i))
 				trig_delays[ds_i] <= l1_delay_i;
 			if (l1_delay_addr_i == ds_i)
 				trig_delay_out <= trig_delays[ds_i];
 		end
 	end
 
 

	// NOTE THE BACKWARDS INDICES!
	wire [MAX_DAUGHTERS-1:0] tr_rsv_trig_p[DBTRIG-1:0];
	wire [MAX_DAUGHTERS-1:0] tr_rsv_trig_n[DBTRIG-1:0];
	wire [MAX_DAUGHTERS-1:0] tr_rsv_scal[DBTRIG-1:0];
	reg [DBTRIG-1:0] l1_rsv_p = {DBTRIG{1'b0}};
	reg [DBTRIG-1:0] l1_rsv_n = {DBTRIG{1'b0}};
	reg [DBTRIG-1:0] l1_rsv_scal = {DBTRIG{1'b0}};
	wire [MAX_DAUGHTERS-1:0] rsv_sel;
	generate
		genvar i,j,k,l,m;
		// This is a little harder now. L1[15:0] are the TDAs.
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin : L1DB
			for (j=0;j<DBTRIG;j=j+1) begin : L1CH
				//% One-shot trigger and scaler (flag) output for each channel
				trigger_scaler_v5 tda_ts(.power_i(tr_power[i][j]),.mask_i(l1_mask_i[i*DBTRIG+j]),
												 .trigger_i(tr_trig[i][j]),
												 .trig_p_o(l1_trig_p_o[i*DBTRIG+j]),
												 .trig_n_o(l1_trig_n_o[i*DBTRIG+j]),
												 .scaler_o(l1_scaler_o[i*DBTRIG+j]),
												 .fast_clk_i(fclk_i),
												 .slow_clk_i(sclk_i),
												 .slow_ce_i(sce_i),
												 .sync_i(stuck_sync),
												 .trig_oneshot_i(l1_oneshot_i),
												 //%FIXME: addition from Patrick's patch
 												 .delay_i(trig_delays[i*DBTRIG+j]));
				// We *completely* sleaze the reserve trigger muxing:
				// rsv_trig_db_i determines which four of the daughterboards
				// is pretended to be 'powered', and then *all* of the outputs are or'd
				// together.
				// We shorten the number of sync cycles by 1, and then extend it here
				// to match the other one.
				//% Power indicator for reserve DB. Only rsv_trig_db is considered to have power.
				assign rsv_sel[i] = (rsv_trig_db_i == i);
				//% Reserve DB trigger and scaler.
				trigger_scaler_v5 #(.POLARITY("NEGATIVE")) 
										rsv_ts(.power_i(tr_power[i][j+DBTRIG] && rsv_sel[i]),.mask_i(l1_mask_i[MAX_DAUGHTERS*DBTRIG]),
												 .trigger_i(tr_trig[i][j+DBTRIG]),
												 .trig_p_o(tr_rsv_trig_p[j][i]),
												 .trig_n_o(tr_rsv_trig_n[j][i]),
												 .scaler_o(tr_rsv_scal[j][i]),
												 .fast_clk_i(fclk_i),
												 .slow_clk_i(sclk_i),
												 .slow_ce_i(sce_i),
												 .sync_i(stuck_sync),
												 .trig_oneshot_i(l1_oneshot_i),
												 //%FIXME: addition from Patrick's patch
 												 .delay_i(trig_delays[i*DBTRIG+j]));
			end
		end
		for (k=NUM_DAUGHTERS;k<MAX_DAUGHTERS;k=k+1) begin : DUMMYLOOP
			//% Dummy (non-implemented) +edge triggers.
			assign l1_trig_p_o[k*DBTRIG +: DBTRIG] = {DBTRIG{1'b0}};
			//% Dummy (non-implemented) -edge triggers.
			assign l1_trig_n_o[k*DBTRIG +: DBTRIG] = {DBTRIG{1'b0}};
			//% Dummy (non-implemented) scalers.
			assign l1_scaler_o[k*DBTRIG +: DBTRIG] = {DBTRIG{1'b0}};

			// Have to loop here because the indices are backwards.
			for (l=0;l<DBTRIG;l=l+1) begin : DUMMYRSV
				//% Dummy (non-implemented) reserve +edge triggers.
				assign tr_rsv_trig_p[l][k] = 1'b0;
				//% Dummy (non-implemented) reserve -edge triggers.
				assign tr_rsv_trig_n[l][k] = 1'b0;
				//% Dummy (non-implemented) reserve scalers.
				assign tr_rsv_scal[l][k] = 1'b0;
			end
		end
		for (m=0;m<DBTRIG;m=m+1) begin : ORLOOP
			//% Merge the reserve triggers/scalers. Both on +edge.
			always @(posedge fclk_i) begin : ORREGP
				l1_rsv_p[m] <= (!l1_mask_i[MAX_DAUGHTERS*DBTRIG+m]) && (|tr_rsv_trig_p[m]);
				l1_rsv_scal[m] <= |tr_rsv_scal[m];
			end
			//% Merge the reserve trigger on the -edge.
			always @(negedge fclk_i) begin : ORREGN
				l1_rsv_n[m] <= (!l1_mask_i[MAX_DAUGHTERS*DBTRIG+m]) && (|tr_rsv_trig_n[m]);
			end
		end
	endgenerate

	assign l1_trig_p_o[DBTRIG*MAX_DAUGHTERS +: DBTRIG] = l1_rsv_p;
	assign l1_trig_n_o[DBTRIG*MAX_DAUGHTERS +: DBTRIG] = l1_rsv_n;
	assign l1_scaler_o[DBTRIG*MAX_DAUGHTERS +: DBTRIG] = l1_rsv_scal;
	//%FIXME: addition from Patrick's patch
	assign l1_delay_o = trig_delay_out;

endmodule

