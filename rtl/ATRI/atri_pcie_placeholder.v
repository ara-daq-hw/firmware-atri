`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Placeholder for the PCIe module when it's not being used as a PHY. Why do we
// actually keep the PCIe module around? Because it lets us tell the difference
// between an FPGA problem and an FX2 problem, and may let us know the reliability
// of the PCIe link.
//
//////////////////////////////////////////////////////////////////////////////////
module atri_pcie_placeholder(
		input sys_reset_n,
		input sys_clk_p,
		input sys_clk_n,
		output pci_exp_txp,
		output pci_exp_txn,
		input pci_exp_rxp,
		input pci_exp_rxn  //,
//		output trn_lnk_up_n,
//		output pcie_clk
    );

	wire sys_clk;
	IBUFDS sys_clk_ibuf(.I(sys_clk_p),.IB(sys_clk_n),.O(sys_clk));

core pciexp_core (
  // PCI Express (PCI_EXP) Fabric Interface
  .pci_exp_txp                        ( pci_exp_txp                 ),
  .pci_exp_txn                        ( pci_exp_txn                 ),
  .pci_exp_rxp                        ( pci_exp_rxp                 ),
  .pci_exp_rxn                        ( pci_exp_rxn                 ),

  // Transaction (TRN) Interface
  // Common clock & reset
  .user_lnk_up                        ( trn_lnk_up_n 					  ),
  .user_clk_out                       ( pcie_clk                    ),
  // System (SYS) Interface
  .sys_clk                            ( sys_clk		                 ),
  .sys_reset                          ( sys_reset		              ),
  .received_hot_reset                 ( received_hot_reset          )
  );
//
//core pciexp_core (
//  .pci_exp_txp            (pci_exp_txp            ),
//  .pci_exp_txn            (pci_exp_txn            ),
//  .pci_exp_rxp            (pci_exp_rxp            ),
//  .pci_exp_rxn            (pci_exp_rxn            ),
//  .user_lnk_up_n           (trn_lnk_up_n           ),
//  .trn_td                 (trn_td                 ), // Bus [31 : 0]
//  .trn_tsof_n             (trn_tsof_n             ),
//  .trn_teof_n             (trn_teof_n             ),
//  .trn_tsrc_rdy_n         (trn_tsrc_rdy_n         ),
//  .trn_tdst_rdy_n         (trn_tdst_rdy_n         ),
//  .trn_terr_drop_n        (trn_terr_drop_n        ),
//  .trn_tsrc_dsc_n         (trn_tsrc_dsc_n         ),
//  .trn_terrfwd_n          (trn_terrfwd_n          ),
//  .trn_tbuf_av            (trn_tbuf_av            ), // Bus [31 : 0]
//  .trn_tstr_n             (trn_tstr_n             ),
//  .trn_tcfg_req_n         (trn_tcfg_req_n         ),
//  .trn_tcfg_gnt_n         (trn_tcfg_gnt_n         ),
//  .trn_rd                 (trn_rd                 ), // Bus [31 : 0]
//  .trn_rsof_n             (trn_rsof_n             ),
//  .trn_reof_n             (trn_reof_n             ),
//  .trn_rsrc_rdy_n         (trn_rsrc_rdy_n         ),
//  .trn_rsrc_dsc_n         (trn_rsrc_dsc_n         ),
//  .trn_rdst_rdy_n         (trn_rdst_rdy_n         ),
//  .trn_rerrfwd_n          (trn_rerrfwd_n          ),
//  .trn_rnp_ok_n           (trn_rnp_ok_n           ),
//  .trn_rbar_hit_n         (trn_rbar_hit_n         ), // Bus [31 : 0]
//  .trn_fc_sel             (trn_fc_sel             ), // Bus [31 : 0]
//  .trn_fc_nph             (trn_fc_nph             ), // Bus [31 : 0]
//  .trn_fc_npd             (trn_fc_npd             ), // Bus [31 : 0]
//  .trn_fc_ph              (trn_fc_ph              ), // Bus [31 : 0]
//  .trn_fc_pd              (trn_fc_pd              ), // Bus [31 : 0]
//  .trn_fc_cplh            (trn_fc_cplh            ), // Bus [31 : 0]
//  .trn_fc_cpld            (trn_fc_cpld            ), // Bus [31 : 0]
//  .cfg_do                 (cfg_do                 ), // Bus [31 : 0]
//  .cfg_rd_wr_done_n       (cfg_rd_wr_done_n       ),
//  .cfg_dwaddr             (cfg_dwaddr             ), // Bus [31 : 0]
//  .cfg_rd_en_n            (cfg_rd_en_n            ),
//  .cfg_err_ur_n           (cfg_err_ur_n           ),
//  .cfg_err_cor_n          (cfg_err_cor_n          ),
//  .cfg_err_ecrc_n         (cfg_err_ecrc_n         ),
//  .cfg_err_cpl_timeout_n  (cfg_err_cpl_timeout_n  ),
//  .cfg_err_cpl_abort_n    (cfg_err_cpl_abort_n    ),
//  .cfg_err_posted_n       (cfg_err_posted_n       ),
//  .cfg_err_locked_n       (cfg_err_locked_n       ),
//  .cfg_err_tlp_cpl_header (cfg_err_tlp_cpl_header ), // Bus [31 : 0]
//  .cfg_err_cpl_rdy_n      (cfg_err_cpl_rdy_n      ),
//  .cfg_interrupt_n        (cfg_interrupt_n        ),
//  .cfg_interrupt_rdy_n    (cfg_interrupt_rdy_n    ),
//  .cfg_interrupt_assert_n (cfg_interrupt_assert_n ),
//  .cfg_interrupt_do       (cfg_interrupt_do       ), // Bus [31 : 0]
//  .cfg_interrupt_di       (cfg_interrupt_di       ), // Bus [31 : 0]
//  .cfg_interrupt_mmenable (cfg_interrupt_mmenable ), // Bus [31 : 0]
//  .cfg_interrupt_msienable(cfg_interrupt_msienable),
//  .cfg_turnoff_ok_n       (cfg_turnoff_ok_n       ),
//  .cfg_to_turnoff_n       (cfg_to_turnoff_n       ),
//  .cfg_pm_wake_n          (cfg_pm_wake_n          ),
//  .cfg_pcie_link_state_n  (cfg_pcie_link_state_n  ), // Bus [31 : 0]
//  .cfg_trn_pending_n      (cfg_trn_pending_n      ),
//  .cfg_dsn                (cfg_dsn                ), // Bus [31 : 0]
//  .cfg_bus_number         (cfg_bus_number         ), // Bus [31 : 0]
//  .cfg_device_number      (cfg_device_number      ), // Bus [31 : 0]
//  .cfg_function_number    (cfg_function_number    ), // Bus [31 : 0]
//  .cfg_status             (cfg_status             ), // Bus [31 : 0]
//  .cfg_command            (cfg_command            ), // Bus [31 : 0]
//  .cfg_dstatus            (cfg_dstatus            ), // Bus [31 : 0]
//  .cfg_dcommand           (cfg_dcommand           ), // Bus [31 : 0]
//  .cfg_lstatus            (cfg_lstatus            ), // Bus [31 : 0]
//  .cfg_lcommand           (cfg_lcommand           ), // Bus [31 : 0]
//  .sys_clk                (sys_clk                ),
//  .sys_reset_n            (sys_reset            ),
//  .trn_clk                (trn_clk                ),
//  .trn_reset_n            (trn_reset_n            ),
//  .received_hot_reset     (received_hot_reset     ));

endmodule
