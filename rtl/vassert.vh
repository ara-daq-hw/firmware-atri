// Macros for Verilog assertion.

`define VA_WARN_LESS( v_name, v_value , v_limit , v_message ) \
	vassert_if_less_than #(.VALUE( v_value ), .LIMIT( v_limit ), \
								  .WARN("YES"), .ERR( v_message )) v_name()
								  
`define VA_ERR_LESS( v_name , v_value , v_limit , v_message ) \
	vassert_if_less_than #(.VALUE( v_value ), .LIMIT( v_limit ), \
								  .ERR( v_message )) v_name()

`define VA_WARN_GREATER( v_name , v_value , v_limit , v_message ) \
	vassert_if_greater_than #(.VALUE( v_value ), .LIMIT( v_limit ), \
								  .WARN("YES"), .ERR( v_message )) v_name()

`define VA_ERR_GREATER( v_name , v_value , v_limit , v_message ) \
	vassert_if_greater_than #(.VALUE( v_value ), .LIMIT( v_limit ), \
								     .ERR( v_message )) v_name()

`define VA_WARN_NOT( v_name , v_value , v_message ) \
	vassert_if_not #(.BOOL( v_value ), \
								     .WARN("YES"), .ERR( v_message )) v_name()

`define VA_ERR_NOT( v_name , v_value , v_message ) \
	vassert_if_not #(.VALUE( v_value ), \
						  .ERR( v_message )) v_name()

