`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Buffers data for the event header. The address from each stack should be
// incremented on each rising edge of trigger_processed (or at each e frame).
//////////////////////////////////////////////////////////////////////////////////
module event_data_buffer #(
		parameter RAMB_TYPE = "RAMB16",
		parameter ADDR_WIDTH = (RAMB_TYPE == "DRAM") ? 4 : ((RAMB_TYPE == "RAMB8") ? 8 : 9),
		parameter MAX_DAUGHTERS = 4,
		parameter NUM_DAUGHTERS = 4
	)
    (
		output [15:0] event_pps_count_o,
		output [31:0] event_cycle_count_o,
		output [15:0] event_id_o,
		input [ADDR_WIDTH-1:0] d1_addr_i,
		input [ADDR_WIDTH-1:0] d2_addr_i,
		input [ADDR_WIDTH-1:0] d3_addr_i,
		input [ADDR_WIDTH-1:0] d4_addr_i,
		output [NUM_DAUGHTERS-1:0] d_sel_o,
		
		input clk_i,
		input rst_i,
		input [31:0] cycle_count_i,
		input [15:0] pps_count_i,
		input event_flag_i,
		input [8:0] event_delay_i
    );

	reg [31:0] cycle_count_latch = {32{1'b0}};	
	reg [8:0] event_delay_latch = {9{1'b0}};	
	reg [15:0] pps_count_latch = {16{1'b0}};

	always @(posedge clk_i) begin
		if (event_flag_i) begin
			cycle_count_latch <= cycle_count_i;
			pps_count_latch <= pps_count_i;
			event_delay_latch <= event_delay_i;
		end
	end	

	reg store_and_increment = 0;
	always @(posedge clk_i) begin
		store_and_increment <= event_flag_i;
	end
	
	reg [15:0] event_id = {16{1'b0}};
	always @(posedge clk_i) begin
		if (rst_i)
			event_id <= {16{1'b0}};
		else if (store_and_increment)
			event_id <= event_id + 1;
	end
	
	reg [NUM_DAUGHTERS-1:0] daughter_select;
	reg [NUM_DAUGHTERS-1:0] daughter_select_delayed = {NUM_DAUGHTERS{1'b0}};

	wire [ADDR_WIDTH-1:0] addr_in[MAX_DAUGHTERS-1:0];
	assign addr_in[0] = d1_addr_i;
	assign addr_in[1] = d2_addr_i;
	assign addr_in[2] = d3_addr_i;
	assign addr_in[3] = d4_addr_i;

	wire [ADDR_WIDTH-1:0] addr_in_mux;
	wire [NUM_DAUGHTERS-1:0] daughter_select_any;
	generate
		genvar i;
		// This is all fairly silly, since daughter_select just loops around.
		// For a single daughter this should just optimize completely away.
		// For multiple daughters this should basically optimize to a NUM_DAUGHTERS-to-1 mux
		// with daughter_select doing the selecting.
		// Should make daughter_select a counter rather than a shift register.
		for (i=0;i<NUM_DAUGHTERS;i=i+1) begin : LOOP
			if (i == 0) begin : HEAD
				initial daughter_select[i] <= 1;
				always @(posedge clk_i) daughter_select[i] <= daughter_select[NUM_DAUGHTERS-1];
				assign addr_in_mux = (daughter_select[i] || daughter_select == {NUM_DAUGHTERS{1'b0}}) ? addr_in[i] : {ADDR_WIDTH{1'bZ}};
				assign daughter_select_any[i] = daughter_select[i];
			end else begin : TAIL
				initial daughter_select[i] <= 0;
				always @(posedge clk_i) daughter_select[i] <= daughter_select[i-1];
				assign addr_in_mux = (daughter_select[i] && !daughter_select_any[i-1]) ? addr_in[i] : {ADDR_WIDTH{1'bZ}};
				assign daughter_select_any[i] = daughter_select[i] || daughter_select_any[i-1];				
			end
		end
	endgenerate
	always @(posedge clk_i) begin 
		daughter_select_delayed <= daughter_select;
	end
	
	assign d_sel_o = daughter_select_delayed;

	reg [ADDR_WIDTH-1:0] event_addr_counter = {ADDR_WIDTH{1'b0}};

	wire [31:0] id_and_pps_in = {event_id, pps_count_latch};
	wire [31:0] id_and_pps_out;

	wire [31:0] cycle_count_output;

	always @(posedge clk_i) begin
		if (rst_i)
			event_addr_counter <= {ADDR_WIDTH{1'b0}};
		else if (store_and_increment)
			event_addr_counter <= event_addr_counter + 1;
	end
		
	// Avoid collisions.
	wire enb = !((addr_in_mux == event_addr_counter) && store_and_increment);
	
	generate
		if (RAMB_TYPE == "RAMB16") begin : RAMB16_TYPE
			RAMB16BWER #(.DATA_WIDTH_A(36),.DATA_WIDTH_B(36)) time_tag_buffer(
					.CLKA(clk_i),
					.ADDRA({event_addr_counter,{5{1'b0}}}),
					.ENA(store_and_increment),
					.WEA({4{store_and_increment}}),
					.DIA(cycle_count_latch),
					.DIPA(4'b0000),

					.CLKB(clk_i),
					.ADDRB({addr_in_mux,{5{1'b0}}}),
					.DIB({32{1'b0}}),
					.DIPB({4{1'b0}}),
					.ENB(enb),
					.WEB({4{1'b0}}),
					.DOB(cycle_count_output),
					
					.REGCEA(1'b0),
					.REGCEB(1'b0),
					.RSTA(1'b0),
					.RSTB(1'b0)
			);
			RAMB16BWER #(.DATA_WIDTH_A(36),.DATA_WIDTH_B(36)) id_and_pps_buffer(
					.CLKA(clk_i),
					.ADDRA({event_addr_counter,{5{1'b0}}}),
					.ENA(store_and_increment),
					.WEA({4{store_and_increment}}),
					.DIA(id_and_pps_in),
					.DIPA(4'b0000),

					.CLKB(clk_i),
					.ADDRB({addr_in_mux,{5{1'b0}}}),
					.DIB({32{1'b0}}),
					.DIPB({4{1'b0}}),
					.ENB(enb),
					.WEB({4{1'b0}}),
					.DOB(id_and_pps_out),
					
					.REGCEA(1'b0),
					.REGCEB(1'b0),
					.RSTA(1'b0),
					.RSTB(1'b0)
			);
		end else if (RAMB_TYPE == "DRAM") begin : DRAM_TYPE
		// We need 2 32-bit buffers. We're going to build them out of distributed RAM,
		// and we'll make them 16 deep. Eventually we should add a full output to
		// hold off the trigger when the event buffers are full, but in the ATRI based
		// firmware this never happens.

		// This is 64 total slices. Geh.
			genvar ri;
			for (ri=0;ri<32;ri=ri+1) begin : DRAM_LOOP
				RAM16X1D #(.INIT(16'h0000)) 
					cycle_count_bit(.WCLK(clk_i),.WE(store_and_increment),.D(cycle_count_latch[ri]),
								.A0(event_addr_counter[0]),.A1(event_addr_counter[1]),
								.A2(event_addr_counter[2]),.A3(event_addr_counter[2]),
								.DPRA0(addr_in_mux[0]),.DPRA1(addr_in_mux[1]),
								.DPRA2(addr_in_mux[2]),.DPRA3(addr_in_mux[3]),
								.DPO(cycle_count_output[ri]));
				RAM16X1D #(.INIT(16'h0000))
					id_pps_bit(.WCLK(clk_i),.WE(store_and_increment),.D(id_and_pps_in[ri]),
								.A0(event_addr_counter[0]),.A1(event_addr_counter[1]),
								.A2(event_addr_counter[2]),.A3(event_addr_counter[2]),
								.DPRA0(addr_in_mux[0]),.DPRA1(addr_in_mux[1]),
								.DPRA2(addr_in_mux[2]),.DPRA3(addr_in_mux[3]),
								.DPO(id_and_pps_out[ri]));
			end
		end else if (RAMB_TYPE == "RAMB8") begin : RAMB8_TYPE 
			RAMB8BWER #(.RAM_MODE("SDP"),.DATA_WIDTH_A(36),.DATA_WIDTH_B(36)) time_tag_buffer(
					.CLKAWRCLK(clk_i),
					.ADDRAWRADDR({event_addr_counter,{5{1'b0}}}),
					.ENAWREN(store_and_increment),
					.WEAWEL({2{store_and_increment}}),
					.WEBWEU({2{store_and_increment}}),
					.DIADI(cycle_count_latch),
					.DIPADIP(4'b0000),

					.CLKBRDCLK(clk_i),
					.ADDRBRDADDR({addr_in_mux,{5{1'b0}}}),
					.DIBDI({32{1'b0}}),
					.DIPBDIP({4{1'b0}}),
					.ENBRDEN(1'b1),
					.DOBDO(cycle_count_output)
			);
			RAMB8BWER #(.RAM_MODE("SDP"),.DATA_WIDTH_A(36),.DATA_WIDTH_B(36)) id_and_pps_buffer(
					.CLKAWRCLK(clk_i),
					.ADDRAWRADDR({event_addr_counter,{5{1'b0}}}),
					.ENAWREN(store_and_increment),
					.WEAWEL({2{store_and_increment}}),
					.WEBWEU({2{store_and_increment}}),
					.DIADI(id_and_pps_in),
					.DIPADIP(4'b0000),

					.CLKBRDCLK(clk_i),
					.ADDRBRDADDR({addr_in_mux,{5{1'b0}}}),
					.DIBDI({32{1'b0}}),
					.DIPBDIP({4{1'b0}}),
					.ENBRDEN(1'b1),
					.DOBDO(id_and_pps_out)
			);
		end
	endgenerate
	
	
	// Event ID output
	assign event_id_o = id_and_pps_out[31:16];

	// PPS count output
	assign event_pps_count_o = id_and_pps_out[15:0];

	// Cycle counter output
	assign event_cycle_count_o = cycle_count_output;
			
endmodule
