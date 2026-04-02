


module user_stream_if_monitor(
    input clk,
    input rstn,
    //h2c
    output reg m_axis_h2c_tready = 0,
    input m_axis_h2c_tvalid,
    input [255:0] m_axis_h2c_tdata,
    input m_axis_h2c_tlast,
    input [31:0]  m_axis_h2c_tuser,
    input [31:0]  m_axis_h2c_tkeep,
    input [63:0]  h2c_overhead,
    //c2h
    input s_axis_c2h_tready,
    output s_axis_c2h_tvalid,
    output reg s_axis_c2h_tlast = 0,
    output [255:0] s_axis_c2h_tdata,
    output reg [31:0] s_axis_c2h_tuser = 0,
    output reg [31:0] s_axis_c2h_tkeep = 0,
    output reg c2h_overhead_valid = 0,
    output reg [63:0] c2h_overhead_data = 64'h01_02_03_04_aa_bb_cc_dd,
    //local bus
    input               local_wren,
    input               local_rden,
    input [15:0]        local_addr,
    input [31:0]        local_wrdata,
    output reg [31:0]   local_rddata,
    output reg          local_rd_vld,
    output reg          local_wr_rdy,

    input h2c_run,
    input c2h_run
    
);


reg h2c_latch_init_data;
reg [255:0] h2c_comp_data = 0;
integer i,j,m,n;
reg h2c_data_error;
reg [31:0] h2c_data_byte_error;
reg h2c_length_error;
reg h2c_clear_test_result;
reg [31:0] h2c_one_packet_byte_cnt;
reg [31:0] h2c_one_packet_byte_cnt_to_uart;
reg h2c_comp_byte_length_flag;

reg [7:0]   h2c_initial_m_axis_h2c_tdata = 0;
reg [31:0]  h2c_packet_length = 0;
localparam address_h2c_initial_m_axis_h2c_tdata = 16'h0100;
localparam address_h2c_packet_length = 16'h0101;
localparam address_m_axis_h2c_tready = 16'h0102;
localparam address_h2c_clear_test_result = 16'h0103;
localparam address_h2c_error = 16'h0104;
localparam address_h2c_one_packet_byte_cnt = 16'h0105;
localparam address_h2c_data_byte_error = 16'h0106;


//----c2h signal define ------
reg [7:0]   c2h_initial_m_axis_c2h_tdata = 0;
reg [31:0]  c2h_byte_length = 0;
reg [31:0]  c2h_byte_length_reg = 0;
reg c2h_clear_test_result = 0;
wire s_axis_c2h_start = c2h_run;
localparam address_c2h_initial_m_axis_c2h_tdata = 16'h0200;
localparam address_c2h_length = 16'h0201;
localparam address_m_axis_c2h_start = 16'h0202;
localparam address_c2h_clear_test_result = 16'h0203;
localparam address_c2h_length_inc_en = 16'h0204;
reg [255:0] c2h_tx_data;
reg c2h_latch_init_data;
localparam S_IDLE = 3'b001;
localparam S_DATA = 3'b010;
localparam S_GAP  = 3'b100;
reg [2:0] c_state = S_IDLE;/*synthesis syn_encoding="onehot"*/
reg [2:0] n_state;
reg c2h_length_inc_en = 0;


function [5:0] accumulation_one;
    input [31:0] din;
    integer i;
    begin
        accumulation_one = 0;
        for(i=0;i<32;i=i+1) begin
            accumulation_one = accumulation_one + din[i];
        end
    end
endfunction
    
//----local bus operation---
always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        local_wr_rdy <= 1'b0;
    end
    else begin
        if (local_wr_rdy) begin
            local_wr_rdy <= 1'b0;
        end
        else if (local_wren) begin
            local_wr_rdy <= 1'b1;
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        local_rd_vld <= 1'b0;
    end
    else begin
        if (local_rd_vld) begin
            local_rd_vld <= 1'b0;
        end
        else if (local_rden) begin
            local_rd_vld <= 1'b1;
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        h2c_initial_m_axis_h2c_tdata <= 0;
        h2c_packet_length <= 0;
        m_axis_h2c_tready <= 0;
        h2c_clear_test_result <= 0;       
        c2h_initial_m_axis_c2h_tdata <= 0;
        c2h_clear_test_result <= 0;
    end
    else begin
        if (local_wren && local_wr_rdy) begin
            case(local_addr)
                address_h2c_packet_length:    
                    h2c_packet_length <= local_wrdata;
                address_m_axis_h2c_tready:              
                    m_axis_h2c_tready <= local_wrdata[0];
                address_h2c_clear_test_result:          
                    h2c_clear_test_result <= local_wrdata[0];               
                address_c2h_initial_m_axis_c2h_tdata:
                    c2h_initial_m_axis_c2h_tdata <= local_wrdata[7:0];
                address_c2h_clear_test_result:
                    c2h_clear_test_result <= local_wrdata[0];
                address_c2h_length_inc_en:
                    c2h_length_inc_en <= local_wrdata[0];
            endcase
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        local_rddata <= 0;
    end
    else begin
        if (local_rden) begin
            local_rddata <= 0;
            case(local_addr)
                address_h2c_packet_length:
                    local_rddata <= h2c_packet_length;
                address_m_axis_h2c_tready:
                    local_rddata[0] <= m_axis_h2c_tready;
                address_h2c_clear_test_result:          
                    local_rddata[0] <= h2c_clear_test_result;  
                address_h2c_error: begin
                    local_rddata[0] <= h2c_data_error;
                    local_rddata[1] <= h2c_length_error;
                end
                address_h2c_one_packet_byte_cnt:
                    local_rddata <= h2c_one_packet_byte_cnt_to_uart;
                address_h2c_data_byte_error:
                    local_rddata <= h2c_data_byte_error;
                    
                address_c2h_initial_m_axis_c2h_tdata:
                    local_rddata <= c2h_initial_m_axis_c2h_tdata;
                address_c2h_clear_test_result:
                    local_rddata[0] <= c2h_clear_test_result;
                address_c2h_length:
                    local_rddata <= c2h_byte_length;
                address_m_axis_c2h_start:
                    local_rddata[0] <= s_axis_c2h_start;
                address_c2h_length_inc_en:
                    local_rddata[0] <= c2h_length_inc_en;     
                default:
                    local_rddata <= 0;
            endcase
        end
    end
end

reg m_axis_h2c_tvalid_d0;

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        h2c_comp_data <= 0;
        m_axis_h2c_tvalid_d0 <= 0;
    end
    else begin
        if (!h2c_run || (m_axis_h2c_tlast && m_axis_h2c_tvalid && m_axis_h2c_tready)) begin
            m_axis_h2c_tvalid_d0 <= 0;
        end
        else if (m_axis_h2c_tready) begin
            m_axis_h2c_tvalid_d0 <= m_axis_h2c_tvalid;
        end


        if (!h2c_run || (m_axis_h2c_tlast && m_axis_h2c_tvalid && m_axis_h2c_tready)) begin
            h2c_comp_data <= 0;
        end
        else if (m_axis_h2c_tready) begin
            if (m_axis_h2c_tvalid && !m_axis_h2c_tvalid_d0) begin
                for(i=0;i<32;i=i+1) begin
                    h2c_comp_data[i*8+:8] <= m_axis_h2c_tdata[i*8+:8] + 32;
                end
            end
            else if (m_axis_h2c_tvalid) begin
                for(i=0;i<32;i=i+1) begin
                    h2c_comp_data[i*8+:8] <= h2c_comp_data[i*8+:8] + 32;
                end
            end
        end
    end
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        h2c_one_packet_byte_cnt <= 0;
        h2c_data_error <= 1'b0;
        h2c_length_error <= 1'b0;
        h2c_comp_byte_length_flag <= 0;
    end
    else begin
        h2c_comp_byte_length_flag <= (m_axis_h2c_tvalid && m_axis_h2c_tready && m_axis_h2c_tlast);
        if (h2c_clear_test_result) begin
            h2c_data_error <= 1'b0;
            h2c_length_error <= 1'b0;
            h2c_one_packet_byte_cnt <= 0;
            h2c_data_byte_error <= 0;
        end
        else begin
            h2c_data_error <= |h2c_data_byte_error;
            if (m_axis_h2c_tvalid && m_axis_h2c_tready && m_axis_h2c_tvalid_d0) begin
                for(j=0;j<32;j=j+1) begin
                    if (m_axis_h2c_tkeep[j]) begin
                        if (h2c_comp_data[j*8+:8] != m_axis_h2c_tdata[j*8+:8]) begin
                            h2c_data_byte_error[j] <= 1'b1;
                        end
                    end
                end
            end
            if (m_axis_h2c_tvalid && m_axis_h2c_tready) begin
                if (!m_axis_h2c_tlast) begin
                    h2c_one_packet_byte_cnt <= h2c_one_packet_byte_cnt + 32;
                end
                else begin
                    h2c_one_packet_byte_cnt <= h2c_one_packet_byte_cnt + accumulation_one(m_axis_h2c_tkeep[1*32-1:0]);
                end
            end
            if (h2c_comp_byte_length_flag) begin
                h2c_one_packet_byte_cnt <= 0;
                h2c_one_packet_byte_cnt_to_uart <= h2c_one_packet_byte_cnt;
                if (h2c_one_packet_byte_cnt != h2c_packet_length) begin
                    h2c_length_error <= 1'b1;
                end
            end
        end
    end
end

//----c2h generate----
reg [31:0] c2h_32byte_cnt = 0;
wire [26:0] c2h_32byte_length;
wire [5:0] c2h_last_add;

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        c2h_tx_data <= 0;
        c2h_latch_init_data <= 0;
    end
    else begin    
        c2h_latch_init_data <= local_wren && local_wr_rdy && local_addr == address_c2h_initial_m_axis_c2h_tdata;
        if (c_state == S_IDLE || c2h_latch_init_data) begin
            for(m=0;m<32;m=m+1) begin
                c2h_tx_data[m*8+:8] <= c2h_initial_m_axis_c2h_tdata + m;
            end
        end
        else if (s_axis_c2h_tvalid && s_axis_c2h_tready) begin
            if (s_axis_c2h_tlast) begin
                for(n=0;n<32;n=n+1) begin
                    c2h_tx_data[n*8+:8] <= c2h_tx_data[n*8+:8] + c2h_last_add;
                end
            end
            else begin
                for(n=0;n<32;n=n+1) begin
                    c2h_tx_data[n*8+:8] <= c2h_tx_data[n*8+:8] + 32;
                end
            end
        end
    end
end

assign c2h_32byte_length = c2h_byte_length[31:5]+|c2h_byte_length[4:0];
assign c2h_last_add = (c2h_byte_length[4:0] == 0) ? 32 : c2h_byte_length[4:0];

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        c2h_32byte_cnt <= 0;
    end
    else begin
        if (c_state == S_IDLE || c_state == S_GAP) begin
            c2h_32byte_cnt <= 0;
        end
        else begin
            if (s_axis_c2h_tvalid && s_axis_c2h_tready) begin
                c2h_32byte_cnt <= c2h_32byte_cnt + 1;
            end
        end
    end
end



always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        c_state <= S_IDLE;
    end
    else begin
        c_state <= n_state;
    end
end


always@(*) begin
    n_state = c_state;
    case(c_state)
        S_IDLE:
            if (s_axis_c2h_start) begin
                n_state = S_DATA;
            end
        S_DATA:
            if (!s_axis_c2h_start) begin
                n_state = S_IDLE;
            end
            else if (s_axis_c2h_tvalid && s_axis_c2h_tready && s_axis_c2h_tlast) begin
                n_state = S_GAP;
            end
        S_GAP:
            if (s_axis_c2h_start) begin
                n_state = S_DATA;
            end
            else begin
                n_state = S_IDLE;
            end
        default:
            n_state = S_IDLE;
    endcase
end

assign s_axis_c2h_tvalid = c_state == S_DATA;

always@(posedge clk) begin
    c2h_overhead_valid <= (c_state == S_IDLE || c_state == S_GAP) && n_state == S_DATA;
    if (c2h_overhead_valid) begin
        c2h_overhead_data <= c2h_overhead_data + 1;
    end
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        s_axis_c2h_tlast <= 0;
    end
    else begin
        if ((c_state == S_IDLE || c_state == S_GAP) && n_state == S_DATA) begin
            if (c2h_32byte_length == 1) begin
                s_axis_c2h_tlast <= 1'b1;
            end
        end
        else if (s_axis_c2h_tvalid && s_axis_c2h_tready) begin
            if (s_axis_c2h_tlast) begin
                s_axis_c2h_tlast <= 1'b0;
            end
            else if (c_state == S_DATA && c2h_32byte_cnt+2 == c2h_32byte_length) begin
                s_axis_c2h_tlast <= 1'b1;
            end
        end
        
        if ((c_state == S_IDLE || c_state == S_GAP) && n_state == S_DATA) begin 
            if (c2h_32byte_length == 1) begin
                if (c2h_byte_length[4:0] == 0) begin 
                    s_axis_c2h_tkeep <= 32'hffff_ffff;
                end
                else begin
                    s_axis_c2h_tkeep <= 32'hffff_ffff >> (32-c2h_byte_length[4:0]);
                end
            end
            else begin
                s_axis_c2h_tkeep <= 32'hffff_ffff;
            end
        end
        else if (c_state == S_DATA && s_axis_c2h_tvalid && s_axis_c2h_tready) begin
            if (s_axis_c2h_tlast) begin
                s_axis_c2h_tkeep <= 0;
            end
            else if (c2h_32byte_cnt+2 == c2h_32byte_length) begin
                if (c2h_byte_length[4:0] == 0) begin 
                    s_axis_c2h_tkeep <= 32'hffff_ffff;
                end
                else begin
                    s_axis_c2h_tkeep <= 32'hffff_ffff >> (32-c2h_byte_length[4:0]);
                end
            end
            else begin
                s_axis_c2h_tkeep <= 32'hffff_ffff;
            end
        end
    end
end


always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        c2h_byte_length_reg <= 0; 
        c2h_byte_length <= 0;
    end
    else begin
        if (local_wren && local_wr_rdy && local_addr == address_c2h_length) begin
            c2h_byte_length_reg <= local_wrdata;
            c2h_byte_length <= local_wrdata;
        end
        else if (!c2h_run) begin
            c2h_byte_length <= c2h_byte_length_reg;
        end
        else if (c2h_length_inc_en && s_axis_c2h_tlast && s_axis_c2h_tvalid && s_axis_c2h_tready) begin
            c2h_byte_length <= c2h_byte_length + 1;
        end
    end
end
        

assign s_axis_c2h_tdata = c2h_tx_data;


endmodule
