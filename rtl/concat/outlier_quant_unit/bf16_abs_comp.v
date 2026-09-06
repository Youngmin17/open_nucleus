// SPDX-License-Identifier: Apache-2.0
module bf16_abs_comp #(
    parameter DATA_WIDTH = 16
)
(
    input wire [DATA_WIDTH-2:0] a,
    input wire [DATA_WIDTH-2:0] b,
    output wire a_greater_b,
    output wire a_equal_b
);

assign a_greater_b = (a > b);
assign a_equal_b   = (a == b);

endmodule