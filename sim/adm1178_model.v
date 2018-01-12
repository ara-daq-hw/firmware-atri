`timescale 1ns / 1ps

/**
 * @file adm1178_model.v Contains adm1178_model simulation model.
 */

//% @brief Model for the ADM1178 hotswap controller.
//%
//% 

module adm1178_model(SDA, SCL, ON, ALERT);

	input SCL;
	inout SDA;
	
	input ON;
	inout ALERT;
	
	//% ADR pin connection: "GND", "RESISTOR", "FLOATING", or "HIGH".
	parameter ADR = "GND";
	
	//% Sense resistor value, in ohms
	parameter SENSE_RESISTOR = 0.2;
	
	//% Gaussian fuzz on the voltage value, in millivolts
	parameter VOLTAGE_NOISE = 1.0;

	//% Gaussian fuzz on the current value, in milliamps
	parameter CURRENT_NOISE = 1.0;
	
	//% Nominal voltage readback
	parameter VOLTAGE = 3.3;
	
	//% Nominal current readback
	parameter CURRENT = 100.0;
	
	
	localparam [6:0] I2C_ADDRESS = {3'b111, ADR=="FLOATING" || ADR=="HIGH",
														 ADR=="RESISTOR" || ADR=="HIGH",
											  2'b10};
	// extended register selects
	localparam [1:0] R_ALERT_EN = 2'b01;
	localparam [1:0] R_ALERT_TH = 2'b10;
	localparam [1:0] R_CONTROL = 2'b11;
	
	function [11:0] voltage_to_value(input range, input real vlt, input real noise);
		real vlt_val;
		real noise_mv;
		
		begin
			noise_mv = ( ( ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) ) - 2.0 ) * 1.732050808 * noise;
			if (range)
				vlt_val = (vlt + noise_mv)*(4096/6.65);
			else
				vlt_val = (vlt + noise_mv)*(4096/26.35);
			voltage_to_value = vlt_val;
		end
	endfunction

	function [11:0] current_to_value(input real sense_resistance, input real current, input real noise);
		real amp_val;
		real noise_ma;
		
		begin
			noise_ma = ( ( ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) +
								 ($random / 4294967295.0 + 0.5) ) - 2.0 ) * 1.732050808 * noise;
			amp_val = (current+noise_ma)*sense_resistance*4096/105.84;
			current_to_value = amp_val;
		end
	endfunction

	reg [11:0] current_measurement;
	reg [11:0] voltage_measurement;
	
	reg [7:0] status_register = {8{1'b0}};
	reg [7:0] extended_register_select = {8{1'b0}};
	reg [6:0] command_byte = {7{1'b0}};
	reg [4:0] alert_en_register = 5'b00100;
	reg [7:0] alert_th_register = 8'hFF;
	reg [0:0] control_register = 1'b0;
	reg i2c_first_byte_done = 0;
	reg i2c_second_byte_done = 0;
	reg i2c_third_byte_done = 0;
	reg voltage_conversion = 0;
	reg current_conversion = 0;

	reg on_filtered = 0;

	initial begin
		current_measurement <= current_to_value(SENSE_RESISTOR, CURRENT, CURRENT_NOISE);
		voltage_measurement <= voltage_to_value(0, VOLTAGE, VOLTAGE_NOISE);
	end
	
	wire i2c_select;
	wire i2c_acknowledge = i2c_select;
	wire i2c_acko;
	wire i2c_read;
	wire i2c_start;
	wire i2c_stop;
	wire [7:0] i2c_write_data;
	reg [7:0] i2c_read_data = {8{1'b0}};
	i2c_slave_base_model #(.ADDRESS(I2C_ADDRESS)) slave(.SCL(SCL),.SDA(SDA),
																		 .START(i2c_start),.STOP(i2c_stop),
																		 .RD(i2c_read),.SEL(i2c_select),
																		 .DO(i2c_write_data),.DI(i2c_read_data),
																		 .ACK(i2c_acknowledge),.ACKO(i2c_acko));
	reg i2c_transaction_in_progress = 0;
	always @(posedge SCL or posedge i2c_start or posedge i2c_stop) begin
		if (i2c_start || i2c_stop) 
			i2c_transaction_in_progress <= 0;
		else if (i2c_select)
			i2c_transaction_in_progress <= 1;
	end
	always @(posedge SCL or posedge i2c_start or posedge i2c_stop) begin
		if (i2c_start || i2c_stop) begin
			i2c_first_byte_done <= 0;
			i2c_second_byte_done <= 0;
			i2c_third_byte_done <= 0;
			extended_register_select <= {8{1'b0}};
		end else if (i2c_select && i2c_read && !i2c_transaction_in_progress) begin
			i2c_first_byte_done <= 1;
		end else if (i2c_select && i2c_read && i2c_transaction_in_progress) begin
			i2c_second_byte_done <= 1;
		end else if (i2c_select && i2c_read && i2c_transaction_in_progress && i2c_second_byte_done) begin
			i2c_third_byte_done <= 1;
		end else if (i2c_transaction_in_progress && i2c_select && !i2c_read && !i2c_first_byte_done) begin
			i2c_first_byte_done <= 1;
			// first i2c write completed: if the MSB is low, it's a command byte
			if (!i2c_write_data[7]) command_byte <= i2c_write_data[6:0];
			else extended_register_select <= i2c_write_data;

		end else if (i2c_transaction_in_progress && i2c_select && !i2c_read && i2c_first_byte_done) begin
			// this should be an extended write...
			if (!extended_register_select[7]) begin
				$display("%m : 2 bytes written (%h %h), but not extended register write",
							{1'b0, command_byte}, i2c_write_data);
				$display("%m : ignoring second byte");
			end else begin
				if (extended_register_select[6:2] != {5{1'b0}}) begin
					$display("%m : extended register write with bits 6:2 not zero (%h)", extended_register_select);
					$display("%m : ignoring second byte");
				end else begin
					if (extended_register_select[1:0] == R_ALERT_EN) begin
						alert_en_register <= i2c_write_data[4:0];
					end else if (extended_register_select[1:0] == R_ALERT_TH) begin
						alert_th_register <= i2c_write_data;
					end else if (extended_register_select[1:0] == R_CONTROL) begin
						control_register <= i2c_write_data[0];
					end else begin
						$display("%m : extended register write to invalid register (%h)", extended_register_select);
						$display("%m : ignoring second byte");
					end
				end
			end
		end
	end
	always @(command_byte) begin
		if (command_byte[1] && command_byte[3]) begin
			voltage_conversion <= 1;
			current_conversion <= 1;
			$display("%m : voltage and current conversion begun");
		end else if (command_byte[1] && !command_byte[3]) begin
			voltage_conversion <= 1;
			current_conversion <= 0;
			$display("%m : voltage conversion begun");
		end else if (!command_byte[1] && command_byte[3]) begin
			voltage_conversion <= 0;
			current_conversion <= 1;
			$display("%m : current conversion begun");
		end
	end
	always @(posedge command_byte[1]) begin
		#150000;
		voltage_measurement <= voltage_to_value(command_byte[4], VOLTAGE, VOLTAGE_NOISE);
		command_byte[1] <= 0;
	end
	always @(posedge command_byte[3]) begin
		#150000;
		current_measurement <= current_to_value(SENSE_RESISTOR, CURRENT, CURRENT_NOISE);
		command_byte[3] <= 0;
	end
	always @(*) begin
		if (command_byte[6])
			i2c_read_data <= status_register;
		else begin
			if (i2c_first_byte_done && !i2c_second_byte_done) begin
				if (voltage_conversion)
					i2c_read_data <= voltage_measurement[11:4];
				else if (current_conversion)
					i2c_read_data <= current_measurement[11:4];
				else
					i2c_read_data <= {8{1'b0}};
			end else if (i2c_second_byte_done && !i2c_third_byte_done) begin
				if (voltage_conversion && current_conversion)
					i2c_read_data <= current_measurement[11:4];
				else if (voltage_conversion)
					i2c_read_data <= {voltage_measurement[3:0], 4'h0};
				else if (current_conversion)
					i2c_read_data <= {current_measurement[3:0], 4'h0};
				else
					i2c_read_data <= {8{1'b0}};
			end else if (i2c_third_byte_done) begin
				if (voltage_conversion && current_conversion)
					i2c_read_data <= {voltage_measurement[3:0], current_measurement[3:0]};
				else
					i2c_read_data <= {8{1'b0}};
			end
		end
	end

	reg [11:0] filter_timer = 0;
	reg filter_timer_clock = 0;
	wire filter_timer_expire = (filter_timer > 3000);
	// ON input filtering:
	//
	// We do this pretty simply. If ON changes high, and on_state is low,
	// we increment timer, and keep incrementing until filter_timer_expire
	// goes. If ON changes high, and on_state is high, we reset the timer.
	// If ON changes low, and on_state is low, we reset the timer, and
	// if ON changes low, and on_state is high, we increment timer.
	// This way it takes a pulse of > 3000 ns (3 us) to trip us: this probably
	// isn't exactly correct (it's probably an RC filter), but it's close
	// enough for our purposes.
	//
	always @(ON or posedge filter_timer_expire) begin
		// If ON, and on_state is high, or ON is low, and on_state is low
		if (!ON ^ on_state)
			filter_timer = 0;
		else begin
			// if ON, and on_state is low, or ON is low, and on_state is high
			if (filter_timer > 3000) begin
				on_state = ON;
				filter_timer = 0;
			end else
				filter_timer = 1;
		end
	end
	always begin
		#0.5 filter_timer_clock <= ~filter_timer_clock;
	end
	always @(posedge filter_timer_clock) begin
		if (filter_timer) filter_timer = filter_timer + 1;
	end

	reg on_state = 0;
	
	always @(on_state or control_register[0]) begin
		status_register[4] <= !on_state || control_register[0];
	end

	//% we don't handle ALERT right now
	assign ALERT = 1'bZ;
endmodule
