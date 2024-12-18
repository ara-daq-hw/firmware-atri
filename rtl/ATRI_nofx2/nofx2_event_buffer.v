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
			   output empty_o);

   // fill a 32-bit buffer with frame data
   // frame structure is always the same:
   // word 0: type
   // word 1: length (number of following words)
   // so we just bounce
   // when we hit an odd number of words we just
   // write a dummy word, the software will
   // know because it'll pad the number of
   // subsequent reads after the header and just
   // lie about the delivered data

   reg [15:0] 			  data_holding = {32{1'b0}};
   wire [31:0] 			  data_to_fifo = { dat_i, data_holding };   
   
   // we're small enough that we can hack-ball this, I hope
   // in state LENGTH we want to capture a value such that
   // we _add_ to the overflow. so for instance, if we get
   // 1, we want to store FFFF so that in DATA_0 nwords_remaining_plus_1[16]
   // is set.
   // so look at this:
   // ~0001 (1 remaining) = FFFE = 2 to go (1 off)
   // ~8000 (32768 remaining)  = 7FFF = 32769 to go (1 off)
   // etc.
   // so what we can do is:
   // if (state == (LENGTH || DATA_0 || DATA_1))
   //    nwords_remaining <= nwords_in_plus_one;
   // assign nwords_in = (state == LENGTH) ? ~dat_i : nwords_remaining;
   // assign nwords_in_plus_one = nwords_in + 1;
   //
   // this is actually fully implementable in a single compact
   // adder trivially, but who knows what Xilinx will do.
   // (it just takes in dat_i/nwords_remaining/2 control bits)
   // who cares, if we need to we'll do it ourselves.  
   reg [15:0] 			  nwords_remaining = {16{1'b0}};
   localparam FSM_BITS = 3;
   localparam [FSM_BITS-1:0] RESET = 0;
   localparam [FSM_BITS-1:0] RESET_COMPLETE = 1;   
   localparam [FSM_BITS-1:0] IDLE = 2;
   localparam [FSM_BITS-1:0] LENGTH = 3;
   localparam [FSM_BITS-1:0] DATA_0 = 4;
   localparam [FSM_BITS-1:0] DATA_1 = 5;
   localparam [FSM_BITS-1:0] PAD_1 = 6;   
   reg [FSM_BITS-1:0] 		  state = RESET;

   wire fifo_wr = (state == LENGTH ||
		   state == DATA_1 ||
		   state == PAD_1);   
   
   wire [15:0] 			  nwords_in = (state == LENGTH) ? ~dat_i : nwords_remaining;
   wire [16:0] 			  nwords_in_plus_one = nwords_in + 1;   
   
   wire 			  reset_delay;
   wire 			  reset_clear;   
   SRLC32E u_reset_delay(.D(state == RESET),.CE(1'b1),.CLK(clk),
			 .A(5'd15),
			 .Q(reset_clear),
			 .Q31(reset_delay));
   // this will need a CC
   reg 				  reset_fifo = 0;
   always @(posedge wr_clk) begin
      reset_fifo <= (state == RESET && !reset_clear);
      
      if (rst_i) state <= RESET;
      else begin 
	 case (state)
	   RESET: if (reset_delay) state <= RESET_COMPLETE;
	   RESET_COMPLETE: state <= IDLE;	   
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
   assign rst_ack_o = (state == RESET_COMPLETE);
   assign count_o = out_data_count;   
   
endmodule // nofx2_event_buffer
