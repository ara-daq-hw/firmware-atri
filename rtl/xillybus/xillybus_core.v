module xillybus_core
  (
  input  bus_clk_w,
  input [7:0] cfg_bus_number_w,
  input [15:0] cfg_dcommand_w,
  input [4:0] cfg_device_number_w,
  input [15:0] cfg_dstatus_w,
  input [2:0] cfg_function_number_w,
  input  cfg_interrupt_rdy_n_w,
  input [15:0] cfg_lcommand_w,
  input [11:0] trn_fc_cpld_w,
  input [7:0] trn_fc_cplh_w,
  input  trn_lnk_up_n_w,
  input [6:0] trn_rbar_hit_n_w,
  input [31:0] trn_rd_w,
  input  trn_reof_n_w,
  input  trn_rerrfwd_n_w,
  input  trn_reset_n_w,
  input  trn_rsof_n_w,
  input  trn_rsrc_dsc_n_w,
  input  trn_rsrc_rdy_n_w,
  input  trn_tdst_rdy_n_w,
  input  trn_terr_drop_n_w,
  input [31:0] user_r_ev_out_data_w,
  input  user_r_ev_out_empty_w,
  input  user_r_ev_out_eof_w,
  input [7:0] user_r_pkt_out_data_w,
  input  user_r_pkt_out_empty_w,
  input  user_r_pkt_out_eof_w,
  input  user_w_icap_in_full_w,
  input  user_w_pkt_in_full_w,
  output [3:0] GPIO_LED_w,
  output  cfg_interrupt_n_w,
  output  quiesce_w,
  output  trn_rdst_rdy_n_w,
  output  trn_rnp_ok_n_w,
  output [31:0] trn_td_w,
  output  trn_teof_n_w,
  output  trn_tsof_n_w,
  output  trn_tsrc_rdy_n_w,
  output  user_r_ev_out_open_w,
  output  user_r_ev_out_rden_w,
  output  user_r_pkt_out_open_w,
  output  user_r_pkt_out_rden_w,
  output [15:0] user_w_icap_in_data_w,
  output  user_w_icap_in_open_w,
  output  user_w_icap_in_wren_w,
  output [7:0] user_w_pkt_in_data_w,
  output  user_w_pkt_in_open_w,
  output  user_w_pkt_in_wren_w
);
endmodule
