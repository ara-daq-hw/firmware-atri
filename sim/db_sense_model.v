`timescale 1ns / 1ps
/**
 * @file db_sense_model.v Contains db_sense_model Verilog simulation model.
 */
 
//% @brief Model for the MB+daughterboard sense logic.
//%
//% @gensymbol
//% MODULE db_sense_model
//% LPORT PRESENT input
//% RPORT SENSE inout
//% @endgensymbol
//%
//% @par Overview
//% \n\n
//% Simulation model for the combination of the daughterboard and ATRI pullup/pulldowns.
//% \n\n
//% SENSE is an inout from the FPGA: it can therefore be driven (in Verilog
//% drive strength symbols, St1 and St0) or floated (high-Z) from the FPGA.
//% On the ATRI+DDA, it can either be pulled up (if no daughterboard present)
//% or pulled down (if a daughterboard is present). This is modeled by a
//% buffer which pulls to 1 or 0 based on whether or not the PRESENT signal
//% is asserted.
module db_sense_model(
		input PRESENT,
		inout SENSE
    );

	buf (pull1, pull0) db_pull(SENSE, !PRESENT);
	
endmodule
