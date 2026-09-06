// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`ifndef __RAM_2D_COMMON_V__
`define __RAM_2D_COMMON_V__
module ram_2d
# (
    parameter num_rams = 1,
    parameter w = 2048,
    parameter d = 128
)
(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             wen,
    input  wire [num_rams*$clog2(d)-1:0]    write_addr,
    input  wire [num_rams*w-1:0]            din,
    input  wire                             ren,
    input  wire [num_rams*$clog2(d)-1:0]    read_addr,
    output wire [num_rams*$clog2(d)-1:0]    read_addr_r,
    output wire                             dout_vld,
    output wire [num_rams*w-1:0]            dout
);
    genvar i;

    wire [$clog2(d)-1:0] write_addrs[num_rams-1:0];
    wire [w-1:0] dins[num_rams-1:0];

    wire [$clog2(d)-1:0] read_addrs[num_rams-1:0];
    reg [$clog2(d)-1:0] read_addrs_r[num_rams-1:0];
    wire [w-1:0] douts[num_rams-1:0];

    reg dout_vld_r;
    reg ren_r;
    wire [num_rams-1:0] vendor_rvalid_vec;
    wire vendor_rvalid_any = |vendor_rvalid_vec;
    wire clk_wire = clk;
    wire rst_n_wire = rst_n;
    wire ren_wire = ren;
    wire dout_vld_wire = dout_vld_r;
    always @(posedge clk_wire)
    if(!rst_n_wire) begin
        ren_r      <= 1'b0;
        dout_vld_r <= 1'b0;
    end
    else begin
`ifdef USE_VENDOR_SRAM
        if ((w == 2048) && ((d == 128) || (d == 64))) begin
            dout_vld_r <= vendor_rvalid_any;
        end else begin
            ren_r      <= ren_wire;
            dout_vld_r <= ren_r;
        end
`else
        ren_r      <= ren_wire;
        dout_vld_r <= ren_r;
`endif
    end
    assign dout_vld = dout_vld_wire;

generate
for(i=0 ; i<num_rams ; i=i+1)
begin : GENERATE_WIRING
    assign write_addrs[i] = write_addr[($clog2(d)*i + $clog2(d)-1) : ($clog2(d)*i)];
    assign dins[i] = din[(w*i + w-1) : (w*i)];
    assign read_addrs[i] = read_addr[($clog2(d)*i + $clog2(d)-1) : ($clog2(d)*i)];
    assign read_addr_r[($clog2(d)*i + $clog2(d)-1) : ($clog2(d)*i)] = read_addrs_r[i];
    assign dout[(w*i + w-1) : (w*i)] = douts[i];
end

for(i=0 ; i<num_rams ; i=i+1)
begin : GENERATE_DELAY_ADDR
    wire clk_delay_wire = clk;
    wire rst_n_delay_wire = rst_n;
    always @(posedge clk_delay_wire)
    if(!rst_n_delay_wire) begin
        read_addrs_r[i] <= 1'b0;
    end
    else begin
        read_addrs_r[i] <= read_addrs[i];
    end
end

for(i=0 ; i<num_rams ; i=i+1)
begin : GENERATE_RAMS
`ifdef USE_VENDOR_SRAM
    if ((w == 2048) && ((d == 128) || (d == 64))) begin : GEN_SRAM_BANK
        wire [w-1:0] rdata_i;
        wire         rvalid_i;
        reg  [w-1:0] douts_pipe_i;

        accum_buffer_sram #(
            .DATA_WIDTH(16),
            .DATA_NUM  (128),
            .BUFFER_ADDR(d)
        ) u_accum_sram (
            .clk   (clk),
            .rst_n (rst_n),
            .wen   (wen),
            .waddr (write_addrs[i]),
            .write_precision(4'b0000),
            .wdata (dins[i]),
            .wvalid(wen),
            .write_done(),
            .ren   (ren),
            .raddr (read_addrs[i]),
            .read_precision(4'b0000),
            .rdata (rdata_i),
            .rvalid(rvalid_i),
            .read_done()
        );

        always @(posedge clk)
        if(!rst_n) begin
            douts_pipe_i <= {w{1'b0}};
        end
        else if (rvalid_i) begin
            douts_pipe_i <= rdata_i;
        end
        assign douts[i] = douts_pipe_i;
        assign vendor_rvalid_vec[i] = rvalid_i;
    end else begin : GEN_DW_FALLBACK
        wire cs_n_i;
        wire wr_n_i;
        assign cs_n_i = ~(wen | ren);
        assign wr_n_i = ~wen;

        wire [w-1:0] douts_mem_i;
        reg  [w-1:0] douts_pipe_i;

        DW_ram_r_w_s_dff_inst #(
          .data_width(w),
          .depth(d),
          .rst_mode(0)
        ) u_dw_ram (
          .inst_clk(clk),
          .inst_rst_n(rst_n),
          .inst_cs_n(cs_n_i),
          .inst_wr_n(wr_n_i),
          .inst_rd_addr(read_addrs[i]),
          .inst_wr_addr(write_addrs[i]),
          .inst_data_in(dins[i]),
          .data_out_inst(douts_mem_i)
        );

        always @(posedge clk)
        if(!rst_n) begin
            douts_pipe_i <= {w{1'b0}};
        end
        else if (ren) begin
            douts_pipe_i <= douts_mem_i;
        end

        assign douts[i] = douts_pipe_i;
        assign vendor_rvalid_vec[i] = 1'b0;
    end
`else
    wire cs_n_i;
    wire wr_n_i;
    wire wen_wire = wen;
    wire ren_wire = ren;
    assign cs_n_i = ~(wen_wire | ren_wire);
    assign wr_n_i = ~wen_wire;

    wire [w-1:0] douts_mem_i;
    reg  [w-1:0] douts_pipe_i;

    DW_ram_r_w_s_dff_inst #(
      .data_width(w),
      .depth(d),
      .rst_mode(0)
    ) u_dw_ram (
      .inst_clk(clk),
      .inst_rst_n(rst_n),
      .inst_cs_n(cs_n_i),
      .inst_wr_n(wr_n_i),
      .inst_rd_addr(read_addrs[i]),
      .inst_wr_addr(write_addrs[i]),
      .inst_data_in(dins[i]),
      .data_out_inst(douts_mem_i)
    );

    wire clk_pipe_wire = clk;
    wire rst_n_pipe_wire = rst_n;
    wire ren_pipe_wire = ren;
    always @(posedge clk_pipe_wire)
    if(!rst_n_pipe_wire) begin
        douts_pipe_i <= {w{1'b0}};
    end
    else if (ren_pipe_wire) begin
        douts_pipe_i <= douts_mem_i;
    end

    assign douts[i] = douts_pipe_i;
    assign vendor_rvalid_vec[i] = 1'b0;
`endif
end
endgenerate

endmodule

`endif
