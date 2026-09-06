// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module core_top #(
    parameter integer CORE_ID         = 0,
    parameter integer CORE_NUM        = 8,
    parameter integer HBM_CHANNELS    = 32,
    parameter integer HBM_DATA_WIDTH  = 256,
    parameter integer DATA_WIDTH       = 16,
    parameter integer FMAT_OUT_WIDTH   = 24,
    parameter integer DATA_NUM         = 128,
    parameter integer MULT_DIMENSION   = 32,
    parameter integer AXI_CHNL         = 128,
    parameter integer AXI_DATA_WIDTH   = 16,
    parameter integer BLOCK_ROW        = 128,
    parameter integer VRF_DEPTH_ROWS   = 64,
    parameter integer BUNDLE_PAIR_NUM  = 4,
    parameter [3:0]   GEMM_A_XFERS     = 4'd2,
    parameter [3:0]   GEMM_W_XFERS     = 4'd4
) (
    input  wire                             core_clk,
    input  wire                             rst_n,

    input  wire                             isa_valid,
    input  wire                             is_mode_valid,
    input  wire                             is_gemm_mode,
    input  wire                             is_proj_mode,
    input  wire                             is_residual_mode,
    input  wire                             dest_on_chip,

    input  wire [1:0]                       group_width,
    input  wire [5:0]                       group_size,
    input  wire [6:0]                       kv_head_num,
    input  wire [7:0]                       batch_num,
    input  wire [8:0]                       hidden_dim,
    input  wire [8:0]                       output_dim,
    input  wire [8:0]                       seq_row_tiles,
    input  wire                             is_gating,
    input  wire                             causal_mode,
    input  wire [DATA_WIDTH-1:0]            gemv_rms_div,
    input  wire                             gemv_rms_div_vld,
    input  wire [7:0]                       batch_space,
    input  wire [1:0]                       opm_mode,
    input  wire                             opm_compute_start,

    input  wire                             opm_a_row_vld,
    input  wire                             opm_b_row_vld,
    input  wire                             residual_row_vld,
    input  wire                             scale_zp_vld,
    input  wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_row,
    input  wire [3072-1:0]                  scale_zp_in,

    input  wire                             reduce_max_vld,
    input  wire [DATA_WIDTH-1:0]            reduce_max_value,
    input  wire                             diag_done_in,
    input  wire                             pmu_start_emit,

    input  wire                             vec_load_start,

    input  wire                             cpu_vrf_in_vld,
    input  wire [63:0]                      cpu_vrf_row_data,

    output wire                             result_out_vld,
    output wire [AXI_CHNL*AXI_DATA_WIDTH/2-1:0]  result_row_out,

    output wire                             core_compute_done,
    output wire                             gqa_q_phase_done,
    output wire                             gqa_score_phase_done,
    output wire                             gqa_compute_stop
);
    localparam integer VRF_ADDR_W = $clog2(VRF_DEPTH_ROWS);
    localparam integer CONCAT_NUM = HBM_CHANNELS * HBM_DATA_WIDTH / (AXI_CHNL * AXI_DATA_WIDTH);

    wire                            mpu_out_valid;
    wire [AXI_CHNL*FMAT_OUT_WIDTH-1:0]  mpu_out_data;
    wire                            mpu_block_done;
    wire [6:0]                      mpu_outer_row_cnt;
    wire                            score_row_vld;
    wire [AXI_CHNL*AXI_DATA_WIDTH-1:0]  score_row;
    wire                            pmu_row_vld;
    wire [AXI_CHNL*AXI_DATA_WIDTH-1:0]  pmu_row;

    wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_row_full = d_in_row;

    localparam integer VRF_ROW_W        = HBM_CHANNELS * HBM_DATA_WIDTH;
    localparam integer CPU_VRF_BEATS    = VRF_ROW_W / 64;

    reg [VRF_ROW_W-1:0] cpu_vrf_data_latch;
    reg [$clog2(CPU_VRF_BEATS)-1:0] cpu_vrf_beat_cnt;
    reg                  cpu_vrf_data_vld;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_vrf_data_latch <= {VRF_ROW_W{1'b0}};
            cpu_vrf_beat_cnt   <= {$clog2(CPU_VRF_BEATS){1'b0}};
            cpu_vrf_data_vld   <= 1'b0;
        end else begin
            cpu_vrf_data_vld <= 1'b0;
            if (cpu_vrf_in_vld) begin
                cpu_vrf_data_latch[64*cpu_vrf_beat_cnt +: 64] <= cpu_vrf_row_data;
                cpu_vrf_beat_cnt <= cpu_vrf_beat_cnt + 1'b1;
                if (cpu_vrf_beat_cnt == CPU_VRF_BEATS - 1) begin
                    cpu_vrf_beat_cnt <= {$clog2(CPU_VRF_BEATS){1'b0}};
                    cpu_vrf_data_vld <= 1'b1;
                end
            end
        end
    end

    wire [5:0] a_row_num;
    wire [2:0] effective_q_head_num =
            CORE_ID < group_size[5:2] ? 3'd4 :
            CORE_ID == group_size[5:2] ? {1'b0, group_size[1:0]} : 3'd0;
    wire [7:0] q_row_num = is_gemm_mode ? (is_proj_mode ? (a_row_num << 2)
                                                         : (group_size * (BLOCK_ROW/CORE_NUM)))
                                        : {5'b0, effective_q_head_num};

    reg [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] score_concat_data;
    reg [$clog2(CONCAT_NUM)-1:0] score_concat_cnt;

    wire score_concat_vld = score_row_vld && score_concat_cnt == (is_gemm_mode ? CONCAT_NUM : effective_q_head_num)-1;
    wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] score_concat_lower_mask =
            (effective_q_head_num <= 3'd1) ? {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}} :
            ({HBM_CHANNELS*HBM_DATA_WIDTH{1'b1}} >> (HBM_CHANNELS*HBM_DATA_WIDTH - AXI_CHNL*AXI_DATA_WIDTH*(effective_q_head_num-1)));
    wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] score_concat_data_eff =
            is_gemm_mode ? {score_row, score_concat_data[HBM_CHANNELS*HBM_DATA_WIDTH-AXI_CHNL*AXI_DATA_WIDTH-1:0]} :
                           (score_concat_data & score_concat_lower_mask) | (({HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}} | score_row) << (AXI_CHNL*AXI_DATA_WIDTH*(effective_q_head_num-1)));

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            score_concat_data <= {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}};
            score_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};
        end else begin
            if (score_row_vld) begin
                score_concat_cnt <= score_concat_cnt + 1'b1;
                score_concat_data[AXI_CHNL*AXI_DATA_WIDTH*score_concat_cnt +: AXI_CHNL*AXI_DATA_WIDTH] <= score_row;
                if(score_concat_cnt == (is_gemm_mode ? CONCAT_NUM : effective_q_head_num)-1) begin
                    score_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};
                end
            end
        end
    end

    reg opm_a_row_vld_reg, opm_b_row_vld_reg, cpu_vrf_in_vld_reg;
    reg opm_compute_start_reg;
    reg vec_load_start_reg;
    reg [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_row_reg;
    reg [$clog2(CONCAT_NUM)-1:0] opm_a_row_concat_cnt;

    generate
    if(CORE_NUM == 64) begin : gen_q_concat_core64
        always @(posedge core_clk or negedge rst_n) begin
            if (!rst_n) begin
                opm_a_row_vld_reg <= 1'b0;
                opm_b_row_vld_reg <= 1'b0;
                cpu_vrf_in_vld_reg <= 1'b0;
                d_in_row_reg <= {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}};
                opm_a_row_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};

            end else begin
                opm_a_row_vld_reg <= 1'b0;
                opm_b_row_vld_reg <= opm_b_row_vld;
                cpu_vrf_in_vld_reg <= cpu_vrf_in_vld;

                if (opm_a_row_vld) begin
                    opm_a_row_concat_cnt <= opm_a_row_concat_cnt + 1'b1;
                    d_in_row_reg[2*AXI_CHNL*AXI_DATA_WIDTH*opm_a_row_concat_cnt +: 2*AXI_CHNL*AXI_DATA_WIDTH] <= d_in_row_full[2*AXI_CHNL*AXI_DATA_WIDTH-1:0];
                    if(opm_a_row_concat_cnt == 1) begin
                        opm_a_row_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};
                        opm_a_row_vld_reg <= 1'b1;
                    end
                end else if (opm_b_row_vld) begin
                    d_in_row_reg <= d_in_row_full;
                end
            end
        end
    end else if(CORE_NUM == 128) begin : gen_q_concat_core128
        always @(posedge core_clk or negedge rst_n) begin
            if (!rst_n) begin
                opm_a_row_vld_reg <= 1'b0;
                opm_b_row_vld_reg <= 1'b0;
                cpu_vrf_in_vld_reg <= 1'b0;
                d_in_row_reg <= {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}};
                opm_a_row_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};

            end else begin
                opm_a_row_vld_reg <= 1'b0;
                opm_b_row_vld_reg <= opm_b_row_vld;
                cpu_vrf_in_vld_reg <= cpu_vrf_in_vld;

                if (opm_a_row_vld) begin
                    opm_a_row_concat_cnt <= opm_a_row_concat_cnt + 1'b1;
                    d_in_row_reg[AXI_CHNL*AXI_DATA_WIDTH*opm_a_row_concat_cnt +: AXI_CHNL*AXI_DATA_WIDTH] <= d_in_row_full[AXI_CHNL*AXI_DATA_WIDTH-1:0];
                    if(opm_a_row_concat_cnt == 3) begin
                        opm_a_row_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};
                        opm_a_row_vld_reg <= 1'b1;
                    end
                end else if (opm_b_row_vld) begin
                    d_in_row_reg <= d_in_row_full;
                end
            end
        end
    end else begin : gen_q_concat_core_other
        always @(posedge core_clk or negedge rst_n) begin
            if (!rst_n) begin
                opm_a_row_vld_reg <= 1'b0;
                opm_b_row_vld_reg <= 1'b0;
                cpu_vrf_in_vld_reg <= 1'b0;
                opm_compute_start_reg <= 1'b0;
                vec_load_start_reg <= 1'b0;
                d_in_row_reg <= {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}};
                opm_a_row_concat_cnt <= {($clog2(CONCAT_NUM)){1'b0}};
            end else begin
                opm_a_row_vld_reg        <= opm_a_row_vld;
                opm_b_row_vld_reg        <= opm_b_row_vld;
                cpu_vrf_in_vld_reg       <= cpu_vrf_in_vld;
                opm_compute_start_reg    <= opm_compute_start;
                vec_load_start_reg       <= vec_load_start;

                if (opm_a_row_vld || opm_b_row_vld || residual_row_vld) begin
                    d_in_row_reg <= d_in_row_full;
                end
            end
        end
    end
    endgenerate

    reg                                    residual_row_vld_r;
    reg                                    residual_latch_phase;
    reg                                    residual_to_pmu_vld;
    reg [2*DATA_NUM*DATA_WIDTH-1:0]        residual_to_pmu_data;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            residual_row_vld_r   <= 1'b0;
            residual_latch_phase <= 1'b0;
            residual_to_pmu_vld  <= 1'b0;
            residual_to_pmu_data <= {2*DATA_NUM*DATA_WIDTH{1'b0}};
        end else begin
            residual_row_vld_r <= residual_row_vld;
            residual_to_pmu_vld <= 1'b0;
            if (residual_row_vld_r) begin
                residual_latch_phase <= 1'b0;
                residual_to_pmu_vld  <= 1'b1;
                residual_to_pmu_data <= d_in_row_reg[2*DATA_NUM*DATA_WIDTH-1:0];
            end else if (residual_latch_phase == 1'b0 && residual_to_pmu_vld) begin
                residual_latch_phase <= 1'b1;
                residual_to_pmu_vld  <= 1'b1;
                residual_to_pmu_data <= d_in_row_reg[HBM_CHANNELS*HBM_DATA_WIDTH-1:2*DATA_NUM*DATA_WIDTH];
            end
        end
    end

    reg                scale_zp_vld_reg;
    reg [3072-1:0]     scale_zp_in_reg;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            scale_zp_vld_reg <= 1'b0;
            scale_zp_in_reg  <= {3072{1'b0}};
        end else begin
            scale_zp_vld_reg <= scale_zp_vld;
            if (scale_zp_vld) begin
                scale_zp_in_reg <= scale_zp_in;
            end
        end
    end

    wire vrf_read_valid;
    wire [VRF_ROW_W-1:0] vrf_read_data;

    wire load_done_A, load_done_B;
    wire generate_done_A, generate_done_B;
    wire compute_stop, compute_stop_latch;

    wire opm_a_vld_from_gen    = opm_a_row_vld_reg;
    wire opm_b_vld_from_gen    = opm_b_row_vld_reg;
    wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_from_gen = d_in_row_reg;

    localparam integer VRF_LANES = VRF_ROW_W / DATA_WIDTH;
    wire [VRF_ROW_W-1:0] vrf_read_data_norm;
    wire gemv_rms_active = !is_gemm_mode && gemv_rms_div_vld;
    wire [DATA_WIDTH-1:0] gemv_rms_denom =
            (!gemv_rms_active || gemv_rms_div == {DATA_WIDTH{1'b0}}) ? 16'h3F80 : gemv_rms_div;
    genvar rl;
    generate
    for (rl = 0; rl < VRF_LANES; rl = rl + 1) begin : GEMV_RMS_DIV
        DW_fp_div_inst #(
            .sig_width(7),
            .exp_width(8),
            .ieee_compliance(1)
        ) u_gemv_rms_div (
            .inst_a  (vrf_read_data[DATA_WIDTH*rl +: DATA_WIDTH]),
            .inst_b  (gemv_rms_denom),
            .inst_rnd(3'b000),
            .z_inst  (vrf_read_data_norm[DATA_WIDTH*rl +: DATA_WIDTH]),
            .status_inst()
        );
    end
    endgenerate
    wire [VRF_ROW_W-1:0] vrf_read_data_eff = gemv_rms_active ? vrf_read_data_norm : vrf_read_data;

    wire mpu_a_row_vld_eff = vrf_read_valid || (is_gemm_mode && opm_a_vld_from_gen) || score_concat_vld;
    wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] mpu_a_in_row_eff =
            vrf_read_valid ? vrf_read_data_eff :
            score_concat_vld ? score_concat_data_eff :
            (is_gemm_mode && opm_a_vld_from_gen) ? d_in_from_gen : {HBM_CHANNELS*HBM_DATA_WIDTH{1'b0}};

    wire opm_compute_stop_eff =
            (is_proj_mode && is_residual_mode) ?  compute_stop :
            (is_proj_mode && !is_residual_mode) ? isa_valid  :
            (!is_proj_mode) ?                   compute_stop : 1'b0;

    assign gqa_compute_stop = (!is_proj_mode) ? compute_stop : 1'b0;

    wire gate_active_bn  = (CORE_ID < batch_num);
    wire value_active_bn = is_gating && (CORE_ID >= (CORE_NUM/2)) &&
                           (CORE_ID < ((CORE_NUM/2) + batch_num));
    wire [7:0] batch_num_eff =
                batch_num < CORE_NUM ?
                    ((gate_active_bn || value_active_bn) ? 8'd1 : 8'd0) :
                    (CORE_ID < batch_num[$clog2(CORE_NUM)-1:0] ? ((batch_num >> $clog2(CORE_NUM)) + 8'd1) : (batch_num >> $clog2(CORE_NUM)));

    reg [16:0] vrf_read_cnt;
    reg vrf_read_stall;

    reg [8:0] output_dim_remaining;

    wire vrf_write_valid_mem = cpu_vrf_data_vld || (!is_gemm_mode && opm_a_row_vld_reg);
    wire [VRF_ROW_W-1:0] vrf_write_data_eff =
            cpu_vrf_data_vld    ? cpu_vrf_data_latch    :
            (!is_gemm_mode && opm_a_row_vld_reg) ? d_in_row_reg :
            {VRF_ROW_W{1'b0}};
    wire vrf_read_en =  !is_gemm_mode && !is_proj_mode ? vec_load_start_reg :
                        !is_gemm_mode ? (vec_load_start_reg || opm_compute_start_reg || generate_done_A) : 1'b0;
    wire vrf_read_en_eff = vrf_read_stall ? vec_load_start_reg : vrf_read_en;
    wire [8:0] batch_space_eff = ({1'b0, batch_space} < output_dim_remaining) ? {1'b0, batch_space} : output_dim_remaining;
    wire [8:0] vrf_k_replay_tiles = (!is_gemm_mode && is_proj_mode && !is_residual_mode && !is_gating && !gemv_rms_div_vld && (opm_mode == 2'b01)) ? batch_space_eff : 9'd1;

    always @(posedge core_clk or negedge rst_n) begin
        if(!rst_n) begin
            vrf_read_cnt <= 17'd0;
            vrf_read_stall <= 1'b0;
            output_dim_remaining <= 9'd0;
        end else begin
            if(vrf_read_en_eff) begin
                vrf_read_cnt <= vrf_read_cnt + 17'd1;
                if(vrf_read_cnt == hidden_dim*batch_space_eff-1) begin
                    vrf_read_cnt <= 17'd0;
                    vrf_read_stall <= is_residual_mode;
                    if(output_dim_remaining > {1'b0, batch_space}) begin
                        output_dim_remaining <= output_dim_remaining - {1'b0, batch_space};
                    end
                end else begin
                    vrf_read_stall <= 1'b0;
                end
            end
            if(isa_valid) begin
                vrf_read_cnt <= 17'd0;
                vrf_read_stall <= 1'b0;
                output_dim_remaining <= output_dim;
            end
        end
    end

    mpu_top #(
        .HBM_CHANNELS   (HBM_CHANNELS),
        .HBM_DATA_WIDTH (HBM_DATA_WIDTH),
        .AXI_CHNL       (AXI_CHNL),
        .BLOCK_ROW      (BLOCK_ROW),
        .DATA_WIDTH     (DATA_WIDTH),
        .FMAT_OUT_WIDTH (FMAT_OUT_WIDTH),
        .SCALE_WIDTH    (16),
        .SCALE_ADD_WIDTH(16),
        .MULT_DIMENSION (MULT_DIMENSION),
        .FMAT_SCALE_WIDTH(8),
        .LANE           (64),
        .CORE_ID        (CORE_ID),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM)
    ) u_mpu_top (
        .clk            (core_clk),
        .rst_n          (rst_n),
        .isa_valid      (isa_valid),
        .is_gemm_mode   (is_gemm_mode),
        .is_residual_mode(is_residual_mode),
        .is_proj_mode   (is_proj_mode),
        .group_width    (group_width),
        .batch_num      (batch_num_eff),
        .effective_q_head_num(effective_q_head_num),
        .kv_head_num    (kv_head_num),
        .opm_mode       (opm_mode),
        .opm_compute_start (opm_compute_start_reg),
        .opm_compute_stop  (opm_compute_stop_eff),
        .a_in           (mpu_a_in_row_eff),
        .a_in_vld       (mpu_a_row_vld_eff),
        .b_in           (d_in_from_gen),
        .b_in_vld       (opm_b_vld_from_gen),
        .scale_zp_in_vld(scale_zp_vld_reg),
        .scale_in       (scale_zp_in_reg[1024-1:0]),
        .zp_in          (scale_zp_in_reg[3072-1:1024]),
        .load_done_A   (load_done_A),
        .load_done_B   (load_done_B),
        .generate_done_A(generate_done_A),
        .generate_done_B(generate_done_B),
        .a_row_num      (a_row_num),
        .out_vld        (mpu_out_valid),
        .d_out          (mpu_out_data),
        .block_done     (mpu_block_done)
    );

    pmu_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .MPU_OUT_WIDTH(FMAT_OUT_WIDTH),
        .BLOCK_SIZE(DATA_NUM),
        .BLOCK_ROW(BLOCK_ROW),
        .CORE_NUM(CORE_NUM),
        .CORE_ID(CORE_ID),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS),
        .ENABLE_SWIGLU(0),
        .ENABLE_ROPE(0),
        .ENABLE_QUANT(0)
    ) u_pmu_top (
        .core_clk(core_clk),
        .rst_n(rst_n),

        .isa_valid(isa_valid),
        .is_mode_valid(is_mode_valid),
        .is_gemm_mode(is_gemm_mode),
        .is_proj_mode(is_proj_mode),
        .quant_kv(opm_mode != 2'b01),
        .causal_mode(causal_mode),
        .dest_on_chip(dest_on_chip),
        .hidden_dim(hidden_dim),
        .output_dim(output_dim),
        .seq_row_tiles(seq_row_tiles),
        .is_gating(is_gating),
        .batch_num(batch_num_eff),
        .batch_space(batch_space),

        .start_emit(pmu_start_emit),
        .diag_done(diag_done_in),

        .mpu_row_valid(mpu_out_valid && (is_proj_mode ? 1'b1 : !compute_stop)),
        .mpu_row_data(mpu_out_data),
        .residual_row_vld(residual_to_pmu_vld),
        .residual_row_data(residual_to_pmu_data),

        .reduce_max_vld(reduce_max_vld),
        .reduce_max_value(reduce_max_value),

        .q_row_num(q_row_num),

        .score_row(score_row),
        .score_row_vld(score_row_vld),
        .pmu_row(pmu_row),
        .pmu_row_vld(pmu_row_vld),
        .gqa_q_phase_done(gqa_q_phase_done),
        .gqa_score_phase_done(gqa_score_phase_done),
        .compute_stop(compute_stop),
        .compute_stop_latch(compute_stop_latch)
    );

    vector_register_file #(
        .DIM(DATA_NUM),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH_ROWS(VRF_DEPTH_ROWS)
    ) u_shared_vrf (
        .clk      (core_clk),
        .rst_n    (rst_n),
        .isa_valid(isa_valid),
        .is_proj_mode(is_proj_mode),
        .hidden_dim(hidden_dim),
        .batch_num (batch_num_eff),
        .k_replay_tiles(vrf_k_replay_tiles),
        .prog_en   (vrf_write_valid_mem),
        .prog_data (vrf_write_data_eff),
        .rd_en     (vrf_read_en_eff),
        .rd_vld    (vrf_read_valid),
        .rd_data   (vrf_read_data)
    );

    assign core_compute_done = mpu_block_done;

    reg [AXI_CHNL*AXI_DATA_WIDTH-1:0] result_row_latch;
    reg result_half_sel;
    reg result_out_vld_r;

    wire result_src_vld = !is_mode_valid ? 1'b0 : pmu_row_vld;
    wire [AXI_CHNL*AXI_DATA_WIDTH-1:0] result_src_data = !is_mode_valid ? {AXI_CHNL*AXI_DATA_WIDTH{1'b0}} : pmu_row;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            result_row_latch <= {AXI_CHNL*AXI_DATA_WIDTH{1'b0}};
            result_half_sel  <= 1'b0;
            result_out_vld_r <= 1'b0;
        end else begin
            if (result_src_vld) begin
                result_row_latch <= result_src_data;
                result_half_sel  <= 1'b0;
                result_out_vld_r <= 1'b1;
            end else if (result_half_sel == 1'b0 && result_out_vld_r) begin
                result_half_sel  <= 1'b1;
            end else begin
                result_out_vld_r <= 1'b0;
            end
        end
    end

    assign result_out_vld = result_out_vld_r;
    assign result_row_out = result_half_sel ? result_row_latch[AXI_CHNL*AXI_DATA_WIDTH-1:AXI_CHNL*AXI_DATA_WIDTH/2]
                                            : result_row_latch[AXI_CHNL*AXI_DATA_WIDTH/2-1:0];

endmodule
