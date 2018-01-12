`timescale 1ns / 1ps
/**
 * @file tmp102_model.v Contains tmp102_model simulation model.
 */
 
//% @brief Model for Texas Instruments TMP102.
//%
//% @par Overview
//% \n\n
//% Pretty detailed model for the TMP102 temperature sensor. Generates random temperature measurements
//% at the rate given, etc.
//% \n\n
//% Requires: i2c_slave_base_model.v
//% \n\n
//% Not implemented yet: ALERT pin/bit behavior.
module tmp102_model(SCL, SDA);

	input SCL;
	inout SDA;

	//% Connection of the ADD0 pin: either "GND","V+","SDA", or "SCL". See datasheet.
	parameter ADD0 = "GND";
	//% Gaussian fuzz on the temperature value, in degrees Celsius.
	parameter real NOISE_AMPLITUDE = 0.5;
	//% Mean value of the temperature, in degrees Celsius.
	parameter real TEMPERATURE = 25.0;

	//% I2C address, based on ADD0 parameter
	localparam [6:0] I2C_ADR = {5'b10010,ADD0=="SDA" || ADD0=="SCL",ADD0=="V+" || ADD0=="SCL"};
	//% Select temperature register
	localparam [1:0] R_TEMPERATURE = 2'b00;
	//% Select configuration register
	localparam [1:0] R_CONFIGURATION = 2'b01;
	//% Select T_low register
	localparam [1:0] R_TLOW = 2'b10;
	//% Select T_high register
	localparam [1:0] R_THIGH = 2'b11;
	//% Update at 0.25 Hz
	localparam [1:0] CR_0_25HZ = 2'b00;
	//% Update at 1 Hz
	localparam [1:0] CR_1HZ = 2'b01;
	//% Update at 4 Hz
	localparam [1:0] CR_4HZ = 2'b10;
	//% Update at 8 Hz
	localparam [1:0] CR_8HZ = 2'b11;
	
	//% 1 consecutive fault needed
	localparam [1:0] FQ_1 = 2'b00;
	//% 2 consecutive faults needed
	localparam [1:0] FQ_2 = 2'b01;
	//% 4 consecutive faults needed
	localparam [1:0] FQ_4 = 2'b10;
	//% 6 consecutive faults needed
	localparam [1:0] FQ_6 = 2'b11;
	
	//% Default pointer register value
	localparam [1:0] POINTER_DEFAULT = R_TEMPERATURE;
	//% Default configuration register value
	localparam [11:0] CONFIGURATION_DEFAULT = 12'b011000001010;
	//% Default T_low register values
	localparam [12:0] TLOW_DEFAULT = 12'd1200;
	//% Default T_high register values
	localparam [12:0] THIGH_DEFAULT = 12'd1280;

	function [12:0] temperature_to_value(input real tmp, input real noise);
		real tmp_val;
		real noise_tmp;
		begin
			noise_tmp = ( ( ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) ) - 2.0 ) * 1.732050808 * noise;
			tmp_val = (tmp + noise_tmp)/0.0625;
			temperature_to_value = tmp_val;
		end
	endfunction

	reg [12:0] temperature_register;
	initial begin
		temperature_register <= temperature_to_value(TEMPERATURE, NOISE_AMPLITUDE);
	end
	reg [12:0] tlow_register = TLOW_DEFAULT;
	reg [12:0] thigh_register = THIGH_DEFAULT;
	reg [11:0] configuration_register = CONFIGURATION_DEFAULT;
	reg alert_bit = 0;
	reg oneshot_status = 0;
	wire [11:0] configuration_register_readback = 
		{oneshot_status,2'b11,configuration_register[8:2],alert_bit,configuration_register[0]};	
	reg [1:0] pointer_register = POINTER_DEFAULT;
	
	// conversion clock
	reg conversion_clock = 0;
	always begin
		#62500000 conversion_clock <= ~conversion_clock;
	end

	reg [5:0] conversion_counter = {6{1'b0}};		

	always @(posedge conversion_clock) begin
		if (configuration_register[4]) begin
			conversion_counter <= 0;
		end else if (((configuration_register[3:2] == CR_0_25HZ) && conversion_counter == 31) ||
			 ((configuration_register[3:2] == CR_1HZ) && conversion_counter == 7) ||
			 ((configuration_register[3:2] == CR_4HZ) && conversion_counter == 1) ||
			 (configuration_register[3:2] == CR_8HZ)) begin
			temperature_register <= temperature_to_value(TEMPERATURE, NOISE_AMPLITUDE);
			conversion_counter <= 0;
		end else
			conversion_counter <= conversion_counter + 1;
	end

	wire i2c_start;
	wire i2c_stop;
	wire i2c_select;
	wire i2c_master_ack;
	wire i2c_read;
	wire [7:0] i2c_write_data;
	reg [7:0] i2c_read_data;
	i2c_slave_base_model #(.ADDRESS(I2C_ADR)) slave(.SCL(SCL),.SDA(SDA),
																	.START(i2c_start),.STOP(i2c_stop),
																	.SEL(i2c_select),.RD(i2c_read),
																	.ACK(i2c_select),.ACKO(i2c_master_ack),
																	.DI(i2c_read_data),.DO(i2c_write_data));
	reg i2c_transaction_in_progress = 0;
	reg i2c_select_byte_1 = 0;
	reg i2c_select_byte_2 = 0;
	always @(posedge SCL or posedge i2c_stop) begin
		if (i2c_stop)
			i2c_transaction_in_progress <= 0;
		else if (i2c_select)
			i2c_transaction_in_progress <= 1;
	end

	always @(posedge SCL or posedge i2c_stop or posedge i2c_start) begin
		if (i2c_stop || i2c_start) begin
			i2c_select_byte_1 <= 0;
			i2c_select_byte_2 <= 0;
		end else if (i2c_select && i2c_transaction_in_progress && !i2c_read) begin
			if (!i2c_select_byte_1 && !i2c_select_byte_2)
				i2c_select_byte_1 <= 1;
			else if (i2c_select_byte_1) begin
				i2c_select_byte_2 <= 1;
				i2c_select_byte_1 <= 0;
			end
		end else if (i2c_select && i2c_read) begin
			if (!i2c_select_byte_1 && !i2c_select_byte_2)
				i2c_select_byte_1 <= 1;
			else if (i2c_select_byte_1) begin
				i2c_select_byte_1 <= 0;
				i2c_select_byte_2 <= 1;
			end
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && !i2c_select_byte_1 && !i2c_select_byte_2)
			pointer_register[1:0] <= i2c_write_data[1:0];
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && pointer_register[1:0] == 2'b01) begin
			if (i2c_select_byte_1)
				configuration_register[11:4] <= i2c_write_data;
			if (i2c_select_byte_2)
				configuration_register[3:0] <= i2c_write_data[7:4];
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && pointer_register[1:0] == 2'b10) begin
			if (i2c_select_byte_1) begin
				$display("reading...\n");
				if (configuration_register[0])
					tlow_register[12:5] <= i2c_write_data;
				else
					tlow_register[11:4] <= i2c_write_data;
			end
			if (i2c_select_byte_2)
				if (configuration_register[0])
					tlow_register[4:0] <= i2c_write_data[7:3];
				else
					tlow_register[3:0] <= i2c_write_data[7:4];
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && pointer_register[1:0] == 2'b11) begin
			if (i2c_select_byte_1)
				if (configuration_register[0])
					thigh_register[12:5] <= i2c_write_data;
				else
					thigh_register[11:4] <= i2c_write_data;
			if (i2c_select_byte_2)
				if (configuration_register[0])
					thigh_register[4:0] <= i2c_write_data[7:3];
				else
					thigh_register[3:0] <= i2c_write_data[7:4];
		end
	end
	
	always @(*) begin
		if (i2c_select_byte_1) begin
			case (pointer_register[1:0])
				R_TEMPERATURE: if (configuration_register[0]) i2c_read_data <= temperature_register[12:5];
						 else i2c_read_data <= temperature_register[11:4];
				R_CONFIGURATION: i2c_read_data <= configuration_register_readback[11:4];
				R_TLOW: if (configuration_register[0]) i2c_read_data <= tlow_register[12:5];
						 else i2c_read_data <= tlow_register[11:4];
				R_THIGH: if (configuration_register[0]) i2c_read_data <= thigh_register[12:5];
						 else i2c_read_data <= thigh_register[11:4];
			endcase
		end else if (i2c_select_byte_2) begin
			case (pointer_register[1:0])
				R_TEMPERATURE: if (configuration_register[0]) i2c_read_data <= {temperature_register[4:0],3'b000};
						 else i2c_read_data <= {temperature_register[3:0], 4'h0};
				R_CONFIGURATION: i2c_read_data <= {configuration_register_readback[3:0], 4'h0};
				R_TLOW: if (configuration_register[0]) i2c_read_data <= {tlow_register[4:0],3'b000};
						 else i2c_read_data <= {tlow_register[3:0],4'h0};
				R_THIGH: if (configuration_register[0]) i2c_read_data <= {thigh_register[4:0],3'b000};
						 else i2c_read_data <= {thigh_register[3:0],4'h0};
			endcase
		end
	end
	always @(configuration_register[0]) begin
		if (configuration_register[0])
			$display("%m : beginning extended (13-bit) mode");
		else
			$display("%m : beginning normal (12-bit) mode");
	end
	always @(configuration_register[3:2]) begin
		if (configuration_register[3:2] == CR_0_25HZ)
			$display("%m : conversion rate 0.25 Hz");
		else if (configuration_register[3:2] == CR_1HZ)
			$display("%m : conversion rate 1 Hz");
		else if (configuration_register[3:2] == CR_4HZ)
			$display("%m : conversion rate 4 Hz");
		else if (configuration_register[3:2] == CR_8HZ)
			$display("%m : conversion rate 8 Hz");
	end
	always @(configuration_register[4]) begin
		if (configuration_register[4])
			$display("%m : shutting down (SD bit set)");
		else
			$display("%m : turning on (SD bit cleared)");
	end
	always @(configuration_register[5]) begin
		if (configuration_register[5])
			$display("%m : ALERT stays and remains on once fault threshold reached");
		else
			$display("%m : ALERT stays on only while temperature out of bounds over consecutive faults");
	end
	always @(configuration_register[6]) begin
		if (configuration_register[6])
			$display("%m : alert pin is active high");
		else
			$display("%m : alert pin is active low");
	end
	always @(configuration_register[8:7]) begin
		if (configuration_register[8:7] == FQ_1)
			$display("%m : 1 fault needed to trip ALERT");
		else if (configuration_register[8:7] == FQ_2)
			$display("%m : 2 consecutive faults needed to trip ALERT");
		else if (configuration_register[8:7] == FQ_4)
			$display("%m : 4 consecutive faults needed to trip ALERT");
		else if (configuration_register[8:7] == FQ_6)
			$display("%m : 6 consecutive faults needed to trip ALERT");
	end
	always @(posedge configuration_register[11] or configuration_register[4]) begin
		if (!configuration_register[4]) begin
			if (configuration_register[11]) 
				$display("%m : one-shot conversion requested, but device not shut down");
			#1 configuration_register[11] <= 0;
			oneshot_status <= 0;
		end else if (configuration_register[11]) begin
			$display("%m : one-shot conversion requested");
			oneshot_status <= 0;
			#26000000;
			temperature_register <= temperature_to_value(TEMPERATURE, NOISE_AMPLITUDE);
			oneshot_status <= 1;
			$display("%m : one-shot conversion complete");
		end
	end
endmodule
