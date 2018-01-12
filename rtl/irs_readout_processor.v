`timescale 1ns / 1ps
`include "trigger_defs.vh"
module irs_readout_processor(
		// Block interface
		block_dat_i,
		block_empty_i,
		block_rd_o,
		// Trigger info interface
		trig_info_i,
		trig_info_addr_o,
		trig_info_rd_o,
		// Event FIFO interface
		event_dat_o,
		event_cnt_i,
		event_wr_o,
		// DMA interface
		dma_addr_o,
		dma_dat_o,
		dma_dat_i,
		dma_wr_o,
		dma_done_i,
		// Free interface
		free_block_o, 
		free_req_o,
		free_ack_i,


		// IRS control interface
		irs_addr_o,
		irs_mask_i,
		irs_mask_o,
		irs_rdy_i,
		irs_active_i,
		irs_wr_o,
		irs_go_o,

		readout_ready_o,
		readout_err_o,
		// Delay from first trigger to readout.
		readout_delay_i,
		
		clk_i,
		rst_i,
		debug_o
    );

	localparam NUM_L4 = `SCAL_NUM_L4;
	`include "clogb2.vh"
	localparam NL4_BITS = clogb2(NUM_L4-1);
	localparam MAX_DAUGHTERS = 4;
	localparam NMXD_BITS = clogb2(MAX_DAUGHTERS-1);

	input [71:0] block_dat_i;
	input block_empty_i;
	output block_rd_o;
	
	input [31:0] trig_info_i;
	output [NL4_BITS-1:0] trig_info_addr_o;
	output trig_info_rd_o;
	
	output [15:0] event_dat_o;
	input [15:0] event_cnt_i;
	output event_wr_o;
	
	output [2:0] dma_addr_o;
	output [7:0] dma_dat_o;
	input [7:0] dma_dat_i;
	output dma_wr_o;
	input dma_done_i;
	
	output [8:0] free_block_o;
	output free_req_o;
	input free_ack_i;
	
	output [NMXD_BITS-1:0] irs_addr_o;
	input [7:0] irs_mask_i;
	output [7:0] irs_mask_o;
	input [MAX_DAUGHTERS-1:0] irs_rdy_i;
	input [MAX_DAUGHTERS-1:0] irs_active_i;
	output irs_wr_o;
	output [MAX_DAUGHTERS-1:0] irs_go_o;

	output readout_ready_o;

	output [7:0] readout_err_o;
	
	input [7:0] readout_delay_i;
	
	input clk_i;
	input rst_i;
	output [17:0] debug_o;
	
	reg [7:0] readout_err = {8{1'b0}};
	
	
	// PicoBlaze interface:
	// 
	// Block output from the buffer goes directly to the readout: the PicoBlaze can't alter that,
	// but it can alter the mask based on the L4 reg if it needs to.

	//% PicoBlaze output data.
	wire [7:0] pb_data_out;
	//% PicoBlaze input data.
	reg [7:0] pb_data_in = {8{1'b0}};
	//% PicoBlaze port address.
	wire [7:0] pb_port;

	//% Trigger data, in 8 bit chunks.
	wire [7:0] pb_trigdata[15:0];
	generate
		genvar tdi;
		for (tdi=0;tdi<9;tdi=tdi+1) begin : TDV
			assign pb_trigdata[tdi] = block_dat_i[tdi*8 +: 8];
			if (tdi>1 && tdi<8) begin : SHDW
				assign pb_trigdata[tdi+8] = block_dat_i[tdi*8 +: 8];
			end
		end
	endgenerate
	
	//% Event FIFO count. Registered here to give propagation time.
	reg [15:0] event_count_local = {16{1'b0}};

	always @(posedge clk_i) begin
		event_count_local <= event_cnt_i;
	end

	//% Trigger data status.
	wire [7:0] pb_bfifo_status = {{6{1'b0}},block_empty_i};
	assign pb_trigdata[9] = pb_bfifo_status;
	//% PicoBlaze IRS ready
	wire [7:0] pb_irsready = irs_rdy_i;
	//% PicoBlaze IRS active
	wire [7:0] pb_irsactive = irs_active_i;
	//% PicoBlaze FIFO count.
	wire [7:0] pb_fifo_cnt[1:0];
	assign pb_fifo_cnt[0] = event_count_local[7:0];
	assign pb_fifo_cnt[1] = event_count_local[15:8];
	//% Trigger info control/status register.
	wire [7:0] pb_tinfo_csr;
	//% Trigger info data.
	wire [7:0] pb_tinfo[3:0];
	assign pb_tinfo[0] = trig_info_i[0 +: 8];
	assign pb_tinfo[1] = trig_info_i[8 +: 8];
	assign pb_tinfo[2] = trig_info_i[16 +: 8];
	assign pb_tinfo[3] = trig_info_i[24 +: 8];
	//% Mask of L4 triggers. Here to keep PicoBlaze code generic.
	wire [7:0] pb_l4mask = {{8-NUM_L4{1'b0}},{NUM_L4{1'b1}}};

	//////////////////////////////////////////////////////
	// PICOBLAZE PORT MAP
	//////////////////////////////////////////////////////

	// All ports get 16 addresses.
	// 0x00-0x0F: Trigger data
	// 0x10-0x1F: Mask registers
	// 0x20-0x2F: DMA registers
	// 0x30-0x3F: Free block interface
	// 0x40-0x4F: IRS registers (active/ready/go) and L4 mask
	// 0x50-0x5F: FIFO count registers
	// 0x60-0x6F: Trigger info registers
	// 0x70-0x7F: (Trigger info registers, shadow)
	// 0x80-0xFF: Output data
	`define PICOBLAZE_PORT_MAP( sel_name , addr , descr , rangecheck) \
		localparam [7:0] sel_name``address = addr;                     \
		wire sel_name = ( pb_port rangecheck == sel_name``address rangecheck)
		
	`PICOBLAZE_PORT_MAP( pb_sel_trigdata , 8'h00 , "Trigger block buffer data", [7:4] );
	`PICOBLAZE_PORT_MAP( pb_sel_mask ,     8'h10 , "IRS mask registers", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_dma ,      8'h20 , "DMA registers", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_free , 		8'h30 , "Free block interface", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_irs ,      8'h40 , "IRS control/status registers", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_fifocnt ,  8'h50 , "Event FIFO count registers", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_tinfo ,    8'h60 , "Trigger info registers", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_params ,   8'h70 , "Readout parameters", [7:4]);
	`PICOBLAZE_PORT_MAP( pb_sel_outdata ,  8'h80 , "Output data", [7] );	
	`undef PICOBLAZE_PORT_MAP

	wire [9:0] pb_addr;
	wire [17:0] pb_instr;
	wire pb_interrupt_ack;
	wire pb_interrupt;
	kcpsm3 processor(.instruction(pb_instr),.address(pb_addr),
						  .port_id(pb_port),
						  .read_strobe(pb_read),
						  .write_strobe(pb_write),
						  .in_port(pb_data_in),
						  .out_port(pb_data_out),
						  .interrupt(pb_interrupt),
						  .interrupt_ack(pb_interrupt_ack),
						  .reset(rst_i),
						  .clk(clk_i));
	atri_readout_rom prom(.address(pb_addr),.instruction(pb_instr),.clk(clk_i));
	
	reg [7:0] readout_delay = {8{1'b0}};
	always @(posedge clk_i) begin
		readout_delay <= readout_delay_i;
	end
	
	reg dma_complete_seen = 0;
	always @(posedge clk_i) begin
		if (rst_i || pb_interrupt_ack) dma_complete_seen <= 0;
		else if (dma_done_i) dma_complete_seen <= 1;
	end
	assign pb_interrupt = dma_complete_seen;
	
	//% Data in multiplex.
	always @(posedge clk_i) begin : PB_DATA_IN_LOGIC
		if (pb_sel_trigdata)
			pb_data_in <= pb_trigdata[pb_port[3:0]];
		else if (pb_sel_dma)
			pb_data_in <= dma_dat_i;
		else if (pb_sel_mask)
			pb_data_in <= irs_mask_i;
		else if (pb_sel_irs) begin
			if      (pb_port[1:0] == 2'b00) pb_data_in <= irs_rdy_i;
			else if (pb_port[1:0] == 2'b01) pb_data_in <= irs_go_o;
			else if (pb_port[1:0] == 2'b10) pb_data_in <= irs_active_i;
			else if (pb_port[1:0] == 2'b11) pb_data_in <= pb_l4mask;
		end else if (pb_sel_tinfo) begin
			if (!pb_port[2]) pb_data_in <= pb_tinfo_csr;
			else pb_data_in <= pb_tinfo[pb_port[1:0]];
		end else if (pb_sel_params) begin
			// The only parameter currently is the readout delay.
			pb_data_in <= readout_delay;
		end else if (pb_sel_fifocnt) begin
			if (!pb_port[0]) pb_data_in <= event_cnt_i[7:0];
			else pb_data_in <= event_cnt_i[15:8];
		end
	end
	
	//% Register for the trigger info address.
	reg [NL4_BITS-1:0] tinfo_addr = {NL4_BITS{1'b0}};
	assign pb_tinfo_csr = {{8-NL4_BITS{1'b0}},tinfo_addr};
	//% Trigger info address logic. Just a PicoBlaze output register.
	always @(posedge clk_i) begin : TINFO_ADDR_LOGIC
		if (pb_sel_tinfo && !pb_port[2] && pb_write)
			tinfo_addr <= pb_data_out[NL4_BITS-1:0];
	end
	//% Register to increment the trigger info.
	reg tinfo_rd = 0;
	//% Trigger info increment logic.
	always @(posedge clk_i) begin : TINFO_RD_LOGIC
		if (pb_sel_tinfo && (pb_port[2:0] == 3'b111) && pb_read)
			tinfo_rd <= 1;
		else
			tinfo_rd <= 0;
	end

	
	//% Register to hold output data.
	reg [15:0] event_data = {16{1'b0}};
	reg event_wr = 0;
	always @(posedge clk_i) begin : EVENT_DATA_LOGIC
		if (pb_sel_outdata && pb_write) begin
			if (!pb_port[0]) begin
				event_data[7:0] <= pb_data_out;
				event_wr <= 0;
			end else begin
				event_data[15:8] <= pb_data_out;
				event_wr <= 1;
			end
		end else begin
			event_wr <= 0;
		end
	end

	//% Register to signal to an IRS to begin readout.
	reg [MAX_DAUGHTERS-1:0] irs_go = {MAX_DAUGHTERS{1'b0}};
	always @(posedge clk_i) begin : IRS_GO_LOGIC
		if (pb_sel_irs && (pb_port[1:0] == 2'b01) && pb_write)
			irs_go <= irs_active_i;
		else
			irs_go <= {MAX_DAUGHTERS{1'b0}};
	end
	
	//% Indicate that readout is not ready.
	reg readout_not_ready = 0;
	always @(posedge clk_i) begin : READY_LOGIC
		if (rst_i)
			readout_not_ready <= 0;
		else if (pb_sel_irs && (pb_port[1:0] == 2'b11) && pb_write)
			readout_not_ready <= |(pb_data_out[7:5]);
	end
	assign readout_ready_o = !readout_not_ready;
	
	//% Register to hold free block address
	reg [8:0] free_block_addr = {9{1'b0}};
	//% Free strobe.
	reg free_strobe = 0;
	always @(posedge clk_i) begin : FREE_BLOCK_LOGIC
		if (pb_sel_free && pb_write) begin
			if (!pb_port[0]) free_block_addr[7:0] <= pb_data_out;
			else begin
				free_block_addr[8] <= pb_data_out[0];
				free_strobe <= 1;
			end
		end else begin
			free_strobe <= 0;
		end
	end
	//% Issue a read request. This can be registered since we've got 2 cycles after pb_write.
	reg block_read = 0;
	always @(posedge clk_i) begin : BLOCK_RD_LOGIC
		block_read <= (pb_sel_trigdata && pb_write);
	end

	//% DMA data output. Latched due to timing constraints.
	reg [7:0] dma_dat = {8{1'b0}};
	//% DMA write strobe.
	reg dma_wr = 0;
	//% DMA address.
	reg [2:0] dma_addr = {3{1'b0}};
	always @(posedge clk_i) begin : DMA_DAT_LOGIC
		if (pb_sel_dma && pb_write) begin
			dma_dat <= pb_data_out;
			dma_wr <= 1;
			dma_addr <= pb_port[2:0];
		end else begin
			dma_wr <= 0;
		end
	end

	//% Error latch. 0x82 is the err output (also goes to event path)
	always @(posedge clk_i) begin : ERR_LOGIC
		if (rst_i)
			readout_err <= {8{1'b0}};
		else if (pb_sel_outdata && pb_port[1] && pb_write)
			readout_err <= pb_data_out;
	end
	assign readout_err_o = readout_err;
	
	assign irs_go_o = irs_go;
	assign block_rd_o = block_read;

	assign trig_info_addr_o = tinfo_addr;
	assign trig_info_rd_o = tinfo_rd; 

	assign event_dat_o = event_data;
	assign event_wr_o = event_wr;

	assign dma_dat_o = dma_dat;
	assign dma_addr_o = dma_addr;
	assign dma_wr_o = dma_wr;

	assign free_block_o = free_block_addr;
	assign free_req_o = free_strobe;

	assign irs_addr_o = pb_port[1:0];
	assign irs_mask_o = pb_data_out;
	assign irs_wr_o = (pb_sel_mask && pb_write);

	reg [9:0] pb_addr_delayed = {10{1'b0}};
	always @(posedge clk_i) begin
		pb_addr_delayed <= pb_addr;
	end
	reg [7:0] pb_port_mux = {8{1'b0}};
	always @(posedge clk_i) begin
		if (pb_write) pb_port_mux <= pb_data_out;
		else if (pb_read) pb_port_mux <= pb_data_in;
	end
	assign debug_o[9:0] = pb_addr_delayed;
	assign debug_o[17:10] = pb_port_mux;
endmodule
