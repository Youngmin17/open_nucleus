// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module exp_sub_mant_shift_fmat
#(
    parameter DATA_WIDTH_EXP = 8,
    parameter DATA_WIDTH_MANT = 8,
    parameter DATA_WIDTH_OUT = 16
)
(
    input [DATA_WIDTH_MANT-1:0] mant_in,
    input [DATA_WIDTH_EXP-1:0] max_exp,
    input [DATA_WIDTH_EXP-1:0] exp_op,
    output [DATA_WIDTH_OUT-1:0] shift_mant
    );

    wire [DATA_WIDTH_EXP-1:0] shift_amount;
    wire [DATA_WIDTH_EXP-1:0] exp_diff;

    localparam PAD_WIDTH = DATA_WIDTH_OUT - DATA_WIDTH_MANT;

    assign exp_diff = max_exp - exp_op;
    assign shift_amount = (exp_diff > DATA_WIDTH_OUT[DATA_WIDTH_EXP-1:0]) ?
                          DATA_WIDTH_OUT[DATA_WIDTH_EXP-1:0] : exp_diff;
    assign shift_mant = {mant_in, {PAD_WIDTH{1'b0}}} >> shift_amount;

endmodule
