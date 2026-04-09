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

    output reg [AXIADDRWIDTH-1:0] ddr_h2c_addr,
    output reg [ AXILENWIDTH-1:0] ddr_h2c_len,
    output reg                    ddr_h2c_valid,
    input                         ddr_h2c_ready,

    output reg [AXIADDRWIDTH-1:0] ddr_c2h_addr,
    output reg [ AXILENWIDTH-1:0] ddr_c2h_len,
    output reg                    ddr_c2h_valid,
    input                         ddr_c2h_ready,

    // Config & run control for Logic Adder
    output reg [AXIADDRWIDTH-1:0] lad_read_addr,
    output reg [AXIADDRWIDTH-1:0] lad_write_addr,
    output reg [ AXILENWIDTH-1:0] lad_len,
    output reg                    lad_run,
    input                         lad_busy,
    input                         lad_done
);
  //* All lengths in bytes.

  localparam integer RegCtrl = 8'h00;
  localparam integer RegStatus = 8'h04;
  localparam integer RegAddrDDRh2c = 8'h10;
  localparam integer RegLengDDRh2c = 8'h14;
  localparam integer RegAddrDDRc2h = 8'h20;
  localparam integer RegLengDDRc2h = 8'h24;
  localparam integer RegAddrLadRd = 8'h30;
  localparam integer RegAddrLadWr = 8'h34;
  localparam integer RegLengLad = 8'h38;

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

      ddr_c2h_addr <= {AXIADDRWIDTH{1'b0}};
      ddr_c2h_len <= {AXILENWIDTH{1'b0}};
      ddr_c2h_valid <= 1'b0;

      ddr_h2c_addr <= {AXIADDRWIDTH{1'b0}};
      ddr_h2c_len <= {AXILENWIDTH{1'b0}};
      ddr_h2c_valid <= 1'b0;

      lad_read_addr <= {AXIADDRWIDTH{1'b0}};
      lad_write_addr <= {AXIADDRWIDTH{1'b0}};
      lad_len <= {AXILENWIDTH{1'b0}};
      lad_run <= 1'b0;

      lad_done_latched <= 1'b0;
    end else begin
      user_rd_valid <= 1'b0;

      if (ddr_c2h_valid && ddr_c2h_ready) begin
        ddr_c2h_valid <= 1'b0;
      end
      if (ddr_h2c_valid && ddr_h2c_ready) begin
        ddr_h2c_valid <= 1'b0;
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
              ddr_h2c_valid <= 1'b1;
            end
            if (user_wr_data[1]) begin
              ddr_c2h_valid <= 1'b1;
            end
            if (user_wr_data[2]) begin
              lad_run <= 1'b1;
              lad_done_latched <= 1'b0;
            end
            if (user_wr_data[3]) begin
              lad_run <= 1'b0;
            end
          end

          RegAddrDDRh2c: begin
            ddr_h2c_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegLengDDRh2c: begin
            ddr_h2c_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegAddrDDRc2h: begin
            ddr_c2h_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegLengDDRc2h: begin
            ddr_c2h_len <= user_wr_data[AXILENWIDTH-1:0];
          end

          RegAddrLadRd: begin
            lad_read_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegAddrLadWr: begin
            lad_write_addr <= user_wr_data[AXIADDRWIDTH-1:0];
          end
          RegLengLad: begin
            lad_len <= user_wr_data[AXILENWIDTH-1:0];
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
            user_rd_data[0] <= ddr_c2h_valid;
            user_rd_data[1] <= ddr_h2c_valid;
            user_rd_data[2] <= ddr_c2h_ready;
            user_rd_data[3] <= ddr_h2c_ready;
            user_rd_data[4] <= lad_run;
            user_rd_data[5] <= lad_busy;
            user_rd_data[6] <= lad_done_latched;
            user_rd_data[31:7] <= 25'd0;
          end

          RegAddrDDRh2c: user_rd_data <= {{(32 - AXIADDRWIDTH) {1'b0}}, ddr_h2c_addr};
          RegLengDDRh2c: user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, ddr_h2c_len};

          RegAddrDDRc2h: user_rd_data <= {{(32 - AXIADDRWIDTH) {1'b0}}, ddr_c2h_addr};
          RegLengDDRc2h: user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, ddr_c2h_len};

          RegAddrLadRd: user_rd_data <= {{(32 - AXIADDRWIDTH) {1'b0}}, lad_read_addr};
          RegAddrLadWr: user_rd_data <= {{(32 - AXIADDRWIDTH) {1'b0}}, lad_write_addr};
          RegLengLad:   user_rd_data <= {{(32 - AXILENWIDTH) {1'b0}}, lad_len};

          default: user_rd_data <= 32'd0;
        endcase
      end
    end
  end

endmodule
