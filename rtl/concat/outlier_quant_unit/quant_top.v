// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

module quant_top
#(
    parameter BEFORE_PREC = 16,
    parameter MAX_GROUP_WIDTH = 128,
    parameter LOOP_NUM = 4,
    parameter A_XFERS = 2,
    parameter W_XFERS = 4
)
(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         isa_valid,
    input  wire         proj_done,

    input  wire         in_vld,
    input  wire         indicate_kv,
    input  wire [2:0]   quant_precision,
    input  wire [1:0]   group_size,
    input  wire [6:0]   outlier_num,
    input  wire [BEFORE_PREC*MAX_GROUP_WIDTH-1:0] d_in,

    input wire          comb_sram_wen,
    input wire [101:0]  comb_sram_wdata,

    output wire                                     out_vld,
    output wire [$clog2(W_XFERS)-1:0]               out_bundle_idx,
    output wire [BEFORE_PREC*MAX_GROUP_WIDTH-1:0]   d_out,
    output wire                                     out_is_code,

    output wire prefill_start_write,
    output wire decode_start_write,
    output wire fp_scale_zp_start_write,
    output wire int_scale_zp_start_write,
    output wire outlier_pos_start_write,
    output wire outlier_val_start_write,
    output wire [1:0] outlier_val_burst_length,
    output wire [$clog2(W_XFERS)-1:0] outlier_pos_emit_bundle,
    output wire [$clog2(W_XFERS)-1:0] outlier_val_emit_bundle
);

    genvar i;
    integer idx;

    localparam MIN_GROUP_WIDTH = 32;
    localparam ROW_WIDTH = MAX_GROUP_WIDTH * BEFORE_PREC;
    localparam MIN_ROW_WIDTH = MIN_GROUP_WIDTH * BEFORE_PREC;

    localparam BUNDLE_LOOP_NUM = 4/A_XFERS;

    wire comp_tree_out_vld;
    wire [4*BEFORE_PREC-1:0] max_out_wire;
    wire [4*BEFORE_PREC-1:0] min_out_wire;
    wire [4*BEFORE_PREC-1:0] mean_out_wire;

    wire outlier_tree_out_vld;
    wire [BEFORE_PREC*MAX_GROUP_WIDTH-1:0] outlier_tree_val;
    wire [MAX_GROUP_WIDTH-1:0] outlier_tree_pos;
    wire [4*BEFORE_PREC-1:0] outlier_excluded_max;
    wire [4*BEFORE_PREC-1:0] outlier_excluded_min;

    wire scale_zerop_out_vld;
    wire [4*BEFORE_PREC-1:0] scale_fp_prec2_out_wire;
    wire [4*BEFORE_PREC-1:0] scale_fp_prec4_out_wire;
    wire [4*BEFORE_PREC-1:0] scale_fp_prec8_out_wire;
    wire [4*BEFORE_PREC-1:0] scale_int_prec2_out_wire;
    wire [4*BEFORE_PREC-1:0] scale_int_prec4_out_wire;
    wire [4*BEFORE_PREC-1:0] scale_int_prec8_out_wire;
    wire [4*BEFORE_PREC-1:0] zerop_fp_out_wire;
    wire [4*BEFORE_PREC-1:0] zerop_int_out_wire;
    wire [BEFORE_PREC*MAX_GROUP_WIDTH-1:0] outlier_val_out;
    wire [MAX_GROUP_WIDTH-1:0] outlier_pos_out;

    wire [3:0] norm_out_vld;
    wire [BEFORE_PREC-1:0] norm_scale_fp_out_wire [0:3];
    wire [BEFORE_PREC-1:0] norm_scale_int_out_wire [0:3];
    wire [BEFORE_PREC-1:0] norm_zerop_fp_out_wire [0:3];
    wire [BEFORE_PREC-1:0] norm_zerop_int_out_wire [0:3];
    wire [(MIN_GROUP_WIDTH<<3)-1:0] norm_d_out_fp [0:3];
    wire [(MIN_GROUP_WIDTH<<2)-1:0] norm_d_out_int [0:3];
    wire [MIN_GROUP_WIDTH*5-1:0] outlier_mask_out [0:3];

    reg [6:0] norm_out_vld_cnt;
    reg [6:0] norm_out_a_cnt;
    reg [6:0] norm_out_w_cnt;
    reg [6:0] norm_out_loop_cnt;

    wire [6:0] norm_out_a_xfers_eff     = (group_size == 2'b01 && A_XFERS > 2) ? 7'd2 : A_XFERS[6:0];
    wire [6:0] norm_out_bundle_loop_eff = (group_size == 2'b01 && A_XFERS > 2) ? 7'd2 : BUNDLE_LOOP_NUM[6:0];

    reg [BEFORE_PREC*MAX_GROUP_WIDTH-1:0] d_in_reg, d_in_reg_1st, d_in_reg_2nd, d_in_reg_3rd;

    reg transposer_out_in_vld;
    reg [4:0] transposer_out_din_cnt;
    reg [1023:0] transposer_out_fp_din;
    reg [511:0] transposer_out_int_din;
    reg [639:0] transposer_out_outlier_din;
    wire transposer_out_dout_vld;
    wire [ROW_WIDTH-1:0] transposer_out_dout;
    wire [1:0] transposer_out_dout_kind;
    wire [128*5-1:0] transposer_out_outlier_dout;
    wire transposer_out_outlier_dout_vld;

    reg outlier_compressor_in_vld;
    reg [128*5-1:0] outlier_compressor_in_data;
    reg outlier_compressor_in_pos_or_val;
    wire outlier_compressor_out_vld;
    wire [ROW_WIDTH-1:0] outlier_compressor_out_data;

    reg [8191:0] fp_scale_reg [0:W_XFERS-1];
    reg [8191:0] int_scale_reg [0:W_XFERS-1];
    reg [16383:0] fp_zp_reg [0:W_XFERS-1];
    reg [16383:0] int_zp_reg [0:W_XFERS-1];

    reg [7:0] scale_zp_tile_cnt;
    reg [9:0] scale_zp_row_offset [0:W_XFERS-1];

    reg [2:0] scale_zp_emit_state;
    reg [3:0] scale_zp_emit_cnt;
    reg [3:0] scale_zp_emit_loop_cnt;
    reg [3:0] scale_zp_delay_cnt;
    reg [ROW_WIDTH-1:0] scale_zp_dout_reg;
    reg scale_zp_dout_vld;

    reg fp_scale_zp_start_write_reg;
    reg int_scale_zp_start_write_reg;
    assign fp_scale_zp_start_write = fp_scale_zp_start_write_reg;
    assign int_scale_zp_start_write = int_scale_zp_start_write_reg;

    wire decode_write_done;
    wire prefill_write_done;

    reg decode_write_done_pip1, decode_write_done_pip2, decode_write_done_pip3, decode_write_done_pip4;

    reg proj_done_latch;
    reg outlier_compressor_proj_done;
    reg scale_zp_emit_done;

    reg [3:0] scale_zp_emit_done_delay;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_in_reg     <= {(BEFORE_PREC*MAX_GROUP_WIDTH){1'b0}};
            d_in_reg_1st <= {(BEFORE_PREC*MAX_GROUP_WIDTH){1'b0}};
            d_in_reg_2nd <= {(BEFORE_PREC*MAX_GROUP_WIDTH){1'b0}};
            d_in_reg_3rd <= {(BEFORE_PREC*MAX_GROUP_WIDTH){1'b0}};
            transposer_out_in_vld <= 1'b0;
            transposer_out_din_cnt <= 5'd0;
            transposer_out_fp_din <= {1024{1'b0}};
            transposer_out_int_din <= {512{1'b0}};
            transposer_out_outlier_din <= {640{1'b0}};
            outlier_compressor_in_vld <= 1'b0;
            outlier_compressor_in_data <= {128*5{1'b0}};
            outlier_compressor_in_pos_or_val <= 1'b0;
            norm_out_vld_cnt <= 7'd0;
            norm_out_a_cnt <= 7'd0;
            norm_out_w_cnt <= 7'd0;
            norm_out_loop_cnt <= 7'd0;

            for(idx=0; idx<W_XFERS; idx=idx+1) begin
                fp_scale_reg[idx] <= 8192'd0;
                int_scale_reg[idx] <= 8192'd0;
                fp_zp_reg[idx] <= 16384'd0;
                int_zp_reg[idx] <= 16384'd0;
            end
            scale_zp_tile_cnt <= 8'd0;
            for(idx=0; idx<W_XFERS; idx=idx+1) begin
                scale_zp_row_offset[idx] <= 10'd0;
            end

            scale_zp_emit_state <= 3'd0;
            scale_zp_emit_cnt <= 4'd0;
            scale_zp_emit_loop_cnt <= 4'd0;
            scale_zp_delay_cnt <= 4'd0;
            scale_zp_dout_reg <= {ROW_WIDTH{1'b0}};
            scale_zp_dout_vld <= 1'b0;
            fp_scale_zp_start_write_reg <= 1'b0;
            int_scale_zp_start_write_reg <= 1'b0;
            proj_done_latch <= 1'b0;
            outlier_compressor_proj_done <= 1'b0;
            scale_zp_emit_done <= 1'b0;
            scale_zp_emit_done_delay <= 4'b0;

            decode_write_done_pip1 <= 1'b0;
            decode_write_done_pip2 <= 1'b0;
            decode_write_done_pip3 <= 1'b0;
            decode_write_done_pip4 <= 1'b0;

        end else begin
            transposer_out_in_vld <= &norm_out_vld;
            outlier_compressor_in_vld <= (&norm_out_vld && !indicate_kv) || transposer_out_outlier_dout_vld;
            scale_zp_dout_vld <= 1'b0;
            scale_zp_emit_done <= 1'b0;

            decode_write_done_pip1 <= decode_write_done;
            decode_write_done_pip2 <= decode_write_done_pip1;
            decode_write_done_pip3 <= decode_write_done_pip2;
            decode_write_done_pip4 <= decode_write_done_pip3;

            scale_zp_emit_done_delay <= {scale_zp_emit_done_delay[2:0], 1'b0};
            if(scale_zp_emit_done_delay[3])
                scale_zp_emit_done <= 1'b1;

            d_in_reg_1st <= d_in_reg;
            if(in_vld) begin
                d_in_reg <= d_in;
            end
            if(&comp_tree_out_vld) begin
                d_in_reg_2nd <= d_in_reg_1st;
            end
            if(&scale_zerop_out_vld) begin
                d_in_reg_3rd <= d_in_reg_2nd;
            end

            if(&norm_out_vld) begin
                norm_out_vld_cnt <= norm_out_vld_cnt + 7'd1;
                if(norm_out_vld_cnt == 7'd127) begin
                    norm_out_vld_cnt <= 7'd0;
                    norm_out_a_cnt <= norm_out_a_cnt + 7'd1;
                    scale_zp_row_offset[norm_out_w_cnt] <= scale_zp_row_offset[norm_out_w_cnt] + 10'd128;
                    if(norm_out_a_cnt == norm_out_a_xfers_eff - 7'd1) begin
                        norm_out_a_cnt <= 7'd0;
                        norm_out_w_cnt <= norm_out_w_cnt + 7'd1;
                        if(norm_out_w_cnt == W_XFERS-1) begin
                            norm_out_w_cnt <= 7'd0;
                            norm_out_loop_cnt <= norm_out_loop_cnt + 7'd1;
                            if(norm_out_loop_cnt == norm_out_bundle_loop_eff - 7'd1) begin
                                norm_out_loop_cnt <= 7'd0;
                            end
                        end
                    end
                end

                if(group_size == 2'b01) begin
                    for(idx=0; idx<4; idx=idx+1) begin
                        fp_scale_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*32 + idx*1024 + norm_out_vld_cnt*8 +: 8] <= norm_scale_fp_out_wire[idx][7:0];
                        int_scale_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*32 + idx*1024 + norm_out_vld_cnt*8 +: 8] <= norm_scale_int_out_wire[idx][7:0];
                        fp_zp_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*64 + idx*2048 + norm_out_vld_cnt*16 +: 16] <= norm_zerop_fp_out_wire[idx][15:0];
                        int_zp_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*64 + idx*2048 + norm_out_vld_cnt*16 +: 16] <= norm_zerop_int_out_wire[idx][15:0];
                    end
                end else if(group_size == 2'b10) begin
                    for(idx=0; idx<2; idx=idx+1) begin
                        fp_scale_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*16 + idx*1024 + norm_out_vld_cnt*8 +: 8] <= norm_scale_fp_out_wire[idx*2][7:0];
                        int_scale_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*16 + idx*1024 + norm_out_vld_cnt*8 +: 8] <= norm_scale_int_out_wire[idx*2][7:0];
                        fp_zp_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*32 + idx*2048 + norm_out_vld_cnt*16 +: 16] <= norm_zerop_fp_out_wire[idx*2][15:0];
                        int_zp_reg[norm_out_w_cnt][scale_zp_row_offset[norm_out_w_cnt]*32 + idx*2048 + norm_out_vld_cnt*16 +: 16] <= norm_zerop_int_out_wire[idx*2][15:0];
                    end
                end else if(group_size == 2'b11) begin
                    fp_scale_reg[norm_out_w_cnt][(scale_zp_row_offset[norm_out_w_cnt] + norm_out_vld_cnt)*8 +: 8] <= norm_scale_fp_out_wire[0][7:0];
                    int_scale_reg[norm_out_w_cnt][(scale_zp_row_offset[norm_out_w_cnt] + norm_out_vld_cnt)*8 +: 8] <= norm_scale_int_out_wire[0][7:0];
                    fp_zp_reg[norm_out_w_cnt][(scale_zp_row_offset[norm_out_w_cnt] + norm_out_vld_cnt)*16 +: 16] <= norm_zerop_fp_out_wire[0][15:0];
                    int_zp_reg[norm_out_w_cnt][(scale_zp_row_offset[norm_out_w_cnt] + norm_out_vld_cnt)*16 +: 16] <= norm_zerop_int_out_wire[0][15:0];
                end

                outlier_compressor_in_data <= {{outlier_mask_out[3][MIN_GROUP_WIDTH*5-1:0]}, {outlier_mask_out[2][MIN_GROUP_WIDTH*5-1:0]},
                                              {outlier_mask_out[1][MIN_GROUP_WIDTH*5-1:0]}, {outlier_mask_out[0][MIN_GROUP_WIDTH*5-1:0]}};
                outlier_compressor_in_pos_or_val <= 1'b0;

                transposer_out_outlier_din <= {{outlier_mask_out[3][MIN_GROUP_WIDTH*5-1:0]}, {outlier_mask_out[2][MIN_GROUP_WIDTH*5-1:0]},
                                              {outlier_mask_out[1][MIN_GROUP_WIDTH*5-1:0]}, {outlier_mask_out[0][MIN_GROUP_WIDTH*5-1:0]}};

                if(quant_precision == 3'b010) begin
                    transposer_out_fp_din <= 0;
                    transposer_out_int_din[511:256] <= 0;
                    for(idx=0; idx<32; idx=idx+1) begin
                        transposer_out_int_din[     idx*2 +: 2] <= norm_d_out_int[0][idx*4 +:2];
                        transposer_out_int_din[64 + idx*2 +: 2] <= norm_d_out_int[1][idx*4 +:2];
                        transposer_out_int_din[128 + idx*2 +: 2] <= norm_d_out_int[2][idx*4 +:2];
                        transposer_out_int_din[192 + idx*2 +: 2] <= norm_d_out_int[3][idx*4 +:2];
                    end
                end else if(quant_precision == 3'b011) begin
                    transposer_out_fp_din[1023:512] <= 0;
                    transposer_out_int_din[511:256] <= 0;
                    for(idx=0; idx<32; idx=idx+1) begin
                        transposer_out_fp_din[      idx*4 +: 4] <= norm_d_out_fp[0][idx*8 +:4];
                        transposer_out_fp_din[128 + idx*4 +: 4] <= norm_d_out_fp[1][idx*8 +:4];
                        transposer_out_fp_din[256 + idx*4 +: 4] <= norm_d_out_fp[2][idx*8 +:4];
                        transposer_out_fp_din[384 + idx*4 +: 4] <= norm_d_out_fp[3][idx*8 +:4];
                        transposer_out_int_din[     idx*2 +: 2] <= norm_d_out_int[0][idx*4 +:2];
                        transposer_out_int_din[64 + idx*2 +: 2] <= norm_d_out_int[1][idx*4 +:2];
                        transposer_out_int_din[128 + idx*2 +: 2] <= norm_d_out_int[2][idx*4 +:2];
                        transposer_out_int_din[192 + idx*2 +: 2] <= norm_d_out_int[3][idx*4 +:2];
                    end
                end else if(quant_precision == 3'b100) begin
                    transposer_out_fp_din <= 0;
                    transposer_out_int_din <= {norm_d_out_int[3][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[2][(MIN_GROUP_WIDTH<<2)-1:0],
                                              norm_d_out_int[1][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[0][(MIN_GROUP_WIDTH<<2)-1:0]};
                end else if(quant_precision == 3'b101) begin
                    transposer_out_fp_din <= {norm_d_out_fp[3][(MIN_GROUP_WIDTH<<3)-1:0], norm_d_out_fp[2][(MIN_GROUP_WIDTH<<3)-1:0],
                                             norm_d_out_fp[1][(MIN_GROUP_WIDTH<<3)-1:0], norm_d_out_fp[0][(MIN_GROUP_WIDTH<<3)-1:0]};
                    transposer_out_int_din <= {norm_d_out_int[3][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[2][(MIN_GROUP_WIDTH<<2)-1:0],
                                             norm_d_out_int[1][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[0][(MIN_GROUP_WIDTH<<2)-1:0]};
                end else if(quant_precision == 3'b110) begin
                    transposer_out_int_din[511:256] <= 0;
                    transposer_out_fp_din <= {norm_d_out_fp[3][(MIN_GROUP_WIDTH<<3)-1:0], norm_d_out_fp[2][(MIN_GROUP_WIDTH<<3)-1:0],
                                             norm_d_out_fp[1][(MIN_GROUP_WIDTH<<3)-1:0], norm_d_out_fp[0][(MIN_GROUP_WIDTH<<3)-1:0]};
                    for(idx=0; idx<32; idx=idx+1) begin
                        transposer_out_int_din[     idx*2 +: 2] <= norm_d_out_int[0][idx*4 +:2];
                        transposer_out_int_din[64 + idx*2 +: 2] <= norm_d_out_int[1][idx*4 +:2];
                        transposer_out_int_din[128 + idx*2 +: 2] <= norm_d_out_int[2][idx*4 +:2];
                        transposer_out_int_din[192 + idx*2 +: 2] <= norm_d_out_int[3][idx*4 +:2];
                    end
                end else if(quant_precision == 3'b111) begin
                    transposer_out_fp_din[1023:512] <= 0;
                    for(idx=0; idx<32; idx=idx+1) begin
                        transposer_out_fp_din[      idx*4 +: 4] <= norm_d_out_fp[0][idx*8 +:4];
                        transposer_out_fp_din[128 + idx*4 +: 4] <= norm_d_out_fp[1][idx*8 +:4];
                        transposer_out_fp_din[256 + idx*4 +: 4] <= norm_d_out_fp[2][idx*8 +:4];
                        transposer_out_fp_din[384 + idx*4 +: 4] <= norm_d_out_fp[3][idx*8 +:4];
                    end
                    transposer_out_int_din <= {norm_d_out_int[3][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[2][(MIN_GROUP_WIDTH<<2)-1:0],
                                             norm_d_out_int[1][(MIN_GROUP_WIDTH<<2)-1:0], norm_d_out_int[0][(MIN_GROUP_WIDTH<<2)-1:0]};
                end
            end

            if(transposer_out_outlier_dout_vld) begin
                outlier_compressor_in_data <= transposer_out_outlier_dout;
                outlier_compressor_in_pos_or_val <= 1'b1;
            end

            fp_scale_zp_start_write_reg <= 1'b0;
            int_scale_zp_start_write_reg <= 1'b0;
            outlier_compressor_proj_done <= 1'b0;

            if(decode_write_done_pip4) begin
                scale_zp_tile_cnt <= scale_zp_tile_cnt + 8'd1;
                if(((A_XFERS == 1) || (scale_zp_tile_cnt[0] == 1'b1)) &&
                   ((group_size == 2'b01 && scale_zp_tile_cnt != W_XFERS*2-1) ||
                    (group_size == 2'b10 && scale_zp_tile_cnt != W_XFERS*4-1) ||
                    (group_size == 2'b11 && scale_zp_tile_cnt != W_XFERS*4-1))) begin
                    scale_zp_emit_done_delay[0] <= 1'b1;
                end
            end
            if(proj_done) begin
                proj_done_latch <= 1'b1;
            end

            case(scale_zp_emit_state)
                3'd0: begin
                    if((group_size == 2'b01 && scale_zp_tile_cnt == W_XFERS*2) ||
                    (group_size == 2'b10 && scale_zp_tile_cnt == W_XFERS*4) ||
                    (group_size == 2'b11 && scale_zp_tile_cnt == W_XFERS*4) || proj_done_latch) begin
                        for(idx=0; idx<W_XFERS; idx=idx+1) begin
                            scale_zp_row_offset[idx] <= 10'd0;
                        end
                        if(proj_done_latch && scale_zp_tile_cnt == 4'd0) begin
                            proj_done_latch <= 1'b0;
                            outlier_compressor_proj_done <= !indicate_kv;
                            for(idx=0; idx<W_XFERS; idx=idx+1) begin
                                fp_scale_reg[idx] <= 8192'd0;
                                int_scale_reg[idx] <= 8192'd0;
                                fp_zp_reg[idx] <= 16384'd0;
                                int_zp_reg[idx] <= 16384'd0;
                            end
                        end else begin
                            scale_zp_tile_cnt <= 4'd0;
                            scale_zp_emit_cnt <= 4'd0;
                            scale_zp_emit_loop_cnt <= 4'd0;
                            if(quant_precision == 3'b011 || quant_precision == 3'b101 || quant_precision == 3'b110 || quant_precision == 3'b111) begin
                                scale_zp_emit_state <= 3'd1;
                            end else if(quant_precision == 3'b010 || quant_precision == 3'b100) begin
                                scale_zp_emit_state <= 3'd4;
                            end
                        end
                    end
                end
                3'd1: begin
                    fp_scale_zp_start_write_reg <= 1'b1;
                    scale_zp_emit_state <= 3'd2;
                end
                3'd2: begin
                    scale_zp_dout_vld <= 1'b1;
                    scale_zp_dout_reg <= fp_scale_reg[scale_zp_emit_loop_cnt][scale_zp_emit_cnt*ROW_WIDTH +: ROW_WIDTH];
                    scale_zp_emit_cnt <= scale_zp_emit_cnt + 4'd1;
                    if(scale_zp_emit_cnt == 4'd3) begin
                        scale_zp_emit_state <= 3'd3;
                        scale_zp_emit_cnt <= 4'd0;
                    end
                end
                3'd3: begin
                    scale_zp_dout_vld <= group_size == 2'b11 ? (scale_zp_emit_cnt <= 4'd3) : (scale_zp_emit_cnt <= 4'd7);
                    scale_zp_dout_reg <= fp_zp_reg[scale_zp_emit_loop_cnt][scale_zp_emit_cnt*ROW_WIDTH +: ROW_WIDTH];
                    scale_zp_emit_cnt <= scale_zp_emit_cnt + 4'd1;
                    if(scale_zp_emit_cnt == 4'd7) begin
                        scale_zp_emit_cnt <= 4'd0;
                        scale_zp_emit_loop_cnt <= scale_zp_emit_loop_cnt + 4'd1;
                        if(scale_zp_emit_loop_cnt == W_XFERS-1) begin
                            scale_zp_emit_loop_cnt <= 4'd0;
                            scale_zp_emit_state <= 3'd4;
                        end else begin
                            scale_zp_emit_state <= 3'd1;
                        end
                    end
                end
                3'd4: begin
                    int_scale_zp_start_write_reg <= 1'b1;
                    scale_zp_emit_state <= 3'd5;
                end
                3'd5: begin
                    scale_zp_dout_vld <= 1'b1;
                    scale_zp_dout_reg <= int_scale_reg[scale_zp_emit_loop_cnt][scale_zp_emit_cnt*ROW_WIDTH +: ROW_WIDTH];
                    scale_zp_emit_cnt <= scale_zp_emit_cnt + 4'd1;
                    if(scale_zp_emit_cnt == 4'd3) begin
                        scale_zp_emit_state <= 3'd6;
                        scale_zp_emit_cnt <= 4'd0;
                    end
                end
                3'd6: begin
                    scale_zp_dout_vld <= group_size == 2'b11 ? (scale_zp_emit_cnt <= 4'd3) : 1'b1;
                    scale_zp_dout_reg <= int_zp_reg[scale_zp_emit_loop_cnt][scale_zp_emit_cnt*ROW_WIDTH +: ROW_WIDTH];
                    scale_zp_emit_cnt <= scale_zp_emit_cnt + 4'd1;

                    if(scale_zp_emit_cnt == 4'd7) begin
                        scale_zp_emit_cnt <= 4'd0;
                        scale_zp_emit_loop_cnt <= scale_zp_emit_loop_cnt + 4'd1;
                        if(scale_zp_emit_loop_cnt == W_XFERS-1) begin
                            scale_zp_emit_loop_cnt <= 4'd0;
                            scale_zp_emit_done_delay[0] <= 1'b1;
                            scale_zp_emit_state <= 3'd0;
                            for(idx=0; idx<W_XFERS; idx=idx+1) begin
                                fp_scale_reg[idx] <= 8192'd0;
                                int_scale_reg[idx] <= 8192'd0;
                                fp_zp_reg[idx] <= 16384'd0;
                                int_zp_reg[idx] <= 16384'd0;
                            end
                            if(proj_done_latch) begin
                                proj_done_latch <= 1'b0;
                                outlier_compressor_proj_done <= !indicate_kv;
                                scale_zp_emit_done_delay[0] <= 1'b0;
                            end
                        end else begin
                            scale_zp_emit_state <= 3'd4;
                        end
                    end
                end
                default: scale_zp_emit_state <= 3'd0;
            endcase
        end
    end

    assign out_vld = scale_zp_dout_vld ||
                     (transposer_out_dout_vld && (transposer_out_dout_kind == 2'b01 || transposer_out_dout_kind == 2'b10)) ||
                     outlier_compressor_out_vld;
    assign d_out = scale_zp_dout_vld ? scale_zp_dout_reg :
                   (transposer_out_dout_vld && (transposer_out_dout_kind == 2'b01 || transposer_out_dout_kind == 2'b10)) ? transposer_out_dout :
                   outlier_compressor_out_vld ? outlier_compressor_out_data :
                   {(BEFORE_PREC*MAX_GROUP_WIDTH){1'b0}};
    assign out_is_code = !scale_zp_dout_vld &&
                         transposer_out_dout_vld &&
                         (transposer_out_dout_kind == 2'b10);

    assign out_bundle_idx = scale_zp_dout_vld ? scale_zp_emit_loop_cnt[$clog2(W_XFERS)-1:0]
                                              : {$clog2(W_XFERS){1'b0}};

`ifdef KVPROBE
    // synopsys translate_off
    integer qt_dense_cnt, qt_scale_cnt, qt_ocomp_cnt;
    initial begin qt_dense_cnt=0; qt_scale_cnt=0; qt_ocomp_cnt=0; end
    always @(posedge clk) begin
        if (rst_n && out_vld) begin
            if (transposer_out_dout_vld && (transposer_out_dout_kind==2'b10)) qt_dense_cnt <= qt_dense_cnt+1;
            if (scale_zp_dout_vld)          qt_scale_cnt <= qt_scale_cnt+1;
            if (outlier_compressor_out_vld) qt_ocomp_cnt <= qt_ocomp_cnt+1;
        end
    end
    final $display("[QTOP-KVPROBE] indicate_kv=%b dense(kind10)=%0d scale=%0d ocomp=%0d",
                   indicate_kv, qt_dense_cnt, qt_scale_cnt, qt_ocomp_cnt);
    reg [15:0] qg_cnt;  reg [15:0] qs_cnt;  reg [15:0] qo_cnt;
    initial begin qg_cnt = 0; qs_cnt = 0; qo_cnt = 0; end
    always @(posedge clk) begin
        if (rst_n && in_vld) qg_cnt <= qg_cnt + 16'd1;
        if (rst_n && in_vld && qg_cnt < 16'd2048) begin
            $display("[QGRP] t=%0t n=%0d kv=%b qp=%0d gs=%0d d_in=%h", $time, qg_cnt, indicate_kv, quant_precision, group_size, d_in);
        end
        if (rst_n && out_vld && out_is_code && qo_cnt < 16'd160) begin
            qo_cnt <= qo_cnt + 16'd1;
            $display("[QOUT] t=%0t n=%0d bundle=%0d kv=%b d_out=%h", $time, qo_cnt, out_bundle_idx, indicate_kv, d_out);
        end
        if (rst_n && comp_tree_out_vld && qs_cnt < 16'd2048) begin
            qs_cnt <= qs_cnt + 16'd1;
            $display("[QSTAT] t=%0t n=%0d kv=%b max=%h min=%h oemax=%h oemin=%h", $time, qs_cnt, indicate_kv, max_out_wire, min_out_wire, outlier_excluded_max, outlier_excluded_min);
        end
    end
    // synopsys translate_on
`endif

    comparator_tree #(
        .PRECISION(BEFORE_PREC),
        .MAX_GROUP_WIDTH(128)
    ) u_comparator_tree (
        .clk(clk),
        .rst_n(rst_n),
        .group_size(group_size),
        .in_vld(in_vld),
        .d_in(d_in),
        .out_vld(comp_tree_out_vld),
        .max_out(max_out_wire),
        .min_out(min_out_wire),
        .mean_out(mean_out_wire)
    );

    outlier_tree #(
        .PRECISION(BEFORE_PREC),
        .DATA_NUM(MAX_GROUP_WIDTH),
        .LOOP_NUM(LOOP_NUM)
    ) u_outlier_tree (
        .clk(clk),
        .rst_n(rst_n),
        .in_vld(in_vld && !indicate_kv),
        .group_size(group_size),
        .outlier_num(outlier_num),
        .d_in(d_in),
        .out_vld(outlier_tree_out_vld),
        .outlier_pos(outlier_tree_pos),
        .outlier_val(outlier_tree_val),
        .outlier_excluded_max(outlier_excluded_max),
        .outlier_excluded_min(outlier_excluded_min)
    );

    scale_zerop #(
        .PREC(BEFORE_PREC),
        .DATA_NUM(MAX_GROUP_WIDTH)
    ) u_scale_zerop (
        .clk(clk),
        .rst_n(rst_n),
        .indicate_kv(indicate_kv),
        .in_vld(comp_tree_out_vld),
        .max_value(max_out_wire),
        .min_value(min_out_wire),
        .outlier_excluded_max_value(!indicate_kv ? outlier_excluded_max : max_out_wire),
        .outlier_excluded_min_value(!indicate_kv ? outlier_excluded_min : min_out_wire),
        .mean_value(mean_out_wire),
        .outlier_pos(outlier_tree_pos),
        .outlier_val(outlier_tree_val),
        .out_vld(scale_zerop_out_vld),
        .scale_fp_prec2(scale_fp_prec2_out_wire),
        .scale_fp_prec4(scale_fp_prec4_out_wire),
        .scale_fp_prec8(scale_fp_prec8_out_wire),
        .scale_int_prec2(scale_int_prec2_out_wire),
        .scale_int_prec4(scale_int_prec4_out_wire),
        .scale_int_prec8(scale_int_prec8_out_wire),
        .zerop_fp(zerop_fp_out_wire),
        .zerop_int(zerop_int_out_wire),
        .outlier_pos_out(outlier_pos_out),
        .outlier_val_out(outlier_val_out)
    );

    wire [4*BEFORE_PREC-1:0] norm_scale_fp_prec2_in_wire
            = group_size == 2'b01 ? scale_fp_prec2_out_wire :
              group_size == 2'b10 ? {scale_fp_prec2_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec2_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec2_out_wire[0+:BEFORE_PREC], scale_fp_prec2_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_fp_prec2_out_wire[0+:BEFORE_PREC], scale_fp_prec2_out_wire[0+:BEFORE_PREC], scale_fp_prec2_out_wire[0+:BEFORE_PREC], scale_fp_prec2_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_scale_fp_prec4_in_wire
            = group_size == 2'b01 ? scale_fp_prec4_out_wire :
              group_size == 2'b10 ? {scale_fp_prec4_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec4_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec4_out_wire[0+:BEFORE_PREC], scale_fp_prec4_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_fp_prec4_out_wire[0+:BEFORE_PREC], scale_fp_prec4_out_wire[0+:BEFORE_PREC], scale_fp_prec4_out_wire[0+:BEFORE_PREC], scale_fp_prec4_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_scale_fp_prec8_in_wire
            = group_size == 2'b01 ? scale_fp_prec8_out_wire :
              group_size == 2'b10 ? {scale_fp_prec8_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec8_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_fp_prec8_out_wire[0+:BEFORE_PREC], scale_fp_prec8_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_fp_prec8_out_wire[0+:BEFORE_PREC], scale_fp_prec8_out_wire[0+:BEFORE_PREC], scale_fp_prec8_out_wire[0+:BEFORE_PREC], scale_fp_prec8_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_scale_int_prec2_in_wire
            = group_size == 2'b01 ? scale_int_prec2_out_wire :
              group_size == 2'b10 ? {scale_int_prec2_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec2_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec2_out_wire[0+:BEFORE_PREC], scale_int_prec2_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_int_prec2_out_wire[0+:BEFORE_PREC], scale_int_prec2_out_wire[0+:BEFORE_PREC], scale_int_prec2_out_wire[0+:BEFORE_PREC], scale_int_prec2_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_scale_int_prec4_in_wire
            = group_size == 2'b01 ? scale_int_prec4_out_wire :
              group_size == 2'b10 ? {scale_int_prec4_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec4_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec4_out_wire[0+:BEFORE_PREC], scale_int_prec4_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_int_prec4_out_wire[0+:BEFORE_PREC], scale_int_prec4_out_wire[0+:BEFORE_PREC], scale_int_prec4_out_wire[0+:BEFORE_PREC], scale_int_prec4_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_scale_int_prec8_in_wire
            = group_size == 2'b01 ? scale_int_prec8_out_wire :
              group_size == 2'b10 ? {scale_int_prec8_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec8_out_wire[BEFORE_PREC*2+:BEFORE_PREC], scale_int_prec8_out_wire[0+:BEFORE_PREC], scale_int_prec8_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {scale_int_prec8_out_wire[0+:BEFORE_PREC], scale_int_prec8_out_wire[0+:BEFORE_PREC], scale_int_prec8_out_wire[0+:BEFORE_PREC], scale_int_prec8_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_zerop_fp_in_wire
            = group_size == 2'b01 ? zerop_fp_out_wire :
              group_size == 2'b10 ? {zerop_fp_out_wire[BEFORE_PREC*2+:BEFORE_PREC], zerop_fp_out_wire[BEFORE_PREC*2+:BEFORE_PREC], zerop_fp_out_wire[0+:BEFORE_PREC], zerop_fp_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {zerop_fp_out_wire[0+:BEFORE_PREC], zerop_fp_out_wire[0+:BEFORE_PREC], zerop_fp_out_wire[0+:BEFORE_PREC], zerop_fp_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    wire [4*BEFORE_PREC-1:0] norm_zerop_int_in_wire
            = group_size == 2'b01 ? zerop_int_out_wire :
              group_size == 2'b10 ? {zerop_int_out_wire[BEFORE_PREC*2+:BEFORE_PREC], zerop_int_out_wire[BEFORE_PREC*2+:BEFORE_PREC], zerop_int_out_wire[0+:BEFORE_PREC], zerop_int_out_wire[0+:BEFORE_PREC]} :
              group_size == 2'b11 ? {zerop_int_out_wire[0+:BEFORE_PREC], zerop_int_out_wire[0+:BEFORE_PREC], zerop_int_out_wire[0+:BEFORE_PREC], zerop_int_out_wire[0+:BEFORE_PREC]} :
              {4*BEFORE_PREC{1'b0}};

    generate
    for(i=0; i<4; i=i+1)
    begin : pipeline_structure
        norm #(
            .BEFORE_PREC(BEFORE_PREC),
            .LOOP_NUM(LOOP_NUM)
        ) u_norm (
            .clk(clk),
            .rst_n(rst_n),
            .in_vld(scale_zerop_out_vld),
            .quant_precision(quant_precision),
            .indicate_kv(indicate_kv),
            .d_in(d_in_reg_2nd[MIN_ROW_WIDTH*i +: MIN_ROW_WIDTH]),
            .outlier_in(outlier_val_out[MIN_ROW_WIDTH*i +: MIN_ROW_WIDTH]),
            .outlier_pos(outlier_pos_out[MIN_GROUP_WIDTH*i +: MIN_GROUP_WIDTH]),
            .scale_fp_prec2(norm_scale_fp_prec2_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .scale_fp_prec4(norm_scale_fp_prec4_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .scale_fp_prec8(norm_scale_fp_prec8_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .scale_int_prec2(norm_scale_int_prec2_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .scale_int_prec4(norm_scale_int_prec4_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .scale_int_prec8(norm_scale_int_prec8_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .zerop_fp(norm_zerop_fp_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .zerop_int(norm_zerop_int_in_wire[i*BEFORE_PREC +: BEFORE_PREC]),
            .out_vld(norm_out_vld[i]),
            .d_out_fp(norm_d_out_fp[i]),
            .d_out_int(norm_d_out_int[i]),
            .scale_fp_out(norm_scale_fp_out_wire[i]),
            .scale_int_out(norm_scale_int_out_wire[i]),
            .zerop_fp_out(norm_zerop_fp_out_wire[i]),
            .zerop_int_out(norm_zerop_int_out_wire[i]),
            .outlier_mask_out(outlier_mask_out[i])
        );
    end
    endgenerate

    transposer_out #(
        .BLOCK_SIZE(MAX_GROUP_WIDTH),
        .ROW_WIDTH(ROW_WIDTH)
    ) u_transposer_out (
        .clk(clk),
        .rst_n(rst_n),
        .indicate_kv(indicate_kv),
        .mode(quant_precision),
        .din_vld(transposer_out_in_vld),
        .fp_din(transposer_out_fp_din),
        .int_din(transposer_out_int_din),
        .outlier_din(transposer_out_outlier_din),
        .dout(transposer_out_dout),
        .dout_vld(transposer_out_dout_vld),
        .dout_kind(transposer_out_dout_kind),
        .outlier_dout(transposer_out_outlier_dout),
        .outlier_dout_vld(transposer_out_outlier_dout_vld),
        .prefill_start_write(prefill_start_write),
        .prefill_write_done(prefill_write_done),
        .decode_start_write(decode_start_write),
        .decode_write_done(decode_write_done)
    );

    outlier_compressor #(
        .DATA_NUM(MAX_GROUP_WIDTH),
        .PREC(BEFORE_PREC),
        .A_XFERS(A_XFERS),
        .W_XFERS(W_XFERS)
    ) u_outlier_compressor (
        .clk(clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .mode(quant_precision),
        .outlier_num(outlier_num),
        .outlier_pos_write_phase(norm_out_vld_cnt < 7'd120 && norm_out_vld_cnt > 7'd1),
        .in_vld(outlier_compressor_in_vld),
        .in_pos_or_val(outlier_compressor_in_pos_or_val),
        .in_data(outlier_compressor_in_data),
        .proj_done(outlier_compressor_proj_done),
        .scale_zp_emit_done(scale_zp_emit_done),
        .comb_sram_wen(comb_sram_wen),
        .comb_sram_wdata(comb_sram_wdata),
        .out_vld(outlier_compressor_out_vld),
        .out_data(outlier_compressor_out_data),
        .outlier_pos_start_write(outlier_pos_start_write),
        .outlier_val_start_write(outlier_val_start_write),
        .outlier_val_burst_length(outlier_val_burst_length),
        .outlier_pos_emit_bundle(outlier_pos_emit_bundle),
        .outlier_val_emit_bundle(outlier_val_emit_bundle)
    );

endmodule
