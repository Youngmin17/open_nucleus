// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module comparator_tree_bf16 #(
    parameter EXP_WIDTH = 8,
    parameter SIG_WIDTH = 15,
    parameter DATA_NUM  = 128

)(
    input wire clk,
    input wire rst_n,
    input wire [(1+EXP_WIDTH+SIG_WIDTH)*DATA_NUM-1:0] d_in,
    input wire in_vld,
    output wire out_vld,
    output wire [(1+EXP_WIDTH+SIG_WIDTH)-1:0] d_out
);
    localparam DATA_WIDTH = 1+EXP_WIDTH+SIG_WIDTH;
    localparam STAGE_1 = DATA_NUM/2;
    localparam STAGE_2 = DATA_NUM/4;
    localparam STAGE_3 = DATA_NUM/8;
    localparam STAGE_4 = DATA_NUM/16;
    localparam STAGE_5 = DATA_NUM/32;
    localparam STAGE_6 = DATA_NUM/64;
    localparam STAGE_7 = DATA_NUM/128;

    genvar i;

    wire [DATA_WIDTH-1:0] d_in_w [DATA_NUM-1:0];

    generate
    for (i=0; i<DATA_NUM; i=i+1)
    begin : DATA_DIVSION
        assign d_in_w[i] = d_in[DATA_WIDTH*i+:DATA_WIDTH];
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val1 [STAGE_1-1:0];
    wire [DATA_WIDTH-1:0] lt_val1 [STAGE_1-1:0];

    generate
    for (i=0; i<STAGE_1; i=i+1)
    begin : DATA_COMP1
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(d_in_w[2*i]),
            .inst_b(d_in_w[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val1[i]),
            .z1_inst(gt_val1[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val1_r [STAGE_1-1:0];

    generate
    for (i=0; i<STAGE_1; i=i+1)
    begin : DATA_DIVSION1
        always @ (posedge clk) begin
            if (!rst_n) gt_val1_r[i] <= 0;
            else        gt_val1_r[i] <= gt_val1[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val2 [STAGE_2-1:0];
    wire [DATA_WIDTH-1:0] lt_val2 [STAGE_2-1:0];

    generate
    for (i=0; i<STAGE_2; i=i+1)
    begin : DATA_COMP2
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val1_r[2*i]),
            .inst_b(gt_val1_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val2[i]),
            .z1_inst(gt_val2[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val2_r [STAGE_2-1:0];

    generate
    for (i=0; i<STAGE_2; i=i+1)
    begin : DATA_DIVSION2
        always @ (posedge clk) begin
            if (!rst_n) gt_val2_r[i] <= 0;
            else        gt_val2_r[i] <= gt_val2[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val3 [STAGE_3-1:0];
    wire [DATA_WIDTH-1:0] lt_val3 [STAGE_3-1:0];

    generate
    for (i=0; i<STAGE_3; i=i+1)
    begin : DATA_COMP3
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val2_r[2*i]),
            .inst_b(gt_val2_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val3[i]),
            .z1_inst(gt_val3[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val3_r [STAGE_3-1:0];

    generate
    for (i=0; i<STAGE_3; i=i+1)
    begin : DATA_DIVSION3
        always @ (posedge clk) begin
            if (!rst_n) gt_val3_r[i] <= 0;
            else        gt_val3_r[i] <= gt_val3[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val4 [STAGE_4-1:0];
    wire [DATA_WIDTH-1:0] lt_val4 [STAGE_4-1:0];

    generate
    for (i=0; i<STAGE_4; i=i+1)
    begin : DATA_COMP4
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val3_r[2*i]),
            .inst_b(gt_val3_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val4[i]),
            .z1_inst(gt_val4[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val4_r [STAGE_4-1:0];

    generate
    for (i=0; i<STAGE_4; i=i+1)
    begin : DATA_DIVSION4
        always @ (posedge clk) begin
            if (!rst_n) gt_val4_r[i] <= 0;
            else        gt_val4_r[i] <= gt_val4[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val5 [STAGE_5-1:0];
    wire [DATA_WIDTH-1:0] lt_val5 [STAGE_5-1:0];

    generate
    for (i=0; i<STAGE_5; i=i+1)
    begin : DATA_COMP5
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val4_r[2*i]),
            .inst_b(gt_val4_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val5[i]),
            .z1_inst(gt_val5[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val5_r [STAGE_5-1:0];

    generate
    for (i=0; i<STAGE_5; i=i+1)
    begin : DATA_DIVSION5
        always @ (posedge clk) begin
            if (!rst_n) gt_val5_r[i] <= 0;
            else        gt_val5_r[i] <= gt_val5[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val6 [STAGE_6-1:0];
    wire [DATA_WIDTH-1:0] lt_val6 [STAGE_6-1:0];

    generate
    for (i=0; i<STAGE_6; i=i+1)
    begin : DATA_COMP6
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val5_r[2*i]),
            .inst_b(gt_val5_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val6[i]),
            .z1_inst(gt_val6[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val6_r [STAGE_6-1:0];

    generate
    for (i=0; i<STAGE_6; i=i+1)
    begin : DATA_DIVSION6
        always @ (posedge clk) begin
            if (!rst_n) gt_val6_r[i] <= 0;
            else        gt_val6_r[i] <= gt_val6[i];
        end
    end
    endgenerate

    wire [DATA_WIDTH-1:0] gt_val7 [STAGE_7-1:0];
    wire [DATA_WIDTH-1:0] lt_val7 [STAGE_7-1:0];

    generate
    for (i=0; i<STAGE_7; i=i+1)
    begin : DATA_COMP7
        DW_fp_cmp_inst#(
            .sig_width(SIG_WIDTH),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_DW_fp_cmp_inst (
            .inst_a(gt_val6_r[2*i]),
            .inst_b(gt_val6_r[2*i+1]),
            .inst_zctr(1'b0),
            .aeqb_inst(),
            .altb_inst(),
            .agtb_inst(),
            .unordered_inst(),
            .z0_inst(lt_val7[i]),
            .z1_inst(gt_val7[i]),
            .status0_inst(),
            .status1_inst()
        );
    end
    endgenerate

    reg [DATA_WIDTH-1:0] gt_val7_r [STAGE_7-1:0];

    generate
    for (i=0; i<STAGE_7; i=i+1)
    begin : DATA_DIVSION7
        always @ (posedge clk) begin
            if (!rst_n) gt_val7_r[i] <= 0;
            else        gt_val7_r[i] <= gt_val7[i];
        end
    end
    endgenerate

    reg comp_vld1_r;
    reg comp_vld2_r;
    reg comp_vld3_r;
    reg comp_vld4_r;
    reg comp_vld5_r;
    reg comp_vld6_r;
    reg comp_vld7_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            comp_vld1_r <= 1'b0;
            comp_vld2_r <= 1'b0;
            comp_vld3_r <= 1'b0;
            comp_vld4_r <= 1'b0;
            comp_vld5_r <= 1'b0;
            comp_vld6_r <= 1'b0;
            comp_vld7_r <= 1'b0;
        end
        else begin
            comp_vld1_r <= in_vld;
            comp_vld2_r <= comp_vld1_r;
            comp_vld3_r <= comp_vld2_r;
            comp_vld4_r <= comp_vld3_r;
            comp_vld5_r <= comp_vld4_r;
            comp_vld6_r <= comp_vld5_r;
            comp_vld7_r <= comp_vld6_r;
        end
    end

    assign d_out = gt_val7_r[0];
    assign out_vld = comp_vld7_r;

endmodule
