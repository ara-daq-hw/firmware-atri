`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Blatantly stolen from fpga4fun.com/CrossClockDomain3.html
//
// Task synchronizer: Module in clkA domain asserts req, module in
// clkB domain asserts ack, busy is held until clkB domain can accept
// another req.
//
//////////////////////////////////////////////////////////////////////////////////
module task_sync(
    input clkA,
    input clkB,
    input req_clkA,
    output req_clkB,
    output ack_clkA,
    input ack_clkB,
    output busy_clkA,
    output busy_clkB
    );

	reg FlagToggle_clkA = 0, FlagToggle_clkB = 0, Busyhold_clkB = 0;
	reg [2:0] SyncA_clkB = {3{1'b0}}, SyncB_clkA = {3{1'b0}};
	
	initial begin
		FlagToggle_clkA <= 0;
		Busyhold_clkB <= 0;
		SyncA_clkB <= 3'b000;
		SyncB_clkA <= 3'b000;
	end
	
	always @(posedge clkA) if (req_clkA && ~busy_clkA) FlagToggle_clkA <= ~FlagToggle_clkA;
	always @(posedge clkB) SyncA_clkB <= {SyncA_clkB[1:0], FlagToggle_clkA};
	assign req_clkB = ^SyncA_clkB[2:1];
	assign busy_clkB = req_clkB | Busyhold_clkB;
	always @(posedge clkB) Busyhold_clkB <= ~ack_clkB & busy_clkB;
	always @(posedge clkB) if (busy_clkB & ack_clkB) FlagToggle_clkB <= FlagToggle_clkA;
	always @(posedge clkA) SyncB_clkA <= {SyncB_clkA[1:0], FlagToggle_clkB};
	assign busy_clkA = FlagToggle_clkA ^ SyncB_clkA[2];
	assign ack_clkA = ^SyncB_clkA[2:1];
endmodule
