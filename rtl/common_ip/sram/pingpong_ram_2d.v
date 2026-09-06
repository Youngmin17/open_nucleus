// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module pingpong_ram_2d
# (
    parameter num_rams = 1,
    parameter w = 2048,
    parameter d = 128
)
(
    input clk,
    input rst_n,

    input wen_A,
    input [num_rams*$clog2(d)-1:0] write_addr_A,
    input [num_rams*w-1:0] din_A,
    input ren_A,
    input [num_rams*$clog2(d)-1:0] read_addr_A,
    output [num_rams*$clog2(d)-1:0] read_addr_r_A,
    output dout_vld_A,
    output [num_rams*w-1:0] dout_A,

    input wen_B,
    input [num_rams*$clog2(d)-1:0] write_addr_B,
    input [num_rams*w-1:0] din_B,
    input ren_B,
    input [num_rams*$clog2(d)-1:0] read_addr_B,
    output [num_rams*$clog2(d)-1:0] read_addr_r_B,
    output dout_vld_B,
    output [num_rams*w-1:0] dout_B
);

    ram_2d # (
      .num_rams(num_rams),
      .w(w),
      .d(d)
    )
    u_ram_2d_A (
      .clk(clk),
      .rst_n(rst_n),
      .wen(wen_A),
      .write_addr(write_addr_A),
      .din(din_A),
      .ren(ren_A),
      .read_addr(read_addr_A),
      .read_addr_r(read_addr_r_A),
      .dout_vld(dout_vld_A),
      .dout(dout_A)
    );

    ram_2d # (
      .num_rams(num_rams),
      .w(w),
      .d(d)
    )
    u_ram_2d_B (
      .clk(clk),
      .rst_n(rst_n),
      .wen(wen_B),
      .write_addr(write_addr_B),
      .din(din_B),
      .ren(ren_B),
      .read_addr(read_addr_B),
      .read_addr_r(read_addr_r_B),
      .dout_vld(dout_vld_B),
      .dout(dout_B)
    );

endmodule
