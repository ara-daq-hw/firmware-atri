`timescale 1ps / 1ps
// Model for an IRS2.
//
// Right now all this does is output TSTOUT and TSA_OUT based on Vdly and Vadj values,
// assuming a 0-2.5V full-scale value in 16 bits.
//
module irs3_model(
		input [15:0] vdly,
		input [15:0] vadj,
		input [15:0] isel,
		input [15:0] vbias,
		input [15:0] vped,
		input RD_ADDR_ADV,
		input RD_ADDR_RST,
		input SIN,
		input SCLK,
		output SHOUT,
		input REGCLR,
		input PCLK,
		input POWER,
		input START,
		input CLR,
		input RAMP,
		input TSTCLR,
		output TSTOUT,
		input TSA,
		output TSAOUT,
		input DOE,
		output [11:0] DAT,
		input SMPALL,
		input [5:0] SMP,
		input [2:0] CH
    );

	reg [144:0] input_shift_register = {145{1'b0}};
	reg sgn = 0;
	reg [11:0] TRGbias = {12{1'b0}};
	reg [11:0] TBbias = {12{1'b0}};
	reg [11:0] TRGthresh[7:0];
	reg [11:0] TRGthref = {12{1'b0}};
	reg [11:0] SBbias = {12{1'b0}};
	integer thr_i;
	initial begin
		for (thr_i=0;thr_i<8;thr_i=thr_i+1) begin
			TRGthresh[thr_i] <= {12{1'b0}};
		end
	end
	
	always @(PCLK) begin
		sgn <= input_shift_register[0];
		TRGbias <= input_shift_register[1 +: 12];
		TBbias <= input_shift_register[13 +: 12];
		TRGthresh[7] <= input_shift_register[25 +: 12];
		// TRGthresh[6]
		TRGthresh[6] <= input_shift_register[37 +: 12];
		// TRGthresh[5]
		TRGthresh[5] <= input_shift_register[49 +: 12];
		// TRGthresh[4]
		TRGthresh[4] <= input_shift_register[61 +: 12];
		// TRGthresh[3]
		TRGthresh[3] <= input_shift_register[73 +: 12];
		// TRGthresh[2]
		TRGthresh[2] <= input_shift_register[85 +: 12];
		// TRGthresh[1]
		TRGthresh[1] <= input_shift_register[97 +: 12];
		// TRG_thresh[0]
		TRGthresh[0] <= input_shift_register[109 +: 12];
		// TRG_thref
		TRGthref     <= input_shift_register[121 +: 12];
		// SBbias
		SBbias 		 <= input_shift_register[133 +: 12];
	end
	always @(posedge SCLK or REGCLR) begin
		if (REGCLR) input_shift_register <= {145{1'b0}};
		else begin
			// This is a GUESS based on what we observe with the IRS3!!
			// I'm assuming the first problem is between SGN and TRGbias...
			input_shift_register[0] <= SIN;
			// If bit 0 is 1, and SIN is 0, then it clocks a 0.
			// If bit 0 is 0, and SIN is 1, then it clocks a 0.
			// If bit 0 is 1, and SIN is 1, then it clocks a 1.
			// If bit 0 is 0, and SIN is 0, then it clocks a 0.
			// TRGbias MSB. (TRGbias is 12:1)
			input_shift_register[1] <= (input_shift_register[0] && SIN);
			// Rest of TRGbias (12:2)
			input_shift_register[2 +: 11] <= input_shift_register[11:1];
			// TBbias
			input_shift_register[13 +: 12] <= input_shift_register[23:12];
			// TRGthresh[7]
			input_shift_register[25 +: 12] <= input_shift_register[35:24];
			// TRGthresh[6]
			input_shift_register[37 +: 12] <= input_shift_register[47:36];
			// TRGthresh[5]
			input_shift_register[49 +: 12] <= input_shift_register[59:48];
			// TRGthresh[4]
			input_shift_register[61 +: 12] <= input_shift_register[71:60];
			// TRGthresh[3]
			input_shift_register[73 +: 12] <= input_shift_register[83:72];
			// TRGthresh[2]
			input_shift_register[85 +: 12] <= input_shift_register[95:84];
			// TRGthresh[1]
			input_shift_register[97 +: 12] <= input_shift_register[107:96];
			// TRG_thresh[0]
			input_shift_register[109 +: 12] <= input_shift_register[119:108];
			// TRG_thref
			input_shift_register[121 +: 12] <= input_shift_register[131:120];
			// And the other connection problem is between TRG_thref and SBbias (maybe between TRG_thresh[0] and TRG_thref)
			// Same as before, can only clock a 1 if the previous bit's a 1.
			// SBbias MSB
			input_shift_register[133] <= input_shift_register[132] && input_shift_register[131];
			// Rest of SBbias
			input_shift_register[144:134] <= input_shift_register[143:133];
		end
	end
	function real isel_dac_to_microamps;
		input [15:0] isel;
		begin
			// This is a horrible linearization that should be replaced.
			// Works for now...
			// 100 uA = 1.3V
			// 50 uA = 1.5V
			// so uA = 425 uA - (250 uA/V)*volt
			// Note that anything above 1.7V stops at 0 uA, obviously.
			// This is 44000.
			if (isel < 44000)
				isel_dac_to_microamps = 425.0 - (isel*625/65535.0);
			else
				isel_dac_to_microamps = 0.0;
		end
	endfunction

	// This is in picofarads.
	parameter CRAMP_PF = 100.0;
	// This is in microamps.
	reg [15:0] isel_microamps = {16{1'b0}};

	//% Gaussian fuzz on the readout value.
	parameter real NOISE_AMPLITUDE = 1;
	function [12:0] add_noise_to_value(input real tmp, input real noise);
		real tmp_val;
		real noise_tmp;
		begin
			noise_tmp = ( ( ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) ) - 2.0 ) * 1.732050808 * noise;
			tmp_val = (tmp + noise_tmp);
			add_noise_to_value = tmp_val;
		end
	endfunction

	
	always @(isel) isel_microamps = isel_dac_to_microamps(isel);

	// Wilkinson voltage threshold is just V = (I/C)*t
	// Yes, we are actually simulating a Wilkinson ADC.
	reg [12:0] wilkinson_counter = {13{1'b0}};
	reg [12:0] test_wilkinson_counter = {13{1'b0}};
	
	reg test_wilkinson_enable = 0;
	reg wilkinson_enable;
	always @(posedge TSTCLR or posedge SCLK) begin
		if (SCLK)
			test_wilkinson_enable = 1;
		else if (TSTCLR)
			test_wilkinson_enable = 0;
	end
	always @(posedge START or posedge CLR) begin
		if (CLR)
			wilkinson_enable = 0;
		else if (START)
			wilkinson_enable = 1;
	end

	// delay for wilkinson
	// from goofy previous mesurements
	// 2.5V = 180 kHz = 5.6 us
	// 2.0V = 170 kHz = 5.9 us
	// 1.4V = 160 kHz = 6.2 us
	// 1.1V = 135 kHz = 7.4 us
	// 1.0V = 125 kHz = 8 us
	// linearizing (horrible approximation) we get 2.4 us/1.5V
	// delay in ns = 9600 - (dac value)*(2500 mV/65535)*(2400/1500)
	/// = 9600 - 0.061*(dac value)
	// or, much simpler = 9600 - (dac_value)/16
	// so the half-time is 4800 - (dac_value)/32
	// We then need to divide that by 2^12 to get the *base* Wilkinson clock,
	// which will be running somewhere in the near-GHz range.
	// That will be in picoseconds.
	function [15:0] vdly_to_delay;
		input [15:0] vdly;
		reg [43:0] tmp;
		begin
			tmp = (153600 - vdly)*1000;
			// now divide by 32*4096
			// and divide by 2 again to get a clock.
			vdly_to_delay = tmp[33:18];			
		end
	endfunction
	
	reg test_wilk_clock = 0;
	reg wilk_clock;
	reg [15:0] wilkinson_delay;
	always @(vdly) begin
		wilkinson_delay = vdly_to_delay(vdly);
	end
	always @(posedge test_wilk_clock) begin
		#wilkinson_delay test_wilk_clock = 0;
	end
	always @(posedge wilk_clock) begin
		#wilkinson_delay wilk_clock = 0;
	end
	always @(negedge test_wilk_clock) begin
		if (test_wilkinson_enable)
			#wilkinson_delay test_wilk_clock = 1;
	end
	always @(negedge wilk_clock) begin
		if (wilkinson_enable)
			#wilkinson_delay wilk_clock = 1;
	end

	always @(posedge test_wilkinson_enable) begin
		#wilkinson_delay test_wilk_clock = 1;
	end
	always @(posedge wilkinson_enable) begin
		#wilkinson_delay wilk_clock = 1;
	end

	always @(posedge test_wilk_clock or negedge test_wilkinson_enable) begin
		if (!test_wilkinson_enable)
			test_wilkinson_counter <= {13{1'b0}};
		else
			test_wilkinson_counter <= test_wilkinson_counter + 1;
	end
	always @(posedge wilk_clock or negedge wilkinson_enable) begin
		if (!wilkinson_enable)
			wilkinson_counter <= {13{1'b0}};
		else
			wilkinson_counter <= wilkinson_counter + 1;
	end

	reg [11:0] wilkinson_register = {12{1'b0}};
	reg [11:0] data_value = {12{1'b0}};
	always @(SMPALL or SMP or CH) begin
		data_value <= add_noise_to_value(wilkinson_register, NOISE_AMPLITUDE);
	end

	// VPED's scale is 0 -> 65535 = 0 - 2.5V
	// Wilkinson register's scale is 0 -> 4095 = 0 - 2.5V
	// So we just downshift vped, and compare.
	always @(posedge wilk_clock or posedge CLR) begin
		if (CLR)
			wilkinson_register <= {12{1'b0}};
		else if (wilkinson_counter > vped[15:4])
			wilkinson_register <= wilkinson_counter;
	end
	
	assign TSTOUT = test_wilkinson_counter[12];

	function [15:0] vadj_to_delay;
		input [15:0] vadj;
		reg [31:0] tmp;
		begin
			tmp = vadj - 18350;
			vadj_to_delay = 20 - tmp[27:12];
		end
	endfunction

	reg [31:0] tsa_delay;
	always @(vadj) begin
		tsa_delay = vadj_to_delay(vadj)*1000;
	end

	reg tsa_out_reg = 0;
	always @(posedge TSA)
		#tsa_delay tsa_out_reg = 1;		
	always @(negedge TSA)
		#tsa_delay tsa_out_reg = 0;
		
	assign TSAOUT = tsa_out_reg;
	// turn this into some Gaussian noise at some point
	assign DAT = (DOE) ? wilkinson_register : {12{1'bZ}};

	assign SHOUT = input_shift_register[144];

endmodule
