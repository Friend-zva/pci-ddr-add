module auto_stop_h2c #(
    parameter integer AXI_LEN_WIDTH = 20
) (
    input clk,
    input rstn,

    input [              6:0] cfg_desc_num,
    input [AXI_LEN_WIDTH-1:0] cfg_desc_len,
    input                     en_gen_mode,

    input resp_fire,
    input data_fire,

    output reg axis_auto_data_tlast,
    output reg done
);

  reg  [26:0] beat_count;
  reg  [ 6:0] desc_count;

  //? Check
  wire [33:0] bytes_total = cfg_desc_num * cfg_desc_len;
  wire [26:0] target_beats = bytes_total >> 5;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      beat_count <= 0;
      axis_auto_data_tlast <= 0;
    end else begin
      if (cfg_desc_num != 0 && !en_gen_mode) begin
        if (data_fire) begin
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
      done <= 0;
    end else begin
      if (cfg_desc_num != 0 && !en_gen_mode) begin
        if (resp_fire) begin
          if (desc_count + 1 == cfg_desc_num) begin
            desc_count <= 0;
            done <= 1'b1;
          end else begin
            desc_count <= desc_count + 1;
            done <= 0;
          end
        end else begin
          done <= 0;
        end
      end else begin
        desc_count <= 0;
        done <= 0;
      end
    end
  end

endmodule
