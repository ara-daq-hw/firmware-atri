`timescale 1ns / 1ps

`include "wb_interface.vh"

module wishbone_scaler_block(
		inout [`WBIF_SIZE-1:0] interface_io,
		input [3:0] d1_tda_scal_i,
		input [3:0] d2_tda_scal_i,
		input [3:0] d3_tda_scal_i,
		input [3:0] d4_tda_scal_i,
		input [3:0] d1_rsv_scal_i,
		input [3:0] d2_rsv_scal_i,
		input [3:0] d3_rsv_scal_i,
		input [3:0] d4_rsv_scal_i,
		input [15:0] l2_scalers,
		input [1:0] l2_5_scalers,
		input top_self_scaler,
		input top_surf_scaler,
		input fast_clk_i,
		input pps_flag_fast_clk_i,
		output [15:0] debug_counter
    );

	parameter NUM_DAUGHTERS = 4;
	parameter MAX_DAUGHTERS = 4;

	// downscale L1 by 32.
	parameter L1_PRESCALE_BITS = 5;
	//do not downscale L2  - for now!
	parameter L2_PRESCALE_BITS = 0; 
	parameter L2_5_PRESCALE_BITS = 0; 
	//do not downscale top trigger - for now!
	parameter TOP_PRESCALE_BITS = 0; 
	localparam OUTPUT_BITS = 16;
	localparam L1_SCALER_BITS = L1_PRESCALE_BITS+OUTPUT_BITS;
	localparam L2_SCALER_BITS = L2_PRESCALE_BITS+OUTPUT_BITS;
	localparam L2_5_SCALER_BITS = L2_5_PRESCALE_BITS+OUTPUT_BITS;
	localparam TOP_SCALER_BITS = TOP_PRESCALE_BITS+OUTPUT_BITS;

	// Logic here might change a bit: we might split the prescaler and counter
	// into two separate portions and generate a flag off of the prescaler
	// to cut down on the logic demands, since we don't actually care about being one
	// cycle delayed all that much.

	// WISHBONE interface expander (virtual ports)
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

	wire [3:0] tda_in[NUM_DAUGHTERS-1:0];
	wire [3:0] rsv_in[NUM_DAUGHTERS-1:0];
	generate
		if (NUM_DAUGHTERS > 0) begin : D1
			assign tda_in[0] = d1_tda_scal_i;
			assign rsv_in[0] = d1_rsv_scal_i;
		end
		if (NUM_DAUGHTERS > 1) begin : D2
			assign tda_in[1] = d2_tda_scal_i;
			assign rsv_in[1] = d2_rsv_scal_i;
		end
		if (NUM_DAUGHTERS > 2) begin : D3
			assign tda_in[2] = d3_tda_scal_i;
			assign rsv_in[2] = d3_rsv_scal_i;
		end
		if (NUM_DAUGHTERS > 3) begin : D4
			assign tda_in[3] = d4_tda_scal_i;
			assign rsv_in[3] = d4_rsv_scal_i;
		end
	endgenerate
	reg [L1_SCALER_BITS-1:0] tda_counters[NUM_DAUGHTERS-1:0][3:0];
	reg [L1_SCALER_BITS-1:0] rsv_counters[NUM_DAUGHTERS-1:0][3:0];
	reg [L1_SCALER_BITS-1:0] tda_latch[NUM_DAUGHTERS-1:0][3:0];
	reg [L1_SCALER_BITS-1:0] rsv_latch[NUM_DAUGHTERS-1:0][3:0];
	reg [L1_SCALER_BITS-1:0] tda_latch_wb[NUM_DAUGHTERS-1:0][3:0];
	reg [L1_SCALER_BITS-1:0] rsv_latch_wb[NUM_DAUGHTERS-1:0][3:0];
	
	reg [L2_SCALER_BITS-1:0] l2_counters[15:0];
	reg [L2_SCALER_BITS-1:0] l2_latch[15:0];
	reg [L2_SCALER_BITS-1:0] l2_latch_wb[15:0];
	
	reg [L2_5_SCALER_BITS-1:0] l2_5_counters[1:0];
	reg [L2_5_SCALER_BITS-1:0] l2_5_latch[1:0];
	reg [L2_5_SCALER_BITS-1:0] l2_5_latch_wb[1:0];
	
	reg [TOP_SCALER_BITS-1:0] top_counter;
	reg [TOP_SCALER_BITS-1:0] top_latch;
	reg [TOP_SCALER_BITS-1:0] top_latch_wb;
	
	reg [TOP_SCALER_BITS-1:0] top_s_counter;
	reg [TOP_SCALER_BITS-1:0] top_s_latch;
	reg [TOP_SCALER_BITS-1:0] top_s_latch_wb;
	
	wire pps_flag_fastclk = pps_flag_fast_clk_i;
	
	integer i,j,k,l;

	// Initialize everything to zero.
	initial begin
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin
			for (j=0;j<4;j=j+1) begin
				tda_counters[i][j] <= {L1_SCALER_BITS{1'b0}};
				rsv_counters[i][j] <= {L1_SCALER_BITS{1'b0}};
				tda_latch[i][j] <= {L1_SCALER_BITS{1'b0}};
				rsv_latch[i][j] <= {L1_SCALER_BITS{1'b0}};
				tda_latch_wb[i][j] <= {L1_SCALER_BITS{1'b0}};
				rsv_latch_wb[i][j] <= {L1_SCALER_BITS{1'b0}};
			end
		end
		for (k=0;k<15;k=k+1) begin
				l2_counters[k] <= {L2_SCALER_BITS{1'b0}};
				l2_latch[k] <= {L2_SCALER_BITS{1'b0}};
				l2_latch_wb[k] <= {L2_SCALER_BITS{1'b0}};
		end
		for (l=0;l<1;l=l+1) begin
				l2_5_counters[l] <= {L2_5_SCALER_BITS{1'b0}};
				l2_5_latch[l] <= {L2_5_SCALER_BITS{1'b0}};
				l2_5_latch_wb[l] <= {L2_5_SCALER_BITS{1'b0}};
		end
			top_counter <= {TOP_SCALER_BITS{1'b0}};
			top_latch <= {TOP_SCALER_BITS{1'b0}};
			top_latch_wb <= {TOP_SCALER_BITS{1'b0}};
			
			top_s_counter <= {TOP_SCALER_BITS{1'b0}};
			top_s_latch <= {TOP_SCALER_BITS{1'b0}};
			top_s_latch_wb <= {TOP_SCALER_BITS{1'b0}};
	end
	
	wire update_wb;

	// Count when a flag comes in, and reset
	// at a PPS flag. Note! The current scalar
	// implementation isn't that accurate at
	// high rates when the occupancy gets large
	// because it's an edge detection algorithm.
	
	// Also, when a PPS flag occurs, latch the value
	// to transfer to the WB domain.
	integer m;
	generate
		genvar n;
		for (n=0;n<NUM_DAUGHTERS;n=n+1) begin : SCALER_LOOP
			always @(posedge fast_clk_i) begin
				for (m=0;m<4;m=m+1) begin
					if (pps_flag_fastclk)
						tda_counters[n][m] <= {L1_SCALER_BITS{1'b0}};
					else if (tda_in[n][m] && tda_counters[n][m] != {L1_SCALER_BITS{1'b1}})
						tda_counters[n][m] <= tda_counters[n][m] + 1;

					if (pps_flag_fastclk)
						rsv_counters[n][m] <= {L1_SCALER_BITS{1'b0}};
					else if (rsv_in[n][m] && rsv_counters[n][m] != {L1_SCALER_BITS{1'b1}})
						rsv_counters[n][m] <= rsv_counters[n][m] + 1;

					if (pps_flag_fastclk) begin
						tda_latch[n][m] <= tda_counters[n][m];
						rsv_latch[n][m] <= rsv_counters[n][m];
					end
				end
			end
		end
	endgenerate
	//l2 scalers counters
	generate
		genvar L2_i;
		for (L2_i=0;L2_i<15;L2_i=L2_i+1) begin : L2_COUNT_LOOP
			always @(posedge fast_clk_i) begin
				if (pps_flag_fastclk)
					l2_counters[L2_i] <= {L2_SCALER_BITS{1'b0}};
				else if (l2_scalers[L2_i] && l2_counters[L2_i] != {L2_SCALER_BITS{1'b1}})
					l2_counters[L2_i] <= l2_counters[L2_i] + 1;
				if (pps_flag_fastclk)
					l2_latch[L2_i] <= l2_counters[L2_i];
			end
		end
	endgenerate
	
	//l2.5 scalers counters (Version 2 only)

	// NOTE! This WAS "L25_i<1", but there are 2 L2.5 scalers.
	generate
		genvar L25_i;
		for (L25_i=0;L25_i<2;L25_i=L25_i+1) begin : L25_COUNT_LOOP
			always @(posedge fast_clk_i) begin
				if (pps_flag_fastclk)
					l2_5_counters[L25_i] <= {L2_5_SCALER_BITS{1'b0}};
				else if (l2_5_scalers[L25_i] && l2_5_counters[L25_i] != {L2_5_SCALER_BITS{1'b1}})
					l2_5_counters[L25_i] <= l2_5_counters[L25_i] + 1;
				if (pps_flag_fastclk) begin
					l2_5_latch[L25_i] <= l2_5_counters[L25_i];
				end
			end
		end
	endgenerate
		
		//top scaler counter
	always @(posedge fast_clk_i) begin
				if (pps_flag_fastclk)
					top_counter <= {L2_SCALER_BITS{1'b0}};
				else if (top_self_scaler && top_counter != {L2_SCALER_BITS{1'b1}})
					top_counter <= top_counter + 1;
				if (pps_flag_fastclk) begin
					top_latch <= top_counter;
				end
	end
	
			//top surface scaler counter
	always @(posedge fast_clk_i) begin
				if (pps_flag_fastclk)
					top_s_counter <= {L2_SCALER_BITS{1'b0}};
				else if (top_surf_scaler && top_s_counter != {L2_SCALER_BITS{1'b1}})
					top_s_counter <= top_s_counter + 1;
				if (pps_flag_fastclk) begin
					top_s_latch <= top_s_counter;
				end
	end
	
	// Send a flag to the WB clk domain when a PPS flag occurs.
	flag_sync update_wb_sync(.in_clkA(pps_flag_fastclk),.out_clkB(update_wb),.clkA(fast_clk_i),
									 .clkB(wb_clk_i));

	// Transfer scaler count to WB clk domain.
	integer o,p;
	always @(posedge wb_clk_i) begin
		for (o=0;o<NUM_DAUGHTERS;o=o+1) begin
			for (p=0;p<4;p=p+1) begin
				if (update_wb) begin
					tda_latch_wb[o][p] <= tda_latch[o][p];
					rsv_latch_wb[o][p] <= rsv_latch[o][p];
				end
			end
		end
	end
	
	integer q;
	always @(posedge wb_clk_i) begin
			for (q=0;q<15;q=q+1) begin
				if (update_wb) begin
					l2_latch_wb[q] <= l2_latch[q];
				end
			end
	end

	integer r;
	always @(posedge wb_clk_i) begin
			for (r=0;r<1;r=r+1) begin
				if (update_wb) begin
					l2_5_latch_wb[r] <= l2_5_latch[r];
				end
			end
	end
	
	always @(posedge wb_clk_i) begin
				if (update_wb) begin
					top_latch_wb <= top_latch;
				end
	end
	
	
	always @(posedge wb_clk_i) begin
				if (update_wb) begin
					top_s_latch_wb <= top_s_latch;
				end
	end
	
	// Multiplexed data output.
	reg [7:0] dat_out_muxed = {8{1'b0}};
	
	// SCALER MAP:
	// 2 addresses per scaler, 4 scalers per TDA, 4 daughters
	// So the TDAs generate 8 addresses per daughter, 4 daughters total, or 32 total addresses
	// We reserve an equivalent number of addresses for the higher-level triggers, which will
	// be added later.
	// Reserveds take up a possible additional 32 total addresses.
	// We may remap things around later, but I'd prefer not to.
	//
	// NOTE: Our real address space is 0x0100-0x01FF. We can't exceed 0x0000-0x00FF here,
	// so we'll only use adr_i[7:0] here.
	//
	// addresses 0x0000-0x001F: TDAs. (000x xxxx) 
	wire scaler_select_tda = (adr_i[7:5] == 3'b000);
	wire [1:0] ss_tda_channel = adr_i[2:1];
	wire [1:0] ss_tda_daughter = adr_i[4:3];
	// addresses 0x0020-0x003F: higher level triggers based on TDAs (001x xxxx)
	wire scaler_select_tda_higher_level = (adr_i[7:5] == 3'b001);
	wire [3:0] ss_l2 = adr_i[4:1];
//	// addresses 0x0080-0x009F: higher level triggers based on TDAs (100x xxxx)
//	wire scaler_select_tda_higher_level = (adr_i[7:5] == 3'b100);
//	wire [3:0] ss_l2 = adr_i[4:1];
	// addresses 0x0040-0x005F: reserveds. (010x xxxx)
	wire scaler_select_reserveds = (adr_i[7:5] == 3'b010);
	wire [1:0] ss_rsv_channel = adr_i[2:1];
	wire [1:0] ss_rsv_daughter = adr_i[4:3];
	wire [OUTPUT_BITS-1:0] tda_latch_wb_selected = 
		tda_latch_wb[ss_tda_daughter][ss_tda_channel][L1_SCALER_BITS-1:L1_SCALER_BITS-OUTPUT_BITS];
	wire [OUTPUT_BITS-1:0] rsv_latch_wb_selected = 
		rsv_latch_wb[ss_rsv_daughter][ss_rsv_channel][L1_SCALER_BITS-1:L1_SCALER_BITS-OUTPUT_BITS];
	wire [OUTPUT_BITS-1:0] l2_latch_wb_selected = 
		l2_latch_wb[ss_l2][L2_SCALER_BITS-1:L2_SCALER_BITS-OUTPUT_BITS];

	wire scaler_select_top = (adr_i[7:1] == 7'b0110000); //chosen the first "free"
	
	wire [OUTPUT_BITS-1:0] top_latch_wb_selected =
	   top_latch_wb[L2_SCALER_BITS-1:L2_SCALER_BITS-OUTPUT_BITS];

	wire scaler_select_top_s = (adr_i[7:1] == 7'b0110001); //after the top RF scaler
	
	wire [OUTPUT_BITS-1:0] top_s_latch_wb_selected =
	   top_s_latch_wb[L2_SCALER_BITS-1:L2_SCALER_BITS-OUTPUT_BITS];
	
	
	wire scaler_select_l_2_5 = (adr_i[7:2] == 6'b011001);

	wire  [0:0] ss_l2_5 = adr_i[1];

	wire [OUTPUT_BITS-1:0] l2_5_latch_wb_selected = 
		l2_latch_wb[ss_l2_5][L2_5_SCALER_BITS-1:L2_5_SCALER_BITS-OUTPUT_BITS];
		

	always @(*) begin
		if (scaler_select_tda) begin
			// Demux
			if (!adr_i[0])
				dat_out_muxed <= tda_latch_wb_selected[7:0];
			else
				dat_out_muxed <= tda_latch_wb_selected[15:8];
		end
		else if (scaler_select_tda_higher_level) begin
			if (!adr_i[0]) 
				dat_out_muxed <= l2_latch_wb_selected[7:0];
			else
				dat_out_muxed <= l2_latch_wb_selected[15:8];
		end
		else if (scaler_select_reserveds) begin
			if (!adr_i[0])
				dat_out_muxed <= rsv_latch_wb_selected[7:0];
			else
				dat_out_muxed <= rsv_latch_wb_selected[15:8];
		end
		else if (scaler_select_top) begin
			if (!adr_i[0])
				dat_out_muxed <= top_latch_wb_selected[7:0];
			else
				dat_out_muxed <= top_latch_wb_selected[15:8];
		end
		else if (scaler_select_top_s) begin
			if (!adr_i[0])
				dat_out_muxed <= top_s_latch_wb_selected[7:0];
			else
				dat_out_muxed <= top_s_latch_wb_selected[15:8];
		end
		else if (scaler_select_l_2_5 ) begin
			if (!adr_i[0]) 
				dat_out_muxed <= l2_5_latch_wb_selected[7:0];
			else
				dat_out_muxed <= l2_5_latch_wb_selected[15:8];
		end
		else 
			dat_out_muxed <= {8{1'b0}};
	end
	assign ack_o = cyc_i && stb_i;
	assign rty_o = 0;
	assign err_o = 0;
	assign dat_o = dat_out_muxed;
	assign debug_counter = l2_counters[12];
endmodule
