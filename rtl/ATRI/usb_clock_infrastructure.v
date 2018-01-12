`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module for generating xIFCLK from IFCLK for a USB PHY.
//////////////////////////////////////////////////////////////////////////////////
module usb_clock_infrastructure(
			input IFCLK,
			output xIFCLK
    );

	parameter IFCLK_PS = -98;

	wire LOCKED;
	wire [7:0] STATUS;
	wire IFCLK_deskew_to_BUFG;
	wire IFCLK_to_BUFG;
	wire IFCLK_in;
	IBUFG ifclk_ibufg(.I(IFCLK),.O(IFCLK_to_BUFG));
	BUFG ifclk_bufg(.I(IFCLK_to_BUFG),.O(IFCLK_in));

	reg dcm_reset_done = 0;
	reg [3:0] dcm_reset_count = 4'b0000;
	always @(posedge IFCLK_in) begin
		if (!dcm_reset_done)
			dcm_reset_count <= dcm_reset_count + 1;
	end
	always @(posedge IFCLK_in) begin
		if (dcm_reset_count == 4'hF) dcm_reset_done <= 1;
	end

	// We have to insert a DCM here to deskew IFCLK. Timing to the USB bridge is way, way
	// way too tight.
	
	// We also need to advance the clock more than the deskew allows. 8 ns should be good.
	// This is ~98/256ths.
	DCM #(
		.CLKDV_DIVIDE(2.0), // Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
								  // 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
		.CLKFX_DIVIDE(1), // Can be any integer from 1 to 32
		.CLKFX_MULTIPLY(4), // Can be any integer from 2 to 32
		.CLKIN_DIVIDE_BY_2("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
		.CLKIN_PERIOD(20.83), // Specify period of input clock
		.CLKOUT_PHASE_SHIFT("FIXED"), // Specify phase shift of NONE, FIXED or VARIABLE
		.CLK_FEEDBACK("1X"), // Specify clock feedback of NONE, 1X or 2X
		.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"), // SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or
		// an integer from 0 to 15
		.DLL_FREQUENCY_MODE("LOW"), // HIGH or LOW frequency mode for DLL
		.DUTY_CYCLE_CORRECTION("TRUE"), // Duty cycle correction, TRUE or FALSE
		.PHASE_SHIFT(IFCLK_PS), // Amount of fixed phase shift from -255 to 255
		.STARTUP_WAIT("FALSE") // Delay configuration DONE until DCM LOCK, TRUE/FALSE
	) IFCLK_deskew_dcm (
		.CLK0(IFCLK_deskew_to_BUFG), // 0 degree DCM CLK output
		.CLK180(), // 180 degree DCM CLK output
		.CLK270(), // 270 degree DCM CLK output
		.CLK2X(), // 2X DCM CLK output
		.CLK2X180(), // 2X, 180 degree DCM CLK out
		.CLK90(), // 90 degree DCM CLK output
		.CLKDV(), // Divided DCM CLK out (CLKDV_DIVIDE)
		.CLKFX(), // DCM CLK synthesis out (M/D)
		.CLKFX180(), // 180 degree CLK synthesis out
		.LOCKED(LOCKED), // DCM LOCK status output
		.PSDONE(), // Dynamic phase adjust done output
		.STATUS(STATUS), // 8-bit DCM status bits output
		.CLKFB(IFCLK_deskew_to_BUFG), // DCM clock feedback
		.CLKIN(IFCLK_in), // Clock input (from IBUFG, BUFG or DCM)
		.PSCLK(1'b0), // Dynamic phase adjust clock input
		.PSEN(1'b0), // Dynamic phase adjust enable input
		.PSINCDEC(1'b0), // Dynamic phase adjust increment/decrement
		.RST(!dcm_reset_done) // DCM asynchronous reset input
	);
	BUFG xifclk_bufg(.I(IFCLK_deskew_to_BUFG),.O(xIFCLK));

endmodule
