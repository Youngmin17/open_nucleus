// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module schedule_manager #(
    parameter ADDR_WIDTH                = 64,
    parameter DATA_WIDTH                = 256,
    parameter CORE_NUM                  = 4,
    parameter AXI_CHANNELS              = 32,
    parameter [3:0] GEMM_A_XFERS        = 4'd2,
    parameter [3:0] GEMM_W_XFERS        = 4'd4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         isa_valid,

    input  wire                         is_gemm_mode,
    input  wire                         is_proj_mode,
    input  wire                         is_residual_mode,
    input  wire                         is_gating_mode,
    input  wire                         is_norm_mode,

    input  wire                         a_on_chip,

    input  wire [ADDR_WIDTH-1:0]        op_a_addr,
    input  wire [ADDR_WIDTH-1:0]        op_b_addr,
    input  wire [ADDR_WIDTH-1:0]        op_c_addr,
    input  wire [ADDR_WIDTH-1:0]        residual_base_addr,
    input  wire [ADDR_WIDTH-1:0]        qkv_head_addr_offset,

    input  wire [4:0]                   op_a_prec,
    input  wire [4:0]                   op_b_prec,
    input  wire [4:0]                   op_c_prec,
    input  wire                         op_b_fmt_explicit,
    input  wire                         op_c_fmt_explicit,
    input  wire                         w_szp_ovr,

    input  wire [31:0]                  seq_len,
    input  wire [15:0]                  hidden_dim,
    input  wire [15:0]                  output_dim,
    input  wire [7:0]                   batch_num,

    input  wire [6:0]                   q_head_num,
    input  wire [6:0]                   kv_head_num,
    input  wire [5:0]                   group_size,
    input  wire [1:0]                   group_width,
    input  wire [15:0]                  window_size,

    input  wire [6:0]                   outlier_num,

    input  wire                         dma_arready,
    input  wire                         dma_read_done,
    input  wire                         core_compute_done,
    input  wire                         gqa_q_phase_done,
    input  wire                         gqa_score_phase_done,
    input  wire                         concat_phase_done,
    input  wire                         residual_load_done,

    output wire                         vec_load_start,
    output wire                         tile_last,
    output wire                         result_block_done,
    output wire                         idle_state,

    output reg                          start_read,
    output reg [7:0]                    read_burst_length,
    output reg [ADDR_WIDTH-1:0]         read_init_addr
);

    wire [6:0] outlier_pos_length;
    wire [6:0] outlier_val_length;

    outlier_lut_scheduler u_outlier_lut (
        .clk               (clk),
        .rst_n             (rst_n),
        .isa_valid         (isa_valid),
        .outlier_num       (outlier_num[6:0]),
        .outlier_pos_length(outlier_pos_length),
        .outlier_val_length(outlier_val_length)
    );

    reg [6:0]  k_tile_dense_burst_length;
    reg [6:0]  v_tile_dense_burst_length;
    reg [6:0]  szp_burst_length;
    reg [22:0] bundle_num;
    reg [6:0]  gemm_gqa_bundle_burst_length;
    reg [6:0]  gemv_gqa_bundle_burst_length;

    reg isa_valid_detected;
    reg start_all;
    reg bundle_values_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            isa_valid_detected           <= 1'b0;
            start_all                    <= 1'b0;
            bundle_values_latched        <= 1'b0;
            k_tile_dense_burst_length    <= 7'd0;
            v_tile_dense_burst_length    <= 7'd0;
            szp_burst_length             <= 7'd0;
            bundle_num                   <= 23'd0;
            gemm_gqa_bundle_burst_length <= 7'd0;
            gemv_gqa_bundle_burst_length <= 7'd0;
        end else begin
            start_all <= 1'b0;
            if (isa_valid_detected) begin
                if (!bundle_values_latched) begin
                    gemm_gqa_bundle_burst_length <= (group_width == 2'b01) ?
                        k_tile_dense_burst_length*4 + v_tile_dense_burst_length*4 + szp_burst_length*2 +
                        outlier_pos_length + outlier_val_length :
                        k_tile_dense_burst_length*4 + v_tile_dense_burst_length*4 + szp_burst_length +
                        outlier_pos_length + outlier_val_length;
                    gemv_gqa_bundle_burst_length <= (group_width == 2'b01) ?
                        k_tile_dense_burst_length*4 + v_tile_dense_burst_length*4 + szp_burst_length*2 :
                        k_tile_dense_burst_length*4 + v_tile_dense_burst_length*4 + szp_burst_length;
                    bundle_values_latched <= 1'b1;
                end
                if (isa_valid == 1'b0) begin
                    isa_valid_detected    <= 1'b0;
                    bundle_values_latched <= 1'b0;
                    start_all             <= 1'b1;
                end
            end else if (isa_valid) begin
                isa_valid_detected <= 1'b1;
                k_tile_dense_burst_length <= op_b_fmt_explicit ? ({op_b_prec, 1'b0} + 7'd2) :
                                             (op_b_prec == 5'd15) ? 7'd32 :
                                             (op_b_prec == 5'd7)  ? 7'd16 :
                                             (op_b_prec == 5'd3)  ? 7'd8  :
                                             (op_b_prec == 5'd1)  ? 7'd4  : 7'd0;
                v_tile_dense_burst_length <= op_c_fmt_explicit ? ({op_c_prec, 1'b0} + 7'd2) :
                                             (op_c_prec == 5'd15) ? 7'd32 :
                                             (op_c_prec == 5'd7)  ? 7'd16 :
                                             (op_c_prec == 5'd3)  ? 7'd8  :
                                             (op_c_prec == 5'd1)  ? 7'd4  : 7'd0;
                szp_burst_length <= (group_width == 2'b01) ? 7'd6 :
                                    (group_width == 2'b10) ? 7'd6 :
                                    (group_width == 2'b11) ? 7'd4 : 7'd0;
                bundle_num <= seq_len >> 9;
            end
        end
    end

    wire start_proj = start_all &&  is_proj_mode;
    wire start_gqa  = start_all && !is_proj_mode;

    wire                  proj_start_read;
    wire [ADDR_WIDTH-1:0] proj_read_init_addr;
    wire [7:0]            proj_read_burst_len;
    wire                  proj_tile_last;
    wire                  proj_result_block_done;
    wire                  proj_vec_load_start;
    wire                  gqa_vec_load_start;

    wire proj_idle_state;
    wire gqa_idle_state;
    assign idle_state = is_proj_mode ? proj_idle_state : gqa_idle_state;

    proj_scheduler #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .CORE_NUM    (CORE_NUM),
        .AXI_CHANNELS(AXI_CHANNELS),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS)
    ) u_proj_scheduler (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_all          (start_proj),
        .isa_valid          (isa_valid),

        .is_gemm_mode       (is_gemm_mode),
        .is_residual_mode   (is_residual_mode),
        .is_gating_mode     (is_gating_mode),
        .is_norm_mode       (is_norm_mode),
        .a_on_chip           (a_on_chip),

        .op_a_addr          (op_a_addr),
        .op_b_addr          (op_b_addr),
        .op_c_addr          (op_c_addr),
        .residual_base_addr (residual_base_addr),

        .op_a_prec          (op_a_prec),
        .op_b_prec          (op_b_prec),
        .op_b_fmt_explicit  (op_b_fmt_explicit),
        .w_szp_ovr          (w_szp_ovr),
        .group_width        (group_width),
        .outlier_num        (outlier_num[6:0]),

        .seq_len            (seq_len),
        .hidden_dim         (hidden_dim),
        .output_dim         (output_dim),
        .batch_num          (batch_num),

        .dma_arready        (dma_arready),
        .dma_read_done      (dma_read_done),
        .core_compute_done  (core_compute_done),
        .residual_load_done (residual_load_done),

        .start_read         (proj_start_read),
        .read_init_addr     (proj_read_init_addr),
        .read_burst_length  (proj_read_burst_len),
        .vec_load_start     (proj_vec_load_start),
        .tile_last          (proj_tile_last),
        .result_block_done  (proj_result_block_done),
        .idle_state         (proj_idle_state)
    );

    wire                  gqa_start_read;
    wire [ADDR_WIDTH-1:0] gqa_read_init_addr;
    wire [7:0]            gqa_read_burst_len;

    gqa_scheduler #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .CORE_NUM    (CORE_NUM),
        .AXI_CHANNELS(AXI_CHANNELS)
    ) u_gqa_scheduler (
        .clk                          (clk),
        .rst_n                        (rst_n),
        .start_all                    (start_gqa),
        .isa_valid                    (isa_valid),

        .is_gemm_mode                 (is_gemm_mode),
        .outlier_num                  (outlier_num[6:0]),

        .op_a_addr                    (op_a_addr),
        .op_b_addr                    (op_b_addr),
        .qkv_head_addr_offset          (qkv_head_addr_offset),

        .op_a_prec                    (op_a_prec),
        .op_b_prec                    (op_b_prec),
        .op_c_prec                    (op_c_prec),

        .seq_len                      (seq_len),
        .q_head_num                   (q_head_num),
        .kv_head_num                  (kv_head_num),
        .group_size                   (group_size),
        .group_width                  (group_width),
        .window_size                  (window_size),

        .k_tile_dense_burst_length    (k_tile_dense_burst_length),
        .v_tile_dense_burst_length    (v_tile_dense_burst_length),
        .szp_burst_length             (szp_burst_length),
        .bundle_num                   (bundle_num),
        .gemv_gqa_bundle_burst_length (gemv_gqa_bundle_burst_length),

        .dma_arready                  (dma_arready),
        .dma_read_done                (dma_read_done),

        .concat_phase_done            (concat_phase_done),

        .start_read                   (gqa_start_read),
        .read_init_addr               (gqa_read_init_addr),
        .read_burst_length            (gqa_read_burst_len),
        .vec_load_start               (gqa_vec_load_start),
        .idle_state                   (gqa_idle_state)
    );

    always @(*) begin
        start_read        = 1'b0;
        read_burst_length = 8'd0;
        read_init_addr    = {ADDR_WIDTH{1'b0}};
        if (is_proj_mode && proj_start_read) begin
            read_init_addr    = proj_read_init_addr;
            read_burst_length = proj_read_burst_len;
            start_read        = 1'b1;
        end else if (!is_proj_mode && gqa_start_read) begin
            read_init_addr    = gqa_read_init_addr;
            read_burst_length = gqa_read_burst_len;
            start_read        = 1'b1;
        end
    end

    assign vec_load_start    = proj_vec_load_start || gqa_vec_load_start;
    assign tile_last         = proj_tile_last;
    assign result_block_done = proj_result_block_done;

endmodule
