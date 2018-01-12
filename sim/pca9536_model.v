`timescale 1ns / 1ps
/**
 * @file pca9536_model.v Contains pca9536_model simulation model.
 */
 
//% @brief Model for NXP PCA9536.
//%
//% @par Overview
//% \n\n
//% Model for the PCA9536 GPIO.
//% \n\n
//% Requires: i2c_slave_base_model.v
//% \n\n
module pca9536_model(SCL, SDA, GPIO);

	parameter NBITS = 4;
	
	input SCL;
	inout SDA;
	inout [NBITS-1:0] GPIO;

	localparam [6:0] I2C_ADR = 7'b1000001;
	//% Select Input register
	localparam [1:0] R_INPUT = 2'b00;
	//% Select Output register
	localparam [1:0] R_OUTPUT = 2'b01;
	//% Select Polarity Inversion register
	localparam [1:0] R_POLARITY = 2'b10;
	//% Select Configuration register
	localparam [1:0] R_CONFIG = 2'b11;

	localparam NFILL = 8-NBITS;

	//% Default output register value
	localparam [7:0] OUTPUT_DEFAULT = 8'hFF;
	//% Default polarity register value.
	localparam [7:0] POLARITY_DEFAULT = 8'h00;
	//% Default configuration register value.
	localparam [7:0] CONFIG_DEFAULT = 8'hFF;
	
	wire [7:0] input_register = {{NFILL{1'b1}},GPIO};
	reg [7:0] output_register = OUTPUT_DEFAULT;
	reg [7:0] polarity_register = POLARITY_DEFAULT;
	reg [7:0] config_register = CONFIG_DEFAULT;
	
	reg [1:0] command = R_INPUT;
	
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
	reg i2c_select_command = 0;
	reg i2c_select_register = 0;
	always @(posedge SCL or posedge i2c_stop) begin
		if (i2c_stop)
			i2c_transaction_in_progress <= 0;
		else if (i2c_select)
			i2c_transaction_in_progress <= 1;
	end

	always @(posedge SCL or posedge i2c_stop or posedge i2c_start) begin
		if (i2c_stop || i2c_start) begin
			i2c_select_register <= 0;
		end else if (i2c_select && i2c_transaction_in_progress && !i2c_read) begin
			i2c_select_register <= 1;
		end else if (i2c_select && i2c_read) begin
			i2c_select_register <= 1;
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && !i2c_select_register && !i2c_select_register)
			command[1:0] <= i2c_write_data[1:0];
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && command[1:0] == R_CONFIG) begin
			if (i2c_select_register)
				config_register[7:0] <= i2c_write_data[7:0];
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && command[1:0] == R_POLARITY) begin
			if (i2c_select_register)
				polarity_register[7:0] <= i2c_write_data[7:0];
		end
	end
	always @(posedge SCL) begin
		if (i2c_select && i2c_transaction_in_progress && !i2c_read && command[1:0] == R_OUTPUT) begin
			if (i2c_select_register)
				output_register[7:0] <= i2c_write_data[7:0];
		end
	end

	always @(*) begin
		if (i2c_select_register) begin
			case (command)
				R_INPUT: i2c_read_data <= input_register;
				R_OUTPUT: i2c_read_data <= output_register;
				R_POLARITY: i2c_read_data <= polarity_register;
				R_CONFIG: i2c_read_data <= config_register;
			endcase
		end else begin
			i2c_read_data <= {8{1'b0}};
		end
	end

	generate
		genvar i;
		for (i=0;i<NBITS;i=i+1) begin : GPIO_OUT
			assign GPIO[i] = (config_register[i]) ? 1'bZ : output_register[i];
		end
	endgenerate

endmodule
