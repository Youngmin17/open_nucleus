// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire
module online_rescale_unit #(
    parameter DATA_WIDTH      = 16,
    parameter MPU_OUT_WIDTH   = 24,
    parameter BLOCK_SIZE      = 128,
    parameter ADDR_W          = 9,
    parameter BUNDLE_PAIR_NUM = 4,
    parameter ROW_W           = 7,
    parameter BNK_W           = 2
)(
    input  wire                                 clk,
    input  wire                                 rst_n,
    input  wire                                 isa_valid,

    input  wire                                 alpha_vld,
    input  wire [DATA_WIDTH-1:0]                alpha_in,
    input  wire [ROW_W-1:0]                     alpha_row,
    input  wire [BNK_W-1:0]                     alpha_bank,

    input  wire                                 pv_vld,
    input  wire [MPU_OUT_WIDTH*BLOCK_SIZE-1:0]  pv_data,
    input  wire [ADDR_W-1:0]                    pv_addr,
    input  wire [ROW_W-1:0]                     pv_row,
    input  wire [BNK_W-1:0]                     pv_bank,
    input  wire                                 first_kv_blk,

    output wire                                 ren,
    output wire [ADDR_W-1:0]                    raddr,
    input  wire [DATA_WIDTH*BLOCK_SIZE-1:0]     rdata,

    output wire                                 acc_vld,
    output wire [ADDR_W-1:0]                    acc_addr,
    output wire [MPU_OUT_WIDTH*BLOCK_SIZE-1:0]  acc_data,
    output wire                                 acc_overwrite,

    output wire                                 dbg_alpha_wr,
    output wire                                 dbg_upd_fire
);
    localparam ACC_W = MPU_OUT_WIDTH * BLOCK_SIZE;

    genvar i;

    reg [DATA_WIDTH-1:0] alpha_buf [0:BUNDLE_PAIR_NUM*BLOCK_SIZE-1];
    integer a;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (a = 0; a < BUNDLE_PAIR_NUM*BLOCK_SIZE; a = a + 1)
                alpha_buf[a] <= {DATA_WIDTH{1'b0}};
        end else if (isa_valid) begin
            for (a = 0; a < BUNDLE_PAIR_NUM*BLOCK_SIZE; a = a + 1)
                alpha_buf[a] <= {DATA_WIDTH{1'b0}};
        end else if (alpha_vld) begin
            alpha_buf[{alpha_bank, alpha_row}] <= alpha_in;
        end
    end
    assign dbg_alpha_wr = alpha_vld;

    assign ren   = pv_vld && !first_kv_blk;
    assign raddr = pv_addr;

    reg                 upd_vld0, upd_vld1, upd_vld2;
    reg [ADDR_W-1:0]    upd_addr0, upd_addr1, upd_addr2;
    reg [ACC_W-1:0]     pv_pip0, pv_pip1;
    reg [DATA_WIDTH-1:0] alpha_pip0;
    reg                 first_pip0, first_pip1, first_pip2;
    reg [ACC_W-1:0]     prod_r, num_new_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            upd_vld0   <= 1'b0;
            upd_addr0  <= {ADDR_W{1'b0}};
            pv_pip0    <= {ACC_W{1'b0}};
            alpha_pip0 <= {DATA_WIDTH{1'b0}};
            first_pip0 <= 1'b0;
        end else begin
            upd_vld0 <= pv_vld;
            if (pv_vld) begin
                upd_addr0  <= pv_addr;
                pv_pip0    <= pv_data;
                alpha_pip0 <= alpha_buf[{pv_bank, pv_row}];
                first_pip0 <= first_kv_blk;
            end
        end
    end

    wire [ACC_W-1:0] prod_w;
    generate
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : G_RESCALE_MULT
            DW_fp_mult_inst #(
                .sig_width(15), .exp_width(8), .ieee_compliance(0)
            ) u_mult (
                .inst_a  ({alpha_pip0, 8'd0}),
                .inst_b  ({rdata[DATA_WIDTH*i +: DATA_WIDTH], 8'd0}),
                .inst_rnd(3'b000),
                .z_inst  (prod_w[MPU_OUT_WIDTH*i +: MPU_OUT_WIDTH]),
                .status_inst()
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            upd_vld1   <= 1'b0;
            upd_addr1  <= {ADDR_W{1'b0}};
            pv_pip1    <= {ACC_W{1'b0}};
            first_pip1 <= 1'b0;
            prod_r     <= {ACC_W{1'b0}};
        end else begin
            upd_vld1   <= upd_vld0;
            upd_addr1  <= upd_addr0;
            pv_pip1    <= pv_pip0;
            first_pip1 <= first_pip0;
            prod_r     <= prod_w;
        end
    end

    wire [ACC_W-1:0] add_w;
    generate
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : G_RESCALE_ADD
            DW_fp_add_inst #(
                .sig_width(15), .exp_width(8), .ieee_compliance(0)
            ) u_add (
                .inst_a  (prod_r[MPU_OUT_WIDTH*i +: MPU_OUT_WIDTH]),
                .inst_b  (pv_pip1[MPU_OUT_WIDTH*i +: MPU_OUT_WIDTH]),
                .inst_rnd(3'b000),
                .z_inst  (add_w[MPU_OUT_WIDTH*i +: MPU_OUT_WIDTH]),
                .status_inst()
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            upd_vld2   <= 1'b0;
            upd_addr2  <= {ADDR_W{1'b0}};
            first_pip2 <= 1'b0;
            num_new_r  <= {ACC_W{1'b0}};
        end else begin
            upd_vld2   <= upd_vld1;
            upd_addr2  <= upd_addr1;
            first_pip2 <= first_pip1;
            num_new_r  <= first_pip1 ? pv_pip1 : add_w;
        end
    end

    assign acc_vld       = upd_vld2;
    assign acc_addr      = upd_addr2;
    assign acc_data      = num_new_r;
    assign acc_overwrite = upd_vld2;
    assign dbg_upd_fire  = upd_vld2;

endmodule
`default_nettype wire
