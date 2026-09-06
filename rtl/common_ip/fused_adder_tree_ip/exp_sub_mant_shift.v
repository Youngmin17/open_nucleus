// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module exp_sub_mant_shift
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

    assign exp_diff = max_exp - exp_op;
    assign shift_amount = (exp_diff > 8'd16) ? 8'd16 : exp_diff;
    assign shift_mant = {mant_in, 8'b0} >> shift_amount;

endmodule
