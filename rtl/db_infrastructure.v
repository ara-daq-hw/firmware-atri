`timescale 1ns / 1ps
//% @file db_infrastructure.v Contains db_infrastructure module.

//% @brief db_infrastructure Contains bidirectional control signals for a daughterboard.
module db_infrastructure(
		inout SCL,
		output scl_input_o,
		input scl_output_i,
		input scl_oen_i,
		inout SDA,
		output sda_input_o,
		input sda_output_i,
		input sda_oen_i,
		inout DDASENSE,
		output ddasense_input_o,
		input ddasense_output_i,
		input ddasense_oen_i,
		inout TDASENSE,
		output tdasense_input_o,
		input tdasense_output_i,
		input tdasense_oen_i,
		inout DRSV9,
		output drsv9_input_o,
		input drsv9_output_i,
		input drsv9_oen_i,
		inout DRSV10,
		output drsv10_input_o,
		input drsv10_output_i,
		input drsv10_oen_i
    );

	parameter IMPLEMENT_RESERVED = "YES";

	IOBUF sda_iobuf(.IO(SDA), .O(sda_input_o), .I(sda_output_i), .T(sda_oen_i));
	IOBUF scl_iobuf(.IO(SCL), .O(scl_input_o), .I(scl_output_i), .T(scl_oen_i));
	IOBUF ddasense_iobuf(.IO(DDASENSE), .O(ddasense_input_o), .I(ddasense_output_i), .T(ddasense_oen_i));
	IOBUF tdasense_iobuf(.IO(TDASENSE), .O(tdasense_input_o), .I(tdasense_output_i), .T(tdasense_oen_i));
	generate
		if (IMPLEMENT_RESERVED=="YES") begin : RSVD
			IOBUF drsv9_iobuf(.IO(DRSV9), .O(drsv9_input_o), .I(drsv9_output_i), .T(drsv9_oen_i));
			IOBUF drsv10_iobuf(.IO(DRSV10), .O(drsv10_input_o), .I(drsv10_output_i), .T(drsv10_oen_i));
		end
	endgenerate
endmodule
