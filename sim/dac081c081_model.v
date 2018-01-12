`timescale 1ns / 1ps
/**
 * @file dac081c081_model.v Contains dac081c081_model simulation model.
 */
 
//% @brief Model for Nat. Semi's DAC081C081 single-channel DAC.
//%
//% @par Overview
//% \n\n
//% Model for the DAC081C081 DAC.
//% \n\n
//% Requires: i2c_slave_base_model.v
//% \n\n
module dac081c081_model(SCL, SDA, VOUT);

	input SCL;
	inout SDA;
	output [15:0] VOUT;

	parameter ADR0 = "VA";
	localparam [1:0] A = {(ADR0== "VA"),(ADR0 == "GND")};

	localparam [6:0] I2C_ADR = {5'b00011, A};

	localparam [7:0] DAC_DEFAULT = {8{1'b0}};

	reg [7:0] dac_register = DAC_DEFAULT;

	reg [15:0] input_register = {16{1'b0}};
	wire [1:0] powerdown_command = input_register[13:12];
	
	localparam [1:0] P_NORMAL = 2'b00;
	localparam [1:0] P_2_5K_TO_GND = 2'b01;
	localparam [1:0] P_100K_TO_GND = 2'b10;
	localparam [1:0] P_HI_Z = 2'b11;
	
	reg [1:0] power_status = P_NORMAL;
		
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
	localparam [2:0] IDLE = 0;
	localparam [2:0] HIGH_BYTE = 1;
	localparam [2:0] LOW_BYTE = 2;
	reg [2:0] state = IDLE;
	reg command_done = 0;
	
	always @(posedge SCL or posedge i2c_stop or posedge i2c_start) begin
		if (i2c_start || i2c_stop) begin
			state <= IDLE;
			command_done <= 0;
		end else begin
			if (i2c_select) begin
				case (state)
					IDLE: begin
						state <= HIGH_BYTE;
						command_done <= 0;
					end
					HIGH_BYTE: begin
						input_register[15:8] <= i2c_write_data;
						state <= LOW_BYTE;
						command_done <= 0;
					end
					LOW_BYTE: begin
						input_register[7:0] <= i2c_write_data;
						state <= HIGH_BYTE;
						command_done <= 1;
					end
				endcase
			end
		end
	end
	
	always @(posedge command_done) begin
		dac_register <= input_register[7:0];
		power_status <= powerdown_command;
	end

	assign VOUT = (power_status == P_NORMAL) ? dac_register : {8{1'bZ}};
endmodule
