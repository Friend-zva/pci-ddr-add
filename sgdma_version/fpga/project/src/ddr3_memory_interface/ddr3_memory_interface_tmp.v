//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02
//IP Version: 6.0
//Part Number: GW5AST-LV138FPG676AC1/I0
//Device: GW5AST-138
//Device Version: B
//Created Time: Fri Apr  3 20:06:56 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	DDR3_Memory_Interface_Top your_instance_name(
		.clk(clk), //input clk
		.pll_stop(pll_stop), //output pll_stop
		.memory_clk(memory_clk), //input memory_clk
		.pll_lock(pll_lock), //input pll_lock
		.rst_n(rst_n), //input rst_n
		.clk_out(clk_out), //output clk_out
		.ddr_rst(ddr_rst), //output ddr_rst
		.init_calib_complete(init_calib_complete), //output init_calib_complete
		.s_axi_awvalid(s_axi_awvalid), //input s_axi_awvalid
		.s_axi_awready(s_axi_awready), //output s_axi_awready
		.s_axi_awid(s_axi_awid), //input [3:0] s_axi_awid
		.s_axi_awaddr(s_axi_awaddr), //input [28:0] s_axi_awaddr
		.s_axi_awlen(s_axi_awlen), //input [7:0] s_axi_awlen
		.s_axi_awsize(s_axi_awsize), //input [2:0] s_axi_awsize
		.s_axi_awburst(s_axi_awburst), //input [1:0] s_axi_awburst
		.s_axi_wvalid(s_axi_wvalid), //input s_axi_wvalid
		.s_axi_wready(s_axi_wready), //output s_axi_wready
		.s_axi_wdata(s_axi_wdata), //input [255:0] s_axi_wdata
		.s_axi_wstrb(s_axi_wstrb), //input [31:0] s_axi_wstrb
		.s_axi_wlast(s_axi_wlast), //input s_axi_wlast
		.s_axi_bvalid(s_axi_bvalid), //output s_axi_bvalid
		.s_axi_bready(s_axi_bready), //input s_axi_bready
		.s_axi_bresp(s_axi_bresp), //output [1:0] s_axi_bresp
		.s_axi_bid(s_axi_bid), //output [3:0] s_axi_bid
		.s_axi_arvalid(s_axi_arvalid), //input s_axi_arvalid
		.s_axi_arready(s_axi_arready), //output s_axi_arready
		.s_axi_arid(s_axi_arid), //input [3:0] s_axi_arid
		.s_axi_araddr(s_axi_araddr), //input [28:0] s_axi_araddr
		.s_axi_arlen(s_axi_arlen), //input [7:0] s_axi_arlen
		.s_axi_arsize(s_axi_arsize), //input [2:0] s_axi_arsize
		.s_axi_arburst(s_axi_arburst), //input [1:0] s_axi_arburst
		.s_axi_rvalid(s_axi_rvalid), //output s_axi_rvalid
		.s_axi_rready(s_axi_rready), //input s_axi_rready
		.s_axi_rdata(s_axi_rdata), //output [255:0] s_axi_rdata
		.s_axi_rresp(s_axi_rresp), //output [1:0] s_axi_rresp
		.s_axi_rid(s_axi_rid), //output [3:0] s_axi_rid
		.s_axi_rlast(s_axi_rlast), //output s_axi_rlast
		.sr_req(sr_req), //input sr_req
		.ref_req(ref_req), //input ref_req
		.sr_ack(sr_ack), //output sr_ack
		.ref_ack(ref_ack), //output ref_ack
		.burst(burst), //input burst
		.O_ddr_addr(O_ddr_addr), //output [13:0] O_ddr_addr
		.O_ddr_ba(O_ddr_ba), //output [2:0] O_ddr_ba
		.O_ddr_cs_n(O_ddr_cs_n), //output O_ddr_cs_n
		.O_ddr_ras_n(O_ddr_ras_n), //output O_ddr_ras_n
		.O_ddr_cas_n(O_ddr_cas_n), //output O_ddr_cas_n
		.O_ddr_we_n(O_ddr_we_n), //output O_ddr_we_n
		.O_ddr_clk(O_ddr_clk), //output O_ddr_clk
		.O_ddr_clk_n(O_ddr_clk_n), //output O_ddr_clk_n
		.O_ddr_cke(O_ddr_cke), //output O_ddr_cke
		.O_ddr_odt(O_ddr_odt), //output O_ddr_odt
		.O_ddr_reset_n(O_ddr_reset_n), //output O_ddr_reset_n
		.O_ddr_dqm(O_ddr_dqm), //output [3:0] O_ddr_dqm
		.IO_ddr_dq(IO_ddr_dq), //inout [31:0] IO_ddr_dq
		.IO_ddr_dqs(IO_ddr_dqs), //inout [3:0] IO_ddr_dqs
		.IO_ddr_dqs_n(IO_ddr_dqs_n) //inout [3:0] IO_ddr_dqs_n
	);

//--------Copy end-------------------
