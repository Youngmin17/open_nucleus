// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module bf16_cos_ip_wrap
(
    input clk,
    input rst_n,
    input a_vld,
    input [15:0] a_in,
    output out_vld,
    output [15:0] d_out
);
    reg [15:0] a_in_r;
    reg [15:0] d_out_r;
    reg out_vld_buf;
    reg out_vld_r;

    wire [15:0] tmp_out;
    wire [7:0] status_cos;

    always @ (posedge clk) begin
        if (! rst_n) begin
            a_in_r <= 16'b0;
            out_vld_buf <= 1'b0;
        end
        else if (a_vld) begin
            a_in_r <= a_in;
            out_vld_buf <= a_vld;
        end
        else begin
            a_in_r <= 16'b0;
            out_vld_buf <= 1'b0;
        end
    end

    DW_fp_sincos_inst #(
        .sig_width(7),
        .exp_width(8),
        .ieee_compliance(1),
        .pi_multiple(0),
        .arch(0),
        .err_range(1)
    ) u_DW_fp_sincos_inst (
        .inst_a(a_in_r),
        .inst_sin_cos(1'b1),
        .z_inst(tmp_out),
        .status_inst(status_cos)
        );

    always @ (posedge clk) begin
        if (! rst_n) begin
            d_out_r <= 16'b0;
            out_vld_r <= 1'b0;
        end
        else if (out_vld_buf) begin
            d_out_r <= tmp_out;
            out_vld_r <= out_vld_buf;
        end
        else begin
            d_out_r <= 16'b0;
            out_vld_r <= 1'b0;
        end
    end

    assign d_out = d_out_r;
    assign out_vld = out_vld_r;

endmodule

