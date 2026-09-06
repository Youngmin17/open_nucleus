// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype none
`ifndef __VECTOR_REGISTER_FILE_V__
`define __VECTOR_REGISTER_FILE_V__
`ifdef VENDOR_MACRO
module vector_register_file
#(
    parameter integer DIM = 128,
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH_ROWS = 64
)
(
    input wire clk,
    input wire rst_n,

    input  wire                  residual_load,
    input  wire                  prog_en,
    input  wire [$clog2(DEPTH_ROWS)-2:0] prog_addr,
    input  wire [DIM*DATA_WIDTH-1:0]     prog_data,

    input  wire                  rd_en,
    input  wire [$clog2(DEPTH_ROWS)-2:0] rd_addr,
    output wire                 rd_vld,
    output wire [DIM*DATA_WIDTH-1:0]     rd_data
);

    localparam integer NUM_160_MACROS = (DIM*DATA_WIDTH) / 160;

    wire [DIM*DATA_WIDTH-1:0] ram_dout;
    reg ram_dout_vld;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_dout_vld <= 1'b0;
        end else begin
            if (rd_en) begin
                ram_dout_vld <= 1'b1;
            end else begin
                ram_dout_vld <= 1'b0;
            end
        end
    end

    assign rd_vld  = ram_dout_vld;
    assign rd_data = ram_dout;
    wire read_buf_sel_eff = 1'b0;

    genvar gi;
    generate
        if (DEPTH_ROWS == 64) begin : gen_mem_160_depth64
            for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_mem_160_64
                sram_dp_64x160 u_mem_160 (
                    .dout_b  (ram_dout[(160*gi+159):(160*gi)]),
                    .addr_a  ({1'b0, prog_addr[4:0]}),
                    .din_a   (prog_data[(160*gi+159):(160*gi)]),
                    .we_a    (prog_en),
                    .en_a    (rst_n),
                    .clk     (clk),
                    .addr_b  ({1'b0, rd_addr[4:0]}),
                    .en_b    (rst_n)
                );
            end
        end else begin : gen_mem_160_depth128
            for (gi = 0; gi < NUM_160_MACROS; gi = gi + 1) begin : gen_mem_160_128
                sram_dp_128x160 u_mem_160 (
                    .dout_b  (ram_dout[(160*gi+159):(160*gi)]),
                    .addr_a  ({2'b0, prog_addr[4:0]}),
                    .din_a   (prog_data[(160*gi+159):(160*gi)]),
                    .we_a    (prog_en),
                    .en_a    (rst_n),
                    .clk     (clk),
                    .addr_b  ({2'b0, rd_addr[4:0]}),
                    .en_b    (rst_n)
                );
            end
        end
    endgenerate

    generate
        if (DEPTH_ROWS == 64) begin : gen_mem_128_depth64
            sram_dp_64x128 u_mem_128 (
                .dout_b  (ram_dout[(160*NUM_160_MACROS+127):(160*NUM_160_MACROS)]),
                .addr_a  ({1'b0, prog_addr[4:0]}),
                .din_a   (prog_data[(160*NUM_160_MACROS+127):(160*NUM_160_MACROS)]),
                .we_a    (prog_en),
                .en_a    (rst_n),
                .clk     (clk),
                .addr_b  ({1'b0, rd_addr[4:0]}),
                .en_b    (rst_n)
            );
        end else begin : gen_mem_128_depth128
            sram_dp_128x128_a u_mem_128 (
                .dout_b  (ram_dout[(160*NUM_160_MACROS+127):(160*NUM_160_MACROS)]),
                .addr_a  ({2'b0, prog_addr[4:0]}),
                .din_a   (prog_data[(160*NUM_160_MACROS+127):(160*NUM_160_MACROS)]),
                .we_a    (prog_en),
                .en_a    (rst_n),
                .clk     (clk),
                .addr_b  ({2'b0, rd_addr[4:0]}),
                .en_b    (rst_n)
            );
        end
    endgenerate

endmodule

`elsif EMU_SINGLE_CORE
module vector_register_file
#(
    parameter integer DECODE_CORE_NUM = 1,
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
    reg [$clog2(DEPTH_ROWS):0] write_addr, read_addr;
    reg [DIM*DATA_WIDTH-1:0] write_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_enable <= 1'b0;
            read_enable  <= 1'b0;
            write_addr   <= {($clog2(DEPTH_ROWS)+1){1'b0}};
            read_addr    <= {($clog2(DEPTH_ROWS)+1){1'b0}};
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
        end else if (DEPTH_ROWS == 64) begin
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

`else
module vector_register_file
#(
    parameter integer DECODE_CORE_NUM = 32,
    parameter integer DIM = 128,
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH_ROWS = 64
)
(
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire is_proj_mode,
    input wire [8:0] hidden_dim,
    input wire [7:0] batch_num,
    input wire [8:0] k_replay_tiles,

    input  wire                 prog_en,
    input  wire [8192-1:0]      prog_data,

    input  wire                 rd_en,
    output reg                  rd_vld,
    output reg [8192-1:0]       rd_data
);

    localparam integer ROW_W = 8192;

    wire [6:0] token_stride = (hidden_dim + 9'd3) >> 2;

    reg [5:0]       wr_row_mem;

    wire             sram_wen   = prog_en;
    wire [5:0]       sram_waddr = wr_row_mem;
    wire [ROW_W-1:0] sram_wdata = prog_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_row_mem     <= 6'd0;
        end else begin
            if (isa_valid) begin
                wr_row_mem     <= 6'd0;
            end
            if (prog_en && is_proj_mode) begin
                wr_row_mem <= wr_row_mem + 1'b1;
            end
        end
    end

    wire [5:0] group_count = (batch_num + 8'd3) >> 2;
    wire [2:0] last_g_size = (batch_num[1:0] == 2'd0) ? 3'd4 : {1'b0, batch_num[1:0]};

    localparam [1:0] RD_IDLE = 2'd0,
                     RD_ACQ  = 2'd1,
                     RD_EMIT = 2'd2;

    reg [1:0]        rd_state;
    reg [2:0]        iss_cnt;
    reg [4:0]        cap_cnt;
    reg [2:0]        g_size_r;
    reg [5:0]        g_idx;
    reg [8:0]        ci;
    reg [8:0]        k_replay_limit;
    reg [8:0]        k_replay_cnt;
    reg [5:0]        group_base;
    reg [5:0]        tok_base;
    reg [2048-1:0]   cap [15:0];

    reg              sram_ren;
    reg  [5:0]       sram_raddr;
    wire [ROW_W-1:0] sram_rdata;
    wire             sram_rvalid;

    wire [1:0] ci_lo = ci[1:0];
    wire [6:0] ci_hi = ci[8:2];
    wire [8:0] k_replay_tiles_eff = (k_replay_tiles == 9'd0) ? 9'd1
                                                               : k_replay_tiles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state    <= RD_IDLE;
            iss_cnt     <= 3'd0;
            cap_cnt     <= 5'd0;
            g_size_r    <= 3'd0;
            g_idx       <= 6'd0;
            ci          <= 9'd0;
            k_replay_limit <= 9'd1;
            k_replay_cnt   <= 9'd0;
            group_base  <= 6'd0;
            tok_base    <= 6'd0;
            for (int i = 0; i < 16; i = i + 1) begin
                cap[i] <= {2048{1'b0}};
            end
            sram_ren    <= 1'b0;
            sram_raddr  <= 6'd0;
            rd_vld      <= 1'b0;
            rd_data     <= {ROW_W{1'b0}};

        end else begin
            rd_vld   <= 1'b0;
            sram_ren <= 1'b0;

            if (isa_valid) begin
                rd_state   <= RD_IDLE;
                iss_cnt    <= 3'd0;
                cap_cnt    <= 5'd0;
                g_idx      <= 6'd0;
                ci         <= 9'd0;
                k_replay_limit <= 9'd1;
                k_replay_cnt   <= 9'd0;
                group_base <= 6'd0;
                tok_base   <= 6'd0;
                for (int i = 0; i < 16; i = i + 1) begin
                    cap[i] <= {2048{1'b0}};
                end

            end else begin
                case (rd_state)
                    RD_IDLE: begin
                        if (is_proj_mode) begin
                            if (rd_en && (batch_num != 8'd0)) begin
                                if ((ci == 9'd0) && (k_replay_cnt == 9'd0)) begin
                                    k_replay_limit <= k_replay_tiles_eff;
                                end
                                iss_cnt  <= 3'd0;
                                cap_cnt  <= 5'd0;
                                tok_base <= group_base;
                                for (int i = 0; i < 16; i = i + 1) begin
                                    cap[i] <= {2048{1'b0}};
                                end
                                rd_state <= RD_ACQ;
                            end
                        end else begin
                            sram_ren <= rd_en;
                            sram_raddr <= 6'b0;
                            if(sram_rvalid) begin
                                rd_vld  <= 1'b1;
                                rd_data <= sram_rdata;
                            end
                        end
                    end
                    RD_ACQ: begin
                        if (iss_cnt < batch_num) begin
                            sram_ren   <= 1'b1;
                            sram_raddr <= tok_base + iss_cnt * token_stride[5:0];
                            iss_cnt    <= iss_cnt + 1'b1;
                        end
                        if (sram_rvalid) begin
                            cap[cap_cnt[3:0]]  <= sram_rdata[2048*ci_lo +: 2048];
                            cap_cnt <= cap_cnt + 1'b1;
                            if (cap_cnt == batch_num - 8'd1) begin
                                rd_state <= RD_EMIT;
                                cap_cnt  <= 5'd0;
                            end
                        end
                    end
                    RD_EMIT: begin
                        rd_vld  <= 1'b1;
                        rd_data <= {cap[(cap_cnt<<2)+3], cap[(cap_cnt<<2)+2], cap[(cap_cnt<<2)+1], cap[(cap_cnt<<2)]};
                        cap_cnt <= cap_cnt + 1'b1;
                        if(cap_cnt == group_count - 6'd1) begin
                            cap_cnt <= 5'd0;
                            if (k_replay_cnt == k_replay_limit - 9'd1) begin
                                k_replay_cnt <= 9'd0;
                                if (ci == hidden_dim - 9'd1) begin
                                    ci <= 9'd0;
                                    if (g_idx == 6'd3) begin
                                        g_idx      <= 6'd0;
                                        group_base <= group_base + 6'd1;
                                        if(group_base == token_stride - 6'd1) begin
                                            group_base <= 6'd0;
                                        end
                                    end else begin
                                        g_idx      <= g_idx + 1'b1;
                                    end
                                end else begin
                                    ci <= ci + 1'b1;
                                end
                            end else begin
                                k_replay_cnt <= k_replay_cnt + 9'd1;
                            end
                            rd_state <= RD_IDLE;
                        end
                    end
                    default: rd_state <= RD_IDLE;
                endcase
            end
        end
    end

    sram_64x8192_wrapper u_sram (
        .clk    (clk),
        .rst_n  (rst_n),
        .wen    (sram_wen),
        .waddr  (sram_waddr),
        .wdata  (sram_wdata),
        .ren    (sram_ren),
        .raddr  (sram_raddr),
        .rdata  (sram_rdata),
        .rvalid (sram_rvalid)
    );

endmodule

`endif

`default_nettype wire

`endif
