// SPDX-License-Identifier: Apache-2.0
module L4_CELL (
    input wire [7:0] high,
    input wire [7:0] low,
    input wire [3:0] num_one_high,
    input wire [3:0] num_one_low,
    output wire [15:0] out_data,
    output wire [4:0] out_num_one
);

    localparam L4_WEIGHT_KR_0                 = 1'd1;
    localparam L4_WEIGHT_KR_1                 = 4'd8;
    localparam L4_WEIGHT_KR_2                 = 5'd28;
    localparam L4_WEIGHT_KR_3                 = 6'd56;
    localparam L4_WEIGHT_KR_4                 = 7'd70;

    localparam L4_OFFSET_K_1_KL_1                  = 4'd8;
    localparam L4_OFFSET_K_2_KL_1                  = 5'd28;
    localparam L4_OFFSET_K_2_KL_2                  = 7'd92;
    localparam L4_OFFSET_K_3_KL_1                  = 6'd56;
    localparam L4_OFFSET_K_3_KL_2                  = 9'd280;
    localparam L4_OFFSET_K_3_KL_3                  = 9'd504;
    localparam L4_OFFSET_K_4_KL_1                  = 7'd70;
    localparam L4_OFFSET_K_4_KL_2                  = 10'd518;
    localparam L4_OFFSET_K_4_KL_3                  = 11'd1302;
    localparam L4_OFFSET_K_4_KL_4                  = 11'd1750;
    localparam L4_OFFSET_K_5_KL_1                  = 6'd56;
    localparam L4_OFFSET_K_5_KL_2                  = 10'd616;
    localparam L4_OFFSET_K_5_KL_3                  = 12'd2184;
    localparam L4_OFFSET_K_5_KL_4                  = 12'd3752;
    localparam L4_OFFSET_K_5_KL_5                  = 13'd4312;
    localparam L4_OFFSET_K_6_KL_1                  = 5'd28;
    localparam L4_OFFSET_K_6_KL_2                  = 9'd476;
    localparam L4_OFFSET_K_6_KL_3                  = 12'd2436;
    localparam L4_OFFSET_K_6_KL_4                  = 13'd5572;
    localparam L4_OFFSET_K_6_KL_5                  = 13'd7532;
    localparam L4_OFFSET_K_6_KL_6                  = 13'd7980;
    localparam L4_OFFSET_K_7_KL_1                  = 4'd8;
    localparam L4_OFFSET_K_7_KL_2                  = 8'd232;
    localparam L4_OFFSET_K_7_KL_3                  = 11'd1800;
    localparam L4_OFFSET_K_7_KL_4                  = 13'd5720;
    localparam L4_OFFSET_K_7_KL_5                  = 14'd9640;
    localparam L4_OFFSET_K_7_KL_6                  = 14'd11208;
    localparam L4_OFFSET_K_7_KL_7                  = 14'd11432;
    localparam L4_OFFSET_K_8_KL_1                  = 1'd1;
    localparam L4_OFFSET_K_8_KL_2                  = 7'd65;
    localparam L4_OFFSET_K_8_KL_3                  = 10'd849;
    localparam L4_OFFSET_K_8_KL_4                  = 12'd3985;
    localparam L4_OFFSET_K_8_KL_5                  = 14'd8885;
    localparam L4_OFFSET_K_8_KL_6                  = 14'd12021;
    localparam L4_OFFSET_K_8_KL_7                  = 14'd12805;
    localparam L4_OFFSET_K_8_KL_8                  = 14'd12869;
    localparam L4_OFFSET_K_9_KL_1                  = 1'd0;
    localparam L4_OFFSET_K_9_KL_2                  = 4'd8;
    localparam L4_OFFSET_K_9_KL_3                  = 8'd232;
    localparam L4_OFFSET_K_9_KL_4                  = 11'd1800;
    localparam L4_OFFSET_K_9_KL_5                  = 13'd5720;
    localparam L4_OFFSET_K_9_KL_6                  = 14'd9640;
    localparam L4_OFFSET_K_9_KL_7                  = 14'd11208;
    localparam L4_OFFSET_K_9_KL_8                  = 14'd11432;
    localparam L4_OFFSET_K_10_KL_2                 = 1'd0;
    localparam L4_OFFSET_K_10_KL_3                 = 5'd28;
    localparam L4_OFFSET_K_10_KL_4                 = 9'd476;
    localparam L4_OFFSET_K_10_KL_5                 = 12'd2436;
    localparam L4_OFFSET_K_10_KL_6                 = 13'd5572;
    localparam L4_OFFSET_K_10_KL_7                 = 13'd7532;
    localparam L4_OFFSET_K_10_KL_8                 = 13'd7980;
    localparam L4_OFFSET_K_11_KL_3                 = 1'd0;
    localparam L4_OFFSET_K_11_KL_4                 = 6'd56;
    localparam L4_OFFSET_K_11_KL_5                 = 10'd616;
    localparam L4_OFFSET_K_11_KL_6                 = 12'd2184;
    localparam L4_OFFSET_K_11_KL_7                 = 12'd3752;
    localparam L4_OFFSET_K_11_KL_8                 = 13'd4312;
    localparam L4_OFFSET_K_12_KL_4                 = 1'd0;
    localparam L4_OFFSET_K_12_KL_5                 = 7'd70;
    localparam L4_OFFSET_K_12_KL_6                 = 10'd518;
    localparam L4_OFFSET_K_12_KL_7                 = 11'd1302;
    localparam L4_OFFSET_K_12_KL_8                 = 11'd1750;
    localparam L4_OFFSET_K_13_KL_5                 = 1'd0;
    localparam L4_OFFSET_K_13_KL_6                 = 6'd56;
    localparam L4_OFFSET_K_13_KL_7                 = 9'd280;
    localparam L4_OFFSET_K_13_KL_8                 = 9'd504;
    localparam L4_OFFSET_K_14_KL_6                 = 1'd0;
    localparam L4_OFFSET_K_14_KL_7                 = 5'd28;
    localparam L4_OFFSET_K_14_KL_8                 = 7'd92;
    localparam L4_OFFSET_K_15_KL_7                 = 1'd0;
    localparam L4_OFFSET_K_15_KL_8                 = 4'd8;
    localparam L4_OFFSET_K_16_KL_8                 = 1'd0;

    wire [13:0] offset = out_num_one == 5'd0 ? 14'd0 :
                        out_num_one == 5'd1 ? (num_one_high == 4'd1 ? L4_OFFSET_K_1_KL_1 : 14'd0) :
                        out_num_one == 5'd2 ? (num_one_high == 4'd2 ? L4_OFFSET_K_2_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_2_KL_1 : 14'd0)) :
                        out_num_one == 5'd3 ? (num_one_high == 4'd3 ? L4_OFFSET_K_3_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_3_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_3_KL_1 : 14'd0))) :
                        out_num_one == 5'd4 ? (num_one_high == 4'd4 ? L4_OFFSET_K_4_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_4_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_4_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_4_KL_1 : 14'd0)))) :
                        out_num_one == 5'd5 ? (num_one_high == 4'd5 ? L4_OFFSET_K_5_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_5_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_5_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_5_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_5_KL_1 : 14'd0))))) :
                        out_num_one == 5'd6 ? (num_one_high == 4'd6 ? L4_OFFSET_K_6_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_6_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_6_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_6_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_6_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_6_KL_1 : 14'd0)))))) :
                        out_num_one == 5'd7 ? (num_one_high == 4'd7 ? L4_OFFSET_K_7_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_7_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_7_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_7_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_7_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_7_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_7_KL_1 : 14'd0))))))) :
                        out_num_one == 5'd8 ? (num_one_high == 4'd8 ? L4_OFFSET_K_8_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_8_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_8_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_8_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_8_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_8_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_8_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_8_KL_1 : 14'd0)))))))) :
                        out_num_one == 5'd9 ? (num_one_high == 4'd8 ? L4_OFFSET_K_9_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_9_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_9_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_9_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_9_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_9_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_9_KL_2 : (num_one_high == 4'd1 ? L4_OFFSET_K_9_KL_1 : 14'd0)))))))) :
                        out_num_one == 5'd10 ? (num_one_high == 4'd8 ? L4_OFFSET_K_10_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_10_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_10_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_10_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_10_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_10_KL_3 : (num_one_high == 4'd2 ? L4_OFFSET_K_10_KL_2 : 14'd0))))))) :
                        out_num_one == 5'd11 ? (num_one_high == 4'd8 ? L4_OFFSET_K_11_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_11_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_11_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_11_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_11_KL_4 : (num_one_high == 4'd3 ? L4_OFFSET_K_11_KL_3 : 14'd0)))))) :
                        out_num_one == 5'd12 ? (num_one_high == 4'd8 ? L4_OFFSET_K_12_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_12_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_12_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_12_KL_5 : (num_one_high == 4'd4 ? L4_OFFSET_K_12_KL_4 : 14'd0))))) :
                        out_num_one == 5'd13 ? (num_one_high == 4'd8 ? L4_OFFSET_K_13_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_13_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_13_KL_6 : (num_one_high == 4'd5 ? L4_OFFSET_K_13_KL_5 : 14'd0)))) :
                        out_num_one == 5'd14 ? (num_one_high == 4'd8 ? L4_OFFSET_K_14_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_14_KL_7 : (num_one_high == 4'd6 ? L4_OFFSET_K_14_KL_6 : 14'd0))) :
                        out_num_one == 5'd15 ? (num_one_high == 4'd8 ? L4_OFFSET_K_15_KL_8 : (num_one_high == 4'd7 ? L4_OFFSET_K_15_KL_7 : 14'd0)) :
                        out_num_one == 5'd16 ? (num_one_high == 4'd8 ? L4_OFFSET_K_16_KL_8 : 14'd0) :
                        14'd0;

    wire [6:0] weight = num_one_low == 4'd0 ? L4_WEIGHT_KR_0 :
                        num_one_low == 4'd1 ? L4_WEIGHT_KR_1 :
                        num_one_low == 4'd2 ? L4_WEIGHT_KR_2 :
                        num_one_low == 4'd3 ? L4_WEIGHT_KR_3 :
                        num_one_low == 4'd4 ? L4_WEIGHT_KR_4 :
                        num_one_low == 4'd5 ? L4_WEIGHT_KR_3 :
                        num_one_low == 4'd6 ? L4_WEIGHT_KR_2 :
                        num_one_low == 4'd7 ? L4_WEIGHT_KR_1 :
                        num_one_low == 4'd8 ? L4_WEIGHT_KR_0 :
                        7'd0;

    assign out_num_one = num_one_high + num_one_low;
    assign out_data = offset + high * weight + low;

endmodule