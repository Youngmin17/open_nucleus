// SPDX-License-Identifier: Apache-2.0
module dma_custom_write
# (
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 256
)
(
    input wire                      clk,
    input wire                      rst_n,

    input wire                      write_vld,
    input wire                      all_write_rdy,

    input wire                      start_write,
    input wire [7:0]                burst_length,
    input wire [ADDR_WIDTH-1:0]     init_addr,
    input wire [DATA_WIDTH-1:0]     write_data,

    output reg                      m_axi_AWVALID ,
    output reg [ADDR_WIDTH-1:0]     m_axi_AWADDR  ,
    output reg [7:0]                m_axi_AWLEN   ,

    output reg [2:0]                m_axi_AWSIZE  ,
    output reg [1:0]                m_axi_AWBURST ,
    input  wire                     m_axi_AWREADY ,

    output wire                      m_axi_WVALID,
    output wire [DATA_WIDTH - 1:0]   m_axi_WDATA ,
    output wire                      m_axi_WLAST ,

    output reg [DATA_WIDTH/8-1:0]   m_axi_WSTRB,

    input  wire                     m_axi_WREADY,

    input wire                      m_axi_BVALID,
    input wire [1:0]                m_axi_BRESP,
    output reg                      m_axi_BREADY,

    output reg                      write_done,
    output reg                      write_error,
    output wire                     waddr_rdy,
    output wire                     write_rdy
);

always @(posedge clk) begin
    m_axi_AWSIZE  <= (DATA_WIDTH == 256)? 3'b101:3'b110;
    m_axi_AWBURST <= 2'b01;
    m_axi_WSTRB   <= {(DATA_WIDTH>>3){1'b1}};
end

localparam ST_IDLE  = 2'b00;
localparam ST_ADDR  = 2'b01;
localparam ST_WRITE = 2'b10;
localparam ST_WAIT  = 2'b11;

reg [1:0] cur_state;
reg [1:0] nxt_state;
reg [7:0] burstlen;
// synopsys translate_off
`ifdef KVPROBE
reg [ADDR_WIDTH-1:0] kp_awaddr;
`endif
// synopsys translate_on
reg [7:0] burst_counter;

reg wvgate;
initial wvgate = $test$plusargs("WVGATE");
assign waddr_rdy    = m_axi_AWREADY;
assign write_rdy    = m_axi_WREADY;
assign m_axi_WVALID = (cur_state == ST_WRITE && (all_write_rdy || !wvgate)) ? write_vld : 1'b0;
assign m_axi_WDATA  = (cur_state == ST_WRITE) ? write_data : {DATA_WIDTH{1'b0}};
assign m_axi_WLAST  = (cur_state == ST_WRITE && write_vld && all_write_rdy && (burst_counter == burstlen-1));

always @(*) begin
    if(!rst_n) begin
        nxt_state = ST_IDLE;
    end
    else begin
        nxt_state = cur_state;
        case(cur_state)
            ST_IDLE:  if(start_write) nxt_state = ST_ADDR;
            ST_ADDR:  if(m_axi_AWREADY) nxt_state = ST_WRITE;
            ST_WRITE: if(burst_counter == burstlen-1 && ((write_vld && all_write_rdy) || !wvgate)) nxt_state = ST_WAIT;
            ST_WAIT:  if(m_axi_BVALID) nxt_state = ST_IDLE;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cur_state <= ST_IDLE;
        burstlen <= 0;
        burst_counter <= 0;
        write_done <= 0;
        write_error <= 1'b0;
        m_axi_AWADDR <= {ADDR_WIDTH{1'b0}};
        m_axi_AWVALID <= 0;
        m_axi_AWLEN <= 0;
        m_axi_BREADY <= 1'b0;
    end

    else begin
        cur_state <= nxt_state;
        case(cur_state)
            ST_IDLE: begin
                write_done <= 1'b0;
                write_error <= 1'b0;
                if(start_write) begin
// synopsys translate_off
`ifdef KVPROBE
                    kp_awaddr <= init_addr;
`endif
// synopsys translate_on
                    m_axi_AWADDR <= init_addr;
                    m_axi_AWVALID <= 1'b1;
                    m_axi_AWLEN <= burst_length-1;
                    burstlen <= burst_length;
                end
            end
            ST_ADDR: begin
                if(m_axi_AWREADY) begin
                    m_axi_AWADDR <= {ADDR_WIDTH{1'b0}};
                    m_axi_AWVALID <= 1'b0;
                    m_axi_AWLEN <= 8'b0;
                end
            end
            ST_WRITE: begin
                if(write_vld && all_write_rdy) begin
// synopsys translate_off
`ifdef KVPROBE
                    $display("[DMA-BEAT] %m t=%0t word=%0d beat=%0d data=%064h", $time,
                             (kp_awaddr >> 5) + burst_counter, burst_counter, write_data);
`endif
// synopsys translate_on
                    burst_counter <= burst_counter + 1;
                    if(burst_counter == burstlen-1) begin
                        burst_counter <= 0;
                        burstlen <= 0;
                        m_axi_BREADY <= 1'b1;
                    end
                end
            end
            ST_WAIT: begin
                if(m_axi_BVALID) begin
                    write_done <= 1'b1;
                    m_axi_BREADY <= 1'b0;
                    if(m_axi_BRESP != 2'b00) write_error <= 1'b1;
                end
            end

        endcase
    end
end

endmodule
