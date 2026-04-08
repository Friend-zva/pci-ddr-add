module logic_dma #(
    parameter integer AXIADDRWIDTH = 29,
    parameter integer AXILENWIDTH  = 20
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

    output reg [AXIADDRWIDTH-1:0] pcie_write_addr,
    output reg [ AXILENWIDTH-1:0] pcie_write_len,
    output reg                    pcie_write_valid,
    input                         pcie_write_ready,

    output reg [AXIADDRWIDTH-1:0] pcie_read_addr,
    output reg [ AXILENWIDTH-1:0] pcie_read_len,
    output reg                    pcie_read_valid,
    input                         pcie_read_ready,

    // Config & run control for Logic Adder
    output reg [63:0] lad_read_addr,
    output reg [63:0] lad_write_addr,
    output reg [31:0] lad_len,
    output reg        lad_run,
    input             lad_busy,
    input             lad_done
);
  //* All lengths in bytes.

  localparam integer RegCtrl = 8'h00;
  localparam integer RegStatus = 8'h04;
  localparam integer RegAddrDDRh2cLo = 8'h10;
  localparam integer RegAddrDDRh2cHi = 8'h14;
  localparam integer RegLengDDRh2c = 8'h18;
  localparam integer RegAddrDDRc2hLo = 8'h1C;
  localparam integer RegAddrDDRc2hHi = 8'h20;
  localparam integer RegLengDDRc2h = 8'h24;
  localparam integer RegAddrLadRdLo = 8'h30;
  localparam integer RegAddrLadRdHi = 8'h34;
  localparam integer RegAddrLadWrLo = 8'h38;
  localparam integer RegAddrLadWrHi = 8'h3C;
  localparam integer RegLengLad = 8'h40;

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

      pcie_read_addr <= {AXIADDRWIDTH{1'b0}};
      pcie_read_len <= {AXILENWIDTH{1'b0}};
      pcie_read_valid <= 1'b0;

      pcie_write_addr <= {AXIADDRWIDTH{1'b0}};
      pcie_write_len <= {AXILENWIDTH{1'b0}};
      pcie_write_valid <= 1'b0;

      pcie_rd_addr_lo <= 32'd0;
      pcie_rd_addr_hi <= 32'd0;
      pcie_wr_addr_lo <= 32'd0;
      pcie_wr_addr_hi <= 32'd0;

      lad_read_addr <= 64'h0000_0000_0000_5000;
      lad_write_addr <= 64'h0000_0000_0000_6000;
      lad_len <= 32'd0;
      lad_run <= 1'b0;

      lad_rd_addr_lo <= 32'h0000_5000;
      lad_rd_addr_hi <= 32'd0;
      lad_wr_addr_lo <= 32'h0000_6000;
      lad_wr_addr_hi <= 32'd0;

      lad_done_latched <= 1'b0;
    end else begin
      user_rd_valid <= 1'b0;

      if (pcie_read_valid && pcie_read_ready) begin
        pcie_read_valid <= 1'b0;
      end
      if (pcie_write_valid && pcie_write_ready) begin
        pcie_write_valid <= 1'b0;
      end

      if (lad_done) begin
        lad_run <= 1'b0;
        lad_done_latched <= 1'b1;
      end

      if (wr_en) begin
        case (reg_addr)
          RegCtrl: begin
            // bit0: start pcie write descriptor
            // bit1: start pcie read  descriptor
            // bit2: start logic_adder run
            // bit3: stop  logic_adder run
            if (user_wr_data[0]) begin
              pcie_write_addr  <= pcie_wr_addr_lo[AXIADDRWIDTH-1:0];
              pcie_write_valid <= 1'b1;
            end
            if (user_wr_data[1]) begin
              pcie_read_addr  <= pcie_rd_addr_lo[AXIADDRWIDTH-1:0];
              pcie_read_valid <= 1'b1;
            end
            if (user_wr_data[2]) begin
              lad_run <= 1'b1;
              lad_done_latched <= 1'b0;
            end
            if (user_wr_data[3]) begin
              lad_run <= 1'b0;
            end
          end

          RegAddrDDRh2cLo: begin
            pcie_wr_addr_lo <= user_wr_data;
            pcie_write_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegAddrDDRh2cHi: begin
            pcie_wr_addr_hi <= user_wr_data;
          end
          RegLengDDRh2c: begin
            pcie_write_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegAddrDDRc2hLo: begin
            pcie_rd_addr_lo <= user_wr_data;
            pcie_read_addr  <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegAddrDDRc2hHi: begin
            pcie_rd_addr_hi <= user_wr_data;
          end
          RegLengDDRc2h: begin
            pcie_read_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegAddrLadRdLo: begin
            lad_rd_addr_lo <= user_wr_data;
            lad_read_addr[31:0] <= user_wr_data;
          end
          RegAddrLadRdHi: begin
            lad_rd_addr_hi <= user_wr_data;
            lad_read_addr[63:32] <= user_wr_data;
          end
          RegAddrLadWrLo: begin
            lad_wr_addr_lo <= user_wr_data;
            lad_write_addr[31:0] <= user_wr_data;
          end
          RegAddrLadWrHi: begin
            lad_wr_addr_hi <= user_wr_data;
            lad_write_addr[63:32] <= user_wr_data;
          end
          RegLengLad: begin
            if (user_wr_be[0]) lad_len[7:0] <= user_wr_data[7:0];
            if (user_wr_be[1]) lad_len[15:8] <= user_wr_data[15:8];
            if (user_wr_be[2]) lad_len[23:16] <= user_wr_data[23:16];
            if (user_wr_be[3]) lad_len[31:24] <= user_wr_data[31:24];
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
            user_rd_data[0] <= pcie_read_valid;
            user_rd_data[1] <= pcie_write_valid;
            user_rd_data[2] <= pcie_read_ready;
            user_rd_data[3] <= pcie_write_ready;
            user_rd_data[4] <= lad_run;
            user_rd_data[5] <= lad_busy;
            user_rd_data[6] <= lad_done_latched;
            user_rd_data[31:7] <= 25'd0;
          end

          RegAddrDDRh2cLo: user_rd_data <= pcie_wr_addr_lo;
          RegAddrDDRh2cHi: user_rd_data <= pcie_wr_addr_hi;
          RegLengDDRh2c:   user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, pcie_write_len};

          RegAddrDDRc2hLo: user_rd_data <= pcie_rd_addr_lo;
          RegAddrDDRc2hHi: user_rd_data <= pcie_rd_addr_hi;
          RegLengDDRc2h:   user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, pcie_read_len};

          RegAddrLadRdLo: user_rd_data <= lad_rd_addr_lo;
          RegAddrLadRdHi: user_rd_data <= lad_rd_addr_hi;
          RegAddrLadWrLo: user_rd_data <= lad_wr_addr_lo;
          RegAddrLadWrHi: user_rd_data <= lad_wr_addr_hi;
          RegLengLad: user_rd_data <= lad_len;
          default: user_rd_data <= 32'd0;
        endcase
      end
    end
  end

endmodule
