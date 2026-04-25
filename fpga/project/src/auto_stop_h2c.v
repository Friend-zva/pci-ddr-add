module auto_stop_h2c #(
    parameter integer AXI_LEN_WIDTH = 20
) (
    input clk,
    input rstn,

    input [              6:0] num_desc,
    input [AXI_LEN_WIDTH-1:0] axis_h2c_desc_len,
    input                     en_gen_mode,

    input bvalid,
    input bready,

    input axis_write_data_tvalid,
    input axis_write_data_tready,

    output reg axis_auto_data_tlast,
    output reg h2c_done
);

  reg  [26:0] beat_count;
  reg  [ 6:0] desc_count;

  //? Check
  wire [26:0] target_beats = ({20'd0, num_desc} * {7'd0, axis_h2c_desc_len}) >> 5;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      beat_count <= 0;
      axis_auto_data_tlast <= 0;
    end else begin
      if (num_desc != 0 && !en_gen_mode) begin
        if (axis_write_data_tvalid && axis_write_data_tready) begin
          if (beat_count + 1 == target_beats) begin
            beat_count <= 0;
            axis_auto_data_tlast <= 1'b1;
          end else begin
            beat_count <= beat_count + 1;
            axis_auto_data_tlast <= 0;
          end
        end else begin
          axis_auto_data_tlast <= 0;
        end
      end else begin
        beat_count <= 0;
        axis_auto_data_tlast <= 0;
      end
    end
  end

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      desc_count <= 0;
      h2c_done   <= 0;
    end else begin
      if (num_desc != 0 && !en_gen_mode) begin
        if (bvalid && bready) begin
          if (desc_count + 1 == num_desc) begin
            desc_count <= 0;
            h2c_done   <= 1'b1;
          end else begin
            desc_count <= desc_count + 1;
            h2c_done   <= 0;
          end
        end else begin
          h2c_done <= 0;
        end
      end else begin
        desc_count <= 0;
        h2c_done   <= 0;
      end
    end
  end

endmodule
