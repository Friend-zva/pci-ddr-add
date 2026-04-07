module logic_dma #(
    parameter integer AXIADDRWIDTH = 29,
    parameter integer AXILENWIDTH  = 20
) (
    input             clk,
    input             rstn,
    // BAR2 user interface from Pcie_Sgdma_Top
    input             user_cs,
    input      [63:0] user_address,
    input             user_rw,
    input      [31:0] user_wr_data,
    input      [ 3:0] user_wr_be,
    input      [ 3:0] user_rd_be,
    output reg        user_rd_valid,
    output reg [31:0] user_rd_data,

    // Descriptor control for axi_dma_pcie_sgdma
    output reg [AXIADDRWIDTH-1:0] pcie_read_desc_addr,
    output reg [ AXILENWIDTH-1:0] pcie_read_desc_len,
    output reg [           7 : 0] pcie_read_desc_tag,
    output reg                    pcie_read_desc_valid,
    input                         pcie_read_desc_ready,

    output reg [AXIADDRWIDTH-1:0] pcie_write_desc_addr,
    output reg [ AXILENWIDTH-1:0] pcie_write_desc_len,
    output reg [           7 : 0] pcie_write_desc_tag,
    output reg                    pcie_write_desc_valid,
    input                         pcie_write_desc_ready,

    // Config + run control for logic_adder path
    output reg [63:0] lad_read_addr,
    output reg [63:0] lad_write_addr,
    output reg [31:0] lad_byte_len,
    output reg [ 7:0] lad_desc_tag,
    output reg        lad_h2c_run,
    output reg        lad_c2h_run,
    input             lad_busy,
    input             lad_done
);

  localparam integer RegCtrl = 8'h00;
  localparam integer RegStatus = 8'h04;
  localparam integer RegPcieRdAddrLo = 8'h10;
  localparam integer RegPcieRdAddrHi = 8'h14;
  localparam integer RegPcieRdLen = 8'h18;
  localparam integer RegPcieWrAddrLo = 8'h1C;
  localparam integer RegPcieWrAddrHi = 8'h20;
  localparam integer RegPcieWrLen = 8'h24;
  localparam integer RegLadRdAddrLo = 8'h30;
  localparam integer RegLadRdAddrHi = 8'h34;
  localparam integer RegLadWrAddrLo = 8'h38;
  localparam integer RegLadWrAddrHi = 8'h3C;
  localparam integer RegLadLen = 8'h40;
  localparam integer RegTags = 8'h44;

  reg [31:0] pcie_rd_addr_lo;
  reg [31:0] pcie_rd_addr_hi;
  reg [31:0] pcie_wr_addr_lo;
  reg [31:0] pcie_wr_addr_hi;

  reg [31:0] lad_rd_addr_lo;
  reg [31:0] lad_rd_addr_hi;
  reg [31:0] lad_wr_addr_lo;
  reg [31:0] lad_wr_addr_hi;

  reg lad_done_latched;

  wire wr_en;
  wire rd_en;
  wire [7:0] reg_addr;

  assign wr_en = user_cs && user_rw;
  assign rd_en = user_cs && !user_rw;
  assign reg_addr = user_address[7:0];

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      user_rd_valid <= 1'b0;
      user_rd_data <= 32'd0;

      pcie_read_desc_addr <= {AXIADDRWIDTH{1'b0}};
      pcie_read_desc_len <= {AXILENWIDTH{1'b0}};
      pcie_read_desc_tag <= 8'd0;
      pcie_read_desc_valid <= 1'b0;

      pcie_write_desc_addr <= {AXIADDRWIDTH{1'b0}};
      pcie_write_desc_len <= {AXILENWIDTH{1'b0}};
      pcie_write_desc_tag <= 8'd0;
      pcie_write_desc_valid <= 1'b0;

      pcie_rd_addr_lo <= 32'd0;
      pcie_rd_addr_hi <= 32'd0;
      pcie_wr_addr_lo <= 32'd0;
      pcie_wr_addr_hi <= 32'd0;

      lad_read_addr <= 64'h0000_0000_0000_5000;
      lad_write_addr <= 64'h0000_0000_0000_6000;
      lad_byte_len <= 32'd1000;
      lad_desc_tag <= 8'h01;
      lad_h2c_run <= 1'b0;
      lad_c2h_run <= 1'b0;

      lad_rd_addr_lo <= 32'h0000_5000;
      lad_rd_addr_hi <= 32'd0;
      lad_wr_addr_lo <= 32'h0000_6000;
      lad_wr_addr_hi <= 32'd0;

      lad_done_latched <= 1'b0;
    end else begin
      user_rd_valid <= 1'b0;

      if (pcie_read_desc_valid && pcie_read_desc_ready) begin
        pcie_read_desc_valid <= 1'b0;
      end
      if (pcie_write_desc_valid && pcie_write_desc_ready) begin
        pcie_write_desc_valid <= 1'b0;
      end

      if (lad_done) begin
        lad_h2c_run <= 1'b0;
        lad_c2h_run <= 1'b0;
        lad_done_latched <= 1'b1;
      end

      if (wr_en) begin
        case (reg_addr)
          RegCtrl: begin
            // bit0: pulse pcie read descriptor
            // bit1: pulse pcie write descriptor
            // bit2: start logic_adder run
            // bit3: stop logic_adder run
            if (user_wr_data[0]) begin
              pcie_read_desc_addr  <= pcie_rd_addr_lo[AXIADDRWIDTH-1:0];
              pcie_read_desc_valid <= 1'b1;
            end
            if (user_wr_data[1]) begin
              pcie_write_desc_addr  <= pcie_wr_addr_lo[AXIADDRWIDTH-1:0];
              pcie_write_desc_valid <= 1'b1;
            end
            if (user_wr_data[2]) begin
              lad_h2c_run <= 1'b1;
              lad_c2h_run <= 1'b1;
              lad_done_latched <= 1'b0;
            end
            if (user_wr_data[3]) begin
              lad_h2c_run <= 1'b0;
              lad_c2h_run <= 1'b0;
            end
          end

          RegPcieRdAddrLo: begin
            pcie_rd_addr_lo <= user_wr_data;
            pcie_read_desc_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegPcieRdAddrHi: begin
            pcie_rd_addr_hi <= user_wr_data;
          end
          RegPcieRdLen: begin
            pcie_read_desc_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegPcieWrAddrLo: begin
            pcie_wr_addr_lo <= user_wr_data;
            pcie_write_desc_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegPcieWrAddrHi: begin
            pcie_wr_addr_hi <= user_wr_data;
          end
          RegPcieWrLen: begin
            pcie_write_desc_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegLadRdAddrLo: begin
            lad_rd_addr_lo <= user_wr_data;
            lad_read_addr[31:0] <= user_wr_data;
          end
          RegLadRdAddrHi: begin
            lad_rd_addr_hi <= user_wr_data;
            lad_read_addr[63:32] <= user_wr_data;
          end
          RegLadWrAddrLo: begin
            lad_wr_addr_lo <= user_wr_data;
            lad_write_addr[31:0] <= user_wr_data;
          end
          RegLadWrAddrHi: begin
            lad_wr_addr_hi <= user_wr_data;
            lad_write_addr[63:32] <= user_wr_data;
          end
          RegLadLen: begin
            if (user_wr_be[0]) lad_byte_len[7:0] <= user_wr_data[7:0];
            if (user_wr_be[1]) lad_byte_len[15:8] <= user_wr_data[15:8];
            if (user_wr_be[2]) lad_byte_len[23:16] <= user_wr_data[23:16];
            if (user_wr_be[3]) lad_byte_len[31:24] <= user_wr_data[31:24];
          end
          RegTags: begin
            pcie_read_desc_tag <= user_wr_data[7:0];
            pcie_write_desc_tag <= user_wr_data[15:8];
            lad_desc_tag <= user_wr_data[23:16];
          end
          default: begin
          end
        endcase
      end

      if (rd_en) begin
        user_rd_valid <= 1'b1;
        case (reg_addr)
          RegCtrl: user_rd_data <= 32'd0;
          RegStatus: begin
            user_rd_data[0] <= pcie_read_desc_valid;
            user_rd_data[1] <= pcie_write_desc_valid;
            user_rd_data[2] <= pcie_read_desc_ready;
            user_rd_data[3] <= pcie_write_desc_ready;
            user_rd_data[4] <= lad_h2c_run;
            user_rd_data[5] <= lad_c2h_run;
            user_rd_data[6] <= lad_busy;
            user_rd_data[7] <= lad_done_latched;
            user_rd_data[31:8] <= 24'd0;
          end

          RegPcieRdAddrLo: user_rd_data <= pcie_rd_addr_lo;
          RegPcieRdAddrHi: user_rd_data <= pcie_rd_addr_hi;
          RegPcieRdLen: user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, pcie_read_desc_len};

          RegPcieWrAddrLo: user_rd_data <= pcie_wr_addr_lo;
          RegPcieWrAddrHi: user_rd_data <= pcie_wr_addr_hi;
          RegPcieWrLen: user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, pcie_write_desc_len};

          RegLadRdAddrLo: user_rd_data <= lad_rd_addr_lo;
          RegLadRdAddrHi: user_rd_data <= lad_rd_addr_hi;
          RegLadWrAddrLo: user_rd_data <= lad_wr_addr_lo;
          RegLadWrAddrHi: user_rd_data <= lad_wr_addr_hi;
          RegLadLen: user_rd_data <= lad_byte_len;
          RegTags: user_rd_data <= {8'd0, lad_desc_tag, pcie_write_desc_tag, pcie_read_desc_tag};
          default: user_rd_data <= 32'd0;
        endcase
      end
    end
  end

endmodule
