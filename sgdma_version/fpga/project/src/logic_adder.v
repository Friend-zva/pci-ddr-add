module logic_adder (
    input             clk,
    input             rstn,
    input      [63:0] cfg_read_addr,
    input      [63:0] cfg_write_addr,
    input      [31:0] cfg_byte_len,
    input      [ 7:0] cfg_desc_tag,
    // dma descriptors: logic -> axi_dma_2
    output reg        s_axis_read_desc_valid,
    input             s_axis_read_desc_ready,
    output     [63:0] s_axis_read_desc_addr,
    output     [31:0] s_axis_read_desc_len,
    output     [ 7:0] s_axis_read_desc_tag,

    output reg        s_axis_write_desc_valid,
    input             s_axis_write_desc_ready,
    output     [63:0] s_axis_write_desc_addr,
    output     [31:0] s_axis_write_desc_len,
    output     [ 7:0] s_axis_write_desc_tag,

    // h2c
    output         m_axis_h2c_tready,
    input          m_axis_h2c_tvalid,
    input  [255:0] m_axis_h2c_tdata,
    input          m_axis_h2c_tlast,
    input  [ 31:0] m_axis_h2c_tuser,
    input  [ 31:0] m_axis_h2c_tkeep,
    input  [ 63:0] h2c_overhead,
    // c2h
    input          s_axis_c2h_tready,
    output         s_axis_c2h_tvalid,
    output         s_axis_c2h_tlast,
    output [255:0] s_axis_c2h_tdata,
    output [ 31:0] s_axis_c2h_tuser,
    output [ 31:0] s_axis_c2h_tkeep,
    output         c2h_overhead_valid,
    output [ 63:0] c2h_overhead_data,

    input      h2c_run,
    input      c2h_run,
    output reg busy,
    output reg done
);

  wire stream_enable;
  wire read_desc_fire;
  wire write_desc_fire;
  wire stream_fire;
  wire [255:0] c2h_tx_data_add16;

  reg read_desc_issued;
  reg write_desc_issued;

  assign stream_enable = h2c_run && c2h_run;
  assign read_desc_fire = s_axis_read_desc_valid && s_axis_read_desc_ready;
  assign write_desc_fire = s_axis_write_desc_valid && s_axis_write_desc_ready;
  assign stream_fire = m_axis_h2c_tvalid && m_axis_h2c_tready;
  assign s_axis_read_desc_addr = cfg_read_addr;
  assign s_axis_read_desc_len = cfg_byte_len;
  assign s_axis_read_desc_tag = cfg_desc_tag;
  assign s_axis_write_desc_addr = cfg_write_addr;
  assign s_axis_write_desc_len = cfg_byte_len;
  assign s_axis_write_desc_tag = cfg_desc_tag;

  genvar c2h_dw;
  generate
    for (c2h_dw = 0; c2h_dw < 8; c2h_dw = c2h_dw + 1) begin : gen_c2h_add16
      wire [31:0] word_in;
      wire [16:0] sum16;
      assign word_in = m_axis_h2c_tdata[c2h_dw*32+:32];
      assign sum16 = word_in[15:0] + word_in[31:16];
      assign c2h_tx_data_add16[c2h_dw*32+:32] = {15'd0, sum16};
    end
  endgenerate

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      s_axis_read_desc_valid <= 1'b0;
      s_axis_write_desc_valid <= 1'b0;
      read_desc_issued <= 1'b0;
      write_desc_issued <= 1'b0;
      busy <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;

      if (!stream_enable) begin
        s_axis_read_desc_valid <= 1'b0;
        s_axis_write_desc_valid <= 1'b0;
        read_desc_issued <= 1'b0;
        write_desc_issued <= 1'b0;
        busy <= 1'b0;
      end else begin
        busy <= 1'b1;

        if (!read_desc_issued) begin
          s_axis_read_desc_valid <= 1'b1;
          if (read_desc_fire) begin
            s_axis_read_desc_valid <= 1'b0;
            read_desc_issued <= 1'b1;
          end
        end else begin
          s_axis_read_desc_valid <= 1'b0;
        end

        if (!write_desc_issued) begin
          s_axis_write_desc_valid <= 1'b1;
          if (write_desc_fire) begin
            s_axis_write_desc_valid <= 1'b0;
            write_desc_issued <= 1'b1;
          end
        end else begin
          s_axis_write_desc_valid <= 1'b0;
        end

        if (stream_fire && m_axis_h2c_tlast) begin
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
  reg [31:0] pipe_tuser;

  wire pipe_ready = s_axis_c2h_tready || !pipe_tvalid;
  wire in_valid = stream_enable && read_desc_issued && write_desc_issued && m_axis_h2c_tvalid;

  assign m_axis_h2c_tready = stream_enable && read_desc_issued && write_desc_issued && pipe_ready;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pipe_tvalid <= 1'b0;
      pipe_tlast  <= 1'b0;
    end else begin
      if (pipe_ready) begin
        pipe_tvalid <= in_valid;
        pipe_tdata  <= c2h_tx_data_add16;
        pipe_tlast  <= m_axis_h2c_tlast;
        pipe_tkeep  <= m_axis_h2c_tkeep;
        pipe_tuser  <= m_axis_h2c_tuser;
      end
    end
  end

  assign s_axis_c2h_tvalid  = pipe_tvalid;
  assign s_axis_c2h_tdata   = pipe_tdata;
  assign s_axis_c2h_tlast   = pipe_tlast;
  assign s_axis_c2h_tkeep   = pipe_tkeep;
  assign s_axis_c2h_tuser   = pipe_tuser;
  assign c2h_overhead_valid = 1'b0;
  assign c2h_overhead_data  = 64'h01_02_03_04_aa_bb_cc_dd;

endmodule
