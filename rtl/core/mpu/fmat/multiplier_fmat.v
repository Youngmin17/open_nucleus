// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module multiplier_fmat
#(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 24,
    parameter DATA_NUM = 4,
    parameter SCALE_FACTOR = 8
)
(
    input [7:0] mode,
    input [DATA_WIDTH*DATA_NUM-1:0] a_in,
    input [DATA_WIDTH-1:0] b_in,
    input [DATA_NUM*SCALE_FACTOR-1:0] scale_in,
    output [OUT_WIDTH*DATA_NUM-1:0] d_out
);
    localparam EXP_WIDTH      = 8;
    localparam MANT_WIDTH     = 8;
    localparam OUT_MANT_WIDTH = 15;

    wire [DATA_WIDTH-1:0] data_a0;
    wire [DATA_WIDTH-1:0] data_a1;
    wire [DATA_WIDTH-1:0] data_a2;
    wire [DATA_WIDTH-1:0] data_a3;

    wire sign_a0;
    wire sign_a1;
    wire sign_a2;
    wire sign_a3;

    wire [EXP_WIDTH-1:0] exp_a0;
    wire [EXP_WIDTH-1:0] exp_a1;
    wire [EXP_WIDTH-1:0] exp_a2;
    wire [EXP_WIDTH-1:0] exp_a3;

    wire [MANT_WIDTH-1:0] mant_a0;
    wire [MANT_WIDTH-1:0] mant_a1;
    wire [MANT_WIDTH-1:0] mant_a2;
    wire [MANT_WIDTH-1:0] mant_a3;

    wire [DATA_WIDTH-1:0] data_b0;

    wire sign_b0;
    wire sign_b1;
    wire sign_b2;
    wire sign_b3;

    wire [EXP_WIDTH-1:0] exp_b0;
    wire [EXP_WIDTH-1:0] exp_b1;
    wire [EXP_WIDTH-1:0] exp_b2;
    wire [EXP_WIDTH-1:0] exp_b3;

    wire [1:0] mant_b0;
    wire [1:0] mant_b1;
    wire [1:0] mant_b2;
    wire [1:0] mant_b3;

    assign data_a0 = a_in[15:0];
    assign data_a1 = a_in[31:16];
    assign data_a2 = a_in[47:32];
    assign data_a3 = a_in[63:48];

    assign sign_a0 = data_a0[15];
    assign sign_a1 = data_a1[15];
    assign sign_a2 = data_a2[15];
    assign sign_a3 = data_a3[15];

    assign exp_a0 = data_a0[14:7];
    assign exp_a1 = data_a1[14:7];
    assign exp_a2 = data_a2[14:7];
    assign exp_a3 = data_a3[14:7];

    assign mant_a0 = (mode[1:0] == 2'b01) ? {1'b1, data_a3[6:0]} :
                     (mode[1:0] == 2'b10) ? {1'b1, data_a0[6:0]} :
                     (mode[1:0] == 2'b11) ? {1'b1, data_a0[6:0]} :
                                          8'b0                   ;

    assign mant_a1 = (mode[3:2] == 2'b01) ? {1'b1, data_a3[6:0]} :
                     (mode[3:2] == 2'b10) ? {1'b1, data_a0[6:0]} :
                     (mode[3:2] == 2'b11) ? {1'b1, data_a1[6:0]} :
                                          8'b0                   ;

    assign mant_a2 = (mode[5:4] == 2'b01) ? {1'b1, data_a3[6:0]} :
                     (mode[5:4] == 2'b10) ? {1'b1, data_a2[6:0]} :
                     (mode[5:4] == 2'b11) ? {1'b1, data_a2[6:0]} :
                                          8'b0                   ;

    assign mant_a3 = (mode[7:6] == 2'b01) ? {1'b1, data_a3[6:0]} :
                     (mode[7:6] == 2'b10) ? {1'b1, data_a2[6:0]} :
                     (mode[7:6] == 2'b11) ? {1'b1, data_a3[6:0]} :
                                          8'b0                   ;

    wire subnormal_a0 = (exp_a0 == 8'd0);
    wire subnormal_a1 = (exp_a1 == 8'd0);
    wire subnormal_a2 = (exp_a2 == 8'd0);
    wire subnormal_a3 = (exp_a3 == 8'd0);

    assign data_b0 = b_in;

    wire subnormal_b0 = ((mode[1:0] == 2'b10) && (exp_b0 == 8'd0));
    wire subnormal_b1 = ((mode[3:2] == 2'b10) && (exp_b1 == 8'd0));
    wire subnormal_b2 = ((mode[5:4] == 2'b10) && (exp_b2 == 8'd0));
    wire subnormal_b3 = ((mode[7:6] == 2'b01) && (exp_b3 == 8'd0)) || ((mode[7:6] == 2'b10) && (exp_b3 == 8'd0));

    assign sign_b0 = (mode[1:0] == 2'b01) ? 1'b0         :
                     (mode[1:0] == 2'b10) ? data_b0[7]   :
                     (mode[1:0] == 2'b11) ? data_b0[3]   :
                                          1'b0           ;

    assign sign_b1 = (mode[3:2] == 2'b01) ? 1'b0         :
                     (mode[3:2] == 2'b11) ? data_b0[7]   :
                                          1'b0           ;

    assign sign_b2 = (mode[5:4] == 2'b01) ? 1'b0         :
                     (mode[5:4] == 2'b10) ? data_b0[15]  :
                     (mode[5:4] == 2'b11) ? data_b0[11]  :
                                          1'b0           ;

    assign sign_b3 = (mode[7:6] == 2'b01) ? data_b0[15] :
                     (mode[7:6] == 2'b11) ? data_b0[15] :
                                          1'b0          ;

    assign exp_b0 = (mode[1:0] == 2'b01) ? 8'b0                 :
                    (mode[1:0] == 2'b10) ? {4'b0, data_b0[6:3]} :
                    (mode[1:0] == 2'b11) ? {6'b0, data_b0[2:1]} :
                                         8'b0                   ;

    assign exp_b1 = (mode[3:2] == 2'b01) ? 8'b0                 :
                    (mode[3:2] == 2'b11) ? {6'b0, data_b0[6:5]} :
                                         8'b0                   ;

    assign exp_b2 = (mode[5:4] == 2'b01) ? 8'b0                   :
                    (mode[5:4] == 2'b10) ? {4'b0, data_b0[14:11]} :
                    (mode[5:4] == 2'b11) ? {6'b0, data_b0[10:9]}  :
                                         8'b0                     ;

    assign exp_b3 = (mode[7:6] == 2'b01) ? data_b0[14:7]          :
                    (mode[7:6] == 2'b11) ? {6'b0, data_b0[14:13]} :
                                         8'b0                     ;

    assign mant_b0 = (mode[1:0] == 2'b01) ? data_b0[1:0]                            :
                     (mode[1:0] == 2'b10) ? (exp_b0 == 8'd0) ? 2'b00 : data_b0[1:0] :
                     (mode[1:0] == 2'b11) ? {(exp_b0 != 8'd0), data_b0[0]}          :
                                          2'b0                                      ;

    assign mant_b1 = (mode[3:2] == 2'b01) ? data_b0[3:2]                   :
                     (mode[3:2] == 2'b10) ? {(exp_b0 != 8'd0), data_b0[2]} :
                     (mode[3:2] == 2'b11) ? {(exp_b1 != 8'd0), data_b0[4]} :
                                          2'b0                             ;

    assign mant_b2 = (mode[5:4] == 2'b01) ? data_b0[5:4]                            :
                     (mode[5:4] == 2'b10) ? (exp_b2 == 8'd0) ? 2'b00 : data_b0[9:8] :
                     (mode[5:4] == 2'b11) ? {(exp_b2 != 8'd0), data_b0[8]}          :
                                          2'b0                                      ;

    assign mant_b3 = (mode[7:6] == 2'b01) ? {1'b1, data_b0[6]}              :
                     (mode[7:6] == 2'b10) ? {(exp_b2 != 8'd0), data_b0[10]} :
                     (mode[7:6] == 2'b11) ? {(exp_b3 != 8'd0), data_b0[12]} :
                                          2'b0                              ;

    wire sign_0;
    wire sign_1;
    wire sign_2;
    wire sign_3;

    wire [EXP_WIDTH:0] tmp_exp_0;
    wire [EXP_WIDTH:0] tmp_exp_1;
    wire [EXP_WIDTH:0] tmp_exp_2;
    wire [EXP_WIDTH:0] tmp_exp_3;

    assign sign_1 = sign_a1 ^ sign_b1;
    assign sign_3 = sign_a3 ^ sign_b3;

    assign tmp_exp_0 = (mode[1:0] == 2'b01) ? (exp_a0 + exp_b0 - 8'b01111111) :
                       (mode[1:0] == 2'b10) ? (exp_a0 + exp_b0 - 4'b0111)     :
                       (mode[1:0] == 2'b11) ? (exp_a0 + 4'b0011)              :
                                            9'b0                              ;

    assign tmp_exp_1 = (mode[3:2] == 2'b01) ? (exp_a1 + exp_b1 - 8'b01111111) :
                       (mode[3:2] == 2'b10) ? (exp_a1 + exp_b1 - 4'b0111)     :
                       (mode[3:2] == 2'b11) ? (exp_a1 + 4'b0011)              :
                                            9'b0                              ;

    assign tmp_exp_2 = (mode[5:4] == 2'b01) ? (exp_a2 + exp_b2 - 8'b01111111) :
                       (mode[5:4] == 2'b10) ? (exp_a2 + exp_b2 - 4'b0111)     :
                       (mode[5:4] == 2'b11) ? (exp_a2 + 4'b0011)              :
                                            9'b0                              ;

    assign tmp_exp_3 = (mode[7:6] == 2'b01) ? (exp_a3 + exp_b3 - 8'b01111111) :
                       (mode[7:6] == 2'b10) ? (exp_a3 + exp_b3 - 4'b0111)     :
                       (mode[7:6] == 2'b11) ? (exp_a3 + 4'b0011)              :
                                            9'b0                              ;

    wire subnormal_c0 = 1'b0;
    wire subnormal_c1 = 1'b0;
    wire subnormal_c2 = 1'b0;
    wire subnormal_c3 = ((mode[7:6] == 2'b01) && (exp_a3 + exp_b3 < 9'd127));

    wire [9:0] mul_o0;
    wire [9:0] mul_o1;
    wire [9:0] mul_o2;
    wire [9:0] mul_o3;
    wire [15:0] pp_0;
    wire [15:0] pp_1;
    wire [15:0] pp_2;
    wire [15:0] pp_3;

    mult_8x2_fmat mult0 (.a(mant_a0), .b(mant_b0), .d_out(mul_o0));
    mult_8x2_fmat mult1 (.a(mant_a1), .b(mant_b1), .d_out(mul_o1));
    mult_8x2_fmat mult2 (.a(mant_a2), .b(mant_b2), .d_out(mul_o2));
    mult_8x2_fmat mult3 (.a(mant_a3), .b(mant_b3), .d_out(mul_o3));

    wire [2:0] fp4_shift_b0 = (exp_b0 == 8'd0) ? 3'd3 :
                              (exp_b0 == 8'd1) ? 3'd3 :
                              (exp_b0 == 8'd2) ? 3'd4 :
                                                 3'd5 ;

    wire [2:0] fp4_shift_b1 = (exp_b1 == 8'd0) ? 3'd3 :
                              (exp_b1 == 8'd1) ? 3'd3 :
                              (exp_b1 == 8'd2) ? 3'd4 :
                                                 3'd5 ;

    wire [2:0] fp4_shift_b2 = (exp_b2 == 8'd0) ? 3'd3 :
                              (exp_b2 == 8'd1) ? 3'd3 :
                              (exp_b2 == 8'd2) ? 3'd4 :
                                                 3'd5 ;

    wire [2:0] fp4_shift_b3 = (exp_b3 == 8'd0) ? 3'd3 :
                              (exp_b3 == 8'd1) ? 3'd3 :
                              (exp_b3 == 8'd2) ? 3'd4 :
                                                 3'd5 ;

    assign pp_0 = (mode[1:0] == 2'b01) ? {6'b0, mul_o0}                       :
                  (mode[1:0] == 2'b10) ? {2'b0, mul_o0, 4'b0}                :
                  (mode[1:0] == 2'b11) ? ({6'b0, mul_o0} << fp4_shift_b0)   :
                                       16'b0;

    assign pp_1 = (mode[3:2] == 2'b01) ? {4'b0, mul_o1, 2'b0}                :
                  (mode[3:2] == 2'b10) ? {mul_o1, 6'b0}                       :
                  (mode[3:2] == 2'b11) ? ({6'b0, mul_o1} << fp4_shift_b1)   :
                                       16'b0                                  ;

    assign pp_2 = (mode[5:4] == 2'b01) ? {2'b0, mul_o2, 4'b0}                :
                  (mode[5:4] == 2'b10) ? {2'b0, mul_o2, 4'b0}                :
                  (mode[5:4] == 2'b11) ? ({6'b0, mul_o2} << fp4_shift_b2)   :
                                       16'b0                                  ;

    assign pp_3 = (mode[7:6] == 2'b01) ? {mul_o3, 6'b0}                       :
                  (mode[7:6] == 2'b10) ? {mul_o3, 6'b0}                       :
                  (mode[7:6] == 2'b11) ? ({6'b0, mul_o3} << fp4_shift_b3)   :
                                       16'b0                                  ;

    assign sign_0 = sign_a0 ^ sign_b0;
    assign sign_2 = sign_a2 ^ sign_b2;

    wire [15:0] aligned_mant_0;
    wire [15:0] aligned_mant_1;
    wire [15:0] aligned_mant_2;
    wire [15:0] aligned_mant_3;

    assign aligned_mant_0 = (mode[1:0] == 2'b01) ? 16'b0       :
                            (mode[1:0] == 2'b10) ? pp_1+pp_0   :
                            (mode[1:0] == 2'b11) ? pp_0         :
                                                 16'b0         ;

    assign aligned_mant_1 = (mode[3:2] == 2'b01) ? 16'b0 :
                            (mode[3:2] == 2'b10) ? 16'b0 :
                            (mode[3:2] == 2'b11) ? pp_1  :
                                                 16'b0   ;

    assign aligned_mant_2 = (mode[5:4] == 2'b01) ? 16'b0       :
                            (mode[5:4] == 2'b10) ? pp_3+pp_2   :
                            (mode[5:4] == 2'b11) ? pp_2         :
                                                 16'b0         ;

    assign aligned_mant_3 = (mode[7:6] == 2'b01) ? pp_3+pp_2+pp_1+pp_0 :
                            (mode[7:6] == 2'b10) ? 16'b0               :
                            (mode[7:6] == 2'b11) ? pp_3                :
                                                 16'b0                 ;

    wire [3:0] shift_num_0;
    wire [3:0] shift_num_1;
    wire [3:0] shift_num_2;
    wire [3:0] shift_num_3;

    wire [15:0] shift_mant_0;
    wire [15:0] shift_mant_1;
    wire [15:0] shift_mant_2;
    wire [15:0] shift_mant_3;

    lzd_16bit_fmat u0_lzd_16bit (.d_in(aligned_mant_0), .d_out(shift_num_0));
    lzd_16bit_fmat u1_lzd_16bit (.d_in(aligned_mant_1), .d_out(shift_num_1));
    lzd_16bit_fmat u2_lzd_16bit (.d_in(aligned_mant_2), .d_out(shift_num_2));
    lzd_16bit_fmat u3_lzd_16bit (.d_in(aligned_mant_3), .d_out(shift_num_3));

    assign shift_mant_0 = aligned_mant_0 << shift_num_0;
    assign shift_mant_1 = aligned_mant_1 << shift_num_1;
    assign shift_mant_2 = aligned_mant_2 << shift_num_2;
    assign shift_mant_3 = aligned_mant_3 << shift_num_3;

    wire [OUT_MANT_WIDTH-1:0] norm_mant_0;
    wire [OUT_MANT_WIDTH-1:0] norm_mant_1;
    wire [OUT_MANT_WIDTH-1:0] norm_mant_2;
    wire [OUT_MANT_WIDTH-1:0] norm_mant_3;

    wire signed [4:0] increment_0;
    wire signed [4:0] increment_1;
    wire signed [4:0] increment_2;
    wire signed [4:0] increment_3;

    assign norm_mant_0 = shift_mant_0[14:0];
    assign norm_mant_1 = shift_mant_1[14:0];
    assign norm_mant_2 = shift_mant_2[14:0];
    assign norm_mant_3 = shift_mant_3[14:0];

    assign increment_0 = (mode[1:0] == 2'b01) ? 5'sd0                                                                                     :
                         (mode[1:0] == 2'b10) ? ((exp_b0 == 8'd0) ? $signed(5'd2) - $signed({1'b0, shift_num_0}) : $signed(5'd1) - $signed({1'b0, shift_num_0})) :
                         (mode[1:0] == 2'b11) ? ($signed(5'd1) - $signed({1'b0, shift_num_0}))                                                                    :
                                              5'sd0                                                                                                              ;

    assign increment_1 = (mode[3:2] == 2'b01) ? 5'sd0                                                                  :
                         (mode[3:2] == 2'b10) ? 5'sd0                                                                  :
                         (mode[3:2] == 2'b11) ? ($signed(5'd1) - $signed({1'b0, shift_num_1}))                     :
                                              5'sd0                                                                  ;

    assign increment_2 = (mode[5:4] == 2'b01) ? 5'sd0                                                                                     :
                         (mode[5:4] == 2'b10) ? ((exp_b2 == 8'd0) ? $signed(5'd2) - $signed({1'b0, shift_num_2}) : $signed(5'd1) - $signed({1'b0, shift_num_2})) :
                         (mode[5:4] == 2'b11) ? ($signed(5'd1) - $signed({1'b0, shift_num_2}))                                                                    :
                                              5'sd0                                                                                                              ;

    assign increment_3 = (mode[7:6] == 2'b01) ? ($signed(5'd1) - $signed({1'b0, shift_num_3}))  :
                         (mode[7:6] == 2'b10) ? 5'sd0                                          :
                         (mode[7:6] == 2'b11) ? ($signed(5'd1) - $signed({1'b0, shift_num_3}))  :
                                              5'sd0                                          ;

    wire [EXP_WIDTH+1:0] exp_norm_0;
    wire [EXP_WIDTH+1:0] exp_norm_1;
    wire [EXP_WIDTH+1:0] exp_norm_2;
    wire [EXP_WIDTH+1:0] exp_norm_3;

    wire signed [EXP_WIDTH+1:0] exp_inc_0 = $signed({1'b0, tmp_exp_0}) + increment_0;
    wire signed [EXP_WIDTH+1:0] exp_inc_1 = $signed({1'b0, tmp_exp_1}) + increment_1;
    wire signed [EXP_WIDTH+1:0] exp_inc_2 = $signed({1'b0, tmp_exp_2}) + increment_2;
    wire signed [EXP_WIDTH+1:0] exp_inc_3 = $signed({1'b0, tmp_exp_3}) + increment_3;

    assign exp_norm_0 = (mode[1:0] == 2'b01) ? 10'b0       :
                        (mode[1:0] == 2'b10) ? exp_inc_0    :
                        (mode[1:0] == 2'b11) ? exp_inc_0    :
                                              10'b0         ;

    assign exp_norm_1 = (mode[3:2] == 2'b01) ? 10'b0        :
                        (mode[3:2] == 2'b10) ? 10'b0        :
                        (mode[3:2] == 2'b11) ? exp_inc_1    :
                                             10'b0          ;

    assign exp_norm_2 = (mode[5:4] == 2'b01) ? 10'b0       :
                        (mode[5:4] == 2'b10) ? exp_inc_2    :
                        (mode[5:4] == 2'b11) ? exp_inc_2    :
                                              10'b0         ;

    assign exp_norm_3 = (mode[7:6] == 2'b01) ? exp_inc_3    :
                        (mode[7:6] == 2'b10) ? 10'b0        :
                        (mode[7:6] == 2'b11) ? exp_inc_3    :
                                             10'b0          ;

    wire [OUT_MANT_WIDTH-1:0] mant_0;
    wire [OUT_MANT_WIDTH-1:0] mant_1;
    wire [OUT_MANT_WIDTH-1:0] mant_2;
    wire [OUT_MANT_WIDTH-1:0] mant_3;

    wire mant_overflow_0;
    wire mant_overflow_1;
    wire mant_overflow_2;
    wire mant_overflow_3;

    assign mant_0 = norm_mant_0;
    assign mant_1 = norm_mant_1;
    assign mant_2 = norm_mant_2;
    assign mant_3 = norm_mant_3;

    assign mant_overflow_0 = 1'b0;
    assign mant_overflow_1 = 1'b0;
    assign mant_overflow_2 = 1'b0;
    assign mant_overflow_3 = 1'b0;

    wire [EXP_WIDTH-1:0] exp_scale_0;
    wire [EXP_WIDTH-1:0] exp_scale_1;
    wire [EXP_WIDTH-1:0] exp_scale_2;
    wire [EXP_WIDTH-1:0] exp_scale_3;

    wire signed [EXP_WIDTH+2:0] exp_0;
    wire signed [EXP_WIDTH+2:0] exp_1;
    wire signed [EXP_WIDTH+2:0] exp_2;
    wire signed [EXP_WIDTH+2:0] exp_3;

    assign exp_scale_0 = scale_in[7:0];
    assign exp_scale_1 = scale_in[15:8];
    assign exp_scale_2 = scale_in[23:16];
    assign exp_scale_3 = scale_in[31:24];

    assign exp_0 = $signed({1'b0, exp_norm_0}) + $signed({10'b0, mant_overflow_0}) + $signed({1'b0, exp_scale_0}) - $signed(11'd127);
    assign exp_1 = $signed({1'b0, exp_norm_1}) + $signed({10'b0, mant_overflow_1}) + $signed({1'b0, exp_scale_1}) - $signed(11'd127);
    assign exp_2 = $signed({1'b0, exp_norm_2}) + $signed({10'b0, mant_overflow_2}) + $signed({1'b0, exp_scale_2}) - $signed(11'd127);
    assign exp_3 = $signed({1'b0, exp_norm_3}) + $signed({10'b0, mant_overflow_3}) + $signed({1'b0, exp_scale_3}) - $signed(11'd127);

    wire [OUT_WIDTH-1:0] tmp_out_0;
    wire [OUT_WIDTH-1:0] tmp_out_1;
    wire [OUT_WIDTH-1:0] tmp_out_2;
    wire [OUT_WIDTH-1:0] tmp_out_3;

    assign tmp_out_0 = ((mode[1:0] == 2'b10) && (data_b0[6:0] == 7'b0000000))      ? {OUT_WIDTH{1'b0}} :
                       ((mode[1:0] == 2'b11) && (data_b0[2:0] == 3'b000))          ? {OUT_WIDTH{1'b0}} :
                                                                                    {sign_0, exp_0[7:0], mant_0};

    assign tmp_out_1 = ((mode[3:2] == 2'b11) && (data_b0[6:4] == 3'b000))          ? {OUT_WIDTH{1'b0}} :
                                                                                    {sign_1, exp_1[7:0], mant_1};

    assign tmp_out_2 = ((mode[5:4] == 2'b10) && (data_b0[14:8]  == 7'b0000000))    ? {OUT_WIDTH{1'b0}} :
                       ((mode[5:4] == 2'b11) && (data_b0[10:8] == 3'b000))         ? {OUT_WIDTH{1'b0}} :
                                                                                    {sign_2, exp_2[7:0], mant_2};

    assign tmp_out_3 = ((mode[7:6] == 2'b11) && (data_b0[14:12] == 3'b000))        ? {OUT_WIDTH{1'b0}} :
                                                                                    {sign_3, exp_3[7:0], mant_3};

    wire overflow_0;
    wire overflow_1;
    wire overflow_2;
    wire overflow_3;

    wire underflow_0;
    wire underflow_1;
    wire underflow_2;
    wire underflow_3;

    assign overflow_0 = (exp_0 >= $signed(11'd255));
    assign overflow_1 = (exp_1 >= $signed(11'd255));
    assign overflow_2 = (exp_2 >= $signed(11'd255));
    assign overflow_3 = (exp_3 >= $signed(11'd255));

    assign underflow_0 = (exp_0 <= $signed(11'd0)) || subnormal_a0 || subnormal_b0 || subnormal_c0;
    assign underflow_1 = (exp_1 <= $signed(11'd0)) || subnormal_a1 || subnormal_b1 || subnormal_c1;
    assign underflow_2 = (exp_2 <= $signed(11'd0)) || subnormal_a2 || subnormal_b2 || subnormal_c2;
    assign underflow_3 = (exp_3 <= $signed(11'd0)) || subnormal_a3 || subnormal_b3 || subnormal_c3;

    wire [OUT_WIDTH-1:0] out_0;
    wire [OUT_WIDTH-1:0] out_1;
    wire [OUT_WIDTH-1:0] out_2;
    wire [OUT_WIDTH-1:0] out_3;
    wire [DATA_NUM*OUT_WIDTH-1:0] d_out_w;

    assign out_0 = (underflow_0) ? {OUT_WIDTH{1'b0}} :
                   (overflow_0)  ? {tmp_out_0[OUT_WIDTH-1], 8'b11111111, {OUT_MANT_WIDTH{1'b0}}} :
                   tmp_out_0;

    assign out_1 = (underflow_1) ? {OUT_WIDTH{1'b0}} :
                   (overflow_1)  ? {tmp_out_1[OUT_WIDTH-1], 8'b11111111, {OUT_MANT_WIDTH{1'b0}}} :
                   tmp_out_1;

    assign out_2 = (underflow_2) ? {OUT_WIDTH{1'b0}} :
                   (overflow_2)  ? {tmp_out_2[OUT_WIDTH-1], 8'b11111111, {OUT_MANT_WIDTH{1'b0}}} :
                   tmp_out_2;

    assign out_3 = (underflow_3) ? {OUT_WIDTH{1'b0}} :
                   (overflow_3)  ? {tmp_out_3[OUT_WIDTH-1], 8'b11111111, {OUT_MANT_WIDTH{1'b0}}} :
                   tmp_out_3;

    assign d_out_w = {out_3, out_2, out_1, out_0};

    assign d_out = d_out_w;

    // synopsys translate_off
    // synopsys translate_on

endmodule
