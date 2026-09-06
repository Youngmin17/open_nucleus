// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire
module psm_online_adapter #(
    parameter MPU_OUT_WIDTH = 24,
    parameter BLOCK_SIZE    = 128
)(
    input  wire                                clk,
    input  wire                                rst_n,
    input  wire                                isa_valid,

    input  wire                                row_vld,
    input  wire [MPU_OUT_WIDTH*BLOCK_SIZE-1:0] row_data,
    input  wire                                block_start_in,
    input  wire                                flush,

    output reg                                 psm_in_vld,
    output reg  [2*MPU_OUT_WIDTH*BLOCK_SIZE-1:0] psm_d_in,
    output wire                                psm_block_start,

    output wire                                dbg_pair_out,
    output wire                                dbg_backpressure_viol
);
    localparam ROW_W = MPU_OUT_WIDTH * BLOCK_SIZE;

    reg [ROW_W-1:0] lo_latch;
    reg             lo_pending;

    reg flush_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) flush_d <= 1'b0;
        else        flush_d <= flush;
    end
    wire flush_pulse = flush && !flush_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lo_latch   <= {ROW_W{1'b0}};
            lo_pending <= 1'b0;
            psm_in_vld <= 1'b0;
            psm_d_in   <= {2*ROW_W{1'b0}};
        end else if (isa_valid || block_start_in) begin
            lo_pending <= 1'b0;
            psm_in_vld <= 1'b0;
        end else begin
            psm_in_vld <= 1'b0;
            if (row_vld) begin
                if (!lo_pending) begin
                    lo_latch   <= row_data;
                    lo_pending <= 1'b1;
                end else begin
                    psm_d_in   <= {row_data, lo_latch};
                    psm_in_vld <= 1'b1;
                    lo_pending <= 1'b0;
                end
            end else if (flush_pulse && lo_pending) begin
                psm_d_in   <= {{ROW_W{1'b0}}, lo_latch};
                psm_in_vld <= 1'b1;
                lo_pending <= 1'b0;
            end
        end
    end

    assign psm_block_start        = block_start_in;
    assign dbg_pair_out           = psm_in_vld;
    assign dbg_backpressure_viol  = psm_in_vld && row_vld && lo_pending;

endmodule
`default_nettype wire
