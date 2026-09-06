// SPDX-License-Identifier: Apache-2.0
module sram_8192x16_wrapper (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 wen,
    input  wire [12:0]          waddr,
    input  wire [15:0]          wdata,
    input  wire                 ren,
    input  wire [12:0]          raddr,
    output wire [15:0]          rdata,
    output wire                 rvalid
);

    reg rvalid_reg;
    assign rvalid = rvalid_reg;

    reg read_enable_r, write_enable_r;
    wire read_enable, write_enable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_reg <= 1'b0;
        end else begin
            rvalid_reg <= ren;
        end
    end

    `ifndef SYNTHESIS
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_enable_r <= 1'b0;
            write_enable_r <= 1'b0;
        end else begin
            read_enable_r <= ren;
            write_enable_r <= wen;
        end
    end
    assign read_enable = read_enable_r;
    assign write_enable = write_enable_r;
    `else
    assign read_enable = ren;
    assign write_enable = wen;
    `endif

    genvar i;

    generate
        for (i = 0; i < 16; i = i + 1) begin : SRAM_ARRAY_512x16
            sram_512x16 u_sram_512x16 (
                .rdata   (rdata),
                .clk     (clk),
                .re_n    (~(read_enable && (raddr[12:9] == i[3:0]))),
                .we_n    (~(write_enable && (waddr[12:9] == i[3:0]))),
                .raddr   (raddr[8:0]),
                .waddr   (waddr[8:0]),
                .wdata   (wdata)
            );
        end
    endgenerate

endmodule