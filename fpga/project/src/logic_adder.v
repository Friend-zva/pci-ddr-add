module logic_adder #(
    parameter integer AXI_ADDR_WIDTH = 29,
    parameter integer AXI_LEN_WIDTH  = 20,
    parameter integer AXI_DATA_WIDTH = 256,
    parameter integer AXI_STRB_WIDTH = 32
) (
    input clk,
    input rstn,

    // Config
    input [AXI_ADDR_WIDTH-1:0] cfg_read_addr,
    input [AXI_ADDR_WIDTH-1:0] cfg_write_addr,
    input [ AXI_LEN_WIDTH-1:0] cfg_len,
    input [               7:0] cfg_desc_tag,

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
    output reg busy,
    output reg done
);

  assign m_axis_read_desc_addr  = cfg_read_addr;
  assign m_axis_read_desc_len   = cfg_len;
  assign m_axis_read_desc_tag   = cfg_desc_tag;
  assign m_axis_write_desc_addr = cfg_write_addr;
  assign m_axis_write_desc_len  = cfg_len;
  assign m_axis_write_desc_tag  = cfg_desc_tag;

  // Adder
  wire [AXI_DATA_WIDTH-1:0] tx_data_add16;

  genvar tx_dw;
  generate
    for (tx_dw = 0; tx_dw < (AXI_DATA_WIDTH / 32); tx_dw = tx_dw + 1) begin : gen_tx_add16
      wire [31:0] dword = s_axis_rx_tdata[tx_dw*32+:32];
      wire [16:0] sum16 = dword[15:0] + dword[31:16];
      assign tx_data_add16[tx_dw*32+:32] = {15'd0, sum16};
    end
  endgenerate

  // FSM
  localparam IDLE = 3'd0;
  localparam ISSUE_CMD = 3'd1;
  localparam WAIT_DATA = 3'd2;
  localparam DONE_STATE = 3'd3;

  reg [2:0] state;

  wire stream_fire = s_axis_rx_tvalid && s_axis_rx_tready;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state <= IDLE;
      m_axis_read_desc_valid <= 1'b0;
      m_axis_write_desc_valid <= 1'b0;
      busy <= 1'b0;
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
            busy <= 1'b1;
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
          if (stream_fire && s_axis_rx_tlast) begin
            done  <= 1'b1;
            state <= DONE_STATE;
          end
        end

        DONE_STATE: begin
          if (!run) begin
            busy  <= 1'b0;
            state <= IDLE;
          end
        end

      endcase
    end
  end

  // Pipeline
  reg  [AXI_DATA_WIDTH-1:0] pipe_tdata;
  reg                       pipe_tvalid;
  reg                       pipe_tlast;
  reg  [AXI_STRB_WIDTH-1:0] pipe_tkeep;

  wire                      stream_enable = (state == WAIT_DATA);
  wire                      pipe_ready = m_axis_tx_tready || !pipe_tvalid;

  assign s_axis_rx_tready = stream_enable && pipe_ready;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pipe_tvalid <= 1'b0;
      pipe_tlast  <= 1'b0;
    end else begin
      if (pipe_ready) begin
        pipe_tvalid <= (stream_enable && s_axis_rx_tvalid);
        pipe_tdata  <= tx_data_add16;
        pipe_tlast  <= s_axis_rx_tlast;
        pipe_tkeep  <= s_axis_rx_tkeep;
      end
    end
  end

  assign m_axis_tx_tvalid = pipe_tvalid;
  assign m_axis_tx_tdata  = pipe_tdata;
  assign m_axis_tx_tlast  = pipe_tlast;
  assign m_axis_tx_tkeep  = pipe_tkeep;

endmodule
