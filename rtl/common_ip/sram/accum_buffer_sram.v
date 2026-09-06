// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module accum_buffer_sram
#(
    parameter DATA_WIDTH = 16,
    parameter DATA_NUM   = 128,
    parameter BUFFER_ADDR = 128
)
(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         wen,
    input  wire [$clog2(BUFFER_ADDR)-1:0] waddr,
    input  wire [3:0]                    write_precision,
    input  wire [DATA_WIDTH*DATA_NUM-1:0] wdata,
    input  wire                         wvalid,
    output reg                          write_done,

    input  wire                         ren,
    input  wire [$clog2(BUFFER_ADDR)-1:0] raddr,
    input  wire [3:0]                    read_precision,
    output wire [DATA_WIDTH*DATA_NUM-1:0] rdata,
    output wire                          rvalid,
    output wire                          read_done
);

`ifdef VENDOR_MACRO

    localparam integer TOTAL_WIDTH      = DATA_WIDTH * DATA_NUM;
    localparam integer NUM_160_MACROS   = 12;
    localparam integer NUM_128_MACROS   = 1;
    localparam integer READ_ADDR_WIDTH  = $clog2(BUFFER_ADDR);

    wire do_write = (wen && wvalid);
    wire do_read  = (ren && !do_write);

    reg                     ram_rd_en_n;
    reg                     ram_wr_en_n;
    reg [READ_ADDR_WIDTH-1:0] ram_rd_addr;
    reg [READ_ADDR_WIDTH-1:0] ram_wr_addr;
    reg                     read_pending;
    reg                     wr_req, rd_req;
    reg [TOTAL_WIDTH-1:0]   wdata_lat;
    reg                     rvalid_r, rvalid_d1;

    assign rvalid = rvalid_r;
    assign read_done = rvalid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_rd_en_n     <= 1'b1;
            ram_wr_en_n     <= 1'b1;
            ram_rd_addr  <= {READ_ADDR_WIDTH{1'b0}};
            ram_wr_addr  <= {READ_ADDR_WIDTH{1'b0}};
            write_done   <= 1'b0;
            rvalid_r       <= 1'b0;
            read_pending <= 1'b0;
            wr_req <= 1'b0;
            rd_req <= 1'b0;
            wdata_lat <= {TOTAL_WIDTH{1'b0}};
            rvalid_d1 <= 1'b0;
        end else begin
            ram_rd_en_n   <= 1'b1;
            ram_wr_en_n   <= 1'b1;
            write_done <= 1'b0;
            rvalid_r     <= 1'b0;

            if (do_write) begin
                ram_wr_addr <= waddr;
                wdata_lat   <= wdata;
                wr_req      <= 1'b1;
                read_pending <= 1'b0;
            end else if (do_read) begin
                ram_rd_addr <= raddr;
                rd_req      <= 1'b1;
                read_pending <= 1'b0;
            end else begin
                read_pending <= 1'b0;
            end

            if (wr_req) begin
                ram_wr_en_n   <= 1'b0;
                write_done <= 1'b1;
                wr_req     <= 1'b0;
            end
            if (rd_req) begin
                ram_rd_en_n   <= 1'b0;
                read_pending <= 1'b1;
                rd_req     <= 1'b0;
            end

            rvalid_d1 <= read_pending;
            if (rvalid_d1) begin
                rvalid_r    <= 1'b1;
            end
        end
    end

    wire [159:0] rd160   [0:NUM_160_MACROS-1];
    wire [127:0] rd128;
    wire [159:0] wr160   [0:NUM_160_MACROS-1];
    wire [127:0] wr128;

    genvar gi;
    generate
        for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_db_slice_160
            localparam integer BASE_BIT = gi * 160;
            assign wr160[gi] = wdata_lat[BASE_BIT +: 160];
        end
    endgenerate
    assign wr128 = wdata_lat[1920 +: 128];

    generate
        for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_q_concat_160
            localparam integer BASE_BIT = gi * 160;
            assign rdata[BASE_BIT +: 160] = rd160[gi];
        end
    endgenerate
    assign rdata[1920 +: 128] = rd128;

    wire [READ_ADDR_WIDTH-1:0] rd_addr_w = ram_rd_addr;
    wire [READ_ADDR_WIDTH-1:0] wr_addr_w = ram_wr_addr;

    localparam integer PAD_64  = (6 > READ_ADDR_WIDTH) ? (6 - READ_ADDR_WIDTH) : 0;
    localparam integer PAD_128 = (7 > READ_ADDR_WIDTH) ? (7 - READ_ADDR_WIDTH) : 0;
    wire [5:0] rd_addr_64  = {{PAD_64{1'b0}}, rd_addr_w};
    wire [5:0] wr_addr_64  = {{PAD_64{1'b0}}, wr_addr_w};
    wire [6:0] rd_addr_128 = {{PAD_128{1'b0}}, rd_addr_w};
    wire [6:0] wr_addr_128 = {{PAD_128{1'b0}}, wr_addr_w};
`ifndef SYNTHESIS
    reg rd_en_sim_reg, wr_en_sim_reg;
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_en_sim_reg <= 1'b1;
            wr_en_sim_reg <= 1'b1;
        end else begin
            rd_en_sim_reg <= ram_rd_en_n;
            wr_en_sim_reg <= ram_wr_en_n;
        end
    end
    wire rd_en_n = rd_en_sim_reg;
    wire wr_en_n = wr_en_sim_reg;
`else
    wire rd_en_n = ram_rd_en_n;
    wire wr_en_n = ram_wr_en_n;
`endif

    generate
        if (BUFFER_ADDR == 64) begin : gen_mem_160_depth64
            for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_mem_160_64
                sram_dp_64x160 u_mem_160 (
                    .dout_b  (rd160[gi]),
                    .addr_a  (wr_addr_w[5:0]),
                    .din_a   (wr160[gi]),
                    .we_a    (!wr_en_n),
                    .en_a    (rst_n),
                    .clk     (clk),
                    .addr_b  (rd_addr_w[5:0]),
                    .en_b    (rst_n)
                );
            end
        end else begin : gen_mem_160_depth128
            for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_mem_160_128
                sram_dp_128x160 u_mem_160 (
                    .dout_b  (rd160[gi]),
                    .addr_a  (wr_addr_w),
                    .din_a   (wr160[gi]),
                    .we_a    (!wr_en_n),
                    .en_a    (rst_n),
                    .clk     (clk),
                    .addr_b  (rd_addr_w),
                    .en_b    (rst_n)
                );
            end
        end
    endgenerate

    generate
        if (BUFFER_ADDR == 64) begin : gen_mem_128_depth64
            sram_dp_64x128 u_mem_128 (
                .dout_b  (rd128),
                .addr_a  (wr_addr_w[5:0]),
                .din_a   (wr128),
                .we_a    (!wr_en_n),
                .en_a    (rst_n),
                .clk     (clk),
                .addr_b  (rd_addr_w[5:0]),
                .en_b    (rst_n)
            );
        end else begin : gen_mem_128_depth128
            sram_dp_128x128_b u_mem_128 (
                .dout_b  (rd128),
                .addr_a  (wr_addr_w),
                .din_a   (wr128),
                .we_a    (!wr_en_n),
                .en_a    (rst_n),
                .clk     (clk),
                .addr_b  (rd_addr_w),
                .en_b    (rst_n)
            );
        end
    endgenerate

`else

    assign read_done = rvalid;
    reg read_enable, write_enable;
    reg [$clog2(BUFFER_ADDR)-1:0] read_addr, write_addr;
    reg [DATA_WIDTH*DATA_NUM-1:0] write_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_enable <= 1'b0;
            write_enable <= 1'b0;
            read_addr <= 0;
            write_addr <= 0;
            write_data <= 0;
        end else begin
            read_enable <= ren;
            write_enable <= wen && wvalid;
            read_addr <= raddr;
            write_addr <= waddr;
            write_data <= wdata;
            write_done <= write_enable;
        end
    end

    generate
        if (BUFFER_ADDR == 64) begin : gen_sram_mem_64x2048
            sram_64x2048_wrapper u_sram_64x2048 (
                .clk     (clk),
                .rst_n   (rst_n),
                .wen     (write_enable),
                .waddr   (write_addr),
                .wdata   (write_data),
                .ren     (read_enable),
                .raddr   (read_addr),
                .rdata   (rdata),
                .rvalid  (rvalid)
            );
        end else begin : gen_sram_mem_128x2048
            sram_128x2048_wrapper u_sram_128x2048 (
                .clk     (clk),
                .rst_n   (rst_n),
                .wen     (write_enable),
                .waddr   (write_addr),
                .wdata   (write_data),
                .ren     (read_enable),
                .raddr   (read_addr),
                .rdata   (rdata),
                .rvalid  (rvalid)
            );
        end
    endgenerate

`endif

endmodule
