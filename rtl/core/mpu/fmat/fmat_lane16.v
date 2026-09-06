// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module fmat_lane16 #(
    parameter DATA_WIDTH     = 16,
    parameter DIMENSION      = 128,
    parameter SCALE_WIDTH    = 8,
    parameter MULT_DIMENSION = 32,
    parameter LANE           = 16
) (
    input wire clk,
    input wire rst_n,
    input wire [LANE-1:0] a_vld,
    input wire [LANE-1:0] b_vld,
    input wire [LANE-1:0] scale_vld,
    input wire [LANE*12*MULT_DIMENSION-1:0] mode,
    input wire [LANE*4*DATA_WIDTH*MULT_DIMENSION-1:0] a_in,
    input wire [LANE*DATA_WIDTH*MULT_DIMENSION-1:0] b_in,
    input wire [4*SCALE_WIDTH*MULT_DIMENSION-1:0] scale_in,
    output wire [LANE-1:0] out_vld,
    output wire [LANE*DATA_WIDTH-1:0] d_out
);

    genvar i;
    generate
        for (i=0; i<LANE; i=i+1)
        begin: FMAT_LANE_DUPLICATION
            fmat_top #(
                .DATA_WIDTH(DATA_WIDTH),
                .DATA_NUM (DIMENSION),
                .MULT_DIMENSION(MULT_DIMENSION),
                .SCALE_FACTOR(SCALE_WIDTH)
            ) u_fmat_top (
                .clk(clk),
                .rst_n(rst_n),
                .a_vld(a_vld[i]),
                .b_vld(b_vld[i]),
                .scale_vld(scale_vld[i]),
                .mode(mode[12*MULT_DIMENSION*i+:12*MULT_DIMENSION]),
                .a_in(a_in[4*DATA_WIDTH*MULT_DIMENSION*i+:4*DATA_WIDTH*MULT_DIMENSION]),
                .b_in(b_in[DATA_WIDTH*MULT_DIMENSION*i+:DATA_WIDTH*MULT_DIMENSION]),
                .scale_in(scale_in),
                .out_vld(out_vld[i]),
                .d_out(d_out[DATA_WIDTH*i+:DATA_WIDTH])
            );
        end
    endgenerate

endmodule