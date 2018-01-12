`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:22:42 03/01/2012 
// Design Name: 
// Module Name:    irs3_dac_val_gen_test 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module irs3_dac_val_gen_test(
    );

	function [11:0] irs3_dac_shift_value;
		// Value can't exceed 2500, so this is 12 bits.
		input [11:0] millivolts;
		// Then to convert to the DAC value, we
		// need to multiply by 16384, then divide by 10,000.
		reg [25:0] millivolts_times_16384;
		reg [11:0] raw_dac_value;
		begin
			millivolts_times_16384 = {millivolts,{14{1'b0}}};
			raw_dac_value = millivolts_times_16384/10000;
			irs3_dac_shift_value = ~raw_dac_value;
		end
	endfunction
	
	localparam [11:0] IRS3_SBBIAS_MV = 860;
	localparam [11:0] IRS3_SBBIAS = irs3_dac_shift_value(IRS3_SBBIAS_MV);
	initial begin
		$display("IRS3_SBBIAS : %d ", IRS3_SBBIAS);
	end

endmodule
