// SPDX-License-Identifier: Apache-2.0
module sram_32x512_wrapper (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 wen,
    input  wire [4:0]           waddr,
    input  wire [511:0]         wdata,
    input  wire                 ren,
    input  wire [4:0]           raddr,
    output wire [511:0]         rdata,
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
        for (i = 0; i < 4; i = i + 1) begin: SRAM_ARRAY_32x128
            sram_32x128 u_sram_32x128 (
                .rdata   (rdata[i*128 +: 128]),
                .clk     (clk),
                .re_n    (~read_enable),
                .we_n    (~write_enable),
                .raddr   (raddr),
                .waddr   (waddr),
                .wdata   (wdata[i*128 +: 128])
            );
        end
    endgenerate

endmodule