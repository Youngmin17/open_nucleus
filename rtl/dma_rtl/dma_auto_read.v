// SPDX-License-Identifier: Apache-2.0
`ifndef DMA_VCS
`timescale 1ns/1ps
`endif

module dma_auto_read
# (
    parameter ADDR_WIDTH = 33,
    parameter DATA_WIDTH = 256
)
(
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   start_read,
    input  wire  [7:0]            burst_length,
    input  wire  [ADDR_WIDTH-1:0] init_addr,
    input  wire                   read_rdy,

    output wire                  m_axi_ARVALID ,
    output wire [ADDR_WIDTH-1:0] m_axi_ARADDR ,
    output wire [7:0]            m_axi_ARLEN  ,

    output wire [2:0]            m_axi_ARSIZE ,
    output wire [1:0]            m_axi_ARBURST,
    input  wire                  m_axi_ARREADY,

    input  wire                  m_axi_RVALID,
    input  wire [DATA_WIDTH-1:0] m_axi_RDATA ,
    input  wire                  m_axi_RLAST ,
    input  wire [1:0]            m_axi_RRESP ,
    output wire                  m_axi_RREADY,

    output wire                  read_vld,
    output wire [DATA_WIDTH-1:0] read_data,
    output wire                  read_done,
    output wire                  read_error
);

assign m_axi_ARVALID = start_read;
assign m_axi_ARADDR  = init_addr;
assign m_axi_ARLEN   = burst_length - 8'd1;
assign m_axi_ARSIZE  = (DATA_WIDTH == 256) ? 3'b101 : 3'b110;
assign m_axi_ARBURST = 2'b01;

assign m_axi_RREADY = read_rdy;
assign read_vld      = m_axi_RVALID;
assign read_data     = m_axi_RDATA;
assign read_done     = m_axi_RLAST & m_axi_RVALID & m_axi_RREADY;
assign read_error    = m_axi_RVALID & (m_axi_RRESP != 2'b00);

endmodule
