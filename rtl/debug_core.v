`timescale 1ns / 1ps
//% @file debug_core.v Contains debug_core, the main debugging wrapper.

//% @brief Wrapper for the ChipScope ICON and ILAs.
//%
//% debug_core is intended to cleanup the atri_core top level module
//% and move the bajillion instances of the ICON/ILA to a sane setup.
module debug_core(
		input phy_clk_i,
		input phy_debug_clk_i,
		input irs_clk_i,
		input pcie_clk_i,
		input [52:0] phy_debug_i,
		input [52:0] pc_debug_i,
		input [52:0] pcie_debug_i,
		input [52:0] i2c_debug_i,
		input [52:0] irs_debug_i,
		input [52:0] trig_debug_i,
		input [52:0] irsraw_debug_i,
		output [3:0] vio_debug_o
    );
	 
	parameter DEBUG = "YES";

	wire ila0_clk;
	wire ila1_clk;
	wire [52:0] ila0_debug;
	wire [52:0] ila1_debug;
	wire [7:0] vio_debug;
	
	reg [52:0] trig_debug = {53{1'b0}};
	reg [52:0] irs_debug = {53{1'b0}};
	reg [52:0] mux_debug = {53{1'b0}};
	always @(posedge irs_clk_i) begin
		if (vio_debug[7]) trig_debug <= trig_debug_i;
		if (!vio_debug[7]) irs_debug <= irs_debug_i;
		if (vio_debug[7]) mux_debug <= trig_debug;
		else mux_debug <= irs_debug;
	end
/*
	wire [7:0] vio_sel;

	localparam [2:0] DEBUG_PC = 3'b000;
	localparam [2:0] DEBUG_I2C = 3'b001;
	localparam [2:0] DEBUG_IRS = 3'b100;
	localparam [2:0] DEBUG_TRIG = 3'b101;
	localparam [2:0] DEBUG_IRSRAW = 3'b110;
	
	reg [52:0] phyclk_mux = {53{1'b0}};
	reg [1:0] phyclk_sel = {2{1'b0}};
	always @(posedge phy_clk_i) phyclk_sel <= 

	assign vio_debug_o = vio_sel[7:5];
	// We have bucket-tons of resources available.
	// There's no real reason NOT to make the debug dynamically switchable.
	reg [47:0] pc_debug = {48{1'b0}};
	always @(posedge phy_clk_i) pc_debug <= pc_debug_i;
	
	reg [47:0] i2c_debug = {48{1'b0}};
	always @(posedge phy_clk_i) i2c_debug <= i2c_debug_i;
	
	reg [47:0] irs_debug = {48{1'b0}};
	always @(posedge irs_clk_i) irs_debug <= irs_debug_i;
	
	reg [47:0] trig_debug = {48{1'b0}};
	always @(posedge irs_clk_i) trig_debug <= trig_debug_i;
	
	wire debug_clk;
	BUFGMUX debug_clk_mux(.I0(phy_clk_i),.I1(irs_clk_i),.S(vio_sel[4]),.O(debug_clk));

	wire [35:0] CONTROL2;
	
*/
	wire [35:0] CONTROL0;
	wire [35:0] CONTROL1;
	wire [35:0] CONTROL2;
	
	// ILA0 sticks with the PHY debug inputs.
	assign ila0_clk = phy_debug_clk_i;
	assign ila0_debug = phy_debug_i;

	// ILA1 gets assigned based on the DEBUG parameter.
	generate
		if (DEBUG == "YES" ) begin : DBGMUX
			assign ila1_clk = irs_clk_i;
			assign ila1_debug = mux_debug;
		end else if (DEBUG == "PC") begin : DBGPC
			assign ila1_clk = phy_clk_i;
			assign ila1_clk = pc_debug_i;
		end else if (DEBUG == "I2C") begin : DBGI2C
			assign ila1_clk = phy_clk_i;
			assign ila1_debug = i2c_debug_i;
		end else if (DEBUG == "IRS") begin : DBGIRS
			assign ila1_clk = irs_clk_i;
			assign ila1_debug = irs_debug_i;
		end else if (DEBUG == "TRIG") begin : DBGTRIG
			assign ila1_clk = irs_clk_i;
			assign ila1_debug = trig_debug_i;
		end else if (DEBUG == "IRSRAW") begin : DBGIRSRAW
			assign ila1_clk = irs_clk_i;
			assign ila1_debug = irsraw_debug_i;
		end else if (DEBUG == "PCIE") begin : DBPCIE
			assign ila1_clk = pcie_clk_i;
			assign ila1_debug = pcie_debug_i;
		end
		if (DEBUG != "NO") begin : CS_CORES
			chipscope_icon icon(.CONTROL0(CONTROL0), .CONTROL1(CONTROL1),.CONTROL2(CONTROL2));
			chipscope_ila ila0(.CONTROL(CONTROL0),.CLK(ila0_clk),.TRIG0(ila0_debug));
			chipscope_ila ila1(.CONTROL(CONTROL1),.CLK(ila1_clk),.TRIG0(ila1_debug));
			chipscope_vio vio0(.CONTROL(CONTROL2),.ASYNC_OUT(vio_debug));
		end
	endgenerate

	assign vio_debug_o = vio_debug[3:0];
endmodule
