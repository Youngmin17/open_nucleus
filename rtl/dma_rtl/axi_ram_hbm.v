/*
 * Derived from axi_ram.v of the verilog-axi project
 * (https://github.com/alexforencich/verilog-axi).
 * Copyright (c) 2018 Alex Forencich.
 * Modifications Copyright 2026 Youngmin17.
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

`timescale 1ns / 1ps
`default_nettype none

module axi_ram_hbm #
(
    parameter MAX_BURST_LEN = 128,
    parameter CHECK_WLAST = 1,
    parameter START_ADDR = 0,
    parameter DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 64,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter MEM_DEPTH = 2**(29 - $clog2(STRB_WIDTH)),
    parameter BUFFER = 16383,
    parameter LATENCY = 70,
    parameter PROBABILITY = 1000
)
(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,
    output wire [DATA_WIDTH-1:0]  s_axi_rdata,
    output wire                   s_axi_rlast,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready
);

always @(posedge clk) begin
    if (s_axi_awvalid == 1'b1 && s_axi_awlen >= MAX_BURST_LEN) begin
        $error("Error: s_axi_awlen exceed maximum burst length! \n");
        $finish;
    end
    if (s_axi_arvalid == 1'b1 && s_axi_arlen >= MAX_BURST_LEN) begin
        $error("Error: s_axi_arlen exceed maximum burst length! \n");
        $finish;
    end
end

integer i, j;
reg s_axi_awready_reg = 1'b0, s_axi_awready_next;
reg [ADDR_WIDTH-1:0] awaddr_buf [0:16383];
reg [7:0] awlen_buf [0:16383];
reg [13:0] aw_read=14'd0, aw_write=14'd0;
reg [13:0] aw_valid_count=14'd0;
wire [ADDR_WIDTH-1:0] aw_buffer_addr;
wire [7:0] aw_buffer_len;
wire aw_buffer_valid;
wire aw_buffer_write = (s_axi_awvalid == 1'b1 && aw_valid_count < BUFFER && (aw_valid_count != 0 || s_axi_awready_reg == 1'b0)) ? 1'b1 : 1'b0;
wire aw_buffer_read = (aw_valid_count != 0 && aw_buffer_valid == 1'b1 && s_axi_awready_reg == 1'b1) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if (!rst_n) begin
        for(i=0; i<8192; i=i+1) begin
            awaddr_buf[i] <= {ADDR_WIDTH{1'd0}};
            awlen_buf[i] <= 8'd0;
        end
        aw_read <= 14'd0;
        aw_write <= 14'd0;
        aw_valid_count <= 14'd0;
    end
    else begin
        if (aw_buffer_write) begin
            awaddr_buf[aw_write] <= s_axi_awaddr;
            awlen_buf[aw_write] <= s_axi_awlen;
            aw_write <= aw_write + 1;
        end
        if (aw_buffer_read) begin
            aw_read <= aw_read + 1;
        end
        if ({aw_buffer_write, aw_buffer_read} == 2'b10) aw_valid_count <= aw_valid_count + 1;
        else if ({aw_buffer_write, aw_buffer_read} == 2'b01) aw_valid_count <= aw_valid_count - 1;
    end
end
assign aw_buffer_addr = (aw_valid_count == 0) ? s_axi_awaddr : awaddr_buf[aw_read];
assign aw_buffer_len = (aw_valid_count == 0) ? s_axi_awlen : awlen_buf[aw_read];
assign aw_buffer_valid = (aw_valid_count == 0) ? s_axi_awvalid : 1'b1;
assign #2 s_axi_awready = (aw_valid_count < BUFFER) ? 1'b1 : 1'b0;
reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
reg [ADDR_WIDTH-1:0] araddr_buf [0:16383];
reg [7:0] arlen_buf [0:16383];
reg [13:0] ar_read=14'd0, ar_write=14'd0;
reg [13:0] ar_valid_count=14'd0;
wire [ADDR_WIDTH-1:0] ar_buffer_addr;
wire [7:0] ar_buffer_len;
wire ar_buffer_valid;
wire ar_buffer_write = (s_axi_arvalid == 1'b1 && ar_valid_count < BUFFER && (ar_valid_count != 0 || s_axi_arready_reg == 1'b0)) ? 1'b1 : 1'b0;
wire ar_buffer_read = (ar_valid_count != 0 && ar_buffer_valid == 1'b1 && s_axi_arready_reg == 1'b1) ? 1'b1 : 1'b0;
always @(posedge clk) begin
    if (!rst_n) begin
        for(i=0; i<1024; i=i+1) begin
            araddr_buf[i] <= {ADDR_WIDTH{1'b0}};
            arlen_buf[i] <= 8'd0;
        end
        ar_read <= 14'd0;
        ar_write <= 14'd0;
        ar_valid_count <= 14'd0;
    end
    else begin
        if (ar_buffer_write) begin
            araddr_buf[ar_write] <= s_axi_araddr;
            arlen_buf[ar_write] <= s_axi_arlen;
            ar_write <= ar_write + 1;
        end
        if (ar_buffer_read) begin
            ar_read <= ar_read + 1;
        end
        if ({ar_buffer_write, ar_buffer_read} == 2'b10) ar_valid_count <= ar_valid_count + 1;
        else if ({ar_buffer_write, ar_buffer_read} == 2'b01) ar_valid_count <= ar_valid_count - 1;
    end
end
assign ar_buffer_addr = (ar_valid_count == 0) ? s_axi_araddr : araddr_buf[ar_read];
assign ar_buffer_len = (ar_valid_count == 0) ? s_axi_arlen : arlen_buf[ar_read];
assign ar_buffer_valid = (ar_valid_count == 0) ? s_axi_arvalid : 1'b1;

assign #2 s_axi_arready = (ar_valid_count < BUFFER) ? 1'b1 : 1'b0;

parameter VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

initial begin
    if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
        $error("Error: AXI data width not evenly divisble (instance %m)");
        $finish;
    end

    if (2**$clog2(WORD_WIDTH) != WORD_WIDTH) begin
        $error("Error: AXI word width must be even power of two (instance %m)");
        $finish;
    end
end

localparam [0:0]
    READ_STATE_IDLE = 1'd0,
    READ_STATE_BURST = 1'd1;

reg [0:0] read_state_reg = READ_STATE_IDLE, read_state_next;

localparam [1:0]
    WRITE_STATE_IDLE = 2'd0,
    WRITE_STATE_BURST = 2'd1,
    WRITE_STATE_RESP = 2'd2;

reg [1:0] write_state_reg = WRITE_STATE_IDLE, write_state_next;

reg mem_wr_en;
reg mem_rd_en;

reg [ADDR_WIDTH-1:0] read_addr_reg = {ADDR_WIDTH{1'b0}}, read_addr_next;
reg [7:0] read_count_reg = 8'd0, read_count_next;
reg [2:0] read_size_reg = $clog2(STRB_WIDTH), read_size_next;
reg [ADDR_WIDTH-1:0] write_addr_reg = {ADDR_WIDTH{1'b0}}, write_addr_next;
reg [7:0] write_count_reg = 8'd0, write_count_next;
reg [2:0] write_size_reg = $clog2(STRB_WIDTH), write_size_next;

reg s_axi_wready_reg = 1'b0, s_axi_wready_next;
reg s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;
reg [DATA_WIDTH-1:0] s_axi_rdata_reg = {DATA_WIDTH{1'b0}}, s_axi_rdata_next;
reg s_axi_rlast_reg = 1'b0, s_axi_rlast_next;
reg s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;

reg [DATA_WIDTH-1:0] mem[MEM_DEPTH-1:0];

wire [VALID_ADDR_WIDTH-1:0] read_addr_valid = (read_addr_reg - START_ADDR) >> (ADDR_WIDTH - VALID_ADDR_WIDTH);
wire [VALID_ADDR_WIDTH-1:0] write_addr_valid = (write_addr_reg - START_ADDR) >> (ADDR_WIDTH - VALID_ADDR_WIDTH);

assign #2 s_axi_wready = s_axi_wready_reg;
assign #2 s_axi_bvalid = s_axi_bvalid_reg;

reg [DATA_WIDTH-1:0] s_axi_rdata_pipe_reg [0:LATENCY-1];
reg [LATENCY-1:0] s_axi_rlast_pipe_reg = {LATENCY{1'b0}};
reg [LATENCY-1:0] s_axi_rvalid_pipe_reg = {LATENCY{1'b0}};
assign #2 s_axi_rdata = s_axi_rdata_pipe_reg[LATENCY-1];
assign #2 s_axi_rlast = s_axi_rlast_pipe_reg[LATENCY-1];
assign #2 s_axi_rvalid = s_axi_rvalid_pipe_reg[LATENCY-1];

initial begin
    for (i = 0; i < 2**VALID_ADDR_WIDTH; i = i + 2**(VALID_ADDR_WIDTH/2)) begin
        for (j = i; j < i + 2**(VALID_ADDR_WIDTH/2); j = j + 1) begin
            mem[j] = 0;
        end
    end
end

reg [31:0] write_probability;
always @(posedge clk) begin
    write_probability <= $urandom_range(0, 1000);
end

always @* begin
    write_state_next = WRITE_STATE_IDLE;

    mem_wr_en = 1'b0;

    write_addr_next = write_addr_reg;
    write_count_next = write_count_reg;
    write_size_next = write_size_reg;

    s_axi_awready_next = 1'b0;
    s_axi_wready_next = 1'b0;
    s_axi_bvalid_next = s_axi_bvalid_reg && !s_axi_bready;

    case (write_state_reg)
        WRITE_STATE_IDLE: begin
            s_axi_awready_next = 1'b1;

            if (s_axi_awready_reg && aw_buffer_valid) begin
                write_addr_next = aw_buffer_addr;
                write_count_next = aw_buffer_len;
                write_size_next = $clog2(STRB_WIDTH);

                s_axi_awready_next = 1'b0;
                if (write_probability < PROBABILITY) s_axi_wready_next = 1'b1;
                else s_axi_wready_next = 1'b0;
                write_state_next = WRITE_STATE_BURST;
            end else begin
                write_state_next = WRITE_STATE_IDLE;
            end
        end
        WRITE_STATE_BURST: begin
            if (s_axi_wready == 1'b1 && s_axi_wvalid ==1'b0) s_axi_wready_next = 1'b1;
            else begin
                if (write_probability < PROBABILITY) s_axi_wready_next = 1'b1;
                else s_axi_wready_next = 1'b0;
            end
            if (s_axi_wready && s_axi_wvalid) begin
                mem_wr_en = 1'b1;
                write_addr_next = write_addr_reg + (1 << write_size_reg);
                write_count_next = write_count_reg - 1;
                if (write_count_reg > 0) begin
                    write_state_next = WRITE_STATE_BURST;
                    if (CHECK_WLAST && s_axi_wlast == 1'b1) begin
                        $error("\n######################################################################\nError: AXI wlast signal should be 1'b0 if the data is not the last one\n######################################################################\n");
                        $finish;
                    end
                end else begin
                    if (CHECK_WLAST && s_axi_wlast == 1'b0) begin
                        $error("\n#################################################################\nError: AXI wlast signal should be 1'b1 when writing the last data\n#################################################################\n");
                        $finish;
                    end
                    s_axi_wready_next = 1'b0;
                    if (s_axi_bready || !s_axi_bvalid) begin
                        s_axi_bvalid_next = 1'b1;
                        s_axi_awready_next = 1'b1;
                        write_state_next = WRITE_STATE_IDLE;
                    end else begin
                        write_state_next = WRITE_STATE_RESP;
                    end
                end
            end else begin
                write_state_next = WRITE_STATE_BURST;
            end
        end
        WRITE_STATE_RESP: begin
            if (s_axi_bready || !s_axi_bvalid) begin
                s_axi_bvalid_next = 1'b1;
                s_axi_awready_next = 1'b1;
                write_state_next = WRITE_STATE_IDLE;
            end else begin
                write_state_next = WRITE_STATE_RESP;
            end
        end
    endcase
end

always @(posedge clk) begin
    write_state_reg <= write_state_next;

    write_addr_reg <= write_addr_next;
    write_count_reg <= write_count_next;
    write_size_reg <= write_size_next;

    s_axi_awready_reg <= s_axi_awready_next;
    s_axi_wready_reg <= s_axi_wready_next;
    s_axi_bvalid_reg <= s_axi_bvalid_next;

    for (i = 0; i < WORD_WIDTH; i = i + 1) begin
        if (mem_wr_en & s_axi_wstrb[i]) begin
            mem[write_addr_valid][WORD_SIZE*i +: WORD_SIZE] <= s_axi_wdata[WORD_SIZE*i +: WORD_SIZE];
        end
    end

    if (!rst_n) begin
        write_state_reg <= WRITE_STATE_IDLE;

        s_axi_awready_reg <= 1'b0;
        s_axi_wready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
    end
end

reg [31:0] read_probability;
always @(posedge clk) begin
    read_probability <= $urandom_range(0, 1000);
end

always @* begin
    read_state_next = READ_STATE_IDLE;

    mem_rd_en = 1'b0;

    s_axi_rlast_next = s_axi_rlast_reg;
    s_axi_rvalid_next = s_axi_rvalid_reg && !(s_axi_rready || (!{&s_axi_rvalid_pipe_reg}));

    read_addr_next = read_addr_reg;
    read_count_next = read_count_reg;
    read_size_next = read_size_reg;

    s_axi_arready_next = 1'b0;

    case (read_state_reg)
        READ_STATE_IDLE: begin
            s_axi_arready_next = 1'b1;

            if (s_axi_arready_reg && ar_buffer_valid) begin
                read_addr_next = ar_buffer_addr;
                read_count_next = ar_buffer_len;
                read_size_next = $clog2(STRB_WIDTH);

                s_axi_arready_next = 1'b0;
                read_state_next = READ_STATE_BURST;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_BURST: begin
            if (s_axi_rready || (!{&s_axi_rvalid_pipe_reg}) || !s_axi_rvalid_reg) begin
                if (read_probability < PROBABILITY) begin
                    mem_rd_en = 1'b1;
                    s_axi_rvalid_next = 1'b1;
                    s_axi_rlast_next = read_count_reg == 0;
                    read_addr_next = read_addr_reg + (1 << read_size_reg);
                    read_count_next = read_count_reg - 1;
                    if (read_count_reg > 0) begin
                        read_state_next = READ_STATE_BURST;
                    end else begin
                        s_axi_arready_next = 1'b1;
                        read_state_next = READ_STATE_IDLE;
                    end
                end
                else read_state_next = READ_STATE_BURST;
            end else begin
                read_state_next = READ_STATE_BURST;
            end
        end
    endcase
end

always @(posedge clk) begin
    read_state_reg <= read_state_next;

    read_addr_reg <= read_addr_next;
    read_count_reg <= read_count_next;
    read_size_reg <= read_size_next;

    s_axi_arready_reg <= s_axi_arready_next;
    s_axi_rlast_reg <= s_axi_rlast_next;
    s_axi_rvalid_reg <= s_axi_rvalid_next;

    if (mem_rd_en) begin
        s_axi_rdata_reg <= mem[read_addr_valid];
    end

    if (!rst_n) begin
        read_state_reg <= READ_STATE_IDLE;

        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_reg <= 1'b0;
    end
end

genvar k;
generate
    for(k=0; k<LATENCY; k=k+1) begin
        if (k==0) begin
            always @(posedge clk) begin
                if (!{&s_axi_rvalid_pipe_reg[LATENCY-1:k]} || s_axi_rready) begin
                    s_axi_rdata_pipe_reg[k] <= s_axi_rdata_reg;
                    s_axi_rlast_pipe_reg[k] <= s_axi_rlast_reg;
                    s_axi_rvalid_pipe_reg[k] <= s_axi_rvalid_reg;
                end
                if (!rst_n) s_axi_rvalid_pipe_reg[k] <= 1'b0;
            end
        end
        else begin
            always @(posedge clk) begin
                if (!{&s_axi_rvalid_pipe_reg[LATENCY-1:k]} || s_axi_rready) begin
                    s_axi_rdata_pipe_reg[k] <= s_axi_rdata_pipe_reg[k-1];
                    s_axi_rlast_pipe_reg[k] <= s_axi_rlast_pipe_reg[k-1];
                    s_axi_rvalid_pipe_reg[k] <= s_axi_rvalid_pipe_reg[k-1];
                end
                if (!rst_n) s_axi_rvalid_pipe_reg[k] <= 1'b0;
            end
        end
    end
endgenerate

endmodule