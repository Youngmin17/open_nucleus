// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`ifdef VENDOR_MACRO
module meta_buffer_sram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 128,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    output reg                      wr_done,

    input  wire                     rd_en,
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output wire [DATA_WIDTH-1:0]    rd_data,
    output reg                      rd_vld,

    input  wire                     clear
);

    wire do_write = wr_en;
    wire do_read  = rd_en && !do_write;

    reg                     ram_rd_en_n;
    reg                     ram_wr_en_n;
    reg [ADDR_WIDTH-1:0]    ram_rd_addr;
    reg [ADDR_WIDTH-1:0]    ram_rd_addr_pip;
    reg [ADDR_WIDTH-1:0]    ram_wr_addr;
    reg [DATA_WIDTH-1:0]    wr_data_lat;

    reg                     wr_req, rd_req;
    reg                     rd_pending;

    always @(posedge clk) begin
        if (!rst_n) begin
            ram_rd_en_n     <= 1'b1;
            ram_wr_en_n     <= 1'b1;
            ram_rd_addr  <= {ADDR_WIDTH{1'b0}};
            ram_wr_addr  <= {ADDR_WIDTH{1'b0}};
            wr_data_lat  <= {DATA_WIDTH{1'b0}};
            wr_req       <= 1'b0;
            rd_req       <= 1'b0;
            rd_pending   <= 1'b0;
            wr_done      <= 1'b0;
            rd_vld       <= 1'b0;
            ram_rd_addr_pip <= {ADDR_WIDTH{1'b0}};
        end else begin
            ram_rd_en_n <= 1'b1;
            ram_wr_en_n <= 1'b1;
            wr_done  <= 1'b0;
            rd_vld   <= 1'b0;
            ram_rd_addr_pip <= ram_rd_addr;

            if (do_write) begin
                ram_wr_addr <= wr_addr;
                wr_data_lat <= wr_data;
                wr_req      <= 1'b1;
                rd_pending  <= 1'b0;
            end
            if (do_read) begin
                ram_rd_addr <= rd_addr;
                rd_req      <= 1'b1;
            end

            if (wr_req) begin
                ram_wr_en_n <= 1'b0;
                wr_done  <= 1'b1;
                wr_req   <= 1'b0;
            end
            if (rd_req) begin
                ram_rd_en_n   <= 1'b0;
                rd_pending <= 1'b1;
                rd_req     <= 1'b0;
            end

            if (rd_pending) begin
                rd_vld     <= 1'b1;
                rd_pending <= 1'b0;
            end
        end
    end

    wire [DATA_WIDTH-1:0] qa;
    wire [DATA_WIDTH-1:0] db = wr_data_lat;

    `ifndef SYNTHESIS
        reg rd_en_sim, wr_en_sim;
        always @(negedge clk) begin
            if (!rst_n) begin
                rd_en_sim <= 1'b1;
                wr_en_sim <= 1'b1;
            end else begin
                rd_en_sim <= ram_rd_en_n;
                wr_en_sim <= ram_wr_en_n;
            end
        end
        wire rd_en_n = rd_en_sim;
        wire wr_en_n = wr_en_sim;
    `else
        wire rd_en_n = ram_rd_en_n;
        wire wr_en_n = ram_wr_en_n;
    `endif

    wire [DATA_WIDTH-1:0] read_data [0:(DEPTH/16)-1];

    genvar i;

    generate
    for (i=0; i< (DEPTH/16); i=i+1) begin : sram_16x16_gen
        sram_dp_16x16 meta_sram_16x16_A(
            .dout_b  (read_data[i][31:16]),
            .addr_a  (ram_wr_addr[3:0]),
            .din_a   (db[31:16]),
            .we_a    (!wr_en_n && ram_wr_addr >> 4 == i),
            .en_a    (rst_n),
            .clk     (clk),
            .addr_b  (ram_rd_addr[3:0]),
            .en_b    (rst_n)
        );

        sram_dp_16x16 meta_sram_16x16_B(
            .dout_b  (read_data[i][15:0]),
            .addr_a  (ram_wr_addr[3:0]),
            .din_a   (db[15:0]),
            .we_a    (!wr_en_n && ram_wr_addr >> 4 == i),
            .en_a    (rst_n),
            .clk     (clk),
            .addr_b  (ram_rd_addr[3:0]),
            .en_b    (rst_n)
        );
    end
    endgenerate

    assign qa = read_data[ram_rd_addr_pip >> 4];
    assign rd_data = qa;

endmodule

`else
module meta_buffer_sram #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 8192,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    output reg                      wr_done,

    input  wire                     rd_en,
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output wire [DATA_WIDTH-1:0]    rd_data,
    output wire                     rd_vld,

    input  wire                     clear
);

    reg write_enable, read_enable;
    reg [ADDR_WIDTH-1:0] write_addr, read_addr;
    reg [DATA_WIDTH-1:0] write_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_enable <= 1'b0;
            read_enable  <= 1'b0;
            write_addr   <= {ADDR_WIDTH{1'b0}};
            read_addr    <= {ADDR_WIDTH{1'b0}};
            write_data   <= {DATA_WIDTH{1'b0}};
            wr_done      <= 1'b0;
        end else begin
            write_enable <= wr_en;
            read_enable  <= rd_en;
            write_addr   <= wr_addr;
            read_addr    <= rd_addr;
            write_data   <= wr_data;
            wr_done      <= write_enable;
        end
    end

    sram_8192x16_wrapper meta_buffer_sram_depth8192 (
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

endmodule

`endif
