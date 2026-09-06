// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

`ifndef __BF16_DIV_IP_WRAP_V__
`define __BF16_DIV_IP_WRAP_V__
module bf16_div_ip_wrap
(
    input clk,
    input rst_n,
    input a_vld,
    input b_vld,
    input [15:0] a_in,
    input [15:0] b_in,
    output out_vld,
    output [15:0] d_out
);
    reg [15:0] a_in_r;
    reg [15:0] b_in_r;
    reg [15:0] d_out_r;
    reg out_vld_buf;
    reg out_vld_r;

    wire [15:0] tmp_out;
    wire [7:0] status_mult;

    always @ (posedge clk) begin
        if (! rst_n) begin
            a_in_r <= 16'b0;
            b_in_r <= 16'b0;
            out_vld_buf <= 1'b0;
        end
        else if (a_vld && b_vld) begin
            a_in_r <= a_in;
            b_in_r <= b_in;
            out_vld_buf <= a_vld && b_vld;
        end
        else begin
            a_in_r <= 16'b0;
            b_in_r <= 16'b0;
            out_vld_buf <= 1'b0;
        end
    end

    DW_fp_div_inst #(
        .sig_width(7),
        .exp_width(8),
        .ieee_compliance(1)
    ) u_DW_fp_div_inst (
        .inst_a(a_in_r),
        .inst_b(b_in_r),
        .inst_rnd(3'b000),
        .z_inst(tmp_out),
        .status_inst(status_mult)
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

`endif
