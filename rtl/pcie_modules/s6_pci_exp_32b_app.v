//-----------------------------------------------------------------------------
//
// (c) Copyright 2001, 2002, 2003, 2004, 2005, 2007, 2008, 2009 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information of Xilinx, Inc.
// and is protected under U.S. and international copyright and other
// intellectual property laws.
//
// DISCLAIMER
//
// This disclaimer is not a license and does not grant any rights to the
// materials distributed herewith. Except as otherwise provided in a valid
// license issued to you by Xilinx, and to the maximum extent permitted by
// applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL
// FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS,
// IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
// MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE;
// and (2) Xilinx shall not be liable (whether in contract or tort, including
// negligence, or under any other theory of liability) for any loss or damage
// of any kind or nature related to, arising under or in connection with these
// materials, including for any direct, or any indirect, special, incidental,
// or consequential loss or damage (including loss of data, profits, goodwill,
// or any type of loss or damage suffered as a result of any action brought by
// a third party) even if such damage or loss was reasonably foreseeable or
// Xilinx had been advised of the possibility of the same.
//
// CRITICAL APPLICATIONS
//
// Xilinx products are not designed or intended to be fail-safe, or for use in
// any application requiring fail-safe performance, such as life-support or
// safety devices or systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any other
// applications that could lead to death, personal injury, or severe property
// or environmental damage (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and liability of any use of
// Xilinx products in Critical Applications, subject only to applicable laws
// and regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE
// AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Spartan-6 Integrated Block for PCI Express
// File       : pcie_app_s6.v
// Description: PCI Express Endpoint sample application
//              design. 
//
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

`include "ev2_interface.vh"

module pcie_app_s6
(

  input            trn_clk,
  input            trn_reset_n,
  input            trn_lnk_up_n, 

  // Tx
  input  [5:0]     trn_tbuf_av,
  input            trn_tcfg_req_n,
  input            trn_terr_drop_n,
  input            trn_tdst_rdy_n,
  output [31:0]    trn_td,
  output           trn_tsof_n,
  output           trn_teof_n,
  output           trn_tsrc_rdy_n,
  output           trn_tsrc_dsc_n,
  output           trn_terrfwd_n,
  output           trn_tcfg_gnt_n,
  output           trn_tstr_n,

  // Rx
  input  [31:0]    trn_rd,
  input            trn_rsof_n,
  input            trn_reof_n,
  input            trn_rsrc_rdy_n,
  input            trn_rsrc_dsc_n,
  input            trn_rerrfwd_n,
  input  [6:0]     trn_rbar_hit_n,
  output           trn_rdst_rdy_n,
  output           trn_rnp_ok_n, 

  // Flow Control
  input  [11:0]    trn_fc_cpld,
  input  [7:0]     trn_fc_cplh,
  input  [11:0]    trn_fc_npd,
  input  [7:0]     trn_fc_nph,
  input  [11:0]    trn_fc_pd,
  input  [7:0]     trn_fc_ph,
  output [2:0]     trn_fc_sel,


  input  [31:0]    cfg_do,
  input            cfg_rd_wr_done_n,
  output [9:0]     cfg_dwaddr,
  output           cfg_rd_en_n,


  output           cfg_err_cor_n,
  output           cfg_err_ur_n,
  output           cfg_err_ecrc_n,
  output           cfg_err_cpl_timeout_n,
  output           cfg_err_cpl_abort_n,
  output           cfg_err_posted_n,
  output           cfg_err_locked_n,
  output [47:0]    cfg_err_tlp_cpl_header,
  input            cfg_err_cpl_rdy_n,
  output           cfg_interrupt_n,
  input            cfg_interrupt_rdy_n,
  output           cfg_interrupt_assert_n,
  output [7:0]     cfg_interrupt_di,
  input  [7:0]     cfg_interrupt_do,
  input  [2:0]     cfg_interrupt_mmenable,
  input            cfg_interrupt_msienable,
  output           cfg_turnoff_ok_n,
  input            cfg_to_turnoff_n,
  output           cfg_trn_pending_n,
  output           cfg_pm_wake_n,
  input   [7:0]    cfg_bus_number,
  input   [4:0]    cfg_device_number,
  input   [2:0]    cfg_function_number,
  input  [15:0]    cfg_status,
  input  [15:0]    cfg_command,
  input  [15:0]    cfg_dstatus,
  input  [15:0]    cfg_dcommand,
  input  [15:0]    cfg_lstatus,
  input  [15:0]    cfg_lcommand,
  input   [2:0]    cfg_pcie_link_state_n,

  output [63:0]    cfg_dsn,


  output [52:0] debug_o,
  output [52:0] debug_o2,


												//now we add the output from the event interface: This is do to some compatibility problems. 
												//We should somehow try to clean this up.
	input ev2_irsclk_i, 
	input [15:0] ev2_dat_i,
	output [15:0] ev2_count_o,
	input ev2_wr_i,
	output ev2_full_o,
	input ev2_rst_i,
	output ev2_rst_ack_o


  
);

  localparam PCI_EXP_EP_OUI    = 24'h000A35;
  localparam PCI_EXP_EP_DSN_1  = {{8'h1},PCI_EXP_EP_OUI};
  localparam PCI_EXP_EP_DSN_2  = 32'h00000001;

  //
  // Core input tie-offs
  //
  
  assign trn_fc_sel = 3'b0; 
  
  assign trn_rnp_ok_n = 1'b0;
  assign trn_terrfwd_n = 1'b1;
 
  assign trn_tcfg_gnt_n = 1'b0;
  
  assign cfg_err_cor_n = 1'b1;
  assign cfg_err_ur_n = 1'b1;
  assign cfg_err_ecrc_n = 1'b1;
  assign cfg_err_cpl_timeout_n = 1'b1;
  assign cfg_err_cpl_abort_n = 1'b1;
  assign cfg_err_posted_n = 1'b0;
  assign cfg_err_locked_n = 1'b1;
  assign cfg_pm_wake_n = 1'b1;
  assign cfg_trn_pending_n = 1'b1;

  assign trn_tstr_n = 1'b0;
  assign cfg_interrupt_di = 8'b0;
  
  assign cfg_err_tlp_cpl_header = 47'h0;
 // assign cfg_dwaddr = 16'b0;
 // assign cfg_rd_en_n = 1'b1;
  assign cfg_dsn = {PCI_EXP_EP_DSN_2, PCI_EXP_EP_DSN_1};
  
wire [15:0] cfg_completer_id = {cfg_bus_number,
                                cfg_device_number,
                                cfg_function_number};

wire cfg_bus_mstr_enable = cfg_command[2];

//assign cfg_ext_tag_en = cfg_dcommand[8];
//assign cfg_max_rd_req_size = cfg_dcommand[14:12];
//assign cfg_max_payload_size = cfg_dcommand[7:5];

wire        cfg_ext_tag_en           = cfg_dcommand[8];
wire  [5:0] cfg_neg_max_lnk_width    = cfg_lstatus[9:4];
wire  [2:0] cfg_prg_max_payload_size = cfg_dcommand[7:5];
wire  [2:0] cfg_max_rd_req_size      = cfg_dcommand[14:12];
wire        cfg_rd_comp_bound        = cfg_lcommand[3];
 
 
wire pcie_ready_for_data;
wire tx_to_atri_data_request;
wire wr_en_atri;
wire [10:0] req_addr_atri;
wire [31:0] mwr_data_atri;
wire [31:0] wr_data_atri;
wire [7:0] wr_be_atri;
wire [31:0] mwr_len_atri;
wire [31:0] mwr_count_atri;
//wire [10:0] DW_available;
wire mwr_done_to_atri;
wire bmd_REG_wr_en_atri;
wire [15:0] cur_wr_count_to_atri;
wire [31:0] cpld_data;
 
parameter INTERFACE_WIDTH = 32;
 parameter INTERFACE_TYPE = 4'b0010;
 parameter FPGA_FAMILY = 8'h20; 


       BMD#
       (
        .INTERFACE_WIDTH(INTERFACE_WIDTH),
        .INTERFACE_TYPE(INTERFACE_TYPE),
        .FPGA_FAMILY(FPGA_FAMILY)
        )
        BMD(
        .trn_clk ( trn_clk ),                        // I
        .trn_reset_n ( trn_reset_n ),                // I
        .trn_lnk_up_n ( trn_lnk_up_n ),              // I

        .trn_td ( trn_td ),
        .trn_tsof_n ( trn_tsof_n ),                  // O [31:0]
        .trn_teof_n ( trn_teof_n ),                  // O
        .trn_tsrc_rdy_n ( trn_tsrc_rdy_n ),          // O
        .trn_tsrc_dsc_n ( trn_tsrc_dsc_n ),          // O
        .trn_tdst_rdy_n ( trn_tdst_rdy_n ),          // I
        .trn_tdst_dsc_n ( 1'b1 ),          // I
        .trn_tbuf_av ( trn_tbuf_av ),               // I [5:0]

        .trn_rd ( trn_rd ),                          // I [31:0]
        .trn_rsof_n ( trn_rsof_n ),                  // I
        .trn_reof_n ( trn_reof_n ),                  // I
        .trn_rsrc_rdy_n ( trn_rsrc_rdy_n ),          // I
        .trn_rsrc_dsc_n ( trn_rsrc_dsc_n ),          // I
        .trn_rdst_rdy_n ( trn_rdst_rdy_n ),          // O
        .trn_rbar_hit_n ( trn_rbar_hit_n ),         // I [6:0]

        .cfg_to_turnoff_n ( cfg_to_turnoff_n ),      // I
        .cfg_turnoff_ok_n ( cfg_turnoff_ok_n ),      // O

        .cfg_interrupt_n(cfg_interrupt_n),           // O
        .cfg_interrupt_rdy_n(cfg_interrupt_rdy_n),   // I

        .cfg_interrupt_msienable(cfg_interrupt_msienable), // I
        .cfg_interrupt_assert_n(cfg_interrupt_assert_n),   // O

        .cfg_ext_tag_en(cfg_ext_tag_en),                // I 

        .cfg_neg_max_lnk_width(cfg_neg_max_lnk_width),       // I [5:0]
        .cfg_prg_max_payload_size(cfg_prg_max_payload_size), // I [5:0]
        .cfg_max_rd_req_size(cfg_max_rd_req_size),           // I [2:0]
        .cfg_rd_comp_bound(cfg_rd_comp_bound),          // I

        .cfg_dwaddr(cfg_dwaddr),                        // O [11:0]
        .cfg_rd_en_n(cfg_rd_en_n),                      // O
        .cfg_do(cfg_do),                                // I [31:0]
        .cfg_rd_wr_done_n(cfg_rd_wr_done_n),            // I

        .cfg_completer_id ( cfg_completer_id ),      // I [15:0]
        .cfg_bus_mstr_enable (cfg_bus_mstr_enable ),  // I

			//ATRI interface
     		.pcie_ready_for_data_o(pcie_ready_for_data),
			.tx_to_atri_data_request_o(tx_to_atri_data_request),//Basically the read enable to the FIFO.
			.wr_en_atri_i(wr_en_atri),				//this is the additional write enable from the atri, in case there is data available to be shipped out.
			.req_addr_atri_i(req_addr_atri),  		//the register address to write to from the atri: This should be fixed to the "Device DMA control status register!"
			.mwr_data_atri_i(mwr_data_atri), 			//data coming directly from the atri interface
			.wr_data_atri_i(wr_data_atri),			//Data from the ATRI to be written to the registers
			.wr_be_atri_i(wr_be_atri),				//Needed to determine which bytes are accessed
			.mwr_len_atri_i(mwr_len_atri),
			.mwr_count_atri_i(mwr_count_atri),
			.mwr_done_to_atri_o(mwr_done_to_atri),
			.bmd_REG_wr_en_atri_i(bmd_REG_wr_en_atri),
			.cur_wr_count_to_atri_o(cur_wr_count_to_atri),
			.cpld_data_o(cpld_data)
        );

		pcie_interface atri_interface(
				.pcie_clk_i(trn_clk),
				.pcie_rst_i(trn_reset_n),
				.pcie_ready_for_data_i(pcie_ready_for_data),			
				.tx_to_atri_data_request_i(tx_to_atri_data_request),
				.data_pending_o(wr_en_atri),
//				.DW_available_o(DW_available),
				.data_to_pcie_o(mwr_data_atri),
				.bmd_REG_ADDR_DSRT_o(req_addr_atri),
				.bmd_REG_DATA_DSRT_o(wr_data_atri),
				.bmd_REG_BE_DSRT_o(wr_be_atri),
				.mwr_len_atri_o(mwr_len_atri),
				.mwr_count_atri_o(mwr_count_atri),
				.mwr_done_to_atri_i(mwr_done_to_atri),
				.bmd_REG_wr_en_o(bmd_REG_wr_en_atri),
				.cur_wr_count_to_atri_i(cur_wr_count_to_atri),
				.cpld_data_i(cpld_data),
				.debug_o(debug_o),
				.debug_o2(debug_o2),
		//		.trn_tdst_rdy_n_i(trn_tdst_rdy_n)
												//now we add the output from the event interface: This is do to some compatibility problems. 
												//We should somehow try to clean this up.
												.ev2_irsclk_i(ev2_irsclk_i), 
												.ev2_dat_i(ev2_dat_i),
												.ev2_count_o(ev2_count_o),
												.ev2_wr_i(ev2_wr_i),
												.ev2_full_o(ev2_full_o),
												.ev2_rst_i(ev2_rst_i),
												.ev2_rst_ack_o(ev2_rst_ack_o)
		);




endmodule // pcie_app_s6

