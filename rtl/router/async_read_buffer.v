// SPDX-License-Identifier: Apache-2.0
module async_read_buffer (
    input wire mem_clk,
    input wire core_clk,
    input wire rst_n,

    input wire          in_vld,
    input wire [8191:0] d_in,

    output reg          out_vld,
    output reg [4095:0] d_out,

    output wire         ready
);

    reg [8191:0] buf_mem [0:3];

    reg [2:0] wr_ptr;
    wire [2:0] wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

    reg [2:0] rd_ptr;
    wire [2:0] rd_ptr_gray = rd_ptr ^ (rd_ptr >> 1);
    reg rd_phase;

    reg [2:0] wr_gray_meta, wr_gray_sync;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_gray_meta <= 3'b0;
            wr_gray_sync <= 3'b0;
        end else begin
            wr_gray_meta <= wr_ptr_gray;
            wr_gray_sync <= wr_gray_meta;
        end
    end

    reg [2:0] rd_gray_meta, rd_gray_sync;
    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_gray_meta <= 3'b0;
            rd_gray_sync <= 3'b0;
        end else begin
            rd_gray_meta <= rd_ptr_gray;
            rd_gray_sync <= rd_gray_meta;
        end
    end

    wire full  = (wr_ptr_gray[2] != rd_gray_sync[2]) &&
                 (wr_ptr_gray[1] != rd_gray_sync[1]) &&
                 (wr_ptr_gray[0] == rd_gray_sync[0]);
    wire empty = (rd_ptr_gray == wr_gray_sync);

    assign ready = ~full;

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 3'b0;
        end else if (in_vld && ready) begin
            buf_mem[wr_ptr[1:0]] <= d_in;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= 3'b0;
            rd_phase <= 1'b0;
            out_vld  <= 1'b0;
        end else begin
            if (!empty) begin
                out_vld <= 1'b1;
                if (!rd_phase) begin
                    d_out    <= buf_mem[rd_ptr[1:0]][4095:0];
                    rd_phase <= 1'b1;
                end else begin
                    d_out    <= buf_mem[rd_ptr[1:0]][8191:4096];
                    rd_phase <= 1'b0;
                    rd_ptr   <= rd_ptr + 1'b1;
                end
            end else begin
                out_vld <= 1'b0;
            end
        end
    end

endmodule