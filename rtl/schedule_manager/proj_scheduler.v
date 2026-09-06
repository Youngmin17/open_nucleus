// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module proj_scheduler #(
    parameter ADDR_WIDTH   = 64,
    parameter DATA_WIDTH   = 256,
    parameter CORE_NUM     = 4,
    parameter AXI_CHANNELS = 32,
    parameter [3:0] GEMM_A_XFERS = 4'd2,
    parameter [3:0] GEMM_W_XFERS = 4'd4
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start_all,
    input  wire                    isa_valid,

    input  wire                    is_gemm_mode,
    input  wire                    is_residual_mode,
    input  wire                    is_gating_mode,
    input  wire                    is_norm_mode,
    input  wire                    a_on_chip,

    input  wire [ADDR_WIDTH-1:0]   op_a_addr,
    input  wire [ADDR_WIDTH-1:0]   op_b_addr,
    input  wire [ADDR_WIDTH-1:0]   op_c_addr,
    input  wire [ADDR_WIDTH-1:0]   residual_base_addr,

    input  wire [4:0]              op_a_prec,
    input  wire [4:0]              op_b_prec,
    input  wire                    op_b_fmt_explicit,
    input  wire                    w_szp_ovr,
    input  wire [1:0]              group_width,
    input  wire [6:0]              outlier_num,

    input  wire [31:0]             seq_len,
    input  wire [15:0]             hidden_dim,
    input  wire [15:0]             output_dim,
    input  wire [7:0]              batch_num,

    input  wire                    dma_arready,
    input  wire                    dma_read_done,
    input  wire                    core_compute_done,
    input  wire                    residual_load_done,

    output reg                     start_read,
    output reg  [ADDR_WIDTH-1:0]   read_init_addr,
    output reg  [7:0]              read_burst_length,

    output reg                     vec_load_start,
    output reg                     tile_last,
    output reg                     result_block_done,
    output wire                    idle_state
);

    wire [7:0] w_burst_generic = {2'b00, op_b_prec, 1'b0} + 8'd2;
    wire [7:0] w_burst_length = op_b_fmt_explicit ? w_burst_generic :
                                (op_b_prec == 4'd15) ? 8'd32 :
                                (op_b_prec == 4'd7)  ? 8'd16 :
                                (op_b_prec == 4'd3)  ? 8'd8  :
                                (op_b_prec == 4'd1)  ? 8'd4  : 8'd0;

    wire w_outlier_active = ((op_b_prec == 4'd1) || (op_b_prec == 4'd3) || w_szp_ovr)
                            && (outlier_num != 7'd0);
    wire w_outlier_fits = (w_burst_length <= 8'd16);
    wire [7:0] w_burst_eff = (w_outlier_active && w_outlier_fits) ? {w_burst_length[6:0], 1'b0} : w_burst_length;

    wire [ADDR_WIDTH-1:0] w_tile_addr_step = {w_burst_eff, 5'b0};

    wire szp_needed = ((op_b_prec == 4'd1) || (op_b_prec == 4'd3)) || w_szp_ovr;
    wire [5:0] szp_burst = (group_width == 2'b01) ? 6'd6 :
                           (group_width == 2'b10) ? 6'd3 :
                           (group_width == 2'b11) ? ((szp_needed && !is_gemm_mode && output_dim > 16'd512) ? 6'd4 : 6'd2) : 6'd2;
    wire [ADDR_WIDTH-1:0] szp_offset = szp_needed ?
        {{(ADDR_WIDTH-11){1'b0}}, szp_burst, 5'b0} : {ADDR_WIDTH{1'b0}};

    localparam [7:0]             ACT_BURST       = 8'd32;
    localparam [ADDR_WIDTH-1:0]  ACT_ADDR_STEP   = 64'd1024;
    localparam [ADDR_WIDTH-1:0]  RES_TOKEN_STEP  = 64'd32;
    localparam [4:0] A_SHIFT=$clog2(GEMM_A_XFERS); localparam [4:0] W_SHIFT=$clog2(GEMM_W_XFERS);
    localparam [4:0] W_SHIFT_S = (W_SHIFT == 5'd0) ? 5'd1 : W_SHIFT;
    localparam [3:0] TP_ACT_LAST=GEMM_A_XFERS-3'd1; localparam [3:0] TP_WT_START=GEMM_A_XFERS;
    localparam [3:0] TP_WG_LAST=GEMM_A_XFERS+GEMM_W_XFERS-3'd1;
    localparam [3:0] GATE_TILES  = GEMM_W_XFERS >> 1;
    localparam [3:0] VALUE_TILES = GEMM_W_XFERS - GATE_TILES;
    localparam [3:0] TP_WG_GATE_LAST = TP_WT_START + GATE_TILES - 4'd1;
    localparam [3:0] TP_WV_START     = TP_WT_START + GATE_TILES;
    localparam [3:0] TP_WV_LAST      = TP_WT_START + GATE_TILES + VALUE_TILES - 4'd1;
    localparam [5:0] RES_TILES_TOTAL = GEMM_A_XFERS * GEMM_W_XFERS;
    localparam       SINGLE_COL_GROUP = (GEMM_W_XFERS <= 3'd4);

    localparam integer MEM_DATA_WIDTH = 8192;
    wire [31:0] hidden_dim32   = {16'd0, hidden_dim};
    wire [9:0]  rms_tile_xfers = 10'd2 +
        10'd2 * (((hidden_dim32 << 4) + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH));

    reg [15:0] act_row_tiles;
    reg [15:0] act_col_tiles;
    reg [15:0] w_col_tiles;

    reg [15:0] act_row_groups;
    reg [15:0] w_col_groups;

    reg [31:0] total_w_tiles_gemv;

    reg [31:0] rms_read_interval;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_row_tiles    <= 16'd0;
            act_col_tiles    <= 16'd0;
            w_col_tiles      <= 16'd0;
            act_row_groups   <= 16'd0;
            w_col_groups     <= 16'd0;
            total_w_tiles_gemv <= 32'd0;
            rms_read_interval <= 32'd0;
        end else if (isa_valid) begin
            act_row_tiles    <= seq_len[22:7];
            act_col_tiles    <= hidden_dim >> 7;
            w_col_tiles      <= output_dim >> 7;
            act_row_groups   <= is_gating_mode
                                  ? ((seq_len[22:7]              == 16'd0) ? 16'd1 : seq_len[22:7])
                                  : (((seq_len[22:7] >> A_SHIFT) == 16'd0) ? 16'd1 : (seq_len[22:7] >> A_SHIFT));
            w_col_groups     <= is_gating_mode
                                  ? (((output_dim >> 7) / {12'd0, GATE_TILES}) == 16'd0 ? 16'd1
                                     : ((output_dim >> 7) / {12'd0, GATE_TILES}))
                                  : (((output_dim >> 7) >> W_SHIFT)            == 16'd0 ? 16'd1
                                     : ((output_dim >> 7) >> W_SHIFT));
            total_w_tiles_gemv <= (is_gating_mode ? 32'd2 : 32'd1)
                                  * (hidden_dim >> 7) * (output_dim >> 7);
            rms_read_interval <= (((hidden_dim >> 7) * (output_dim >> 7)) >> W_SHIFT)
                                 * ((GEMM_A_XFERS == 4'd0) ? 32'd1 : (32'd4 / {28'd0, GEMM_A_XFERS}));
        end
    end

    localparam ST_IDLE             = 5'd0;
    localparam ST_GEMM_RMS_READ   = 5'd1;
    localparam ST_GEMM_RMS_WAIT   = 5'd2;
    localparam ST_GEMM_ACT_READ   = 5'd3;
    localparam ST_GEMM_ACT_WAIT   = 5'd4;
    localparam ST_GEMM_WG_READ    = 5'd5;
    localparam ST_GEMM_WG_WAIT    = 5'd6;
    localparam ST_GEMM_WV_READ    = 5'd7;
    localparam ST_GEMM_WV_WAIT    = 5'd8;
    localparam ST_GEMM_PHASE_WAIT = 5'd9;
    localparam ST_GEMM_TILE_LAST  = 5'd10;
    localparam ST_GEMM_CD_WAIT1   = 5'd11;
    localparam ST_GEMM_CD_WAIT2   = 5'd12;
    localparam ST_GEMM_RES_READ   = 5'd13;
    localparam ST_GEMM_RES_WAIT   = 5'd14;
    localparam ST_GEMM_RES_DONE   = 5'd15;
    localparam ST_GEMV_VEC_START  = 5'd16;
    localparam ST_GEMV_W_READ     = 5'd17;
    localparam ST_GEMV_W_WAIT     = 5'd18;
    localparam ST_GAP             = 5'd19;
    localparam ST_GEMV_RMS_READ   = 5'd20;
    localparam ST_GEMV_RMS_WAIT   = 5'd21;
    localparam ST_GEMM_SZP_READ   = 5'd22;
    localparam ST_GEMM_SZP_WAIT   = 5'd23;
    localparam ST_GEMV_RES_READ   = 5'd24;
    localparam ST_GEMV_RES_WAIT   = 5'd25;
    localparam ST_GEMV_SZP_READ   = 5'd26;
    localparam ST_GEMV_SZP_WAIT   = 5'd27;
    localparam ST_GEMV_ACT_READ   = 5'd28;
    localparam ST_GEMV_ACT_WAIT   = 5'd29;

    reg [4:0] state, state_next;

    reg [15:0] phase_cnt;
    reg [3:0]  tile_in_phase;
    reg [15:0] act_row_group_idx;
    reg [15:0] w_col_group_idx;
    reg [15:0] inner_phase_idx;
    reg [31:0] rms_phase_cnt;
    reg [15:0] rms_addr_idx;
    reg [4:0]  res_tile_cnt;
    reg [7:0]  res_token_cnt;
    reg [3:0]  tile_last_cnt;
    reg [1:0]  cd_wait_cnt;
    reg [31:0] gemv_w_idx;
    reg [7:0]  gemv_grp_idx;
    reg [7:0]  gemv_out_tile;
    reg [1:0]  gap_cnt;

    reg        preload_done;
    reg [4:0]  return_state;

    wire [31:0] gemv_act_bits = {16'd0, hidden_dim} << 4;
    wire [31:0] gemv_act_words_w =
        (gemv_act_bits + MEM_DATA_WIDTH - 1) >> $clog2(MEM_DATA_WIDTH);
    wire [7:0] gemv_act_burst = gemv_act_words_w[7:0];
    wire gemv_hbm_act_bypass_supported =
        !is_gemm_mode && !a_on_chip &&
        !is_norm_mode && !is_residual_mode && !is_gating_mode &&
        (batch_num == 8'd1) &&
        (op_a_prec == 5'd15) &&
        ((op_b_prec == 5'd15) || (op_b_prec == 5'd1) || (op_b_prec == 5'd3)) &&
        (hidden_dim != 16'd0) && (hidden_dim[6:0] == 7'd0) &&
        (output_dim != 16'd0) && (output_dim[6:0] == 7'd0) &&
        (gemv_act_words_w != 32'd0) && (gemv_act_words_w <= 32'd255);

    reg [ADDR_WIDTH-1:0] cur_addr;
    reg [7:0]            cur_burst;

    wire [15:0] ffn_w_per_tensor = w_col_tiles;

    wire [15:0] act_tile_row = is_gating_mode ? act_row_group_idx
                                              : (act_row_group_idx << A_SHIFT) + tile_in_phase[1:0];
    wire [ADDR_WIDTH-1:0] act_tile_addr = op_a_addr +
        ({{(ADDR_WIDTH-32){1'b0}}, act_tile_row} * {{(ADDR_WIDTH-16){1'b0}}, act_col_tiles} +
         {{(ADDR_WIDTH-16){1'b0}}, inner_phase_idx}) * ACT_ADDR_STEP;

    wire [3:0] w_tile_offset = tile_in_phase - TP_WT_START;
    wire [15:0] w_col_group_base = is_gating_mode ? (w_col_group_idx * {12'd0, GATE_TILES})
                                                  : (w_col_group_idx << W_SHIFT);
    wire [15:0] w_tile_col = w_col_group_base + {{12{1'b0}}, w_tile_offset};
    wire [ADDR_WIDTH-1:0] w_tile_addr = op_b_addr + szp_offset +
        ({{(ADDR_WIDTH-16){1'b0}}, w_tile_col} * {{(ADDR_WIDTH-16){1'b0}}, act_col_tiles} +
         {{(ADDR_WIDTH-16){1'b0}}, inner_phase_idx}) * {{(ADDR_WIDTH-8){1'b0}}, w_tile_addr_step};

    wire [3:0]  wv_tile_offset = tile_in_phase - TP_WV_START;
    wire [15:0] wv_tile_col = w_col_group_base + {{12{1'b0}}, wv_tile_offset};
    wire [ADDR_WIDTH-1:0] gate_tensor_size = {{(ADDR_WIDTH-16){1'b0}}, ffn_w_per_tensor} *
                                              {{(ADDR_WIDTH-16){1'b0}}, act_col_tiles} *
                                              {{(ADDR_WIDTH-8){1'b0}}, w_tile_addr_step};
    wire [31:0] gemv_gate_w_tiles = {16'd0, act_col_tiles} * {16'd0, w_col_tiles};
    wire        gemv_w_is_value    = is_gating_mode && (gemv_w_idx >= gemv_gate_w_tiles);
    wire [31:0] gemv_w_rel_idx     = gemv_w_is_value ? (gemv_w_idx - gemv_gate_w_tiles) : gemv_w_idx;
    wire [8:0]  gemv_out_tiles      = output_dim[15:7];
    wire [15:0] gemv_group_stride_w = {10'b0, szp_burst} +
                                      ({7'b0, gemv_out_tiles} * {8'b0, w_burst_eff});
    wire [ADDR_WIDTH-1:0] gemv_grp_base = op_b_addr +
        (({{(ADDR_WIDTH-8){1'b0}}, gemv_grp_idx} *
          {{(ADDR_WIDTH-16){1'b0}}, gemv_group_stride_w}) << 5);
    wire [ADDR_WIDTH-1:0] gemv_w_read_addr = szp_needed ?
        (gemv_grp_base + szp_offset +
         {{(ADDR_WIDTH-8){1'b0}}, gemv_out_tile} * {{(ADDR_WIDTH-8){1'b0}}, w_tile_addr_step}) :
        (op_b_addr + szp_offset + (gemv_w_is_value ? gate_tensor_size : {ADDR_WIDTH{1'b0}}) +
         {{(ADDR_WIDTH-32){1'b0}}, gemv_w_rel_idx} * {{(ADDR_WIDTH-8){1'b0}}, w_tile_addr_step});
    wire [ADDR_WIDTH-1:0] wv_tile_addr = op_b_addr + gate_tensor_size + szp_offset +
        ({{(ADDR_WIDTH-16){1'b0}}, wv_tile_col} * {{(ADDR_WIDTH-16){1'b0}}, act_col_tiles} +
         {{(ADDR_WIDTH-16){1'b0}}, inner_phase_idx}) * {{(ADDR_WIDTH-8){1'b0}}, w_tile_addr_step};

    wire [2:0] res_grid_row = res_tile_cnt >> W_SHIFT;
    wire [2:0] res_grid_col = res_tile_cnt[W_SHIFT_S-1:0] & {3{(W_SHIFT != 5'd0)}};
    wire [ADDR_WIDTH-1:0] res_seq_tile =
        {{(ADDR_WIDTH-16){1'b0}}, act_row_group_idx} * {{(ADDR_WIDTH-4){1'b0}}, GEMM_A_XFERS}
        + {{(ADDR_WIDTH-3){1'b0}}, res_grid_row};
    wire [ADDR_WIDTH-1:0] res_col_tile =
        ({{(ADDR_WIDTH-16){1'b0}}, w_col_group_idx} << W_SHIFT)
        + {{(ADDR_WIDTH-3){1'b0}}, res_grid_col};
    wire [ADDR_WIDTH-1:0] res_tile_linear =
        res_seq_tile * {{(ADDR_WIDTH-16){1'b0}}, (output_dim >> 7)} + res_col_tile;
    wire [ADDR_WIDTH-1:0] res_tile_addr = residual_base_addr + res_tile_linear * ACT_ADDR_STEP;

    wire [3:0] tiles_per_phase = is_gating_mode ? 4'd12 : 4'd12;

    wire phase_is_last_in_group = (inner_phase_idx == act_col_tiles - 1);

    wire is_final_group = (act_row_group_idx == act_row_groups - 1) &&
                          (w_col_group_idx == w_col_groups - 1) &&
                          phase_is_last_in_group;

    assign idle_state = state == ST_IDLE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= ST_IDLE;
            phase_cnt         <= 16'd0;
            tile_in_phase     <= 4'd0;
            act_row_group_idx <= 16'd0;
            w_col_group_idx   <= 16'd0;
            inner_phase_idx   <= 16'd0;
            rms_phase_cnt     <= 32'd0;
            rms_addr_idx      <= 16'd0;
            res_tile_cnt      <= 5'd0;
            res_token_cnt     <= 8'd0;
            tile_last_cnt     <= 4'd0;
            cd_wait_cnt       <= 2'd0;
            gemv_w_idx        <= 32'd0;
            gemv_grp_idx      <= 8'd0;
            gemv_out_tile     <= 8'd0;
            gap_cnt           <= 2'd0;
            preload_done      <= 1'b0;
            return_state      <= ST_IDLE;
            start_read        <= 1'b0;
            read_init_addr    <= {ADDR_WIDTH{1'b0}};
            read_burst_length <= 8'd0;
            vec_load_start    <= 1'b0;
            tile_last         <= 1'b0;
            result_block_done <= 1'b0;
        end else begin
            vec_load_start    <= 1'b0;
            tile_last         <= 1'b0;
            result_block_done <= 1'b0;

            if (start_read && dma_arready)
                start_read <= 1'b0;

            if (isa_valid) begin
                phase_cnt         <= 16'd0;
                tile_in_phase     <= 4'd0;
                act_row_group_idx <= 16'd0;
                w_col_group_idx   <= 16'd0;
                inner_phase_idx   <= 16'd0;
                rms_phase_cnt     <= 32'd0;
                rms_addr_idx      <= 16'd0;
                res_tile_cnt      <= 5'd0;
                res_token_cnt     <= 8'd0;
                tile_last_cnt     <= 4'd0;
                cd_wait_cnt       <= 2'd0;
                gemv_w_idx        <= 32'd0;
                gap_cnt           <= 2'd0;
                preload_done      <= 1'b0;
                state             <= ST_IDLE;
            end else begin

            case (state)
                ST_IDLE: begin
                    if (start_all) begin
                        if (is_gemm_mode) begin
                            if (is_norm_mode && rms_phase_cnt == 32'd0) begin
                                state <= ST_GEMM_RMS_READ;
                            end else begin
                                state         <= ST_GEMM_ACT_READ;
                                tile_in_phase <= 4'd0;
                            end
                        end else begin
                            if (!a_on_chip) begin
                                if (gemv_hbm_act_bypass_supported) begin
                                    gemv_w_idx     <= 32'd0;
                                    gemv_grp_idx   <= 8'd0;
                                    gemv_out_tile  <= 8'd0;
                                    state          <= ST_GEMV_ACT_READ;
                                end else begin
                                    state <= ST_IDLE;
`ifndef SYNTHESIS
                                    $fatal(1,
                                        "proj_scheduler: unsupported non-resident GEMV ACT contract batch=%0d H=%0d O=%0d ap=%0d bp=%0d norm=%0b residual=%0b gating=%0b",
                                        batch_num, hidden_dim, output_dim, op_a_prec,
                                        op_b_prec, is_norm_mode, is_residual_mode,
                                        is_gating_mode);
`endif
                                end
                            end else if (is_norm_mode) begin
                                rms_addr_idx <= 16'd0;
                                state        <= ST_GEMV_RMS_READ;
                            end else begin
                                state <= ST_GEMV_VEC_START;
                            end
                        end
                    end
                end

                ST_GEMM_RMS_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= op_c_addr + ({{(ADDR_WIDTH-16){1'b0}}, rms_addr_idx} << 5);
                    read_burst_length <= 8'd1;
                    state             <= ST_GEMM_RMS_WAIT;
                end

                ST_GEMM_RMS_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (rms_addr_idx == (rms_tile_xfers >> 1) - 10'd1) begin
                            rms_addr_idx  <= 16'd0;
                            tile_in_phase <= 4'd0;
                            return_state  <= ST_GEMM_ACT_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end else begin
                            rms_addr_idx  <= rms_addr_idx + 16'd1;
                            return_state  <= ST_GEMM_RMS_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_ACT_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= act_tile_addr;
                    read_burst_length <= ACT_BURST;
                    state             <= ST_GEMM_ACT_WAIT;
                end

                ST_GEMM_ACT_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (tile_in_phase == TP_ACT_LAST) begin
                            tile_in_phase <= TP_WT_START;
                            return_state  <= szp_needed ? ST_GEMM_SZP_READ : ST_GEMM_WG_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end else begin
                            tile_in_phase <= tile_in_phase + 1;
                            return_state  <= ST_GEMM_ACT_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_SZP_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= op_b_addr;
                    read_burst_length <= {2'b0, szp_burst};
                    state             <= ST_GEMM_SZP_WAIT;
                end

                ST_GEMM_SZP_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        return_state <= ST_GEMM_WG_READ;
                        gap_cnt      <= 2'd0;
                        state        <= ST_GAP;
                    end
                end

                ST_GEMM_WG_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= w_tile_addr;
                    read_burst_length <= w_burst_eff;
                    state             <= ST_GEMM_WG_WAIT;
                end

                ST_GEMM_WG_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (is_gating_mode) begin
                            if (tile_in_phase == TP_WG_GATE_LAST) begin
                                tile_in_phase <= TP_WV_START;
                                return_state  <= ST_GEMM_WV_READ;
                                gap_cnt       <= 2'd0;
                                state         <= ST_GAP;
                            end else begin
                                tile_in_phase <= tile_in_phase + 1;
                                return_state  <= ST_GEMM_WG_READ;
                                gap_cnt       <= 2'd0;
                                state         <= ST_GAP;
                            end
                        end else begin
                            if (tile_in_phase == TP_WG_LAST) begin
                                return_state <= ST_GEMM_PHASE_WAIT;
                                gap_cnt      <= 2'd0;
                                state        <= ST_GAP;
                            end else begin
                                tile_in_phase <= tile_in_phase + 1;
                                return_state  <= ST_GEMM_WG_READ;
                                gap_cnt       <= 2'd0;
                                state         <= ST_GAP;
                            end
                        end
                    end
                end

                ST_GEMM_WV_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= wv_tile_addr;
                    read_burst_length <= w_burst_eff;
                    state             <= ST_GEMM_WV_WAIT;
                end

                ST_GEMM_WV_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (tile_in_phase == TP_WV_LAST) begin
                            return_state <= ST_GEMM_PHASE_WAIT;
                            gap_cnt      <= 2'd0;
                            state        <= ST_GAP;
                        end else begin
                            tile_in_phase <= tile_in_phase + 1;
                            return_state  <= ST_GEMM_WV_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_PHASE_WAIT: begin
                    phase_cnt       <= phase_cnt + 1;
                    rms_phase_cnt   <= rms_phase_cnt + 1;

                    if (inner_phase_idx == act_col_tiles - 1) begin
                        inner_phase_idx <= 16'd0;

                        tile_last_cnt <= 4'd0;
                        state         <= ST_GEMM_TILE_LAST;
                    end else begin
                        if (!preload_done) begin
                            inner_phase_idx <= inner_phase_idx + 1;
                            preload_done  <= 1'b1;
                            tile_in_phase <= 4'd0;
                            if (is_norm_mode && rms_phase_cnt + 1 == rms_read_interval) begin
                                rms_phase_cnt <= 32'd0;
                                state         <= ST_GEMM_RMS_READ;
                            end else begin
                                state <= ST_GEMM_ACT_READ;
                            end
                        end else begin
                            if (core_compute_done) begin
                                inner_phase_idx <= inner_phase_idx + 1;
                                tile_in_phase <= 4'd0;
                                if (is_norm_mode && rms_phase_cnt + 1 == rms_read_interval) begin
                                    rms_phase_cnt <= 32'd0;
                                    state         <= ST_GEMM_RMS_READ;
                                end else begin
                                    state <= ST_GEMM_ACT_READ;
                                end
                            end else begin
                                state <= ST_GEMM_PHASE_WAIT;
                            end
                        end
                    end
                end

                ST_GEMM_TILE_LAST: begin
                    if (tile_last_cnt == 4'd9) begin
                        tile_last     <= 1'b1;
                        tile_last_cnt <= 4'd0;

                        if (is_residual_mode) begin
                            cd_wait_cnt <= 2'd0;
                            state       <= ST_GEMM_CD_WAIT1;
                        end else begin
                            cd_wait_cnt <= 2'd0;
                            state       <= ST_GEMM_CD_WAIT1;
                        end
                    end else begin
                        tile_last_cnt <= tile_last_cnt + 1;
                    end
                end

                ST_GEMM_CD_WAIT1: begin
                    if (SINGLE_COL_GROUP && (act_col_tiles == 16'd1)) begin
                        state <= ST_GEMM_CD_WAIT2;
                    end else if (core_compute_done) begin
                        state <= ST_GEMM_CD_WAIT2;
                    end
                end

                ST_GEMM_CD_WAIT2: begin
                    if (core_compute_done) begin
                        if (is_residual_mode) begin
                            res_tile_cnt <= 5'd0;
                            state        <= ST_GEMM_RES_READ;
                        end else begin
                            result_block_done <= 1'b1;
                            if (w_col_group_idx == w_col_groups - 1) begin
                                w_col_group_idx <= 16'd0;
                                if (act_row_group_idx == act_row_groups - 1) begin
                                    state <= ST_IDLE;
                                end else begin
                                    act_row_group_idx <= act_row_group_idx + 1;
                                    preload_done  <= 1'b0;
                                    tile_in_phase <= 4'd0;
                                    if (is_norm_mode && (rms_phase_cnt >= rms_read_interval)) begin
                                        rms_phase_cnt <= 32'd0;
                                        state         <= ST_GEMM_RMS_READ;
                                    end else begin
                                        state <= ST_GEMM_ACT_READ;
                                    end
                                end
                            end else begin
                                w_col_group_idx <= w_col_group_idx + 1;
                                preload_done  <= 1'b0;
                                tile_in_phase <= 4'd0;
                                state         <= ST_GEMM_ACT_READ;
                            end
                        end
                    end
                end

                ST_GEMM_RES_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= res_tile_addr;
                    read_burst_length <= ACT_BURST;
                    state             <= ST_GEMM_RES_WAIT;
                end

                ST_GEMM_RES_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (res_tile_cnt == RES_TILES_TOTAL - 6'd1) begin
                            state <= ST_GEMM_RES_DONE;
                        end else begin
                            res_tile_cnt  <= res_tile_cnt + 1;
                            return_state  <= ST_GEMM_RES_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
                        end
                    end
                end

                ST_GEMM_RES_DONE: begin
                    if (residual_load_done) begin
                        result_block_done <= 1'b1;
                        if (w_col_group_idx == w_col_groups - 1) begin
                            w_col_group_idx <= 16'd0;
                            if (act_row_group_idx == act_row_groups - 1) begin
                                state <= ST_IDLE;
                            end else begin
                                act_row_group_idx <= act_row_group_idx + 1;
                                preload_done  <= 1'b0;
                                tile_in_phase <= 4'd0;
                                if (is_norm_mode) begin
                                    rms_phase_cnt <= 32'd0;
                                    state         <= ST_GEMM_RMS_READ;
                                end else begin
                                    state <= ST_GEMM_ACT_READ;
                                end
                            end
                        end else begin
                            w_col_group_idx <= w_col_group_idx + 1;
                            preload_done  <= 1'b0;
                            tile_in_phase <= 4'd0;
                            state         <= ST_GEMM_ACT_READ;
                        end
                    end
                end

                ST_GEMV_RMS_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= op_c_addr + ({{(ADDR_WIDTH-16){1'b0}}, rms_addr_idx} << 5);
                    read_burst_length <= 8'd1;
                    state             <= ST_GEMV_RMS_WAIT;
                end

                ST_GEMV_RMS_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (rms_addr_idx == (rms_tile_xfers >> 1) - 10'd1) begin
                            rms_addr_idx <= 16'd0;
                            gemv_w_idx   <= 32'd0;
                            gap_cnt      <= 2'd0;
                            return_state <= a_on_chip ? ST_GEMV_VEC_START : ST_GEMV_W_READ;
                            state        <= ST_GAP;
                        end else begin
                            rms_addr_idx <= rms_addr_idx + 16'd1;
                            return_state <= ST_GEMV_RMS_READ;
                            gap_cnt      <= 2'd0;
                            state        <= ST_GAP;
                        end
                    end
                end

                ST_GEMV_ACT_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= op_a_addr;
                    read_burst_length <= gemv_act_burst;
                    state             <= ST_GEMV_ACT_WAIT;
                end

                ST_GEMV_ACT_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        gemv_w_idx       <= 32'd0;
                        gemv_grp_idx     <= 8'd0;
                        gemv_out_tile    <= 8'd0;
                        return_state     <= szp_needed ? ST_GEMV_SZP_READ : ST_GEMV_W_READ;
                        gap_cnt         <= 2'd0;
                        state           <= ST_GAP;
                    end
                end

                ST_GEMV_VEC_START: begin
                    vec_load_start <= 1'b1;
                    gemv_w_idx     <= 32'd0;
                    gemv_grp_idx   <= 8'd0;
                    gemv_out_tile  <= 8'd0;
                    state          <= szp_needed ? ST_GEMV_SZP_READ : ST_GEMV_W_READ;
                end

                ST_GEMV_SZP_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= gemv_grp_base;
                    read_burst_length <= {2'b0, szp_burst};
                    state             <= ST_GEMV_SZP_WAIT;
                end

                ST_GEMV_SZP_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        return_state <= ST_GEMV_W_READ;
                        gap_cnt      <= 2'd0;
                        state        <= ST_GAP;
                    end
                end

                ST_GEMV_W_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= gemv_w_read_addr;
                    read_burst_length <= w_burst_eff;
                    state             <= ST_GEMV_W_WAIT;
                end

                ST_GEMV_W_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (gemv_w_idx == total_w_tiles_gemv - 1) begin
                            if (is_residual_mode) begin
                                res_token_cnt <= 8'd0;
                                state         <= ST_GEMV_RES_READ;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end else begin
                            gemv_w_idx   <= gemv_w_idx + 1;
                            gap_cnt      <= 2'd0;
                            state        <= ST_GAP;
                            if (szp_needed && gemv_out_tile == gemv_out_tiles[7:0] - 8'd1) begin
                                gemv_out_tile <= 8'd0;
                                gemv_grp_idx  <= gemv_grp_idx + 8'd1;
                                return_state  <= ST_GEMV_SZP_READ;
                            end else begin
                                gemv_out_tile <= gemv_out_tile + 8'd1;
                                return_state  <= ST_GEMV_W_READ;
                            end
                        end
                    end
                end

                ST_GEMV_RES_READ: begin
                    start_read        <= 1'b1;
                    read_init_addr    <= residual_base_addr +
                                         ({{(ADDR_WIDTH-8){1'b0}}, res_token_cnt} * RES_TOKEN_STEP);
                    read_burst_length <= 8'd1;
                    state             <= ST_GEMV_RES_WAIT;
                end

                ST_GEMV_RES_WAIT: begin
                    if (dma_arready) start_read <= 1'b0;
                    if (dma_read_done) begin
                        if (res_token_cnt == batch_num - 8'd1) begin
                            state <= ST_IDLE;
                        end else begin
                            res_token_cnt <= res_token_cnt + 8'd1;
                            return_state  <= ST_GEMV_RES_READ;
                            gap_cnt       <= 2'd0;
                            state         <= ST_GAP;
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

    // synopsys translate_off
    `ifdef PRERMSPROBE
    always @(posedge clk) begin
        if (rst_n && state == ST_GEMM_ACT_READ)
            $display("[SCHEDACT] t=%0t rg=%0d tp=%0d inner=%0d wcg=%0d rms_pc=%0d preload=%b act_tile_row=%0d addr=%h",
                     $time, act_row_group_idx, tile_in_phase, inner_phase_idx,
                     w_col_group_idx, rms_phase_cnt, preload_done, act_tile_row, act_tile_addr);
    end
    `endif
    // synopsys translate_on

endmodule
