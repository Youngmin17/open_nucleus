// SPDX-License-Identifier: Apache-2.0
module mult_int4_fp8 (
    input wire [15:0] a,
    input wire [7:0] b,
    input wire [7:0] scale,
    input wire m,
    output wire [15:0] d_out
);

    wire [15:0] d_out_fp8;

    wire        sign_a = a[15];
    wire [7:0]  exp_a = a[14:7];
    wire [6:0]  mant_a = a[6:0];
    wire        zero_a = (exp_a == 8'd0);
    wire [7:0]  mant_a_ext = zero_a ? 8'd0 : {1'b1, mant_a};

    wire        sign_b_fp8 = b[7];
    wire [3:0]  exp_b_fp8  = b[6:3];
    wire [2:0]  mant_b_fp8 = b[2:0];

    wire zero_b_fp8 = (exp_b_fp8 == 4'd0);
    wire [3:0] mant_b_ext_fp8 = zero_b_fp8 ? {1'b0, mant_b_fp8} : {1'b1, mant_b_fp8};

    wire        sign_res_fp8 = sign_a ^ sign_b_fp8;

    wire signed [11:0] exp_calc_fp8 = $signed({4'b0, exp_a}) + $signed({8'b0, exp_b_fp8}) + $signed({4'b0, scale}) - $signed(12'd134);

    wire [11:0] mant_prod_fp8 = mant_a_ext * mant_b_ext_fp8;

    wire norm_fp8 = mant_prod_fp8[11];

    wire [6:0] mant_res_fp8 =   mant_prod_fp8[11] ?  mant_prod_fp8[10:4] :
                                mant_prod_fp8[10] ?  mant_prod_fp8[9:3] :
                                mant_prod_fp8[9]  ?  mant_prod_fp8[8:2] :
                                mant_prod_fp8[8]  ?  mant_prod_fp8[7:1] :
                                                     mant_prod_fp8[6:0];

    wire [2:0] norm_shift = mant_prod_fp8[11] ? 3'd0 :
                            mant_prod_fp8[10] ? 3'd0 :
                            mant_prod_fp8[9]  ? 3'd1 :
                            mant_prod_fp8[8]  ? 3'd2 :
                                                3'd3;

    wire signed [11:0] exp_norm_fp8 = exp_calc_fp8 + norm_fp8 - $signed({9'd0, norm_shift});

    wire [7:0] exp_final_fp8 = (zero_a || b[6:0] == 7'd0) ? 8'd0 :
                               (exp_norm_fp8 < 0) ? 8'd0 :
                               (exp_norm_fp8 > 255) ? 8'd255 : exp_norm_fp8[7:0];

    wire [6:0] mant_final_fp8 = (exp_final_fp8 == 8'd0) ? 7'd0 : mant_res_fp8;
    wire sign_final_fp8 = (exp_final_fp8 == 8'd0) ? 1'b0 : sign_res_fp8;

    assign d_out_fp8 = {sign_final_fp8, exp_final_fp8, mant_final_fp8};

    assign d_out = d_out_fp8;

endmodule