// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module psm_register
#(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 128,
    parameter INIT_VALUE = 16'hFF80
)
(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear,
    input  wire                     wr_en,
    input  wire [$clog2(DEPTH)-1:0] wr_idx,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    input  wire                     rd_en,
    input  wire [$clog2(DEPTH)-1:0] rd_idx,
    output reg  [DATA_WIDTH-1:0]    rd_data,
    output reg                      rd_vld
);

    reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i=0; i<DEPTH; i=i+1) begin
                mem[i] <= INIT_VALUE;
            end
            rd_data <= INIT_VALUE;
            rd_vld  <= 1'b0;
        end
        else if (clear) begin
            rd_data <= INIT_VALUE;
            rd_vld  <= 1'b0;
            for (i=0; i<DEPTH; i=i+1)
                mem[i] <= INIT_VALUE;
        end
        else begin
            if (wr_en) begin
                mem[wr_idx] <= wr_data;
            end
            if (rd_en) begin
                rd_data <= mem[rd_idx];
            end
            rd_vld <= rd_en;
        end
    end

endmodule

`default_nettype wire

