// SPDX-License-Identifier: Apache-2.0

function real fp_to_real(input integer SIG, input integer EXP, input [63:0] w);
  integer s, e, bias; reg [63:0] mant; real m;
  begin
    bias = (1 << (EXP-1)) - 1;
    s    = w[SIG+EXP];
    e    = (w >> SIG) & ((1 << EXP) - 1);
    mant = w & ((64'd1 << SIG) - 1);
    if (e == 0) begin
      fp_to_real = 0.0;
    end else if (e == ((1 << EXP) - 1)) begin
      fp_to_real = s ? -1.0e300 : 1.0e300;
    end else begin
      m = 1.0 + $itor(mant) / (2.0 ** SIG);
      fp_to_real = (2.0 ** (e - bias)) * m;
      if (s) fp_to_real = -fp_to_real;
    end
  end
endfunction

function [63:0] real_to_fp(input integer SIG, input integer EXP, input real x);
  integer s, e, bias, expmax; real ax, frac, scaled, fl, half; reg [63:0] mant;
  begin
    bias   = (1 << (EXP-1)) - 1;
    expmax = (1 << EXP) - 1;
    if (x == 0.0) begin
      real_to_fp = 64'd0;
    end else if (x != x) begin
      real_to_fp = 64'd0;
    end else if ((x > 3.0e38) || (x < -3.0e38)) begin
      real_to_fp = ((x < 0.0) ? (64'd1 << (SIG+EXP)) : 64'd0) | (((64'd1 << EXP) - 1) << SIG);
    end else begin
      s = (x < 0.0) ? 1 : 0;
      ax = s ? -x : x;
      e = 0;
      while (ax >= 2.0) begin ax = ax / 2.0; e = e + 1; end
      while (ax <  1.0) begin ax = ax * 2.0; e = e - 1; end
      e = e + bias;
      frac   = ax - 1.0;
      scaled = frac * (2.0 ** SIG);
      fl     = $floor(scaled);
      half   = scaled - fl;
      mant   = $rtoi(fl);
      if (half > 0.5)            mant = mant + 1;
      else if (half == 0.5)      mant = mant + (mant & 64'd1);
      if (mant == (64'd1 << SIG)) begin mant = 0; e = e + 1; end
      if (e <= 0)
        real_to_fp = (s ? (64'd1 << (SIG+EXP)) : 64'd0);
      else if (e >= expmax)
        real_to_fp = ({1'b0, {8{1'b0}}} | ((64'd1 << (SIG+EXP)) & (s ? -64'd1 : 64'd0)))
                     | (((64'd1 << EXP) - 1) << SIG);
      else
        real_to_fp = ((s ? (64'd1 << (SIG+EXP)) : 64'd0))
                     | ((e[63:0] & ((64'd1 << EXP) - 1)) << SIG)
                     | (mant & ((64'd1 << SIG) - 1));
    end
  end
endfunction
