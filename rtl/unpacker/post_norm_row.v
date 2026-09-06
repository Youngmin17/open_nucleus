// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire
module post_norm_row
#(
    parameter DATA_WIDTH = 16,
    parameter DIM = 128,
    parameter ACT_XFERS = 2,
    parameter WT_XFERS  = 4
)
(
    input wire                        clk,
    input wire                        rst_n,
    input wire                        isa_valid,
    input wire                        is_gemm_mode,
    input wire                        post_norm_en,
    input wire                        row_in_vld,
    input wire                        rms_phase,
    input wire                        res_phase,
    input wire [6:0]                  wt_tile_xfers,
    input wire [9:0]                  num_gamma_beats,
    input wire [5:0]                  act_xfers,
    input wire [15:0]                 phases_per_sub,
    input wire [4096-1:0]             row_din,
    output wire                       post_norm_out_vld,
    output wire [4096-1:0]            post_norm_out
);

    localparam NUM_DIVIDERS = 4096 / DATA_WIDTH;
    localparam NUM_HALF     = 2048 / DATA_WIDTH;
    localparam NUM_ROWS = 4096 / (DIM*DATA_WIDTH);
    localparam RMS_BEATS = 2;
    localparam RMS_ENTRIES = RMS_BEATS * NUM_DIVIDERS;

    localparam TOTAL_XFERS = ACT_XFERS + WT_XFERS;

    localparam NUM_SUBS    = (ACT_XFERS == 0) ? 1 : (4 / ACT_XFERS);
    localparam SUB_STRIDE  = RMS_ENTRIES / NUM_SUBS;

    integer idx;
    genvar  i;

    reg [DATA_WIDTH-1:0] rms_r [0:RMS_ENTRIES-1];

    reg          gamma_wen;
    reg  [4:0]   gamma_waddr;
    reg  [4095:0] gamma_wdata;
    wire         gamma_ren;
    wire [4:0]   gamma_raddr;
    wire [4095:0] gamma_sram_rdata;
    wire         gamma_sram_rvalid;

    sram_32x4096_wrapper u_gamma_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .wen   (gamma_wen),
        .waddr (gamma_waddr),
        .wdata (gamma_wdata),
        .ren   (gamma_ren),
        .raddr (gamma_raddr),
        .rdata (gamma_sram_rdata),
        .rvalid(gamma_sram_rvalid)
    );

    reg [4096-1:0] row_din_pip;
    reg [8:0] row_cnt, row_cnt_pip;
    reg [4:0] tile_cnt, tile_cnt_pip;
    reg [7:0] batch_cnt, batch_cnt_pip;
    reg [6:0] wt_sub_cnt;
    reg [6:0] rms_phase_cnt;

    reg [3:0] rms_half_sel;
    reg [15:0] phase_cnt;

    reg [5:0] gamma_slice_idx;

    reg [4:0] gamma_beat_cnt;

    reg act_in_vld_pip;
    reg wt_in_vld_pip;
    reg post_norm_en_d1, post_norm_en_d2;
    reg gamma_half_sel_pip;
    reg is_gemm_mode_pip;
    reg is_gemm_mode_d2;
    reg [3:0] rms_half_sel_pip;

    wire in_wt_phase       = !(tile_cnt < act_xfers);
    wire wt_short_mode     = in_wt_phase && (wt_tile_xfers != 7'd0);
    wire wt_short_tile_end = wt_short_mode && (wt_sub_cnt == wt_tile_xfers - 7'd1);
    wire [5:0] gamma_slice_max_m1 = {num_gamma_beats[4:0], 1'b0} - 6'd1;

    assign gamma_ren   = row_in_vld && !rms_phase && !res_phase
                         && (is_gemm_mode ? (tile_cnt < act_xfers) : 1'b1);
    assign gamma_raddr = is_gemm_mode ? gamma_slice_idx[5:1] : gamma_beat_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < RMS_ENTRIES; idx = idx + 1) begin
                rms_r[idx] <= {DATA_WIDTH{1'b0}};
            end
            row_cnt          <= 9'd0;
            row_cnt_pip      <= 9'd0;
            tile_cnt         <= 5'd0;
            tile_cnt_pip     <= 5'd0;
            batch_cnt          <= 8'd0;
            batch_cnt_pip      <= 8'd0;
            row_din_pip      <= {4096{1'b0}};
            act_in_vld_pip   <= 1'b0;
            wt_in_vld_pip    <= 1'b0;
            post_norm_en_d1 <= 1'b0;
            post_norm_en_d2 <= 1'b0;
            rms_phase_cnt    <= 7'd0;
            wt_sub_cnt       <= 7'd0;
            gamma_slice_idx  <= 6'd0;
            gamma_beat_cnt   <= 5'd0;
            gamma_half_sel_pip <= 1'b0;
            is_gemm_mode_pip   <= 1'b0;
            is_gemm_mode_d2    <= 1'b0;
            rms_half_sel_pip   <= 4'd0;
            rms_half_sel       <= 4'd0;
            phase_cnt          <= 16'd0;
            gamma_wen        <= 1'b0;
            gamma_waddr      <= 5'd0;
            gamma_wdata      <= {4096{1'b0}};

        end else begin
            row_cnt_pip       <= row_cnt;
            tile_cnt_pip      <= tile_cnt;
            batch_cnt_pip     <= batch_cnt;
            act_in_vld_pip    <= row_in_vld && !rms_phase && !res_phase
                                 && (is_gemm_mode ? (tile_cnt < act_xfers) : 1'b1);
            wt_in_vld_pip     <= row_in_vld && !rms_phase
                                 && ( res_phase
                                      || (is_gemm_mode && !(tile_cnt < act_xfers)) );
            post_norm_en_d1  <= post_norm_en;
            post_norm_en_d2  <= post_norm_en_d1;
            gamma_half_sel_pip<= gamma_slice_idx[0];
            is_gemm_mode_pip  <= is_gemm_mode;
            is_gemm_mode_d2   <= is_gemm_mode_pip;
            rms_half_sel_pip  <= rms_half_sel;

            gamma_wen         <= 1'b0;

            if(isa_valid) begin
                row_cnt         <= 9'd0;
                tile_cnt        <= 5'd0;
                rms_phase_cnt   <= 7'd0;
                wt_sub_cnt      <= 7'd0;
                gamma_slice_idx <= 6'd0;
                gamma_beat_cnt  <= 5'd0;
                rms_half_sel    <= 4'd0;
                phase_cnt       <= 16'd0;
                for (idx = 0; idx < RMS_ENTRIES; idx = idx + 1) begin
                    rms_r[idx] <= {DATA_WIDTH{1'b0}};
                end
            end

            if (row_in_vld && !rms_phase && !res_phase
                && (tile_cnt == (TOTAL_XFERS - 1))
                && ( (wt_short_mode && wt_short_tile_end)
                  || (!wt_short_mode && (row_cnt == (DIM - NUM_ROWS))) )) begin
                phase_cnt <= phase_cnt + 16'd1;
                if (phase_cnt == (phases_per_sub - 16'd1)) begin
                    phase_cnt <= 16'd0;
                    if (rms_half_sel == (NUM_SUBS - 1))
                        rms_half_sel <= 4'd0;
                    else
                        rms_half_sel <= rms_half_sel + 4'd1;
                end
            end

            if(row_in_vld && rms_phase) begin
                row_din_pip <= {4096{1'b0}};
                row_cnt     <= 9'd0;
                wt_sub_cnt  <= 7'd0;
                rms_phase_cnt <= rms_phase_cnt + 7'd1;
                if (rms_phase_cnt < 7'd2) begin
                    for (idx = 0; idx < 256; idx = idx + 1) begin
                        rms_r[idx + (rms_phase_cnt[0] << 8)] <= row_din[DATA_WIDTH*idx +: DATA_WIDTH];
                    end
                end else begin
                    gamma_wen   <= 1'b1;
                    gamma_waddr <= rms_phase_cnt[4:0] - 5'd2;
                    gamma_wdata <= row_din;
                end
                if (rms_phase_cnt == (10'd2 + num_gamma_beats - 10'd1)) begin
                    rms_phase_cnt   <= 7'd0;
                    gamma_slice_idx <= 6'd0;
                    gamma_beat_cnt  <= 5'd0;
                end

            end else if(row_in_vld && res_phase) begin
                row_din_pip <= row_din;

            end else if(row_in_vld && is_gemm_mode) begin
                row_din_pip <= row_din;
                if (wt_short_mode) begin
                    wt_sub_cnt <= wt_sub_cnt + 7'd1;
                    if (wt_short_tile_end) begin
                        wt_sub_cnt <= 7'd0;
                        tile_cnt   <= tile_cnt + 1;
                        if(tile_cnt == (TOTAL_XFERS - 1)) begin
                            tile_cnt <= 5'd0;
                            if (gamma_slice_idx == gamma_slice_max_m1)
                                gamma_slice_idx <= 6'd0;
                            else
                                gamma_slice_idx <= gamma_slice_idx + 6'd1;
                        end
                    end
                end else begin
                    row_cnt <= row_cnt + NUM_ROWS;
                    if(row_cnt == (DIM - NUM_ROWS)) begin
                        row_cnt  <= 9'd0;
                        tile_cnt <= tile_cnt + 1;
                        if(tile_cnt == (TOTAL_XFERS - 1)) begin
                            tile_cnt <= 5'd0;
                            if (gamma_slice_idx == gamma_slice_max_m1)
                                gamma_slice_idx <= 6'd0;
                            else
                                gamma_slice_idx <= gamma_slice_idx + 6'd1;
                        end
                    end
                end

            end else if(row_in_vld && !is_gemm_mode) begin
                row_din_pip <= row_din;
                if (gamma_beat_cnt == (num_gamma_beats[4:0] - 5'd1)) begin
                    gamma_beat_cnt <= 5'd0;
                    batch_cnt <= batch_cnt + 1;
                end else begin
                    gamma_beat_cnt <= gamma_beat_cnt + 5'd1;
                end
            end
        end
    end

    wire [4096-1:0] div_out_w;
    wire [9:0] sub_off       = {6'd0, rms_half_sel_pip} * SUB_STRIDE[9:0];
    wire [9:0] tile_off      = {2'd0, DIM[7:0]} * {8'd0, tile_cnt_pip[1:0]};
    wire [9:0] rms_idx_base  = sub_off + tile_off + {2'd0, row_cnt_pip[7:0]};
    generate
    for (i = 0; i < NUM_DIVIDERS; i = i + 1)
    begin: POST_NORM_DIV
        wire [DATA_WIDTH-1:0] rms_value =
            !is_gemm_mode_pip ? rms_r[batch_cnt_pip] :
            (i < NUM_DIVIDERS/2) ? rms_r[rms_idx_base] : rms_r[rms_idx_base + 10'd1];
        wire [DATA_WIDTH-1:0] denom =
                        rms_value == {DATA_WIDTH{1'b0}} ? 16'h3F80 :
                        post_norm_en_d1 ? rms_value : 16'h3F80;
        DW_fp_div_inst #(
            .sig_width(7),
            .exp_width(8),
            .ieee_compliance(1)
        ) u_DW_fp_div_inst (
            .inst_a(row_din_pip[DATA_WIDTH*i+:DATA_WIDTH]),
            .inst_b(denom),
            .inst_rnd(3'b000),
            .z_inst(div_out_w[DATA_WIDTH*i+:DATA_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    reg [4096-1:0] div_out_r;
    reg [4096-1:0] wt_data_d2;
    reg            act_vld_d2;
    reg            wt_vld_d2;
    reg [4095:0]   gamma_data_d2;
    reg            gamma_half_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_out_r     <= {4096{1'b0}};
            wt_data_d2    <= {4096{1'b0}};
            act_vld_d2    <= 1'b0;
            wt_vld_d2     <= 1'b0;
            gamma_data_d2 <= {4096{1'b0}};
            gamma_half_d2 <= 1'b0;
        end else begin
            div_out_r     <= div_out_w;
            wt_data_d2    <= row_din_pip;
            act_vld_d2    <= act_in_vld_pip;
            wt_vld_d2     <= wt_in_vld_pip;
            gamma_data_d2 <= gamma_sram_rdata;
            gamma_half_d2 <= gamma_half_sel_pip;
        end
    end

    // synopsys translate_off
    `ifdef PRERMSPROBE
    always @(posedge clk) begin
        if (rst_n && act_in_vld_pip && is_gemm_mode_pip) begin
            $display("[PNPROBE] t=%0t tile=%0d half=%0d row=%0d base=%0d en1=%b rmsB=%h rmsB1=%h rms0=%h rms64=%h rms128=%h rms192=%h rms256=%h rms384=%h din=%h",
                $time, tile_cnt_pip, rms_half_sel_pip, row_cnt_pip, rms_idx_base,
                post_norm_en_d1, rms_r[rms_idx_base], rms_r[rms_idx_base+10'd1],
                rms_r[10'd0], rms_r[10'd64], rms_r[10'd128], rms_r[10'd192],
                rms_r[10'd256], rms_r[10'd384],
                row_din_pip[15:0]);
            if (row_cnt_pip < 8'd4)
              $display("[PNLANE] tile=%0d row=%0d | din[0:15]=%h | divout[0:15]=%h | din[120:135]=%h | divout[120:135]=%h",
                tile_cnt_pip, row_cnt_pip,
                row_din_pip[16*16-1:0], div_out_w[16*16-1:0],
                row_din_pip[136*16-1:120*16], div_out_w[136*16-1:120*16]);
        end
    end
    `endif
    // synopsys translate_on

    wire [2047:0]   gamma_half_w  = gamma_half_d2 ? gamma_data_d2[4095:2048]
                                                  : gamma_data_d2[2047:0];
    wire [4095:0]   gamma_full_w  = !post_norm_en_d2 ? {256{16'h3F80}} :
                                    is_gemm_mode_d2 ? {gamma_half_w, gamma_half_w}
                                                    : gamma_data_d2;
    wire [4096-1:0] mult_out_w;
    generate
    for (i = 0; i < NUM_DIVIDERS; i = i + 1)
    begin: POST_NORM_MULT
        DW_fp_mult_inst #(
            .sig_width(7),
            .exp_width(8),
            .ieee_compliance(1)
        ) u_DW_fp_mult_inst (
            .inst_a(div_out_r[DATA_WIDTH*i +: DATA_WIDTH]),
            .inst_b(gamma_full_w[DATA_WIDTH*i +: DATA_WIDTH]),
            .inst_rnd(3'b000),
            .z_inst(mult_out_w[DATA_WIDTH*i +: DATA_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    reg [4096-1:0] mult_out_r;
    reg [4096-1:0] wt_data_d3;
    reg            act_vld_d3;
    reg            wt_vld_d3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_out_r <= {4096{1'b0}};
            wt_data_d3 <= {4096{1'b0}};
            act_vld_d3 <= 1'b0;
            wt_vld_d3  <= 1'b0;
        end else begin
            mult_out_r <= mult_out_w;
            wt_data_d3 <= wt_data_d2;
            act_vld_d3 <= act_vld_d2;
            wt_vld_d3  <= wt_vld_d2;
        end
    end

    assign post_norm_out_vld = act_vld_d3 || wt_vld_d3;
    assign post_norm_out     = act_vld_d3 ? mult_out_r :
                               wt_vld_d3  ? wt_data_d3 : {4096{1'b0}};

endmodule

`default_nettype wire

