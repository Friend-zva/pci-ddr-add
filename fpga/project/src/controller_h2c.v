module controller_h2c (
    input en_gen_mode,

    input  [255:0] axis_gen_data_tdata,
    input  [ 31:0] axis_gen_data_tkeep,
    input          axis_gen_data_tvalid,
    output         axis_gen_data_tready,
    input          axis_gen_data_tlast,

    input  [255:0] axis_h2c_data_tdata,
    input  [ 31:0] axis_h2c_data_tkeep,
    input          axis_h2c_data_tvalid,
    output         axis_h2c_data_tready,
    input          axis_h2c_data_tlast,

    input axis_auto_data_tlast,

    output [255:0] axis_write_data_tdata,
    output [ 31:0] axis_write_data_tkeep,
    output         axis_write_data_tvalid,
    input          axis_write_data_tready,
    output         axis_write_data_tlast
);

  assign axis_write_data_tdata = en_gen_mode ? axis_gen_data_tdata : axis_h2c_data_tdata;
  assign axis_write_data_tkeep = en_gen_mode ? axis_gen_data_tkeep : axis_h2c_data_tkeep;
  assign axis_write_data_tvalid = en_gen_mode ? axis_gen_data_tvalid : axis_h2c_data_tvalid;
  assign axis_write_data_tlast  = en_gen_mode ? axis_gen_data_tlast : (axis_h2c_data_tlast | axis_auto_data_tlast);

  assign axis_gen_data_tready = en_gen_mode ? axis_write_data_tready : 1'b0;
  assign axis_h2c_data_tready = en_gen_mode ? 1'b0 : axis_write_data_tready;

endmodule
