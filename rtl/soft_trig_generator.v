`timescale 1ns / 1ps
//% @brief Generates soft triggers based on the control register.
module soft_trig_generator(
		ctrl_i,
		ctrlclk_i,
		trigclk_i,
		slow_ce_i,
		trig_o		
    );

	input [7:0] ctrl_i;
	input ctrlclk_i;
	input trigclk_i;
	input slow_ce_i;
	output trig_o;
	
	wire [3:0] delay_count = ctrl_i[7:4];
	wire [2:0] trig_count = ctrl_i[3:1];
	wire trig_go = ctrl_i[0];
	
	reg [4:0] delay_counter = {4{1'b0}};
	reg [2:0] trig_counter = {3{1'b0}};
	
	wire trig_flag;
	SYNCEDGE_R trig_flag_gen(.I(trig_go),.O(trig_flag),.CLK(ctrlclk_i));
	reg trig_busy = 0;
	always @(posedge ctrlclk_i) begin
		if ((trig_counter == trig_count) && (delay_counter > delay_count)) trig_busy <= 0;
		else if (trig_flag) trig_busy <= 1;
	end

	// This is naturally a flag, because when delay_counter exceeds delay_count,
	// it resets delay_counter (so it can no longer exceed it).
	wire trigger = (trig_busy && (delay_counter > delay_count));
	reg trig_flag_to_trigclk = 0;
	always @(posedge ctrlclk_i) 
		trig_flag_to_trigclk <= trigger;
	
	always @(posedge ctrlclk_i) begin
		if (trig_busy) begin
			if (delay_counter > delay_count) delay_counter <= {4{1'b0}};
			else if (slow_ce_i) delay_counter <= delay_counter + 1;
		end else
			delay_counter <= {4{1'b0}};
	end
	
	always @(posedge ctrlclk_i) begin
		if (trig_busy) begin
			if (trigger) trig_counter <= trig_counter + 1;
		end else
			trig_counter <= {3{1'b0}};
	end

	flag_sync trig_flag_sync(.in_clkA(trig_flag_to_trigclk),.out_clkB(trig_o),
									 .clkA(ctrlclk_i),.clkB(trigclk_i));

endmodule
