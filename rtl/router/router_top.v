// SPDX-License-Identifier: Apache-2.0
module router_top #(
    parameter CORE_NUM       = 8,
    parameter DATA_WIDTH     = 16,
    parameter HBM_CHANNELS   = 8,
    parameter HBM_DATA_WIDTH = 1024
)
(
    input  wire                             core_clk,
    input  wire                             rst_n,

    input  wire                             isa_valid,
    input  wire                             is_mode_valid,
    input  wire                             is_gemm_mode,
    input  wire                             is_proj_mode,
    input  wire                             is_residual_mode,
    input  wire                             dest_on_chip,
    input  wire [7:0]                       batch_num,
    input  wire [1:0]                       group_width,
    input  wire [1:0]                       opm_mode,

    input  wire                             reduce_max_vld,
    input  wire [DATA_WIDTH-1:0]            reduce_max_value,

    input  wire [CORE_NUM-1:0]              diag_done_in,
    input  wire                             vec_load_start,

    input  wire [8:0]                       hidden_dim,
    input  wire [8:0]                       output_dim,
    input  wire [7:0]                       batch_space,
    input  wire [5:0]                       group_size,

    input  wire [CORE_NUM-1:0]              dense_routing_id,
    input  wire                             opm_a_row_vld,
    input  wire                             opm_b_row_vld,
    input  wire                             residual_row_vld,
    input  wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_row,

    input  wire [CORE_NUM-1:0]              scale_zp_routing_id,
    input  wire                             scale_zp_vld,
    input  wire [3072-1:0]                  scale_zp_in,

    input  wire [CORE_NUM-1:0]              opm_compute_start,
    input  wire [CORE_NUM-1:0]              pmu_start_emit,
    input  wire [CORE_NUM-1:0]              cpu_vrf_in_vld,
    input  wire [63:0]                      cpu_vrf_row_data,

    output wire [CORE_NUM-1:0]              isa_valid_out,
    output wire [CORE_NUM-1:0]              is_mode_valid_out,
    output wire [CORE_NUM-1:0]              is_gemm_mode_out,
    output wire [CORE_NUM-1:0]              is_proj_mode_out,
    output wire [CORE_NUM-1:0]              is_residual_mode_out,
    output wire [CORE_NUM-1:0]              dest_on_chip_out,
    output wire [CORE_NUM*8-1:0]            batch_num_out,
    output wire [CORE_NUM*2-1:0]            group_width_out,
    output wire [CORE_NUM*2-1:0]            opm_mode_out,

    output wire [CORE_NUM-1:0]              reduce_max_vld_out,
    output wire [CORE_NUM*DATA_WIDTH-1:0]   reduce_max_value_out,

    output wire [CORE_NUM-1:0]              diag_done_in_out,
    output wire [CORE_NUM-1:0]              vec_load_start_out,

    output wire [CORE_NUM*9-1:0]            hidden_dim_out,
    output wire [CORE_NUM*9-1:0]            output_dim_out,
    output wire [CORE_NUM*8-1:0]            batch_space_out,
    output wire [CORE_NUM*6-1:0]            group_size_out,

    output wire [CORE_NUM-1:0]              opm_a_row_vld_out,
    output wire [CORE_NUM-1:0]              opm_b_row_vld_out,
    output wire [CORE_NUM-1:0]              residual_row_vld_out,
    output wire [CORE_NUM*HBM_CHANNELS*HBM_DATA_WIDTH-1:0] d_in_row_out,

    output wire [CORE_NUM-1:0]              scale_zp_vld_out,
    output wire [CORE_NUM*3072-1:0]         scale_zp_in_out,

    output wire [CORE_NUM-1:0]              opm_compute_start_out,
    output wire [CORE_NUM-1:0]              pmu_start_emit_out,
    output wire [CORE_NUM-1:0]              cpu_vrf_in_vld_out,
    output wire [CORE_NUM*64-1:0]           cpu_vrf_row_data_out
);

    localparam DIN_W    = HBM_CHANNELS * HBM_DATA_WIDTH;
    localparam SZP_W    = 3072;
    localparam VRF_W    = 64;
    localparam S2_NUM   = (CORE_NUM/4 >= 1) ? CORE_NUM/4 : 1;
    localparam S3_NUM   = (CORE_NUM/2 >= 1) ? CORE_NUM/2 : 1;
    localparam S2_CORES = CORE_NUM / S2_NUM;
    localparam S3_CORES = CORE_NUM / S3_NUM;
    localparam S2_FAN   = S3_NUM / S2_NUM;
    localparam OUT_FAN  = CORE_NUM / S3_NUM;

    genvar gi;

    reg                    s1_isa_valid;
    reg                    s1_is_mode_valid;
    reg                    s1_is_gemm_mode;
    reg                    s1_is_proj_mode;
    reg                    s1_is_residual_mode;
    reg                    s1_dest_on_chip;
    reg [7:0]              s1_batch_num;
    reg [1:0]              s1_group_width;
    reg [1:0]              s1_opm_mode;
    reg                    s1_reduce_max_vld;
    reg [DATA_WIDTH-1:0]   s1_reduce_max_value;
    reg [8:0]              s1_hidden_dim;
    reg [8:0]              s1_output_dim;
    reg [7:0]              s1_batch_space;
    reg [5:0]              s1_group_size;

    reg [CORE_NUM-1:0]     s1_diag_done_in;
    reg                    s1_vec_load_start;

    reg [CORE_NUM-1:0]     s1_dense_rid;
    reg                    s1_opm_a_row_vld;
    reg                    s1_opm_b_row_vld;
    reg                    s1_residual_row_vld;
    reg [DIN_W-1:0]        s1_d_in_row;

    reg [CORE_NUM-1:0]     s1_szp_rid;
    reg                    s1_scale_zp_vld;
    reg [SZP_W-1:0]        s1_scale_zp_in;

    reg [CORE_NUM-1:0]     s1_opm_compute_start;
    reg [CORE_NUM-1:0]     s1_pmu_start_emit;
    reg [CORE_NUM-1:0]     s1_cpu_vrf_in_vld;

    reg [VRF_W-1:0]        s1_cpu_vrf_row_data;

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_isa_valid            <= 1'b0;
            s1_is_mode_valid        <= 1'b0;
            s1_is_gemm_mode         <= 1'b0;
            s1_is_proj_mode         <= 1'b0;
            s1_is_residual_mode     <= 1'b0;
            s1_dest_on_chip         <= 1'b0;
            s1_batch_num            <= 8'd0;
            s1_group_width          <= 2'd0;
            s1_opm_mode             <= 2'd0;
            s1_reduce_max_vld       <= 1'b0;
            s1_reduce_max_value     <= {DATA_WIDTH{1'b0}};
            s1_hidden_dim           <= 9'd0;
            s1_output_dim           <= 9'd0;
            s1_batch_space          <= 8'd0;
            s1_group_size           <= 6'd0;
            s1_diag_done_in         <= {CORE_NUM{1'b0}};
            s1_vec_load_start       <= 1'b0;
            s1_dense_rid            <= {CORE_NUM{1'b0}};
            s1_opm_a_row_vld        <= 1'b0;
            s1_opm_b_row_vld        <= 1'b0;
            s1_residual_row_vld     <= 1'b0;
            s1_d_in_row             <= {DIN_W{1'b0}};
            s1_szp_rid              <= {CORE_NUM{1'b0}};
            s1_scale_zp_vld         <= 1'b0;
            s1_scale_zp_in          <= {SZP_W{1'b0}};
            s1_opm_compute_start    <= {CORE_NUM{1'b0}};
            s1_pmu_start_emit       <= {CORE_NUM{1'b0}};
            s1_cpu_vrf_in_vld       <= {CORE_NUM{1'b0}};
            s1_cpu_vrf_row_data     <= {VRF_W{1'b0}};
        end else begin
            s1_isa_valid            <= isa_valid;
            s1_is_mode_valid        <= is_mode_valid;
            s1_is_gemm_mode         <= is_gemm_mode;
            s1_is_proj_mode         <= is_proj_mode;
            s1_is_residual_mode     <= is_residual_mode;
            s1_dest_on_chip         <= dest_on_chip;
            s1_batch_num            <= batch_num;
            s1_group_width          <= group_width;
            s1_opm_mode             <= opm_mode;
            s1_reduce_max_vld       <= reduce_max_vld;
            s1_reduce_max_value     <= reduce_max_value;
            s1_hidden_dim           <= hidden_dim;
            s1_output_dim           <= output_dim;
            s1_batch_space          <= batch_space;
            s1_group_size           <= group_size;
            s1_diag_done_in         <= diag_done_in;
            s1_vec_load_start       <= vec_load_start;
            s1_dense_rid            <= dense_routing_id;
            s1_opm_a_row_vld        <= opm_a_row_vld;
            s1_opm_b_row_vld        <= opm_b_row_vld;
            s1_residual_row_vld     <= residual_row_vld;
            s1_d_in_row             <= d_in_row;
            s1_szp_rid              <= scale_zp_routing_id;
            s1_scale_zp_vld         <= scale_zp_vld;
            s1_scale_zp_in          <= scale_zp_in;
            s1_opm_compute_start    <= opm_compute_start;
            s1_pmu_start_emit       <= pmu_start_emit;
            s1_cpu_vrf_in_vld       <= cpu_vrf_in_vld;
            s1_cpu_vrf_row_data     <= cpu_vrf_row_data;
        end
    end

    generate
    for (gi = 0; gi < S2_NUM; gi = gi + 1) begin : s2

        reg                    r_isa_valid;
        reg                    r_is_mode_valid;
        reg                    r_is_gemm_mode;
        reg                    r_is_proj_mode;
        reg                    r_is_residual_mode;
        reg                    r_dest_on_chip;
        reg [7:0]              r_batch_num;
        reg [1:0]              r_group_width;
        reg [1:0]              r_opm_mode;
        reg                    r_reduce_max_vld;
        reg [DATA_WIDTH-1:0]   r_reduce_max_value;
        reg [8:0]              r_hidden_dim;
        reg [8:0]              r_output_dim;
        reg [7:0]              r_batch_space;
        reg [5:0]              r_group_size;

        reg [S2_CORES-1:0]     r_diag_done_in;
        reg                    r_vec_load_start;

        reg [S2_CORES-1:0]     r_dense_rid;
        reg                    r_opm_a_row_vld;
        reg                    r_opm_b_row_vld;
        reg                    r_residual_row_vld;
        reg [DIN_W-1:0]        r_d_in_row;

        reg [S2_CORES-1:0]     r_szp_rid;
        reg                    r_scale_zp_vld;
        reg [SZP_W-1:0]        r_scale_zp_in;

        reg [S2_CORES-1:0]     r_opm_compute_start;
        reg [S2_CORES-1:0]     r_pmu_start_emit;
        reg [S2_CORES-1:0]     r_cpu_vrf_in_vld;

        reg [VRF_W-1:0]        r_cpu_vrf_row_data;

        wire dense_active = |s1_dense_rid[gi*S2_CORES +: S2_CORES];
        wire szp_active   = |s1_szp_rid  [gi*S2_CORES +: S2_CORES];
        wire cvrf_in_act  = |s1_cpu_vrf_in_vld    [gi*S2_CORES +: S2_CORES];

        always @(posedge core_clk or negedge rst_n) begin
            if (!rst_n) begin
                r_isa_valid            <= 1'b0;
                r_is_mode_valid        <= 1'b0;
                r_is_gemm_mode         <= 1'b0;
                r_is_proj_mode         <= 1'b0;
                r_is_residual_mode     <= 1'b0;
                r_dest_on_chip         <= 1'b0;
                r_batch_num            <= 8'd0;
                r_group_width          <= 2'd0;
                r_opm_mode             <= 2'd0;
                r_reduce_max_vld       <= 1'b0;
                r_reduce_max_value     <= {DATA_WIDTH{1'b0}};
                r_hidden_dim           <= 9'd0;
                r_output_dim           <= 9'd0;
                r_batch_space          <= 8'd0;
                r_group_size           <= 6'd0;
                r_diag_done_in         <= {S2_CORES{1'b0}};
                r_vec_load_start       <= 1'b0;
                r_dense_rid            <= {S2_CORES{1'b0}};
                r_opm_a_row_vld        <= 1'b0;
                r_opm_b_row_vld        <= 1'b0;
                r_residual_row_vld     <= 1'b0;
                r_d_in_row             <= {DIN_W{1'b0}};
                r_szp_rid              <= {S2_CORES{1'b0}};
                r_scale_zp_vld         <= 1'b0;
                r_scale_zp_in          <= {SZP_W{1'b0}};
                r_opm_compute_start    <= {S2_CORES{1'b0}};
                r_pmu_start_emit       <= {S2_CORES{1'b0}};
                r_cpu_vrf_in_vld       <= {S2_CORES{1'b0}};
                r_cpu_vrf_row_data     <= {VRF_W{1'b0}};
            end else begin
                r_isa_valid            <= s1_isa_valid;
                r_is_mode_valid        <= s1_is_mode_valid;
                r_is_gemm_mode         <= s1_is_gemm_mode;
                r_is_proj_mode         <= s1_is_proj_mode;
                r_is_residual_mode     <= s1_is_residual_mode;
                r_dest_on_chip         <= s1_dest_on_chip;
                r_batch_num            <= s1_batch_num;
                r_group_width          <= s1_group_width;
                r_opm_mode             <= s1_opm_mode;
                r_reduce_max_vld       <= s1_reduce_max_vld;
                r_reduce_max_value     <= s1_reduce_max_value;
                r_hidden_dim           <= s1_hidden_dim;
                r_output_dim           <= s1_output_dim;
                r_batch_space          <= s1_batch_space;
                r_group_size           <= s1_group_size;

                r_diag_done_in         <= s1_diag_done_in[gi*S2_CORES +: S2_CORES];
                r_vec_load_start       <= s1_vec_load_start;

                r_dense_rid            <= s1_dense_rid[gi*S2_CORES +: S2_CORES];
                r_opm_a_row_vld        <= dense_active ? s1_opm_a_row_vld    : 1'b0;
                r_opm_b_row_vld        <= dense_active ? s1_opm_b_row_vld    : 1'b0;
                r_residual_row_vld     <= dense_active ? s1_residual_row_vld  : 1'b0;
                r_d_in_row             <= dense_active ? s1_d_in_row          : {DIN_W{1'b0}};

                r_szp_rid              <= s1_szp_rid[gi*S2_CORES +: S2_CORES];
                r_scale_zp_vld         <= szp_active ? s1_scale_zp_vld : 1'b0;
                r_scale_zp_in          <= szp_active ? s1_scale_zp_in  : {SZP_W{1'b0}};

                r_opm_compute_start    <= s1_opm_compute_start [gi*S2_CORES +: S2_CORES];
                r_pmu_start_emit       <= s1_pmu_start_emit    [gi*S2_CORES +: S2_CORES];
                r_cpu_vrf_in_vld       <= s1_cpu_vrf_in_vld    [gi*S2_CORES +: S2_CORES];

                r_cpu_vrf_row_data     <= cvrf_in_act  ? s1_cpu_vrf_row_data    : {VRF_W{1'b0}};
            end
        end

    end
    endgenerate

    generate
    for (gi = 0; gi < S3_NUM; gi = gi + 1) begin : s3

        reg                    r_isa_valid;
        reg                    r_is_mode_valid;
        reg                    r_is_gemm_mode;
        reg                    r_is_proj_mode;
        reg                    r_is_residual_mode;
        reg                    r_dest_on_chip;
        reg [7:0]              r_batch_num;
        reg [1:0]              r_group_width;
        reg [1:0]              r_opm_mode;
        reg                    r_reduce_max_vld;
        reg [DATA_WIDTH-1:0]   r_reduce_max_value;
        reg [8:0]              r_hidden_dim;
        reg [8:0]              r_output_dim;
        reg [7:0]              r_batch_space;
        reg [5:0]              r_group_size;

        reg [S3_CORES-1:0]     r_diag_done_in;
        reg                    r_vec_load_start;

        reg [S3_CORES-1:0]     r_dense_rid;
        reg                    r_opm_a_row_vld;
        reg                    r_opm_b_row_vld;
        reg                    r_residual_row_vld;
        reg [DIN_W-1:0]        r_d_in_row;

        reg [S3_CORES-1:0]     r_szp_rid;
        reg                    r_scale_zp_vld;
        reg [SZP_W-1:0]        r_scale_zp_in;

        reg [S3_CORES-1:0]     r_opm_compute_start;
        reg [S3_CORES-1:0]     r_pmu_start_emit;
        reg [S3_CORES-1:0]     r_cpu_vrf_in_vld;

        reg [VRF_W-1:0]        r_cpu_vrf_row_data;

        wire dense_active = |s2[gi/S2_FAN].r_dense_rid[(gi%S2_FAN)*S3_CORES +: S3_CORES];
        wire szp_active   = |s2[gi/S2_FAN].r_szp_rid  [(gi%S2_FAN)*S3_CORES +: S3_CORES];
        wire cvrf_in_act  = |s2[gi/S2_FAN].r_cpu_vrf_in_vld    [(gi%S2_FAN)*S3_CORES +: S3_CORES];

        always @(posedge core_clk or negedge rst_n) begin
            if (!rst_n) begin
                r_isa_valid            <= 1'b0;
                r_is_mode_valid        <= 1'b0;
                r_is_gemm_mode         <= 1'b0;
                r_is_proj_mode         <= 1'b0;
                r_is_residual_mode     <= 1'b0;
                r_dest_on_chip         <= 1'b0;
                r_batch_num            <= 8'd0;
                r_group_width          <= 2'd0;
                r_opm_mode             <= 2'd0;
                r_reduce_max_vld       <= 1'b0;
                r_reduce_max_value     <= {DATA_WIDTH{1'b0}};
                r_hidden_dim           <= 9'd0;
                r_output_dim           <= 9'd0;
                r_batch_space          <= 8'd0;
                r_group_size           <= 6'd0;
                r_diag_done_in         <= {S3_CORES{1'b0}};
                r_vec_load_start       <= 1'b0;
                r_dense_rid            <= {S3_CORES{1'b0}};
                r_opm_a_row_vld        <= 1'b0;
                r_opm_b_row_vld        <= 1'b0;
                r_residual_row_vld     <= 1'b0;
                r_d_in_row             <= {DIN_W{1'b0}};
                r_szp_rid              <= {S3_CORES{1'b0}};
                r_scale_zp_vld         <= 1'b0;
                r_scale_zp_in          <= {SZP_W{1'b0}};
                r_pmu_start_emit       <= {S3_CORES{1'b0}};
                r_cpu_vrf_in_vld       <= {S3_CORES{1'b0}};
                r_opm_compute_start    <= {S3_CORES{1'b0}};
                r_cpu_vrf_row_data     <= {VRF_W{1'b0}};
            end else begin
                r_isa_valid            <= s2[gi/S2_FAN].r_isa_valid;
                r_is_mode_valid        <= s2[gi/S2_FAN].r_is_mode_valid;
                r_is_gemm_mode         <= s2[gi/S2_FAN].r_is_gemm_mode;
                r_is_proj_mode         <= s2[gi/S2_FAN].r_is_proj_mode;
                r_is_residual_mode     <= s2[gi/S2_FAN].r_is_residual_mode;
                r_dest_on_chip         <= s2[gi/S2_FAN].r_dest_on_chip;
                r_batch_num            <= s2[gi/S2_FAN].r_batch_num;
                r_group_width          <= s2[gi/S2_FAN].r_group_width;
                r_opm_mode             <= s2[gi/S2_FAN].r_opm_mode;
                r_reduce_max_vld       <= s2[gi/S2_FAN].r_reduce_max_vld;
                r_reduce_max_value     <= s2[gi/S2_FAN].r_reduce_max_value;
                r_hidden_dim           <= s2[gi/S2_FAN].r_hidden_dim;
                r_output_dim           <= s2[gi/S2_FAN].r_output_dim;
                r_batch_space          <= s2[gi/S2_FAN].r_batch_space;
                r_group_size           <= s2[gi/S2_FAN].r_group_size;

                r_diag_done_in         <= s2[gi/S2_FAN].r_diag_done_in[(gi%S2_FAN)*S3_CORES +: S3_CORES];
                r_vec_load_start       <= s2[gi/S2_FAN].r_vec_load_start;

                r_dense_rid            <= s2[gi/S2_FAN].r_dense_rid[(gi%S2_FAN)*S3_CORES +: S3_CORES];
                r_opm_a_row_vld        <= dense_active ? s2[gi/S2_FAN].r_opm_a_row_vld    : 1'b0;
                r_opm_b_row_vld        <= dense_active ? s2[gi/S2_FAN].r_opm_b_row_vld    : 1'b0;
                r_residual_row_vld     <= dense_active ? s2[gi/S2_FAN].r_residual_row_vld  : 1'b0;
                r_d_in_row             <= dense_active ? s2[gi/S2_FAN].r_d_in_row          : {DIN_W{1'b0}};

                r_szp_rid              <= s2[gi/S2_FAN].r_szp_rid[(gi%S2_FAN)*S3_CORES +: S3_CORES];
                r_scale_zp_vld         <= szp_active ? s2[gi/S2_FAN].r_scale_zp_vld : 1'b0;
                r_scale_zp_in          <= szp_active ? s2[gi/S2_FAN].r_scale_zp_in  : {SZP_W{1'b0}};

                r_opm_compute_start    <= s2[gi/S2_FAN].r_opm_compute_start[(gi%S2_FAN)*S3_CORES +: S3_CORES];
                r_pmu_start_emit       <= s2[gi/S2_FAN].r_pmu_start_emit    [(gi%S2_FAN)*S3_CORES +: S3_CORES];
                r_cpu_vrf_in_vld       <= s2[gi/S2_FAN].r_cpu_vrf_in_vld    [(gi%S2_FAN)*S3_CORES +: S3_CORES];

                r_cpu_vrf_row_data     <= cvrf_in_act  ? s2[gi/S2_FAN].r_cpu_vrf_row_data    : {VRF_W{1'b0}};
            end
        end

    end
    endgenerate

    generate
    for (gi = 0; gi < CORE_NUM; gi = gi + 1) begin : out_assign

        assign isa_valid_out[gi]                                     = s3[gi/OUT_FAN].r_isa_valid;
        assign is_mode_valid_out[gi]                                 = s3[gi/OUT_FAN].r_is_mode_valid;
        assign is_gemm_mode_out[gi]                                  = s3[gi/OUT_FAN].r_is_gemm_mode;
        assign is_proj_mode_out[gi]                                  = s3[gi/OUT_FAN].r_is_proj_mode;
        assign is_residual_mode_out[gi]                                = s3[gi/OUT_FAN].r_is_residual_mode;
        assign dest_on_chip_out[gi]                                  = s3[gi/OUT_FAN].r_dest_on_chip;
        assign batch_num_out[gi*8 +: 8]                              = s3[gi/OUT_FAN].r_batch_num;
        assign group_width_out[gi*2 +: 2]                            = s3[gi/OUT_FAN].r_group_width;
        assign opm_mode_out[gi*2 +: 2]                               = s3[gi/OUT_FAN].r_opm_mode;
        assign reduce_max_vld_out[gi]                                = s3[gi/OUT_FAN].r_reduce_max_vld;
        assign reduce_max_value_out[gi*DATA_WIDTH +: DATA_WIDTH]     = s3[gi/OUT_FAN].r_reduce_max_value;

        assign diag_done_in_out[gi]      = s3[gi/OUT_FAN].r_diag_done_in[gi%OUT_FAN];
        assign vec_load_start_out[gi]    = s3[gi/OUT_FAN].r_vec_load_start;
        assign hidden_dim_out[gi*9 +: 9] = s3[gi/OUT_FAN].r_hidden_dim;
        assign output_dim_out[gi*9 +: 9] = s3[gi/OUT_FAN].r_output_dim;
        assign batch_space_out[gi*8 +: 8] = s3[gi/OUT_FAN].r_batch_space;
        assign group_size_out[gi*6 +: 6] = s3[gi/OUT_FAN].r_group_size;

        assign opm_a_row_vld_out[gi]                                 = s3[gi/OUT_FAN].r_dense_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_opm_a_row_vld    : 1'b0;
        assign opm_b_row_vld_out[gi]                                 = s3[gi/OUT_FAN].r_dense_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_opm_b_row_vld    : 1'b0;
        assign residual_row_vld_out[gi]                              = s3[gi/OUT_FAN].r_dense_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_residual_row_vld  : 1'b0;
        assign d_in_row_out[gi*DIN_W +: DIN_W]                       = s3[gi/OUT_FAN].r_dense_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_d_in_row          : {DIN_W{1'b0}};

        assign scale_zp_vld_out[gi]                                  = s3[gi/OUT_FAN].r_szp_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_scale_zp_vld : 1'b0;
        assign scale_zp_in_out[gi*SZP_W +: SZP_W]                    = s3[gi/OUT_FAN].r_szp_rid[gi%OUT_FAN] ? s3[gi/OUT_FAN].r_scale_zp_in  : {SZP_W{1'b0}};

        assign opm_compute_start_out[gi]    = s3[gi/OUT_FAN].r_opm_compute_start[gi%OUT_FAN];
        assign pmu_start_emit_out[gi]     = s3[gi/OUT_FAN].r_pmu_start_emit    [gi%OUT_FAN];
        assign cpu_vrf_in_vld_out[gi]     = s3[gi/OUT_FAN].r_cpu_vrf_in_vld    [gi%OUT_FAN];

        assign cpu_vrf_row_data_out[gi*VRF_W +: VRF_W]    = s3[gi/OUT_FAN].r_cpu_vrf_in_vld[gi%OUT_FAN] ?
                                                             s3[gi/OUT_FAN].r_cpu_vrf_row_data    : {VRF_W{1'b0}};

    end
    endgenerate

endmodule