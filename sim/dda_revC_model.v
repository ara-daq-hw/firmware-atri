`timescale 1ns / 1ps
// Model for a DDA rev C.
module dda_revC_model(
		inout SENSE,
		inout SDA,
		inout SCL,
		inout [9:0] RD,
		input [5:0] SMP,
		input [2:0] CH,
		output [11:0] DAT,
		input TSA,
		output TSAOUT,
		output TSTOUT
    );

	// DDA has a pulldown on SENSE.
	buf (pull1, pull0) pd(SENSE, 0);
	
	wire ON = SENSE;
	wire ALERT;

	reg [8*3-1:0] LEDFAULT = "OFF";
	reg [8*3-1:0] LEDINIT = "OFF";
	
	wire [15:0] VADJ;
	wire [15:0] VDLY;

	// GPIOs.
	wire [3:0] GPIO;

	always @(GPIO[3]) begin
		case (GPIO[3])
			1'b1,1'bX,1'bZ: LEDINIT <= "OFF";
			1'b0: LEDINIT <= " ON";
		endcase
	end
	always @(ALERT) begin
		case (ALERT)
			1'b0: LEDFAULT <= " ON";
			1'b1,1'bX,1'bZ: LEDFAULT <= "OFF";
		endcase
	end

	// DDA rev C has an ADM1178...
	adm1178_model adm1178(.ON(ON),.ALERT(ALERT),.SDA(SDA),.SCL(SCL));
	// a TMP102...
	tmp102_model tmp102(.SDA(SDA),.SCL(SCL));
	// an AD5667...
	ad5667_model ad5667(.SDA(SDA),.SCL(SCL),.VOUTA(VDLY),.VOUTB(VADJ), .NLDAC(1),.NCLR(1));
	// a PCA9536
	pca9536_model pca9536(.SDA(SDA),.SCL(SCL),.GPIO(GPIO));
	// and an IRS2
	irs2_model irs2(.vdly(VDLY),.vadj(VADJ),.TSTCLR(GPIO[1]),.TSTST(GPIO[0]),.POWER(SENSE),
						 .TSTOUT(TSTOUT),.TSA(TSA),.TSAOUT(TSAOUT),.DAT(DAT),.SMP(SMP),.CH(CH));
	
endmodule
