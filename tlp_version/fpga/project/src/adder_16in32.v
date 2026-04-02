module adder_16in32 #(
  parameter integer CH_NUM = 1
) (
    input  wire [CH_NUM*256-1:0] in_data,
    output wire [CH_NUM*256-1:0] out_data
);

  genvar ch;
  genvar dw;
  generate
    for (ch = 0; ch < CH_NUM; ch = ch + 1) begin : gen_ch_loop
      for (dw = 0; dw < 8; dw = dw + 1) begin : gen_word_loop
        wire [31:0] word_in = in_data[ch*256+dw*32+:32];
        wire [16:0] sum16 = word_in[15:0] + word_in[31:16];
        assign out_data[ch*256+dw*32+:32] = {15'd0, sum16};
      end
    end
  endgenerate

endmodule
