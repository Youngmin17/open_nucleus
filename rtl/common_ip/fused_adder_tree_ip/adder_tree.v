// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire

module adder_tree
#(
    parameter DATA_WIDTH_IN  = 17,
    parameter DATA_WIDTH_OUT = 24,
    parameter DIMENSION      = 128
)
(
    input signed [DIMENSION*DATA_WIDTH_IN-1:0] d_in,
    output signed [DATA_WIDTH_OUT-1:0]         d_out
);

    genvar i;
    wire signed [DATA_WIDTH_IN-1:0] d_in_w [DIMENSION-1:0];

    generate
      for (i=0; i<DIMENSION; i=i+1)
      begin : UNPACK_D_IN
        assign d_in_w[i] = d_in[(DATA_WIDTH_IN*i+DATA_WIDTH_IN-1):(DATA_WIDTH_IN*i)];
      end
    endgenerate

    wire signed [DATA_WIDTH_IN:0] layer1 [63:0];
    generate
    for (i=0; i<64; i=i+1) begin : LAYER1
        assign layer1[i] = d_in_w[2*i] + d_in_w[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+1:0] layer2 [31:0];
    generate
    for (i=0; i<32; i=i+1) begin : LAYER2
        assign layer2[i] = layer1[2*i] + layer1[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+2:0] layer3 [15:0];
    generate
    for (i=0; i<16; i=i+1) begin : LAYER3
        assign layer3[i] = layer2[2*i] + layer2[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+3:0] layer4 [7:0];
    generate
    for (i=0; i<8; i=i+1) begin : LAYER4
        assign layer4[i] = layer3[2*i] + layer3[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+4:0] layer5 [3:0];
    generate
    for (i=0; i<4; i=i+1) begin : LAYER5
        assign layer5[i] = layer4[2*i] + layer4[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+5:0] layer6 [1:0];
    generate
    for (i=0; i<2; i=i+1) begin : LAYER6
        assign layer6[i] = layer5[2*i] + layer5[2*i+1];
    end
    endgenerate

    wire signed [DATA_WIDTH_IN+6:0] layer7;
    assign layer7 = layer6[0] + layer6[1];

    assign d_out  =  layer7;
endmodule