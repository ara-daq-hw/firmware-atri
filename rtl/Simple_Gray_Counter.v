`timescale 1ns / 1ps
module Simple_Gray_Counter(
		CLK,
		CE,
		RST,
		Q
	);
	
	parameter WIDTH = 16;
	input CLK;
	input CE;
	input RST;
	output [WIDTH-1:0] Q;
	
	reg parity = 0;
	always @(posedge CLK or posedge RST) begin
		if (RST)
			parity <= 0;
		else if (CE)
			parity <= ~parity;
	end
	
	wire [WIDTH-1:0] cell_Q_o;
	wire [WIDTH-1:0] cell_Z_o;
	
	generate
		genvar i;
		for (i=0;i<WIDTH;i = i+1) begin : CELLS
			if (i == 0) begin : CELL_ZERO
				Simple_Gray_Counter_Cell cell_zero(.Q_i(1'b1),.Z_i(1'b1),.parity(parity),.C(CLK),.enable(CE),.up_n_dn(1'b1),
															  .rst(RST),.Q_o(cell_Q_o[i]));
			end else if (i==1) begin : CELL_ONE
				Simple_Gray_Counter_Cell cell_one(.Q_i(cell_Q_o[i-1]),.Z_i(1'b1),.parity(~parity),.C(CLK),.enable(CE),.up_n_dn(1'b1),
															 .rst(RST),.Q_o(cell_Q_o[i]),.Z_o(cell_Z_o[i]));
			end else if (i==WIDTH-1) begin : CELL_MSB
				Simple_Gray_Counter_Cell cell_msb(.Q_i(1'b1),.Z_i(cell_Z_o[i-1]),.parity(~parity),.C(CLK),.enable(CE),.up_n_dn(1'b1),
															 .rst(RST),.Q_o(cell_Q_o[i]));
			end else begin : CELL_BODY
				Simple_Gray_Counter_Cell cell_body(.Q_i(cell_Q_o[i-1]),.Z_i(cell_Z_o[i-1]),.parity(~parity),.C(CLK),.enable(CE),.up_n_dn(1'b1),
															  .rst(RST),.Q_o(cell_Q_o[i]),.Z_o(cell_Z_o[i]));
			end
		end
	endgenerate
	
	assign Q = cell_Q_o;
endmodule
