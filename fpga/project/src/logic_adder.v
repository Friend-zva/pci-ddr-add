module logic_adder #(
    parameter integer AXI_ADDR_WIDTH = 29,
    parameter integer AXI_LEN_WIDTH  = 20,
    parameter integer AXI_DATA_WIDTH = 256,
    parameter integer AXI_STRB_WIDTH = 32
) (
    input clk,
    input rst_n,

    // Config
    input [AXI_ADDR_WIDTH-1:0] cfg_read_addr,
    input [AXI_ADDR_WIDTH-1:0] cfg_write_addr,
    input [ AXI_LEN_WIDTH-1:0] cfg_len,

    // Descriptors for AXI DMA

    output reg                      m_axis_read_desc_valid,
    input                           m_axis_read_desc_ready,
    output     [AXI_ADDR_WIDTH-1:0] m_axis_read_desc_addr,
    output     [ AXI_LEN_WIDTH-1:0] m_axis_read_desc_len,
    output     [               7:0] m_axis_read_desc_tag,

    output reg                      m_axis_write_desc_valid,
    input                           m_axis_write_desc_ready,
    output     [AXI_ADDR_WIDTH-1:0] m_axis_write_desc_addr,
    output     [ AXI_LEN_WIDTH-1:0] m_axis_write_desc_len,
    output     [               7:0] m_axis_write_desc_tag,
    input                           s_axis_write_desc_status_valid,

    // Receive
    output                      s_axis_rx_tready,
    input                       s_axis_rx_tvalid,
    input  [AXI_DATA_WIDTH-1:0] s_axis_rx_tdata,
    input                       s_axis_rx_tlast,
    input  [AXI_STRB_WIDTH-1:0] s_axis_rx_tkeep,
    // Transmit
    input                       m_axis_tx_tready,
    output                      m_axis_tx_tvalid,
    output                      m_axis_tx_tlast,
    output [AXI_DATA_WIDTH-1:0] m_axis_tx_tdata,
    output [AXI_STRB_WIDTH-1:0] m_axis_tx_tkeep,

    // Control
    input      run,
    output reg done
);

  assign m_axis_read_desc_addr  = cfg_read_addr;
  assign m_axis_read_desc_len   = cfg_len;
  assign m_axis_read_desc_tag   = cfg_read_addr[15:8];
  assign m_axis_write_desc_addr = cfg_write_addr;
  assign m_axis_write_desc_len  = cfg_len;
  assign m_axis_write_desc_tag  = cfg_write_addr[15:8];

  // Register Receive
  reg  [AXI_DATA_WIDTH-1:0] reg_rx_tdata;
  reg  [AXI_STRB_WIDTH-1:0] reg_rx_tkeep;
  reg                       reg_rx_tvalid;
  reg                       reg_rx_tlast;
  // Register Transmit
  reg  [AXI_DATA_WIDTH-1:0] reg_tx_tdata;
  reg  [AXI_STRB_WIDTH-1:0] reg_tx_tkeep;
  reg                       reg_tx_tvalid;
  reg                       reg_tx_tlast;

  wire [AXI_DATA_WIDTH-1:0] sum32;
  genvar dw;
  generate
    for (dw = 0; dw < (AXI_DATA_WIDTH / 32); dw = dw + 1) begin : gen_add16
      wire [31:0] dword = reg_rx_tdata[dw*32+:32];
      wire [16:0] sum16 = dword[15:0] + dword[31:16];
      assign sum32[dw*32+:32] = {15'd0, sum16};
    end
  endgenerate

  // FSM
  localparam IDLE = 3'd0;
  localparam ISSUE_CMD = 3'd1;
  localparam WAIT_DATA = 3'd2;
  localparam WAIT_AXI = 3'd3;
  localparam DONE_STATE = 3'd4;

  reg  [2:0] state;

  wire       tx_fire = m_axis_tx_tvalid && m_axis_tx_tready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      m_axis_read_desc_valid <= 1'b0;
      m_axis_write_desc_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;

      if (m_axis_read_desc_valid && m_axis_read_desc_ready) begin
        m_axis_read_desc_valid <= 1'b0;
      end
      if (m_axis_write_desc_valid && m_axis_write_desc_ready) begin
        m_axis_write_desc_valid <= 1'b0;
      end

      case (state)
        IDLE: begin
          if (run) begin
            m_axis_read_desc_valid <= 1'b1;
            m_axis_write_desc_valid <= 1'b1;
            state <= ISSUE_CMD;
          end
        end

        ISSUE_CMD: begin
          if (!m_axis_read_desc_valid && !m_axis_write_desc_valid) begin
            state <= WAIT_DATA;
          end
        end

        WAIT_DATA: begin
          if (tx_fire && m_axis_tx_tlast) begin
            state <= WAIT_AXI;
          end
        end

        WAIT_AXI: begin
          if (s_axis_write_desc_status_valid) begin
            done  <= 1'b1;
            state <= DONE_STATE;
          end
        end

        DONE_STATE: begin
          if (!run) begin
            state <= IDLE;
          end
        end

      endcase
    end
  end

  // Pipeline
  wire stream_enable = (state == WAIT_DATA);
  assign s_axis_rx_tready = stream_enable && m_axis_tx_tready;
  wire stream_fire = s_axis_rx_tvalid && s_axis_rx_tready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_rx_tvalid <= 1'b0;
      reg_rx_tlast  <= 1'b0;
    end else if (m_axis_tx_tready) begin
      reg_rx_tvalid <= stream_fire;
      reg_rx_tdata  <= s_axis_rx_tdata;
      reg_rx_tlast  <= s_axis_rx_tlast;
      reg_rx_tkeep  <= s_axis_rx_tkeep;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_tx_tvalid <= 1'b0;
      reg_tx_tlast  <= 1'b0;
    end else if (m_axis_tx_tready) begin
      reg_tx_tvalid <= reg_rx_tvalid;
      reg_tx_tdata  <= sum32;
      reg_tx_tlast  <= reg_rx_tlast;
      reg_tx_tkeep  <= reg_rx_tkeep;
    end
  end

  assign m_axis_tx_tvalid = reg_tx_tvalid;
  assign m_axis_tx_tdata  = reg_tx_tdata;
  assign m_axis_tx_tlast  = reg_tx_tlast;
  assign m_axis_tx_tkeep  = reg_tx_tkeep;

endmodule
