// SPDX-License-Identifier: Apache-2.0
module unpacker_top #(
    parameter CORE_NUM        = 8,
    parameter CHIP_DATA_WIDTH = 4096,
    parameter MEM_DATA_WIDTH  = 8192,
    parameter [3:0] GEMM_A_XFERS = 4'd2,
    parameter [3:0] GEMM_W_XFERS = 4'd4,
    parameter SCALE_W       = CHIP_DATA_WIDTH/4,
    parameter ZP_W          = CHIP_DATA_WIDTH/2,
    parameter SZP_OUT_WIDTH = 3*CHIP_DATA_WIDTH/4,
    parameter INT2_ELEMS    = CHIP_DATA_WIDTH/2,
    parameter INT4_ELEMS    = CHIP_DATA_WIDTH/4,
    parameter integer DQ_BANK_ELEMS = 128,
    parameter integer DQ_SHARE_KV   = 0
)
(
    input wire              clk,
    input wire              rst_n,

    input wire              isa_valid,
    input wire              a_on_chip,
    input wire              is_gemm_mode,
    input wire              is_proj_mode,
    input wire              is_residual_mode,
    input wire              is_norm_mode,
    input wire              is_gating_mode,

    input wire [31:0]       seq_len,
    input wire [15:0]       hidden_dim,
    input wire [15:0]       output_dim,
    input wire [7:0]        batch_num,
    input wire [7:0]        batch_space,
    input wire [1:0]        group_width,
    input wire [5:0]        group_size,
    input wire [15:0]       window_size,
    input wire [4:0]        w_precision,
    input wire [4:0]        k_precision,
    input wire [4:0]        v_precision,
    input wire [7:0]        outlier_num,
    input wire [5:0]        decode_core_num,

    input wire [1:0]        gemm_proj_routing_mode,

    input wire              rom_wen,
    input wire [101:0]      rom_wdata,

    input wire              in_vld,
    input wire [CHIP_DATA_WIDTH-1:0]     in_data,

    output reg              residual_load_done,

    output wire               dim_read_done,
    output reg [CORE_NUM-1:0] diag_done,

    output reg              dense_a_out_vld,
    output reg              dense_b_out_vld,
    output reg              dense_r_out_vld,
    output reg              scale_zp_out_vld,
    output reg [CORE_NUM-1:0] dense_routing_id,
    output reg [CORE_NUM-1:0] scale_zp_routing_id,
    output reg [MEM_DATA_WIDTH-1:0]     dense_out_data,
    output reg [SZP_OUT_WIDTH-1:0]      scale_zp_out_data,
    output reg [CORE_NUM-1:0] vec_load_start,
    output reg [CORE_NUM-1:0] opm_compute_start,

    output reg [15:0]           gemv_rms_div,
    output reg                  gemv_rms_div_vld
);

    genvar gi;

    localparam [2:0] GVPF_IDLE = 3'd0;
    localparam [2:0] GVPF_RMS  = 3'd1;
    localparam [2:0] GVPF_ACT  = 3'd2;
    localparam [2:0] GVPF_WT   = 3'd3;
    localparam [2:0] GVPF_RES  = 3'd4;
    reg  [2:0]               gvpf_state;

    reg                      gmp_rms_phase;
    reg                      gvpl_rms_phase;
    reg                      gmp_residual_phase;
    reg                      residual_phase;

    wire [6:0]               gmp_low_tile_xfers;

    reg  [2:0]               gpl_state_d1, gpl_state_d2, gpl_state_d3;
    reg                      pnorm_rms_phase_d1, pnorm_rms_phase_d2, pnorm_rms_phase_d3;
    reg  [CORE_NUM-1:0]      route_pipe_lp_d1, route_pipe_lp_d2, route_pipe_lp_d3;

    reg  [CORE_NUM-1:0]      gmp_wt_route;
    wire [CORE_NUM-1:0]      gv_wkv_route;

    reg  [CORE_NUM-1:0]      gmp_act_route;
    reg  [CORE_NUM-1:0]      gmp_residual_route;
    wire [CORE_NUM-1:0]      gvp_act_route;
    wire [CORE_NUM-1:0]      gvp_res_route;

    wire [15:0]              gvpl_wt_chunk_w;
    wire                     gvpl_wt_all_done;

    reg                      gvpl_dim_read_done_r;

    wire mode_gemm_proj_full_prec = is_gemm_mode && is_proj_mode && w_precision == 5'd16;
    wire mode_gemm_proj_low_prec = is_gemm_mode && is_proj_mode && w_precision != 5'd16;
    wire mode_gemm_gqa  = is_gemm_mode && !is_proj_mode;
    wire mode_gemv_proj_full_prec = !is_gemm_mode && is_proj_mode && w_precision == 5'd16;
    wire mode_gemv_proj_low_prec = !is_gemm_mode && is_proj_mode && w_precision != 5'd16;
    wire mode_gemv_gqa  = !is_gemm_mode && !is_proj_mode;

    localparam integer GVPF_FIRST_B_TILE_DENSE_BEATS =
        (128 * 128 * 16) / MEM_DATA_WIDTH;
    wire gvpf_bypass_stream_launch =
        mode_gemv_proj_full_prec &&
        !is_norm_mode && !is_residual_mode && !is_gating_mode;

    wire [7:0]  compress_bits;
    wire [13:0] out_shift_bits;
    wire [10:0] bookmark_capacity;
    wire [6:0]  outlier_pos_length;
    wire [6:0]  outlier_val_length;

    reg         decomp_in_vld;
    reg  [102*16-1:0] decomp_in_data;
    reg         decomp_val_in_vld;
    reg  [CHIP_DATA_WIDTH-1:0] decomp_val_in_data;
    wire        decomp_out_vld;
    wire [CHIP_DATA_WIDTH-1:0] decomp_out_data;

    wire decomp_int2_or_int4 = mode_gemv_gqa ? (k_precision == 5'd4) :
                               mode_gemv_proj_low_prec ? (w_precision == 5'd4) :
                               mode_gemm_proj_low_prec ? (w_precision == 5'd4) : 1'b0;

    reg         pnorm_row_in_vld;
    reg  [CHIP_DATA_WIDTH-1:0] pnorm_row_din;
    wire        pnorm_out_vld;
    wire [CHIP_DATA_WIDTH-1:0] pnorm_out;

    reg rms_phase;
    wire [9:0] rms_tile_xfers = 2 + 2*(((hidden_dim << 4) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));
    wire gvpf_rms_phase;
    wire pnorm_rms_phase = rms_phase || gmp_rms_phase || gvpf_rms_phase || gvpl_rms_phase;

    localparam [2:0] NUM_SUBS = (GEMM_A_XFERS == 3'd0) ? 3'd1 : (3'd4 / GEMM_A_XFERS);

    wire [15:0] hidden_div128 = {6'd0, hidden_dim[15:7]};
    wire [15:0] output_div128 = {6'd0, output_dim[15:7]};
    wire [31:0] phases_per_sub_full = ({16'd0, hidden_div128} * {16'd0, output_div128}) >> $clog2(GEMM_W_XFERS);
    wire [15:0] phases_per_sub = phases_per_sub_full[15:0];

    wire [15:0] gemv_act_ceil = ((hidden_dim << 4) + 16'd8191) >> 13;
    wire [5:0]  gemv_act_xfers = {gemv_act_ceil[4:0], 1'b0};
    wire [5:0]  pnorm_act_xfers = is_gemm_mode ? {3'd0, GEMM_A_XFERS} : gemv_act_xfers;

    localparam [15:0] DQ_I2_DEFAULT   = 16'h3210;
    localparam [63:0] DQ_I4_DEFAULT_L = 64'h4E4C_4A48_4440_3800;
    localparam [63:0] DQ_I4_DEFAULT_H = 64'hCECC_CAC8_C4C0_B880;

    localparam [5:0] DQ_CFG_TAG = 6'b111111;
    localparam [2:0] DQ_SEL_I2  = 3'd0,
                     DQ_SEL_I4L = 3'd1,
                     DQ_SEL_I4H = 3'd2,
                     DQ_SEL_RST = 3'd3;

`ifdef DQ_LUT_CFG_OFF
    wire dq_cfg_wen = 1'b0;
`else
    wire dq_cfg_wen = rom_wen && (rom_wdata[101:96] == DQ_CFG_TAG);
`endif
    wire [2:0] dq_cfg_sel = rom_wdata[95:93];

`ifdef DQLUT_SIM_INIT
    reg [15:0] dq_i2_init;
    reg [63:0] dq_i4l_init, dq_i4h_init;
    initial begin
        dq_i2_init  = DQ_I2_DEFAULT;
        dq_i4l_init = DQ_I4_DEFAULT_L;
        dq_i4h_init = DQ_I4_DEFAULT_H;
        if ($value$plusargs("DQLUT_I2=%h",  dq_i2_init))  $display("[DQLUT] i2  init = %04h",  dq_i2_init);
        if ($value$plusargs("DQLUT_I4L=%h", dq_i4l_init)) $display("[DQLUT] i4L init = %016h", dq_i4l_init);
        if ($value$plusargs("DQLUT_I4H=%h", dq_i4h_init)) $display("[DQLUT] i4H init = %016h", dq_i4h_init);
    end
`else
    wire [15:0] dq_i2_init  = DQ_I2_DEFAULT;
    wire [63:0] dq_i4l_init = DQ_I4_DEFAULT_L;
    wire [63:0] dq_i4h_init = DQ_I4_DEFAULT_H;
`endif

    reg [15:0]  dq_i2_shadow;
    reg [127:0] dq_i4_shadow;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dq_i2_shadow <= dq_i2_init;
            dq_i4_shadow <= {dq_i4h_init, dq_i4l_init};
        end else if (dq_cfg_wen) begin
            case (dq_cfg_sel)
                DQ_SEL_I2 : dq_i2_shadow          <= rom_wdata[15:0];
                DQ_SEL_I4L: dq_i4_shadow[63:0]    <= rom_wdata[63:0];
                DQ_SEL_I4H: dq_i4_shadow[127:64]  <= rom_wdata[63:0];
                DQ_SEL_RST: begin
                              dq_i2_shadow        <= DQ_I2_DEFAULT;
                              dq_i4_shadow        <= {DQ_I4_DEFAULT_H, DQ_I4_DEFAULT_L};
                            end
                default   : ;
            endcase
        end
    end

    localparam integer DQ_I2_BE     = (DQ_BANK_ELEMS > INT2_ELEMS) ? INT2_ELEMS : DQ_BANK_ELEMS;
    localparam integer DQ_I4_BE     = (DQ_BANK_ELEMS > INT4_ELEMS) ? INT4_ELEMS : DQ_BANK_ELEMS;
    localparam integer DQ_I2_BPA    = INT2_ELEMS / DQ_I2_BE;
    localparam integer DQ_I4_BPA    = INT4_ELEMS / DQ_I4_BE;
    localparam integer DQ_I2_COPIES = 4 * DQ_I2_BPA;
    localparam integer DQ_I4_COPIES = 4 * DQ_I4_BPA;
    localparam integer DQA_K   = 0;
    localparam integer DQA_V   = 1;
    localparam integer DQA_GKV = 2;
    localparam integer DQA_GKM = 3;

    reg [16*DQ_I2_COPIES-1:0]  dq_i2_bank;
    reg [128*DQ_I4_COPIES-1:0] dq_i4_bank;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dq_i2_bank <= {DQ_I2_COPIES{dq_i2_init}};
            dq_i4_bank <= {DQ_I4_COPIES{{dq_i4h_init, dq_i4l_init}}};
        end else if (isa_valid) begin
            dq_i2_bank <= {DQ_I2_COPIES{dq_i2_shadow}};
            dq_i4_bank <= {DQ_I4_COPIES{dq_i4_shadow}};
        end
    end

    outlier_lut_unpacker u_outlier_lut (
        .clk              (clk),
        .rst_n            (rst_n),
        .isa_valid        (isa_valid),
        .int2_or_int4_mode(decomp_int2_or_int4),
        .outlier_num      (outlier_num[6:0]),
        .compress_bits    (compress_bits),
        .out_shift_bits   (out_shift_bits),
        .bookmark_capacity(bookmark_capacity),
        .outlier_pos_length(outlier_pos_length),
        .outlier_val_length(outlier_val_length)
    );

    decompressor_top u_decompressor (
        .clk              (clk),
        .rst_n            (rst_n),
        .isa_valid        (isa_valid),
        .int2_or_int4_mode(decomp_int2_or_int4),
        .outlier_num      (outlier_num[6:0]),
        .rom_wen          (rom_wen && !dq_cfg_wen),
        .rom_wdata        (rom_wdata),
        .outlier_val_in_vld (decomp_val_in_vld),
        .outlier_val_in_data(decomp_val_in_data),
        .in_vld           (decomp_in_vld),
        .in_data          (decomp_in_data),
        .out_vld          (decomp_out_vld),
        .out_data         (decomp_out_data)
    );

    post_norm_row #(
        .ACT_XFERS(GEMM_A_XFERS),
        .WT_XFERS (GEMM_W_XFERS)
    ) u_post_norm (
        .clk              (clk),
        .rst_n            (rst_n),
        .isa_valid        (isa_valid),
        .is_gemm_mode     (is_gemm_mode),
        .post_norm_en     (is_norm_mode),
        .row_in_vld       (pnorm_row_in_vld),
        .rms_phase        (pnorm_rms_phase),
        .res_phase        (residual_phase || gmp_residual_phase),
        .wt_tile_xfers    (mode_gemm_proj_low_prec ? gmp_low_tile_xfers : 7'd0),
        .num_gamma_beats  (rms_tile_xfers - 10'd2),
        .act_xfers        (pnorm_act_xfers),
        .phases_per_sub   (phases_per_sub),
        .row_din          (pnorm_row_din),
        .post_norm_out_vld(pnorm_out_vld),
        .post_norm_out    (pnorm_out)
    );

    reg         sram_wen;
    reg  [5:0]  sram_waddr;
    reg  [CHIP_DATA_WIDTH-1:0] sram_wdata;
    reg         sram_ren;
    reg  [5:0]  sram_raddr;
    wire [CHIP_DATA_WIDTH-1:0] sram_rdata;
    wire        sram_rvalid;

    sram_64x4096_wrapper u_mask_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .wen   (sram_wen),
        .waddr (sram_waddr),
        .wdata (sram_wdata),
        .ren   (sram_ren),
        .raddr (sram_raddr),
        .rdata (sram_rdata),
        .rvalid(sram_rvalid)
    );

    reg [SCALE_W-1:0] k_scale_register [0:7];
    reg [ZP_W-1:0]    k_zp_register    [0:7];
    reg [SCALE_W-1:0] v_scale_register [0:7];
    reg [ZP_W-1:0]    v_zp_register    [0:7];

    reg [815:0] pos_reg [0:63];

    wire [9:0] token_beat_num = 2*(((hidden_dim << 4) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));
    wire [9:0] group_head_beat_num = 2*((({5'd0, group_size, 11'd0}) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));

    wire [15:0] residual_beat_num = 16'd2 *
        ((({5'd0, batch_space, 11'd0}) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));

    reg [4:0]  head_number;
    reg [15:0] lp_act_load_cnt;
    reg [15:0] lp_res_load_cnt;
    reg [15:0] weight_bundle_cnt;
    reg [15:0] weight_hidden_dim_cnt;
    reg [8:0]  gvpl_wt_in_grp;
    reg [8:0]  gvpl_grp_cnt;
    reg        gvpl_is_value_phase;

    wire [6:0] a_tile_xfers = 7'd64;
    wire [6:0] w_tile_xfers = (w_precision == 5'd2) ? 7'd8  :
                             (w_precision == 5'd4) ? 7'd16 :
                             (w_precision == 5'd8) ? 7'd32 : 7'd64;

    localparam LP_IDLE      = 3'd0;
    localparam LP_POS       = 3'd1;
    localparam LP_VAL       = 3'd2;
    localparam LP_SCALE_ZP  = 3'd3;
    localparam LP_WKV        = 3'd4;
    localparam LP_ACT       = 3'd5;
    localparam LP_RES       = 3'd6;

    reg [2:0] lp_state;

    reg [6:0]  pos_load_cnt;
    reg [6:0]  val_load_cnt;
    reg [6:0]  scalezp_load_cnt;
    reg [5:0]  wkv_tile_idx;
    reg [6:0]  wkv_tile_sub_cnt;
    reg        group32_second_phase;
    reg [31:0] seqlen_cnt_gqav;

    reg [6:0]  gmp_act_sub_cnt;
    reg [1:0]  gmp_act_tile_idx;
    reg [2:0]  gmp_wkv_tile_idx;
    reg [3:0]  gmp_bundle_idx;
    reg [8:0]  gmp_phase_cnt;
    reg [4:0]  gmp_res_tile_cnt;
    reg [6:0]  gmp_res_sub_cnt;
    reg [8:0]  gmp_block_cnt;
    reg [6:0]  gmp_rms_phase_cnt;
    reg [3:0]  gmp_rms_half_sel;

    reg [6:0]  gvpl_rms_phase_cnt;

    reg [15:0] gvpl_wt_x_remaining;

    wire [5:0] scalezp_total =  (is_proj_mode && group_width == 2'b01) ? 6'd12 :
                                (is_proj_mode && group_width == 2'b10) ? 6'd6 :
                                (is_proj_mode && group_width == 2'b11) ? ((mode_gemv_proj_low_prec && output_div128 > 16'd4) ? 6'd8 : 6'd4) :
                                (group_width == 2'b01) ? 6'd12 :
                                (group_width == 2'b10) ? 6'd12 : 6'd8;
    wire [6:0] k_tile_xfers = (k_precision == 5'd2) ? 7'd8  :
                               (k_precision == 5'd4) ? 7'd16 :
                               (k_precision == 5'd8) ? 7'd32 : 7'd64;
    wire [6:0] v_tile_xfers = (v_precision == 5'd2) ? 7'd8  :
                               (v_precision == 5'd4) ? 7'd16 :
                               (v_precision == 5'd8) ? 7'd32 : 7'd64;
    wire       gemv_gqa_kv_block = mode_gemv_gqa && (group_width != 2'b01);
    wire       kv_is_k = is_proj_mode      ? 1'b1 :
                         gemv_gqa_kv_block ? !wkv_tile_idx[2]
                                           : !wkv_tile_idx[0];
    wire [6:0] gvpf_low_tile_xfers = (w_precision == 5'd2) ? 7'd8  :
                                    (w_precision == 5'd4) ? 7'd16 :
                                    (w_precision == 5'd8) ? 7'd32 : 7'd32;
    assign gmp_low_tile_xfers      = (w_precision == 5'd2) ? 7'd8  :
                                    (w_precision == 5'd4) ? 7'd16 :
                                    (w_precision == 5'd8) ? 7'd32 : 7'd32;

    wire        w_outlier_active = (mode_gemm_proj_low_prec || mode_gemv_proj_low_prec)
                                   && (outlier_num != 8'd0)
                                   && ((w_precision == 5'd2) || (w_precision == 5'd4));
    wire [6:0]  gmp_w_beat_xfers = w_outlier_active ? {gmp_low_tile_xfers[5:0], 1'b0}
                                                    : gmp_low_tile_xfers;
    wire [6:0]  gvpf_w_beat_xfers = w_outlier_active ? {gvpf_low_tile_xfers[5:0], 1'b0}
                                                     : gvpf_low_tile_xfers;
    wire [6:0] cur_tile_xfers = mode_gemv_proj_low_prec ? gvpf_w_beat_xfers :
                                mode_gemm_proj_low_prec ? gmp_w_beat_xfers :
                                kv_is_k ? k_tile_xfers : v_tile_xfers;

    wire w_mask_beat = w_outlier_active && (lp_state == LP_WKV) && in_vld
                       && !wkv_tile_sub_cnt[0];

    reg [CORE_NUM-1:0] diag_done_trigger_gemv;
    reg [CORE_NUM-1:0] diag_done_trigger_gemm;

    reg [2:0] lp_state_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      lp_state_d <= LP_IDLE;
        else if (isa_valid) lp_state_d <= LP_IDLE;
        else             lp_state_d <= lp_state;
    end
    wire lp_entering_pos = (lp_state == LP_POS) && (lp_state_d != LP_POS);
    wire lp_entering_val = (lp_state == LP_VAL) && (lp_state_d != LP_VAL);

    wire [815:0] row_cb32 [0:15];
    generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : gen_pack32
        assign row_cb32[gi] = {
            {70'd0, in_data[32*(gi*8+7) +: 32]}, {70'd0, in_data[32*(gi*8+6) +: 32]},
            {70'd0, in_data[32*(gi*8+5) +: 32]}, {70'd0, in_data[32*(gi*8+4) +: 32]},
            {70'd0, in_data[32*(gi*8+3) +: 32]}, {70'd0, in_data[32*(gi*8+2) +: 32]},
            {70'd0, in_data[32*(gi*8+1) +: 32]}, {70'd0, in_data[32*(gi*8+0) +: 32]}
        };
    end
    endgenerate

    wire [815:0] row_cb46 [0:10];
    generate
    for (gi = 0; gi < 11; gi = gi + 1) begin : gen_pack46
        assign row_cb46[gi] = {
            {56'd0, in_data[46*(gi*8+7) +: 46]}, {56'd0, in_data[46*(gi*8+6) +: 46]},
            {56'd0, in_data[46*(gi*8+5) +: 46]}, {56'd0, in_data[46*(gi*8+4) +: 46]},
            {56'd0, in_data[46*(gi*8+3) +: 46]}, {56'd0, in_data[46*(gi*8+2) +: 46]},
            {56'd0, in_data[46*(gi*8+1) +: 46]}, {56'd0, in_data[46*(gi*8+0) +: 46]}
        };
    end
    endgenerate

    wire [815:0] row_cb64 [0:7];
    generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : gen_pack64
        assign row_cb64[gi] = {
            {38'd0, in_data[64*(gi*8+7) +: 64]}, {38'd0, in_data[64*(gi*8+6) +: 64]},
            {38'd0, in_data[64*(gi*8+5) +: 64]}, {38'd0, in_data[64*(gi*8+4) +: 64]},
            {38'd0, in_data[64*(gi*8+3) +: 64]}, {38'd0, in_data[64*(gi*8+2) +: 64]},
            {38'd0, in_data[64*(gi*8+1) +: 64]}, {38'd0, in_data[64*(gi*8+0) +: 64]}
        };
    end
    endgenerate

    wire [815:0] row_cb73 [0:6];
    generate
    for (gi = 0; gi < 7; gi = gi + 1) begin : gen_pack73
        assign row_cb73[gi] = {
            {29'd0, in_data[73*(gi*8+7) +: 73]}, {29'd0, in_data[73*(gi*8+6) +: 73]},
            {29'd0, in_data[73*(gi*8+5) +: 73]}, {29'd0, in_data[73*(gi*8+4) +: 73]},
            {29'd0, in_data[73*(gi*8+3) +: 73]}, {29'd0, in_data[73*(gi*8+2) +: 73]},
            {29'd0, in_data[73*(gi*8+1) +: 73]}, {29'd0, in_data[73*(gi*8+0) +: 73]}
        };
    end
    endgenerate

    wire [815:0] row_cb85 [0:5];
    generate
    for (gi = 0; gi < 6; gi = gi + 1) begin : gen_pack85
        assign row_cb85[gi] = {
            {17'd0, in_data[85*(gi*8+7) +: 85]}, {17'd0, in_data[85*(gi*8+6) +: 85]},
            {17'd0, in_data[85*(gi*8+5) +: 85]}, {17'd0, in_data[85*(gi*8+4) +: 85]},
            {17'd0, in_data[85*(gi*8+3) +: 85]}, {17'd0, in_data[85*(gi*8+2) +: 85]},
            {17'd0, in_data[85*(gi*8+1) +: 85]}, {17'd0, in_data[85*(gi*8+0) +: 85]}
        };
    end
    endgenerate

    wire [815:0] row_cb102 [0:4];
    generate
    for (gi = 0; gi < 5; gi = gi + 1) begin : gen_pack102
        assign row_cb102[gi] = {
            in_data[102*(gi*8+7) +: 102], in_data[102*(gi*8+6) +: 102],
            in_data[102*(gi*8+5) +: 102], in_data[102*(gi*8+4) +: 102],
            in_data[102*(gi*8+3) +: 102], in_data[102*(gi*8+2) +: 102],
            in_data[102*(gi*8+1) +: 102], in_data[102*(gi*8+0) +: 102]
        };
    end
    endgenerate

    reg [5:0] pos_row_idx;

    wire [5:0] pos_row_idx_now = lp_entering_pos ? 6'd0 : pos_row_idx;

    integer pri;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_row_idx <= 6'd0;
            for (pri = 0; pri < 64; pri = pri + 1)
                pos_reg[pri] <= 816'd0;
        end else if (isa_valid) begin
            pos_row_idx <= 6'd0;
        end else if ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && lp_state == LP_POS && in_vld) begin
            case (compress_bits)
                8'd32: begin
                    for (pri = 0; pri < 16; pri = pri + 1)
                        pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb32[pri];
                    pos_row_idx <= pos_row_idx_now + 6'd16;
                end
                8'd46: begin
                    if (pos_load_cnt < 7'd5) begin
                        for (pri = 0; pri < 11; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb46[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd11;
                    end else begin
                        for (pri = 0; pri < 9; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb46[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd9;
                    end
                end
                8'd64: begin
                    for (pri = 0; pri < 8; pri = pri + 1)
                        pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb64[pri];
                    pos_row_idx <= pos_row_idx_now + 6'd8;
                end
                8'd73: begin
                    if (pos_load_cnt < 7'd9) begin
                        for (pri = 0; pri < 7; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb73[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd7;
                    end else begin
                        pos_reg[pos_row_idx_now] <= row_cb73[0];
                        pos_row_idx <= pos_row_idx_now + 6'd1;
                    end
                end
                8'd85: begin
                    if (pos_load_cnt < 7'd10) begin
                        for (pri = 0; pri < 6; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb85[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd6;
                    end else if (pos_load_cnt == 7'd10) begin
                        for (pri = 0; pri < 4; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb85[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd4;
                    end
                end
                8'd102: begin
                    if (pos_load_cnt < 7'd12) begin
                        for (pri = 0; pri < 5; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb102[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd5;
                    end else if (pos_load_cnt == 7'd12) begin
                        for (pri = 0; pri < 4; pri = pri + 1)
                            pos_reg[pos_row_idx_now + pri[5:0]] <= row_cb102[pri];
                        pos_row_idx <= pos_row_idx_now + 6'd4;
                    end
                end
            endcase
        end else if (lp_entering_pos) begin
            pos_row_idx <= 6'd0;
        end
    end

    reg [5:0]  pos_feed_cnt;
    reg        pos_feed_active;
    reg        pos_feed_toggle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_feed_cnt    <= 6'd0;
            pos_feed_active <= 1'b0;
            pos_feed_toggle <= 1'b0;
        end else if (isa_valid) begin
            pos_feed_cnt    <= 6'd0;
            pos_feed_active <= 1'b0;
            pos_feed_toggle <= 1'b0;
        end else begin
            if ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && lp_state == LP_POS) begin
                pos_feed_cnt    <= 6'd0;
                pos_feed_active <= 1'b0;
                pos_feed_toggle <= 1'b0;
            end

            if ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && lp_entering_val && !pos_feed_active && pos_feed_cnt == 6'd0)
                pos_feed_active <= 1'b1;

            if (pos_feed_active) begin
                if (decomp_int2_or_int4) begin
                    pos_feed_toggle <= ~pos_feed_toggle;
                    if (pos_feed_toggle) begin
                        pos_feed_cnt <= pos_feed_cnt + 6'd1;
                        if (pos_feed_cnt == 6'd31)
                            pos_feed_active <= 1'b0;
                    end
                end else begin
                    pos_feed_cnt <= pos_feed_cnt + 6'd1;
                    if (pos_feed_cnt == 6'd31)
                        pos_feed_active <= 1'b0;
                end
            end
        end
    end

    wire pos_feed_fire = pos_feed_active && (!decomp_int2_or_int4 || pos_feed_toggle);

    wire [102*16-1:0] pos_feed_data;
    wire [5:0] pos_feed_row_lo = {pos_feed_cnt[4:0], 1'b0};
    wire [5:0] pos_feed_row_hi = {pos_feed_cnt[4:0], 1'b1};
    assign pos_feed_data = {pos_reg[pos_feed_row_hi], pos_reg[pos_feed_row_lo]};

    always @(*) begin
        decomp_in_vld      = 1'b0;
        decomp_in_data     = {1632{1'b0}};
        decomp_val_in_vld  = 1'b0;
        decomp_val_in_data = {CHIP_DATA_WIDTH{1'b0}};

        if ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec)) begin
            decomp_in_vld  = pos_feed_fire;
            decomp_in_data = pos_feed_data;

            if (lp_state == LP_VAL && in_vld) begin
                decomp_val_in_vld  = 1'b1;
                decomp_val_in_data = in_data;
            end
        end
    end

    reg [14:0]    delay_vld;
    reg [14:0]    pipe_is_szp;
    reg [14:0]    pipe_is_v;
    reg [14:0]    pipe_is_act_lp;
    reg [14:0]    pipe_is_res_lp;

    reg [CORE_NUM-1:0] diag_done_gemv_pipe [0:14];

    reg [CHIP_DATA_WIDTH-1:0] delay_pipe [0:14];
    reg [6:0]    pipe_szp_cnt [0:14];

    reg [5:0] sram_wr_cnt;
    reg [5:0] sram_rd_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_wr_cnt <= 6'd0;
            sram_rd_cnt <= 6'd0;
        end else if (isa_valid) begin
            sram_wr_cnt <= 6'd0;
            sram_rd_cnt <= 6'd0;
        end else begin
            if ((decomp_out_vld || w_mask_beat) && (mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec)) begin
                sram_wr_cnt <= sram_wr_cnt + 6'd1;
                if(decomp_int2_or_int4 ? (sram_wr_cnt == 6'd63) : (sram_wr_cnt == 6'd31))
                    sram_wr_cnt <= 6'd0;
            end
            if (delay_vld[13] && !pipe_is_szp[13] && !pipe_is_v[13]
                              && !pipe_is_act_lp[13] && !pipe_is_res_lp[13]) begin
                sram_rd_cnt <= sram_rd_cnt + 6'd1;
                if(decomp_int2_or_int4 ? (sram_rd_cnt == 6'd63) : (sram_rd_cnt == 6'd31))
                    sram_rd_cnt <= 6'd0;
            end
        end
    end

    wire q_pipe_input_vld   = (mode_gemv_gqa && lp_state == LP_ACT && in_vld);
    wire k_pipe_input_vld   = (mode_gemv_gqa && lp_state == LP_WKV && in_vld && kv_is_k);
    wire v_pipe_input_vld   = (mode_gemv_gqa && lp_state == LP_WKV && in_vld && !kv_is_k);
    wire w_pipe_input_vld   = (mode_gemv_proj_low_prec && lp_state == LP_WKV && in_vld);
    wire szp_pipe_input_vld = ((mode_gemv_gqa || mode_gemv_proj_low_prec) && lp_state == LP_SCALE_ZP && in_vld);

    wire gvpf_wt_pipe_push   = mode_gemv_proj_full_prec && (gvpf_state == GVPF_WT)  && in_vld;
    wire gvpf_res_pipe_push  = mode_gemv_proj_full_prec && (gvpf_state == GVPF_RES) && in_vld;

    wire gmpl_pnorm_push      = mode_gemm_proj_low_prec && pnorm_out_vld && !pnorm_rms_phase_d3;
    wire gmpl_pnorm_push_act  = gmpl_pnorm_push && (gpl_state_d3 == LP_ACT);
    wire gmpl_pnorm_push_wkv  = gmpl_pnorm_push && (gpl_state_d3 == LP_WKV);
    wire gmpl_pnorm_push_res  = gmpl_pnorm_push && (gpl_state_d3 == LP_RES);

    wire gvpl_pnorm_act_vld  = mode_gemv_proj_low_prec && pnorm_out_vld
                               && !pnorm_rms_phase_d3 && (gpl_state_d3 == LP_ACT);
    wire gvpl_res_pipe_push  = mode_gemv_proj_low_prec && lp_state == LP_RES && in_vld;

    wire any_pipe_input_vld = q_pipe_input_vld || k_pipe_input_vld || v_pipe_input_vld || w_pipe_input_vld
                              || szp_pipe_input_vld || gmpl_pnorm_push
                              || gvpl_res_pipe_push
                              || gvpf_wt_pipe_push || gvpf_res_pipe_push;

    wire [CHIP_DATA_WIDTH-1:0] delay_pipe_in_data = szp_pipe_input_vld ? in_data :
                                       gmpl_pnorm_push     ? pnorm_out :
                                                            in_data;

    integer di;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (di = 0; di < 15; di = di + 1) begin
                delay_pipe[di]    <= {CHIP_DATA_WIDTH{1'b0}};
                pipe_szp_cnt[di]  <= 7'd0;
                diag_done_gemv_pipe[di] <= {CORE_NUM{1'b0}};
            end
            delay_vld      <= 15'd0;
            pipe_is_szp    <= 15'd0;
            pipe_is_v      <= 15'd0;
            pipe_is_act_lp <= 15'd0;
            pipe_is_res_lp <= 15'd0;
        end else if (isa_valid) begin
            for (di = 0; di < 15; di = di + 1) begin
                delay_pipe[di]    <= {CHIP_DATA_WIDTH{1'b0}};
                pipe_szp_cnt[di]  <= 7'd0;
                diag_done_gemv_pipe[di] <= {CORE_NUM{1'b0}};
            end
            delay_vld      <= 15'd0;
            pipe_is_szp    <= 15'd0;
            pipe_is_v      <= 15'd0;
            pipe_is_act_lp <= 15'd0;
            pipe_is_res_lp <= 15'd0;
        end else begin
            delay_pipe[0]      <= any_pipe_input_vld ? delay_pipe_in_data : {CHIP_DATA_WIDTH{1'b0}};
            delay_vld[0]       <= any_pipe_input_vld;
            pipe_is_szp[0]     <= szp_pipe_input_vld;
            pipe_is_v[0]       <= v_pipe_input_vld;
            pipe_is_act_lp[0]  <= gmpl_pnorm_push_act || q_pipe_input_vld;
            pipe_is_res_lp[0]  <= gmpl_pnorm_push_res || gvpl_res_pipe_push;
            pipe_szp_cnt[0]    <= scalezp_load_cnt;
            diag_done_gemv_pipe[0] <= diag_done_trigger_gemv;
            for (di = 1; di < 15; di = di + 1) begin
                delay_pipe[di]    <= delay_pipe[di-1];
                delay_vld[di]     <= delay_vld[di-1];
                pipe_is_szp[di]   <= pipe_is_szp[di-1];
                pipe_is_v[di]     <= pipe_is_v[di-1];
                pipe_is_act_lp[di]<= pipe_is_act_lp[di-1];
                pipe_is_res_lp[di]<= pipe_is_res_lp[di-1];
                pipe_szp_cnt[di]  <= pipe_szp_cnt[di-1];
                diag_done_gemv_pipe[di] <= diag_done_gemv_pipe[di-1];
            end
        end
    end

    wire        q_delayed_vld    = delay_vld[14] && pipe_is_act_lp[14] && mode_gemv_gqa;
    wire [CHIP_DATA_WIDTH-1:0] q_delayed_data   = delay_pipe[14];
    wire        k_delayed_vld    = delay_vld[14] && !pipe_is_szp[14] && !pipe_is_v[14]
                                                 && !pipe_is_act_lp[14] && !pipe_is_res_lp[14];
    wire [CHIP_DATA_WIDTH-1:0] k_delayed_data = delay_pipe[14];
    wire        v_delayed_vld    = delay_vld[14] && pipe_is_v[14];
    wire [CHIP_DATA_WIDTH-1:0] v_delayed_data = delay_pipe[14];
    wire          szp_delayed_vld  = delay_vld[14] && pipe_is_szp[14] && !mode_gemm_proj_low_prec;
    wire [CHIP_DATA_WIDTH-1:0] szp_delayed_data = delay_pipe[14];
    wire [6:0]    szp_delayed_cnt  = pipe_szp_cnt[14];

    wire        gmp_act_delayed_vld    = delay_vld[14] && (pipe_is_act_lp[14] || pipe_is_res_lp[14]);
    wire [CHIP_DATA_WIDTH-1:0] gmp_act_delayed_data = delay_pipe[14];
    wire        gmp_act_delayed_is_res = pipe_is_res_lp[14];
    wire [CORE_NUM-1:0] gmp_act_delayed_route = route_pipe_lp_d3;

    reg [5:0] k_delayed_vld_cnt, v_delayed_vld_cnt;
    reg [5:0] k_delayed_tile_cnt, v_delayed_tile_cnt;

    wire [1:0] lp_kv_pair_raw = wkv_tile_idx[2:1];
    wire [2:0] lp_kv_pair_actual = (group_width == 2'b01 && group32_second_phase) ?
                                     {1'b0, lp_kv_pair_raw} + 3'd2 :
                                     {1'b0, lp_kv_pair_raw};
    wire [CORE_NUM-1:0] lp_wkv_route_entry = mode_gemm_proj_low_prec ? gmp_wt_route : gv_wkv_route;

    wire [$clog2(CORE_NUM)-1:0] gvg_q_core_idx = lp_act_load_cnt[$clog2(CORE_NUM):1];
    wire [CORE_NUM-1:0] gvg_q_route = ({{(CORE_NUM-1){1'b0}}, 1'b1}) << gvg_q_core_idx;

    wire [CORE_NUM-1:0] route_pipe_entry =
        (mode_gemv_gqa && lp_state == LP_ACT && in_vld) ? gvg_q_route :
        ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && lp_state == LP_WKV && in_vld) ? lp_wkv_route_entry :
        (mode_gemm_proj_low_prec && lp_state == LP_ACT && in_vld) ? gmp_act_route :
        (mode_gemm_proj_low_prec && lp_state == LP_RES && in_vld) ? gmp_residual_route :
        (mode_gemv_proj_low_prec && lp_state == LP_ACT && in_vld) ? gvp_act_route :
        (mode_gemv_proj_low_prec && lp_state == LP_RES && in_vld) ? gvp_res_route :
        {CORE_NUM{1'b0}};

    reg [CORE_NUM-1:0] route_pipe [0:14];

    integer ri;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ri = 0; ri < 15; ri = ri + 1)
                route_pipe[ri] <= {CORE_NUM{1'b0}};
        end else if (isa_valid) begin
            for (ri = 0; ri < 15; ri = ri + 1)
                route_pipe[ri] <= {CORE_NUM{1'b0}};
        end else begin
            route_pipe[0] <= route_pipe_entry;
            for (ri = 1; ri < 15; ri = ri + 1) begin
                route_pipe[ri] <= route_pipe[ri-1];
            end
        end
    end

    wire [CORE_NUM-1:0] qkvw_delayed_route = route_pipe[14];

    wire [CORE_NUM-1:0] gvp_res_delayed_route = route_pipe[14];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_pipe_lp_d1 <= {CORE_NUM{1'b0}};
            route_pipe_lp_d2 <= {CORE_NUM{1'b0}};
            route_pipe_lp_d3 <= {CORE_NUM{1'b0}};
        end else if (isa_valid) begin
            route_pipe_lp_d1 <= {CORE_NUM{1'b0}};
            route_pipe_lp_d2 <= {CORE_NUM{1'b0}};
            route_pipe_lp_d3 <= {CORE_NUM{1'b0}};
        end else begin
            route_pipe_lp_d1 <= route_pipe[14];
            route_pipe_lp_d2 <= route_pipe_lp_d1;
            route_pipe_lp_d3 <= route_pipe_lp_d2;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpl_state_d1       <= LP_IDLE;
            gpl_state_d2       <= LP_IDLE;
            gpl_state_d3       <= LP_IDLE;
            pnorm_rms_phase_d1 <= 1'b0;
            pnorm_rms_phase_d2 <= 1'b0;
            pnorm_rms_phase_d3 <= 1'b0;
        end else if (isa_valid) begin
            gpl_state_d1       <= LP_IDLE;
            gpl_state_d2       <= LP_IDLE;
            gpl_state_d3       <= LP_IDLE;
            pnorm_rms_phase_d1 <= 1'b0;
            pnorm_rms_phase_d2 <= 1'b0;
            pnorm_rms_phase_d3 <= 1'b0;
        end else begin
            if (in_vld) begin
                gpl_state_d1       <= lp_state;
                pnorm_rms_phase_d1 <= pnorm_rms_phase;
            end
            gpl_state_d2       <= gpl_state_d1;
            gpl_state_d3       <= gpl_state_d2;
            pnorm_rms_phase_d2 <= pnorm_rms_phase_d1;
            pnorm_rms_phase_d3 <= pnorm_rms_phase_d2;
        end
    end

    function [3:0] dq_i2_lu;
        input [15:0] tab;
        input [1:0]  v;
        dq_i2_lu = tab[{v, 2'b00} +: 4];
    endfunction

    function [7:0] dq_i4_lu;
        input [127:0] tab;
        input [3:0]   v;
        dq_i4_lu = tab[{v, 3'b000} +: 8];
    endfunction

    wire [CHIP_DATA_WIDTH-1:0] kv_mask_src =
        (DQ_SHARE_KV != 0) ? (pipe_is_v[14] ? {CHIP_DATA_WIDTH{1'b0}} : sram_rdata)
                           : sram_rdata;

    wire [MEM_DATA_WIDTH-1:0] merged_k_int2;
    generate
        for (gi = 0; gi < INT2_ELEMS; gi = gi + 1) begin : gen_merge_int2
            wire [1:0]  m2 = kv_mask_src[gi*2 +: 2];
            wire [1:0]  k2 = k_delayed_data[gi*2 +: 2];
            wire [15:0] t2 = dq_i2_bank[(DQA_K*DQ_I2_BPA + gi/DQ_I2_BE)*16 +: 16];
            assign merged_k_int2[gi*4 +: 4] = (m2 != 2'b00) ? {m2, k2} : dq_i2_lu(t2, k2);
        end
    endgenerate

    wire [MEM_DATA_WIDTH-1:0] merged_k_int4;
    generate
        for (gi = 0; gi < INT4_ELEMS; gi = gi + 1) begin : gen_merge_int4
            wire [3:0]   m4 = kv_mask_src[gi*4 +: 4];
            wire [3:0]   k4 = k_delayed_data[gi*4 +: 4];
            wire [127:0] t4 = dq_i4_bank[(DQA_K*DQ_I4_BPA + gi/DQ_I4_BE)*128 +: 128];
            assign merged_k_int4[gi*8 +: 8] = (m4 != 4'b0000) ? {m4, k4} : dq_i4_lu(t4, k4);
        end
    endgenerate

    wire [MEM_DATA_WIDTH-1:0] final_merged_k = decomp_int2_or_int4 ? merged_k_int4 : merged_k_int2;

    wire [MEM_DATA_WIDTH-1:0] dequant_v_int2;
    generate
        for (gi = 0; gi < INT2_ELEMS; gi = gi + 1) begin : gen_dequant_v_int2
            wire [1:0]  v2 = v_delayed_data[gi*2 +: 2];
            wire [15:0] t2 = dq_i2_bank[(DQA_V*DQ_I2_BPA + gi/DQ_I2_BE)*16 +: 16];
            assign dequant_v_int2[gi*4 +: 4] = dq_i2_lu(t2, v2);
        end
    endgenerate

    wire [MEM_DATA_WIDTH-1:0] dequant_v_int4;
    generate
        for (gi = 0; gi < INT4_ELEMS; gi = gi + 1) begin : gen_dequant_v_int4
            wire [3:0]   v4 = v_delayed_data[gi*4 +: 4];
            wire [127:0] t4 = dq_i4_bank[(DQA_V*DQ_I4_BPA + gi/DQ_I4_BE)*128 +: 128];
            assign dequant_v_int4[gi*8 +: 8] = dq_i4_lu(t4, v4);
        end
    endgenerate

    wire [MEM_DATA_WIDTH-1:0] final_dequant_v =
        (DQ_SHARE_KV != 0) ? final_merged_k
                           : (decomp_int2_or_int4 ? dequant_v_int4 : dequant_v_int2);

    wire [MEM_DATA_WIDTH-1:0] gqam_kv_deq_int2;
    generate
        for (gi = 0; gi < INT2_ELEMS; gi = gi + 1) begin : gen_gqam_kv_deq_int2
            wire [15:0] t2 = dq_i2_bank[(DQA_GKV*DQ_I2_BPA + gi/DQ_I2_BE)*16 +: 16];
            assign gqam_kv_deq_int2[gi*4 +: 4] = dq_i2_lu(t2, in_data[gi*2 +: 2]);
        end
    endgenerate
    wire [MEM_DATA_WIDTH-1:0] gqam_kv_deq_int4;
    generate
        for (gi = 0; gi < INT4_ELEMS; gi = gi + 1) begin : gen_gqam_kv_deq_int4
            wire [127:0] t4 = dq_i4_bank[(DQA_GKV*DQ_I4_BPA + gi/DQ_I4_BE)*128 +: 128];
            assign gqam_kv_deq_int4[gi*8 +: 8] = dq_i4_lu(t4, in_data[gi*4 +: 4]);
        end
    endgenerate
    wire [MEM_DATA_WIDTH-1:0] gqam_kv_deq = (k_precision == 5'd4) ? gqam_kv_deq_int4 : gqam_kv_deq_int2;

    reg  [CHIP_DATA_WIDTH-1:0] gqam_mask_reg;
// synopsys translate_off
`ifdef KOPROBE
    integer ko_latch_cnt, ko_latch_nz, ko_emit_cnt, ko_emit_with_mask;
    integer ko_beat_cnt;  initial ko_beat_cnt = 0;
    integer ko_lanes, ko_lanes_first, ko_i;
    initial begin
        ko_latch_cnt = 0; ko_latch_nz = 0; ko_emit_cnt = 0; ko_emit_with_mask = 0;
        ko_lanes = 0; ko_lanes_first = -1;
    end
    final $display("[KOPROBE] outlier_num=%0d active=%0b mask_latches=%0d nonzero=%0d k_emits=%0d with_mask=%0d lanes_merged=%0d first_beat=%0d",
                   outlier_num, outlier_kv_active,
                   ko_latch_cnt, ko_latch_nz, ko_emit_cnt, ko_emit_with_mask,
                   ko_lanes, ko_lanes_first);
`endif
// synopsys translate_on
    wire [MEM_DATA_WIDTH-1:0] gqam_merged_k_int2;
    generate
        for (gi = 0; gi < INT2_ELEMS; gi = gi + 1) begin : gen_gqam_merged_k_int2
            wire [1:0]  gm2 = gqam_mask_reg[gi*2 +: 2];
            wire [1:0]  gk2 = in_data[gi*2 +: 2];
            wire [15:0] t2  = dq_i2_bank[(DQA_GKM*DQ_I2_BPA + gi/DQ_I2_BE)*16 +: 16];
            assign gqam_merged_k_int2[gi*4 +: 4] = (gm2 != 2'b00) ? {gm2, gk2} : dq_i2_lu(t2, gk2);
        end
    endgenerate
    wire [MEM_DATA_WIDTH-1:0] gqam_merged_k_int4;
    generate
        for (gi = 0; gi < INT4_ELEMS; gi = gi + 1) begin : gen_gqam_merged_k_int4
            wire [3:0]   gm4 = gqam_mask_reg[gi*4 +: 4];
            wire [3:0]   gk4 = in_data[gi*4 +: 4];
            wire [127:0] t4  = dq_i4_bank[(DQA_GKM*DQ_I4_BPA + gi/DQ_I4_BE)*128 +: 128];
            assign gqam_merged_k_int4[gi*8 +: 8] = (gm4 != 4'b0000) ? {gm4, gk4} : dq_i4_lu(t4, gk4);
        end
    endgenerate
    wire [MEM_DATA_WIDTH-1:0] gqam_merged_k = (k_precision == 5'd4) ? gqam_merged_k_int4
                                                                   : gqam_merged_k_int2;

    always @(*) begin
        sram_wen   = 1'b0;
        sram_waddr = 7'd0;
        sram_wdata = {CHIP_DATA_WIDTH{1'b0}};
        sram_ren   = 1'b0;
        sram_raddr = 7'd0;

        if ((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec)) begin
            sram_wen   = decomp_out_vld || w_mask_beat;
            sram_waddr = sram_wr_cnt;
            sram_wdata = w_mask_beat ? in_data : decomp_out_data;
            sram_ren   = delay_vld[13] && !pipe_is_szp[13] && !pipe_is_v[13]
                                       && !pipe_is_act_lp[13] && !pipe_is_res_lp[13];
            sram_raddr = sram_rd_cnt;
        end
    end

// synopsys translate_off
`ifdef LPPROBE
    reg [2:0] lp_state_q; reg [5:0] wkv_idx_q; reg g32_q; reg [CORE_NUM-1:0] dd_q, ddt_q;
    always @(posedge clk) if (mode_gemv_gqa) begin
        if (diag_done_trigger_gemv != ddt_q || diag_done != dd_q)
            $display("[LPPROBE-RETIRE] t=%0t diag_done_trigger_gemv=%b diag_done=%b seqlen_cnt=%0d g32_2nd=%0b idx=%0d",
                     $time, diag_done_trigger_gemv, diag_done, seqlen_cnt_gqav, group32_second_phase, wkv_tile_idx);
        ddt_q <= diag_done_trigger_gemv; dd_q <= diag_done;
        if (lp_state != lp_state_q || wkv_tile_idx != wkv_idx_q || group32_second_phase != g32_q)
            $display("[LPPROBE] t=%0t lp_state=%0d wkv_tile_idx=%0d g32_2nd=%0b scalezp_cnt=%0d pos_cnt=%0d in_vld=%0b",
                     $time, lp_state, wkv_tile_idx, group32_second_phase, scalezp_load_cnt, pos_load_cnt, in_vld);
        lp_state_q <= lp_state; wkv_idx_q <= wkv_tile_idx; g32_q <= group32_second_phase;
    end
`endif
// synopsys translate_on
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lp_state            <= LP_IDLE;
            pos_load_cnt         <= 7'd0;
            val_load_cnt         <= 7'd0;
            scalezp_load_cnt     <= 7'd0;
            wkv_tile_idx          <= 6'd0;
            wkv_tile_sub_cnt      <= 7'd0;
            group32_second_phase <= 1'b0;
            seqlen_cnt_gqav  <= 32'd0;
            diag_done_trigger_gemv <= {CORE_NUM{1'b0}};
            diag_done            <= {CORE_NUM{1'b0}};
            gmp_act_sub_cnt      <= 7'd0;
            gmp_act_tile_idx     <= 2'd0;
            gmp_wkv_tile_idx     <= 3'd0;
            gmp_bundle_idx       <= 4'd0;
            gmp_phase_cnt        <= 9'd0;
            gmp_res_tile_cnt     <= 5'd0;
            gmp_res_sub_cnt      <= 7'd0;
            gmp_block_cnt        <= 9'd0;
            gmp_rms_phase_cnt    <= 7'd0;
            gmp_rms_phase        <= 1'b0;
            gmp_rms_half_sel     <= 4'd0;
            gmp_residual_phase   <= 1'b0;
            gvpl_rms_phase_cnt   <= 7'd0;
            gvpl_rms_phase       <= 1'b0;
            head_number          <= 5'd0;
            lp_act_load_cnt     <= 16'd0;
            lp_res_load_cnt     <= 16'd0;
            weight_bundle_cnt    <= 16'd0;
            weight_hidden_dim_cnt<= 16'd0;
            gvpl_wt_in_grp       <= 9'd0;
            gvpl_grp_cnt         <= 9'd0;
            gvpl_wt_x_remaining  <= 16'd0;
            gvpl_dim_read_done_r <= 1'b0;
            gvpl_is_value_phase  <= 1'b0;
        end else if (isa_valid) begin
            lp_state            <= LP_IDLE;
            pos_load_cnt         <= 7'd0;
            val_load_cnt         <= 7'd0;
            scalezp_load_cnt     <= 7'd0;
            wkv_tile_idx          <= 6'd0;
            wkv_tile_sub_cnt      <= 7'd0;
            group32_second_phase <= 1'b0;
            seqlen_cnt_gqav  <= 32'd0;
            diag_done_trigger_gemv <= {CORE_NUM{1'b0}};
            diag_done            <= {CORE_NUM{1'b0}};
            gmp_act_sub_cnt      <= 7'd0;
            gmp_act_tile_idx     <= 2'd0;
            gmp_wkv_tile_idx     <= 3'd0;
            gmp_bundle_idx       <= 4'd0;
            gmp_phase_cnt        <= 9'd0;
            gmp_res_tile_cnt     <= 5'd0;
            gmp_res_sub_cnt      <= 7'd0;
            gmp_block_cnt        <= 9'd0;
            gmp_rms_phase_cnt    <= 7'd0;
            gmp_rms_phase        <= mode_gemm_proj_low_prec && is_norm_mode;
            gmp_rms_half_sel     <= 4'd0;
            gmp_residual_phase   <= 1'b0;
            gvpl_rms_phase_cnt   <= 7'd0;
            gvpl_rms_phase       <= mode_gemv_proj_low_prec && is_norm_mode;
            head_number          <= 5'd0;
            lp_act_load_cnt     <= 16'd0;
            lp_res_load_cnt     <= 16'd0;
            weight_bundle_cnt    <= 16'd0;
            weight_hidden_dim_cnt<= 16'd0;
            gvpl_wt_in_grp       <= 9'd0;
            gvpl_grp_cnt         <= 9'd0;
            gvpl_wt_x_remaining  <= output_dim[15:7];
            gvpl_dim_read_done_r <= 1'b0;
            gvpl_is_value_phase  <= 1'b0;
        end else begin
            diag_done <= {CORE_NUM{1'b0}};
            diag_done_trigger_gemv <= {CORE_NUM{1'b0}};
            gvpl_dim_read_done_r <= 1'b0;

            if (!is_gemm_mode) begin
                diag_done <= diag_done_gemv_pipe[14];
            end else if (|diag_done_trigger_gemm) begin
                diag_done <= diag_done_trigger_gemm;
            end

            if ((mode_gemv_gqa || mode_gemv_proj_low_prec)) begin
                case (lp_state)
                    LP_IDLE: begin
                        if (mode_gemv_proj_low_prec && gvpl_rms_phase) begin
                            if (in_vld) begin
                                gvpl_rms_phase_cnt <= gvpl_rms_phase_cnt + 7'd1;
                                if (gvpl_rms_phase_cnt == rms_tile_xfers - 7'd1) begin
                                    gvpl_rms_phase_cnt <= 7'd0;
                                    gvpl_rms_phase     <= 1'b0;
                                    lp_state           <= !a_on_chip ? LP_ACT : LP_POS;
                                end
                            end
                        end else begin
                            lp_state <=    !a_on_chip ? LP_ACT :
                                            mode_gemv_proj_low_prec ? LP_POS :
                                            (mode_gemv_gqa && k_precision < 5'd8) ? LP_POS : LP_WKV;
                            pos_load_cnt <= 7'd0;
                            group32_second_phase <= 1'b0;
                        end
                    end

                    LP_ACT: begin
                        if (in_vld) begin
                            lp_act_load_cnt <= lp_act_load_cnt + 7'd1;
                            if (lp_act_load_cnt == (is_proj_mode ? token_beat_num * batch_num - 1 : group_head_beat_num - 1)) begin
                                lp_state <=    mode_gemv_proj_low_prec ? LP_POS :
                                                (mode_gemv_gqa && k_precision < 5'd8) ? LP_POS :
                                                mode_gemm_proj_low_prec ?
                                                    ((outlier_num != 8'd0) ? LP_POS : LP_SCALE_ZP) :
                                                LP_WKV;
                                lp_act_load_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_POS: begin
                        if (outlier_pos_length == 7'd0) begin
                            lp_state         <= (outlier_val_length == 7'd0) ? LP_SCALE_ZP : LP_VAL;
                            val_load_cnt     <= 7'd0;
                            scalezp_load_cnt <= 7'd0;
                        end else if (in_vld) begin
                            pos_load_cnt <= pos_load_cnt + 7'd1;
                            if (pos_load_cnt == outlier_pos_length - 7'd1) begin
                                lp_state    <= LP_VAL;
                                val_load_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_VAL: begin
                        if (outlier_val_length == 7'd0) begin
                            lp_state         <= LP_SCALE_ZP;
                            scalezp_load_cnt <= 7'd0;
                        end else if (in_vld) begin
                            val_load_cnt <= val_load_cnt + 7'd1;
                            if (val_load_cnt == outlier_val_length - 7'd1) begin
                                lp_state        <= LP_SCALE_ZP;
                                scalezp_load_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_SCALE_ZP: begin
                        if (in_vld) begin
                            scalezp_load_cnt <= scalezp_load_cnt + 7'd1;
                            if (scalezp_load_cnt == {1'b0, scalezp_total} - 7'd1) begin
                                lp_state       <= LP_WKV;
                                wkv_tile_idx     <= 6'd0;
                                wkv_tile_sub_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_WKV: begin
                        if (in_vld) begin
                            wkv_tile_sub_cnt <= wkv_tile_sub_cnt + 7'd1;
                            if (wkv_tile_sub_cnt == cur_tile_xfers - 7'd1) begin
                                wkv_tile_sub_cnt <= 7'd0;
                                wkv_tile_idx <= wkv_tile_idx + 6'd1;

                                if (mode_gemv_gqa) begin
                                    if ((group_width != 2'b01 || k_precision >= 5'd8) &&
                                        wkv_tile_idx == (gemv_gqa_kv_block ? 6'd3 : 6'd6)) begin
                                        if(seqlen_cnt_gqav == (seq_len >> 9) - 1) begin
                                            diag_done_trigger_gemv <= (1'b1 << decode_core_num) - 1;
                                        end
                                    end else if (group_width == 2'b01 && k_precision < 5'd8 && group32_second_phase && wkv_tile_idx == 6'd2) begin
                                        if(seqlen_cnt_gqav == (seq_len >> 9) - 1) begin
                                            diag_done_trigger_gemv <= (1'b1 << decode_core_num) - 1;
                                        end
                                    end
                                end

                                if (mode_gemv_gqa) begin
                                    if (group_width == 2'b01 && k_precision < 5'd8 && !group32_second_phase && wkv_tile_idx == 6'd3) begin
                                        lp_state <= LP_SCALE_ZP;
                                        scalezp_load_cnt <= 7'd0;
                                        group32_second_phase <= 1'b1;
                                        wkv_tile_idx <= 6'd0;
                                    end
                                    else if (group_width == 2'b01 && k_precision < 5'd8 && group32_second_phase && wkv_tile_idx == 6'd3) begin
                                        pos_load_cnt <= 7'd0;
                                        group32_second_phase <= 1'b0;
                                        wkv_tile_idx <= 6'd0;
                                        seqlen_cnt_gqav <= seqlen_cnt_gqav + 32'd1;
                                        if (seqlen_cnt_gqav == (seq_len >> 9) - 1) begin
                                            seqlen_cnt_gqav <= 32'd0;
                                            lp_state <= !a_on_chip ? LP_ACT : LP_IDLE;
                                        end else begin
                                            lp_state <= LP_POS;
                                        end
                                    end
                                    else if ((group_width != 2'b01 || k_precision >= 5'd8) && wkv_tile_idx == 6'd7) begin
                                        pos_load_cnt <= 7'd0;
                                        wkv_tile_idx <= 6'd0;
                                        seqlen_cnt_gqav <= seqlen_cnt_gqav + 32'd1;
                                        if (seqlen_cnt_gqav == (seq_len >> 9) - 1) begin
                                            seqlen_cnt_gqav <= 32'd0;
                                            lp_state <= !a_on_chip ? LP_ACT : LP_IDLE;
                                        end else begin
                                            if(k_precision < 5'd8) begin
                                                lp_state <= LP_POS;
                                            end
                                        end
                                    end

                                end else begin
                                    if (gvpl_wt_in_grp == gvpl_wt_chunk_w[8:0] - 9'd1) begin
                                        gvpl_wt_in_grp <= 9'd0;
                                        lp_state       <= LP_POS;
                                        pos_load_cnt   <= 7'd0;
                                        if (gvpl_grp_cnt == hidden_div128[8:0] - 9'd1) begin
                                            gvpl_grp_cnt <= 9'd0;
                                            if (is_residual_mode) begin
                                                lp_state <= LP_RES;
                                            end else begin
                                                gvpl_dim_read_done_r <= 1'b1;
                                                if (gvpl_wt_all_done) begin
                                                    if (is_gating_mode && !gvpl_is_value_phase) begin
                                                        gvpl_is_value_phase <= 1'b1;
                                                        gvpl_wt_x_remaining <= output_dim[15:7];
                                                    end
                                                    lp_state           <= LP_IDLE;
                                                end else begin
                                                    gvpl_wt_x_remaining <= gvpl_wt_x_remaining
                                                                          - gvpl_wt_chunk_w;
                                                    lp_state           <= LP_POS;
                                                end
                                            end
                                        end else begin
                                            gvpl_grp_cnt <= gvpl_grp_cnt + 9'd1;
                                        end
                                    end else begin
                                        gvpl_wt_in_grp <= gvpl_wt_in_grp + 9'd1;
                                    end
                                end
                            end
                        end
                    end

                    LP_RES: begin
                        if (in_vld) begin
                            lp_res_load_cnt <= lp_res_load_cnt + 7'd1;
                            if (lp_res_load_cnt == (is_proj_mode ? residual_beat_num * batch_num - 1 : group_head_beat_num - 1)) begin
                                lp_res_load_cnt <= 7'd0;
                                if (mode_gemv_proj_low_prec) begin
                                    gvpl_dim_read_done_r <= 1'b1;
                                    if (gvpl_wt_all_done) begin
                                        lp_state           <= LP_IDLE;
                                    end else begin
                                        gvpl_wt_x_remaining <= gvpl_wt_x_remaining
                                                              - gvpl_wt_chunk_w;
                                        lp_state           <= LP_POS;
                                    end
                                end else begin
                                    lp_state <= LP_IDLE;
                                end
                            end
                        end
                    end

                    default: lp_state <= LP_IDLE;
                endcase

            end else if (mode_gemm_proj_low_prec) begin
                case (lp_state)
                    LP_IDLE: begin
                        if (gmp_rms_phase) begin
                            if(in_vld) begin
                                gmp_rms_phase_cnt <= gmp_rms_phase_cnt + 7'd1;
                                if (gmp_rms_phase_cnt == rms_tile_xfers - 1) begin
                                    gmp_rms_phase_cnt <= 7'd0;
                                    gmp_rms_phase     <= 1'b0;
                                    lp_state         <= LP_ACT;
                                    gmp_act_tile_idx  <= 2'd0;
                                    gmp_act_sub_cnt   <= 7'd0;
                                    gmp_bundle_idx    <= 4'd0;
                                    gmp_wkv_tile_idx  <= 3'd0;
                                end
                            end
                        end else begin
                            lp_state        <= LP_ACT;
                            gmp_act_sub_cnt  <= 7'd0;
                            gmp_act_tile_idx <= 2'd0;
                            gmp_wkv_tile_idx <= 3'd0;
                            gmp_bundle_idx   <= 4'd0;
                        end
                    end

                    LP_ACT: begin
                        if (in_vld) begin
                            gmp_act_sub_cnt <= gmp_act_sub_cnt + 7'd1;
                            if (gmp_act_sub_cnt == a_tile_xfers - 7'd1) begin
                                gmp_act_sub_cnt <= 7'd0;
                                gmp_act_tile_idx <= gmp_act_tile_idx + 2'd1;
                                if (gmp_act_tile_idx == GEMM_A_XFERS - 2'd1) begin
                                    lp_state    <= LP_SCALE_ZP;
                                    pos_load_cnt <= 7'd0;
                                    scalezp_load_cnt <= 7'd0;
                                    gmp_bundle_idx <= 4'd0;
                                    gmp_wkv_tile_idx <= 3'd0;
                                end
                            end
                        end
                    end

                    LP_POS: begin
                        if (outlier_pos_length == 7'd0) begin
                            lp_state         <= (outlier_val_length == 7'd0) ? LP_SCALE_ZP : LP_VAL;
                            val_load_cnt     <= 7'd0;
                            scalezp_load_cnt <= 7'd0;
                        end else if (in_vld) begin
                            pos_load_cnt <= pos_load_cnt + 7'd1;
                            if (pos_load_cnt == outlier_pos_length - 7'd1) begin
                                lp_state    <= LP_VAL;
                                val_load_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_VAL: begin
                        if (outlier_val_length == 7'd0) begin
                            lp_state         <= LP_SCALE_ZP;
                            scalezp_load_cnt <= 7'd0;
                        end else if (in_vld) begin
                            val_load_cnt <= val_load_cnt + 7'd1;
                            if (val_load_cnt == outlier_val_length - 7'd1) begin
                                lp_state        <= LP_SCALE_ZP;
                                scalezp_load_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_SCALE_ZP: begin
                        if (in_vld) begin
                            scalezp_load_cnt <= scalezp_load_cnt + 7'd1;
                            if (scalezp_load_cnt == {1'b0, scalezp_total} - 7'd1) begin
                                lp_state        <= LP_WKV;
                                wkv_tile_sub_cnt <= 7'd0;
                            end
                        end
                    end

                    LP_WKV: begin
                        if (in_vld) begin
                            wkv_tile_sub_cnt <= wkv_tile_sub_cnt + 7'd1;
                            if (wkv_tile_sub_cnt == cur_tile_xfers - 7'd1) begin
                                wkv_tile_sub_cnt <= 7'd0;
                                gmp_wkv_tile_idx <= gmp_wkv_tile_idx + 3'd1;

                                if (gmp_wkv_tile_idx[1:0] == 2'd3) begin
                                    pos_load_cnt   <= 7'd0;
                                    gmp_phase_cnt <= gmp_phase_cnt + 9'd1;
                                    if (gmp_phase_cnt == (hidden_dim >> 7) - 9'd1) begin
                                        gmp_phase_cnt <= 9'd0;
                                        if (is_residual_mode) begin
                                            lp_state          <= LP_RES;
                                            gmp_residual_phase <= 1'b1;
                                            gmp_res_tile_cnt   <= 5'd0;
                                            gmp_res_sub_cnt    <= 7'd0;
                                        end else begin
                                            gmp_act_tile_idx <= 2'd0;
                                            gmp_act_sub_cnt  <= 7'd0;
                                            gmp_bundle_idx   <= 4'd0;
                                            gmp_wkv_tile_idx <= 3'd0;
                                            gmp_block_cnt <= gmp_block_cnt + 9'd1;
                                            if (gmp_block_cnt == ((output_dim >> 7) >> $clog2(GEMM_W_XFERS)) - 9'd1) begin
                                                gmp_block_cnt <= 9'd0;
                                                if (gmp_rms_half_sel == NUM_SUBS - 4'd1) begin
                                                    gmp_rms_half_sel <= 4'd0;
                                                    lp_state      <= is_norm_mode ? LP_IDLE : LP_ACT;
                                                    gmp_rms_phase <= is_norm_mode;
                                                end else begin
                                                    gmp_rms_half_sel <= gmp_rms_half_sel + 4'd1;
                                                    lp_state         <= LP_ACT;
                                                end
                                            end else begin
                                                lp_state <= LP_ACT;
                                            end
                                        end
                                    end else begin
                                        lp_state <= LP_ACT;
                                        gmp_act_tile_idx <= 2'd0;
                                        gmp_act_sub_cnt  <= 7'd0;
                                        gmp_bundle_idx   <= 4'd0;
                                        gmp_wkv_tile_idx <= 3'd0;
                                    end
                                end
                            end
                        end
                    end

                    LP_RES: begin
                        if (in_vld) begin
                            gmp_res_sub_cnt <= gmp_res_sub_cnt + 7'd1;
                            if (gmp_res_sub_cnt == a_tile_xfers - 7'd1) begin
                                gmp_res_sub_cnt <= 7'd0;
                                gmp_res_tile_cnt <= gmp_res_tile_cnt + 5'd1;
                                if (gmp_res_tile_cnt == (GEMM_W_XFERS * GEMM_A_XFERS) - 5'd1) begin
                                    gmp_residual_phase <= 1'b0;
                                    gmp_res_tile_cnt   <= 5'd0;
                                    gmp_act_tile_idx <= 2'd0;
                                    gmp_act_sub_cnt  <= 7'd0;
                                    gmp_bundle_idx   <= 4'd0;
                                    gmp_wkv_tile_idx <= 3'd0;
                                    gmp_block_cnt <= gmp_block_cnt + 9'd1;
                                    if (gmp_block_cnt == ((output_dim >> 7) >> $clog2(GEMM_W_XFERS)) - 9'd1) begin
                                        gmp_block_cnt <= 9'd0;
                                        if (gmp_rms_half_sel == NUM_SUBS - 4'd1) begin
                                            gmp_rms_half_sel <= 4'd0;
                                            lp_state      <= is_norm_mode ? LP_IDLE : LP_ACT;
                                            gmp_rms_phase <= is_norm_mode;
                                        end else begin
                                            gmp_rms_half_sel <= gmp_rms_half_sel + 4'd1;
                                            lp_state         <= LP_ACT;
                                        end
                                    end else begin
                                        lp_state        <= LP_ACT;
                                    end
                                end
                            end
                        end
                    end

                    default: lp_state <= LP_IDLE;
                endcase

            end else begin
               lp_state <= LP_IDLE;
            end
        end
    end

    reg [11:0] gmp_data_cnt;
    reg [8:0] hidden_dim_cnt;
    reg [8:0] result_done_cnt;
    reg [6:0] rms_phase_cnt;
    reg       rms_phase_trigger;
    reg [3:0] rms_half_sel;
    wire gmp_is_act = (gmp_data_cnt < a_tile_xfers * GEMM_A_XFERS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gmp_data_cnt <= 12'd0;
            hidden_dim_cnt <= 9'd0;
            result_done_cnt <= 9'd0;
            rms_phase <= 1'b0;
            rms_phase_trigger <= 1'b0;
            rms_phase_cnt <= 7'd0;
            residual_phase <= 1'b0;
            residual_load_done <= 1'b0;
            rms_half_sel    <= 4'd0;
        end else begin
            residual_load_done <= 1'b0;
            if (isa_valid) begin
                gmp_data_cnt <= 12'd0;
                hidden_dim_cnt <= 9'd0;
                result_done_cnt <= 9'd0;
                rms_phase <= mode_gemm_proj_full_prec && is_norm_mode;
                rms_phase_trigger <= 1'b0;
                rms_phase_cnt <= 7'd0;
                residual_phase <= 1'b0;
                rms_half_sel    <= 4'd0;
            end else if (mode_gemm_proj_full_prec && in_vld && !rms_phase) begin
                gmp_data_cnt <= gmp_data_cnt + 12'd1;
                if(gmp_data_cnt == a_tile_xfers*GEMM_A_XFERS + w_tile_xfers*GEMM_W_XFERS - 1 && !residual_phase) begin
                    gmp_data_cnt <= 12'd0;
                    hidden_dim_cnt <= hidden_dim_cnt + 9'd1;
                    if(hidden_dim_cnt == (hidden_dim >> 7) - 9'd1) begin
                        hidden_dim_cnt <= 9'd0;
                        result_done_cnt <= result_done_cnt + 1'b1;
                        residual_phase <= is_residual_mode;

                        if(result_done_cnt == ((output_dim >> 7) >> $clog2(GEMM_W_XFERS)) - 1) begin
                            result_done_cnt <= 9'd0;
                            if (rms_half_sel == NUM_SUBS - 4'd1) begin
                                rms_half_sel <= 4'd0;
                                rms_phase    <= is_norm_mode && !is_residual_mode;
                                rms_phase_trigger <= is_norm_mode && is_residual_mode;
                            end else begin
                                rms_half_sel <= rms_half_sel + 4'd1;
                            end
                        end
                    end
                end else if (residual_phase) begin
                    if (gmp_data_cnt == a_tile_xfers * (GEMM_A_XFERS * GEMM_W_XFERS) - 12'd1) begin
                        gmp_data_cnt       <= 12'd0;
                        hidden_dim_cnt     <= 9'd0;
                        residual_phase     <= 1'b0;
                        residual_load_done <= 1'b1;
                        rms_phase          <= rms_phase_trigger;
                        rms_phase_trigger  <= 1'b0;
                    end
                end
            end else if (mode_gemm_proj_full_prec && in_vld && rms_phase) begin
                rms_phase_cnt <= rms_phase_cnt + 1'b1;
                if(rms_phase_cnt == rms_tile_xfers - 1) begin
                    rms_phase_cnt <= 7'd0;
                    rms_phase <= 1'b0;
                end
            end else if (mode_gemm_proj_low_prec && in_vld && lp_state == LP_RES &&
                         gmp_res_sub_cnt == a_tile_xfers - 7'd1 && gmp_res_tile_cnt == (GEMM_W_XFERS * GEMM_A_XFERS) - 5'd1) begin
                residual_load_done <= 1'b1;
            end
        end
    end

    wire [1:0] gmp_act_tidx_fp = gmp_data_cnt[7:6];
    wire [2:0] gmp_wt_tidx_fp  = gmp_data_cnt[8:6] - GEMM_A_XFERS;
    wire [4:0] gmp_res_tidx_fp = gmp_data_cnt[10:6];

    wire [1:0] gmp_act_tidx = mode_gemm_proj_low_prec ? gmp_act_tile_idx : gmp_act_tidx_fp;
    wire [2:0] gmp_wt_tidx  = mode_gemm_proj_low_prec ? gmp_wkv_tile_idx : gmp_wt_tidx_fp;
    wire [4:0] gmp_residual_tidx = mode_gemm_proj_low_prec ? gmp_res_tile_cnt : gmp_res_tidx_fp;

    localparam integer GMP_RES_W_SHIFT = $clog2(GEMM_W_XFERS);
    wire [$clog2(CORE_NUM)-1:0] gmp_res_core =
        ((gmp_residual_tidx >> GMP_RES_W_SHIFT) * GEMM_W_XFERS) +
        (gmp_residual_tidx & (GEMM_W_XFERS - 1));

    integer gpri;

    always @(*) begin
        gmp_act_route = {CORE_NUM{1'b0}};
        case (gemm_proj_routing_mode)
            2'b00: gmp_act_route = ({{CORE_NUM{1'b0}}} | ((1 << (GEMM_W_XFERS)) - 1))
                                    << (gmp_act_tidx * (CORE_NUM/GEMM_A_XFERS));
            2'b01: begin
                for(gpri=0; gpri<GEMM_W_XFERS; gpri=gpri+1) begin
                    gmp_act_route[gmp_act_tidx + gpri*(GEMM_A_XFERS)] = 1'b1;
                end
            end
            2'b10: gmp_act_route = (({{CORE_NUM{1'b0}}} | ((1 << (GEMM_W_XFERS/2)) - 1)) << (gmp_act_tidx * GEMM_W_XFERS/2))
                                | (({{CORE_NUM{1'b0}}} | ((1 << (GEMM_W_XFERS/2)) - 1)) << (gmp_act_tidx * GEMM_W_XFERS/2 + CORE_NUM/2));
            default: gmp_act_route = {CORE_NUM{1'b0}};
        endcase
    end

    always @(*) begin
        gmp_wt_route = {CORE_NUM{1'b0}};
        case (gemm_proj_routing_mode)
            2'b00: begin
                for(gpri=0; gpri<GEMM_A_XFERS; gpri=gpri+1) begin
                    gmp_wt_route[gmp_wt_tidx + gpri*(GEMM_W_XFERS)] = 1'b1;
                end
            end
            2'b01: gmp_wt_route = ({{CORE_NUM{1'b0}}} | ((1 << (GEMM_A_XFERS)) - 1))
                                    << (gmp_wt_tidx * (GEMM_A_XFERS));
            2'b10: begin
                if (gmp_wt_tidx < GEMM_W_XFERS/2) begin
                    for(gpri=0; gpri<GEMM_A_XFERS; gpri=gpri+1) begin
                        gmp_wt_route[gmp_wt_tidx + gpri*(GEMM_A_XFERS)]    = 1'b1;
                    end
                end else begin
                    for(gpri=0; gpri<GEMM_A_XFERS; gpri=gpri+1) begin
                        gmp_wt_route[(gmp_wt_tidx - GEMM_W_XFERS/2) + gpri*(GEMM_A_XFERS) + CORE_NUM/2]    = 1'b1;
                    end
                end
            end
            default: gmp_wt_route = {CORE_NUM{1'b0}};
        endcase
    end

    always @(*) begin
        gmp_residual_route = {{CORE_NUM-1{1'b0}}, 1'b1} << gmp_res_core;
    end

    always @(*) begin
        pnorm_row_in_vld = 1'b0;
        pnorm_row_din    = {CHIP_DATA_WIDTH{1'b0}};
        if (mode_gemm_proj_full_prec && is_norm_mode) begin
            pnorm_row_in_vld = in_vld;
            pnorm_row_din    = in_data;
        end else if (mode_gemm_proj_low_prec) begin
            pnorm_row_in_vld = in_vld && !w_mask_beat &&
                                         (lp_state == LP_ACT ||
                                          lp_state == LP_RES ||
                                          lp_state == LP_WKV ||
                                          gmp_rms_phase);
            pnorm_row_din    = in_data;
        end else if (mode_gemv_proj_full_prec) begin
            pnorm_row_in_vld = in_vld && (gvpf_state == GVPF_RMS ||
                                          gvpf_state == GVPF_ACT);
            pnorm_row_din    = in_data;
        end else if (mode_gemv_proj_low_prec) begin
            pnorm_row_in_vld = in_vld && (gvpl_rms_phase ||
                                          lp_state == LP_ACT);
            pnorm_row_din    = in_data;
        end
    end

    reg         gmp_bypass_vld;
    reg [CHIP_DATA_WIDTH-1:0] gmp_bypass_data;
    reg         gmp_bypass_is_act;
    reg         gmp_bypass_is_residual;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gmp_bypass_vld  <= 1'b0;
            gmp_bypass_data <= {CHIP_DATA_WIDTH{1'b0}};
            gmp_bypass_is_act <= 1'b0;
            gmp_bypass_is_residual <= 1'b0;
        end else begin
            gmp_bypass_vld  <= mode_gemm_proj_full_prec && in_vld && !rms_phase;
            gmp_bypass_data <= in_data;
            gmp_bypass_is_act <= gmp_is_act;
            gmp_bypass_is_residual <= residual_phase;
        end
    end

    reg [CORE_NUM-1:0] gmp_act_route_d1, gmp_act_route_d2, gmp_act_route_d3;
    reg [CORE_NUM-1:0] gmp_wt_route_d1,  gmp_wt_route_d2,  gmp_wt_route_d3;
    reg                gmp_is_act_d2,    gmp_is_act_d3;
    reg                gmp_is_res_d2,    gmp_is_res_d3;
    reg [CORE_NUM-1:0] gmp_residual_route_d1, gmp_residual_route_d2, gmp_residual_route_d3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gmp_act_route_d1 <= {CORE_NUM{1'b0}};
            gmp_act_route_d2 <= {CORE_NUM{1'b0}};
            gmp_act_route_d3 <= {CORE_NUM{1'b0}};
            gmp_wt_route_d1  <= {CORE_NUM{1'b0}};
            gmp_wt_route_d2  <= {CORE_NUM{1'b0}};
            gmp_wt_route_d3  <= {CORE_NUM{1'b0}};
            gmp_is_act_d2    <= 1'b0;
            gmp_is_act_d3    <= 1'b0;
            gmp_is_res_d2    <= 1'b0;
            gmp_is_res_d3    <= 1'b0;
            gmp_residual_route_d1 <= {CORE_NUM{1'b0}};
            gmp_residual_route_d2 <= {CORE_NUM{1'b0}};
            gmp_residual_route_d3 <= {CORE_NUM{1'b0}};
        end else begin
            gmp_act_route_d1 <= gmp_act_route;
            gmp_act_route_d2 <= gmp_act_route_d1;
            gmp_act_route_d3 <= gmp_act_route_d2;
            gmp_wt_route_d1  <= gmp_wt_route;
            gmp_wt_route_d2  <= gmp_wt_route_d1;
            gmp_wt_route_d3  <= gmp_wt_route_d2;
            gmp_is_act_d2    <= gmp_bypass_is_act;
            gmp_is_act_d3    <= gmp_is_act_d2;
            gmp_is_res_d2    <= gmp_bypass_is_residual;
            gmp_is_res_d3    <= gmp_is_res_d2;
            gmp_residual_route_d1 <= gmp_residual_route;
            gmp_residual_route_d2 <= gmp_residual_route_d1;
            gmp_residual_route_d3 <= gmp_residual_route_d2;
        end
    end

    wire gmp_path_is_residual = is_norm_mode ? gmp_is_res_d3 : gmp_bypass_is_residual;
    wire gmp_path_is_act = !gmp_path_is_residual && (is_norm_mode ? gmp_is_act_d3 : gmp_bypass_is_act);
    wire gmp_path_is_wt  = !gmp_path_is_residual && (is_norm_mode ? (~gmp_is_act_d3 && ~gmp_is_res_d3) : (~gmp_bypass_is_act && ~gmp_bypass_is_residual));
    wire [CORE_NUM-1:0] gmp_path_route = gmp_path_is_residual ? (is_norm_mode ? gmp_residual_route_d3 : gmp_residual_route_d1) :
                                        gmp_path_is_act ?
                                         (is_norm_mode ? gmp_act_route_d3 : gmp_act_route_d1) :
                                         (is_norm_mode ? gmp_wt_route_d3  : gmp_wt_route_d1);

    wire        gmp_path_vld  = is_norm_mode ? pnorm_out_vld : gmp_bypass_vld;
    wire [CHIP_DATA_WIDTH-1:0] gmp_path_data = is_norm_mode ? pnorm_out     : gmp_bypass_data;

    localparam GQAM_Q       = 2'd1;
    localparam GQAM_SCALEZP = 2'd2;
    localparam GQAM_KV      = 2'd3;

    reg [1:0]  gqam_state;
    reg [15:0] gqam_in_cnt;
    reg [6:0]  gqam_szp_cnt;
    reg [32:0]  gqam_kv_tidx;
    reg [6:0]  gqam_kv_sub;
    reg        gqam_g32_2nd;

    reg [31:0] q_tile_num;

    wire [31:0] unp_window_tiles = {16'd0, window_size[15:7]};
    wire [31:0] kv_pairs_exp     = (unp_window_tiles != 32'd0 && q_tile_num > unp_window_tiles)
                                   ? unp_window_tiles : q_tile_num;

    wire [15:0] q_phase_end = {10'd0, group_size} * 16'd64;
    wire [4:0]  gqam_q_core_idx  = gqam_in_cnt  >> (6 - $clog2(CORE_NUM));
    wire [CORE_NUM-1:0] gqam_q_route   = ({{(CORE_NUM-1){1'b0}}, 1'b1}) << gqam_q_core_idx[$clog2(CORE_NUM)-1:0];
    wire        gqam_kv_is_k = !gqam_kv_tidx[0];
    wire gemm_gqa_is_bf16_kv = mode_gemm_gqa && (k_precision == 5'd16);
    wire outlier_kv_active = mode_gemm_gqa && !gemm_gqa_is_bf16_kv && (outlier_num != 8'd0);
    wire [6:0]  gqam_cur_xfers = (gqam_kv_is_k && outlier_kv_active) ? {k_tile_xfers[5:0],1'b0}
                              : (gqam_kv_is_k ? k_tile_xfers : v_tile_xfers);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gqam_state   <= GQAM_Q;
            gqam_in_cnt  <= 16'd0;
            gqam_szp_cnt <= 7'd0;
            gqam_kv_tidx <= 33'd0;
            gqam_kv_sub  <= 7'd0;
            gqam_g32_2nd <= 1'b0;
            diag_done_trigger_gemm <= {CORE_NUM{1'b0}};
            q_tile_num   <= 32'd0;
        end else if (isa_valid) begin
            gqam_state   <= GQAM_Q;
            gqam_in_cnt  <= 16'd0;
            gqam_szp_cnt <= 7'd0;
            gqam_kv_tidx <= 33'd0;
            gqam_kv_sub  <= 7'd0;
            gqam_g32_2nd <= 1'b0;
            q_tile_num   <= 32'd0;
        end else begin
            diag_done_trigger_gemm <= {CORE_NUM{1'b0}};
            if (mode_gemm_gqa && in_vld) begin
                case (gqam_state)
                    GQAM_Q: begin
                        gqam_in_cnt <= gqam_in_cnt + 16'd1;
                        if (gqam_in_cnt == q_phase_end - 16'd1) begin
                            gqam_in_cnt  <= 16'd0;
                            q_tile_num   <= q_tile_num + 1'b1;
                            gqam_state   <= gemm_gqa_is_bf16_kv ? GQAM_KV : GQAM_SCALEZP;
                            gqam_kv_tidx <= 33'd0;
                            gqam_szp_cnt <= 7'd0;
                        end
                    end
                    GQAM_SCALEZP: begin
                        gqam_szp_cnt <= gqam_szp_cnt + 7'd1;
                        if (gqam_szp_cnt == {1'b0, scalezp_total} - 7'd1) begin
                            gqam_state   <= GQAM_KV;
                            gqam_kv_sub  <= 7'd0;
                        end
                    end
                    GQAM_KV: begin
                        gqam_kv_sub <= gqam_kv_sub + 7'd1;
                        if (outlier_kv_active && gqam_kv_is_k && !gqam_kv_sub[0])
                            gqam_mask_reg <= in_data;
// synopsys translate_off
`ifdef KOPROBE
                        if (outlier_kv_active && gqam_kv_is_k && !gqam_kv_sub[0]) begin
                            ko_latch_cnt = ko_latch_cnt + 1;
                            if (|in_data) ko_latch_nz = ko_latch_nz + 1;
                        end
                        if (outlier_kv_active && gqam_kv_is_k && ko_beat_cnt < 64) begin
                            ko_beat_cnt = ko_beat_cnt + 1;
                            $display("[KOMASK] t=%0t sub=%0d tidx=%0d in_lo=%016h in_hi=%016h mask_lo=%016h mask_hi=%016h", $time, gqam_kv_sub, gqam_kv_tidx[7:0],
                                     in_data[63:0], in_data[MEM_DATA_WIDTH-1 -: 64], gqam_mask_reg[63:0], gqam_mask_reg[MEM_DATA_WIDTH-1 -: 64]);
                        end
`endif
// synopsys translate_on
                        if (gqam_kv_sub == gqam_cur_xfers - 7'd1) begin
                            gqam_kv_sub  <= 7'd0;
                            gqam_kv_tidx <= gqam_kv_tidx + 33'd1;

                            if (gqam_kv_tidx == 2*kv_pairs_exp-2) begin
                                diag_done_trigger_gemm <= {CORE_NUM{1'b1}};
                            end

                            if (gqam_kv_tidx == 2*kv_pairs_exp-1) begin
                                gqam_state <= GQAM_Q;
                                gqam_kv_tidx <= 33'd0;
                                gqam_in_cnt <= 16'd0;
                                if(q_tile_num == (seq_len >> 7)) begin
                                    q_tile_num <= 32'd0;
                                end
                            end else if (group_width == 2'b01 && !gqam_g32_2nd && gqam_kv_tidx[1:0] == 2'd3) begin
                                gqam_state <= gemm_gqa_is_bf16_kv ? GQAM_KV : GQAM_SCALEZP;
                                gqam_szp_cnt <= 7'd0;
                                gqam_g32_2nd <= 1'b1;
                            end else if (group_width == 2'b01 && gqam_g32_2nd && gqam_kv_tidx[1:0] == 2'd3) begin
                                gqam_state <= gemm_gqa_is_bf16_kv ? GQAM_KV : GQAM_SCALEZP;
                                gqam_szp_cnt <= 7'd0;
                                gqam_g32_2nd <= 1'b0;
                            end else if (group_width != 2'b01 && gqam_kv_tidx[2:0] == 3'd7) begin
                                gqam_state <= gemm_gqa_is_bf16_kv ? GQAM_KV : GQAM_SCALEZP;
                                gqam_szp_cnt <= 7'd0;
                            end
                        end
                    end
                endcase
            end
        end
    end

    reg [6:0]  gvpf_rms_cnt;
    reg [15:0] gvpf_act_cnt;
    reg [23:0] gvpf_wt_cnt;
    reg [15:0] gvpf_wt_x_remaining;
    reg [15:0] gvpf_res_burst_cnt;
    reg [9:0]  gvpf_res_batch_cnt;
    reg        gvpf_residual_phase;
    reg        gvpf_is_value_phase;

    wire [15:0] gvpf_wt_chunk_w =
        (gvpf_wt_x_remaining >= {8'd0, batch_space}) ? {8'd0, batch_space}
                                                    : gvpf_wt_x_remaining;
    wire [23:0] gvpf_wt_block_beats =
        ({16'd0, gvpf_wt_chunk_w[7:0]} * {12'd0, hidden_dim[11:0]}) >> 1;

    wire [23:0] gvpf_act_total =
        ({16'd0, batch_num[7:0]} * {14'd0, token_beat_num[9:0]});

    wire [15:0] gvpf_res_burst_size =
        16'd2 * ((({5'd0, gvpf_wt_chunk_w[7:0], 11'd0}) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));
    wire        gvpf_res_burst_last = (gvpf_res_burst_cnt == gvpf_res_burst_size - 16'd1);
    wire        gvpf_res_round_last_batch =
                    (gvpf_res_batch_cnt == {2'd0, batch_num} - 10'd1);
    wire        gvpf_wt_all_done =
                    (gvpf_wt_x_remaining <= {8'd0, batch_space});

    assign gvpl_wt_chunk_w  =
        (gvpl_wt_x_remaining >= {8'd0, batch_space}) ? {8'd0, batch_space}
                                                     : gvpl_wt_x_remaining;
    assign gvpl_wt_all_done =
                    (gvpl_wt_x_remaining <= {8'd0, batch_space});

    wire [15:0] gvpl_res_burst_size =
        16'd2 * ((({5'd0, gvpl_wt_chunk_w[7:0], 11'd0}) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));

    reg gvpf_dim_read_done_r;
    assign dim_read_done = gvpf_dim_read_done_r | gvpl_dim_read_done_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gvpf_state          <= GVPF_IDLE;
            gvpf_rms_cnt        <= 7'd0;
            gvpf_act_cnt        <= 16'd0;
            gvpf_wt_cnt         <= 24'd0;
            gvpf_wt_x_remaining <= 16'd0;
            gvpf_res_burst_cnt  <= 16'd0;
            gvpf_res_batch_cnt  <= 10'd0;
            gvpf_residual_phase <= 1'b0;
            gvpf_is_value_phase <= 1'b0;
            gvpf_dim_read_done_r <= 1'b0;
        end else if (isa_valid) begin
            gvpf_state          <= GVPF_IDLE;
            gvpf_rms_cnt        <= 7'd0;
            gvpf_act_cnt        <= 16'd0;
            gvpf_wt_cnt         <= 24'd0;
            gvpf_wt_x_remaining <= output_dim[15:7];
            gvpf_res_burst_cnt  <= 16'd0;
            gvpf_res_batch_cnt  <= 10'd0;
            gvpf_residual_phase <= 1'b0;
            gvpf_is_value_phase <= 1'b0;
            gvpf_dim_read_done_r <= 1'b0;
        end else begin
            gvpf_dim_read_done_r <= 1'b0;
            if (mode_gemv_proj_full_prec) begin
                case (gvpf_state)
                GVPF_IDLE: begin
                    gvpf_state <=   is_norm_mode ?  GVPF_RMS :
                                    a_on_chip ?     GVPF_WT  : GVPF_ACT;
                end
                GVPF_RMS: begin
                    if (in_vld) begin
                        gvpf_rms_cnt <= gvpf_rms_cnt + 7'd1;
                        if (gvpf_rms_cnt == rms_tile_xfers - 7'd1) begin
                            gvpf_rms_cnt <= 7'd0;
                            gvpf_state   <= a_on_chip ? GVPF_WT : GVPF_ACT;
                        end
                    end
                end
                GVPF_ACT: begin
                    if (in_vld) begin
                        gvpf_act_cnt <= gvpf_act_cnt + 16'd1;
                        if (gvpf_act_cnt == gvpf_act_total[15:0] - 16'd1) begin
                            gvpf_act_cnt <= 16'd0;
                            gvpf_wt_cnt  <= 24'd0;
                            gvpf_state   <= GVPF_WT;
                        end
                    end
                end
                GVPF_WT: begin
                    if (in_vld) begin
                        gvpf_wt_cnt <= gvpf_wt_cnt + 24'd1;
                        if (gvpf_wt_cnt == gvpf_wt_block_beats - 24'd1) begin
                            gvpf_wt_cnt <= 24'd0;
                            if (is_residual_mode) begin
                                gvpf_state          <= GVPF_RES;
                                gvpf_res_burst_cnt  <= 16'd0;
                                gvpf_res_batch_cnt  <= 10'd0;
                                gvpf_residual_phase <= 1'b1;
                            end else begin
                                gvpf_dim_read_done_r <= 1'b1;
                                if (gvpf_wt_all_done) begin
                                    if (is_gating_mode && !gvpf_is_value_phase) begin
                                        gvpf_is_value_phase <= 1'b1;
                                        gvpf_wt_x_remaining <= output_dim[15:7];
                                    end else begin
                                        gvpf_state          <= GVPF_IDLE;
                                    end
                                end else begin
                                    gvpf_wt_x_remaining <= gvpf_wt_x_remaining
                                                          - gvpf_wt_chunk_w;
                                end
                            end
                        end
                    end
                end
                GVPF_RES: begin
                    if (in_vld) begin
                        gvpf_res_burst_cnt <= gvpf_res_burst_cnt + 16'd1;
                        if (gvpf_res_burst_last) begin
                            gvpf_res_burst_cnt <= 16'd0;
                            gvpf_res_batch_cnt <= gvpf_res_batch_cnt + 10'd1;
                            if (gvpf_res_round_last_batch) begin
                                gvpf_res_batch_cnt  <= 10'd0;
                                gvpf_residual_phase <= 1'b0;
                                gvpf_dim_read_done_r <= 1'b1;
                                if (gvpf_wt_all_done) begin
                                    gvpf_state          <= GVPF_IDLE;
                                end else begin
                                    gvpf_wt_x_remaining <= gvpf_wt_x_remaining
                                                          - gvpf_wt_chunk_w;
                                    gvpf_state          <= GVPF_WT;
                                end
                            end
                        end
                    end
                end
                default: gvpf_state <= GVPF_IDLE;
                endcase
            end
        end
    end

    assign gvpf_rms_phase = (gvpf_state == GVPF_RMS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gemv_rms_div     <= 16'd0;
            gemv_rms_div_vld <= 1'b0;
        end else if (isa_valid) begin
            gemv_rms_div     <= 16'd0;
            gemv_rms_div_vld <= 1'b0;
        end else if (mode_gemv_proj_full_prec && is_norm_mode &&
                     gvpf_state == GVPF_RMS && in_vld && gvpf_rms_cnt == 7'd0) begin
            gemv_rms_div     <= in_data[15:0];
            gemv_rms_div_vld <= 1'b1;
        end else if (mode_gemv_proj_low_prec && is_norm_mode && a_on_chip &&
                     gvpl_rms_phase && in_vld && gvpl_rms_phase_cnt == 7'd0) begin
            gemv_rms_div     <= in_data[15:0];
            gemv_rms_div_vld <= 1'b1;
        end
    end

    reg [9:0] gvp_act_beat_in_token;
    reg [5:0] gvp_act_core_idx_r;

    reg [5:0] gvp_res_core_idx_r;

    reg  [15:0] gvpl_res_sub_cnt;
    wire        gvpl_res_sub_last = (gvpl_res_sub_cnt == residual_beat_num - 16'd1);
    wire [15:0] gvpl_res_round_total =
                    ({8'd0, residual_beat_num}) * {8'd0, batch_num[7:0]};
    wire       gvpl_res_round_last = (lp_res_load_cnt == gvpl_res_round_total - 16'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gvp_act_beat_in_token  <= 10'd0;
            gvp_act_core_idx_r     <= 6'd0;
            gvp_res_core_idx_r     <= 6'd0;
            gvpl_res_sub_cnt       <= 16'd0;
        end else if (isa_valid) begin
            gvp_act_beat_in_token  <= 10'd0;
            gvp_act_core_idx_r     <= 6'd0;
            gvp_res_core_idx_r     <= 6'd0;
            gvpl_res_sub_cnt       <= 16'd0;
        end else begin
            if (((mode_gemv_proj_full_prec && gvpf_state == GVPF_ACT) ||
                 (mode_gemv_proj_low_prec  && lp_state == LP_ACT)) && in_vld) begin
                if (gvp_act_beat_in_token == token_beat_num - 10'd1) begin
                    gvp_act_beat_in_token <= 10'd0;
                    if (gvp_act_core_idx_r == decode_core_num[5:0] - 6'd1)
                        gvp_act_core_idx_r <= 6'd0;
                    else
                        gvp_act_core_idx_r <= gvp_act_core_idx_r + 6'd1;
                end else begin
                    gvp_act_beat_in_token <= gvp_act_beat_in_token + 10'd1;
                end
            end

            if (mode_gemv_proj_low_prec && lp_state == LP_RES && in_vld) begin
                if (gvpl_res_sub_last)
                    gvpl_res_sub_cnt <= 16'd0;
                else
                    gvpl_res_sub_cnt <= gvpl_res_sub_cnt + 16'd1;
            end

            if (((mode_gemv_proj_full_prec && gvpf_state == GVPF_RES && gvpf_res_burst_last) ||
                 (mode_gemv_proj_low_prec  && lp_state == LP_RES && gvpl_res_sub_last)) && in_vld) begin
`ifdef RESPROBE
                $display("[DECRESIDX] t=%0t batch=%0d act_core=%0d res_core=%0d route=%b dcn=%0d bn=%0d",
                         $time, gvpf_res_batch_cnt, gvp_act_core_idx_r, gvp_res_core_idx_r,
                         gvp_res_route, decode_core_num, batch_num);
`endif
                if ((mode_gemv_proj_full_prec && gvpf_res_round_last_batch) ||
                    (mode_gemv_proj_low_prec  && gvpl_res_round_last)
`ifndef RESNOFIX
                    || (gvp_res_core_idx_r == decode_core_num[5:0] - 6'd1)
`endif
                   ) begin
                    gvp_res_core_idx_r     <= 6'd0;
                end else begin
                    gvp_res_core_idx_r <= gvp_res_core_idx_r + 6'd1;
                end
            end
        end
    end

    assign gvp_act_route = ({{(CORE_NUM-1){1'b0}}, 1'b1}) << gvp_act_core_idx_r;
    assign gvp_res_route = ({{(CORE_NUM-1){1'b0}}, 1'b1}) << gvp_res_core_idx_r;
    wire [CORE_NUM-1:0] gv_wkv_route_base =
        ({{CORE_NUM{1'b1}}}) >> (CORE_NUM[6:0] - {1'b0, decode_core_num});
    assign gv_wkv_route = (gvpf_is_value_phase | gvpl_is_value_phase)
                              ? (gv_wkv_route_base << (CORE_NUM/2))
                              : gv_wkv_route_base;

    wire gemv_gqa_is_bf16_kv = mode_gemv_gqa && (k_precision == 5'd16);

    reg [2:0]            gvpf_state_d1,     gvpf_state_d2,     gvpf_state_d3;
    reg [CORE_NUM-1:0]   gvp_act_route_d1, gvp_act_route_d2, gvp_act_route_d3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gvpf_state_d1 <= GVPF_IDLE; gvpf_state_d2 <= GVPF_IDLE; gvpf_state_d3 <= GVPF_IDLE;
            gvp_act_route_d1 <= {CORE_NUM{1'b0}};
            gvp_act_route_d2 <= {CORE_NUM{1'b0}};
            gvp_act_route_d3 <= {CORE_NUM{1'b0}};
        end else begin
            gvpf_state_d1     <= gvpf_state;
            gvpf_state_d2     <= gvpf_state_d1;
            gvpf_state_d3     <= gvpf_state_d2;
            gvp_act_route_d1 <= gvp_act_route;
            gvp_act_route_d2 <= gvp_act_route_d1;
            gvp_act_route_d3 <= gvp_act_route_d2;
        end
    end

    wire        gvpf_path_act_vld = mode_gemv_proj_full_prec
                                   && pnorm_out_vld
                                   && !pnorm_rms_phase_d3
                                   && (gvpf_state_d3 == GVPF_ACT);

    wire        gvpf_wt_block_last_raw = gvpf_wt_pipe_push
                                        && (gvpf_wt_cnt == gvpf_wt_block_beats - 24'd1);

    reg                       gvpf_wt_vld_d1,     gvpf_wt_vld_d2,     gvpf_wt_vld_d3;
    reg                       gvpf_res_vld_d1,    gvpf_res_vld_d2,    gvpf_res_vld_d3;
    reg [CORE_NUM-1:0]        gv_wkv_route_d1,   gv_wkv_route_d2,   gv_wkv_route_d3;
    reg [CORE_NUM-1:0]        gvp_res_route_d1,  gvp_res_route_d2,  gvp_res_route_d3;
    reg                       gvpf_wt_blast_d1,   gvpf_wt_blast_d2,   gvpf_wt_blast_d3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gvpf_wt_vld_d1  <= 1'b0; gvpf_wt_vld_d2  <= 1'b0; gvpf_wt_vld_d3  <= 1'b0;
            gvpf_res_vld_d1 <= 1'b0; gvpf_res_vld_d2 <= 1'b0; gvpf_res_vld_d3 <= 1'b0;
            gv_wkv_route_d1  <= {CORE_NUM{1'b0}};
            gv_wkv_route_d2  <= {CORE_NUM{1'b0}};
            gv_wkv_route_d3  <= {CORE_NUM{1'b0}};
            gvp_res_route_d1 <= {CORE_NUM{1'b0}};
            gvp_res_route_d2 <= {CORE_NUM{1'b0}};
            gvp_res_route_d3 <= {CORE_NUM{1'b0}};
            gvpf_wt_blast_d1 <= 1'b0; gvpf_wt_blast_d2 <= 1'b0; gvpf_wt_blast_d3 <= 1'b0;
        end else begin
            gvpf_wt_vld_d1    <= gvpf_wt_pipe_push;
            gvpf_res_vld_d1   <= gvpf_res_pipe_push;
            gv_wkv_route_d1  <= gv_wkv_route;
            gvp_res_route_d1 <= gvp_res_route;
            gvpf_wt_blast_d1  <= gvpf_wt_block_last_raw;
            gvpf_wt_vld_d2    <= gvpf_wt_vld_d1;
            gvpf_res_vld_d2   <= gvpf_res_vld_d1;
            gv_wkv_route_d2  <= gv_wkv_route_d1;
            gvp_res_route_d2 <= gvp_res_route_d1;
            gvpf_wt_blast_d2  <= gvpf_wt_blast_d1;
            gvpf_wt_vld_d3    <= gvpf_wt_vld_d2;
            gvpf_res_vld_d3   <= gvpf_res_vld_d2;
            gv_wkv_route_d3  <= gv_wkv_route_d2;
            gvp_res_route_d3 <= gvp_res_route_d2;
            gvpf_wt_blast_d3  <= gvpf_wt_blast_d2;
        end
    end

    wire        gvpf_path_wt_vld  = gvpf_wt_vld_d3;
    wire        gvpf_path_res_vld = gvpf_res_vld_d3;

    wire        gvpf_wt_block_last = gvpf_wt_blast_d3;

    wire       gmpl_szp_direct = mode_gemm_proj_low_prec && (lp_state == LP_SCALE_ZP) && in_vld;
    wire       szp_loading = szp_delayed_vld || gmpl_szp_direct ||
                             (mode_gemm_gqa && gqam_state == GQAM_SCALEZP && in_vld);
    wire [6:0] szp_cnt     = gmpl_szp_direct ? scalezp_load_cnt :
                             szp_delayed_vld ? szp_delayed_cnt : gqam_szp_cnt;
    wire [CHIP_DATA_WIDTH-1:0] szp_load_data = gmpl_szp_direct ? in_data :
                             szp_delayed_vld ? szp_delayed_data : in_data;

    integer si;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (si = 0; si < 8; si = si + 1) begin
                k_scale_register[si] <= {SCALE_W{1'b0}};
                k_zp_register[si]    <= {ZP_W{1'b0}};
                v_scale_register[si] <= {SCALE_W{1'b0}};
                v_zp_register[si]    <= {ZP_W{1'b0}};
            end
        end else if (isa_valid) begin
            for (si = 0; si < 8; si = si + 1) begin
                k_scale_register[si] <= {SCALE_W{1'b0}};
                k_zp_register[si]    <= {ZP_W{1'b0}};
                v_scale_register[si] <= {SCALE_W{1'b0}};
                v_zp_register[si]    <= {ZP_W{1'b0}};
            end
        end else if (szp_loading && (mode_gemv_proj_low_prec || mode_gemm_proj_low_prec)) begin
            case (group_width)
                2'b01: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd1: begin
                            k_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd2: begin
                            v_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd3: begin
                            v_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd4: begin k_zp_register[0] <= szp_load_data[0 +: ZP_W]; k_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd5: begin k_zp_register[2] <= szp_load_data[0 +: ZP_W]; k_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd6: begin k_zp_register[4] <= szp_load_data[0 +: ZP_W]; k_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd7: begin k_zp_register[6] <= szp_load_data[0 +: ZP_W]; k_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd8:  begin v_zp_register[0] <= szp_load_data[0 +: ZP_W]; v_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd9:  begin v_zp_register[2] <= szp_load_data[0 +: ZP_W]; v_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd10: begin v_zp_register[4] <= szp_load_data[0 +: ZP_W]; v_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd11: begin v_zp_register[6] <= szp_load_data[0 +: ZP_W]; v_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                    endcase
                end
                2'b10: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd1: begin
                            k_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd2: begin k_zp_register[0] <= szp_load_data[0 +: ZP_W]; k_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd3: begin k_zp_register[2] <= szp_load_data[0 +: ZP_W]; k_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd4: begin k_zp_register[4] <= szp_load_data[0 +: ZP_W]; k_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd5: begin k_zp_register[6] <= szp_load_data[0 +: ZP_W]; k_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                    endcase
                end
                2'b11: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[4] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd1: begin  end
                        7'd2: begin k_zp_register[0] <= szp_load_data[0 +: ZP_W]; k_zp_register[2] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd3: begin k_zp_register[4] <= szp_load_data[0 +: ZP_W]; k_zp_register[6] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd4: begin
                            v_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[2] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[4] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[6] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd5: begin  end
                        7'd6: begin v_zp_register[0] <= szp_load_data[0 +: ZP_W]; v_zp_register[2] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd7: begin v_zp_register[4] <= szp_load_data[0 +: ZP_W]; v_zp_register[6] <= szp_load_data[ZP_W +: ZP_W]; end
                    endcase
                end
            endcase
        end else if (szp_loading) begin
            case (group_width)
                2'b01: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd1: begin
                            k_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd2: begin k_zp_register[0] <= szp_load_data[0 +: ZP_W]; k_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd3: begin k_zp_register[2] <= szp_load_data[0 +: ZP_W]; k_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd4: begin k_zp_register[4] <= szp_load_data[0 +: ZP_W]; k_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd5: begin k_zp_register[6] <= szp_load_data[0 +: ZP_W]; k_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd6: begin
                            v_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd7: begin
                            v_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd8:  begin v_zp_register[0] <= szp_load_data[0 +: ZP_W]; v_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd9:  begin v_zp_register[2] <= szp_load_data[0 +: ZP_W]; v_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd10: begin v_zp_register[4] <= szp_load_data[0 +: ZP_W]; v_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd11: begin v_zp_register[6] <= szp_load_data[0 +: ZP_W]; v_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                    endcase
                end
                2'b10: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd1: begin
                            k_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd2:  begin k_zp_register[0] <= szp_load_data[0 +: ZP_W]; k_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd3:  begin k_zp_register[2] <= szp_load_data[0 +: ZP_W]; k_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd4:  begin k_zp_register[4] <= szp_load_data[0 +: ZP_W]; k_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd5:  begin k_zp_register[6] <= szp_load_data[0 +: ZP_W]; k_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd6: begin
                            v_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[1] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[2] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[3] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd7: begin
                            v_scale_register[4] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[5] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[6] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[7] <= szp_load_data[3*SCALE_W +: SCALE_W];
                        end
                        7'd8:  begin v_zp_register[0] <= szp_load_data[0 +: ZP_W]; v_zp_register[1] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd9:  begin v_zp_register[2] <= szp_load_data[0 +: ZP_W]; v_zp_register[3] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd10: begin v_zp_register[4] <= szp_load_data[0 +: ZP_W]; v_zp_register[5] <= szp_load_data[ZP_W +: ZP_W]; end
                        7'd11: begin v_zp_register[6] <= szp_load_data[0 +: ZP_W]; v_zp_register[7] <= szp_load_data[ZP_W +: ZP_W]; end
                    endcase
                end
                2'b11: begin
                    case (szp_cnt)
                        7'd0: begin
                            k_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            k_scale_register[2] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            k_scale_register[4] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            k_scale_register[6] <= szp_load_data[3*SCALE_W +: SCALE_W];
                            k_scale_register[1] <= {SCALE_W{1'b0}};
                            k_scale_register[3] <= {SCALE_W{1'b0}};
                            k_scale_register[5] <= {SCALE_W{1'b0}};
                            k_scale_register[7] <= {SCALE_W{1'b0}};
                        end
                        7'd1: begin  end
                        7'd2: begin
                            k_zp_register[0] <= szp_load_data[0 +: ZP_W];
                            k_zp_register[2] <= szp_load_data[ZP_W +: ZP_W];
                            k_zp_register[1] <= {ZP_W{1'b0}};
                            k_zp_register[3] <= {ZP_W{1'b0}};
                        end
                        7'd3: begin
                            k_zp_register[4] <= szp_load_data[0 +: ZP_W];
                            k_zp_register[6] <= szp_load_data[ZP_W +: ZP_W];
                            k_zp_register[5] <= {ZP_W{1'b0}};
                            k_zp_register[7] <= {ZP_W{1'b0}};
                        end
                        7'd4: begin
                            v_scale_register[0] <= szp_load_data[0*SCALE_W +: SCALE_W];
                            v_scale_register[2] <= szp_load_data[1*SCALE_W +: SCALE_W];
                            v_scale_register[4] <= szp_load_data[2*SCALE_W +: SCALE_W];
                            v_scale_register[6] <= szp_load_data[3*SCALE_W +: SCALE_W];
                            v_scale_register[1] <= {SCALE_W{1'b0}};
                            v_scale_register[3] <= {SCALE_W{1'b0}};
                            v_scale_register[5] <= {SCALE_W{1'b0}};
                            v_scale_register[7] <= {SCALE_W{1'b0}};
                        end
                        7'd5: begin  end
                        7'd6: begin
                            v_zp_register[0] <= szp_load_data[0 +: ZP_W];
                            v_zp_register[2] <= szp_load_data[ZP_W +: ZP_W];
                            v_zp_register[1] <= {ZP_W{1'b0}};
                            v_zp_register[3] <= {ZP_W{1'b0}};
                        end
                        7'd7: begin
                            v_zp_register[4] <= szp_load_data[0 +: ZP_W];
                            v_zp_register[6] <= szp_load_data[ZP_W +: ZP_W];
                            v_zp_register[5] <= {ZP_W{1'b0}};
                            v_zp_register[7] <= {ZP_W{1'b0}};
                        end
                    endcase
                end
            endcase
        end
    end

    wire [2:0] num_groups = (group_width == 2'b01) ? 3'd4 :
                             (group_width == 2'b10) ? 3'd2 : 3'd1;

    wire [6:0] active_kv_sub = (mode_gemv_gqa || mode_gemv_proj_low_prec) ? wkv_tile_sub_cnt : gqam_kv_sub;
    wire       active_kv_is_k = !gqam_kv_tidx[0];
    wire [1:0] active_tile_pair = gqam_kv_tidx[3:1];
    wire       active_g32_2nd = (mode_gemv_gqa || mode_gemv_proj_low_prec) ? group32_second_phase : gqam_g32_2nd;

    reg [2:0] szp_reg_base;
    reg [3:0] w_szp_reg_base;
    always @(*) begin
        if(mode_gemm_gqa) begin
            case (group_width)
                2'b01:   szp_reg_base = {active_tile_pair[0], 2'b00};
                2'b10:   szp_reg_base = {active_tile_pair, 1'b0};
                default: szp_reg_base = {active_tile_pair, 1'b0};
            endcase
        end else if(mode_gemv_gqa && k_delayed_vld) begin
            case (group_width)
                2'b01:   szp_reg_base = {k_delayed_tile_cnt[0], 2'b00};
                2'b10:   szp_reg_base = {k_delayed_tile_cnt[1:0], 1'b0};
                default: szp_reg_base = {k_delayed_tile_cnt[1:0], 1'b0};
            endcase
        end else if((mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && k_delayed_vld) begin
            case (group_width)
                2'b01:   w_szp_reg_base = {k_delayed_tile_cnt[1:0], 2'b00};
                2'b10:   w_szp_reg_base = {1'b0, k_delayed_tile_cnt[1:0], 1'b0};
                default: w_szp_reg_base = {k_delayed_tile_cnt[2:0], 1'b0};
            endcase
        end else if((mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) && v_delayed_vld) begin
            case (group_width)
                2'b01:   szp_reg_base = {v_delayed_tile_cnt[0], 2'b00};
                2'b10:   szp_reg_base = {v_delayed_tile_cnt[1:0], 1'b0};
                default: szp_reg_base = {v_delayed_tile_cnt[1:0], 1'b0};
            endcase
        end
    end

    wire [2:0] szp_grp_idx_raw = mode_gemm_gqa ? active_kv_sub[2:0] :
                                  (mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) ?
                                      (k_delayed_vld ? k_delayed_vld_cnt[2:0] :
                                       v_delayed_vld ? v_delayed_vld_cnt[2:0] : 3'd0) : 3'd0;
    reg  [2:0] szp_grp_idx;
    always @(*) begin
        case (group_width)
            2'b01:   szp_grp_idx = {1'b0, szp_grp_idx_raw[1:0]};
            2'b10:   szp_grp_idx = {2'b0, szp_grp_idx_raw[0]};
            default: szp_grp_idx = 3'd0;
        endcase
    end
    wire [2:0] szp_reg_idx = szp_reg_base + szp_grp_idx;
    wire [3:0] w_szp_reg_idx = w_szp_reg_base + szp_grp_idx;

    wire szp_emit_gemm_gqa =  (active_kv_sub < {4'd0, num_groups} && gqam_state == GQAM_KV && in_vld);
    wire szp_emit_gemv_gqa =  !gemv_gqa_is_bf16_kv &&
                             ((k_delayed_vld_cnt < {4'd0, num_groups} && k_delayed_vld && sram_rvalid) ||
                              (v_delayed_vld_cnt < {4'd0, num_groups} && v_delayed_vld));

    wire szp_emit = mode_gemm_gqa ? szp_emit_gemm_gqa :
                    (mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) ? szp_emit_gemv_gqa : 1'b0;

    wire [SCALE_W-1:0] szp_scale_sel_gemm_gqa = active_kv_is_k ? k_scale_register[szp_reg_idx]
                                                  : v_scale_register[szp_reg_idx];
    wire [ZP_W-1:0]    szp_zp_sel_gemm_gqa    = active_kv_is_k ? k_zp_register[szp_reg_idx]
                                                  : v_zp_register[szp_reg_idx];
    wire [SCALE_W-1:0] szp_scale_sel_gemv_gqa = k_delayed_vld ? k_scale_register[szp_reg_idx] :
                                           v_delayed_vld ? v_scale_register[szp_reg_idx] : {SCALE_W{1'b0}};
    wire [ZP_W-1:0]    szp_zp_sel_gemv_gqa    = k_delayed_vld ? k_zp_register[szp_reg_idx] :
                                           v_delayed_vld ? v_zp_register[szp_reg_idx] : {ZP_W{1'b0}};
    wire [SCALE_W-1:0] szp_scale_sel_proj_low_prec = w_szp_reg_idx[3] ? v_scale_register[w_szp_reg_idx[2:0]] : k_scale_register[w_szp_reg_idx[2:0]];
    wire [ZP_W-1:0]    szp_zp_sel_proj_low_prec    = w_szp_reg_idx[3] ? v_zp_register[w_szp_reg_idx[2:0]] : k_zp_register[w_szp_reg_idx[2:0]];

    wire [SCALE_W-1:0] szp_scale_sel = mode_gemm_gqa ? szp_scale_sel_gemm_gqa :
                                  mode_gemv_gqa ? szp_scale_sel_gemv_gqa :
                                  (mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) ? szp_scale_sel_proj_low_prec : {SCALE_W{1'b0}};
    wire [ZP_W-1:0]    szp_zp_sel    = mode_gemm_gqa ? szp_zp_sel_gemm_gqa    :
                                  mode_gemv_gqa ? szp_zp_sel_gemv_gqa    :
                                  (mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) ? szp_zp_sel_proj_low_prec : {ZP_W{1'b0}};

    reg [CHIP_DATA_WIDTH-1:0] out_lower_reg;
    reg          out_lower_loaded;
    reg [15:0]   gemm_proj_out_vld_cnt;
    reg [15:0]   gemm_gqa_out_vld_cnt;
    reg [15:0]   gemv_gqa_out_vld_cnt;
    reg [CORE_NUM-1:0]   vec_load_start_trigger;
    reg [CORE_NUM-1:0]   opm_compute_start_trigger;
    reg [15:0]   gvp_a_out_cnt;
    reg [15:0]   gvg_a_out_cnt;
    reg [15:0]   gvp_r_out_cnt;
    reg [15:0]   gvp_b_out_cnt;
    reg [15:0]   gvp_r_round_target;
    reg [15:0]   gvp_b_block_target;
    reg [CORE_NUM-1:0] gvp_b_block_route;
    wire [15:0]  gvp_a_done_target = ({8'd0, batch_num} * {6'd0, token_beat_num}) >> 1;
    wire [15:0]  gvg_a_done_target = {6'd0, group_head_beat_num} >> 1;
    reg          gqam_compute_armed;
    reg [1:0]    gqam_state_d1;
    reg          gvpf_wt_armed;
    reg          gvpf_wt_gate_done;
    reg          gvpl_w_armed;
    reg          gvgqa_armed;
    reg [15:0]   gmpl_w_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dense_a_out_vld    <= 1'b0;
            dense_b_out_vld    <= 1'b0;
            dense_r_out_vld    <= 1'b0;
            dense_out_data     <= {MEM_DATA_WIDTH{1'b0}};
            dense_routing_id   <= {CORE_NUM{1'b0}};
            scale_zp_out_vld   <= 1'b0;
            scale_zp_out_data  <= {SZP_OUT_WIDTH{1'b0}};
            scale_zp_routing_id <= {CORE_NUM{1'b0}};
            out_lower_reg      <= {CHIP_DATA_WIDTH{1'b0}};
            out_lower_loaded   <= 1'b0;
            k_delayed_vld_cnt  <= 7'd0;
            v_delayed_vld_cnt  <= 7'd0;
            k_delayed_tile_cnt <= 6'd0;
            v_delayed_tile_cnt <= 6'd0;
            gemm_proj_out_vld_cnt <= 16'd0;
            gemm_gqa_out_vld_cnt  <= 16'd0;
            gemv_gqa_out_vld_cnt <= 16'd0;
            vec_load_start_trigger <= {CORE_NUM{1'b0}};
            opm_compute_start_trigger <= {CORE_NUM{1'b0}};
            opm_compute_start <= {CORE_NUM{1'b0}};
            gqam_compute_armed <= 1'b0;
            gqam_state_d1      <= 2'd0;
            gvpf_wt_armed       <= 1'b0;
            gvpf_wt_gate_done   <= 1'b0;
            gvpl_w_armed       <= 1'b0;
            gvgqa_armed        <= 1'b0;
            gvp_a_out_cnt       <= 16'd0;
            gvg_a_out_cnt       <= 16'd0;
            gvp_r_out_cnt       <= 16'd0;
            gvp_b_out_cnt       <= 16'd0;
            gvp_r_round_target  <= 16'd0;
            gvp_b_block_target  <= 16'd0;
            gvp_b_block_route   <= {CORE_NUM{1'b0}};
            gmpl_w_cnt          <= 16'd0;
        end else if (isa_valid) begin
            dense_a_out_vld    <= 1'b0;
            dense_b_out_vld    <= 1'b0;
            dense_r_out_vld    <= 1'b0;
            dense_out_data     <= {MEM_DATA_WIDTH{1'b0}};
            dense_routing_id   <= {CORE_NUM{1'b0}};
            scale_zp_out_vld   <= 1'b0;
            scale_zp_out_data  <= {SZP_OUT_WIDTH{1'b0}};
            scale_zp_routing_id <= {CORE_NUM{1'b0}};
            out_lower_reg      <= {CHIP_DATA_WIDTH{1'b0}};
            out_lower_loaded   <= 1'b0;
            k_delayed_vld_cnt  <= 7'd0;
            v_delayed_vld_cnt  <= 7'd0;
            k_delayed_tile_cnt <= 6'd0;
            v_delayed_tile_cnt <= 6'd0;
            gemm_proj_out_vld_cnt <= 16'd0;
            gemm_gqa_out_vld_cnt  <= 16'd0;
            gemv_gqa_out_vld_cnt <= 16'd0;
            vec_load_start_trigger <= {CORE_NUM{1'b0}};
            opm_compute_start_trigger <= {CORE_NUM{1'b0}};
            opm_compute_start <= {CORE_NUM{1'b0}};
            gqam_compute_armed <= 1'b0;
            gqam_state_d1      <= 2'd0;
            gvpf_wt_armed       <= 1'b0;
            gvpf_wt_gate_done   <= 1'b0;
            gvpl_w_armed       <= 1'b0;
            gvgqa_armed        <= 1'b0;
            gvp_a_out_cnt       <= 16'd0;
            gvg_a_out_cnt       <= 16'd0;
            gvp_r_out_cnt       <= 16'd0;
            gvp_b_out_cnt       <= 16'd0;
            gvp_r_round_target  <= 16'd0;
            gvp_b_block_target  <= 16'd0;
            gvp_b_block_route   <= {CORE_NUM{1'b0}};
            gmpl_w_cnt          <= 16'd0;
        end else begin
            dense_a_out_vld    <= 1'b0;
            dense_b_out_vld    <= 1'b0;
            dense_r_out_vld    <= 1'b0;
            scale_zp_out_vld   <= 1'b0;
            vec_load_start_trigger <= {CORE_NUM{1'b0}};
            vec_load_start <= vec_load_start_trigger;
            opm_compute_start_trigger <= {CORE_NUM{1'b0}};
            opm_compute_start  <= opm_compute_start_trigger;

            gqam_state_d1 <= gqam_state;

            if (mode_gemv_proj_full_prec && gvpf_state == GVPF_RES) begin
                gvp_r_round_target <=
                    ({8'd0, batch_num} * gvpf_res_burst_size) >> 1;
            end else if (mode_gemv_proj_low_prec && lp_state == LP_RES) begin
                gvp_r_round_target <=
                    ({8'd0, batch_num} * gvpl_res_burst_size) >> 1;
            end

            if (a_on_chip && mode_gemv_proj_full_prec &&
                gvpf_state == GVPF_WT && gvpf_state_d1 != GVPF_WT) begin
                vec_load_start_trigger <=
                    ({CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]))
                    | (is_gating_mode
                        ? (({CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0])) << (CORE_NUM/2))
                        : {CORE_NUM{1'b0}});
                gvpf_wt_armed <= 1'b1;
                gvp_b_block_target <= gvpf_bypass_stream_launch
                                      ? GVPF_FIRST_B_TILE_DENSE_BEATS
                                      : gvpf_wt_block_beats[16:1];
            end
            if (a_on_chip && (mode_gemv_proj_low_prec || mode_gemv_gqa) &&
                lp_state != LP_IDLE && gpl_state_d1 == LP_IDLE) begin
                vec_load_start_trigger <=
                    ({CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]))
                    | ((mode_gemv_proj_low_prec && is_gating_mode)
                        ? (({CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0])) << (CORE_NUM/2))
                        : {CORE_NUM{1'b0}});
                if (mode_gemv_proj_low_prec) gvpl_w_armed <= 1'b1;
                else                          gvgqa_armed  <= 1'b1;
            end

            if (dense_a_out_vld &&
                (mode_gemv_proj_full_prec || mode_gemv_proj_low_prec)) begin
                if (gvp_a_out_cnt == gvp_a_done_target - 16'd1) begin
                    gvp_a_out_cnt <= 16'd0;
                    vec_load_start_trigger <=
                        {CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]);
                    if (mode_gemv_proj_full_prec) begin
                        gvpf_wt_armed      <= 1'b1;
                        gvp_b_block_target <= gvpf_bypass_stream_launch
                                              ? GVPF_FIRST_B_TILE_DENSE_BEATS
                                              : gvpf_wt_block_beats[16:1];
                    end else begin
                        gvpl_w_armed       <= 1'b1;
                    end
                end else begin
                    gvp_a_out_cnt <= gvp_a_out_cnt + 16'd1;
                end
            end

            if (dense_a_out_vld && mode_gemv_gqa) begin
                if (gvg_a_out_cnt == gvg_a_done_target - 16'd1) begin
                    gvg_a_out_cnt <= 16'd0;
                    vec_load_start_trigger <=
                        {CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]);
                    gvgqa_armed   <= 1'b1;
                end else begin
                    gvg_a_out_cnt <= gvg_a_out_cnt + 16'd1;
                end
            end

            if (dense_r_out_vld &&
                (mode_gemv_proj_full_prec || mode_gemv_proj_low_prec)) begin
                if (gvp_r_out_cnt == gvp_r_round_target - 16'd1) begin
                    gvp_r_out_cnt <= 16'd0;
                    vec_load_start_trigger <=
                        {CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]);
                    if (mode_gemv_proj_full_prec) begin
                        gvpf_wt_armed      <= 1'b1;
                        gvp_b_block_target <= gvpf_wt_block_beats[16:1];
                    end else begin
                        gvpl_w_armed       <= 1'b1;
                    end
                end else begin
                    gvp_r_out_cnt <= gvp_r_out_cnt + 16'd1;
                end
            end

            if (mode_gemm_proj_full_prec && gmp_path_vld) begin
                if (!out_lower_loaded) begin
                    out_lower_reg    <= gmp_path_data;
                    out_lower_loaded <= 1'b1;
                end else begin
                    dense_out_data   <= {gmp_path_data, out_lower_reg};
                    dense_a_out_vld  <= gmp_path_is_act;
                    dense_b_out_vld  <= gmp_path_is_wt;
                    dense_r_out_vld  <= gmp_path_is_residual;
                    dense_routing_id <= gmp_path_route;
                    out_lower_loaded <= 1'b0;
                end
                if(gmp_path_is_act || gmp_path_is_wt) begin
                    gemm_proj_out_vld_cnt <= gemm_proj_out_vld_cnt + 16'd1;
                    if(gemm_proj_out_vld_cnt == a_tile_xfers*GEMM_A_XFERS + w_tile_xfers*GEMM_W_XFERS - 1) begin
                        opm_compute_start_trigger <= {CORE_NUM{1'b1}};
                        gemm_proj_out_vld_cnt <= 16'd0;
                    end
                end
            end

            if (mode_gemm_gqa) begin
                if (gqam_state == GQAM_Q && in_vld) begin
                    if (!out_lower_loaded) begin
                        out_lower_reg    <= in_data;
                        out_lower_loaded <= 1'b1;
                    end else begin
                        dense_out_data   <= {in_data, out_lower_reg};
                        dense_a_out_vld  <= 1'b1;
                        dense_b_out_vld  <= 1'b0;
                        dense_r_out_vld  <= 1'b0;
                        dense_routing_id <= gqam_q_route;
                        out_lower_loaded <= 1'b0;
                    end
                end
                if (gqam_state == GQAM_KV && in_vld) begin
                    if (gemm_gqa_is_bf16_kv) begin
                        if (!out_lower_loaded) begin
                            out_lower_reg    <= in_data;
                            out_lower_loaded <= 1'b1;
                        end else begin
                            dense_out_data   <= {in_data, out_lower_reg};
                            dense_a_out_vld  <= 1'b0;
                            dense_b_out_vld  <= 1'b1;
                            dense_r_out_vld  <= 1'b0;
                            dense_routing_id <= {CORE_NUM{1'b1}};
                            out_lower_loaded <= 1'b0;
                        end
                    end else begin
                        if (outlier_kv_active && gqam_kv_is_k) begin
                            if (gqam_kv_sub[0]) begin
// synopsys translate_off
`ifdef KOPROBE
                                ko_emit_cnt = ko_emit_cnt + 1;
                                if (|gqam_mask_reg) ko_emit_with_mask = ko_emit_with_mask + 1;
                                begin : ko_lane_count
                                    integer ko_n; ko_n = 0;
                                    for (ko_i = 0; ko_i < INT2_ELEMS; ko_i = ko_i + 1)
                                        if (gqam_mask_reg[ko_i*2 +: 2] != 2'b00) begin
                                            ko_n = ko_n + 1;
                                            if (ko_lanes_first < 0 && ko_n == 1)
                                                $display("[KOPROBE-LANE] lane=%0d m2=%0b k2=%0b emitted_nibble=%0b base_lut_would_be=%0b",
                                                         ko_i, gqam_mask_reg[ko_i*2 +: 2],
                                                         in_data[ko_i*2 +: 2],
                                                         gqam_merged_k[ko_i*4 +: 4],
                                                         gqam_kv_deq[ko_i*4 +: 4]);
                                        end
                                    ko_lanes = ko_lanes + ko_n;
                                    if (ko_lanes_first < 0) ko_lanes_first = ko_n;
                                end
`endif
// synopsys translate_on
                                dense_out_data   <= gqam_merged_k;
                                dense_a_out_vld  <= 1'b0;
                                dense_b_out_vld  <= 1'b1;
                                dense_r_out_vld  <= 1'b0;
                                dense_routing_id <= {CORE_NUM{1'b1}};
                            end else begin
                                dense_b_out_vld  <= 1'b0;
                            end
                        end else begin
                            dense_out_data   <= gqam_kv_deq;
                            dense_a_out_vld  <= 1'b0;
                            dense_b_out_vld  <= 1'b1;
                            dense_r_out_vld  <= 1'b0;
                            dense_routing_id <= {CORE_NUM{1'b1}};
                        end
                    end
                end
                if (szp_emit) begin
                    scale_zp_out_vld    <= 1'b1;
                    scale_zp_out_data   <= {szp_zp_sel, szp_scale_sel};
                    scale_zp_routing_id <= {CORE_NUM{1'b1}};
                end
                if (gqam_state == GQAM_Q && gqam_state_d1 != GQAM_Q) begin
                    gemm_gqa_out_vld_cnt <= 16'd0;
                    gqam_compute_armed   <= 1'b1;
                end else if (gqam_state == GQAM_Q && in_vld &&
                             gemm_gqa_out_vld_cnt < q_phase_end) begin
                    gemm_gqa_out_vld_cnt <= gemm_gqa_out_vld_cnt + 16'd1;
                end else if (gqam_state == GQAM_KV && in_vld &&
                             gemm_gqa_out_vld_cnt < q_phase_end + (outlier_kv_active ? {k_tile_xfers[5:0],1'b0} : k_tile_xfers)) begin
                    gemm_gqa_out_vld_cnt <= gemm_gqa_out_vld_cnt + 16'd1;
                    if (gemm_gqa_out_vld_cnt == q_phase_end + (outlier_kv_active ? {k_tile_xfers[5:0],1'b0} : k_tile_xfers) - 16'd1 &&
                        gqam_compute_armed) begin
                        opm_compute_start_trigger <= {CORE_NUM{1'b1}};
                        gqam_compute_armed         <= 1'b0;
                    end
                end
            end

            if (mode_gemv_proj_full_prec) begin
                if (gvpf_path_act_vld) begin
                    if (!out_lower_loaded) begin
                        out_lower_reg    <= pnorm_out;
                        out_lower_loaded <= 1'b1;
                    end else begin
                        dense_out_data   <= {pnorm_out, out_lower_reg};
                        dense_a_out_vld  <= 1'b1;
                        dense_b_out_vld  <= 1'b0;
                        dense_r_out_vld  <= 1'b0;
                        dense_routing_id <= gvp_act_route_d3;
                        out_lower_loaded <= 1'b0;
                    end
                end
                else if (gvpf_path_wt_vld) begin
                    if (!out_lower_loaded) begin
                        out_lower_reg    <= delay_pipe[2];
                        out_lower_loaded <= 1'b1;
                    end else begin
                        dense_out_data   <= {delay_pipe[2], out_lower_reg};
                        dense_a_out_vld  <= 1'b0;
                        dense_b_out_vld  <= 1'b1;
                        dense_r_out_vld  <= 1'b0;
                        dense_routing_id <= gv_wkv_route_d3;
                        out_lower_loaded <= 1'b0;
                    end
                end
                else if (gvpf_path_res_vld) begin
                    if (!out_lower_loaded) begin
                        out_lower_reg    <= delay_pipe[2];
                        out_lower_loaded <= 1'b1;
                    end else begin
                        dense_out_data   <= {delay_pipe[2], out_lower_reg};
                        dense_a_out_vld  <= 1'b0;
                        dense_b_out_vld  <= 1'b0;
                        dense_r_out_vld  <= 1'b1;
                        dense_routing_id <= gvp_res_route_d3;
                        out_lower_loaded <= 1'b0;
                    end
                end

                if (dense_b_out_vld && gvpf_wt_armed) begin
                    if (gvp_b_out_cnt == 16'd0) gvp_b_block_route <= gv_wkv_route_d3;
                    if (gvp_b_out_cnt == gvp_b_block_target - 16'd1) begin
                        gvp_b_out_cnt <= 16'd0;
                        opm_compute_start_trigger <=
                            (gvp_b_block_target == 16'd1) ? gv_wkv_route_d3
                                                          : gvp_b_block_route;
                        if (is_gating_mode && !gvpf_wt_gate_done) begin
                            gvpf_wt_armed      <= 1'b1;
                            gvpf_wt_gate_done  <= 1'b1;
                            gvp_b_block_target <= gvpf_wt_block_beats[16:1];
                        end else begin
                            gvpf_wt_armed <= 1'b0;
                        end
                    end else begin
                        gvp_b_out_cnt <= gvp_b_out_cnt + 16'd1;
                    end
                end
            end

            if (mode_gemv_gqa || mode_gemv_proj_low_prec || mode_gemm_proj_low_prec) begin
                if (k_delayed_vld && (gemv_gqa_is_bf16_kv || sram_rvalid)) begin
                    k_delayed_vld_cnt <= k_delayed_vld_cnt + 7'd1;
                    v_delayed_vld_cnt <= 7'd0;
                    if (gemv_gqa_is_bf16_kv) begin
                        if (!out_lower_loaded) begin
                            out_lower_reg    <= k_delayed_data;
                            out_lower_loaded <= 1'b1;
                        end else begin
                            dense_out_data   <= {k_delayed_data, out_lower_reg};
                            dense_a_out_vld  <= 1'b0;
                            dense_b_out_vld  <= 1'b1;
                            dense_r_out_vld  <= 1'b0;
                            dense_routing_id <= qkvw_delayed_route;
                            out_lower_loaded <= 1'b0;
                        end
                    end else begin
                        dense_out_data   <= final_merged_k;
                        dense_a_out_vld  <= 1'b0;
                        dense_b_out_vld  <= 1'b1;
                        dense_r_out_vld  <= 1'b0;
                        dense_routing_id <= mode_gemm_proj_low_prec ? route_pipe_lp_d3
                                                                    : qkvw_delayed_route;
                    end
                    if (mode_gemv_gqa && gvgqa_armed && k_delayed_vld_cnt == 7'd0) begin
                        opm_compute_start_trigger <=
                            {CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]);
                    end

                    if (k_delayed_vld_cnt ==
                            (mode_gemm_proj_low_prec ? gmp_low_tile_xfers :
                             mode_gemv_proj_low_prec ? gvpf_low_tile_xfers  :
                             k_tile_xfers) - 7'd1) begin
                        if (mode_gemv_proj_low_prec && gvpl_w_armed) begin
                            opm_compute_start_trigger <= is_gating_mode
                                ? qkvw_delayed_route
                                : ({CORE_NUM{1'b1}} >> (CORE_NUM[3:0] - decode_core_num[3:0]));
                        end else if (mode_gemm_proj_low_prec) begin
                            gmpl_w_cnt <= gmpl_w_cnt + 16'd1;
                            if(gmpl_w_cnt == GEMM_W_XFERS - 16'd1) begin
                                gmpl_w_cnt <= 16'd0;
                                opm_compute_start_trigger <= {CORE_NUM{1'b1}};
                            end
                        end
                        k_delayed_vld_cnt  <= 7'd0;
                        k_delayed_tile_cnt <= k_delayed_tile_cnt + 6'd1;
                        if (k_delayed_tile_cnt == (mode_gemv_proj_low_prec ?
                                                   (output_div128[5:0] - 6'd1) : 6'd3)) begin
                            k_delayed_tile_cnt <= 6'd0;
                        end
                    end
                end
                if (v_delayed_vld) begin
                    k_delayed_vld_cnt <= 7'd0;
                    v_delayed_vld_cnt <= v_delayed_vld_cnt + 7'd1;
                    if (v_delayed_vld_cnt == v_tile_xfers - 7'd1) begin
                        v_delayed_vld_cnt  <= 7'd0;
                        v_delayed_tile_cnt <= v_delayed_tile_cnt + 6'd1;
                        if (v_delayed_tile_cnt == 6'd3) begin
                            v_delayed_tile_cnt <= 6'd0;
                        end
                    end
                    if (gemv_gqa_is_bf16_kv) begin
                        if (!out_lower_loaded) begin
                            out_lower_reg    <= v_delayed_data;
                            out_lower_loaded <= 1'b1;
                        end else begin
                            dense_out_data   <= {v_delayed_data, out_lower_reg};
                            dense_a_out_vld  <= 1'b0;
                            dense_b_out_vld  <= 1'b1;
                            dense_r_out_vld  <= 1'b0;
                            dense_routing_id <= qkvw_delayed_route;
                            out_lower_loaded <= 1'b0;
                        end
                    end else begin
                        dense_out_data   <= final_dequant_v;
                        dense_a_out_vld  <= 1'b0;
                        dense_b_out_vld  <= 1'b1;
                        dense_r_out_vld  <= 1'b0;
                        dense_routing_id <= qkvw_delayed_route;
                    end
                end
                if (szp_emit) begin
                    scale_zp_out_vld    <= 1'b1;
                    scale_zp_out_data   <= {szp_zp_sel, szp_scale_sel};
                    scale_zp_routing_id <= k_delayed_vld ? qkvw_delayed_route :
                                           v_delayed_vld ? qkvw_delayed_route : {CORE_NUM{1'b1}};
                end
            end

            if (mode_gemv_gqa && q_delayed_vld) begin
                if (!out_lower_loaded) begin
                    out_lower_reg    <= q_delayed_data;
                    out_lower_loaded <= 1'b1;
                end else begin
                    dense_out_data   <= {q_delayed_data, out_lower_reg};
                    dense_a_out_vld  <= 1'b1;
                    dense_b_out_vld  <= 1'b0;
                    dense_r_out_vld  <= 1'b0;
                    dense_routing_id <= qkvw_delayed_route;
                    out_lower_loaded <= 1'b0;
                end
            end

            if (mode_gemm_proj_low_prec && gmp_act_delayed_vld) begin
                if (!out_lower_loaded) begin
                    out_lower_reg    <= gmp_act_delayed_data;
                    out_lower_loaded <= 1'b1;
                end else begin
                    dense_out_data   <= {gmp_act_delayed_data, out_lower_reg};
                    dense_a_out_vld  <= !gmp_act_delayed_is_res;
                    dense_b_out_vld  <= 1'b0;
                    dense_r_out_vld  <=  gmp_act_delayed_is_res;
                    dense_routing_id <= gmp_act_delayed_route;
                    out_lower_loaded <= 1'b0;
                end
            end

            if (mode_gemv_proj_low_prec && gvpl_pnorm_act_vld) begin
                if (!out_lower_loaded) begin
                    out_lower_reg    <= pnorm_out;
                    out_lower_loaded <= 1'b1;
                end else begin
                    dense_out_data   <= {pnorm_out, out_lower_reg};
                    dense_a_out_vld  <= 1'b1;
                    dense_b_out_vld  <= 1'b0;
                    dense_r_out_vld  <= 1'b0;
                    dense_routing_id <= gvp_act_route_d3;
                    out_lower_loaded <= 1'b0;
                end
            end

            if (mode_gemv_proj_low_prec && delay_vld[14] && pipe_is_res_lp[14]) begin
                if (!out_lower_loaded) begin
                    out_lower_reg    <= delay_pipe[14];
                    out_lower_loaded <= 1'b1;
                end else begin
                    dense_out_data   <= {delay_pipe[14], out_lower_reg};
                    dense_a_out_vld  <= 1'b0;
                    dense_b_out_vld  <= 1'b0;
                    dense_r_out_vld  <= 1'b1;
                    dense_routing_id <= gvp_res_delayed_route;
                    out_lower_loaded <= 1'b0;
                end
            end
        end
    end

endmodule
