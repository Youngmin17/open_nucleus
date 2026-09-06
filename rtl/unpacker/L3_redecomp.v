// SPDX-License-Identifier: Apache-2.0
module L3_redecomp (
    input wire clk,
    input wire rst_n,
    input wire in_vld,
    input wire [29:0] val,
    input wire [5:0] k,
    output wire [13:0] val_l,
    output wire [13:0] val_r,
    output wire [4:0] kl,
    output wire [4:0] kr,
    output wire out_vld
);

    localparam L3_WEIGHT_KR_0                 = 1'd1;
    localparam L3_WEIGHT_KR_1                 = 5'd16;
    localparam L3_WEIGHT_KR_2                 = 7'd120;
    localparam L3_WEIGHT_KR_3                 = 10'd560;
    localparam L3_WEIGHT_KR_4                 = 11'd1820;
    localparam L3_WEIGHT_KR_5                 = 13'd4368;
    localparam L3_WEIGHT_KR_6                 = 13'd8008;
    localparam L3_WEIGHT_KR_7                 = 14'd11440;
    localparam L3_WEIGHT_KR_8                 = 14'd12870;

    localparam L3_REC_WEIGHT_KR_0        = 31'd1073741824;
    localparam L3_REC_WEIGHT_KR_1        = 27'd67108864;
    localparam L3_REC_WEIGHT_KR_2        = 24'd8947848;
    localparam L3_REC_WEIGHT_KR_3        = 21'd1917396;
    localparam L3_REC_WEIGHT_KR_4        = 20'd589968;
    localparam L3_REC_WEIGHT_KR_5        = 18'd245820;
    localparam L3_REC_WEIGHT_KR_6        = 18'd134083;
    localparam L3_REC_WEIGHT_KR_7        = 17'd93858;
    localparam L3_REC_WEIGHT_KR_8        = 17'd83429;

    localparam L3_OFFSET_K_1_KL_1                  = 30'd16;
    localparam L3_OFFSET_K_2_KL_1                  = 30'd120;
    localparam L3_OFFSET_K_2_KL_2                  = 30'd376;
    localparam L3_OFFSET_K_3_KL_1                  = 30'd560;
    localparam L3_OFFSET_K_3_KL_2                  = 30'd2480;
    localparam L3_OFFSET_K_3_KL_3                  = 30'd4400;
    localparam L3_OFFSET_K_4_KL_1                  = 30'd1820;
    localparam L3_OFFSET_K_4_KL_2                  = 30'd10780;
    localparam L3_OFFSET_K_4_KL_3                  = 30'd25180;
    localparam L3_OFFSET_K_4_KL_4                  = 30'd34140;
    localparam L3_OFFSET_K_5_KL_1                  = 30'd4368;
    localparam L3_OFFSET_K_5_KL_2                  = 30'd33488;
    localparam L3_OFFSET_K_5_KL_3                  = 30'd100688;
    localparam L3_OFFSET_K_5_KL_4                  = 30'd167888;
    localparam L3_OFFSET_K_5_KL_5                  = 30'd197008;
    localparam L3_OFFSET_K_6_KL_1                  = 30'd8008;
    localparam L3_OFFSET_K_6_KL_2                  = 30'd77896;
    localparam L3_OFFSET_K_6_KL_3                  = 30'd296296;
    localparam L3_OFFSET_K_6_KL_4                  = 30'd609896;
    localparam L3_OFFSET_K_6_KL_5                  = 30'd828296;
    localparam L3_OFFSET_K_6_KL_6                  = 30'd898184;
    localparam L3_OFFSET_K_7_KL_1                  = 30'd11440;
    localparam L3_OFFSET_K_7_KL_2                  = 30'd139568;
    localparam L3_OFFSET_K_7_KL_3                  = 30'd663728;
    localparam L3_OFFSET_K_7_KL_4                  = 30'd1682928;
    localparam L3_OFFSET_K_7_KL_5                  = 30'd2702128;
    localparam L3_OFFSET_K_7_KL_6                  = 30'd3226288;
    localparam L3_OFFSET_K_7_KL_7                  = 30'd3354416;
    localparam L3_OFFSET_K_8_KL_1                  = 30'd12870;
    localparam L3_OFFSET_K_8_KL_2                  = 30'd195910;
    localparam L3_OFFSET_K_8_KL_3                  = 30'd1156870;
    localparam L3_OFFSET_K_8_KL_4                  = 30'd3602950;
    localparam L3_OFFSET_K_8_KL_5                  = 30'd6915350;
    localparam L3_OFFSET_K_8_KL_6                  = 30'd9361430;
    localparam L3_OFFSET_K_8_KL_7                  = 30'd10322390;
    localparam L3_OFFSET_K_8_KL_8                  = 30'd10505430;
    localparam L3_OFFSET_K_9_KL_1                  = 30'd11440;
    localparam L3_OFFSET_K_9_KL_2                  = 30'd217360;
    localparam L3_OFFSET_K_9_KL_3                  = 30'd1590160;
    localparam L3_OFFSET_K_9_KL_4                  = 30'd6074640;
    localparam L3_OFFSET_K_9_KL_5                  = 30'd14024400;
    localparam L3_OFFSET_K_9_KL_6                  = 30'd21974160;
    localparam L3_OFFSET_K_9_KL_7                  = 30'd26458640;
    localparam L3_OFFSET_K_9_KL_8                  = 30'd27831440;
    localparam L3_OFFSET_K_9_KL_9                  = 30'd28037360;
    localparam L3_OFFSET_K_10_KL_1                 = 30'd8008;
    localparam L3_OFFSET_K_10_KL_2                 = 30'd191048;
    localparam L3_OFFSET_K_10_KL_3                 = 30'd1735448;
    localparam L3_OFFSET_K_10_KL_4                 = 30'd8141848;
    localparam L3_OFFSET_K_10_KL_5                 = 30'd22716408;
    localparam L3_OFFSET_K_10_KL_6                 = 30'd41795832;
    localparam L3_OFFSET_K_10_KL_7                 = 30'd56370392;
    localparam L3_OFFSET_K_10_KL_8                 = 30'd62776792;
    localparam L3_OFFSET_K_10_KL_9                 = 30'd64321192;
    localparam L3_OFFSET_K_10_KL_10                = 30'd64504232;
    localparam L3_OFFSET_K_11_KL_1                 = 30'd4368;
    localparam L3_OFFSET_K_11_KL_2                 = 30'd132496;
    localparam L3_OFFSET_K_11_KL_3                 = 30'd1505296;
    localparam L3_OFFSET_K_11_KL_4                 = 30'd8712496;
    localparam L3_OFFSET_K_11_KL_5                 = 30'd29533296;
    localparam L3_OFFSET_K_11_KL_6                 = 30'd64512240;
    localparam L3_OFFSET_K_11_KL_7                 = 30'd99491184;
    localparam L3_OFFSET_K_11_KL_8                 = 30'd120311984;
    localparam L3_OFFSET_K_11_KL_9                 = 30'd127519184;
    localparam L3_OFFSET_K_11_KL_10                = 30'd128891984;
    localparam L3_OFFSET_K_11_KL_11                = 30'd129020112;
    localparam L3_OFFSET_K_12_KL_1                 = 30'd1820;
    localparam L3_OFFSET_K_12_KL_2                 = 30'd71708;
    localparam L3_OFFSET_K_12_KL_3                 = 30'd1032668;
    localparam L3_OFFSET_K_12_KL_4                 = 30'd7439068;
    localparam L3_OFFSET_K_12_KL_5                 = 30'd30862468;
    localparam L3_OFFSET_K_12_KL_6                 = 30'd80832388;
    localparam L3_OFFSET_K_12_KL_7                 = 30'd144960452;
    localparam L3_OFFSET_K_12_KL_8                 = 30'd194930372;
    localparam L3_OFFSET_K_12_KL_9                 = 30'd218353772;
    localparam L3_OFFSET_K_12_KL_10                = 30'd224760172;
    localparam L3_OFFSET_K_12_KL_11                = 30'd225721132;
    localparam L3_OFFSET_K_12_KL_12                = 30'd225791020;
    localparam L3_OFFSET_K_13_KL_1                 = 30'd560;
    localparam L3_OFFSET_K_13_KL_2                 = 30'd29680;
    localparam L3_OFFSET_K_13_KL_3                 = 30'd553840;
    localparam L3_OFFSET_K_13_KL_4                 = 30'd5038320;
    localparam L3_OFFSET_K_13_KL_5                 = 30'd25859120;
    localparam L3_OFFSET_K_13_KL_6                 = 30'd82075280;
    localparam L3_OFFSET_K_13_KL_7                 = 30'd173686800;
    localparam L3_OFFSET_K_13_KL_8                 = 30'd265298320;
    localparam L3_OFFSET_K_13_KL_9                 = 30'd321514480;
    localparam L3_OFFSET_K_13_KL_10                = 30'd342335280;
    localparam L3_OFFSET_K_13_KL_11                = 30'd346819760;
    localparam L3_OFFSET_K_13_KL_12                = 30'd347343920;
    localparam L3_OFFSET_K_13_KL_13                = 30'd347373040;
    localparam L3_OFFSET_K_14_KL_1                 = 30'd120;
    localparam L3_OFFSET_K_14_KL_2                 = 30'd9080;
    localparam L3_OFFSET_K_14_KL_3                 = 30'd227480;
    localparam L3_OFFSET_K_14_KL_4                 = 30'd2673560;
    localparam L3_OFFSET_K_14_KL_5                 = 30'd17248120;
    localparam L3_OFFSET_K_14_KL_6                 = 30'd67218040;
    localparam L3_OFFSET_K_14_KL_7                 = 30'd170281000;
    localparam L3_OFFSET_K_14_KL_8                 = 30'd301154600;
    localparam L3_OFFSET_K_14_KL_9                 = 30'd404217560;
    localparam L3_OFFSET_K_14_KL_10                = 30'd454187480;
    localparam L3_OFFSET_K_14_KL_11                = 30'd468762040;
    localparam L3_OFFSET_K_14_KL_12                = 30'd471208120;
    localparam L3_OFFSET_K_14_KL_13                = 30'd471426520;
    localparam L3_OFFSET_K_14_KL_14                = 30'd471435480;
    localparam L3_OFFSET_K_15_KL_1                 = 30'd16;
    localparam L3_OFFSET_K_15_KL_2                 = 30'd1936;
    localparam L3_OFFSET_K_15_KL_3                 = 30'd69136;
    localparam L3_OFFSET_K_15_KL_4                 = 30'd1088336;
    localparam L3_OFFSET_K_15_KL_5                 = 30'd9038096;
    localparam L3_OFFSET_K_15_KL_6                 = 30'd44017040;
    localparam L3_OFFSET_K_15_KL_7                 = 30'd135628560;
    localparam L3_OFFSET_K_15_KL_8                 = 30'd282861360;
    localparam L3_OFFSET_K_15_KL_9                 = 30'd430094160;
    localparam L3_OFFSET_K_15_KL_10                = 30'd521705680;
    localparam L3_OFFSET_K_15_KL_11                = 30'd556684624;
    localparam L3_OFFSET_K_15_KL_12                = 30'd564634384;
    localparam L3_OFFSET_K_15_KL_13                = 30'd565653584;
    localparam L3_OFFSET_K_15_KL_14                = 30'd565720784;
    localparam L3_OFFSET_K_15_KL_15                = 30'd565722704;
    localparam L3_OFFSET_K_16_KL_1                 = 30'd1;
    localparam L3_OFFSET_K_16_KL_2                 = 30'd257;
    localparam L3_OFFSET_K_16_KL_3                 = 30'd14657;
    localparam L3_OFFSET_K_16_KL_4                 = 30'd328257;
    localparam L3_OFFSET_K_16_KL_5                 = 30'd3640657;
    localparam L3_OFFSET_K_16_KL_6                 = 30'd22720081;
    localparam L3_OFFSET_K_16_KL_7                 = 30'd86848145;
    localparam L3_OFFSET_K_16_KL_8                 = 30'd217721745;
    localparam L3_OFFSET_K_16_KL_9                 = 30'd383358645;
    localparam L3_OFFSET_K_16_KL_10                = 30'd514232245;
    localparam L3_OFFSET_K_16_KL_11                = 30'd578360309;
    localparam L3_OFFSET_K_16_KL_12                = 30'd597439733;
    localparam L3_OFFSET_K_16_KL_13                = 30'd600752133;
    localparam L3_OFFSET_K_16_KL_14                = 30'd601065733;
    localparam L3_OFFSET_K_16_KL_15                = 30'd601080133;
    localparam L3_OFFSET_K_16_KL_16                = 30'd601080389;
    localparam L3_OFFSET_K_17_KL_1                 = 30'd0;
    localparam L3_OFFSET_K_17_KL_2                 = 30'd16;
    localparam L3_OFFSET_K_17_KL_3                 = 30'd1936;
    localparam L3_OFFSET_K_17_KL_4                 = 30'd69136;
    localparam L3_OFFSET_K_17_KL_5                 = 30'd1088336;
    localparam L3_OFFSET_K_17_KL_6                 = 30'd9038096;
    localparam L3_OFFSET_K_17_KL_7                 = 30'd44017040;
    localparam L3_OFFSET_K_17_KL_8                 = 30'd135628560;
    localparam L3_OFFSET_K_17_KL_9                 = 30'd282861360;
    localparam L3_OFFSET_K_17_KL_10                = 30'd430094160;
    localparam L3_OFFSET_K_17_KL_11                = 30'd521705680;
    localparam L3_OFFSET_K_17_KL_12                = 30'd556684624;
    localparam L3_OFFSET_K_17_KL_13                = 30'd564634384;
    localparam L3_OFFSET_K_17_KL_14                = 30'd565653584;
    localparam L3_OFFSET_K_17_KL_15                = 30'd565720784;
    localparam L3_OFFSET_K_17_KL_16                = 30'd565722704;
    localparam L3_OFFSET_K_18_KL_2                 = 30'd0;
    localparam L3_OFFSET_K_18_KL_3                 = 30'd120;
    localparam L3_OFFSET_K_18_KL_4                 = 30'd9080;
    localparam L3_OFFSET_K_18_KL_5                 = 30'd227480;
    localparam L3_OFFSET_K_18_KL_6                 = 30'd2673560;
    localparam L3_OFFSET_K_18_KL_7                 = 30'd17248120;
    localparam L3_OFFSET_K_18_KL_8                 = 30'd67218040;
    localparam L3_OFFSET_K_18_KL_9                 = 30'd170281000;
    localparam L3_OFFSET_K_18_KL_10                = 30'd301154600;
    localparam L3_OFFSET_K_18_KL_11                = 30'd404217560;
    localparam L3_OFFSET_K_18_KL_12                = 30'd454187480;
    localparam L3_OFFSET_K_18_KL_13                = 30'd468762040;
    localparam L3_OFFSET_K_18_KL_14                = 30'd471208120;
    localparam L3_OFFSET_K_18_KL_15                = 30'd471426520;
    localparam L3_OFFSET_K_18_KL_16                = 30'd471435480;
    localparam L3_OFFSET_K_19_KL_3                 = 30'd0;
    localparam L3_OFFSET_K_19_KL_4                 = 30'd560;
    localparam L3_OFFSET_K_19_KL_5                 = 30'd29680;
    localparam L3_OFFSET_K_19_KL_6                 = 30'd553840;
    localparam L3_OFFSET_K_19_KL_7                 = 30'd5038320;
    localparam L3_OFFSET_K_19_KL_8                 = 30'd25859120;
    localparam L3_OFFSET_K_19_KL_9                 = 30'd82075280;
    localparam L3_OFFSET_K_19_KL_10                = 30'd173686800;
    localparam L3_OFFSET_K_19_KL_11                = 30'd265298320;
    localparam L3_OFFSET_K_19_KL_12                = 30'd321514480;
    localparam L3_OFFSET_K_19_KL_13                = 30'd342335280;
    localparam L3_OFFSET_K_19_KL_14                = 30'd346819760;
    localparam L3_OFFSET_K_19_KL_15                = 30'd347343920;
    localparam L3_OFFSET_K_19_KL_16                = 30'd347373040;
    localparam L3_OFFSET_K_20_KL_4                 = 30'd0;
    localparam L3_OFFSET_K_20_KL_5                 = 30'd1820;
    localparam L3_OFFSET_K_20_KL_6                 = 30'd71708;
    localparam L3_OFFSET_K_20_KL_7                 = 30'd1032668;
    localparam L3_OFFSET_K_20_KL_8                 = 30'd7439068;
    localparam L3_OFFSET_K_20_KL_9                 = 30'd30862468;
    localparam L3_OFFSET_K_20_KL_10                = 30'd80832388;
    localparam L3_OFFSET_K_20_KL_11                = 30'd144960452;
    localparam L3_OFFSET_K_20_KL_12                = 30'd194930372;
    localparam L3_OFFSET_K_20_KL_13                = 30'd218353772;
    localparam L3_OFFSET_K_20_KL_14                = 30'd224760172;
    localparam L3_OFFSET_K_20_KL_15                = 30'd225721132;
    localparam L3_OFFSET_K_20_KL_16                = 30'd225791020;
    localparam L3_OFFSET_K_21_KL_5                 = 30'd0;
    localparam L3_OFFSET_K_21_KL_6                 = 30'd4368;
    localparam L3_OFFSET_K_21_KL_7                 = 30'd132496;
    localparam L3_OFFSET_K_21_KL_8                 = 30'd1505296;
    localparam L3_OFFSET_K_21_KL_9                 = 30'd8712496;
    localparam L3_OFFSET_K_21_KL_10                = 30'd29533296;
    localparam L3_OFFSET_K_21_KL_11                = 30'd64512240;
    localparam L3_OFFSET_K_21_KL_12                = 30'd99491184;
    localparam L3_OFFSET_K_21_KL_13                = 30'd120311984;
    localparam L3_OFFSET_K_21_KL_14                = 30'd127519184;
    localparam L3_OFFSET_K_21_KL_15                = 30'd128891984;
    localparam L3_OFFSET_K_21_KL_16                = 30'd129020112;
    localparam L3_OFFSET_K_22_KL_6                 = 30'd0;
    localparam L3_OFFSET_K_22_KL_7                 = 30'd8008;
    localparam L3_OFFSET_K_22_KL_8                 = 30'd191048;
    localparam L3_OFFSET_K_22_KL_9                 = 30'd1735448;
    localparam L3_OFFSET_K_22_KL_10                = 30'd8141848;
    localparam L3_OFFSET_K_22_KL_11                = 30'd22716408;
    localparam L3_OFFSET_K_22_KL_12                = 30'd41795832;
    localparam L3_OFFSET_K_22_KL_13                = 30'd56370392;
    localparam L3_OFFSET_K_22_KL_14                = 30'd62776792;
    localparam L3_OFFSET_K_22_KL_15                = 30'd64321192;
    localparam L3_OFFSET_K_22_KL_16                = 30'd64504232;
    localparam L3_OFFSET_K_23_KL_7                 = 30'd0;
    localparam L3_OFFSET_K_23_KL_8                 = 30'd11440;
    localparam L3_OFFSET_K_23_KL_9                 = 30'd217360;
    localparam L3_OFFSET_K_23_KL_10                = 30'd1590160;
    localparam L3_OFFSET_K_23_KL_11                = 30'd6074640;
    localparam L3_OFFSET_K_23_KL_12                = 30'd14024400;
    localparam L3_OFFSET_K_23_KL_13                = 30'd21974160;
    localparam L3_OFFSET_K_23_KL_14                = 30'd26458640;
    localparam L3_OFFSET_K_23_KL_15                = 30'd27831440;
    localparam L3_OFFSET_K_23_KL_16                = 30'd28037360;
    localparam L3_OFFSET_K_24_KL_8                 = 30'd0;
    localparam L3_OFFSET_K_24_KL_9                 = 30'd12870;
    localparam L3_OFFSET_K_24_KL_10                = 30'd195910;
    localparam L3_OFFSET_K_24_KL_11                = 30'd1156870;
    localparam L3_OFFSET_K_24_KL_12                = 30'd3602950;
    localparam L3_OFFSET_K_24_KL_13                = 30'd6915350;
    localparam L3_OFFSET_K_24_KL_14                = 30'd9361430;
    localparam L3_OFFSET_K_24_KL_15                = 30'd10322390;
    localparam L3_OFFSET_K_24_KL_16                = 30'd10505430;
    localparam L3_OFFSET_K_25_KL_9                 = 30'd0;
    localparam L3_OFFSET_K_25_KL_10                = 30'd11440;
    localparam L3_OFFSET_K_25_KL_11                = 30'd139568;
    localparam L3_OFFSET_K_25_KL_12                = 30'd663728;
    localparam L3_OFFSET_K_25_KL_13                = 30'd1682928;
    localparam L3_OFFSET_K_25_KL_14                = 30'd2702128;
    localparam L3_OFFSET_K_25_KL_15                = 30'd3226288;
    localparam L3_OFFSET_K_25_KL_16                = 30'd3354416;
    localparam L3_OFFSET_K_26_KL_10                = 30'd0;
    localparam L3_OFFSET_K_26_KL_11                = 30'd8008;
    localparam L3_OFFSET_K_26_KL_12                = 30'd77896;
    localparam L3_OFFSET_K_26_KL_13                = 30'd296296;
    localparam L3_OFFSET_K_26_KL_14                = 30'd609896;
    localparam L3_OFFSET_K_26_KL_15                = 30'd828296;
    localparam L3_OFFSET_K_26_KL_16                = 30'd898184;
    localparam L3_OFFSET_K_27_KL_11                = 30'd0;
    localparam L3_OFFSET_K_27_KL_12                = 30'd4368;
    localparam L3_OFFSET_K_27_KL_13                = 30'd33488;
    localparam L3_OFFSET_K_27_KL_14                = 30'd100688;
    localparam L3_OFFSET_K_27_KL_15                = 30'd167888;
    localparam L3_OFFSET_K_27_KL_16                = 30'd197008;
    localparam L3_OFFSET_K_28_KL_12                = 30'd0;
    localparam L3_OFFSET_K_28_KL_13                = 30'd1820;
    localparam L3_OFFSET_K_28_KL_14                = 30'd10780;
    localparam L3_OFFSET_K_28_KL_15                = 30'd25180;
    localparam L3_OFFSET_K_28_KL_16                = 30'd34140;
    localparam L3_OFFSET_K_29_KL_13                = 30'd0;
    localparam L3_OFFSET_K_29_KL_14                = 30'd560;
    localparam L3_OFFSET_K_29_KL_15                = 30'd2480;
    localparam L3_OFFSET_K_29_KL_16                = 30'd4400;
    localparam L3_OFFSET_K_30_KL_14                = 30'd0;
    localparam L3_OFFSET_K_30_KL_15                = 30'd120;
    localparam L3_OFFSET_K_30_KL_16                = 30'd376;
    localparam L3_OFFSET_K_31_KL_15                = 30'd0;
    localparam L3_OFFSET_K_31_KL_16                = 30'd16;
    localparam L3_OFFSET_K_32_KL_16                = 30'd0;

    wire [30*16-1:0] offset_flat =
        k == 6'd0 ? {30*16{1'b1}} :
        k == 6'd1 ? {{30*15{1'b1}}, L3_OFFSET_K_1_KL_1} :
        k == 6'd2 ? {{30*14{1'b1}}, L3_OFFSET_K_2_KL_2, L3_OFFSET_K_2_KL_1} :
        k == 6'd3 ? {{30*13{1'b1}}, L3_OFFSET_K_3_KL_3, L3_OFFSET_K_3_KL_2, L3_OFFSET_K_3_KL_1} :
        k == 6'd4 ? {{30*12{1'b1}}, L3_OFFSET_K_4_KL_4, L3_OFFSET_K_4_KL_3, L3_OFFSET_K_4_KL_2, L3_OFFSET_K_4_KL_1} :
        k == 6'd5 ? {{30*11{1'b1}}, L3_OFFSET_K_5_KL_5, L3_OFFSET_K_5_KL_4, L3_OFFSET_K_5_KL_3, L3_OFFSET_K_5_KL_2, L3_OFFSET_K_5_KL_1} :
        k == 6'd6 ? {{30*10{1'b1}}, L3_OFFSET_K_6_KL_6, L3_OFFSET_K_6_KL_5, L3_OFFSET_K_6_KL_4, L3_OFFSET_K_6_KL_3, L3_OFFSET_K_6_KL_2, L3_OFFSET_K_6_KL_1} :
        k == 6'd7 ? {{30*9{1'b1}}, L3_OFFSET_K_7_KL_7, L3_OFFSET_K_7_KL_6, L3_OFFSET_K_7_KL_5, L3_OFFSET_K_7_KL_4, L3_OFFSET_K_7_KL_3, L3_OFFSET_K_7_KL_2, L3_OFFSET_K_7_KL_1} :
        k == 6'd8 ? {{30*8{1'b1}}, L3_OFFSET_K_8_KL_8, L3_OFFSET_K_8_KL_7, L3_OFFSET_K_8_KL_6, L3_OFFSET_K_8_KL_5, L3_OFFSET_K_8_KL_4, L3_OFFSET_K_8_KL_3, L3_OFFSET_K_8_KL_2, L3_OFFSET_K_8_KL_1} :
        k == 6'd9 ? {{30*7{1'b1}}, L3_OFFSET_K_9_KL_9, L3_OFFSET_K_9_KL_8, L3_OFFSET_K_9_KL_7, L3_OFFSET_K_9_KL_6, L3_OFFSET_K_9_KL_5, L3_OFFSET_K_9_KL_4, L3_OFFSET_K_9_KL_3, L3_OFFSET_K_9_KL_2, L3_OFFSET_K_9_KL_1} :
        k == 6'd10 ? {{30*6{1'b1}}, L3_OFFSET_K_10_KL_10, L3_OFFSET_K_10_KL_9, L3_OFFSET_K_10_KL_8, L3_OFFSET_K_10_KL_7, L3_OFFSET_K_10_KL_6, L3_OFFSET_K_10_KL_5, L3_OFFSET_K_10_KL_4, L3_OFFSET_K_10_KL_3, L3_OFFSET_K_10_KL_2, L3_OFFSET_K_10_KL_1} :
        k == 6'd11 ? {{30*5{1'b1}}, L3_OFFSET_K_11_KL_11, L3_OFFSET_K_11_KL_10, L3_OFFSET_K_11_KL_9, L3_OFFSET_K_11_KL_8, L3_OFFSET_K_11_KL_7, L3_OFFSET_K_11_KL_6, L3_OFFSET_K_11_KL_5, L3_OFFSET_K_11_KL_4, L3_OFFSET_K_11_KL_3, L3_OFFSET_K_11_KL_2, L3_OFFSET_K_11_KL_1} :
        k == 6'd12 ? {{30*4{1'b1}}, L3_OFFSET_K_12_KL_12, L3_OFFSET_K_12_KL_11, L3_OFFSET_K_12_KL_10, L3_OFFSET_K_12_KL_9, L3_OFFSET_K_12_KL_8, L3_OFFSET_K_12_KL_7, L3_OFFSET_K_12_KL_6, L3_OFFSET_K_12_KL_5, L3_OFFSET_K_12_KL_4, L3_OFFSET_K_12_KL_3, L3_OFFSET_K_12_KL_2, L3_OFFSET_K_12_KL_1} :
        k == 6'd13 ? {{30*3{1'b1}}, L3_OFFSET_K_13_KL_13, L3_OFFSET_K_13_KL_12, L3_OFFSET_K_13_KL_11, L3_OFFSET_K_13_KL_10, L3_OFFSET_K_13_KL_9, L3_OFFSET_K_13_KL_8, L3_OFFSET_K_13_KL_7, L3_OFFSET_K_13_KL_6, L3_OFFSET_K_13_KL_5, L3_OFFSET_K_13_KL_4, L3_OFFSET_K_13_KL_3, L3_OFFSET_K_13_KL_2, L3_OFFSET_K_13_KL_1} :
        k == 6'd14 ? {{30*2{1'b1}}, L3_OFFSET_K_14_KL_14, L3_OFFSET_K_14_KL_13, L3_OFFSET_K_14_KL_12, L3_OFFSET_K_14_KL_11, L3_OFFSET_K_14_KL_10, L3_OFFSET_K_14_KL_9, L3_OFFSET_K_14_KL_8, L3_OFFSET_K_14_KL_7, L3_OFFSET_K_14_KL_6, L3_OFFSET_K_14_KL_5, L3_OFFSET_K_14_KL_4, L3_OFFSET_K_14_KL_3, L3_OFFSET_K_14_KL_2, L3_OFFSET_K_14_KL_1} :
        k == 6'd15 ? {{30*1{1'b1}}, L3_OFFSET_K_15_KL_15, L3_OFFSET_K_15_KL_14, L3_OFFSET_K_15_KL_13, L3_OFFSET_K_15_KL_12, L3_OFFSET_K_15_KL_11, L3_OFFSET_K_15_KL_10, L3_OFFSET_K_15_KL_9, L3_OFFSET_K_15_KL_8, L3_OFFSET_K_15_KL_7, L3_OFFSET_K_15_KL_6, L3_OFFSET_K_15_KL_5, L3_OFFSET_K_15_KL_4, L3_OFFSET_K_15_KL_3, L3_OFFSET_K_15_KL_2, L3_OFFSET_K_15_KL_1} :
        k == 6'd16 ? {{30*0{1'b1}}, L3_OFFSET_K_16_KL_16, L3_OFFSET_K_16_KL_15, L3_OFFSET_K_16_KL_14, L3_OFFSET_K_16_KL_13, L3_OFFSET_K_16_KL_12, L3_OFFSET_K_16_KL_11, L3_OFFSET_K_16_KL_10, L3_OFFSET_K_16_KL_9, L3_OFFSET_K_16_KL_8, L3_OFFSET_K_16_KL_7, L3_OFFSET_K_16_KL_6, L3_OFFSET_K_16_KL_5, L3_OFFSET_K_16_KL_4, L3_OFFSET_K_16_KL_3, L3_OFFSET_K_16_KL_2, L3_OFFSET_K_16_KL_1} :
        k == 6'd17 ? {{30*1{1'b1}}, L3_OFFSET_K_17_KL_16, L3_OFFSET_K_17_KL_15, L3_OFFSET_K_17_KL_14, L3_OFFSET_K_17_KL_13, L3_OFFSET_K_17_KL_12, L3_OFFSET_K_17_KL_11, L3_OFFSET_K_17_KL_10, L3_OFFSET_K_17_KL_9, L3_OFFSET_K_17_KL_8, L3_OFFSET_K_17_KL_7, L3_OFFSET_K_17_KL_6, L3_OFFSET_K_17_KL_5, L3_OFFSET_K_17_KL_4, L3_OFFSET_K_17_KL_3, L3_OFFSET_K_17_KL_2} :
        k == 6'd18 ? {{30*2{1'b1}}, L3_OFFSET_K_18_KL_16, L3_OFFSET_K_18_KL_15, L3_OFFSET_K_18_KL_14, L3_OFFSET_K_18_KL_13, L3_OFFSET_K_18_KL_12, L3_OFFSET_K_18_KL_11, L3_OFFSET_K_18_KL_10, L3_OFFSET_K_18_KL_9, L3_OFFSET_K_18_KL_8, L3_OFFSET_K_18_KL_7, L3_OFFSET_K_18_KL_6, L3_OFFSET_K_18_KL_5, L3_OFFSET_K_18_KL_4, L3_OFFSET_K_18_KL_3} :
        k == 6'd19 ? {{30*3{1'b1}}, L3_OFFSET_K_19_KL_16, L3_OFFSET_K_19_KL_15, L3_OFFSET_K_19_KL_14, L3_OFFSET_K_19_KL_13, L3_OFFSET_K_19_KL_12, L3_OFFSET_K_19_KL_11, L3_OFFSET_K_19_KL_10, L3_OFFSET_K_19_KL_9, L3_OFFSET_K_19_KL_8, L3_OFFSET_K_19_KL_7, L3_OFFSET_K_19_KL_6, L3_OFFSET_K_19_KL_5, L3_OFFSET_K_19_KL_4} :
        k == 6'd20 ? {{30*4{1'b1}}, L3_OFFSET_K_20_KL_16, L3_OFFSET_K_20_KL_15, L3_OFFSET_K_20_KL_14, L3_OFFSET_K_20_KL_13, L3_OFFSET_K_20_KL_12, L3_OFFSET_K_20_KL_11, L3_OFFSET_K_20_KL_10, L3_OFFSET_K_20_KL_9, L3_OFFSET_K_20_KL_8, L3_OFFSET_K_20_KL_7, L3_OFFSET_K_20_KL_6, L3_OFFSET_K_20_KL_5} :
        k == 6'd21 ? {{30*5{1'b1}}, L3_OFFSET_K_21_KL_16, L3_OFFSET_K_21_KL_15, L3_OFFSET_K_21_KL_14, L3_OFFSET_K_21_KL_13, L3_OFFSET_K_21_KL_12, L3_OFFSET_K_21_KL_11, L3_OFFSET_K_21_KL_10, L3_OFFSET_K_21_KL_9, L3_OFFSET_K_21_KL_8, L3_OFFSET_K_21_KL_7, L3_OFFSET_K_21_KL_6} :
        k == 6'd22 ? {{30*6{1'b1}}, L3_OFFSET_K_22_KL_16, L3_OFFSET_K_22_KL_15, L3_OFFSET_K_22_KL_14, L3_OFFSET_K_22_KL_13, L3_OFFSET_K_22_KL_12, L3_OFFSET_K_22_KL_11, L3_OFFSET_K_22_KL_10, L3_OFFSET_K_22_KL_9, L3_OFFSET_K_22_KL_8, L3_OFFSET_K_22_KL_7} :
        k == 6'd23 ? {{30*7{1'b1}}, L3_OFFSET_K_23_KL_16, L3_OFFSET_K_23_KL_15, L3_OFFSET_K_23_KL_14, L3_OFFSET_K_23_KL_13, L3_OFFSET_K_23_KL_12, L3_OFFSET_K_23_KL_11, L3_OFFSET_K_23_KL_10, L3_OFFSET_K_23_KL_9, L3_OFFSET_K_23_KL_8} :
        k == 6'd24 ? {{30*8{1'b1}}, L3_OFFSET_K_24_KL_16, L3_OFFSET_K_24_KL_15, L3_OFFSET_K_24_KL_14, L3_OFFSET_K_24_KL_13, L3_OFFSET_K_24_KL_12, L3_OFFSET_K_24_KL_11, L3_OFFSET_K_24_KL_10, L3_OFFSET_K_24_KL_9} :
        k == 6'd25 ? {{30*9{1'b1}}, L3_OFFSET_K_25_KL_16, L3_OFFSET_K_25_KL_15, L3_OFFSET_K_25_KL_14, L3_OFFSET_K_25_KL_13, L3_OFFSET_K_25_KL_12, L3_OFFSET_K_25_KL_11, L3_OFFSET_K_25_KL_10} :
        k == 6'd26 ? {{30*10{1'b1}}, L3_OFFSET_K_26_KL_16, L3_OFFSET_K_26_KL_15, L3_OFFSET_K_26_KL_14, L3_OFFSET_K_26_KL_13, L3_OFFSET_K_26_KL_12, L3_OFFSET_K_26_KL_11} :
        k == 6'd27 ? {{30*11{1'b1}}, L3_OFFSET_K_27_KL_16, L3_OFFSET_K_27_KL_15, L3_OFFSET_K_27_KL_14, L3_OFFSET_K_27_KL_13, L3_OFFSET_K_27_KL_12} :
        k == 6'd28 ? {{30*12{1'b1}}, L3_OFFSET_K_28_KL_16, L3_OFFSET_K_28_KL_15, L3_OFFSET_K_28_KL_14, L3_OFFSET_K_28_KL_13} :
        k == 6'd29 ? {{30*13{1'b1}}, L3_OFFSET_K_29_KL_16, L3_OFFSET_K_29_KL_15, L3_OFFSET_K_29_KL_14} :
        k == 6'd30 ? {{30*14{1'b1}}, L3_OFFSET_K_30_KL_16, L3_OFFSET_K_30_KL_15} :
        k == 6'd31 ? {{30*15{1'b1}}, L3_OFFSET_K_31_KL_16} :
        k == 6'd32 ? {30*16{1'b1}} :
        {30*16{1'b1}};

    wire [29:0] offset_arr [0:16];
    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_offset_arr
            assign offset_arr[gi] = offset_flat[30*gi +: 30];
        end
    endgenerate
    assign offset_arr[16] = {30{1'b1}};

    wire [4:0] kl_base = k > 6'd16 ? k[4:0] - 5'd16 : 5'd0;

    wire [4:0] lo_0 = 5'd0;
    wire [4:0] hi_0 = 5'd16;
    wire [4:0] mid_0 = 5'd8;
    wire cmp_s0 = (val < offset_arr[mid_0]);
    wire [4:0] lo_1 = cmp_s0 ? lo_0 : (mid_0 + 5'd1);
    wire [4:0] hi_1 = cmp_s0 ? mid_0 : hi_0;

    wire [4:0] mid_1 = (lo_1 + hi_1) >> 1;
    wire cmp_s1 = (val < offset_arr[mid_1]);
    wire [4:0] lo_2 = cmp_s1 ? lo_1 : (mid_1 + 5'd1);
    wire [4:0] hi_2 = cmp_s1 ? mid_1 : hi_1;

    wire [4:0] mid_2 = (lo_2 + hi_2) >> 1;
    wire cmp_s2 = (val < offset_arr[mid_2]);
    wire [4:0] lo_3 = cmp_s2 ? lo_2 : (mid_2 + 5'd1);
    wire [4:0] hi_3 = cmp_s2 ? mid_2 : hi_2;

    wire [4:0] mid_3 = (lo_3 + hi_3) >> 1;
    wire cmp_s3 = (val < offset_arr[mid_3]);
    wire [4:0] lo_4 = cmp_s3 ? lo_3 : (mid_3 + 5'd1);
    wire [4:0] hi_4 = cmp_s3 ? mid_3 : hi_3;

    wire [4:0] mid_4 = (lo_4 + hi_4) >> 1;
    wire cmp_s4 = (val < offset_arr[mid_4]);
    wire [4:0] kl_idx = cmp_s4 ? mid_4 : (mid_4 + 5'd1);

    wire [4:0] kl_comb = kl_idx + kl_base;
    wire [4:0] kr_comb = k - kl_comb;

    wire [29:0] offset_prev = (kl_idx > 5'd0) ? offset_arr[kl_idx - 5'd1] : 30'd0;
    wire [29:0] vali_comb = val - offset_prev;

    reg [4:0] kl_r, kr_r;
    reg [29:0] vali_r;
    reg out_vld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kl_r <= 5'd0;
            kr_r <= 5'd0;
            vali_r <= 30'd0;
            out_vld_r <= 1'b0;
        end else begin
            out_vld_r <= in_vld;
            if (in_vld) begin
                kl_r <= kl_comb;
                kr_r <= kr_comb;
                vali_r <= vali_comb;
            end
        end
    end

    assign kl = kl_r;
    assign kr = kr_r;
    assign out_vld = out_vld_r;

    wire [29:0] vali = vali_r;

    wire [30:0] rec_weight_sel = kr_r == 5'd0 ? L3_REC_WEIGHT_KR_0 :
                        kr_r == 5'd1 ? {{4{1'b0}}, L3_REC_WEIGHT_KR_1} :
                        kr_r == 5'd2 ? {{7{1'b0}}, L3_REC_WEIGHT_KR_2} :
                        kr_r == 5'd3 ? {{10{1'b0}}, L3_REC_WEIGHT_KR_3} :
                        kr_r == 5'd4 ? {{11{1'b0}}, L3_REC_WEIGHT_KR_4} :
                        kr_r == 5'd5 ? {{13{1'b0}}, L3_REC_WEIGHT_KR_5} :
                        kr_r == 5'd6 ? {{13{1'b0}}, L3_REC_WEIGHT_KR_6} :
                        kr_r == 5'd7 ? {{14{1'b0}}, L3_REC_WEIGHT_KR_7} :
                        kr_r == 5'd8 ? {{14{1'b0}}, L3_REC_WEIGHT_KR_8} :
                        kr_r == 5'd9 ? {{14{1'b0}}, L3_REC_WEIGHT_KR_7} :
                        kr_r == 5'd10 ? {{13{1'b0}}, L3_REC_WEIGHT_KR_6} :
                        kr_r == 5'd11 ? {{13{1'b0}}, L3_REC_WEIGHT_KR_5} :
                        kr_r == 5'd12 ? {{11{1'b0}}, L3_REC_WEIGHT_KR_4} :
                        kr_r == 5'd13 ? {{10{1'b0}}, L3_REC_WEIGHT_KR_3} :
                        kr_r == 5'd14 ? {{7{1'b0}}, L3_REC_WEIGHT_KR_2} :
                        kr_r == 5'd15 ? {{4{1'b0}}, L3_REC_WEIGHT_KR_1} :
                        L3_REC_WEIGHT_KR_0;

    wire [14:0] vali_hi = vali[29:15];
    wire [15:0] rec_hi  = rec_weight_sel[30:15];
    wire [14:0] rec_lo  = rec_weight_sel[14:0];

    wire [45:0] prod_a = vali * rec_hi;
    wire [29:0] prod_b = vali_hi * rec_lo;

    wire [34:0] contrib_a = prod_a[45:11];
    wire [18:0] contrib_b = prod_b[29:11];
    wire [34:0] sum_guard = contrib_a + {16'd0, contrib_b};
    wire [13:0] val_l_raw = sum_guard[17:4];

    wire [13:0] weight_sel = kr_r == 5'd0 ? L3_WEIGHT_KR_0 :
                        kr_r == 5'd1 ? L3_WEIGHT_KR_1 :
                        kr_r == 5'd2 ? L3_WEIGHT_KR_2 :
                        kr_r == 5'd3 ? L3_WEIGHT_KR_3 :
                        kr_r == 5'd4 ? L3_WEIGHT_KR_4 :
                        kr_r == 5'd5 ? L3_WEIGHT_KR_5 :
                        kr_r == 5'd6 ? L3_WEIGHT_KR_6 :
                        kr_r == 5'd7 ? L3_WEIGHT_KR_7 :
                        kr_r == 5'd8 ? L3_WEIGHT_KR_8 :
                        kr_r == 5'd9 ? L3_WEIGHT_KR_7 :
                        kr_r == 5'd10 ? L3_WEIGHT_KR_6 :
                        kr_r == 5'd11 ? L3_WEIGHT_KR_5 :
                        kr_r == 5'd12 ? L3_WEIGHT_KR_4 :
                        kr_r == 5'd13 ? L3_WEIGHT_KR_3 :
                        kr_r == 5'd14 ? L3_WEIGHT_KR_2 :
                        kr_r == 5'd15 ? L3_WEIGHT_KR_1 :
                        L3_WEIGHT_KR_0;

    wire [27:0] val_l_times_w = val_l_raw * weight_sel;
    wire [29:0] val_r_raw = vali - {2'b0, val_l_times_w};

    wire overflow = (val_r_raw[14:0] >= {1'b0, weight_sel}) & (val_r_raw[29:15] == 15'd0);

    assign val_l = overflow ? (val_l_raw + 14'd1) : val_l_raw;
    assign val_r = overflow ? (val_r_raw[13:0] - weight_sel) : val_r_raw[13:0];
endmodule