// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

module norm
#(
    parameter BEFORE_PREC = 16,
    parameter GROUP_WIDTH = 32,
    parameter LOOP_NUM = 4
)
(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_vld,
    input  wire [2:0]               quant_precision,
    input  wire                     indicate_kv,

    input  wire [BEFORE_PREC*GROUP_WIDTH-1:0] d_in,
    input  wire [BEFORE_PREC*GROUP_WIDTH-1:0] outlier_in,
    input  wire [GROUP_WIDTH-1:0]             outlier_pos,
    input  wire [15:0]              scale_fp_prec2,
    input  wire [15:0]              scale_fp_prec4,
    input  wire [15:0]              scale_fp_prec8,
    input  wire [15:0]              scale_int_prec2,
    input  wire [15:0]              scale_int_prec4,
    input  wire [15:0]              scale_int_prec8,
    input  wire [15:0]              zerop_fp,
    input  wire [15:0]              zerop_int,

    output reg                      out_vld,
    output reg [(GROUP_WIDTH<<3)-1:0] d_out_fp,
    output reg [(GROUP_WIDTH<<2)-1:0] d_out_int,
    output reg [15:0]              scale_fp_out,
    output reg [15:0]              scale_int_out,
    output reg [15:0]              zerop_fp_out,
    output reg [15:0]              zerop_int_out,
    output reg [GROUP_WIDTH*5-1:0] outlier_mask_out
);

    localparam [15:0] FP4_THRESH_0_354  = 16'h3EB5;
    localparam [15:0] FP4_THRESH_0_707  = 16'h3F2E;
    localparam [15:0] FP4_THRESH_1_225  = 16'h3F9C;
    localparam [15:0] FP4_THRESH_1_732  = 16'h3FDD;
    localparam [15:0] FP4_THRESH_2_449  = 16'h401C;
    localparam [15:0] FP4_THRESH_3_464  = 16'h405D;
    localparam [15:0] FP4_THRESH_4_899  = 16'h409C;
    localparam [15:0] FP4_THRESH_5_477  = 16'h40AE;

    localparam [15:0] INT4_THRESH_0_5  = 16'h3F00;
    localparam [15:0] INT4_THRESH_1_5  = 16'h3FC0;
    localparam [15:0] INT4_THRESH_2_5  = 16'h4020;
    localparam [15:0] INT4_THRESH_3_5  = 16'h4060;
    localparam [15:0] INT4_THRESH_4_5  = 16'h4090;
    localparam [15:0] INT4_THRESH_5_5  = 16'h40B0;
    localparam [15:0] INT4_THRESH_6_5  = 16'h40D0;
    localparam [15:0] INT4_THRESH_7_5  = 16'h40F0;
    localparam [15:0] INT4_THRESH_8_5  = 16'h4108;
    localparam [15:0] INT4_THRESH_9_5  = 16'h4118;
    localparam [15:0] INT4_THRESH_10_5 = 16'h4128;
    localparam [15:0] INT4_THRESH_11_5 = 16'h4138;
    localparam [15:0] INT4_THRESH_12_5 = 16'h4148;
    localparam [15:0] INT4_THRESH_13_5 = 16'h4158;
    localparam [15:0] INT4_THRESH_14_5 = 16'h4168;

    localparam [15:0] INT2_THRESH_0_5   = 16'h3F00;
    localparam [15:0] INT2_THRESH_1_5   = 16'h3FC0;
    localparam [15:0] INT2_THRESH_2_5   = 16'h4020;

    function [7:0] fp8_lut;
        input [15:0] bf16_norm;

        reg sign;
        reg [7:0] exp_bf16;
        reg [6:0] mant_bf16;

        reg [8:0] exp_unbiased;
        reg [4:0] exp_fp8_pre;
        reg [3:0] mant_fp8_pre;

        reg round_bit;
        reg sticky_bit;
        reg round_up;

        begin
            sign = bf16_norm[15];
            exp_bf16 = bf16_norm[14:7];
            mant_bf16 = bf16_norm[6:0];

            if (exp_bf16 == 8'h00) begin
                fp8_lut = 8'b0;
            end
            else if (exp_bf16 == 8'hFF) begin
                fp8_lut = {sign, 7'b1111111};
            end
            else begin
                round_bit = mant_bf16[3];
                sticky_bit = |mant_bf16[2:0];

                round_up = (round_bit && sticky_bit) || (round_bit && !sticky_bit && mant_bf16[4]);

                if (round_up && (mant_bf16[6:4] == 3'b111)) begin
                    mant_fp8_pre = 4'b0000;
                    exp_unbiased = exp_bf16 - 8'd127 + 8'd1;
                end else begin
                    mant_fp8_pre = {1'b0, mant_bf16[6:4]} + round_up;
                    exp_unbiased = exp_bf16 - 8'd127;
                end

                if ($signed(exp_unbiased) > 8) begin
                    fp8_lut = {sign, 4'b1111, 3'b110};
                end
                else if ($signed(exp_unbiased) < -6) begin
                    fp8_lut = {sign, 7'b0000000};
                end
                else begin
                    exp_fp8_pre = exp_unbiased + 9'd7;
                    fp8_lut = {sign, exp_fp8_pre[3:0], mant_fp8_pre[2:0]};
                end
            end
        end
    endfunction

    function [3:0] fp4_lut;
        input [15:0] bf16_norm;
        reg is_zero, is_inf, is_nan;
        reg [15:0] abs_bf16;
        reg [2:0] magnitude_code;
        reg sign_bit;

        begin
            sign_bit = bf16_norm[15];
            abs_bf16 = {1'b0, bf16_norm[14:0]};

            is_zero = (bf16_norm[14:7] == 8'h00);
            is_inf  = (bf16_norm[14:7] == 8'hFF) && (bf16_norm[6:0] == 7'h00);
            is_nan  = (bf16_norm[14:7] == 8'hFF) && (bf16_norm[6:0] != 7'h00);

            if (is_zero) begin
                fp4_lut = 4'b0000;
            end
            else if (is_inf || is_nan) begin
                fp4_lut = {sign_bit, 3'b111};
            end
            else begin
                if (abs_bf16 <= FP4_THRESH_0_354) begin
                    magnitude_code = 3'b000;
                end else if (abs_bf16 <= FP4_THRESH_0_707) begin
                    magnitude_code = 3'b001;
                end else if (abs_bf16 <= FP4_THRESH_1_225) begin
                    magnitude_code = 3'b010;
                end else if (abs_bf16 <= FP4_THRESH_1_732) begin
                    magnitude_code = 3'b011;
                end else if (abs_bf16 <= FP4_THRESH_2_449) begin
                    magnitude_code = 3'b100;
                end else if (abs_bf16 <= FP4_THRESH_3_464) begin
                    magnitude_code = 3'b101;
                end else if (abs_bf16 <= FP4_THRESH_4_899) begin
                    magnitude_code = 3'b110;
                end else begin
                    magnitude_code = 3'b111;
                end

                fp4_lut = {sign_bit, magnitude_code};
            end
        end
    endfunction

    function [3:0] int4_lut;
        input [15:0] bf16_norm;
        reg [15:0] abs_bf16;
        reg [3:0] quant_val;

        begin
            abs_bf16 = {1'b0, bf16_norm[14:0]};

            if (bf16_norm[14:7] == 8'h00) begin
                quant_val = 4'b0000;
            end else if (bf16_norm[14:7] == 8'hFF) begin
                quant_val = 4'b1111;
            end else begin
                if (abs_bf16 <= INT4_THRESH_0_5) begin
                    quant_val = 4'b0000;
                end else if (abs_bf16 <= INT4_THRESH_1_5) begin
                    quant_val = 4'b0001;
                end else if (abs_bf16 <= INT4_THRESH_2_5) begin
                    quant_val = 4'b0010;
                end else if (abs_bf16 <= INT4_THRESH_3_5) begin
                    quant_val = 4'b0011;
                end else if (abs_bf16 <= INT4_THRESH_4_5) begin
                    quant_val = 4'b0100;
                end else if (abs_bf16 <= INT4_THRESH_5_5) begin
                    quant_val = 4'b0101;
                end else if (abs_bf16 <= INT4_THRESH_6_5) begin
                    quant_val = 4'b0110;
                end else if (abs_bf16 <= INT4_THRESH_7_5) begin
                    quant_val = 4'b0111;
                end else if (abs_bf16 <= INT4_THRESH_8_5) begin
                    quant_val = 4'b1000;
                end else if (abs_bf16 <= INT4_THRESH_9_5) begin
                    quant_val = 4'b1001;
                end else if (abs_bf16 <= INT4_THRESH_10_5) begin
                    quant_val = 4'b1010;
                end else if (abs_bf16 <= INT4_THRESH_11_5) begin
                    quant_val = 4'b1011;
                end else if (abs_bf16 <= INT4_THRESH_12_5) begin
                    quant_val = 4'b1100;
                end else if (abs_bf16 <= INT4_THRESH_13_5) begin
                    quant_val = 4'b1101;
                end else if (abs_bf16 <= INT4_THRESH_14_5) begin
                    quant_val = 4'b1110;
                end else begin
                    quant_val = 4'b1111;
                end
            end

            int4_lut = quant_val;
        end
    endfunction

    function [1:0] int2_lut;
        input [15:0] bf16_norm;
        reg [15:0] abs_bf16;
        reg [1:0] quant_val;

        begin
            abs_bf16 = {1'b0, bf16_norm[14:0]};

            if (bf16_norm[14:7] == 8'h00) begin
                quant_val = 2'b00;
            end else if (bf16_norm[14:7] == 8'hFF) begin
                quant_val = 2'b11;
            end else begin
                if (abs_bf16 <= INT2_THRESH_0_5) begin
                    quant_val = 2'b00;
                end else if (abs_bf16 <= INT2_THRESH_1_5) begin
                    quant_val = 2'b01;
                end else if (abs_bf16 <= INT2_THRESH_2_5) begin
                    quant_val = 2'b10;
                end else begin
                    quant_val = 2'b11;
                end
            end

            int2_lut = quant_val;
        end
    endfunction

    integer idx, idx1, idx2;

    reg                     IN_VLD_FLAG;

    reg [BEFORE_PREC-1:0]   d_in_reg [GROUP_WIDTH-1:0];
    reg [BEFORE_PREC-1:0]   outlier_in_reg [GROUP_WIDTH-1:0];
    reg [15:0]              scale_int_reg1, scale_int_reg2, scale_int_reg3, scale_fp_reg1, scale_fp_reg2, scale_fp_reg3;
    reg [15:0]              zerop_fp_reg1, zerop_fp_reg2, zerop_fp_reg3;
    reg [15:0]              zerop_int_reg1, zerop_int_reg2, zerop_int_reg3;
    reg [2:0]               prec1, prec2;
    reg                     kv1, kv2;
    reg [GROUP_WIDTH-1:0]   outlier_pos_reg1, outlier_pos_reg2;

    reg sub_vld;
    reg [4:0] sub_cnt;
    reg norm_vld_at_sub, norm_vld_at_sub_pip;

    reg [BEFORE_PREC-1:0] d_sub_fp_reg [GROUP_WIDTH-1:0];
    reg [BEFORE_PREC-1:0] d_sub_int_reg [GROUP_WIDTH-1:0];
    reg [BEFORE_PREC-1:0] d_sub_outlier_reg [GROUP_WIDTH-1:0];

    always @(*) begin
        if(!rst_n) begin
            IN_VLD_FLAG = 1'b0;
        end else if(in_vld && quant_precision > 3'b001) begin
            IN_VLD_FLAG = 1'b1;
        end else begin
            IN_VLD_FLAG = 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_cnt <= 5'd0;
            sub_vld <= 1'b0;
            out_vld <= 1'b0;
            norm_vld_at_sub <= 1'b0;
            norm_vld_at_sub_pip <= 1'b0;
            scale_int_reg1 <= 16'd0;
            scale_int_reg2 <= 16'd0;
            scale_int_reg3 <= 16'd0;
            scale_fp_reg1 <= 16'd0;
            scale_fp_reg2 <= 16'd0;
            scale_fp_reg3 <= 16'd0;
            zerop_fp_reg1 <= 16'd0;
            zerop_fp_reg2 <= 16'd0;
            zerop_fp_reg3 <= 16'd0;
            zerop_int_reg1 <= 16'd0;
            zerop_int_reg2 <= 16'd0;
            zerop_int_reg3 <= 16'd0;
            scale_fp_out <= 16'd0;
            scale_int_out <= 16'd0;
            zerop_fp_out <= 16'd0;
            zerop_int_out <= 16'd0;
            prec1 <= 3'd0;
            prec2 <= 3'd0;
            kv1 <= 1'b0;
            kv2 <= 1'b0;
            outlier_pos_reg1 <= {GROUP_WIDTH{1'b0}};
            outlier_pos_reg2 <= {GROUP_WIDTH{1'b0}};
            for(idx=0; idx<GROUP_WIDTH; idx=idx+1) begin
                d_in_reg[idx] <= {BEFORE_PREC{1'b0}};
                outlier_in_reg[idx] <= {BEFORE_PREC{1'b0}};
            end

        end else begin
            out_vld <= 1'b0;
            norm_vld_at_sub <= 1'b0;
            norm_vld_at_sub_pip <= norm_vld_at_sub;

            if (IN_VLD_FLAG) begin
                scale_int_reg1 <=  (quant_precision == 3'b010 || quant_precision == 3'b011 || quant_precision == 3'b110) ? scale_int_prec2 : scale_int_prec4;
                scale_fp_reg1 <=  (quant_precision == 3'b010 || quant_precision == 3'b011 || quant_precision == 3'b111) ? scale_fp_prec4 : scale_fp_prec8;
                zerop_fp_reg1 <= zerop_fp;
                zerop_int_reg1 <= zerop_int;
                outlier_pos_reg1 <= outlier_pos;
                prec1 <= quant_precision;
                kv1 <= indicate_kv;
                for(idx=0; idx<GROUP_WIDTH; idx=idx+1) begin
                    d_in_reg[idx] <= d_in[BEFORE_PREC*idx +: BEFORE_PREC];
                    outlier_in_reg[idx] <= outlier_in[BEFORE_PREC*idx +: BEFORE_PREC];
                end
            end

            if(sub_cnt == 1) begin
                sub_cnt <= 5'd0;
                sub_vld <= 1'b0;
                norm_vld_at_sub <= 1'b1;
                scale_int_reg2 <= scale_int_reg1;
                scale_fp_reg2 <= scale_fp_reg1;
                zerop_fp_reg2 <= zerop_fp_reg1;
                zerop_int_reg2 <= zerop_int_reg1;
                outlier_pos_reg2 <= outlier_pos_reg1;
                prec2 <= prec1;
                kv2 <= kv1;
                if(IN_VLD_FLAG) begin
                    sub_cnt <= LOOP_NUM;
                    sub_vld <= 1'b1;
                end
            end else if(sub_cnt > 1) begin
                sub_cnt <= sub_cnt - 1;
            end else if(sub_cnt == 0) begin
                if(IN_VLD_FLAG) begin
                    sub_cnt <= LOOP_NUM;
                    sub_vld <= 1'b1;
                end
            end

            if(norm_vld_at_sub_pip) begin
                out_vld <= 1'b1;
                scale_fp_out <= scale_fp_reg2;
                scale_int_out <= scale_int_reg2;
                zerop_fp_out <= zerop_fp_reg2;
                zerop_int_out <= zerop_int_reg2;
            end
        end
    end

    genvar i;

    generate
    for(i=0; i<GROUP_WIDTH/LOOP_NUM; i=i+1)
    begin : normalization
        wire [BEFORE_PREC-1:0] a_inst = d_in_reg[i+(GROUP_WIDTH/LOOP_NUM)*(sub_cnt-1)];
        wire [BEFORE_PREC-1:0] a_outlier_inst = outlier_in_reg[i+(GROUP_WIDTH/LOOP_NUM)*(sub_cnt-1)];
        wire [BEFORE_PREC-1:0] b_outlier_inst = outlier_pos_reg1[i+(GROUP_WIDTH/LOOP_NUM)*(sub_cnt-1)] ? zerop_int_reg1 : {BEFORE_PREC{1'b0}};
        wire [BEFORE_PREC-1:0] sub_wire_fp, sub_wire_int, sub_wire_outlier;

        DW_fp_addsub_inst #(
            .sig_width (7),
            .exp_width (8),
            .ieee_compliance (0)
        ) dense_minus_zp_fp (
            .inst_a    (a_inst),
            .inst_b    (zerop_fp_reg1),
            .inst_rnd  (3'b000),
            .inst_op   (1'b1),
            .z_inst    (sub_wire_fp),
            .status_inst ()
        );

        DW_fp_addsub_inst #(
            .sig_width (7),
            .exp_width (8),
            .ieee_compliance (0)
        ) dense_minus_zp_int (
            .inst_a    (a_inst),
            .inst_b    (zerop_int_reg1),
            .inst_rnd  (3'b000),
            .inst_op   (1'b1),
            .z_inst    (sub_wire_int),
            .status_inst ()
        );

        DW_fp_addsub_inst #(
            .sig_width (7),
            .exp_width (8),
            .ieee_compliance (0)
        ) outlier_minus_zp_int (
            .inst_a    (a_outlier_inst),
            .inst_b    (b_outlier_inst),
            .inst_rnd  (3'b000),
            .inst_op   (1'b1),
            .z_inst    (sub_wire_outlier),
            .status_inst ()
        );

        genvar j;
        for(j=0; j<LOOP_NUM; j=j+1) begin : reset_loop
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    d_sub_fp_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= {BEFORE_PREC{1'b0}};
                    d_sub_int_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= {BEFORE_PREC{1'b0}};
                    d_sub_outlier_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= {BEFORE_PREC{1'b0}};
                end else begin
                    if(sub_vld && (sub_cnt-1 == j)) begin
                        d_sub_fp_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= sub_wire_fp;
                        d_sub_int_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= sub_wire_int;
                        d_sub_outlier_reg[i+(GROUP_WIDTH/LOOP_NUM)*j] <= sub_wire_outlier;
                    end
                end
            end
        end
    end
    endgenerate

    reg [(GROUP_WIDTH<<3)-1:0] d_out_fp_nonembed;
    reg [(GROUP_WIDTH<<2)-1:0] d_out_int_nonembed;
    reg [(GROUP_WIDTH<<3)-1:0] d_out_outlier_forembed;

    generate
    for(i=0; i<GROUP_WIDTH; i=i+1)
    begin : d_norm_lut_lower
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                d_out_int_nonembed[4*i +: 4] <= 4'b0;
                d_out_fp_nonembed[8*i +: 8] <= 8'b0;
                d_out_outlier_forembed[8*i +: 8] <= 8'b0;
                d_out_fp[8*i +: 8] <= 8'b0;
                d_out_int[4*i +: 4] <= 4'b0;
                outlier_mask_out[5*i +: 5] <= 5'b0;
            end else begin
                if(norm_vld_at_sub) begin
                    if(prec2 == 3'b010 || prec2 == 3'b011 || prec2 == 3'b110) begin
                        d_out_int_nonembed[4*i +: 4] <=
                                {2'b0, {int2_lut({d_sub_int_reg[i][15], (d_sub_int_reg[i][14:7]+9'd127>{1'b0,scale_int_reg2[7:0]} ? d_sub_int_reg[i][14:7]+8'd127-scale_int_reg2[7:0]:8'd0), d_sub_int_reg[i][6:0]})}};
                        d_out_outlier_forembed[8*i +: 8] <=
                                {4'b0, {fp4_lut({d_sub_outlier_reg[i][15], (d_sub_outlier_reg[i][14:7]+9'd127>{1'b0,scale_int_reg2[7:0]} ? d_sub_outlier_reg[i][14:7]+8'd127-scale_int_reg2[7:0]:8'd0), d_sub_outlier_reg[i][6:0]})}};
                    end else begin
                        d_out_int_nonembed[4*i +: 4] <= int4_lut({d_sub_int_reg[i][15], (d_sub_int_reg[i][14:7]+9'd127>{1'b0,scale_int_reg2[7:0]} ? d_sub_int_reg[i][14:7]+8'd127-scale_int_reg2[7:0]:8'd0), d_sub_int_reg[i][6:0]});
                        d_out_outlier_forembed[8*i +: 8] <= fp8_lut({d_sub_outlier_reg[i][15], (d_sub_outlier_reg[i][14:7]+9'd127>{1'b0,scale_int_reg2[7:0]} ? d_sub_outlier_reg[i][14:7]+8'd127-scale_int_reg2[7:0]:8'd0), d_sub_outlier_reg[i][6:0]});
                    end
                    if(prec2 == 3'b011 || prec2 == 3'b111) begin
                        d_out_fp_nonembed[8*i +: 8] <=
                                {4'b0, {fp4_lut({d_sub_fp_reg[i][15], (d_sub_fp_reg[i][14:7]+9'd127>{1'b0,scale_fp_reg2[7:0]} ? d_sub_fp_reg[i][14:7]+8'd127-scale_fp_reg2[7:0]:8'd0), d_sub_fp_reg[i][6:0]})}};
                    end else if(prec2 == 3'b101 || prec2 == 3'b110) begin
                        d_out_fp_nonembed[8*i +: 8] <= fp8_lut({d_sub_fp_reg[i][15], (d_sub_fp_reg[i][14:7]+9'd127>{1'b0,scale_fp_reg2[7:0]} ? d_sub_fp_reg[i][14:7]+8'd127-scale_fp_reg2[7:0]:8'd0), d_sub_fp_reg[i][6:0]});
                    end else begin
                        d_out_fp_nonembed[8*i +: 8] <= 8'b0;
                    end
                end
                if(norm_vld_at_sub_pip) begin
                    d_out_fp[8*i+:8] <= d_out_fp_nonembed[8*i+:8];
                    if(prec2 == 3'b010 || prec2 == 3'b011 || prec2 == 3'b110) begin
                        d_out_int[4*i+:4] <= (!kv2 && outlier_pos_reg2[i]) ? {2'b0, d_out_outlier_forembed[8*i+:2]} : d_out_int_nonembed[4*i+:4];
                        outlier_mask_out[5*i+:5] <= !kv2 ? {2'b0, outlier_pos_reg2[i], d_out_outlier_forembed[8*i+2+:2]} : 5'b0;
                    end else begin
                        d_out_int[4*i+:4] <= (!kv2 && outlier_pos_reg2[i]) ? d_out_outlier_forembed[8*i+:4] : d_out_int_nonembed[4*i+:4];
                        outlier_mask_out[5*i+:5] <= !kv2 ? {outlier_pos_reg2[i], d_out_outlier_forembed[8*i+4+:4]} : 5'b0;
                    end
                end
            end
        end
    end
    endgenerate

endmodule