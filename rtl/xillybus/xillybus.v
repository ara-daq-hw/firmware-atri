`timescale 1ns / 10ps

module xillybus(GPIO_LED, PCIE_TX0_P, PCIE_TX0_N, PCIE_RX0_P, PCIE_RX0_N,
  PCIE_250M_P, PCIE_250M_N, PCIE_PERST_B_LS, bus_clk, quiesce,
  user_w_icap_in_wren, user_w_icap_in_data, user_w_icap_in_full,
  user_w_icap_in_open, user_w_pkt_in_wren, user_w_pkt_in_data,
  user_w_pkt_in_full, user_w_pkt_in_open, user_r_pkt_out_rden,
  user_r_pkt_out_data, user_r_pkt_out_empty, user_r_pkt_out_eof,
  user_r_pkt_out_open, user_r_ev_out_rden, user_r_ev_out_data,
  user_r_ev_out_empty, user_r_ev_out_eof, user_r_ev_out_open);

  input  PCIE_RX0_P;
  input  PCIE_RX0_N;
  input  PCIE_250M_P;
  input  PCIE_250M_N;
  input  PCIE_PERST_B_LS;
  input  user_w_icap_in_full;
  input  user_w_pkt_in_full;
  input [7:0] user_r_pkt_out_data;
  input  user_r_pkt_out_empty;
  input  user_r_pkt_out_eof;
  input [15:0] user_r_ev_out_data;
  input  user_r_ev_out_empty;
  input  user_r_ev_out_eof;
  output [3:0] GPIO_LED;
  output  PCIE_TX0_P;
  output  PCIE_TX0_N;
  output  bus_clk;
  output  quiesce;
  output  user_w_icap_in_wren;
  output [15:0] user_w_icap_in_data;
  output  user_w_icap_in_open;
  output  user_w_pkt_in_wren;
  output [7:0] user_w_pkt_in_data;
  output  user_w_pkt_in_open;
  output  user_r_pkt_out_rden;
  output  user_r_pkt_out_open;
  output  user_r_ev_out_rden;
  output  user_r_ev_out_open;
  wire  trn_reset_n;
  wire  trn_lnk_up_n;
  wire [31:0] trn_td;
  wire  trn_tsof_n;
  wire  trn_teof_n;
  wire  trn_tsrc_rdy_n;
  wire  trn_tdst_rdy_n;
  wire  trn_terr_drop_n;
  wire [31:0] trn_rd;
  wire  trn_rsof_n;
  wire  trn_reof_n;
  wire  trn_rsrc_rdy_n;
  wire  trn_rsrc_dsc_n;
  wire  trn_rdst_rdy_n;
  wire  trn_rerrfwd_n;
  wire  trn_rnp_ok_n;
  wire [6:0] trn_rbar_hit_n;
  wire [7:0] trn_fc_cplh;
  wire [11:0] trn_fc_cpld;
  wire  cfg_interrupt_n;
  wire  cfg_interrupt_rdy_n;
  wire [7:0] cfg_bus_number;
  wire [4:0] cfg_device_number;
  wire [2:0] cfg_function_number;
  wire [15:0] cfg_dcommand;
  wire [15:0] cfg_lcommand;
  wire [15:0] cfg_dstatus;
  wire  pcie_ref_clk;

   IBUFDS pcieclk_ibuf (.O(pcie_ref_clk), .I(PCIE_250M_P), .IB(PCIE_250M_N));

   pcie pcie
     (
      .pci_exp_txp            (PCIE_TX0_P             ),
      .pci_exp_txn            (PCIE_TX0_N             ),
      .pci_exp_rxp            (PCIE_RX0_P             ),
      .pci_exp_rxn            (PCIE_RX0_N             ),

      .trn_rd(trn_rd),
      .trn_rsof_n(trn_rsof_n),
      .trn_reof_n(trn_reof_n),
      .trn_rsrc_rdy_n(trn_rsrc_rdy_n),
      .trn_rsrc_dsc_n(trn_rsrc_dsc_n),
      .trn_rbar_hit_n(trn_rbar_hit_n),
      .trn_rerrfwd_n(trn_rerrfwd_n),
      .trn_rdst_rdy_n(trn_rdst_rdy_n),
      .trn_rnp_ok_n(trn_rnp_ok_n),

      .trn_td(trn_td),
      .trn_tsof_n(trn_tsof_n),
      .trn_teof_n(trn_teof_n),
      .trn_tsrc_rdy_n(trn_tsrc_rdy_n),
      .trn_tdst_rdy_n(trn_tdst_rdy_n),
      .trn_terr_drop_n(trn_terr_drop_n),
      .trn_tsrc_dsc_n(1'b1),

      .trn_terrfwd_n		(1'b1),
      .trn_tstr_n		(1'b1), // No streaming transmission
      .trn_tcfg_gnt_n		(1'b0), // Always grant core's TLPs
      .trn_fc_sel		(3'd0), // Receive credit available Space
      .trn_fc_cplh(trn_fc_cplh), // Completion Header credits
      .trn_fc_cpld(trn_fc_cpld), // Completion Data credits

      .cfg_bus_number(cfg_bus_number),
      .cfg_device_number(cfg_device_number),
      .cfg_function_number(cfg_function_number),
      .cfg_dcommand(cfg_dcommand),
      .cfg_lcommand(cfg_lcommand),
      .cfg_dstatus(cfg_dstatus),
      .cfg_interrupt_n(cfg_interrupt_n),
      .cfg_interrupt_di(8'd0), // Single MSI anyhow
      .cfg_interrupt_rdy_n(cfg_interrupt_rdy_n),

      // Configuration functionality disabled
      .cfg_dwaddr		(10'd0),
      .cfg_rd_en_n		(1'b1),
      .cfg_err_ur_n		(1'b1),
      .cfg_err_cor_n		(1'b1),
      .cfg_err_ecrc_n		(1'b1),
      .cfg_err_cpl_timeout_n	(1'b1),
      .cfg_err_cpl_abort_n	(1'b1),
      .cfg_err_posted_n	(1'b1),
      .cfg_err_locked_n	(1'b1),
      .cfg_err_tlp_cpl_header	(48'd0),

      .cfg_interrupt_assert_n	(1'b1),

      .cfg_turnoff_ok_n	(1'b1),
      .cfg_pm_wake_n		(1'b1),
      .cfg_trn_pending_n	(1'b1),
      .cfg_dsn			(64'd0),

      .sys_clk                (pcie_ref_clk           ),
      .sys_reset_n            (PCIE_PERST_B_LS        ),

      .trn_clk(bus_clk),
      .trn_reset_n(trn_reset_n),

      .trn_lnk_up_n(trn_lnk_up_n),
      .received_hot_reset     (                       )
      );

  xillybus_core  xillybus_core_ins(.bus_clk_w(bus_clk),
    .trn_reset_n_w(trn_reset_n), .trn_lnk_up_n_w(trn_lnk_up_n),
    .quiesce_w(quiesce), .trn_td_w(trn_td), .trn_tsof_n_w(trn_tsof_n),
    .trn_teof_n_w(trn_teof_n), .trn_tsrc_rdy_n_w(trn_tsrc_rdy_n),
    .trn_tdst_rdy_n_w(trn_tdst_rdy_n), .trn_terr_drop_n_w(trn_terr_drop_n),
    .GPIO_LED_w(GPIO_LED), .trn_rd_w(trn_rd), .trn_rsof_n_w(trn_rsof_n),
    .trn_reof_n_w(trn_reof_n), .trn_rsrc_rdy_n_w(trn_rsrc_rdy_n),
    .trn_rsrc_dsc_n_w(trn_rsrc_dsc_n), .trn_rdst_rdy_n_w(trn_rdst_rdy_n),
    .trn_rerrfwd_n_w(trn_rerrfwd_n), .trn_rnp_ok_n_w(trn_rnp_ok_n),
    .trn_rbar_hit_n_w(trn_rbar_hit_n), .trn_fc_cplh_w(trn_fc_cplh),
    .trn_fc_cpld_w(trn_fc_cpld), .cfg_interrupt_n_w(cfg_interrupt_n),
    .cfg_interrupt_rdy_n_w(cfg_interrupt_rdy_n), .cfg_bus_number_w(cfg_bus_number),
    .cfg_device_number_w(cfg_device_number), .cfg_function_number_w(cfg_function_number),
    .cfg_dcommand_w(cfg_dcommand), .cfg_lcommand_w(cfg_lcommand),
    .cfg_dstatus_w(cfg_dstatus), .user_w_icap_in_wren_w(user_w_icap_in_wren),
    .user_w_icap_in_data_w(user_w_icap_in_data), .user_w_icap_in_full_w(user_w_icap_in_full),
    .user_w_icap_in_open_w(user_w_icap_in_open), .user_w_pkt_in_wren_w(user_w_pkt_in_wren),
    .user_w_pkt_in_data_w(user_w_pkt_in_data), .user_w_pkt_in_full_w(user_w_pkt_in_full),
    .user_w_pkt_in_open_w(user_w_pkt_in_open), .user_r_pkt_out_rden_w(user_r_pkt_out_rden),
    .user_r_pkt_out_data_w(user_r_pkt_out_data), .user_r_pkt_out_empty_w(user_r_pkt_out_empty),
    .user_r_pkt_out_eof_w(user_r_pkt_out_eof), .user_r_pkt_out_open_w(user_r_pkt_out_open),
    .user_r_ev_out_rden_w(user_r_ev_out_rden), .user_r_ev_out_data_w(user_r_ev_out_data),
    .user_r_ev_out_empty_w(user_r_ev_out_empty), .user_r_ev_out_eof_w(user_r_ev_out_eof),
    .user_r_ev_out_open_w(user_r_ev_out_open));

endmodule
