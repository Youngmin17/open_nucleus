// SPDX-License-Identifier: Apache-2.0
module sram_256x160 (
  output wire [159:0] rdata,
  input wire clk,
  input wire re_n, input wire we_n,
  input wire [7:0] raddr, input wire [7:0] waddr,
  input wire [159:0] wdata
);
  reg [159:0] mem [0:255];
  reg [159:0] qa_reg;
  assign rdata = qa_reg;
  initial begin
    integer i;
    for (i = 0; i < 256; i = i + 1) mem[i] = 160'd0;
    qa_reg = 160'd0;
  end
  always @(posedge clk) begin
    if (!we_n) mem[waddr] <= wdata;
    if (!re_n) qa_reg <= mem[raddr];
  end
endmodule

module sram_256x128 (
  output wire [127:0] rdata,
  input wire clk,
  input wire re_n, input wire we_n,
  input wire [7:0] raddr, input wire [7:0] waddr,
  input wire [127:0] wdata
);
  reg [127:0] mem [0:255];
  reg [127:0] qa_reg;
  assign rdata = qa_reg;
  initial begin
    integer i;
    for (i = 0; i < 256; i = i + 1) mem[i] = 128'd0;
    qa_reg = 128'd0;
  end
  always @(posedge clk) begin
    if (!we_n) mem[waddr] <= wdata;
    if (!re_n) qa_reg <= mem[raddr];
  end
endmodule

module sram_256x6144_wrapper (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 wen,
    input  wire [7:0]           waddr,
    input  wire [6143:0]        wdata,
    input  wire                 ren,
    input  wire [7:0]           raddr,
    output wire [6143:0]        rdata,
    output wire                 rvalid
);
    reg rvalid_reg;
    assign rvalid = rvalid_reg;

    reg read_enable_r, write_enable_r;
    wire read_enable, write_enable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rvalid_reg <= 1'b0;
        else        rvalid_reg <= ren;
    end

    `ifndef SYNTHESIS
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_enable_r  <= 1'b0;
            write_enable_r <= 1'b0;
        end else begin
            read_enable_r  <= ren;
            write_enable_r <= wen;
        end
    end
    assign read_enable  = read_enable_r;
    assign write_enable = write_enable_r;
    `else
    assign read_enable  = ren;
    assign write_enable = wen;
    `endif

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin: SRAM_ARRAY_256x160
            sram_256x160 u_sram_256x160 (
                .rdata (rdata[i*160 +: 160]), .clk(clk),
                .re_n (~read_enable), .we_n(~write_enable),
                .raddr (raddr), .waddr(waddr), .wdata(wdata[i*160 +: 160])
            );
        end
    endgenerate
    generate
        for (i = 0; i < 8; i = i + 1) begin: SRAM_ARRAY_256x128
            sram_256x128 u_sram_256x128 (
                .rdata (rdata[5120+128*i +: 128]), .clk(clk),
                .re_n (~read_enable), .we_n(~write_enable),
                .raddr (raddr), .waddr(waddr), .wdata(wdata[5120+128*i +: 128])
            );
        end
    endgenerate
endmodule
