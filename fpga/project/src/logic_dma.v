module logic_dma #(
    parameter integer AXI_ADDR_WIDTH = 29,
    parameter integer AXI_LEN_WIDTH  = 20
) (
    input clk,
    input rstn,

    // BAR2 user interface from PCIe Sgdma
    input             user_cs,
    input      [63:0] user_address,
    input             user_rw,
    input      [31:0] user_wr_data,
    input      [ 3:0] user_wr_be,
    input      [ 3:0] user_rd_be,
    output reg        user_rd_valid,
    output reg [31:0] user_rd_data,

    // Descriptor control for AXI DMA (PCIe Sgdma)

    output reg [AXI_ADDR_WIDTH-1:0] m_axis_h2c_desc_addr,
    output reg [ AXI_LEN_WIDTH-1:0] m_axis_h2c_desc_len,
    output reg                      m_axis_h2c_desc_valid,
    input                           m_axis_h2c_desc_ready,
    input      [            63 : 0] h2c_overhead_reg,

    output reg [AXI_ADDR_WIDTH-1:0] m_axis_c2h_desc_addr,
    output reg [ AXI_LEN_WIDTH-1:0] m_axis_c2h_desc_len,
    output reg                      m_axis_c2h_desc_valid,
    input                           m_axis_c2h_desc_ready,

    // Config & run control for Logic Adder
    output reg [AXI_ADDR_WIDTH-1:0] lad_read_addr,
    output reg [AXI_ADDR_WIDTH-1:0] lad_write_addr,
    output reg [ AXI_LEN_WIDTH-1:0] lad_len,
    output reg                      lad_run,
    input                           lad_busy,
    input                           lad_done,

    output reg [AXI_LEN_WIDTH-1:0] gen_len,
    output reg                     gen_run,
    input                          gen_done,
    output reg                     en_gen_mode,
    output reg [            6 : 0] num_desc,
    input                          h2c_done
);
  //* All lengths in bytes.

  localparam integer RegCtrl = 8'h00;
  localparam integer RegStatus = 8'h04;
  localparam integer RegNumDesc = 8'h08;  //? Temp
  localparam integer RegAddrDDRh2c = 8'h10;
  localparam integer RegLengDDRh2c = 8'h14;
  localparam integer RegOverheadh2cLo = 8'h18;  //? Temp
  localparam integer RegOverheadh2cHi = 8'h1C;  //? Temp
  localparam integer RegAddrDDRc2h = 8'h20;
  localparam integer RegLengDDRc2h = 8'h24;
  localparam integer RegAddrLadRd = 8'h30;
  localparam integer RegAddrLadWr = 8'h34;
  localparam integer RegLengLad = 8'h38;

  reg lad_done_latched;
  reg gen_done_latched;
  reg h2c_done_latched;
  reg lad_start_pulse;
  reg lad_stop_pulse;

  wire wr_en;
  wire rd_en;
  wire [7:0] addr_reg;

  assign wr_en = user_cs && user_rw;
  assign rd_en = user_cs && !user_rw;
  assign addr_reg = user_address[7:0];

  // gen
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      gen_run <= 1'b0;
      gen_len <= {AXI_LEN_WIDTH{1'b0}};
    end else begin
      if (en_gen_mode && m_axis_h2c_desc_valid && m_axis_h2c_desc_ready) begin
        gen_run <= 1'b1;
        gen_len <= m_axis_h2c_desc_len;
      end

      if (gen_done) begin
        gen_run <= 1'b0;
      end
    end
  end

  // lad
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      lad_run <= 1'b0;
      lad_done_latched <= 1'b0;
    end else begin
      if (lad_done) begin
        lad_run <= 1'b0;
        lad_done_latched <= 1'b1;
      end

      if (lad_start_pulse) begin
        lad_run <= 1'b1;
        lad_done_latched <= 1'b0;
      end

      if (lad_stop_pulse) begin
        lad_run <= 1'b0;
      end
    end
  end

  // h2c done
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      h2c_done_latched <= 1'b0;
    end else begin
      if (h2c_done) begin
        h2c_done_latched <= 1'b1;
      end
      if (wr_en && addr_reg == RegCtrl && user_wr_data[0]) begin
        h2c_done_latched <= 1'b0;
      end
    end
  end
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      gen_done_latched <= 1'b0;
    end else begin
      if (gen_done) begin
        gen_done_latched <= 1'b1;
      end
      if (wr_en && addr_reg == RegCtrl && user_wr_data[0]) begin
        gen_done_latched <= 1'b0;
      end
    end
  end

  // BAR2 host write
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      m_axis_h2c_desc_addr <= {AXI_ADDR_WIDTH{1'b0}};
      m_axis_h2c_desc_len <= {AXI_LEN_WIDTH{1'b0}};
      m_axis_h2c_desc_valid <= 1'b0;

      m_axis_c2h_desc_addr <= {AXI_ADDR_WIDTH{1'b0}};
      m_axis_c2h_desc_len <= {AXI_LEN_WIDTH{1'b0}};
      m_axis_c2h_desc_valid <= 1'b0;

      lad_read_addr <= {AXI_ADDR_WIDTH{1'b0}};
      lad_write_addr <= {AXI_ADDR_WIDTH{1'b0}};
      lad_len <= {AXI_LEN_WIDTH{1'b0}};

      en_gen_mode <= 1'b0;
      num_desc <= 7'd0;

      lad_start_pulse <= 1'b0;
      lad_stop_pulse <= 1'b0;
    end else begin
      lad_start_pulse <= 1'b0;
      lad_stop_pulse  <= 1'b0;

      if (m_axis_h2c_desc_valid && m_axis_h2c_desc_ready) begin
        m_axis_h2c_desc_valid <= 1'b0;
      end
      if (m_axis_c2h_desc_valid && m_axis_c2h_desc_ready) begin
        m_axis_c2h_desc_valid <= 1'b0;
      end

      if (wr_en) begin
        case (addr_reg)
          RegCtrl: begin
            // bit0: start pcie write descriptor
            // bit1: stop  pcie write descriptor
            // bit2: start pcie read  descriptor
            // bit3: stop  pcie read  descriptor
            // bit4: start logic adder
            // bit5: stop  logic adder
            // bit6: enable gen write data
            if (user_wr_data[0]) begin
              m_axis_h2c_desc_valid <= 1'b1;
            end
            if (user_wr_data[1]) begin
              m_axis_h2c_desc_valid <= 1'b0;
            end
            if (user_wr_data[2]) begin
              m_axis_c2h_desc_valid <= 1'b1;
            end
            if (user_wr_data[3]) begin
              m_axis_c2h_desc_valid <= 1'b0;
            end
            if (user_wr_data[4]) begin
              lad_start_pulse <= 1'b1;
            end
            if (user_wr_data[5]) begin
              lad_stop_pulse <= 1'b1;
            end
            if (user_wr_data[6]) begin
              en_gen_mode <= 1'b1;
            end
          end

          RegNumDesc: begin
            num_desc <= user_wr_data[6:0];
          end

          RegAddrDDRh2c: begin
            m_axis_h2c_desc_addr <= user_wr_data[AXI_ADDR_WIDTH-1:0];
          end
          RegLengDDRh2c: begin
            m_axis_h2c_desc_len <= user_wr_data[AXI_LEN_WIDTH-1:0];
          end

          RegAddrDDRc2h: begin
            m_axis_c2h_desc_addr <= user_wr_data[AXI_ADDR_WIDTH-1:0];
          end
          RegLengDDRc2h: begin
            m_axis_c2h_desc_len <= user_wr_data[AXI_LEN_WIDTH-1:0];
          end

          RegAddrLadRd: begin
            lad_read_addr <= user_wr_data[AXI_ADDR_WIDTH-1:0];
          end
          RegAddrLadWr: begin
            lad_write_addr <= user_wr_data[AXI_ADDR_WIDTH-1:0];
          end
          RegLengLad: begin
            lad_len <= user_wr_data[AXI_LEN_WIDTH-1:0];
          end

          default: begin
          end
        endcase
      end
    end
  end

  // BAR2 host read
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      user_rd_valid <= 1'b0;
      user_rd_data  <= 32'd0;
    end else begin
      user_rd_valid <= 1'b0;

      if (rd_en) begin
        user_rd_valid <= 1'b1;
        case (addr_reg)
          RegCtrl: user_rd_data <= 32'd0;
          RegStatus: begin
            user_rd_data[0] <= m_axis_c2h_desc_valid;
            user_rd_data[1] <= m_axis_h2c_desc_valid;
            user_rd_data[2] <= m_axis_c2h_desc_ready;
            user_rd_data[3] <= m_axis_h2c_desc_ready;
            user_rd_data[4] <= lad_run;
            user_rd_data[5] <= lad_done_latched;
            user_rd_data[6] <= gen_done_latched;
            user_rd_data[7] <= h2c_done_latched;
            user_rd_data[31:8] <= 24'd0;
          end

          RegAddrDDRh2c: begin
            user_rd_data <= {{(32 - AXI_ADDR_WIDTH) {1'b0}}, m_axis_h2c_desc_addr};
          end
          RegLengDDRh2c: begin
            user_rd_data <= {{(32 - AXI_LEN_WIDTH) {1'b0}}, m_axis_h2c_desc_len};
          end

          RegOverheadh2cLo: begin
            user_rd_data <= h2c_overhead_reg[31:0];
          end
          RegOverheadh2cHi: begin
            user_rd_data <= h2c_overhead_reg[63:32];
          end

          RegAddrDDRc2h: begin
            user_rd_data <= {{(32 - AXI_ADDR_WIDTH) {1'b0}}, m_axis_c2h_desc_addr};
          end
          RegLengDDRc2h: begin
            user_rd_data <= {{(32 - AXI_LEN_WIDTH) {1'b0}}, m_axis_c2h_desc_len};
          end

          RegAddrLadRd: begin
            user_rd_data <= {{(32 - AXI_ADDR_WIDTH) {1'b0}}, lad_read_addr};
          end
          RegAddrLadWr: begin
            user_rd_data <= {{(32 - AXI_ADDR_WIDTH) {1'b0}}, lad_write_addr};
          end
          RegLengLad: begin
            user_rd_data <= {{(32 - AXI_LEN_WIDTH) {1'b0}}, lad_len};
          end

          default: begin
            user_rd_data <= 32'd0;
          end
        endcase
      end
    end
  end

endmodule
