module nofx2_event_buffer( input wr_clk,
			   input [15:0] dat_i,
			   input wr_i,
			   output full_o,
			   output [15:0] count_o,
			   input rst_i,
			   output rst_ack_o,

			   input rd_clk,
			   output [31:0] dat_o,
			   input rd_i,
			   output empty_o,
				// DEBUGGING
				// DEBUGGING WORKS IN WR_CLK LAND - WE NEED TO SWITCH
				// THE PHY DEBUG FOR THIS
				// 3 BITS STATE
				// 16 BITS COUNTER
				// 1 BIT WR
				// 16 BITS DAT
				// 16 BITS COUNT
				// 1 BIT FIFO WR
				output [52:0] debug_o
				);

   // fill a 32-bit buffer with frame data
   // frame structure is always the same:
   // word 0: type
   // word 1: TOTAL length
   // so we just bounce
   // when we hit an odd number of words we just
   // write a dummy word, the software will
   // know because it'll pad the number of
   // subsequent reads after the header and just
   // lie about the delivered data
	//
   reg [15:0] 			  data_holding = {32{1'b0}};
	// aaaugh
	// I have NO IDEA HOW but SOMEHOW
	// the 16-bit words got BYTE SWAPPED going to
	// software. So the software is expecting these to be SWAPPED.
	// So we STUPIDLY SWAP THEM HERE. Note that it's ONLY THE BYTES IN THE WORDS,
	// NOT THE WORDS IN THE INT.
	// For instance for a single event at the beginning we might get
	// 4500
	// 080D
	// when this is written, data_holding is 4500, dat_i is 080D.
	// Ryan expects 45, 00, 08, 0D.
	// This then translates that to
	// 0x0D080045, which in x86 (little-endian) gets stored as above
   wire [31:0] 			  data_to_fifo = { dat_i[7:0], dat_i[15:8], data_holding[7:0], data_holding[15:8] };   
   
   reg [15:0] 			  nwords_remaining = {16{1'b0}};
   localparam FSM_BITS = 3;
   localparam [FSM_BITS-1:0] RESET = 0;
   localparam [FSM_BITS-1:0] RESET_COMPLETE = 1;
	localparam [FSM_BITS-1:0] RESET_WAIT = 2;
   localparam [FSM_BITS-1:0] IDLE = 3;
   localparam [FSM_BITS-1:0] LENGTH = 4;
   localparam [FSM_BITS-1:0] DATA_0 = 5;
   localparam [FSM_BITS-1:0] DATA_1 = 6;
   localparam [FSM_BITS-1:0] PAD_1 = 7;   
   reg [FSM_BITS-1:0] 		  state = RESET;

	// so effing stupid
	// in LENGTH and DATA_1 the write needs to be qualified on wr_i
	// The write in PAD_1 is forced.
   wire fifo_wr = ((state == LENGTH || state == DATA_1) && wr_i) ||
		   (state == PAD_1);   
   
   wire [15:0] 			  nwords_in = (state == LENGTH) ? ~dat_i : nwords_remaining;
	wire [15:0]				  nwords_addend = 16'h1;
   wire [16:0] 			  nwords_in_plus_one = nwords_in + nwords_addend;   
   
	// sigh, reset needs to be rising-edge flag, otherwise rst_i
	// will just hold us in reset.
	reg reset_rereg = 0;
	reg reset_flag = 0;
   wire 			  reset_delay;
   wire 			  reset_clear;   
   SRLC32E u_reset_delay(.D(state == RESET),.CE(1'b1),.CLK(wr_clk),
			 .A(5'd15),
			 .Q(reset_clear),
			 .Q31(reset_delay));
   // this will need a CC
   reg 				  reset_fifo = 0;	
   always @(posedge wr_clk) begin
		reset_rereg <= rst_i;
		reset_flag <= rst_i && !reset_rereg;
      reset_fifo <= (state == RESET && !reset_clear);
      
      if (reset_flag) state <= RESET;
      else begin 
	 case (state)
	   RESET: if (reset_delay) state <= RESET_COMPLETE;
	   RESET_COMPLETE: state <= RESET_WAIT;
		RESET_WAIT: if (!rst_i) state <= IDLE;
	   IDLE: if (wr_i) state <= LENGTH;
	   LENGTH: if (wr_i) state <= DATA_0;
	   DATA_0: if (wr_i) begin
	      if (nwords_in_plus_one[16]) state <= PAD_1;
	      else state <= DATA_1;	      
	   end
	   DATA_1: if (wr_i) begin
	      if (nwords_in_plus_one[16]) state <= IDLE;
	      else state <= DATA_0;
	   end
	   // the PAD_1 state is the only different one:
	   // here we capture again into data_holding if wr_i
	   // happens and skip IDLE (two back-to-back frames)
	   // so assume 
	   // dat_i   data_holding  output     output wr  state   nwords_remain
	   // 0xHEAD  X             0xHEADxxxx 0          IDLE    X
	   // 0x0001  0xHEAD        0x0001HEAD 1          LENGTH  X
	   // 0xDAT0  0xHEAD        0xDAT00001 0          DATA_0  FFFF
	   // 0xHEAD  0xDAT0        0xHEADDAT0 1          PAD_1   X
	   // 0xNWDS  0xHEAD        0xNWDSHEAD 1          LENGTH  X
	   // ...
	   // output_wr is 1 in LENGTH/DATA_1/PAD_1.
	   PAD_1: begin
	      if (wr_i) state <= LENGTH;
	      else state <= IDLE;
	   end	   
	 endcase // case (state)
      end // else: !if(rst_i)

      // as basic as this seems, this should work
      if (wr_i) nwords_remaining <= nwords_in_plus_one[15:0];
      // this _always_ happens each time, even if we only
      // use it once
      if (wr_i) data_holding <= dat_i;      
   end // always @ (posedge clk)

   // the old FIFO was 131072 16-bit words so we duplicate that here
   // in terms of depth.
   // the output side needs to be non-FWFT for Xillybus
   // we generate a prog_full output of 32760-ish: we then output
   // {data_count,1'b0} | {16{!prog_full}}
   // and hope to hell that works
   wire [15:0] data_count;
   wire        fifo_prog_full;
	// saturate out_data_count when we're above 32760-ish
	// this should be fine. we could actually change stuff
	// throughout to make this accurate.
   wire [15:0] out_data_count = {data_count[14:0],1'b0} | {16{!fifo_prog_full}};   

   xilly_evfifo u_fifo(.wr_clk(wr_clk),
		       .din(data_to_fifo),
		       .wr_en(fifo_wr),
		       .rst(reset_fifo),
		       .prog_full(fifo_prog_full),
		       .full(full_o),
		       .wr_data_count(data_count),
		       .rd_clk(rd_clk),
		       .dout(dat_o),
		       .rd_en(rd_i),
		       .empty(empty_o));   
   assign rst_ack_o = (state == RESET_COMPLETE || state == RESET_WAIT);
   assign count_o = out_data_count;   
   
	assign debug_o[2:0] = state;
	assign debug_o[3] = wr_i;
	assign debug_o[4 +: 16] = nwords_remaining;
	assign debug_o[20 +: 16] = dat_i;
	assign debug_o[36 +: 16] = out_data_count;
	assign debug_o[52] = fifo_wr;
endmodule // nofx2_event_buffer
