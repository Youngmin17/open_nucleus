// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

module fp24_to_bf16_round
(
    input  wire [23:0] d_in,
    output wire [15:0] d_out
);

    wire        sign     = d_in[23];
    wire [7:0]  exp_in   = d_in[22:15];
    wire [14:0] mant_in  = d_in[14:0];

    wire [6:0]  mant_hi  = mant_in[14:8];
    wire        guard    = mant_in[7];
    wire        round_b  = mant_in[6];
    wire        sticky   = |mant_in[5:0];

    wire        round_up = guard & (round_b | sticky);
    wire [7:0]  mant_rounded_ext = {1'b0, mant_hi} + {7'b0, round_up};
    wire        mant_overflow    = mant_rounded_ext[7];
    wire [6:0]  mant_out         = mant_rounded_ext[6:0];

    wire        is_zero_in   = (exp_in == 8'd0) && (mant_in == 15'd0);
    wire        is_inf_nan_in = (exp_in == 8'hFF);

    wire [8:0]  exp_incremented = {1'b0, exp_in} + 9'd1;
    wire        exp_overflow    = mant_overflow && (exp_incremented[8] | (exp_incremented[7:0] == 8'hFF));

    wire [7:0]  exp_out         = mant_overflow ? exp_incremented[7:0] : exp_in;

    assign d_out = is_zero_in     ? {sign, 8'd0, 7'd0} :
                   is_inf_nan_in  ? {sign, 8'hFF, mant_hi} :
                   exp_overflow   ? {sign, 8'hFF, 7'd0} :
                                    {sign, exp_out, mant_out};
endmodule
