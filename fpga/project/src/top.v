// `define EN_GEN_H2C

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

  // ===============
  // Clocks & Resets
  // ===============
  localparam PCIE_DLY = 8;  //25~500ms
  localparam PERST_DLY = 25;
  localparam RUN_DLY = 23;
  localparam SYS_RST_DLY = 20;

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
  assign ddr_clk = pll_50m_clk;  //? In DDR3 IP User Guide recommended
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

  // PCIE start delay
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

  // Control led blink
  always @(posedge cfg_clk or negedge w_rst_n)
    if (!w_rst_n) run_cnt <= 0;
    else run_cnt <= run_cnt + 2'd1;

  wire pcie_linkup;
  reg  pcie_linkup_r;
  /* synthesis syn_keep = 1 */

  always @(posedge tlp_clk) pcie_linkup_r <= pcie_linkup;

  // =========
  // PCIe Core
  // =========
  /* PCIe IP */
  wire [  4:0] pcie_ltssm;
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
  wire         pcie_tl_drp_clk;
  wire [ 23:0] pcie_tl_drp_addr;
  wire         pcie_tl_drp_ready;
  wire [  7:0] pcie_tl_drp_strb;
  wire         pcie_tl_drp_resp;
  wire         pcie_tl_drp_wr;
  wire [ 31:0] pcie_tl_drp_wrdata;
  wire         pcie_tl_drp_rd;
  wire [ 31:0] pcie_tl_drp_rddata;
  wire         pcie_tl_drp_rd_valid;
  wire         pcie_tl_int_req;
  wire         pcie_tl_int_ack;
  wire         pcie_tl_int_status;
  wire [  4:0] pcie_tl_int_msinum;
  wire [ 12:0] pcie_tl_cfg_busdev;

  SerDes_Top u_pcie_ip (
      .PCIE_Controller_Top_pcie_rstn_i(rst_n),
      .PCIE_Controller_Top_pcie_tl_clk_i(tlp_clk),
      .PCIE_Controller_Top_pcie_linkup_o(pcie_linkup),
      .PCIE_Controller_Top_pcie_ltssm_o(pcie_ltssm),
      .PCIE_Controller_Top_pcie_tl_rx_sop_o(pcie_tl_rx_sop),
      .PCIE_Controller_Top_pcie_tl_rx_eop_o(pcie_tl_rx_eop),
      .PCIE_Controller_Top_pcie_tl_rx_data_o(pcie_tl_rx_data),
      .PCIE_Controller_Top_pcie_tl_rx_valid_o(pcie_tl_rx_valid),
      .PCIE_Controller_Top_pcie_tl_rx_bardec_o(pcie_tl_rx_bardec),
      .PCIE_Controller_Top_pcie_tl_rx_wait_i(pcie_tl_rx_wait),
      .PCIE_Controller_Top_pcie_tl_rx_masknp_i(pcie_tl_rx_masknp),
      .PCIE_Controller_Top_pcie_tl_rx_err_o(pcie_tl_rx_err),
      .PCIE_Controller_Top_pcie_tl_tx_sop_i(pcie_tl_tx_sop),
      .PCIE_Controller_Top_pcie_tl_tx_eop_i(pcie_tl_tx_eop),
      .PCIE_Controller_Top_pcie_tl_tx_data_i(pcie_tl_tx_data),
      .PCIE_Controller_Top_pcie_tl_tx_valid_i(pcie_tl_tx_valid),
      .PCIE_Controller_Top_pcie_tl_tx_wait_o(pcie_tl_tx_wait),
      .PCIE_Controller_Top_pcie_tl_drp_clk_o(pcie_tl_drp_clk),
      .PCIE_Controller_Top_pcie_tl_drp_addr_i(pcie_tl_drp_addr),
      .PCIE_Controller_Top_pcie_tl_drp_ready_o(pcie_tl_drp_ready),
      .PCIE_Controller_Top_pcie_tl_drp_resp_o(pcie_tl_drp_resp),
      .PCIE_Controller_Top_pcie_tl_drp_strb_i(pcie_tl_drp_strb),
      .PCIE_Controller_Top_pcie_tl_drp_wr_i(pcie_tl_drp_wr),
      .PCIE_Controller_Top_pcie_tl_drp_wrdata_i(pcie_tl_drp_wrdata),
      .PCIE_Controller_Top_pcie_tl_drp_rd_i(pcie_tl_drp_rd),
      .PCIE_Controller_Top_pcie_tl_drp_rddata_o(pcie_tl_drp_rddata),
      .PCIE_Controller_Top_pcie_tl_drp_rd_valid_o(pcie_tl_drp_rd_valid),
      .PCIE_Controller_Top_pcie_tl_int_req_i(pcie_tl_int_req),
      .PCIE_Controller_Top_pcie_tl_int_ack_o(pcie_tl_int_ack),
      .PCIE_Controller_Top_pcie_tl_int_status_i(pcie_tl_int_status),
      .PCIE_Controller_Top_pcie_tl_int_msinum_i(pcie_tl_int_msinum),
      .PCIE_Controller_Top_pcie_tl_cfg_busdev_o(pcie_tl_cfg_busdev)
  );

  /* PCIe SGDMA */
  // h2c AXI stream data
  wire         axis_h2c_data_tready;
  wire         axis_h2c_data_tvalid;
  wire [255:0] axis_h2c_data_tdata;
  wire         axis_h2c_data_tlast;
  wire [ 31:0] axis_h2c_data_tkeep;
  wire [ 63:0] h2c_overhead;
  wire         h2c_run;
  // c2h AXI stream data
  wire         axis_c2h_data_tready;
  wire         axis_c2h_data_tvalid;
  wire         axis_c2h_data_tlast;
  wire [255:0] axis_c2h_data_tdata;
  wire [ 31:0] axis_c2h_data_tkeep;
  wire         c2h_run;
  // BAR2
  wire         user_cs;
  wire [ 63:0] user_address;
  wire         user_rw;
  wire [ 31:0] user_wr_data;
  wire [  3:0] user_wr_be;
  wire [  3:0] user_rd_be;
  wire         user_rd_valid;
  wire [ 31:0] user_rd_data;

  Pcie_Sgdma_Top #() u_pcie_sgdma (
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
`ifdef EN_GEN_H2C
      .m_axis_h2c_tready(1'b1),
      .m_axis_h2c_tvalid(),
      .m_axis_h2c_tdata(),
      .m_axis_h2c_tlast(),
      .m_axis_h2c_tkeep(),
`else
      .m_axis_h2c_tready(axis_h2c_data_tready),
      .m_axis_h2c_tvalid(axis_h2c_data_tvalid),
      .m_axis_h2c_tdata(axis_h2c_data_tdata),
      .m_axis_h2c_tlast(axis_h2c_data_tlast),
      .m_axis_h2c_tkeep(axis_h2c_data_tkeep),
`endif
      .h2c_overhead(h2c_overhead),
      .s_axis_c2h_tready(axis_c2h_data_tready),
      .s_axis_c2h_tvalid(axis_c2h_data_tvalid),
      .s_axis_c2h_tlast(axis_c2h_data_tlast),
      .s_axis_c2h_tdata(axis_c2h_data_tdata),
      .s_axis_c2h_tkeep(axis_c2h_data_tkeep),
      .c2h_overhead_valid(1'b1),
      .c2h_overhead_data(64'h76543210),
      .user_cs(user_cs),
      .user_address(user_address),
      .user_rw(user_rw),
      .user_wr_data(user_wr_data),
      .user_wr_be(user_wr_be),
      .user_rd_be(user_rd_be),
      .user_rd_valid(user_rd_valid),
      .user_rd_data(user_rd_data),
      .h2c_run(h2c_run),
      .c2h_run(c2h_run)
  );

  reg [63:0] h2c_overhead_reg;

  always @(posedge tlp_clk or negedge rst_n) begin
    if (!rst_n) begin
      h2c_overhead_reg <= 64'd0;
    end else begin
`ifdef EN_GEN_H2C
      if (axis_h2c_gen_tvalid) begin
`else
      if (axis_h2c_data_tvalid) begin
`endif
        h2c_overhead_reg <= h2c_overhead;
      end
    end
  end

  wire [AXILENWIDTH-1:0] lad_cfg_len;  //? Temporary
  wire axis_h2c_gen_done;  //? Temporary
`ifdef EN_GEN_H2C
  reg          axis_h2c_gen_start;
  wire         axis_h2c_gen_busy;
  wire         axis_h2c_gen_tready;
  wire         axis_h2c_gen_tvalid;
  wire [255:0] axis_h2c_gen_tdata;
  wire [ 31:0] axis_h2c_gen_tkeep;
  wire         axis_h2c_gen_tlast;

  wire [ 31:0] axis_h2c_gen_data_tdata_debug;
  assign axis_h2c_gen_data_tdata_debug = axis_h2c_gen_tdata[31:0];

  always @(posedge tlp_clk or negedge rst_n) begin
    if (!rst_n) begin
      axis_h2c_gen_start <= 1'b0;
    end else begin
      if (axis_h2c_desc_valid && axis_h2c_desc_ready) begin
        axis_h2c_gen_start <= 1'b1;
      end

      if (axis_h2c_gen_done) begin
        axis_h2c_gen_start <= 1'b0;
      end
    end
  end

  gen_h2c #(
      .DATA_WIDTH(256),
      .LEN_WIDTH (AXILENWIDTH)
  ) u_gen_h2c (
      .clk(tlp_clk),
      .rstn(tlp_rst_n),
      .start(axis_h2c_gen_start),
      .cfg_len(lad_cfg_len),
      .busy(axis_h2c_gen_busy),
      .done(axis_h2c_gen_done),
      .m_axis_tdata(axis_h2c_gen_tdata),
      .m_axis_tkeep(axis_h2c_gen_tkeep),
      .m_axis_tvalid(axis_h2c_gen_tvalid),
      .m_axis_tready(axis_h2c_gen_tready),
      .m_axis_tlast(axis_h2c_gen_tlast)
  );
`endif

  wire [31:0] pcie_tl_tx_data_debug;
  wire [31:0] pcie_tl_rx_data_debug;
  wire [31:0] axis_h2c_data_tdata_debug;
  wire [31:0] axis_c2h_data_tdata_debug;

  assign pcie_tl_tx_data_debug = pcie_tl_tx_data[31:0];
  assign pcie_tl_rx_data_debug = pcie_tl_rx_data[31:0];

`ifdef EN_GEN_H2C
  assign axis_h2c_data_tdata_debug = axis_h2c_gen_tdata[31:0];
`else
  assign axis_h2c_data_tdata_debug = axis_h2c_data_tdata[31:0];
`endif
  assign axis_c2h_data_tdata_debug = axis_c2h_data_tdata[31:0];

  /* Logic control BAR2 (Descriptors for DDR3) */
  localparam integer AXIADDRWIDTH = 29;
  localparam integer AXILENWIDTH = 20;
  // h2c AXI stream descriptors
  wire [AXIADDRWIDTH-1:0] axis_h2c_desc_addr;
  wire [ AXILENWIDTH-1:0] axis_h2c_desc_len;
  wire                    axis_h2c_desc_ready;
  wire                    axis_h2c_desc_valid;
  // c2h AXI stream descriptors
  wire [AXIADDRWIDTH-1:0] axis_c2h_desc_addr;
  wire [ AXILENWIDTH-1:0] axis_c2h_desc_len;
  wire                    axis_c2h_desc_valid;
  wire                    axis_c2h_desc_ready;
  // Logic Adder config
  wire [AXIADDRWIDTH-1:0] lad_cfg_read_addr;
  wire [AXIADDRWIDTH-1:0] lad_cfg_write_addr;
  // wire [ AXILENWIDTH-1:0] lad_cfg_len;
  wire                    lad_run;
  wire                    lad_busy;
  wire                    lad_done;

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
      .m_axis_h2c_desc_addr(axis_h2c_desc_addr),
      .m_axis_h2c_desc_len(axis_h2c_desc_len),
      .m_axis_h2c_desc_valid(axis_h2c_desc_valid),
      .m_axis_h2c_desc_ready(axis_h2c_desc_ready),
      .h2c_overhead_reg(h2c_overhead_reg),
      .m_axis_c2h_desc_addr(axis_c2h_desc_addr),
      .m_axis_c2h_desc_len(axis_c2h_desc_len),
      .m_axis_c2h_desc_valid(axis_c2h_desc_valid),
      .m_axis_c2h_desc_ready(axis_c2h_desc_ready),
      .lad_read_addr(lad_cfg_read_addr),
      .lad_write_addr(lad_cfg_write_addr),
      .lad_len(lad_cfg_len),
      .lad_run(lad_run),
      .lad_busy(lad_busy),
      .lad_done(lad_done),
      .axis_h2c_gen_done(axis_h2c_gen_done)
  );

  /* AXI DMA */
  localparam integer AXIDATAWIDTH = 256;
  localparam integer AXISTRBWIDTH = AXIDATAWIDTH / 8;
  localparam integer AXIIDWIDTH = 4;

  wire [  AXIIDWIDTH-1:0] axi_pci_dma_awid;
  wire [AXIADDRWIDTH-1:0] axi_pci_dma_awaddr;
  wire [             7:0] axi_pci_dma_awlen;
  wire [             2:0] axi_pci_dma_awsize;
  wire [             1:0] axi_pci_dma_awburst;
  wire                    axi_pci_dma_awlock;
  wire [             3:0] axi_pci_dma_awcache;
  wire [             2:0] axi_pci_dma_awprot;
  wire                    axi_pci_dma_awvalid;
  wire                    axi_pci_dma_awready;
  wire [AXIDATAWIDTH-1:0] axi_pci_dma_wdata;
  wire [AXISTRBWIDTH-1:0] axi_pci_dma_wstrb;
  wire                    axi_pci_dma_wlast;
  wire                    axi_pci_dma_wvalid;
  wire                    axi_pci_dma_wready;
  wire [  AXIIDWIDTH-1:0] axi_pci_dma_bid;
  wire [             1:0] axi_pci_dma_bresp;
  wire                    axi_pci_dma_bvalid;
  wire                    axi_pci_dma_bready;
  wire [  AXIIDWIDTH-1:0] axi_pci_dma_arid;
  wire [AXIADDRWIDTH-1:0] axi_pci_dma_araddr;
  wire [             7:0] axi_pci_dma_arlen;
  wire [             2:0] axi_pci_dma_arsize;
  wire [             1:0] axi_pci_dma_arburst;
  wire                    axi_pci_dma_arlock;
  wire [             3:0] axi_pci_dma_arcache;
  wire [             2:0] axi_pci_dma_arprot;
  wire                    axi_pci_dma_arvalid;
  wire                    axi_pci_dma_arready;
  wire [  AXIIDWIDTH-1:0] axi_pci_dma_rid;
  wire [AXIDATAWIDTH-1:0] axi_pci_dma_rdata;
  wire [             1:0] axi_pci_dma_rresp;
  wire                    axi_pci_dma_rlast;
  wire                    axi_pci_dma_rvalid;
  wire                    axi_pci_dma_rready;

  axi_dma #(
      .AXI_DATA_WIDTH(AXIDATAWIDTH),
      .AXI_ADDR_WIDTH(AXIADDRWIDTH),
      .AXI_STRB_WIDTH(AXISTRBWIDTH),
      .AXI_ID_WIDTH(AXIIDWIDTH),
      .LEN_WIDTH(AXILENWIDTH),
      .AXI_MAX_BURST_LEN(256),
      .AXIS_DATA_WIDTH(256),
      .AXIS_KEEP_ENABLE(1),
      .AXIS_KEEP_WIDTH(32),
      .AXIS_LAST_ENABLE(1),
      .AXIS_ID_ENABLE(0),
      .AXIS_DEST_ENABLE(0),
      .AXIS_USER_ENABLE(0),
      .ENABLE_SG(1),
      .ENABLE_UNALIGNED(0)
  ) u_axi_dma_pcie_sgdma (
      .clk(tlp_clk),
      .rst(tlp_rst),
      .s_axis_read_desc_addr(axis_c2h_desc_addr),
      .s_axis_read_desc_len(axis_c2h_desc_len),
      .s_axis_read_desc_tag(8'd0),
      .s_axis_read_desc_id(8'd0),
      .s_axis_read_desc_dest(8'd0),
      .s_axis_read_desc_user(32'd0),
      .s_axis_read_desc_valid(axis_c2h_desc_valid),
      .s_axis_read_desc_ready(axis_c2h_desc_ready),
      .m_axis_read_data_tdata(axis_c2h_data_tdata),
      .m_axis_read_data_tkeep(axis_c2h_data_tkeep),
      .m_axis_read_data_tvalid(axis_c2h_data_tvalid),
      .m_axis_read_data_tready(axis_c2h_data_tready),
      .m_axis_read_data_tlast(axis_c2h_data_tlast),
      .s_axis_write_desc_addr(axis_h2c_desc_addr),
      .s_axis_write_desc_len(axis_h2c_desc_len),
      .s_axis_write_desc_tag(8'd0),
      .s_axis_write_desc_valid(axis_h2c_desc_valid),
      .s_axis_write_desc_ready(axis_h2c_desc_ready),
`ifdef EN_GEN_H2C
      .s_axis_write_data_tdata(axis_h2c_gen_tdata),
      .s_axis_write_data_tkeep(axis_h2c_gen_tkeep),
      .s_axis_write_data_tvalid(axis_h2c_gen_tvalid),
      .s_axis_write_data_tready(axis_h2c_gen_tready),
      .s_axis_write_data_tlast(axis_h2c_gen_tlast),
`else
      .s_axis_write_data_tdata(axis_h2c_data_tdata),
      .s_axis_write_data_tkeep(axis_h2c_data_tkeep),
      .s_axis_write_data_tvalid(axis_h2c_data_tvalid),
      .s_axis_write_data_tready(axis_h2c_data_tready),
      .s_axis_write_data_tlast(axis_h2c_data_tlast),
`endif
      .s_axis_write_data_tid(8'd0),
      .s_axis_write_data_tdest(8'd0),
      .m_axi_awid(axi_pci_dma_awid),
      .m_axi_awaddr(axi_pci_dma_awaddr),
      .m_axi_awlen(axi_pci_dma_awlen),
      .m_axi_awsize(axi_pci_dma_awsize),
      .m_axi_awburst(axi_pci_dma_awburst),
      .m_axi_awlock(axi_pci_dma_awlock),
      .m_axi_awcache(axi_pci_dma_awcache),
      .m_axi_awprot(axi_pci_dma_awprot),
      .m_axi_awvalid(axi_pci_dma_awvalid),
      .m_axi_awready(axi_pci_dma_awready),
      .m_axi_wdata(axi_pci_dma_wdata),
      .m_axi_wstrb(axi_pci_dma_wstrb),
      .m_axi_wlast(axi_pci_dma_wlast),
      .m_axi_wvalid(axi_pci_dma_wvalid),
      .m_axi_wready(axi_pci_dma_wready),
      .m_axi_bid(axi_pci_dma_bid),
      .m_axi_bresp(axi_pci_dma_bresp),
      .m_axi_bvalid(axi_pci_dma_bvalid),
      .m_axi_bready(axi_pci_dma_bready),
      .m_axi_arid(axi_pci_dma_arid),
      .m_axi_araddr(axi_pci_dma_araddr),
      .m_axi_arlen(axi_pci_dma_arlen),
      .m_axi_arsize(axi_pci_dma_arsize),
      .m_axi_arburst(axi_pci_dma_arburst),
      .m_axi_arlock(axi_pci_dma_arlock),
      .m_axi_arcache(axi_pci_dma_arcache),
      .m_axi_arprot(axi_pci_dma_arprot),
      .m_axi_arvalid(axi_pci_dma_arvalid),
      .m_axi_arready(axi_pci_dma_arready),
      .m_axi_rid(axi_pci_dma_rid),
      .m_axi_rdata(axi_pci_dma_rdata),
      .m_axi_rresp(axi_pci_dma_rresp),
      .m_axi_rlast(axi_pci_dma_rlast),
      .m_axi_rvalid(axi_pci_dma_rvalid),
      .m_axi_rready(axi_pci_dma_rready),
      .read_enable(1'b1),
      .write_enable(1'b1),
      .write_abort(1'b0)
  );

  // ==========
  // Logic Core
  // ==========
  /* Adder */
  // Read descriptor
  wire [AXIADDRWIDTH-1:0] axis_lad_rd_desc_addr;
  wire [ AXILENWIDTH-1:0] axis_lad_rd_desc_len;
  wire [             7:0] axis_lad_rd_desc_tag;
  wire                    axis_lad_rd_desc_valid;
  wire                    axis_lad_rd_desc_ready;
  // Write descriptor
  wire [AXIADDRWIDTH-1:0] axis_lad_wr_desc_addr;
  wire [ AXILENWIDTH-1:0] axis_lad_wr_desc_len;
  wire [             7:0] axis_lad_wr_desc_tag;
  wire                    axis_lad_wr_desc_valid;
  wire                    axis_lad_wr_desc_ready;
  // Receive data
  wire                    axis_lad_rx_data_tready;
  wire                    axis_lad_rx_data_tvalid;
  wire [AXIDATAWIDTH-1:0] axis_lad_rx_data_tdata;
  wire                    axis_lad_rx_data_tlast;
  wire [AXISTRBWIDTH-1:0] axis_lad_rx_data_tkeep;
  // Transmit data
  wire                    axis_lad_tx_data_tready;
  wire                    axis_lad_tx_data_tvalid;
  wire                    axis_lad_tx_data_tlast;
  wire [AXIDATAWIDTH-1:0] axis_lad_tx_data_tdata;
  wire [AXISTRBWIDTH-1:0] axis_lad_tx_data_tkeep;

  logic_adder #(
      .AXIADDRWIDTH(AXIADDRWIDTH),
      .AXILENWIDTH (AXILENWIDTH),
      .AXIDATAWIDTH(AXIDATAWIDTH),
      .AXISTRBWIDTH(AXISTRBWIDTH)
  ) u_logic_adder (
      .clk(tlp_clk),
      .rstn(tlp_rst_n),
      .cfg_read_addr(lad_cfg_read_addr),
      .cfg_write_addr(lad_cfg_write_addr),
      .cfg_len(lad_cfg_len),
      .cfg_desc_tag(8'd0),
      .m_axis_read_desc_valid(axis_lad_rd_desc_valid),
      .m_axis_read_desc_ready(axis_lad_rd_desc_ready),
      .m_axis_read_desc_addr(axis_lad_rd_desc_addr),
      .m_axis_read_desc_len(axis_lad_rd_desc_len),
      .m_axis_read_desc_tag(axis_lad_rd_desc_tag),
      .m_axis_write_desc_valid(axis_lad_wr_desc_valid),
      .m_axis_write_desc_ready(axis_lad_wr_desc_ready),
      .m_axis_write_desc_addr(axis_lad_wr_desc_addr),
      .m_axis_write_desc_len(axis_lad_wr_desc_len),
      .m_axis_write_desc_tag(axis_lad_wr_desc_tag),
      .s_axis_rx_tready(axis_lad_rx_data_tready),
      .s_axis_rx_tvalid(axis_lad_rx_data_tvalid),
      .s_axis_rx_tdata(axis_lad_rx_data_tdata),
      .s_axis_rx_tlast(axis_lad_rx_data_tlast),
      .s_axis_rx_tkeep(axis_lad_rx_data_tkeep),
      .m_axis_tx_tready(axis_lad_tx_data_tready),
      .m_axis_tx_tvalid(axis_lad_tx_data_tvalid),
      .m_axis_tx_tlast(axis_lad_tx_data_tlast),
      .m_axis_tx_tdata(axis_lad_tx_data_tdata),
      .m_axis_tx_tkeep(axis_lad_tx_data_tkeep),
      .run(lad_run),
      .busy(lad_busy),
      .done(lad_done)
  );

  /* AXI DMA */
  wire [  AXIIDWIDTH-1:0] axi_lad_dma_awid;
  wire [AXIADDRWIDTH-1:0] axi_lad_dma_awaddr;
  wire [             7:0] axi_lad_dma_awlen;
  wire [             2:0] axi_lad_dma_awsize;
  wire [             1:0] axi_lad_dma_awburst;
  wire                    axi_lad_dma_awlock;
  wire [             3:0] axi_lad_dma_awcache;
  wire [             2:0] axi_lad_dma_awprot;
  wire                    axi_lad_dma_awvalid;
  wire                    axi_lad_dma_awready;
  wire [AXIDATAWIDTH-1:0] axi_lad_dma_wdata;
  wire [AXISTRBWIDTH-1:0] axi_lad_dma_wstrb;
  wire                    axi_lad_dma_wlast;
  wire                    axi_lad_dma_wvalid;
  wire                    axi_lad_dma_wready;
  wire [  AXIIDWIDTH-1:0] axi_lad_dma_bid;
  wire [             1:0] axi_lad_dma_bresp;
  wire                    axi_lad_dma_bvalid;
  wire                    axi_lad_dma_bready;
  wire [  AXIIDWIDTH-1:0] axi_lad_dma_arid;
  wire [AXIADDRWIDTH-1:0] axi_lad_dma_araddr;
  wire [             7:0] axi_lad_dma_arlen;
  wire [             2:0] axi_lad_dma_arsize;
  wire [             1:0] axi_lad_dma_arburst;
  wire                    axi_lad_dma_arlock;
  wire [             3:0] axi_lad_dma_arcache;
  wire [             2:0] axi_lad_dma_arprot;
  wire                    axi_lad_dma_arvalid;
  wire                    axi_lad_dma_arready;
  wire [  AXIIDWIDTH-1:0] axi_lad_dma_rid;
  wire [AXIDATAWIDTH-1:0] axi_lad_dma_rdata;
  wire [             1:0] axi_lad_dma_rresp;
  wire                    axi_lad_dma_rlast;
  wire                    axi_lad_dma_rvalid;
  wire                    axi_lad_dma_rready;

  axi_dma #(
      .AXI_DATA_WIDTH(AXIDATAWIDTH),
      .AXI_ADDR_WIDTH(AXIADDRWIDTH),
      .AXI_STRB_WIDTH(AXISTRBWIDTH),
      .AXI_ID_WIDTH(AXIIDWIDTH),
      .LEN_WIDTH(AXILENWIDTH),
      .AXI_MAX_BURST_LEN(256),
      .AXIS_DATA_WIDTH(256),
      .AXIS_KEEP_ENABLE(1),
      .AXIS_KEEP_WIDTH(32),
      .AXIS_LAST_ENABLE(1),
      .AXIS_ID_ENABLE(0),
      .AXIS_DEST_ENABLE(0),
      .AXIS_USER_ENABLE(0),
      .ENABLE_SG(1),
      .ENABLE_UNALIGNED(0)
  ) u_axi_pci_dma_logic_adder (
      .clk(tlp_clk),
      .rst(tlp_rst),
      .s_axis_read_desc_addr(axis_lad_rd_desc_addr),
      .s_axis_read_desc_len(axis_lad_rd_desc_len),
      .s_axis_read_desc_tag(axis_lad_rd_desc_tag),
      .s_axis_read_desc_id(8'd0),
      .s_axis_read_desc_dest(8'd0),
      .s_axis_read_desc_user(32'd0),
      .s_axis_read_desc_valid(axis_lad_rd_desc_valid),
      .s_axis_read_desc_ready(axis_lad_rd_desc_ready),
      .m_axis_read_data_tdata(axis_lad_rx_data_tdata),
      .m_axis_read_data_tkeep(axis_lad_rx_data_tkeep),
      .m_axis_read_data_tvalid(axis_lad_rx_data_tvalid),
      .m_axis_read_data_tready(axis_lad_rx_data_tready),
      .m_axis_read_data_tlast(axis_lad_rx_data_tlast),
      .s_axis_write_desc_addr(axis_lad_wr_desc_addr),
      .s_axis_write_desc_len(axis_lad_wr_desc_len),
      .s_axis_write_desc_tag(axis_lad_wr_desc_tag),
      .s_axis_write_desc_valid(axis_lad_wr_desc_valid),
      .s_axis_write_desc_ready(axis_lad_wr_desc_ready),
      .s_axis_write_data_tdata(axis_lad_tx_data_tdata),
      .s_axis_write_data_tkeep(axis_lad_tx_data_tkeep),
      .s_axis_write_data_tvalid(axis_lad_tx_data_tvalid),
      .s_axis_write_data_tready(axis_lad_tx_data_tready),
      .s_axis_write_data_tlast(axis_lad_tx_data_tlast),
      .s_axis_write_data_tid(8'd0),
      .s_axis_write_data_tdest(8'd0),
      .m_axi_awid(axi_lad_dma_awid),
      .m_axi_awaddr(axi_lad_dma_awaddr),
      .m_axi_awlen(axi_lad_dma_awlen),
      .m_axi_awsize(axi_lad_dma_awsize),
      .m_axi_awburst(axi_lad_dma_awburst),
      .m_axi_awlock(axi_lad_dma_awlock),
      .m_axi_awcache(axi_lad_dma_awcache),
      .m_axi_awprot(axi_lad_dma_awprot),
      .m_axi_awvalid(axi_lad_dma_awvalid),
      .m_axi_awready(axi_lad_dma_awready),
      .m_axi_wdata(axi_lad_dma_wdata),
      .m_axi_wstrb(axi_lad_dma_wstrb),
      .m_axi_wlast(axi_lad_dma_wlast),
      .m_axi_wvalid(axi_lad_dma_wvalid),
      .m_axi_wready(axi_lad_dma_wready),
      .m_axi_bid(axi_lad_dma_bid),
      .m_axi_bresp(axi_lad_dma_bresp),
      .m_axi_bvalid(axi_lad_dma_bvalid),
      .m_axi_bready(axi_lad_dma_bready),
      .m_axi_arid(axi_lad_dma_arid),
      .m_axi_araddr(axi_lad_dma_araddr),
      .m_axi_arlen(axi_lad_dma_arlen),
      .m_axi_arsize(axi_lad_dma_arsize),
      .m_axi_arburst(axi_lad_dma_arburst),
      .m_axi_arlock(axi_lad_dma_arlock),
      .m_axi_arcache(axi_lad_dma_arcache),
      .m_axi_arprot(axi_lad_dma_arprot),
      .m_axi_arvalid(axi_lad_dma_arvalid),
      .m_axi_arready(axi_lad_dma_arready),
      .m_axi_rid(axi_lad_dma_rid),
      .m_axi_rdata(axi_lad_dma_rdata),
      .m_axi_rresp(axi_lad_dma_rresp),
      .m_axi_rlast(axi_lad_dma_rlast),
      .m_axi_rvalid(axi_lad_dma_rvalid),
      .m_axi_rready(axi_lad_dma_rready),
      .read_enable(1'b1),
      .write_enable(1'b1),
      .write_abort(1'b0)
  );

  // =========
  // DDR3 Core
  // =========
  // Config
  wire                    ddr_clk_out;
  wire                    ddr_rst;
  wire                    ddr_sr_ack;
  wire                    ddr_ref_ack;
  wire                    ddr_init;
  // AXI
  wire [  AXIIDWIDTH-1:0] axi_ddr_awid;
  wire [AXIADDRWIDTH-1:0] axi_ddr_awaddr;
  wire [             7:0] axi_ddr_awlen;
  wire [             2:0] axi_ddr_awsize;
  wire [             1:0] axi_ddr_awburst;
  wire                    axi_ddr_awvalid;
  wire                    axi_ddr_awready;
  wire [AXIDATAWIDTH-1:0] axi_ddr_wdata;
  wire [AXISTRBWIDTH-1:0] axi_ddr_wstrb;
  wire                    axi_ddr_wlast;
  wire                    axi_ddr_wvalid;
  wire                    axi_ddr_wready;
  wire [  AXIIDWIDTH-1:0] axi_ddr_bid;
  wire [             1:0] axi_ddr_bresp;
  wire                    axi_ddr_bvalid;
  wire                    axi_ddr_bready;
  wire [  AXIIDWIDTH-1:0] axi_ddr_arid;
  wire [AXIADDRWIDTH-1:0] axi_ddr_araddr;
  wire [             7:0] axi_ddr_arlen;
  wire [             2:0] axi_ddr_arsize;
  wire [             1:0] axi_ddr_arburst;
  wire                    axi_ddr_arvalid;
  wire                    axi_ddr_arready;
  wire [  AXIIDWIDTH-1:0] axi_ddr_rid;
  wire [AXIDATAWIDTH-1:0] axi_ddr_rdata;
  wire [             1:0] axi_ddr_rresp;
  wire                    axi_ddr_rvalid;
  wire                    axi_ddr_rready;
  wire                    axi_ddr_rlast;

  DDR3_Memory_Interface_Top u_ddr3 (
      .clk(tlp_clk),
      .pll_stop(pll_stop),
      .memory_clk(memory_clk),
      .pll_lock(pll_lock),
      .rst_n(tlp_rst_n),
      .clk_out(ddr_clk_out),
      .ddr_rst(ddr_rst),
      .init_calib_complete(ddr_init),
      .s_axi_awvalid(axi_ddr_awvalid),
      .s_axi_awready(axi_ddr_awready),
      .s_axi_awid(axi_ddr_awid),
      .s_axi_awaddr(axi_ddr_awaddr),
      .s_axi_awlen(axi_ddr_awlen),
      .s_axi_awsize(axi_ddr_awsize),
      .s_axi_awburst(axi_ddr_awburst),
      .s_axi_wvalid(axi_ddr_wvalid),
      .s_axi_wready(axi_ddr_wready),
      .s_axi_wdata(axi_ddr_wdata),
      .s_axi_wstrb(axi_ddr_wstrb),
      .s_axi_wlast(axi_ddr_wlast),
      .s_axi_bvalid(axi_ddr_bvalid),
      .s_axi_bready(axi_ddr_bready),
      .s_axi_bresp(axi_ddr_bresp),
      .s_axi_bid(axi_ddr_bid),
      .s_axi_arvalid(axi_ddr_arvalid),
      .s_axi_arready(axi_ddr_arready),
      .s_axi_arid(axi_ddr_arid),
      .s_axi_araddr(axi_ddr_araddr),
      .s_axi_arlen(axi_ddr_arlen),
      .s_axi_arsize(axi_ddr_arsize),
      .s_axi_arburst(axi_ddr_arburst),
      .s_axi_rvalid(axi_ddr_rvalid),
      .s_axi_rready(axi_ddr_rready),
      .s_axi_rdata(axi_ddr_rdata),
      .s_axi_rresp(axi_ddr_rresp),
      .s_axi_rid(axi_ddr_rid),
      .s_axi_rlast(axi_ddr_rlast),
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

  // ================
  // AXI Interconnect
  // ================
  axi_interconnect #(
      .S_COUNT(2),
      .M_COUNT(1),
      .DATA_WIDTH(AXIDATAWIDTH),
      .ADDR_WIDTH(AXIADDRWIDTH),
      .STRB_WIDTH(AXISTRBWIDTH),
      .ID_WIDTH(AXIIDWIDTH),
      .M_REGIONS(1),
      .M_ADDR_WIDTH(AXIADDRWIDTH)
  ) u_axi_interconnect (
      .clk(tlp_clk),
      .rst(tlp_rst),
      .s_axi_awid({axi_lad_dma_awid, axi_pci_dma_awid}),
      .s_axi_awaddr({axi_lad_dma_awaddr, axi_pci_dma_awaddr}),
      .s_axi_awlen({axi_lad_dma_awlen, axi_pci_dma_awlen}),
      .s_axi_awsize({axi_lad_dma_awsize, axi_pci_dma_awsize}),
      .s_axi_awburst({axi_lad_dma_awburst, axi_pci_dma_awburst}),
      .s_axi_awlock({axi_lad_dma_awlock, axi_pci_dma_awlock}),
      .s_axi_awcache({axi_lad_dma_awcache, axi_pci_dma_awcache}),
      .s_axi_awprot({axi_lad_dma_awprot, axi_pci_dma_awprot}),
      .s_axi_awqos({4'd0, 4'd0}),
      .s_axi_awuser(2'b00),
      .s_axi_awvalid({axi_lad_dma_awvalid, axi_pci_dma_awvalid}),
      .s_axi_awready({axi_lad_dma_awready, axi_pci_dma_awready}),
      .s_axi_wdata({axi_lad_dma_wdata, axi_pci_dma_wdata}),
      .s_axi_wstrb({axi_lad_dma_wstrb, axi_pci_dma_wstrb}),
      .s_axi_wlast({axi_lad_dma_wlast, axi_pci_dma_wlast}),
      .s_axi_wuser(2'b00),
      .s_axi_wvalid({axi_lad_dma_wvalid, axi_pci_dma_wvalid}),
      .s_axi_wready({axi_lad_dma_wready, axi_pci_dma_wready}),
      .s_axi_bid({axi_lad_dma_bid, axi_pci_dma_bid}),
      .s_axi_bresp({axi_lad_dma_bresp, axi_pci_dma_bresp}),
      .s_axi_bvalid({axi_lad_dma_bvalid, axi_pci_dma_bvalid}),
      .s_axi_bready({axi_lad_dma_bready, axi_pci_dma_bready}),
      .s_axi_arid({axi_lad_dma_arid, axi_pci_dma_arid}),
      .s_axi_araddr({axi_lad_dma_araddr, axi_pci_dma_araddr}),
      .s_axi_arlen({axi_lad_dma_arlen, axi_pci_dma_arlen}),
      .s_axi_arsize({axi_lad_dma_arsize, axi_pci_dma_arsize}),
      .s_axi_arburst({axi_lad_dma_arburst, axi_pci_dma_arburst}),
      .s_axi_arlock({axi_lad_dma_arlock, axi_pci_dma_arlock}),
      .s_axi_arcache({axi_lad_dma_arcache, axi_pci_dma_arcache}),
      .s_axi_arprot({axi_lad_dma_arprot, axi_pci_dma_arprot}),
      .s_axi_arqos({4'd0, 4'd0}),
      .s_axi_aruser(2'b00),
      .s_axi_arvalid({axi_lad_dma_arvalid, axi_pci_dma_arvalid}),
      .s_axi_arready({axi_lad_dma_arready, axi_pci_dma_arready}),
      .s_axi_rid({axi_lad_dma_rid, axi_pci_dma_rid}),
      .s_axi_rdata({axi_lad_dma_rdata, axi_pci_dma_rdata}),
      .s_axi_rresp({axi_lad_dma_rresp, axi_pci_dma_rresp}),
      .s_axi_rlast({axi_lad_dma_rlast, axi_pci_dma_rlast}),
      .s_axi_rvalid({axi_lad_dma_rvalid, axi_pci_dma_rvalid}),
      .s_axi_rready({axi_lad_dma_rready, axi_pci_dma_rready}),
      .m_axi_awid(axi_ddr_awid),
      .m_axi_awaddr(axi_ddr_awaddr),
      .m_axi_awlen(axi_ddr_awlen),
      .m_axi_awsize(axi_ddr_awsize),
      .m_axi_awburst(axi_ddr_awburst),
      .m_axi_awvalid(axi_ddr_awvalid),
      .m_axi_awready(axi_ddr_awready),
      .m_axi_wdata(axi_ddr_wdata),
      .m_axi_wstrb(axi_ddr_wstrb),
      .m_axi_wlast(axi_ddr_wlast),
      .m_axi_wvalid(axi_ddr_wvalid),
      .m_axi_wready(axi_ddr_wready),
      .m_axi_bid(axi_ddr_bid),
      .m_axi_bresp(axi_ddr_bresp),
      .m_axi_buser(1'b0),
      .m_axi_bvalid(axi_ddr_bvalid),
      .m_axi_bready(axi_ddr_bready),
      .m_axi_arid(axi_ddr_arid),
      .m_axi_araddr(axi_ddr_araddr),
      .m_axi_arlen(axi_ddr_arlen),
      .m_axi_arsize(axi_ddr_arsize),
      .m_axi_arburst(axi_ddr_arburst),
      .m_axi_arvalid(axi_ddr_arvalid),
      .m_axi_arready(axi_ddr_arready),
      .m_axi_rid(axi_ddr_rid),
      .m_axi_rdata(axi_ddr_rdata),
      .m_axi_rresp(axi_ddr_rresp),
      .m_axi_rlast(axi_ddr_rlast),
      .m_axi_ruser(1'b0),
      .m_axi_rvalid(axi_ddr_rvalid),
      .m_axi_rready(axi_ddr_rready)
  );

  // ====
  // Leds
  // ====
  assign led[0] = ~run_cnt[RUN_DLY];
  assign led[1] = ~perst_cnt[PERST_DLY];
  assign led[2] = ~pcie_start;
  assign led[3] = ~pcie_linkup_r;
  assign led[4] = ~ddr_init;
  assign led[5] = ~h2c_run;

endmodule
