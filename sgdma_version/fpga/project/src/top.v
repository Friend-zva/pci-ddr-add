module top (
    input sys_clk_p,
    input pcie_rstn,
    input rst_n,

    output [5:0] led,

    output [13:0] ddr_addr,
    output [2:0] ddr_bank,
    output ddr_cs,
    output ddr_ras,
    output ddr_cas,
    output ddr_we,
    output ddr_ck,
    output ddr_ck_n,
    output ddr_cke,
    output ddr_odt,
    output ddr_reset_n,
    output [3:0] ddr_dm,
    inout [31:0] ddr_dq,
    inout [3:0] ddr_dqs,
    inout [3:0] ddr_dqs_n
);

  localparam PCIE_DLY = 8;  //25~500ms
  localparam PERST_DLY = 25;
  localparam RUN_DLY = 23;
  localparam SYS_RST_DLY = 20;


  /* Clocks & Reset */
  // Clocks
  wire sys_clk;
  /* synthesis syn_keep = 1 */
  wire cfg_clk;
  /* synthesis syn_keep = 1 */
  wire ddr_clk;
  /* synthesis syn_keep = 1 */
  wire memory_clk;
  /* synthesis syn_keep = 1 */
  wire div_clk, tlp_clk;
  wire pll_50m_clk, pll_200m_clk, pll_400m_clk;
  wire pll_lock, pll_stop;

  Gowin_PLL u_pll (
      .clkin(sys_clk_p),
      .init_clk(sys_clk_p),
      .clkout0(pll_50m_clk),
      .clkout1(pll_200m_clk),
      .clkout2(pll_400m_clk),
      .enclk0(1'b1),
      .enclk1(1'b1),
      .enclk2(pll_stop),
      .lock(pll_lock),
      .reset(~rst_n)
  );
  assign ddr_clk = pll_50m_clk;  //? recommend in ip core guide [maybe try]
  assign sys_clk = pll_200m_clk;
  assign memory_clk = pll_400m_clk;

  CLKDIV #(
      .DIV_MODE("2")
  ) uut_div2 (
      div_clk,
      'b0,
      sys_clk,
      'b1
  );
  assign cfg_clk = div_clk;
  assign tlp_clk = div_clk;

  // Reset generate
  reg  [         26:0] pcie_st_cnt = 0;
  reg  [         26:0] run_cnt = 0;
  reg  [         26:0] perst_cnt = 0;
  reg  [SYS_RST_DLY:0] sys_rst_cnt = 0;

  wire                 w_rst_n = rst_n & pcie_rstn;
  wire                 pcie_start;
  wire                 tlp_rst = !pcie_start;
  wire                 tlp_rst_n = rst_n & pcie_start;

  // PCIE Start Delay
  always @(posedge cfg_clk or negedge w_rst_n)
    if (!w_rst_n) sys_rst_cnt <= 0;
    else if (!sys_rst_cnt[SYS_RST_DLY]) sys_rst_cnt <= sys_rst_cnt + 2'd1;

  wire rstn = sys_rst_cnt[SYS_RST_DLY];

  always @(posedge cfg_clk or negedge rstn)
    if (!rstn) perst_cnt <= 0;
    else if (!perst_cnt[PERST_DLY]) perst_cnt <= perst_cnt + 2'd1;

  always @(posedge cfg_clk or negedge rstn)
    if (!rstn) pcie_st_cnt <= 0;
    else if (!pcie_start) pcie_st_cnt <= pcie_st_cnt + 2'd1;

  assign pcie_start = pcie_st_cnt[PCIE_DLY] ? 1'b1 : 1'b0;

  // for Led blink
  always @(posedge cfg_clk or negedge w_rst_n)
    if (!w_rst_n) run_cnt <= 0;
    else run_cnt <= run_cnt + 2'd1;

  wire pcie_linkup;
  wire ddr_init_calib_complete;
  wire h2c_run = 1'b0;  //? 1'b1
  wire c2h_run = 1'b0;
  reg  pcie_linkup_r;
  /* synthesis syn_keep = 1 */

  always @(posedge tlp_clk) pcie_linkup_r <= pcie_linkup;

  assign led[0] = ~run_cnt[RUN_DLY];
  assign led[1] = ~perst_cnt[PERST_DLY];
  assign led[2] = ~pcie_start;
  assign led[3] = ~pcie_linkup_r;
  assign led[4] = ~ddr_init_calib_complete;
  assign led[5] = ~h2c_run;

  /* PCIe IP */
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
  wire [ 31:0] PCIE_Controller_Top_pcie_tl_tx_creditsp;
  wire [ 31:0] PCIE_Controller_Top_pcie_tl_tx_creditsnp;
  wire [ 31:0] PCIE_Controller_Top_pcie_tl_tx_creditscpl;
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

  //BAR2
  wire         user_cs;
  wire [ 63:0] user_address;
  wire         user_rw;
  wire [ 31:0] user_wr_data;
  wire [  3:0] user_wr_be;
  wire [  3:0] user_rd_be;
  wire         user_rd_valid;
  wire [ 31:0] user_rd_data;
  wire         user_zero_read;

  localparam integer AXIDATAWIDTH = 256;
  localparam integer AXIADDRWIDTH = 29;
  localparam integer AXISTRBWIDTH = AXIDATAWIDTH / 8;
  localparam integer AXIIDWIDTH = 4;
  localparam integer AXILENWIDTH = 20;

  wire                      ddr_clk_out;
  wire                      ddr_rst;
  wire                      ddr_sr_ack;
  wire                      ddr_ref_ack;

  wire [  AXIADDRWIDTH-1:0] dma_read_desc_addr;
  wire [   AXILENWIDTH-1:0] dma_read_desc_len;
  wire [             7 : 0] dma_read_desc_tag;
  wire [             7 : 0] dma_read_desc_id;
  wire [             7 : 0] dma_read_desc_dest;
  wire [            31 : 0] dma_read_desc_user;
  wire                      dma_read_desc_valid;
  wire                      dma_read_desc_ready;
  wire [             7 : 0] dma_read_status_tag;
  wire [             3 : 0] dma_read_status_error;
  wire                      dma_read_status_valid;

  wire [  AXIADDRWIDTH-1:0] dma_write_desc_addr;
  wire [   AXILENWIDTH-1:0] dma_write_desc_len;
  wire [             7 : 0] dma_write_desc_tag;
  wire                      dma_write_desc_valid;
  wire                      dma_write_desc_ready;
  wire [   AXILENWIDTH-1:0] dma_write_status_len;
  wire [             7 : 0] dma_write_status_tag;
  wire [             7 : 0] dma_write_status_id;
  wire [             7 : 0] dma_write_status_dest;
  wire [            31 : 0] dma_write_status_user;
  wire [             3 : 0] dma_write_status_error;
  wire                      dma_write_status_valid;

  // logic_adder <-> axi_dma stream/descriptors
  wire                      lad_h2c_tready;
  wire                      lad_h2c_tvalid;
  wire [           255 : 0] lad_h2c_tdata;
  wire                      lad_h2c_tlast;
  wire [            31 : 0] lad_h2c_tuser;
  wire [            31 : 0] lad_h2c_tkeep;
  wire [            63 : 0] lad_h2c_overhead;

  wire                      lad_c2h_tready;
  wire                      lad_c2h_tvalid;
  wire                      lad_c2h_tlast;
  wire [           255 : 0] lad_c2h_tdata;
  wire [            31 : 0] lad_c2h_tuser;
  wire [            31 : 0] lad_c2h_tkeep;
  wire                      lad_c2h_overhead_valid;
  wire [            63 : 0] lad_c2h_overhead_data;

  wire [            63 : 0] lad_read_desc_addr;
  wire [            31 : 0] lad_read_desc_len;
  wire [             7 : 0] lad_read_desc_tag;
  wire                      lad_read_desc_valid;
  wire                      lad_read_desc_ready;

  wire [            63 : 0] lad_write_desc_addr;
  wire [            31 : 0] lad_write_desc_len;
  wire [             7 : 0] lad_write_desc_tag;
  wire                      lad_write_desc_valid;
  wire                      lad_write_desc_ready;

  wire [             7 : 0] lad_dma_read_status_tag;
  wire [             3 : 0] lad_dma_read_status_error;
  wire                      lad_dma_read_status_valid;
  wire [   AXILENWIDTH-1:0] lad_dma_write_status_len;
  wire [             7 : 0] lad_dma_write_status_tag;
  wire [             7 : 0] lad_dma_write_status_id;
  wire [             7 : 0] lad_dma_write_status_dest;
  wire [            31 : 0] lad_dma_write_status_user;
  wire [             3 : 0] lad_dma_write_status_error;
  wire                      lad_dma_write_status_valid;

  wire                      lad_h2c_run;
  wire                      lad_c2h_run;
  wire                      lad_busy;
  wire                      lad_done;
  wire [            63 : 0] lad_cfg_read_addr;
  wire [            63 : 0] lad_cfg_write_addr;
  wire [            31 : 0] lad_cfg_byte_len;
  wire [             7 : 0] lad_cfg_desc_tag;

  wire [    AXIIDWIDTH-1:0] dma_axi_awid;
  wire [  AXIADDRWIDTH-1:0] dma_axi_awaddr;
  wire [               7:0] dma_axi_awlen;
  wire [               2:0] dma_axi_awsize;
  wire [               1:0] dma_axi_awburst;
  wire                      dma_axi_awlock;
  wire [               3:0] dma_axi_awcache;
  wire [               2:0] dma_axi_awprot;
  wire                      dma_axi_awvalid;
  wire                      dma_axi_awready;
  wire [  AXIDATAWIDTH-1:0] dma_axi_wdata;
  wire [  AXISTRBWIDTH-1:0] dma_axi_wstrb;
  wire                      dma_axi_wlast;
  wire                      dma_axi_wvalid;
  wire                      dma_axi_wready;
  wire [    AXIIDWIDTH-1:0] dma_axi_bid;
  wire [               1:0] dma_axi_bresp;
  wire                      dma_axi_bvalid;
  wire                      dma_axi_bready;
  wire [    AXIIDWIDTH-1:0] dma_axi_arid;
  wire [  AXIADDRWIDTH-1:0] dma_axi_araddr;
  wire [               7:0] dma_axi_arlen;
  wire [               2:0] dma_axi_arsize;
  wire [               1:0] dma_axi_arburst;
  wire                      dma_axi_arlock;
  wire [               3:0] dma_axi_arcache;
  wire [               2:0] dma_axi_arprot;
  wire                      dma_axi_arvalid;
  wire                      dma_axi_arready;
  wire [    AXIIDWIDTH-1:0] dma_axi_rid;
  wire [  AXIDATAWIDTH-1:0] dma_axi_rdata;
  wire [               1:0] dma_axi_rresp;
  wire                      dma_axi_rlast;
  wire                      dma_axi_rvalid;
  wire                      dma_axi_rready;

  wire [    AXIIDWIDTH-1:0] lad_dma_axi_awid;
  wire [  AXIADDRWIDTH-1:0] lad_dma_axi_awaddr;
  wire [               7:0] lad_dma_axi_awlen;
  wire [               2:0] lad_dma_axi_awsize;
  wire [               1:0] lad_dma_axi_awburst;
  wire                      lad_dma_axi_awlock;
  wire [               3:0] lad_dma_axi_awcache;
  wire [               2:0] lad_dma_axi_awprot;
  wire                      lad_dma_axi_awvalid;
  wire                      lad_dma_axi_awready;
  wire [  AXIDATAWIDTH-1:0] lad_dma_axi_wdata;
  wire [  AXISTRBWIDTH-1:0] lad_dma_axi_wstrb;
  wire                      lad_dma_axi_wlast;
  wire                      lad_dma_axi_wvalid;
  wire                      lad_dma_axi_wready;
  wire [    AXIIDWIDTH-1:0] lad_dma_axi_bid;
  wire [               1:0] lad_dma_axi_bresp;
  wire                      lad_dma_axi_bvalid;
  wire                      lad_dma_axi_bready;
  wire [    AXIIDWIDTH-1:0] lad_dma_axi_arid;
  wire [  AXIADDRWIDTH-1:0] lad_dma_axi_araddr;
  wire [               7:0] lad_dma_axi_arlen;
  wire [               2:0] lad_dma_axi_arsize;
  wire [               1:0] lad_dma_axi_arburst;
  wire                      lad_dma_axi_arlock;
  wire [               3:0] lad_dma_axi_arcache;
  wire [               2:0] lad_dma_axi_arprot;
  wire                      lad_dma_axi_arvalid;
  wire                      lad_dma_axi_arready;
  wire [    AXIIDWIDTH-1:0] lad_dma_axi_rid;
  wire [  AXIDATAWIDTH-1:0] lad_dma_axi_rdata;
  wire [               1:0] lad_dma_axi_rresp;
  wire                      lad_dma_axi_rlast;
  wire                      lad_dma_axi_rvalid;
  wire                      lad_dma_axi_rready;

  wire [             2-1:0] ic_s_axi_awready;
  wire [             2-1:0] ic_s_axi_wready;
  wire [  2*AXIIDWIDTH-1:0] ic_s_axi_bid;
  wire [           2*2-1:0] ic_s_axi_bresp;
  wire [             2-1:0] ic_s_axi_bvalid;
  wire [             2-1:0] ic_s_axi_arready;
  wire [  2*AXIIDWIDTH-1:0] ic_s_axi_rid;
  wire [2*AXIDATAWIDTH-1:0] ic_s_axi_rdata;
  wire [           2*2-1:0] ic_s_axi_rresp;
  wire [             2-1:0] ic_s_axi_rlast;
  wire [             2-1:0] ic_s_axi_rvalid;

  wire [    AXIIDWIDTH-1:0] ic_m_axi_awid;
  wire [  AXIADDRWIDTH-1:0] ic_m_axi_awaddr;
  wire [               7:0] ic_m_axi_awlen;
  wire [               2:0] ic_m_axi_awsize;
  wire [               1:0] ic_m_axi_awburst;
  wire                      ic_m_axi_awlock;
  wire [               3:0] ic_m_axi_awcache;
  wire [               2:0] ic_m_axi_awprot;
  wire [               3:0] ic_m_axi_awqos;
  wire [               3:0] ic_m_axi_awregion;
  wire                      ic_m_axi_awuser;
  wire                      ic_m_axi_awvalid;
  wire                      ic_m_axi_awready;
  wire [  AXIDATAWIDTH-1:0] ic_m_axi_wdata;
  wire [  AXISTRBWIDTH-1:0] ic_m_axi_wstrb;
  wire                      ic_m_axi_wlast;
  wire                      ic_m_axi_wuser;
  wire                      ic_m_axi_wvalid;
  wire                      ic_m_axi_wready;
  wire [    AXIIDWIDTH-1:0] ic_m_axi_bid;
  wire [               1:0] ic_m_axi_bresp;
  wire                      ic_m_axi_buser;
  wire                      ic_m_axi_bvalid;
  wire                      ic_m_axi_bready;
  wire [    AXIIDWIDTH-1:0] ic_m_axi_arid;
  wire [  AXIADDRWIDTH-1:0] ic_m_axi_araddr;
  wire [               7:0] ic_m_axi_arlen;
  wire [               2:0] ic_m_axi_arsize;
  wire [               1:0] ic_m_axi_arburst;
  wire                      ic_m_axi_arlock;
  wire [               3:0] ic_m_axi_arcache;
  wire [               2:0] ic_m_axi_arprot;
  wire [               3:0] ic_m_axi_arqos;
  wire [               3:0] ic_m_axi_arregion;
  wire                      ic_m_axi_aruser;
  wire                      ic_m_axi_arvalid;
  wire                      ic_m_axi_arready;
  wire [    AXIIDWIDTH-1:0] ic_m_axi_rid;
  wire [  AXIDATAWIDTH-1:0] ic_m_axi_rdata;
  wire [               1:0] ic_m_axi_rresp;
  wire                      ic_m_axi_rlast;
  wire                      ic_m_axi_ruser;
  wire                      ic_m_axi_rvalid;
  wire                      ic_m_axi_rready;

  assign dma_read_desc_tag  = 8'd0;
  assign dma_read_desc_id   = 8'd0;
  assign dma_read_desc_dest = 8'd0;
  assign dma_read_desc_user = 32'd0;
  assign dma_write_desc_tag = 8'd0;
  assign c2h_overhead_valid = 1'b0;
  assign c2h_overhead_data  = 64'd0;
  assign lad_h2c_overhead   = 64'd0;

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
      .PCIE_Controller_Top_pcie_rstn_i(rst_n),
      .PCIE_Controller_Top_pcie_tl_clk_i(tlp_clk),
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
      .PCIE_Controller_Top_pcie_tl_drp_rd_i(pcie_tl_drp_rd),
      .PCIE_Controller_Top_pcie_tl_int_status_i(pcie_tl_int_status),
      .PCIE_Controller_Top_pcie_tl_int_req_i(pcie_tl_int_req),
      .PCIE_Controller_Top_pcie_tl_int_msinum_i(pcie_tl_int_msinum),
      .PCIE_Controller_Top_pcie_tl_int_ack_o(pcie_tl_int_ack)
  );

  //**************************dut dma********************
  Pcie_Sgdma_Top u_dut (
      .pcie_rstn(rst_n),
      .clk(tlp_clk),
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

  //**************logic dma control (BAR2)****************
  logic_dma #(
      .AXIADDRWIDTH(AXIADDRWIDTH),
      .AXILENWIDTH (AXILENWIDTH)
  ) u_logic_dma (
      .clk(tlp_clk),
      .rstn(tlp_rst_n),
      .user_cs(user_cs),
      .user_address(user_address),
      .user_rw(user_rw),
      .user_wr_data(user_wr_data),
      .user_wr_be(user_wr_be),
      .user_rd_be(user_rd_be),
      .user_rd_valid(user_rd_valid),
      .user_rd_data(user_rd_data),
      .pcie_read_desc_addr(dma_write_desc_addr),
      .pcie_read_desc_len(dma_write_desc_len),
      .pcie_read_desc_tag(),
      .pcie_read_desc_valid(dma_write_desc_valid),
      .pcie_read_desc_ready(dma_write_desc_ready),
      .pcie_write_desc_addr(dma_read_desc_addr),
      .pcie_write_desc_len(dma_read_desc_len),
      .pcie_write_desc_tag(),
      .pcie_write_desc_valid(dma_read_desc_valid),
      .pcie_write_desc_ready(dma_read_desc_ready),
      .lad_read_addr(lad_cfg_read_addr),
      .lad_write_addr(lad_cfg_write_addr),
      .lad_byte_len(lad_cfg_byte_len),
      .lad_desc_tag(lad_cfg_desc_tag),
      .lad_h2c_run(lad_h2c_run),
      .lad_c2h_run(lad_c2h_run),
      .lad_busy(lad_busy),
      .lad_done(lad_done)
  );

  //**************axi dma (pcie_sgdma)****************
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
  ) u_axi_dma_pcie_sgdma (
      .clk(tlp_clk),
      .rst(tlp_rst),
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

  //**************logic_adder****************
  logic_adder u_logic_adder (
      .clk(tlp_clk),
      .rstn(tlp_rst_n),
      .cfg_read_addr(lad_cfg_read_addr),
      .cfg_write_addr(lad_cfg_write_addr),
      .cfg_byte_len(lad_cfg_byte_len),
      .cfg_desc_tag(lad_cfg_desc_tag),
      .s_axis_read_desc_valid(lad_read_desc_valid),
      .s_axis_read_desc_ready(lad_read_desc_ready),
      .s_axis_read_desc_addr(lad_read_desc_addr),
      .s_axis_read_desc_len(lad_read_desc_len),
      .s_axis_read_desc_tag(lad_read_desc_tag),
      .s_axis_write_desc_valid(lad_write_desc_valid),
      .s_axis_write_desc_ready(lad_write_desc_ready),
      .s_axis_write_desc_addr(lad_write_desc_addr),
      .s_axis_write_desc_len(lad_write_desc_len),
      .s_axis_write_desc_tag(lad_write_desc_tag),
      .m_axis_h2c_tready(lad_h2c_tready),
      .m_axis_h2c_tvalid(lad_h2c_tvalid),
      .m_axis_h2c_tdata(lad_h2c_tdata),
      .m_axis_h2c_tlast(lad_h2c_tlast),
      .m_axis_h2c_tuser(lad_h2c_tuser),
      .m_axis_h2c_tkeep(lad_h2c_tkeep),
      .h2c_overhead(lad_h2c_overhead),
      .s_axis_c2h_tready(lad_c2h_tready),
      .s_axis_c2h_tvalid(lad_c2h_tvalid),
      .s_axis_c2h_tlast(lad_c2h_tlast),
      .s_axis_c2h_tdata(lad_c2h_tdata),
      .s_axis_c2h_tuser(lad_c2h_tuser),
      .s_axis_c2h_tkeep(lad_c2h_tkeep),
      .c2h_overhead_valid(lad_c2h_overhead_valid),
      .c2h_overhead_data(lad_c2h_overhead_data),
      .h2c_run(lad_h2c_run),
      .c2h_run(lad_c2h_run),
      .busy(lad_busy),
      .done(lad_done)
  );

  //**************axi dma (logic_adder)****************
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
  ) u_axi_dma_logic_adder (
      .clk(tlp_clk),
      .rst(tlp_rst),
      .s_axis_read_desc_addr(lad_read_desc_addr[AXIADDRWIDTH-1:0]),
      .s_axis_read_desc_len(lad_read_desc_len[AXILENWIDTH-1:0]),
      .s_axis_read_desc_tag(lad_read_desc_tag),
      .s_axis_read_desc_id(8'd0),
      .s_axis_read_desc_dest(8'd0),
      .s_axis_read_desc_user(32'd0),
      .s_axis_read_desc_valid(lad_read_desc_valid),
      .s_axis_read_desc_ready(lad_read_desc_ready),
      .m_axis_read_desc_status_tag(lad_dma_read_status_tag),
      .m_axis_read_desc_status_error(lad_dma_read_status_error),
      .m_axis_read_desc_status_valid(lad_dma_read_status_valid),
      .m_axis_read_data_tdata(lad_h2c_tdata),
      .m_axis_read_data_tkeep(lad_h2c_tkeep),
      .m_axis_read_data_tvalid(lad_h2c_tvalid),
      .m_axis_read_data_tready(lad_h2c_tready),
      .m_axis_read_data_tlast(lad_h2c_tlast),
      .m_axis_read_data_tid(),
      .m_axis_read_data_tdest(),
      .m_axis_read_data_tuser(lad_h2c_tuser),
      .s_axis_write_desc_addr(lad_write_desc_addr[AXIADDRWIDTH-1:0]),
      .s_axis_write_desc_len(lad_write_desc_len[AXILENWIDTH-1:0]),
      .s_axis_write_desc_tag(lad_write_desc_tag),
      .s_axis_write_desc_valid(lad_write_desc_valid),
      .s_axis_write_desc_ready(lad_write_desc_ready),
      .m_axis_write_desc_status_len(lad_dma_write_status_len),
      .m_axis_write_desc_status_tag(lad_dma_write_status_tag),
      .m_axis_write_desc_status_id(lad_dma_write_status_id),
      .m_axis_write_desc_status_dest(lad_dma_write_status_dest),
      .m_axis_write_desc_status_user(lad_dma_write_status_user),
      .m_axis_write_desc_status_error(lad_dma_write_status_error),
      .m_axis_write_desc_status_valid(lad_dma_write_status_valid),
      .s_axis_write_data_tdata(lad_c2h_tdata),
      .s_axis_write_data_tkeep(lad_c2h_tkeep),
      .s_axis_write_data_tvalid(lad_c2h_tvalid),
      .s_axis_write_data_tready(lad_c2h_tready),
      .s_axis_write_data_tlast(lad_c2h_tlast),
      .s_axis_write_data_tid(8'd0),
      .s_axis_write_data_tdest(8'd0),
      .s_axis_write_data_tuser(lad_c2h_tuser),
      .m_axi_awid(lad_dma_axi_awid),
      .m_axi_awaddr(lad_dma_axi_awaddr),
      .m_axi_awlen(lad_dma_axi_awlen),
      .m_axi_awsize(lad_dma_axi_awsize),
      .m_axi_awburst(lad_dma_axi_awburst),
      .m_axi_awlock(lad_dma_axi_awlock),
      .m_axi_awcache(lad_dma_axi_awcache),
      .m_axi_awprot(lad_dma_axi_awprot),
      .m_axi_awvalid(lad_dma_axi_awvalid),
      .m_axi_awready(lad_dma_axi_awready),
      .m_axi_wdata(lad_dma_axi_wdata),
      .m_axi_wstrb(lad_dma_axi_wstrb),
      .m_axi_wlast(lad_dma_axi_wlast),
      .m_axi_wvalid(lad_dma_axi_wvalid),
      .m_axi_wready(lad_dma_axi_wready),
      .m_axi_bid(lad_dma_axi_bid),
      .m_axi_bresp(lad_dma_axi_bresp),
      .m_axi_bvalid(lad_dma_axi_bvalid),
      .m_axi_bready(lad_dma_axi_bready),
      .m_axi_arid(lad_dma_axi_arid),
      .m_axi_araddr(lad_dma_axi_araddr),
      .m_axi_arlen(lad_dma_axi_arlen),
      .m_axi_arsize(lad_dma_axi_arsize),
      .m_axi_arburst(lad_dma_axi_arburst),
      .m_axi_arlock(lad_dma_axi_arlock),
      .m_axi_arcache(lad_dma_axi_arcache),
      .m_axi_arprot(lad_dma_axi_arprot),
      .m_axi_arvalid(lad_dma_axi_arvalid),
      .m_axi_arready(lad_dma_axi_arready),
      .m_axi_rid(lad_dma_axi_rid),
      .m_axi_rdata(lad_dma_axi_rdata),
      .m_axi_rresp(lad_dma_axi_rresp),
      .m_axi_rlast(lad_dma_axi_rlast),
      .m_axi_rvalid(lad_dma_axi_rvalid),
      .m_axi_rready(lad_dma_axi_rready),
      .read_enable(1'b1),
      .write_enable(1'b1),
      .write_abort(1'b0)
  );

  //**************axi interconnect****************
  axi_interconnect #(
      .S_COUNT(2),
      .M_COUNT(1),
      .DATA_WIDTH(AXIDATAWIDTH),
      .ADDR_WIDTH(AXIADDRWIDTH),
      .STRB_WIDTH(AXISTRBWIDTH),
      .ID_WIDTH(AXIIDWIDTH),
      .M_REGIONS(1),
      .M_ADDR_WIDTH(32'd29)
  ) u_axi_interconnect (
      .clk(tlp_clk),
      .rst(tlp_rst),
      .s_axi_awid({lad_dma_axi_awid, dma_axi_awid}),
      .s_axi_awaddr({lad_dma_axi_awaddr, dma_axi_awaddr}),
      .s_axi_awlen({lad_dma_axi_awlen, dma_axi_awlen}),
      .s_axi_awsize({lad_dma_axi_awsize, dma_axi_awsize}),
      .s_axi_awburst({lad_dma_axi_awburst, dma_axi_awburst}),
      .s_axi_awlock({lad_dma_axi_awlock, dma_axi_awlock}),
      .s_axi_awcache({lad_dma_axi_awcache, dma_axi_awcache}),
      .s_axi_awprot({lad_dma_axi_awprot, dma_axi_awprot}),
      .s_axi_awqos({4'd0, 4'd0}),
      .s_axi_awuser(2'b00),
      .s_axi_awvalid({lad_dma_axi_awvalid, dma_axi_awvalid}),
      .s_axi_awready(ic_s_axi_awready),
      .s_axi_wdata({lad_dma_axi_wdata, dma_axi_wdata}),
      .s_axi_wstrb({lad_dma_axi_wstrb, dma_axi_wstrb}),
      .s_axi_wlast({lad_dma_axi_wlast, dma_axi_wlast}),
      .s_axi_wuser(2'b00),
      .s_axi_wvalid({lad_dma_axi_wvalid, dma_axi_wvalid}),
      .s_axi_wready(ic_s_axi_wready),
      .s_axi_bid(ic_s_axi_bid),
      .s_axi_bresp(ic_s_axi_bresp),
      .s_axi_buser(),
      .s_axi_bvalid(ic_s_axi_bvalid),
      .s_axi_bready({lad_dma_axi_bready, dma_axi_bready}),
      .s_axi_arid({lad_dma_axi_arid, dma_axi_arid}),
      .s_axi_araddr({lad_dma_axi_araddr, dma_axi_araddr}),
      .s_axi_arlen({lad_dma_axi_arlen, dma_axi_arlen}),
      .s_axi_arsize({lad_dma_axi_arsize, dma_axi_arsize}),
      .s_axi_arburst({lad_dma_axi_arburst, dma_axi_arburst}),
      .s_axi_arlock({lad_dma_axi_arlock, dma_axi_arlock}),
      .s_axi_arcache({lad_dma_axi_arcache, dma_axi_arcache}),
      .s_axi_arprot({lad_dma_axi_arprot, dma_axi_arprot}),
      .s_axi_arqos({4'd0, 4'd0}),
      .s_axi_aruser(2'b00),
      .s_axi_arvalid({lad_dma_axi_arvalid, dma_axi_arvalid}),
      .s_axi_arready(ic_s_axi_arready),
      .s_axi_rid(ic_s_axi_rid),
      .s_axi_rdata(ic_s_axi_rdata),
      .s_axi_rresp(ic_s_axi_rresp),
      .s_axi_rlast(ic_s_axi_rlast),
      .s_axi_ruser(),
      .s_axi_rvalid(ic_s_axi_rvalid),
      .s_axi_rready({lad_dma_axi_rready, dma_axi_rready}),
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

  assign {lad_dma_axi_awready, dma_axi_awready} = ic_s_axi_awready;
  assign {lad_dma_axi_wready, dma_axi_wready} = ic_s_axi_wready;
  assign {lad_dma_axi_bid, dma_axi_bid} = ic_s_axi_bid;
  assign {lad_dma_axi_bresp, dma_axi_bresp} = ic_s_axi_bresp;
  assign {lad_dma_axi_bvalid, dma_axi_bvalid} = ic_s_axi_bvalid;
  assign {lad_dma_axi_arready, dma_axi_arready} = ic_s_axi_arready;
  assign {lad_dma_axi_rid, dma_axi_rid} = ic_s_axi_rid;
  assign {lad_dma_axi_rdata, dma_axi_rdata} = ic_s_axi_rdata;
  assign {lad_dma_axi_rresp, dma_axi_rresp} = ic_s_axi_rresp;
  assign {lad_dma_axi_rlast, dma_axi_rlast} = ic_s_axi_rlast;
  assign {lad_dma_axi_rvalid, dma_axi_rvalid} = ic_s_axi_rvalid;

  //**************ddr3 memory interface****************
  DDR3_Memory_Interface_Top u_ddr3 (
      .clk(tlp_clk),
      .pll_stop(pll_stop),
      .memory_clk(memory_clk),
      .pll_lock(pll_lock),
      .rst_n(tlp_rst_n),
      .clk_out(ddr_clk_out),
      .ddr_rst(ddr_rst),
      .init_calib_complete(ddr_init_calib_complete),
      .s_axi_awvalid(ic_m_axi_awvalid),
      .s_axi_awready(ic_m_axi_awready),
      .s_axi_awid(ic_m_axi_awid),
      .s_axi_awaddr(ic_m_axi_awaddr),
      .s_axi_awlen(ic_m_axi_awlen),
      .s_axi_awsize(ic_m_axi_awsize),
      .s_axi_awburst(ic_m_axi_awburst),
      .s_axi_wvalid(ic_m_axi_wvalid),
      .s_axi_wready(ic_m_axi_wready),
      .s_axi_wdata(ic_m_axi_wdata),
      .s_axi_wstrb(ic_m_axi_wstrb),
      .s_axi_wlast(ic_m_axi_wlast),
      .s_axi_bvalid(ic_m_axi_bvalid),
      .s_axi_bready(ic_m_axi_bready),
      .s_axi_bresp(ic_m_axi_bresp),
      .s_axi_bid(ic_m_axi_bid),
      .s_axi_arvalid(ic_m_axi_arvalid),
      .s_axi_arready(ic_m_axi_arready),
      .s_axi_arid(ic_m_axi_arid),
      .s_axi_araddr(ic_m_axi_araddr),
      .s_axi_arlen(ic_m_axi_arlen),
      .s_axi_arsize(ic_m_axi_arsize),
      .s_axi_arburst(ic_m_axi_arburst),
      .s_axi_rvalid(ic_m_axi_rvalid),
      .s_axi_rready(ic_m_axi_rready),
      .s_axi_rdata(ic_m_axi_rdata),
      .s_axi_rresp(ic_m_axi_rresp),
      .s_axi_rid(ic_m_axi_rid),
      .s_axi_rlast(ic_m_axi_rlast),
      .sr_req(1'b0),
      .ref_req(1'b0),
      .sr_ack(ddr_sr_ack),
      .ref_ack(ddr_ref_ack),
      .burst(1'b1),
      .O_ddr_addr(ddr_addr),
      .O_ddr_ba(ddr_bank),
      .O_ddr_cs_n(ddr_cs),
      .O_ddr_ras_n(ddr_ras),
      .O_ddr_cas_n(ddr_cas),
      .O_ddr_we_n(ddr_we),
      .O_ddr_clk(ddr_ck),
      .O_ddr_clk_n(ddr_ck_n),
      .O_ddr_cke(ddr_cke),
      .O_ddr_odt(ddr_odt),
      .O_ddr_reset_n(ddr_reset_n),
      .O_ddr_dqm(ddr_dm),
      .IO_ddr_dq(ddr_dq),
      .IO_ddr_dqs(ddr_dqs),
      .IO_ddr_dqs_n(ddr_dqs_n)
  );

  assign ic_m_axi_buser = 1'b0;
  assign ic_m_axi_ruser = 1'b0;
endmodule
