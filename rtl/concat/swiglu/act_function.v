// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module act_function
(
    input wire clk,
    input wire rst_n,
    input wire in_vld,
    input wire [15:0] gate_in,
    input wire [15:0] val_in,
    output wire swig_out_vld,
    output wire [15:0] swig_out
);
    localparam BF16_ONE = 16'h3F80;

    reg [15:0] val_in_r1, val_in_r2;

    wire [15:0] d_in_invert;
    assign d_in_invert = {~gate_in[15], gate_in[14:0]};

    wire [15:0] exp_out;
    reg [15:0] exp_out_r;
    reg exp_out_vld_r;

    DW_fp_exp_inst #(
        .inst_sig_width (7),
        .inst_exp_width (8),
        .inst_ieee_compliance (1),
        .inst_arch (2)
    ) u_dw_fp_exp_inst(
        .inst_a     (d_in_invert),
        .z_inst     (exp_out),
        .status_inst()
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_out_r <= 16'd0;
            exp_out_vld_r <= 1'b0;
            val_in_r1 <= 16'd0;
        end
        else begin
            val_in_r1 <= val_in;
            if (in_vld) begin
                exp_out_r <= exp_out;
                exp_out_vld_r <= 1'b1;
            end else begin
                exp_out_r <= 16'd0;
                exp_out_vld_r <= 1'b0;
            end
        end
    end

    wire [15:0] add_out;
    reg [15:0] add_out_r;
    reg add_out_vld_r;

    DW_fp_add_inst #(
        .sig_width(7),
        .exp_width(8),
        .ieee_compliance(1)
    ) u_DW_fp_add_inst (
        .inst_a(exp_out_r),
        .inst_b(BF16_ONE),
        .inst_rnd(3'b000),
        .z_inst(add_out),
        .status_inst()
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add_out_r <= 16'd0;
            add_out_vld_r <= 1'b0;
            val_in_r2 <= 16'd0;
        end
        else begin
            val_in_r2 <= val_in_r1;
            if (exp_out_vld_r) begin
                add_out_r <= add_out;
                add_out_vld_r <= 1'b1;
            end
            else begin
                add_out_r <= 16'd0;
                add_out_vld_r <= 1'b0;
            end
        end
    end

    wire [15:0] div_out;
    reg [15:0] div_out_r;
    reg div_out_vld_r;

    DW_fp_div_inst #(
        .sig_width(7),
        .exp_width(8),
        .ieee_compliance(1)
    ) u_DW_fp_div_inst (
        .inst_a(val_in_r2),
        .inst_b(add_out_r),
        .inst_rnd(3'b000),
        .z_inst(div_out),
        .status_inst()
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_out_r <= 16'd0;
            div_out_vld_r <= 1'b0;
        end
        else begin
            if (add_out_vld_r) begin
                div_out_r <= div_out;
                div_out_vld_r <= 1'b1;
            end
            else begin
                div_out_r <= 16'd0;
                div_out_vld_r <= 1'b0;
            end
        end
    end

    assign swig_out = div_out_r;
    assign swig_out_vld = div_out_vld_r;

endmodule