// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

module comparator_tree
#(
    parameter PRECISION         = 16,
    parameter MAX_GROUP_WIDTH       = 128
)
(
    input  wire                 clk,
    input  wire                 rst_n,
    input wire [1:0]            group_size,
    input  wire                 in_vld,
    input  wire [PRECISION*MAX_GROUP_WIDTH-1:0] d_in,

    output reg                    out_vld,
    output reg [4*PRECISION-1:0]  max_out,
    output reg [4*PRECISION-1:0]  min_out,
    output reg [4*PRECISION-1:0]  mean_out
);

    localparam MIN_GROUP_WIDTH = 32;

    localparam SIGN_WIDTH = 1;
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 7;

    localparam MANT_OUT_WIDTH = 17;
    localparam TREE_OUT_WIDTH = 24;

    localparam FP24_WIDTH   = 24;
    localparam FP24_MANT_W  = 15;

    reg [PRECISION-1:0] d_in_reg [MAX_GROUP_WIDTH-1:0];
    reg FLAG, inter_vld_max, inter_vld_min;
    reg inter_vld_pip1, inter_vld_pip2;
    reg [4*PRECISION-1:0] max_out_interm1, min_out_interm1, max_out_interm2, min_out_interm2;

    wire [PRECISION-1:0] d1 [(MAX_GROUP_WIDTH>>1)-1:0];
    wire [PRECISION-1:0] d2 [(MAX_GROUP_WIDTH>>2)-1:0];
    wire [PRECISION-1:0] d3 [(MAX_GROUP_WIDTH>>3)-1:0];
    wire [PRECISION-1:0] d4 [(MAX_GROUP_WIDTH>>4)-1:0];
    wire [PRECISION-1:0] d5 [(MAX_GROUP_WIDTH>>5)-1:0];
    wire [PRECISION-1:0] d6 [(MAX_GROUP_WIDTH>>6)-1:0];
    wire [PRECISION-1:0] d7;

    genvar i;

    always @(*) begin
        if(!rst_n) begin
            FLAG = 1'b0;
        end else if(in_vld) begin
            FLAG = 1'b1;
        end else begin
            FLAG = 1'b0;
        end
    end

    generate
    for (i=0; i<MAX_GROUP_WIDTH; i=i+1)
    begin : reg_assign_comptree
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            d_in_reg[i] <= {PRECISION{1'b0}};
        end else if(FLAG) begin
            d_in_reg[i] <= d_in[PRECISION*i+PRECISION-1:PRECISION*i];
        end
    end
    end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            inter_vld_max <= 1'b0;
            inter_vld_min <= 1'b0;
            inter_vld_pip1 <= 1'b0;
            inter_vld_pip2 <= 1'b0;
        end else begin
            inter_vld_max <= FLAG;
            inter_vld_min <= inter_vld_max;
            inter_vld_pip1 <= inter_vld_min;
            inter_vld_pip2 <= inter_vld_pip1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_vld <= 1'b0;
            max_out <= {4*PRECISION{1'b0}};
            min_out <= {4*PRECISION{1'b0}};
            max_out_interm1 <= {4*PRECISION{1'b0}};
            min_out_interm1 <= {4*PRECISION{1'b0}};
            max_out_interm2 <= {4*PRECISION{1'b0}};
            min_out_interm2 <= {4*PRECISION{1'b0}};

        end else begin
            out_vld <= inter_vld_pip2;
            max_out_interm2 <= max_out_interm1;
            max_out <= max_out_interm2;
            min_out_interm2 <= min_out_interm1;
            min_out <= min_out_interm1;
            if(inter_vld_max) begin
                max_out_interm1 <= group_size == 2'b01 ? {d5[3], d5[2], d5[1], d5[0]} :
                        group_size == 2'b10 ? {16'b0, d6[1], 16'b0, d6[0]} :
                        group_size == 2'b11 ? {48'b0, d7} :
                        {4*PRECISION{1'b0}};
            end
            if(inter_vld_min) begin
                min_out_interm1 <= group_size == 2'b01 ? {d5[3], d5[2], d5[1], d5[0]} :
                        group_size == 2'b10 ? {16'b0, d6[1], 16'b0, d6[0]} :
                        group_size == 2'b11 ? {48'b0, d7} :
                        {4*PRECISION{1'b0}};
            end
        end
    end

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>1); i=i+1)
    begin : first_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_1st (
            .max_min(inter_vld_max),
            .a_in(d_in_reg[2*i]),
            .b_in(d_in_reg[2*i+1]),
            .d_out(d1[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>2); i=i+1)
    begin : second_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_2nd (
            .max_min(inter_vld_max),
            .a_in(d1[2*i]),
            .b_in(d1[2*i+1]),
            .d_out(d2[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>3); i=i+1)
    begin : third_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_3rd (
            .max_min(inter_vld_max),
            .a_in(d2[2*i]),
            .b_in(d2[2*i+1]),
            .d_out(d3[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>4); i=i+1)
    begin : fourth_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_4th (
            .max_min(inter_vld_max),
            .a_in(d3[2*i]),
            .b_in(d3[2*i+1]),
            .d_out(d4[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>5); i=i+1)
    begin : fifth_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_5th (
            .max_min(inter_vld_max),
            .a_in(d4[2*i]),
            .b_in(d4[2*i+1]),
            .d_out(d5[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>6); i=i+1)
    begin : sixth_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_6th (
            .max_min(inter_vld_max),
            .a_in(d5[2*i]),
            .b_in(d5[2*i+1]),
            .d_out(d6[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(MAX_GROUP_WIDTH>>7); i=i+1)
    begin : seventh_layer_comptree
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_7th (
            .max_min(inter_vld_max),
            .a_in(d6[2*i]),
            .b_in(d6[2*i+1]),
            .d_out(d7),
            .pos()
        );
    end
    endgenerate

    wire [4*FP24_WIDTH-1:0] norm_out;
    reg [3:0] adder_tree_vld_r;
    reg [3:0] pre_process_vld_r;

    generate
    for(i=0; i<4; i=i+1) begin : MEAN_COMPUTE_LOOP
        wire [MIN_GROUP_WIDTH*MANT_OUT_WIDTH-1:0] mant_out;
        wire [EXP_WIDTH-1:0] exp_out;

        pre_process_concat #(
            .DATA_WIDTH(PRECISION),
            .DATA_NUM(MIN_GROUP_WIDTH),
            .SIGN_WIDTH(SIGN_WIDTH),
            .EXP_WIDTH (EXP_WIDTH),
            .MANT_WIDTH(MANT_WIDTH)
        ) u_pre_process_mean (
            .d_in(d_in[i*MIN_GROUP_WIDTH*PRECISION +: MIN_GROUP_WIDTH*PRECISION]),
            .exp_out(exp_out),
            .mant_out(mant_out)
        );

        reg [MIN_GROUP_WIDTH*MANT_OUT_WIDTH-1:0] mant_out_r;
        reg [EXP_WIDTH-1:0] exp_out_r;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                mant_out_r <= {(MIN_GROUP_WIDTH*MANT_OUT_WIDTH){1'b0}};
                exp_out_r  <= {EXP_WIDTH{1'b0}};
                pre_process_vld_r[i]  <= 1'b0;
            end
            else begin
                pre_process_vld_r[i]  <= in_vld;
                if (in_vld) begin
                    mant_out_r  <= mant_out;
                    exp_out_r <= exp_out;
                end
            end
        end

        wire [TREE_OUT_WIDTH-1:0] adder_tree_out;

        adder_tree_concat #(
            .DATA_WIDTH_IN(MANT_OUT_WIDTH),
            .DATA_WIDTH_OUT(TREE_OUT_WIDTH),
            .DIMENSION(MIN_GROUP_WIDTH)
        ) u_adder_tree (
            .d_in(mant_out_r),
            .d_out(adder_tree_out)
        );

        reg [TREE_OUT_WIDTH-1:0] adder_tree_out_r;
        reg [EXP_WIDTH-1:0] exp_delay_r;

        always @ (posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                adder_tree_out_r <= {TREE_OUT_WIDTH{1'b0}};
                exp_delay_r <= {EXP_WIDTH{1'b0}};
                adder_tree_vld_r[i] <= 1'b0;
            end
            else begin
                adder_tree_vld_r[i] <= pre_process_vld_r[i];
                if (pre_process_vld_r[i]) begin
                    adder_tree_out_r <= adder_tree_out;
                    exp_delay_r <= exp_out_r;
                end
            end
        end

        norm_round_concat #(
            .MANT_WIDTH_IN(TREE_OUT_WIDTH),
            .EXP_WIDTH_IN(EXP_WIDTH),
            .MANT_WIDTH_OUT(FP24_MANT_W)
        ) u_norm_round (
            .exp_in(exp_delay_r),
            .mant_in(adder_tree_out_r),
            .d_out(norm_out[i*FP24_WIDTH +: FP24_WIDTH])
        );
    end
    endgenerate

    wire [2*FP24_WIDTH-1:0] first_add_out;
    wire [FP24_WIDTH-1:0]   second_add_out;

    reg [4*FP24_WIDTH-1:0] norm_out_r;
    reg norm_out_vld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            norm_out_r <= {4*FP24_WIDTH{1'b0}};
            norm_out_vld_r <= 1'b0;
        end else begin
            norm_out_vld_r <= |adder_tree_vld_r;
            if (|adder_tree_vld_r) begin
                norm_out_r <= norm_out;
            end
        end
    end

    wire [FP24_WIDTH-1:0] norm_out_div32_fp24  [3:0];
    wire [FP24_WIDTH-1:0] first_add_div64_fp24 [1:0];
    wire [FP24_WIDTH-1:0] second_add_div128_fp24;

    generate
    for (i=0; i<4; i=i+1) begin : DIV32_ADJUST
        wire [7:0] orig_exp = norm_out_r[i*FP24_WIDTH + 22 -: 8];
        wire [7:0] adj_exp  = (orig_exp >= 8'd5) ? (orig_exp - 8'd5) : 8'd0;
        assign norm_out_div32_fp24[i] = {
            norm_out_r[i*FP24_WIDTH + 23],
            adj_exp,
            norm_out_r[i*FP24_WIDTH + 14 -: 15]
        };
    end
    endgenerate

    generate
    for (i=0; i<2; i=i+1) begin : DIV64_ADJUST
        wire [7:0] orig_exp = first_add_out[i*FP24_WIDTH + 22 -: 8];
        wire [7:0] adj_exp  = (orig_exp >= 8'd6) ? (orig_exp - 8'd6) : 8'd0;
        assign first_add_div64_fp24[i] = {
            first_add_out[i*FP24_WIDTH + 23],
            adj_exp,
            first_add_out[i*FP24_WIDTH + 14 -: 15]
        };
    end
    endgenerate

    wire [7:0] second_orig_exp = second_add_out[22 -: 8];
    wire [7:0] second_adj_exp  = (second_orig_exp >= 8'd7) ? (second_orig_exp - 8'd7) : 8'd0;
    assign second_add_div128_fp24 = {
        second_add_out[23],
        second_adj_exp,
        second_add_out[14 -: 15]
    };

    wire [PRECISION-1:0] norm_out_div32_bf16  [3:0];
    wire [PRECISION-1:0] first_add_div64_bf16 [1:0];
    wire [PRECISION-1:0] second_add_div128_bf16;

    generate
    for (i=0; i<4; i=i+1) begin : DIV32_ROUND_BF16
        fp24_to_bf16_round u_round_div32 (
            .d_in (norm_out_div32_fp24[i]),
            .d_out(norm_out_div32_bf16[i])
        );
    end
    endgenerate

    generate
    for (i=0; i<2; i=i+1) begin : DIV64_ROUND_BF16
        fp24_to_bf16_round u_round_div64 (
            .d_in (first_add_div64_fp24[i]),
            .d_out(first_add_div64_bf16[i])
        );
    end
    endgenerate

    fp24_to_bf16_round u_round_div128 (
        .d_in (second_add_div128_fp24),
        .d_out(second_add_div128_bf16)
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mean_out <= {4*PRECISION{1'b0}};
        end
        else begin
            if (norm_out_vld_r) begin
                mean_out <= group_size == 2'b01 ? {norm_out_div32_bf16[3], norm_out_div32_bf16[2], norm_out_div32_bf16[1], norm_out_div32_bf16[0]} :
                        group_size == 2'b10 ? {16'b0, first_add_div64_bf16[1], 16'b0, first_add_div64_bf16[0]} :
                        group_size == 2'b11 ? {48'b0, second_add_div128_bf16} :
                        {4*PRECISION{1'b0}};
            end
        end
    end

    generate
    for(i=0; i<2; i=i+1) begin : FIRST_ADD_STAGE
        DW_fp_add_inst #(
            .sig_width (FP24_MANT_W),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_first_add (
            .inst_a    (norm_out_r[(2*i+1)*FP24_WIDTH +: FP24_WIDTH]),
            .inst_b    (norm_out_r[(2*i)*FP24_WIDTH +: FP24_WIDTH]),
            .inst_rnd  (3'b000),
            .z_inst    (first_add_out[i*FP24_WIDTH +: FP24_WIDTH]),
            .status_inst ()
        );
    end
    endgenerate

    DW_fp_add_inst #(
        .sig_width (FP24_MANT_W),
        .exp_width (8),
        .ieee_compliance (0)
    ) u_second_add (
        .inst_a    (first_add_out[FP24_WIDTH +: FP24_WIDTH]),
        .inst_b    (first_add_out[0 +: FP24_WIDTH]),
        .inst_rnd  (3'b000),
        .z_inst    (second_add_out),
        .status_inst ()
    );

endmodule
