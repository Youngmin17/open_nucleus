// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module bf16_exp_ip_wrap
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
    wire [7:0] status_exp;

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

    DW_fp_exp_inst #(
        .inst_sig_width(7),
        .inst_exp_width(8),
        .inst_ieee_compliance(1),
        .inst_arch(2)
    ) u_DW_fp_exp_inst (
        .inst_a(a_in_r),
        .z_inst(tmp_out),
        .status_inst(status_exp)
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

