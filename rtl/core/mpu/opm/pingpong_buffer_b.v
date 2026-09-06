// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire

module pingpong_buffer_b #(
    parameter HBM_CHANNELS = 32,
    parameter HBM_DATA_WIDTH = 256,
    parameter DATA_WIDTH = 16,
    parameter AXI_CHNL = 128,
    parameter BUNDLE_PAIR_NUM = 4
)
(
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire compute_start,
    input wire compute_stop,
    input wire stall,
    input wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] up_dat,
    input wire                                   up_vld,
    input wire [1:0]                             opm_mode,
    input wire                                   is_proj_mode,
    input wire                                   is_gemm_mode,
    input wire                                   is_residual_mode,
    input wire [5:0]                             a_row_num,

    output wire [HBM_CHANNELS*HBM_DATA_WIDTH-1:0] dn_dat,
    output wire                                   dn_vld,

    output reg  [1:0] group_num,

    output reg  load_done,
    output reg  generate_done,
    output reg  b_stall,
    output wire gqa_b_pending,
    output wire gqa_rd_adv
);

    localparam RAM_WIDTH = HBM_CHANNELS*HBM_DATA_WIDTH;
    localparam BUFFER_ADDR = (AXI_CHNL*AXI_CHNL*DATA_WIDTH)/RAM_WIDTH;

    localparam THROUGHPUT_128 = 8;
    localparam THROUGHPUT_64  = 16;
    localparam THROUGHPUT_32  = 32;

    wire residual_rst = compute_stop && is_residual_mode;

    reg compute_phase;
    always @(posedge clk) begin
        if (!rst_n) begin
            compute_phase <= 1'b0;
        end else begin
            if (compute_stop) compute_phase <= 1'b0;
            else if (compute_start && !compute_phase) compute_phase <= 1'b1;
            else compute_phase <= compute_phase;
            if (isa_valid || residual_rst) compute_phase <= 1'b0;
        end
    end

    wire [1:0] mode_throughput;
    assign mode_throughput = opm_mode == 2'b01 ? 2'b01:
                             opm_mode == 2'b11 ? 2'b10:
                             opm_mode == 2'b10 ? 2'b11:
                                                 2'b00;

    reg [$clog2(BUFFER_ADDR)-1:0] pingpong_we_cnt;
    reg pingpong_wen_sel;

    reg we_vld_A;
    reg we_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] w_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] w_addr_B;
    reg [RAM_WIDTH-1:0] ram_up_dat_A;
    reg [RAM_WIDTH-1:0] ram_up_dat_B;

    reg bank_A_full, bank_B_full;

    reg [$clog2(BUFFER_ADDR)-1:0] pingpong_re_cnt;
    reg pingpong_ren_sel;
    reg [5:0] loop_cnt;

    reg re_vld_A;
    reg re_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] r_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] r_addr_B;
    reg [1:0] group_decision, group_decision_pip;

    reg [39:0] gqa_gemv_wr_cnt, gqa_gemv_rd_cnt;
    assign gqa_b_pending = !is_proj_mode && !is_gemm_mode &&
                           (gqa_gemv_wr_cnt != gqa_gemv_rd_cnt);

    wire nothing_to_read = (pingpong_ren_sel == pingpong_wen_sel && pingpong_we_cnt == 0 && pingpong_re_cnt == 0 && loop_cnt == 0);

    wire gqa_rd_ok = (is_proj_mode || is_gemm_mode) ||
                     (gqa_gemv_rd_cnt < gqa_gemv_wr_cnt);

    assign gqa_rd_adv = compute_phase && !compute_stop &&
                        !nothing_to_read && !stall && gqa_rd_ok;

    always @(posedge clk) begin
        if (!rst_n) begin
            pingpong_we_cnt <= 0;
            pingpong_wen_sel <= 1'b0;
            load_done <= 1'b0;

            we_vld_A <= 1'b0;
            w_addr_A <= 0;
            ram_up_dat_A <= 0;

            we_vld_B <= 1'b0;
            w_addr_B <= 0;
            ram_up_dat_B <= 0;

            bank_A_full <= 1'b0;
            bank_B_full <= 1'b0;

            gqa_gemv_wr_cnt <= 0;

        end else begin
            load_done <= 1'b0;
            we_vld_A <= 1'b0;
            we_vld_B <= 1'b0;

            if (bank_A_full && re_vld_A) begin
                bank_A_full <= 1'b0;
            end

            if (bank_B_full && re_vld_B) begin
                bank_B_full <= 1'b0;
            end

            if (up_vld) begin
                if (!is_proj_mode && !is_gemm_mode) begin
                    gqa_gemv_wr_cnt <= gqa_gemv_wr_cnt + 1;
                end

                if (pingpong_wen_sel) begin
                    ram_up_dat_A <= 0;
                    w_addr_A <= 0;

                    we_vld_B <= up_vld;
                    ram_up_dat_B <= up_dat;
                    w_addr_B <= pingpong_we_cnt;
                end
                else begin
                    we_vld_A <= up_vld;
                    ram_up_dat_A <= up_dat;
                    w_addr_A <= pingpong_we_cnt;

                    ram_up_dat_B <= 0;
                    w_addr_B <= 0;
                end

                if (mode_throughput == 2'b10) begin
                    if (pingpong_we_cnt == THROUGHPUT_128-1) begin
                        pingpong_we_cnt <= 0;
                        pingpong_wen_sel <= !pingpong_wen_sel;
                        load_done <= 1'b1;
                        if(pingpong_wen_sel) begin
                            bank_B_full <= 1'b1;
                        end else begin
                            bank_A_full <= 1'b1;
                        end
                    end
                    else begin
                        pingpong_we_cnt <= pingpong_we_cnt + 1;
                        pingpong_wen_sel <= pingpong_wen_sel;
                    end
                end
                else if (mode_throughput == 2'b11) begin
                    if (pingpong_we_cnt == THROUGHPUT_64-1) begin
                        pingpong_we_cnt <= 0;
                        pingpong_wen_sel <= !pingpong_wen_sel;
                        load_done <= 1'b1;
                        if(pingpong_wen_sel) begin
                            bank_B_full <= 1'b1;
                        end else begin
                            bank_A_full <= 1'b1;
                        end
                    end
                    else begin
                        pingpong_we_cnt <= pingpong_we_cnt + 1;
                        pingpong_wen_sel <= pingpong_wen_sel;
                    end
                end
                else if (mode_throughput == 2'b01) begin
                    if (pingpong_we_cnt == THROUGHPUT_32-1) begin
                        pingpong_we_cnt <= 0;
                        pingpong_wen_sel <= !pingpong_wen_sel;
                        load_done <= 1'b1;
                        if(pingpong_wen_sel) begin
                            bank_B_full <= 1'b1;
                        end else begin
                            bank_A_full <= 1'b1;
                        end
                    end
                    else begin
                        pingpong_we_cnt <= pingpong_we_cnt + 1;
                        pingpong_wen_sel <= pingpong_wen_sel;
                    end
                end
            end
            else begin
                pingpong_we_cnt <= pingpong_we_cnt;
                pingpong_wen_sel <= pingpong_wen_sel;
                w_addr_A <= w_addr_A;
                w_addr_B <= w_addr_B;
            end

            if(isa_valid || residual_rst) begin
                pingpong_we_cnt <= 0;
                pingpong_wen_sel <= 1'b0;
                w_addr_A <= 0;
                ram_up_dat_A <= 0;
                w_addr_B <= 0;
                ram_up_dat_B <= 0;
                bank_A_full <= 1'b0;
                bank_B_full <= 1'b0;
                gqa_gemv_wr_cnt <= 0;
            end

            if(compute_stop && !is_proj_mode && !is_gemm_mode) begin
                gqa_gemv_wr_cnt <= gqa_gemv_wr_cnt - gqa_gemv_rd_cnt
                                   + (up_vld ? 40'd1 : 40'd0);
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pingpong_re_cnt <= 0;
            pingpong_ren_sel <= 1'b0;
            generate_done <= 1'b0;
            loop_cnt <= 0;
            group_decision <= 2'b0;
            group_decision_pip <= 2'b0;
            group_num <= 2'b0;
            b_stall <= 1'b0;

            re_vld_A <= 1'b0;
            re_vld_B <= 1'b0;
            r_addr_A <= 0;
            r_addr_B <= 0;

            gqa_gemv_rd_cnt <= 0;

        end else begin
            group_decision_pip <= group_decision;
            group_num <= group_decision_pip;
            re_vld_A <= 1'b0;
            re_vld_B <= 1'b0;
            generate_done <= 1'b0;

            if (!is_proj_mode && !is_gemm_mode) begin
                if (gqa_gemv_rd_cnt < gqa_gemv_wr_cnt || (gqa_gemv_rd_cnt == gqa_gemv_wr_cnt && up_vld)) begin
                    b_stall <= 1'b0;
                end
            end else begin
                if (b_stall && ((!pingpong_ren_sel && bank_A_full) || (pingpong_ren_sel && bank_B_full))) begin
                    b_stall <= 1'b0;
                end
            end

            if (compute_phase && !compute_stop) begin
                if (!nothing_to_read && !stall && gqa_rd_ok && !is_proj_mode && !is_gemm_mode) begin
                    gqa_gemv_rd_cnt <= gqa_gemv_rd_cnt + 1;
                end

                if (mode_throughput == 2'b10) begin
                    re_vld_A <= !pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_A <= pingpong_ren_sel ? 0 : pingpong_re_cnt;
                    re_vld_B <= pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_B <= pingpong_ren_sel ? pingpong_re_cnt : 0;
                    group_decision <= (pingpong_re_cnt < (THROUGHPUT_128/4)) ? 2'b00 :
                                      (pingpong_re_cnt < (THROUGHPUT_128/2)) ? 2'b01 :
                                      (pingpong_re_cnt < (3*THROUGHPUT_128/4)) ? 2'b10 : 2'b11;
                    if(!nothing_to_read && !stall && gqa_rd_ok) begin
                        if (pingpong_re_cnt == THROUGHPUT_128-1) begin
                            if(loop_cnt == a_row_num-1) begin
                                loop_cnt <= 0;
                                pingpong_ren_sel <= !pingpong_ren_sel;
                                generate_done <= 1'b1;
                                pingpong_re_cnt <= 0;
                                if(!is_proj_mode && !is_gemm_mode) begin
                                    if (gqa_gemv_rd_cnt == gqa_gemv_wr_cnt-1) begin
                                        b_stall <= 1'b1;
                                    end
                                end else begin
                                    if(!((pingpong_ren_sel && bank_A_full) || (!pingpong_ren_sel && bank_B_full))) begin
                                        b_stall <= 1'b1;
                                    end
                                end
                            end else begin
                                loop_cnt <= loop_cnt + 1;
                                pingpong_re_cnt <= 0;
                            end
                        end else begin
                            pingpong_re_cnt <= pingpong_re_cnt + 1;
                            pingpong_ren_sel <= pingpong_ren_sel;
                        end
                    end
                end

                else if (mode_throughput == 2'b11) begin
                    re_vld_A <= !pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_A <= pingpong_ren_sel ? 0 : pingpong_re_cnt;
                    re_vld_B <= pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_B <= pingpong_ren_sel ? pingpong_re_cnt : 0;
                    group_decision <= (pingpong_re_cnt < (THROUGHPUT_64/4)) ? 2'b00 :
                                      (pingpong_re_cnt < (THROUGHPUT_64/2)) ? 2'b01 :
                                      (pingpong_re_cnt < (3*THROUGHPUT_64/4)) ? 2'b10 : 2'b11;
                    if(!nothing_to_read && !stall && gqa_rd_ok) begin
                        if (pingpong_re_cnt == THROUGHPUT_64-1) begin
                            if(loop_cnt == a_row_num-1) begin
                                loop_cnt <= 0;
                                pingpong_ren_sel <= !pingpong_ren_sel;
                                generate_done <= 1'b1;
                                pingpong_re_cnt <= 0;
                                if(!is_proj_mode && !is_gemm_mode) begin
                                    if (gqa_gemv_rd_cnt == gqa_gemv_wr_cnt-1) begin
                                        b_stall <= 1'b1;
                                    end
                                end else begin
                                    if(!((pingpong_ren_sel && bank_A_full) || (!pingpong_ren_sel && bank_B_full))) begin
                                        b_stall <= 1'b1;
                                    end
                                end
                            end else begin
                                loop_cnt <= loop_cnt + 1;
                                pingpong_re_cnt <= 0;
                            end
                        end else begin
                            pingpong_re_cnt <= pingpong_re_cnt + 1;
                            pingpong_ren_sel <= pingpong_ren_sel;
                        end
                    end
                end

                else if (mode_throughput == 2'b01) begin
                    re_vld_A <= !pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_A <= pingpong_ren_sel ? 0 : pingpong_re_cnt;
                    re_vld_B <= pingpong_ren_sel && !nothing_to_read && !stall && gqa_rd_ok;
                    r_addr_B <= pingpong_ren_sel ? pingpong_re_cnt : 0;
                    group_decision <= (pingpong_re_cnt < (THROUGHPUT_32/4)) ? 2'b00 :
                                      (pingpong_re_cnt < (THROUGHPUT_32/2)) ? 2'b01 :
                                      (pingpong_re_cnt < (3*THROUGHPUT_32/4)) ? 2'b10 : 2'b11;
                    if(!nothing_to_read && !stall && gqa_rd_ok) begin
                        if (pingpong_re_cnt == THROUGHPUT_32-1) begin
                            if(loop_cnt == a_row_num-1) begin
                                loop_cnt <= 0;
                                pingpong_ren_sel <= !pingpong_ren_sel;
                                generate_done <= 1'b1;
                                pingpong_re_cnt <= 0;
                                if(!is_proj_mode && !is_gemm_mode) begin
                                    if (gqa_gemv_rd_cnt == gqa_gemv_wr_cnt-1) begin
                                        b_stall <= 1'b1;
                                    end
                                end else begin
                                    if(!((pingpong_ren_sel && bank_A_full) || (!pingpong_ren_sel && bank_B_full))) begin
                                        b_stall <= 1'b1;
                                    end
                                end
                            end else begin
                                loop_cnt <= loop_cnt + 1;
                                pingpong_re_cnt <= 0;
                            end
                        end else begin
                            pingpong_re_cnt <= pingpong_re_cnt + 1;
                            pingpong_ren_sel <= pingpong_ren_sel;
                        end
                    end
                end

            end else begin
                pingpong_re_cnt <= 0;
                loop_cnt <= 0;
                pingpong_ren_sel <= pingpong_ren_sel;

                r_addr_A <= 0;
                r_addr_B <= 0;

                b_stall <= 1'b0;

                gqa_gemv_rd_cnt <= 0;
            end

            if(isa_valid || residual_rst) begin
                pingpong_re_cnt <= 0;
                loop_cnt <= 0;
                pingpong_ren_sel <= 1'b0;

                r_addr_A <= 0;
                r_addr_B <= 0;

                group_decision <= 2'b0;
                group_decision_pip <= 2'b0;
                group_num <= 2'b0;

                b_stall <= 1'b0;

                gqa_gemv_rd_cnt <= 0;
            end
        end
    end

    wire [RAM_WIDTH-1:0] ram_dn_dat_A;
    wire [RAM_WIDTH-1:0] ram_dn_dat_B;

    wire ram_dn_vld_A;
    wire ram_dn_vld_B;

    sram_32x8192_wrapper uB0_sram_32x8192_wrapper(
            .clk   (clk),
            .rst_n (rst_n),
            .wen   (we_vld_A),
            .waddr (w_addr_A),
            .wdata (ram_up_dat_A),
            .ren   (re_vld_A),
            .raddr (r_addr_A),
            .rdata (ram_dn_dat_A),
            .rvalid(ram_dn_vld_A)
    );

    sram_32x8192_wrapper uB1_sram_32x8192_wrapper(
            .clk   (clk),
            .rst_n (rst_n),
            .wen   (we_vld_B),
            .waddr (w_addr_B),
            .wdata (ram_up_dat_B),
            .ren   (re_vld_B),
            .raddr (r_addr_B),
            .rdata (ram_dn_dat_B),
            .rvalid(ram_dn_vld_B)
    );

    reg [HBM_CHANNELS*HBM_DATA_WIDTH-1:0]   dn_dat_r;
    reg                        dn_vld_r;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dn_dat_r <= 0;
            dn_vld_r <= 1'b0;
        end
        else if (isa_valid || residual_rst) begin
            dn_dat_r <= {RAM_WIDTH{1'b0}};
            dn_vld_r <= 1'b0;
        end
        else begin
            if (ram_dn_vld_A) begin
                dn_dat_r <= ram_dn_dat_A;
                dn_vld_r <= ram_dn_vld_A ;
            end
            else if (ram_dn_vld_B) begin
                dn_dat_r <= ram_dn_dat_B;
                dn_vld_r <= ram_dn_vld_B;
            end
            else begin
                dn_dat_r <= {RAM_WIDTH{1'b0}};
                dn_vld_r <= 1'b0;
            end
        end
    end

    assign dn_dat = dn_dat_r;
    assign dn_vld = dn_vld_r;

endmodule

`default_nettype wire
