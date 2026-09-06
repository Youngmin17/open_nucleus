// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module mult_8x2_fmat(
  input  [7:0] a,
  input  [1:0] b,
  output [9:0] d_out
);
  wire [9:0] a1 = {2'b00, a};
  wire [9:0] a2 = {1'b0, a, 1'b0};

  wire [9:0] pp0 = a1 & {10{b[0]}};
  wire [9:0] pp1 = a2 & {10{b[1]}};

  assign d_out = pp0 + pp1;
endmodule

