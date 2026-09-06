// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module fmat_top
#(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 24,
    parameter DATA_NUM = 128,
    parameter MULT_DIMENSION = 32,
    parameter SCALE_FACTOR = 8
)
(
    input wire clk,
    input wire rst_n,
    input wire a_vld,
    input wire b_vld,
    input wire scale_vld,
    input wire [1:0] mode,
    input wire [4*DATA_WIDTH*MULT_DIMENSION-1:0] a_in,
    input wire [DATA_WIDTH*MULT_DIMENSION-1:0] b_in,
    input wire [4*SCALE_FACTOR*MULT_DIMENSION-1:0] scale_in,
    output reg out_vld,
    output reg [OUT_WIDTH-1:0] d_out
);
    localparam MULT_DATA_NUM = 4;

    localparam SIGN_WIDTH = 1;
    localparam EXP_WIDTH  = 8;
    localparam MANT_WIDTH = OUT_WIDTH - 1 - EXP_WIDTH;

    localparam MANT_OUT_WIDTH = (1+MANT_WIDTH)*2 + SIGN_WIDTH;
    localparam TREE_OUT_WIDTH = MANT_OUT_WIDTH + 7;

    genvar i;

    wire enable = a_vld && b_vld && scale_vld;
    wire [4*OUT_WIDTH*MULT_DIMENSION-1:0] mult_out;

    generate
    for (i=0; i<MULT_DIMENSION; i=i+1)
    begin : MULTIPLICATION
        multiplier_fmat #(
            .DATA_WIDTH(DATA_WIDTH),
            .OUT_WIDTH (OUT_WIDTH),
            .DATA_NUM(MULT_DATA_NUM),
            .SCALE_FACTOR(SCALE_FACTOR)
        )   u_multiplier (
            .mode({4{mode}}),
            .a_in(a_in[4*DATA_WIDTH*i+4*DATA_WIDTH-1:4*DATA_WIDTH*i]),
            .b_in(b_in[DATA_WIDTH*i+DATA_WIDTH-1:DATA_WIDTH*i]),
            .scale_in(scale_in[4*SCALE_FACTOR*i+4*SCALE_FACTOR-1:4*SCALE_FACTOR*i]),
            .d_out(mult_out[4*OUT_WIDTH*i+4*OUT_WIDTH-1:4*OUT_WIDTH*i])
        );
    end
    endgenerate

    reg [4*OUT_WIDTH*MULT_DIMENSION-1:0] mult_out_r;
    reg mult_out_vld_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            mult_out_r <= 0;
            mult_out_vld_r <= 1'b0;
        end
        else begin
            mult_out_vld_r <= enable;
            if (enable)
                mult_out_r <= mult_out;
        end
    end

    wire [DATA_NUM*MANT_OUT_WIDTH-1:0] mant_out;
    wire [EXP_WIDTH-1:0] exp_out;

    pre_process_fmat #(
        .DATA_WIDTH(OUT_WIDTH),
        .DATA_NUM(DATA_NUM),
        .SIGN_WIDTH(SIGN_WIDTH),
        .EXP_WIDTH (EXP_WIDTH),
        .MANT_WIDTH(MANT_WIDTH)
    ) u_pre_process (
        .d_in(mult_out_r),
        .exp_out(exp_out),
        .mant_out(mant_out)
    );

    reg [DATA_NUM*MANT_OUT_WIDTH-1:0] mant_out_r;
    reg [EXP_WIDTH-1:0] exp_out_r;
    reg pre_process_vld_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            mant_out_r <= 0;
            exp_out_r  <= 0;
            pre_process_vld_r  <= 1'b0;
        end
        else begin
            pre_process_vld_r  <= mult_out_vld_r;
            if (mult_out_vld_r) begin
                mant_out_r  <= mant_out;
                exp_out_r <= exp_out;
            end
        end
    end

    wire [TREE_OUT_WIDTH-1:0] adder_tree_out;

    adder_tree_fmat #(
        .DATA_WIDTH_IN(MANT_OUT_WIDTH),
        .DATA_WIDTH_OUT(TREE_OUT_WIDTH),
        .DIMENSION(DATA_NUM)
    ) u_adder_tree (
        .d_in(mant_out_r),
        .d_out(adder_tree_out)
    );

    reg [TREE_OUT_WIDTH-1:0] adder_tree_out_r;
    reg [EXP_WIDTH-1:0] exp_delay_r;
    reg adder_tree_vld_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            adder_tree_out_r <= 0;
            exp_delay_r <= 0;
            adder_tree_vld_r <= 1'b0;
        end
        else begin
            adder_tree_vld_r <= pre_process_vld_r;
            if (pre_process_vld_r) begin
                adder_tree_out_r <= adder_tree_out;
                exp_delay_r <= exp_out_r;
            end
        end
    end

    wire [OUT_WIDTH-1:0] norm_out;

    norm_round_fmat #(
        .MANT_WIDTH_IN(TREE_OUT_WIDTH),
        .EXP_WIDTH_IN(EXP_WIDTH),
        .DATA_WIDTH_OUT(OUT_WIDTH)
    ) u_norm_round (
        .exp_in(exp_delay_r),
        .mant_in(adder_tree_out_r),
        .d_out(norm_out)
    );

    reg [OUT_WIDTH-1:0] norm_out_r;
    reg norm_vld_r;

    always @ (posedge clk) begin
        if (!rst_n) begin
            norm_out_r <= 0;
            norm_vld_r <= 1'b0;
        end
        else begin
            norm_vld_r <= adder_tree_vld_r;
            if (adder_tree_vld_r)
                norm_out_r <= norm_out;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            d_out  <= 0;
            out_vld<= 1'b0;
        end
        else begin
            out_vld <= norm_vld_r;
            if (norm_vld_r)
                d_out <= norm_out_r;
        end
    end

endmodule
