// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module bf16_fused_adder_tree
#(
    parameter DATA_WIDTH = 16,
    parameter DATA_NUM = 128
)
(
    input clk,
    input rst_n,
    input in_vld,
    input [DATA_NUM*DATA_WIDTH-1:0] d_in,
    output out_vld,
    output [DATA_WIDTH-1:0] d_out
);

    localparam SIGN_WIDTH = 1;
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 7;
    localparam MANT_OUT_WIDTH = 17;
    localparam TREE_OUT_WIDTH = 24;

    wire [DATA_NUM-1:0] vld_pre_process;
    wire [EXP_WIDTH-1:0] exp_out_pre_process;
    wire [DATA_NUM*MANT_OUT_WIDTH-1:0] mant_out_pre_process;

    wire vld_adder_tree = |vld_pre_process;
    wire [TREE_OUT_WIDTH-1:0] dout_adder_tree;

    wire [EXP_WIDTH-1:0] exp_to_norm;
    wire exp_vld_to_norm;

    pre_process #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_NUM(DATA_NUM),
        .SIGN_WIDTH(SIGN_WIDTH),
        .EXP_WIDTH (EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH)
    ) u_pre_process (
        .clk(clk),
        .rst_n(rst_n),
        .d_in(d_in),
        .in_vld({DATA_NUM{in_vld}}),
        .out_vld(vld_pre_process),
        .exp_out(exp_out_pre_process),
        .mant_out(mant_out_pre_process)
    );

    fifo_fma #(
        .DATA_WIDTH(EXP_WIDTH),
        .DEPTH(20)
    ) u_exp_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wen(|vld_pre_process),
        .ren(vld_adder_tree),
        .d_in(exp_out_pre_process),
        .out_vld(exp_vld_to_norm),
        .d_out(exp_to_norm)
    );

    adder_tree #(
        .DATA_WIDTH_IN(MANT_OUT_WIDTH),
        .DATA_WIDTH_OUT(TREE_OUT_WIDTH),
        .DIMENSION(DATA_NUM)
    ) u_adder_tree (
        .d_in(mant_out_pre_process),
        .d_out(dout_adder_tree)
    );

    norm_round #(
        .MANT_WIDTH_IN(TREE_OUT_WIDTH),
        .EXP_WIDTH_IN(EXP_WIDTH),
        .DATA_WIDTH_OUT(DATA_WIDTH)
    ) u_norm_round (
        .clk(clk),
        .rst_n(rst_n),
        .a_vld(exp_vld_to_norm),
        .b_vld(vld_adder_tree),
        .exp_in(exp_to_norm),
        .mant_in(dout_adder_tree),
        .out_vld(out_vld),
        .d_out(d_out)
    );

endmodule
