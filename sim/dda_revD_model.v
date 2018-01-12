`timescale 1ns / 1ps
// Model for a DDA rev D.
module dda_revD_model(
		inout SENSE,
		inout SDA,
		inout SCL,
		input [9:0] RD,
		input SMPALL,
		input [5:0] SMP,
		input [2:0] CH,
		output [11:0] DAT,
		input TSA,
		output TSAOUT,
		output TSTOUT
    );

	// DDA has a pulldown on SENSE.
	buf (pull1, pull0) pd(SENSE, 0);
	
	wire ON;
	wire ALERT;

	reg [8*3-1:0] LEDFAULT = "OFF";
	reg [8*3-1:0] LEDINIT = "OFF";
	
	wire [15:0] VADJ;
	wire [15:0] VDLY;
	wire [15:0] VBIAS;
	wire [15:0] ISEL;

	// GPIOs.
	wire [3:0] GPIO;

	always @(GPIO[3]) begin
		case (GPIO[3])
			1'b1: LEDINIT <= "OFF";
			1'b0: LEDINIT <= " ON";
		endcase
	end
	pullup init_pull(GPIO[3]);
	
	always @(ALERT) begin
		case (ALERT)
			1'b0: LEDFAULT <= " ON";
			1'b1,1'bX,1'bZ: LEDFAULT <= "OFF";
		endcase
	end

	wire [15:0] VPED;
	// VPED via the regulator is ~midscale. VPED here is 16 bits because
	// we actually do math on it in the IRS3. Since the DAC is only 8 bits
	// we just use the top 8 bits from the DAC and assign the rest to zero.
	localparam [15:0] VPED_REGULATOR = 16'h8000;
	
	// DDA rev C has an ADM1178...
	adm1178_model adm1178(.ON(ON),.ALERT(ALERT),.SDA(SDA),.SCL(SCL));
	// a TMP102...
	tmp102_model tmp102(.SDA(SDA),.SCL(SCL));
	// an AD5665...
	ad5665_model ad5665(.SDA(SDA),.SCL(SCL),.VOUTA(VDLY),.VOUTB(VADJ), .VOUTC(VBIAS),.VOUTD(ISEL));
	// a PCA9536
	pca9536_model pca9536(.SDA(SDA),.SCL(SCL),.GPIO(GPIO));
	// a DAC081C081
	dac081c081_model dac081c081(.SDA(SDA),.SCL(SCL),.VOUT(VPED[15:8]));
	// and an IRS3
	irs3_model irs3(.vdly(VDLY),.vadj(VADJ),.vbias(VBIAS),.isel(ISEL),
						 .TSTCLR(GPIO[1]),.RD_ADDR_ADV(RD[0]),.RD_ADDR_RST(RD[1]),.DOE(RD[2]),
						 .SCLK(RD[6]),.SIN(RD[7]),.SHOUT(RD[3]),.REGCLR(RD[4]),.PCLK(RD[5]),.POWER(SENSE),
						 .TSTOUT(TSTOUT),.TSA(TSA),.TSAOUT(TSAOUT),.DAT(DAT), .SMPALL(SMPALL),.CH(CH),.SMP(SMP));
	
	assign VPED = (GPIO[0]) ?  (VPED_REGULATOR) : 16'hZZ00;
	pulldown vped_pull(GPIO[0]);
	
endmodule
