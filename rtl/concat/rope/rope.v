// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module rope
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_vld,
    input  wire [5:0]  idx_in,
    input  wire [15:0] a_in,
    input  wire [15:0] b_in,
    input  wire [15:0] token_pos,
    output reg         d_out_vld_a,
    output reg         d_out_vld_b,
    output reg  [15:0] d_out_a,
    output reg  [15:0] d_out_b,
    output reg  [5:0]  idx_out
);

    wire [31:0] theta_fp32;

    theta_lut_rom u_theta_lut (
        .d_in  (idx_in),
        .d_out (theta_fp32)
    );

    wire [31:0] token_fp32     = {token_pos,     16'b0};
    wire [31:0] a_in_fp32      = {a_in,          16'b0};
    wire [31:0] b_in_fp32      = {b_in,          16'b0};

    reg [31:0] theta_r1,  token_r1;
    reg [31:0] a_r1,      b_r1;
    reg        vld_r1;
    reg [5:0]  idx_r1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            theta_r1 <= 32'd0;  token_r1 <= 32'd0;
            a_r1     <= 32'd0;  b_r1     <= 32'd0;
            vld_r1   <= 1'b0;   idx_r1   <= 6'd0;
        end else begin
            theta_r1 <= in_vld ? theta_fp32 : 32'd0;
            token_r1 <= in_vld ? token_fp32 : 32'd0;
            a_r1     <= in_vld ? a_in_fp32  : 32'd0;
            b_r1     <= in_vld ? b_in_fp32  : 32'd0;
            vld_r1   <= in_vld;
            idx_r1   <= idx_in;
        end
    end

    wire [31:0] radian_fp32;
    wire        radian_vld;

    DW_fp32_mult_pipe u_mult_radian (
        .clk    (clk),
        .rst_n  (rst_n),
        .a      (token_r1),
        .b      (theta_r1),
        .rnd    (3'b000),
        .in_vld (vld_r1),
        .z      (radian_fp32),
        .out_vld(radian_vld)
    );

    reg [31:0] a_r2, b_r2;
    reg [5:0]  idx_r2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin a_r2 <= 32'd0; b_r2 <= 32'd0; idx_r2 <= 6'd0; end
        else        begin a_r2 <= a_r1;  b_r2 <= b_r1;  idx_r2 <= idx_r1; end
    end

    reg [31:0] a_r3, b_r3;
    reg [31:0] radian_r3;
    reg        vld_r3;
    reg [5:0]  idx_r3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r3      <= 32'd0;  b_r3      <= 32'd0;
            radian_r3 <= 32'd0;  vld_r3    <= 1'b0;
            idx_r3    <= 6'd0;
        end else begin
            a_r3      <= a_r2;
            b_r3      <= b_r2;
            radian_r3 <= radian_fp32;
            vld_r3    <= radian_vld;
            idx_r3    <= idx_r2;
        end
    end

    wire [31:0] cos_fp32, sin_fp32;
    wire        cos_vld,  sin_vld;

    DW_fp32_sincos_pipe u_sincos_cos (
        .clk     (clk),
        .rst_n   (rst_n),
        .a       (radian_r3),
        .sin_cos (1'b1),
        .in_vld  (vld_r3),
        .z       (cos_fp32),
        .out_vld (cos_vld)
    );

    DW_fp32_sincos_pipe u_sincos_sin (
        .clk     (clk),
        .rst_n   (rst_n),
        .a       (radian_r3),
        .sin_cos (1'b0),
        .in_vld  (vld_r3),
        .z       (sin_fp32),
        .out_vld (sin_vld)
    );

    reg [31:0] a_pipe [0:6];
    reg [31:0] b_pipe [0:6];
    reg [5:0]  idx_pipe [0:6];
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 7; k = k + 1) begin
                a_pipe[k]   <= 32'd0;
                b_pipe[k]   <= 32'd0;
                idx_pipe[k] <= 6'd0;
            end
        end else begin
            a_pipe[0]   <= a_r3;
            b_pipe[0]   <= b_r3;
            idx_pipe[0] <= idx_r3;
            for (k = 1; k < 7; k = k + 1) begin
                a_pipe[k]   <= a_pipe[k-1];
                b_pipe[k]   <= b_pipe[k-1];
                idx_pipe[k] <= idx_pipe[k-1];
            end
        end
    end

    reg [31:0] cos_r9, sin_r9, neg_sin_r9;
    reg [31:0] a_r9,   b_r9;
    reg        vld_r9;
    reg [5:0]  idx_r9;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cos_r9     <= 32'd0;
            sin_r9     <= 32'd0;
            neg_sin_r9 <= 32'd0;
            a_r9       <= 32'd0;
            b_r9       <= 32'd0;
            vld_r9     <= 1'b0;
            idx_r9     <= 6'd0;
        end else begin
            cos_r9     <= cos_fp32;
            sin_r9     <= sin_fp32;
            neg_sin_r9 <= {~sin_fp32[31], sin_fp32[30:0]};
            a_r9       <= a_pipe[6];
            b_r9       <= b_pipe[6];
            vld_r9     <= cos_vld;
            idx_r9     <= idx_pipe[6];
        end
    end

    wire [31:0] m0_fp32, m1_fp32, m2_fp32, m3_fp32;
    wire        m0_vld,  m1_vld,  m2_vld,  m3_vld;

    DW_fp32_mult_pipe u_mult_a_cos (
        .clk    (clk),   .rst_n  (rst_n),
        .a      (a_r9),  .b      (cos_r9),
        .rnd    (3'b000), .in_vld (vld_r9),
        .z      (m0_fp32), .out_vld(m0_vld)
    );

    DW_fp32_mult_pipe u_mult_b_negsin (
        .clk    (clk),   .rst_n  (rst_n),
        .a      (b_r9),  .b      (neg_sin_r9),
        .rnd    (3'b000), .in_vld (vld_r9),
        .z      (m1_fp32), .out_vld(m1_vld)
    );

    DW_fp32_mult_pipe u_mult_a_sin (
        .clk    (clk),   .rst_n  (rst_n),
        .a      (a_r9),  .b      (sin_r9),
        .rnd    (3'b000), .in_vld (vld_r9),
        .z      (m2_fp32), .out_vld(m2_vld)
    );

    DW_fp32_mult_pipe u_mult_b_cos (
        .clk    (clk),   .rst_n  (rst_n),
        .a      (b_r9),  .b      (cos_r9),
        .rnd    (3'b000), .in_vld (vld_r9),
        .z      (m3_fp32), .out_vld(m3_vld)
    );

    reg [5:0] idx_r10;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) idx_r10 <= 6'd0;
        else        idx_r10 <= idx_r9;
    end

    reg [31:0] m0_r, m1_r, m2_r, m3_r;
    reg        vld_r11;
    reg [5:0]  idx_r11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m0_r    <= 32'd0;  m1_r    <= 32'd0;
            m2_r    <= 32'd0;  m3_r    <= 32'd0;
            vld_r11 <= 1'b0;   idx_r11 <= 6'd0;
        end else begin
            m0_r    <= m0_fp32;   m1_r    <= m1_fp32;
            m2_r    <= m2_fp32;   m3_r    <= m3_fp32;
            vld_r11 <= m0_vld;    idx_r11 <= idx_r10;
        end
    end

    wire [31:0] a_out_fp32, b_out_fp32;

    DW_fp32_add_inst u_add_a (
        .a   (m0_r),  .b   (m1_r),
        .rnd (3'b000),
        .z   (a_out_fp32), .status()
    );

    DW_fp32_add_inst u_add_b (
        .a   (m2_r),  .b   (m3_r),
        .rnd (3'b000),
        .z   (b_out_fp32), .status()
    );

    wire [15:0] a_out_bf16 = a_out_fp32[31:16];
    wire [15:0] b_out_bf16 = b_out_fp32[31:16];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_out_a     <= 16'b0;
            d_out_b     <= 16'b0;
            d_out_vld_a <= 1'b0;
            d_out_vld_b <= 1'b0;
            idx_out     <= 6'd0;
        end else begin
            d_out_a     <= vld_r11 ? a_out_bf16 : 16'b0;
            d_out_b     <= vld_r11 ? b_out_bf16 : 16'b0;
            d_out_vld_a <= vld_r11;
            d_out_vld_b <= vld_r11;
            idx_out     <= idx_r11;
        end

    end

// synopsys translate_off
`ifdef KVPROBE
    integer rp_cnt; initial rp_cnt = 0;
    reg [31:0] rp_a_r10, rp_b_r10, rp_cos_r10, rp_sin_r10, rp_a_r11, rp_b_r11, rp_cos_r11, rp_sin_r11;
    always @(posedge clk) begin
        rp_a_r10 <= a_r9; rp_b_r10 <= b_r9; rp_cos_r10 <= cos_r9; rp_sin_r10 <= sin_r9;
        rp_a_r11 <= rp_a_r10; rp_b_r11 <= rp_b_r10; rp_cos_r11 <= rp_cos_r10; rp_sin_r11 <= rp_sin_r10;
        if (vld_r11 && rp_cnt < 40000) begin
            rp_cnt = rp_cnt + 1;
            $display("[ROPEP] t=%0t n=%0d idx=%0d a=%08h b=%08h cos=%08h sin=%08h m0=%08h m1=%08h m2=%08h m3=%08h aout=%08h bout=%08h",
                     $time, rp_cnt, idx_r11, rp_a_r11, rp_b_r11, rp_cos_r11, rp_sin_r11, m0_r, m1_r, m2_r, m3_r, a_out_fp32, b_out_fp32);
        end
    end
`endif
// synopsys translate_on

endmodule
