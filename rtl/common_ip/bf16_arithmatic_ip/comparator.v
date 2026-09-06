// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

`ifndef COMMON_BF16_COMPARATOR_SV
`define COMMON_BF16_COMPARATOR_SV
module comparator
#(
    parameter PRECISION         = 16
)
(
    input  wire                     max_min,

    input  wire [PRECISION-1:0]     a_in,
    input  wire [PRECISION-1:0]     b_in,

    output wire [PRECISION-1:0]     d_out,
    output wire                     pos
);

wire        a_sign = a_in[15];
wire [7:0]  a_exp  = a_in[14:7];
wire [6:0]  a_mant = a_in[6:0];

wire        b_sign = b_in[15];
wire [7:0]  b_exp  = b_in[14:7];
wire [6:0]  b_mant = b_in[6:0];

wire        signs_different = a_sign ^ b_sign;
wire        both_positive   = ~a_sign & ~b_sign;
wire        both_negative   =  a_sign &  b_sign;

wire [14:0] a_exp_mant = {a_exp, a_mant};
wire [14:0] b_exp_mant = {b_exp, b_mant};

wire        a_greater_unsigned = (a_exp_mant > b_exp_mant);

wire        a_greater_than_b = (signs_different) ? (~a_sign) :
                                (both_positive)   ? a_greater_unsigned :
                                (both_negative)   ? (~a_greater_unsigned) : 1'b0;

wire select_a = max_min ? a_greater_than_b : ~a_greater_than_b;

assign d_out = select_a ? a_in : b_in;
assign pos = ~select_a;

endmodule
`endif
