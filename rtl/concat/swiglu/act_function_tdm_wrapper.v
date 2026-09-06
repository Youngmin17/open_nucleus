// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module act_function_tdm_wrapper #(
    parameter DATA_WIDTH = 16,
    parameter DATA_NUM   = 128,
    parameter LOOP_NUM   = 4
)(
    input  wire                           clk,
    input  wire                           rst_n,

    input  wire                           data_in_vld,
    input  wire [DATA_WIDTH*DATA_NUM-1:0] gate_vec_in,
    input  wire [DATA_WIDTH*DATA_NUM-1:0] value_vec_in,

    output reg  [DATA_WIDTH*DATA_NUM-1:0] result_out,
    output reg                            result_out_vld
);

    localparam DIM = DATA_NUM / LOOP_NUM;

    reg [DATA_WIDTH*DATA_NUM-1:0] gate_buffer;
    reg [DATA_WIDTH*DATA_NUM-1:0] value_buffer;

    wire [DIM-1:0] swig_out_vld_w;
    wire [DATA_WIDTH-1:0] swig_out_w [DIM-1:0];

    reg act_func_vld;
    reg [6:0] loop_cnt, loop_cnt_r1, loop_cnt_r2, loop_cnt_r3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loop_cnt <= 7'd0;
            loop_cnt_r1 <= 7'd0;
            loop_cnt_r2 <= 7'd0;
            loop_cnt_r3 <= 7'd0;
            gate_buffer <= {DATA_WIDTH*DATA_NUM{1'b0}};
            value_buffer <= {DATA_WIDTH*DATA_NUM{1'b0}};
            act_func_vld <= 1'b0;

        end else begin
            loop_cnt_r1 <= loop_cnt;
            loop_cnt_r2 <= loop_cnt_r1;
            loop_cnt_r3 <= loop_cnt_r2;
            result_out_vld <= 1'b0;
            if(loop_cnt_r3 == 7'd1) begin
                result_out_vld <= 1'b1;
            end
            if(loop_cnt == 7'd1) begin
                loop_cnt <= 7'd0;
                act_func_vld <= 1'b0;
                if(data_in_vld) begin
                    gate_buffer <= gate_vec_in;
                    value_buffer <= value_vec_in;
                    loop_cnt <= LOOP_NUM;
                    act_func_vld <= 1'b1;
                end
            end else if(loop_cnt > 7'd1) begin
                loop_cnt <= loop_cnt - 7'd1;
            end else begin
                if(data_in_vld) begin
                    gate_buffer <= gate_vec_in;
                    value_buffer <= value_vec_in;
                    loop_cnt <= LOOP_NUM;
                    act_func_vld <= 1'b1;
                end
            end
        end
    end

    integer idx;
    genvar gi;

    generate
    for (gi = 0; gi < DIM; gi = gi + 1) begin : GEN_ACT
        wire        swig_out_vld;
        wire [15:0] swig_out;

        act_function u_act (
            .clk          (clk),
            .rst_n        (rst_n),
            .in_vld       (act_func_vld),
            .gate_in      (gate_buffer[DATA_WIDTH*(gi + DIM*(loop_cnt-1)) +: DATA_WIDTH]),
            .val_in       (value_buffer[DATA_WIDTH*(gi + DIM*(loop_cnt-1)) +: DATA_WIDTH]),
            .swig_out_vld (swig_out_vld),
            .swig_out     (swig_out)
        );

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                for(idx = 0; idx < LOOP_NUM; idx = idx + 1) begin
                    result_out[DATA_WIDTH*(gi + DIM*idx) +: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
                end
            end else begin
                if(swig_out_vld) begin
                    result_out[DATA_WIDTH*(gi + DIM*(loop_cnt_r3-1)) +: DATA_WIDTH] <= swig_out;
                end
            end
        end
    end
    endgenerate

endmodule

`default_nettype wire

