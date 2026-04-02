// `include "header.vh"
// `include "define.vh"
// `include "static_macro_define.vh"


module test_top(
    input soc_pcie_rstn,
    input clk_200m_p,
    input clk_200m_n,
    input clk_50m,
    input uart_rx,
    output uart_tx,   
    output sysclk_o
    
);

wire sysclk;
reg [15:0] reset_cnt = 0;
reg soc_pcie_rstn_d0 = 0;
reg soc_pcie_rstn_d1 = 0;
reg pcie_rstn = 0;

//PCIe IP
wire           pcie_tl_rx_sop;
wire           pcie_tl_rx_eop;
wire [255:0]   pcie_tl_rx_data;
wire [7:0]     pcie_tl_rx_valid;
wire [5:0]     pcie_tl_rx_bardec;
wire [7:0]     pcie_tl_rx_err;
wire           pcie_tl_rx_wait;
wire           pcie_tl_rx_masknp;
wire           pcie_tl_tx_sop;
wire           pcie_tl_tx_eop;
wire  [255:0]  pcie_tl_tx_data;
wire  [7:0]    pcie_tl_tx_valid;
wire           pcie_tl_tx_wait;
wire           pcie_tl_int_status;
wire           pcie_tl_int_req;
wire  [4:0]    pcie_tl_int_msinum;
wire           pcie_tl_int_ack;
wire           pcie_tl_drp_clk;
wire  [23:0]   pcie_tl_drp_addr;
wire           pcie_tl_drp_wr;
wire  [31:0]   pcie_tl_drp_wrdata;
wire  [7:0]    pcie_tl_drp_strb;
wire           pcie_tl_drp_rd;
wire           pcie_tl_drp_ready;
wire           pcie_tl_drp_rd_valid;
wire [31:0]    pcie_tl_drp_rddata;
wire           pcie_tl_drp_resp;
wire [4:0]     pcie_ltssm;
wire           pcie_linkup;
wire [12:0]    pcie_tl_cfg_busdev;
//H2C axi stream
wire m_axis_h2c_tready;
wire m_axis_h2c_tvalid;
wire [255:0] m_axis_h2c_tdata;
wire m_axis_h2c_tlast;
wire [31:0] m_axis_h2c_tuser;
wire [31:0] m_axis_h2c_tkeep;
wire [63:0] h2c_overhead;
//C2H axi stream
wire s_axis_c2h_tready;
wire s_axis_c2h_tvalid;
wire s_axis_c2h_tlast;
wire [255:0] s_axis_c2h_tdata;
wire [31:0] s_axis_c2h_tuser;
wire [31:0] s_axis_c2h_tkeep;
wire c2h_overhead_valid;
wire [63:0] c2h_overhead_data;

wire h2c_run;
wire c2h_run;
//BAR2
wire                        user_cs;
wire [63:0]                 user_address;
wire                        user_rw;
wire [31:0]                 user_wr_data;
wire [3:0]                  user_wr_be;
wire [3:0]                  user_rd_be;
reg                         user_rd_valid;
reg  [31:0]                 user_rd_data;
wire                        user_zero_read;
//UART local bus
wire        local_wren;
wire        local_rden;
wire [15:0] local_addr;
wire [31:0] local_wrdata;
wire [31:0] local_rddata;
wire        local_rd_vld;
wire        local_wr_rdy;

//*************sysclk generate*************
TLVDS_IBUF  u_TLVDS_IBUF(
    .O  (clk_200m),
    .I  (clk_200m_p),
    .IB (clk_200m_n)
);

Gowin_PLL u_Gowin_PLL(
        .clkin(clk_200m), //input  clkin
        .clkout0(sysclk), //output  clkout0
        .mdclk(clk_50m) //input  mdclk
);

//*************reset generate*************

always@(posedge sysclk) begin
    soc_pcie_rstn_d0 <= soc_pcie_rstn;
    soc_pcie_rstn_d1 <= soc_pcie_rstn_d0;
    if (!soc_pcie_rstn_d1) begin
        reset_cnt <= 0;
    end
    else if (reset_cnt < 16'd50000) begin
        reset_cnt <= reset_cnt + 1;
    end
    pcie_rstn <= (reset_cnt == 16'd50000);
end

//*************PCIe IP*************
SerDes_Top u_PCIe_IP(
    .PCIE_Controller_Top_pcie_tl_rx_sop_o(pcie_tl_rx_sop),
    .PCIE_Controller_Top_pcie_tl_rx_eop_o(pcie_tl_rx_eop),
    .PCIE_Controller_Top_pcie_tl_rx_data_o(pcie_tl_rx_data),
    .PCIE_Controller_Top_pcie_tl_rx_valid_o(pcie_tl_rx_valid),
    .PCIE_Controller_Top_pcie_tl_rx_bardec_o(pcie_tl_rx_bardec),
    .PCIE_Controller_Top_pcie_tl_rx_err_o(pcie_tl_rx_err),
    .PCIE_Controller_Top_pcie_tl_tx_wait_o(pcie_tl_tx_wait),
    .PCIE_Controller_Top_pcie_tl_int_ack_o(pcie_tl_int_ack),
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
    .PCIE_Controller_Top_pcie_tl_int_status_i(pcie_tl_int_status),
    .PCIE_Controller_Top_pcie_tl_int_req_i(pcie_tl_int_req),
    .PCIE_Controller_Top_pcie_tl_int_msinum_i(pcie_tl_int_msinum),
    .PCIE_Controller_Top_pcie_tl_drp_addr_i(pcie_tl_drp_addr),
    .PCIE_Controller_Top_pcie_tl_drp_wrdata_i(pcie_tl_drp_wrdata),
    .PCIE_Controller_Top_pcie_tl_drp_strb_i(pcie_tl_drp_strb),
    .PCIE_Controller_Top_pcie_tl_drp_wr_i(pcie_tl_drp_wr),
    .PCIE_Controller_Top_pcie_tl_drp_rd_i(pcie_tl_drp_rd)
);

//**************************dut dma********************
pcie_sgdma u_dut (
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


//**************user interface****************
user_stream_if_monitor u_user_stream_if_monitor (
    .clk(sysclk),
    .rstn(pcie_rstn),
    //h2c
    .m_axis_h2c_tready(m_axis_h2c_tready),
    .m_axis_h2c_tvalid(m_axis_h2c_tvalid),
    .m_axis_h2c_tdata(m_axis_h2c_tdata),
    .m_axis_h2c_tlast(m_axis_h2c_tlast),
    .m_axis_h2c_tuser(m_axis_h2c_tuser),
    .m_axis_h2c_tkeep(m_axis_h2c_tkeep),
    .h2c_overhead(h2c_overhead),
    //c2h
    .s_axis_c2h_tready(s_axis_c2h_tready),
    .s_axis_c2h_tvalid(s_axis_c2h_tvalid),
    .s_axis_c2h_tlast(s_axis_c2h_tlast),
    .s_axis_c2h_tdata(s_axis_c2h_tdata),
    .s_axis_c2h_tuser(s_axis_c2h_tuser),
    .s_axis_c2h_tkeep(s_axis_c2h_tkeep),
    .c2h_overhead_valid(c2h_overhead_valid),
    .c2h_overhead_data(c2h_overhead_data),
    .h2c_run(h2c_run),
    .c2h_run(c2h_run),
    //local bus
    .local_wren(local_wren),
    .local_rden(local_rden),
    .local_addr(local_addr),
    .local_wrdata(local_wrdata),
    .local_rddata(local_rddata),
    .local_rd_vld(local_rd_vld),
    .local_wr_rdy(local_wr_rdy)
    
);

	Uart_to_Bus_Top u_Uart_to_Bus_Top(
		.rst_n_i(pcie_rstn), //input rst_n_i
		.clk_i(sysclk), //input clk_i
		.local0_wren_o(local_wren), //output local0_wren_o
		.local0_addr_o(local_addr), //output [15:0] local0_addr_o
		.local0_rden_o(local_rden), //output local0_rden_o
		.local0_wdat_o(local_wrdata), //output [31:0] local0_wdat_o
		.local0_rdat_i(local_rddata), //input [31:0] local0_rdat_i
		.local0_rdat_vld_i(local_rd_vld), //input local0_rdat_vld_i
		.local0_wdat_rdy_i(local_wr_rdy), //input local0_wdat_rdy_i
		.uart_rx_led_o(), //output uart_rx_led_o
		.uart_tx_led_o(), //output uart_tx_led_o
		.uart_rx_i(uart_rx), //input uart_rx_i
		.uart_tx_o(uart_tx) //output uart_tx_o
	);



endmodule
