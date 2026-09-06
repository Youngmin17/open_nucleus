// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module lzd_8bit(
    input [7:0] d_in,
    output reg [7:0] d_out
    );

    always @ (*)
        casez (d_in)
            8'b1??????? :  d_out = 8'b00000000;
            8'b01?????? :  d_out = 8'b00000001;
            8'b001????? :  d_out = 8'b00000010;
            8'b0001???? :  d_out = 8'b00000011;
            8'b00001??? :  d_out = 8'b00000100;
            8'b000001?? :  d_out = 8'b00000101;
            8'b0000001? :  d_out = 8'b00000110;
            8'b00000001 :  d_out = 8'b00000111;
            default     :  d_out = 8'b00001000;
        endcase
endmodule

