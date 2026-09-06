// SPDX-License-Identifier: Apache-2.0
`ifndef QUANT_VERIFY
`timescale 1ns / 1ps
`endif

module scale_zerop
#(
    parameter PREC         = 16,
    parameter DATA_NUM     = 128
)
(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 indicate_kv,
    input  wire                 in_vld,

    input  wire [4*PREC-1:0]    max_value,
    input  wire [4*PREC-1:0]    min_value,
    input  wire [4*PREC-1:0]    outlier_excluded_max_value,
    input  wire [4*PREC-1:0]    outlier_excluded_min_value,
    input  wire [4*PREC-1:0]    mean_value,
    input  wire [DATA_NUM-1:0]  outlier_pos,
    input  wire [DATA_NUM*PREC-1:0] outlier_val,

    output wire                 out_vld,
    output reg [4*PREC-1:0]     scale_fp_prec2,
    output reg [4*PREC-1:0]     scale_fp_prec4,
    output reg [4*PREC-1:0]     scale_fp_prec8,
    output reg [4*PREC-1:0]     scale_int_prec2,
    output reg [4*PREC-1:0]     scale_int_prec4,
    output reg [4*PREC-1:0]     scale_int_prec8,
    output reg [4*PREC-1:0]     zerop_fp,
    output reg [4*PREC-1:0]     zerop_int,
    output reg [DATA_NUM-1:0]   outlier_pos_out,
    output reg [DATA_NUM*PREC-1:0] outlier_val_out
);

    genvar i;

    localparam IPREC = 24;

    localparam [IPREC-1:0] LUT_1_3   = {1'b0, 8'h7D, 7'b0101010, 8'b10101011};
    localparam [IPREC-1:0] LUT_1_15  = {1'b0, 8'h7B, 7'b0001000, 8'b10001001};
    localparam [IPREC-1:0] LUT_1_255 = {1'b0, 8'h77, 7'b0000000, 8'b10000001};

    localparam ZP_SIGN_WIDTH = 1;
    localparam ZP_EXP_WIDTH  = 8;
    localparam ZP_MANT_WIDTH = 15;
    localparam ZP_MANT_OUT_WIDTH = 17;

    localparam  ST_IDLE  = 3'd0,
                ST_PRESCALE = 3'd1,
                ST_EXP = 3'd2,
                ST_HALF = 3'd3;

    reg [3:0] out_vld_r;
    assign out_vld = &(out_vld_r);

    reg [DATA_NUM-1:0] outlier_pos_r1, outlier_pos_r2;
    reg [DATA_NUM*PREC-1:0] outlier_val_r1, outlier_val_r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outlier_pos_r1 <= {DATA_NUM{1'b0}};
            outlier_pos_r2 <= {DATA_NUM{1'b0}};
            outlier_pos_out <= {DATA_NUM{1'b0}};
            outlier_val_r1 <= {DATA_NUM*PREC{1'b0}};
            outlier_val_r2 <= {DATA_NUM*PREC{1'b0}};
            outlier_val_out <= {DATA_NUM*PREC{1'b0}};
        end else begin
            outlier_pos_r1 <= outlier_pos;
            outlier_pos_r2 <= outlier_pos_r1;
            outlier_pos_out <= outlier_pos_r2;
            outlier_val_r1 <= outlier_val;
            outlier_val_r2 <= outlier_val_r1;
            outlier_val_out <= outlier_val_r2;
        end
    end

    generate
    for(i=0; i<4; i=i+1) begin : GEN_SCALE_ZP
        reg [2:0] state;
        reg [IPREC-1:0] fp_max_reg, fp_min_reg, int_max_reg, int_min_reg;
        wire [IPREC-1:0] addsub_out_fp, mult_out_fp_prec8, mult_out_fp_prec4, mult_out_fp_prec2;
        reg [IPREC-1:0] addsub_out_fp_reg;
        wire [IPREC-1:0] addsub_out_int, mult_out_int_prec8, mult_out_int_prec4, mult_out_int_prec2;
        reg [IPREC-1:0] addsub_out_int_reg;
        reg FLAG;

        wire [IPREC-1:0] fp_max_fp24  = {max_value[i*PREC+PREC-1], max_value[i*PREC+PREC-2:i*PREC+7], max_value[i*PREC+6:i*PREC], 8'b0};
        wire [IPREC-1:0] fp_min_fp24  = {min_value[i*PREC+PREC-1], min_value[i*PREC+PREC-2:i*PREC+7], min_value[i*PREC+6:i*PREC], 8'b0};
        wire [IPREC-1:0] int_max_fp24 = {outlier_excluded_max_value[i*PREC+PREC-1], outlier_excluded_max_value[i*PREC+PREC-2:i*PREC+7], outlier_excluded_max_value[i*PREC+6:i*PREC], 8'b0};
        wire [IPREC-1:0] int_min_fp24 = {outlier_excluded_min_value[i*PREC+PREC-1], outlier_excluded_min_value[i*PREC+PREC-2:i*PREC+7], outlier_excluded_min_value[i*PREC+6:i*PREC], 8'b0};
        wire [IPREC-1:0] mean_fp24    = {mean_value[i*PREC+PREC-1], mean_value[i*PREC+PREC-2:i*PREC+7], mean_value[i*PREC+6:i*PREC], 8'b0};

        always @(*) begin
            if (!rst_n) begin
                FLAG = 1'b0;
            end else if (in_vld && rst_n) begin
                FLAG = 1'b1;
            end else begin
                FLAG = 1'b0;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                fp_max_reg <= {IPREC{1'b0}};
                fp_min_reg <= {IPREC{1'b0}};
                int_max_reg <= {IPREC{1'b0}};
                int_min_reg <= {IPREC{1'b0}};
                scale_int_prec2[i*PREC +: PREC] <= {PREC{1'b0}};
                scale_int_prec4[i*PREC +: PREC] <= {PREC{1'b0}};
                scale_int_prec8[i*PREC +: PREC] <= {PREC{1'b0}};
                scale_fp_prec2[i*PREC +: PREC] <= {PREC{1'b0}};
                scale_fp_prec4[i*PREC +: PREC] <= {PREC{1'b0}};
                scale_fp_prec8[i*PREC +: PREC] <= {PREC{1'b0}};
                zerop_fp[i*PREC +: PREC] <= {PREC{1'b0}};
                zerop_int[i*PREC +: PREC] <= {PREC{1'b0}};
                state <= ST_IDLE;
                addsub_out_fp_reg <= {IPREC{1'b0}};
                addsub_out_int_reg <= {IPREC{1'b0}};
                out_vld_r[i] <= 1'b0;

            end else begin
                out_vld_r[i] <= 1'b0;
                case(state)
                    ST_IDLE: begin
                        if (FLAG) begin
                            fp_max_reg <= fp_max_fp24;
                            fp_min_reg <= fp_min_fp24;
                            int_max_reg <= int_max_fp24;
                            int_min_reg <= int_min_fp24;
                            zerop_fp[i*PREC +: PREC] <= mean_value[i*PREC +: PREC];
                            zerop_int[i*PREC +: PREC] <= !indicate_kv ? outlier_excluded_min_value[i*PREC +: PREC] : min_value[i*PREC +: PREC];
                            state <= ST_PRESCALE;
                        end else begin
                            fp_max_reg <= {IPREC{1'b0}};
                            fp_min_reg <= {IPREC{1'b0}};
                            zerop_fp[i*PREC +: PREC] <= {PREC{1'b0}};
                            zerop_int[i*PREC +: PREC] <= {PREC{1'b0}};
                            state <= ST_IDLE;
                        end
                    end

                    ST_PRESCALE: begin
                        state <= ST_EXP;
                        addsub_out_fp_reg <= addsub_out_fp;
                        addsub_out_int_reg <= addsub_out_int;
                    end

                    ST_EXP: begin
                        scale_fp_prec2[i*PREC +: PREC] <= (mult_out_fp_prec2[14:0] > 15'h3504 && mult_out_fp_prec2[22:15] != 8'hFF) ? {8'b0, mult_out_fp_prec2[22:15] + 1} : {8'b0, mult_out_fp_prec2[22:15]};
                        scale_fp_prec4[i*PREC +: PREC] <= (mult_out_fp_prec4[14:0] > 15'h3504 && mult_out_fp_prec4[22:15] != 8'hFF) ? {8'b0, mult_out_fp_prec4[22:15] + 1} : {8'b0, mult_out_fp_prec4[22:15]};
                        scale_fp_prec8[i*PREC +: PREC] <= (mult_out_fp_prec8[14:0] > 15'h3504 && mult_out_fp_prec8[22:15] != 8'hFF) ? {8'b0, mult_out_fp_prec8[22:15] + 1} : {8'b0, mult_out_fp_prec8[22:15]};
                        scale_int_prec2[i*PREC +: PREC] <= (mult_out_int_prec2[14:0] > 15'h3504 && mult_out_int_prec2[22:15] != 8'hFF) ? {8'b0, mult_out_int_prec2[22:15] + 1} : {8'b0, mult_out_int_prec2[22:15]};
                        scale_int_prec4[i*PREC +: PREC] <= (mult_out_int_prec4[14:0] > 15'h3504 && mult_out_int_prec4[22:15] != 8'hFF) ? {8'b0, mult_out_int_prec4[22:15] + 1} : {8'b0, mult_out_int_prec4[22:15]};
                        scale_int_prec8[i*PREC +: PREC] <= (mult_out_int_prec8[14:0] > 15'h3504 && mult_out_int_prec8[22:15] != 8'hFF) ? {8'b0, mult_out_int_prec8[22:15] + 1} : {8'b0, mult_out_int_prec8[22:15]};
                        state <= ST_IDLE;
                        out_vld_r[i] <= 1'b1;
                    end
                endcase
            end
        end

        DW_fp_addsub_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) U_fp_scale_sub (
            .inst_a    (fp_max_reg),
            .inst_b    (fp_min_reg),
            .inst_rnd  (3'b000),
            .inst_op   (1'b1),
            .z_inst    (addsub_out_fp),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_fp_prec8 (
            .inst_a    (addsub_out_fp_reg),
            .inst_b    (LUT_1_255),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_fp_prec8),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_fp_prec4 (
            .inst_a    (addsub_out_fp_reg),
            .inst_b    (LUT_1_15),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_fp_prec4),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_fp_prec2 (
            .inst_a    (addsub_out_fp_reg),
            .inst_b    (LUT_1_3),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_fp_prec2),
            .status_inst ()
        );

        DW_fp_addsub_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) U_int_scale_sub (
            .inst_a    (int_max_reg),
            .inst_b    (int_min_reg),
            .inst_rnd  (3'b000),
            .inst_op   (1'b1),
            .z_inst    (addsub_out_int),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_int_prec8 (
            .inst_a    (addsub_out_int_reg),
            .inst_b    (LUT_1_255),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_int_prec8),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_int_prec4 (
            .inst_a    (addsub_out_int_reg),
            .inst_b    (LUT_1_15),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_int_prec4),
            .status_inst ()
        );

        DW_fp_mult_inst #(
            .sig_width (15),
            .exp_width (8),
            .ieee_compliance (0)
        ) u_gen_scale_int_prec2 (
            .inst_a    (addsub_out_int_reg),
            .inst_b    (LUT_1_3),
            .inst_rnd  (3'b000),
            .z_inst    (mult_out_int_prec2),
            .status_inst ()
        );
    end
    endgenerate

endmodule
