// SPDX-License-Identifier: Apache-2.0
module L5_CELL (
    input wire [15:0] high,
    input wire [15:0] low,
    input wire [4:0] num_one_high,
    input wire [4:0] num_one_low,
    output wire [31:0] out_data,
    output wire [5:0] out_num_one
);

    localparam L5_WEIGHT_KR_0                 = 1'd1;
    localparam L5_WEIGHT_KR_1                 = 5'd16;
    localparam L5_WEIGHT_KR_2                 = 7'd120;
    localparam L5_WEIGHT_KR_3                 = 10'd560;
    localparam L5_WEIGHT_KR_4                 = 11'd1820;
    localparam L5_WEIGHT_KR_5                 = 13'd4368;
    localparam L5_WEIGHT_KR_6                 = 13'd8008;
    localparam L5_WEIGHT_KR_7                 = 14'd11440;
    localparam L5_WEIGHT_KR_8                 = 14'd12870;

    localparam L5_OFFSET_K_1_KL_1                  = 5'd16;
    localparam L5_OFFSET_K_2_KL_1                  = 7'd120;
    localparam L5_OFFSET_K_2_KL_2                  = 9'd376;
    localparam L5_OFFSET_K_3_KL_1                  = 10'd560;
    localparam L5_OFFSET_K_3_KL_2                  = 12'd2480;
    localparam L5_OFFSET_K_3_KL_3                  = 13'd4400;
    localparam L5_OFFSET_K_4_KL_1                  = 11'd1820;
    localparam L5_OFFSET_K_4_KL_2                  = 14'd10780;
    localparam L5_OFFSET_K_4_KL_3                  = 15'd25180;
    localparam L5_OFFSET_K_4_KL_4                  = 16'd34140;
    localparam L5_OFFSET_K_5_KL_1                  = 13'd4368;
    localparam L5_OFFSET_K_5_KL_2                  = 16'd33488;
    localparam L5_OFFSET_K_5_KL_3                  = 17'd100688;
    localparam L5_OFFSET_K_5_KL_4                  = 18'd167888;
    localparam L5_OFFSET_K_5_KL_5                  = 18'd197008;
    localparam L5_OFFSET_K_6_KL_1                  = 13'd8008;
    localparam L5_OFFSET_K_6_KL_2                  = 17'd77896;
    localparam L5_OFFSET_K_6_KL_3                  = 19'd296296;
    localparam L5_OFFSET_K_6_KL_4                  = 20'd609896;
    localparam L5_OFFSET_K_6_KL_5                  = 20'd828296;
    localparam L5_OFFSET_K_6_KL_6                  = 20'd898184;
    localparam L5_OFFSET_K_7_KL_1                  = 14'd11440;
    localparam L5_OFFSET_K_7_KL_2                  = 18'd139568;
    localparam L5_OFFSET_K_7_KL_3                  = 20'd663728;
    localparam L5_OFFSET_K_7_KL_4                  = 21'd1682928;
    localparam L5_OFFSET_K_7_KL_5                  = 22'd2702128;
    localparam L5_OFFSET_K_7_KL_6                  = 22'd3226288;
    localparam L5_OFFSET_K_7_KL_7                  = 22'd3354416;
    localparam L5_OFFSET_K_8_KL_1                  = 14'd12870;
    localparam L5_OFFSET_K_8_KL_2                  = 18'd195910;
    localparam L5_OFFSET_K_8_KL_3                  = 21'd1156870;
    localparam L5_OFFSET_K_8_KL_4                  = 22'd3602950;
    localparam L5_OFFSET_K_8_KL_5                  = 23'd6915350;
    localparam L5_OFFSET_K_8_KL_6                  = 24'd9361430;
    localparam L5_OFFSET_K_8_KL_7                  = 24'd10322390;
    localparam L5_OFFSET_K_8_KL_8                  = 24'd10505430;
    localparam L5_OFFSET_K_9_KL_1                  = 14'd11440;
    localparam L5_OFFSET_K_9_KL_2                  = 18'd217360;
    localparam L5_OFFSET_K_9_KL_3                  = 21'd1590160;
    localparam L5_OFFSET_K_9_KL_4                  = 23'd6074640;
    localparam L5_OFFSET_K_9_KL_5                  = 24'd14024400;
    localparam L5_OFFSET_K_9_KL_6                  = 25'd21974160;
    localparam L5_OFFSET_K_9_KL_7                  = 25'd26458640;
    localparam L5_OFFSET_K_9_KL_8                  = 25'd27831440;
    localparam L5_OFFSET_K_9_KL_9                  = 25'd28037360;
    localparam L5_OFFSET_K_10_KL_1                 = 13'd8008;
    localparam L5_OFFSET_K_10_KL_2                 = 18'd191048;
    localparam L5_OFFSET_K_10_KL_3                 = 21'd1735448;
    localparam L5_OFFSET_K_10_KL_4                 = 23'd8141848;
    localparam L5_OFFSET_K_10_KL_5                 = 25'd22716408;
    localparam L5_OFFSET_K_10_KL_6                 = 26'd41795832;
    localparam L5_OFFSET_K_10_KL_7                 = 26'd56370392;
    localparam L5_OFFSET_K_10_KL_8                 = 26'd62776792;
    localparam L5_OFFSET_K_10_KL_9                 = 26'd64321192;
    localparam L5_OFFSET_K_10_KL_10                = 26'd64504232;
    localparam L5_OFFSET_K_11_KL_1                 = 13'd4368;
    localparam L5_OFFSET_K_11_KL_2                 = 18'd132496;
    localparam L5_OFFSET_K_11_KL_3                 = 21'd1505296;
    localparam L5_OFFSET_K_11_KL_4                 = 24'd8712496;
    localparam L5_OFFSET_K_11_KL_5                 = 25'd29533296;
    localparam L5_OFFSET_K_11_KL_6                 = 26'd64512240;
    localparam L5_OFFSET_K_11_KL_7                 = 27'd99491184;
    localparam L5_OFFSET_K_11_KL_8                 = 27'd120311984;
    localparam L5_OFFSET_K_11_KL_9                 = 27'd127519184;
    localparam L5_OFFSET_K_11_KL_10                = 27'd128891984;
    localparam L5_OFFSET_K_11_KL_11                = 27'd129020112;
    localparam L5_OFFSET_K_12_KL_1                 = 11'd1820;
    localparam L5_OFFSET_K_12_KL_2                 = 17'd71708;
    localparam L5_OFFSET_K_12_KL_3                 = 20'd1032668;
    localparam L5_OFFSET_K_12_KL_4                 = 23'd7439068;
    localparam L5_OFFSET_K_12_KL_5                 = 25'd30862468;
    localparam L5_OFFSET_K_12_KL_6                 = 27'd80832388;
    localparam L5_OFFSET_K_12_KL_7                 = 28'd144960452;
    localparam L5_OFFSET_K_12_KL_8                 = 28'd194930372;
    localparam L5_OFFSET_K_12_KL_9                 = 28'd218353772;
    localparam L5_OFFSET_K_12_KL_10                = 28'd224760172;
    localparam L5_OFFSET_K_12_KL_11                = 28'd225721132;
    localparam L5_OFFSET_K_12_KL_12                = 28'd225791020;
    localparam L5_OFFSET_K_13_KL_1                 = 10'd560;
    localparam L5_OFFSET_K_13_KL_2                 = 15'd29680;
    localparam L5_OFFSET_K_13_KL_3                 = 20'd553840;
    localparam L5_OFFSET_K_13_KL_4                 = 23'd5038320;
    localparam L5_OFFSET_K_13_KL_5                 = 25'd25859120;
    localparam L5_OFFSET_K_13_KL_6                 = 27'd82075280;
    localparam L5_OFFSET_K_13_KL_7                 = 28'd173686800;
    localparam L5_OFFSET_K_13_KL_8                 = 28'd265298320;
    localparam L5_OFFSET_K_13_KL_9                 = 29'd321514480;
    localparam L5_OFFSET_K_13_KL_10                = 29'd342335280;
    localparam L5_OFFSET_K_13_KL_11                = 29'd346819760;
    localparam L5_OFFSET_K_13_KL_12                = 29'd347343920;
    localparam L5_OFFSET_K_13_KL_13                = 29'd347373040;
    localparam L5_OFFSET_K_14_KL_1                 = 7'd120;
    localparam L5_OFFSET_K_14_KL_2                 = 14'd9080;
    localparam L5_OFFSET_K_14_KL_3                 = 18'd227480;
    localparam L5_OFFSET_K_14_KL_4                 = 22'd2673560;
    localparam L5_OFFSET_K_14_KL_5                 = 25'd17248120;
    localparam L5_OFFSET_K_14_KL_6                 = 27'd67218040;
    localparam L5_OFFSET_K_14_KL_7                 = 28'd170281000;
    localparam L5_OFFSET_K_14_KL_8                 = 29'd301154600;
    localparam L5_OFFSET_K_14_KL_9                 = 29'd404217560;
    localparam L5_OFFSET_K_14_KL_10                = 29'd454187480;
    localparam L5_OFFSET_K_14_KL_11                = 29'd468762040;
    localparam L5_OFFSET_K_14_KL_12                = 29'd471208120;
    localparam L5_OFFSET_K_14_KL_13                = 29'd471426520;
    localparam L5_OFFSET_K_14_KL_14                = 29'd471435480;
    localparam L5_OFFSET_K_15_KL_1                 = 5'd16;
    localparam L5_OFFSET_K_15_KL_2                 = 11'd1936;
    localparam L5_OFFSET_K_15_KL_3                 = 17'd69136;
    localparam L5_OFFSET_K_15_KL_4                 = 21'd1088336;
    localparam L5_OFFSET_K_15_KL_5                 = 24'd9038096;
    localparam L5_OFFSET_K_15_KL_6                 = 26'd44017040;
    localparam L5_OFFSET_K_15_KL_7                 = 28'd135628560;
    localparam L5_OFFSET_K_15_KL_8                 = 29'd282861360;
    localparam L5_OFFSET_K_15_KL_9                 = 29'd430094160;
    localparam L5_OFFSET_K_15_KL_10                = 29'd521705680;
    localparam L5_OFFSET_K_15_KL_11                = 30'd556684624;
    localparam L5_OFFSET_K_15_KL_12                = 30'd564634384;
    localparam L5_OFFSET_K_15_KL_13                = 30'd565653584;
    localparam L5_OFFSET_K_15_KL_14                = 30'd565720784;
    localparam L5_OFFSET_K_15_KL_15                = 30'd565722704;
    localparam L5_OFFSET_K_16_KL_1                 = 1'd1;
    localparam L5_OFFSET_K_16_KL_2                 = 9'd257;
    localparam L5_OFFSET_K_16_KL_3                 = 14'd14657;
    localparam L5_OFFSET_K_16_KL_4                 = 19'd328257;
    localparam L5_OFFSET_K_16_KL_5                 = 22'd3640657;
    localparam L5_OFFSET_K_16_KL_6                 = 25'd22720081;
    localparam L5_OFFSET_K_16_KL_7                 = 27'd86848145;
    localparam L5_OFFSET_K_16_KL_8                 = 28'd217721745;
    localparam L5_OFFSET_K_16_KL_9                 = 29'd383358645;
    localparam L5_OFFSET_K_16_KL_10                = 29'd514232245;
    localparam L5_OFFSET_K_16_KL_11                = 30'd578360309;
    localparam L5_OFFSET_K_16_KL_12                = 30'd597439733;
    localparam L5_OFFSET_K_16_KL_13                = 30'd600752133;
    localparam L5_OFFSET_K_16_KL_14                = 30'd601065733;
    localparam L5_OFFSET_K_16_KL_15                = 30'd601080133;
    localparam L5_OFFSET_K_16_KL_16                = 30'd601080389;
    localparam L5_OFFSET_K_17_KL_1                 = 1'd0;
    localparam L5_OFFSET_K_17_KL_2                 = 5'd16;
    localparam L5_OFFSET_K_17_KL_3                 = 11'd1936;
    localparam L5_OFFSET_K_17_KL_4                 = 17'd69136;
    localparam L5_OFFSET_K_17_KL_5                 = 21'd1088336;
    localparam L5_OFFSET_K_17_KL_6                 = 24'd9038096;
    localparam L5_OFFSET_K_17_KL_7                 = 26'd44017040;
    localparam L5_OFFSET_K_17_KL_8                 = 28'd135628560;
    localparam L5_OFFSET_K_17_KL_9                 = 29'd282861360;
    localparam L5_OFFSET_K_17_KL_10                = 29'd430094160;
    localparam L5_OFFSET_K_17_KL_11                = 29'd521705680;
    localparam L5_OFFSET_K_17_KL_12                = 30'd556684624;
    localparam L5_OFFSET_K_17_KL_13                = 30'd564634384;
    localparam L5_OFFSET_K_17_KL_14                = 30'd565653584;
    localparam L5_OFFSET_K_17_KL_15                = 30'd565720784;
    localparam L5_OFFSET_K_17_KL_16                = 30'd565722704;
    localparam L5_OFFSET_K_18_KL_2                 = 1'd0;
    localparam L5_OFFSET_K_18_KL_3                 = 7'd120;
    localparam L5_OFFSET_K_18_KL_4                 = 14'd9080;
    localparam L5_OFFSET_K_18_KL_5                 = 18'd227480;
    localparam L5_OFFSET_K_18_KL_6                 = 22'd2673560;
    localparam L5_OFFSET_K_18_KL_7                 = 25'd17248120;
    localparam L5_OFFSET_K_18_KL_8                 = 27'd67218040;
    localparam L5_OFFSET_K_18_KL_9                 = 28'd170281000;
    localparam L5_OFFSET_K_18_KL_10                = 29'd301154600;
    localparam L5_OFFSET_K_18_KL_11                = 29'd404217560;
    localparam L5_OFFSET_K_18_KL_12                = 29'd454187480;
    localparam L5_OFFSET_K_18_KL_13                = 29'd468762040;
    localparam L5_OFFSET_K_18_KL_14                = 29'd471208120;
    localparam L5_OFFSET_K_18_KL_15                = 29'd471426520;
    localparam L5_OFFSET_K_18_KL_16                = 29'd471435480;
    localparam L5_OFFSET_K_19_KL_3                 = 1'd0;
    localparam L5_OFFSET_K_19_KL_4                 = 10'd560;
    localparam L5_OFFSET_K_19_KL_5                 = 15'd29680;
    localparam L5_OFFSET_K_19_KL_6                 = 20'd553840;
    localparam L5_OFFSET_K_19_KL_7                 = 23'd5038320;
    localparam L5_OFFSET_K_19_KL_8                 = 25'd25859120;
    localparam L5_OFFSET_K_19_KL_9                 = 27'd82075280;
    localparam L5_OFFSET_K_19_KL_10                = 28'd173686800;
    localparam L5_OFFSET_K_19_KL_11                = 28'd265298320;
    localparam L5_OFFSET_K_19_KL_12                = 29'd321514480;
    localparam L5_OFFSET_K_19_KL_13                = 29'd342335280;
    localparam L5_OFFSET_K_19_KL_14                = 29'd346819760;
    localparam L5_OFFSET_K_19_KL_15                = 29'd347343920;
    localparam L5_OFFSET_K_19_KL_16                = 29'd347373040;
    localparam L5_OFFSET_K_20_KL_4                 = 1'd0;
    localparam L5_OFFSET_K_20_KL_5                 = 11'd1820;
    localparam L5_OFFSET_K_20_KL_6                 = 17'd71708;
    localparam L5_OFFSET_K_20_KL_7                 = 20'd1032668;
    localparam L5_OFFSET_K_20_KL_8                 = 23'd7439068;
    localparam L5_OFFSET_K_20_KL_9                 = 25'd30862468;
    localparam L5_OFFSET_K_20_KL_10                = 27'd80832388;
    localparam L5_OFFSET_K_20_KL_11                = 28'd144960452;
    localparam L5_OFFSET_K_20_KL_12                = 28'd194930372;
    localparam L5_OFFSET_K_20_KL_13                = 28'd218353772;
    localparam L5_OFFSET_K_20_KL_14                = 28'd224760172;
    localparam L5_OFFSET_K_20_KL_15                = 28'd225721132;
    localparam L5_OFFSET_K_20_KL_16                = 28'd225791020;
    localparam L5_OFFSET_K_21_KL_5                 = 1'd0;
    localparam L5_OFFSET_K_21_KL_6                 = 13'd4368;
    localparam L5_OFFSET_K_21_KL_7                 = 18'd132496;
    localparam L5_OFFSET_K_21_KL_8                 = 21'd1505296;
    localparam L5_OFFSET_K_21_KL_9                 = 24'd8712496;
    localparam L5_OFFSET_K_21_KL_10                = 25'd29533296;
    localparam L5_OFFSET_K_21_KL_11                = 26'd64512240;
    localparam L5_OFFSET_K_21_KL_12                = 27'd99491184;
    localparam L5_OFFSET_K_21_KL_13                = 27'd120311984;
    localparam L5_OFFSET_K_21_KL_14                = 27'd127519184;
    localparam L5_OFFSET_K_21_KL_15                = 27'd128891984;
    localparam L5_OFFSET_K_21_KL_16                = 27'd129020112;
    localparam L5_OFFSET_K_22_KL_6                 = 1'd0;
    localparam L5_OFFSET_K_22_KL_7                 = 13'd8008;
    localparam L5_OFFSET_K_22_KL_8                 = 18'd191048;
    localparam L5_OFFSET_K_22_KL_9                 = 21'd1735448;
    localparam L5_OFFSET_K_22_KL_10                = 23'd8141848;
    localparam L5_OFFSET_K_22_KL_11                = 25'd22716408;
    localparam L5_OFFSET_K_22_KL_12                = 26'd41795832;
    localparam L5_OFFSET_K_22_KL_13                = 26'd56370392;
    localparam L5_OFFSET_K_22_KL_14                = 26'd62776792;
    localparam L5_OFFSET_K_22_KL_15                = 26'd64321192;
    localparam L5_OFFSET_K_22_KL_16                = 26'd64504232;
    localparam L5_OFFSET_K_23_KL_7                 = 1'd0;
    localparam L5_OFFSET_K_23_KL_8                 = 14'd11440;
    localparam L5_OFFSET_K_23_KL_9                 = 18'd217360;
    localparam L5_OFFSET_K_23_KL_10                = 21'd1590160;
    localparam L5_OFFSET_K_23_KL_11                = 23'd6074640;
    localparam L5_OFFSET_K_23_KL_12                = 24'd14024400;
    localparam L5_OFFSET_K_23_KL_13                = 25'd21974160;
    localparam L5_OFFSET_K_23_KL_14                = 25'd26458640;
    localparam L5_OFFSET_K_23_KL_15                = 25'd27831440;
    localparam L5_OFFSET_K_23_KL_16                = 25'd28037360;
    localparam L5_OFFSET_K_24_KL_8                 = 1'd0;
    localparam L5_OFFSET_K_24_KL_9                 = 14'd12870;
    localparam L5_OFFSET_K_24_KL_10                = 18'd195910;
    localparam L5_OFFSET_K_24_KL_11                = 21'd1156870;
    localparam L5_OFFSET_K_24_KL_12                = 22'd3602950;
    localparam L5_OFFSET_K_24_KL_13                = 23'd6915350;
    localparam L5_OFFSET_K_24_KL_14                = 24'd9361430;
    localparam L5_OFFSET_K_24_KL_15                = 24'd10322390;
    localparam L5_OFFSET_K_24_KL_16                = 24'd10505430;
    localparam L5_OFFSET_K_25_KL_9                 = 1'd0;
    localparam L5_OFFSET_K_25_KL_10                = 14'd11440;
    localparam L5_OFFSET_K_25_KL_11                = 18'd139568;
    localparam L5_OFFSET_K_25_KL_12                = 20'd663728;
    localparam L5_OFFSET_K_25_KL_13                = 21'd1682928;
    localparam L5_OFFSET_K_25_KL_14                = 22'd2702128;
    localparam L5_OFFSET_K_25_KL_15                = 22'd3226288;
    localparam L5_OFFSET_K_25_KL_16                = 22'd3354416;
    localparam L5_OFFSET_K_26_KL_10                = 1'd0;
    localparam L5_OFFSET_K_26_KL_11                = 13'd8008;
    localparam L5_OFFSET_K_26_KL_12                = 17'd77896;
    localparam L5_OFFSET_K_26_KL_13                = 19'd296296;
    localparam L5_OFFSET_K_26_KL_14                = 20'd609896;
    localparam L5_OFFSET_K_26_KL_15                = 20'd828296;
    localparam L5_OFFSET_K_26_KL_16                = 20'd898184;
    localparam L5_OFFSET_K_27_KL_11                = 1'd0;
    localparam L5_OFFSET_K_27_KL_12                = 13'd4368;
    localparam L5_OFFSET_K_27_KL_13                = 16'd33488;
    localparam L5_OFFSET_K_27_KL_14                = 17'd100688;
    localparam L5_OFFSET_K_27_KL_15                = 18'd167888;
    localparam L5_OFFSET_K_27_KL_16                = 18'd197008;
    localparam L5_OFFSET_K_28_KL_12                = 1'd0;
    localparam L5_OFFSET_K_28_KL_13                = 11'd1820;
    localparam L5_OFFSET_K_28_KL_14                = 14'd10780;
    localparam L5_OFFSET_K_28_KL_15                = 15'd25180;
    localparam L5_OFFSET_K_28_KL_16                = 16'd34140;
    localparam L5_OFFSET_K_29_KL_13                = 1'd0;
    localparam L5_OFFSET_K_29_KL_14                = 10'd560;
    localparam L5_OFFSET_K_29_KL_15                = 12'd2480;
    localparam L5_OFFSET_K_29_KL_16                = 13'd4400;
    localparam L5_OFFSET_K_30_KL_14                = 1'd0;
    localparam L5_OFFSET_K_30_KL_15                = 7'd120;
    localparam L5_OFFSET_K_30_KL_16                = 9'd376;
    localparam L5_OFFSET_K_31_KL_15                = 1'd0;
    localparam L5_OFFSET_K_31_KL_16                = 5'd16;
    localparam L5_OFFSET_K_32_KL_16                = 1'd0;

    wire [29:0] offset;
    assign offset =
        out_num_one == 6'd0 ? 30'd0 :
        out_num_one == 6'd1 ? (num_one_high == 5'd1 ? L5_OFFSET_K_1_KL_1 : 30'd0) :
        out_num_one == 6'd2 ? (num_one_high == 5'd1 ? L5_OFFSET_K_2_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_2_KL_2 : 30'd0) :
        out_num_one == 6'd3 ? (num_one_high == 5'd1 ? L5_OFFSET_K_3_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_3_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_3_KL_3 : 30'd0) :
        out_num_one == 6'd4 ? (num_one_high == 5'd1 ? L5_OFFSET_K_4_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_4_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_4_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_4_KL_4 : 30'd0) :
        out_num_one == 6'd5 ? (num_one_high == 5'd1 ? L5_OFFSET_K_5_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_5_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_5_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_5_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_5_KL_5 : 30'd0) :
        out_num_one == 6'd6 ? (num_one_high == 5'd1 ? L5_OFFSET_K_6_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_6_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_6_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_6_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_6_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_6_KL_6 : 30'd0) :
        out_num_one == 6'd7 ? (num_one_high == 5'd1 ? L5_OFFSET_K_7_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_7_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_7_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_7_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_7_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_7_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_7_KL_7 : 30'd0) :
        out_num_one == 6'd8 ? (num_one_high == 5'd1 ? L5_OFFSET_K_8_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_8_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_8_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_8_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_8_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_8_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_8_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_8_KL_8 : 30'd0) :
        out_num_one == 6'd9 ? (num_one_high == 5'd1 ? L5_OFFSET_K_9_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_9_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_9_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_9_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_9_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_9_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_9_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_9_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_9_KL_9 : 30'd0) :
        out_num_one == 6'd10 ? (num_one_high == 5'd1 ? L5_OFFSET_K_10_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_10_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_10_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_10_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_10_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_10_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_10_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_10_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_10_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_10_KL_10 : 30'd0) :
        out_num_one == 6'd11 ? (num_one_high == 5'd1 ? L5_OFFSET_K_11_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_11_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_11_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_11_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_11_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_11_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_11_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_11_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_11_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_11_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_11_KL_11 : 30'd0) :
        out_num_one == 6'd12 ? (num_one_high == 5'd1 ? L5_OFFSET_K_12_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_12_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_12_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_12_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_12_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_12_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_12_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_12_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_12_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_12_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_12_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_12_KL_12 : 30'd0) :
        out_num_one == 6'd13 ? (num_one_high == 5'd1 ? L5_OFFSET_K_13_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_13_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_13_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_13_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_13_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_13_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_13_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_13_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_13_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_13_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_13_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_13_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_13_KL_13 : 30'd0) :
        out_num_one == 6'd14 ? (num_one_high == 5'd1 ? L5_OFFSET_K_14_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_14_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_14_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_14_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_14_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_14_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_14_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_14_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_14_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_14_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_14_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_14_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_14_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_14_KL_14 : 30'd0) :
        out_num_one == 6'd15 ? (num_one_high == 5'd1 ? L5_OFFSET_K_15_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_15_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_15_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_15_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_15_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_15_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_15_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_15_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_15_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_15_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_15_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_15_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_15_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_15_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_15_KL_15 : 30'd0) :
        out_num_one == 6'd16 ? (num_one_high == 5'd1 ? L5_OFFSET_K_16_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_16_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_16_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_16_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_16_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_16_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_16_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_16_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_16_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_16_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_16_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_16_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_16_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_16_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_16_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_16_KL_16 : 30'd0) :
        out_num_one == 6'd17 ? (num_one_high == 5'd1 ? L5_OFFSET_K_17_KL_1 : num_one_high == 5'd2 ? L5_OFFSET_K_17_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_17_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_17_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_17_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_17_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_17_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_17_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_17_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_17_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_17_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_17_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_17_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_17_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_17_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_17_KL_16 : 30'd0) :
        out_num_one == 6'd18 ? (num_one_high == 5'd2 ? L5_OFFSET_K_18_KL_2 : num_one_high == 5'd3 ? L5_OFFSET_K_18_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_18_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_18_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_18_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_18_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_18_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_18_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_18_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_18_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_18_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_18_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_18_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_18_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_18_KL_16 : 30'd0) :
        out_num_one == 6'd19 ? (num_one_high == 5'd3 ? L5_OFFSET_K_19_KL_3 : num_one_high == 5'd4 ? L5_OFFSET_K_19_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_19_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_19_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_19_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_19_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_19_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_19_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_19_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_19_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_19_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_19_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_19_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_19_KL_16 : 30'd0) :
        out_num_one == 6'd20 ? (num_one_high == 5'd4 ? L5_OFFSET_K_20_KL_4 : num_one_high == 5'd5 ? L5_OFFSET_K_20_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_20_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_20_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_20_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_20_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_20_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_20_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_20_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_20_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_20_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_20_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_20_KL_16 : 30'd0) :
        out_num_one == 6'd21 ? (num_one_high == 5'd5 ? L5_OFFSET_K_21_KL_5 : num_one_high == 5'd6 ? L5_OFFSET_K_21_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_21_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_21_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_21_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_21_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_21_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_21_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_21_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_21_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_21_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_21_KL_16 : 30'd0) :
        out_num_one == 6'd22 ? (num_one_high == 5'd6 ? L5_OFFSET_K_22_KL_6 : num_one_high == 5'd7 ? L5_OFFSET_K_22_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_22_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_22_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_22_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_22_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_22_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_22_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_22_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_22_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_22_KL_16 : 30'd0) :
        out_num_one == 6'd23 ? (num_one_high == 5'd7 ? L5_OFFSET_K_23_KL_7 : num_one_high == 5'd8 ? L5_OFFSET_K_23_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_23_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_23_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_23_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_23_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_23_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_23_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_23_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_23_KL_16 : 30'd0) :
        out_num_one == 6'd24 ? (num_one_high == 5'd8 ? L5_OFFSET_K_24_KL_8 : num_one_high == 5'd9 ? L5_OFFSET_K_24_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_24_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_24_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_24_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_24_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_24_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_24_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_24_KL_16 : 30'd0) :
        out_num_one == 6'd25 ? (num_one_high == 5'd9 ? L5_OFFSET_K_25_KL_9 : num_one_high == 5'd10 ? L5_OFFSET_K_25_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_25_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_25_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_25_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_25_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_25_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_25_KL_16 : 30'd0) :
        out_num_one == 6'd26 ? (num_one_high == 5'd10 ? L5_OFFSET_K_26_KL_10 : num_one_high == 5'd11 ? L5_OFFSET_K_26_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_26_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_26_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_26_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_26_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_26_KL_16 : 30'd0) :
        out_num_one == 6'd27 ? (num_one_high == 5'd11 ? L5_OFFSET_K_27_KL_11 : num_one_high == 5'd12 ? L5_OFFSET_K_27_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_27_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_27_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_27_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_27_KL_16 : 30'd0) :
        out_num_one == 6'd28 ? (num_one_high == 5'd12 ? L5_OFFSET_K_28_KL_12 : num_one_high == 5'd13 ? L5_OFFSET_K_28_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_28_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_28_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_28_KL_16 : 30'd0) :
        out_num_one == 6'd29 ? (num_one_high == 5'd13 ? L5_OFFSET_K_29_KL_13 : num_one_high == 5'd14 ? L5_OFFSET_K_29_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_29_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_29_KL_16 : 30'd0) :
        out_num_one == 6'd30 ? (num_one_high == 5'd14 ? L5_OFFSET_K_30_KL_14 : num_one_high == 5'd15 ? L5_OFFSET_K_30_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_30_KL_16 : 30'd0) :
        out_num_one == 6'd31 ? (num_one_high == 5'd15 ? L5_OFFSET_K_31_KL_15 : num_one_high == 5'd16 ? L5_OFFSET_K_31_KL_16 : 30'd0) :
        out_num_one == 6'd32 ? (num_one_high == 5'd16 ? L5_OFFSET_K_32_KL_16 : 30'd0) :
        30'd0;

    wire [14:0] weight;
    assign weight =
        num_one_low == 5'd0 ? L5_WEIGHT_KR_0 :
        num_one_low == 5'd1 ? L5_WEIGHT_KR_1 :
        num_one_low == 5'd2 ? L5_WEIGHT_KR_2 :
        num_one_low == 5'd3 ? L5_WEIGHT_KR_3 :
        num_one_low == 5'd4 ? L5_WEIGHT_KR_4 :
        num_one_low == 5'd5 ? L5_WEIGHT_KR_5 :
        num_one_low == 5'd6 ? L5_WEIGHT_KR_6 :
        num_one_low == 5'd7 ? L5_WEIGHT_KR_7 :
        num_one_low == 5'd8 ? L5_WEIGHT_KR_8 :
        num_one_low == 5'd9 ? L5_WEIGHT_KR_7 :
        num_one_low == 5'd10 ? L5_WEIGHT_KR_6 :
        num_one_low == 5'd11 ? L5_WEIGHT_KR_5 :
        num_one_low == 5'd12 ? L5_WEIGHT_KR_4 :
        num_one_low == 5'd13 ? L5_WEIGHT_KR_3 :
        num_one_low == 5'd14 ? L5_WEIGHT_KR_2 :
        num_one_low == 5'd15 ? L5_WEIGHT_KR_1 :
        num_one_low == 5'd16 ? L5_WEIGHT_KR_0 :
        15'd0;

    assign out_num_one = num_one_high + num_one_low;
    assign out_data = offset + high * weight + low;

endmodule