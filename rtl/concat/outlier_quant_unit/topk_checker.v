// SPDX-License-Identifier: Apache-2.0

module topk_checker #(
    parameter DATA_NUM = 128,
    parameter DATA_WIDTH  = 16
)
(
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH*DATA_NUM-1:0] b,
    input wire [6:0] k,
    input wire [$clog2(DATA_NUM)-1:0] my_pos,
    output wire valid
);

    wire greater_bits [DATA_NUM-1:0];
    wire [1:0] greater_bits_add_1st [DATA_NUM/2-1:0];
    wire [2:0] greater_bits_add_2nd [DATA_NUM/4-1:0];
    wire [3:0] greater_bits_add_3rd [DATA_NUM/8-1:0];
    wire [4:0] greater_bits_add_4th [DATA_NUM/16-1:0];
    wire [5:0] greater_bits_add_5th [DATA_NUM/32-1:0];
    wire [6:0] greater_bits_add_6th [DATA_NUM/64-1:0];
    wire [7:0] greater_bits_add_7th;

    wire equal_bits [DATA_NUM-1:0];
    wire masked_equal_bits [DATA_NUM-1:0];
    wire [1:0] equal_bits_add_1st [DATA_NUM/2-1:0];
    wire [2:0] equal_bits_add_2nd [DATA_NUM/4-1:0];
    wire [3:0] equal_bits_add_3rd [DATA_NUM/8-1:0];
    wire [4:0] equal_bits_add_4th [DATA_NUM/16-1:0];
    wire [5:0] equal_bits_add_5th [DATA_NUM/32-1:0];
    wire [6:0] equal_bits_add_6th [DATA_NUM/64-1:0];
    wire [7:0] equal_bits_add_7th;

    genvar i;

    generate
    for(i=0; i<DATA_NUM; i=i+1) begin : abs_comp_gen
        bf16_abs_comp #(
            .DATA_WIDTH(DATA_WIDTH)
        ) u_bf16_abs_comp (
            .a(a[DATA_WIDTH-2:0]),
            .b(b[DATA_WIDTH*i+:DATA_WIDTH-1]),
            .a_greater_b(greater_bits[i]),
            .a_equal_b(equal_bits[i])
        );
        assign masked_equal_bits[i] = equal_bits[i] & (i > my_pos);
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/2; i=i+1) begin : bits_add_1st
        assign greater_bits_add_1st[i] = greater_bits[2*i] + greater_bits[2*i+1];
        assign equal_bits_add_1st[i] = masked_equal_bits[2*i] + masked_equal_bits[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/4; i=i+1) begin : bits_add_2nd
        assign greater_bits_add_2nd[i] = greater_bits_add_1st[2*i] + greater_bits_add_1st[2*i+1];
        assign equal_bits_add_2nd[i] = equal_bits_add_1st[2*i] + equal_bits_add_1st[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/8; i=i+1) begin : bits_add_3rd
        assign greater_bits_add_3rd[i] = greater_bits_add_2nd[2*i] + greater_bits_add_2nd[2*i+1];
        assign equal_bits_add_3rd[i] = equal_bits_add_2nd[2*i] + equal_bits_add_2nd[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/16; i=i+1) begin : bits_add_4th
        assign greater_bits_add_4th[i] = greater_bits_add_3rd[2*i] + greater_bits_add_3rd[2*i+1];
        assign equal_bits_add_4th[i] = equal_bits_add_3rd[2*i] + equal_bits_add_3rd[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/32; i=i+1) begin : bits_add_5th
        assign greater_bits_add_5th[i] = greater_bits_add_4th[2*i] + greater_bits_add_4th[2*i+1];
        assign equal_bits_add_5th[i] = equal_bits_add_4th[2*i] + equal_bits_add_4th[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/64; i=i+1) begin : bits_add_6th
        assign greater_bits_add_6th[i] = greater_bits_add_5th[2*i] + greater_bits_add_5th[2*i+1];
        assign equal_bits_add_6th[i] = equal_bits_add_5th[2*i] + equal_bits_add_5th[2*i+1];
    end
    endgenerate

    assign greater_bits_add_7th = greater_bits_add_6th[0] + greater_bits_add_6th[1];
    assign equal_bits_add_7th = equal_bits_add_6th[0] + equal_bits_add_6th[1];

    assign valid = (greater_bits_add_7th + equal_bits_add_7th >= 8'd128-k);

endmodule