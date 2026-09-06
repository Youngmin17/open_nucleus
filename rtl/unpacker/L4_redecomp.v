// SPDX-License-Identifier: Apache-2.0
module L4_redecomp (
    input wire [13:0] val,
    input wire [4:0] k,
    output wire [6:0] val_l,
    output wire [6:0] val_r,
    output wire [3:0] kl,
    output wire [3:0] kr
);

    localparam L4_WEIGHT_KR_0                 = 1'd1;
    localparam L4_WEIGHT_KR_1                 = 4'd8;
    localparam L4_WEIGHT_KR_2                 = 5'd28;
    localparam L4_WEIGHT_KR_3                 = 6'd56;
    localparam L4_WEIGHT_KR_4                 = 7'd70;

    localparam L4_REC_WEIGHT_KR_0        = 15'd16384;
    localparam L4_REC_WEIGHT_KR_1        = 12'd2048;
    localparam L4_REC_WEIGHT_KR_2        = 10'd585;
    localparam L4_REC_WEIGHT_KR_3        = 9'd292;
    localparam L4_REC_WEIGHT_KR_4        = 8'd234;

    localparam L4_OFFSET_K_1_KL_1                   = 14'd8;
    localparam L4_OFFSET_K_2_KL_1                   = 14'd28;
    localparam L4_OFFSET_K_2_KL_2                   = 14'd92;
    localparam L4_OFFSET_K_3_KL_1                   = 14'd56;
    localparam L4_OFFSET_K_3_KL_2                   = 14'd280;
    localparam L4_OFFSET_K_3_KL_3                   = 14'd504;
    localparam L4_OFFSET_K_4_KL_1                   = 14'd70;
    localparam L4_OFFSET_K_4_KL_2                   = 14'd518;
    localparam L4_OFFSET_K_4_KL_3                   = 14'd1302;
    localparam L4_OFFSET_K_4_KL_4                   = 14'd1750;
    localparam L4_OFFSET_K_5_KL_1                   = 14'd56;
    localparam L4_OFFSET_K_5_KL_2                   = 14'd616;
    localparam L4_OFFSET_K_5_KL_3                   = 14'd2184;
    localparam L4_OFFSET_K_5_KL_4                   = 14'd3752;
    localparam L4_OFFSET_K_5_KL_5                   = 14'd4312;
    localparam L4_OFFSET_K_6_KL_1                   = 14'd28;
    localparam L4_OFFSET_K_6_KL_2                   = 14'd476;
    localparam L4_OFFSET_K_6_KL_3                   = 14'd2436;
    localparam L4_OFFSET_K_6_KL_4                   = 14'd5572;
    localparam L4_OFFSET_K_6_KL_5                   = 14'd7532;
    localparam L4_OFFSET_K_6_KL_6                   = 14'd7980;
    localparam L4_OFFSET_K_7_KL_1                   = 14'd8;
    localparam L4_OFFSET_K_7_KL_2                   = 14'd232;
    localparam L4_OFFSET_K_7_KL_3                   = 14'd1800;
    localparam L4_OFFSET_K_7_KL_4                   = 14'd5720;
    localparam L4_OFFSET_K_7_KL_5                   = 14'd9640;
    localparam L4_OFFSET_K_7_KL_6                   = 14'd11208;
    localparam L4_OFFSET_K_7_KL_7                   = 14'd11432;
    localparam L4_OFFSET_K_8_KL_1                   = 14'd1;
    localparam L4_OFFSET_K_8_KL_2                   = 14'd65;
    localparam L4_OFFSET_K_8_KL_3                   = 14'd849;
    localparam L4_OFFSET_K_8_KL_4                   = 14'd3985;
    localparam L4_OFFSET_K_8_KL_5                   = 14'd8885;
    localparam L4_OFFSET_K_8_KL_6                   = 14'd12021;
    localparam L4_OFFSET_K_8_KL_7                   = 14'd12805;
    localparam L4_OFFSET_K_8_KL_8                   = 14'd12869;
    localparam L4_OFFSET_K_9_KL_1                   = 14'd0;
    localparam L4_OFFSET_K_9_KL_2                   = 14'd8;
    localparam L4_OFFSET_K_9_KL_3                   = 14'd232;
    localparam L4_OFFSET_K_9_KL_4                   = 14'd1800;
    localparam L4_OFFSET_K_9_KL_5                   = 14'd5720;
    localparam L4_OFFSET_K_9_KL_6                   = 14'd9640;
    localparam L4_OFFSET_K_9_KL_7                   = 14'd11208;
    localparam L4_OFFSET_K_9_KL_8                   = 14'd11432;
    localparam L4_OFFSET_K_10_KL_2                  = 14'd0;
    localparam L4_OFFSET_K_10_KL_3                  = 14'd28;
    localparam L4_OFFSET_K_10_KL_4                  = 14'd476;
    localparam L4_OFFSET_K_10_KL_5                  = 14'd2436;
    localparam L4_OFFSET_K_10_KL_6                  = 14'd5572;
    localparam L4_OFFSET_K_10_KL_7                  = 14'd7532;
    localparam L4_OFFSET_K_10_KL_8                  = 14'd7980;
    localparam L4_OFFSET_K_11_KL_3                  = 14'd0;
    localparam L4_OFFSET_K_11_KL_4                  = 14'd56;
    localparam L4_OFFSET_K_11_KL_5                  = 14'd616;
    localparam L4_OFFSET_K_11_KL_6                  = 14'd2184;
    localparam L4_OFFSET_K_11_KL_7                  = 14'd3752;
    localparam L4_OFFSET_K_11_KL_8                  = 14'd4312;
    localparam L4_OFFSET_K_12_KL_4                  = 14'd0;
    localparam L4_OFFSET_K_12_KL_5                  = 14'd70;
    localparam L4_OFFSET_K_12_KL_6                  = 14'd518;
    localparam L4_OFFSET_K_12_KL_7                  = 14'd1302;
    localparam L4_OFFSET_K_12_KL_8                  = 14'd1750;
    localparam L4_OFFSET_K_13_KL_5                  = 14'd0;
    localparam L4_OFFSET_K_13_KL_6                  = 14'd56;
    localparam L4_OFFSET_K_13_KL_7                  = 14'd280;
    localparam L4_OFFSET_K_13_KL_8                  = 14'd504;
    localparam L4_OFFSET_K_14_KL_6                  = 14'd0;
    localparam L4_OFFSET_K_14_KL_7                  = 14'd28;
    localparam L4_OFFSET_K_14_KL_8                  = 14'd92;
    localparam L4_OFFSET_K_15_KL_7                  = 14'd0;
    localparam L4_OFFSET_K_15_KL_8                  = 14'd8;
    localparam L4_OFFSET_K_16_KL_8                  = 14'd0;

    wire [13:0] off0, off1, off2, off3, off4, off5, off6, off7;

    assign off0 = k == 5'd1 ? L4_OFFSET_K_1_KL_1 :
                  k == 5'd2 ? L4_OFFSET_K_2_KL_1 :
                  k == 5'd3 ? L4_OFFSET_K_3_KL_1 :
                  k == 5'd4 ? L4_OFFSET_K_4_KL_1 :
                  k == 5'd5 ? L4_OFFSET_K_5_KL_1 :
                  k == 5'd6 ? L4_OFFSET_K_6_KL_1 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_1 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_1 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_2 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_3 :
                  k == 5'd11 ? L4_OFFSET_K_11_KL_4 :
                  k == 5'd12 ? L4_OFFSET_K_12_KL_5 :
                  k == 5'd13 ? L4_OFFSET_K_13_KL_6 :
                  k == 5'd14 ? L4_OFFSET_K_14_KL_7 :
                  k == 5'd15 ? L4_OFFSET_K_15_KL_8 :
                  14'h3FFF;

    assign off1 = k == 5'd2 ? L4_OFFSET_K_2_KL_2 :
                  k == 5'd3 ? L4_OFFSET_K_3_KL_2 :
                  k == 5'd4 ? L4_OFFSET_K_4_KL_2 :
                  k == 5'd5 ? L4_OFFSET_K_5_KL_2 :
                  k == 5'd6 ? L4_OFFSET_K_6_KL_2 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_2 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_2 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_3 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_4 :
                  k == 5'd11 ? L4_OFFSET_K_11_KL_5 :
                  k == 5'd12 ? L4_OFFSET_K_12_KL_6 :
                  k == 5'd13 ? L4_OFFSET_K_13_KL_7 :
                  k == 5'd14 ? L4_OFFSET_K_14_KL_8 :
                  14'h3FFF;

    assign off2 = k == 5'd3 ? L4_OFFSET_K_3_KL_3 :
                  k == 5'd4 ? L4_OFFSET_K_4_KL_3 :
                  k == 5'd5 ? L4_OFFSET_K_5_KL_3 :
                  k == 5'd6 ? L4_OFFSET_K_6_KL_3 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_3 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_3 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_4 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_5 :
                  k == 5'd11 ? L4_OFFSET_K_11_KL_6 :
                  k == 5'd12 ? L4_OFFSET_K_12_KL_7 :
                  k == 5'd13 ? L4_OFFSET_K_13_KL_8 :
                  14'h3FFF;

    assign off3 = k == 5'd4 ? L4_OFFSET_K_4_KL_4 :
                  k == 5'd5 ? L4_OFFSET_K_5_KL_4 :
                  k == 5'd6 ? L4_OFFSET_K_6_KL_4 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_4 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_4 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_5 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_6 :
                  k == 5'd11 ? L4_OFFSET_K_11_KL_7 :
                  k == 5'd12 ? L4_OFFSET_K_12_KL_8 :
                  14'h3FFF;

    assign off4 = k == 5'd5 ? L4_OFFSET_K_5_KL_5 :
                  k == 5'd6 ? L4_OFFSET_K_6_KL_5 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_5 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_5 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_6 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_7 :
                  k == 5'd11 ? L4_OFFSET_K_11_KL_8 :
                  14'h3FFF;

    assign off5 = k == 5'd6 ? L4_OFFSET_K_6_KL_6 :
                  k == 5'd7 ? L4_OFFSET_K_7_KL_6 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_6 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_7 :
                  k == 5'd10 ? L4_OFFSET_K_10_KL_8 :
                  14'h3FFF;

    assign off6 = k == 5'd7 ? L4_OFFSET_K_7_KL_7 :
                  k == 5'd8 ? L4_OFFSET_K_8_KL_7 :
                  k == 5'd9 ? L4_OFFSET_K_9_KL_8 :
                  14'h3FFF;

    assign off7 = k == 5'd8 ? L4_OFFSET_K_8_KL_8 :
                  14'h3FFF;

    wire [3:0] kl_base = k > 5'd8 ? k[3:0] - 4'd8 : 4'd0;

    wire c0 = (val < off0);
    wire c1 = (val < off1);
    wire c2 = (val < off2);
    wire c3 = (val < off3);
    wire c4 = (val < off4);
    wire c5 = (val < off5);
    wire c6 = (val < off6);
    wire c7 = (val < off7);

    wire [3:0] kl_idx = c0 ? 4'd0 :
                         c1 ? 4'd1 :
                         c2 ? 4'd2 :
                         c3 ? 4'd3 :
                         c4 ? 4'd4 :
                         c5 ? 4'd5 :
                         c6 ? 4'd6 :
                         c7 ? 4'd7 : 4'd8;

    assign kl = kl_idx + kl_base;
    assign kr = k - kl;

    wire [13:0] off_prev [0:8];
    assign off_prev[0] = 14'd0;
    assign off_prev[1] = off0;
    assign off_prev[2] = off1;
    assign off_prev[3] = off2;
    assign off_prev[4] = off3;
    assign off_prev[5] = off4;
    assign off_prev[6] = off5;
    assign off_prev[7] = off6;
    assign off_prev[8] = off7;

    wire [13:0] offset_prev = off_prev[kl_idx];
    wire [13:0] vali = val - offset_prev;

    wire [14:0] rec_weight_sel = kr == 4'd0 ? L4_REC_WEIGHT_KR_0 :
                        kr == 4'd1 ? {{3{1'b0}}, L4_REC_WEIGHT_KR_1} :
                        kr == 4'd2 ? {{5{1'b0}}, L4_REC_WEIGHT_KR_2} :
                        kr == 4'd3 ? {{6{1'b0}}, L4_REC_WEIGHT_KR_3} :
                        kr == 4'd4 ? {{7{1'b0}}, L4_REC_WEIGHT_KR_4} :
                        kr == 4'd5 ? {{6{1'b0}}, L4_REC_WEIGHT_KR_3} :
                        kr == 4'd6 ? {{5{1'b0}}, L4_REC_WEIGHT_KR_2} :
                        kr == 4'd7 ? {{3{1'b0}}, L4_REC_WEIGHT_KR_1} :
                        L4_REC_WEIGHT_KR_0;

    wire [28:0] full_product = vali * rec_weight_sel;

    wire [6:0] val_l_raw = full_product[20:14];

    wire [6:0] weight_sel = kr == 4'd0 ? L4_WEIGHT_KR_0 :
                        kr == 4'd1 ? L4_WEIGHT_KR_1 :
                        kr == 4'd2 ? L4_WEIGHT_KR_2 :
                        kr == 4'd3 ? L4_WEIGHT_KR_3 :
                        kr == 4'd4 ? L4_WEIGHT_KR_4 :
                        kr == 4'd5 ? L4_WEIGHT_KR_3 :
                        kr == 4'd6 ? L4_WEIGHT_KR_2 :
                        kr == 4'd7 ? L4_WEIGHT_KR_1 : L4_WEIGHT_KR_0;

    wire [13:0] val_l_times_w = val_l_raw * weight_sel;
    wire [13:0] val_r_raw = vali - val_l_times_w;

    wire overflow = (val_r_raw[6:0] >= weight_sel) & (val_r_raw[13:7] == 7'd0);

    assign val_l = overflow ? (val_l_raw + 7'd1) : val_l_raw;
    assign val_r = overflow ? (val_r_raw[6:0] - weight_sel) : val_r_raw[6:0];
endmodule