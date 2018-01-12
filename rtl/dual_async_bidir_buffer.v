`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Dual, asynchronous, bidirectional 8-bit buffer from a single block RAM.
//           +--------+
//      A  <-|        |
//         ->|        |-> Y
//      B  <-|        |<-
//         ->|        |
//           |        |
// clk_AB_i <|        |> clk_Y_i
//           +--------
//
// A and B have to have a 1/2 duty cycle on clk_AB.
//
// When not empty, the FIFOs read ahead by one, storing the old value
// in a data register. This just compensates for the one-cycle delay in reading
// since if a read comes in off-cycle, you need to wait one cycle before reading it,
// and obviously a two-cycle latency won't work without a buffer when reads can 
// occur every 2 cycles.
// This means that the FIFOs are effectively 513 words deep.
//
// For writes from A/B to Y, the data is just held if it occurs off-cycle and
// written during its next assigned slot. This is just because PicoBlaze data
// is only valid when the write strobe is high.
//////////////////////////////////////////////////////////////////////////////////
module dual_async_bidir_buffer(
		input rst_i,

		input clk_AB_i,
		// A-side interface
		input [7:0] A_dat_i,
		output [7:0] A_dat_o,
		input A_rd_i,
		input A_wr_i,
		output reg A_empty_o,
		output A_full_o,
		// B-side interface
		input [7:0] B_dat_i,
		output [7:0] B_dat_o,
		input B_rd_i,
		input B_wr_i,
		output reg B_empty_o,
		output B_full_o,
		// Y-side interface
		input clk_Y_i,
		input Y_sel_i,
		input [7:0] Y_dat_i,
		output [7:0] Y_dat_o,
		input Y_rd_i,
		input Y_wr_i,
		output Y_empty_o,
		output Y_full_o,
		// 8-bit version of number of bytes free in the buffer selected by Y_sel_i.
		// If greater than 255, 255 is reported.
		output [7:0] Y_count_o
    );

	localparam FIFO_SEL_A = 0;
	localparam FIFO_SEL_B = 1;
	reg fifo_selector = FIFO_SEL_A;
	always @(posedge clk_AB_i) begin
		if (fifo_selector == FIFO_SEL_A)
			fifo_selector <= FIFO_SEL_B;
		else
			fifo_selector <= FIFO_SEL_A;
	end


	localparam Y_SEL_A = 0;
	localparam Y_SEL_B = 1;

	// Demux the inputs from Y, mux the empty/full outputs
	wire AY_rd = (Y_rd_i && Y_sel_i == Y_SEL_A);
	wire YA_wr = (Y_wr_i && Y_sel_i == Y_SEL_A);
	wire BY_rd = (Y_rd_i && Y_sel_i == Y_SEL_B);
	wire YB_wr = (Y_wr_i && Y_sel_i == Y_SEL_B);

	// For Y: empty = (A/B) -> Y, read = (A/B) -> Y
	//        full = Y -> (A/B), write = Y -> (A/B)
	wire AY_empty; 										//% A->Y FIFO empty
	wire YA_full;											//% Y->A FIFO full
	wire BY_empty;											//% B->Y FIFO empty
	wire YB_full;											//% Y->B FIFO full
	assign Y_empty_o = (Y_sel_i) ? AY_empty : BY_empty;
	assign Y_full_o = (Y_sel_i) ? YA_full : YB_full;

	// For A: empty = Y->A, read = Y->A
	//        full = A->Y, write = A->Y
	reg A_write = 0;
	wire AY_wr;
	wire YA_empty;											//% Y->A FIFO empty
	reg YA_was_empty = 1;								//% Y->A FIFO was empty 
	wire AY_full;											//% A->Y FIFO full

	initial A_empty_o <= 1;
	always @(posedge clk_AB_i or posedge rst_i) begin
		if (rst_i) A_empty_o <= 1;
		else begin
			// Going from empty to not empty only when preread is done.
			if (A_empty_o) begin
				if (fifo_selector == FIFO_SEL_A && !YA_was_empty)
					A_empty_o <= 0;
			end else begin
				// Going from not empty to empty immediately on a read when
				// the pointer math indicates that the FIFO is empty.
				if (A_rd_i && YA_empty)
					A_empty_o <= 1;
			end
		end
	end	
	wire YA_rd = (!YA_empty && YA_was_empty && fifo_selector == FIFO_SEL_A) || (A_rd_i && !YA_empty);

	// For B: empty = Y->B, read = Y->B
	//        full = B->Y, write = B->Y
	reg B_write = 0;
	wire BY_wr;
	wire YB_empty;											//% Y->B FIFO empty
	reg YB_was_empty = 1;
	wire BY_full;											//% B->Y FIFO full
	wire YB_rd = (!YB_empty && YB_was_empty && fifo_selector == FIFO_SEL_B) || (B_rd_i && !YB_empty);

	initial B_empty_o <= 1;
	always @(posedge clk_AB_i) begin
		if (rst_i) B_empty_o <= 1;
		// Going from empty to not empty only when preread is done.
		else begin
			if (B_empty_o) begin
				if (fifo_selector == FIFO_SEL_B && !YB_was_empty)
					B_empty_o <= 0;
			end else begin
				// Going from not empty to empty immediately on a read when
				// the pointer math indicates that the FIFO is empty.
				if (B_rd_i && YB_empty)
					B_empty_o <= 1;
			end
		end
	end

	// We need 8 total address counters: 2 for each FIFO.
	wire [8:0] pWriteYtoA, pReadYtoA;
	wire [8:0] pWriteAtoY, pReadAtoY;
	wire [8:0] pWriteYtoB, pReadYtoB;
	wire [8:0] pWriteBtoY, pReadBtoY;

	wire [8:0] rdYAsub;
	wire [8:0] rdYBsub;
	wire [8:0] YA_count;
	wire [8:0] YB_count;
	reg [7:0] Y_count_out = {8{1'b0}};
	always @(posedge clk_Y_i) begin
		if (Y_sel_i == Y_SEL_A) begin
			if (YA_count[8])
				Y_count_out <= {8{1'b1}};
			else
				Y_count_out <= YA_count[7:0];
		end else begin
			if (YB_count[8])
				Y_count_out <= {8{1'b1}};
			else
				Y_count_out <= YB_count[7:0];
		end
	end
	assign Y_count_o = Y_count_out;
	
	wire AY_wr_incr = (AY_wr && !AY_full && fifo_selector == FIFO_SEL_A);
	wire BY_wr_incr = (BY_wr && !BY_full && fifo_selector == FIFO_SEL_B);

	// For the Y->A FIFO, a write comes from Y, a read comes from A
	dual_async_bidir_buffer_gray_counter pWrYtoA(.O(pWriteYtoA),.EN(YA_wr && !YA_full),.RST(rst_i),
							  .CLK(clk_Y_i),
							  .B_sub(rdYAsub),
							  .Y_sub(YA_count)); // from Y
	dual_async_bidir_buffer_gray_counter pRdYtoA(.O(pReadYtoA),.EN(YA_rd && !YA_empty),.RST(rst_i),
							  .CLK(clk_AB_i)); // from A
	dual_async_bidir_buffer_fifo_status_register #(.ADDRESS_WIDTH(9)) YtoA_status(.pWr_i(pWriteYtoA),.pRd_i(pReadYtoA),.rst_i(rst_i),
																		 .wr_clk_i(clk_Y_i),.rd_clk_i(clk_AB_i),
																		 .full_o(YA_full),.empty_o(YA_empty),
																		 .pRd_in_Wr_o(rdYAsub));
	// For the Y->B FIFO, a write comes from Y, a read comes from B
	dual_async_bidir_buffer_gray_counter pWrYtoB(.O(pWriteYtoB),.EN(YB_wr && !YB_full),.RST(rst_i),
							  .CLK(clk_Y_i),
							  .B_sub(rdYBsub),
							  .Y_sub(YB_count)); // from Y
	dual_async_bidir_buffer_gray_counter pRdYtoB(.O(pReadYtoB),.EN(YB_rd && !YB_empty),.RST(rst_i),
							  .CLK(clk_AB_i)); // from A
	dual_async_bidir_buffer_fifo_status_register #(.ADDRESS_WIDTH(9)) YtoB_status(.pWr_i(pWriteYtoB),.pRd_i(pReadYtoB),.rst_i(rst_i),
																		 .wr_clk_i(clk_Y_i),.rd_clk_i(clk_AB_i),
																		 .full_o(YB_full),.empty_o(YB_empty),
																		 .pRd_in_Wr_o(rdYBsub));
	// For the A->Y FIFO, a write comes from A, a read comes from Y
	dual_async_bidir_buffer_gray_counter pWrAtoY(.O(pWriteAtoY),.EN(AY_wr_incr),.RST(rst_i),
							  .CLK(clk_AB_i));
	dual_async_bidir_buffer_gray_counter pRdAtoY(.O(pReadAtoY),.EN(AY_rd && !AY_empty),.RST(rst_i),
							  .CLK(clk_Y_i));
	dual_async_bidir_buffer_fifo_status_register #(.ADDRESS_WIDTH(9)) AtoY_status(.pWr_i(pWriteAtoY),.pRd_i(pReadAtoY),.rst_i(rst_i),
																		 .wr_clk_i(clk_AB_i),.rd_clk_i(clk_Y_i),
																		 .full_o(AY_full),.empty_o(AY_empty));

	// For the B->Y FIFO, a write comes from B, a read comes from Y
	dual_async_bidir_buffer_gray_counter pWrBtoY(.O(pWriteBtoY),.EN(BY_wr_incr),.RST(rst_i),
							  .CLK(clk_AB_i));
	dual_async_bidir_buffer_gray_counter pRdBtoY(.O(pReadBtoY),.EN(BY_rd && !BY_empty),.RST(rst_i),
							  .CLK(clk_Y_i));
	dual_async_bidir_buffer_fifo_status_register #(.ADDRESS_WIDTH(9)) BtoY_status(.pWr_i(pWriteBtoY),.pRd_i(pReadBtoY),.rst_i(rst_i),
																		 .wr_clk_i(clk_AB_i),.rd_clk_i(clk_Y_i),
																		 .full_o(BY_full),.empty_o(BY_empty));

	wire bram_write = (fifo_selector == FIFO_SEL_A) ? AY_wr : BY_wr;
	
	// was_empty logic		
	always @(posedge clk_AB_i or posedge rst_i) begin : YA_WAS_EMPTY_LOGIC
		if (rst_i) begin
			YA_was_empty <= 1;
		end else if (!YA_was_empty && A_rd_i && YA_empty)
			YA_was_empty <= 1;
		else if (!YA_empty && fifo_selector == FIFO_SEL_A)
			YA_was_empty <= 0;
	end
	always @(posedge clk_AB_i or posedge rst_i) begin : YB_WAS_EMPTY_LOGIC
		if (rst_i) begin
			YB_was_empty <= 1;
		end else if (!YB_was_empty && B_rd_i && YB_empty)
			YB_was_empty <= 1;
		else if (!YB_empty && fifo_selector == FIFO_SEL_B && !bram_write)
			YB_was_empty <= 0;
	end
	
	always @(posedge clk_AB_i) begin
		if (fifo_selector == FIFO_SEL_B)
			A_write <= A_wr_i;
		else
			A_write <= 0;
	end
	always @(posedge clk_AB_i) begin
		if (fifo_selector == FIFO_SEL_A)
			B_write <= B_wr_i;
		else
			B_write <= 0;
	end
	wire [1:0] bram_high_address_bits = {fifo_selector, bram_write};
	reg [8:0] bram_low_address_bits = {9{1'b0}};
	always @(*) begin
		if (fifo_selector == FIFO_SEL_A) begin
			if (bram_write)
				bram_low_address_bits <= pWriteAtoY;
			else
				bram_low_address_bits <= pReadYtoA;
		end else begin
			if (bram_write)
				bram_low_address_bits <= pWriteBtoY;
			else
				bram_low_address_bits <= pReadYtoB;
		end
	end
	wire [10:0] bram_address = {bram_high_address_bits,bram_low_address_bits};
	reg [7:0] A_in_data = {8{1'b0}};
	reg [7:0] B_in_data = {8{1'b0}};
	wire [7:0] bram_data_in = (fifo_selector == FIFO_SEL_A) ? A_in_data : B_in_data;
	wire [7:0] bram_data_out;
	// Y->A data storage
	reg YA_rd_delayed = 0;
	always @(posedge clk_AB_i) begin
		YA_rd_delayed <= YA_rd;
	end
	reg [7:0] Y_to_A_data = {8{1'b0}};
	always @(posedge clk_AB_i) begin
		if (fifo_selector == FIFO_SEL_B)
			if (YA_rd || YA_rd_delayed)
				Y_to_A_data <= bram_data_out;
	end

	reg YB_rd_delayed = 0;
	always @(posedge clk_AB_i) begin
		YB_rd_delayed <= YB_rd;
	end
	reg [7:0] Y_to_B_data = {8{1'b0}};
	always @(posedge clk_AB_i) begin
		if (fifo_selector == FIFO_SEL_A)
			if (YB_rd || YB_rd_delayed)
				Y_to_B_data <= bram_data_out;
	end

	// Hold for writes
	reg [7:0] A_hold_data = {8{1'b0}};
	reg [7:0] B_hold_data = {8{1'b0}};
	reg A_wr_delayed = 0;
	reg B_wr_delayed = 0;
	assign AY_wr = (A_wr_i || A_wr_delayed);
	assign BY_wr = (B_wr_i || B_wr_delayed);
	always @(posedge clk_AB_i) begin
		A_wr_delayed <= A_wr_i;
	end
	always @(posedge clk_AB_i) begin
		B_wr_delayed <= B_wr_i;
	end
	always @(posedge clk_AB_i) begin
		if (A_wr_i)
			A_hold_data <= A_dat_i;
	end
	always @(posedge clk_AB_i) begin
		if (B_wr_i)
			B_hold_data <= B_dat_i;
	end
	always @(*) begin
		if (A_wr_i)
			A_in_data <= A_dat_i;
		else
			A_in_data <= A_hold_data;
	end
	always @(*) begin
		if (B_wr_i)
			B_in_data <= B_dat_i;
		else
			B_in_data <= B_hold_data;
	end

	wire [1:0] y_bram_high_address_bits = {Y_sel_i, ~Y_wr_i};
	reg [8:0] y_bram_low_address_bits = {9{1'b0}};
	always @(*) begin
		if (Y_sel_i == Y_SEL_A) begin
			if (Y_wr_i)
				y_bram_low_address_bits <= pWriteYtoA;
			else
				y_bram_low_address_bits <= pReadAtoY;
		end else begin
			if (Y_wr_i)
				y_bram_low_address_bits <= pWriteYtoB;
			else
				y_bram_low_address_bits <= pReadBtoY;
		end
	end
	wire [10:0] y_bram_address = {y_bram_high_address_bits,y_bram_low_address_bits};
	// Port A is AB, port B is Y
	RAMB16_S9_S9 #(.SIM_COLLISION_CHECK("GENERATE_X_ONLY"),.WRITE_MODE_A("WRITE_FIRST"),.WRITE_MODE_B("WRITE_FIRST")) 
					 bram(.WEA(bram_write),.ENA(1'b1),.SSRA(1'b0),.CLKA(clk_AB_i),
							.ADDRA(bram_address),.DIA(bram_data_in),.DIPA(1'b0),.DOA(bram_data_out),
							.WEB(Y_wr_i),.ENB(1'b1),.SSRB(1'b0),.CLKB(clk_Y_i),
							.ADDRB(y_bram_address),.DIB(Y_dat_i),.DIPB(1'b0),.DOB(Y_dat_o));
	assign A_dat_o = Y_to_A_data;
	assign B_dat_o = Y_to_B_data;
	assign A_full_o = AY_full;
	assign B_full_o = BY_full;
endmodule

module dual_async_bidir_buffer_gray_counter 
		#(parameter   COUNTER_WIDTH = 9)
		 (
			output reg  [COUNTER_WIDTH-1:0]    O,  //'Gray' code count output.
			input wire                         EN,  //Count enable.
			input wire                         RST,   //Count reset. 
			input wire                         CLK,
			input [COUNTER_WIDTH-1:0]			  B_sub, // Gray input to subtract from the binary count.
			output [COUNTER_WIDTH-1:0]			  Y_sub // Binary out.
		  );

			reg    [COUNTER_WIDTH-1:0]         BinaryCount = {COUNTER_WIDTH{1'b0}} + 1;
			initial begin
				O <= {COUNTER_WIDTH{1'b0}};
			end
 
			always @ (posedge CLK or posedge RST) begin
				if (RST) begin
					BinaryCount   <= {COUNTER_WIDTH{1'b 0}} + 1;  //Gray count begins @ '1' with
					O <= {COUNTER_WIDTH{1'b 0}};      				 // first 'EN'.
				end
				else if (EN) begin
					BinaryCount   <= BinaryCount + 1;
					O <= {BinaryCount[COUNTER_WIDTH-1],
							BinaryCount[COUNTER_WIDTH-2:0] ^ BinaryCount[COUNTER_WIDTH-1:1]};
				end
			end

			wire [COUNTER_WIDTH-1:0] B_sub_binary;
			Generic_Gray_to_Binary #(.WIDTH(COUNTER_WIDTH),.LATENCY(0))
				B_to_binary(.G_in(B_sub),.B_out(B_sub_binary),.CONVERT(1'b1),.CE(1'b1),.CLK(CLK));
			// This is off by 1: don't care, as it's in the right direction (it's
			// pessimistic.)
			assign Y_sub = B_sub_binary - BinaryCount;
endmodule

// see "Simulation and Synthesis Techniques for Asynchronous FIFO Design with Asynchronous
//      Pointer Comparisons."
module dual_async_bidir_buffer_fifo_status_register
		#(parameter ADDRESS_WIDTH = 9)
		 (
			input [ADDRESS_WIDTH-1:0] pWr_i,
			input [ADDRESS_WIDTH-1:0] pRd_i,
			input wr_clk_i,
			input rd_clk_i,
			output reg full_o,
			output reg empty_o,
			input rst_i,
			output [8:0] pRd_in_Wr_o
		 );
		 
			reg Status = 0;
			wire Going_Full = (pWr_i[ADDRESS_WIDTH-2] ~^ pRd_i[ADDRESS_WIDTH-1]) & (pWr_i[ADDRESS_WIDTH-1]^pRd_i[ADDRESS_WIDTH-2]);
			wire Going_Empty = (pWr_i[ADDRESS_WIDTH-2] ^ pRd_i[ADDRESS_WIDTH-1]) & (pWr_i[ADDRESS_WIDTH-1] ~^ pRd_i[ADDRESS_WIDTH-2]);
			
			reg [ADDRESS_WIDTH-1:0] pWr_in_Rd_Domain[1:0];
			reg [ADDRESS_WIDTH-1:0] pRd_in_Wr_Domain[1:0];
			initial begin
				pWr_in_Rd_Domain[0] <= {ADDRESS_WIDTH{1'b0}};
				pWr_in_Rd_Domain[1] <= {ADDRESS_WIDTH{1'b0}};
				pRd_in_Wr_Domain[0] <= {ADDRESS_WIDTH{1'b0}};
				pRd_in_Wr_Domain[1] <= {ADDRESS_WIDTH{1'b0}};
			end
			// Synchronize the read/write pointers. Two-stage synchronizer.
			always @(posedge wr_clk_i) begin
				pRd_in_Wr_Domain[0] <= pRd_i;
				pRd_in_Wr_Domain[1] <= pRd_in_Wr_Domain[0];
			end

			always @(posedge rd_clk_i) begin
				pWr_in_Rd_Domain[0] <= pWr_i;
				pWr_in_Rd_Domain[1] <= pWr_in_Rd_Domain[0];
			end
			
			wire Addresses_Equal_in_Wr_Domain = (pWr_i == pRd_in_Wr_Domain[1]);
			wire Addresses_Equal_in_Rd_Domain = (pRd_i == pWr_in_Rd_Domain[1]);

			always @(Going_Full or Going_Empty or rst_i) begin
				if (Going_Empty | rst_i)
					Status <= 0;
				else if (Going_Full)
					Status <= 1;
			end
			wire Set_Full = (Status & Addresses_Equal_in_Wr_Domain);
			always @(posedge wr_clk_i or posedge Set_Full) begin
				if (Set_Full)
					full_o <= 1;
				else
					full_o <= 0;
			end
			wire Set_Empty = (!Status & Addresses_Equal_in_Rd_Domain);
			always @(posedge rd_clk_i or posedge Set_Empty) begin
				if (Set_Empty)
					empty_o <= 1;
				else
					empty_o <= 0;
			end

			assign pRd_in_Wr_o = pRd_in_Wr_Domain[1];
endmodule
