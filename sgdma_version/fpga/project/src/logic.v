module logic (
    input              clk,
    input              rstn,
    //h2c
    output reg         m_axis_h2c_tready = 0,
    input              m_axis_h2c_tvalid,
    input      [255:0] m_axis_h2c_tdata,
    input              m_axis_h2c_tlast,
    input      [ 31:0] m_axis_h2c_tuser,
    input      [ 31:0] m_axis_h2c_tkeep,
    input      [ 63:0] h2c_overhead,
    //c2h
    input              s_axis_c2h_tready,
    output             s_axis_c2h_tvalid,
    output             s_axis_c2h_tlast,
    output     [255:0] s_axis_c2h_tdata,
    output     [ 31:0] s_axis_c2h_tuser,
    output     [ 31:0] s_axis_c2h_tkeep,
    output             c2h_overhead_valid,
    output     [ 63:0] c2h_overhead_data,
    //local bus
    input              local_wren,
    input              local_rden,
    input      [ 15:0] local_addr,
    input      [ 31:0] local_wrdata,
    output reg [ 31:0] local_rddata,
    output reg         local_rd_vld,
    output reg         local_wr_rdy,

    input h2c_run,
    input c2h_run
);

  reg [31:0] h2c_packet_length = 0;
  reg h2c_clear_test_result = 0;
  reg [7:0] c2h_initial_m_axis_c2h_tdata = 0;
  reg [31:0] c2h_byte_length = 0;
  reg [31:0] c2h_byte_length_reg = 0;
  reg c2h_clear_test_result = 0;
  reg c2h_length_inc_en = 0;

  wire stream_enable;
  wire [255:0] c2h_tx_data_add16;
  assign stream_enable = h2c_run && c2h_run;

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
      local_wr_rdy <= 1'b0;
    end else begin
      if (local_wr_rdy) begin
        local_wr_rdy <= 1'b0;
      end else if (local_wren) begin
        local_wr_rdy <= 1'b1;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      local_rd_vld <= 1'b0;
    end else begin
      if (local_rd_vld) begin
        local_rd_vld <= 1'b0;
      end else if (local_rden) begin
        local_rd_vld <= 1'b1;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      m_axis_h2c_tready <= 1'b0;
      h2c_packet_length <= 32'd0;
      h2c_clear_test_result <= 1'b0;
      c2h_initial_m_axis_c2h_tdata <= 8'd0;
      c2h_clear_test_result <= 1'b0;
      c2h_length_inc_en <= 1'b0;
    end else begin
      m_axis_h2c_tready <= stream_enable && s_axis_c2h_tready;
      if (local_wren && local_wr_rdy) begin
        case (local_addr)
          16'h0101: h2c_packet_length <= local_wrdata;
          16'h0103: h2c_clear_test_result <= local_wrdata[0];
          16'h0200: c2h_initial_m_axis_c2h_tdata <= local_wrdata[7:0];
          16'h0203: c2h_clear_test_result <= local_wrdata[0];
          16'h0201: begin
            c2h_byte_length_reg <= local_wrdata;
            c2h_byte_length <= local_wrdata;
          end
          16'h0204: c2h_length_inc_en <= local_wrdata[0];
          default: begin
          end
        endcase
      end else if (!c2h_run) begin
        c2h_byte_length <= c2h_byte_length_reg;
      end else if (
          c2h_length_inc_en && m_axis_h2c_tvalid &&
          m_axis_h2c_tready && m_axis_h2c_tlast
      ) begin
        c2h_byte_length <= c2h_byte_length + 1;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      local_rddata <= 32'd0;
    end else if (local_rden) begin
      local_rddata <= 32'd0;
      case (local_addr)
        16'h0101: local_rddata <= h2c_packet_length;
        16'h0102: local_rddata[0] <= m_axis_h2c_tready;
        16'h0103: local_rddata[0] <= h2c_clear_test_result;
        16'h0104: local_rddata <= 32'd0;
        16'h0105: local_rddata <= 32'd0;
        16'h0106: local_rddata <= 32'd0;

        16'h0200: local_rddata <= c2h_initial_m_axis_c2h_tdata;
        16'h0203: local_rddata[0] <= c2h_clear_test_result;
        16'h0201: local_rddata <= c2h_byte_length;
        16'h0202: local_rddata[0] <= c2h_run;
        16'h0204: local_rddata[0] <= c2h_length_inc_en;
        default:  local_rddata <= 32'd0;
      endcase
    end
  end

  assign s_axis_c2h_tvalid  = stream_enable && m_axis_h2c_tvalid;
  assign s_axis_c2h_tdata   = c2h_tx_data_add16;

  assign s_axis_c2h_tlast   = m_axis_h2c_tlast;
  assign s_axis_c2h_tkeep   = m_axis_h2c_tkeep;
  assign s_axis_c2h_tuser   = m_axis_h2c_tuser;
  assign c2h_overhead_valid = 1'b0;
  assign c2h_overhead_data  = 64'h01_02_03_04_aa_bb_cc_dd;

endmodule
