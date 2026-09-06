// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module mpu_top #(
    parameter CORE_ID         = 0,
    parameter HBM_CHANNELS    = 32,
    parameter HBM_DATA_WIDTH  = 256,
    parameter AXI_CHNL        = 128,
    parameter BLOCK_ROW       = 128,
    parameter DATA_WIDTH      = 16,
    parameter FMAT_OUT_WIDTH  = 24,
    parameter SCALE_WIDTH     = 16,
    parameter SCALE_ADD_WIDTH = 16,
    parameter MULT_DIMENSION  = 32,
    parameter FMAT_SCALE_WIDTH = 8,
    parameter LANE            = 64,
    parameter BUNDLE_PAIR_NUM = 4
) (
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire is_residual_mode,
    input wire is_gemm_mode,
    input wire is_proj_mode,

    input wire [1:0] group_width,
    input wire [7:0] batch_num,
    input wire [2:0] effective_q_head_num,
    input wire [6:0] kv_head_num,
    input wire [1:0] opm_mode,
    input wire opm_compute_start,
    input wire opm_compute_stop,

    input wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] a_in,
    input wire a_in_vld,

    input wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] b_in,
    input wire b_in_vld,

    input wire scale_zp_in_vld,
    input wire [1024-1:0] scale_in,
    input wire [2048-1:0] zp_in,

    output wire load_done_A,
    output wire generate_done_A,
    output wire load_done_B,
    output wire generate_done_B,
    output wire [5:0] a_row_num,

    output reg out_vld,
    output reg [AXI_CHNL*FMAT_OUT_WIDTH-1:0] d_out,
    output reg block_done
);
    localparam OPM_BANDWIDTH = 8192;
    localparam SCALE_ZP_DATAWIDTH = 4096;
    localparam FMAT_CLUSTER = 4;
    localparam FMAT_LANE = 16;
    localparam LOOP_NUM = 4;

    wire op_a_out_vld;
    wire op_b_out_vld;
    wire [OPM_BANDWIDTH-1:0] op_a_out;
    wire [OPM_BANDWIDTH-1:0] op_b_out;
    wire a_new_row;
    wire [1:0] b_group_num;

    operand_manager_top #(
        .HBM_CHANNELS(HBM_CHANNELS),
        .HBM_DATA_WIDTH(HBM_DATA_WIDTH),
        .AXI_CHNL(AXI_CHNL),
        .BLOCK_ROW(BLOCK_ROW),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .LANE(LANE),
        .DOUT_BANDWIDTH(OPM_BANDWIDTH),
        .BUNDLE_PAIR_NUM(BUNDLE_PAIR_NUM)
    ) u_operand_manager_top (
        .clk(clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .compute_start(opm_compute_start),
        .compute_stop(opm_compute_stop),
        .batch_num(batch_num),
        .kv_head_num(kv_head_num),
        .opm_mode(opm_mode),
        .is_gemm_mode(is_gemm_mode),
        .is_residual_mode(is_residual_mode),
        .is_proj_mode(is_proj_mode),
        .a_in(a_in),
        .a_in_vld(a_in_vld),
        .b_in(b_in),
        .b_in_vld(b_in_vld),
        .op_a_out_vld(op_a_out_vld),
        .op_b_out_vld(op_b_out_vld),
        .op_a_out(op_a_out),
        .op_b_out(op_b_out),
        .load_done_A(load_done_A),
        .generate_done_A(generate_done_A),
        .load_done_B(load_done_B),
        .generate_done_B(generate_done_B),
        .a_row_num(a_row_num),
        .a_new_row(a_new_row),
        .b_group_num(b_group_num)
    );

    wire [AXI_CHNL*FMAT_SCALE_WIDTH-1:0] exp_scale;
    wire [LANE-1:0]                      fmat_in_vld;
    wire [LANE-1:0]                      fmat_out_vld;
    wire [LANE*FMAT_OUT_WIDTH-1:0]       fmat_d_out;
    wire                                 fmat_vtr_in_vld;

    assign fmat_in_vld = {LANE{op_a_out_vld && op_b_out_vld }};

    reg [11:0] fmat_vld_cnt;
    wire [11:0] total_compute_cycles =
        (opm_mode == 2'b01) ? (a_row_num << 5) :
        (opm_mode == 2'b10) ? (a_row_num << 4) :
        (opm_mode == 2'b11) ? (a_row_num << 3) :
        12'd0;

    always @(posedge clk) begin
        if (!rst_n) begin
            fmat_vld_cnt <= 12'd0;
        end else if (isa_valid) begin
            fmat_vld_cnt <= 12'd0;
        end else begin
            if (op_a_out_vld && op_b_out_vld ) begin
                fmat_vld_cnt <= fmat_vld_cnt + 1'b1;
                if(fmat_vld_cnt == total_compute_cycles - 1) begin
                    fmat_vld_cnt <= 12'd0;
                end
            end
        end
    end

    wire [SCALE_ZP_DATAWIDTH-1:0] fmat_scale_out;
    wire [SCALE_ZP_DATAWIDTH*2-1:0] fmat_zp_out;

    wire scale_zp_buf_change;
    assign scale_zp_buf_change = (fmat_vld_cnt == total_compute_cycles - 1) && (op_a_out_vld && op_b_out_vld );

    wire zp_read_valid;

    scale_zp_register #(
        .AXI_CHNL(AXI_CHNL),
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_WIDTH_IN(SCALE_ZP_DATAWIDTH),
        .DATA_WIDTH_OUT(SCALE_ZP_DATAWIDTH)
    ) u_scale_zp_register (
        .clk(clk),
        .rst_n(rst_n),
        .isa_valid(isa_valid),
        .group_width(group_width),
        .buf_change(scale_zp_buf_change),
        .in_vld(scale_zp_in_vld),
        .scale_din(scale_in),
        .zp_din(zp_in),
        .scale_dout(fmat_scale_out),
        .zp_dout(fmat_zp_out),
        .zp_read_valid(zp_read_valid)
    );

`ifdef PERCOL_ZP
    reg [16*AXI_CHNL-1:0] fmat_zp_col_lat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) fmat_zp_col_lat <= {16*AXI_CHNL{1'b0}};
        else if (zp_read_valid && fmat_vld_cnt != total_compute_cycles - 1)
            fmat_zp_col_lat <= fmat_zp_out[16*AXI_CHNL-1:0];
    end
`endif

`ifdef PERCOL_SCALE
// synopsys translate_off
    reg        pks_probe_en;
    reg [15:0] pks_probe_cnt;
    initial begin
        pks_probe_en  = $test$plusargs("PKSPROBE");
        pks_probe_cnt = 16'd0;
    end
    always @(posedge clk) begin
        if (pks_probe_en && rst_n && (opm_mode == 2'b11) && op_a_out_vld && op_b_out_vld
            && (pks_probe_cnt < 16'd32)) begin
            pks_probe_cnt <= pks_probe_cnt + 16'd1;
            $display("[PKSCALE] %m beat=%0d gw=%0d bgn=%0d col=%0d s0=%h s1=%h s2=%h s3=%h",
                     fmat_vld_cnt, group_width, b_group_num, 16*fmat_vld_cnt[2:0],
                     fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*0
                                    + FMAT_SCALE_WIDTH*(16*fmat_vld_cnt[2:0]) +: FMAT_SCALE_WIDTH],
                     fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*1
                                    + FMAT_SCALE_WIDTH*(16*fmat_vld_cnt[2:0]) +: FMAT_SCALE_WIDTH],
                     fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*2
                                    + FMAT_SCALE_WIDTH*(16*fmat_vld_cnt[2:0]) +: FMAT_SCALE_WIDTH],
                     fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*3
                                    + FMAT_SCALE_WIDTH*(16*fmat_vld_cnt[2:0]) +: FMAT_SCALE_WIDTH]);
        end
    end
// synopsys translate_on
`endif

    wire [4*OPM_BANDWIDTH-1:0] a_dup_prec16;
    wire [2*OPM_BANDWIDTH-1:0] a_dup_prec8;
    wire [SCALE_ZP_DATAWIDTH*2-1:0] fmat_scale_dup_prec8;

    genvar i;

    generate
        for(i=0; i<AXI_CHNL*4; i=i+1)
        begin : PREC16_DUPLICATE
            assign a_dup_prec16[DATA_WIDTH*4*i+:DATA_WIDTH*4] = {op_a_out[DATA_WIDTH*i+:DATA_WIDTH], {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b0}}};
        end
    endgenerate

    generate
        for(i=0; i<AXI_CHNL*2; i=i+1)
        begin : PREC8_DUPLICATE
            assign a_dup_prec8[DATA_WIDTH*4*i+:DATA_WIDTH*4] = {{DATA_WIDTH{1'b0}},  op_a_out[DATA_WIDTH*2*i+DATA_WIDTH+:DATA_WIDTH], {DATA_WIDTH{1'b0}}, op_a_out[DATA_WIDTH*2*i+:DATA_WIDTH]};
        end
    endgenerate

    generate
        for(i=0; i<AXI_CHNL*4; i=i+1)
        begin : SCALE_PREC8_DUPLICATE
            localparam integer SRC_IDX = (i / AXI_CHNL) * AXI_CHNL + (AXI_CHNL - 1 - (i % AXI_CHNL));
            assign fmat_scale_dup_prec8[FMAT_SCALE_WIDTH*2*i+:FMAT_SCALE_WIDTH*2] = {{FMAT_SCALE_WIDTH{1'b0}}, fmat_scale_out[FMAT_SCALE_WIDTH*i+:FMAT_SCALE_WIDTH]};
        end
    endgenerate

    generate
        for (i=0; i<LANE; i=i+1)
        begin : FMAT_64

            wire [4*DATA_WIDTH*MULT_DIMENSION-1:0] fmat_a_in_per_fmat =
                (opm_mode == 2'b01) ?
                    (i[5:4] == 2'b00 ?   (i[1:0] == 2'b00 ? a_dup_prec16[0*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b01 ? a_dup_prec16[4*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b10 ? a_dup_prec16[8*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        a_dup_prec16[12*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b01 ?   (i[1:0] == 2'b00 ? a_dup_prec16[16*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b01 ? a_dup_prec16[20*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b10 ? a_dup_prec16[24*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        a_dup_prec16[28*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b10 ?   (i[1:0] == 2'b00 ? a_dup_prec16[32*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b01 ? a_dup_prec16[36*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b10 ? a_dup_prec16[40*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        a_dup_prec16[44*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                                        (i[1:0] == 2'b00 ? a_dup_prec16[48*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b01 ? a_dup_prec16[52*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        i[1:0] == 2'b10 ? a_dup_prec16[56*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                        a_dup_prec16[60*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION])) :

                (opm_mode == 2'b10) ?
                    (i[5:4] == 2'b00 ?   (i[0] ? a_dup_prec8[4*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                                a_dup_prec8[0*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b01 ?   (i[0] ? a_dup_prec8[12*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                                a_dup_prec8[8*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b10 ?   (i[0] ? a_dup_prec8[20*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                                a_dup_prec8[16*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                                        (i[0] ? a_dup_prec8[28*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION] :
                                                a_dup_prec8[24*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) ) :

                    (i[5:4] == 2'b00 ?  (op_a_out[0*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b01 ?   (op_a_out[4*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                    i[5:4] == 2'b10 ?   (op_a_out[8*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION]) :
                                        (op_a_out[12*DATA_WIDTH*MULT_DIMENSION +: 4*DATA_WIDTH*MULT_DIMENSION])) ;

`ifdef PERCOL_SCALE
            wire [6:0] pks_col = 16*fmat_vld_cnt[2:0] + i[3:0];
            wire [FMAT_SCALE_WIDTH-1:0] pks_s0 =
                fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*0 + FMAT_SCALE_WIDTH*pks_col +: FMAT_SCALE_WIDTH];
            wire [FMAT_SCALE_WIDTH-1:0] pks_s1 =
                fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*1 + FMAT_SCALE_WIDTH*pks_col +: FMAT_SCALE_WIDTH];
            wire [FMAT_SCALE_WIDTH-1:0] pks_s2 =
                fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*2 + FMAT_SCALE_WIDTH*pks_col +: FMAT_SCALE_WIDTH];
            wire [FMAT_SCALE_WIDTH-1:0] pks_s3 =
                fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*3 + FMAT_SCALE_WIDTH*pks_col +: FMAT_SCALE_WIDTH];
            wire [4*FMAT_SCALE_WIDTH*MULT_DIMENSION-1:0] pks_scale_vec =
                { {MULT_DIMENSION{pks_s3}}, {MULT_DIMENSION{pks_s2}},
                  {MULT_DIMENSION{pks_s1}}, {MULT_DIMENSION{pks_s0}} };
`endif

            wire [4*FMAT_SCALE_WIDTH*MULT_DIMENSION-1:0] scale_in_per_fmat =
`ifdef PERCOL_SCALE
                (opm_mode == 2'b10) ?
                {(4*MULT_DIMENSION){fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*b_group_num + FMAT_SCALE_WIDTH*(8*fmat_vld_cnt[3:0] + i[3:1]) +: FMAT_SCALE_WIDTH]}} :
                (opm_mode == 2'b11) ?
                pks_scale_vec :
                {4*MULT_DIMENSION{8'h7F}};
`else
                (opm_mode == 2'b10) ?
                fmat_scale_dup_prec8[((SCALE_ZP_DATAWIDTH/2)*b_group_num+4*FMAT_SCALE_WIDTH*MULT_DIMENSION*i[0]) +: 4*FMAT_SCALE_WIDTH*MULT_DIMENSION] :
                (opm_mode == 2'b11) ?
                fmat_scale_out[4*FMAT_SCALE_WIDTH*MULT_DIMENSION*b_group_num +: 4*FMAT_SCALE_WIDTH*MULT_DIMENSION] :
                {4*MULT_DIMENSION{8'h7F}};
`endif

            fmat_top #(
                .DATA_WIDTH(DATA_WIDTH),
                .OUT_WIDTH (FMAT_OUT_WIDTH),
                .DATA_NUM (AXI_CHNL),
                .MULT_DIMENSION(MULT_DIMENSION),
                .SCALE_FACTOR(FMAT_SCALE_WIDTH)
            ) u_fmat_top (
                .clk(clk),
                .rst_n(rst_n),
                .a_vld(fmat_in_vld[i]),
                .b_vld(fmat_in_vld[i]),
                .scale_vld(fmat_in_vld[i]),
                .mode(opm_mode),
                .a_in(fmat_a_in_per_fmat),
                .b_in(op_b_out[DATA_WIDTH*MULT_DIMENSION*(i[3:0])+:DATA_WIDTH*MULT_DIMENSION]),
                .scale_in(scale_in_per_fmat),
                .out_vld(fmat_out_vld[i]),
                .d_out(fmat_d_out[FMAT_OUT_WIDTH*i+:FMAT_OUT_WIDTH])
            );
        end
    endgenerate

    reg [16*FMAT_OUT_WIDTH-1:0] fmat_top_zp_result_reg;
    reg [4:0] fmat_top_zp_in_cnt, fmat_top_zp_out_cnt;

    wire [4:0] zp_io_cycle_num = (opm_mode == 2'b11) ? 5'd8 :
                                 (opm_mode == 2'b10) ? 5'd16 :
                                 5'd0;

`ifdef PERCOL_ZP
    wire fmat_top_zp_in_vld = (opm_mode >= 2'b10 && opm_mode <= 2'b11) ? ((a_new_row || fmat_top_zp_in_cnt != 5'd0) && op_a_out_vld && op_b_out_vld) : 1'b0;
`else
    wire fmat_top_zp_in_vld = (opm_mode >= 2'b10 && opm_mode <= 2'b11) ? (a_new_row || fmat_top_zp_in_cnt != 5'd0) : 1'b0;
`endif
    wire [1:0] fmat_top_zp_out_vld;
    wire [FMAT_OUT_WIDTH-1:0] fmat_top_zp_d_out [0:1];

    wire fmat_top_zp_done = &fmat_top_zp_out_vld && (fmat_top_zp_out_cnt == (zp_io_cycle_num - 1));
    wire [16*FMAT_OUT_WIDTH-1:0] fmat_top_zp_result = {fmat_top_zp_d_out[1], fmat_top_zp_result_reg[8*FMAT_OUT_WIDTH+:7*FMAT_OUT_WIDTH], fmat_top_zp_d_out[0], fmat_top_zp_result_reg[0+:7*FMAT_OUT_WIDTH]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fmat_top_zp_in_cnt <= 5'd0;
            fmat_top_zp_out_cnt <= 5'd0;
            fmat_top_zp_result_reg <= {16*FMAT_OUT_WIDTH{1'b0}};
        end
        else if (isa_valid) begin
            fmat_top_zp_in_cnt <= 5'd0;
            fmat_top_zp_out_cnt <= 5'd0;
            fmat_top_zp_result_reg <= {16*FMAT_OUT_WIDTH{1'b0}};
        end
        else begin
`ifdef PERCOL_ZP
            if(fmat_top_zp_in_cnt > 0 && op_a_out_vld && op_b_out_vld) begin
`else
            if(fmat_top_zp_in_cnt > 0) begin
`endif
                fmat_top_zp_in_cnt <= fmat_top_zp_in_cnt + 5'd1;
                if(fmat_top_zp_in_cnt == (zp_io_cycle_num - 1)) begin
                    fmat_top_zp_in_cnt <= 5'd0;
                end
            end
            if(fmat_top_zp_in_vld && a_new_row) begin
                fmat_top_zp_in_cnt <= 5'd1;
            end
            if(&fmat_top_zp_out_vld) begin
                fmat_top_zp_out_cnt <= fmat_top_zp_out_cnt + 5'd1;
                fmat_top_zp_result_reg[FMAT_OUT_WIDTH*(fmat_top_zp_out_cnt[2:0]) +: FMAT_OUT_WIDTH] <= fmat_top_zp_d_out[0];
                fmat_top_zp_result_reg[FMAT_OUT_WIDTH*(fmat_top_zp_out_cnt[2:0]) + FMAT_OUT_WIDTH*8 +: FMAT_OUT_WIDTH] <= fmat_top_zp_d_out[1];
                if(fmat_top_zp_out_cnt == (zp_io_cycle_num - 1)) begin
                    fmat_top_zp_out_cnt <= 5'd0;
                end
            end
        end
    end

    fmat_top_zp #(
        .DATA_WIDTH  (DATA_WIDTH),
        .OUT_WIDTH   (FMAT_OUT_WIDTH),
        .DATA_NUM    (AXI_CHNL),
        .SCALE_FACTOR(FMAT_SCALE_WIDTH)
    ) u_fmat_top_zp0 (
        .clk         (clk),
        .rst_n       (rst_n),
        .a_vld       (fmat_top_zp_in_vld),
        .b_vld       (fmat_top_zp_in_vld),
        .a_in        (op_a_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[2]) +: DATA_WIDTH*AXI_CHNL]),
`ifdef PERCOL_ZP
        .b_in        ((opm_mode == 2'b11) ? {AXI_CHNL{16'h3F80}} :
                      fmat_zp_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[1:0]) +: DATA_WIDTH*AXI_CHNL]),
`else
        .b_in        (fmat_zp_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[1:0]) +: DATA_WIDTH*AXI_CHNL]),
`endif
        .out_vld     (fmat_top_zp_out_vld[0]),
        .d_out       (fmat_top_zp_d_out[0])
    );

    fmat_top_zp #(
        .DATA_WIDTH  (DATA_WIDTH),
        .OUT_WIDTH   (FMAT_OUT_WIDTH),
        .DATA_NUM    (AXI_CHNL),
        .SCALE_FACTOR(FMAT_SCALE_WIDTH)
    ) u_fmat_top_zp1 (
        .clk         (clk),
        .rst_n       (rst_n),
        .a_vld       (fmat_top_zp_in_vld),
        .b_vld       (fmat_top_zp_in_vld),
        .a_in        (op_a_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[2]) + DATA_WIDTH*AXI_CHNL*2 +: DATA_WIDTH*AXI_CHNL]),
`ifdef PERCOL_ZP
        .b_in        ((opm_mode == 2'b11) ? {AXI_CHNL{16'h3F80}} :
                      fmat_zp_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[1:0]) +: DATA_WIDTH*AXI_CHNL]),
`else
        .b_in        (fmat_zp_out[DATA_WIDTH*AXI_CHNL*(fmat_top_zp_in_cnt[1:0]) +: DATA_WIDTH*AXI_CHNL]),
`endif
        .out_vld     (fmat_top_zp_out_vld[1]),
        .d_out       (fmat_top_zp_d_out[1])
    );

    assign fmat_vtr_in_vld = &fmat_out_vld;

    wire vtr_out_vld;
    wire [AXI_CHNL*FMAT_OUT_WIDTH-1:0] vtr_d_out;
    wire vtr_block_done;

    localparam PARTITION = FMAT_OUT_WIDTH*AXI_CHNL/LOOP_NUM;

    vectorizer #(
        .DATA_WIDTH(FMAT_OUT_WIDTH),
        .AXI_CHNL(AXI_CHNL),
        .LANE(LANE)
    ) u_vectorizer (
        .clk            (clk),
        .rst_n          (rst_n),
        .is_gemm_mode   (is_gemm_mode),
        .is_proj_mode   (is_proj_mode),
        .opm_mode       (opm_mode),
        .cnt_rst        (isa_valid || (is_residual_mode && opm_compute_stop)),
        .batch_num      (batch_num),
        .effective_q_head_num(effective_q_head_num),
        .a_row_num      (a_row_num),
        .fmat_in_vld    (fmat_vtr_in_vld),
        .fmat_din       (fmat_d_out),
        .fmat_zp_in_vld (fmat_top_zp_done),
        .fmat_zp_din    (fmat_top_zp_result),
`ifdef PERCOL_ZP
        .fmat_zp_col    (fmat_zp_col_lat),
`endif
        .block_done     (vtr_block_done),
        .out_vld        (vtr_out_vld),
        .d_out          (vtr_d_out)
    );

`ifdef GQAPVPROBE
// synopsys translate_off
    reg        gqapv_en;  reg [31:0] gqapv_cnt;  reg [7:0] gqapv_pass;
    reg        gqapv_gda_p;
    initial begin gqapv_en = $test$plusargs("GQAPVPROBE"); gqapv_cnt = 0; end
    always @(posedge clk) begin
        if (!rst_n || isa_valid) begin
            gqapv_pass  <= 8'd0;
            gqapv_gda_p <= 1'b0;
        end else begin
            gqapv_gda_p <= generate_done_A;
            if (generate_done_A && !gqapv_gda_p && !is_proj_mode)
                gqapv_pass <= gqapv_pass + 8'd1;
        end
        if (gqapv_en && rst_n && !is_proj_mode
            && op_a_out_vld && op_b_out_vld && gqapv_cnt < 32'd6144) begin
            gqapv_cnt <= gqapv_cnt + 32'd1;
            $display("[GQAPV-IN] %m t=%0t pass=%0d beat=%0d bgn=%0d a=%h_%h_%h_%h b_s0=%h b_s1=%h scl=%h",
                     $time, gqapv_pass, fmat_vld_cnt, b_group_num,
                     op_a_out[15:0], op_a_out[31:16], op_a_out[47:32], op_a_out[63:48],
                     op_b_out[63:0], op_b_out[512 +: 64],
                     fmat_scale_dup_prec8[(SCALE_ZP_DATAWIDTH/2)*b_group_num +: 8]);
        end
        if (gqapv_en && rst_n && !is_proj_mode && gqapv_cnt < 32'd6144) begin
            if (opm_mode == 2'b10 && u_vectorizer.accum_1st_vld_r)
                $display("[GQAPV-ACC] %m t=%0t pass=%0d acnt=%0d c=%h %h %h %h %h %h %h %h",
                         $time, gqapv_pass, u_vectorizer.accum_cnt,
                         u_vectorizer.accum_1st_out_r[0*24+:24], u_vectorizer.accum_1st_out_r[1*24+:24],
                         u_vectorizer.accum_1st_out_r[2*24+:24], u_vectorizer.accum_1st_out_r[3*24+:24],
                         u_vectorizer.accum_1st_out_r[4*24+:24], u_vectorizer.accum_1st_out_r[5*24+:24],
                         u_vectorizer.accum_1st_out_r[6*24+:24], u_vectorizer.accum_1st_out_r[7*24+:24]);
            else if (opm_mode == 2'b11 && |fmat_out_vld)
                $display("[GQAPV-ACC] %m t=%0t pass=%0d c=%h %h %h %h",
                         $time, gqapv_pass, fmat_d_out[0*24+:24], fmat_d_out[1*24+:24],
                         fmat_d_out[2*24+:24], fmat_d_out[3*24+:24]);
        end
    end
// synopsys translate_on
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            d_out   <= {AXI_CHNL*FMAT_OUT_WIDTH{1'b0}};
            block_done <= 1'b0;
        end
        else if (isa_valid) begin
            out_vld <= 1'b0;
            d_out   <= {AXI_CHNL*FMAT_OUT_WIDTH{1'b0}};
            block_done <= 1'b0;
        end
        else begin
            out_vld <= vtr_out_vld;
            d_out   <= vtr_d_out;
            block_done <= vtr_block_done;
        end
    end

endmodule
