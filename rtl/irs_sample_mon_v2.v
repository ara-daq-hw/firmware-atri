`timescale 1ns / 1ps
// This is a (quad) sample monitor for an IRS. For fewer IRSes, just set NUM_IRS to less than 4,
// and only pick off the ones you want.
// Input clock should be 1/32 of the desired sampling frequency. If it's not, just read
// the code carefully to see if it will still be okay. You might need to increase/decrease
// the SERDES.
// BUFIO2s go outside of here because they're architecture dependent.
module irs_sample_mon_v2(
		sample_mon_i,
		clk_i,
		en_i,
		rst_i,
		sync_i,
		sst_i,
		irs1_mon_o,
		irs2_mon_o,
		irs3_mon_o,
		irs4_mon_o,
		debug_o
    );

	parameter MAX_IRS = 4;
	parameter NUM_IRS = 4;
	input [NUM_IRS-1:0] sample_mon_i;
	input clk_i;
	input en_i;
	input rst_i;
	input sync_i;
	input sst_i;
	output [52:0] debug_o;

	// These might need to be increased in resolution. The PicoBlaze can
	// handle that.
	output [7:0] irs1_mon_o;
	output [7:0] irs2_mon_o;
	output [7:0] irs3_mon_o;
	output [7:0] irs4_mon_o;
	wire [MAX_IRS-1:0] irs_mon_o;
	assign irs1_mon_o = irs_mon_o[0];
	assign irs2_mon_o = irs_mon_o[1];
	assign irs3_mon_o = irs_mon_o[2];
	assign irs4_mon_o = irs_mon_o[3];
	
	// Phase-shifted 100 MHz clock.
	wire shiftclk;

	reg [7:0] irs_monitor_value[NUM_IRS-1:0];
	wire [7:0] irs_sample_mon_data[MAX_IRS-1:0];
	wire [MAX_IRS-1:0] irs_sample_mon_en = {NUM_IRS{1'b1}};
	wire sample_data;
	wire sample_data_sync;
	wire latch_data_go_high;
	wire latch_data_go_low;
	wire shreg_latch_data;
	reg [1:0] irs_sel = {2{1'b0}};
	wire latch_output_value;
	wire [7:0] pb_output_value;
	wire [MAX_IRS-1:0] dbg_tsaout_p;
	wire [MAX_IRS-1:0] dbg_tsaout_n;
	integer ii;
	initial for (ii=0;ii<NUM_IRS;ii=ii+1) irs_monitor_value[ii] <= {8{1'b0}};
	generate
		genvar i;
		for (i=0;i<MAX_IRS;i=i+1) begin : ML
			if (i<NUM_IRS) begin : IRSMON
				wire q_rise, q_fall;
				reg latch_data = 0;
				reg [1:0] dbg_p = 0;
				reg [1:0] dbg_n = 0;
				always @(posedge shiftclk) begin
					if (latch_data_go_high)
						latch_data <= 1;
					else if (latch_data_go_low)	
						latch_data <= 0;
				end
				assign irs_mon_o[i] = irs_monitor_value[i];
				always @(posedge clk_i) begin : LATCH_OUT
					if (latch_output_value && (irs_sel == i)) 
						irs_monitor_value[i] <= pb_output_value;
				end
				IDDR2 #(.DDR_ALIGNMENT("NONE"),.INIT_Q0(0),.INIT_Q1(0))
						tsaout_ddrff(.D(sample_mon_i[i]),.C0(shiftclk),.C1(~shiftclk),.CE(1'b1),
										 .Q0(q_rise),.Q1(q_fall));					
				reg [1:0] ddelay = {2{1'b0}};
				always @(posedge shiftclk) ddelay[0] <= q_rise;
				always @(negedge shiftclk) ddelay[1] <= q_fall;
				reg [7:0] data_in = {8{1'b0}};
				// Rising edge comes first, since we just latch them here.
				// Then the negative edge.
				always @(posedge shiftclk) begin : LATCH_IN
					if (latch_data) data_in <= {data_in[5:0],ddelay[0],ddelay[1]};
				end
				always @(posedge shiftclk) begin : DBGOUT
					dbg_p[1] <= dbg_p[0];
					dbg_n[1] <= dbg_n[0];
				end
				always @(posedge shiftclk) begin : DBGP
					dbg_p[0] <= ddelay[0];
				end
				always @(negedge shiftclk) begin : DBGN
					dbg_n[0] <= ddelay[1];
				end
				assign dbg_tsaout_p[i] = dbg_p[1];
				assign dbg_tsaout_n[i] = dbg_n[1];
				assign irs_sample_mon_data[i] = data_in;
			end else begin : DUMMY
				assign irs_mon_o[i] = {8{1'b0}};
				assign irs_sample_mon_data[i] = {4{1'b0}};
			end
		end
	endgenerate
	reg [3:0] latching = {4{1'b0}};
//	assign latch_data = (latching != {4{1'b1}});
	flag_sync sample_flag_sync(.in_clkA(sample_data),.out_clkB(sample_data_sync),.clkA(clk_i),.clkB(shiftclk));				
	always @(posedge shiftclk) begin
		if (sample_data_sync) begin
			latching <= {4{1'b0}};
		end else begin
			latching <= {latching[2:0],1'b1};
		end
	end
	assign latch_data_go_high = sample_data_sync;
	assign latch_data_go_low = (latching == 4'b0111);
	assign shreg_latch_data = !(latching == 4'b1111);
//	always @(posedge shiftclk) begin
//		if (sample_data_sync) latch_data <= 1;
//		else if (latching == 4'b0111) latch_data <= 0;
//	end
	reg latch_done = 0;
	always @(posedge shiftclk) begin
		latch_done <= (latching == 4'b0111);
	end
	wire latch_done_sync;
	flag_sync latch_done_flag_sync(.in_clkA(latch_done),.out_clkB(latch_done_sync),.clkA(shiftclk),.clkB(clk_i));

	reg [7:0] this_sample_data = {8{1'b0}};
	always @(posedge clk_i) begin
		if (latch_done_sync) this_sample_data <= irs_sample_mon_data[irs_sel];
	end
	
	reg data_latched = 0;
	always @(posedge clk_i) begin
		if (latch_done) data_latched <= 1;
		else if (do_sample) data_latched <= 0;
	end
	
	// Shift clock generation.
	wire shiftclk_fb;
	wire [7:0] dcm_status;
	wire psdone;
	reg psdone_seen = 0;
	reg psoverflow_seen = 0;
	reg psen = 0;
	reg psincdec;
	reg dcm_reset=0;
	wire dcm_locked;
	DCM_SP #(.CLKOUT_PHASE_SHIFT("VARIABLE"),.CLKIN_PERIOD("10.0")) shift_dcm(.CLKIN(clk_i),.CLKFB(shiftclk_fb),.CLK0(shiftclk_fb),.LOCKED(dcm_locked),.PSCLK(clk_i),.PSDONE(psdone),
						  .PSEN(psen),.PSINCDEC(psincdec),.RST(dcm_reset),.STATUS(dcm_status));
	BUFG shiftclk_bufg(.I(shiftclk_fb),.O(shiftclk));

	wire [7:0] pb_port;
	wire [7:0] pb_inport;
	wire [7:0] pb_outport;
	wire [9:0] pb_addr;
	wire [17:0] pb_instr;
	wire pb_read;
	wire pb_write;
	kcpsm3 processor(.instruction(pb_instr),.address(pb_addr),
						  .port_id(pb_port),.read_strobe(pb_read),.write_strobe(pb_write),
						  .in_port(pb_inport),.out_port(pb_outport),
						  .interrupt(1'b0),.reset(rst_i),.clk(clk_i));
	atri_samplemon_rom prom(.address(pb_addr),.instruction(pb_instr),.clk(clk_i));
	wire do_dcm_reset = (pb_write && (pb_port[1:0] == 2'b00) && !pb_port[7]);
	always @(posedge clk_i) begin
		if (do_dcm_reset && !pb_outport[0])
			dcm_reset <= 0;
		else if (do_dcm_reset && pb_outport[0])
			dcm_reset <= 1;
	end

	always @(posedge clk_i) begin
		psen <= (pb_write && (pb_port[1:0] == 2'b01) && !pb_port[7]);
	end
	always @(posedge clk_i) begin
		psincdec <= (pb_write && (pb_port[1:0] == 2'b01) && !pb_port[7]) && pb_outport[0];
	end
	always @(posedge clk_i) begin
		if (psen) begin
			psdone_seen <= 0;
			psoverflow_seen <= 0;
		end else begin
			if (psdone) psdone_seen <= 1;
			if (dcm_status[0]) psoverflow_seen <= 1;
		end
	end
	wire [7:0] pb_dcm_status = 
		{{2{1'b0}},data_latched,psdone_seen,dcm_locked,dcm_status[7],dcm_status[1],psoverflow_seen};
	

	wire [7:0] pb_registers[3:0];
	assign pb_registers[0] = pb_dcm_status;
	assign pb_registers[1] = 8'h00;
	assign pb_registers[2] = this_sample_data;
	assign pb_registers[3] = irs_sample_mon_en;
	assign pb_inport = pb_registers[pb_port[1:0]];

	wire do_sample = (pb_port[1:0] == 2'b10 && !pb_port[7] && pb_read);
	reg sample_wait = 0;
	always @(posedge clk_i) begin
		if (do_sample) sample_wait <= 1;
		else if (sync_i && sst_i) sample_wait <= 0;	
	end
	assign sample_data = (sample_wait && sync_i && sst_i);
	
	always @(posedge clk_i) begin
		if ((pb_port[1:0] == 2'b11) && pb_write && !pb_port[7])
			irs_sel <= pb_outport[1:0];
	end
	assign pb_output_value = pb_outport;
	assign latch_output_value = (pb_port[1:0] == 2'b10) && !pb_port[7];
	reg [7:0] debug = {8{1'b0}};
	always @(posedge clk_i) begin
		if (pb_port[7] && pb_write) debug <= pb_outport;
	end
	assign debug_o[0 +: 10] = pb_addr;
	assign debug_o[10 +: 8] = (pb_read) ? pb_inport : pb_outport;
	assign debug_o[18 +: 8] = debug;
	assign debug_o[26 +: 4] = dbg_tsaout_p;
	assign debug_o[30 +: 8] = this_sample_data;
	assign debug_o[38 +: 2] = irs_sel;
	assign debug_o[40] = psdone;
	assign debug_o[41] = dcm_reset;
	assign debug_o[42] = pb_dcm_status[0];
	assign debug_o[43 +: 4] = dbg_tsaout_n;
endmodule
