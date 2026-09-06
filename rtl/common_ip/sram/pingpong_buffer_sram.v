// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype none

module pingpong_buffer_sram
# (
    parameter integer AXI_CHNL       = 128,
    parameter integer AXI_DATA_WIDTH = 16,
    parameter integer BUFFER_ADDR    = 128
)
(
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire                            rewind,
    input  wire                            one_shot,
    input  wire [AXI_CHNL*AXI_DATA_WIDTH-1:0] up_dat,
    input  wire                            up_vld,
    output wire [AXI_CHNL*AXI_DATA_WIDTH-1:0] dn_dat,
    output wire                            dn_vld
);

    localparam integer ROW_W = AXI_CHNL*AXI_DATA_WIDTH;
    localparam integer ADDR_W = $clog2(BUFFER_ADDR);

    reg                  wr_bank_sel;
    reg [ADDR_W-1:0]     waddr0, waddr1;
    wire                 end_of_block0 = (waddr0 == BUFFER_ADDR[ADDR_W-1:0]-1);
    wire                 end_of_block1 = (waddr1 == BUFFER_ADDR[ADDR_W-1:0]-1);

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_bank_sel <= 1'b0;
            waddr0      <= {ADDR_W{1'b0}};
            waddr1      <= {ADDR_W{1'b0}};
        end else begin
            if (up_vld) begin
                if (one_shot) begin
                    wr_bank_sel <= ~wr_bank_sel;
                    waddr0      <= {ADDR_W{1'b0}};
                    waddr1      <= {ADDR_W{1'b0}};
                end else if (!wr_bank_sel) begin
                    if (end_of_block0) begin
                        wr_bank_sel <= 1'b1;
                        waddr0      <= {ADDR_W{1'b0}};
                    end else begin
                        waddr0 <= waddr0 + {{(ADDR_W-1){1'b0}}, 1'b1};
                    end
                end else begin
                    if (end_of_block1) begin
                        wr_bank_sel <= 1'b0;
                        waddr1      <= {ADDR_W{1'b0}};
                    end else begin
                        waddr1 <= waddr1 + {{(ADDR_W-1){1'b0}}, 1'b1};
                    end
                end
            end
        end
    end

    wire               wen0  = up_vld & ~one_shot & (~wr_bank_sel);
    wire               wen1  = up_vld & ~one_shot & ( wr_bank_sel);
    wire [ADDR_W-1:0]  waddr_sel0 = waddr0;
    wire [ADDR_W-1:0]  waddr_sel1 = waddr1;

    reg                rd_active;
    reg                rd_bank_sel;
    reg [ADDR_W-1:0]   raddr0, raddr1;
    wire               last_row0 = (raddr0 == BUFFER_ADDR[ADDR_W-1:0]-1);
    wire               last_row1 = (raddr1 == BUFFER_ADDR[ADDR_W-1:0]-1);

    wire [ROW_W-1:0] rdata0, rdata1;
    wire             rvalid0, rvalid1;
    wire             write_done0, write_done1;
    wire             read_done0,  read_done1;

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_active   <= 1'b0;
            rd_bank_sel <= 1'b0;
            raddr0      <= {ADDR_W{1'b0}};
            raddr1      <= {ADDR_W{1'b0}};
        end else begin
            if (rewind) begin
                rd_active   <= 1'b1;
                rd_bank_sel <= ~wr_bank_sel;
                raddr0      <= {ADDR_W{1'b0}};
                raddr1      <= {ADDR_W{1'b0}};
            end else if (rd_active) begin
                if (~rd_bank_sel) begin
                    if (rvalid0) begin
                        if (last_row0) begin
                            rd_active <= 1'b0;
                        end else begin
                            raddr0 <= raddr0 + {{(ADDR_W-1){1'b0}}, 1'b1};
                        end
                    end
                end else begin
                    if (rvalid1) begin
                        if (last_row1) begin
                            rd_active <= 1'b0;
                        end else begin
                            raddr1 <= raddr1 + {{(ADDR_W-1){1'b0}}, 1'b1};
                        end
                    end
                end
            end
        end
    end

    wire ren0 = rd_active & (~rd_bank_sel);
    wire ren1 = rd_active & ( rd_bank_sel);

    accum_buffer_sram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .DATA_NUM  (AXI_CHNL),
        .BUFFER_ADDR(BUFFER_ADDR)
    ) u_bank0 (
        .clk       (clk),
        .rst_n     (rst_n),
        .wen       (wen0),
        .waddr     (waddr_sel0),
        .wdata     (up_dat),
        .wvalid    (wen0),
        .write_done(write_done0),
        .ren       (ren0),
        .raddr     (raddr0),
        .rdata     (rdata0),
        .rvalid    (rvalid0),
        .read_done (read_done0)
    );

    accum_buffer_sram #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .DATA_NUM  (AXI_CHNL),
        .BUFFER_ADDR(BUFFER_ADDR)
    ) u_bank1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .wen       (wen1),
        .waddr     (waddr_sel1),
        .wdata     (up_dat),
        .wvalid    (wen1),
        .write_done(write_done1),
        .ren       (ren1),
        .raddr     (raddr1),
        .rdata     (rdata1),
        .rvalid    (rvalid1),
        .read_done (read_done1)
    );

    assign dn_vld = rd_active & ( (~rd_bank_sel & rvalid0) | (rd_bank_sel & rvalid1) );
    assign dn_dat = rd_active ? (rd_bank_sel ? rdata1 : rdata0) : {ROW_W{1'b0}};

endmodule

`default_nettype wire
