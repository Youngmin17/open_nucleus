// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps

`define RE(x) fp_to_real(sig_width, exp_width, {{(64-sig_width-exp_width-1){1'b0}}, x})
`define QF(v) real_to_fp(sig_width, exp_width, v)

module DW_fp_mult #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter en_ubr_flag = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input [2:0] rnd, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(`RE(a) * `RE(b));
  assign status = 8'h00;
endmodule

module DW_fp_add #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter en_ubr_flag = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input [2:0] rnd, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(`RE(a) + `RE(b));
  assign status = 8'h00;
endmodule

module DW_fp_sub #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter en_ubr_flag = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input [2:0] rnd, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(`RE(a) - `RE(b));
  assign status = 8'h00;
endmodule

module DW_fp_cmp #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input zctr, output aeqb, output altb, output agtb, output unordered,
   output [sig_width+exp_width:0] z0, output [sig_width+exp_width:0] z1,
   output [7:0] status0, output [7:0] status1 );
  `include "fp_funcs.vh"
  wire signed_lt = (`RE(a) < `RE(b));
  wire signed_gt = (`RE(a) > `RE(b));
  assign aeqb      = (`RE(a) == `RE(b));
  assign altb      = signed_lt;
  assign agtb      = signed_gt;
  assign unordered = 1'b0;
  assign z0 = zctr ? (signed_lt ? b : a) : (signed_lt ? a : b);
  assign z1 = zctr ? (signed_lt ? a : b) : (signed_lt ? b : a);
  assign status0 = 8'h00;
  assign status1 = 8'h00;
endmodule

module DW_fp_addsub #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter en_ubr_flag = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input [2:0] rnd, input op, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = op ? `QF(`RE(a) - `RE(b)) : `QF(`RE(a) + `RE(b));
  assign status = 8'h00;
endmodule

module DW_fp_exp2 #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter arch = 2
)( input [sig_width+exp_width:0] a, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(2.0 ** `RE(a));
  assign status = 8'h00;
endmodule

module DW_fp_div #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter faithful_round = 0, parameter en_ubr_flag = 0
)( input [sig_width+exp_width:0] a, input [sig_width+exp_width:0] b,
   input [2:0] rnd, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = (`RE(b) == 0.0)
             ? ((a[sig_width+exp_width] ^ b[sig_width+exp_width])
                 ? {1'b1, {exp_width{1'b1}}, {sig_width{1'b0}}}
                 : {1'b0, {exp_width{1'b1}}, {sig_width{1'b0}}})
             : `QF(`RE(a) / `RE(b));
  assign status = 8'h00;
endmodule

module DW_fp_sqrt #(
    parameter sig_width = 7, parameter exp_width = 8, parameter ieee_compliance = 0
)( input [sig_width+exp_width:0] a, input [2:0] rnd,
   output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = (`RE(a) <= 0.0) ? {(sig_width+exp_width+1){1'b0}}
                             : `QF(`RE(a) ** 0.5);
  assign status = 8'h00;
endmodule

module DW_fp_exp #(
    parameter sig_width = 7, parameter exp_width = 8,
    parameter ieee_compliance = 0, parameter arch = 2
)( input [sig_width+exp_width:0] a, output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(2.71828182845904523536 ** `RE(a));
  assign status = 8'h00;
endmodule

module DW_fp_sincos #(
    parameter sig_width = 7, parameter exp_width = 8, parameter ieee_compliance = 0,
    parameter pi_multiple = 1, parameter arch = 0, parameter err_range = 1
)( input [sig_width+exp_width:0] a, input sin_cos,
   output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = sin_cos
    ? `QF($cos((pi_multiple != 0) ? `RE(a) * 3.14159265358979323846 : `RE(a)))
    : `QF($sin((pi_multiple != 0) ? `RE(a) * 3.14159265358979323846 : `RE(a)));
  assign status = 8'h00;
endmodule

module DW_fp_i2flt #(
    parameter sig_width = 7, parameter exp_width = 8, parameter isize = 32, parameter isign = 0
)( input [isize-1:0] a, input [2:0] rnd,
   output [sig_width+exp_width:0] z, output [7:0] status );
  `include "fp_funcs.vh"
  assign z = `QF(isign ? $itor($signed(a)) : $itor(a));
  assign status = 8'h00;
endmodule
