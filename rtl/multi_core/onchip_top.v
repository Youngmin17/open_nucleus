// SPDX-License-Identifier: Apache-2.0
module onchip_top #(
    parameter AXI_CHANNELS   = 32,
    parameter ADDR_WIDTH     = 64,
    parameter DMA_DATA_WIDTH = 256,
    parameter HBM_CHANNELS   = 8,
    parameter HBM_DATA_WIDTH = 1024,
    parameter BLOCK_SIZE     = 128,
    parameter DATA_NUM       = 64,
    parameter DIN_WIDTH      = HBM_CHANNELS * HBM_DATA_WIDTH,
    parameter CORE_NUM       = 8,
    parameter DATA_WIDTH     = 16,
    parameter [3:0] GEMM_A_XFERS = 4'd2,
    parameter [3:0] GEMM_W_XFERS = 4'd4
)
(
    input wire core_clk,
    input wire mem_clk,
    input wire rst_n,

    input wire        isa_latched,
    input wire        is_mode_valid,
    input wire        is_gemm_mode,
    input wire        is_proj_mode,
    input wire        is_norm_mode,
    input wire        is_residual_mode,
    input wire        is_gating_mode,
    input wire        causal_mode,
    input wire        dest_on_chip,
    input wire        a_on_chip,
    input wire [3:0]  fuse_mode,
    input wire [1:0]  opm_mode,
    input wire [1:0]  group_width,
    input wire [7:0]  batch_num,
    input wire [5:0]  group_size,
    input wire [15:0] window_size,
    input wire [6:0]  kv_head_num,
    input wire [4:0]  op_b_prec,
    input wire [4:0]  op_c_prec,
    input wire [6:0]  outlier_num,
    input wire [15:0] hidden_dim,
    input wire [31:0] seq_len,
    input wire [15:0] output_dim,
    input wire [2:0]  quant_precision,
    input wire [39:0] dest_addr1,
    input wire [39:0] dest_addr2,
    input wire [29:0] qkv_head_addr_offset,
    input wire [19:0] rope_token_pos,

    input wire        result_block_done,
    input wire        vec_load_start,

    input wire        async_out_vld,
    input wire [4095:0] async_d_out,

    input wire        reduce_max_vld,
    input wire [DATA_WIDTH-1:0] reduce_max_value,
    input wire [31:0] cpu_vrf_in_vld,
    input wire [63:0] cpu_vrf_row_data,
    input wire        comb_sram_wen,
    input wire [101:0] comb_sram_wdata,

    output wire        gqa_q_phase_done_out,
    output wire        gqa_score_phase_done_out,
    output wire        core_compute_done_out,
    output wire        concat_phase_done_out,
    output wire        residual_load_done_out,

    output wire        cpu_row_valid,
    output wire [63:0] cpu_row_data,

    output wire        write_vld,
    output wire        start_write,
    output wire [7:0]  write_burst_length,
    output wire [ADDR_WIDTH-1:0] write_init_addr,
    output wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] write_data,
    output wire        write_is_code,
    output wire        cmd_is_code
);

    localparam  GEMM_BYPASS   = 4'd1,
                GEMM_ROPE     = 4'd2,
                GEMM_RTQT     = 4'd3,
                GEMM_QT       = 4'd4,
                GEMM_PRERMS   = 4'd5,
                GEMM_SWIGELU  = 4'd6,
                GEMM_TRANSPOSE= 4'd7,
                GEMM_GQA      = 4'd8,
                GEMV_BYPASS   = 4'd9,
                GEMV_ROPE     = 4'd10,
                GEMV_PRERMS   = 4'd11,
                GEMV_SWIGELU  = 4'd12;

    reg isa_toggle;
    reg vec_load_start_toggle;
    reg result_block_done_toggle;

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            isa_toggle             <= 1'b0;
            vec_load_start_toggle  <= 1'b0;
            result_block_done_toggle <= 1'b0;
        end else begin
            if (isa_latched)    isa_toggle            <= ~isa_toggle;
            if (vec_load_start) vec_load_start_toggle <= ~vec_load_start_toggle;
            if (result_block_done) result_block_done_toggle <= ~result_block_done_toggle;
        end
    end

    reg isa_s1, isa_s2, isa_s3;
    reg vec_load_start_s1, vec_load_start_s2, vec_load_start_s3;
    reg result_block_done_s1, result_block_done_s2, result_block_done_s3;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            isa_s1             <= 1'b0;
            isa_s2             <= 1'b0;
            isa_s3             <= 1'b0;
            vec_load_start_s1  <= 1'b0;
            vec_load_start_s2  <= 1'b0;
            vec_load_start_s3  <= 1'b0;
            result_block_done_s1 <= 1'b0;
            result_block_done_s2 <= 1'b0;
            result_block_done_s3 <= 1'b0;
        end else begin
            isa_s1             <= isa_toggle;
            isa_s2             <= isa_s1;
            isa_s3             <= isa_s2;
            vec_load_start_s1  <= vec_load_start_toggle;
            vec_load_start_s2  <= vec_load_start_s1;
            vec_load_start_s3  <= vec_load_start_s2;
            result_block_done_s1 <= result_block_done_toggle;
            result_block_done_s2 <= result_block_done_s1;
            result_block_done_s3 <= result_block_done_s2;
        end
    end

    wire isa_valid           = isa_s2            ^ isa_s3;
    wire vec_load_start_cdc  = vec_load_start_s2 ^ vec_load_start_s3;
    wire result_block_done_cdc = result_block_done_s2 ^ result_block_done_s3;

    wire gqa_q_phase_done_core;
    wire gqa_score_phase_done_core;
    wire core_compute_done_core;
    wire phase_done_concat;
    wire residual_load_done;

    reg toggle_gqa_q_phase_done;
    reg toggle_gqa_score_phase_done;
    reg toggle_core_compute_done;
    reg toggle_concat_phase_done;
    reg toggle_residual_load_done;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            toggle_gqa_q_phase_done     <= 1'b0;
            toggle_gqa_score_phase_done <= 1'b0;
            toggle_core_compute_done    <= 1'b0;
            toggle_concat_phase_done          <= 1'b0;
            toggle_residual_load_done          <= 1'b0;
        end else begin
            if (gqa_q_phase_done_core)     toggle_gqa_q_phase_done     <= ~toggle_gqa_q_phase_done;
            if (gqa_score_phase_done_core) toggle_gqa_score_phase_done <= ~toggle_gqa_score_phase_done;
            if (core_compute_done_core)    toggle_core_compute_done    <= ~toggle_core_compute_done;
            if (phase_done_concat)         toggle_concat_phase_done    <= ~toggle_concat_phase_done;
            if (residual_load_done)        toggle_residual_load_done   <= ~toggle_residual_load_done;
        end
    end

    reg toggle_gqa_q_s1, toggle_gqa_q_s2, toggle_gqa_q_s3;
    reg toggle_gqa_score_s1, toggle_gqa_score_s2, toggle_gqa_score_s3;
    reg toggle_compute_s1, toggle_compute_s2, toggle_compute_s3;
    reg toggle_concat_done_s1, toggle_concat_done_s2, toggle_concat_done_s3;
    reg toggle_residual_load_s1, toggle_residual_load_s2, toggle_residual_load_s3;

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            toggle_gqa_q_s1     <= 1'b0;
            toggle_gqa_q_s2     <= 1'b0;
            toggle_gqa_q_s3     <= 1'b0;
            toggle_gqa_score_s1 <= 1'b0;
            toggle_gqa_score_s2 <= 1'b0;
            toggle_gqa_score_s3 <= 1'b0;
            toggle_compute_s1   <= 1'b0;
            toggle_compute_s2   <= 1'b0;
            toggle_compute_s3   <= 1'b0;
            toggle_concat_done_s1 <= 1'b0;
            toggle_concat_done_s2 <= 1'b0;
            toggle_concat_done_s3 <= 1'b0;
            toggle_residual_load_s1 <= 1'b0;
            toggle_residual_load_s2 <= 1'b0;
            toggle_residual_load_s3 <= 1'b0;
        end else begin
            toggle_gqa_q_s1     <= toggle_gqa_q_phase_done;
            toggle_gqa_q_s2     <= toggle_gqa_q_s1;
            toggle_gqa_q_s3     <= toggle_gqa_q_s2;
            toggle_gqa_score_s1 <= toggle_gqa_score_phase_done;
            toggle_gqa_score_s2 <= toggle_gqa_score_s1;
            toggle_gqa_score_s3 <= toggle_gqa_score_s2;
            toggle_compute_s1   <= toggle_core_compute_done;
            toggle_compute_s2   <= toggle_compute_s1;
            toggle_compute_s3   <= toggle_compute_s2;
            toggle_concat_done_s1 <= toggle_concat_phase_done;
            toggle_concat_done_s2 <= toggle_concat_done_s1;
            toggle_concat_done_s3 <= toggle_concat_done_s2;
            toggle_residual_load_s1 <= toggle_residual_load_done;
            toggle_residual_load_s2 <= toggle_residual_load_s1;
            toggle_residual_load_s3 <= toggle_residual_load_s2;
        end
    end

    assign gqa_q_phase_done_out     = toggle_gqa_q_s2     ^ toggle_gqa_q_s3;
    assign gqa_score_phase_done_out = toggle_gqa_score_s2 ^ toggle_gqa_score_s3;
    assign core_compute_done_out    = toggle_compute_s2   ^ toggle_compute_s3;
    assign concat_phase_done_out    = toggle_concat_done_s2 ^ toggle_concat_done_s3;
    assign residual_load_done_out   = toggle_residual_load_s2 ^ toggle_residual_load_s3;

    wire [1:0]  gemm_proj_routing_mode;
    wire        dense_a_out_vld;
    wire        dense_b_out_vld;
    wire        dense_r_out_vld;
    wire        scale_zp_out_vld;
    wire [5:0]  head_number;
    wire [CORE_NUM-1:0] dense_routing_id;
    wire [CORE_NUM-1:0] scale_zp_routing_id;
    wire [8191:0] dense_out_data;
    wire [3071:0] scale_zp_out_data;
    wire [CORE_NUM-1:0] compute_start;
    wire [CORE_NUM-1:0] diag_done;
    wire [DATA_WIDTH-1:0] gemv_rms_div;
    wire                  gemv_rms_div_vld;

    wire [CORE_NUM-1:0]            router_isa_valid_out;
    wire [CORE_NUM-1:0]            router_is_mode_valid_out;
    wire [CORE_NUM-1:0]            router_is_gemm_mode_out;
    wire [CORE_NUM-1:0]            router_is_proj_mode_out;
    wire [CORE_NUM-1:0]            router_is_residual_mode_out;
    wire [CORE_NUM-1:0]            router_dest_on_chip_out;
    wire [CORE_NUM*2-1:0]          router_group_width_out;
    wire [CORE_NUM*8-1:0]          router_batch_num_out;
    wire [CORE_NUM*2-1:0]          router_opm_mode_out;
    wire [CORE_NUM-1:0]            router_reduce_max_vld_out;
    wire [CORE_NUM*DATA_WIDTH-1:0] router_reduce_max_value_out;
    wire [CORE_NUM-1:0]            router_opm_compute_start_out;
    wire [CORE_NUM-1:0]            router_diag_done_in_out;
    wire [CORE_NUM-1:0]            router_vec_load_start_out;
    wire [CORE_NUM*9-1:0]          router_hidden_dim_out;
    wire [CORE_NUM*9-1:0]          router_output_dim_out;
    wire [CORE_NUM*8-1:0]          router_batch_space_out;
    wire [CORE_NUM*6-1:0]          router_group_size_out;
    wire [CORE_NUM-1:0]            router_opm_a_row_vld_out;
    wire [CORE_NUM-1:0]            router_opm_b_row_vld_out;
    wire [CORE_NUM-1:0]            router_residual_row_vld_out;
    wire [CORE_NUM*DIN_WIDTH-1:0]  router_d_in_row_out;
    wire [CORE_NUM-1:0]            router_scale_zp_vld_out;
    wire [CORE_NUM*3072-1:0]       router_scale_zp_in_out;
    wire [CORE_NUM-1:0]            router_pmu_start_emit_out;
    wire [CORE_NUM-1:0]            router_cpu_vrf_in_vld_out;
    wire [CORE_NUM*64-1:0]         router_cpu_vrf_row_data_out;

    wire [CORE_NUM-1:0]      core_result_out_vld;
    wire [CORE_NUM*1024-1:0] core_result_row_out;
    wire [CORE_NUM-1:0]      core_compute_done_arr;
    wire [CORE_NUM-1:0]      core_gqa_q_phase_done_arr;
    wire [CORE_NUM-1:0]      core_gqa_score_phase_done_arr;
    wire [CORE_NUM-1:0]      core_gqa_compute_stop_arr;

    wire        accum_core_row_valid;
    wire [DATA_WIDTH*DATA_NUM*2-1:0] accum_core_row_data;
    wire [DATA_WIDTH*DATA_NUM*2-1:0] accum_core_row_data_swig_val;
    wire [CORE_NUM-1:0]     concat_start_emit;
    wire                    gqa_compute_stop;

    wire [CORE_NUM-1:0] pmu_start_emit = concat_start_emit;

    wire dim_read_done;

    wire [5:0] decode_core_num =
            is_gemm_mode ? 6'b0 :
            is_proj_mode ? (batch_num < CORE_NUM ? batch_num : CORE_NUM) :
            ((group_size + 3) >> 2);

    wire [7:0] batch_num_eff =
                batch_num < CORE_NUM ? 8'd1 : ((batch_num + CORE_NUM - 1) >> $clog2(CORE_NUM));

    wire [7:0] batch_space_next
        = batch_num_eff == 8'd1 ? 8'd128 :
          batch_num_eff == 8'd2 ? 8'd64  :
          batch_num_eff == 8'd3 ? 8'd40  :
          batch_num_eff == 8'd4 ? 8'd32  :
          batch_num_eff == 8'd5 ? 8'd24  :
          batch_num_eff == 8'd6 ? 8'd20  :
          batch_num_eff == 8'd7 ? 8'd16  :
          batch_num_eff == 8'd8 ? 8'd16  :
          batch_num_eff == 8'd9 ? 8'd12  :
          batch_num_eff == 8'd10 ? 8'd12 :
          batch_num_eff == 8'd11 ? 8'd8  :
          batch_num_eff == 8'd12 ? 8'd8  :
          batch_num_eff == 8'd13 ? 8'd8  :
          batch_num_eff == 8'd14 ? 8'd8  :
          batch_num_eff == 8'd15 ? 8'd8  :
          batch_num_eff == 8'd16 ? 8'd8  : 8'd0;

    reg [7:0] batch_space;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            batch_space <= 8'd0;
        end else if (isa_valid) begin
            batch_space <=  fuse_mode == GEMV_ROPE ? {2'b0, group_size} :
                            output_dim[15:7] > batch_space_next ? batch_space_next : output_dim[15:7];
        end
    end

    assign gemm_proj_routing_mode =
            (fuse_mode == GEMM_BYPASS || fuse_mode == GEMM_PRERMS) ? 2'b00 :
            (fuse_mode == GEMM_ROPE || fuse_mode == GEMM_RTQT || fuse_mode == GEMM_QT || fuse_mode == GEMM_TRANSPOSE) ? 2'b01 :
            (fuse_mode == GEMM_SWIGELU) ? 2'b10 : 2'b00;

    unpacker_top #(
        .CORE_NUM(CORE_NUM),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS)
    ) u_unpacker_top (
        .clk                   (core_clk),
        .rst_n                 (rst_n),
        .isa_valid             (isa_valid),
        .is_gemm_mode          (is_gemm_mode),
        .is_proj_mode          (is_proj_mode),
        .is_norm_mode          (is_norm_mode),
        .is_residual_mode      (is_residual_mode),
        .is_gating_mode        (is_gating_mode),
        .a_on_chip             (a_on_chip),
        .seq_len               (seq_len),
        .hidden_dim            (hidden_dim),
        .output_dim            (output_dim),
        .batch_num             (batch_num),
        .batch_space           (batch_space),
        .group_width           (group_width),
        .group_size            (group_size),
        .window_size           (window_size),
        .w_precision           (op_b_prec + 5'd1),
        .k_precision           (op_b_prec + 5'd1),
        .v_precision           (op_c_prec + 5'd1),
        .outlier_num           ({1'b0, outlier_num}),
        .decode_core_num       (decode_core_num),
        .gemm_proj_routing_mode(gemm_proj_routing_mode),
        .diag_done             (diag_done),
        .rom_wen               (comb_sram_wen),
        .rom_wdata             (comb_sram_wdata),
        .in_vld                (async_out_vld),
        .in_data               (async_d_out),
        .dense_a_out_vld       (dense_a_out_vld),
        .dense_b_out_vld       (dense_b_out_vld),
        .dense_r_out_vld       (dense_r_out_vld),
        .scale_zp_out_vld      (scale_zp_out_vld),
        .residual_load_done    (residual_load_done),
        .dim_read_done         (dim_read_done),
        .dense_routing_id      (dense_routing_id),
        .scale_zp_routing_id   (scale_zp_routing_id),
        .dense_out_data        (dense_out_data),
        .scale_zp_out_data     (scale_zp_out_data),
        .opm_compute_start     (compute_start),
        .gemv_rms_div          (gemv_rms_div),
        .gemv_rms_div_vld      (gemv_rms_div_vld)
    );

    router_top #(
        .CORE_NUM(CORE_NUM)
    ) u_router_top (
        .core_clk              (core_clk),
        .rst_n                 (rst_n),
        .isa_valid             (isa_valid),
        .is_mode_valid         (is_mode_valid),
        .is_gemm_mode          (is_gemm_mode),
        .is_proj_mode          (is_proj_mode),
        .is_residual_mode      (is_residual_mode),
        .dest_on_chip          (dest_on_chip),
        .batch_num             (batch_num),
        .group_width           (group_width),
        .opm_mode              (opm_mode),
        .reduce_max_vld        (reduce_max_vld),
        .reduce_max_value      (reduce_max_value),
        .diag_done_in          (diag_done),
        .vec_load_start        (vec_load_start_cdc),
        .hidden_dim            (hidden_dim[15:7]),
        .output_dim            (output_dim[15:7]),
        .batch_space           (batch_space),
        .group_size            (group_size),
        .dense_routing_id      (dense_routing_id),
        .opm_a_row_vld         (dense_a_out_vld),
        .opm_b_row_vld         (dense_b_out_vld),
        .residual_row_vld      (dense_r_out_vld),
        .d_in_row              (dense_out_data),
        .scale_zp_routing_id   (scale_zp_routing_id),
        .scale_zp_vld          (scale_zp_out_vld),
        .scale_zp_in           (scale_zp_out_data),
        .opm_compute_start     (compute_start),
        .pmu_start_emit        (pmu_start_emit),
        .cpu_vrf_in_vld        (cpu_vrf_in_vld[CORE_NUM-1:0]),
        .cpu_vrf_row_data      (cpu_vrf_row_data),
        .isa_valid_out             (router_isa_valid_out),
        .is_mode_valid_out         (router_is_mode_valid_out),
        .is_gemm_mode_out          (router_is_gemm_mode_out),
        .is_proj_mode_out          (router_is_proj_mode_out),
        .is_residual_mode_out      (router_is_residual_mode_out),
        .dest_on_chip_out          (router_dest_on_chip_out),
        .group_width_out           (router_group_width_out),
        .batch_num_out             (router_batch_num_out),
        .opm_mode_out              (router_opm_mode_out),
        .reduce_max_vld_out        (router_reduce_max_vld_out),
        .reduce_max_value_out      (router_reduce_max_value_out),
        .opm_compute_start_out     (router_opm_compute_start_out),
        .diag_done_in_out          (router_diag_done_in_out),
        .vec_load_start_out        (router_vec_load_start_out),
        .hidden_dim_out            (router_hidden_dim_out),
        .output_dim_out            (router_output_dim_out),
        .batch_space_out           (router_batch_space_out),
        .group_size_out            (router_group_size_out),
        .opm_a_row_vld_out         (router_opm_a_row_vld_out),
        .opm_b_row_vld_out         (router_opm_b_row_vld_out),
        .residual_row_vld_out      (router_residual_row_vld_out),
        .d_in_row_out              (router_d_in_row_out),
        .scale_zp_vld_out          (router_scale_zp_vld_out),
        .scale_zp_in_out           (router_scale_zp_in_out),
        .pmu_start_emit_out        (router_pmu_start_emit_out),
        .cpu_vrf_in_vld_out        (router_cpu_vrf_in_vld_out),
        .cpu_vrf_row_data_out      (router_cpu_vrf_row_data_out)
    );

    genvar gi;
    generate
        for (gi = 0; gi < CORE_NUM; gi = gi + 1) begin : gen_core
            core_top #(
                .CORE_ID(gi),
                .CORE_NUM(CORE_NUM),
                .GEMM_A_XFERS(GEMM_A_XFERS),
                .GEMM_W_XFERS(GEMM_W_XFERS)
            ) u_core_top (
                .core_clk          (core_clk),
                .rst_n             (rst_n),
                .isa_valid         (router_isa_valid_out[gi]),
                .is_mode_valid     (router_is_mode_valid_out[gi]),
                .is_gemm_mode      (router_is_gemm_mode_out[gi]),
                .is_proj_mode      (router_is_proj_mode_out[gi]),
                .is_residual_mode  (router_is_residual_mode_out[gi]),
                .dest_on_chip      (router_dest_on_chip_out[gi]),
                .group_width       (router_group_width_out[2*gi +: 2]),
                .opm_mode          (router_opm_mode_out[2*gi +: 2]),
                .opm_compute_start (router_opm_compute_start_out[gi]),
                .batch_num         (router_batch_num_out[8*gi +: 8]),
                .hidden_dim        (router_hidden_dim_out[9*gi +: 9]),
                .output_dim        (router_output_dim_out[9*gi +: 9]),
                .seq_row_tiles     (seq_len[15:7]),
                .is_gating         (is_gating_mode),
                .causal_mode       (causal_mode),
                .gemv_rms_div      (gemv_rms_div),
                .gemv_rms_div_vld  (gemv_rms_div_vld),
                .batch_space       (router_batch_space_out[8*gi +: 8]),
                .group_size        (router_group_size_out[6*gi +: 6]),
                .opm_a_row_vld     (router_opm_a_row_vld_out[gi]),
                .opm_b_row_vld     (router_opm_b_row_vld_out[gi]),
                .residual_row_vld  (router_residual_row_vld_out[gi]),
                .scale_zp_vld      (router_scale_zp_vld_out[gi]),
                .d_in_row          (router_d_in_row_out[DIN_WIDTH*gi +: DIN_WIDTH]),
                .scale_zp_in       (router_scale_zp_in_out[3072*gi +: 3072]),
                .reduce_max_vld    (router_reduce_max_vld_out[gi]),
                .reduce_max_value  (router_reduce_max_value_out[DATA_WIDTH*gi +: DATA_WIDTH]),
                .diag_done_in      (router_diag_done_in_out[gi]),
                .pmu_start_emit    (router_pmu_start_emit_out[gi]),
                .vec_load_start    (router_vec_load_start_out[gi]),
                .cpu_vrf_in_vld    (router_cpu_vrf_in_vld_out[gi]),
                .cpu_vrf_row_data  (router_cpu_vrf_row_data_out[64*gi +: 64]),
                .result_out_vld    (core_result_out_vld[gi]),
                .result_row_out    (core_result_row_out[1024*gi +: 1024]),
                .core_compute_done (core_compute_done_arr[gi]),
                .gqa_q_phase_done  (core_gqa_q_phase_done_arr[gi]),
                .gqa_score_phase_done(core_gqa_score_phase_done_arr[gi]),
                .gqa_compute_stop  (core_gqa_compute_stop_arr[gi])
            );
        end
    endgenerate

    accumulator #(
        .CORE_NUM(CORE_NUM)
    ) u_accumulator (
        .clk                   (core_clk),
        .rst_n                 (rst_n),
        .fuse_mode             (fuse_mode),
        .is_gemm_mode          (is_gemm_mode),
        .is_proj_mode          (is_proj_mode),
        .isa_valid             (isa_valid),
        .decode_core_num       (decode_core_num),
        .d_in                  (core_result_row_out),
        .in_vld                (core_result_out_vld),
        .core_compute_done     (core_compute_done_arr),
        .gqa_q_phase_done      (core_gqa_q_phase_done_arr),
        .gqa_score_phase_done  (core_gqa_score_phase_done_arr),
        .gqa_compute_stop      (core_gqa_compute_stop_arr),
        .core_row_valid        (accum_core_row_valid),
        .core_row_data         (accum_core_row_data),
        .core_row_data_swig_val(accum_core_row_data_swig_val),
        .gqa_q_phase_done_out  (gqa_q_phase_done_core),
        .gqa_score_phase_done_out(gqa_score_phase_done_core),
        .core_compute_done_out (core_compute_done_core),
        .gqa_compute_stop_out  (gqa_compute_stop)
    );

    concat_top #(
        .CORE_NUM(CORE_NUM),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS)
    ) u_concat_top (
        .core_clk              (core_clk),
        .rst_n                 (rst_n),
        .fuse_mode             (fuse_mode),
        .isa_valid             (isa_valid),
        .is_mode_valid         (is_mode_valid),
        .is_proj_mode          (is_proj_mode),
        .is_gemm_mode          (is_gemm_mode),
        .group_width           (group_width),
        .group_size            (group_size),
        .kv_head_num           (kv_head_num),
        .seq_len               (seq_len),
        .output_dim            (output_dim),
        .batch_num             (batch_num),
        .batch_space           (batch_space),
        .outlier_num           (outlier_num),
        .decode_core_num       (decode_core_num),
        .quant_precision       (quant_precision),
        .dest_addr1            ({24'd0, dest_addr1}),
        .dest_addr2            ({24'd0, dest_addr2}),
        .qkv_head_addr_offset       ({34'd0, qkv_head_addr_offset}),
        .result_block_done     (result_block_done_cdc),
        .dim_read_done         (dim_read_done),
        .core_row_valid        (accum_core_row_valid),
        .core_row_data         (accum_core_row_data),
        .core_row_data_swig_val(accum_core_row_data_swig_val),
        .gqa_compute_stop      (gqa_compute_stop),
        .rope_token_pos        ({8'd0, rope_token_pos}),
        .comb_sram_wen         (comb_sram_wen),
        .comb_sram_wdata       (comb_sram_wdata),
        .wrvalid               (write_vld),
        .start_write           (start_write),
        .write_burst_length    (write_burst_length),
        .write_init_addr       (write_init_addr),
        .write_data            (write_data),
        .write_is_code         (write_is_code),
        .cmd_is_code           (cmd_is_code),
        .start_emit            (concat_start_emit),

        .concat_phase_done     (phase_done_concat)
    );

endmodule
