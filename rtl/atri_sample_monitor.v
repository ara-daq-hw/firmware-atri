`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:50:29 09/29/2012 
// Design Name: 
// Module Name:    atri_sample_monitor 
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
module atri_sample_monitor(
		input clk_i,
		input rst_i,
		input en_i,
		input [3:0] sample_mon_i,
		input sync_i,
		input sst_i,
		output [7:0] irs1_mon_o,
		output [7:0] irs2_mon_o,
		output [7:0] irs3_mon_o,
		output [7:0] irs4_mon_o,
		output [52:0] debug_o
		);

	// screw this, we just use an IDDR2 now and deserialize ourselves.
	irs_sample_mon_v2 smon(.sample_mon_i(sample_mon_i),
								  .clk_i(clk_i),.en_i(en_i),.rst_i(rst_i),.sync_i(sync_i),
								  .sst_i(sst_i),
								  .irs1_mon_o(irs1_mon_o),
								  .irs2_mon_o(irs2_mon_o),
								  .irs3_mon_o(irs3_mon_o),
								  .irs4_mon_o(irs4_mon_o),
								  .debug_o(debug_o));
endmodule
