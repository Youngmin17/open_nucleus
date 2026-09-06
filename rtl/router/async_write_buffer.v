// SPDX-License-Identifier: Apache-2.0
module async_write_buffer #(
    parameter ADDR_WIDTH = 64
)(
    input wire mem_clk,
    input wire core_clk,
    input wire rst_n,

    input wire          start_write,
    input wire [ADDR_WIDTH-1:0] write_addr,
    input wire [7:0]    write_burst_length,
    input wire          wrvalid,
    input wire [8191:0] d_in,
    input wire          cmd_is_code,
    input wire          data_is_code,

    input  wire                  write_rdy,
    input  wire                  write_done_in,
    input  wire                  write_beat_accept,
    output reg                   start_write_out,
    output reg [ADDR_WIDTH-1:0]  write_addr_out,
    output reg [7:0]             write_burst_length_out,
    output wire                  out_vld,
    output reg  [8191:0]         d_out
);

`ifdef WBUF_BIG
    localparam FAW = 5;
    localparam SAW = 12;
`else
    localparam FAW = 3;
    localparam SAW = 6;
`endif
    localparam FDEPTH = (1 << FAW);
    localparam SDEPTH = (1 << SAW);

    reg [ADDR_WIDTH-1:0] write_addr_fifo         [0:FDEPTH-1];
    reg [7:0]            write_burst_length_fifo [0:FDEPTH-1];
    reg [15:0]           target_cnt_fifo         [0:FDEPTH-1];

    localparam [SAW-1:0] CODE_BASE = (SDEPTH >> 1) + (SDEPTH >> 2);
    reg [ADDR_WIDTH-1:0] write_addr_fifo_cd         [0:FDEPTH-1];
    reg [7:0]            write_burst_length_fifo_cd [0:FDEPTH-1];
    reg [15:0]           target_cnt_fifo_cd         [0:FDEPTH-1];

    reg [FAW-1:0] fifo_wr_ptr;
    reg [FAW-1:0] fifo_wr_done_ptr;

    reg [FAW-1:0] fifo_rd_ptr;

    reg [FAW-1:0] fifo_wr_ptr_cd;
    reg [FAW-1:0] fifo_wr_done_ptr_cd;
    reg [FAW-1:0] fifo_rd_ptr_cd;

    wire [FAW-1:0] wr_done_gray = fifo_wr_done_ptr ^ (fifo_wr_done_ptr >> 1);
    reg  [FAW-1:0] wr_done_gray_s1, wr_done_gray_s2;

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_done_gray_s1 <= {FAW{1'b0}};
            wr_done_gray_s2 <= {FAW{1'b0}};
        end else begin
            wr_done_gray_s1 <= wr_done_gray;
            wr_done_gray_s2 <= wr_done_gray_s1;
        end
    end

    reg  [FAW-1:0] fifo_wr_done_sync;
    integer gb_i;
    always @(*) begin
        fifo_wr_done_sync[FAW-1] = wr_done_gray_s2[FAW-1];
        for (gb_i = FAW-2; gb_i >= 0; gb_i = gb_i - 1)
            fifo_wr_done_sync[gb_i] = fifo_wr_done_sync[gb_i+1] ^ wr_done_gray_s2[gb_i];
    end

    wire fifo_not_empty = (fifo_wr_done_sync != fifo_rd_ptr);

    wire [FAW-1:0] wr_done_gray_cd = fifo_wr_done_ptr_cd ^ (fifo_wr_done_ptr_cd >> 1);
    reg  [FAW-1:0] wr_done_gray_cd_s1, wr_done_gray_cd_s2;
    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_done_gray_cd_s1 <= {FAW{1'b0}};
            wr_done_gray_cd_s2 <= {FAW{1'b0}};
        end else begin
            wr_done_gray_cd_s1 <= wr_done_gray_cd;
            wr_done_gray_cd_s2 <= wr_done_gray_cd_s1;
        end
    end
    reg  [FAW-1:0] fifo_wr_done_sync_cd;
    integer gb_i_cd;
    always @(*) begin
        fifo_wr_done_sync_cd[FAW-1] = wr_done_gray_cd_s2[FAW-1];
        for (gb_i_cd = FAW-2; gb_i_cd >= 0; gb_i_cd = gb_i_cd - 1)
            fifo_wr_done_sync_cd[gb_i_cd] = fifo_wr_done_sync_cd[gb_i_cd+1] ^ wr_done_gray_cd_s2[gb_i_cd];
    end
    wire fifo_not_empty_cd = (fifo_wr_done_sync_cd != fifo_rd_ptr_cd);

    reg        wen;
    reg [SAW-1:0]  waddr_cnt;
    reg [SAW-1:0]  waddr;
    reg [8191:0] wdata;

    reg [15:0] wr_total_cnt;
    reg [15:0] last_target;

    reg [SAW-1:0] waddr_cnt_cd;
    reg [15:0]    wr_total_cnt_cd;
    reg [15:0]    last_target_cd;

    wire [15:0] wr_total_cnt_eff = wr_total_cnt + ((wrvalid && !data_is_code) ? 16'd1 : 16'd0);
    wire signed [15:0] target_diff =
        $signed(wr_total_cnt_eff) - $signed(target_cnt_fifo[fifo_wr_done_ptr]);
    wire cmd_pending  = (fifo_wr_done_ptr != fifo_wr_ptr);
    wire burst_reached = cmd_pending && (target_diff >= 0);

    wire [15:0] wr_total_cnt_cd_eff = wr_total_cnt_cd + ((wrvalid && data_is_code) ? 16'd1 : 16'd0);
    wire signed [15:0] target_diff_cd =
        $signed(wr_total_cnt_cd_eff) - $signed(target_cnt_fifo_cd[fifo_wr_done_ptr_cd]);
    wire cmd_pending_cd  = (fifo_wr_done_ptr_cd != fifo_wr_ptr_cd);
    wire burst_reached_cd = cmd_pending_cd && (target_diff_cd >= 0);

    // synopsys translate_off
    `ifdef KVPROBE
        integer kp_beat;  reg [ADDR_WIDTH-1:0] kp_prev_addr;
        initial begin kp_beat = 0; kp_prev_addr = {ADDR_WIDTH{1'b1}}; end
    `endif
    // synopsys translate_on
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            wen              <= 1'b0;
            waddr_cnt        <= {SAW{1'b0}};
            waddr            <= {SAW{1'b0}};
            wdata            <= {8192{1'b0}};
            fifo_wr_ptr      <= {FAW{1'b0}};
            fifo_wr_done_ptr <= {FAW{1'b0}};
            wr_total_cnt     <= 16'd0;
            last_target      <= 16'd0;
            waddr_cnt_cd        <= {SAW{1'b0}};
            fifo_wr_ptr_cd      <= {FAW{1'b0}};
            fifo_wr_done_ptr_cd <= {FAW{1'b0}};
            wr_total_cnt_cd     <= 16'd0;
            last_target_cd      <= 16'd0;
        end else begin
            wen <= 1'b0;

            if (wrvalid) begin
                wdata        <= d_in;
                wen          <= 1'b1;
                if (data_is_code) begin
                    waddr           <= CODE_BASE + waddr_cnt_cd;
                    waddr_cnt_cd    <= waddr_cnt_cd + 1'b1;
                    wr_total_cnt_cd <= wr_total_cnt_cd + 16'd1;
                end else begin
                    waddr        <= waddr_cnt;
                    waddr_cnt    <= waddr_cnt + 1'b1;
                    wr_total_cnt <= wr_total_cnt + 16'd1;
                end
            end

// synopsys translate_off
`ifdef KVPROBE
    if (wrvalid)
        $display("[WBUF-BEAT] t=%0t code=%0d slot=%0d ch0=%h ch1=%h", $time, data_is_code,
                 data_is_code ? (CODE_BASE + waddr_cnt_cd) : waddr_cnt,
                 d_in[255:0], d_in[511:256]);
`endif
    // synopsys translate_on

            if (start_write) begin
                if (cmd_is_code) begin
                    write_addr_fifo_cd[fifo_wr_ptr_cd]         <= write_addr;
                    write_burst_length_fifo_cd[fifo_wr_ptr_cd] <= write_burst_length;
                    target_cnt_fifo_cd[fifo_wr_ptr_cd]         <= last_target_cd + write_burst_length;
                    last_target_cd                             <= last_target_cd + write_burst_length;
                    fifo_wr_ptr_cd                             <= fifo_wr_ptr_cd + 1'b1;
                end else begin
                    write_addr_fifo[fifo_wr_ptr]         <= write_addr;
                    write_burst_length_fifo[fifo_wr_ptr] <= write_burst_length;
                    target_cnt_fifo[fifo_wr_ptr]         <= last_target + write_burst_length;
                    last_target                          <= last_target + write_burst_length;
                    fifo_wr_ptr                          <= fifo_wr_ptr + 1'b1;
                end
            end

            if (burst_reached) begin
                fifo_wr_done_ptr <= fifo_wr_done_ptr + 1'b1;
            end
            if (burst_reached_cd) begin
                fifo_wr_done_ptr_cd <= fifo_wr_done_ptr_cd + 1'b1;
            end
        end
    end

    reg        ren;
    reg [SAW-1:0]  raddr;
    wire [8191:0] rdata;
    wire       rvalid;

    reg [7:0]  cur_bl, cur_bl_cnt;
    reg [ADDR_WIDTH-1:0] cur_addr;
    reg [SAW-1:0]  read_bookmark;
    reg [SAW-1:0]  read_bookmark_cd;
    reg        read_lane_code;
    reg        read_phase;
    reg        start_write_out_latch;
    reg [5:0]  start_write_out_latch_cnt;
    reg [7:0]  deq_budget;
    reg        prev_done;
`ifdef WBUF_BIG
    wire       pop_ok = prev_done;
`else
    wire       pop_ok = 1'b1;
`endif

    reg [8191:0] ofifo [0:7];
    reg [3:0] ofifo_wr_ptr, ofifo_rd_ptr;
    wire [2:0] ofifo_waddr = ofifo_wr_ptr[2:0];
    wire [2:0] ofifo_raddr = ofifo_rd_ptr[2:0];
    wire ofifo_empty = (ofifo_wr_ptr == ofifo_rd_ptr);
    wire ofifo_full  = (ofifo_wr_ptr[3] != ofifo_rd_ptr[3]) &&
                       (ofifo_wr_ptr[2:0] == ofifo_rd_ptr[2:0]);

    assign out_vld = !ofifo_empty;
    always @(*) begin
        d_out = ofifo[ofifo_raddr];
    end

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            ofifo_wr_ptr <= 4'd0;
            ofifo_rd_ptr <= 4'd0;
            deq_budget   <= 8'd0;
        end else begin
            if (rvalid && !ofifo_full) begin
                ofifo[ofifo_waddr] <= rdata;
                ofifo_wr_ptr <= ofifo_wr_ptr + 4'd1;
            end
`ifdef WBUF_BIG
            if (!ofifo_empty && write_beat_accept) begin
                ofifo_rd_ptr <= ofifo_rd_ptr + 4'd1;
// synopsys translate_off
`ifdef KVPROBE
                begin : kv_drain_probe
                    integer kp_ch;
                    if (write_addr_out != kp_prev_addr) begin kp_beat = 0; kp_prev_addr = write_addr_out; end
                    $write("[WBUF-DRAIN] t=%0t word=%0d beat=%0d", $time,
                           (write_addr_out >> 5) + kp_beat, kp_beat);
                    kp_beat = kp_beat + 1;
                    for (kp_ch = 0; kp_ch < 32; kp_ch = kp_ch + 1)
                        $write(" ch%0d=%064h", kp_ch, d_out[kp_ch*256 +: 256]);
                    $write("\n");
                end
`endif
// synopsys translate_on
            end
`else
            if (!ofifo_empty && write_rdy) begin
                ofifo_rd_ptr <= ofifo_rd_ptr + 4'd1;
            end
`endif
        end
    end

    reg [3:0] in_flight;
    wire [3:0] ofifo_occ = ofifo_wr_ptr - ofifo_rd_ptr;
    wire ofifo_has_room  = ((ofifo_occ + in_flight) < 4'd8);

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            in_flight <= 4'd0;
        end else begin
            case ({ren, rvalid})
                2'b10: in_flight <= in_flight + 4'd1;
                2'b01: in_flight <= in_flight - 4'd1;
                default: in_flight <= in_flight;
            endcase
        end
    end

    always @(posedge mem_clk or negedge rst_n) begin
        if (!rst_n) begin
            start_write_out           <= 1'b0;
            write_addr_out            <= {ADDR_WIDTH{1'b0}};
            write_burst_length_out    <= 8'd0;
            ren                       <= 1'b0;
            raddr                     <= {SAW{1'b0}};
            start_write_out_latch     <= 1'b0;
            start_write_out_latch_cnt <= 6'd0;
            read_phase                <= 1'b0;
            read_bookmark             <= {SAW{1'b0}};
            read_bookmark_cd          <= {SAW{1'b0}};
            read_lane_code            <= 1'b0;
            cur_bl                    <= 8'd0;
            cur_bl_cnt                <= 8'd0;
            cur_addr                  <= {ADDR_WIDTH{1'b0}};
            fifo_rd_ptr               <= {FAW{1'b0}};
            fifo_rd_ptr_cd            <= {FAW{1'b0}};
            prev_done                 <= 1'b1;
        end else begin
            start_write_out <= 1'b0;
            ren <= 1'b0;

`ifdef WBUF_BIG
            if (write_done_in) prev_done <= 1'b1;
`endif

            if (read_phase) begin
                if (ofifo_has_room) begin
                    ren   <= 1'b1;
                    raddr <= (read_lane_code ? (CODE_BASE + read_bookmark_cd) : read_bookmark) + cur_bl_cnt;
                    if (cur_bl_cnt == cur_bl - 1) begin
                        read_phase    <= 1'b0;
                        cur_bl_cnt    <= 8'd0;
                        if (read_lane_code) read_bookmark_cd <= read_bookmark_cd + cur_bl;
                        else                read_bookmark    <= read_bookmark + cur_bl;
                    end else begin
                        cur_bl_cnt <= cur_bl_cnt + 8'd1;
                    end
                end
            end else if (start_write_out_latch) begin
                start_write_out_latch_cnt <= start_write_out_latch_cnt + 6'd1;
                if (start_write_out_latch_cnt == 6'd3) begin
                    start_write_out_latch     <= 1'b0;
                    start_write_out_latch_cnt <= 6'd0;
                    read_phase <= 1'b1;
                end
            end else if (start_write_out) begin
                start_write_out_latch <= 1'b1;
            end else if (!read_phase && pop_ok && (fifo_not_empty || fifo_not_empty_cd)) begin
                start_write_out        <= 1'b1;
`ifdef WBUF_BIG
                prev_done              <= 1'b0;
`endif
                if (fifo_not_empty) begin
                    cur_bl                 <= write_burst_length_fifo[fifo_rd_ptr];
                    cur_addr               <= write_addr_fifo[fifo_rd_ptr];
                    write_addr_out         <= write_addr_fifo[fifo_rd_ptr];
                    write_burst_length_out <= write_burst_length_fifo[fifo_rd_ptr];
                    fifo_rd_ptr            <= fifo_rd_ptr + 1'b1;
                    read_lane_code         <= 1'b0;
                end else begin
                    cur_bl                 <= write_burst_length_fifo_cd[fifo_rd_ptr_cd];
                    cur_addr               <= write_addr_fifo_cd[fifo_rd_ptr_cd];
                    write_addr_out         <= write_addr_fifo_cd[fifo_rd_ptr_cd];
                    write_burst_length_out <= write_burst_length_fifo_cd[fifo_rd_ptr_cd];
                    fifo_rd_ptr_cd         <= fifo_rd_ptr_cd + 1'b1;
                    read_lane_code         <= 1'b1;
                end
            end
        end
    end

`ifdef WBUF_BIG
    reg [8191:0] wbuf_mem [0:SDEPTH-1];
    reg [8191:0] rdata_beh;
    reg          rvalid_beh;
    always @(posedge core_clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_beh <= 1'b0;
            rdata_beh  <= {8192{1'b0}};
        end else begin
            if (wen) wbuf_mem[waddr] <= wdata;
            rdata_beh  <= wbuf_mem[raddr];
            rvalid_beh <= ren;
        end
    end
    assign rdata  = rdata_beh;
    assign rvalid = rvalid_beh;
`else
    sram_64x8192_wrapper uW0_sram_64x8192_wrapper(
        .clk   (core_clk),
        .rst_n (rst_n),
        .wen   (wen),
        .waddr (waddr),
        .wdata (wdata),
        .ren   (ren),
        .raddr (raddr),
        .rdata (rdata),
        .rvalid(rvalid)
    );
`endif

endmodule