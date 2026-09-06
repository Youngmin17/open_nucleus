// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module result_accumulator
#(
    parameter DATA_WIDTH = 16,
    parameter BLOCK_SIZE = 128,
    parameter MAX_BLOCKS = 32,
    parameter LOOP_NUM = 4
)
(
    input clk,
    input rst_n,

    input in_vld,
    input prefill_decode_mode,
    input [DATA_WIDTH*BLOCK_SIZE-1:0] d_in,
    input [$clog2(BLOCK_SIZE)-1:0] idx_in,

    input row_avg_vld,
    input [DATA_WIDTH-1:0] row_avg_val,
    input [$clog2(BLOCK_SIZE)-1:0] row_avg_idx,

    input result_pre_done,

    output reg out_vld,
    output reg [DATA_WIDTH*BLOCK_SIZE-1:0] d_out,
    output reg [$clog2(BLOCK_SIZE)-1:0] idx_out,

    output wire result_done
);

    reg [DATA_WIDTH-1:0] row_avg0 [0:BLOCK_SIZE-1];
    reg [DATA_WIDTH-1:0] row_avg1 [0:BLOCK_SIZE-1];

    reg [$clog2(BLOCK_SIZE)-1:0] process_row_idx;
    reg [$clog2(BLOCK_SIZE)-1:0] process_col_idx;
    reg [$clog2(BLOCK_SIZE)-1:0] out_col_idx;
    reg [$clog2(BLOCK_SIZE)-1:0] out_row_idx;

    localparam TOT_ELEMS = BLOCK_SIZE*BLOCK_SIZE;
    localparam ELEMS_CNT_WIDTH = $clog2(TOT_ELEMS);
    localparam DIM = BLOCK_SIZE / LOOP_NUM;

    reg                   div_ren;
    reg                   div_wen;
    reg [$clog2(BLOCK_SIZE)-1:0] div_raddr;
    reg [$clog2(BLOCK_SIZE)-1:0] div_waddr;
    reg [DATA_WIDTH*BLOCK_SIZE-1:0] div_rdata_reg;
    reg                   start_div;
    reg                   new_row;

    reg [DATA_WIDTH*BLOCK_SIZE-1:0] accum_add_sum;
    reg accum_add_sum_vld;

    wire wen1, wen0;
    wire [($clog2(BLOCK_SIZE))-1:0] waddr1, waddr0;
    wire [DATA_WIDTH*BLOCK_SIZE-1:0] wdata1, wdata0;
    wire write_done1, write_done0;
    wire ren1, ren0;
    wire [($clog2(BLOCK_SIZE))-1:0] raddr1, raddr0;
    wire [DATA_WIDTH*BLOCK_SIZE-1:0] rdata1, rdata0;
    wire rvalid1, rvalid0;
    wire read_done1, read_done0;

    reg buffer_sel;
    reg emit_buf_sel;

    accum_buffer_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_NUM  (BLOCK_SIZE),
        .BUFFER_ADDR(128)
    ) u_acc_buf0 (
        .clk(clk),
        .rst_n(rst_n),
        .wen(wen0),
        .waddr(waddr0),
        .wdata(wdata0),
        .wvalid(wen0),
        .write_done(write_done0),
        .ren(ren0),
        .raddr(raddr0),
        .rdata(rdata0),
        .rvalid(rvalid0),
        .read_done(read_done0)
    );

    accum_buffer_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_NUM  (BLOCK_SIZE),
        .BUFFER_ADDR(128)
    ) u_acc_buf1 (
        .clk(clk),
        .rst_n(rst_n),
        .wen(wen1),
        .waddr(waddr1),
        .wdata(wdata1),
        .wvalid(wen1),
        .write_done(write_done1),
        .ren(ren1),
        .raddr(raddr1),
        .rdata(rdata1),
        .rvalid(rvalid1),
        .read_done(read_done1)
    );

    reg [DATA_WIDTH*BLOCK_SIZE-1:0] d_in_reg1, d_in_reg2, d_in_reg3;
    reg [$clog2(BLOCK_SIZE)-1:0]    idx_in_reg1, idx_in_reg2, idx_in_reg3, idx_in_reg4;

    assign ren0 = (!buffer_sel) ? in_vld : div_ren;
    assign raddr0 = (!buffer_sel) ? idx_in : div_raddr;
    assign wen0 = (!buffer_sel) ? accum_add_sum_vld : div_wen;
    assign waddr0 = (!buffer_sel) ? idx_in_reg4 : div_waddr;
    assign wdata0 = (!buffer_sel) ? accum_add_sum : {DATA_WIDTH*BLOCK_SIZE{1'b0}};

    assign ren1 = (buffer_sel) ? in_vld : div_ren;
    assign raddr1 = (buffer_sel) ? idx_in : div_raddr;
    assign wen1 = (buffer_sel) ? accum_add_sum_vld : div_wen;
    assign waddr1 = (buffer_sel) ? idx_in_reg4 : div_waddr;
    assign wdata1 = (buffer_sel) ? accum_add_sum : {DATA_WIDTH*BLOCK_SIZE{1'b0}};

    wire [DATA_WIDTH*BLOCK_SIZE-1:0] acc_rdata = (buffer_sel) ? rdata1 : rdata0;
    wire                             acc_rvalid = (buffer_sel) ? rvalid1 : rvalid0;
    reg [DATA_WIDTH*BLOCK_SIZE-1:0]  acc_row_data;

    wire                  div_rvalid = (emit_buf_sel) ? rvalid1 : rvalid0;
    wire [DATA_WIDTH*BLOCK_SIZE-1:0] div_rdata = (emit_buf_sel) ? rdata1 : rdata0;

    reg [DATA_WIDTH-1:0] div_num_in0, div_num_in1;
    reg [DATA_WIDTH-1:0] div_den_in;
    reg                   div_in_vld, div_in_vld0, div_in_vld1;

    wire [DATA_WIDTH*DIM-1:0] tmp_out;
    reg [7:0] acc_row_division;
    reg [3:0] add_cnt;

    reg [3:0] result_pre_done_cnt;
    reg result_pre_done_latch;
    assign result_done = result_pre_done_latch;

    reg div_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_row_data <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            acc_row_division <= 0;
            add_cnt <= 0;
            accum_add_sum <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            accum_add_sum_vld <= 1'b0;

        end else begin
            accum_add_sum_vld <= 1'b0;
            if(add_cnt == 1) begin
                accum_add_sum[DATA_WIDTH*acc_row_division +: DATA_WIDTH*DIM] <= tmp_out;
                acc_row_division <= 0;
                add_cnt <= 0;
                accum_add_sum_vld <= 1'b1;
                if(acc_rvalid) begin
                    acc_row_data <= acc_rdata;
                    add_cnt <= LOOP_NUM;
                end
            end else if (add_cnt != 0) begin
                accum_add_sum[DATA_WIDTH*acc_row_division +: DATA_WIDTH*DIM] <= tmp_out;
                acc_row_division <= acc_row_division + DIM;
                add_cnt <= add_cnt - 1;
            end else if (acc_rvalid) begin
                acc_row_data <= acc_rdata;
                acc_row_division <= 0;
                add_cnt <= LOOP_NUM;
            end else begin
                acc_row_data <= 0;
                accum_add_sum <= 0;
                acc_row_division <= 0;
                add_cnt <= 0;
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < DIM; i = i + 1)
        begin : gen_accum_data
            DW_fp_add_inst #(
                .sig_width(7),
                .exp_width(8),
                .ieee_compliance(1)
            ) u_DW_fp_add_inst (
                .inst_a(acc_row_data[(i+acc_row_division)*DATA_WIDTH+:DATA_WIDTH]),
                .inst_b(d_in_reg3[(i+acc_row_division)*DATA_WIDTH+:DATA_WIDTH]),
                .inst_rnd(3'b000),
                .z_inst(tmp_out[i*DATA_WIDTH +: DATA_WIDTH]),
                .status_inst()
            );
        end
    endgenerate

    wire                  div_out_vld0, div_out_vld1;
    wire [DATA_WIDTH-1:0] div_out0, div_out1;

    integer ai;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            d_in_reg1 <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            d_in_reg2 <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            d_in_reg3 <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            idx_in_reg1 <= {($clog2(BLOCK_SIZE)){1'b0}};
            idx_in_reg2 <= {($clog2(BLOCK_SIZE)){1'b0}};
            idx_in_reg3 <= {($clog2(BLOCK_SIZE)){1'b0}};
            idx_in_reg4 <= {($clog2(BLOCK_SIZE)){1'b0}};
            result_pre_done_cnt <= 4'd0;
            result_pre_done_latch <= 1'b0;
            div_state <= 1'b0;
            buffer_sel <= 1'b0;
            emit_buf_sel <= 1'b0;
            process_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
            process_col_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
            out_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
            out_col_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
            new_row <= 1'b0;
            start_div <= 1'b0;
            div_ren <= 1'b0;
            div_wen <= 1'b0;
            div_raddr <= {($clog2(BLOCK_SIZE)){1'b0}};
            div_waddr <= {($clog2(BLOCK_SIZE)){1'b0}};
            div_rdata_reg <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            div_in_vld <= 1'b0;
            div_num_in0 <= {DATA_WIDTH{1'b0}};
            div_num_in1 <= {DATA_WIDTH{1'b0}};
            div_den_in <= {DATA_WIDTH{1'b0}};
            out_vld <= 1'b0;
            d_out <= {DATA_WIDTH*BLOCK_SIZE{1'b0}};
            idx_out <= {($clog2(BLOCK_SIZE)){1'b0}};

            for (ai = 0; ai < BLOCK_SIZE; ai = ai + 1) begin
                row_avg0[ai] <= {DATA_WIDTH{1'b0}};
                row_avg1[ai] <= {DATA_WIDTH{1'b0}};
            end

        end else begin
            d_in_reg2 <= d_in_reg1;
            d_in_reg3 <= d_in_reg2;
            idx_in_reg2 <= idx_in_reg1;
            idx_in_reg3 <= idx_in_reg2;
            idx_in_reg4 <= idx_in_reg3;
            if(in_vld) begin
                d_in_reg1 <= d_in;
                idx_in_reg1 <= idx_in;
            end

            result_pre_done_latch <= 1'b0;
            if(result_pre_done) begin
                result_pre_done_cnt <= 4'd10;
            end else if(result_pre_done_cnt > 0) begin
                result_pre_done_cnt <= result_pre_done_cnt - 1'b1;
                if(result_pre_done_cnt == 4'd1) begin
                    result_pre_done_latch <= 1'b1;
                end
            end

            if(row_avg_vld) begin
                if(!buffer_sel) row_avg0[row_avg_idx] <= row_avg_val;
                else row_avg1[row_avg_idx] <= row_avg_val;
            end

            if(result_pre_done_latch) begin
                div_state <= 1'b1;
                new_row <= 1'b1;
                emit_buf_sel <= buffer_sel;
                buffer_sel <= ~buffer_sel;
            end

            div_in_vld <= 1'b0;
            div_ren <= 1'b0;
            div_wen <= 1'b0;
            out_vld <= 1'b0;
            if(div_state) begin
                if(new_row) begin
                    div_ren <= 1'b1;
                    div_raddr <= process_row_idx;
                    new_row <= 1'b0;
                end else if(div_rvalid) begin
                    div_rdata_reg <= div_rdata;
                    start_div <= 1'b1;
                    div_wen <= 1'b1;
                    div_waddr <= process_row_idx;
                end else if(start_div) begin
                    div_in_vld0 <= (process_col_idx == 0) ? 1'b1 : div_out_vld0;
                    div_in_vld1 <= (process_col_idx == 0) ? 1'b1 : div_out_vld1;
                    div_den_in <= (emit_buf_sel) ? row_avg1[process_row_idx] : row_avg0[process_row_idx];
                    div_num_in0 <= div_rdata_reg[(process_col_idx*DATA_WIDTH*2) +: DATA_WIDTH];
                    div_num_in1 <= div_rdata_reg[(process_col_idx*DATA_WIDTH*2)+DATA_WIDTH +: DATA_WIDTH];
                    process_col_idx <= (process_col_idx == 0) ? process_col_idx + 1 : ((div_out_vld0 && div_out_vld1)? process_col_idx + 1 : process_col_idx);
                    if(process_col_idx == (BLOCK_SIZE>>1)-1 && div_out_vld0 && div_out_vld1) begin
                        start_div <= 1'b0;
                        new_row <= (prefill_decode_mode && process_row_idx == 0) ? 1'b0 : 1'b1;
                        process_col_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
                        process_row_idx <= (prefill_decode_mode && process_row_idx == 0) ? 1'b0 : process_row_idx + 1;
                        div_state <= (prefill_decode_mode && process_row_idx == 0) ? 1'b0 : 1'b1;
                        if(process_row_idx == BLOCK_SIZE-1) begin
                            process_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
                            div_state <= 1'b0;
                            new_row <= 1'b0;
                        end
                        if(emit_buf_sel) begin
                            row_avg1[process_row_idx] <= {DATA_WIDTH{1'b0}};
                        end else begin
                            row_avg0[process_row_idx] <= {DATA_WIDTH{1'b0}};
                        end
                    end
                end
            end

            if(div_out_vld0 && div_out_vld1) begin
                d_out[(out_col_idx*DATA_WIDTH) +: DATA_WIDTH] <= {div_out1, div_out0};
                out_col_idx <= out_col_idx + 1;
                if(out_col_idx == (BLOCK_SIZE>>1)-1) begin
                    out_col_idx <= {($clog2((BLOCK_SIZE>>1))){1'b0}};
                    out_vld <= 1'b1;
                    idx_out <= out_row_idx;
                    out_row_idx <= out_row_idx + 1;
                    if(out_row_idx == BLOCK_SIZE-1) begin
                        out_row_idx <= {($clog2(BLOCK_SIZE)){1'b0}};
                    end
                end
            end
        end
    end

    bf16_div_ip_wrap u_bf16_div_ip_wrap_0 (
        .clk(clk),
        .rst_n(rst_n),
        .a_vld(div_in_vld),
        .b_vld(div_in_vld),
        .a_in(div_num_in0),
        .b_in(div_den_in),
        .out_vld(div_out_vld0),
        .d_out(div_out0)
    );

    bf16_div_ip_wrap u_bf16_div_ip_wrap_1 (
        .clk(clk),
        .rst_n(rst_n),
        .a_vld(div_in_vld),
        .b_vld(div_in_vld),
        .a_in(div_num_in1),
        .b_in(div_den_in),
        .out_vld(div_out_vld1),
        .d_out(div_out1)
    );

reg gw2_en; integer gw2_cnt, gw2_i;
initial begin gw2_en = $test$plusargs("GQAWAVE2"); gw2_cnt = 0; end
always @(posedge clk) begin
  if (!rst_n) gw2_cnt <= 0;
  else if (gw2_en && out_vld && gw2_cnt < 32'd512) begin
    $write("[GQAWAVE2] %m emit=%0d idx_out=%0d d=", gw2_cnt, idx_out);
    for (gw2_i=0; gw2_i<BLOCK_SIZE; gw2_i=gw2_i+1) $write("%h ", d_out[gw2_i*DATA_WIDTH +: DATA_WIDTH]);
    $write("\n"); gw2_cnt <= gw2_cnt + 1;
  end
end

endmodule

