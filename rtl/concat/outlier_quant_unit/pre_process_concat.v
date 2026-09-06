// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module pre_process_concat
#(  parameter DATA_WIDTH = 16,
    parameter DATA_NUM = 32,
    parameter SIGN_WIDTH = 1,
    parameter EXP_WIDTH = 8,
    parameter MANT_WIDTH = 7
)
(
    input [DATA_NUM*DATA_WIDTH-1:0] d_in,
    output [EXP_WIDTH-1:0] exp_out,
    output [17*DATA_NUM-1:0] mant_out
    );

    localparam MANT_OUT_WIDTH = (1+MANT_WIDTH)*2+SIGN_WIDTH;

    wire sign_w [DATA_NUM-1:0];
    wire [MANT_WIDTH-1:0] mant_w [DATA_NUM-1:0];
    wire zero [DATA_NUM-1:0];
    wire [SIGN_WIDTH+MANT_WIDTH-1:0] one_mant_w [DATA_NUM-1:0];

    wire [EXP_WIDTH-1:0] exp_w [DATA_NUM-1:0];
    wire [MANT_OUT_WIDTH-1:0] mant_2s_w [DATA_NUM-1:0];
    wire [MANT_OUT_WIDTH-2:0] shift_mant [DATA_NUM-1:0];

    wire [EXP_WIDTH-1:0] comp_1st_w [(DATA_NUM>>1)-1:0];
    wire [EXP_WIDTH-1:0] comp_2nd_w [(DATA_NUM>>2)-1:0];
    wire [EXP_WIDTH-1:0] comp_3rd_w [(DATA_NUM>>3)-1:0];
    wire [EXP_WIDTH-1:0] comp_4th_w [(DATA_NUM>>4)-1:0];
    wire [EXP_WIDTH-1:0] comp_5th_w [(DATA_NUM>>5)-1:0];
    wire [EXP_WIDTH-1:0] comp_out;

    genvar i;

    generate
    for (i=0; i<DATA_NUM; i=i+1)
    begin : GENERATE_PRE_ALIGNMENT
        assign sign_w[i] = d_in[(DATA_WIDTH*i)+(DATA_WIDTH-1)];
        assign exp_w[i]= d_in[(DATA_WIDTH*i)+((EXP_WIDTH+MANT_WIDTH)-1):(DATA_WIDTH*i)+MANT_WIDTH];
        assign mant_w[i] = d_in[(DATA_WIDTH*i)+(MANT_WIDTH-1):(DATA_WIDTH*i)];
        assign zero[i] = ~(|exp_w[i]) & ~(|mant_w[i]);
        assign one_mant_w[i] = (zero[i]) ? 8'b0 : {1'b1, mant_w[i]};
    end
    endgenerate

    generate
        for (i=0; i<(DATA_NUM>>1); i=i+1)
        begin : L1
            assign comp_1st_w[i] = (exp_w[2*i] >= exp_w[2*i+1]) ? exp_w[2*i] : exp_w[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<(DATA_NUM>>2); i=i+1)
        begin : L2
            assign comp_2nd_w[i] = (comp_1st_w[2*i] >= comp_1st_w[2*i+1]) ? comp_1st_w[2*i] : comp_1st_w[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<(DATA_NUM>>3); i=i+1)
        begin : L3
            assign comp_3rd_w[i] = (comp_2nd_w[2*i] >= comp_2nd_w[2*i+1]) ? comp_2nd_w[2*i] : comp_2nd_w[2*i+1];
        end
    endgenerate

    generate
        for (i=0; i<(DATA_NUM>>4); i=i+1)
        begin : L4
            assign comp_4th_w[i] = (comp_3rd_w[2*i] >= comp_3rd_w[2*i+1]) ? comp_3rd_w[2*i] : comp_3rd_w[2*i+1];
        end
    endgenerate

    assign comp_out = ((comp_4th_w[0] >= comp_4th_w[1]) ? comp_4th_w[0] : comp_4th_w[1]);

    generate
    for (i=0; i<DATA_NUM; i=i+1)
    begin : LEADING_BIT_MANTISSA_SHIFT
        exp_sub_mant_shift_concat #(
            .DATA_WIDTH_EXP(EXP_WIDTH),
            .DATA_WIDTH_MANT(MANT_WIDTH+1),
            .DATA_WIDTH_OUT(MANT_OUT_WIDTH-1)
        )   u_exp_sub_mant_shift
        (
            .mant_in(one_mant_w[i]),
            .max_exp(comp_out),
            .exp_op(exp_w[i]),
            .shift_mant(shift_mant[i])
        );
    end
    endgenerate

    generate
    for (i=0; i<DATA_NUM; i=i+1)
    begin : TWOS_COMPLEMENT
        wire effective_sign = sign_w[i] && (|shift_mant[i]);

        comp_2s_concat #(
            .DATA_WIDTH_IN(MANT_OUT_WIDTH-1),
            .DATA_WIDTH_OUT(MANT_OUT_WIDTH)
        )   u_comp_2s
        (
            .sign_in(effective_sign),
            .shift_mant_in(shift_mant[i]),
            .comp_2s_out(mant_2s_w[i])
        );
    end
    endgenerate

generate
for (i=0; i<DATA_NUM; i=i+1)
begin : GENERATE_VECTOR_COMB
    assign mant_out[(MANT_OUT_WIDTH*i)+(MANT_OUT_WIDTH-1):(MANT_OUT_WIDTH*i)] = mant_2s_w[i];
end
endgenerate

assign exp_out = comp_out;

endmodule