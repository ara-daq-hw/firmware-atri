`timescale 1ns / 1ps
//% @brief Parameterized pipelined compare tree.
module par_compare_tree(
		vector_i,
		max_o,
		clk_i
    );

	//% Width of each element.
	parameter WIDTH = 4;
	//% Number of elements.
	parameter ELEMENTS = 30;
	//% Input vector (concatenated).
	input [WIDTH*ELEMENTS-1:0] vector_i;
	//% Maximum element output.
	output [WIDTH-1:0] max_o;
	//% System clock. Fully pipelined design, one element per clock.
	input clk_i;
	
	`include "clogb2.vh"
	//% Number of stages needed. This is clogb2(ELEMENTS-1) because clogb2(x) is actually clogb2(x+1).
	parameter NSTAGE = clogb2(ELEMENTS-1);
	parameter TEST = nelem(1, ELEMENTS);
	parameter TEST2 = nelem(2, ELEMENTS);
	parameter TEST3 = nelem(3, ELEMENTS);
	function integer nelem;
		input integer stage;
		input integer max_elem;
		begin
			if (stage == 0) begin
				nelem = max_elem;
			end else begin
				// Divide it by 2.
				nelem = nelem(stage-1,max_elem)>>1;
				// Take the remainder.
				nelem = nelem + (nelem(stage-1,max_elem) % 2);
			end
		end
	endfunction
	
	//% The comparison tree will be connected using these wires. Stage 0 is the input data.
	wire [WIDTH-1:0] compare_tree[NSTAGE:0][ELEMENTS-1:0];
	generate
		genvar i,j,k;
		for (i=0;i<ELEMENTS;i=i+1) begin : EX
			assign compare_tree[0][i] = vector_i[i*WIDTH +: WIDTH];
		end
		for (j=1;j<=NSTAGE;j=j+1) begin : ST
			reg [WIDTH-1:0] stage_elements[nelem(j,ELEMENTS)-1:0];
			for (k=0;k<nelem(j,ELEMENTS);k=k+1) begin : LP
				// Figure out if the previous stage has enough elements.
				if (2*k+1 < nelem(j-1,ELEMENTS)) begin : CMP
					//% Max of two previous stage values.
					wire [WIDTH-1:0] max;
					//% Comparator. This is here to make the schematic readable for checking.
					par_compare #(.WIDTH(WIDTH),.TYPE("GREATER"))
						comp(.A(compare_tree[j-1][2*k]),.B(compare_tree[j-1][2*k+1]),
							  .O(max));
					always @(posedge clk_i) begin : MX
						stage_elements[k] <= max;
					end
				end else begin : DUM
					always @(posedge clk_i) begin : SR
						stage_elements[k] <= compare_tree[j-1][2*k];
					end
				end
				// Fill the compare tree.
				assign compare_tree[j][k] = stage_elements[k];
			end
		end
	endgenerate
	assign max_o = (compare_tree[NSTAGE][0]);
endmodule

module par_compare(A, B, O);
	parameter WIDTH = 4;
	parameter TYPE = "GREATER";
	input [WIDTH-1:0] A;
	input [WIDTH-1:0] B;
	output [WIDTH-1:0] O;
	generate
		if (TYPE == "GREATER") begin : GR
			assign O = (A > B) ? A : B;
		end else if (TYPE == "LESSER") begin : LS
			assign O = (A < B) ? A : B;
		end
	endgenerate
endmodule
