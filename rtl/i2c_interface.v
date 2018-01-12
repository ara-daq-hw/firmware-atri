`timescale 1ns / 1ps
//% @file i2c_interface.v Contains I2C interface expanders and reassign module.

`include "i2c_interface.vh"

//% @brief i2c_controller Remaps the I2C controller bus to individual inputs/outputs
module i2c_controller(
		inout [`I2CIF_SIZE-1:0] interface_io,
		input [7:0] dat_i,
		output [7:0] dat_o,
		input full_i,
		input empty_i,
		output rd_o,
		output wr_o,
		output packet_o
    );

	assign interface_io[15:8] = dat_i;	//% data from controller to daughter
	assign dat_o = interface_io[7:0];   //% data to controller from daughter
	assign interface_io[16] = full_i;   //% daughter to controller FIFO full
	assign interface_io[17] = empty_i;  //% controller to daughter FIFO empty
	assign wr_o = interface_io[18];     //% daughter to controller FIFO write
	assign rd_o = interface_io[19];     //% controller to daughter FIFO read
	assign packet_o = interface_io[20]; //% issue packet done from daughter to controller

endmodule

//% @brief i2c_daughter Remaps the I2C daughter bus to individual inputs/outputs.
module i2c_daughter(
		inout [`I2CIF_SIZE-1:0] interface_io,
		output [7:0] dat_o,
		input [7:0] dat_i,
		output full_o,
		output empty_o,
		input wr_i,
		input rd_i,
		input packet_i
    );

	assign dat_o = interface_io[15:8];	//% data from controller to daughter
	assign interface_io[7:0] = dat_i;   //% data to controller from daughter
	assign full_o = interface_io[16];   //% daughter to controller FIFO full
	assign empty_o = interface_io[17];  //% controller to daughter FIFO empty
	assign interface_io[18] = wr_i;     //% daughter to controller FIFO write
	assign interface_io[19] = rd_i;		//% controller to daughter FIFO read
	assign interface_io[20] = packet_i;	//% issue packet done from daughter to controller

endmodule

//% @brief i2c_reassign_controller Aliases an interface from a controller.
//%
//% This module renames an I2C interface coming from a controller. The naming
//% means that i2c_reassign_controller is used in a daughter module (unless it's the
//% outbound interface on B_o), and i2c_reassign_daughter is used in a controller module
//% (again, unless it's the outbound interface on B_o). 
module i2c_reassign_controller( A_i, B_o );
		inout [`I2CIF_SIZE-1:0] A_i;
		inout [`I2CIF_SIZE-1:0] B_o;
	
		wire [7:0] dat_to_controller;
		wire [7:0] dat_to_daughter;
		wire full, empty;
		wire rd, wr;
		wire packet;	
		i2c_daughter daughter_side(.interface_io(A_i),.dat_i(dat_to_controller),
			.dat_o(dat_to_daughter),.wr_i(wr),.rd_i(rd),
			.full_o(full),.empty_o(empty),.packet_i(packet));
		i2c_controller controller_side(.interface_io(B_o),.dat_o(dat_to_controller),
			.dat_i(dat_to_daughter),.wr_o(wr),.rd_o(rd),
			.full_i(full),.empty_i(empty),.packet_o(packet));
endmodule

//% @brief i2c_reassign_daughter Aliases an interface coming from a daughter (to a controller).
//%
//% This module renames an I2C interface coming from a daughter.
module i2c_reassign_daughter( A_i, B_o );
		inout [`I2CIF_SIZE-1:0] A_i;
		inout [`I2CIF_SIZE-1:0] B_o;
	
		wire [7:0] dat_to_controller;
		wire [7:0] dat_to_daughter;
		wire full, empty;
		wire rd, wr;
		wire packet;	
		i2c_controller controller_side(.interface_io(A_i),.dat_o(dat_to_controller),
			.dat_i(dat_to_daughter),.wr_o(wr),.rd_o(rd),
			.full_i(full),.empty_i(empty),.packet_o(packet));
		i2c_daughter daughter_side(.interface_io(B_o),.dat_i(dat_to_controller),
			.dat_o(dat_to_daughter),.wr_i(wr),.rd_i(rd),
			.full_o(full),.empty_o(empty),.packet_i(packet));
endmodule
