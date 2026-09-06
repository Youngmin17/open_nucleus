// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire
module pre_softmax_online #(
    parameter DATA_WIDTH = 16,
    parameter DIN_WIDTH  = 24,
    parameter DATA_NUM   = 128,
    parameter BLOCK_ROW  = 128,
    parameter IDX_W      = 7
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire in_vld,
    input  wire diag_done,
    input  wire prefill_decode,
    input  wire [2*DIN_WIDTH*DATA_NUM-1:0] d_in,
    input  wire [6:0] s_row_num,
    input  wire block_start,

    output wire [DATA_WIDTH-1:0]          rsum_out,
    output wire                           rsum_out_vld,
    output wire [IDX_W-1:0]               rsum_row_out,
    output wire [DATA_WIDTH-1:0]          alpha_out,
    output wire                           alpha_out_vld,
    output wire [IDX_W-1:0]               alpha_row_out,
    output wire [DATA_WIDTH*DATA_NUM-1:0] p_out,
    output wire                           p_out_vld,
    output wire                           ps_done
);
    localparam [DIN_WIDTH-1:0] SCALE = 24'b001111011011010100000000;
    localparam [DIN_WIDTH-1:0] INF_VALUE = 24'b111111111000000000000000;

    localparam FP24_S_WIDTH = 1;
    localparam FP24_E_WIDTH = 8;
    localparam FP24_M_WIDTH = 15;
    localparam FP24_MOUT_WIDTH = (1+FP24_M_WIDTH)*2 + FP24_S_WIDTH;
    localparam FP24_TREE_OUT   = FP24_MOUT_WIDTH + 7;

    localparam MULT_DELAY = 9;
    localparam SCALED_DELAY  = 2;
    localparam NEW_MAX_DELAY = 6;
    localparam OLD_IDX_DELAY = 3;
    localparam NEW_IDX_DELAY = 7;
    localparam ALPHA_IDX_DELAY = OLD_IDX_DELAY + 1;

    genvar i;
    genvar j;
    integer k;

    wire [DIN_WIDTH*DATA_NUM-1:0] mult_out;
    wire                          mult_out_vld;

    wire [DIN_WIDTH-1:0]          max_out;
    wire                          max_out_vld;

    wire [DIN_WIDTH-1:0]          old_max;
    wire                          old_max_vld;

    wire [DIN_WIDTH-1:0]          new_max;
    wire                          new_max_vld;

    wire [DIN_WIDTH-1:0]          sub_out;
    wire                          sub_out_vld;

    wire [DIN_WIDTH-1:0]          exp_out;

    wire [DIN_WIDTH-1:0]          alpha;
    wire                          alpha_vld;

    wire [DIN_WIDTH-1:0]          old_row_sum;
    wire                          old_row_sum_vld;

    wire [DIN_WIDTH*DATA_NUM-1:0] score_sub;
    wire                          score_sub_vld;

    wire [DIN_WIDTH*DATA_NUM-1:0] score_exp;
    wire                          score_exp_vld;

    wire [DIN_WIDTH-1:0]          row_sum;
    wire                          row_sum_vld;

    wire [DIN_WIDTH-1:0]          scaled_row;
    wire                          scaled_row_vld;

    wire [DIN_WIDTH-1:0]          new_row_sum;
    wire                          new_row_sum_vld;

    wire wen;

    reg [IDX_W-1:0] s_row_num_r;

    reg [DIN_WIDTH*DATA_NUM-1:0] mult_out_r;
    reg                          mult_out_vld_r;

    reg [DIN_WIDTH-1:0]          max_out_r;
    reg                          max_out_vld_r;

    reg [DIN_WIDTH-1:0]          new_max_r;
    reg                          new_max_vld_r;

    reg [DIN_WIDTH-1:0]          old_max_r;

    reg [DIN_WIDTH-1:0]          sub_out_r;
    reg                          sub_out_vld_r;

    reg [DIN_WIDTH*DATA_NUM-1:0] score_sub_r;
    reg                          score_sub_vld_r;

    reg [DIN_WIDTH*DATA_NUM-1:0] score_exp_r;
    reg                          score_exp_vld_r;

    reg [DIN_WIDTH-1:0]          row_sum_r;
    reg                          row_sum_vld_r;

    reg [DIN_WIDTH-1:0]          scaled_row_r;
    reg                          scaled_row_vld_r;

    reg [DIN_WIDTH-1:0]          new_row_sum_r;
    reg                          new_row_sum_vld_r;

    reg [DIN_WIDTH * DATA_NUM-1:0] mult_out_d     [0:MULT_DELAY-1];
    reg                            mult_out_vld_d [0:MULT_DELAY-1];

    reg [DIN_WIDTH-1:0] scaled_row_d     [0:SCALED_DELAY-1];
    reg                 scaled_row_vld_d [0:SCALED_DELAY-1];

    reg [DIN_WIDTH-1:0] new_max_d     [0:NEW_MAX_DELAY-1];
    reg                 new_max_vld_d [0:NEW_MAX_DELAY-1];

    reg [IDX_W-1:0] old_idx;
    reg [IDX_W-1:0] new_idx;

    reg [IDX_W-1:0] old_idx_d [0:ALPHA_IDX_DELAY-1];
    reg [IDX_W-1:0] new_idx_d [0:NEW_IDX_DELAY-1];

    always @(posedge clk) begin
        if (!rst_n)           s_row_num_r <= BLOCK_ROW-1;
        else if (block_start) s_row_num_r <= s_row_num;
    end

    reg [DIN_WIDTH*DATA_NUM-1:0] din_latch;
    reg                          pending;
    reg [IDX_W-1:0]              serial_idx;
    reg                          serial_vld;
    reg [DIN_WIDTH*DATA_NUM-1:0] serial_din;

    always @(posedge clk) begin
        if (!rst_n || block_start) begin
            din_latch  <= {DIN_WIDTH*DATA_NUM{1'b0}};
            pending    <= 1'b0;
            serial_idx <= {IDX_W{1'b0}};
            serial_vld <= 1'b0;
            serial_din <= {DIN_WIDTH*DATA_NUM{1'b0}};
        end
        else begin
            serial_vld <= 1'b0;
            if (in_vld) begin
                serial_vld <= 1'b1;
                serial_din <= d_in[DIN_WIDTH*DATA_NUM-1:0];
                din_latch  <= d_in[2*DIN_WIDTH*DATA_NUM-1:DIN_WIDTH*DATA_NUM];
                if (serial_idx == s_row_num_r) begin
                    serial_idx <= {IDX_W{1'b0}};
                    pending    <= 1'b0;
                end
                else begin
                    serial_idx <= serial_idx + 1'b1;
                    pending    <= 1'b1;
                end
            end
            else if (pending) begin
                serial_vld <= 1'b1;
                serial_din <= din_latch;
                pending    <= 1'b0;
                if (serial_idx == s_row_num_r)
                    serial_idx <= {IDX_W{1'b0}};
                else
                    serial_idx <= serial_idx + 1'b1;
            end
        end
    end

    assign mult_out_vld = serial_vld;

    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GENERATE_MULT
        DW_fp_mult_inst #(
            .sig_width(FP24_M_WIDTH),
            .exp_width(FP24_E_WIDTH),
            .ieee_compliance(0)
        ) u0_dw_fp24_mult (
            .inst_a  (serial_din[DIN_WIDTH*i+:DIN_WIDTH]),
            .inst_b  (SCALE),
            .inst_rnd(3'b000),
            .z_inst  (mult_out[DIN_WIDTH*i+:DIN_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            mult_out_vld_r <= 1'b0;
            mult_out_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
        end
        else if (mult_out_vld) begin
            mult_out_vld_r <= mult_out_vld;
            mult_out_r <= mult_out;
        end
        else begin
            mult_out_vld_r <= 1'b0;
            mult_out_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
        end
    end

    wire [$clog2(DATA_NUM)-1:0] mask_row_nxt;
    wire mask_en;
    wire [DIN_WIDTH*DATA_NUM-1:0] d_mask;

    reg [$clog2(DATA_NUM)-1:0] mask_row_cnt;
    reg [$clog2(DATA_NUM)-1:0] mask_row_idx;
    reg mask_en_r;

    assign mask_row_nxt = (mask_row_cnt == s_row_num_r) ? 0 : mask_row_cnt + 1'b1;
    assign mask_en = diag_done && !prefill_decode;

    always @ (posedge clk) begin
        if (!rst_n || block_start) begin
            mask_row_cnt <= 0;
            mask_row_idx <= 0;
            mask_en_r    <= 1'b0;
        end
        else if (mult_out_vld) begin
            mask_row_idx <= mask_row_cnt;
            mask_row_cnt <= mask_row_nxt;
            mask_en_r    <= mask_en;
        end
    end

    generate
    for (j=0;j<DATA_NUM;j=j+1) begin : GEN_MASK
        assign d_mask[DIN_WIDTH*j+:DIN_WIDTH] = (mask_en_r && (j>mask_row_idx)) ? INF_VALUE : mult_out_r[DIN_WIDTH*j+:DIN_WIDTH];
    end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k=0; k<MULT_DELAY; k=k+1) begin
                mult_out_d[k]     <= {DIN_WIDTH*DATA_NUM{1'b0}};
                mult_out_vld_d[k] <= 1'b0;
            end
        end
        else begin
            mult_out_d[0]     <= d_mask;
            mult_out_vld_d[0] <= mult_out_vld_r;
            for (k=1; k<MULT_DELAY; k=k+1) begin
                mult_out_d[k]     <= mult_out_d[k-1];
                mult_out_vld_d[k] <= mult_out_vld_d[k-1];
            end
        end
    end

    comparator_tree_bf16 #(
        .EXP_WIDTH(FP24_E_WIDTH),
        .SIG_WIDTH(FP24_M_WIDTH),
        .DATA_NUM (DATA_NUM)
    ) u_comparator_tree_fp24 (
        .clk    (clk),
        .rst_n  (rst_n),
        .d_in   (d_mask),
        .in_vld (mult_out_vld_r),
        .out_vld(max_out_vld),
        .d_out  (max_out)
    );

    always @ (posedge clk) begin
        if (!rst_n) begin
            max_out_r     <= {DIN_WIDTH{1'b0}};
            max_out_vld_r <= 1'b0;
        end
        else if (max_out_vld) begin
            max_out_r     <= max_out;
            max_out_vld_r <= max_out_vld;
        end
        else begin
            max_out_r     <= {DIN_WIDTH{1'b0}};
            max_out_vld_r <= 1'b0;
        end
    end

    always @ (posedge clk) begin
        if (!rst_n || block_start) begin
            old_idx <= 0;
        end
        else if (max_out_vld) begin
            if (old_idx == s_row_num_r)
                old_idx <= 0;
            else
                old_idx <= old_idx + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)           new_idx <= 0;
        else if (max_out_vld) new_idx <= old_idx;
        else                  new_idx <= 0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k=0; k<ALPHA_IDX_DELAY; k=k+1)
                old_idx_d[k] <= 0;
        end
        else begin
            old_idx_d[0] <= old_idx;
            for (k=1; k<ALPHA_IDX_DELAY; k=k+1)
                old_idx_d[k] <= old_idx_d[k-1];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k=0; k<NEW_IDX_DELAY; k=k+1)
                new_idx_d[k] <= 0;
        end
        else begin
            new_idx_d[0] <= new_idx;
            for (k=1; k<NEW_IDX_DELAY; k=k+1)
                new_idx_d[k] <= new_idx_d[k-1];
        end
    end

    assign wen = !block_start && new_max_vld_d[NEW_MAX_DELAY-1] && new_row_sum_vld_r;

    psm_register #(
        .DATA_WIDTH (DIN_WIDTH),
        .DEPTH      (BLOCK_ROW),
        .INIT_VALUE (INF_VALUE)
    ) u_row_m_register (
        .clk    (clk),
        .rst_n  (rst_n),
        .clear  (block_start),
        .wr_en  (wen),
        .wr_idx (new_idx_d[NEW_IDX_DELAY-1]),
        .wr_data(new_max_d[NEW_MAX_DELAY-1]),
        .rd_en  (max_out_vld),
        .rd_idx (old_idx),
        .rd_data(old_max),
        .rd_vld (old_max_vld)
    );

    wire [DIN_WIDTH-1:0] gt_val;
    wire [DIN_WIDTH-1:0] lt_val;

    DW_fp_cmp_inst #(
        .sig_width(FP24_M_WIDTH),
        .exp_width(FP24_E_WIDTH),
        .ieee_compliance(0)
    ) u_dw_fp24_cmp (
        .inst_a(max_out_r),
        .inst_b(old_max),
        .inst_zctr(1'b0),
        .aeqb_inst(),
        .altb_inst(),
        .agtb_inst(),
        .unordered_inst(),
        .z0_inst(lt_val),
        .z1_inst(gt_val),
        .status0_inst(),
        .status1_inst()
    );

    assign new_max     = gt_val;
    assign new_max_vld = old_max_vld && max_out_vld_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k=0; k<NEW_MAX_DELAY; k=k+1) begin
                new_max_d[k]     <= {DIN_WIDTH{1'b0}};
                new_max_vld_d[k] <= 1'b0;
            end
        end
        else begin
            new_max_d[0]     <= new_max_r;
            new_max_vld_d[0] <= new_max_vld_r;
            for (k=1; k<NEW_MAX_DELAY; k=k+1) begin
                new_max_d[k]     <= new_max_d[k-1];
                new_max_vld_d[k] <= new_max_vld_d[k-1];
            end
        end
    end

    always @ (posedge clk) begin
        if (!rst_n) begin
            new_max_r <= {DIN_WIDTH{1'b0}};
            old_max_r <= {DIN_WIDTH{1'b0}};
            new_max_vld_r <= 1'b0;
        end
        else if (new_max_vld) begin
            new_max_r <= new_max;
            old_max_r <= old_max;
            new_max_vld_r <= new_max_vld;
        end
        else begin
            new_max_r <= {DIN_WIDTH{1'b0}};
            old_max_r <= {DIN_WIDTH{1'b0}};
            new_max_vld_r <= 1'b0;
        end
    end

    DW_fp_sub_inst #(
        .sig_width(FP24_M_WIDTH),
        .exp_width(FP24_E_WIDTH),
        .ieee_compliance(0)
    ) u0_dw_fp24_sub (
        .inst_a    (old_max_r),
        .inst_b    (new_max_r),
        .inst_rnd  (3'b000),
        .z_inst    (sub_out),
        .status_inst()
    );

    assign sub_out_vld = new_max_vld_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            sub_out_r <= {DIN_WIDTH{1'b0}};
            sub_out_vld_r <= 1'b0;
        end
        else if (sub_out_vld) begin
            sub_out_r <= sub_out;
            sub_out_vld_r <= sub_out_vld;
        end
        else begin
            sub_out_r <= {DIN_WIDTH{1'b0}};
            sub_out_vld_r <= 1'b0;
        end
    end

    DW_fp_exp_inst #(
        .inst_sig_width(FP24_M_WIDTH),
        .inst_exp_width(FP24_E_WIDTH),
        .inst_ieee_compliance(0),
        .inst_arch(0)
    ) u0_dw_fp24_exp (
        .inst_a    (sub_out_r),
        .z_inst    (exp_out),
        .status_inst()
    );

    assign alpha     = exp_out;
    assign alpha_vld = sub_out_vld_r;

    reg [DIN_WIDTH-1:0] alpha_r;
    reg alpha_vld_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            alpha_r <= {DIN_WIDTH{1'b0}};
            alpha_vld_r <= 1'b0;
        end
        else if (alpha_vld) begin
            alpha_r <= alpha;
            alpha_vld_r <= alpha_vld;
        end
        else begin
            alpha_r <= {DIN_WIDTH{1'b0}};
            alpha_vld_r <= 1'b0;
        end
    end

    assign score_sub_vld = new_max_vld_r && mult_out_vld_d[MULT_DELAY-1];

    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GENERATE_SUB_NUMERATOR
        DW_fp_sub_inst #(
            .sig_width(FP24_M_WIDTH),
            .exp_width(FP24_E_WIDTH),
            .ieee_compliance(0)
        ) u1_dw_fp24_sub (
            .inst_a    (mult_out_d[MULT_DELAY-1][DIN_WIDTH*i+:DIN_WIDTH]),
            .inst_b    (new_max_r),
            .inst_rnd  (3'b000),
            .z_inst    (score_sub[DIN_WIDTH*i+:DIN_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            score_sub_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
            score_sub_vld_r <= 1'b0;
        end
        else if (score_sub_vld) begin
            score_sub_r <= score_sub;
            score_sub_vld_r <= score_sub_vld;
        end
        else begin
            score_sub_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
            score_sub_vld_r <= 1'b0;
        end
    end

    assign score_exp_vld = score_sub_vld_r;

    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GENERATE_EXP_NUMERATOR
        DW_fp_exp_inst #(
            .inst_sig_width(FP24_M_WIDTH),
            .inst_exp_width(FP24_E_WIDTH),
            .inst_ieee_compliance(0),
            .inst_arch(0)
        ) u1_dw_fp24_exp (
            .inst_a    (score_sub_r[DIN_WIDTH*i+:DIN_WIDTH]),
            .z_inst    (score_exp[DIN_WIDTH*i+:DIN_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            score_exp_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
            score_exp_vld_r <= 1'b0;
        end
        else if (score_exp_vld) begin
            score_exp_r <= score_exp;
            score_exp_vld_r <= score_exp_vld;
        end
        else begin
            score_exp_r <= {DIN_WIDTH*DATA_NUM{1'b0}};
            score_exp_vld_r <= 1'b0;
        end
    end

    wire [FP24_E_WIDTH-1:0]             accum_exp_out;
    wire [DATA_NUM*FP24_MOUT_WIDTH-1:0] accum_mant_out;
    wire [FP24_TREE_OUT-1:0]            adder_tree_out;

    reg [FP24_E_WIDTH-1:0]             accum_exp_out_r;
    reg [FP24_E_WIDTH-1:0]             accum_exp_out_r0;
    reg [DATA_NUM*FP24_MOUT_WIDTH-1:0] accum_mant_out_r;
    reg [FP24_TREE_OUT-1:0]            adder_tree_out_r;
    reg pre_process_vld;
    reg adder_tree_vld;

    assign row_sum_vld = score_exp_vld_r;

    pre_process_fmat #(
        .DATA_WIDTH (DIN_WIDTH),
        .DATA_NUM   (DATA_NUM),
        .SIGN_WIDTH (FP24_S_WIDTH),
        .EXP_WIDTH  (FP24_E_WIDTH),
        .MANT_WIDTH (FP24_M_WIDTH)
    ) u_pre_process (
        .d_in    (score_exp_r),
        .exp_out (accum_exp_out),
        .mant_out(accum_mant_out)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            accum_exp_out_r  <= 0;
            accum_mant_out_r <= 0;
            pre_process_vld  <= 1'b0;
        end
        else if (row_sum_vld) begin
            accum_exp_out_r  <= accum_exp_out;
            accum_mant_out_r <= accum_mant_out;
            pre_process_vld  <= row_sum_vld;
        end
        else begin
            accum_exp_out_r  <= 0;
            accum_mant_out_r <= 0;
            pre_process_vld  <= 1'b0;
        end
    end

    adder_tree_fmat #(
        .DATA_WIDTH_IN (FP24_MOUT_WIDTH),
        .DATA_WIDTH_OUT(FP24_TREE_OUT),
        .DIMENSION     (DATA_NUM)
    ) u_adder_tree (
        .d_in (accum_mant_out_r),
        .d_out(adder_tree_out)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            accum_exp_out_r0 <= 0;
            adder_tree_out_r <= 0;
            adder_tree_vld   <= 1'b0;
        end
        else if (pre_process_vld) begin
            accum_exp_out_r0 <= accum_exp_out_r;
            adder_tree_out_r <= adder_tree_out;
            adder_tree_vld   <= pre_process_vld;
        end
        else begin
            accum_exp_out_r0 <= 0;
            adder_tree_out_r <= 0;
            adder_tree_vld   <= 1'b0;
        end
    end

    norm_round_fmat #(
        .MANT_WIDTH_IN (FP24_TREE_OUT),
        .EXP_WIDTH_IN  (FP24_E_WIDTH),
        .DATA_WIDTH_OUT(DIN_WIDTH)
    ) u_norm_round (
        .exp_in (accum_exp_out_r0),
        .mant_in(adder_tree_out_r),
        .d_out  (row_sum)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            row_sum_r <= {DIN_WIDTH{1'b0}};
            row_sum_vld_r <= 1'b0;
        end
        else if (adder_tree_vld) begin
            row_sum_r <= row_sum;
            row_sum_vld_r <= adder_tree_vld;
        end
        else begin
            row_sum_r <= {DIN_WIDTH{1'b0}};
            row_sum_vld_r <= 1'b0;
        end
    end

    psm_register #(
        .DATA_WIDTH (DIN_WIDTH),
        .DEPTH      (BLOCK_ROW),
        .INIT_VALUE ({DIN_WIDTH{1'b0}})
    ) u_row_l_register (
        .clk    (clk),
        .rst_n  (rst_n),
        .clear  (block_start),
        .wr_en  (wen),
        .wr_idx (new_idx_d[NEW_IDX_DELAY-1]),
        .wr_data(new_row_sum_r),
        .rd_en  (alpha_vld),
        .rd_idx (old_idx_d[OLD_IDX_DELAY-1]),
        .rd_data(old_row_sum),
        .rd_vld (old_row_sum_vld)
    );

    assign scaled_row_vld = old_row_sum_vld && alpha_vld_r;

    DW_fp_mult_inst #(
        .sig_width(FP24_M_WIDTH),
        .exp_width(FP24_E_WIDTH),
        .ieee_compliance(0)
    ) u1_dw_fp24_mult (
        .inst_a  (alpha_r),
        .inst_b  (old_row_sum),
        .inst_rnd(3'b000),
        .z_inst  (scaled_row),
        .status_inst()
    );

    always @ (posedge clk) begin
        if (!rst_n) begin
            scaled_row_r <= {DIN_WIDTH{1'b0}};
            scaled_row_vld_r <= 1'b0;
        end
        else if (scaled_row_vld) begin
            scaled_row_r <= scaled_row;
            scaled_row_vld_r <= scaled_row_vld;
        end
        else begin
            scaled_row_r <= {DIN_WIDTH{1'b0}};
            scaled_row_vld_r <= 1'b0;
        end
   end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (k=0; k<SCALED_DELAY; k=k+1) begin
                scaled_row_d[k]     <= {DIN_WIDTH{1'b0}};
                scaled_row_vld_d[k] <= 1'b0;
            end
        end
        else begin
            scaled_row_d[0]     <= scaled_row_r;
            scaled_row_vld_d[0] <= scaled_row_vld_r;
            for (k=1; k<SCALED_DELAY; k=k+1) begin
                scaled_row_d[k]     <= scaled_row_d[k-1];
                scaled_row_vld_d[k] <= scaled_row_vld_d[k-1];
            end
        end
    end

    assign new_row_sum_vld = scaled_row_vld_d[SCALED_DELAY-1] && row_sum_vld_r;

    DW_fp_add_inst #(
        .sig_width(FP24_M_WIDTH),
        .exp_width(FP24_E_WIDTH),
        .ieee_compliance(0)
    ) u1_dw_fp24_add (
        .inst_a  (scaled_row_d[SCALED_DELAY-1]),
        .inst_b  (row_sum_r),
        .inst_rnd(3'b000),
        .z_inst  (new_row_sum),
        .status_inst()
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            new_row_sum_r <= {DIN_WIDTH{1'b0}};
            new_row_sum_vld_r <= 1'b0;
        end
        else if (new_row_sum_vld) begin
            new_row_sum_r <= new_row_sum;
            new_row_sum_vld_r <= new_row_sum_vld;
        end
        else begin
            new_row_sum_r <= {DIN_WIDTH{1'b0}};
            new_row_sum_vld_r <= 1'b0;
        end
    end

    assign alpha_out     = alpha_r[DIN_WIDTH-1-:DATA_WIDTH];
    assign alpha_out_vld = alpha_vld_r;

    assign rsum_out     = new_row_sum_r[DIN_WIDTH-1-:DATA_WIDTH];
    assign rsum_out_vld = new_row_sum_vld_r;
    assign rsum_row_out = new_idx_d[NEW_IDX_DELAY-1];
    assign alpha_row_out = old_idx_d[ALPHA_IDX_DELAY-1];

    generate
    for (i=0; i<DATA_NUM; i=i+1) begin : GEN_POUT
        assign p_out[DATA_WIDTH*i +: DATA_WIDTH] = score_exp_r[DIN_WIDTH*i+DIN_WIDTH-1 -:DATA_WIDTH];
    end
    endgenerate

    assign p_out_vld = score_exp_vld_r;

    assign ps_done = wen && (new_idx_d[NEW_IDX_DELAY-1] == s_row_num_r);

endmodule

`default_nettype wire
