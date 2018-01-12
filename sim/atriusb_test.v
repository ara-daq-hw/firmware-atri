`timescale 1ns / 1ps

module atriusb_test;
	parameter PINPOL = "NEGATIVE";
	parameter [1:0] CONTROL_IN_FIFO = 2'b00;
	parameter [1:0] CONTROL_OUT_FIFO = 2'b01;
	parameter [1:0] EVENT_OUT_FIFO = 2'b10;
	reg FPTRIG_IN = 0;
	reg PPS_IN = 0;
	// Daughter 1
	// Inputs
	wire [11:0] D1DAT;
	wire D1TSAOUT;
	wire D1TSTOUT;
	reg [7:0] D1TRG;
	wire [7:0] D1TRG_P = D1TRG;
	wire [7:0] D1TRG_N = ~D1TRG;

	// Outputs
	wire [9:0] D1WR;
	wire D1WRSTRB;
	wire [9:0] D1RD;
	wire D1RDEN;
	wire [5:0] D1SMP;
	wire D1SMPALL;
	wire [2:0] D1CH;
	wire D1TSA;
	wire D1TSA_CLOSE;
	wire D1RAMP;
	wire D1START;
	wire D1CLR;

	// Bidirs
	wire D1DDASENSE;
	wire D1TDASENSE;
	wire D1SDA;
	wire D1SCL;
	wire [10:9] D1DRSV;
	
	// Daughter 2
	// Inputs
	wire [11:0] D2DAT;
	wire D2TSAOUT;
	wire D2TSTOUT;
	reg [7:0] D2TRG;
	wire [7:0] D2TRG_P = D2TRG;
	wire [7:0] D2TRG_N = ~D2TRG;

	// Outputs
	wire [9:0] D2WR;
	wire D2WRSTRB;
	wire [9:0] D2RD;
	wire D2RDEN;
	wire [5:0] D2SMP;
	wire D2SMPALL;
	wire [2:0] D2CH;
	wire D2TSA;
	wire D2TSA_CLOSE;
	wire D2RAMP;
	wire D2START;
	wire D2CLR;

	// Bidirs
	wire D2DDASENSE;
	wire D2TDASENSE;
	wire D2SDA;
	wire D2SCL;
	wire [10:9] D2DRSV;


	// Daughter 3
	// Inputs
	wire [11:0] D3DAT;
	wire D3TSAOUT;
	wire D3TSTOUT;
	reg [7:0] D3TRG;
	wire [7:0] D3TRG_P = D3TRG;
	wire [7:0] D3TRG_N = ~D3TRG;

	// Outputs
	wire [9:0] D3WR;
	wire D3WRSTRB;
	wire [9:0] D3RD;
	wire D3RDEN;
	wire [5:0] D3SMP;
	wire D3SMPALL;
	wire [2:0] D3CH;
	wire D3TSA;
	wire D3TSA_CLOSE;
	wire D3RAMP;
	wire D3START;
	wire D3CLR;

	// Bidirs
	wire D3DDASENSE;
	wire D3TDASENSE;
	wire D3SDA;
	wire D3SCL;
	wire [10:9] D3DRSV;

	// Daughter 4
	// Inputs
	wire [11:0] D4DAT;
	wire D4TSAOUT;
	wire D4TSTOUT;
	reg [7:0] D4TRG;
	wire [7:0] D4TRG_P = D4TRG;
	wire [7:0] D4TRG_N = ~D4TRG;

	// Outputs
	wire [9:0] D4WR;
	wire D4WRSTRB;
	wire [9:0] D4RD;
	wire D4RDEN;
	wire [5:0] D4SMP;
	wire D4SMPALL;
	wire [2:0] D4CH;
	wire D4TSA;
	wire D4TSA_CLOSE;
	wire D4RAMP;
	wire D4START;
	wire D4CLR;

	// Bidirs
	wire D4DDASENSE;
	wire D4TDASENSE;
	wire D4SDA;
	wire D4SCL;
	wire [10:9] D4DRSV;

	// USB interface
	reg ctrl_in_empty = 1;
	reg ctrl_out_full = 0;
	wire event_out_full;
	reg phy_reset = 0;
	wire FLAGA;
	wire FLAGB;
	wire FLAGC;
	wire FLAGD = phy_reset;
	generate
		if (PINPOL == "POSITIVE") begin : FLAGPOS
			assign FLAGA = ctrl_in_empty;
			assign FLAGB = ctrl_out_full;
			assign FLAGC = event_out_full;
		end else begin : FLAGNEG
			assign FLAGA = ~ctrl_in_empty;
			assign FLAGB = ~ctrl_out_full;
			assign FLAGC = ~event_out_full;
		end
	endgenerate
	
	
	wire SLOE, SLWR, SLRD, PKTEND;
	reg [7:0] FD_O = {8{1'b0}};
	wire [7:0] FD = (SLOE) ? 8'hZZ : FD_O;
	wire [1:0] FIFOADR;

	reg [7:0] pktno = 8'h01;
	
	//% PHY clock.
	reg IFCLK = 0;

	//% IRS clock.
	reg REFCLK = 0;
	wire FPGA_REFCLK_P = REFCLK;
	wire FPGA_REFCLK_N = ~REFCLK;
	
	// Daughter presence.
	reg [3:0] D1DBPRESENT = {4{1'b0}};
	reg [3:0] D2DBPRESENT = {4{1'b0}};
	reg [3:0] D3DBPRESENT = {4{1'b0}};
	reg [3:0] D4DBPRESENT = {4{1'b0}};
	
	// Models.
	buf (weak1, weak0) pu1dda(D1DDASENSE, 1);
	buf (weak1, weak0) pu1tda(D1TDASENSE, 1);
	buf (weak1, weak0) pu1drsv9(D1DRSV[9], 1);
	buf (weak1, weak0) pu1drsv10(D1DRSV[10], 1);

	buf (weak1, weak0) pu2dda(D2DDASENSE, 1);
	buf (weak1, weak0) pu2tda(D2TDASENSE, 1);
	buf (weak1, weak0) pu2drsv9(D2DRSV[9], 1);
	buf (weak1, weak0) pu2drsv10(D2DRSV[10], 1);

	buf (weak1, weak0) pu3dda(D3DDASENSE, 1);
	buf (weak1, weak0) pu3tda(D3TDASENSE, 1);
	buf (weak1, weak0) pu3drsv9(D3DRSV[9], 1);
	buf (weak1, weak0) pu3drsv10(D3DRSV[10], 1);

	buf (weak1, weak0) pu4dda(D4DDASENSE, 1);
	buf (weak1, weak0) pu4tda(D4TDASENSE, 1);
	buf (weak1, weak0) pu4drsv9(D4DRSV[9], 1);
	buf (weak1, weak0) pu4drsv10(D4DRSV[10], 1);
	
	// Pullups on the I2C lines
	pullup d1scl(D1SCL);
	pullup d1sda(D1SDA);
	pullup d2scl(D2SCL);
	pullup d2sda(D2SDA);
	pullup d3scl(D3SCL);
	pullup d3sda(D3SDA);
	pullup d4scl(D4SCL);
	pullup d4sda(D4SDA);

	// ...and instantiate the DDAs.
	dda_revC_model d1dda(.SCL(D1SCL),.SDA(D1SDA),.SENSE(D1DDASENSE),.DAT(D1DAT),.RD(D1RD),
								.SMP(D1SMP),.CH(D1CH),
								.TSA(D1TSA),.TSAOUT(D1TSAOUT),
								.TSTOUT(D1TSTOUT));

	dda_revC_model d2dda(.SCL(D2SCL),.SDA(D2SDA),.SENSE(D2DDASENSE),.DAT(D2DAT),.RD(D2RD),
								.SMP(D2SMP),.CH(D2CH),
								.TSA(D2TSA),.TSAOUT(D2TSAOUT),
								.TSTOUT(D2TSTOUT));

	dda_revC_model d3dda(.SCL(D3SCL),.SDA(D3SDA),.SENSE(D3DDASENSE),.DAT(D3DAT),.RD(D3RD),
								.SMP(D3SMP),.CH(D3CH),
								.TSA(D3TSA),.TSAOUT(D3TSAOUT),
								.TSTOUT(D3TSTOUT));

	dda_revC_model d4dda(.SCL(D4SCL),.SDA(D4SDA),.SENSE(D4DDASENSE),.DAT(D4DAT),.RD(D4RD),
								.SMP(D4SMP),.CH(D4CH),
								.TSA(D4TSA),.TSAOUT(D4TSAOUT),
								.TSTOUT(D4TSTOUT));

	// Instantiate the Unit Under Test (UUT)
	ATRI_revB #(.DEBUG("FALSE"), .SENSE("FAST"), .IFCLK_PS(0),.PCIE("NO")) uut (
		// Daughter 1
		.D1WR(D1WR), 
		.D1WRSTRB(D1WRSTRB), 
		.D1RD(D1RD), 
		.D1RDEN(D1RDEN), 
		.D1SMP(D1SMP), 
		.D1SMPALL(D1SMPALL), 
		.D1CH(D1CH), 
		.D1DAT(D1DAT), 
		.D1TSA(D1TSA), 
		.D1TSAOUT(D1TSAOUT), 
		.D1TSA_CLOSE(D1TSA_CLOSE), 
		.D1RAMP(D1RAMP), 
		.D1START(D1START), 
		.D1CLR(D1CLR), 
		.D1TSTOUT(D1TSTOUT), 
		.D1TRG_P(D1TRG_P), 
		.D1TRG_N(D1TRG_N), 
		.D1DDASENSE(D1DDASENSE), 
		.D1TDASENSE(D1TDASENSE), 
		.D1SDA(D1SDA), 
		.D1SCL(D1SCL), 
		.D1DRSV(D1DRSV),
		// Daughter 2
		.D2WR(D2WR), 
		.D2WRSTRB(D2WRSTRB), 
		.D2RD(D2RD), 
		.D2RDEN(D2RDEN), 
		.D2SMP(D2SMP), 
		.D2SMPALL(D2SMPALL), 
		.D2CH(D2CH), 
		.D2DAT(D2DAT), 
		.D2TSA(D2TSA), 
		.D2TSAOUT(D2TSAOUT), 
		.D2TSA_CLOSE(D2TSA_CLOSE), 
		.D2RAMP(D2RAMP), 
		.D2START(D2START), 
		.D2CLR(D2CLR), 
		.D2TSTOUT(D2TSTOUT), 
		.D2TRG_P(D2TRG_P), 
		.D2TRG_N(D2TRG_N), 
		.D2DDASENSE(D2DDASENSE), 
		.D2TDASENSE(D2TDASENSE), 
		.D2SDA(D2SDA), 
		.D2SCL(D2SCL), 
		.D2DRSV(D2DRSV),
		// Daughter 3
		.D3WR(D3WR), 
		.D3WRSTRB(D3WRSTRB), 
		.D3RD(D3RD), 
		.D3RDEN(D3RDEN), 
		.D3SMP(D3SMP), 
		.D3SMPALL(D3SMPALL), 
		.D3CH(D3CH), 
		.D3DAT(D3DAT), 
		.D3TSA(D3TSA), 
		.D3TSAOUT(D3TSAOUT), 
		.D3TSA_CLOSE(D3TSA_CLOSE), 
		.D3RAMP(D3RAMP), 
		.D3START(D3START), 
		.D3CLR(D3CLR), 
		.D3TSTOUT(D3TSTOUT), 
		.D3TRG_P(D3TRG_P), 
		.D3TRG_N(D3TRG_N), 
		.D3DDASENSE(D3DDASENSE), 
		.D3TDASENSE(D3TDASENSE), 
		.D3SDA(D3SDA), 
		.D3SCL(D3SCL), 
		.D3DRSV(D3DRSV),
		// Daughter 4.
		.D4WR(D4WR), 
		.D4WRSTRB(D4WRSTRB), 
		.D4RD(D4RD), 
		.D4RDEN(D4RDEN), 
		.D4SMP(D4SMP), 
		.D4SMPALL(D4SMPALL), 
		.D4CH(D4CH), 
		.D4DAT(D4DAT), 
		.D4TSA(D4TSA), 
		.D4TSAOUT(D4TSAOUT), 
		.D4TSA_CLOSE(D4TSA_CLOSE), 
		.D4RAMP(D4RAMP), 
		.D4START(D4START), 
		.D4CLR(D4CLR), 
		.D4TSTOUT(D4TSTOUT), 
		.D4TRG_P(D4TRG_P), 
		.D4TRG_N(D4TRG_N), 
		.D4DDASENSE(D4DDASENSE), 
		.D4TDASENSE(D4TDASENSE), 
		.D4SDA(D4SDA), 
		.D4SCL(D4SCL), 
		.D4DRSV(D4DRSV),
		.FLAGA(FLAGA),
		.FLAGB(FLAGB),
		.FLAGC(FLAGC),
		.FLAGD(FLAGD),
		.SLOE(SLOE),
		.SLRD(SLRD),
		.SLWR(SLWR),
		.FIFOADR(FIFOADR),
		.FD(FD),
		.PKTEND(PKTEND),
		.IFCLK(IFCLK),
		.PPS_IN(PPS_IN),
		.FPTRIG_IN(FPTRIG_IN),
		.FPGA_REFCLK_P(FPGA_REFCLK_P),
		.FPGA_REFCLK_N(FPGA_REFCLK_N)
	);
	

	// I2C buffer.
	reg [7:0] i2c_buffer[255:0];
	integer i2c_i;
	initial begin
		for (i2c_i=0;i2c_i<256;i2c_i=i2c_i+1) begin
			i2c_buffer[i2c_i] = {8{1'b0}};
		end
	end

	always begin
		#10.415 IFCLK = ~IFCLK;
	end
	always begin
		#5 REFCLK = ~REFCLK;
	end


	reg [7:0] tmpval = {8{1'b0}};
	reg [31:0] tmp2 = {32{1'b0}};
	reg [31:0] idchars = {32{1'b0}};
	reg [31:0] fwver = {32{1'b0}};
	integer i;
	initial begin
		// We have 4 DDAs and 4 TDAs.
		D1DBPRESENT = 4'b0011;
		D2DBPRESENT = 4'b0011;
		D3DBPRESENT = 4'b0011;
		D4DBPRESENT = 4'b0011;
		// Initialize Inputs
		D4TRG = 0;

		D3TRG = 0;

		D2TRG = 0;

		D1TRG = 0;

		// Wait 100 ns for global reset to finish
		#1000;
        
		// Add stimulus here
		wb_usbrd_32(16'h0000, idchars);
		$display("ID read: %s", idchars);
		wb_usbrd_32(16'h0004, fwver);
		$display("Firmware version: v%d.%d.%d , %d/%d board rev %d",
			fwver[15:12],
			fwver[11:8],
			fwver[7:0],
			fwver[27:24],
			fwver[23:16],
			fwver[31:28]);
		// turn on the DDAs, TDAs, but don't drive the DDAs
		$display("Powering DDAs and TDAs");
		wb_usbwr_8(16'h0010, 8'h23);
		#100;
		wb_usbwr_8(16'h0011, 8'h23);
		#100;
		wb_usbwr_8(16'h0012, 8'h23);
		#100;
		wb_usbwr_8(16'h0013, 8'h23);
		// Clear mode bits, and set all IRSes as active.
		$display("Setting IRS modes to 0, all IRSes active");
		wb_usbwr_8(16'h0021, 8'h0F);
		// Now drive the DDAs.
		$display("Driving DDA outputs");
		wb_usbwr_8(16'h0010, 8'h33);
		#100;
		wb_usbwr_8(16'h0011, 8'h33);
		#100;
		wb_usbwr_8(16'h0012, 8'h33);
		#100;
		wb_usbwr_8(16'h0013, 8'h33);
		// And initialize the DACs.
		// DDA DAC write
		i2c_buffer[0] = 8'h00;
		i2c_buffer[1] = 8'hB8;
		i2c_buffer[2] = 8'h52;
		i2c_buffer[3] = 8'h11;
		i2c_buffer[4] = 8'h46;
		i2c_buffer[5] = 8'h00;
		$display("D1 DDA: Vdly = %d , Vadj = %d",
					{i2c_buffer[1],i2c_buffer[2]},
					{i2c_buffer[4],i2c_buffer[5]});
		i2c_usbwr(0, 8'h18, 6, 0);

		i2c_buffer[0] = 8'h00;
		i2c_buffer[1] = 8'hB8;
		i2c_buffer[2] = 8'h52;
		i2c_buffer[3] = 8'h11;
		i2c_buffer[4] = 8'h46;
		i2c_buffer[5] = 8'h00;
		$display("D2 DDA: Vdly = %d , Vadj = %d",
					{i2c_buffer[1],i2c_buffer[2]},
					{i2c_buffer[4],i2c_buffer[5]});
		i2c_usbwr(1, 8'h18, 6, 0);

		i2c_buffer[0] = 8'h00;
		i2c_buffer[1] = 8'hB8;
		i2c_buffer[2] = 8'h52;
		i2c_buffer[3] = 8'h11;
		i2c_buffer[4] = 8'h46;
		i2c_buffer[5] = 8'h00;
		$display("D3 DDA: Vdly = %d , Vadj = %d",
					{i2c_buffer[1],i2c_buffer[2]},
					{i2c_buffer[4],i2c_buffer[5]});
		i2c_usbwr(2, 8'h18, 6, 0);

		i2c_buffer[0] = 8'h00;
		i2c_buffer[1] = 8'hB8;
		i2c_buffer[2] = 8'h52;
		i2c_buffer[3] = 8'h11;
		i2c_buffer[4] = 8'h46;
		i2c_buffer[5] = 8'h00;
		$display("D4 DDA: Vdly = %d , Vadj = %d",
					{i2c_buffer[1],i2c_buffer[2]},
					{i2c_buffer[4],i2c_buffer[5]});
		i2c_usbwr(3, 8'h18, 6, 0);
		

		#60000;
		$display("Enabling digitzer");
		wb_usbwr_8(16'h0020, 8'h01);
		#10000;
		$display("Disabling digitizer");
		wb_usbwr_8(16'h0020, 8'h00);
		$display("Resetting digitizer");
		wb_usbwr_8(16'h0020, 8'h02);
		wb_usbwr_8(16'h0020, 8'h00);
		$display("Reenabling digitizer");
		wb_usbwr_8(16'h0020, 8'h01);
		#10000;
		wb_usbrd_8(16'h007F, tmpval);
		$display("TRIGCTL = %2.2x", tmpval);
		tmpval[1:0] = 2'b00;
		$display("Selecting D1 as surface trigger daughterboard.");
		wb_usbwr_8(16'h007F, tmpval);
		#1000;
		tmpval[4] = 0;
		$display("Disabling T1 mask");
		wb_usbwr_8(16'h007F, tmpval);
		$display("Issuing L4RF0");
		@(posedge REFCLK);
		D1TRG = 4'hF;
		@(posedge REFCLK);
		@(posedge REFCLK);
		D1TRG = 4'h0;
		for (i=0;i<100;i=i+1) begin
			@(posedge REFCLK);
			D1TRG[0] = 1'b1;
			#30;
			D1TRG[0] = 1'b0;
			#1000;
		end
		#5000;
		PPS_IN = 1;
		#1000;
		PPS_IN = 0;
		wb_usbrd_32(16'h0100, tmp2);
		$display("L1[0] = %4.4x", tmp2[15:0]);
		wb_usbrd_32(16'h0140, tmp2);
		$display("L2[0] = %4.4x", tmp2[15:0]);
		wb_usbrd_32(16'h0142, tmp2);
		$display("L2[1] = %4.4x", tmp2[15:0]);
//		$display("Issuing soft-trigger");
//		wb_usbwr_8(16'h002A, 8'h01);
//		wb_usbwr_8(16'h002A, 8'h00);
		// DDA revD DAC write
//		i2c_buffer[0] = 8'h02;
//		i2c_buffer[1] = 8'h80;
//		i2c_buffer[2] = 8'h00;
//		i2c_buffer[3] = 8'h13;
//		i2c_buffer[4] = 8'h80;
//		i2c_buffer[5] = 8'h00;
//		i2c_usbwr(0, 8'h18, 6);
//		#60000;
		// Wilkinson monitor enable.
//		wb_usbwr_8(16'h0023, 8'h0F);
		
		// Set IRS active.
//		wb_usbwr_8(16'h0020, 8'h01);
		
		// 2 blocks
//		wb_usbwr_8(16'h002B, 8'h1F);
		
		// Now try soft triggering.
//		wb_usbwr_8(16'h002A, 8'h01);
//		#250000;
//		wb_usbwr_8(16'h002A, 8'h01);
/*
		// Now try forcing a few self triggers.
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;
		// What happens if we try one, say, 50 ns later?
		// Answer - nothing, because I think Luca one-shots everything 
		// by 100 ns.
		//
		// Let's try 1200 ns later.
		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#1200;
		@(posedge REFCLK);
		D1TRG = 8'h0F;
		@(posedge REFCLK);
		D1TRG = 8'h00;

		#100000;
*/		

	end
   
	reg [1:0] ev_buf_full = {2{1'b0}};
	reg [8:0] ev_buf_counter = {9{1'b0}};
	always @(posedge IFCLK) begin
		if (!PKTEND && FIFOADR == EVENT_OUT_FIFO) begin
			if (ev_buf_full == 2'b00) ev_buf_full <= 2'b01;
			else if (ev_buf_full == 2'b01) ev_buf_full <= 2'b11;
			else if (ev_buf_full == 2'b10) ev_buf_full <= 2'b11;
			ev_buf_counter <= {9{1'b0}};
		end
		if (!SLWR && FIFOADR == EVENT_OUT_FIFO) begin
			if (ev_buf_full == 2'b11) begin
				$display("Transmission error! Both buffers are full.");
				$finish;
			end
			if (ev_buf_counter == 511) begin
				if (ev_buf_full == 2'b00) ev_buf_full <= 2'b01;
				else if (ev_buf_full == 2'b01) ev_buf_full <= 2'b11;
				else if (ev_buf_full == 2'b10) ev_buf_full <= 2'b11;
				ev_buf_counter <= {9{1'b0}};
			end else begin
				ev_buf_counter <= ev_buf_counter + 1;
			end
		end
	end
	assign event_out_full = ((ev_buf_full == 2'b11) || 
	((ev_buf_full == 2'b01 || ev_buf_full == 2'b10) && ev_buf_counter == 511));
	
	always @(posedge ev_buf_full[0]) begin
		#50000;
		ev_buf_full[0] <= 0;
	end
	
	always @(posedge ev_buf_full[1]) begin
		#50000;
		ev_buf_full[1] <= 0;
	end

	
	reg packet_available = 0;
	reg [7:0] packet_number = {8{1'b0}};
	reg [7:0] packet[2047:0]; // packet buffer
	integer packet_pointer = 0;
	integer packet_length = 0;
	integer packet_i;
	initial begin
		for (packet_i=0;packet_i<2048;packet_i=packet_i+1) begin
			packet[packet_i] = {8{1'b0}};
		end
	end

	always @(posedge IFCLK) begin
		// This is the packet receiving process.
		// THIS NEEDS TO BE IMPROVED. It should buffer everything into a USB frame
		// and then ship it off to a separate process.
		if (!SLWR && FIFOADR == CONTROL_OUT_FIFO) begin
			packet_available = 0;
			packet_pointer = 0;
			packet_length = 0;
			// SOF
			packet[packet_pointer] = FD;
			packet_pointer = packet_pointer + 1;
			@(posedge IFCLK); while (SLWR || (FIFOADR != CONTROL_OUT_FIFO)) @(posedge IFCLK);			
			// Source
			packet[packet_pointer] = FD;
			packet_pointer = packet_pointer + 1;
			@(posedge IFCLK); while (SLWR || (FIFOADR != CONTROL_OUT_FIFO)) @(posedge IFCLK);			
			// Packet number
			packet[packet_pointer] = FD;
			packet_pointer = packet_pointer + 1;
			packet_number = FD;
			@(posedge IFCLK); while (SLWR || (FIFOADR != CONTROL_OUT_FIFO)) @(posedge IFCLK);			
			// Packet length
			packet[packet_pointer] = FD;
			packet_pointer = packet_pointer + 1;
			packet_length = FD;
			for (packet_i=0;packet_i<packet_length;packet_i=packet_i+1) begin
				@(posedge IFCLK); while (SLWR || (FIFOADR != CONTROL_OUT_FIFO)) @(posedge IFCLK);			
				packet[packet_pointer] = FD;
				packet_pointer = packet_pointer + 1;
			end
			// EOF
			@(posedge IFCLK); while (SLWR || (FIFOADR != CONTROL_OUT_FIFO)) @(posedge IFCLK);			
			packet[packet_pointer] = FD;
			packet_pointer = packet_pointer + 1;
			packet_available = 1;
//			$display("Packet %d, length %d is available\n", packet_number, packet_length);
		end else
			packet_available = 0;
	end	

	task i2c_usbrd;
		input [1:0] daughter;
		input [7:0] address;
		input [7:0] nbytes;
		integer loop;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = daughter+8'h03;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 3;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h00;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = nbytes;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			ctrl_in_empty = 1;
			#2 FD_O = 8'h3E;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
//			for (loop=0;loop<nbytes;loop=loop+1) i2c_buffer[loop] = packet[6+loop];
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
			@(posedge IFCLK); @(posedge IFCLK);
		end
	endtask


	task i2c_usbwr;
		input [1:0] daughter;
		input [7:0] address;
		input [7:0] buflen;
		input wait_for_ack;
		integer loop;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = daughter+8'h03;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = buflen + 2;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h00;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			for (loop=0;loop<buflen;loop=loop+1) begin
				#2 FD_O = i2c_buffer[loop];
				@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			end
			#2 FD_O = 8'h3E;
			ctrl_in_empty = 1;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			if (wait_for_ack) begin
				@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
			end
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
			@(posedge IFCLK); @(posedge IFCLK);
		end
	endtask
	
	task wb_usbwr_8;
		input [15:0] address;
		input [7:0] towrite;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h01;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h04;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h01;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[15:8];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = towrite;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 ctrl_in_empty = 1;
			FD_O = 8'h3E;
			@(posedge IFCLK); while (SLRD || (FIFOADR != 2'b00)) @(posedge IFCLK);
			@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
		end
	endtask

	task wb_usbrd_8;
		input [15:0] address;
		output [7:0] readval;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h01;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h04;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h00;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[15:8];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h1;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			// OUT EMPTY MINUS 1
			#2 ctrl_in_empty = 1;
			FD_O = 8'h3E;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
			readval = packet[4];
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
		end
	endtask

	task wb_usbrd_16;
		input [15:0] address;
		output [15:0] readval;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h01;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h04;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h00;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[15:8];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h2;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h3E;
			// OUT EMPTY MINUS 1
			ctrl_in_empty = 1;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
			readval[7:0] = packet[4];
			readval[15:8] = packet[5];
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
		end
	endtask

	task wb_usbrd_32;
		input [15:0] address;
		output [31:0] readval;
		begin
			@(posedge IFCLK);
			ctrl_in_empty = 0;
			#2 FD_O = 8'h3C;
			while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h01;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = pktno;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h04;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h00;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[15:8];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = address[7:0];
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 FD_O = 8'h4;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			#2 ctrl_in_empty = 1;
			FD_O = 8'h3E;
			@(posedge IFCLK); while (SLRD || (FIFOADR != CONTROL_IN_FIFO)) @(posedge IFCLK);
			@(posedge packet_available); while (packet_number != pktno) @(posedge packet_available);
			readval[7:0] = packet[4];
			readval[15:8] = packet[5];
			readval[23:16] = packet[6];
			readval[31:24] = packet[7];
			pktno = pktno + 1;
			if (pktno == {8{1'b0}}) pktno = 8'h01;
		end
	endtask

endmodule
