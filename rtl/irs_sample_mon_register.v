`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// IRS sample mon register. Just a 256-bit register, really.
//////////////////////////////////////////////////////////////////////////////////
module irs_sample_mon_register(
		input clk_i,
		input [4:0] adr_i,
		output [7:0] dat_o,
		input tsa_delayed_i,
		input tsaout_i,
		input begin_i,
		input shift_i,
		input complete_i
	);

	reg [255:0] sample_monitor_register_working = {256{1'b0}};
	reg [255:0] sample_monitor_register = {256{1'b0}};

	wire tsaout_temp_latch;
	reg [3:0] temp_latch = {4{1'b0}};
	(* IOBUF = "TRUE" *) FD delayed_tsa_latch(.D(tsaout_i),.C(tsa_delayed_i),.Q(tsaout_temp_latch));
	always @(posedge clk_i) begin
		temp_latch <= {temp_latch[2:0],tsaout_temp_latch};
	end

	reg [7:0] bit_address_counter = {8{1'b0}};

	always @(posedge clk_i) begin
		if (begin_i) bit_address_counter <= {8{1'b0}};
		else if (shift_i) bit_address_counter <= bit_address_counter + 1;
	end
	
	always @(posedge clk_i) begin
		if (shift_i)
			sample_monitor_register_working[bit_address_counter] <= temp_latch[3];
	end
	always @(posedge clk_i) begin
		if (complete_i)
			sample_monitor_register <= sample_monitor_register_working;
	end

	wire [7:0] address_upshift = {adr_i,3'b000};
	assign dat_o = (sample_monitor_register[address_upshift +: 8]);
	
endmodule
