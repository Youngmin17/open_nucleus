// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps

module cmd_ring_tracker #(
    parameter integer REQ_ID_W   = 8,
    parameter integer MAX_REQ    = 256,
    parameter integer RING_DEPTH = 32
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire [REQ_ID_W-1:0] request_id,
    input  wire [7:0]          read_id,
    input  wire [7:0]          finished_id,
    input  wire [REQ_ID_W-1:0] req_query_id,
    output reg  [7:0]          req_inflight_q,
    output reg  [15:0]         inflight_count,
    output reg  [6:0]          ring_occupancy,
    output wire                ring_empty,
    output wire                ring_full,
    output reg  [REQ_ID_W-1:0] ring_head_req,
    output reg                 err_retire_idle,
    output reg                 err_ring_overflow
);
    localparam integer RPW = (RING_DEPTH <= 1) ? 1 : $clog2(RING_DEPTH);

    reg [7:0]          req_inflight [0:MAX_REQ-1];
    reg [REQ_ID_W-1:0] ring_req     [0:RING_DEPTH-1];
    reg [RPW-1:0]      ring_head, ring_tail;

    wire dispatch_ev = (read_id     != 8'd0);
    wire retire_ev   = (finished_id != 8'd0);
    wire retire_ok   = retire_ev && (req_inflight[request_id] != 8'd0);

    assign ring_empty = (ring_occupancy == 7'd0);
    assign ring_full  = (ring_occupancy == RING_DEPTH[6:0]);

    integer i;
    initial begin
        for (i = 0; i < MAX_REQ; i = i + 1) req_inflight[i] = 8'd0;
        for (i = 0; i < RING_DEPTH; i = i + 1) ring_req[i] = {REQ_ID_W{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ring_head <= {RPW{1'b0}}; ring_tail <= {RPW{1'b0}};
            ring_occupancy <= 7'd0; inflight_count <= 16'd0;
            err_retire_idle <= 1'b0; err_ring_overflow <= 1'b0;
        end else begin
            err_retire_idle   <= retire_ev && (req_inflight[request_id] == 8'd0);
            err_ring_overflow <= dispatch_ev && ring_full;

            if (dispatch_ev)
                req_inflight[request_id] <= req_inflight[request_id] + 8'd1;
            else if (retire_ok)
                req_inflight[request_id] <= req_inflight[request_id] - 8'd1;

            if (dispatch_ev && !ring_full) begin
                ring_req[ring_tail] <= request_id;
                ring_tail <= (ring_tail == RING_DEPTH[RPW-1:0]-1'b1) ? {RPW{1'b0}} : ring_tail + 1'b1;
            end
            if (retire_ok)
                ring_head <= (ring_head == RING_DEPTH[RPW-1:0]-1'b1) ? {RPW{1'b0}} : ring_head + 1'b1;

            case ({dispatch_ev && !ring_full, retire_ok})
                2'b10:   ring_occupancy <= ring_occupancy + 7'd1;
                2'b01:   ring_occupancy <= ring_occupancy - 7'd1;
                default: ring_occupancy <= ring_occupancy;
            endcase
            case ({dispatch_ev, retire_ok})
                2'b10:   inflight_count <= inflight_count + 16'd1;
                2'b01:   inflight_count <= inflight_count - 16'd1;
                default: inflight_count <= inflight_count;
            endcase
        end
    end

    always @(*) req_inflight_q = req_inflight[req_query_id];
    always @(*) ring_head_req  = ring_req[ring_head];
endmodule
