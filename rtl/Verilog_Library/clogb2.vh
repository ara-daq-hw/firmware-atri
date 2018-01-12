function integer clogb2;
      input [31:0] value;
		reg [31:0] in_val;
		begin
			in_val = value;
			for (clogb2=0;in_val>0;clogb2=clogb2+1)
				in_val= in_val >> 1;
		end
endfunction // clogb2
