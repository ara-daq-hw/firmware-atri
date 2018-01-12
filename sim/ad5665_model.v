`timescale 1ns / 1ps
/**
 * @file ad5665_model.v Contains ad5665_model simulation model.
 */
 
//% @brief Model for Analog Devices AD5665 quad-channel DAC.
//%
//% @par Overview
//% \n\n
//% Model for the AD5665 DAC.
//% \n\n
//% Requires: i2c_slave_base_model.v
//% \n\n
module ad5665_model(SCL, SDA, VOUTA, VOUTB, VOUTC, VOUTD);

	input SCL;
	inout SDA;
	output [15:0] VOUTA;
	output [15:0] VOUTB;
	output [15:0] VOUTC;
	output [15:0] VOUTD;

	parameter ADDR = "VDD";
	localparam [1:0] A = {(ADDR== "NC" || ADDR == "GND"),(ADDR == "GND")};

	localparam [6:0] I2C_ADR = {5'b00011, A};
	//% Write to input register
	localparam [2:0] C_WRITE = 3'b000;
	//% Update DAC register
	localparam [2:0] C_UPDATE = 3'b001;
	//% Write to input register, then update all (software \LDAC)
	localparam [2:0] C_WRITE_AND_UPDATE_ALL = 3'b010;
	//% Write to input register, then update
	localparam [2:0] C_WRITE_AND_UPDATE = 3'b011;
	//% Power up/down.
	localparam [2:0] C_POWERDOWN = 3'b100;
	//% Reset
	localparam [2:0] C_RESET = 3'b101;
	//% nLDAC register setup
	localparam [2:0] C_LDAC = 3'b110;
	//% Internal reference setup
	localparam [2:0] C_REFERENCE = 3'b111;
	
	localparam [15:0] DAC_A_DEFAULT = {16{1'b0}};
	localparam [15:0] DAC_B_DEFAULT = {16{1'b0}};
	localparam [15:0] DAC_C_DEFAULT = {16{1'b0}};
	localparam [15:0] DAC_D_DEFAULT = {16{1'b0}};
	
	reg [15:0] dac_a_register = DAC_A_DEFAULT;
	reg [15:0] dac_b_register = DAC_B_DEFAULT;
	reg [15:0] dac_c_register = DAC_C_DEFAULT;
	reg [15:0] dac_d_register = DAC_D_DEFAULT;
	reg [15:0] dac_a_value = DAC_A_DEFAULT;
	reg [15:0] dac_b_value = DAC_B_DEFAULT;
	reg [15:0] dac_c_value = DAC_C_DEFAULT;
	reg [15:0] dac_d_value = DAC_D_DEFAULT;
	
	reg [7:0] command_byte = {8{1'b0}};
	wire [2:0] command = command_byte[5:3];
	wire [2:0] dac = command_byte[2:0];
	wire command_mode_select = command_byte[6];
	
	localparam [2:0] DAC_A = 3'b000;
	localparam [2:0] DAC_B = 3'b001;
	localparam [2:0] DAC_C = 3'b010;
	localparam [2:0] DAC_D = 3'b011;
	localparam [2:0] DAC_ABCD = 3'b111;
	
	localparam [1:0] P_NORMAL = 2'b00;
	localparam [1:0] P_1K_TO_GND = 2'b01;
	localparam [1:0] P_100K_TO_GND = 2'b10;
	localparam [1:0] P_HI_Z = 2'b11;
	
	reg [1:0] a_power_status = P_NORMAL;
	reg [1:0] b_power_status = P_NORMAL;
	
	localparam LDAC_NORMAL = 0;
	localparam LDAC_AUTO = 1;
	reg ldac_dac_a = LDAC_NORMAL;
	reg ldac_dac_b = LDAC_NORMAL;
	
	localparam REFERENCE_OFF = 0;
	localparam REFERENCE_ON = 1;
	reg internal_reference = REFERENCE_OFF;
	
	reg software_reset = 0;
	reg power_on_reset = 0;
	
	localparam COMMAND_INITIAL = 1;
	localparam COMMAND_ALL = 0;
	reg command_mode = COMMAND_ALL;
	
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
	localparam [2:0] TRANSACTION = 1;
	localparam [2:0] COMMAND = 2;
	localparam [2:0] HIGH_BYTE = 3;
	reg [2:0] state = IDLE;
	reg command_done = 0;
	reg [15:0] input_register = {16{1'b0}};
	
	always @(posedge SCL or posedge i2c_stop or posedge i2c_start) begin
		if (i2c_start || i2c_stop) begin
			state <= IDLE;
			command_done <= 0;
		end else begin
			if (i2c_select) begin
				case (state)
					IDLE: begin
						state <= TRANSACTION;
						command_done <= 0;
					end
					TRANSACTION: begin
						command_byte <= i2c_write_data;
						command_mode <= command_mode_select;
						state <= COMMAND;
						command_done <= 0;
					end
					COMMAND: begin
						input_register[15:8] <= i2c_write_data;
						state <= HIGH_BYTE;
						command_done <= 0;
					end
					HIGH_BYTE: begin
						input_register[7:0] <= i2c_write_data;
						command_done <= 1;
						if (command_mode == COMMAND_INITIAL) state <= COMMAND;
						else state <= TRANSACTION;
					end
				endcase
			end
		end
	end
	
	always @(posedge command_done) begin
		case (command)
			C_WRITE: begin
				if (dac == DAC_A)
					dac_a_register <= input_register;
				else if (dac == DAC_B)
					dac_b_register <= input_register;
				else if (dac == DAC_C)
					dac_c_register <= input_register;
				else if (dac == DAC_D)
					dac_d_register <= input_register;
				else if (dac == DAC_ABCD) begin
					dac_a_register <= input_register;
					dac_b_register <= input_register;
					dac_c_register <= input_register;
					dac_d_register <= input_register;
				end
			end
			C_UPDATE: begin
				if (dac == DAC_A)
					dac_a_value <= dac_a_register;
				else if (dac == DAC_B)
					dac_b_value <= dac_b_register;
				else if (dac == DAC_C)
					dac_c_value <= dac_c_register;
				else if (dac == DAC_D)
					dac_d_value <= dac_d_register;
				else if (dac == DAC_ABCD) begin
					dac_a_value <= dac_a_register;
					dac_b_value <= dac_b_register;
					dac_c_value <= dac_c_register;
					dac_d_value <= dac_d_register;
				end
			end
			C_WRITE_AND_UPDATE_ALL: begin
				if (dac == DAC_A) begin
					dac_a_register <= input_register;
					dac_a_value <= input_register;
					dac_b_value <= dac_b_register;
					dac_c_value <= dac_c_register;
					dac_d_value <= dac_d_register;
				end else if (dac == DAC_B) begin
					dac_b_register <= input_register;
					dac_b_value <= input_register;
					dac_a_value <= dac_a_register;
					dac_c_value <= dac_c_register;
					dac_d_value <= dac_d_register;
				end else if (dac == DAC_C) begin
					dac_c_register <= input_register;
					dac_c_value <= input_register;
					dac_a_value <= dac_a_register;
					dac_b_value <= dac_b_register;
					dac_d_value <= dac_d_register;
				end else if (dac == DAC_D) begin
					dac_d_register <= input_register;
					dac_d_value <= input_register;
					dac_a_value <= dac_a_register;
					dac_b_value <= dac_b_register;
					dac_c_value <= dac_c_register;
				end else if (dac == DAC_ABCD) begin
					dac_a_register <= input_register;
					dac_b_register <= input_register;
					dac_c_register <= input_register;
					dac_d_register <= input_register;
					dac_a_value <= input_register;
					dac_b_value <= input_register;
					dac_c_value <= dac_c_register;
					dac_d_value <= dac_d_register;
				end
			end
			C_WRITE_AND_UPDATE: begin
				if (dac == DAC_A) begin
					dac_a_register <= input_register;
					dac_a_value <= input_register;
				end else if (dac == DAC_B) begin
					dac_b_register <= input_register;
					dac_b_value <= input_register;
				end else if (dac == DAC_C) begin
					dac_c_register <= input_register;
					dac_c_value <= input_register;
				end else if (dac == DAC_D) begin
					dac_d_register <= input_register;
					dac_d_value <= input_register;
				end else if (dac == DAC_ABCD) begin
					dac_a_register <= input_register;
					dac_b_register <= input_register;
					dac_c_register <= input_register;
					dac_d_register <= input_register;
					dac_a_value <= input_register;
					dac_b_value <= input_register;
					dac_c_value <= input_register;
					dac_d_value <= input_register;
				end
			end
			C_POWERDOWN: $display("%m : power down command received (not implemented)");
			C_RESET: $display("%m : reset command received (not implemented)");
			C_LDAC: $display("%m : ldac command received (not implemented)");
			C_REFERENCE: $display("%m : internal reference command received (not implemented)");
		endcase
	end

	assign VOUTA = dac_a_value;
	assign VOUTB = dac_b_value;
	assign VOUTC = dac_c_value;
	assign VOUTD = dac_d_value;
endmodule
