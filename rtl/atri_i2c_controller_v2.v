`timescale 1ns / 1ps

`include "i2c_interface.vh"
`include "irsi2c_interface.vh"

module atri_i2c_controller_v2(
		input clk_i,							//% System clock.
		input MHz_CE_i,						//% MHz clock enable input.
		input KHz_CE_i,						//% KHz clock enable input.
		input sda_i,							//% SDA: I2C data input
		output sda_o,							//% SDA: I2C data output
		output sda_oe,							//% SDA: I2C data output enable
		input scl_i,							//% SCL: I2C clock input
		output scl_o,							//% SCL: I2C clock output
		output scl_oe,							//% SCL: I2C clock output enable
		// ONLY FOR DDA_EVAL: here we only have one, so screw it
		inout regsda_io,						//% REGSDA: I2C data line for VCCAUX regulator
		inout regscl_io,						//% REGSCL: I2C clock line for VCCAUX regulator
		output vccaux_done_o,				//% Output to indicate VCCAUX is at 2.5V

		input rst_i,							//% Reset module.

		input pps_i,							//% 1 Hz

		input [7:0] db_status_i,				//% Daughterboard status.
		inout [`I2CIF_SIZE-1:0] i2c_interface,
		inout [`IRSI2CIF_SIZE-1:0] irsi2c_interface,
		
		output [47:0] debug_o
    );

	parameter VCCAUX_I2C = "NO";

	// I2C interface remap.
	wire	[7:0] dat_i; // fifo->i2c : i2c_interface[15:8]
	wire	[7:0] dat_o; // i2c->fifo : i2c_interface[7:0]
	wire	full_i;      // i2c_interface[16]
	wire	empty_i;		 // i2c_interface[17]
	wire	wr_o;        // i2c_interface[18]
	wire	rd_o;        // i2c_interface[19]
	wire	packet_o;    // i2c_interface[20]
	i2c_daughter i2c_io(.interface_io(i2c_interface),
							  .dat_o(dat_i),.dat_i(dat_o),
							  .full_o(full_i),.empty_o(empty_i),
							  .wr_i(wr_o),.rd_i(rd_o),.packet_i(packet_o));
	
	// IRSI2C interface remap.

	// INTERFACE_INS irsi2c irsi2c_i2c RPL interface_io irsi2c_interface
	wire irs_clk_i;
	wire i2c_clk_o;
	wire irs_init_i;
	wire [1:0] gpio_i;
	wire [1:0] gpio_ack_o;
	irsi2c_i2c irsi2cif(.interface_io(irsi2c_interface),
	                    .irs_clk_o(irs_clk_i),
	                    .i2c_clk_i(i2c_clk_o),
	                    .irs_init_o(irs_init_i),
	                    .gpio_o(gpio_i),
	                    .gpio_ack_i(gpio_ack_o));
	// INTERFACE_END
	
	assign i2c_clk_o = clk_i;

	/** @name PicoBlaze
	 * PicoBlaze processor, signals, and port map.
	 */
	//@{
	wire [9:0] pb_address;									//% PicoBlaze processor instruction address
	wire [17:0] pb_instruction;							//% PicoBlaze processor instruction
	wire [7:0] pb_port;										//% PicoBlaze processor port ID
	reg [7:0] pb_inport={8{1'b0}};						//% PicoBlaze processor input port data
	wire [7:0] pb_outport;									//% PicoBlaze processor output port data
	wire pb_wr_stb;											//% PicoBlaze write strobe
	wire pb_rd_stb;											//% PicoBlaze read strobe
	wire pb_interrupt;										//% PicoBlaze interrupt
	wire pb_interrupt_ack;									//% PicoBlaze interrupt acknowledge
	wire pb_reset;												//% PicoBlaze reset

	wire pb_wb_sel = (pb_port[7:3] == {5{1'b0}});			//% WISHBONE bus: ports 0x00-0x07
	wire pb_timer_sel = (pb_port[7:3] == 5'b00001);			//% Timer port: port 0x08 (shadowed to 0x0F)
	wire pb_status_sel = (pb_port[7:4] == 4'b0010);			//% Inputs : ports 0x20-0x2F
	wire pb_db_status_sel = pb_status_sel && (pb_port[2:0] == 3'b000);	//% DB status: port 0x20 
	wire pb_irs_status_sel = pb_status_sel && (pb_port[2:0] == 3'b001); //% IRS status: port 0x21
	wire pb_pps_status_sel = pb_status_sel && (pb_port[2:0] == 3'b010); //% PPS status: port 0x22
	wire pb_fifo_sel = (pb_port[7] == 1); 						//% FIFO: 0x80-0xFF
	wire pb_jumptable_sel = (pb_port[7:3] == 5'b00111);	//% Jumptable port: 0x38 (shadowed to 0x3F)
	wire pb_page_sel = (pb_port[7:4] == 4'b0001);   		//% Block/local RAM pages: ports 0x10-0x1F
	wire pb_lram_page_sel = pb_page_sel && !pb_port[0];	//% Local RAM page: port 0x10 (shadowed at 0x10,0x12.. 0x1E)
	wire pb_fifo_status_sel = pb_page_sel && pb_port[0];  //% FIFO control: port 0x11
	wire pb_lram_sel = (pb_port[7:5] == 3'b010); 			//% PicoBlaze local RAM: ports 0x40-0x5F

	kcpsm3 #(
				.INTERRUPT_VECTOR(10'h37E)
				)
				processor(.address(pb_address), .instruction(pb_instruction),
						  .port_id(pb_port),.read_strobe(pb_rd_stb),.write_strobe(pb_wr_stb),
						  .in_port(pb_inport),.out_port(pb_outport),.interrupt(pb_interrupt),
						  .interrupt_ack(pb_interrupt_ack),.reset(pb_reset),.clk(clk_i));
	

	//@}
		/** @name LRAM/PROM
	 * PicoBlaze program ROM (PROM) and local RAM (LRAM). Shared in one block RAM -
	 * the PicoBlaze only has an instruction space from 0x000-0x37F.
	 */
	//@{
	reg [2:0] lram_page = {3{1'b0}};								//% PicoBlaze LRAM page
	wire [7:0] lram_addr = {lram_page,pb_port[4:0]};		//% PicoBlaze LRAM address
	wire lram_wr_stb = pb_wr_stb && pb_lram_sel;				//% PicoBlaze LRAM write strobe
	wire lram_rd_stb = pb_rd_stb && pb_lram_sel;				//% PicoBlaze LRAM read strobe
	wire [7:0] lram_dat;												//% PicoBlaze LRAM data
	wire jumptable_wr_stb = pb_wr_stb && pb_jumptable_sel;//% PicoBlaze interrupt jump access

	atri_i2c_rom prom(.address(pb_address),
							 .instruction(pb_instruction),
							 .reset(pb_reset),.clk(clk_i),
							 .jump_wr_stb(jumptable_wr_stb),
							 .ram_address(lram_addr),.ram_data_out(lram_dat),
							 .ram_data_in(pb_outport),.ram_wr_stb(lram_wr_stb));
	//@}
	
	/** @name Timers
	 * Timers are to allow the PicoBlaze to keep track of time since a previous
	 * action to ensure that certain actions aren't repeated too quickly - namely,
	 * a write to the LCD on the Spartan 3A Starter Kit, an attempted read of the
	 * ADM1178 after a conversion, and an attempted read/write of the EEPROM after
	 * a write. They're all in one 8-bit port: a write to a bit starts the timer,
	 * and it is 1 after an appropriate number of "clock + clock enable" periods
	 * have occurred.
	 */
	//@{
	wire adm1178_timer_out;
	wire eeprom_timer_out;
	wire [7:0] timer_out = {{6{1'b0}},eeprom_timer_out,adm1178_timer_out};
	simple_timer #(.COUNT(301)) adm1178_timer(.CLK(clk_i),.CE(MHz_CE_i),
															.CLR(pb_timer_sel &&
																  pb_wr_stb && pb_outport[0]),
															.OUT(adm1178_timer_out));
	simple_timer #(.COUNT(4)) eeprom_timer(.CLK(clk_i),.CE(KHz_CE_i),
														.CLR(pb_timer_sel &&
															  pb_wr_stb && pb_outport[1]),
														.OUT(eeprom_timer_out));
	//@}

	/** @name OpenCores I2C Controller (WISHBONE)
	 * I2C Controller from www.opencores.org, slightly modified.
    * Communicates via WISHBONE bus. Controller was modified to respond to
	 * WISHBONE cycles immediately, without 1-cycle latency, to allow for
	 * direct interfacing.
	 * \n\n
	 * When pb_interrupt_ack occurs, an automatic WISHBONE cycle is generated
	 * to clear the interrupt.
	 */
	//@{
	// ONLY FOR DDA_EVAL
	reg vccaux_done = 0; 
	/** @brief VCCAUX done logic. */
	always @(posedge clk_i) begin : VCCAUX_DONE_LOGIC
		if (pb_db_status_sel && pb_wr_stb)
			vccaux_done <= pb_outport[2];
	end
	

	wire wb_cyc = (pb_wb_sel && (pb_wr_stb || pb_rd_stb)) || pb_interrupt_ack; //% WISHBONE cycle 
	wire wb_stb = wb_cyc;																		//% WISHBONE strobe
	wire wb_ack;																					//% WISHBONE acknowledge
	wire [7:0] wb_dat_to_i2c = pb_interrupt_ack ? 8'h01 : pb_outport;				//% PicoBlaze -> WISHBONE
	wire [7:0] wb_dat_from_i2c;																//% WISHBONE -> PicoBlaze
	wire wb_we = (pb_wb_sel && pb_wr_stb) || pb_interrupt_ack;						//% WISHBONE write
	wire [2:0] wb_adr = pb_interrupt_ack ? 3'b100 : pb_port[2:0];					//% WISHBONE address
	wire wb_interrupt;																			//% WISHBONE interrupt
	assign pb_interrupt = wb_interrupt;
	
	wire [4:0] i2c_debug;									//% For debugging I2C byte controller state
	wire scl_in, scl_out, scl_output_enable;			//% SCL input/output and output enable
	wire sda_in, sda_out, sda_output_enable;			//% SDA input/output and output enable
	i2c_master_top #(.WB_LATENCY(0)) 
		i2c_controller(.wb_clk_i(clk_i), .wb_rst_i(rst_i), .arst_i(1'b1),
							.wb_adr_i(wb_adr), .wb_dat_i(wb_dat_to_i2c), .wb_dat_o(wb_dat_from_i2c),
							.wb_we_i(wb_we), .wb_stb_i(wb_stb), .wb_cyc_i(wb_cyc), .wb_ack_o(wb_ack),
							.wb_inta_o(wb_interrupt),
							.scl_pad_i(scl_in), .scl_pad_o(scl_out), .scl_padoen_o(scl_output_enable),
							.sda_pad_i(sda_in), .sda_pad_o(sda_out), .sda_padoen_o(sda_output_enable),
							.debug_o(i2c_debug));
	//
	// ONLY FOR DDA_EVAL TO REMAP VCCAUX TO 2.5V
	// 
	generate
		if (VCCAUX_I2C == "YES") begin : DDAEVAL
			// scl_output_enable/sda_output_enable are negative logic.
			// vccaux_done is positive logic.
			// !(!A && !B) is A or B.
			wire reg_i2c_scl_oe = scl_output_enable || vccaux_done;
			wire reg_i2c_sda_oe = sda_output_enable || vccaux_done;
			assign regsda_io = reg_i2c_sda_oe ? 1'bZ : sda_out;
			assign regscl_io = reg_i2c_scl_oe ? 1'bZ : scl_out;
			// scl_output_enable/sda_output_enable are negative logic.
			// vccaux_done is positive logic.
			// !(!A && B) is A or !B.
			assign scl_oe = scl_output_enable || !vccaux_done;
			assign sda_oe = sda_output_enable || !vccaux_done;
			assign scl_o = scl_out;
			assign sda_o = sda_out;
			assign scl_in = (vccaux_done) ? scl_i : regscl_io;
			assign sda_in = (vccaux_done) ? sda_i : regsda_io;
		end else begin : ATRI
			assign scl_oe = scl_output_enable;
			assign sda_oe = sda_output_enable;
			assign scl_o = scl_out;
			assign sda_o = sda_out;
			assign scl_in = scl_i;
			assign sda_in = sda_i;
		end
	endgenerate
	//@}

	/** @name IRS requests to I2C controller.
	 */
	//@{
	reg [7:0] irs_request_register = {8{1'b0}};
	wire [7:0] irs_requests;
	flag_sync wilk_start_sync(.clkA(irs_clk_i),.clkB(clk_i),.in_clkA(gpio_i[0]),.out_clkB(irs_requests[0]));
	flag_sync wilk_clear_sync(.clkA(irs_clk_i),.clkB(clk_i),.in_clkA(gpio_i[1]),.out_clkB(irs_requests[1]));
	flag_sync irs_init_sync(.clkA(irs_clk_i),.clkB(clk_i),.in_clkA(irs_init_i),.out_clkB(irs_requests[2]));
	integer ii;
	always @(posedge clk_i) begin
		for (ii=0;ii<8;ii=ii+1) begin
			if (irs_requests[ii])
				irs_request_register[ii] <= 1;
			else if (pb_irs_status_sel && pb_rd_stb)
				irs_request_register[ii] <= 0;
		end
	end
	assign gpio_ack_o[0] = (pb_irs_status_sel && pb_rd_stb && irs_request_register[0]);
	assign gpio_ack_o[1] = (pb_irs_status_sel && pb_rd_stb && irs_request_register[1]);
	
	wire [7:0] fifo_status = {{6{1'b0}},full_i,empty_i};

	always @(*) begin : PB_INPORT_MUX
		if (pb_fifo_sel)
			pb_inport <= dat_i;
		else if (pb_lram_sel)
			pb_inport <= lram_dat;
		else if (pb_db_status_sel)
			pb_inport <= db_status_i;
		else if (pb_irs_status_sel)
			pb_inport <= irs_request_register;
		else if (pb_fifo_status_sel)
			pb_inport <= fifo_status;
		else if (pb_lram_page_sel)
			pb_inport <= {lram_page,5'b00000};
		else if (pb_timer_sel)
			pb_inport <= timer_out;
		else
			pb_inport <= wb_dat_from_i2c;
	end
	
	/** @brief LRAM page logic. Top 3 bits of output byte are stored as LRAM page. */
	always @(posedge clk_i) begin : LRAM_PAGE_LOGIC
		if (pb_lram_page_sel && pb_wr_stb)
			lram_page <= pb_outport[7:5];
	end


	assign vccaux_done_o = vccaux_done;
	assign dat_o = pb_outport;
	assign wr_o = (pb_fifo_sel && pb_wr_stb);
	assign rd_o = (pb_fifo_sel && pb_rd_stb);
	assign packet_o = (pb_fifo_status_sel && pb_outport[4] && pb_wr_stb);
	
	assign debug_o[7:0] = pb_inport;
	assign debug_o[15:8] = pb_outport;
	assign debug_o[23:16] = pb_port;
	assign debug_o[24] = pb_wr_stb;
	assign debug_o[25] = pb_rd_stb;
	assign debug_o[26] = pb_interrupt;
	assign debug_o[27] = pb_interrupt_ack;
	assign debug_o[37:28] = pb_address;
	assign debug_o[38] = full_i;
	assign debug_o[39] = empty_i;
	assign debug_o[40] = scl_in;
	assign debug_o[41] = sda_in;
	assign debug_o[42] = scl_output_enable;
	assign debug_o[43] = sda_output_enable;
	assign debug_o[47:44] = {4{1'b0}};

endmodule
