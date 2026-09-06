// SPDX-License-Identifier: Apache-2.0
module residual_vector_file
#(
    parameter integer DIM = 128,
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH_ROWS = 64
)
(
    input wire clk,
    input wire rst_n,

    input  wire                  prog_en,
    input  wire [$clog2(DEPTH_ROWS)-1:0] prog_addr,
    input  wire [DIM*DATA_WIDTH-1:0]     prog_data,

    input  wire                  rd_en,
    input  wire [$clog2(DEPTH_ROWS)-1:0] rd_addr,
    output wire                 rd_vld,
    output wire [DIM*DATA_WIDTH-1:0]     rd_data
);

reg write_enable, read_enable;
reg [$clog2(DEPTH_ROWS)-1:0] write_addr, read_addr;
reg [DIM*DATA_WIDTH-1:0] write_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_enable <= 1'b0;
        read_enable  <= 1'b0;
        write_addr   <= {($clog2(DEPTH_ROWS)){1'b0}};
        read_addr    <= {($clog2(DEPTH_ROWS)){1'b0}};
        write_data   <= {(DIM*DATA_WIDTH){1'b0}};
    end else begin
        write_enable <= prog_en;
        read_enable  <= rd_en;
        write_addr   <= prog_addr;
        read_addr    <= rd_addr;
        write_data   <= prog_data;
    end
end

generate
    if(DEPTH_ROWS == 32) begin
        sram_32x2048_wrapper vector_register_file_depth32 (
            .clk    (clk),
            .rst_n  (rst_n),
            .wen    (write_enable),
            .waddr  (write_addr),
            .wdata  (write_data),
            .ren    (read_enable),
            .raddr  (read_addr),
            .rdata  (rd_data),
            .rvalid (rd_vld)
        );
    end else if (DEPTH_ROWS == 64) begin
        sram_64x2048_wrapper vector_register_file_depth64 (
            .clk    (clk),
            .rst_n  (rst_n),
            .wen    (write_enable),
            .waddr  (write_addr),
            .wdata  (write_data),
            .ren    (read_enable),
            .raddr  (read_addr),
            .rdata  (rd_data),
            .rvalid (rd_vld)
        );
    end else if (DEPTH_ROWS == 128) begin
        sram_128x2048_wrapper vector_register_file_depth128 (
            .clk    (clk),
            .rst_n  (rst_n),
            .wen    (write_enable),
            .waddr  (write_addr),
            .wdata  (write_data),
            .ren    (read_enable),
            .raddr  (read_addr),
            .rdata  (rd_data),
            .rvalid (rd_vld)
        );
    end
endgenerate

endmodule