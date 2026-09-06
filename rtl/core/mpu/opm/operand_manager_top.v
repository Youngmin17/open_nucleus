// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire

module operand_manager_top # (
    parameter HBM_CHANNELS = 32,
    parameter HBM_DATA_WIDTH = 256,
    parameter AXI_CHNL = 128,
    parameter AXI_DATA_WIDTH = 16,
    parameter BLOCK_ROW = 128,
    parameter LANE = 64,
    parameter DOUT_BANDWIDTH = 8192,
    parameter BUNDLE_PAIR_NUM = 4
)
(
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire compute_start,
    input wire compute_stop,
    input wire [7:0] batch_num,
    input wire [6:0] kv_head_num,
    input wire [1:0] opm_mode,

    input wire                               is_gemm_mode,
    input wire                               is_residual_mode,
    input wire                               is_proj_mode,
    input wire                               a_in_vld,
    input wire                               b_in_vld,
    input wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] a_in,
    input wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] b_in,

    output wire op_a_out_vld,
    output wire op_b_out_vld,
    output wire [DOUT_BANDWIDTH-1:0] op_a_out,
    output wire [DOUT_BANDWIDTH-1:0] op_b_out,

    output wire load_done_A,
    output wire generate_done_A,
    output wire load_done_B,
    output wire generate_done_B,
    output wire a_new_row,
    output wire [5:0] a_row_num,
    output wire [1:0] b_group_num
);

    wire a_stall, b_stall, stall;
    assign stall = a_stall || b_stall;

    wire gqa_b_pending;
    reg [1:0] gqa_restart_sr;
    reg [6:0] gqa_restart_cnt;
    wire [6:0] gqa_head_max = (kv_head_num == 7'd0) ? 7'd0 : (kv_head_num - 7'd1);
    wire gqa_restart_fire = compute_stop && !is_proj_mode && !is_gemm_mode
                            && gqa_b_pending && (gqa_restart_cnt < gqa_head_max);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gqa_restart_sr  <= 2'b00;
            gqa_restart_cnt <= 7'd0;
        end else if (isa_valid) begin
            gqa_restart_sr  <= 2'b00;
            gqa_restart_cnt <= 7'd0;
        end else begin
            gqa_restart_sr <= {gqa_restart_sr[0], gqa_restart_fire};
            if (gqa_restart_fire) gqa_restart_cnt <= gqa_restart_cnt + 7'd1;
        end
    end
    wire compute_start_eff = compute_start | gqa_restart_sr[1];

    wire gqa_rd_adv;

    pingpong_buffer_a #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_CHNL(AXI_CHNL),
        .DOUT_BANDWIDTH(DOUT_BANDWIDTH),
        .LANE(LANE),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM)
    ) u_pingpong_buffer_a (
        .clk           (clk),
        .rst_n         (rst_n),
        .isa_valid     (isa_valid),
        .opm_mode      (opm_mode),
        .compute_start (compute_start_eff),
        .compute_stop  (compute_stop),
        .batch_num     (batch_num),
        .stall         (stall),
        .is_proj_mode  (is_proj_mode),
        .is_gemm_mode  (is_gemm_mode),
        .is_residual_mode(is_residual_mode),
        .up_vld        (a_in_vld),
        .up_dat        (a_in),
        .gqa_b_adv     (gqa_rd_adv),
        .dn_vld        (op_a_out_vld),
        .dn_dat        (op_a_out),
        .load_done     (load_done_A),
        .generate_done (generate_done_A),
        .a_row_num     (a_row_num),
        .a_new_row     (a_new_row),
        .a_stall       (a_stall)
    );

    pingpong_buffer_b #(
        .HBM_CHANNELS(HBM_CHANNELS),
        .HBM_DATA_WIDTH(HBM_DATA_WIDTH),
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_CHNL(AXI_CHNL),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM)
    ) u_pingpong_buffer_b (
        .clk           (clk),
        .rst_n         (rst_n),
        .isa_valid     (isa_valid),
        .compute_start (compute_start_eff),
        .compute_stop  (compute_stop),
        .stall         (stall),
        .is_proj_mode  (is_proj_mode),
        .is_gemm_mode  (is_gemm_mode),
        .is_residual_mode(is_residual_mode),
        .opm_mode      (opm_mode),
        .a_row_num     (a_row_num),
        .up_dat        (b_in),
        .up_vld        (b_in_vld),
        .dn_dat        (op_b_out),
        .dn_vld        (op_b_out_vld),
        .group_num     (b_group_num),
        .load_done     (load_done_B),
        .generate_done (generate_done_B),
        .b_stall       (b_stall),
        .gqa_b_pending (gqa_b_pending),
        .gqa_rd_adv    (gqa_rd_adv)
    );

endmodule
