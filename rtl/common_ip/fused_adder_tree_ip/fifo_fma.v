// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`ifndef __FIFO_FMA_V__
`define __FIFO_FMA_V__
module fifo_fma #(
    parameter DATA_WIDTH = 2048,
    parameter DEPTH = 20
)(
    input clk,
    input rst_n,
    input wen,
    input ren,
    input [DATA_WIDTH-1:0] d_in,
    output reg out_vld,
    output reg [DATA_WIDTH-1:0] d_out
);

    localparam SIZE = $clog2(DEPTH);

    integer i;

    wire write;
    wire read;
    wire empty;
    wire full;

    reg [DATA_WIDTH-1:0] mem_fifo [DEPTH-1:0];
    reg [SIZE:0] rd_ptr;
    reg [SIZE:0] wr_ptr;
    reg [SIZE-1:0] fifo_cnt;

    assign write = !full && wen;
    assign read  = !empty && ren;
    assign full  = (fifo_cnt == DEPTH);
    assign empty = (fifo_cnt == 0);

    always @(posedge clk) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (write) begin
            if (wr_ptr == DEPTH - 1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
            rd_ptr <= 0;
        else if (read) begin
            if (rd_ptr == DEPTH - 1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem_fifo[i] <= {DATA_WIDTH{1'b0}};
        end else if (write) begin
            mem_fifo[wr_ptr] <= d_in;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            d_out <= {DATA_WIDTH{1'b0}};
            out_vld <= 1'b0;
        end else if (read) begin
            d_out <= mem_fifo[rd_ptr];
            out_vld <= 1'b1;
        end else begin
            out_vld <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
            fifo_cnt <= 0;
        else if (write && !read)
            fifo_cnt <= fifo_cnt + 1;
        else if (!write && read)
            fifo_cnt <= fifo_cnt - 1;
        else
            fifo_cnt <= fifo_cnt;
    end
endmodule

`endif
