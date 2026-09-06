// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module pmu_top #(
    parameter DATA_WIDTH      = 16,
    parameter MPU_OUT_WIDTH   = 24,
    parameter BLOCK_SIZE      = 128,
    parameter BLOCK_ROW       = 128,
    parameter CORE_NUM        = 32,
    parameter integer CORE_ID = 0,
    parameter BUNDLE_PAIR_NUM = 4,
    parameter LOOP_NUM        = 2,
    parameter [3:0] GEMM_A_XFERS = 4'd2,
    parameter [3:0] GEMM_W_XFERS = 4'd4,
    parameter ENABLE_SWIGLU   = 0,
    parameter ENABLE_ROPE     = 0,
    parameter ENABLE_QUANT    = 0,
`ifdef ONLINE_SOFTMAX
    parameter ENABLE_ONLINE_SOFTMAX = 1
`else
    parameter ENABLE_ONLINE_SOFTMAX = 0
`endif
)(
    input  wire                             core_clk,
    input  wire                             rst_n,

    input  wire                             isa_valid,
    input  wire                             is_mode_valid,
    input  wire                             is_gemm_mode,
    input  wire                             is_proj_mode,
    input  wire                             dest_on_chip,
    input  wire [8:0]                       hidden_dim,
    input  wire [8:0]                       output_dim,
    input  wire [8:0]                       seq_row_tiles,
    input  wire                             is_gating,

    input  wire                             start_emit,
    input  wire                             diag_done,

    input  wire                             mpu_row_valid,
    input  wire                             quant_kv,
    input  wire                             causal_mode,
    input  wire [MPU_OUT_WIDTH*BLOCK_SIZE-1:0] mpu_row_data,
    input  wire                             residual_row_vld,
    input  wire [2*DATA_WIDTH*BLOCK_SIZE-1:0] residual_row_data,

    input  wire                             reduce_max_vld,
    input  wire [DATA_WIDTH-1:0]            reduce_max_value,

    input wire [7:0]                        q_row_num,
    input wire [7:0]                        batch_num,
    input wire [7:0]                        batch_space,

    output wire [DATA_WIDTH*BLOCK_SIZE-1:0] score_row,
    output wire                             score_row_vld,
    output wire [DATA_WIDTH*BLOCK_SIZE-1:0] pmu_row,
    output wire                             pmu_row_vld,
    output wire                             gqa_q_phase_done,
    output wire                             gqa_score_phase_done,
    output wire                             compute_stop,
    output wire                             compute_stop_latch
);

    genvar i;
    integer ai;

    localparam ROW_WIDTH     = DATA_WIDTH * BLOCK_SIZE;
    localparam ACC_ROW_WIDTH = MPU_OUT_WIDTH * BLOCK_SIZE;
    localparam DIM           = BLOCK_SIZE/2;
    localparam IDX_W   = $clog2(BLOCK_SIZE) + 1;
    localparam integer PP_BUFFER_ADDR = 512;

    localparam  GEMM_BYPASS = 4'd1,
                GEMM_ROPE = 4'd2,
                GEMM_RQT = 4'd3,
                GEMM_QUANT = 4'd4,
                GEMM_PRERMS = 4'd5,
                GEMM_SP = 4'd6,
                GEMM_GQA_PROJ = 4'd7,

                GEMV_BYPASS = 4'd8,
                GEMV_ROPE = 4'd9,
                GEMV_PRERMS = 4'd10,
                GEMV_SP = 4'd11,
                GEMV_GQA_PROJ = 4'd12,

                DECODE_QUANT_TRANSPOSE = 4'd13,
                DECODE_QUANT = 4'd14;
    localparam  FUSE_ST_IDLE = 4'd0,
                FUSE_ST_BYPASS = 4'd1,
                FUSE_ST_ROPE = 4'd2,
                FUSE_ST_RQT = 4'd3,
                FUSE_ST_QUANT = 4'd4,
                FUSE_ST_PRERMS = 4'd5,
                FUSE_ST_SP = 4'd6,
                FUSE_ST_GQA = 4'd7,
                FUSE_ST_PROJ = 4'd15,
                DECODE_QUANT_ST = 4'd8;

    reg [3:0]  fuse_state;
    reg        fuse_active;
    reg        fuse_start;
    reg        fuse_in_done, fuse_out_done;
    reg [IDX_W-1:0] fuse_in_idx;
    reg [IDX_W-1:0] fuse_out_idx;
    reg [7:0]  batch_cnt;

    reg                 emit_vld;
    reg [ROW_WIDTH-1:0] emit_data;

    reg buffer_sel, emit_buf_sel, buffer_clear;
    reg buffer_clear_trigger;
    reg gemv_emit_pending;
    reg gemv_wr_drained;

    assign pmu_row_vld = emit_vld;
    assign pmu_row     = emit_data;

    reg                           fuse_in_vld;

    wire                             row_sum_vld;
    wire [DATA_WIDTH*BLOCK_ROW-1:0]  row_sum_val;
    reg                             score_result_toggle;

    wire en_pre_softmax = !is_proj_mode && !score_result_toggle;
    wire ps_done;
    wire diag_done_eff = (!is_proj_mode) ? diag_done : 1'b0;
    reg  result_pre_done;
    reg  result_phase_done;
    reg  result_pre_done_latch;
    reg  dec_z_valid;
    reg  dec_fuse_pend;
    reg       onl_emit_ok;
    reg [3:0] onl_ps_dly;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            onl_emit_ok <= 1'b0;
            onl_ps_dly  <= 4'd0;
        end else if (isa_valid || result_phase_done) begin
            onl_emit_ok <= 1'b0;
            onl_ps_dly  <= 4'd0;
        end else if (ENABLE_ONLINE_SOFTMAX != 0) begin
            if (ps_done)            onl_ps_dly <= 4'd8;
            else if (|onl_ps_dly) begin
                onl_ps_dly <= onl_ps_dly - 1'b1;
                if (onl_ps_dly == 4'd1) onl_emit_ok <= 1'b1;
            end
        end
    end

    assign compute_stop = result_pre_done;
    assign compute_stop_latch = result_pre_done_latch;
    reg  diag_done_latched;
    reg  all_scores_generated;
    reg [15:0] tile_accum_cnt;
    reg [8:0] hidden_dim_cnt;
    reg [8:0] output_dim_cnt;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            diag_done_latched <= 1'b0;
            all_scores_generated <= 1'b0;
        end else if (isa_valid) begin
            diag_done_latched <= 1'b0;
            all_scores_generated <= 1'b0;
        end else begin
            if (diag_done_eff) diag_done_latched <= 1'b1;
            if (diag_done_latched) begin
                if(ps_done) all_scores_generated <= 1'b1;
            end
            if (diag_done_latched && result_pre_done && !is_proj_mode) begin
                diag_done_latched <= 1'b0;
                all_scores_generated <= 1'b0;
            end
        end
    end

    assign gqa_q_phase_done = ps_done;

    assign gqa_score_phase_done = result_phase_done;
    reg [7:0] core_row_idx;
    reg [7:0] res_row_idx;
    reg [7:0] bundle_cnt;

    always @ (posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            score_result_toggle <= 1'b0;
            result_phase_done <= 1'b0;
        end else if (isa_valid) begin
            score_result_toggle <= 1'b0;
            result_phase_done <= 1'b0;
        end else begin
            result_phase_done <= 1'b0;
            if(!is_proj_mode && is_gemm_mode) begin
                if (core_row_idx == q_row_num-1 && mpu_row_valid && !score_result_toggle) begin
                    score_result_toggle <= 1'b1;
                end else if (core_row_idx == q_row_num-1 && mpu_row_valid && score_result_toggle) begin
                    score_result_toggle <= 1'b0;
                    result_phase_done <= 1'b1;
                end

            end else if(!is_proj_mode && !is_gemm_mode) begin
                if (core_row_idx == q_row_num-1 && bundle_cnt == BUNDLE_PAIR_NUM-1 && mpu_row_valid && !score_result_toggle) begin
                    score_result_toggle <= 1'b1;
                end else if (core_row_idx == q_row_num-1 && bundle_cnt == BUNDLE_PAIR_NUM-1 && mpu_row_valid && score_result_toggle) begin
                    score_result_toggle <= 1'b0;
                    result_phase_done <= 1'b1;
                end
            end
        end
    end

    reg [$clog2(PP_BUFFER_ADDR)-1:0]  acc_addr0, acc_addr1;
    reg [1:0]                         seq_tile_idx;
    localparam integer A_SHIFT      = $clog2(GEMM_A_XFERS);
    localparam integer W_SHIFT      = $clog2(GEMM_W_XFERS);
    localparam integer GATE_TILES   = GEMM_W_XFERS >> 1;
    localparam integer SLOT_W       = $clog2(PP_BUFFER_ADDR/BLOCK_SIZE);
    localparam integer GR_W         = (A_SHIFT < 1) ? 1 : A_SHIFT;
    wire [GR_W-1:0]                   grid_row = (A_SHIFT < 1) ? {GR_W{1'b0}} : CORE_ID[W_SHIFT +: GR_W];
    wire                              gemm_proj = is_proj_mode && is_gemm_mode;
    reg  [8:0]                        act_row_groups_r;
    reg  [8:0]                        w_col_groups_r;
    reg  [15:0]                       expected_blocks;
    reg  [15:0]                       blk_written;
    reg  [8:0]                        arg_w;
    reg  [3:0]                        wcg_w;
    reg  [1:0]                        seq_iq;
    reg  [8:0]                        emit_arg;
    reg  [3:0]                        wcg_e;
    wire                              wcg_overflow = (w_col_groups_r > 9'd2) && (act_row_groups_r == 9'd1);
    wire [SLOT_W-1:0]                 wr_slot = wcg_overflow ? wcg_w[SLOT_W-1:0]
                                              : (wcg_w[SLOT_W-1:0]*GEMM_A_XFERS + grid_row);
    wire [SLOT_W-1:0]                 rd_slot = wcg_overflow ? wcg_e[SLOT_W-1:0]
                                              : (wcg_e[SLOT_W-1:0]*GEMM_A_XFERS + grid_row);
    wire                              wr_bank  = wcg_overflow ? wcg_w[2] : buffer_sel;
    wire                              emit_bank = wcg_overflow ? wcg_e[2] : emit_buf_sel;
    wire                              wr_gate = gemm_proj ? (blk_written < expected_blocks) : 1'b1;
    reg [1:0]                         emit_seq_tile;
    reg [2*ACC_ROW_WIDTH-1:0]       acc_data0, acc_data1;
    reg                           acc_valid0, acc_valid1;
    reg                           overwrite0, overwrite1;
    reg                           residual_phase0, residual_phase1;

    wire [2*ACC_ROW_WIDTH-1:0] residual_row_fp24;
    genvar rp;
    generate
        for (rp = 0; rp < 2*BLOCK_SIZE; rp = rp + 1) begin : G_RES_PAD
            assign residual_row_fp24[MPU_OUT_WIDTH*rp +: MPU_OUT_WIDTH] =
                {residual_row_data[DATA_WIDTH*rp + DATA_WIDTH - 1],
                 residual_row_data[DATA_WIDTH*rp + DATA_WIDTH - 2 -: 8],
                 residual_row_data[DATA_WIDTH*rp +: 7],
                 8'd0};
        end
    endgenerate

    reg                           ren0, ren1;
    reg [$clog2(PP_BUFFER_ADDR)-1:0]  raddr0, raddr1;
    wire [ROW_WIDTH-1:0]          rdata0, rdata1;

    wire [DATA_WIDTH*BLOCK_SIZE-1:0] psm_leg_score_row,  psm_onl_score_row;
    wire                             psm_leg_score_row_vld, psm_onl_score_row_vld;
    wire [DATA_WIDTH*BLOCK_ROW-1:0]  psm_leg_row_sum_val, psm_onl_row_sum_val;
    wire                             psm_leg_row_sum_vld, psm_onl_row_sum_vld;
    wire                             psm_leg_ps_done,     psm_onl_ps_done;

    assign score_row     = (ENABLE_ONLINE_SOFTMAX != 0) ? psm_onl_score_row     : psm_leg_score_row;
    assign score_row_vld = (ENABLE_ONLINE_SOFTMAX != 0) ? psm_onl_score_row_vld : psm_leg_score_row_vld;
    assign row_sum_val   = (ENABLE_ONLINE_SOFTMAX != 0) ? psm_onl_row_sum_val   : psm_leg_row_sum_val;
    assign row_sum_vld   = (ENABLE_ONLINE_SOFTMAX != 0) ? psm_onl_row_sum_vld   : psm_leg_row_sum_vld;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_z_valid   <= 1'b0;
            dec_fuse_pend <= 1'b0;
        end else if (isa_valid) begin
            dec_z_valid   <= 1'b0;
            dec_fuse_pend <= 1'b0;
        end else begin
            if (row_sum_vld && (ENABLE_ONLINE_SOFTMAX == 0)) dec_z_valid <= 1'b1;
            if (fuse_out_done && !is_proj_mode && !is_gemm_mode) dec_z_valid <= 1'b0;
            if (fuse_start && is_mode_valid && !is_proj_mode && !is_gemm_mode
                && !(dec_z_valid || (ENABLE_ONLINE_SOFTMAX != 0)))
                dec_fuse_pend <= 1'b1;
            if (fuse_state == FUSE_ST_GQA) dec_fuse_pend <= 1'b0;
        end
    end
    assign ps_done       = (ENABLE_ONLINE_SOFTMAX != 0) ? psm_onl_ps_done       : psm_leg_ps_done;

    wire                              onl_ren;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] onl_raddr;
    wire [DATA_WIDTH*BLOCK_SIZE-1:0]  onl_rdata;
    wire                              onl_acc_vld, onl_acc_ovw;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] onl_acc_addr;
    wire [MPU_OUT_WIDTH*BLOCK_SIZE-1:0] onl_acc_data;
    wire [$clog2(BLOCK_SIZE)-1:0]     onl_alpha_row;
    wire [$clog2(BLOCK_ROW)-1:0]      onl_rsum_row;
    wire [DATA_WIDTH-1:0]             onl_rsum, onl_alpha;
    wire                              onl_rsum_vld, onl_alpha_vld;
    wire [$clog2(BUNDLE_PAIR_NUM)-1:0] onl_bank;
    wire                              onl_pv_vld;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] onl_pv_addr;
    wire                              onl_pair_out;
    wire                              onl_bp_viol;
    wire [7:0]                        onl_den_idx;
    wire [DATA_WIDTH-1:0]             onl_div_den;

    reg  onl_ob_sel, onl_first_kv;
    wire onl_block_start = isa_valid;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            onl_ob_sel      <= 1'b0;
            onl_first_kv    <= 1'b1;
        end else if (ENABLE_ONLINE_SOFTMAX != 0) begin
            if (isa_valid || onl_block_start) begin
                onl_ob_sel      <= 1'b0;
                onl_first_kv    <= 1'b1;
                end else begin
                if (score_result_toggle && mpu_row_valid && core_row_idx == q_row_num-1) begin
                    onl_ob_sel   <= ~onl_ob_sel;
                    onl_first_kv <= 1'b0;
                end
            end
        end
    end

    assign onl_bank      = is_gemm_mode ? {($clog2(BUNDLE_PAIR_NUM)){1'b0}}
                                        : bundle_cnt[$clog2(BUNDLE_PAIR_NUM)-1:0];
    assign onl_pv_vld    = (ENABLE_ONLINE_SOFTMAX != 0) && is_mode_valid && !is_proj_mode &&
                           mpu_row_valid && score_result_toggle;
    assign onl_pv_addr   = core_row_idx[$clog2(PP_BUFFER_ADDR)-1:0];
    assign onl_rdata     = onl_ob_sel ? rdata1 : rdata0;

    wire onl_score_pass_end = !is_proj_mode && !score_result_toggle && mpu_row_valid &&
                              (core_row_idx == q_row_num - 8'd1);
    reg  onl_flush_lone_row;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) onl_flush_lone_row <= 1'b0;
        else        onl_flush_lone_row <= (ENABLE_ONLINE_SOFTMAX != 0) && onl_score_pass_end;
    end

    pre_softmax #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_WIDTH(MPU_OUT_WIDTH),
        .DATA_NUM(BLOCK_SIZE),
        .BLOCK_ROW(BLOCK_ROW),
        .PSM_BUFFER_SIZE(128),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM),
        .LOOP_NUM(LOOP_NUM),
        .CORE_ID(CORE_ID),
        .SEQ_PER_CORE(BLOCK_ROW/CORE_NUM)
    ) u_pre_softmax (
        .clk(core_clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .in_vld(mpu_row_valid && en_pre_softmax),
        .diag_done(diag_done_latched),
        .prefill(is_gemm_mode),
        .quant_kv(quant_kv),
        .causal_mode(causal_mode),
        .d_in(mpu_row_data),
        .reduce_max_vld(reduce_max_vld),
        .constant_max(reduce_max_value),
        .q_row_num(q_row_num),
        .score_out(psm_leg_score_row),
        .score_out_vld(psm_leg_score_row_vld),
        .row_sum_out(psm_leg_row_sum_val),
        .row_sum_vld(psm_leg_row_sum_vld),
        .ps_done(psm_leg_ps_done)
    );

    generate
    if (ENABLE_ONLINE_SOFTMAX != 0) begin : g_psm_online

    wire                                psm_onl_in_vld;
    wire [2*MPU_OUT_WIDTH*BLOCK_SIZE-1:0] psm_onl_d_in;
    wire                                psm_onl_block_start;

    psm_online_adapter #(
        .MPU_OUT_WIDTH(MPU_OUT_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE)
    ) u_psm_adapter (
        .clk(core_clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .row_vld(mpu_row_valid && en_pre_softmax),
        .row_data(mpu_row_data),
        .block_start_in(onl_block_start),
        .flush(onl_flush_lone_row),
        .psm_in_vld(psm_onl_in_vld),
        .psm_d_in(psm_onl_d_in),
        .psm_block_start(psm_onl_block_start),
        .dbg_pair_out(onl_pair_out),
        .dbg_backpressure_viol(onl_bp_viol)
    );

    pre_softmax_online #(
        .DATA_WIDTH(DATA_WIDTH),
        .DIN_WIDTH(MPU_OUT_WIDTH),
        .DATA_NUM(BLOCK_SIZE),
        .BLOCK_ROW(BLOCK_ROW),
        .IDX_W($clog2(BLOCK_ROW))
    ) u_pre_softmax_online (
        .clk(core_clk),
        .rst_n(rst_n),
        .in_vld(psm_onl_in_vld),
        .diag_done(diag_done_latched),
        .prefill_decode(!is_gemm_mode),
        .d_in(psm_onl_d_in),
        .s_row_num(q_row_num[6:0] - 7'd1),
        .block_start(psm_onl_block_start),
        .rsum_out(onl_rsum),
        .rsum_out_vld(onl_rsum_vld),
        .rsum_row_out(onl_rsum_row),
        .alpha_out(onl_alpha),
        .alpha_out_vld(onl_alpha_vld),
        .alpha_row_out(onl_alpha_row),
        .p_out(psm_onl_score_row),
        .p_out_vld(psm_onl_score_row_vld),
        .ps_done(psm_onl_ps_done)
    );

    assign psm_onl_row_sum_val = {BLOCK_ROW{onl_rsum}};
    assign psm_onl_row_sum_vld = onl_rsum_vld;

    online_rescale_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .MPU_OUT_WIDTH(MPU_OUT_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDR_W($clog2(PP_BUFFER_ADDR)),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM),
        .ROW_W($clog2(BLOCK_SIZE)),
        .BNK_W($clog2(BUNDLE_PAIR_NUM))
    ) u_online_rescale (
        .clk(core_clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .alpha_vld(onl_alpha_vld),
        .alpha_in(onl_alpha),
        .alpha_row(onl_alpha_row),
        .alpha_bank(onl_bank),
        .pv_vld(onl_pv_vld),
        .pv_data(mpu_row_data),
        .pv_addr(onl_pv_addr),
        .pv_row(core_row_idx[$clog2(BLOCK_SIZE)-1:0]),
        .pv_bank(onl_bank),
        .first_kv_blk(onl_first_kv),
        .ren(onl_ren),
        .raddr(onl_raddr),
        .rdata(onl_rdata),
        .acc_vld(onl_acc_vld),
        .acc_addr(onl_acc_addr),
        .acc_data(onl_acc_data),
        .acc_overwrite(onl_acc_ovw),
        .dbg_alpha_wr(),
        .dbg_upd_fire()
    );

    reg [DATA_WIDTH-1:0] l_live [0:BLOCK_ROW-1];
    reg [DATA_WIDTH-1:0] l_snap [0:BLOCK_ROW-1];
    reg [3:0]            snap_dly;
    integer              li;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n || isa_valid) begin
            for (li=0; li<BLOCK_ROW; li=li+1) l_live[li] <= {DATA_WIDTH{1'b0}};
        end else if (onl_rsum_vld) begin
            l_live[onl_rsum_row] <= onl_rsum;
        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n || isa_valid)  snap_dly <= 4'd0;
        else if (psm_onl_ps_done) snap_dly <= 4'd2;
        else if (|snap_dly)       snap_dly <= snap_dly - 4'd1;
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n || isa_valid) begin
            for (li=0; li<BLOCK_ROW; li=li+1) l_snap[li] <= {DATA_WIDTH{1'b0}};
        end else if (snap_dly == 4'd1) begin
            for (li=0; li<BLOCK_ROW; li=li+1) l_snap[li] <= l_live[li];
        end
    end

    assign onl_div_den = l_snap[onl_den_idx[$clog2(BLOCK_ROW)-1:0]];

    end
    endgenerate
    wire                          rvalid0, rvalid1;

    wire                          pip_empty0, pip_empty1;

    wire onl_rd0 = (ENABLE_ONLINE_SOFTMAX != 0) && onl_ren && !onl_ob_sel;
    wire onl_rd1 = (ENABLE_ONLINE_SOFTMAX != 0) && onl_ren &&  onl_ob_sel;
    wire onl_wr0 = (ENABLE_ONLINE_SOFTMAX != 0) && onl_acc_vld &&  onl_ob_sel;
    wire onl_wr1 = (ENABLE_ONLINE_SOFTMAX != 0) && onl_acc_vld && !onl_ob_sel;

    wire                              acc_ren0_m   = ren0 | onl_rd0;
    wire                              acc_ren1_m   = ren1 | onl_rd1;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] acc_raddr0_m = onl_rd0 ? onl_raddr : raddr0;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] acc_raddr1_m = onl_rd1 ? onl_raddr : raddr1;

    wire                              acc_valid0_m = onl_wr0 ? 1'b1 : acc_valid0;
    wire                              acc_valid1_m = onl_wr1 ? 1'b1 : acc_valid1;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] acc_addr0_m  = onl_wr0 ? onl_acc_addr : acc_addr0;
    wire [$clog2(PP_BUFFER_ADDR)-1:0] acc_addr1_m  = onl_wr1 ? onl_acc_addr : acc_addr1;
    wire [2*ACC_ROW_WIDTH-1:0]        acc_data0_m  = onl_wr0 ? {{ACC_ROW_WIDTH{1'b0}}, onl_acc_data} : acc_data0;
    wire [2*ACC_ROW_WIDTH-1:0]        acc_data1_m  = onl_wr1 ? {{ACC_ROW_WIDTH{1'b0}}, onl_acc_data} : acc_data1;
    wire                              overwrite0_m = onl_wr0 ? onl_acc_ovw : overwrite0;
    wire                              overwrite1_m = onl_wr1 ? onl_acc_ovw : overwrite1;

    concat_accum_buffer_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(MPU_OUT_WIDTH),
        .DATA_NUM(BLOCK_SIZE),
        .BUFFER_ADDR(PP_BUFFER_ADDR),
        .LOOP_NUM(LOOP_NUM)
    ) u_concat_accum_buffer_sram_0 (
        .clk       (core_clk),
        .rst_n     (rst_n),
        .clear     ((!emit_buf_sel && buffer_clear && !gemm_proj) || isa_valid),

        .acc_addr  (acc_addr0_m),
        .acc_data  (acc_data0_m),
        .acc_valid (acc_valid0_m),
        .overwrite (overwrite0_m),
        .residual_phase(residual_phase0),
        .is_gemv_proj(is_proj_mode && !is_gemm_mode),

        .ren       (acc_ren0_m),
        .raddr     (acc_raddr0_m),
        .rdata     (rdata0),
        .rvalid    (rvalid0),

        .pip_empty (pip_empty0)
    );

    concat_accum_buffer_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(MPU_OUT_WIDTH),
        .DATA_NUM(BLOCK_SIZE),
        .BUFFER_ADDR(PP_BUFFER_ADDR),
        .LOOP_NUM(LOOP_NUM)
    ) u_concat_accum_buffer_sram_1 (
        .clk       (core_clk),
        .rst_n     (rst_n),
        .clear     ((emit_buf_sel && buffer_clear && !gemm_proj)  || isa_valid),

        .acc_addr  (acc_addr1_m),
        .acc_data  (acc_data1_m),
        .acc_valid (acc_valid1_m),
        .overwrite (overwrite1_m),
        .residual_phase(residual_phase1),
        .is_gemv_proj(is_proj_mode && !is_gemm_mode),

        .ren       (acc_ren1_m),
        .raddr     (acc_raddr1_m),
        .rdata     (rdata1),
        .rvalid    (rvalid1),

        .pip_empty (pip_empty1)
    );

    reg gqa_new_row, gemm_new_row;
    reg [2:0] gqa_new_row_cnt, gemm_new_row_cnt;

    reg                         div_out_vld;
    wire [DATA_WIDTH*DIM-1:0]   div_out;

    reg [DATA_WIDTH*DIM-1:0] div_num_in;
    reg [DATA_WIDTH-1:0] div_den_in;

    reg                 start_div;

    reg [DATA_WIDTH-1:0] row_sum [0:BLOCK_SIZE-1];

    reg [7:0]                    process_row_idx;
    reg                          process_col_idx;
    reg                          out_col_idx;

    reg [ROW_WIDTH-1:0] div_rdata;

    reg [5:0] gqa_emit_cnt, proj_emit_cnt;
    assign onl_den_idx = process_row_idx + (BLOCK_ROW/CORE_NUM)*gqa_emit_cnt;
    reg [2:0] gemv_fuse_delay_cnt;

    reg [8:0] output_dim_remaining;
    reg [8:0] emit_row_num;

    wire [8:0] batch_space_eff = ({1'b0, batch_space} < output_dim_remaining) ? {1'b0, batch_space} : output_dim_remaining;

    wire [8:0] emit_row_num_eff = ({1'b0, batch_space} < emit_row_num) ? {1'b0, batch_space} : emit_row_num;

    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            fuse_state <= FUSE_ST_IDLE;
            fuse_active <= 1'b0;
            fuse_in_done <= 1'b0;
            fuse_out_done <= 1'b0;
            fuse_in_idx <= {IDX_W{1'b0}};
            fuse_out_idx <= {IDX_W{1'b0}};
            fuse_in_vld <= 1'b0;
            buffer_clear_trigger <= 1'b0;
            batch_cnt <= 8'd0;

            emit_vld <= 1'b0;
            emit_data <= {ROW_WIDTH{1'b0}};
            ren0 <= 1'b0;
            ren1 <= 1'b0;
            raddr0 <= {($clog2(BLOCK_SIZE)){1'b0}};
            raddr1 <= {($clog2(BLOCK_SIZE)){1'b0}};

            gqa_new_row <= 1'b0;
            gqa_new_row_cnt <= 3'd0;
            gemm_new_row <= 1'b0;
            gemm_new_row_cnt <= 3'd0;

            process_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
            process_col_idx <= 1'b0;
            out_col_idx <= 1'b0;

            div_rdata <= {ROW_WIDTH{1'b0}};
            div_num_in <= {(DATA_WIDTH*DIM){1'b0}};
            div_den_in <= {DATA_WIDTH{1'b0}};
            div_out_vld <= 1'b0;

            start_div <= 1'b0;

        end else if (isa_valid) begin
            fuse_state           <= FUSE_ST_IDLE;
            fuse_active          <= 1'b0;
            fuse_in_done         <= 1'b0;
            fuse_out_done        <= 1'b0;
            fuse_in_idx          <= {IDX_W{1'b0}};
            fuse_out_idx         <= {IDX_W{1'b0}};
            fuse_in_vld          <= 1'b0;
            buffer_clear_trigger <= 1'b0;
            batch_cnt            <= 8'd0;

            emit_vld             <= 1'b0;
            emit_data            <= {ROW_WIDTH{1'b0}};
            ren0                 <= 1'b0;
            ren1                 <= 1'b0;
            raddr0               <= {($clog2(BLOCK_SIZE)){1'b0}};
            raddr1               <= {($clog2(BLOCK_SIZE)){1'b0}};

            gqa_new_row          <= 1'b0;
            gqa_new_row_cnt      <= 3'd0;
            gemm_new_row         <= 1'b0;
            gemm_new_row_cnt     <= 3'd0;

            process_row_idx      <= 8'd0;
            process_col_idx      <= 1'b0;
            out_col_idx          <= 1'b0;

            div_rdata            <= {ROW_WIDTH{1'b0}};
            div_num_in           <= {(DATA_WIDTH*DIM){1'b0}};
            div_den_in           <= {DATA_WIDTH{1'b0}};
            div_out_vld          <= 1'b0;

            start_div            <= 1'b0;

        end else begin
            fuse_in_vld <= 1'b0;
            fuse_out_done <= 1'b0;
            buffer_clear_trigger <= 1'b0;
            emit_vld <= 1'b0;
            ren0 <= 1'b0;
            ren1 <= 1'b0;

            case (fuse_state)
                FUSE_ST_IDLE: begin
                    fuse_in_vld <= 1'b0;
                    fuse_in_idx <= {IDX_W{1'b0}};
                    fuse_in_done <= 1'b0;
                    fuse_out_idx <= {IDX_W{1'b0}};
                    gqa_new_row <= 1'b1;
                    gqa_new_row_cnt <= 3'd0;
                    gemm_new_row <= 1'b1;
                    gemm_new_row_cnt <= 3'd0;
                    div_out_vld <= 1'b0;

                    process_row_idx <= 8'd0;
                    process_col_idx <= 1'b0;
                    out_col_idx <= 1'b0;
                    start_div <= 1'b0;

                    if((fuse_start || dec_fuse_pend) && is_mode_valid && !is_proj_mode
                       && (is_gemm_mode || dec_z_valid || (ENABLE_ONLINE_SOFTMAX != 0))) begin
                        fuse_active <= 1'b1;
                        fuse_state <= FUSE_ST_GQA;
                    end else if(fuse_start && is_mode_valid && is_proj_mode
                               && (is_gemm_mode || batch_num != 8'd0)) begin
                        fuse_active <= 1'b1;
                        fuse_state <= FUSE_ST_PROJ;
                    end
                end

                FUSE_ST_GQA: begin

                    ren0 <= !fuse_in_done && gqa_new_row && !emit_buf_sel;
                    ren1 <= !fuse_in_done && gqa_new_row && emit_buf_sel;
                    raddr0 <= fuse_in_idx + (BLOCK_ROW/CORE_NUM)*gqa_emit_cnt;
                    raddr1 <= fuse_in_idx + (BLOCK_ROW/CORE_NUM)*gqa_emit_cnt;
                    fuse_in_vld <= emit_buf_sel ? rvalid1 : rvalid0;
                    div_rdata <= (emit_buf_sel ? rvalid1 : rvalid0) ? (emit_buf_sel ? rdata1 : rdata0) : div_rdata;

                    if(!fuse_in_done && gqa_new_row) begin
                        fuse_in_idx <= fuse_in_idx + 1'b1;
                        if ((!is_proj_mode && is_gemm_mode && fuse_in_idx == (BLOCK_ROW/CORE_NUM)-1) ||
                            (!is_proj_mode && !is_gemm_mode && fuse_in_idx == q_row_num-1)) begin
                            fuse_in_idx <= {IDX_W{1'b0}};
                            fuse_in_done <= 1'b1;
                        end
                    end

                    gqa_new_row <= 1'b0;
                    gqa_new_row_cnt <= gqa_new_row_cnt + 1'b1;
                    if(gqa_new_row_cnt) begin
                        gqa_new_row_cnt <= 3'd0;
                        gqa_new_row <= 1'b1;
                    end

                    div_den_in <= (ENABLE_ONLINE_SOFTMAX != 0)
                                  ? onl_div_den
                                  : row_sum[process_row_idx+(BLOCK_ROW/CORE_NUM)*gqa_emit_cnt];
                    div_num_in <= div_rdata[process_col_idx*DATA_WIDTH*DIM +: DATA_WIDTH*DIM];
                    process_col_idx <= fuse_in_vld;
                    if(process_col_idx) begin
                        process_row_idx <= process_row_idx + 1'b1;
                        if(!is_proj_mode && is_gemm_mode && process_row_idx == (BLOCK_ROW/CORE_NUM)-1) begin
                            process_row_idx <= 8'd0;
                        end
                        if(!is_proj_mode && !is_gemm_mode && process_row_idx == q_row_num-1) begin
                            process_row_idx <= 8'd0;
                        end
                    end

                    out_col_idx <= process_col_idx;
                    div_out_vld <= fuse_in_vld || process_col_idx;
                    if(div_out_vld) begin
                        emit_data[(out_col_idx*DATA_WIDTH*DIM) +: DATA_WIDTH*DIM] <= div_out;
                        if(out_col_idx) begin
                            emit_vld <= 1'b1;
                            fuse_out_idx <= fuse_out_idx + 1'b1;
                            if ((!is_proj_mode && is_gemm_mode && fuse_out_idx == (BLOCK_ROW/CORE_NUM)-1) ||
                                (!is_proj_mode && !is_gemm_mode && fuse_out_idx == q_row_num-1)) begin
                                fuse_in_done <= 1'b0;
                                fuse_out_done <= 1'b1;
                                fuse_out_idx <= {IDX_W{1'b0}};
                                fuse_active <= 1'b0;
                                fuse_state <= FUSE_ST_IDLE;
                            end
                        end
                    end
                end

                FUSE_ST_PROJ: begin

                    ren0 <= !fuse_in_done && gemm_new_row && !emit_bank;
                    ren1 <= !fuse_in_done && gemm_new_row && emit_bank;
                    raddr0 <= is_gemm_mode ? {rd_slot, fuse_in_idx[6:0]} : (batch_cnt * (batch_space << 1) + fuse_in_idx);
                    raddr1 <= is_gemm_mode ? {rd_slot, fuse_in_idx[6:0]} : (batch_cnt * (batch_space << 1) + fuse_in_idx);
                    emit_vld <= emit_bank ? rvalid1 : rvalid0;
                    emit_data <= emit_bank ? rdata1 : rdata0;
`ifdef RESPROBE
                    if (!is_gemm_mode && (emit_buf_sel ? rvalid1 : rvalid0) && CORE_ID < 2)
                        $display("[DECEMIT] core=%0d t=%0t batch_cnt=%0d raddr=%0d emit_buf_sel=%b fuse_in_idx=%0d emit=%h",
                                 CORE_ID, $time, batch_cnt,
                                 (emit_buf_sel ? raddr1 : raddr0), emit_buf_sel, fuse_in_idx,
                                 (emit_buf_sel ? rdata1[15:0] : rdata0[15:0]));
`endif
                    // synopsys translate_off
                    `ifdef PRERMSPROBE
                    if (is_gemm_mode && (emit_buf_sel ? rvalid1 : rvalid0) && fuse_in_idx[6:0] == 7'd0)
                        $display("[PMUEMIT] t=%0t ebsel=%b rd_slot=%0d rdata_lo=%h",
                                 $time, emit_buf_sel, rd_slot,
                                 (emit_buf_sel ? rdata1[15:0] : rdata0[15:0]));
                    `endif
                    // synopsys translate_on

                    if(!fuse_in_done && gemm_new_row) begin
                        fuse_in_idx <= fuse_in_idx + 1'b1;
                        if (fuse_in_idx == (is_gemm_mode ? BLOCK_ROW : emit_row_num_eff) - 1) begin
                            fuse_in_idx <= {IDX_W{1'b0}};
                            fuse_in_done <= 1'b1;
                        end
                    end

                    gemm_new_row <= 1'b0;
                    gemm_new_row_cnt <= gemm_new_row_cnt + 1'b1;
                    if(gemm_new_row_cnt == 3'd3) begin
                        gemm_new_row_cnt <= 3'd0;
                        gemm_new_row <= 1'b1;
                    end

                    if(emit_bank ? rvalid1 : rvalid0) begin
                        fuse_out_idx <= fuse_out_idx + 1'b1;
                        if(fuse_out_idx == (is_gemm_mode ? BLOCK_ROW : emit_row_num_eff) - 1) begin
                            fuse_in_done <= 1'b0;
                            fuse_out_done <= 1'b1;
                            if(gemm_proj) begin
                                if(wcg_e == w_col_groups_r - 1) begin
                                    wcg_e        <= 4'd0;
                                    emit_arg     <= emit_arg + 9'd1;
                                    emit_buf_sel <= (emit_arg + 9'd1) & 9'd1;
                                end else begin
                                    wcg_e <= wcg_e + 4'd1;
                                end
                            end
                            fuse_out_idx <= {IDX_W{1'b0}};
                            fuse_active <= 1'b0;
                            fuse_state <= FUSE_ST_IDLE;
                            batch_cnt <= batch_cnt + 1'b1;
                            if(is_gemm_mode || batch_cnt == batch_num - 1) begin
                                batch_cnt <= 8'd0;
                                buffer_clear_trigger <= 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            fuse_start <= 1'b0;

            core_row_idx <= 8'd0;
            res_row_idx <= 8'd0;
            bundle_cnt <= 8'd0;

            acc_valid0 <= 1'b0;
            acc_valid1 <= 1'b0;
            overwrite0 <= 1'b0;
            overwrite1 <= 1'b0;
            acc_addr0 <= {($clog2(BLOCK_SIZE)){1'b0}};
            acc_addr1 <= {($clog2(BLOCK_SIZE)){1'b0}};
            acc_data0 <= {2*ACC_ROW_WIDTH{1'b0}};
            acc_data1 <= {2*ACC_ROW_WIDTH{1'b0}};
            residual_phase0 <= 1'b0;
            residual_phase1 <= 1'b0;

            result_pre_done <= 1'b0;
            result_pre_done_latch <= 1'b0;

            gqa_emit_cnt <= 6'd0;
            proj_emit_cnt <= 6'd0;
            gemv_fuse_delay_cnt <= 3'd0;
            gemv_emit_pending <= 1'b0;
            gemv_wr_drained <= 1'b0;

            buffer_sel <= 1'b0;
            emit_buf_sel <= 1'b0;
            buffer_clear <= 1'b0;
            seq_tile_idx <= 2'd0;
            emit_seq_tile <= 2'd0;
            arg_w <= 9'd0; wcg_w <= 4'd0; seq_iq <= 2'd0; blk_written <= 16'd0;
            emit_arg <= 9'd0; wcg_e <= 4'd0;
            act_row_groups_r <= 9'd1; w_col_groups_r <= 9'd1; expected_blocks <= 16'd0;

            tile_accum_cnt <= 16'd0;
            hidden_dim_cnt <= 9'd0;
            output_dim_cnt <= 9'd0;

            output_dim_remaining <= 9'd0;
            emit_row_num         <= 9'd0;

        end else begin
            fuse_start <= 1'b0;
            result_pre_done <= 1'b0;
            buffer_clear <= 1'b0;

            if(isa_valid) begin
                tile_accum_cnt       <= 16'd0;
                hidden_dim_cnt       <= 9'd0;
                output_dim_cnt       <= 9'd0;
                buffer_sel           <= 1'b0;
                emit_buf_sel         <= 1'b0;
                seq_tile_idx         <= 2'd0;
                emit_seq_tile        <= 2'd0;
                arg_w <= 9'd0; wcg_w <= 4'd0; seq_iq <= 2'd0; blk_written <= 16'd0;
                emit_arg <= 9'd0; wcg_e <= 4'd0;
                act_row_groups_r <= is_gating ? (seq_row_tiles == 9'd0 ? 9'd1 : seq_row_tiles)
                                              : ((seq_row_tiles >> A_SHIFT) == 9'd0 ? 9'd1 : (seq_row_tiles >> A_SHIFT));
                w_col_groups_r   <= is_gating ? ((output_dim / GATE_TILES) == 9'd0 ? 9'd1 : (output_dim / GATE_TILES))
                                              : ((output_dim >> W_SHIFT) == 9'd0 ? 9'd1 : (output_dim >> W_SHIFT));
                expected_blocks  <= (is_gating ? (seq_row_tiles == 9'd0 ? 16'd1 : seq_row_tiles)
                                               : ((seq_row_tiles >> A_SHIFT) == 9'd0 ? 16'd1 : (seq_row_tiles >> A_SHIFT)))
                                  * (is_gating ? ((output_dim / GATE_TILES) == 9'd0 ? 16'd1 : (output_dim / GATE_TILES))
                                               : ((output_dim >> W_SHIFT) == 9'd0 ? 16'd1 : (output_dim >> W_SHIFT)));
                output_dim_remaining <= output_dim;
                emit_row_num         <= 9'd0;
                proj_emit_cnt        <= 6'd0;
                gqa_emit_cnt         <= 6'd0;
                gemv_emit_pending    <= 1'b0;
                gemv_wr_drained      <= 1'b0;
                bundle_cnt           <= 8'd0;
                result_pre_done_latch <= 1'b0;
            end

            if(result_pre_done && is_proj_mode && !is_gemm_mode) begin
                buffer_sel <= ~buffer_sel;
                emit_buf_sel <= buffer_sel;
                emit_row_num <= output_dim_remaining;
                if(output_dim_remaining > {1'b0, batch_space}) begin
                    output_dim_remaining <= output_dim_remaining - {1'b0, batch_space};
                end
            end

            if (is_proj_mode && !is_gemm_mode) begin
                if (start_emit) gemv_emit_pending <= 1'b1;
                if (result_pre_done_latch) begin
                    if (!(emit_buf_sel ? pip_empty1 : pip_empty0))
                        gemv_wr_drained <= 1'b1;
                end
                if ((gemv_emit_pending || start_emit) && result_pre_done_latch &&
                    (gemv_wr_drained || batch_cnt != 8'd0) && (emit_buf_sel ? pip_empty1 : pip_empty0)) begin
                    fuse_start        <= 1'b1;
                    gemv_emit_pending <= 1'b0;
                    gemv_wr_drained   <= 1'b0;
                end
            end else if (gemm_proj) begin
                if (emit_arg == 9'd0 && wcg_e == 4'd0) begin
                    if (start_emit) gemv_emit_pending <= 1'b1;
                    if (result_pre_done_latch && !(emit_buf_sel ? pip_empty1 : pip_empty0))
                        gemv_wr_drained <= 1'b1;
                    if ((gemv_emit_pending || start_emit) && result_pre_done_latch &&
                        gemv_wr_drained && (emit_buf_sel ? pip_empty1 : pip_empty0)) begin
                        fuse_start        <= 1'b1;
                        gemv_emit_pending <= 1'b0;
                        gemv_wr_drained   <= 1'b0;
                    end
                end else if (start_emit) begin
                    fuse_start <= 1'b1;
                end
            end else if (start_emit) begin
                fuse_start <= 1'b1;
            end

            if(fuse_out_done) begin
                if(!is_proj_mode) begin
                    if(is_gemm_mode) begin
                        gqa_emit_cnt <= gqa_emit_cnt + 6'd1;
                        if(gqa_emit_cnt * (BLOCK_ROW/CORE_NUM) == q_row_num - (BLOCK_ROW/CORE_NUM)) begin
                            result_pre_done_latch <= 1'b0;
                            gqa_emit_cnt <= 6'd0;
                            proj_emit_cnt <= 6'd0;
                            buffer_clear <= 1'b1;
                        end
                    end else begin
                        gqa_emit_cnt <= 6'd0;
                        proj_emit_cnt <= 6'd0;
                        result_pre_done_latch <= 1'b0;
                        buffer_clear <= 1'b1;
                    end
                end else begin
                    if(is_gemm_mode || (!is_gemm_mode && buffer_clear_trigger)) begin
                        gqa_emit_cnt <= 6'd0;
                        proj_emit_cnt <= 6'd0;
                        result_pre_done_latch <= 1'b0;
                        buffer_clear <= 1'b1;
                    end
                end
            end

            if (is_mode_valid && is_proj_mode && (is_gemm_mode || batch_num != 8'd0)) begin

                acc_valid0 <= (wr_gate && mpu_row_valid && !wr_bank) || (residual_row_vld && (is_gemm_mode || !res_row_idx[0]) && wr_bank);
                acc_valid1 <= (wr_gate && mpu_row_valid && wr_bank) || (residual_row_vld && (is_gemm_mode || !res_row_idx[0]) && !wr_bank);
                overwrite0 <= (is_gemm_mode ? (tile_accum_cnt == 16'd0) : ((hidden_dim_cnt == 9'd0) && (output_dim_cnt[0] == 1'b0))) && wr_gate && mpu_row_valid && !wr_bank;
                overwrite1 <= (is_gemm_mode ? (tile_accum_cnt == 16'd0) : ((hidden_dim_cnt == 9'd0) && (output_dim_cnt[0] == 1'b0))) && wr_gate && mpu_row_valid && wr_bank;
                acc_addr0 <= is_gemm_mode ? {wr_slot, (residual_row_vld ? res_row_idx[6:0] : core_row_idx[6:0])} : (core_row_idx * (batch_space << 1) + output_dim_cnt);
                acc_addr1 <= is_gemm_mode ? {wr_slot, (residual_row_vld ? res_row_idx[6:0] : core_row_idx[6:0])} : (core_row_idx * (batch_space << 1) + output_dim_cnt);
                acc_data0 <= residual_row_vld ? residual_row_fp24 : {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                acc_data1 <= residual_row_vld ? residual_row_fp24 : {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                residual_phase0 <= residual_row_vld && buffer_sel;
                residual_phase1 <= residual_row_vld && !buffer_sel;

                if (residual_row_vld) res_row_idx <= res_row_idx + 1'b1;
`ifdef RESPROBE
                if (!is_gemm_mode && residual_row_vld && CORE_ID < 2)
                    $display("[DECRACC] core=%0d t=%0t acc_addr=%0d res_row_idx=%0d core_row_idx=%0d buffer_sel=%b res_bank=%0d resval=%h",
                             CORE_ID, $time, (buffer_sel ? acc_addr1 : acc_addr0), res_row_idx,
                             core_row_idx, buffer_sel, (buffer_sel ? 0 : 1), residual_row_fp24[15:0]);
`endif

`ifdef RESPROBE
                if (!is_gemm_mode && mpu_row_valid && CORE_ID < 2)
                    $display("[DECACC] core=%0d t=%0t core_row_idx=%0d acc_addr=%0d buffer_sel=%b batch_cnt=%0d mpu=%h",
                             CORE_ID, $time, core_row_idx,
                             core_row_idx*batch_space + output_dim_cnt, buffer_sel, batch_cnt, mpu_row_data[23:8]);
`endif
                if (mpu_row_valid) begin
                    core_row_idx <= core_row_idx + 1'b1;
                    if(is_gemm_mode) begin
                        output_dim_cnt <= 9'd0;
                        if(core_row_idx == q_row_num - 1) begin
                            core_row_idx <= 8'd0;
                            tile_accum_cnt <= tile_accum_cnt + 16'd1;
                            if(tile_accum_cnt == hidden_dim - 1) begin
                                tile_accum_cnt <= 16'd0;
                                result_pre_done <= 1'b1;
                                result_pre_done_latch <= 1'b1;
                                res_row_idx <= 8'd0;
                                if(gemm_proj && (blk_written < expected_blocks)) begin
                                    blk_written <= blk_written + 16'd1;
                                    if(wcg_w == w_col_groups_r - 1) begin
                                        wcg_w      <= 4'd0;
                                        arg_w      <= arg_w + 9'd1;
                                        buffer_sel <= (arg_w + 9'd1) & 9'd1;
                                    end else begin
                                        wcg_w <= wcg_w + 4'd1;
                                    end
                                end
                            end
                        end
                    end else begin
                        tile_accum_cnt <= 16'd0;
                        if(core_row_idx == batch_num - 1) begin
                            core_row_idx <= 8'd0;
                            output_dim_cnt <= output_dim_cnt + 9'd1;
                            if(output_dim_cnt == batch_space_eff - 1) begin
                                output_dim_cnt <= 9'd0;
                                hidden_dim_cnt <= hidden_dim_cnt + 9'd1;
                                if(hidden_dim_cnt == hidden_dim - 1) begin
                                    hidden_dim_cnt <= 9'd0;
                                    result_pre_done <= 1'b1;
                                    result_pre_done_latch <= 1'b1;
                                end
                            end
                        end
                    end
                end

            end else if (is_mode_valid && !is_proj_mode && is_gemm_mode) begin

                acc_valid0 <= mpu_row_valid && !buffer_sel && score_result_toggle;
                acc_valid1 <= mpu_row_valid && buffer_sel && score_result_toggle;
                acc_addr0 <= core_row_idx;
                acc_addr1 <= core_row_idx;
                acc_data0 <= {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                acc_data1 <= {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                residual_phase0 <= 1'b0;
                residual_phase1 <= 1'b0;

                if (mpu_row_valid) begin
                    core_row_idx <= core_row_idx + 1'b1;
                    if(core_row_idx == q_row_num-1) begin
                        core_row_idx <= 8'd0;
                        if(all_scores_generated) begin
                            result_pre_done <= 1'b1;
                            result_pre_done_latch <= 1'b1;
                        end
                    end
                end

            end else if (is_mode_valid && !is_proj_mode && !is_gemm_mode) begin

                acc_valid0 <= mpu_row_valid && !buffer_sel && score_result_toggle;
                acc_valid1 <= mpu_row_valid && buffer_sel && score_result_toggle;
                acc_addr0 <= core_row_idx;
                acc_addr1 <= core_row_idx;
                acc_data0 <= {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                acc_data1 <= {{ACC_ROW_WIDTH{1'b0}}, mpu_row_data};
                residual_phase0 <= 1'b0;
                residual_phase1 <= 1'b0;

                if (mpu_row_valid) begin
                    core_row_idx <= core_row_idx + 1'b1;
                    if(core_row_idx == q_row_num-1) begin
                        core_row_idx <= 8'd0;
                        bundle_cnt <= bundle_cnt + 1'b1;
                        if(bundle_cnt == BUNDLE_PAIR_NUM - 1) begin
                            bundle_cnt <= 8'd0;
                            if(score_result_toggle) begin
                                result_pre_done <= 1'b1;
                                result_pre_done_latch <= 1'b1;
                            end
                        end
                    end
                end

            end else begin
                acc_valid0 <= 1'b0;
                acc_valid1 <= 1'b0;
                residual_phase0 <= 1'b0;
                residual_phase1 <= 1'b0;
                acc_addr0 <= {$clog2(BLOCK_SIZE){1'b0}};
                acc_addr1 <= {$clog2(BLOCK_SIZE){1'b0}};
                acc_data0 <= {2*ACC_ROW_WIDTH{1'b0}};
                acc_data1 <= {2*ACC_ROW_WIDTH{1'b0}};
                core_row_idx <= 8'd0;
            end
        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            for (ai = 0; ai < BLOCK_SIZE; ai = ai + 1) begin
                row_sum[ai] <= {DATA_WIDTH{1'b0}};
            end

        end else begin
            if(row_sum_vld && (ENABLE_ONLINE_SOFTMAX == 0)) begin
                for(ai = 0; ai < BLOCK_SIZE; ai = ai + 1) begin
                    row_sum[ai] <= row_sum_val[(ai*DATA_WIDTH) +: DATA_WIDTH];
                end
            end
            if((buffer_clear && !score_result_toggle) || isa_valid) begin
                for (ai = 0; ai < BLOCK_SIZE; ai = ai + 1) begin
                    row_sum[ai] <= {DATA_WIDTH{1'b0}};
                end
            end
        end
    end

    generate
    for(i=0; i<DIM; i=i+1)
    DW_fp_div_inst u_DW_fp_div_inst (
        .inst_a(div_num_in[i*DATA_WIDTH +: DATA_WIDTH]),
        .inst_b(div_den_in),
        .inst_rnd(3'd0),
        .z_inst(div_out[i*DATA_WIDTH +: DATA_WIDTH]),
        .status_inst()
    );
    endgenerate

    `ifdef RESPROBE
    integer resp_b0, resp_b1, resp_em;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin resp_b0<=0; resp_b1<=0; resp_em<=0; end
        else begin
            if (residual_row_vld &&  buffer_sel) resp_b0 <= resp_b0 + 1;
            if (residual_row_vld && !buffer_sel) resp_b1 <= resp_b1 + 1;
            if (emit_vld && gemm_proj)           resp_em <= resp_em + 1;
            if (isa_valid && (resp_b0|resp_b1|resp_em)!=0)
                $display("[RESCORE] core=%0d resid->bank0=%0d resid->bank1=%0d emit=%0d last_embufsel=%b last_wr_slot=%0d last_rd_slot=%0d",
                         CORE_ID, resp_b0, resp_b1, resp_em, emit_buf_sel, wr_slot, rd_slot);
        end
    end
    always @(posedge core_clk) begin
        if (rst_n && acc_valid0 && (CORE_ID == 0 || CORE_ID == 4))
            $display("[BK0WR] t=%0t core=%0d addr=%0d rphase=%b ovw=%b data_lo=%h",
                     $time, CORE_ID, acc_addr0, residual_phase0, overwrite0, acc_data0[15:0]);
        if (rst_n && residual_row_vld)
            $display("[RESACC] core=%0d bufsel=%b av0=%b av1=%b wr_slot=%0d accaddr0=%0d accaddr1=%0d resid_lo=%h",
                     CORE_ID, buffer_sel, acc_valid0, acc_valid1, wr_slot, acc_addr0, acc_addr1, residual_row_data[15:0]);
        if (rst_n && (CORE_ID == 0 || CORE_ID == 4) && u_concat_accum_buffer_sram_0.acc_internal_vld)
            $display("[INTADDR] t=%0t core=%0d rphase=%b int_addr=%0d res1cnt=%0d ovw=%b data_lo=%h",
                     $time, CORE_ID, u_concat_accum_buffer_sram_0.residual_phase,
                     u_concat_accum_buffer_sram_0.acc_internal_addr,
                     u_concat_accum_buffer_sram_0.res1_counter,
                     u_concat_accum_buffer_sram_0.overwrite_internal,
                     u_concat_accum_buffer_sram_0.acc_internal_data[15:0]);
        if (rst_n && emit_vld && gemm_proj && (CORE_ID == 0 || CORE_ID == 4))
            $display("[RESEMIT] t=%0t core=%0d embufsel=%b raddr0=%0d rd0=%h emit_lo=%h",
                     $time, CORE_ID, emit_buf_sel, raddr0, rdata0[15:0], emit_data[15:0]);
    end
    `endif

// synopsys translate_off
`ifdef GQAPVPROBE
    integer ph_wraps, ph_rpd, ph_lines;
    initial begin ph_wraps = 0; ph_rpd = 0; ph_lines = 0; end
    always @(posedge core_clk) if (rst_n && !is_proj_mode) begin
        if (mpu_row_valid && core_row_idx == q_row_num - 1) begin
            ph_wraps = ph_wraps + 1;
            if (ph_lines < 40) begin
                ph_lines = ph_lines + 1;
                $display("[PMUPH] t=%0t wrap=%0d bundle_cnt=%0d toggle=%b gemm=%b q_row_num=%0d", $time, ph_wraps, bundle_cnt, score_result_toggle, is_gemm_mode, q_row_num);
            end
        end
        if (result_pre_done) ph_rpd = ph_rpd + 1;
    end
    final $display("[PMUPH-SUM] row_wraps=%0d result_pre_done=%0d BUNDLE_PAIR_NUM=%0d", ph_wraps, ph_rpd, BUNDLE_PAIR_NUM);
    integer pe_rsv, pe_fs, pe_fa, pe_lines; reg pe_fa_q;
    initial begin pe_rsv = 0; pe_fs = 0; pe_fa = 0; pe_lines = 0; pe_fa_q = 0; end
    always @(posedge core_clk) if (rst_n && !is_proj_mode && !is_gemm_mode) begin
        if (row_sum_vld) pe_rsv = pe_rsv + 1;
        if (fuse_start) pe_fs = pe_fs + 1;
        if (fuse_active && !pe_fa_q) pe_fa = pe_fa + 1;
        if (pe_lines < 24 && (fuse_start || row_sum_vld || (fuse_active != pe_fa_q))) begin
            pe_lines = pe_lines + 1;
            $display("[PMUEMIT] t=%0t fuse_start=%b row_sum_vld=%b dec_z_valid=%b dec_fuse_pend=%b fuse_active=%b", $time, fuse_start, row_sum_vld, dec_z_valid, dec_fuse_pend, fuse_active);
        end
        pe_fa_q = fuse_active;
    end
    final $display("[PMUEMIT-SUM] row_sum_vld=%0d fuse_start=%0d fuse_active_rises=%0d", pe_rsv, pe_fs, pe_fa);
`endif
// synopsys translate_on

endmodule
