`timescale 1ns / 1ps
/**
 * @file i2c_slave_base_model.v Contains i2c_slave_base_model module.
 */
 
//% @brief Basic I2C slave functionality.
//%
//% @par Module Symbol
//%
//% @gensymbol
//% MODULE i2c_slave_base_model
//% PARAMETER ADDRESS
//% RPORT SCL inout
//% RPORT SDA inout
//% LPORT DO output
//% LPORT DI input
//% LPORT RD output
//% LPORT START output
//% LPORT STOP output
//% LPORT SEL output
//% LPORT ACK input
//% LPORT ACKO output
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% i2c_slave_base_model implements the basic functionality of an I2C slave.
//% Note that it is not a functional I2C slave on its own: it does not ACK
//% anything.
//% @par Parameters
//% \n\n
//% ADDRESS defines the 7 bit I2C address.
//% \n\n
//% @par Operation
//% \n\n
//% The beginning of an I2C access is indicated by the assertion 
//% of START. START is high from detection to the next falling edge of
//% SCL.
//% \n\n
//% Once the I2C address specified in the parameter ADDRESS has been
//% matched and the R/W bit seen, SEL is asserted for one clock cycle,
//% synchronized to the rising edge of SCL. SEL is high from the rising
//% edge of SCL for the R/W bit to the next SCL rising edge.
//% \n\n
//% RD also goes high at that point if the access is a read, and will
//% stay high until a STOP or START is seen.
//% \n\n
//% If ACK is asserted by the falling edge of SCL after SEL is asserted,
//% the transfer will be acknowledged - otherwise, it will not. The simplest
//% way to accomplish this is to assign ACK = SEL, possibly qualified by
//% logic if there are cases where the slave would not acknowledge the
//% transfer.
//% \n\n
//% The data to be read from the slave (on a read) must be placed on the
//% DI input at the second falling edge after SEL is asserted. In Verilog,
//% this sequence would appear:
//% @(posedge SCL); SEL <= 1; RD <= SDA;
//% @(negedge SCL); acknowledge_transfer <= ACK;
//% @(negedge SCL); data_to_bus <= DI;
//% \n\n
//% For most cases, the data to be read should be always ready at DI for
//% the first transfer, so this timing requirement should be easy.
//% \n\n
//% For a block operation (multiple reads/writes), SEL will assert on the
//% rising edge of SCL on the 8th bit operation (the LSB, and before the ACK)
//% for one clock cycle. For a write, ACK must be asserted, again, by the
//% falling edge of SCL after SEL is asserted.
//% \n\n
//% For a read, the ACK from the master is asserted on ACKO at the rising edge of
//% SCL after SEL is asserted, and the data to be on the bus must be ready
//% by the falling edge of SCL after ACKO is asserted. An address pointer
//% increment should most likely occur on the rising edge of "ACKO || STOP".
//% \n\n
//% This base model does not have support for clock stretching yet.
//% \n\n
//% The RST line is intended to prevent the device from interpreting SCL/SDA
//% during device reset.
module i2c_slave_base_model(
		SCL, SDA,
		DO, DI,
		START, STOP,
		RD, SEL,
		ACK, ACKO,
		RST
    );

	parameter ADDRESS = {7{1'b0}};
	input SCL;
	inout SDA;
	output [7:0] DO;
	input [7:0] DI;
	output START;
	output STOP;
	output RD;
	output SEL;
	input ACK;
	output ACKO;
	input RST;
	
	reg [7:0] output_data = {8{1'b0}};
	reg sel_strobe = 0;
	reg start_strobe = 0;
	reg stop_strobe = 0;
	reg read_transaction = 0;
	reg acko_strobe = 0;
	reg sda_value = 1;
	
	reg [7:0] input_shift_register = {8{1'b0}};
	reg [7:0] output_shift_register = {8{1'b0}};

	localparam ST_IDLE = 0;
	localparam ST_ADDRESS = 1;
	localparam ST_RNW = 2;
	localparam ST_ACK = 3;
	localparam ST_DATA = 4;
	reg [3:0] state = ST_IDLE;
	
	reg [3:0] bit_counter = 0;
	
	always @(negedge SDA or posedge RST) begin
		if (RST)
			start_strobe <= 0;
		else if (SCL && !SDA) begin
			start_strobe <= 1;
			// max hold time is 900 ns, so we one-shot for 800 ns
			#800;
			start_strobe <= 0;
		end
	end
	always @(posedge SDA or posedge RST) begin
		if (RST)
			stop_strobe <= 0;
		else if (SCL && SDA) begin
			stop_strobe <= 1;
			// minimum bus-free time is 1.3 us, so we can safely put a one shot of 1200 ns here.
			#1200;
			stop_strobe <= 0;
		end
	end

	always @(posedge SCL or RST) begin
		if (RST || state == ST_IDLE)
			bit_counter <= 0;
		else begin
			if (state == ST_ACK)
				bit_counter <= 0;
			else
				bit_counter <= bit_counter + 1;
		end
	end
	
	always @(posedge SCL or posedge start_strobe or posedge stop_strobe or RST) begin
		if (RST) begin
			state <= ST_IDLE;
			sda_value <= 1;
			read_transaction <= 0;
		end else if (stop_strobe) begin
			state <= ST_IDLE;
			sda_value <= 1;
			read_transaction <= 0;
		end
		else if (start_strobe) begin
			state <= ST_ADDRESS;
			sda_value <= 1;
			read_transaction <= 0;
		end else begin
			case (state)
				ST_IDLE: begin
					sda_value <= 1;
					read_transaction <= 0;
					state <= ST_IDLE;
				end
				ST_ADDRESS: if (bit_counter == 7) begin
					if (input_shift_register[6:0] == ADDRESS) begin
						state <= ST_RNW;
						sel_strobe <= 1;
						read_transaction <= SDA;
						@(negedge SCL);
						sda_value <= !ACK;
					end else
						state <= ST_IDLE;
				end else begin
					input_shift_register[7:1] <= input_shift_register[6:0];
					input_shift_register[0] <= SDA;
				end
				ST_RNW: begin
					sel_strobe <= 0;
					state <= ST_ACK;
					if (!read_transaction) begin
						@(negedge SCL);
						sda_value <= 1;
					end else begin
						@(negedge SCL);
						output_shift_register[7:1] <= DI[6:0];
						sda_value <= DI[7];
					end
				end
				ST_ACK: begin
					state <= ST_DATA;
					acko_strobe <= 0;
					if (read_transaction) begin
						@(negedge SCL);
						output_shift_register[7:1] <= output_shift_register[6:0];
						sda_value <= output_shift_register[7];
					end else begin
						input_shift_register[0] <= SDA;
						input_shift_register[7:1] <= input_shift_register[6:0];
					end
				end
				ST_DATA: begin
					if (bit_counter == 6) begin
						sel_strobe <= 1;
						if (!read_transaction) begin
							// output data received
							output_data[7:1] <= input_shift_register[6:0];
							output_data[0] <= SDA;
							// claim SDA at falling edge if acknowledge is requested
							@(negedge SCL);
							sda_value <= !ACK;
						end else begin
							// release SDA at falling edge
							@(negedge SCL);
							sda_value <= 1;
						end
					end else if (bit_counter == 7) begin
						sel_strobe <= 0;
						state <= ST_ACK;
						if (!read_transaction) begin
							@(negedge SCL);
							sda_value <= 1;
						end else begin
							acko_strobe <= !SDA;
							if (!SDA) begin
								@(negedge SCL);
								output_shift_register[7:1] <= DI[6:0];
								sda_value <= DI[7];
							end else begin
								@(negedge SCL);
								state <= ST_IDLE;
							end
						end
					end else begin
						if (!read_transaction) begin
							input_shift_register[0] <= SDA;
							input_shift_register[7:1] <= input_shift_register[6:0];
						end else begin
							@(negedge SCL);
							output_shift_register[7:1] <= output_shift_register[6:0];
							sda_value <= output_shift_register[7];
						end
					end
				end
			endcase
		end
	end
	
	//% SDA output buffer. Tristates high, drives low. SDA needs a pullup somewhere.
	buf (highz1, strong0) sda_output_buffer(SDA, sda_value);
	assign SEL = sel_strobe;
	assign RD = read_transaction;
	assign ACKO = acko_strobe;
	assign START = start_strobe;
	assign STOP = stop_strobe;
	assign DO = output_data;
endmodule
