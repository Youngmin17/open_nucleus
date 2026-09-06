// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module concat_top #(
    parameter DATA_WIDTH      = 16,
    parameter BLOCK_SIZE      = 128,
    parameter CORE_NUM        = 8,
    parameter AXI_CHANNELS    = 32,
    parameter AXI_DATA_WIDTH  = 256,
    parameter ADDR_WIDTH      = 64,
    parameter [3:0] GEMM_A_XFERS = 4'd2,
    parameter [3:0] GEMM_W_XFERS = 4'd4
)(
    input  wire                             core_clk,
    input  wire                             rst_n,

    input  wire [3:0]                       fuse_mode,

    input  wire                             isa_valid,
    input  wire                             is_mode_valid,
    input  wire                             is_proj_mode,
    input  wire                             is_gemm_mode,

    input  wire [1:0]                       group_width,
    input  wire [5:0]                       group_size,
    input  wire [31:0]                      seq_len,
    input  wire [15:0]                      output_dim,
    input  wire [7:0]                       batch_num,
    input  wire [7:0]                       batch_space,
    input  wire [6:0]                       outlier_num,
    input  wire [5:0]                       decode_core_num,
    input  wire [6:0]                       kv_head_num,

    input  wire [2:0]                       quant_precision,
    input  wire [ADDR_WIDTH-1:0]            dest_addr1,
    input  wire [ADDR_WIDTH-1:0]            dest_addr2,
    input  wire [ADDR_WIDTH-1:0]            qkv_head_addr_offset,

    input  wire                             result_block_done,
    input  wire                             dim_read_done,

    input  wire                             core_row_valid,
    input  wire [DATA_WIDTH*BLOCK_SIZE-1:0] core_row_data,
    input  wire [DATA_WIDTH*BLOCK_SIZE-1:0] core_row_data_swig_val,
    input  wire                             gqa_compute_stop,

    input  wire [31:0]                      rope_token_pos,

    input  wire                             comb_sram_wen,
    input  wire [101:0]                     comb_sram_wdata,

    output reg                             wrvalid,
    output reg                             start_write,
    output reg [7:0]                       write_burst_length,
    output reg [ADDR_WIDTH-1:0]            write_init_addr,
    output reg [AXI_CHANNELS*AXI_DATA_WIDTH-1:0] write_data,
    output reg                             write_is_code,
    output reg                             cmd_is_code,

    output reg [CORE_NUM-1:0]              start_emit,

    input  wire                            concat_gemv_out_done,

    output reg                             concat_phase_done
);

    localparam SWIG_LOOP_NUM    = 4;
    localparam PRERMS_LOOP_NUM  = 4;
    localparam ROPE_LOOP_NUM    = 4;
    localparam QUANT_LOOP_NUM   = 4;

    localparam ROW_WIDTH     = DATA_WIDTH * BLOCK_SIZE;
    localparam BLOCK_ROW     = BLOCK_SIZE;
    localparam AXI_WORD_BITS = AXI_CHANNELS * AXI_DATA_WIDTH;
    localparam MEM_DATA_WIDTH = AXI_CHANNELS * AXI_DATA_WIDTH;
    localparam PACK_RATIO    = (AXI_WORD_BITS / ROW_WIDTH);
    localparam IDX_W   = $clog2(BLOCK_ROW);

    localparam HEAD_ROW_NUM_PER_CORE = BLOCK_ROW / CORE_NUM;

    localparam  GEMM_BYPASS   = 4'd1,
                GEMM_ROPE     = 4'd2,
                GEMM_RTQT     = 4'd3,
                GEMM_QT       = 4'd4,
                GEMM_PRERMS   = 4'd5,
                GEMM_SWIGLU  = 4'd6,
                GEMM_TRANSPOSE= 4'd7,
                GEMV_BYPASS   = 4'd9,
                GEMV_ROPE_Q   = 4'd10,
                GEMV_ROPE_K   = 4'd11,
                GEMV_PRERMS   = 4'd12,
                GEMV_SWIGLU  = 4'd13;

    localparam  FUSE_ST_IDLE     = 4'd0,
                FUSE_ST_BYPASS   = 4'd1,
                FUSE_ST_ROPE     = 4'd2,
                FUSE_ST_RTQT     = 4'd3,
                FUSE_ST_QT       = 4'd4,
                FUSE_ST_PRERMS   = 4'd5,
                FUSE_ST_SWIGLU  = 4'd6,
                FUSE_ST_TRANSPOSE= 4'd7,
                FUSE_ST_GQA      = 4'd8;

    localparam [2:0] GATE_TILES = GEMM_W_XFERS >> 1;

    localparam [4:0] A_SHIFT_C = $clog2(GEMM_A_XFERS);
    localparam [4:0] W_SHIFT_C = $clog2(GEMM_W_XFERS);
    localparam [4:0] A_SHIFT_S = (A_SHIFT_C == 5'd0) ? 5'd1 : A_SHIFT_C;
    localparam [4:0] W_SHIFT_S = (W_SHIFT_C == 5'd0) ? 5'd1 : W_SHIFT_C;

    wire gemm_proj = is_gemm_mode && is_proj_mode;
    wire gemv_proj = !is_gemm_mode && is_proj_mode;
    wire gemm_gqa  = is_gemm_mode && !is_proj_mode;
    wire gemv_gqa  = !is_gemm_mode && !is_proj_mode;
    wire gemv_swiglu = gemv_proj && (fuse_mode == GEMV_SWIGLU);

    genvar gi;
    integer k, r;

    reg [3:0]  fuse_state;
    reg        fuse_active;
    reg        fuse_start;
    reg        fuse_in_done;
    reg        fuse_out_done;
    reg [IDX_W-1:0] fuse_in_idx;
    reg [IDX_W-1:0] fuse_out_idx;

    reg        emit_phase_active;
    reg        all_core_emit_done;
    reg [4:0]  emit_cnt;
    reg        emit_trigger;
    reg [3:0]  rbd_pending;
    reg [15:0] expected_phases;
    reg [15:0] emit_phase_ctr;
    reg [3:0]  swig_wcg;
    reg [3:0]  swig_wcg_last;

    reg gqa_gemm_out_done;
    reg gqa_compute_stop_latch;
    reg [2:0] gqa_gemm_delay_cnt;
    reg [6:0] gqa_core_cnt;
    reg [6:0] gqa_head_cnt;
    reg [6:0] gqa_data_head_cnt;
    reg [7:0] gqa_wr_cnt;

    reg                 emit_vld, emit_vld_pip_gemv, emit_vld_pip_gemm;
    reg [ROW_WIDTH-1:0] emit_data;

    reg  [ROW_WIDTH-1:0] swig_gate_row;
    reg  [ROW_WIDTH-1:0] swig_val_row;
    wire                  swig_out_vld;
    wire [ROW_WIDTH-1:0]  swig_out_row;
    reg                   swig_fuse_in_vld;

    reg  [31:0]           cur_rope_token_pos;
    reg  [6:0]            cur_rope_token_pos_idx;
    reg  [24:0]           rope_token_row_idx;
    reg  [8:0]            rope_token_loop_cnt;
    wire                  rope_out_vld;
    wire [ROW_WIDTH-1:0]  rope_out_row;

    wire                  quant_out_vld;
    wire [1:0]            quant_out_kind;
    wire [ROW_WIDTH-1:0]  quant_out_row;
    wire                  quant_out_is_code;
    reg                   emit_is_code;
    reg                   beat_is_code;

    reg                   fuse_in_vld;
    reg  [ROW_WIDTH-1:0]  fuse_in_row;

    reg [6:0] fuse_in_vld_cnt;
    reg [6:0] fuse_out_vld_cnt;
    reg [6:0] loop_cnt;

    reg first_phase_done_latch;

    reg gqa_gemm_start_write;

    reg isa_valid_pip;

    reg [7:0] KV_prefill_burst_length;
    reg [7:0] KV_decode_burst_length;
    reg [7:0] dense_burst_length;
    reg [7:0] scale_zp_burst_length;
    reg [7:0] outlier_pos_burst_length;
    reg [7:0] rms_burst_length;
    reg [7:0] phase_num;
    reg [9:0] output_dim_tile_num;
    reg [24:0] seq_len_tile_num;
    reg [9:0] emit_interm_delay;

    reg [9:0] fp_scale_zp_addr_offset_per_bundle;
    reg [9:0] int_scale_zp_addr_offset_per_bundle;
    reg [12:0] fp_scale_zp2_addr_offset;
    reg [12:0] int_scale_zp2_addr_offset;
    reg [9:0] outlier_pos_addr_offset_per_bundle;
    reg [9:0] outlier_val_addr_offset_per_bundle;
    reg [10:0] fp_kv_tile_addr_offset;
    reg [10:0] int_kv_tile_addr_offset;
    reg [15:0] prefill_bundle_addr_offset;
    reg [15:0] decode_bundle_addr_offset;

    wire [7:0] KV_total_burst_length =
            quant_precision < 3'b010 ? KV_decode_burst_length :
            quant_precision == 3'b010 && fuse_mode == GEMM_QT ? KV_decode_burst_length :
            quant_precision == 3'b100 && fuse_mode == GEMM_QT ? KV_decode_burst_length :
            KV_prefill_burst_length + KV_decode_burst_length;

    wire [4:0] dest_precision1 =
            quant_precision == 3'b011 ? 5'd4 :
            quant_precision == 3'b101 ? 5'd8 :
            quant_precision == 3'b110 ? 5'd8 : 5'd0;

    wire [4:0] dest_precision2 =
            quant_precision == 3'b000 ? 5'd2 :
            quant_precision == 3'b001 ? 5'd4 :
            quant_precision == 3'b010 ? 5'd2 :
            quant_precision == 3'b011 ? 5'd2 :
            quant_precision == 3'b100 ? 5'd4 :
            quant_precision == 3'b101 ? 5'd4 :
            quant_precision == 3'b110 ? 5'd2 :
            quant_precision == 3'b111 ? 5'd4 : 5'd0;

    always @ (posedge core_clk) begin
        if (!rst_n) begin
            isa_valid_pip <= 1'b0;
            KV_prefill_burst_length <= 8'd0;
            KV_decode_burst_length <= 8'd0;
            dense_burst_length <= 8'd0;
            scale_zp_burst_length <= 8'd0;
            outlier_pos_burst_length <= 8'd0;
            phase_num <= 8'd0;
            expected_phases <= 16'd0;
            output_dim_tile_num <= 10'd0;
            emit_interm_delay <= 10'd0;
            rms_burst_length <= 8'd0;
            fp_scale_zp_addr_offset_per_bundle <= 10'd0;
            int_scale_zp_addr_offset_per_bundle <= 10'd0;
            fp_scale_zp2_addr_offset <= 13'd0;
            int_scale_zp2_addr_offset <= 13'd0;
            outlier_pos_addr_offset_per_bundle <= 10'd0;
            outlier_val_addr_offset_per_bundle <= 10'd0;
            fp_kv_tile_addr_offset <= 11'd0;
            int_kv_tile_addr_offset <= 11'd0;
            prefill_bundle_addr_offset <= 16'd0;
            decode_bundle_addr_offset <= 16'd0;

        end else begin
            isa_valid_pip <= isa_valid;
            if (isa_valid) begin
                KV_prefill_burst_length <=  (dest_precision1 == 2) ? 8'd4 :
                                            (dest_precision1 == 4) ? 8'd8 :
                                            (dest_precision1 == 8) ? 8'd16 : 8'd32;
                KV_decode_burst_length <=   (dest_precision2 == 2) ? 8'd4 :
                                            (dest_precision2 == 4) ? 8'd8 :
                                            (dest_precision2 == 8) ? 8'd16 : 8'd32;
                dense_burst_length      <= 8'd32;
                scale_zp_burst_length   <= group_width == 2'b11 ? 8'd2 : 8'd3;
                outlier_pos_burst_length    <= 8'd1;
                rms_burst_length        <= 8'd1;
                phase_num               <= (fuse_mode == GEMM_SWIGLU) ? (seq_len >> $clog2(BLOCK_SIZE)) :
                                           output_dim >> ($clog2(GEMM_W_XFERS) + $clog2(BLOCK_SIZE));
                output_dim_tile_num     <= output_dim >> $clog2(BLOCK_SIZE);
                seq_len_tile_num        <= seq_len >> $clog2(BLOCK_SIZE);
                swig_wcg_last           <= (fuse_mode == GEMM_SWIGLU) ? (((output_dim >> $clog2(BLOCK_SIZE)) / {13'd0, GATE_TILES}) - 4'd1) : 4'd0;
                expected_phases         <= (fuse_mode == GEMM_SWIGLU) ?
                                           ((seq_len >> $clog2(BLOCK_SIZE)) * ((output_dim >> $clog2(BLOCK_SIZE)) / {13'd0, GATE_TILES})) :
                                           ((((seq_len    >> ($clog2(GEMM_A_XFERS) + $clog2(BLOCK_SIZE))) == 16'd0) ? 16'd1
                                             : (seq_len    >> ($clog2(GEMM_A_XFERS) + $clog2(BLOCK_SIZE)))) *
                                            (((output_dim >> ($clog2(GEMM_W_XFERS) + $clog2(BLOCK_SIZE))) == 16'd0) ? 16'd1
                                             : (output_dim >> ($clog2(GEMM_W_XFERS) + $clog2(BLOCK_SIZE)))));
                emit_interm_delay       <= fuse_mode == GEMM_RTQT ? 10'd400 :
                                        fuse_mode == GEMM_QT ? 10'd400 :
                                        fuse_mode == GEMM_PRERMS ? 10'd200 : 10'd20;

                fp_scale_zp_addr_offset_per_bundle <= (fuse_mode != GEMM_RTQT && fuse_mode != GEMM_QT) ? 10'd0 :
                                                (quant_precision == 3'b000 && fuse_mode == GEMM_QT) ? 10'd0 :
                                                (quant_precision == 3'b001 && fuse_mode == GEMM_QT) ? 10'd0 :
                                                (quant_precision == 3'b010) ? 10'd0 :
                                                (quant_precision == 3'b100) ? 10'd0 :
                                                (group_width == 2'b01) ? 10'd384 :
                                                (group_width == 2'b10) ? 10'd192 :
                                                (group_width == 2'b11) ? 10'd128 : 10'd0;
                int_scale_zp_addr_offset_per_bundle <= (fuse_mode != GEMM_RTQT && fuse_mode != GEMM_QT) ? 10'd0 :
                                                (group_width == 2'b01) ? 10'd384 :
                                                (group_width == 2'b10) ? 10'd192 :
                                                (group_width == 2'b11) ? 10'd128 : 10'd0;
                outlier_pos_addr_offset_per_bundle <= (fuse_mode != GEMM_RTQT) ? 10'd0 :
                                                    (outlier_num <= 7'd2) ? 10'd32 :
                                                    (outlier_num <= 7'd5) ? 10'd64 :
                                                    (outlier_num <= 7'd9) ? 10'd96 :
                                                    (outlier_num <= 7'd15) ? 10'd128 :
                                                    (outlier_num <= 7'd20) ? 10'd160 :
                                                    (outlier_num <= 7'd28) ? 10'd192 :
                                                    (outlier_num <= 7'd32) ? 10'd224 : 10'd0;
                outlier_val_addr_offset_per_bundle <= (fuse_mode != GEMM_RTQT) ? 10'd0 :
                                                    (outlier_num <= 7'd8) ? 10'd32 :
                                                    (outlier_num <= 7'd16) ? 10'd64 :
                                                    (outlier_num <= 7'd24) ? 10'd96 :
                                                    (outlier_num <= 7'd32) ? 10'd128 : 10'd0;
                fp_kv_tile_addr_offset <= quant_precision == 3'b000 && fuse_mode == GEMM_RTQT ? 11'd1024 :
                                        quant_precision == 3'b001 && fuse_mode == GEMM_RTQT ? 11'd1024 :
                                        quant_precision == 3'b011 ? 11'd256 :
                                        quant_precision == 3'b101 ? 11'd512 :
                                        quant_precision == 3'b110 ? 11'd512 :
                                        quant_precision == 3'b111 ? 11'd256 : 11'd0;
                int_kv_tile_addr_offset <=  quant_precision == 3'b000 ? 11'd128 :
                                            quant_precision == 3'b001 ? 11'd256 :
                                            quant_precision == 3'b010 ? 11'd128 :
                                            quant_precision == 3'b011 ? 11'd128 :
                                            quant_precision == 3'b100 ? 11'd256 :
                                            quant_precision == 3'b101 ? 11'd256 :
                                            quant_precision == 3'b110 ? 11'd128 :
                                            quant_precision == 3'b111 ? 11'd256 : 11'd0;
            end
            if(isa_valid_pip) begin
                prefill_bundle_addr_offset <= (fp_kv_tile_addr_offset << 3) + fp_scale_zp_addr_offset_per_bundle;
                decode_bundle_addr_offset <= (int_kv_tile_addr_offset << 3) + int_scale_zp_addr_offset_per_bundle
                                            + outlier_pos_addr_offset_per_bundle + outlier_val_addr_offset_per_bundle;
                fp_scale_zp2_addr_offset <= (fp_scale_zp_addr_offset_per_bundle >> 1) + {fp_kv_tile_addr_offset, 2'b0};
                int_scale_zp2_addr_offset <= (int_scale_zp_addr_offset_per_bundle >> 1) + {int_kv_tile_addr_offset, 2'b0};
            end
        end
    end

    wire rms_start_write;
    wire rms_out_vld;
    wire [DATA_WIDTH*BLOCK_SIZE-1:0] rms_out_data;

    reg [1:0] prerms_core_group;
    reg prerms_in_last;

    reg [7:0]  batch_space_eff;

    residual_and_pre_rms_unit #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_NUM   (BLOCK_SIZE),
        .BLOCK_ROW  (BLOCK_SIZE),
        .LOOP_NUM   (PRERMS_LOOP_NUM)
    ) u_residual_rms (
        .clk                 (core_clk),
        .rst_n               (rst_n),
        .output_dim          (output_dim),
        .batch_num           (batch_num),
        .batch_space         (batch_space_eff),
        .core_group          (prerms_core_group),
        .is_gemm_mode        (is_gemm_mode),
        .in_vld              (fuse_in_vld && (fuse_state == FUSE_ST_PRERMS)),
        .in_last             (prerms_in_last),
        .in_data             (fuse_in_row),
        .rms_start_write     (rms_start_write),
        .rms_out_vld         (rms_out_vld),
        .rms_out_data        (rms_out_data)
    );

    act_function_tdm_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_NUM   (BLOCK_SIZE),
        .LOOP_NUM   (SWIG_LOOP_NUM)
    ) u_act_function_tdm_wrapper (
        .clk            (core_clk),
        .rst_n          (rst_n),
        .gate_vec_in    (swig_gate_row),
        .value_vec_in   (swig_val_row),
        .data_in_vld    ((fuse_in_vld && (fuse_state == FUSE_ST_SWIGLU)) || swig_fuse_in_vld),
        .result_out     (swig_out_row),
        .result_out_vld (swig_out_vld)
    );

    rope_tdm_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_NUM   (BLOCK_SIZE),
        .LOOP_NUM   (ROPE_LOOP_NUM)
    ) u_rope_tdm_wrapper (
        .clk            (core_clk),
        .rst_n          (rst_n),
        .data_in_vld    (fuse_in_vld && ((fuse_state == FUSE_ST_ROPE || fuse_state == FUSE_ST_RTQT) ||
                          (!is_gemm_mode && (fuse_mode == GEMV_ROPE_Q || fuse_mode == GEMV_ROPE_K)))),
        .data_in        (fuse_in_row),
        .token_pos      (cur_rope_token_pos),
        .data_out       (rope_out_row),
        .data_out_vld   (rope_out_vld)
    );

    reg transposer_in_sel;
    reg [6:0] transposer_in_out_vld_cnt;
    reg [8:0] transposer_in_out_loop_cnt;
    reg transposer_in_start_write;

    wire transposer_in_in_vld = (rope_out_vld && (fuse_mode == GEMM_RTQT)) ||
                                (fuse_in_vld && fuse_state == FUSE_ST_TRANSPOSE);
    wire [ROW_WIDTH-1:0] transposer_in_in_row =
                                (rope_out_vld && fuse_mode == GEMM_RTQT) ? rope_out_row :
                                (fuse_in_vld && fuse_state == FUSE_ST_TRANSPOSE) ? fuse_in_row :
                                {ROW_WIDTH{1'b0}};

    wire transposer_in_out_vld_A;
    wire [ROW_WIDTH-1:0] transposer_in_out_row_A;

    transposer_in #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ROW_WIDTH(BLOCK_SIZE*DATA_WIDTH)
    ) u_transposer_in_A (
        .clk           (core_clk),
        .rst_n         (rst_n),
        .din_vld       (transposer_in_in_vld && !transposer_in_sel),
        .din           (transposer_in_in_row),
        .dout_vld      (transposer_in_out_vld_A),
        .dout          (transposer_in_out_row_A)
    );

    wire transposer_in_out_vld_B;
    wire [ROW_WIDTH-1:0] transposer_in_out_row_B;

    transposer_in #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ROW_WIDTH(BLOCK_SIZE*DATA_WIDTH)
    ) u_transposer_in_B (
        .clk           (core_clk),
        .rst_n         (rst_n),
        .din_vld       (transposer_in_in_vld && transposer_in_sel),
        .din           (transposer_in_in_row),
        .dout_vld      (transposer_in_out_vld_B),
        .dout          (transposer_in_out_row_B)
    );

    wire transposer_in_out_vld = transposer_in_out_vld_A || transposer_in_out_vld_B;
    wire [ROW_WIDTH-1:0] transposer_in_out_row = transposer_in_out_vld_A ? transposer_in_out_row_A : transposer_in_out_row_B;

    wire quant_top_prefill_start_write;
    wire quant_top_decode_start_write;
    wire quant_top_fp_scale_zp_start_write;
    wire quant_top_int_scale_zp_start_write;
    wire quant_top_outlier_pos_start_write;
    wire quant_top_outlier_val_start_write;
    wire [1:0] quant_top_outlier_val_burst_length;
    wire [$clog2(GEMM_W_XFERS)-1:0] quant_top_outlier_pos_emit_bundle;
    wire [$clog2(GEMM_W_XFERS)-1:0] quant_top_outlier_val_emit_bundle;

    wire quant_in_vld =
        !is_mode_valid ? 1'b0 :
        (fuse_mode == GEMM_QT) ? fuse_in_vld :
        (fuse_mode == GEMM_RTQT) ? transposer_in_out_vld :
        1'b0;

    wire [ROW_WIDTH-1:0] quant_in_row =
        !is_mode_valid ? {ROW_WIDTH{1'b0}} :
        (fuse_mode == GEMM_QT) ? fuse_in_row :
        (fuse_mode == GEMM_RTQT) ? transposer_in_out_row :
        {ROW_WIDTH{1'b0}};

    wire [2:0] quant_precision_in = quant_precision == 3'b000 ? 3'b010 :
                                    quant_precision == 3'b001 ? 3'b100 :
                                    quant_precision;

    wire both_quant_mode = quant_precision > 3'b001;
    wire k_only_quant_decode = !both_quant_mode && (fuse_mode == GEMM_RTQT);

    wire prefill_start_write =
            k_only_quant_decode ? emit_trigger :
            quant_top_prefill_start_write;

    reg quant_top_proj_done;

    quant_top #(
        .BEFORE_PREC(DATA_WIDTH),
        .MAX_GROUP_WIDTH(BLOCK_SIZE),
        .LOOP_NUM(QUANT_LOOP_NUM),
        .A_XFERS(GEMM_A_XFERS),
        .W_XFERS(GEMM_W_XFERS)
    ) u_quant_top (
        .clk(core_clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .proj_done(quant_top_proj_done),
        .in_vld(quant_in_vld),
        .indicate_kv(fuse_mode == GEMM_QT),
        .quant_precision(quant_precision_in),
        .group_size(group_width),
        .outlier_num(outlier_num),
        .d_in(quant_in_row),
        .comb_sram_wen(comb_sram_wen),
        .comb_sram_wdata(comb_sram_wdata),
        .out_vld(quant_out_vld),
        .d_out(quant_out_row),
        .out_is_code(quant_out_is_code),
        .prefill_start_write(quant_top_prefill_start_write),
        .decode_start_write(quant_top_decode_start_write),
        .fp_scale_zp_start_write(quant_top_fp_scale_zp_start_write),
        .int_scale_zp_start_write(quant_top_int_scale_zp_start_write),
        .outlier_pos_start_write(quant_top_outlier_pos_start_write),
        .outlier_val_start_write(quant_top_outlier_val_start_write),
        .outlier_val_burst_length(quant_top_outlier_val_burst_length),
        .outlier_pos_emit_bundle(quant_top_outlier_pos_emit_bundle),
        .outlier_val_emit_bundle(quant_top_outlier_val_emit_bundle)
    );

    reg [6:0] swig_gate_wr_idx;
    reg [6:0] swig_gate_rd_idx;
    reg       swig_gate_phase;
    reg       swig_gate_stored;

    reg [($clog2(BLOCK_SIZE)-1):0] read_fifo_row_idx;

    reg        new_emit_start;
    reg        new_emit_trigger_latch;
    reg [9:0]  new_emit_trigger_latch_cnt;
    reg [15:0] rope_phase_cnt;
    reg [15:0] prerms_phase_cnt;
    reg [15:0] rope_token_row_phase_cnt;
    reg        fuse_in_done_gqa_latch;
    reg [2:0]  fuse_in_done_gqa_delay;
    reg        fuse_in_done_stop;
    reg [15:0] fuse_gqa_cnt;
    reg        read_fifo_row_ready;
    reg [9:0]  concat_phase_last_cnt;
    reg [ROW_WIDTH-1:0] row_sumsq_out_row;

    reg fuse_out_done_gemm_latch;
    reg concat_gemv_out_done_latch;
    reg gemv_proj_isa_done_d;
    reg [4:0] gemv_wr_hold_cnt;
    reg [4:0] gemv_wr_hold_cnt_d;

    reg [3:0]  dim_read_pending;
    reg [9:0]  remaining_tiles;
    reg [7:0]  gemv_burst_length;
    reg [3:0]  gemv_zero_pad_rows;
    reg [9:0]  gemv_phase_idx;
    reg [ADDR_WIDTH-1:0] token_stride;
    reg [ADDR_WIDTH-1:0] gemv_phase_offset;
    reg [7:0]  gemv_emit_batch_cnt;
    reg [5:0]  gemv_emit_core;
    reg [9:0]  gemv_row_recv_cnt;
    reg [3:0]  gemv_row_pace_cnt;
    reg        gemv_emit_busy;
    reg        gemv_phase_busy;
    reg        gemv_phase_last;
    reg        gemv_proj_isa_done;

    reg        gemv_write_req;
    reg [ADDR_WIDTH-1:0] gemv_write_addr_pip;
    reg [7:0]  gemv_write_burst_pip;
    reg [3:0]  gemv_write_zpad_pip;
    reg        gemv_write_req_d1, gemv_write_req_d2, gemv_write_req_d3,
               gemv_write_req_d4, gemv_write_req_d5, gemv_write_req_d6,
               gemv_write_req_d7, gemv_write_req_d8;
    reg [ADDR_WIDTH-1:0] gemv_write_addr_d [1:8];
    reg [7:0]  gemv_write_burst_d [1:8];
    reg [3:0]  gemv_write_zpad_d  [1:8];

    reg        gqa_v_phase_busy;
    reg [5:0]  gqa_v_emit_core;
    reg [6:0]  gqa_v_recv_cnt;
    reg [6:0]  gqa_v_emit_target;
    reg [6:0]  gqa_v_token_acc;
    reg        gqa_v_emit_busy;
    reg [3:0]  gqa_v_pace_cnt;
    reg        gqa_v_write_req;
    reg [3:0]  gqa_v_write_tokens;
    reg        gqa_v_write_req_d1, gqa_v_write_req_d2, gqa_v_write_req_d3,
               gqa_v_write_req_d4, gqa_v_write_req_d5, gqa_v_write_req_d6,
               gqa_v_write_req_d7, gqa_v_write_req_d8;
    reg [3:0]  gqa_v_write_tokens_d [1:8];
    reg [ADDR_WIDTH-1:0] gqa_v_write_addr;
    reg [ADDR_WIDTH-1:0] gqa_v_write_addr_d [1:8];
    reg        gqa_v_stop_latch;
    reg        gqa_v_last_write_seed;
    reg [6:0]  gqa_v_phase_cnt;
    reg        gqa_v_last_beat_d1, gqa_v_last_beat_d2, gqa_v_last_beat_d3,
               gqa_v_last_beat_d4, gqa_v_last_beat_d5, gqa_v_last_beat_d6,
               gqa_v_last_beat_d7, gqa_v_last_beat_d8;

    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            fuse_out_done_gemm_latch <= 1'b0;
            concat_gemv_out_done_latch <= 1'b0;
            concat_phase_done <= 1'b0;
            concat_phase_last_cnt <= 10'd0;
            gemv_proj_isa_done_d <= 1'b0;
            gemv_wr_hold_cnt_d <= 5'd0;
        end else begin
            concat_phase_done <= 1'b0;
            gemv_proj_isa_done_d <= gemv_proj_isa_done;
            gemv_wr_hold_cnt_d <= gemv_wr_hold_cnt;
`ifdef RESPROBE
            if (swig_out_vld)
                $display("[SWVLD] t=%0t swig_out_vld=1", $time);
            if (swig_fuse_in_vld)
                $display("[SWACT] t=%0t swig_fuse_in_vld=1 (act gate opened)", $time);
            if (gemv_wr_hold_cnt != gemv_wr_hold_cnt_d)
                $display("[SWHOLD] t=%0t gemv_wr_hold_cnt %0d -> %0d (isa_done=%b)",
                         $time, gemv_wr_hold_cnt_d, gemv_wr_hold_cnt, gemv_proj_isa_done);
`endif
            if(fuse_out_done_gemm_latch || concat_gemv_out_done_latch) begin
                concat_phase_last_cnt <= concat_phase_last_cnt + 10'd1;
                if(concat_phase_last_cnt == 10'd9) begin
                    concat_phase_last_cnt <= 10'd0;
                    concat_phase_done <= 1'b1;
                    fuse_out_done_gemm_latch <= 1'b0;
                    concat_gemv_out_done_latch <= 1'b0;
                end
            end else if(is_gemm_mode && fuse_out_done &&
                        (gemm_proj ? (emit_phase_ctr == expected_phases) : (rbd_pending == 4'd0))) begin
                fuse_out_done_gemm_latch <= 1'b1;
            end else if(concat_gemv_out_done ||
                        (gemv_proj &&
                         (fuse_mode == GEMV_BYPASS || fuse_mode == GEMV_PRERMS) &&
                         gemv_proj_isa_done && !gemv_proj_isa_done_d) ||
                        (gemv_proj &&
                         (fuse_mode == GEMV_ROPE_Q || fuse_mode == GEMV_ROPE_K ||
                          fuse_mode == GEMV_SWIGLU) &&
                         gemv_proj_isa_done &&
                         (gemv_wr_hold_cnt == 5'd0) && (gemv_wr_hold_cnt_d != 5'd0)) ||
                        (gemv_gqa && gqa_v_last_beat_d8)) begin
                concat_gemv_out_done_latch <= 1'b1;
            end

        end
    end

    // synopsys translate_off
    reg [31:0] retire_wait_cnt;
    reg        retire_wait_warned;
    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            retire_wait_cnt    <= 32'd0;
            retire_wait_warned <= 1'b0;
        end else if(concat_phase_done || !is_mode_valid || is_gemm_mode) begin
            retire_wait_cnt    <= 32'd0;
            retire_wait_warned <= 1'b0;
        end else begin
            retire_wait_cnt <= retire_wait_cnt + 32'd1;
            if(retire_wait_cnt == 32'd100000 && !retire_wait_warned) begin
                retire_wait_warned <= 1'b1;
                $display("[CONCAT-RETIRE-WARN] t=%0t decode fuse_mode=%0d waited >100000 cyc with no retire: not mapped in the per-fuse decode retire branch (add its last-write-drained completion condition).",
                         $time, fuse_mode);
            end
        end
    end

    reg dec_prerms_core_row_d;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_prerms_core_row_d <= 1'b0;
        end else begin
            if (dec_prerms_core_row_d) begin
                if (!emit_vld)
                    $error("[PRERMS-DECODE-ROUTE] core row did not reach GEMV emit");
                if (fuse_in_vld)
                    $error("[PRERMS-DECODE-ROUTE] decode row entered prefill reducer");
            end
            dec_prerms_core_row_d <= is_mode_valid && !is_gemm_mode &&
                                     fuse_mode == GEMV_PRERMS &&
                                     fuse_state == FUSE_ST_PRERMS && core_row_valid;
        end
    end
    // synopsys translate_on

    reg [2:0] quant_top_decode_start_write_cnt;
    reg [9:0] proj_done_delay_cnt;

    wire emit_phase_done =
            gemm_gqa ? gqa_core_cnt == CORE_NUM-1 && gqa_head_cnt == group_size-1 :
            fuse_mode == GEMM_SWIGLU ? emit_cnt == {2'd0, GATE_TILES}-5'd1 : emit_cnt == CORE_NUM-1;

    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            emit_phase_active <= 1'b0;
            all_core_emit_done <= 1'b0;
            emit_cnt <= 5'd0;
            emit_trigger <= 1'b0;
            rbd_pending <= 4'd0;
            emit_phase_ctr <= 16'd0;

            fuse_state <= FUSE_ST_IDLE;
            fuse_active <= 1'b0;
            fuse_start <= 1'b0;
            fuse_in_done <= 1'b0;
            fuse_out_done <= 1'b0;
            fuse_in_idx <= {IDX_W{1'b0}};
            fuse_out_idx <= {IDX_W{1'b0}};
            fuse_in_vld <= 1'b0;
            fuse_in_row <= {ROW_WIDTH{1'b0}};
            fuse_in_vld_cnt <= 7'd0;
            fuse_out_vld_cnt <= 7'd0;
            loop_cnt <= 7'd0;

            swig_gate_row <= {ROW_WIDTH{1'b0}};
            swig_val_row  <= {ROW_WIDTH{1'b0}};
            cur_rope_token_pos <= 32'd0;
            cur_rope_token_pos_idx <= 7'd0;
            rope_token_row_idx <= 25'd0;
            rope_token_loop_cnt <= 9'd0;
            emit_vld <= 1'b0;
            emit_data <= {ROW_WIDTH{1'b0}};

            gqa_gemm_out_done <= 1'b0;
            gqa_compute_stop_latch <= 1'b0;
            gqa_gemm_delay_cnt <= 3'd0;
            gqa_core_cnt <= 7'd0;
            gqa_head_cnt <= 7'd0;
            gqa_data_head_cnt <= 7'd0;
            gqa_wr_cnt <= 8'd0;

            start_emit <= {CORE_NUM{1'b0}};

            first_phase_done_latch <= 1'b0;
            swig_gate_phase <= 1'b0;
            swig_gate_stored <= 1'b0;
            swig_gate_wr_idx <= 7'd0;
            swig_gate_rd_idx <= 7'd0;

            transposer_in_sel <= 1'b0;
            transposer_in_start_write <= 1'b0;

            read_fifo_row_ready <= 1'b0;
            read_fifo_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};

            transposer_in_out_vld_cnt <= 7'd0;
            transposer_in_out_loop_cnt <= 9'd0;

            new_emit_start <= 1'b0;
            new_emit_trigger_latch <= 1'b0;
            new_emit_trigger_latch_cnt <= 10'd0;
            rope_phase_cnt <= 16'd0;
            prerms_phase_cnt <= 16'd0;
            rope_token_row_phase_cnt <= 16'd0;
            fuse_in_done_gqa_latch <= 1'b0;
            fuse_in_done_gqa_delay <= 3'd0;
            fuse_in_done_stop <= 1'b0;
            fuse_gqa_cnt <= 16'd0;
            row_sumsq_out_row <= {ROW_WIDTH{1'b0}};
            gqa_gemm_start_write <= 1'b0;

            quant_top_decode_start_write_cnt <= 3'd0;
            proj_done_delay_cnt <= 10'd0;

            dim_read_pending      <= 4'd0;
            remaining_tiles       <= 10'd0;
            batch_space_eff       <= 8'd0;
            gemv_burst_length     <= 8'd0;
            gemv_zero_pad_rows    <= 4'd0;
            gemv_phase_idx        <= 10'd0;
            token_stride          <= {ADDR_WIDTH{1'b0}};
            gemv_phase_offset     <= {ADDR_WIDTH{1'b0}};
            gemv_emit_batch_cnt   <= 8'd0;
            gemv_emit_core        <= 6'd0;
            gemv_row_recv_cnt     <= 10'd0;
            gemv_row_pace_cnt     <= 4'd0;
            gemv_emit_busy        <= 1'b0;
            gemv_phase_busy       <= 1'b0;
            gemv_phase_last       <= 1'b0;
            gemv_proj_isa_done    <= 1'b0;
            gemv_write_req        <= 1'b0;
            gemv_write_addr_pip   <= {ADDR_WIDTH{1'b0}};
            gemv_write_burst_pip  <= 8'd0;
            gemv_write_zpad_pip   <= 4'd0;

            gqa_v_phase_busy      <= 1'b0;
            gqa_v_emit_core       <= 6'd0;
            gqa_v_recv_cnt        <= 7'd0;
            gqa_v_emit_target     <= 7'd0;
            gqa_v_token_acc       <= 7'd0;
            gqa_v_emit_busy       <= 1'b0;
            gqa_v_pace_cnt        <= 4'd0;
            gqa_v_write_req       <= 1'b0;
            gqa_v_write_tokens    <= 4'd0;
            gqa_v_write_addr      <= {ADDR_WIDTH{1'b0}};
            gqa_v_stop_latch      <= 1'b0;
            gqa_v_last_write_seed <= 1'b0;
            gqa_v_phase_cnt       <= 7'd0;

        end else begin
            fuse_in_vld <= 1'b0;
            fuse_out_done <= 1'b0;
            fuse_in_done <= 1'b0;
            gqa_gemm_out_done <= 1'b0;
            emit_vld <= 1'b0;
            emit_data <= {ROW_WIDTH{1'b0}};
            start_emit <= {CORE_NUM{1'b0}};
            swig_fuse_in_vld <= 1'b0;
            fuse_start <= 1'b0;
            emit_trigger <= 1'b0;
            all_core_emit_done <= 1'b0;
            quant_top_proj_done <= 1'b0;
            new_emit_start <= 1'b0;
            fuse_in_done_stop <= 1'b0;
            gqa_gemm_start_write <= 1'b0;
            transposer_in_start_write <= 1'b0;
            gemv_write_req <= 1'b0;
            gqa_v_write_req <= 1'b0;
            gqa_v_last_write_seed <= 1'b0;

            if(isa_valid) begin
                gqa_v_phase_cnt <= 7'd0;
                rope_token_row_idx <= 25'd0;
                rope_token_loop_cnt <= 9'd0;
                rope_phase_cnt <= 16'd0;
                prerms_phase_cnt <= 16'd0;
                rope_token_row_phase_cnt <= 16'd0;
                fuse_in_done_gqa_latch <= 1'b0;
                fuse_in_done_gqa_delay <= 3'd0;
                fuse_gqa_cnt <= 16'd0;
                new_emit_trigger_latch <= 1'b0;
                new_emit_trigger_latch_cnt <= 10'd0;
                transposer_in_out_vld_cnt <= 7'd0;
                transposer_in_out_loop_cnt <= 9'd0;
                quant_top_decode_start_write_cnt <= 3'd0;
                proj_done_delay_cnt <= 10'd0;

                dim_read_pending     <= 4'd0;
                remaining_tiles      <= output_dim >> $clog2(BLOCK_SIZE);
                gemv_phase_idx       <= 10'd0;
                gemv_phase_offset    <= {ADDR_WIDTH{1'b0}};
                gemv_emit_batch_cnt  <= 8'd0;
                gemv_emit_core       <= 6'd0;
                gemv_row_recv_cnt    <= 10'd0;
                gemv_row_pace_cnt    <= 4'd0;
                gemv_emit_busy       <= 1'b0;
                gemv_phase_busy      <= 1'b0;
                gemv_phase_last      <= 1'b0;
                gemv_proj_isa_done   <= 1'b0;
                batch_space_eff      <= 8'd0;
                gemv_burst_length    <= 8'd0;
                gemv_zero_pad_rows   <= 4'd0;
                token_stride         <= 64'd32 * (((({48'd0, output_dim} << 4) + (MEM_DATA_WIDTH-1)) >> $clog2(MEM_DATA_WIDTH)));

                gqa_v_phase_busy     <= 1'b0;
                gqa_v_emit_core      <= 6'd0;
                gqa_v_recv_cnt       <= 7'd0;
                gqa_v_emit_target    <= 7'd0;
                gqa_v_token_acc      <= 7'd0;
                gqa_v_emit_busy      <= 1'b0;
                gqa_v_pace_cnt       <= 4'd0;
                gqa_v_write_tokens   <= 4'd0;
                gqa_v_write_addr     <= dest_addr1;
                gqa_v_stop_latch     <= 1'b0;
            end

            if (isa_valid) begin emit_phase_ctr <= 16'd0; swig_wcg <= 4'd0; end

            if (gemm_proj && !emit_phase_active && rbd_pending != 4'd0 &&
                !((fuse_mode == GEMM_TRANSPOSE) && fuse_active)) begin
                emit_phase_active <= 1'b1;
                emit_cnt <= 5'd0;
                emit_trigger <= 1'b1;
                rbd_pending <= rbd_pending - 4'd1 + (result_block_done ? 4'd1 : 4'd0);
            end else if (gemm_proj && result_block_done) begin
                rbd_pending <= rbd_pending + 4'd1;
            end
`ifdef SWIGPROBE
            if ($test$plusargs("SWIGPROBE") && gemm_proj && result_block_done && fuse_mode == GEMM_SWIGLU)
                $display("[SWIG_RBD] t=%0t rbd_pending=%0d emit_phase_ctr=%0d exp=%0d fuse_out_done=%0d",
                         $time, rbd_pending, emit_phase_ctr, expected_phases, fuse_out_done);
`endif

            if (emit_trigger) begin
                start_emit <= ({{(CORE_NUM-1){1'b0}}, 1'b1} << emit_cnt);
                if(!fuse_active) begin
                    fuse_start <= 1'b1;
                end
                if (fuse_mode == GEMM_SWIGLU)
                    start_emit <= {2{{{((CORE_NUM/2 >= 1) ? (CORE_NUM/2-1) : 0){1'b0}}, 1'b1} << emit_cnt}};
            end

            if (new_emit_start) begin
                if (fuse_mode == GEMM_SWIGLU) begin
                    emit_trigger <= 1'b1;
                    if (emit_cnt == {2'd0, GATE_TILES} - 5'd1) begin
                        emit_phase_active <= 1'b0;
                        all_core_emit_done <= 1'b1;
                        emit_phase_ctr <= emit_phase_ctr + 16'd1;
`ifdef SWIGPROBE
                        if ($test$plusargs("SWIGPROBE"))
                            $display("[SWIG_EMIT] t=%0t emit_phase_ctr %0d->%0d exp=%0d swig_wcg=%0d",
                                     $time, emit_phase_ctr, emit_phase_ctr + 16'd1, expected_phases, swig_wcg);
`endif
                        swig_wcg <= (swig_wcg == swig_wcg_last) ? 4'd0 : (swig_wcg + 4'd1);
                        emit_cnt <= 5'd0;
                        emit_trigger <= 1'b0;
                    end else begin
                        emit_cnt <= emit_cnt + 1;
                    end
                end else if (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_TRANSPOSE) begin
                    emit_trigger <= 1'b1;
                    transposer_in_sel <= ~transposer_in_sel;
                    if (emit_cnt == CORE_NUM - 5'd1) begin
                        emit_phase_active <= 1'b0;
                        all_core_emit_done <= 1'b1;
                        if (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_TRANSPOSE)
                            emit_phase_ctr <= emit_phase_ctr + 16'd1;
                        emit_cnt <= 5'd0;
                        emit_trigger <= 1'b0;
                    end else begin
                        emit_cnt <= emit_cnt + 1;
                    end
                end else if(is_gemm_mode) begin
                    emit_trigger <= 1'b1;
                    if (emit_cnt == CORE_NUM - 5'd1) begin
                        emit_phase_active <= 1'b0;
                        all_core_emit_done <= 1'b1;
                        emit_phase_ctr <= emit_phase_ctr + 16'd1;
                        emit_cnt <= 5'd0;
                        emit_trigger <= 1'b0;
                    end else begin
                        emit_cnt <= emit_cnt + 1;
                    end
                end
            end else if(new_emit_trigger_latch) begin
                new_emit_trigger_latch_cnt <= new_emit_trigger_latch_cnt + 1'b1;
                if(new_emit_trigger_latch_cnt == emit_interm_delay-1) begin
                    new_emit_trigger_latch <= 1'b0;
                    new_emit_trigger_latch_cnt <= 10'd0;
                    new_emit_start <= 1'b1;
                end
            end else if(gemm_proj && fuse_in_done && emit_phase_active) begin
                new_emit_trigger_latch <= 1'b1;
            end

            if (quant_top_decode_start_write_cnt == 3'd4) begin
                proj_done_delay_cnt <= proj_done_delay_cnt + 1'b1;
                if(proj_done_delay_cnt == 10'd290) begin
                    quant_top_decode_start_write_cnt <= 0;
                    proj_done_delay_cnt <= 10'd0;
                    quant_top_proj_done <= 1'b1;
                end
            end else if (quant_top_decode_start_write) begin
                quant_top_decode_start_write_cnt <= quant_top_decode_start_write_cnt + 1'b1;
            end

            if (gemv_proj) begin
                dim_read_pending <= dim_read_pending
                    + ((dim_read_done) ? 4'd1 : 4'd0)
                    - ((!gemv_phase_busy && dim_read_pending != 4'd0 && !gemv_proj_isa_done) ? 4'd1 : 4'd0);
            end

            if (gemv_proj && !gemv_phase_busy && dim_read_pending != 4'd0 && !gemv_proj_isa_done) begin
                gemv_phase_busy   <= 1'b1;
                gemv_emit_batch_cnt <= 8'd0;
                gemv_emit_core    <= 6'd0;
                gemv_emit_busy    <= 1'b0;
                gemv_row_recv_cnt <= 10'd0;
                if (remaining_tiles <= {2'd0, batch_space}) begin
                    batch_space_eff   <= remaining_tiles[7:0];
                    gemv_burst_length <= (remaining_tiles[7:0] + 8'd3) >> 2;
                    gemv_zero_pad_rows<= (((remaining_tiles[7:0] + 8'd3) >> 2) << 2) - remaining_tiles[7:0];
                    gemv_phase_last   <= 1'b1;
                end else begin
                    batch_space_eff   <= batch_space;
                    gemv_burst_length <= (batch_space + 8'd3) >> 2;
                    gemv_zero_pad_rows<= (((batch_space + 8'd3) >> 2) << 2) - batch_space;
                    gemv_phase_last   <= 1'b0;
                end
                if(!fuse_active) fuse_start <= 1'b1;
            end

            if (gemv_proj && gemv_phase_busy && !gemv_emit_busy) begin
                start_emit <= ({{(CORE_NUM-1){1'b0}}, 1'b1} << gemv_emit_core)
                            | (gemv_swiglu
                                ? ({{(CORE_NUM-1){1'b0}}, 1'b1} << (gemv_emit_core + (CORE_NUM/2)))
                                : {CORE_NUM{1'b0}});
                gemv_emit_busy   <= 1'b1;
                gemv_row_recv_cnt<= 10'd0;
                gemv_row_pace_cnt<= 4'd0;
            end

            if (gemv_proj && gemv_emit_busy) begin
                if (core_row_valid) begin
                    gemv_row_recv_cnt <= gemv_row_recv_cnt + 10'd1;
                    if (gemv_row_recv_cnt == {2'd0, batch_space_eff} - 10'd1) begin
                        gemv_emit_busy   <= 1'b0;
                        gemv_write_req   <= 1'b1;
`ifdef RESPROBE
                        $display("[DECWR] t=%0t batch_cnt=%0d core=%0d write_word=%0d (token_stride=%0d phase_off=%0d batch_space_eff=%0d)",
                                 $time, gemv_emit_batch_cnt, gemv_emit_core,
                                 (dest_addr1 + (token_stride*{56'd0,gemv_emit_batch_cnt}) + gemv_phase_offset) >> 5,
                                 token_stride, gemv_phase_offset, batch_space_eff);
`endif
                        gemv_write_addr_pip <= dest_addr1
                                              + (token_stride * {56'd0, gemv_emit_batch_cnt})
                                              + gemv_phase_offset;
                        gemv_write_burst_pip <= gemv_burst_length;
                        gemv_write_zpad_pip  <= gemv_zero_pad_rows;

                        gemv_emit_batch_cnt <= gemv_emit_batch_cnt + 8'd1;
                        if (gemv_emit_core == decode_core_num - 6'd1) begin
                            gemv_emit_core <= 6'd0;
                        end else begin
                            gemv_emit_core <= gemv_emit_core + 6'd1;
                        end

                        if (gemv_emit_batch_cnt == batch_num - 8'd1) begin
                            gemv_phase_busy   <= 1'b0;
                            gemv_phase_idx    <= gemv_phase_idx + 10'd1;
                            gemv_phase_offset <= gemv_phase_offset + ({56'd0, gemv_burst_length} << 5);
                            if (remaining_tiles <= {2'd0, batch_space_eff})
                                remaining_tiles <= 10'd0;
                            else
                                remaining_tiles <= remaining_tiles - {2'd0, batch_space_eff};
                            if (gemv_phase_last) begin
                                gemv_proj_isa_done <= 1'b1;
                                fuse_out_done      <= 1'b1;
                                fuse_active        <= 1'b0;
                                fuse_state         <= FUSE_ST_IDLE;
                            end
                        end
                    end
                end
            end

            if (gemv_gqa) begin
                if (gqa_compute_stop) gqa_v_stop_latch <= 1'b1;

                if (!gqa_v_phase_busy && gqa_v_stop_latch) begin
                    gqa_v_phase_busy <= 1'b1;
                    gqa_v_stop_latch <= 1'b0;
                    gqa_v_emit_core  <= 6'd0;
                    gqa_v_emit_busy  <= 1'b0;
                    gqa_v_recv_cnt   <= 7'd0;
                    if(!fuse_active) fuse_start <= 1'b1;
                end

                if (gqa_v_phase_busy && !gqa_v_emit_busy) begin
                    gqa_v_emit_target <= ({1'b0, group_size} + {1'b0, decode_core_num} - 7'd1) / {1'b0, decode_core_num};
                    start_emit       <= ({{(CORE_NUM-1){1'b0}}, 1'b1} << gqa_v_emit_core);
                    gqa_v_emit_busy  <= 1'b1;
                    gqa_v_recv_cnt   <= 7'd0;
                end

                if (gqa_v_phase_busy && gqa_v_emit_busy && core_row_valid) begin
                    gqa_v_recv_cnt   <= gqa_v_recv_cnt + 7'd1;
                    gqa_v_token_acc  <= gqa_v_token_acc + 7'd1;
                    if (gqa_v_token_acc == 7'd3) begin
                        gqa_v_write_req    <= 1'b1;
                        gqa_v_write_tokens <= 4'd4;
                        gqa_v_token_acc    <= 7'd0;
                    end
                    if (gqa_v_recv_cnt == gqa_v_emit_target - 7'd1) begin
                        gqa_v_emit_busy <= 1'b0;
                        if (gqa_v_emit_core == decode_core_num - 6'd1) begin
                            gqa_v_phase_busy <= 1'b0;
                            gqa_v_phase_cnt  <= gqa_v_phase_cnt + 7'd1;
                            if (gqa_v_phase_cnt >= (kv_head_num == 7'd0 ? 7'd0
                                                                        : kv_head_num - 7'd1))
                                gqa_v_last_write_seed <= 1'b1;
                            if (gqa_v_token_acc != 7'd3) begin
                                if ((gqa_v_token_acc + 7'd1) != 7'd0) begin
                                    gqa_v_write_req    <= 1'b1;
                                    gqa_v_write_tokens <= gqa_v_token_acc[3:0] + 4'd1;
                                    gqa_v_token_acc    <= 7'd0;
                                end
                            end
                        end else begin
                            gqa_v_emit_core <= gqa_v_emit_core + 6'd1;
                        end
                    end
                end
            end

            if (is_mode_valid && gemm_gqa) begin
                if(gqa_compute_stop_latch) begin
                    gqa_gemm_delay_cnt <= gqa_gemm_delay_cnt + 3'd1;
                    if(gqa_gemm_delay_cnt == 3'd3) begin
                        gqa_gemm_delay_cnt <= 3'd0;
                        gqa_compute_stop_latch <= 1'b0;
                        if(!fuse_active) begin
                            fuse_start <= 1'b1;
                            emit_phase_active <= 1'b1;
                        end
                    end
                end else if(gqa_compute_stop) begin
                    gqa_compute_stop_latch <= 1'b1;
                end

                if(fuse_in_done_stop) begin
                    fuse_in_done_gqa_latch <= 1'b0;
                end else if (fuse_in_done_gqa_latch) begin
                    fuse_in_done_gqa_delay <= fuse_in_done_gqa_delay + 1'b1;
                    if(fuse_in_done_gqa_delay == 3'd7) begin
                        fuse_in_done_gqa_delay <= 0;
                        fuse_in_done_stop <= 1'b1;
                    end
                end else if (fuse_in_done) begin
                    fuse_in_done_gqa_latch <= 1'b1;
                end
            end

            case (fuse_state)
                FUSE_ST_IDLE: begin
                    fuse_in_vld_cnt <= 7'd0;
                    fuse_out_vld_cnt <= 7'd0;
                    fuse_in_idx <= {IDX_W{1'b0}};
                    fuse_out_idx <= {IDX_W{1'b0}};

                    if(fuse_start && is_mode_valid) begin
                        loop_cnt <= 7'd0;
                        fuse_active <= 1'b1;
                        transposer_in_out_vld_cnt <= 7'd0;
                        transposer_in_out_loop_cnt <= 9'd0;
                        case (fuse_mode)
                            GEMM_BYPASS, GEMV_BYPASS:               fuse_state <= FUSE_ST_BYPASS;
                            GEMM_PRERMS, GEMV_PRERMS:               fuse_state <= FUSE_ST_PRERMS;
                            GEMM_ROPE, GEMV_ROPE_Q, GEMV_ROPE_K:    fuse_state <= FUSE_ST_ROPE;
                            GEMM_RTQT:                              fuse_state <= FUSE_ST_RTQT;
                            GEMM_QT:                                fuse_state <= FUSE_ST_QT;
                            GEMM_SWIGLU, GEMV_SWIGLU:               fuse_state <= FUSE_ST_SWIGLU;
                            GEMM_TRANSPOSE:                         fuse_state <= FUSE_ST_TRANSPOSE;
                            default: fuse_active <= 1'b0;
                        endcase
                        if(gemm_gqa) fuse_state <= FUSE_ST_GQA;
                    end
                end

                FUSE_ST_BYPASS: begin
                    if (core_row_valid) begin
                        emit_vld <= 1'b1;
                        emit_data <= core_row_data;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if (fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_vld_cnt <= 0;
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if(is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                    end
                end

                FUSE_ST_PRERMS: begin
                    if (core_row_valid) begin
                        if (is_gemm_mode) begin
                            fuse_in_vld <= 1'b1;
                            fuse_in_row <= core_row_data;
                            prerms_core_group <= emit_cnt >> $clog2(GEMM_W_XFERS);
                            prerms_in_last <= (fuse_in_vld_cnt == BLOCK_ROW-1 &&
                                               emit_cnt == CORE_NUM-1 &&
                                               prerms_phase_cnt == phase_num-1);
                            fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                            if(fuse_in_vld_cnt == BLOCK_ROW-1) begin
                                fuse_in_vld_cnt <= 0;
                                fuse_in_done <= 1'b1;
                            end
                        end else begin
                            emit_vld  <= 1'b1;
                            emit_data <= core_row_data;
                        end
                    end

                    if(is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                        prerms_phase_cnt <= prerms_phase_cnt + 1'b1;
                        if(prerms_phase_cnt == phase_num-1) begin
                            prerms_phase_cnt <= 0;
                        end
                    end

                    emit_vld <= core_row_valid;
                    emit_data <= core_row_data;
                end

                FUSE_ST_SWIGLU: begin
                    if (core_row_valid) begin
                        fuse_in_vld <= 1'b1;
                        swig_fuse_in_vld <= 1'b1;
                        swig_gate_row <= core_row_data;
                        swig_val_row <= core_row_data_swig_val;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if(fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_vld_cnt <= 0;
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if (is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                    end

                    if (is_gemm_mode) begin
                        emit_vld <= swig_out_vld;
                        emit_data <= swig_out_row;
                    end
                end

                FUSE_ST_ROPE: begin
                    if (core_row_valid) begin
                        fuse_in_vld <= 1'b1;
                        fuse_in_row <= core_row_data;
                        cur_rope_token_pos <= !is_gemm_mode ? rope_token_pos :
                                          (rope_token_row_phase_cnt << 9) + (((emit_cnt-1) & 5'b00011) << 7) + fuse_in_vld_cnt + rope_token_pos;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if(fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_vld_cnt <= 7'd0;
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if(is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                        rope_phase_cnt <= rope_phase_cnt + 1'b1;
                        if(rope_phase_cnt == phase_num-1) begin
                            rope_phase_cnt <= 0;
                            rope_token_row_phase_cnt <= rope_token_row_phase_cnt + 1'b1;
                        end
                    end

                    emit_vld <= rope_out_vld;
                    emit_data <= rope_out_row;
                end

                FUSE_ST_QT: begin
                    if (core_row_valid) begin
                        fuse_in_vld <= 1'b1;
                        fuse_in_row <= core_row_data;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if (fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_vld_cnt <= 7'd0;
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if (is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                    end
                end

                FUSE_ST_RTQT: begin
                    if (core_row_valid) begin
                        fuse_in_vld <= 1'b1;
                        fuse_in_row <= core_row_data;
                        cur_rope_token_pos <= !is_gemm_mode ? rope_token_pos :
                                          (rope_token_row_phase_cnt << 9) + (((emit_cnt-1) & 5'b00011) << 7) + fuse_in_vld_cnt + rope_token_pos;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if(fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_vld_cnt <= 7'd0;
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if(is_gemm_mode && all_core_emit_done) begin
                        fuse_out_done <= 1'b1;
                        fuse_active <= 1'b0;
                        fuse_state <= FUSE_ST_IDLE;
                        rope_phase_cnt <= rope_phase_cnt + 1'b1;
                        if(rope_phase_cnt == phase_num-1) begin
                            rope_phase_cnt <= 0;
                            rope_token_row_phase_cnt <= rope_token_row_phase_cnt + 1'b1;
                        end
                    end
                end

                FUSE_ST_TRANSPOSE: begin
                    if (core_row_valid) begin
                        fuse_in_vld <= 1'b1;
                        fuse_in_row <= core_row_data;
                        fuse_in_vld_cnt <= fuse_in_vld_cnt + 7'd1;
                        if (fuse_in_vld_cnt == BLOCK_ROW-1 && is_gemm_mode) begin
                            fuse_in_done <= 1'b1;
                        end
                    end

                    if (is_gemm_mode && transposer_in_out_vld) begin
                        transposer_in_out_vld_cnt <= transposer_in_out_vld_cnt + 7'd1;
                        if (transposer_in_out_vld_cnt == BLOCK_ROW-1) begin
                            transposer_in_out_vld_cnt <= 0;
                            transposer_in_out_loop_cnt <= transposer_in_out_loop_cnt + 1'b1;
                            transposer_in_start_write <= 1'b1;
                            if (transposer_in_out_loop_cnt == CORE_NUM-1) begin
                                transposer_in_start_write <= 1'b0;
                                fuse_out_done <= 1'b1;
                                fuse_active <= 1'b0;
                                fuse_state <= FUSE_ST_IDLE;
                            end
                        end
                    end
                end

                FUSE_ST_GQA     : begin
                    if(!fuse_in_done_gqa_latch && !fuse_in_done && emit_phase_active) begin
                        fuse_gqa_cnt <= fuse_gqa_cnt + 1'b1;
                        start_emit <= fuse_gqa_cnt[$clog2(2*HEAD_ROW_NUM_PER_CORE)-1:0] == 0 ? ({{(CORE_NUM-1){1'b0}}, 1'b1} << gqa_core_cnt) : {CORE_NUM{1'b0}};
                    end

                    if(fuse_gqa_cnt[$clog2(2*HEAD_ROW_NUM_PER_CORE)-1:0] == 2*HEAD_ROW_NUM_PER_CORE-1) begin
                        gqa_core_cnt <= gqa_core_cnt + 1'b1;
                        if(gqa_core_cnt == CORE_NUM-1) begin
                            fuse_in_done <= 1'b1;
                            gqa_core_cnt <= 0;
                            fuse_gqa_cnt <= 0;
                            gqa_head_cnt <= gqa_head_cnt + 1'b1;
                            if(gqa_head_cnt == group_size-1) begin
                                fuse_in_done <= 1'b0;
                                gqa_head_cnt <= 0;
                                emit_phase_active <= 1'b0;
                                all_core_emit_done <= 1'b1;
                            end
                        end
                    end

                    if(core_row_valid) begin
                        fuse_out_vld_cnt <= fuse_out_vld_cnt + 7'd1;
                        if (fuse_out_vld_cnt == BLOCK_ROW-1) begin
                            fuse_out_vld_cnt <= 0;
                            gqa_data_head_cnt <= gqa_data_head_cnt + 7'd1;
                            if (gqa_data_head_cnt < group_size - 1) gqa_gemm_start_write <= 1'b1;
                            else if(gqa_data_head_cnt == group_size - 1) begin
                                fuse_out_vld_cnt <= 7'd0;
                                fuse_out_done <= 1'b1;
                                gqa_gemm_start_write <= 1'b0;
                                fuse_active <= 1'b0;
                                fuse_state <= FUSE_ST_IDLE;
                                gqa_gemm_out_done <= 1'b1;
                                gqa_data_head_cnt <= 7'd0;
                            end
                        end
                    end

                    emit_vld <= core_row_valid;
                    emit_data <= core_row_data;
                end

            endcase

            if (gemv_swiglu && swig_out_vld) begin
                emit_vld  <= 1'b1;
                emit_data <= swig_out_row;
            end

            if(is_mode_valid && fuse_mode == GEMM_RTQT) begin
                emit_vld <= quant_out_vld || (k_only_quant_decode && rope_out_vld);
                emit_data <= quant_out_vld ? quant_out_row :
                            (k_only_quant_decode && rope_out_vld) ? rope_out_row :
                            {ROW_WIDTH{1'b0}};
            end else if(is_mode_valid && fuse_mode == GEMM_QT) begin
                emit_vld <= quant_out_vld;
                emit_data <= quant_out_vld ? quant_out_row : {ROW_WIDTH{1'b0}};
            end else if(is_mode_valid && fuse_mode == GEMM_TRANSPOSE) begin
                emit_vld <= transposer_in_out_vld;
                emit_data <= transposer_in_out_vld ? transposer_in_out_row : {ROW_WIDTH{1'b0}};
            end else if(is_mode_valid && fuse_mode == GEMM_PRERMS) begin
                if(rms_out_vld) begin
                    emit_vld <= 1'b1;
                    emit_data <= rms_out_data;
                end
            end else if(is_mode_valid && !is_gemm_mode &&
                        (fuse_mode == GEMV_ROPE_Q || fuse_mode == GEMV_ROPE_K)) begin
                emit_vld  <= rope_out_vld;
                emit_data <= rope_out_vld ? rope_out_row : {ROW_WIDTH{1'b0}};
            end
        end
    end

    reg [ADDR_WIDTH-1:0] base_addr1;
    reg [ADDR_WIDTH-1:0] base_addr2;
    reg [ADDR_WIDTH-1:0] base_addr3;
    reg [ADDR_WIDTH-1:0] base_addr4;
    reg [ADDR_WIDTH-1:0] base_addr5;
    reg [ADDR_WIDTH-1:0] base_addr6;
    reg [ADDR_WIDTH-1:0] rms_base_addr;

    reg [5:0]  fuse_in_done_cnt;
    reg [15:0] channel_phase_cnt;

    reg [5:0]  token_dense_tile_cnt;
    reg [15:0] token_dense_phase_cnt;
    reg [15:0] prefill_dense_phase_cnt;
    reg [15:0] decode_dense_phase_cnt;
    reg [15:0] fp_scale_zp_phase_cnt;
    reg [15:0] int_scale_zp_phase_cnt;
    reg [15:0] outlier_pos_phase_cnt;
    reg [15:0] outlier_val_phase_cnt;

    reg [5:0]  prefill_tile_cnt;
    reg [5:0]  decode_tile_cnt;
    reg [5:0]  fp_scale_zp_tile_cnt;
    reg [5:0]  int_scale_zp_tile_cnt;
    reg [5:0]  outlier_pos_tile_cnt [0:GEMM_W_XFERS-1];
    reg [5:0]  outlier_pos_col_cnt;
    reg [5:0]  outlier_val_tile_cnt [0:GEMM_W_XFERS-1];
    reg [5:0]  outlier_val_col_cnt;
    integer    oi;
    reg [24:0] seq_len_tile_cnt;

    wire [1:0] prefill_tk_row      = prefill_tile_cnt[$clog2(GEMM_A_XFERS)-1:0];
    wire [2:0] prefill_tk_col      = prefill_tile_cnt[$clog2(GEMM_W_XFERS)+$clog2(GEMM_A_XFERS)-1:$clog2(GEMM_A_XFERS)];
    wire [1:0] decode_tk_row       = decode_tile_cnt[$clog2(GEMM_A_XFERS)-1:0];
    wire [2:0] decode_tk_col       = decode_tile_cnt[$clog2(GEMM_W_XFERS)+$clog2(GEMM_A_XFERS)-1:$clog2(GEMM_A_XFERS)];

    reg [7:0]  latched_dense_burst;
    reg [7:0]  latched_prefill_burst;
    reg [7:0]  latched_decode_burst;
    reg [7:0]  latched_scale_zp_burst;
    reg [7:0]  latched_outlier_burst;
    reg [7:0]  latched_rms_burst;

    reg [2:0]  start_write_hold_cnt;

    reg        gemm_proj_start_write;
    reg        rms_start_write_d1;
    reg        prefill_start_write_d1;
    reg        decode_start_write_d1;
    reg        fp_scale_zp_start_write_d1;
    reg        int_scale_zp_start_write_d1;
    reg        outlier_pos_start_write_d1;
    reg        outlier_val_start_write_d1;
    reg [1:0]  outlier_val_burst_length_d1;
    reg [$clog2(GEMM_W_XFERS)-1:0] outlier_pos_emit_bundle_d1;
    reg [$clog2(GEMM_W_XFERS)-1:0] outlier_val_emit_bundle_d1;

    wire is_token_dir_mode = (fuse_mode == GEMM_ROPE) || (fuse_mode == GEMM_RTQT) ||
                             (fuse_mode == GEMM_QT)   || (fuse_mode == GEMM_TRANSPOSE);
    wire is_channel_dir_mode = (fuse_mode == GEMM_BYPASS) || (fuse_mode == GEMM_PRERMS) ||
                               (fuse_mode == GEMM_SWIGLU) || (is_gemm_mode && !is_proj_mode);

    wire [2:0] ch_col = fuse_in_done_cnt[W_SHIFT_S-1:0] & {3{(W_SHIFT_C != 5'd0)}};
    wire [2:0] ch_row = fuse_in_done_cnt[A_SHIFT_S+W_SHIFT_C-1:W_SHIFT_C] & {3{(A_SHIFT_C != 5'd0)}};

    wire [1:0] tk_row = token_dense_tile_cnt[$clog2(GEMM_A_XFERS)-1:0];
    wire [2:0] tk_col = token_dense_tile_cnt[$clog2(GEMM_W_XFERS)+$clog2(GEMM_A_XFERS)-1:$clog2(GEMM_A_XFERS)];

    wire gqa_gemm_start_write_wire = is_mode_valid && is_gemm_mode && !is_proj_mode && (fuse_start || gqa_gemm_start_write);

    wire [31:0] gqa_word_off_w = gqa_wr_cnt * seq_len;
    wire [ADDR_WIDTH-1:0] gqa_write_addr_w = dest_addr1 + ({{(ADDR_WIDTH-32){1'b0}}, gqa_word_off_w} << 5);
    reg gqa_gemm_start_write_d1, gqa_gemm_start_write_d2, gqa_gemm_start_write_d3, gqa_gemm_start_write_d4,
        gqa_gemm_start_write_d5, gqa_gemm_start_write_d6, gqa_gemm_start_write_d7;
    reg transposer_in_start_write_d1, transposer_in_start_write_d2, transposer_in_start_write_d3, transposer_in_start_write_d4,
        transposer_in_start_write_d5, transposer_in_start_write_d6, transposer_in_start_write_d7;
    reg fuse_in_done_d1, fuse_in_done_d2, fuse_in_done_d3, fuse_in_done_d4,
        fuse_in_done_d5, fuse_in_done_d6, fuse_in_done_d7;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            fuse_in_done_d1            <= 1'b0;
            fuse_in_done_d2            <= 1'b0;
            fuse_in_done_d3            <= 1'b0;
            fuse_in_done_d4            <= 1'b0;
            fuse_in_done_d5            <= 1'b0;
            fuse_in_done_d6            <= 1'b0;
            fuse_in_done_d7            <= 1'b0;
            gemm_proj_start_write            <= 1'b0;
            rms_start_write_d1         <= 1'b0;
            prefill_start_write_d1     <= 1'b0;
            decode_start_write_d1      <= 1'b0;
            fp_scale_zp_start_write_d1 <= 1'b0;
            int_scale_zp_start_write_d1<= 1'b0;
            outlier_pos_start_write_d1 <= 1'b0;
            outlier_val_start_write_d1 <= 1'b0;
            outlier_val_burst_length_d1<= 1'b0;
            outlier_pos_emit_bundle_d1 <= {$clog2(GEMM_W_XFERS){1'b0}};
            outlier_val_emit_bundle_d1 <= {$clog2(GEMM_W_XFERS){1'b0}};
            gqa_gemm_start_write_d1    <= 1'b0;
            gqa_gemm_start_write_d2    <= 1'b0;
            gqa_gemm_start_write_d3    <= 1'b0;
            gqa_gemm_start_write_d4    <= 1'b0;
            gqa_gemm_start_write_d5    <= 1'b0;
            gqa_gemm_start_write_d6    <= 1'b0;
            gqa_gemm_start_write_d7    <= 1'b0;
            transposer_in_start_write_d1 <= 1'b0;
            transposer_in_start_write_d2 <= 1'b0;
            transposer_in_start_write_d3 <= 1'b0;
            transposer_in_start_write_d4 <= 1'b0;
            transposer_in_start_write_d5 <= 1'b0;
            transposer_in_start_write_d6 <= 1'b0;
            transposer_in_start_write_d7 <= 1'b0;

            gemv_write_req_d1 <= 1'b0; gemv_write_req_d2 <= 1'b0;
            gemv_write_req_d3 <= 1'b0; gemv_write_req_d4 <= 1'b0;
            gemv_write_req_d5 <= 1'b0; gemv_write_req_d6 <= 1'b0;
            gemv_write_req_d7 <= 1'b0; gemv_write_req_d8 <= 1'b0;
            gqa_v_write_req_d1 <= 1'b0; gqa_v_write_req_d2 <= 1'b0;
            gqa_v_write_req_d3 <= 1'b0; gqa_v_write_req_d4 <= 1'b0;
            gqa_v_write_req_d5 <= 1'b0; gqa_v_write_req_d6 <= 1'b0;
            gqa_v_write_req_d7 <= 1'b0; gqa_v_write_req_d8 <= 1'b0;
            gqa_v_last_beat_d1 <= 1'b0; gqa_v_last_beat_d2 <= 1'b0;
            gqa_v_last_beat_d3 <= 1'b0; gqa_v_last_beat_d4 <= 1'b0;
            gqa_v_last_beat_d5 <= 1'b0; gqa_v_last_beat_d6 <= 1'b0;
            gqa_v_last_beat_d7 <= 1'b0; gqa_v_last_beat_d8 <= 1'b0;

        end else begin
            gemm_proj_start_write      <= start_emit != {CORE_NUM{1'b0}};
            rms_start_write_d1         <= rms_start_write;
            prefill_start_write_d1     <= prefill_start_write;
            decode_start_write_d1      <= quant_top_decode_start_write;
            fp_scale_zp_start_write_d1 <= quant_top_fp_scale_zp_start_write;
            int_scale_zp_start_write_d1<= quant_top_int_scale_zp_start_write;
            outlier_pos_start_write_d1 <= quant_top_outlier_pos_start_write;
            outlier_val_start_write_d1 <= quant_top_outlier_val_start_write;
            outlier_val_burst_length_d1<= quant_top_outlier_val_burst_length;
            outlier_pos_emit_bundle_d1 <= quant_top_outlier_pos_emit_bundle;
            outlier_val_emit_bundle_d1 <= quant_top_outlier_val_emit_bundle;
            gqa_gemm_start_write_d1    <= gqa_gemm_start_write_wire;
            gqa_gemm_start_write_d2    <= gqa_gemm_start_write_d1;
            gqa_gemm_start_write_d3    <= gqa_gemm_start_write_d2;
            gqa_gemm_start_write_d4    <= gqa_gemm_start_write_d3;
            gqa_gemm_start_write_d5    <= gqa_gemm_start_write_d4;
            gqa_gemm_start_write_d6    <= gqa_gemm_start_write_d5;
            gqa_gemm_start_write_d7    <= gqa_gemm_start_write_d6;
            transposer_in_start_write_d1 <= transposer_in_start_write || fuse_start;
            transposer_in_start_write_d2 <= transposer_in_start_write_d1;
            transposer_in_start_write_d3 <= transposer_in_start_write_d2;
            transposer_in_start_write_d4 <= transposer_in_start_write_d3;
            transposer_in_start_write_d5 <= transposer_in_start_write_d4;
            transposer_in_start_write_d6 <= transposer_in_start_write_d5;
            transposer_in_start_write_d7 <= transposer_in_start_write_d6;
            gemv_write_req_d1 <= gemv_write_req;       gemv_write_addr_d[1] <= gemv_write_addr_pip;  gemv_write_burst_d[1] <= gemv_write_burst_pip; gemv_write_zpad_d[1] <= gemv_write_zpad_pip;
            gemv_write_req_d2 <= gemv_write_req_d1;    gemv_write_addr_d[2] <= gemv_write_addr_d[1]; gemv_write_burst_d[2] <= gemv_write_burst_d[1]; gemv_write_zpad_d[2] <= gemv_write_zpad_d[1];
            gemv_write_req_d3 <= gemv_write_req_d2;    gemv_write_addr_d[3] <= gemv_write_addr_d[2]; gemv_write_burst_d[3] <= gemv_write_burst_d[2]; gemv_write_zpad_d[3] <= gemv_write_zpad_d[2];
            gemv_write_req_d4 <= gemv_write_req_d3;    gemv_write_addr_d[4] <= gemv_write_addr_d[3]; gemv_write_burst_d[4] <= gemv_write_burst_d[3]; gemv_write_zpad_d[4] <= gemv_write_zpad_d[3];
            gemv_write_req_d5 <= gemv_write_req_d4;    gemv_write_addr_d[5] <= gemv_write_addr_d[4]; gemv_write_burst_d[5] <= gemv_write_burst_d[4]; gemv_write_zpad_d[5] <= gemv_write_zpad_d[4];
            gemv_write_req_d6 <= gemv_write_req_d5;    gemv_write_addr_d[6] <= gemv_write_addr_d[5]; gemv_write_burst_d[6] <= gemv_write_burst_d[5]; gemv_write_zpad_d[6] <= gemv_write_zpad_d[5];
            gemv_write_req_d7 <= gemv_write_req_d6;    gemv_write_addr_d[7] <= gemv_write_addr_d[6]; gemv_write_burst_d[7] <= gemv_write_burst_d[6]; gemv_write_zpad_d[7] <= gemv_write_zpad_d[6];
            gemv_write_req_d8 <= gemv_write_req_d7;    gemv_write_addr_d[8] <= gemv_write_addr_d[7]; gemv_write_burst_d[8] <= gemv_write_burst_d[7]; gemv_write_zpad_d[8] <= gemv_write_zpad_d[7];

            gqa_v_write_req_d1 <= gqa_v_write_req;     gqa_v_write_tokens_d[1] <= gqa_v_write_tokens; gqa_v_write_addr_d[1] <= gqa_v_write_addr;
            gqa_v_write_req_d2 <= gqa_v_write_req_d1;  gqa_v_write_tokens_d[2] <= gqa_v_write_tokens_d[1]; gqa_v_write_addr_d[2] <= gqa_v_write_addr_d[1];
            gqa_v_write_req_d3 <= gqa_v_write_req_d2;  gqa_v_write_tokens_d[3] <= gqa_v_write_tokens_d[2]; gqa_v_write_addr_d[3] <= gqa_v_write_addr_d[2];
            gqa_v_write_req_d4 <= gqa_v_write_req_d3;  gqa_v_write_tokens_d[4] <= gqa_v_write_tokens_d[3]; gqa_v_write_addr_d[4] <= gqa_v_write_addr_d[3];
            gqa_v_write_req_d5 <= gqa_v_write_req_d4;  gqa_v_write_tokens_d[5] <= gqa_v_write_tokens_d[4]; gqa_v_write_addr_d[5] <= gqa_v_write_addr_d[4];
            gqa_v_write_req_d6 <= gqa_v_write_req_d5;  gqa_v_write_tokens_d[6] <= gqa_v_write_tokens_d[5]; gqa_v_write_addr_d[6] <= gqa_v_write_addr_d[5];
            gqa_v_write_req_d7 <= gqa_v_write_req_d6;  gqa_v_write_tokens_d[7] <= gqa_v_write_tokens_d[6]; gqa_v_write_addr_d[7] <= gqa_v_write_addr_d[6];
            gqa_v_write_req_d8 <= gqa_v_write_req_d7;  gqa_v_write_tokens_d[8] <= gqa_v_write_tokens_d[7]; gqa_v_write_addr_d[8] <= gqa_v_write_addr_d[7];
            gqa_v_last_beat_d1 <= gqa_v_last_write_seed;
            gqa_v_last_beat_d2 <= gqa_v_last_beat_d1;
            gqa_v_last_beat_d3 <= gqa_v_last_beat_d2;
            gqa_v_last_beat_d4 <= gqa_v_last_beat_d3;
            gqa_v_last_beat_d5 <= gqa_v_last_beat_d4;
            gqa_v_last_beat_d6 <= gqa_v_last_beat_d5;
            gqa_v_last_beat_d7 <= gqa_v_last_beat_d6;
            gqa_v_last_beat_d8 <= gqa_v_last_beat_d7;
        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            start_write         <= 1'b0;
            cmd_is_code         <= 1'b0;
            write_burst_length  <= 8'd0;
            write_init_addr     <= {ADDR_WIDTH{1'b0}};
            start_write_hold_cnt<= 3'd0;

            base_addr1          <= {ADDR_WIDTH{1'b0}};
            base_addr2          <= {ADDR_WIDTH{1'b0}};
            base_addr3          <= {ADDR_WIDTH{1'b0}};
            base_addr4          <= {ADDR_WIDTH{1'b0}};
            base_addr5          <= {ADDR_WIDTH{1'b0}};
            base_addr6          <= {ADDR_WIDTH{1'b0}};
            rms_base_addr       <= {ADDR_WIDTH{1'b0}};

            fuse_in_done_cnt    <= 6'd0;
            channel_phase_cnt   <= 16'd0;

            token_dense_tile_cnt  <= 6'd0;
            token_dense_phase_cnt <= 16'd0;
            prefill_dense_phase_cnt <= 16'd0;
            decode_dense_phase_cnt  <= 16'd0;
            fp_scale_zp_phase_cnt   <= 16'd0;
            int_scale_zp_phase_cnt  <= 16'd0;
            outlier_pos_phase_cnt   <= 16'd0;
            outlier_val_phase_cnt   <= 16'd0;

            prefill_tile_cnt    <= 6'd0;
            decode_tile_cnt     <= 6'd0;
            fp_scale_zp_tile_cnt<= 6'd0;
            int_scale_zp_tile_cnt<=6'd0;
            for (oi=0; oi<GEMM_W_XFERS; oi=oi+1) begin
                outlier_pos_tile_cnt[oi] <= 6'd0;
                outlier_val_tile_cnt[oi] <= 6'd0;
            end
            outlier_pos_col_cnt <= 6'd0;
            outlier_val_col_cnt <= 6'd0;
            seq_len_tile_cnt    <= 25'd0;

            latched_dense_burst   <= 8'd0;
            latched_prefill_burst <= 8'd0;
            latched_decode_burst  <= 8'd0;
            latched_scale_zp_burst<= 8'd0;
            latched_outlier_burst <= 8'd0;
            latched_rms_burst     <= 8'd0;
        end else begin

            if (isa_valid) begin
                base_addr1          <= dest_addr1;
                base_addr2          <= dest_addr2;
                base_addr3          <= dest_addr1;
                base_addr4          <= dest_addr2;
                base_addr5          <= dest_addr2;
                base_addr6          <= dest_addr2;
                rms_base_addr       <= dest_addr2;

                fuse_in_done_cnt    <= 6'd0;
                channel_phase_cnt   <= 16'd0;
                token_dense_tile_cnt  <= 6'd0;
                token_dense_phase_cnt <= 16'd0;
                prefill_dense_phase_cnt <= 16'd0;
                decode_dense_phase_cnt  <= 16'd0;
                fp_scale_zp_phase_cnt   <= 16'd0;
                int_scale_zp_phase_cnt  <= 16'd0;
                outlier_pos_phase_cnt   <= 16'd0;
                outlier_val_phase_cnt   <= 16'd0;

                prefill_tile_cnt    <= 6'd0;
                decode_tile_cnt     <= 6'd0;
                fp_scale_zp_tile_cnt<= 6'd0;
                int_scale_zp_tile_cnt<=6'd0;
                for (oi=0; oi<GEMM_W_XFERS; oi=oi+1) begin
                    outlier_pos_tile_cnt[oi] <= 6'd0;
                    outlier_val_tile_cnt[oi] <= 6'd0;
                end
                outlier_pos_col_cnt <= 6'd0;
                outlier_val_col_cnt <= 6'd0;
                seq_len_tile_cnt    <= 25'd0;

                latched_dense_burst   <= 8'd32;
                latched_prefill_burst <= 8'd0;
                latched_decode_burst  <= 8'd0;
                latched_scale_zp_burst<= 8'd0;
                latched_outlier_burst <= 8'd0;
                latched_rms_burst     <= 8'd0;
            end

            start_write <= 1'b0;
            cmd_is_code <= 1'b0;

            if (gemm_proj_start_write && gemm_proj && is_channel_dir_mode && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_dense_burst <= dense_burst_length;
                write_burst_length <= dense_burst_length;
                write_init_addr    <= base_addr1 + {42'd0, ({10'd0, ch_row} * {2'd0, output_dim_tile_num}), 10'd0}
                                                 + {51'd0, ch_col, 10'd0};

                fuse_in_done_cnt <= fuse_in_done_cnt + 6'd1;
                if (fuse_in_done_cnt == (fuse_mode == GEMM_SWIGLU ? (CORE_NUM/2-1) : (CORE_NUM-1))) begin
                    fuse_in_done_cnt <= 6'd0;
                    channel_phase_cnt <= channel_phase_cnt + 16'd1;
                    base_addr1 <= base_addr1 + 11'd1024 * GEMM_W_XFERS;
                    if (channel_phase_cnt == phase_num - 16'd1) begin
                        channel_phase_cnt <= 16'd0;
                        base_addr1 <= dest_addr1 + {output_dim_tile_num, {$clog2(GEMM_A_XFERS){1'b0}}, 10'd0};
                    end
                end
            end

            if (gemm_proj_start_write && is_gemm_mode && fuse_mode == GEMM_ROPE && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_dense_burst <= dense_burst_length;
                write_burst_length <= dense_burst_length;
                write_init_addr    <= base_addr1
                                    + (qkv_head_addr_offset * {61'd0, tk_col})
                                    + {49'd0, ({8'd0, tk_row} * {2'd0, dense_burst_length}), 5'd0};

                token_dense_tile_cnt <= token_dense_tile_cnt + 6'd1;
                if (token_dense_tile_cnt == CORE_NUM-1) begin
                    token_dense_tile_cnt <= 6'd0;
                    token_dense_phase_cnt <= token_dense_phase_cnt + 16'd1;
                    base_addr1 <= base_addr1 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if (token_dense_phase_cnt == phase_num - 16'd1) begin
                        token_dense_phase_cnt <= 16'd0;
                        base_addr1 <= base_addr1 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + {49'd0, dense_burst_length, {$clog2(GEMM_A_XFERS){1'b0}}, 5'd0};
                    end
                end
            end

            if (transposer_in_start_write_d7 && is_gemm_mode && fuse_mode == GEMM_TRANSPOSE && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_dense_burst <= dense_burst_length;
                write_burst_length <= dense_burst_length;
                write_init_addr    <= base_addr1
                                    + (qkv_head_addr_offset * {61'd0, tk_col})
                                    + {49'd0, ({8'd0, tk_row} * {2'd0, dense_burst_length}), 5'd0};

                token_dense_tile_cnt <= token_dense_tile_cnt + 6'd1;
                if (token_dense_tile_cnt == CORE_NUM-1) begin
                    token_dense_tile_cnt <= 6'd0;
                    token_dense_phase_cnt <= token_dense_phase_cnt + 16'd1;
                    base_addr1 <= base_addr1 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if (token_dense_phase_cnt == phase_num - 16'd1) begin
                        token_dense_phase_cnt <= 16'd0;
                        base_addr1 <= base_addr1 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + {49'd0, dense_burst_length, {$clog2(GEMM_A_XFERS){1'b0}}, 5'd0};
                    end
                end
            end

            if (prefill_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_prefill_burst <= KV_prefill_burst_length;
                write_burst_length <= KV_prefill_burst_length;
                write_init_addr    <= base_addr1
                                    + (qkv_head_addr_offset * {61'd0, prefill_tk_col})
                                    + (group_width != 2'b01 ? fp_scale_zp_addr_offset_per_bundle :
                                       prefill_tk_row < 2'd2 ? (fp_scale_zp_addr_offset_per_bundle >> 1) : fp_scale_zp_addr_offset_per_bundle)
                                    + fp_kv_tile_addr_offset * (2*prefill_tk_row + (fuse_mode == GEMM_RTQT ? 1'b0 : 1'b1));

                prefill_tile_cnt <= prefill_tile_cnt + 6'd1;
                if (prefill_tile_cnt == CORE_NUM-1) begin
                    prefill_tile_cnt <= 6'd0;
                    prefill_dense_phase_cnt <= prefill_dense_phase_cnt + 16'd1;
                    base_addr1 <= base_addr1 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if (prefill_dense_phase_cnt == phase_num - 16'd1) begin
                        prefill_dense_phase_cnt <= 16'd0;
                        base_addr1 <= base_addr1 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + prefill_bundle_addr_offset;
                    end
                end
            end

            if (decode_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                cmd_is_code        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_decode_burst <= KV_decode_burst_length;
                write_burst_length <= KV_decode_burst_length;
                write_init_addr    <= base_addr2
                                    + (qkv_head_addr_offset * {61'd0, decode_tk_col})
                                    + (group_width != 2'b01 ? int_scale_zp_addr_offset_per_bundle :
                                       decode_tk_row < 2'd2 ? (int_scale_zp_addr_offset_per_bundle >> 1) : int_scale_zp_addr_offset_per_bundle)
                                    + outlier_pos_addr_offset_per_bundle
                                    + outlier_val_addr_offset_per_bundle
                                    + int_kv_tile_addr_offset * (2*decode_tk_row + (fuse_mode == GEMM_RTQT ? 1'b0 : 1'b1));

                decode_tile_cnt <= decode_tile_cnt + 6'd1;
                if (decode_tile_cnt == CORE_NUM-1) begin
                    decode_tile_cnt <= 6'd0;
                    decode_dense_phase_cnt <= decode_dense_phase_cnt + 16'd1;
                    base_addr2 <= base_addr2 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if (decode_dense_phase_cnt == phase_num - 16'd1) begin
                        decode_dense_phase_cnt <= 16'd0;
                        base_addr2 <= base_addr2 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + decode_bundle_addr_offset;
                    end
                end
            end

            if (fp_scale_zp_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_scale_zp_burst <= scale_zp_burst_length;
                write_burst_length <= scale_zp_burst_length;
                write_init_addr    <= base_addr3
                                    + (qkv_head_addr_offset * (group_width == 2'b01 ? fp_scale_zp_tile_cnt[5:1] : fp_scale_zp_tile_cnt))
                                    + (fuse_mode == GEMM_RTQT ? 0 : (group_width == 2'b01 ? (fp_scale_zp_addr_offset_per_bundle >> 2) : (fp_scale_zp_addr_offset_per_bundle >> 1)))
                                    + ((group_width == 2'b01 && fp_scale_zp_tile_cnt[0] )? fp_scale_zp2_addr_offset : 0);

                fp_scale_zp_tile_cnt <= fp_scale_zp_tile_cnt + 6'd1;
                if (fp_scale_zp_tile_cnt == (group_width == 2'b01 ? 6'd15 : 6'd7)) begin
                    fp_scale_zp_tile_cnt <= 6'd0;
                    fp_scale_zp_phase_cnt <= fp_scale_zp_phase_cnt + 16'd1;
                    base_addr3 <= base_addr3 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if(fp_scale_zp_phase_cnt == phase_num - 16'd1) begin
                        fp_scale_zp_phase_cnt <= 16'd0;
                        base_addr3 <= base_addr3 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + prefill_bundle_addr_offset;
                    end
                end
            end

            if (int_scale_zp_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_scale_zp_burst <= scale_zp_burst_length;
                write_burst_length <= scale_zp_burst_length;
                write_init_addr    <= base_addr4
                                    + (qkv_head_addr_offset * (group_width == 2'b01 ? int_scale_zp_tile_cnt[5:1] : int_scale_zp_tile_cnt))
                                    + outlier_pos_addr_offset_per_bundle
                                    + outlier_val_addr_offset_per_bundle
                                    + (fuse_mode == GEMM_RTQT ? 0 : (group_width == 2'b01 ? (int_scale_zp_addr_offset_per_bundle >> 2) : (int_scale_zp_addr_offset_per_bundle >> 1)))
                                    + ((group_width == 2'b01 && int_scale_zp_tile_cnt[0] )? int_scale_zp2_addr_offset : 0);

                int_scale_zp_tile_cnt <= int_scale_zp_tile_cnt + 6'd1;
                if (int_scale_zp_tile_cnt == (group_width == 2'b01 ? 6'd15 : 6'd7)) begin
                    int_scale_zp_tile_cnt <= 6'd0;
                    int_scale_zp_phase_cnt <= int_scale_zp_phase_cnt + 16'd1;
                    base_addr4 <= base_addr4 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    if(int_scale_zp_phase_cnt == phase_num - 16'd1) begin
                        int_scale_zp_phase_cnt <= 16'd0;
                        base_addr4 <= base_addr4 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + decode_bundle_addr_offset;
                    end
                end
            end

            if (outlier_pos_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_outlier_burst <= outlier_pos_burst_length;
                write_burst_length <= outlier_pos_burst_length;
                write_init_addr    <= base_addr5
                                    + (qkv_head_addr_offset * outlier_pos_emit_bundle_d1)
                                    + (outlier_pos_tile_cnt[outlier_pos_emit_bundle_d1] << 5);

                outlier_pos_tile_cnt[outlier_pos_emit_bundle_d1] <= outlier_pos_tile_cnt[outlier_pos_emit_bundle_d1] + 6'd1;
                if (outlier_pos_tile_cnt[outlier_pos_emit_bundle_d1] == (outlier_pos_addr_offset_per_bundle >> 5)-1) begin
                    outlier_pos_col_cnt <= outlier_pos_col_cnt + 1'b1;
                    if(outlier_pos_col_cnt == GEMM_W_XFERS-1) begin
                        outlier_pos_col_cnt <= 6'd0;
                        outlier_pos_phase_cnt <= outlier_pos_phase_cnt + 16'd1;
                        base_addr5 <= base_addr5 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                        for (oi=0; oi<GEMM_W_XFERS; oi=oi+1) outlier_pos_tile_cnt[oi] <= 6'd0;
                        if(outlier_pos_phase_cnt == phase_num - 16'd1) begin
                            outlier_pos_phase_cnt <= 16'd0;
                            base_addr5 <= base_addr5 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + decode_bundle_addr_offset;
                        end
                    end
                end
            end

            if (outlier_val_start_write_d1 && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT) && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_outlier_burst <= outlier_val_burst_length_d1;
                write_burst_length <= outlier_val_burst_length_d1;
                write_init_addr    <= base_addr6
                                    + outlier_pos_addr_offset_per_bundle
                                    + (qkv_head_addr_offset * outlier_val_emit_bundle_d1)
                                    + (outlier_val_tile_cnt[outlier_val_emit_bundle_d1] << 5);

                outlier_val_tile_cnt[outlier_val_emit_bundle_d1] <= outlier_val_tile_cnt[outlier_val_emit_bundle_d1] + {4'd0, outlier_val_burst_length_d1};
                outlier_val_col_cnt <= outlier_val_col_cnt + 1'b1;
                if(outlier_val_col_cnt == GEMM_W_XFERS-1) begin
                    outlier_val_col_cnt <= 6'd0;
                    outlier_val_phase_cnt <= outlier_val_phase_cnt + 16'd1;
                    base_addr6 <= base_addr6 + {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}};
                    for (oi=0; oi<GEMM_W_XFERS; oi=oi+1) outlier_val_tile_cnt[oi] <= 6'd0;
                    if(outlier_val_phase_cnt == phase_num - 16'd1) begin
                        outlier_val_phase_cnt <= 16'd0;
                        base_addr6 <= base_addr6 - (phase_num - 16'd1) * {qkv_head_addr_offset, {$clog2(GEMM_W_XFERS){1'b0}}} + decode_bundle_addr_offset;
                    end
                end
            end

            if (rms_start_write_d1 && fuse_mode == GEMM_PRERMS && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                latched_rms_burst  <= rms_burst_length;
                write_burst_length <= rms_burst_length;
                write_init_addr    <= rms_base_addr;
                rms_base_addr      <= rms_base_addr + 64'd32;
            end

            if (gqa_gemm_start_write_d7 && gemm_gqa && !start_write) begin
                start_write        <= 1'b1;
                start_write_hold_cnt <= 3'd0;
                write_burst_length <= 8'd32;
                write_init_addr    <= gqa_write_addr_w;
                if (gqa_wr_cnt == (CORE_NUM*group_size - 1))
                    gqa_wr_cnt <= 8'd0;
                else
                    gqa_wr_cnt <= gqa_wr_cnt + 8'd1;
                fuse_in_done_cnt <= fuse_in_done_cnt + 6'd1;
                if (fuse_in_done_cnt == group_size-1)
                    fuse_in_done_cnt <= 6'd0;
            end

            if (gemv_write_req_d8 && gemv_proj && !start_write) begin
                start_write        <= 1'b1;
                write_burst_length <= gemv_write_burst_d[8];
                write_init_addr    <= gemv_write_addr_d[8];
            end

            if (gqa_v_write_req_d8 && gemv_gqa && !start_write) begin
                start_write        <= 1'b1;
                write_burst_length <= 8'd1;
                write_init_addr    <= gqa_v_write_addr_d[8];
                gqa_v_write_addr   <= gqa_v_write_addr + {57'd0, gqa_v_write_tokens_d[8], 3'd0};
            end

        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) emit_is_code <= 1'b0;
        else        emit_is_code <= (is_mode_valid &&
                                     (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT)) &&
                                    quant_out_vld && quant_out_is_code;
    end

    reg [AXI_WORD_BITS-1:0] write_data_pip;
    reg [1:0] wdata_portion, wdata_portion_pip;
    reg [1:0] wrvalid_cnt;

    reg [AXI_WORD_BITS-1:0] rms_write_data_pip;
    reg [1:0] rms_wdata_portion;
    reg       rms_wrvalid_pending;

    reg [3:0] rms_write_delay_cnt;
    reg rms_out_vld_latch;
    reg gqa_gemm_done_flag;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            wrvalid <= 1'b0;
            wrvalid_cnt <= 2'b0;
            emit_vld_pip_gemv <= 1'b0;
            emit_vld_pip_gemm <= 1'b0;
            wdata_portion <= 2'b0;
            wdata_portion_pip <= 2'b0;
            write_data <= {AXI_WORD_BITS{1'b0}};
            write_data_pip <= {AXI_WORD_BITS{1'b0}};
            gqa_gemm_done_flag <= 1'b0;
            rms_out_vld_latch <= 1'b0;
            rms_write_delay_cnt <= 4'b0;
            rms_write_data_pip <= {AXI_WORD_BITS{1'b0}};
            rms_wdata_portion <= 2'b0;
            rms_wrvalid_pending <= 1'b0;
            gemv_wr_hold_cnt <= 5'd0;
            write_is_code <= 1'b0;
            beat_is_code  <= 1'b0;
        end else begin

            wrvalid <= 1'b0;
            write_is_code <= 1'b0;

            if (is_mode_valid && is_gemm_mode && fuse_mode != GEMM_PRERMS) begin
                if (emit_vld) begin
                    write_data_pip[ROW_WIDTH*wdata_portion +: ROW_WIDTH] <= emit_data;
                    wdata_portion <= (wdata_portion == GEMM_W_XFERS-1) ? 2'd0 : wdata_portion + 2'd1;
                    if (wdata_portion == 2'd0) beat_is_code <= emit_is_code;
                end
                emit_vld_pip_gemm <= emit_vld;
                wdata_portion_pip <= wdata_portion;

                if (emit_vld_pip_gemm && wdata_portion_pip == GEMM_W_XFERS-1) begin
                    wrvalid <= 1'b1;
                    write_data <= write_data_pip;
                    write_is_code <= beat_is_code;
                end

            end else if (is_mode_valid && fuse_mode == GEMM_PRERMS) begin
                if (emit_vld && is_gemm_mode) begin
                    write_data_pip[ROW_WIDTH*wdata_portion +: ROW_WIDTH] <= emit_data;
                    wdata_portion <= wdata_portion + 2'd1;
                end
                emit_vld_pip_gemm <= (emit_vld && is_gemm_mode);
                wdata_portion_pip <= wdata_portion;

                if (emit_vld_pip_gemm && wdata_portion_pip == 2'b11) begin
                    wrvalid <= 1'b1;
                    write_data <= write_data_pip;
                end

            end else if (is_mode_valid && gemv_proj) begin
                if (emit_vld) begin
                    write_data_pip[ROW_WIDTH*wdata_portion +: ROW_WIDTH] <= emit_data;
                    wdata_portion <= wdata_portion + 2'd1;
`ifdef RESPROBE
                    if (!is_gemm_mode)
                        $display("[DECPACK] t=%0t emit_data_lo=%h wdata_portion=%0d", $time, emit_data[15:0], wdata_portion);
`endif
                end
                emit_vld_pip_gemv <= emit_vld;
                wdata_portion_pip <= wdata_portion;

                if (emit_vld_pip_gemv && wdata_portion_pip == 2'b11) begin
                    wrvalid <= 1'b1;
                    write_data <= write_data_pip;
                    write_data_pip <= {AXI_WORD_BITS{1'b0}};
                end

                if (!is_gemm_mode &&
                    (fuse_mode == GEMV_ROPE_Q || fuse_mode == GEMV_ROPE_K ||
                     fuse_mode == GEMV_SWIGLU) &&
                    emit_vld_pip_gemv && wdata_portion != 2'b00 && gemv_wr_hold_cnt == 5'd0) begin
                    wrvalid          <= 1'b1;
                    write_data       <= write_data_pip;
                    write_data_pip   <= {AXI_WORD_BITS{1'b0}};
                    wdata_portion    <= 2'b00;
                    gemv_wr_hold_cnt <= 5'd16;
                end

                if (gemv_write_req_d8 && wdata_portion != 2'b00) begin
                    wrvalid    <= 1'b1;
                    write_data <= write_data_pip;
`ifdef RESPROBE
                    if (!is_gemm_mode)
                        $display("[DECFLUSH] t=%0t addr_word=%0d data_lo=%h wdata_portion=%0d", $time, gemv_write_addr_d[8]>>5, write_data_pip[15:0], wdata_portion);
`endif
                    write_data_pip <= {AXI_WORD_BITS{1'b0}};
                    wdata_portion  <= 2'b00;
                    gemv_wr_hold_cnt <= 5'd0;
                end else if (gemv_wr_hold_cnt != 5'd0) begin
                    wrvalid          <= 1'b1;
                    gemv_wr_hold_cnt <= gemv_wr_hold_cnt - 5'd1;
                end

            end else if (is_mode_valid && gemv_gqa) begin
                if (core_row_valid) begin
                    write_data_pip[ROW_WIDTH*wdata_portion +: ROW_WIDTH] <= core_row_data;
                    wdata_portion <= wdata_portion + 2'd1;
                end
                if (gqa_v_write_req) begin
                    wrvalid    <= 1'b1;
                    write_data <= write_data_pip;
                    write_data_pip <= {AXI_WORD_BITS{1'b0}};
                    wdata_portion  <= 2'b00;
                end

            end else begin
                wdata_portion <= 2'b0;
                wdata_portion_pip <= 2'b0;
                write_data_pip <= {AXI_WORD_BITS{1'b0}};
                rms_write_data_pip <= {AXI_WORD_BITS{1'b0}};
                rms_wdata_portion <= 2'b0;
                rms_wrvalid_pending <= 1'b0;
                gqa_gemm_done_flag <= 1'b0;
                emit_vld_pip_gemv <= 1'b0;
                emit_vld_pip_gemm <= 1'b0;
            end
        end
    end

    // synopsys translate_off
    `ifdef ROPEPOS
    always @(posedge core_clk) begin
        if (rst_n && (fuse_state == FUSE_ST_ROPE || fuse_state == FUSE_ST_RTQT)
            && core_row_valid && is_gemm_mode)
            $display("[ROPEPOS] t=%0t pos=%0d phase=%0d emit=%0d vldcnt=%0d gemm0=%h gemm1=%h",
                $time,
                (rope_token_row_phase_cnt << 9) + (((emit_cnt-1) & 5'b00011) << 7) + fuse_in_vld_cnt + rope_token_pos,
                rope_token_row_phase_cnt, emit_cnt, fuse_in_vld_cnt,
                core_row_data[15:0], core_row_data[31:16]);
    end
    `endif

    `ifdef ROPEFULL
    integer ropefull_fd;
    initial ropefull_fd = $fopen("rope_fed_dump.hex", "w");
    always @(posedge core_clk) begin
        if (rst_n && (fuse_state == FUSE_ST_ROPE || fuse_state == FUSE_ST_RTQT)
            && core_row_valid && is_gemm_mode)
            $fwrite(ropefull_fd, "IN %0d %0d %0d %0d %0512h\n",
                (rope_token_row_phase_cnt << 9) + (((emit_cnt-1) & 5'b00011) << 7) + fuse_in_vld_cnt + rope_token_pos,
                rope_token_row_phase_cnt, emit_cnt, fuse_in_vld_cnt, core_row_data);
        if (rst_n && (fuse_state == FUSE_ST_ROPE) && rope_out_vld && is_gemm_mode)
            $fwrite(ropefull_fd, "OUT %0512h\n", rope_out_row);
    end
    `endif

    `ifdef RTQTDBG
    integer rtqt_crv, rtqt_fiv, rtqt_rin, rtqt_rout, rtqt_tin, rtqt_tout, rtqt_qin, rtqt_qout, rtqt_emit;
    initial begin rtqt_crv=0; rtqt_fiv=0; rtqt_rin=0; rtqt_rout=0; rtqt_tin=0;
                  rtqt_tout=0; rtqt_qin=0; rtqt_qout=0; rtqt_emit=0; end
    always @(posedge core_clk) begin
        if (rst_n && (fuse_mode == GEMM_RTQT)) begin
            if (fuse_state == FUSE_ST_RTQT && core_row_valid) rtqt_crv <= rtqt_crv + 1;
            if (fuse_in_vld && (fuse_state == FUSE_ST_RTQT))  rtqt_fiv <= rtqt_fiv + 1;
            if (fuse_in_vld && (fuse_state == FUSE_ST_ROPE || fuse_state == FUSE_ST_RTQT)) rtqt_rin <= rtqt_rin + 1;
            if (rope_out_vld)             rtqt_rout <= rtqt_rout + 1;
            if (transposer_in_in_vld)     rtqt_tin  <= rtqt_tin + 1;
            if (transposer_in_out_vld)    rtqt_tout <= rtqt_tout + 1;
            if (quant_in_vld)             rtqt_qin  <= rtqt_qin + 1;
            if (quant_out_vld)            rtqt_qout <= rtqt_qout + 1;
            if (emit_vld)                 rtqt_emit <= rtqt_emit + 1;
        end
    end
    final $display("[RTQTDBG] crv=%0d fiv=%0d rope_in=%0d rope_out=%0d tin=%0d tout=%0d qin=%0d qout=%0d emit=%0d",
                   rtqt_crv, rtqt_fiv, rtqt_rin, rtqt_rout, rtqt_tin, rtqt_tout, rtqt_qin, rtqt_qout, rtqt_emit);
    `endif
    // synopsys translate_on

    // synopsys translate_off
    reg retprobe_en;
    initial retprobe_en = $test$plusargs("RETPROBE");
    always @(posedge core_clk) begin
        if (retprobe_en && rst_n && is_mode_valid && gemv_proj && !is_gemm_mode &&
            (isa_valid || concat_phase_done || wrvalid || (gemv_wr_hold_cnt != 5'd0) ||
             (gemv_proj_isa_done && !gemv_proj_isa_done_d) || rope_out_vld ||
             emit_vld || emit_vld_pip_gemv || core_row_valid || gemv_write_req_d8)) begin
            $display("[RETPROBE] t=%0t fm=%0d isaV=%b isadone=%b(d%b) hold=%0d(d%0d) cpd=%b outl=%b | crv=%b emit=%b emitpip=%b wport=%0d wrvld=%b gwr8=%b ropevld=%b",
                     $time, fuse_mode, isa_valid, gemv_proj_isa_done, gemv_proj_isa_done_d,
                     gemv_wr_hold_cnt, gemv_wr_hold_cnt_d, concat_phase_done,
                     concat_gemv_out_done_latch, core_row_valid, emit_vld, emit_vld_pip_gemv,
                     wdata_portion, wrvalid, gemv_write_req_d8, rope_out_vld);
        end
    end
    // synopsys translate_on

    // synopsys translate_off
`ifdef KVPROBE
    integer kv_ncmd, kv_nbeat, kv_nqout, kv_nemit;
    integer kv_pf_seen, kv_dc_seen, kv_fs_seen, kv_is_seen, kv_op_seen, kv_ov_seen;
    integer kv_pf_drop, kv_dc_drop, kv_fs_drop, kv_is_drop, kv_op_drop, kv_ov_drop;
    initial begin
        kv_ncmd=0; kv_nbeat=0; kv_nqout=0; kv_nemit=0;
        kv_pf_seen=0; kv_dc_seen=0; kv_fs_seen=0; kv_is_seen=0; kv_op_seen=0; kv_ov_seen=0;
        kv_pf_drop=0; kv_dc_drop=0; kv_fs_drop=0; kv_is_drop=0; kv_op_drop=0; kv_ov_drop=0;
    end
    always @(posedge core_clk) begin
        if (rst_n && (fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT)) begin
            if (prefill_start_write_d1)      begin kv_pf_seen<=kv_pf_seen+1; if(start_write) kv_pf_drop<=kv_pf_drop+1;
                $display("[KVCMD] t=%0t PREFILL busy=%b burst=%0d", $time, start_write, KV_prefill_burst_length); end
            if (decode_start_write_d1)       begin kv_dc_seen<=kv_dc_seen+1; if(start_write) kv_dc_drop<=kv_dc_drop+1;
                $display("[KVCMD] t=%0t DECODE  busy=%b burst=%0d", $time, start_write, KV_decode_burst_length); end
            if (fp_scale_zp_start_write_d1)  begin kv_fs_seen<=kv_fs_seen+1; if(start_write) kv_fs_drop<=kv_fs_drop+1;
                $display("[KVCMD] t=%0t FPSZP   busy=%b", $time, start_write); end
            if (int_scale_zp_start_write_d1) begin kv_is_seen<=kv_is_seen+1; if(start_write) kv_is_drop<=kv_is_drop+1;
                $display("[KVCMD] t=%0t INTSZP  busy=%b", $time, start_write); end
            if (outlier_pos_start_write_d1)  begin kv_op_seen<=kv_op_seen+1; if(start_write) kv_op_drop<=kv_op_drop+1;
                $display("[KVCMD] t=%0t OPOS    busy=%b", $time, start_write); end
            if (outlier_val_start_write_d1)  begin kv_ov_seen<=kv_ov_seen+1; if(start_write) kv_ov_drop<=kv_ov_drop+1;
                $display("[KVCMD] t=%0t OVAL    busy=%b", $time, start_write); end
            if (start_write) begin kv_ncmd<=kv_ncmd+1;
                $display("[KVOUT-CMD] t=%0t word=%0d burst=%0d", $time, write_init_addr>>5, write_burst_length); end
            if (wrvalid) begin kv_nbeat<=kv_nbeat+1;
                $display("[KVOUT-BEAT] t=%0t n=%0d lo=%h", $time, kv_nbeat, write_data[63:0]); end
            if (quant_out_vld) kv_nqout<=kv_nqout+1;
            if (emit_vld)      kv_nemit<=kv_nemit+1;
        end
    end
    final $display("[KVPROBE] ncmd=%0d nbeat=%0d nqout=%0d nemit=%0d | seen P=%0d D=%0d FS=%0d IS=%0d OP=%0d OV=%0d | drop P=%0d D=%0d FS=%0d IS=%0d OP=%0d OV=%0d",
        kv_ncmd, kv_nbeat, kv_nqout, kv_nemit,
        kv_pf_seen, kv_dc_seen, kv_fs_seen, kv_is_seen, kv_op_seen, kv_ov_seen,
        kv_pf_drop, kv_dc_drop, kv_fs_drop, kv_is_drop, kv_op_drop, kv_ov_drop);
`endif
    // synopsys translate_on

reg gw2c_en; integer gw2c_cnt, gw2c_i;
initial begin gw2c_en = $test$plusargs("GQAWAVE2"); gw2c_cnt = 0; end
always @(posedge core_clk) begin
  if (!rst_n) gw2c_cnt <= 0;
  else if (gw2c_en && (fuse_state == FUSE_ST_GQA) && core_row_valid && gw2c_cnt < 32'd600) begin
    $write("[GQAWAVE2] %m h=%0d dhc=%0d s=%0d d=", gqa_wr_cnt, gqa_data_head_cnt, fuse_out_vld_cnt);
    for (gw2c_i=0; gw2c_i<BLOCK_SIZE; gw2c_i=gw2c_i+1) $write("%h ", core_row_data[gw2c_i*DATA_WIDTH +: DATA_WIDTH]);
    $write("\n"); gw2c_cnt <= gw2c_cnt + 1;
  end
end

// synopsys translate_off
`ifdef GQAPVPROBE
    integer gw_stop, gw_rows, gw_req, gw_sw, gw_lines;
    reg gw_busy_q;
    initial begin gw_stop = 0; gw_rows = 0; gw_req = 0; gw_sw = 0; gw_lines = 0; gw_busy_q = 0; end
    always @(posedge core_clk) if (rst_n) begin
        if (gqa_compute_stop) gw_stop = gw_stop + 1;
        if (core_row_valid) gw_rows = gw_rows + 1;
        if (gqa_v_write_req) gw_req = gw_req + 1;
        if (start_write) gw_sw = gw_sw + 1;
        if (gw_lines < 48 && (gqa_compute_stop || gqa_v_write_req || (gqa_v_phase_busy != gw_busy_q))) begin
            gw_lines = gw_lines + 1;
            $display("[GQAWR] t=%0t stop=%b busy=%b recv=%0d target=%0d phase_cnt=%0d req=%b rows_so_far=%0d", $time,
                     gqa_compute_stop, gqa_v_phase_busy, gqa_v_recv_cnt, gqa_v_emit_target, gqa_v_phase_cnt, gqa_v_write_req, gw_rows);
        end
        gw_busy_q = gqa_v_phase_busy;
    end
    final $display("[GQAWR-SUM] compute_stop=%0d rows=%0d write_req=%0d start_write=%0d", gw_stop, gw_rows, gw_req, gw_sw);
`endif
// synopsys translate_on

// synopsys translate_off
`ifdef KVPROBE
    integer ka_n; reg ka_sw_q; initial begin ka_n = 0; ka_sw_q = 0; end
    always @(posedge core_clk) if (rst_n) begin
        if (start_write && !ka_sw_q && ka_n < 400) begin
            ka_n = ka_n + 1;
            $display("[KVADDR] t=%0t n=%0d code=%b fuse=%0d tile=%0d row=%0d col=%0d phase=%0d base2-d2=%0d addr-d2=%0d addr-d1=%0d burst=%0d", $time, ka_n,
                     cmd_is_code, fuse_mode, decode_tile_cnt, decode_tk_row, decode_tk_col, decode_dense_phase_cnt,
                     $signed(base_addr2 - dest_addr2) >>> 5, $signed(write_init_addr - dest_addr2) >>> 5, $signed(write_init_addr - dest_addr1) >>> 5, write_burst_length);
        end
        ka_sw_q = start_write;
    end
    integer kd_req, kd_drop; reg kd_q; initial begin kd_req = 0; kd_drop = 0; kd_q = 0; end
    always @(posedge core_clk) if (rst_n) begin
        if (decode_start_write_d1 && !kd_q) begin
            kd_req = kd_req + 1;
            if (start_write) begin kd_drop = kd_drop + 1; $display("[KVDROP] t=%0t req=%0d arrived while start_write=1 tile=%0d phase=%0d", $time, kd_req, decode_tile_cnt, decode_dense_phase_cnt); end
        end
        kd_q = decode_start_write_d1;
    end
    final $display("[KVADDR-SUM] write_commands=%0d decode_write_requests=%0d dropped_while_busy=%0d", ka_n, kd_req, kd_drop);
`endif
// synopsys translate_on

endmodule
