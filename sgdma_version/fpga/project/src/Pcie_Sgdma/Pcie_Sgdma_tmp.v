//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.01 (64-bit)
//IP Version: 1.0
//Part Number: GW5AT-LV60UG225C2/I1
//Device: GW5AT-60
//Device Version: B
//Created Time: Wed Jan  7 14:56:20 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	pcie_sgdma your_instance_name(
		.pcie_rstn(pcie_rstn), //input pcie_rstn
		.clk(clk), //input clk
		.pcie_tl_rx_sop(pcie_tl_rx_sop), //input pcie_tl_rx_sop
		.pcie_tl_rx_eop(pcie_tl_rx_eop), //input pcie_tl_rx_eop
		.pcie_tl_rx_data(pcie_tl_rx_data), //input [255:0] pcie_tl_rx_data
		.pcie_tl_rx_valid(pcie_tl_rx_valid), //input [7:0] pcie_tl_rx_valid
		.pcie_tl_rx_bardec(pcie_tl_rx_bardec), //input [5:0] pcie_tl_rx_bardec
		.pcie_tl_rx_err(pcie_tl_rx_err), //input [7:0] pcie_tl_rx_err
		.pcie_tl_rx_wait(pcie_tl_rx_wait), //output pcie_tl_rx_wait
		.pcie_tl_rx_masknp(pcie_tl_rx_masknp), //output pcie_tl_rx_masknp
		.pcie_tl_tx_sop(pcie_tl_tx_sop), //output pcie_tl_tx_sop
		.pcie_tl_tx_eop(pcie_tl_tx_eop), //output pcie_tl_tx_eop
		.pcie_tl_tx_data(pcie_tl_tx_data), //output [255:0] pcie_tl_tx_data
		.pcie_tl_tx_valid(pcie_tl_tx_valid), //output [7:0] pcie_tl_tx_valid
		.pcie_tl_tx_wait(pcie_tl_tx_wait), //input pcie_tl_tx_wait
		.pcie_tl_int_status(pcie_tl_int_status), //output pcie_tl_int_status
		.pcie_tl_int_req(pcie_tl_int_req), //output pcie_tl_int_req
		.pcie_tl_int_msinum(pcie_tl_int_msinum), //output [4:0] pcie_tl_int_msinum
		.pcie_tl_int_ack(pcie_tl_int_ack), //input pcie_tl_int_ack
		.pcie_tl_drp_clk(pcie_tl_drp_clk), //input pcie_tl_drp_clk
		.pcie_tl_drp_addr(pcie_tl_drp_addr), //output [23:0] pcie_tl_drp_addr
		.pcie_tl_drp_wr(pcie_tl_drp_wr), //output pcie_tl_drp_wr
		.pcie_tl_drp_wrdata(pcie_tl_drp_wrdata), //output [31:0] pcie_tl_drp_wrdata
		.pcie_tl_drp_strb(pcie_tl_drp_strb), //output [7:0] pcie_tl_drp_strb
		.pcie_tl_drp_rd(pcie_tl_drp_rd), //output pcie_tl_drp_rd
		.pcie_tl_drp_ready(pcie_tl_drp_ready), //input pcie_tl_drp_ready
		.pcie_tl_drp_rd_valid(pcie_tl_drp_rd_valid), //input pcie_tl_drp_rd_valid
		.pcie_tl_drp_rddata(pcie_tl_drp_rddata), //input [31:0] pcie_tl_drp_rddata
		.pcie_tl_drp_resp(pcie_tl_drp_resp), //input pcie_tl_drp_resp
		.pcie_ltssm(pcie_ltssm), //input [4:0] pcie_ltssm
		.pcie_linkup(pcie_linkup), //input pcie_linkup
		.pcie_tl_cfg_busdev(pcie_tl_cfg_busdev), //input [12:0] pcie_tl_cfg_busdev
		.m_axis_h2c_tready(m_axis_h2c_tready), //input [0:0] m_axis_h2c_tready
		.m_axis_h2c_tvalid(m_axis_h2c_tvalid), //output [0:0] m_axis_h2c_tvalid
		.m_axis_h2c_tdata(m_axis_h2c_tdata), //output [255:0] m_axis_h2c_tdata
		.m_axis_h2c_tlast(m_axis_h2c_tlast), //output [0:0] m_axis_h2c_tlast
		.m_axis_h2c_tuser(m_axis_h2c_tuser), //output [31:0] m_axis_h2c_tuser
		.m_axis_h2c_tkeep(m_axis_h2c_tkeep), //output [31:0] m_axis_h2c_tkeep
		.h2c_overhead(h2c_overhead), //output [63:0] h2c_overhead
		.h2c_run(h2c_run), //output [0:0] h2c_run
		.s_axis_c2h_tready(s_axis_c2h_tready), //output [0:0] s_axis_c2h_tready
		.s_axis_c2h_tvalid(s_axis_c2h_tvalid), //input [0:0] s_axis_c2h_tvalid
		.s_axis_c2h_tlast(s_axis_c2h_tlast), //input [0:0] s_axis_c2h_tlast
		.s_axis_c2h_tdata(s_axis_c2h_tdata), //input [255:0] s_axis_c2h_tdata
		.s_axis_c2h_tuser(s_axis_c2h_tuser), //input [31:0] s_axis_c2h_tuser
		.s_axis_c2h_tkeep(s_axis_c2h_tkeep), //input [31:0] s_axis_c2h_tkeep
		.c2h_overhead_valid(c2h_overhead_valid), //input [0:0] c2h_overhead_valid
		.c2h_overhead_data(c2h_overhead_data), //input [63:0] c2h_overhead_data
		.c2h_run(c2h_run), //output [0:0] c2h_run
		.user_cs(user_cs), //output user_cs
		.user_address(user_address), //output [63:0] user_address
		.user_rw(user_rw), //output user_rw
		.user_wr_data(user_wr_data), //output [31:0] user_wr_data
		.user_wr_be(user_wr_be), //output [3:0] user_wr_be
		.user_rd_be(user_rd_be), //output [3:0] user_rd_be
		.user_rd_valid(user_rd_valid), //input user_rd_valid
		.user_rd_data(user_rd_data), //input [31:0] user_rd_data
		.user_zero_read(user_zero_read) //output user_zero_read
	);

//--------Copy end-------------------
