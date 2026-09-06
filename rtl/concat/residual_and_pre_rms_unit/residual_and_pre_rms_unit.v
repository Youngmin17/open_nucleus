// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps
`default_nettype none
module residual_and_pre_rms_unit #(
    parameter integer DATA_WIDTH = 16,
    parameter integer DATA_NUM   = 128,
    parameter integer BLOCK_ROW  = 128,
    parameter integer VRF_DEPTH_ROWS = 64,
    parameter integer LOOP_NUM = 4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [15:0]                  output_dim,
    input  wire [7:0]                   batch_num,
    input  wire [7:0]                   batch_space,
    input  wire [1:0]                   core_group,
    input  wire                         is_gemm_mode,

    input  wire                             in_vld,
    input  wire                             in_last,
    input  wire [DATA_WIDTH*DATA_NUM-1:0]   in_data,

    output reg                              rms_start_write,
    output reg                              rms_out_vld,
    output reg  [DATA_WIDTH*BLOCK_ROW-1:0]  rms_out_data
);

    localparam integer SIGN_WIDTH = 1;
    localparam integer EXP_WIDTH  = 8;
    localparam integer MANT_WIDTH = 7;
    localparam integer MANT_OUT_WIDTH = 17;
    localparam integer DIM = DATA_NUM / LOOP_NUM;
    localparam integer DIV_DIM = 16;
    localparam integer DIV_LOOP_NUM = 4*DATA_NUM / DIV_DIM;

    integer idx;

    reg [1:0] group_reg1, group_reg2, group_reg3, group_reg4, group_reg5;
    reg       last_reg1, last_reg2, last_reg3, last_reg4, last_reg5;
    reg       last_indicator;

    reg       row_sumsq_out_done;
    reg       row_sumsq_out_done_latch;
    reg       row_sumsq_out_done_phase;
    reg [7:0] row_sumsq_out_done_latch_cnt;
    reg [7:0] row_sumsq_out_vld_cnt;

    reg [DATA_WIDTH*DIV_DIM*DIV_LOOP_NUM-1:0] row_sumsq_out_buffer;

    reg  [DATA_WIDTH*DATA_NUM-1:0] in_data_reg;
    reg                            square_out_vld;
    reg  [DATA_WIDTH*DATA_NUM-1:0] square_out_bf16;
    reg [2:0] mul_cnt;
    reg mul_vld;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mul_cnt <= 3'd0;
            square_out_vld <= 1'b0;
            mul_vld <= 1'b0;
            in_data_reg <= {DATA_WIDTH*DATA_NUM{1'b0}};
            group_reg1 <= 2'd0;
            group_reg2 <= 2'd0;
            last_reg1 <= 1'b0;
            last_reg2 <= 1'b0;
        end else begin
            square_out_vld <= 1'b0;
            if(mul_cnt == 3'd1) begin
                mul_cnt <= 3'd0;
                mul_vld <= 1'b0;
                square_out_vld <= 1'b1;
                group_reg2 <= group_reg1;
                last_reg2 <= last_reg1;
                if(in_vld) begin
                    in_data_reg <= in_data;
                    group_reg1 <= core_group;
                    last_reg1 <= in_last;
                    mul_cnt <= LOOP_NUM[2:0];
                    mul_vld <= 1'b1;
                end
            end else if(mul_cnt != 0) begin
                mul_cnt <= mul_cnt - 3'd1;
            end else if(in_vld) begin
                in_data_reg <= in_data;
                group_reg1 <= core_group;
                last_reg1 <= in_last;
                mul_cnt <= LOOP_NUM[2:0];
                mul_vld <= 1'b1;
            end
        end
    end

    genvar i;

    generate
    for (i = 0; i < DIM; i = i + 1) begin : GEN_SQUARE
        wire [DATA_WIDTH-1:0] a_bf16 = in_data_reg[DATA_WIDTH*(i + DIM*(mul_cnt-1)) +: DATA_WIDTH];
        wire [DATA_WIDTH-1:0] z_bf16;
        DW_fp_mult_inst #(
            .sig_width(7), .exp_width(8), .ieee_compliance(0), .en_ubr_flag(0)
        ) u_dw_mul (
            .inst_a(a_bf16), .inst_b(a_bf16), .inst_rnd(3'b000), .z_inst(z_bf16), .status_inst()
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (idx = 0; idx < LOOP_NUM; idx = idx + 1) begin
                    square_out_bf16[DATA_WIDTH*(i + DIM*idx) +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                end
            end else if (mul_vld) begin
                square_out_bf16[DATA_WIDTH*(i + DIM*(mul_cnt-1)) +: DATA_WIDTH] <= z_bf16;
            end
        end
    end
    endgenerate

    wire [EXP_WIDTH-1:0]                 exp_out;
    wire [DATA_NUM*MANT_OUT_WIDTH-1:0]   mant_out;

    pre_process #(
        .DATA_WIDTH (DATA_WIDTH),
        .DATA_NUM   (DATA_NUM),
        .SIGN_WIDTH (SIGN_WIDTH),
        .EXP_WIDTH  (EXP_WIDTH),
        .MANT_WIDTH (MANT_WIDTH)
    ) u_pre_sqsum (
        .d_in    (square_out_bf16),
        .exp_out (exp_out),
        .mant_out(mant_out)
    );

    reg clear_global_accum;

    reg                                 pre_vld_r;
    reg [EXP_WIDTH-1:0]                 exp_out_r, exp_out_r_pip;
    reg [DATA_NUM*MANT_OUT_WIDTH-1:0]   mant_out_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_vld_r  <= 1'b0;
            exp_out_r  <= {EXP_WIDTH{1'b0}};
            exp_out_r_pip <= {EXP_WIDTH{1'b0}};
            mant_out_r <= {DATA_NUM*MANT_OUT_WIDTH{1'b0}};
            group_reg3 <= 2'd0;
            last_reg3 <= 1'b0;
        end else begin
            pre_vld_r  <= square_out_vld;
            exp_out_r  <= exp_out;
            exp_out_r_pip <= exp_out_r;
            mant_out_r <= mant_out;
            group_reg3 <= group_reg2;
            last_reg3 <= last_reg2;
        end
    end

    wire [23:0]                        tree_mant_sum;
    adder_tree #(
        .DATA_WIDTH_IN (MANT_OUT_WIDTH),
        .DATA_WIDTH_OUT(24),
        .DIMENSION     (DATA_NUM)
    ) u_tree_sqsum (
        .d_in   (mant_out_r),
        .d_out  (tree_mant_sum)
    );

    reg        tree_out_vld_d1;
    reg [23:0] tree_mant_sum_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tree_out_vld_d1 <= 1'b0;
            tree_mant_sum_d1 <= 24'd0;
            group_reg4 <= 2'd0;
            last_reg4 <= 1'b0;
        end else begin
            tree_out_vld_d1 <= pre_vld_r;
            tree_mant_sum_d1 <= tree_mant_sum;
            group_reg4 <= group_reg3;
            last_reg4 <= last_reg3;
        end
    end

    reg [EXP_WIDTH-1:0]  pair_exp;
    reg [23:0]           pair_mant;
    reg                  pair_fire;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_exp     <= {EXP_WIDTH{1'b0}};
            pair_mant    <= 24'd0;
            pair_fire    <= 1'b0;
            group_reg5   <= 2'd0;
            last_reg5    <= 1'b0;
        end else begin
            pair_fire <= 1'b0;
            if (tree_out_vld_d1) begin
                pair_exp  <= exp_out_r_pip;
                pair_mant <= tree_mant_sum_d1;
                pair_fire <= 1'b1;
                group_reg5 <= group_reg4;
                last_reg5 <= last_reg4;
            end
        end
    end

    wire                   row_sumsq_vld = pair_fire;
    wire [DATA_WIDTH-1:0]  row_sumsq_bf16;
    norm_round #(
        .MANT_WIDTH_IN(24),
        .EXP_WIDTH_IN (EXP_WIDTH),
        .DATA_WIDTH_OUT(DATA_WIDTH)
    ) u_norm_sqsum (
        .exp_in (pair_exp),
        .mant_in(pair_mant),
        .d_out  (row_sumsq_bf16)
    );

    reg [15:0] row_sumsq_bf16_reg;
    reg        row_sumsq_vld_reg;
    reg [11:0] row_idx_reg, rd_ptr;
    reg [11:0] batch_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_sumsq_bf16_reg <= 16'h0000;
            row_sumsq_vld_reg  <= 1'b0;
            row_idx_reg <= 12'd0;
            rd_ptr <= 12'd0;
            batch_cnt <= 12'd0;
            last_indicator <= 1'b0;
        end else begin
            last_indicator <= 1'b0;
            if (row_sumsq_vld) begin
                row_sumsq_bf16_reg <= row_sumsq_bf16;
                row_sumsq_vld_reg  <= row_sumsq_vld;
                row_idx_reg <= is_gemm_mode ? rd_ptr+(group_reg5<<$clog2(BLOCK_ROW)) : batch_cnt;
                last_indicator <= last_reg5;
                if(is_gemm_mode) begin
                    rd_ptr <= rd_ptr + 12'd1;
                    if(rd_ptr == BLOCK_ROW-1) begin
                        rd_ptr <= 12'd0;
                    end
                end else begin
                    rd_ptr <= rd_ptr + 12'd1;
                    if(rd_ptr == batch_space-1) begin
                        rd_ptr <= 12'd0;
                        batch_cnt <= batch_cnt + 12'd1;
                        if(batch_cnt == batch_num-1) begin
                            batch_cnt <= 12'd0;
                        end
                    end
                end
            end else begin
                row_sumsq_bf16_reg <= 16'h0000;
                row_sumsq_vld_reg  <= 1'b0;
            end

            if(clear_global_accum) begin
                rd_ptr     <= 12'd0;
                batch_cnt  <= 12'd0;
            end
        end
    end

    reg  [31:0] global_accum_fp32 [BLOCK_ROW*4-1:0];
    wire [31:0] global_accum_next_fp32;
    reg  [7:0] global_accum_idx;
    reg  global_accum_done;
    reg [15:0] output_dim_latch;
    reg [15:0] output_dim_bf16_latch;

    wire [15:0] output_dim_bf16_w;
    DW_fp_i2flt #(
        .sig_width(7),
        .exp_width(8),
        .isize(16),
        .isign(0)
    ) u_output_dim_i2flt (
        .a(output_dim),
        .rnd(3'b000),
        .z(output_dim_bf16_w),
        .status()
    );

    wire [31:0] accum_cur_fp32 = global_accum_fp32[row_idx_reg];
    wire [31:0] row_sumsq_fp32 = {row_sumsq_bf16_reg, 16'b0};

    DW_fp_add #(.sig_width(23), .exp_width(8), .ieee_compliance(0))
    u_acc_add_fp32 (
        .a(accum_cur_fp32), .b(row_sumsq_fp32), .rnd(3'b000),
        .z(global_accum_next_fp32), .status()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < BLOCK_ROW*4; idx = idx + 1) begin
                global_accum_fp32[idx] <= 32'h0000_0000;
            end
            global_accum_idx <= 8'd0;
            global_accum_done <= 1'b0;
            output_dim_latch <= 16'd0;
            output_dim_bf16_latch <= 16'h0000;

        end else begin
            global_accum_done <= 1'b0;

            if(row_sumsq_vld_reg) begin
                global_accum_fp32[row_idx_reg] <= global_accum_next_fp32;
                if(last_indicator) begin
                    global_accum_done <= 1'b1;
                    output_dim_latch <= output_dim;
                    output_dim_bf16_latch <= output_dim_bf16_w;
                end
            end

            if(clear_global_accum) begin
                for (idx = 0; idx < BLOCK_ROW*4; idx = idx + 1) begin
                    global_accum_fp32[idx] <= 32'h0000_0000;
                end
            end
        end
    end

    reg [7:0] div_cnt;
    reg       div_vld;
    reg       div_out_vld;
    reg [DATA_WIDTH*DATA_NUM-1:0] div_out_bf16;

    reg [7:0] sqrt_cnt;
    reg       sqrt_vld;
    reg [DATA_WIDTH*DATA_NUM-1:0] sqrt_in_bf16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 8'd0;
            div_vld <= 1'b0;
            div_out_vld <= 1'b0;
            sqrt_vld <= 1'b0;
            sqrt_cnt <= 8'd0;
            sqrt_in_bf16 <= {DATA_WIDTH*DATA_NUM{1'b0}};
            rms_start_write <= 1'b0;
            rms_out_vld <= 1'b0;
            rms_out_data <= {DATA_WIDTH*BLOCK_ROW{1'b0}};
            row_sumsq_out_done <= 1'b0;
            row_sumsq_out_done_latch <= 1'b0;
            row_sumsq_out_done_phase <= 1'b0;
            row_sumsq_out_done_latch_cnt <= 8'd0;
            row_sumsq_out_vld_cnt <= 8'd0;
            clear_global_accum <= 1'b0;
        end else begin
            div_out_vld <= 1'b0;
            if(div_cnt == 8'd1) begin
                div_cnt <= 8'd0;
                div_vld <= 1'b0;
                div_out_vld <= 1'b1;
                if(global_accum_done) begin
                    div_vld <= 1'b1;
                    div_cnt <= DIV_LOOP_NUM;
                end
            end else if(div_cnt > 1) begin
                div_cnt <= div_cnt - 8'd1;
            end else if(div_cnt == 0) begin
                if(global_accum_done) begin
                    div_vld <= 1'b1;
                    div_cnt <= DIV_LOOP_NUM;
                end
            end

            row_sumsq_out_done <= 1'b0;
            if(sqrt_cnt == 8'd1) begin
                sqrt_cnt <= 8'd0;
                sqrt_vld <= 1'b0;
                row_sumsq_out_done <= 1'b1;
                if(div_out_vld) begin
                    sqrt_in_bf16 <= div_out_bf16;
                    sqrt_vld <= 1'b1;
                    sqrt_cnt <= DIV_LOOP_NUM;
                end
            end else if(sqrt_cnt > 1) begin
                sqrt_cnt <= sqrt_cnt - 8'd1;
            end else if(sqrt_cnt == 0) begin
                if(div_out_vld) begin
                    sqrt_in_bf16 <= div_out_bf16;
                    sqrt_vld <= 1'b1;
                    sqrt_cnt <= DIV_LOOP_NUM;
                end
            end

            rms_start_write <= 1'b0;
            rms_out_vld <= 1'b0;
            clear_global_accum <= 1'b0;
            if(row_sumsq_out_done_phase) begin
                rms_out_vld <= 1'b1;
                rms_out_data <= row_sumsq_out_buffer[DATA_WIDTH*BLOCK_ROW*row_sumsq_out_vld_cnt +: DATA_WIDTH*BLOCK_ROW];
                row_sumsq_out_vld_cnt <= row_sumsq_out_vld_cnt + 8'd1;
                if(row_sumsq_out_vld_cnt == 8'd3) begin
                    row_sumsq_out_vld_cnt <= 8'd0;
                    row_sumsq_out_done_phase <= 1'b0;
                    clear_global_accum <= 1'b1;
                end
            end else if(row_sumsq_out_done_latch) begin
                row_sumsq_out_done_latch_cnt <= row_sumsq_out_done_latch_cnt + 8'd1;
                if(row_sumsq_out_done_latch_cnt == 8'd7) begin
                    row_sumsq_out_done_latch_cnt <= 8'd0;
                    row_sumsq_out_done_latch <= 1'b0;
                    row_sumsq_out_done_phase <= 1'b1;
                end
            end else if(row_sumsq_out_done) begin
                rms_start_write <= 1'b1;
                row_sumsq_out_done_latch <= 1'b1;
            end
        end
    end

    // synopsys translate_off
    `ifdef PRERMSPROBE
    always @(posedge clk) begin
        if (rst_n && in_vld)
            $display("[RPUIN] %m t=%0t in0=%h in1=%h in_last=%b sumsq_vld=%b sumsq=%h ridx=%0d grp=%0d",
                $time, in_data[15:0], in_data[31:16], in_last,
                row_sumsq_vld, row_sumsq_bf16, row_idx_reg, core_group);
        if (rst_n && rms_out_vld)
            $display("[RPUOUT] %m t=%0t rms0=%h rms1=%h rms2=%h rms3=%h vldcnt=%0d gacc0=%h gacc128=%h",
                $time, rms_out_data[15:0], rms_out_data[31:16], rms_out_data[47:32],
                rms_out_data[63:48], row_sumsq_out_vld_cnt,
                global_accum_fp32[0], global_accum_fp32[128]);
    end
    `endif
    // synopsys translate_on

    generate
    for(i=0; i<DIV_DIM; i=i+1) begin: RMS_GEN
        wire [DATA_WIDTH-1:0] div_result, sqrt_result;

        wire [15:0] accum_bf16_trunc = global_accum_fp32[i + DIV_DIM*(div_cnt-1)][31:16];

        DW_fp_div_inst u_DW_fp_div_inst (
            .inst_a(accum_bf16_trunc),
            .inst_b(output_dim_bf16_latch),
            .inst_rnd(3'd0),
            .z_inst(div_result),
            .status_inst()
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (idx = 0; idx < DIV_LOOP_NUM; idx = idx + 1) begin
                    div_out_bf16[DATA_WIDTH*(i + DIV_DIM*idx) +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                end
            end else if (div_vld) begin
                div_out_bf16[DATA_WIDTH*(i + DIV_DIM*(div_cnt-1)) +: DATA_WIDTH] <= div_result;
            end
        end

        DW_fp_sqrt_inst #(
            .inst_sig_width(7),
            .inst_exp_width(8),
            .inst_ieee_compliance(1)
        ) u_DW_fp_sqrt_inst (
            .inst_a(sqrt_in_bf16[DATA_WIDTH*(i + DIV_DIM*(sqrt_cnt-1)) +: DATA_WIDTH]),
            .inst_rnd(3'b000),
            .z_inst(sqrt_result),
            .status_inst()
        );

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (idx = 0; idx < DIV_LOOP_NUM; idx = idx + 1) begin
                    row_sumsq_out_buffer[DATA_WIDTH*(i + DIV_DIM*idx) +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                end
            end else if (sqrt_vld) begin
                row_sumsq_out_buffer[DATA_WIDTH*(i + DIV_DIM*(sqrt_cnt-1)) +: DATA_WIDTH] <= sqrt_result;
            end
        end
    end
    endgenerate

endmodule

`default_nettype wire
