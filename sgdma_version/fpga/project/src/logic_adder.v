module logic_adder (
    input clk,
    input rstn,

    // Config
    input [63:0] cfg_read_addr,
    input [63:0] cfg_write_addr,
    input [31:0] cfg_len,
    input [ 7:0] cfg_desc_tag,

    // Descriptors for AXI DMA

    output reg        m_axis_read_desc_valid,
    input             m_axis_read_desc_ready,
    output     [63:0] m_axis_read_desc_addr,
    output     [31:0] m_axis_read_desc_len,
    output     [ 7:0] m_axis_read_desc_tag,

    output reg        m_axis_write_desc_valid,
    input             m_axis_write_desc_ready,
    output     [63:0] m_axis_write_desc_addr,
    output     [31:0] m_axis_write_desc_len,
    output     [ 7:0] m_axis_write_desc_tag,

    // Receive
    output         s_axis_rx_tready,
    input          s_axis_rx_tvalid,
    input  [255:0] s_axis_rx_tdata,
    input          s_axis_rx_tlast,
    input  [ 31:0] s_axis_rx_tkeep,
    // Transmit
    input          m_axis_tx_tready,
    output         m_axis_tx_tvalid,
    output         m_axis_tx_tlast,
    output [255:0] m_axis_tx_tdata,
    output [ 31:0] m_axis_tx_tkeep,

    input      run,
    output reg busy,
    output reg done
);

  wire stream_enable;
  wire read_desc_fire;
  wire write_desc_fire;
  wire stream_fire;
  wire [255:0] tx_data_add16;

  reg read_desc_issued;
  reg write_desc_issued;

  assign stream_enable = run;
  assign read_desc_fire = m_axis_read_desc_valid && m_axis_read_desc_ready;
  assign write_desc_fire = m_axis_write_desc_valid && m_axis_write_desc_ready;
  assign stream_fire = s_axis_rx_tvalid && s_axis_rx_tready;

  assign m_axis_read_desc_addr = cfg_read_addr;
  assign m_axis_read_desc_len = cfg_len;
  assign m_axis_read_desc_tag = cfg_desc_tag;
  assign m_axis_write_desc_addr = cfg_write_addr;
  assign m_axis_write_desc_len = cfg_len;
  assign m_axis_write_desc_tag = cfg_desc_tag;

  genvar tx_dw;
  generate
    for (tx_dw = 0; tx_dw < 8; tx_dw = tx_dw + 1) begin : gen_tx_add16
      wire [31:0] dword;
      wire [16:0] sum16;
      assign dword = s_axis_rx_tdata[tx_dw*32+:32];
      assign sum16 = dword[15:0] + dword[31:16];
      assign tx_data_add16[tx_dw*32+:32] = {15'd0, sum16};
    end
  endgenerate

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      m_axis_read_desc_valid <= 1'b0;
      m_axis_write_desc_valid <= 1'b0;
      read_desc_issued <= 1'b0;
      write_desc_issued <= 1'b0;
      busy <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;

      if (!stream_enable) begin
        m_axis_read_desc_valid <= 1'b0;
        m_axis_write_desc_valid <= 1'b0;
        read_desc_issued <= 1'b0;
        write_desc_issued <= 1'b0;
        busy <= 1'b0;
      end else begin
        busy <= 1'b1;

        if (!read_desc_issued) begin
          m_axis_read_desc_valid <= 1'b1;
          if (read_desc_fire) begin
            m_axis_read_desc_valid <= 1'b0;
            read_desc_issued <= 1'b1;
          end
        end else begin
          m_axis_read_desc_valid <= 1'b0;
        end

        if (!write_desc_issued) begin
          m_axis_write_desc_valid <= 1'b1;
          if (write_desc_fire) begin
            m_axis_write_desc_valid <= 1'b0;
            write_desc_issued <= 1'b1;
          end
        end else begin
          m_axis_write_desc_valid <= 1'b0;
        end

        if (stream_fire && s_axis_rx_tlast) begin
          read_desc_issued <= 1'b0;
          write_desc_issued <= 1'b0;
          busy <= 1'b0;
          done <= 1'b1;
        end
      end
    end
  end

  // Pipeline
  reg [255:0] pipe_tdata;
  reg pipe_tvalid;
  reg pipe_tlast;
  reg [31:0] pipe_tkeep;

  wire pipe_ready = m_axis_tx_tready || !pipe_tvalid;
  wire in_valid = stream_enable && read_desc_issued && write_desc_issued && s_axis_rx_tvalid;

  assign s_axis_rx_tready = stream_enable && read_desc_issued && write_desc_issued && pipe_ready;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pipe_tvalid <= 1'b0;
      pipe_tlast  <= 1'b0;
    end else begin
      if (pipe_ready) begin
        pipe_tvalid <= in_valid;
        pipe_tdata  <= tx_data_add16;
        pipe_tlast  <= s_axis_rx_tlast;
        pipe_tkeep  <= s_axis_rx_tkeep;
      end
    end
  end

  assign m_axis_tx_tvalid  = pipe_tvalid;
  assign m_axis_tx_tdata   = pipe_tdata;
  assign m_axis_tx_tlast   = pipe_tlast;
  assign m_axis_tx_tkeep   = pipe_tkeep;

endmodule
