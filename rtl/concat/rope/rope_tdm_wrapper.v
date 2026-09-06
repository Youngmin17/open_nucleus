// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module rope_tdm_wrapper #(
    parameter DATA_WIDTH = 16,
    parameter DATA_NUM   = 128,
    parameter LOOP_NUM   = 4
)(
    input  wire                           clk,
    input  wire                           rst_n,

    input  wire                           data_in_vld,

    input  wire [DATA_WIDTH*DATA_NUM-1:0] data_in,
    input  wire [31:0]                    token_pos,

    output reg  [DATA_WIDTH*DATA_NUM-1:0] data_out,
    output reg                            data_out_vld
);

    localparam DIM = DATA_NUM / LOOP_NUM;
    localparam PAIRS_PER_CYCLE = DIM / 2;
    localparam PIPE_DEPTH = 14;

    reg [DATA_WIDTH*DATA_NUM-1:0] data_buffer;
    reg [15:0] token_pos_buffer;

    wire [PAIRS_PER_CYCLE-1:0] rope_out_vld_a;
    wire [PAIRS_PER_CYCLE-1:0] rope_out_vld_b;
    wire [DATA_WIDTH-1:0] rope_out_a [PAIRS_PER_CYCLE-1:0];
    wire [DATA_WIDTH-1:0] rope_out_b [PAIRS_PER_CYCLE-1:0];
    wire [5:0]            rope_idx_out [PAIRS_PER_CYCLE-1:0];

    reg rope_in_vld;
    reg [6:0] loop_cnt;

    reg [2:0] out_batch_cnt;
    wire      first_rope_out_vld = rope_out_vld_a[0] & rope_out_vld_b[0];

    wire [15:0] token_pos_bf16;
    DW_fp_i2flt #(
        .sig_width(7),
        .exp_width(8),
        .isize(32),
        .isign(0)
    ) u_int_to_bf16 (
        .a(token_pos),
        .rnd(3'b000),
        .z(token_pos_bf16),
        .status()
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_cnt <= 7'd0;
            data_buffer <= {DATA_WIDTH*DATA_NUM{1'b0}};
            token_pos_buffer <= 16'd0;
            rope_in_vld <= 1'b0;
            data_out_vld <= 1'b0;
            out_batch_cnt <= 3'd0;
        end else begin
            data_out_vld <= 1'b0;

            if (first_rope_out_vld) begin
                if (out_batch_cnt == LOOP_NUM[2:0] - 3'd1) begin
                    out_batch_cnt <= 3'd0;
                    data_out_vld  <= 1'b1;
                end else begin
                    out_batch_cnt <= out_batch_cnt + 3'd1;
                end
            end

            if (loop_cnt == 7'd1) begin
                loop_cnt <= 7'd0;
                rope_in_vld <= 1'b0;
                if (data_in_vld) begin
                    data_buffer <= data_in;
                    token_pos_buffer <= token_pos_bf16;
                    loop_cnt <= LOOP_NUM;
                    rope_in_vld <= 1'b1;
                end
            end else if (loop_cnt > 7'd1) begin
                loop_cnt <= loop_cnt - 7'd1;
            end else begin
                if (data_in_vld) begin
                    data_buffer <= data_in;
                    token_pos_buffer <= token_pos_bf16;
                    loop_cnt <= LOOP_NUM;
                    rope_in_vld <= 1'b1;
                end
            end
        end
    end

    integer idx;
    genvar gi;

    generate
    for (gi = 0; gi < PAIRS_PER_CYCLE; gi = gi + 1) begin : GEN_ROPE

        wire [6:0] pair_idx_full = gi + PAIRS_PER_CYCLE * (loop_cnt - 7'd1);
        wire [5:0] pair_idx = pair_idx_full[5:0];

        wire [6:0] a_elem_idx = {pair_idx, 1'b0};
        wire [6:0] b_elem_idx = {pair_idx, 1'b0} + 7'd1;
        wire [11:0] a_bit_offset = {5'b0, a_elem_idx} * DATA_WIDTH;
        wire [11:0] b_bit_offset = {5'b0, b_elem_idx} * DATA_WIDTH;
        wire [DATA_WIDTH-1:0] a_in = data_buffer[a_bit_offset +: DATA_WIDTH];
        wire [DATA_WIDTH-1:0] b_in = data_buffer[b_bit_offset +: DATA_WIDTH];

        rope u_rope (
            .clk                (clk),
            .rst_n              (rst_n),
            .in_vld             (rope_in_vld),
            .idx_in             (pair_idx),
            .a_in               (a_in),
            .b_in               (b_in),
            .token_pos          (token_pos_buffer),
            .d_out_vld_a        (rope_out_vld_a[gi]),
            .d_out_vld_b        (rope_out_vld_b[gi]),
            .d_out_a            (rope_out_a[gi]),
            .d_out_b            (rope_out_b[gi]),
            .idx_out            (rope_idx_out[gi])
        );

        wire [5:0] out_pair_idx = rope_idx_out[gi];
        wire rope_out_vld_pair = rope_out_vld_a[gi] & rope_out_vld_b[gi];

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for (idx = 0; idx < LOOP_NUM; idx = idx + 1) begin
                    data_out[((gi + idx * PAIRS_PER_CYCLE) * 2)     * DATA_WIDTH +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                    data_out[((gi + idx * PAIRS_PER_CYCLE) * 2 + 1) * DATA_WIDTH +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                end
            end else if (rope_out_vld_pair) begin
                for (idx = 0; idx < LOOP_NUM; idx = idx + 1) begin
                    if (out_pair_idx == gi + idx * PAIRS_PER_CYCLE) begin
                        data_out[((gi + idx * PAIRS_PER_CYCLE) * 2)     * DATA_WIDTH +: DATA_WIDTH] <= rope_out_a[gi];
                        data_out[((gi + idx * PAIRS_PER_CYCLE) * 2 + 1) * DATA_WIDTH +: DATA_WIDTH] <= rope_out_b[gi];
                    end
                end
            end
        end
    end
    endgenerate

endmodule

`default_nettype wire
