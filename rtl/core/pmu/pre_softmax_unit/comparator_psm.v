// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module comparator_psm #(
    parameter DATA_WIDTH = 8
)(
    input  wire                 a_vld,
    input  wire                 b_vld,
    input  wire [DATA_WIDTH-1:0] a_in,
    input  wire [DATA_WIDTH-1:0] b_in,
    output wire                  out_vld,
    output wire  [DATA_WIDTH-1:0] d_out
);

    assign d_out = (a_in >= b_in) ? a_in : b_in;
    assign out_vld = a_vld & b_vld;

endmodule

