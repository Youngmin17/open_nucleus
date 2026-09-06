// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module norm_round
#(
    parameter MANT_WIDTH_IN = 24,
    parameter EXP_WIDTH_IN = 8,
    parameter DATA_WIDTH_OUT = 16
)
(
    input [EXP_WIDTH_IN-1:0] exp_in,
    input [MANT_WIDTH_IN-1:0] mant_in,
    output [DATA_WIDTH_OUT-1:0] d_out
    );

    wire [MANT_WIDTH_IN-1:0] mant_comp_2s;
    wire [MANT_WIDTH_IN-2:0] without_sign;

    wire sign;
    wire [EXP_WIDTH_IN-1:0] exp;
    wire [6:0] mant;

    wire [7:0] dec_point_left;
    wire [14:0] dec_point_right;

    wire [MANT_WIDTH_IN-2:0] tmp_mant;

    wire shift_left;

    wire [7:0] zero_cnt_left;
    wire [7:0] zero_cnt_right;

    wire [7:0] num_shift;
    wire [MANT_WIDTH_IN-2:0] shift_mant;
    wire [6:0] norm_mant;

    wire signed [9:0] tmp_exp;
    wire [7:0] exp_inc;

    wire guard_bit;
    wire round_bit;
    wire sticky_bit;

    wire mant_overflow;

    wire exp_overflow;
    wire exp_underflow;

    assign sign = mant_in [MANT_WIDTH_IN-1];
    assign mant_comp_2s = sign ? ~mant_in + 1'b1 : mant_in;

    assign without_sign = mant_comp_2s [MANT_WIDTH_IN-2:0];

    wire is_input_zero = ~(|without_sign);

    assign dec_point_left = without_sign [22:15];
    assign dec_point_right = without_sign [14:0];

    assign tmp_mant = (~(|dec_point_left)) ? {dec_point_right, 8'b0} : without_sign;

    assign shift_left = (~(|dec_point_left)) ? 1'b0 : 1'b1;

    lzd_8bit lzd_left(
        .d_in(dec_point_left),
        .d_out(zero_cnt_left)
    );

    lzd_15bit lzd_right(
        .d_in(dec_point_right),
        .d_out(zero_cnt_right)
    );

    assign num_shift = (shift_left) ? zero_cnt_left + 1 : zero_cnt_right + 1;
    assign shift_mant = tmp_mant << num_shift;
    assign norm_mant = shift_mant[22:16];

    assign exp_inc = (shift_left) ? (8'b00001000 - num_shift) : num_shift;
    assign tmp_exp = (shift_left) ? ($signed({2'b0, exp_in}) + $signed({2'b0, exp_inc}))
                                  : ($signed({2'b0, exp_in}) - $signed({2'b0, exp_inc}));

    assign guard_bit = shift_mant[15];
    assign round_bit = shift_mant[14];
    assign sticky_bit = (|shift_mant[13:0]);

    assign mant = (guard_bit & (round_bit | sticky_bit)) ? norm_mant + 1'b1 : norm_mant;

    assign mant_overflow = (&norm_mant) & (~(|mant));
    wire signed [9:0] final_exp_calc = (mant_overflow) ? (tmp_exp + $signed(10'd1)) : tmp_exp;

    assign exp_overflow = (final_exp_calc > $signed(10'd255));
    assign exp_underflow = (final_exp_calc <= $signed(10'd0)) || is_input_zero;

    assign exp = final_exp_calc[7:0];

    assign d_out = (exp_overflow) ? {sign, 8'b11111111, 7'b0} : ((exp_underflow) ? {sign, 8'b0, 7'b0} : {sign, exp, mant});
endmodule
