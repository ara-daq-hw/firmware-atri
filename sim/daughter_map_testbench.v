`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:45:37 08/14/2012
// Design Name:   trigger_scaler_map_v2
// Module Name:   C:/cygwin/home/barawn/repositories/ara/firmware/ATRI/branches/unified/sim/daughter_map_testbench.v
// Project Name:  ATRI
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: trigger_scaler_map_v2
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module daughter_map_testbench;

	// Inputs
	reg [7:0] d1_trig_i;
	reg [7:0] d1_pwr_i;
	reg [7:0] d2_trig_i;
	reg [7:0] d2_pwr_i;
	reg [7:0] d3_trig_i;
	reg [7:0] d3_pwr_i;
	reg [7:0] d4_trig_i;
	reg [7:0] d4_pwr_i;
	reg [1:0] rsv_trig_db_i;
	reg [19:0] l1_mask_i;
	reg fclk_i;
	reg sclk_i;
	reg sce_i;
	reg rst_i;
	reg [15:0] l2_mask_i;
	reg [7:0] l3_mask_i;
	reg [1:0] l4_mask_i;

	// Outputs
	wire [19:0] l1_trig_p_o;
	wire [19:0] l1_trig_n_o;
	wire [19:0] l1_scaler_o;
	wire [15:0] l2_scaler_o;
	wire [7:0] l3_scaler_o;
	wire [1:0] l4_scaler_o;
	
	// Instantiate the Unit Under Test (UUT)
	trigger_scaler_map_v2 uut (
		.d1_trig_i(d1_trig_i), 
		.d1_pwr_i(d1_pwr_i), 
		.d2_trig_i(d2_trig_i), 
		.d2_pwr_i(d2_pwr_i), 
		.d3_trig_i(d3_trig_i), 
		.d3_pwr_i(d3_pwr_i), 
		.d4_trig_i(d4_trig_i), 
		.d4_pwr_i(d4_pwr_i), 
		.l1_trig_p_o(l1_trig_p_o), 
		.l1_trig_n_o(l1_trig_n_o), 
		.l1_scaler_o(l1_scaler_o), 
		.rsv_trig_db_i(rsv_trig_db_i), 
		.l1_mask_i(l1_mask_i), 
		.fclk_i(fclk_i), 
		.sclk_i(sclk_i), 
		.sce_i(sce_i)
	);
	
	reg [7:0] rf0_blocks_i = 8'd19;
	wire [1:0] l4_trig_o;
	rf_trigger_top_v2 rf_top(.l1_trig_p_i(l1_trig_p_o),
									 .l1_trig_n_i(l1_trig_n_o),
									 .l2_mask_i(l2_mask_i),
									 .l3_mask_i(l3_mask_i),
									 .l4_mask_i(l4_mask_i),
									 .l2_scaler_o(l2_scaler_o),
									 .l3_scaler_o(l3_scaler_o),
									 .l4_scaler_o(l4_scaler_o),
									 .clk_i(fclk_i),
									 .rst_i(rst_i),
									 .disable_i(1'b0),
									 .rf0_blocks_i(rf0_blocks_i),
									 .l4_trig_o(l4_trig_o));
	
	always begin
		#5 fclk_i = ~fclk_i;
	end

	initial begin
		// Initialize Inputs
		d1_trig_i = 0;
		d1_pwr_i = 0;
		d2_trig_i = 0;
		d2_pwr_i = 0;
		d3_trig_i = 0;
		d3_pwr_i = 0;
		d4_trig_i = 0;
		d4_pwr_i = 0;
		rsv_trig_db_i = 0;
		l1_mask_i = 0;
		fclk_i = 0;
		sclk_i = 0;
		sce_i = 0;
		l2_mask_i = 0;
		l3_mask_i = 0;
		l4_mask_i = 0;
		rst_i = 0;
		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		@(posedge fclk_i);
		d1_pwr_i = 8'hFF;
		rsv_trig_db_i = 2'b00;
		#50;
		d1_trig_i[3:0] = 4'b1111; #10 d1_trig_i[3:0] = 4'b0000;
		#50;
		d1_trig_i[1] = 1; #10 d1_trig_i[1] = 0;
		#50;
		d1_trig_i[2] = 1; #10 d1_trig_i[2] = 0;
		#50;
		d1_trig_i[3] = 1; #10 d1_trig_i[3] = 0;
		#50;
		d1_trig_i[4] = 1; #10 d1_trig_i[4] = 0;
		#50;
		d1_trig_i[5] = 1; #10 d1_trig_i[5] = 0;
		#50;
		d1_trig_i[6] = 1; #10 d1_trig_i[6] = 0;
		#50;
		d1_trig_i[7] = 1; #10 d1_trig_i[7] = 0;

		
	end
      
endmodule

