// SPDX-License-Identifier: Apache-2.0

`ifndef DMA_VCS
`timescale 1ns/1ps
`endif
module dma_top
# (
  parameter AXI_CHANNELS = 32,
  parameter ADDR_WIDTH   = 64,
  parameter DATA_WIDTH   = 256
)
(
  input wire                    clk,
  input wire                    rst_n,
  input  wire                               start_read,
  input  wire [7:0]                         read_burst_length,
  input  wire [ADDR_WIDTH-1:0]              read_init_addr,
  input  wire                               read_rdy,

  output wire                               read_vld,
  output wire [DATA_WIDTH*AXI_CHANNELS-1:0] read_data,
  output wire                               read_done,
  output wire                               read_error,

  input wire                               start_write,
  input wire [7:0]                         write_burst_length,
  input wire [ADDR_WIDTH-1:0]              write_init_addr,
  input wire                               write_vld,
  input wire [DATA_WIDTH*AXI_CHANNELS-1:0] write_data,

  output wire                              write_done,
  output wire                              waddr_rdy,
  output wire                              write_rdy,
  output wire                              write_beat_accept,
  output wire                              write_error,

  output wire [AXI_CHANNELS-1:0]              hbm_axi_clk,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_arstn,

  output wire [AXI_CHANNELS-1:0]              hbm_axi_arvalid,
  output wire [ADDR_WIDTH*AXI_CHANNELS-1:0]   hbm_axi_araddr,
  output wire [8*AXI_CHANNELS-1:0]            hbm_axi_arlen,
  output wire [3*AXI_CHANNELS-1:0]            hbm_axi_arsize,
  output wire [2*AXI_CHANNELS-1:0]            hbm_axi_arburst,
  input  wire [AXI_CHANNELS-1:0]              hbm_axi_arready,

  input  wire [AXI_CHANNELS-1:0]              hbm_axi_rvalid,
  input  wire [DATA_WIDTH*AXI_CHANNELS-1:0]   hbm_axi_rdata,
  input  wire [AXI_CHANNELS-1:0]              hbm_axi_rlast,
  input  wire [2*AXI_CHANNELS-1:0]            hbm_axi_rresp,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_rready,

  output wire [ADDR_WIDTH*AXI_CHANNELS-1:0]   hbm_axi_awaddr,
  output wire [2*AXI_CHANNELS-1:0]            hbm_axi_awburst,
  output wire [8*AXI_CHANNELS-1:0]            hbm_axi_awlen,
  output wire [3*AXI_CHANNELS-1:0]            hbm_axi_awsize,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_awvalid,
  input  wire [AXI_CHANNELS-1:0]              hbm_axi_awready,

  output wire [DATA_WIDTH*AXI_CHANNELS-1:0]   hbm_axi_wdata,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_wlast,
  output wire [AXI_CHANNELS*DATA_WIDTH/8-1:0] hbm_axi_wstrb,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_wvalid,
  input  wire [AXI_CHANNELS-1:0]              hbm_axi_wready,
  input  wire [2*AXI_CHANNELS-1:0]            hbm_axi_bresp,
  output wire [AXI_CHANNELS-1:0]              hbm_axi_bready,
  input  wire [AXI_CHANNELS-1:0]              hbm_axi_bvalid
);

  localparam MEM_BACKEND_EFF = 0;
localparam AGG_DW = DATA_WIDTH*AXI_CHANNELS;

genvar i;
wire [AXI_CHANNELS-1:0] read_done_w;
wire [AXI_CHANNELS-1:0] read_error_w;

wire [AXI_CHANNELS-1:0] write_done_w;
wire [AXI_CHANNELS-1:0] waddr_rdy_w;
wire [AXI_CHANNELS-1:0] write_rdy_w;
wire [AXI_CHANNELS-1:0] write_error_w;

generate
for(i=0 ; i<AXI_CHANNELS ; i=i+1)
begin : GENERATE_CLOCKING
    assign hbm_axi_clk[i] = clk;
    assign hbm_axi_arstn[i]= rst_n;
end
endgenerate

wire all_write_rdy;
assign all_write_rdy   = &write_rdy_w;

wire hbm_ar_start;
wire hbm_aw_start;

wire [DATA_WIDTH-1:0] read_dats [AXI_CHANNELS-1:0];
wire [AXI_CHANNELS-1:0] read_vlds;
wire [AGG_DW-1:0] hbm_read_data_w;

wire gated_read_rdy = (&read_vlds) & read_rdy;

generate
for(i=0 ; i< AXI_CHANNELS ; i=i+1)
    begin : GENERATE_READ_WIRING
        assign hbm_read_data_w[DATA_WIDTH*i+:DATA_WIDTH] = read_dats[i];
    end
endgenerate

generate
for(i=0; i<AXI_CHANNELS; i=i+1)
begin : GENERATE_HBM_CHANNLE_VERIFY
  dma_auto_read # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_dma_auto_read
  (
    .clk(clk),
    .rst_n(rst_n),

    .start_read(hbm_ar_start),
    .burst_length(read_burst_length),
    .init_addr(read_init_addr),
    .read_rdy(gated_read_rdy),

    .m_axi_ARVALID(hbm_axi_arvalid[i]),
    .m_axi_ARADDR(hbm_axi_araddr[ADDR_WIDTH*i+:ADDR_WIDTH]),
    .m_axi_ARLEN(hbm_axi_arlen[i*8+:8]),
    .m_axi_ARSIZE(hbm_axi_arsize[i*3+:3]),
    .m_axi_ARBURST(hbm_axi_arburst[i*2+:2]),
    .m_axi_ARREADY(hbm_axi_arready[i]),

    .m_axi_RVALID(hbm_axi_rvalid[i]),
    .m_axi_RDATA(hbm_axi_rdata[i*DATA_WIDTH+:DATA_WIDTH]),
    .m_axi_RLAST(hbm_axi_rlast[i]),
    .m_axi_RRESP(hbm_axi_rresp[i*2+:2]),
    .m_axi_RREADY(hbm_axi_rready[i]),

    .read_vld(read_vlds[i]),
    .read_data(read_dats[i]),
    .read_done(read_done_w[i]),
    .read_error(read_error_w[i])
  );

  dma_custom_write # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_dma_custom_write
  (
    .clk(clk),
    .rst_n(rst_n),

    .write_vld(write_vld),
    .all_write_rdy(all_write_rdy),

    .start_write(hbm_aw_start),
    .burst_length(write_burst_length),
    .init_addr(write_init_addr),
    .write_data(write_data[DATA_WIDTH*i+:DATA_WIDTH]),

    .m_axi_AWVALID(hbm_axi_awvalid[i]),
    .m_axi_AWADDR(hbm_axi_awaddr[ADDR_WIDTH*i+:ADDR_WIDTH]),
    .m_axi_AWLEN(hbm_axi_awlen[i*8+:8]),
    .m_axi_AWSIZE(hbm_axi_awsize[i*3+:3]),
    .m_axi_AWBURST(hbm_axi_awburst[i*2+:2]),
    .m_axi_AWREADY(hbm_axi_awready[i]),

    .m_axi_WVALID(hbm_axi_wvalid[i]),
    .m_axi_WDATA(hbm_axi_wdata[i*DATA_WIDTH+:DATA_WIDTH]),
    .m_axi_WSTRB(hbm_axi_wstrb[i*(DATA_WIDTH/8)+:(DATA_WIDTH/8)]),
    .m_axi_WLAST(hbm_axi_wlast[i]),
    .m_axi_WREADY(hbm_axi_wready[i]),

    .m_axi_BVALID(hbm_axi_bvalid[i]),
    .m_axi_BRESP(hbm_axi_bresp[i*2+:2]),
    .m_axi_BREADY(hbm_axi_bready[i]),

    .write_done(write_done_w[i]),
    .write_error(write_error_w[i]),
    .waddr_rdy(waddr_rdy_w[i]),
    .write_rdy(write_rdy_w[i])
  );

end
endgenerate

generate
if (MEM_BACKEND_EFF == 0) begin : g_backend_hbm
  assign hbm_ar_start = start_read;
  assign hbm_aw_start = start_write;

  assign read_done  = &read_done_w;
  assign read_error = (read_error_w != 0);
  assign read_vld   = &read_vlds;
  assign read_data  = hbm_read_data_w;

  assign write_done  = &write_done_w;
  assign waddr_rdy   = &waddr_rdy_w;
  assign write_rdy   = all_write_rdy;
  assign write_beat_accept = &(hbm_axi_wvalid & hbm_axi_wready);
  assign write_error = (write_error_w != 0);

end
endgenerate

endmodule
