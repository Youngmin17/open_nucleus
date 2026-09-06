// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module gqa_scheduler #(
    parameter ADDR_WIDTH   = 64,
    parameter DATA_WIDTH   = 256,
    parameter CORE_NUM     = 4,
    parameter AXI_CHANNELS = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start_all,
    input  wire                    isa_valid,

    input  wire                    is_gemm_mode,
    input  wire [6:0]              outlier_num,

    input  wire [ADDR_WIDTH-1:0]   op_a_addr,
    input  wire [ADDR_WIDTH-1:0]   op_b_addr,
    input  wire [ADDR_WIDTH-1:0]   qkv_head_addr_offset,

    input  wire [4:0]              op_a_prec,
    input  wire [4:0]              op_b_prec,
    input  wire [4:0]              op_c_prec,

    input  wire [31:0]             seq_len,
    input  wire [6:0]              q_head_num,
    input  wire [6:0]              kv_head_num,
    input  wire [5:0]              group_size,
    input  wire [1:0]              group_width,
    input  wire [15:0]             window_size,

    input  wire [6:0]              k_tile_dense_burst_length,
    input  wire [6:0]              v_tile_dense_burst_length,
    input  wire [6:0]              szp_burst_length,
    input  wire [22:0]             bundle_num,
    input  wire [6:0]              gemv_gqa_bundle_burst_length,

    input  wire                    dma_arready,
    input  wire                    dma_read_done,

    input  wire                    concat_phase_done,

    output reg                     start_read,
    output reg  [ADDR_WIDTH-1:0]   read_init_addr,
    output reg  [7:0]              read_burst_length,

    output reg                     vec_load_start,

    output wire                    idle_state
);

    localparam [7:0]            Q_BURST     = 8'd32;
    localparam [ADDR_WIDTH-1:0] Q_ADDR_STEP = 64'd1024;

    wire [ADDR_WIDTH-1:0] k_tile_addr_step = {{(ADDR_WIDTH-7){1'b0}}, k_tile_dense_burst_length} << 5;
    wire k_out = is_gemm_mode && (outlier_num != 7'd0);
    wire [ADDR_WIDTH-1:0] kmask_step = k_out ? k_tile_addr_step : {ADDR_WIDTH{1'b0}};
    wire [ADDR_WIDTH-1:0] v_tile_addr_step = {{(ADDR_WIDTH-7){1'b0}}, v_tile_dense_burst_length} << 5;

    reg [15:0] seq_tiles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            seq_tiles <= 16'd0;
        else if (isa_valid)
            seq_tiles <= seq_len[22:7];
    end

    wire [2:0] szp_interval = (group_width == 2'b01) ? 3'd2 : 3'd4;

    localparam ST_IDLE         = 4'd0;
    localparam ST_GEMM_Q_READ  = 4'd1;
    localparam ST_GEMM_Q_WAIT  = 4'd2;
    localparam ST_GEMM_K_READ  = 4'd3;
    localparam ST_GEMM_K_WAIT  = 4'd4;
    localparam ST_GEMM_V_READ  = 4'd5;
    localparam ST_GEMM_V_WAIT  = 4'd6;
    localparam ST_GEMV_READ    = 4'd7;
    localparam ST_GEMV_WAIT    = 4'd8;
    localparam ST_GEMV_CHUNK   = 4'd11;
    localparam ST_GEMM_CONCAT_WAIT = 4'd10;
    localparam ST_GAP          = 4'd9;

    reg [3:0] state;

    reg [6:0]  cur_kv_head;
    reg [5:0]  cur_q_in_group;
    reg [15:0] cur_q_block_row;
    reg [15:0] cur_kv_tile;

    wire [15:0] window_tiles = {7'd0, window_size[15:7]};
    wire [15:0] kv_start = (window_tiles != 16'd0 && cur_q_block_row >= window_tiles)
                           ? (cur_q_block_row - window_tiles + 16'd1) : 16'd0;
    reg        reading_v;

    reg [6:0]  gemv_kv_head;
    reg [22:0] gemv_bundle_idx;
    reg [9:0]              gemv_words_left;
    reg [ADDR_WIDTH-1:0]   gemv_chunk_addr;

    wire [22:0] window_bundles = (window_size == 16'd0) ? 23'd0
                               : ({16'd0, window_size[15:9]} + {22'd0, |window_size[8:0]});
    wire [22:0] gemv_bundle_start = (window_bundles != 23'd0 && bundle_num > window_bundles)
                                    ? (bundle_num - window_bundles) : 23'd0;

    reg [1:0]  gap_cnt;
    reg [3:0]  return_state;

    wire [15:0] q_head_idx = {{(9){1'b0}}, cur_kv_head} * {{(10){1'b0}}, group_size} + {{(10){1'b0}}, cur_q_in_group};
    wire [ADDR_WIDTH-1:0] q_tile_addr = op_a_addr +
        {{(ADDR_WIDTH-16){1'b0}}, q_head_idx} * qkv_head_addr_offset +
        {{(ADDR_WIDTH-16){1'b0}}, cur_q_block_row} * Q_ADDR_STEP;

    wire [ADDR_WIDTH-1:0] kv_pair_size = kmask_step + k_tile_addr_step + v_tile_addr_step;
    wire [ADDR_WIDTH-1:0] szp_addr_size = {{(ADDR_WIDTH-7){1'b0}}, szp_burst_length} << 5;

    wire [15:0] szp_count = (group_width == 2'b01) ?
        (cur_kv_tile[15:1] + 16'd1) :
        (cur_kv_tile[15:2] + 16'd1);

    wire [ADDR_WIDTH-1:0] k_tile_offset =
        {{(ADDR_WIDTH-16){1'b0}}, szp_count} * szp_addr_size +
        {{(ADDR_WIDTH-16){1'b0}}, cur_kv_tile} * kv_pair_size;

    wire [ADDR_WIDTH-1:0] v_tile_offset = k_tile_offset + kmask_step + k_tile_addr_step;

    wire [15:0] gqa_szp_per_head = (((seq_tiles - 16'd1) >>
                                    ((group_width == 2'b01) ? 4'd1 : 4'd2)) + 16'd1);
    wire [ADDR_WIDTH-1:0] kv_head_stride =
        {{(ADDR_WIDTH-16){1'b0}}, seq_tiles} * kv_pair_size +
        {{(ADDR_WIDTH-16){1'b0}}, gqa_szp_per_head} * szp_addr_size;
    wire [ADDR_WIDTH-1:0] kv_head_base = op_b_addr +
        {{(ADDR_WIDTH-7){1'b0}}, cur_kv_head} * kv_head_stride;

    wire [ADDR_WIDTH-1:0] k_tile_addr = kv_head_base + k_tile_offset;
    wire [ADDR_WIDTH-1:0] v_tile_addr = kv_head_base + v_tile_offset;

    wire k_needs_szp = (group_width == 2'b01) ?
        (cur_kv_tile[0] == 1'b0) :
        (cur_kv_tile[1:0] == 2'b00);

    wire [7:0] kmask_burst = k_out ? {1'b0, k_tile_dense_burst_length} : 8'd0;
    wire [7:0] k_burst = k_needs_szp ?
        ({1'b0, k_tile_dense_burst_length} + {1'b0, szp_burst_length} + kmask_burst) :
        ({1'b0, k_tile_dense_burst_length} + kmask_burst);

    wire [ADDR_WIDTH-1:0] k_read_addr = k_needs_szp ?
        (k_tile_addr - szp_addr_size) : k_tile_addr;

    wire [9:0] gemv_bundle_words =
        ({3'b0, k_tile_dense_burst_length} << 2) +
        ({3'b0, v_tile_dense_burst_length} << 2) +
        ((group_width == 2'b01) ? {2'b0, szp_burst_length, 1'b0}
                                : {3'b0, szp_burst_length});

    wire [ADDR_WIDTH-1:0] gemv_bundle_addr = op_b_addr +
        {{(ADDR_WIDTH-7){1'b0}}, gemv_kv_head} * qkv_head_addr_offset +
        {{(ADDR_WIDTH-23){1'b0}}, gemv_bundle_idx} *
        ({{(ADDR_WIDTH-10){1'b0}}, gemv_bundle_words} << 5);

    assign idle_state = (state == ST_IDLE) ||
                        (state == ST_GEMM_CONCAT_WAIT && concat_phase_done &&
                         (cur_q_block_row == seq_tiles - 16'd1) &&
                         (cur_kv_head == kv_head_num - 7'd1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            cur_kv_head       <= 7'd0;
            cur_q_in_group    <= 6'd0;
            cur_q_block_row   <= 16'd0;
            cur_kv_tile       <= 16'd0;
            reading_v         <= 1'b0;
            gemv_kv_head      <= 7'd0;
            gemv_bundle_idx   <= 23'd0;
            gemv_words_left   <= 10'd0;
            gemv_chunk_addr   <= {ADDR_WIDTH{1'b0}};
            gap_cnt           <= 2'd0;
            return_state      <= ST_IDLE;
            start_read        <= 1'b0;
            read_init_addr    <= {ADDR_WIDTH{1'b0}};
            read_burst_length <= 8'd0;
            vec_load_start    <= 1'b0;
        end else begin

            vec_load_start <= 1'b0;

            if (start_read && dma_arready)
                start_read <= 1'b0;

            if (isa_valid) begin
                state           <= ST_IDLE;
                cur_kv_head     <= 7'd0;
                cur_q_in_group  <= 6'd0;
                cur_q_block_row <= 16'd0;
                cur_kv_tile     <= 16'd0;
                reading_v       <= 1'b0;
                gemv_kv_head    <= 7'd0;
                gemv_bundle_idx <= 23'd0;
            end else begin

            case (state)
                ST_IDLE: begin
                    if (start_all) begin
                        if (is_gemm_mode) begin
                            cur_kv_head     <= 7'd0;
                            cur_q_in_group  <= 6'd0;
                            cur_q_block_row <= 16'd0;
                            cur_kv_tile     <= 16'd0;
                            reading_v       <= 1'b0;
                            state           <= ST_GEMM_Q_READ;
                        end else begin
                            vec_load_start  <= 1'b1;
                            gemv_kv_head    <= 7'd0;
                            gemv_bundle_idx <= gemv_bundle_start;
                            state           <= ST_GEMV_READ;
                        end
                    end
                end

                ST_GEMM_Q_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= q_tile_addr;
                    read_burst_length <= Q_BURST;
                    state             <= ST_GEMM_Q_WAIT;
                end

                ST_GEMM_Q_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (cur_q_in_group == group_size - 1) begin
                            cur_q_in_group <= 6'd0;
                            cur_kv_tile    <= kv_start;
                            reading_v      <= 1'b0;
                            if (cur_q_block_row == 16'd0) begin
                                return_state <= ST_GEMM_K_READ;
                                gap_cnt      <= 2'd0;
                                state        <= ST_GAP;
                            end else begin
                                return_state <= ST_GEMM_K_READ;
                                gap_cnt      <= 2'd0;
                                state        <= ST_GAP;
                            end
                        end else begin
                            cur_q_in_group <= cur_q_in_group + 1;
                            return_state   <= ST_GEMM_Q_READ;
                            gap_cnt        <= 2'd0;
                            state          <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_K_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= k_read_addr;
                    read_burst_length <= k_burst;
                    state             <= ST_GEMM_K_WAIT;
                end

                ST_GEMM_K_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        return_state <= ST_GEMM_V_READ;
                        gap_cnt      <= 2'd0;
                        state        <= ST_GAP;
                    end
                end

                ST_GEMM_V_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= v_tile_addr;
                    read_burst_length <= {1'b0, v_tile_dense_burst_length};
                    state             <= ST_GEMM_V_WAIT;
                end

                ST_GEMM_V_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (cur_kv_tile == cur_q_block_row) begin
                            state <= ST_GEMM_CONCAT_WAIT;
                        end else begin
                            cur_kv_tile  <= cur_kv_tile + 1;
                            return_state <= ST_GEMM_K_READ;
                            gap_cnt      <= 2'd0;
                            state        <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_CONCAT_WAIT: begin
                    if (concat_phase_done) begin
                        if (cur_q_block_row == seq_tiles - 1) begin
                            if (cur_kv_head == kv_head_num - 1) begin
                                state <= ST_IDLE;
                            end else begin
                                cur_kv_head     <= cur_kv_head + 1;
                                cur_q_block_row <= 16'd0;
                                cur_q_in_group  <= 6'd0;
                                return_state    <= ST_GEMM_Q_READ;
                                gap_cnt         <= 2'd0;
                                state           <= ST_GAP;
                            end
                        end else begin
                            cur_q_block_row <= cur_q_block_row + 1;
                            cur_q_in_group  <= 6'd0;
                            return_state    <= ST_GEMM_Q_READ;
                            gap_cnt         <= 2'd0;
                            state           <= ST_GAP;
                        end
                    end
                end

                ST_GEMV_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= gemv_bundle_addr;
                    read_burst_length <= (gemv_bundle_words > 10'd127)
                                         ? 8'd127 : gemv_bundle_words[7:0];
                    gemv_words_left   <= (gemv_bundle_words > 10'd127)
                                         ? (gemv_bundle_words - 10'd127) : 10'd0;
                    gemv_chunk_addr   <= gemv_bundle_addr
                                         + ({{(ADDR_WIDTH-12){1'b0}}, 12'd127} << 5);
                    state             <= ST_GEMV_WAIT;
                end

                ST_GEMV_CHUNK: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= gemv_chunk_addr;
                    read_burst_length <= (gemv_words_left > 10'd127)
                                         ? 8'd127 : gemv_words_left[7:0];
                    gemv_words_left   <= (gemv_words_left > 10'd127)
                                         ? (gemv_words_left - 10'd127) : 10'd0;
                    gemv_chunk_addr   <= gemv_chunk_addr
                                         + ({{(ADDR_WIDTH-12){1'b0}}, 12'd127} << 5);
                    state             <= ST_GEMV_WAIT;
                end

                ST_GEMV_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (gemv_words_left != 10'd0) begin
                            return_state <= ST_GEMV_CHUNK;
                            gap_cnt      <= 2'd0;
                            state        <= ST_GAP;
                        end else
                        if (gemv_bundle_idx == bundle_num - 1) begin
                            if (gemv_kv_head == kv_head_num - 1) begin
                                state <= ST_IDLE;
                            end else begin
                                gemv_kv_head    <= gemv_kv_head + 1;
                                gemv_bundle_idx <= gemv_bundle_start;
                                return_state    <= ST_GEMV_READ;
                                gap_cnt         <= 2'd0;
                                state           <= ST_GAP;
                            end
                        end else begin
                            gemv_bundle_idx <= gemv_bundle_idx + 1;
                            return_state    <= ST_GEMV_READ;
                            gap_cnt         <= 2'd0;
                            state           <= ST_GAP;
                        end
                    end
                end

                ST_GAP: begin
                    if (gap_cnt == 2'd2) begin
                        state <= return_state;
                    end else begin
                        gap_cnt <= gap_cnt + 1;
                    end
                end

                default: state <= ST_IDLE;
            endcase

            end
        end
    end

endmodule
