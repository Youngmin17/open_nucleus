// SPDX-License-Identifier: Apache-2.0
module sram_32x16 (
  output wire [15:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [4:0] raddr,
  input wire [4:0] waddr,
  input wire [15:0] wdata
);

reg [15:0] mem [0:31];
reg [15:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        mem[i] = 16'h0000;
    end
    qa_reg = 16'h0000;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_32x128 (
  output wire [127:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [4:0] raddr,
  input wire [4:0] waddr,
  input wire [127:0] wdata
);

reg [127:0] mem [0:31];
reg [127:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        mem[i] = 128'd0;
    end
    qa_reg = 128'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_32x160 (
  output wire [159:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [4:0] raddr,
  input wire [4:0] waddr,
  input wire [159:0] wdata
);

reg [159:0] mem [0:31];
reg [159:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        mem[i] = 160'd0;
    end
    qa_reg = 160'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_40x128 (
  output wire [127:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [127:0] wdata
);

reg [127:0] mem [0:39];
reg [127:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 128'd0;
    end
    qa_reg = 128'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_40x160 (
  output wire [159:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [159:0] wdata
);

reg [159:0] mem [0:39];
reg [159:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 160'd0;
    end
    qa_reg = 160'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_64x32 (
  output wire [31:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [31:0] wdata
);

reg [31:0] mem [0:63];
reg [31:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 32'd0;
    end
    qa_reg = 32'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_64x40 (
  output wire [39:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [39:0] wdata
);

reg [39:0] mem [0:63];
reg [39:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 40'd0;
    end
    qa_reg = 40'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_64x128 (
  output wire [127:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [127:0] wdata
);

reg [127:0] mem [0:63];
reg [127:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 128'd0;
    end
    qa_reg = 128'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_64x160 (
  output wire [159:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [5:0] raddr,
  input wire [5:0] waddr,
  input wire [159:0] wdata
);

reg [159:0] mem [0:63];
reg [159:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 64; i = i + 1) begin
        mem[i] = 160'd0;
    end
    qa_reg = 160'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x128 (
  output wire [127:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [127:0] wdata
);

reg [127:0] mem [0:127];
reg [127:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 128'd0;
    end
    qa_reg = 128'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x160 (
  output wire [159:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [159:0] wdata
);

reg [159:0] mem [0:127];
reg [159:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 160'd0;
    end
    qa_reg = 160'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x32 (
  output wire [31:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [31:0] wdata
);

reg [31:0] mem [0:127];
reg [31:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 32'd0;
    end
    qa_reg = 32'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x16 (
  output wire [15:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [15:0] wdata
);

reg [15:0] mem [0:127];
reg [15:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 16'd0;
    end
    qa_reg = 16'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_512x16 (
  output wire [15:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [8:0] raddr,
  input wire [8:0] waddr,
  input wire [15:0] wdata
);

reg [15:0] mem [0:511];
reg [15:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 512; i = i + 1) begin
        mem[i] = 16'd0;
    end
    qa_reg = 16'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x14 (
  output wire [13:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [13:0] wdata
);

reg [13:0] mem [0:127];
reg [13:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 14'd0;
    end
    qa_reg = 14'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x20 (
  output wire [19:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [19:0] wdata
);

reg [19:0] mem [0:127];
reg [19:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 20'd0;
    end
    qa_reg = 20'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x24 (
  output wire [23:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [23:0] wdata
);

reg [23:0] mem [0:127];
reg [23:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 24'd0;
    end
    qa_reg = 24'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x28 (
  output wire [27:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [27:0] wdata
);

reg [27:0] mem [0:127];
reg [27:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 28'd0;
    end
    qa_reg = 28'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x34 (
  output wire [33:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [33:0] wdata
);

reg [33:0] mem [0:127];
reg [33:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 34'd0;
    end
    qa_reg = 34'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x38 (
  output wire [37:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [37:0] wdata
);

reg [37:0] mem [0:127];
reg [37:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 38'd0;
    end
    qa_reg = 38'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x42 (
  output wire [41:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [41:0] wdata
);

reg [41:0] mem [0:127];
reg [41:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 42'd0;
    end
    qa_reg = 42'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x46 (
  output wire [45:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [45:0] wdata
);

reg [45:0] mem [0:127];
reg [45:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 46'd0;
    end
    qa_reg = 46'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x50 (
  output wire [49:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [49:0] wdata
);

reg [49:0] mem [0:127];
reg [49:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 50'd0;
    end
    qa_reg = 50'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x52 (
  output wire [51:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [51:0] wdata
);

reg [51:0] mem [0:127];
reg [51:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 52'd0;
    end
    qa_reg = 52'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x56 (
  output wire [55:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [55:0] wdata
);

reg [55:0] mem [0:127];
reg [55:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 56'd0;
    end
    qa_reg = 56'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x58 (
  output wire [57:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [57:0] wdata
);

reg [57:0] mem [0:127];
reg [57:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 58'd0;
    end
    qa_reg = 58'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x62 (
  output wire [61:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [61:0] wdata
);

reg [61:0] mem [0:127];
reg [61:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 62'd0;
    end
    qa_reg = 62'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x64 (
  output wire [63:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [63:0] wdata
);

reg [63:0] mem [0:127];
reg [63:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 64'd0;
    end
    qa_reg = 64'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x68 (
  output wire [67:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [67:0] wdata
);

reg [67:0] mem [0:127];
reg [67:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 68'd0;
    end
    qa_reg = 68'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x70 (
  output wire [69:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [69:0] wdata
);

reg [69:0] mem [0:127];
reg [69:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 70'd0;
    end
    qa_reg = 70'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x72 (
  output wire [71:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [71:0] wdata
);

reg [71:0] mem [0:127];
reg [71:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 72'd0;
    end
    qa_reg = 72'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x76 (
  output wire [75:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [75:0] wdata
);

reg [75:0] mem [0:127];
reg [75:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 76'd0;
    end
    qa_reg = 76'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x78 (
  output wire [77:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [77:0] wdata
);

reg [77:0] mem [0:127];
reg [77:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 78'd0;
    end
    qa_reg = 78'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x80 (
  output wire [79:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [79:0] wdata
);

reg [79:0] mem [0:127];
reg [79:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 80'd0;
    end
    qa_reg = 80'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x82 (
  output wire [81:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [81:0] wdata
);

reg [81:0] mem [0:127];
reg [81:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 82'd0;
    end
    qa_reg = 82'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x84 (
  output wire [83:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [83:0] wdata
);

reg [83:0] mem [0:127];
reg [83:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 84'd0;
    end
    qa_reg = 84'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x86 (
  output wire [85:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [85:0] wdata
);

reg [85:0] mem [0:127];
reg [85:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 86'd0;
    end
    qa_reg = 86'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x88 (
  output wire [87:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [87:0] wdata
);

reg [87:0] mem [0:127];
reg [87:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 88'd0;
    end
    qa_reg = 88'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x90 (
  output wire [89:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [89:0] wdata
);

reg [89:0] mem [0:127];
reg [89:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 90'd0;
    end
    qa_reg = 90'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x92 (
  output wire [91:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [91:0] wdata
);

reg [91:0] mem [0:127];
reg [91:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 92'd0;
    end
    qa_reg = 92'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x94 (
  output wire [93:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [93:0] wdata
);

reg [93:0] mem [0:127];
reg [93:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 94'd0;
    end
    qa_reg = 94'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x96 (
  output wire [95:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [95:0] wdata
);

reg [95:0] mem [0:127];
reg [95:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 96'd0;
    end
    qa_reg = 96'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x98 (
  output wire [97:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [97:0] wdata
);

reg [97:0] mem [0:127];
reg [97:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 98'd0;
    end
    qa_reg = 98'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x100 (
  output wire [99:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [99:0] wdata
);

reg [99:0] mem [0:127];
reg [99:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 100'd0;
    end
    qa_reg = 100'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_128x102 (
  output wire [101:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [6:0] raddr,
  input wire [6:0] waddr,
  input wire [101:0] wdata
);

reg [101:0] mem [0:127];
reg [101:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
        mem[i] = 102'd0;
    end
    qa_reg = 102'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_272x30 (
  output wire [29:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [8:0] raddr,
  input wire [8:0] waddr,
  input wire [29:0] wdata
);

reg [29:0] mem [0:271];
reg [29:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 272; i = i + 1) begin
        mem[i] = 30'd0;
    end
    qa_reg = 30'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_528x62 (
  output wire [61:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [9:0] raddr,
  input wire [9:0] waddr,
  input wire [61:0] wdata
);

reg [61:0] mem [0:527];
reg [61:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 528; i = i + 1) begin
        mem[i] = 62'd0;
    end
    qa_reg = 62'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_32x102 (
  output wire [101:0] rdata,
  input wire clk,
  input wire re_n,
  input wire we_n,
  input wire [4:0] raddr,
  input wire [4:0] waddr,
  input wire [101:0] wdata
);

reg [101:0] mem [0:31];
reg [101:0] qa_reg;

assign rdata = qa_reg;

initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        mem[i] = 102'd0;
    end
    qa_reg = 102'd0;
end

always @(posedge clk) begin
    if (!we_n) begin
        mem[waddr] <= wdata;
    end
    if (!re_n) begin
        qa_reg <= mem[raddr];
    end
end

endmodule

module sram_dp_16x16 (
    output reg [15:0] dout_b,
    input      [3:0] addr_a,
    input      [15:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [3:0] addr_b,
    input en_b
);
    reg [15:0] mem [0:15];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule

module sram_dp_64x128 (
    output reg [127:0] dout_b,
    input      [5:0] addr_a,
    input      [127:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [5:0] addr_b,
    input en_b
);
    reg [127:0] mem [0:63];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule

module sram_dp_64x160 (
    output reg [159:0] dout_b,
    input      [5:0] addr_a,
    input      [159:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [5:0] addr_b,
    input en_b
);
    reg [159:0] mem [0:63];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule

module sram_dp_128x128_a (
    output reg [127:0] dout_b,
    input      [6:0] addr_a,
    input      [127:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [6:0] addr_b,
    input en_b
);
    reg [127:0] mem [0:127];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule

module sram_dp_128x128_b (
    output reg [127:0] dout_b,
    input      [6:0] addr_a,
    input      [127:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [6:0] addr_b,
    input en_b
);
    reg [127:0] mem [0:127];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule

module sram_dp_128x160 (
    output reg [159:0] dout_b,
    input      [6:0] addr_a,
    input      [159:0] din_a,
    input we_a,
    input en_a,
    input clk,
    input      [6:0] addr_b,
    input en_b
);
    reg [159:0] mem [0:127];
    always @(posedge clk) begin
        if (en_a && we_a) mem[addr_a] <= din_a;
        if (en_b)        dout_b        <= mem[addr_b];
    end
endmodule
