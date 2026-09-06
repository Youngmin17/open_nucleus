// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire

module pingpong_buffer_a #(
    parameter DATA_WIDTH = 16,
    parameter AXI_CHNL = 128,
    parameter DIN_BANDWIDTH = 8192,
    parameter DOUT_BANDWIDTH = 8192,
    parameter LANE = 64,
    parameter BUNDLE_PAIR_NUM = 4
)
(
    input wire                          clk,
    input wire                          rst_n,
    input wire                          isa_valid,
    input wire [7:0]                    batch_num,
    input wire [1:0]                    opm_mode,
    input wire                          is_proj_mode,
    input wire                          is_gemm_mode,
    input wire                          is_residual_mode,
    input wire                          compute_start,
    input wire                          compute_stop,
    input wire                          stall,
    input wire                          up_vld,
    input wire [DIN_BANDWIDTH-1:0]      up_dat,
    input wire                          gqa_b_adv,

    output wire                         dn_vld,
    output wire [DOUT_BANDWIDTH-1:0]    dn_dat,
    output wire [$clog2((AXI_CHNL*AXI_CHNL*DATA_WIDTH)/DOUT_BANDWIDTH):0] a_row_num,
    output wire                         a_new_row,
    output reg                          load_done,
    output reg                          generate_done,
    output reg                          a_stall
  );
    localparam RAM_WIDTH = DOUT_BANDWIDTH;
    localparam BUFFER_ADDR = (AXI_CHNL*AXI_CHNL*DATA_WIDTH)/RAM_WIDTH;

    wire [5:0] num_vec_done_cycle = opm_mode == 2'b01 ? 6'd32 :
                                    opm_mode == 2'b11 ? 6'd8 :
                                    opm_mode == 2'b10 ? 6'd16 : 6'd0;

    wire residual_rst = compute_stop && is_residual_mode;
    reg compute_phase;
    reg [$clog2(BUFFER_ADDR):0] q_row_cnt, q_row_num;
    reg gqa_bank_sel;

    assign a_row_num =  (!is_proj_mode && is_gemm_mode) ? q_row_num :
                        (is_proj_mode && !is_gemm_mode) ? (batch_num[1:0] == 2'b00 ? batch_num[7:2] : batch_num[7:2]+1) :
                        !is_gemm_mode ? 6'd1 :
                        ((AXI_CHNL*AXI_CHNL*DATA_WIDTH)/DOUT_BANDWIDTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_phase <= 1'b0;
            q_row_cnt <= 0;
            q_row_num <= 0;
            gqa_bank_sel <= 1'b0;

        end else begin
            if (compute_stop) begin
                compute_phase <= 1'b0;
                q_row_cnt <= 0;
                if(!is_proj_mode) begin
                    gqa_bank_sel <= 1'b0;
                end
            end else if (compute_start && !compute_phase) begin
                compute_phase <= 1'b1;
                q_row_cnt <= 0;
                if(!is_proj_mode) begin
                    q_row_num <= q_row_cnt;
                    gqa_bank_sel <= 1'b1;
                end
            end

            if(up_vld && !compute_phase && !is_proj_mode) begin
                q_row_cnt <= q_row_cnt + 1;
            end

            if(isa_valid || residual_rst) begin
                compute_phase <= 1'b0;
                q_row_cnt <= 0;
                gqa_bank_sel <= 1'b0;
            end
        end
    end

    reg [$clog2(BUFFER_ADDR)-1:0] pingpong_we_cnt;
    reg pingpong_wen_sel;

    reg [$clog2(BUFFER_ADDR)-1:0] gqa_we_cnt_A;
    reg [$clog2(BUFFER_ADDR)-1:0] gqa_we_cnt_B;
    reg bank_A_we_sel;
    reg bank_B_we_sel;

    reg we_vld_A;
    reg we_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] w_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] w_addr_B;
    reg [RAM_WIDTH-1:0] ram_up_dat_A;
    reg [RAM_WIDTH-1:0] ram_up_dat_B;

    reg bank_A_full, bank_B_full;
    reg bank_B_refill_pending;

    reg [5:0] vec_done_cnt;
    reg [$clog2(BUFFER_ADDR)-1:0] pingpong_re_cnt;
    reg pingpong_ren_sel;
    reg pingpong_ren_sel_pip;

    reg re_vld_A;
    reg re_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] r_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] r_addr_B;
    reg new_row_flag, new_row_flag_pip1, new_row_flag_pip2, new_row;

    assign a_new_row = new_row;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pingpong_we_cnt <= 0;
            pingpong_wen_sel <= 1'b0;
            load_done <= 1'b0;

            gqa_we_cnt_A <= 0;
            gqa_we_cnt_B <= 0;
            bank_A_we_sel <= 1'b0;
            bank_B_we_sel <= 1'b0;

            we_vld_A <= 1'b0;
            w_addr_A <= 0;
            ram_up_dat_A <= {RAM_WIDTH{1'b0}};
            we_vld_B <= 1'b0;
            w_addr_B <= 0;
            ram_up_dat_B <= {RAM_WIDTH{1'b0}};

            bank_A_full <= 1'b0;
            bank_B_full <= 1'b0;
            bank_B_refill_pending <= 1'b0;

        end else begin
            load_done <= 1'b0;
            we_vld_A <= 1'b0;
            we_vld_B <= 1'b0;

            if(compute_phase) begin
                gqa_we_cnt_A <= 0;
            end else begin
                gqa_we_cnt_B <= 0;
            end

            if ((bank_A_full && generate_done && !pingpong_ren_sel_pip && is_proj_mode) ||
                (bank_A_full && compute_stop && !is_proj_mode)) begin
                bank_A_full <= 1'b0;
            end else if(!bank_A_full && !compute_phase && compute_start
                        && !(is_proj_mode && !is_gemm_mode)) begin
                bank_A_full <= 1'b1;
            end

            if (bank_B_full && generate_done && pingpong_ren_sel_pip) begin
                if (bank_B_refill_pending && is_proj_mode && is_gemm_mode) begin
                    bank_B_full <= 1'b1;
                    bank_B_refill_pending <= 1'b0;
                end else begin
                    bank_B_full <= 1'b0;
                end
            end

            if (up_vld) begin
                if (!is_proj_mode) begin
                    if (gqa_bank_sel) begin
                        we_vld_A <= 1'b0;
                        w_addr_A <= 0;
                        ram_up_dat_A <= 0;

                        we_vld_B <= 1'b1;
                        w_addr_B <= gqa_we_cnt_B;
                        ram_up_dat_B <= up_dat;

                        gqa_we_cnt_B <= gqa_we_cnt_B + 1;
                        if(is_gemm_mode) begin
                            if(gqa_we_cnt_B == a_row_num-1) begin
                                gqa_we_cnt_B <= 0;
                                bank_B_full <= 1'b1;
                            end
                        end else begin
                            if(gqa_we_cnt_B == a_row_num-1) begin
                                bank_B_full <= 1'b1;
                            end
                            if(gqa_we_cnt_B == (a_row_num * BUNDLE_PAIR_NUM)-1) begin
                                gqa_we_cnt_B <= 0;
                            end
                        end
                    end
                    else begin
                        we_vld_A <= 1'b1;
                        w_addr_A <= gqa_we_cnt_A;
                        ram_up_dat_A <= up_dat;

                        we_vld_B <= 1'b0;
                        w_addr_B <= 0;
                        ram_up_dat_B <= 0;

                        gqa_we_cnt_A <= gqa_we_cnt_A + 1;
                    end
                end

                else begin
                    we_vld_A <= pingpong_wen_sel ? 1'b0 : 1'b1;
                    w_addr_A <= pingpong_wen_sel ? 0 : pingpong_we_cnt;
                    ram_up_dat_A <= pingpong_wen_sel ? 0 : up_dat;

                    we_vld_B <= pingpong_wen_sel ? 1'b1 : 1'b0;
                    w_addr_B <= pingpong_wen_sel ? pingpong_we_cnt : 0;
                    ram_up_dat_B <= pingpong_wen_sel ? up_dat : 0;

                    if ((a_row_num != 0) && (pingpong_we_cnt == a_row_num-1)) begin
                        pingpong_we_cnt <= 0;
                        pingpong_wen_sel <= !pingpong_wen_sel;
                        load_done <= 1'b1;
                        if(pingpong_wen_sel) begin
                            if (bank_B_full && is_proj_mode && is_gemm_mode)
                                bank_B_refill_pending <= 1'b1;
                            bank_B_full <= 1'b1;
                        end else begin
                            bank_A_full <= 1'b1;
                        end
                    end else begin
                        pingpong_we_cnt <= pingpong_we_cnt + 1;
                        pingpong_wen_sel <= pingpong_wen_sel;
                        load_done <= 1'b0;
                    end
                end
            end

            if(isa_valid || residual_rst) begin
                pingpong_we_cnt <= 0;
                pingpong_wen_sel <= 1'b0;
                gqa_we_cnt_A <= 0;
                gqa_we_cnt_B <= 0;
                bank_A_we_sel <= 1'b0;
                bank_B_we_sel <= 1'b0;
                bank_A_full <= 1'b0;
                bank_B_full <= 1'b0;
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vec_done_cnt <= 0;
            pingpong_re_cnt <= 0;
            pingpong_ren_sel <= 1'b0;
            pingpong_ren_sel_pip <= 1'b0;
            generate_done <= 1'b0;

            re_vld_A <= 1'b0;
            r_addr_A <= 0;
            re_vld_B <= 1'b0;
            r_addr_B <= 0;

            new_row_flag <= 1'b0;
            new_row_flag_pip1 <= 1'b0;
            new_row <= 1'b0;

            a_stall <= 1'b0;

        end else begin
            generate_done <= 1'b0;

            pingpong_ren_sel_pip <= pingpong_ren_sel;

`ifdef PERCOL_ZP
            if (!stall) begin
                new_row_flag <= vec_done_cnt == 0;
                new_row_flag_pip1 <= new_row_flag;
                new_row <= new_row_flag_pip1;
            end
`else
            new_row_flag <= vec_done_cnt == 0;
            new_row_flag_pip1 <= new_row_flag;
            new_row <= new_row_flag_pip1;
`endif

            if (compute_phase && !compute_stop) begin
                re_vld_A <= pingpong_ren_sel ? 1'b0 : (!stall && bank_A_full);
                r_addr_A <= pingpong_ren_sel ? 0 : (!is_proj_mode && !is_gemm_mode ? 0 : pingpong_re_cnt);
                re_vld_B <= pingpong_ren_sel ? (!stall && bank_B_full) : 1'b0;
                r_addr_B <= pingpong_ren_sel ? pingpong_re_cnt : 0;

                if (a_stall && ((!pingpong_ren_sel && bank_A_full) || (pingpong_ren_sel && bank_B_full))) begin
                    a_stall <= 1'b0;
                end

                if (!stall && ((is_proj_mode || is_gemm_mode) ? 1'b1 : gqa_b_adv)) begin
                    if ((a_row_num != 0) && (pingpong_re_cnt == (!is_proj_mode && !is_gemm_mode ? (a_row_num * BUNDLE_PAIR_NUM) : a_row_num)-1)
                        && vec_done_cnt == num_vec_done_cycle-1) begin
                        pingpong_ren_sel <= !pingpong_ren_sel;
                        vec_done_cnt <= 0;
                        pingpong_re_cnt <= 0;
                        generate_done <= 1'b1;
                        if(!((pingpong_ren_sel && bank_A_full) || (!pingpong_ren_sel && bank_B_full))) begin
                            a_stall <= 1'b1;
                        end
                    end else begin
                        vec_done_cnt <= vec_done_cnt + 1;
                        pingpong_ren_sel <= pingpong_ren_sel;
                        if(vec_done_cnt == num_vec_done_cycle-1) begin
                            pingpong_re_cnt <= pingpong_re_cnt + 1;
                            vec_done_cnt <= 0;
                        end
                    end
                end

            end else begin
                vec_done_cnt <= 0;
                pingpong_re_cnt <= 0;
                pingpong_ren_sel <= pingpong_ren_sel;

                re_vld_A <= 1'b0;
                r_addr_A <= 0;
                re_vld_B <= 1'b0;
                r_addr_B <= 0;

                a_stall <= 1'b0;
            end

            if (compute_start && !bank_A_full && is_proj_mode && !is_gemm_mode) begin
                a_stall <= 1'b1;
            end

            if(isa_valid || residual_rst) begin
                vec_done_cnt <= 0;
                pingpong_re_cnt <= 0;
                pingpong_ren_sel <= 1'b0;

                re_vld_A <= 1'b0;
                r_addr_A <= 0;
                re_vld_B <= 1'b0;
                r_addr_B <= 0;

                new_row_flag <= 1'b0;
                new_row_flag_pip1 <= 1'b0;
                new_row <= 1'b0;

                a_stall <= 1'b0;
            end
        end
    end

    wire [RAM_WIDTH-1:0] ram_dn_dat_A;
    wire [RAM_WIDTH-1:0] ram_dn_dat_B;
    wire ram_dn_vld_A;
    wire ram_dn_vld_B;

    sram_32x8192_wrapper uA0_sram_32x8192_wrapper(
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

    sram_32x8192_wrapper uA1_sram_32x8192_wrapper(
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

    reg [RAM_WIDTH-1:0] dn_dat_r;
    reg dn_vld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dn_vld_r <= 0;
            dn_dat_r <= 0;
        end
        else if (isa_valid || residual_rst) begin
            dn_vld_r <= 1'b0;
            dn_dat_r <= {RAM_WIDTH{1'b0}};
        end
        else begin
            if (ram_dn_vld_B) begin
                dn_vld_r <= ram_dn_vld_B;
                dn_dat_r <= ram_dn_dat_B;
            end
            else if (ram_dn_vld_A) begin
                dn_vld_r <= ram_dn_vld_A;
                dn_dat_r <= ram_dn_dat_A;
            end
            else begin
                dn_vld_r <= 1'b0;
                dn_dat_r <= {RAM_WIDTH{1'b0}};
            end
        end
    end

    assign dn_vld = dn_vld_r;
    assign dn_dat = dn_dat_r;

endmodule