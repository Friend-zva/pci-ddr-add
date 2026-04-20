module gen_h2c #(
    parameter integer DATA_WIDTH = 256,
    parameter integer LEN_WIDTH  = 20
) (
    input                          clk,
    input                          rstn,
    input                          start,
    input       [   LEN_WIDTH-1:0] cfg_len,
    output reg                     busy,
    output reg                     done,
    output reg  [  DATA_WIDTH-1:0] m_axis_tdata,
    output wire [DATA_WIDTH/8-1:0] m_axis_tkeep,
    output reg                     m_axis_tvalid,
    input                          m_axis_tready,
    output wire                    m_axis_tlast
);

  localparam [255:0] START_DATA = 256'h000F_000E_000D_000C_000B_000A_0009_0008_0007_0006_0005_0004_0003_0002_0001_0000;
  localparam [255:0] STEP_DATA  = 256'h0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010_0010;

  assign m_axis_tkeep = {DATA_WIDTH / 8{1'b1}};

  reg [LEN_WIDTH-1:0] counter;

  wire [LEN_WIDTH-1:0] step = 32;
  wire is_last = (counter + step >= cfg_len);
  assign m_axis_tlast = m_axis_tvalid && is_last;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      busy <= 1'b0;
      done <= 1'b0;
      counter <= 0;
      m_axis_tdata <= START_DATA;
      m_axis_tvalid <= 1'b0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        busy <= 1'b1;
        counter <= 0;
        m_axis_tdata <= START_DATA;
        m_axis_tvalid <= (cfg_len > 0);
        if (cfg_len == 0) done <= 1'b1;
      end else if (busy && m_axis_tvalid && m_axis_tready) begin
        if (is_last) begin
          busy <= 1'b0;
          done <= 1'b1;
          m_axis_tvalid <= 1'b0;
        end else begin
          counter <= counter + step;
          m_axis_tdata <= m_axis_tdata + STEP_DATA;
        end
      end
    end
  end

endmodule
