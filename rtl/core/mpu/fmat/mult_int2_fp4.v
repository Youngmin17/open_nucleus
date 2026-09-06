// SPDX-License-Identifier: Apache-2.0
module mult_int2_fp4 (
    input wire [15:0] a,
    input wire [3:0] b,
    input wire [7:0] scale,
    input wire m,
    output wire [15:0] d_out
);

    wire        sign_a = a[15];
    wire        sign_b = b[3];
    wire [7:0]  exp_a = a[14:7];
    wire [1:0]  exp_b = b[2:1];
    wire [6:0]  mant_a = a[6:0];
    wire        mant_b = b[0];

    wire        sign_fp4 = sign_a ^ sign_b;

    wire zero_a = (exp_a == 8'd0);
    wire zero_b_fp4 = (exp_b == 2'd0);

    wire signed [11:0] exp_fp4_calc = $signed({4'b0, exp_a}) + $signed({10'b0, exp_b}) - $signed(12'd1) + $signed({4'b0, scale}) - $signed(12'd127);

    wire [7:0] mant_a_ext = zero_a ? 8'd0 : {1'b1, mant_a};
    wire [1:0] mant_b_ext_fp4 = zero_b_fp4 ? {1'b0, mant_b} : {1'b1, mant_b};

    wire [9:0] mant_prod_fp4 = mant_a_ext * mant_b_ext_fp4;

    wire norm_fp4 = mant_prod_fp4[9];
    wire [6:0] mant_res_fp4 =   mant_prod_fp4[9] ?  mant_prod_fp4[8:2] :
                                mant_prod_fp4[8] ?  mant_prod_fp4[7:1] :
                                                    mant_prod_fp4[6:0];
    wire signed [11:0] exp_res_fp4 = exp_fp4_calc + norm_fp4;

    wire [7:0] exp_final_fp4 = (zero_a || b[2:0] == 3'd0) ? 8'd0 :
                               (exp_res_fp4 < 0) ? 8'd0 :
                               (exp_res_fp4 > 255) ? 8'd255 : exp_res_fp4[7:0];

    wire [6:0] mant_final_fp4 = (exp_final_fp4 == 8'd0) ? 7'd0 : mant_res_fp4;
    wire sign_final_fp4 = (exp_final_fp4 == 8'd0) ? 1'b0 : sign_fp4;

    assign d_out = {sign_final_fp4, exp_final_fp4, mant_final_fp4};

endmodule