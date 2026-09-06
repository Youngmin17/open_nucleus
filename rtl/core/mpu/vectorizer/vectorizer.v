// SPDX-License-Identifier: Apache-2.0
`default_nettype wire

module vectorizer #(
    parameter DATA_WIDTH = 24,
    parameter AXI_CHNL = 128,
    parameter LANE = 64,
    parameter LOOP_NUM = AXI_CHNL / LANE
) (
    input wire clk,
    input wire rst_n,
    input wire is_proj_mode,
    input wire is_gemm_mode,
    input wire [1:0] opm_mode,
    input wire [7:0] batch_num,
    input wire [2:0] effective_q_head_num,
    input wire [5:0] a_row_num,

    input wire cnt_rst,

    input wire fmat_in_vld,
    input wire [DATA_WIDTH*LANE-1:0] fmat_din,

    input wire fmat_zp_in_vld,
    input wire [DATA_WIDTH*16-1:0] fmat_zp_din,
`ifdef PERCOL_ZP
    input wire [16*AXI_CHNL-1:0] fmat_zp_col,
`endif

    output wire block_done,
    output wire out_vld,
    output wire [DATA_WIDTH*AXI_CHNL-1:0] d_out
);

    wire gemm_proj = is_proj_mode && is_gemm_mode;
    wire gemv_proj = is_proj_mode && !is_gemm_mode;
    wire gemv_gqa = !is_proj_mode && !is_gemm_mode;

    localparam NUM_ACCUM = AXI_CHNL/LANE;

    genvar i;
    genvar k;
    integer idx;

    wire [DATA_WIDTH*(LANE/2)-1:0] accum_1st_out;
    wire [DATA_WIDTH*(LANE/4)-1:0] accum_2nd_out;

    reg accum_1st_vld_r;
    reg accum_2nd_vld_r;
    reg [DATA_WIDTH*(LANE/2)-1:0] accum_1st_out_r;
    reg [DATA_WIDTH*(LANE/4)-1:0] accum_2nd_out_r;

    reg fmat_zp_in_vld_r1, fmat_zp_in_vld_r2, fmat_zp_in_vld_r3, fmat_zp_in_vld_r4;
    reg [DATA_WIDTH*16-1:0] fmat_zp_din_r1, fmat_zp_din_r2, fmat_zp_din_r3, fmat_zp_din_reg;
`ifdef PERCOL_ZP
    reg [16*AXI_CHNL-1:0] zp_col_reg;
    reg [16*AXI_CHNL-1:0] zp_col_hold;
`endif

    generate
        for(k=0; k<LANE/2; k=k+1) begin : ACCUM_1ST
            DW_fp_addsub_inst #(
                .sig_width(15),
                .exp_width(8),
                .ieee_compliance(0)
            ) ACCUMULATOR_1st (
                .inst_a(fmat_din[DATA_WIDTH*(2*k)+:DATA_WIDTH]),
                .inst_b(fmat_din[DATA_WIDTH*(2*k+1)+:DATA_WIDTH]),
                .inst_op(1'b0),
                .inst_rnd(3'b000),
                .z_inst(accum_1st_out[DATA_WIDTH*k+:DATA_WIDTH]),
                .status_inst()
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_1st_vld_r <= 0;
            accum_1st_out_r <= 0;
        end
        else if (cnt_rst) begin
            accum_1st_vld_r <= 0;
            accum_1st_out_r <= 0;
        end
        else begin
            accum_1st_vld_r <= fmat_in_vld;
            accum_1st_out_r <= accum_1st_out;
        end
    end

    generate
        for(k=0; k<LANE/4; k=k+1) begin : ACCUM_2ND
            DW_fp_addsub_inst #(
                .sig_width(15),
                .exp_width(8),
                .ieee_compliance(0)
            ) ACCUMULATOR_2nd (
                .inst_a(accum_1st_out_r[DATA_WIDTH*(2*k)+:DATA_WIDTH]),
                .inst_b(accum_1st_out_r[DATA_WIDTH*(2*k+1)+:DATA_WIDTH]),
                .inst_op(1'b0),
                .inst_rnd(3'b000),
                .z_inst(accum_2nd_out[DATA_WIDTH*k+:DATA_WIDTH]),
                .status_inst()
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_2nd_vld_r <= 0;
            accum_2nd_out_r <= 0;
        end
        else if (cnt_rst) begin
            accum_2nd_vld_r <= 0;
            accum_2nd_out_r <= 0;
        end
        else begin
            accum_2nd_vld_r <= accum_1st_vld_r;
            accum_2nd_out_r <= accum_2nd_out;
        end
    end

    reg [5:0] accum_cnt;
    reg [DATA_WIDTH*AXI_CHNL-1:0] accum_mem [3:0];
    reg [DATA_WIDTH*AXI_CHNL-1:0] vector_fifo [3:0];
    reg accum_done;
    reg vectorize_start;

    integer acc_idx;
    integer trans_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fmat_zp_in_vld_r1 <= 0;
            fmat_zp_din_r1 <= 0;
            fmat_zp_in_vld_r2 <= 0;
            fmat_zp_din_r2 <= 0;
            fmat_zp_in_vld_r3 <= 0;
            fmat_zp_din_r3 <= 0;
            fmat_zp_din_reg <= 0;
`ifdef PERCOL_ZP
            zp_col_reg <= 0;
            zp_col_hold <= 0;
`endif
        end
        else if (cnt_rst) begin
            fmat_zp_in_vld_r1 <= 0;
            fmat_zp_din_r1 <= 0;
            fmat_zp_in_vld_r2 <= 0;
            fmat_zp_din_r2 <= 0;
            fmat_zp_in_vld_r3 <= 0;
            fmat_zp_din_r3 <= 0;
            fmat_zp_din_reg <= 0;
`ifdef PERCOL_ZP
            zp_col_reg <= 0;
            zp_col_hold <= 0;
`endif
        end
        else begin
            fmat_zp_in_vld_r1 <= fmat_zp_in_vld;
            fmat_zp_din_r1 <= fmat_zp_din;
            fmat_zp_in_vld_r2 <= fmat_zp_in_vld_r1;
            fmat_zp_din_r2 <= fmat_zp_din_r1;
            fmat_zp_in_vld_r3 <= fmat_zp_in_vld_r2;
            fmat_zp_din_r3 <= fmat_zp_din_r2;
`ifdef PERCOL_ZP
            if (opm_mode == 2'b11 && fmat_in_vld && accum_cnt != 3'd7)
                zp_col_hold <= fmat_zp_col;
`endif
            if(accum_done) begin
                if(opm_mode == 2'b01) begin
                    fmat_zp_din_reg <= 0;
                end else if(opm_mode == 2'b10) begin
                    fmat_zp_din_reg <= fmat_zp_din_r2;
                end else if(opm_mode == 2'b11) begin
                    fmat_zp_din_reg <= fmat_zp_din_r1;
`ifdef PERCOL_ZP
                    zp_col_reg <= zp_col_hold;
`endif
                end
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        accum_cnt <= 0;
        accum_done <= 1'b0;
        vectorize_start <= 1'b0;
        for(trans_idx=0; trans_idx<4; trans_idx=trans_idx+1) begin
            accum_mem[trans_idx] <= {DATA_WIDTH*AXI_CHNL{1'b0}};
            vector_fifo[trans_idx] <= {DATA_WIDTH*AXI_CHNL{1'b0}};
        end
      end
      else begin
        accum_done <= 1'b0;
        vectorize_start <= 1'b0;

        if(opm_mode == 2'b01) begin
            if(accum_2nd_vld_r) begin
                for(acc_idx=0; acc_idx<4; acc_idx=acc_idx+1) begin
                    accum_mem[acc_idx][(4*DATA_WIDTH)*accum_cnt +: (4*DATA_WIDTH)] <= accum_2nd_out_r[(4*DATA_WIDTH)*acc_idx +: (4*DATA_WIDTH)];
                end
                accum_cnt <= accum_cnt + 1;
                if(accum_cnt == 31) begin
                    accum_done <= 1'b1;
                    accum_cnt <= 0;
                end
            end
        end else if(opm_mode == 2'b10) begin
            if(accum_1st_vld_r) begin
                for(acc_idx=0; acc_idx<4; acc_idx=acc_idx+1) begin
                    accum_mem[acc_idx][(8*DATA_WIDTH)*accum_cnt +: (8*DATA_WIDTH)] <= accum_1st_out_r[(8*DATA_WIDTH)*acc_idx +: (8*DATA_WIDTH)];
                end
                accum_cnt <= accum_cnt + 1;
                if(accum_cnt == 15) begin
                    accum_done <= 1'b1;
                    accum_cnt <= 0;
                end
            end
        end else if(opm_mode == 2'b11) begin
            if(fmat_in_vld) begin
                for(acc_idx=0; acc_idx<4; acc_idx=acc_idx+1) begin
                    accum_mem[acc_idx][(16*DATA_WIDTH)*accum_cnt +: (16*DATA_WIDTH)] <= fmat_din[(16*DATA_WIDTH)*acc_idx +: (16*DATA_WIDTH)];
                end
                accum_cnt <= accum_cnt + 1;
                if(accum_cnt == 7) begin
                    accum_done <= 1'b1;
                    accum_cnt <= 0;
                end
            end
        end

        if(accum_done) begin
            for(trans_idx=0; trans_idx<4; trans_idx=trans_idx+1) begin
                vector_fifo[trans_idx] <= accum_mem[trans_idx];
            end
            vectorize_start <= 1'b1;
        end

        if(cnt_rst) begin
            accum_cnt <= 0;
            for(trans_idx=0; trans_idx<4; trans_idx=trans_idx+1) begin
                accum_mem[trans_idx] <= {DATA_WIDTH*AXI_CHNL{1'b0}};
                vector_fifo[trans_idx] <= {DATA_WIDTH*AXI_CHNL{1'b0}};
            end
        end
      end
    end

    reg [2:0] vectorize_cnt;
    reg vec_vld;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vectorize_cnt <= 0;
            vec_vld <= 1'b0;
        end else begin
            vec_vld <= 1'b0;
            if(cnt_rst) begin
                vectorize_cnt <= 0;
            end else if(vectorize_cnt > 0) begin
                vectorize_cnt <= vectorize_cnt + 1;
                vec_vld <= 1'b1;
                if(vectorize_cnt == 3'd7) begin
                    vectorize_cnt <= 0;
                end
            end else if (vectorize_start) begin
                vectorize_cnt <= vectorize_cnt + 1;
                vec_vld <= 1'b1;
            end
        end
    end

    generate
    for(i=0; i<AXI_CHNL; i=i+1) begin : A_ZP_DOTPRODUCT_ADD
        wire [DATA_WIDTH-1:0] inst_a = vector_fifo[(vectorize_cnt>>1)][DATA_WIDTH*i+:DATA_WIDTH];
`ifdef PERCOL_ZP
        wire [DATA_WIDTH-1:0] zp_col_i = { zp_col_reg[16*i +: 16], {(DATA_WIDTH-16){1'b0}} };
        wire [DATA_WIDTH-1:0] rowsum_i = fmat_zp_din_reg[DATA_WIDTH*4*(vectorize_cnt>>1) +: DATA_WIDTH];
        wire [DATA_WIDTH-1:0] zp_rowsum;
        DW_fp_mult_inst #(
            .sig_width(15),
            .exp_width(8),
            .ieee_compliance(0)
        ) u_zp_mult (
            .inst_a  (zp_col_i),
            .inst_b  (rowsum_i),
            .inst_rnd(3'b000),
            .z_inst  (zp_rowsum),
            .status_inst()
        );
        wire [DATA_WIDTH-1:0] inst_b =
            (opm_mode == 2'b01) ? {DATA_WIDTH{1'b0}} :
            (opm_mode == 2'b11) ? zp_rowsum :
            (i < AXI_CHNL/4) ? fmat_zp_din_reg[DATA_WIDTH*4*(vectorize_cnt>>1) +: DATA_WIDTH] :
            (i < AXI_CHNL/2) ? fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+1) +: DATA_WIDTH] :
            (i < 3*AXI_CHNL/4) ? fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+2) +: DATA_WIDTH] :
                                 fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+3) +: DATA_WIDTH];
`else
        wire [DATA_WIDTH-1:0] inst_b =
            (opm_mode == 2'b01) ? {DATA_WIDTH{1'b0}} :
            (i < AXI_CHNL/4) ? fmat_zp_din_reg[DATA_WIDTH*4*(vectorize_cnt>>1) +: DATA_WIDTH] :
            (i < AXI_CHNL/2) ? fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+1) +: DATA_WIDTH] :
            (i < 3*AXI_CHNL/4) ? fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+2) +: DATA_WIDTH] :
                                 fmat_zp_din_reg[DATA_WIDTH*(4*(vectorize_cnt>>1)+3) +: DATA_WIDTH];
`endif
        DW_fp_add_inst #(
            .sig_width(15),
            .exp_width(8),
            .ieee_compliance(1)
        ) u_DW_fp_add_inst (
            .inst_a(inst_a),
            .inst_b(inst_b),
            .inst_rnd(3'b000),
            .z_inst(d_out[DATA_WIDTH*i+:DATA_WIDTH]),
            .status_inst()
        );
    end
    endgenerate

    reg [7:0] row_done_cnt;

    assign out_vld =
            gemv_proj ? (vec_vld && vectorize_cnt[0] && row_done_cnt < batch_num) :
            gemv_gqa ? (vec_vld && vectorize_cnt[0] && row_done_cnt < effective_q_head_num) :
            (vec_vld && vectorize_cnt[0]);
    assign block_done =
            gemv_proj ? ((row_done_cnt == batch_num-1) && out_vld) :
            gemv_gqa ? ((row_done_cnt == effective_q_head_num-1) && out_vld) :
            ((row_done_cnt == AXI_CHNL-1) && out_vld);

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_done_cnt <= 0;
        end else begin
            if (gemm_proj && vec_vld && vectorize_cnt[0]) begin
                row_done_cnt <= row_done_cnt + 1;
                if (row_done_cnt == AXI_CHNL-1) begin
                    row_done_cnt <= 0;
                end
            end else if (!gemm_proj && vec_vld && vectorize_cnt[0]) begin
                row_done_cnt <= row_done_cnt + 1;
                if (row_done_cnt == (a_row_num << 2)-1) begin
                    row_done_cnt <= 0;
                end
            end

            if (cnt_rst) begin
                row_done_cnt <= 0;
            end
        end
    end

endmodule

`default_nettype wire
