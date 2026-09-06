// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire
module pre_softmax #(
    parameter DATA_WIDTH = 16,
    parameter IN_WIDTH   = 24,
    parameter DATA_NUM = 128,
    parameter BLOCK_ROW = 128,
    parameter HID_DIM = 4096,
    parameter HEAD_DIM = 128,
    parameter SUB_OUT_LATENCY = 1,
    parameter EXP_OUT_LATENCY = 4,
    parameter PSM_BUFFER_SIZE = 128,
    parameter BUNDLE_PAIR_NUM = 4,
    parameter LOOP_NUM = 4,
    parameter integer CORE_ID = 0,
    parameter integer SEQ_PER_CORE = 16
)
(
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire in_vld,
    input wire reduce_max_vld,
    input wire diag_done,
    input wire prefill,
    input wire quant_kv,
    input wire causal_mode,
    input wire [IN_WIDTH*DATA_NUM-1:0] d_in,
    input wire [DATA_WIDTH-1:0] constant_max,
    input wire [7:0] q_row_num,

    output reg [DATA_WIDTH*DATA_NUM-1:0] score_out,
    output reg score_out_vld,
    output reg [DATA_WIDTH*BLOCK_ROW-1:0] row_sum_out,
    output reg row_sum_vld,

    output reg                         ps_done
);
    localparam DIM = DATA_NUM / LOOP_NUM;
    localparam INDEX_FIFO_DEPTH = 8;
    localparam TIMEOUT_CYCLES = 100000;
    localparam [IN_WIDTH-1:0] SCALE = 24'h3E0294;

    genvar i;

    integer k;
    integer s;
    integer t;

    reg  [IN_WIDTH*DATA_NUM-1:0] mult_out_bf16;
    reg                            mult_out_vld;

    reg [IN_WIDTH*DATA_NUM-1:0] d_in_reg;
    reg [2:0] mult_cnt;
    reg       mult_vld;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mult_cnt <= 3'd0;
            mult_out_vld <= 1'b0;
            mult_vld <= 1'b0;
            d_in_reg <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else if (isa_valid) begin
            mult_cnt <= 3'd0;
            mult_out_vld <= 1'b0;
            mult_vld <= 1'b0;
            d_in_reg <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else begin
            mult_out_vld <= 1'b0;
            if(mult_cnt == 3'd1) begin
                mult_cnt <= 3'd0;
                mult_vld <= 1'b0;
                mult_out_vld <= 1'b1;
                if(in_vld && reduce_max_vld) begin
                    d_in_reg <= d_in;
                    mult_cnt <= LOOP_NUM[2:0];
                    mult_vld <= 1'b1;
                end
            end else if(mult_cnt != 0) begin
                mult_cnt <= mult_cnt - 3'd1;
            end else if(in_vld && reduce_max_vld) begin
                d_in_reg <= d_in;
                mult_cnt <= LOOP_NUM[2:0];
                mult_vld <= 1'b1;
            end
        end
    end

    generate
    for (i=0; i<DIM; i=i+1) begin : GENERATE_SUB
        wire [IN_WIDTH-1:0] a_bf16 = d_in_reg[IN_WIDTH*(i+DIM*(mult_cnt-1))+:IN_WIDTH];
        wire [IN_WIDTH-1:0] b_bf16 = SCALE;
        wire [IN_WIDTH-1:0] z_bf16;
        DW_fp_mult_inst #(
            .sig_width(15),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_dw_bf16_mult (
            .inst_a  (a_bf16),
            .inst_b  (b_bf16),
            .inst_rnd(3'b000),
            .z_inst  (z_bf16),
            .status_inst()
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (s = 0; s < LOOP_NUM; s = s + 1) begin
                    mult_out_bf16[IN_WIDTH*(i + DIM*s) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (isa_valid) begin
                for (s = 0; s < LOOP_NUM; s = s + 1) begin
                    mult_out_bf16[IN_WIDTH*(i + DIM*s) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (mult_vld) begin
                mult_out_bf16[IN_WIDTH*(i + DIM*(mult_cnt-1)) +:IN_WIDTH] <= z_bf16;
            end
        end
    end
    endgenerate

    reg  [IN_WIDTH*DATA_NUM-1:0] sub_out_bf16;
    reg                            sub_out_vld;
    reg [IN_WIDTH*DATA_NUM-1:0] sub_reg;
    reg [2:0] sub_cnt;
    reg       sub_vld;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sub_cnt <= 3'd0;
            sub_out_vld <= 1'b0;
            sub_vld <= 1'b0;
            sub_reg <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else if (isa_valid) begin
            sub_cnt <= 3'd0;
            sub_out_vld <= 1'b0;
            sub_vld <= 1'b0;
            sub_reg <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else begin
            sub_out_vld <= 1'b0;
            if(sub_cnt == 3'd1) begin
                sub_cnt <= 3'd0;
                sub_vld <= 1'b0;
                sub_out_vld <= 1'b1;
                if(mult_out_vld) begin
                    sub_reg <= mult_out_bf16;
                    sub_cnt <= LOOP_NUM[2:0];
                    sub_vld <= 1'b1;
                end
            end else if(sub_cnt != 0) begin
                sub_cnt <= sub_cnt - 3'd1;
            end else if(mult_out_vld) begin
                sub_reg <= mult_out_bf16;
                sub_cnt <= LOOP_NUM[2:0];
                sub_vld <= 1'b1;
            end
        end
    end

    generate
    for (i=0; i<DIM; i=i+1) begin : GENERATE_SUB_STAGE
        wire [IN_WIDTH-1:0] a_bf16 = sub_reg[IN_WIDTH*(i+DIM*(sub_cnt-1))+:IN_WIDTH];
        wire [IN_WIDTH-1:0] b_bf16 = reduce_max_vld ? {constant_max, 8'd0} : {IN_WIDTH{1'b0}};
        wire [IN_WIDTH-1:0] z_bf16;
        wire [7:0]  st_sub_unused;
        DW_fp_addsub_inst #(
            .sig_width(15),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_dw_bf16_sub (
            .inst_a  (a_bf16),
            .inst_b  (b_bf16),
            .inst_rnd(3'b000),
            .inst_op (1'b1),
            .z_inst  (z_bf16),
            .status_inst(st_sub_unused)
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (s = 0; s < LOOP_NUM; s = s + 1) begin
                    sub_out_bf16[IN_WIDTH*(i + DIM*s) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (isa_valid) begin
                for (s = 0; s < LOOP_NUM; s = s + 1) begin
                    sub_out_bf16[IN_WIDTH*(i + DIM*s) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (sub_vld) begin
                sub_out_bf16[IN_WIDTH*(i + DIM*(sub_cnt-1)) +:IN_WIDTH] <= z_bf16;
            end
        end
    end
    endgenerate

    reg  [IN_WIDTH*DATA_NUM-1:0] sub_out_bf16_pip;
    reg                            exp_out_vld;
    reg  [IN_WIDTH*DATA_NUM-1:0] exp_out_bf16;
    reg [2:0] exp_cnt;
    reg exp_vld;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            exp_cnt <= 3'd0;
            exp_out_vld <= 1'b0;
            exp_vld <= 1'b0;
            sub_out_bf16_pip <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else if (isa_valid) begin
            exp_cnt <= 3'd0;
            exp_out_vld <= 1'b0;
            exp_vld <= 1'b0;
            sub_out_bf16_pip <= {IN_WIDTH*DATA_NUM{1'b0}};
        end else begin
            exp_out_vld <= 1'b0;
            if(exp_cnt == 3'd1) begin
                exp_cnt <= 3'd0;
                exp_vld <= 1'b0;
                exp_out_vld <= 1'b1;
                if(sub_out_vld) begin
                    sub_out_bf16_pip <= sub_out_bf16;
                    exp_cnt <= LOOP_NUM[2:0];
                    exp_vld <= 1'b1;
                end
            end else if(exp_cnt != 0) begin
                exp_cnt <= exp_cnt - 3'd1;
            end else if(sub_out_vld) begin
                sub_out_bf16_pip <= sub_out_bf16;
                exp_cnt <= LOOP_NUM[2:0];
                exp_vld <= 1'b1;
            end
        end
    end

    generate
    for (i=0; i<DIM; i=i+1) begin : GENERATE_EXP
        wire [IN_WIDTH-1:0] exp_in_bf16  = sub_out_bf16_pip[IN_WIDTH*(i+DIM*(exp_cnt-1))+:IN_WIDTH];
        wire [IN_WIDTH-1:0] exp_out_lane;
        wire [7:0]  st_exp_unused;
        DW_fp_exp2_inst #(
            .inst_sig_width(15),
            .inst_exp_width(8),
            .inst_ieee_compliance(0),
            .inst_arch(2)
        ) u_dw_bf16_exp (
            .inst_a(exp_in_bf16),
            .z_inst(exp_out_lane),
            .status_inst(st_exp_unused)
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (t = 0; t < LOOP_NUM; t = t + 1) begin
                    exp_out_bf16[IN_WIDTH*(i + DIM*t) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (isa_valid) begin
                for (t = 0; t < LOOP_NUM; t = t + 1) begin
                    exp_out_bf16[IN_WIDTH*(i + DIM*t) +: IN_WIDTH] <= {IN_WIDTH{1'b0}};
                end
            end else if (exp_vld) begin
                exp_out_bf16[IN_WIDTH*(i + DIM*(exp_cnt-1)) +:IN_WIDTH] <= exp_out_lane;
            end
        end
    end
    endgenerate

    wire row_out_vld_w = exp_out_vld;
    reg  row_out_vld_w_r;
    reg  [IN_WIDTH*DATA_NUM-1:0] exp_out_bf16_r;
    reg  [IN_WIDTH*DATA_NUM-1:0] row_masked_bf16_r;
    reg  [7:0] row_out_idx_r;
    reg  [7:0] bundle_cnt_r;
    reg        diag_done_r;
    reg diag_seen;
    reg diag_clear;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) diag_seen <= 1'b0;
        else if (isa_valid || diag_clear) diag_seen <= 1'b0;
        else if (diag_done) diag_seen <= 1'b1;
    end
    reg last_pending;

    reg [7:0] row_out_idx;
    reg [7:0] bundle_cnt;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_out_idx <= 8'd0;
            bundle_cnt <= 0;
        end else if (isa_valid) begin
            row_out_idx <= 8'd0;
            bundle_cnt <= 0;
        end else if (row_out_vld_w) begin
            if (prefill) begin
                if (row_out_idx == q_row_num-1) begin
                    row_out_idx <= 8'd0;
                end else begin
                    row_out_idx <= row_out_idx + 8'd1;
                end
            end else begin
                if (row_out_idx == q_row_num-1) begin
                    row_out_idx <= 8'd0;
                    bundle_cnt <= bundle_cnt + 1;
                    if(bundle_cnt == BUNDLE_PAIR_NUM-1) begin
                        bundle_cnt <= 0;
                    end
                end else begin
                    row_out_idx <= row_out_idx + 8'd1;
                end
            end
        end
    end

    wire [IN_WIDTH*DATA_NUM-1:0] row_masked_bf16;
    wire apply_tri_mask = diag_done && prefill;
    reg fullcausal_mode;
    initial fullcausal_mode = $test$plusargs("FULLCAUSAL");
    wire fullcausal_eff = causal_mode || fullcausal_mode;
    wire [7:0] mask_bound = fullcausal_eff
        ? (CORE_ID*SEQ_PER_CORE + (row_out_idx % SEQ_PER_CORE))
        : row_out_idx;
    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GEN_MASK
        assign row_masked_bf16[IN_WIDTH*i+:IN_WIDTH] =
                    (apply_tri_mask && (i > mask_bound)) ?
                        {IN_WIDTH{1'b0}} : exp_out_bf16[IN_WIDTH*i+:IN_WIDTH];
    end
    endgenerate

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_out_vld_w_r  <= 1'b0;
            exp_out_bf16_r   <= {IN_WIDTH*DATA_NUM{1'b0}};
            row_masked_bf16_r<= {IN_WIDTH*DATA_NUM{1'b0}};
            row_out_idx_r    <= 8'd0;
            bundle_cnt_r     <= 8'd0;
            diag_done_r      <= 1'b0;
        end else if (isa_valid) begin
            row_out_vld_w_r  <= 1'b0;
            exp_out_bf16_r   <= {IN_WIDTH*DATA_NUM{1'b0}};
            row_masked_bf16_r<= {IN_WIDTH*DATA_NUM{1'b0}};
            row_out_idx_r    <= 8'd0;
            bundle_cnt_r     <= 8'd0;
            diag_done_r      <= 1'b0;
        end else begin
            row_out_vld_w_r <= row_out_vld_w;
            if (row_out_vld_w) begin
                exp_out_bf16_r    <= exp_out_bf16;
                row_masked_bf16_r <= row_masked_bf16;
                row_out_idx_r     <= row_out_idx;
                bundle_cnt_r      <= bundle_cnt;
                diag_done_r       <= diag_done;
            end
        end
    end

    wire [IN_WIDTH*DATA_NUM-1:0] score_src_fp24 =
        diag_done_r ? row_masked_bf16_r : exp_out_bf16_r;
    wire [DATA_WIDTH*DATA_NUM-1:0] score_src_bf16;
    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GEN_SCORE_FP24_TO_BF16
        assign score_src_bf16[DATA_WIDTH*i +: DATA_WIDTH] =
            {score_src_fp24[IN_WIDTH*i + 23],
             score_src_fp24[IN_WIDTH*i + 22 -: 8],
             score_src_fp24[IN_WIDTH*i + 14 -: 7]};
    end
    endgenerate

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            score_out <= 0;
            score_out_vld <= 1'b0;
            ps_done <= 1'b0;
        end else if (isa_valid) begin
            score_out <= 0;
            score_out_vld <= 1'b0;
            ps_done <= 1'b0;
        end else begin
            ps_done <= 1'b0;
            if (row_out_vld_w_r) begin
                score_out <= score_src_bf16;
                score_out_vld <= 1'b1;
                if(prefill) begin
                    if(row_out_idx_r == q_row_num - 1) begin
                        ps_done <= 1'b1;
                    end
                end else begin
                    if(row_out_idx_r == q_row_num - 1 && bundle_cnt_r == BUNDLE_PAIR_NUM - 1) begin
                        ps_done <= 1'b1;
                    end
                end
            end else begin
                score_out_vld <= 1'b0;
            end
        end
    end

    localparam integer PSM_SIGN_WIDTH = 1;
    localparam integer PSM_EXP_WIDTH  = 8;
    localparam integer PSM_MANT_WIDTH = 15;
    localparam integer PSM_MANT_OUT_WIDTH = (1+PSM_MANT_WIDTH)*2 + PSM_SIGN_WIDTH;
    localparam integer PSM_ADDER_TREE_OUT = PSM_MANT_OUT_WIDTH + 7;

    wire [PSM_EXP_WIDTH-1:0]            psm_exp_out;
    wire [DATA_NUM*PSM_MANT_OUT_WIDTH-1:0] psm_mant_out;

    pre_process_fmat #(
        .DATA_WIDTH (IN_WIDTH),
        .DATA_NUM   (DATA_NUM),
        .SIGN_WIDTH (PSM_SIGN_WIDTH),
        .EXP_WIDTH  (PSM_EXP_WIDTH),
        .MANT_WIDTH (PSM_MANT_WIDTH)
    ) u_psm_pre_process (
        .d_in    (diag_done_r ? row_masked_bf16_r : exp_out_bf16_r),
        .exp_out (psm_exp_out),
        .mant_out(psm_mant_out)
    );

    reg                                   psm_vld_pre_r;
    reg [PSM_EXP_WIDTH-1:0]               psm_exp_out_r;
    reg [DATA_NUM*PSM_MANT_OUT_WIDTH-1:0] psm_mant_out_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psm_vld_pre_r   <= 1'b0;
            psm_exp_out_r   <= {PSM_EXP_WIDTH{1'b0}};
            psm_mant_out_r  <= {DATA_NUM*PSM_MANT_OUT_WIDTH{1'b0}};
        end else if (isa_valid) begin
            psm_vld_pre_r   <= 1'b0;
            psm_exp_out_r   <= {PSM_EXP_WIDTH{1'b0}};
            psm_mant_out_r  <= {DATA_NUM*PSM_MANT_OUT_WIDTH{1'b0}};
        end else begin
            psm_vld_pre_r   <= row_out_vld_w_r;
            psm_exp_out_r   <= psm_exp_out;
            psm_mant_out_r  <= psm_mant_out;
        end
    end

    wire [PSM_ADDER_TREE_OUT-1:0]        psm_adder_tree_out;
    adder_tree_fmat #(
        .DATA_WIDTH_IN (PSM_MANT_OUT_WIDTH),
        .DATA_WIDTH_OUT(PSM_ADDER_TREE_OUT),
        .DIMENSION     (DATA_NUM)
    ) u_psm_adder_tree (
        .d_in   (psm_mant_out_r),
        .d_out  (psm_adder_tree_out)
    );

    reg psm_vld_adder_tree_pip;
    reg [PSM_ADDER_TREE_OUT-1:0] psm_adder_tree_out_pip;
    reg [PSM_EXP_WIDTH-1:0] psm_exp_out_r_pip;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psm_vld_adder_tree_pip <= 1'b0;
            psm_adder_tree_out_pip <= {PSM_ADDER_TREE_OUT{1'b0}};
            psm_exp_out_r_pip      <= {PSM_EXP_WIDTH{1'b0}};
        end else if (isa_valid) begin
            psm_vld_adder_tree_pip <= 1'b0;
            psm_adder_tree_out_pip <= {PSM_ADDER_TREE_OUT{1'b0}};
            psm_exp_out_r_pip      <= {PSM_EXP_WIDTH{1'b0}};
        end else begin
            psm_vld_adder_tree_pip <= psm_vld_pre_r;
            psm_adder_tree_out_pip <= psm_adder_tree_out;
            psm_exp_out_r_pip   <= psm_exp_out_r;
        end
    end

    reg                     row_sum_bf16_vld;
    wire [IN_WIDTH-1:0]     row_sum_fp24;

    wire [7:0] exp_in_norm = psm_exp_out_r_pip;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_sum_bf16_vld <= 1'b0;
        end else if (isa_valid) begin
            row_sum_bf16_vld <= 1'b0;
        end else begin
            row_sum_bf16_vld <= 1'b0;
            if (psm_vld_adder_tree_pip) begin
                row_sum_bf16_vld <= 1'b1;
            end
        end
    end

    norm_round_fmat #(
        .MANT_WIDTH_IN(PSM_ADDER_TREE_OUT),
        .EXP_WIDTH_IN (PSM_EXP_WIDTH),
        .DATA_WIDTH_OUT(IN_WIDTH)
    ) u_psm_norm_round (
        .exp_in (exp_in_norm),
        .mant_in(psm_adder_tree_out_pip),
        .d_out  (row_sum_fp24)
    );

    reg [7:0] idx_fifo [0:INDEX_FIFO_DEPTH-1];
    reg       last_fifo[0:INDEX_FIFO_DEPTH-1];
    reg       diag_fifo[0:INDEX_FIFO_DEPTH-1];
    reg [7:0] bnd_fifo [0:INDEX_FIFO_DEPTH-1];
    reg [$clog2(INDEX_FIFO_DEPTH)-1:0] wr_ptr;
    reg [$clog2(INDEX_FIFO_DEPTH)-1:0] rd_ptr;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
            for (k=0; k<INDEX_FIFO_DEPTH; k=k+1) begin
                idx_fifo[k]  <= 8'd0;
                last_fifo[k] <= 1'b0;
                diag_fifo[k] <= 1'b0;
                bnd_fifo[k]  <= 8'd0;
            end
        end else if (isa_valid) begin
            wr_ptr <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
            for (k=0; k<INDEX_FIFO_DEPTH; k=k+1) begin
                idx_fifo[k]  <= 8'd0;
                last_fifo[k] <= 1'b0;
                diag_fifo[k] <= 1'b0;
                bnd_fifo[k]  <= 8'd0;
            end
        end else if (row_out_vld_w_r) begin
            idx_fifo[wr_ptr]  <= row_out_idx_r;
            last_fifo[wr_ptr] <= prefill ? (row_out_idx_r == q_row_num - 1) : (row_out_idx_r == q_row_num - 1 && bundle_cnt_r == BUNDLE_PAIR_NUM - 1);
            diag_fifo[wr_ptr] <= diag_done_r;
            bnd_fifo[wr_ptr]  <= bundle_cnt_r;
            wr_ptr <= wr_ptr + {{($clog2(INDEX_FIFO_DEPTH)-1){1'b0}},1'b1};
            if(wr_ptr == (INDEX_FIFO_DEPTH - 1)) begin
                wr_ptr <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
            end
        end
    end

    wire [7:0] current_row_idx = idx_fifo[rd_ptr];
    wire [7:0] current_bundle  = bnd_fifo[rd_ptr];
    wire accum_gate = 1'b1;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr      <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
        end else if (isa_valid) begin
            rd_ptr      <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
        end else begin
            if (row_sum_bf16_vld) begin
                rd_ptr <= rd_ptr + {{($clog2(INDEX_FIFO_DEPTH)-1){1'b0}},1'b1};
                if(rd_ptr == (INDEX_FIFO_DEPTH - 1)) begin
                    rd_ptr <= {($clog2(INDEX_FIFO_DEPTH)){1'b0}};
                end
            end
        end
    end

    reg [IN_WIDTH-1:0] row_accumulator_bf16 [0:BLOCK_ROW-1];

    wire [IN_WIDTH-1:0] acc_sum_bf16;
    wire [7:0]  acc_add_status_unused;
    DW_fp_addsub_inst #(
        .sig_width(15), .exp_width(8), .ieee_compliance(0)
    ) u_bf16_acc_add (
        .inst_a  (row_accumulator_bf16[current_row_idx]),
        .inst_b  (row_sum_fp24),
        .inst_rnd(3'b000),
        .inst_op (1'b0),
        .z_inst  (acc_sum_bf16),
        .status_inst(acc_add_status_unused)
    );

    integer r;
    reg clear_accumulators;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r=0; r<BLOCK_ROW; r=r+1) begin
                row_accumulator_bf16[r] <= {IN_WIDTH{1'b0}};
            end
        end else if (isa_valid) begin
            for (r=0; r<BLOCK_ROW; r=r+1) begin
                row_accumulator_bf16[r] <= {IN_WIDTH{1'b0}};
            end
        end else begin
            if (clear_accumulators) begin
                for (r=0; r<BLOCK_ROW; r=r+1) begin
                    row_accumulator_bf16[r] <= {IN_WIDTH{1'b0}};
                end
            end else begin
                if (row_sum_bf16_vld && accum_gate) begin
                    row_accumulator_bf16[current_row_idx] <= acc_sum_bf16;
                end
            end
        end
    end

    reg        emit_state;

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            emit_state <= 1'b0;
            last_pending <= 1'b0;
            diag_clear <= 1'b0;
            clear_accumulators <= 1'b0;
            row_sum_vld <= 1'b0;
            row_sum_out <= {DATA_WIDTH*BLOCK_ROW{1'b0}};
        end else if (isa_valid) begin
            emit_state <= 1'b0;
            last_pending <= 1'b0;
            diag_clear <= 1'b0;
            clear_accumulators <= 1'b0;
            row_sum_vld <= 1'b0;
            row_sum_out <= {DATA_WIDTH*BLOCK_ROW{1'b0}};
        end else begin
            row_sum_vld <= 1'b0;
            clear_accumulators <= 1'b0;
            diag_clear <= 1'b0;

            if(!emit_state) begin
                if(row_sum_bf16_vld && last_fifo[rd_ptr] && (diag_fifo[rd_ptr] || (!prefill && diag_seen))) begin
                    emit_state <= 1'b1;
                    last_pending <= 1'b0;
                end else if(row_sum_bf16_vld && last_fifo[rd_ptr] && !prefill) begin
                    last_pending <= 1'b1;
                end else if(last_pending && !prefill && diag_seen) begin
                    emit_state <= 1'b1;
                    last_pending <= 1'b0;
                end
            end else begin
                row_sum_vld <= 1'b1;
                clear_accumulators <= 1'b1;
                emit_state <= 1'b0;
                diag_clear <= 1'b1;
                for(j=0; j<BLOCK_ROW; j=j+1) begin
                    row_sum_out[DATA_WIDTH*j +: DATA_WIDTH] <=
                        {row_accumulator_bf16[j][IN_WIDTH-1],
                         row_accumulator_bf16[j][IN_WIDTH-2 -: 8],
                         row_accumulator_bf16[j][IN_WIDTH-10 -: 7]};
                end
            end
        end
    end

`ifdef PSMPROBE
    reg psmprobe_mode;
    initial psmprobe_mode = $test$plusargs("PSMPROBE");
    localparam integer PSM_DBG_MAX = 40;
    integer psm_dbg_in_cnt, psm_dbg_exp_cnt, psm_dbg_z_cnt, psm_dbg_i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psm_dbg_in_cnt <= 0; psm_dbg_exp_cnt <= 0; psm_dbg_z_cnt <= 0;
        end else if (isa_valid) begin
            psm_dbg_in_cnt <= 0; psm_dbg_exp_cnt <= 0; psm_dbg_z_cnt <= 0;
        end else if (psmprobe_mode && ((CORE_ID == 0) || (CORE_ID == 7))) begin
            if (in_vld && reduce_max_vld && psm_dbg_in_cnt < PSM_DBG_MAX) begin
                $write("[PSMSC] core=%0d i=%0d cmax=%h din=", CORE_ID, psm_dbg_in_cnt, constant_max);
                for (psm_dbg_i=0; psm_dbg_i<DATA_NUM; psm_dbg_i=psm_dbg_i+1)
                    $write("%h ", d_in[IN_WIDTH*psm_dbg_i +: IN_WIDTH]);
                $write("\n");
                psm_dbg_in_cnt <= psm_dbg_in_cnt + 1;
            end
            if (exp_out_vld && psm_dbg_exp_cnt < PSM_DBG_MAX) begin
                $write("[PSMW] core=%0d i=%0d ridx=%0d absq=%0d prefill=%0d diag=%0d qkv=%0d expo=",
                       CORE_ID, psm_dbg_exp_cnt, row_out_idx,
                       CORE_ID*SEQ_PER_CORE + (row_out_idx % SEQ_PER_CORE),
                       prefill, diag_done, quant_kv);
                for (psm_dbg_i=0; psm_dbg_i<DATA_NUM; psm_dbg_i=psm_dbg_i+1)
                    $write("%h ", exp_out_bf16[IN_WIDTH*psm_dbg_i +: IN_WIDTH]);
                $write("\n");
                psm_dbg_exp_cnt <= psm_dbg_exp_cnt + 1;
            end
            if (psm_vld_adder_tree_pip && psm_dbg_z_cnt < PSM_DBG_MAX) begin
                $display("[PSMZ] core=%0d i=%0d rowsum_fp24=%h maxexp=%h",
                         CORE_ID, psm_dbg_z_cnt, row_sum_fp24, exp_in_norm);
                psm_dbg_z_cnt <= psm_dbg_z_cnt + 1;
            end
        end
    end
`endif

reg gqawave_mode;
initial gqawave_mode = $test$plusargs("GQAWAVE");
integer gqawave_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)            gqawave_cnt <= 0;
    else if (isa_valid)   gqawave_cnt <= 0;
    else if (gqawave_mode && row_out_vld_w && gqawave_cnt < 256) begin
        $display("[GQAWAVE-MASK] core=%0d cnt=%0d prefill=%0d diag=%0d applymask=%0d fce=%0d cmode=%0d fcplus=%0d row_out_idx=%0d absq=%0d bound=%0d qrow=%0d",
                 CORE_ID, gqawave_cnt, prefill, diag_done, apply_tri_mask,
                 fullcausal_eff, causal_mode, fullcausal_mode,
                 row_out_idx,
                 (CORE_ID*SEQ_PER_CORE + (row_out_idx % SEQ_PER_CORE)),
                 mask_bound, q_row_num);
        gqawave_cnt <= gqawave_cnt + 1;
    end
end

// synopsys translate_off
`ifdef GQAPVPROBE
    integer pf_push, pf_last, pf_diag, pf_both, pf_lines;
    initial begin pf_push = 0; pf_last = 0; pf_diag = 0; pf_both = 0; pf_lines = 0; end
    always @(posedge clk) if (rst_n && row_out_vld_w_r) begin
        pf_push = pf_push + 1;
        if (prefill ? (row_out_idx_r == q_row_num - 1) : (row_out_idx_r == q_row_num - 1 && bundle_cnt_r == BUNDLE_PAIR_NUM - 1)) pf_last = pf_last + 1;
        if (diag_done_r) pf_diag = pf_diag + 1;
        if (diag_done_r && (prefill ? (row_out_idx_r == q_row_num - 1) : (row_out_idx_r == q_row_num - 1 && bundle_cnt_r == BUNDLE_PAIR_NUM - 1))) pf_both = pf_both + 1;
        if (pf_lines < 40) begin
            pf_lines = pf_lines + 1;
            $display("[PSMFIFO] t=%0t push=%0d idx=%0d bundle=%0d diag=%b prefill=%b q_row_num=%0d", $time, pf_push, row_out_idx_r, bundle_cnt_r, diag_done_r, prefill, q_row_num);
        end
    end
    integer pf_dd_rises; reg pf_dd_q; initial begin pf_dd_rises = 0; pf_dd_q = 0; end
    always @(posedge clk) if (rst_n) begin
        if (diag_done && !pf_dd_q) begin pf_dd_rises = pf_dd_rises + 1; if (pf_dd_rises <= 8) $display("[PSMDIAG] t=%0t rise=%0d prefill=%b diag_seen=%b last_pending=%b emit_state=%b rd_ptr=%0d wr_ptr=%0d", $time, pf_dd_rises, prefill, diag_seen, last_pending, emit_state, rd_ptr, wr_ptr); end
        pf_dd_q = diag_done;
    end
    final $display("[PSMFIFO-SUM] pushes=%0d last=%0d diag=%0d both=%0d diag_done_rises=%0d", pf_push, pf_last, pf_diag, pf_both, pf_dd_rises);
`endif
// synopsys translate_on

endmodule

`default_nettype wire