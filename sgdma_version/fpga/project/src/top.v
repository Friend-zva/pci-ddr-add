module top (
    input  soc_pcie_rstn,
    input  clk_200m_p,
    input  clk_200m_n,
    input  clk_50m,
    output sysclk_o
);

  wire         sysclk;
  reg  [ 15:0] reset_cnt = 0;
  reg          soc_pcie_rstn_d0 = 0;
  reg          soc_pcie_rstn_d1 = 0;
  reg          pcie_rstn = 0;

  //PCIe IP
  wire         pcie_tl_rx_sop;
  wire         pcie_tl_rx_eop;
  wire [255:0] pcie_tl_rx_data;
  wire [  7:0] pcie_tl_rx_valid;
  wire [  5:0] pcie_tl_rx_bardec;
  wire [  7:0] pcie_tl_rx_err;
  wire         pcie_tl_rx_wait;
  wire         pcie_tl_rx_masknp;
  wire         pcie_tl_tx_sop;
  wire         pcie_tl_tx_eop;
  wire [255:0] pcie_tl_tx_data;
  wire [  7:0] pcie_tl_tx_valid;
  wire         pcie_tl_tx_wait;
  wire         pcie_tl_int_status;
  wire         pcie_tl_int_req;
  wire [  4:0] pcie_tl_int_msinum;
  wire         pcie_tl_int_ack;
  wire         pcie_tl_drp_clk;
  wire [ 23:0] pcie_tl_drp_addr;
  wire         pcie_tl_drp_wr;
  wire [ 31:0] pcie_tl_drp_wrdata;
  wire [  7:0] pcie_tl_drp_strb;
  wire         pcie_tl_drp_rd;
  wire         pcie_tl_drp_ready;
  wire         pcie_tl_drp_rd_valid;
  wire [ 31:0] pcie_tl_drp_rddata;
  wire         pcie_tl_drp_resp;
  wire [  4:0] pcie_ltssm;
  wire         pcie_linkup;
  wire [ 12:0] pcie_tl_cfg_busdev;
  //H2C axi stream
  wire         m_axis_h2c_tready;
  wire         m_axis_h2c_tvalid;
  wire [255:0] m_axis_h2c_tdata;
  wire         m_axis_h2c_tlast;
  wire [ 31:0] m_axis_h2c_tuser;
  wire [ 31:0] m_axis_h2c_tkeep;
  wire [ 63:0] h2c_overhead;
  //C2H axi stream
  wire         s_axis_c2h_tready;
  wire         s_axis_c2h_tvalid;
  wire         s_axis_c2h_tlast;
  wire [255:0] s_axis_c2h_tdata;
  wire [ 31:0] s_axis_c2h_tuser;
  wire [ 31:0] s_axis_c2h_tkeep;
  wire         c2h_overhead_valid;
  wire [ 63:0] c2h_overhead_data;

  wire         h2c_run;
  wire         c2h_run;
  //BAR2
  wire         user_cs;
  wire [ 63:0] user_address;
  wire         user_rw;
  wire [ 31:0] user_wr_data;
  wire [  3:0] user_wr_be;
  wire [  3:0] user_rd_be;
  reg          user_rd_valid;
  reg  [ 31:0] user_rd_data;
  wire         user_zero_read;

  localparam integer AXIDATAWIDTH = 256;
  localparam integer AXIADDRWIDTH = 32;
  localparam integer AXISTRBWIDTH = AXIDATAWIDTH / 8;
  localparam integer AXIIDWIDTH = 8;
  localparam integer AXILENWIDTH = 20;

  wire [AXIADDRWIDTH-1:0] dma_read_desc_addr;
  wire [ AXILENWIDTH-1:0] dma_read_desc_len;
  wire [           7 : 0] dma_read_desc_tag;
  wire [           7 : 0] dma_read_desc_id;
  wire [           7 : 0] dma_read_desc_dest;
  wire [          31 : 0] dma_read_desc_user;
  wire                    dma_read_desc_valid;
  wire                    dma_read_desc_ready;
  wire [           7 : 0] dma_read_status_tag;
  wire [           3 : 0] dma_read_status_error;
  wire                    dma_read_status_valid;

  wire [AXIADDRWIDTH-1:0] dma_write_desc_addr;
  wire [ AXILENWIDTH-1:0] dma_write_desc_len;
  wire [           7 : 0] dma_write_desc_tag;
  wire                    dma_write_desc_valid;
  wire                    dma_write_desc_ready;
  wire [ AXILENWIDTH-1:0] dma_write_status_len;
  wire [           7 : 0] dma_write_status_tag;
  wire [           7 : 0] dma_write_status_id;
  wire [           7 : 0] dma_write_status_dest;
  wire [          31 : 0] dma_write_status_user;
  wire [           3 : 0] dma_write_status_error;
  wire                    dma_write_status_valid;

  wire [  AXIIDWIDTH-1:0] dma_axi_awid;
  wire [AXIADDRWIDTH-1:0] dma_axi_awaddr;
  wire [             7:0] dma_axi_awlen;
  wire [             2:0] dma_axi_awsize;
  wire [             1:0] dma_axi_awburst;
  wire                    dma_axi_awlock;
  wire [             3:0] dma_axi_awcache;
  wire [             2:0] dma_axi_awprot;
  wire                    dma_axi_awvalid;
  wire                    dma_axi_awready;
  wire [AXIDATAWIDTH-1:0] dma_axi_wdata;
  wire [AXISTRBWIDTH-1:0] dma_axi_wstrb;
  wire                    dma_axi_wlast;
  wire                    dma_axi_wvalid;
  wire                    dma_axi_wready;
  wire [  AXIIDWIDTH-1:0] dma_axi_bid;
  wire [             1:0] dma_axi_bresp;
  wire                    dma_axi_bvalid;
  wire                    dma_axi_bready;
  wire [  AXIIDWIDTH-1:0] dma_axi_arid;
  wire [AXIADDRWIDTH-1:0] dma_axi_araddr;
  wire [             7:0] dma_axi_arlen;
  wire [             2:0] dma_axi_arsize;
  wire [             1:0] dma_axi_arburst;
  wire                    dma_axi_arlock;
  wire [             3:0] dma_axi_arcache;
  wire [             2:0] dma_axi_arprot;
  wire                    dma_axi_arvalid;
  wire                    dma_axi_arready;
  wire [  AXIIDWIDTH-1:0] dma_axi_rid;
  wire [AXIDATAWIDTH-1:0] dma_axi_rdata;
  wire [             1:0] dma_axi_rresp;
  wire                    dma_axi_rlast;
  wire                    dma_axi_rvalid;
  wire                    dma_axi_rready;

  wire [  AXIIDWIDTH-1:0] ic_m_axi_awid;
  wire [AXIADDRWIDTH-1:0] ic_m_axi_awaddr;
  wire [             7:0] ic_m_axi_awlen;
  wire [             2:0] ic_m_axi_awsize;
  wire [             1:0] ic_m_axi_awburst;
  wire                    ic_m_axi_awlock;
  wire [             3:0] ic_m_axi_awcache;
  wire [             2:0] ic_m_axi_awprot;
  wire [             3:0] ic_m_axi_awqos;
  wire [             3:0] ic_m_axi_awregion;
  wire                    ic_m_axi_awuser;
  wire                    ic_m_axi_awvalid;
  wire                    ic_m_axi_awready;
  wire [AXIDATAWIDTH-1:0] ic_m_axi_wdata;
  wire [AXISTRBWIDTH-1:0] ic_m_axi_wstrb;
  wire                    ic_m_axi_wlast;
  wire                    ic_m_axi_wuser;
  wire                    ic_m_axi_wvalid;
  wire                    ic_m_axi_wready;
  wire [  AXIIDWIDTH-1:0] ic_m_axi_bid;
  wire [             1:0] ic_m_axi_bresp;
  wire                    ic_m_axi_buser;
  wire                    ic_m_axi_bvalid;
  wire                    ic_m_axi_bready;
  wire [  AXIIDWIDTH-1:0] ic_m_axi_arid;
  wire [AXIADDRWIDTH-1:0] ic_m_axi_araddr;
  wire [             7:0] ic_m_axi_arlen;
  wire [             2:0] ic_m_axi_arsize;
  wire [             1:0] ic_m_axi_arburst;
  wire                    ic_m_axi_arlock;
  wire [             3:0] ic_m_axi_arcache;
  wire [             2:0] ic_m_axi_arprot;
  wire [             3:0] ic_m_axi_arqos;
  wire [             3:0] ic_m_axi_arregion;
  wire                    ic_m_axi_aruser;
  wire                    ic_m_axi_arvalid;
  wire                    ic_m_axi_arready;
  wire [  AXIIDWIDTH-1:0] ic_m_axi_rid;
  wire [AXIDATAWIDTH-1:0] ic_m_axi_rdata;
  wire [             1:0] ic_m_axi_rresp;
  wire                    ic_m_axi_rlast;
  wire                    ic_m_axi_ruser;
  wire                    ic_m_axi_rvalid;
  wire                    ic_m_axi_rready;

  assign dma_read_desc_addr = c2h_overhead_data[31:0];
  assign dma_read_desc_len = c2h_overhead_data[51:32];
  assign dma_read_desc_tag = 8'd0;
  assign dma_read_desc_id = 8'd0;
  assign dma_read_desc_dest = 8'd0;
  assign dma_read_desc_user = 32'd0;
  assign dma_read_desc_valid = c2h_overhead_valid;

  assign dma_write_desc_addr = h2c_overhead[31:0];
  assign dma_write_desc_len = h2c_overhead[51:32];
  assign dma_write_desc_tag = 8'd0;
  assign dma_write_desc_valid = m_axis_h2c_tvalid && m_axis_h2c_tlast;

  assign c2h_overhead_valid = 1'b0;
  assign c2h_overhead_data = 64'd0;
  assign h2c_run = 1'b1;
  assign c2h_run = 1'b1;

  assign sysclk_o = sysclk;

  //*************sysclk generate*************

  TLVDS_IBUF u_TLVDS_IBUF (
      .O (clk_200m),
      .I (clk_200m_p),
      .IB(clk_200m_n)
  );

  Gowin_PLL u_Gowin_PLL (
      .clkin(clk_200m),  //input  clkin
      .clkout0(sysclk),  //output  clkout0
      .init_clk(clk_50m)  //input  init_clk
  );

  //*************reset generate*************
  always @(posedge sysclk) begin
    soc_pcie_rstn_d0 <= soc_pcie_rstn;
    soc_pcie_rstn_d1 <= soc_pcie_rstn_d0;
    if (!soc_pcie_rstn_d1) begin
      reset_cnt <= 0;
    end else if (reset_cnt < 16'd50000) begin
      reset_cnt <= reset_cnt + 1;
    end
    pcie_rstn <= (reset_cnt == 16'd50000);
  end

  //*************PCIe IP*************
  SerDes_Top u_PCIe_IP (
      .PCIE_Controller_Top_pcie_tl_rx_sop_o(pcie_tl_rx_sop),
      .PCIE_Controller_Top_pcie_tl_rx_eop_o(pcie_tl_rx_eop),
      .PCIE_Controller_Top_pcie_tl_rx_data_o(pcie_tl_rx_data),
      .PCIE_Controller_Top_pcie_tl_rx_valid_o(pcie_tl_rx_valid),
      .PCIE_Controller_Top_pcie_tl_rx_bardec_o(pcie_tl_rx_bardec),
      .PCIE_Controller_Top_pcie_tl_rx_err_o(pcie_tl_rx_err),
      .PCIE_Controller_Top_pcie_tl_tx_wait_o(pcie_tl_tx_wait),
      .PCIE_Controller_Top_pcie_ltssm_o(pcie_ltssm),
      .PCIE_Controller_Top_pcie_tl_tx_creditsp_o(PCIE_Controller_Top_pcie_tl_tx_creditsp),
      .PCIE_Controller_Top_pcie_tl_tx_creditsnp_o(PCIE_Controller_Top_pcie_tl_tx_creditsnp),
      .PCIE_Controller_Top_pcie_tl_tx_creditscpl_o(PCIE_Controller_Top_pcie_tl_tx_creditscpl),
      .PCIE_Controller_Top_pcie_tl_cfg_busdev_o(pcie_tl_cfg_busdev),
      .PCIE_Controller_Top_pcie_linkup_o(pcie_linkup),
      .PCIE_Controller_Top_pcie_tl_drp_clk_o(pcie_tl_drp_clk),
      .PCIE_Controller_Top_pcie_tl_drp_rddata_o(pcie_tl_drp_rddata),
      .PCIE_Controller_Top_pcie_tl_drp_resp_o(pcie_tl_drp_resp),
      .PCIE_Controller_Top_pcie_tl_drp_rd_valid_o(pcie_tl_drp_rd_valid),
      .PCIE_Controller_Top_pcie_tl_drp_ready_o(pcie_tl_drp_ready),
      .PCIE_Controller_Top_pcie_rstn_i(pcie_rstn),
      .PCIE_Controller_Top_pcie_tl_clk_i(sysclk),
      .PCIE_Controller_Top_pcie_tl_rx_wait_i(pcie_tl_rx_wait),
      .PCIE_Controller_Top_pcie_tl_rx_masknp_i(pcie_tl_rx_masknp),
      .PCIE_Controller_Top_pcie_tl_tx_sop_i(pcie_tl_tx_sop),
      .PCIE_Controller_Top_pcie_tl_tx_eop_i(pcie_tl_tx_eop),
      .PCIE_Controller_Top_pcie_tl_tx_data_i(pcie_tl_tx_data),
      .PCIE_Controller_Top_pcie_tl_tx_valid_i(pcie_tl_tx_valid),
      .PCIE_Controller_Top_pcie_tl_drp_addr_i(pcie_tl_drp_addr),
      .PCIE_Controller_Top_pcie_tl_drp_wrdata_i(pcie_tl_drp_wrdata),
      .PCIE_Controller_Top_pcie_tl_drp_strb_i(pcie_tl_drp_strb),
      .PCIE_Controller_Top_pcie_tl_drp_wr_i(pcie_tl_drp_wr),
      .PCIE_Controller_Top_pcie_tl_drp_rd_i(pcie_tl_drp_rd)
  );

  //**************************dut dma********************
  Pcie_Sgdma_Top u_dut (
      .pcie_rstn(pcie_rstn),
      .clk(sysclk),
      .pcie_tl_rx_sop(pcie_tl_rx_sop),
      .pcie_tl_rx_eop(pcie_tl_rx_eop),
      .pcie_tl_rx_data(pcie_tl_rx_data),
      .pcie_tl_rx_valid(pcie_tl_rx_valid),
      .pcie_tl_rx_bardec(pcie_tl_rx_bardec),
      .pcie_tl_rx_err(pcie_tl_rx_err),
      .pcie_tl_rx_wait(pcie_tl_rx_wait),
      .pcie_tl_rx_masknp(pcie_tl_rx_masknp),
      .pcie_tl_tx_sop(pcie_tl_tx_sop),
      .pcie_tl_tx_eop(pcie_tl_tx_eop),
      .pcie_tl_tx_data(pcie_tl_tx_data),
      .pcie_tl_tx_valid(pcie_tl_tx_valid),
      .pcie_tl_tx_wait(pcie_tl_tx_wait),
      .pcie_tl_int_status(pcie_tl_int_status),
      .pcie_tl_int_req(pcie_tl_int_req),
      .pcie_tl_int_msinum(pcie_tl_int_msinum),
      .pcie_tl_int_ack(pcie_tl_int_ack),
      .pcie_tl_drp_clk(pcie_tl_drp_clk),
      .pcie_tl_drp_addr(pcie_tl_drp_addr),
      .pcie_tl_drp_wr(pcie_tl_drp_wr),
      .pcie_tl_drp_wrdata(pcie_tl_drp_wrdata),
      .pcie_tl_drp_strb(pcie_tl_drp_strb),
      .pcie_tl_drp_rd(pcie_tl_drp_rd),
      .pcie_tl_drp_ready(pcie_tl_drp_ready),
      .pcie_tl_drp_rd_valid(pcie_tl_drp_rd_valid),
      .pcie_tl_drp_rddata(pcie_tl_drp_rddata),
      .pcie_tl_drp_resp(pcie_tl_drp_resp),
      .pcie_ltssm(pcie_ltssm),
      .pcie_linkup(pcie_linkup),
      .pcie_tl_cfg_busdev(pcie_tl_cfg_busdev),
      .m_axis_h2c_tready(m_axis_h2c_tready),
      .m_axis_h2c_tvalid(m_axis_h2c_tvalid),
      .m_axis_h2c_tdata(m_axis_h2c_tdata),
      .m_axis_h2c_tlast(m_axis_h2c_tlast),
      .m_axis_h2c_tuser(m_axis_h2c_tuser),
      .m_axis_h2c_tkeep(m_axis_h2c_tkeep),
      .h2c_overhead(h2c_overhead),
      .s_axis_c2h_tready(s_axis_c2h_tready),
      .s_axis_c2h_tvalid(s_axis_c2h_tvalid),
      .s_axis_c2h_tlast(s_axis_c2h_tlast),
      .s_axis_c2h_tdata(s_axis_c2h_tdata),
      .s_axis_c2h_tuser(s_axis_c2h_tuser),
      .s_axis_c2h_tkeep(s_axis_c2h_tkeep),
      .c2h_overhead_valid(c2h_overhead_valid),
      .c2h_overhead_data(c2h_overhead_data),
      .user_cs(user_cs),
      .user_address(user_address),
      .user_rw(user_rw),
      .user_wr_data(user_wr_data),
      .user_wr_be(user_wr_be),
      .user_rd_be(user_rd_be),
      .user_rd_valid(user_rd_valid),
      .user_rd_data(user_rd_data),
      .user_zero_read(user_zero_read),
      .h2c_run(h2c_run),
      .c2h_run(c2h_run)
  );

  //**************axi dma****************
  axi_dma #(
      .AXI_DATA_WIDTH(AXIDATAWIDTH),
      .AXI_ADDR_WIDTH(AXIADDRWIDTH),
      .AXI_STRB_WIDTH(AXISTRBWIDTH),
      .AXI_ID_WIDTH(AXIIDWIDTH),
      .AXI_MAX_BURST_LEN(16),
      .AXIS_DATA_WIDTH(256),
      .AXIS_KEEP_ENABLE(1),
      .AXIS_KEEP_WIDTH(32),
      .AXIS_LAST_ENABLE(1),
      .AXIS_ID_ENABLE(0),
      .AXIS_ID_WIDTH(8),
      .AXIS_DEST_ENABLE(0),
      .AXIS_DEST_WIDTH(8),
      .AXIS_USER_ENABLE(1),
      .AXIS_USER_WIDTH(32),
      .LEN_WIDTH(AXILENWIDTH),
      .TAG_WIDTH(8),
      .ENABLE_SG(0),
      .ENABLE_UNALIGNED(0)
  ) u_axi_dma (
      .clk(sysclk),
      .rst(!pcie_rstn),
      .s_axis_read_desc_addr(dma_read_desc_addr),
      .s_axis_read_desc_len(dma_read_desc_len),
      .s_axis_read_desc_tag(dma_read_desc_tag),
      .s_axis_read_desc_id(dma_read_desc_id),
      .s_axis_read_desc_dest(dma_read_desc_dest),
      .s_axis_read_desc_user(dma_read_desc_user),
      .s_axis_read_desc_valid(dma_read_desc_valid),
      .s_axis_read_desc_ready(dma_read_desc_ready),
      .m_axis_read_desc_status_tag(dma_read_status_tag),
      .m_axis_read_desc_status_error(dma_read_status_error),
      .m_axis_read_desc_status_valid(dma_read_status_valid),
      .m_axis_read_data_tdata(s_axis_c2h_tdata),
      .m_axis_read_data_tkeep(s_axis_c2h_tkeep),
      .m_axis_read_data_tvalid(s_axis_c2h_tvalid),
      .m_axis_read_data_tready(s_axis_c2h_tready),
      .m_axis_read_data_tlast(s_axis_c2h_tlast),
      .m_axis_read_data_tid(),
      .m_axis_read_data_tdest(),
      .m_axis_read_data_tuser(s_axis_c2h_tuser),
      .s_axis_write_desc_addr(dma_write_desc_addr),
      .s_axis_write_desc_len(dma_write_desc_len),
      .s_axis_write_desc_tag(dma_write_desc_tag),
      .s_axis_write_desc_valid(dma_write_desc_valid),
      .s_axis_write_desc_ready(dma_write_desc_ready),
      .m_axis_write_desc_status_len(dma_write_status_len),
      .m_axis_write_desc_status_tag(dma_write_status_tag),
      .m_axis_write_desc_status_id(dma_write_status_id),
      .m_axis_write_desc_status_dest(dma_write_status_dest),
      .m_axis_write_desc_status_user(dma_write_status_user),
      .m_axis_write_desc_status_error(dma_write_status_error),
      .m_axis_write_desc_status_valid(dma_write_status_valid),
      .s_axis_write_data_tdata(m_axis_h2c_tdata),
      .s_axis_write_data_tkeep(m_axis_h2c_tkeep),
      .s_axis_write_data_tvalid(m_axis_h2c_tvalid),
      .s_axis_write_data_tready(m_axis_h2c_tready),
      .s_axis_write_data_tlast(m_axis_h2c_tlast),
      .s_axis_write_data_tid(8'd0),
      .s_axis_write_data_tdest(8'd0),
      .s_axis_write_data_tuser(m_axis_h2c_tuser),
      .m_axi_awid(dma_axi_awid),
      .m_axi_awaddr(dma_axi_awaddr),
      .m_axi_awlen(dma_axi_awlen),
      .m_axi_awsize(dma_axi_awsize),
      .m_axi_awburst(dma_axi_awburst),
      .m_axi_awlock(dma_axi_awlock),
      .m_axi_awcache(dma_axi_awcache),
      .m_axi_awprot(dma_axi_awprot),
      .m_axi_awvalid(dma_axi_awvalid),
      .m_axi_awready(dma_axi_awready),
      .m_axi_wdata(dma_axi_wdata),
      .m_axi_wstrb(dma_axi_wstrb),
      .m_axi_wlast(dma_axi_wlast),
      .m_axi_wvalid(dma_axi_wvalid),
      .m_axi_wready(dma_axi_wready),
      .m_axi_bid(dma_axi_bid),
      .m_axi_bresp(dma_axi_bresp),
      .m_axi_bvalid(dma_axi_bvalid),
      .m_axi_bready(dma_axi_bready),
      .m_axi_arid(dma_axi_arid),
      .m_axi_araddr(dma_axi_araddr),
      .m_axi_arlen(dma_axi_arlen),
      .m_axi_arsize(dma_axi_arsize),
      .m_axi_arburst(dma_axi_arburst),
      .m_axi_arlock(dma_axi_arlock),
      .m_axi_arcache(dma_axi_arcache),
      .m_axi_arprot(dma_axi_arprot),
      .m_axi_arvalid(dma_axi_arvalid),
      .m_axi_arready(dma_axi_arready),
      .m_axi_rid(dma_axi_rid),
      .m_axi_rdata(dma_axi_rdata),
      .m_axi_rresp(dma_axi_rresp),
      .m_axi_rlast(dma_axi_rlast),
      .m_axi_rvalid(dma_axi_rvalid),
      .m_axi_rready(dma_axi_rready),
      .read_enable(1'b1),
      .write_enable(1'b1),
      .write_abort(1'b0)
  );

  //**************axi interconnect****************
  axi_interconnect #(
      .S_COUNT(1),
      .M_COUNT(1),
      .DATA_WIDTH(AXIDATAWIDTH),
      .ADDR_WIDTH(AXIADDRWIDTH),
      .STRB_WIDTH(AXISTRBWIDTH),
      .ID_WIDTH(AXIIDWIDTH),
      .M_REGIONS(1),
      .M_ADDR_WIDTH(32'd30)
  ) u_axi_interconnect (
      .clk(sysclk),
      .rst(!pcie_rstn),
      .s_axi_awid(dma_axi_awid),
      .s_axi_awaddr(dma_axi_awaddr),
      .s_axi_awlen(dma_axi_awlen),
      .s_axi_awsize(dma_axi_awsize),
      .s_axi_awburst(dma_axi_awburst),
      .s_axi_awlock(dma_axi_awlock),
      .s_axi_awcache(dma_axi_awcache),
      .s_axi_awprot(dma_axi_awprot),
      .s_axi_awqos(4'd0),
      .s_axi_awuser(1'b0),
      .s_axi_awvalid(dma_axi_awvalid),
      .s_axi_awready(dma_axi_awready),
      .s_axi_wdata(dma_axi_wdata),
      .s_axi_wstrb(dma_axi_wstrb),
      .s_axi_wlast(dma_axi_wlast),
      .s_axi_wuser(1'b0),
      .s_axi_wvalid(dma_axi_wvalid),
      .s_axi_wready(dma_axi_wready),
      .s_axi_bid(dma_axi_bid),
      .s_axi_bresp(dma_axi_bresp),
      .s_axi_buser(),
      .s_axi_bvalid(dma_axi_bvalid),
      .s_axi_bready(dma_axi_bready),
      .s_axi_arid(dma_axi_arid),
      .s_axi_araddr(dma_axi_araddr),
      .s_axi_arlen(dma_axi_arlen),
      .s_axi_arsize(dma_axi_arsize),
      .s_axi_arburst(dma_axi_arburst),
      .s_axi_arlock(dma_axi_arlock),
      .s_axi_arcache(dma_axi_arcache),
      .s_axi_arprot(dma_axi_arprot),
      .s_axi_arqos(4'd0),
      .s_axi_aruser(1'b0),
      .s_axi_arvalid(dma_axi_arvalid),
      .s_axi_arready(dma_axi_arready),
      .s_axi_rid(dma_axi_rid),
      .s_axi_rdata(dma_axi_rdata),
      .s_axi_rresp(dma_axi_rresp),
      .s_axi_rlast(dma_axi_rlast),
      .s_axi_ruser(),
      .s_axi_rvalid(dma_axi_rvalid),
      .s_axi_rready(dma_axi_rready),
      .m_axi_awid(ic_m_axi_awid),
      .m_axi_awaddr(ic_m_axi_awaddr),
      .m_axi_awlen(ic_m_axi_awlen),
      .m_axi_awsize(ic_m_axi_awsize),
      .m_axi_awburst(ic_m_axi_awburst),
      .m_axi_awlock(ic_m_axi_awlock),
      .m_axi_awcache(ic_m_axi_awcache),
      .m_axi_awprot(ic_m_axi_awprot),
      .m_axi_awqos(ic_m_axi_awqos),
      .m_axi_awregion(ic_m_axi_awregion),
      .m_axi_awuser(ic_m_axi_awuser),
      .m_axi_awvalid(ic_m_axi_awvalid),
      .m_axi_awready(ic_m_axi_awready),
      .m_axi_wdata(ic_m_axi_wdata),
      .m_axi_wstrb(ic_m_axi_wstrb),
      .m_axi_wlast(ic_m_axi_wlast),
      .m_axi_wuser(ic_m_axi_wuser),
      .m_axi_wvalid(ic_m_axi_wvalid),
      .m_axi_wready(ic_m_axi_wready),
      .m_axi_bid(ic_m_axi_bid),
      .m_axi_bresp(ic_m_axi_bresp),
      .m_axi_buser(ic_m_axi_buser),
      .m_axi_bvalid(ic_m_axi_bvalid),
      .m_axi_bready(ic_m_axi_bready),
      .m_axi_arid(ic_m_axi_arid),
      .m_axi_araddr(ic_m_axi_araddr),
      .m_axi_arlen(ic_m_axi_arlen),
      .m_axi_arsize(ic_m_axi_arsize),
      .m_axi_arburst(ic_m_axi_arburst),
      .m_axi_arlock(ic_m_axi_arlock),
      .m_axi_arcache(ic_m_axi_arcache),
      .m_axi_arprot(ic_m_axi_arprot),
      .m_axi_arqos(ic_m_axi_arqos),
      .m_axi_arregion(ic_m_axi_arregion),
      .m_axi_aruser(ic_m_axi_aruser),
      .m_axi_arvalid(ic_m_axi_arvalid),
      .m_axi_arready(ic_m_axi_arready),
      .m_axi_rid(ic_m_axi_rid),
      .m_axi_rdata(ic_m_axi_rdata),
      .m_axi_rresp(ic_m_axi_rresp),
      .m_axi_rlast(ic_m_axi_rlast),
      .m_axi_ruser(ic_m_axi_ruser),
      .m_axi_rvalid(ic_m_axi_rvalid),
      .m_axi_rready(ic_m_axi_rready)
  );

  assign ic_m_axi_awready = 1'b0;
  assign ic_m_axi_wready = 1'b0;
  assign ic_m_axi_bid = {AXIIDWIDTH{1'b0}};
  assign ic_m_axi_bresp = 2'b00;
  assign ic_m_axi_buser = 1'b0;
  assign ic_m_axi_bvalid = 1'b0;
  assign ic_m_axi_arready = 1'b0;
  assign ic_m_axi_rid = {AXIIDWIDTH{1'b0}};
  assign ic_m_axi_rdata = {AXIDATAWIDTH{1'b0}};
  assign ic_m_axi_rresp = 2'b00;
  assign ic_m_axi_rlast = 1'b0;
  assign ic_m_axi_ruser = 1'b0;
  assign ic_m_axi_rvalid = 1'b0;
endmodule
