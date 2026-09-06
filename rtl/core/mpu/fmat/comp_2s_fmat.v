// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module comp_2s_fmat
#(  parameter DATA_WIDTH_IN = 16,
    parameter DATA_WIDTH_OUT = 17

)
(
    input sign_in,
    input [DATA_WIDTH_IN-1:0] shift_mant_in,
    output [DATA_WIDTH_OUT-1:0] comp_2s_out
);

    wire [DATA_WIDTH_IN-1:0] comp_2s_w;

    assign comp_2s_w = (sign_in) ? ~shift_mant_in + 1'b1 : shift_mant_in;
    assign comp_2s_out = {sign_in, comp_2s_w};

endmodule
