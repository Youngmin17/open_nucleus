// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module norm_round_fmat
#(
    parameter MANT_WIDTH_IN  = 24,
    parameter EXP_WIDTH_IN   = 8,
    parameter DATA_WIDTH_OUT = 16,
    parameter LEFT_WIDTH     = 8
)
(
    input  [EXP_WIDTH_IN-1:0]   exp_in,
    input  [MANT_WIDTH_IN-1:0]  mant_in,
    output [DATA_WIDTH_OUT-1:0] d_out
);

    localparam OUT_MANT_WIDTH = DATA_WIDTH_OUT - 1 - EXP_WIDTH_IN;
    localparam MAG_WIDTH      = MANT_WIDTH_IN - 1;
    localparam RIGHT_WIDTH    = MAG_WIDTH - LEFT_WIDTH;
    localparam GUARD_POS      = MAG_WIDTH - 1 - OUT_MANT_WIDTH;

    wire sign = mant_in[MANT_WIDTH_IN-1];
    wire [MANT_WIDTH_IN-1:0] mant_comp_2s = sign ? (~mant_in + 1'b1) : mant_in;
    wire [MAG_WIDTH-1:0]     without_sign = mant_comp_2s[MAG_WIDTH-1:0];

    wire is_input_zero = ~(|without_sign);

    wire [LEFT_WIDTH-1:0]  dec_point_left  = without_sign[MAG_WIDTH-1 -: LEFT_WIDTH];
    wire [RIGHT_WIDTH-1:0] dec_point_right = without_sign[RIGHT_WIDTH-1:0];

    wire shift_left = ~(|dec_point_left);

    wire [MAG_WIDTH-1:0] tmp_mant = shift_left ?
            {dec_point_right, {LEFT_WIDTH{1'b0}}} : without_sign;

    reg [7:0] zero_cnt_left;
    integer kl;
    reg     found_l;
    always @(*) begin
        zero_cnt_left = LEFT_WIDTH[7:0];
        found_l = 1'b0;
        for (kl = 0; kl < LEFT_WIDTH; kl = kl + 1) begin
            if (!found_l && dec_point_left[LEFT_WIDTH-1-kl]) begin
                zero_cnt_left = kl[7:0];
                found_l = 1'b1;
            end
        end
    end

    reg [7:0] zero_cnt_right;
    integer kr;
    reg     found_r;
    always @(*) begin
        zero_cnt_right = RIGHT_WIDTH[7:0];
        found_r = 1'b0;
        for (kr = 0; kr < RIGHT_WIDTH; kr = kr + 1) begin
            if (!found_r && dec_point_right[RIGHT_WIDTH-1-kr]) begin
                zero_cnt_right = kr[7:0];
                found_r = 1'b1;
            end
        end
    end

    wire [7:0] num_shift = shift_left ? (zero_cnt_right + 8'd1)
                                      : (zero_cnt_left  + 8'd1);
    wire [MAG_WIDTH-1:0] shift_mant = tmp_mant << num_shift;

    wire [OUT_MANT_WIDTH-1:0] norm_mant = shift_mant[MAG_WIDTH-1 -: OUT_MANT_WIDTH];

    wire [7:0] exp_inc = shift_left ? num_shift : (LEFT_WIDTH[7:0] - num_shift);

    wire signed [EXP_WIDTH_IN+1:0] tmp_exp =
            shift_left ? ($signed({2'b0, exp_in}) - $signed({2'b0, exp_inc}))
                       : ($signed({2'b0, exp_in}) + $signed({2'b0, exp_inc}));

    wire guard_bit  = shift_mant[GUARD_POS];
    wire round_bit  = shift_mant[GUARD_POS-1];
    wire sticky_bit = |shift_mant[GUARD_POS-2:0];

    wire [OUT_MANT_WIDTH-1:0] mant =
            (guard_bit & (round_bit | sticky_bit)) ? (norm_mant + 1'b1) : norm_mant;

    wire mant_overflow = (&norm_mant) & (~(|mant));

    wire signed [EXP_WIDTH_IN+1:0] final_exp_calc =
            mant_overflow ? (tmp_exp + $signed(2'd1)) : tmp_exp;

    wire exp_overflow  = (final_exp_calc > $signed({2'b0, {EXP_WIDTH_IN{1'b1}}}));
    wire exp_underflow = (final_exp_calc <= $signed(2'd0)) || is_input_zero;

    wire [EXP_WIDTH_IN-1:0] exp = final_exp_calc[EXP_WIDTH_IN-1:0];

    assign d_out = exp_overflow  ? {sign, {EXP_WIDTH_IN{1'b1}}, {OUT_MANT_WIDTH{1'b0}}} :
                   exp_underflow ? {sign, {EXP_WIDTH_IN{1'b0}}, {OUT_MANT_WIDTH{1'b0}}} :
                                   {sign, exp, mant};

endmodule
