// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
(* use_dsp = "yes" *)
`ifndef __SIGNED_ADDER_PSM_V__
`define __SIGNED_ADDER_PSM_V__
module signed_adder_psm
#(
    parameter BIT_WIDTH = 17
)
(
    input clk,
    input rst_n,
    input a_vld,
    input b_vld,
    input signed [BIT_WIDTH-1:0] a,
    input signed [BIT_WIDTH-1:0] b,
    output reg out_vld,
    output reg signed [BIT_WIDTH:0] d_out
    );

    wire enable;
    assign enable = a_vld & b_vld;

    wire signed [BIT_WIDTH:0] a_sext = {a[BIT_WIDTH-1], a};
    wire signed [BIT_WIDTH:0] b_sext = {b[BIT_WIDTH-1], b};

    wire signed [BIT_WIDTH:0] sum_w;
`ifdef SYNOPSYS_DW
    wire co_unused;
    DW01_add #(
        .width(BIT_WIDTH+1)
    ) u_dw01_add (
        .A  (a_sext),
        .B  (b_sext),
        .CI (1'b0),
        .SUM(sum_w),
        .CO (co_unused)
    );
`else
    assign sum_w = a_sext + b_sext;
`endif

    always @(posedge clk) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            d_out <= 0;
        end
        else if (enable) begin
            out_vld <= 1'b1;
            d_out <= sum_w;
        end
        else begin
            out_vld <= 1'b0;
            d_out <= 0;
        end
    end
endmodule

`endif
