// SPDX-License-Identifier: Apache-2.0
module multi_core_top_os (
    input wire core_clk,
    input wire mem_clk,
    input wire rst_n,

    input wire                  reduce_max_vld,
    input wire [15:0]           reduce_max_value,

    input wire [511:0]          isa_in,
    input wire                  isa_valid,
    output wire                 isa_in_ready,

    input wire                  comb_sram_wen,
    input wire [101:0]          comb_sram_wdata,

    input wire [31:0]           cpu_vrf_in_vld,
    input wire [63:0]           cpu_vrf_row_data,

    output wire                 cpu_row_valid,
    output wire [63:0]          cpu_row_data,

    output wire [7:0]           read_id,
    output wire [7:0]           finished_id
);

    localparam AXI_CHANNELS   = 32;
    localparam ADDR_WIDTH     = 64;
    localparam DMA_DATA_WIDTH = 256;
    localparam HBM_CHANNELS   = 8;
    localparam HBM_DATA_WIDTH = 1024;
    localparam BLOCK_SIZE     = 128;
    localparam DATA_NUM       = 64;
    localparam DIN_WIDTH      = HBM_CHANNELS * HBM_DATA_WIDTH;
`ifdef CORE1
    localparam CORE_NUM       = 1;
    localparam [3:0] GEMM_A_XFERS = 4'd1;
    localparam [3:0] GEMM_W_XFERS = 4'd1;
`elsif CORE2
    localparam CORE_NUM       = 2;
    localparam [3:0] GEMM_A_XFERS = 4'd1;
    localparam [3:0] GEMM_W_XFERS = 4'd2;
`elsif CORE4
    localparam CORE_NUM       = 4;
    localparam [3:0] GEMM_A_XFERS = 4'd2;
    localparam [3:0] GEMM_W_XFERS = 4'd2;
`elsif CORE16
    localparam CORE_NUM       = 16;
    localparam [3:0] GEMM_A_XFERS = 4'd4;
    localparam [3:0] GEMM_W_XFERS = 4'd4;
`elsif CORE32
    localparam CORE_NUM       = 32;
    localparam [3:0] GEMM_A_XFERS = 4'd8;
    localparam [3:0] GEMM_W_XFERS = 4'd4;
`else
    localparam CORE_NUM       = 8;
    localparam [3:0] GEMM_A_XFERS = 4'd2;
    localparam [3:0] GEMM_W_XFERS = 4'd4;
`endif
    localparam DATA_WIDTH     = 16;

    wire        isa_triggered;
    wire        isa_latched;
    wire        is_mode_valid;
    wire [7:0]  request_id;
    wire [5:0]  decode_core_num;
    wire [6:0]  q_head_num;
    wire [6:0]  kv_head_num;
    wire [29:0] qkv_head_addr_offset;
    wire        a_on_chip;
    wire        dest_on_chip;
    wire [3:0]  fuse_mode;
    wire [1:0]  opm_mode;
    wire [1:0]  group_width;
    wire [2:0]  quant_precision;
    wire [3:0]  op_a_prec;
    wire [3:0]  op_b_prec;
    wire [3:0]  op_c_prec;
    wire [4:0]  op_b_prec_eff;
    wire [4:0]  op_c_prec_eff;
    wire        op_b_fmt_explicit;
    wire        op_c_fmt_explicit;
    wire        w_szp_ovr;
    wire        causal_mode;
    wire [7:0]  batch_num;
    wire [23:0] rope_token_pos;
    wire [15:0] hidden_dim;
    wire [23:0] seq_len;
    wire [15:0] output_dim;
    wire [15:0] window_size;
    wire [6:0]  outlier_num;
    wire [39:0] op_a_base_addr;
    wire [39:0] op_b_base_addr;
    wire [39:0] op_c_base_addr;
    wire [39:0] op_d_base_addr;
    wire [39:0] op_e_base_addr;
    wire [39:0] dest_addr1;
    wire [39:0] dest_addr2;
    wire [5:0]  group_size;
    wire        is_proj_mode;
    wire        is_gemm_mode;
    wire        is_residual_mode;
    wire        is_gating_mode;
    wire        is_norm_mode;

    wire        vec_load_start;
    wire        result_block_done;
    wire        start_read;
    wire [7:0]  read_burst_length;
    wire [ADDR_WIDTH-1:0] read_init_addr;

    wire        core_compute_done;
    wire        gqa_q_phase_done;
    wire        gqa_score_phase_done;
    wire        residual_load_done;

    wire        isa_finished;
    wire        concat_phase_done;
    wire        idle_state;
    assign isa_finished = !is_gemm_mode ? concat_phase_done :
                                          concat_phase_done && idle_state;

    wire        dma_read_done;

    wire        read_vld;
    wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] read_data;
    wire        dma_read_error;

    wire        oc_start_write;
    wire [7:0]  oc_write_burst_length;
    wire [ADDR_WIDTH-1:0] oc_write_init_addr;
    wire        oc_write_vld;
    wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] oc_write_data;
    wire        oc_write_is_code;
    wire        oc_cmd_is_code;

    wire        awb_start_write;
    wire [ADDR_WIDTH-1:0] awb_write_addr;
    wire [7:0]  awb_write_burst_length;
    wire        awb_write_vld;
    wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] awb_write_data;

    wire        write_done;
    wire        waddr_rdy;
    wire        write_rdy;
    wire        write_beat_accept;
    wire        write_error;

    wire [AXI_CHANNELS-1:0]                hbm_axi_clk_w;
    wire [AXI_CHANNELS-1:0]                hbm_axi_arstn;
    wire [AXI_CHANNELS-1:0]                hbm_axi_arvalid;
    wire [ADDR_WIDTH*AXI_CHANNELS-1:0]     hbm_axi_araddr;
    wire [8*AXI_CHANNELS-1:0]              hbm_axi_arlen;
    wire [3*AXI_CHANNELS-1:0]              hbm_axi_arsize;
    wire [2*AXI_CHANNELS-1:0]              hbm_axi_arburst;
    wire [AXI_CHANNELS-1:0]                hbm_axi_arready;
    wire [AXI_CHANNELS-1:0]                hbm_axi_rvalid;
    wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] hbm_axi_rdata;
    wire [AXI_CHANNELS-1:0]                hbm_axi_rlast;
    wire [2*AXI_CHANNELS-1:0]              hbm_axi_rresp;
    wire [AXI_CHANNELS-1:0]                hbm_axi_rready;
    wire [ADDR_WIDTH*AXI_CHANNELS-1:0]     hbm_axi_awaddr;
    wire [2*AXI_CHANNELS-1:0]              hbm_axi_awburst;
    wire [8*AXI_CHANNELS-1:0]              hbm_axi_awlen;
    wire [3*AXI_CHANNELS-1:0]              hbm_axi_awsize;
    wire [AXI_CHANNELS-1:0]                hbm_axi_awvalid;
    wire [AXI_CHANNELS-1:0]                hbm_axi_awready;
    wire [DMA_DATA_WIDTH*AXI_CHANNELS-1:0] hbm_axi_wdata;
    wire [AXI_CHANNELS-1:0]                hbm_axi_wlast;
    wire [AXI_CHANNELS*DMA_DATA_WIDTH/8-1:0] hbm_axi_wstrb;
    wire [AXI_CHANNELS-1:0]                hbm_axi_wvalid;
    wire [AXI_CHANNELS-1:0]                hbm_axi_wready;
    wire [2*AXI_CHANNELS-1:0]              hbm_axi_bresp;
    wire [AXI_CHANNELS-1:0]                hbm_axi_bready;
    wire [AXI_CHANNELS-1:0]                hbm_axi_bvalid;

    wire        async_out_vld;
    wire [4095:0] async_d_out;
    wire        async_ready;

    isa_decoder #(.DECODE_CORE_NUM(CORE_NUM)) u_isa_decoder (
        .clk                (mem_clk),
        .rst_n              (rst_n),
        .isa_in             (isa_in),
        .isa_valid          (isa_valid),
        .isa_in_ready       (isa_in_ready),
        .isa_finished       (isa_finished),
        .isa_triggered      (isa_triggered),
        .isa_latched        (isa_latched),
        .is_mode_valid      (is_mode_valid),
        .request_id         (request_id),
        .read_id            (read_id),
        .finished_id        (finished_id),
        .decode_core_num    (decode_core_num),
        .a_on_chip          (a_on_chip),
        .dest_on_chip       (dest_on_chip),
        .fuse_mode          (fuse_mode),
        .opm_mode           (opm_mode),
        .group_width        (group_width),
        .quant_precision    (quant_precision),
        .op_a_prec          (op_a_prec),
        .op_b_prec          (op_b_prec),
        .op_c_prec          (op_c_prec),
        .op_b_prec_eff      (op_b_prec_eff),
        .op_c_prec_eff      (op_c_prec_eff),
        .op_b_fmt_explicit  (op_b_fmt_explicit),
        .op_c_fmt_explicit  (op_c_fmt_explicit),
        .w_szp_ovr          (w_szp_ovr),
        .causal_mode        (causal_mode),
        .batch_num          (batch_num),
        .q_head_num         (q_head_num),
        .kv_head_num        (kv_head_num),
        .rope_token_pos     (rope_token_pos),
        .hidden_dim         (hidden_dim),
        .seq_len            (seq_len),
        .output_dim         (output_dim),
        .outlier_num        (outlier_num),
        .op_a_base_addr     (op_a_base_addr),
        .op_b_base_addr     (op_b_base_addr),
        .op_c_base_addr     (op_c_base_addr),
        .op_d_base_addr     (op_d_base_addr),
        .op_e_base_addr     (op_e_base_addr),
        .dest_addr1         (dest_addr1),
        .dest_addr2         (dest_addr2),
        .qkv_head_addr_offset    (qkv_head_addr_offset),
        .group_size         (group_size),
        .window_size        (window_size),
        .is_proj_mode       (is_proj_mode),
        .is_gemm_mode       (is_gemm_mode),
        .is_residual_mode   (is_residual_mode),
        .is_gating_mode     (is_gating_mode),
        .is_norm_mode       (is_norm_mode)
    );

    cmd_ring_tracker #(.RING_DEPTH(32)) u_cmd_ring (
        .clk                (mem_clk),
        .rst_n              (rst_n),
        .request_id         (request_id),
        .read_id            (read_id),
        .finished_id        (finished_id),
        .req_query_id       (8'd0),
        .req_inflight_q     (),
        .inflight_count     (),
        .ring_occupancy     (),
        .ring_empty         (),
        .ring_full          (),
        .ring_head_req      (),
        .err_retire_idle    (),
        .err_ring_overflow  ()
    );

    schedule_manager #(
        .CORE_NUM    (CORE_NUM),
        .AXI_CHANNELS(AXI_CHANNELS),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS)
    ) u_schedule_manager (
        .clk                    (mem_clk),
        .rst_n                  (rst_n),
        .isa_valid              (isa_latched),
        .is_gemm_mode           (is_gemm_mode),
        .is_proj_mode           (is_proj_mode),
        .is_residual_mode       (is_residual_mode),
        .is_gating_mode         (is_gating_mode),
        .is_norm_mode           (is_norm_mode),
        .a_on_chip              (a_on_chip),
        .op_a_addr              ({24'd0, op_a_base_addr}),
        .op_b_addr              ({24'd0, op_b_base_addr}),
        .op_c_addr              ({24'd0, op_c_base_addr}),
        .residual_base_addr     ({24'd0, op_d_base_addr}),
        .qkv_head_addr_offset        ({34'd0, qkv_head_addr_offset}),
        .op_a_prec              ({1'b0, op_a_prec}),
        .op_b_prec              (op_b_prec_eff),
        .op_c_prec              (op_c_prec_eff),
        .op_b_fmt_explicit      (op_b_fmt_explicit),
        .op_c_fmt_explicit      (op_c_fmt_explicit),
        .w_szp_ovr              (w_szp_ovr),
        .seq_len                ({8'd0, seq_len}),
        .hidden_dim             (hidden_dim),
        .output_dim             (output_dim),
        .batch_num              (batch_num),
        .q_head_num             (q_head_num),
        .kv_head_num            (kv_head_num),
        .group_size             (group_size),
        .window_size            (window_size),
        .group_width            (group_width),
        .outlier_num            (outlier_num),
        .dma_arready            (1'b1),
        .dma_read_done          (dma_read_done),
        .core_compute_done      (core_compute_done),
        .gqa_q_phase_done       (gqa_q_phase_done),
        .gqa_score_phase_done   (gqa_score_phase_done),
        .residual_load_done     (residual_load_done),
        .concat_phase_done      (concat_phase_done),
        .vec_load_start         (vec_load_start),
        .result_block_done      (result_block_done),
        .idle_state             (idle_state),
        .start_read             (start_read),
        .read_burst_length      (read_burst_length),
        .read_init_addr         (read_init_addr)
    );

    dma_top u_dma_top (
        .clk               (mem_clk),
        .rst_n             (rst_n),
        .start_read        (start_read),
        .read_burst_length (read_burst_length),
        .read_init_addr    (read_init_addr),
        .read_rdy          (async_ready),
        .read_vld          (read_vld),
        .read_data         (read_data),
        .read_done         (dma_read_done),
        .read_error        (dma_read_error),
        .start_write       (awb_start_write),
        .write_burst_length(awb_write_burst_length),
        .write_init_addr   (awb_write_addr),
        .write_vld         (awb_write_vld),
        .write_data        (awb_write_data),
        .write_done        (write_done),
        .waddr_rdy         (waddr_rdy),
        .write_rdy         (write_rdy),
        .write_beat_accept (write_beat_accept),
        .write_error       (write_error),
        .hbm_axi_clk      (hbm_axi_clk_w),
        .hbm_axi_arstn    (hbm_axi_arstn),
        .hbm_axi_arvalid  (hbm_axi_arvalid),
        .hbm_axi_araddr   (hbm_axi_araddr),
        .hbm_axi_arlen    (hbm_axi_arlen),
        .hbm_axi_arsize   (hbm_axi_arsize),
        .hbm_axi_arburst  (hbm_axi_arburst),
        .hbm_axi_arready  (hbm_axi_arready),
        .hbm_axi_rvalid   (hbm_axi_rvalid),
        .hbm_axi_rdata    (hbm_axi_rdata),
        .hbm_axi_rlast    (hbm_axi_rlast),
        .hbm_axi_rresp    (hbm_axi_rresp),
        .hbm_axi_rready   (hbm_axi_rready),
        .hbm_axi_awaddr   (hbm_axi_awaddr),
        .hbm_axi_awburst  (hbm_axi_awburst),
        .hbm_axi_awlen    (hbm_axi_awlen),
        .hbm_axi_awsize   (hbm_axi_awsize),
        .hbm_axi_awvalid  (hbm_axi_awvalid),
        .hbm_axi_awready  (hbm_axi_awready),
        .hbm_axi_wdata    (hbm_axi_wdata),
        .hbm_axi_wlast    (hbm_axi_wlast),
        .hbm_axi_wstrb    (hbm_axi_wstrb),
        .hbm_axi_wvalid   (hbm_axi_wvalid),
        .hbm_axi_wready   (hbm_axi_wready),
        .hbm_axi_bresp    (hbm_axi_bresp),
        .hbm_axi_bready   (hbm_axi_bready),
        .hbm_axi_bvalid   (hbm_axi_bvalid)
    );

    genvar hi;
    generate
        for (hi = 0; hi < AXI_CHANNELS; hi = hi + 1) begin : gen_hbm_ram
            axi_ram_hbm #(
                .DATA_WIDTH (DMA_DATA_WIDTH),
                .ADDR_WIDTH (ADDR_WIDTH),
                .MAX_BURST_LEN(256), .CHECK_WLAST(0)
            ) u_axi_ram_hbm (
                .clk             (hbm_axi_clk_w[hi]),
                .rst_n           (hbm_axi_arstn[hi]),
                .s_axi_awaddr    (hbm_axi_awaddr[ADDR_WIDTH*hi +: ADDR_WIDTH]),
                .s_axi_awlen     (hbm_axi_awlen[8*hi +: 8]),
                .s_axi_awvalid   (hbm_axi_awvalid[hi]),
                .s_axi_awready   (hbm_axi_awready[hi]),
                .s_axi_wdata     (hbm_axi_wdata[DMA_DATA_WIDTH*hi +: DMA_DATA_WIDTH]),
                .s_axi_wstrb     (hbm_axi_wstrb[(DMA_DATA_WIDTH/8)*hi +: (DMA_DATA_WIDTH/8)]),
                .s_axi_wlast     (hbm_axi_wlast[hi]),
                .s_axi_wvalid    (hbm_axi_wvalid[hi]),
                .s_axi_wready    (hbm_axi_wready[hi]),
                .s_axi_bvalid    (hbm_axi_bvalid[hi]),
                .s_axi_bready    (hbm_axi_bready[hi]),
                .s_axi_araddr    (hbm_axi_araddr[ADDR_WIDTH*hi +: ADDR_WIDTH]),
                .s_axi_arlen     (hbm_axi_arlen[8*hi +: 8]),
                .s_axi_arvalid   (hbm_axi_arvalid[hi]),
                .s_axi_arready   (hbm_axi_arready[hi]),
                .s_axi_rdata     (hbm_axi_rdata[DMA_DATA_WIDTH*hi +: DMA_DATA_WIDTH]),
                .s_axi_rlast     (hbm_axi_rlast[hi]),
                .s_axi_rvalid    (hbm_axi_rvalid[hi]),
                .s_axi_rready    (hbm_axi_rready[hi])
            );
        end
    endgenerate

    async_read_buffer u_async_read_buffer (
        .mem_clk  (mem_clk),
        .core_clk (core_clk),
        .rst_n    (rst_n),
        .in_vld   (read_vld),
        .d_in     (read_data),
        .out_vld  (async_out_vld),
        .d_out    (async_d_out),
        .ready    (async_ready)
    );

    async_write_buffer #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_async_write_buffer (
        .mem_clk              (mem_clk),
        .core_clk             (core_clk),
        .rst_n                (rst_n),
        .start_write          (oc_start_write),
        .write_addr           (oc_write_init_addr),
        .write_burst_length   (oc_write_burst_length),
        .wrvalid              (oc_write_vld),
        .d_in                 (oc_write_data),
        .cmd_is_code          (oc_cmd_is_code),
        .data_is_code         (oc_write_is_code),
        .write_rdy            (write_rdy),
        .write_done_in        (write_done),
        .write_beat_accept    (write_beat_accept),
        .start_write_out      (awb_start_write),
        .write_addr_out       (awb_write_addr),
        .write_burst_length_out(awb_write_burst_length),
        .out_vld              (awb_write_vld),
        .d_out                (awb_write_data)
    );

    onchip_top #(
        .CORE_NUM(CORE_NUM),
        .GEMM_A_XFERS(GEMM_A_XFERS),
        .GEMM_W_XFERS(GEMM_W_XFERS)
    ) u_onchip_top (
        .core_clk              (core_clk),
        .mem_clk               (mem_clk),
        .rst_n                 (rst_n),
        .isa_latched           (isa_latched),
        .is_mode_valid         (is_mode_valid),
        .is_gemm_mode          (is_gemm_mode),
        .is_proj_mode          (is_proj_mode),
        .is_norm_mode          (is_norm_mode),
        .is_residual_mode      (is_residual_mode),
        .is_gating_mode        (is_gating_mode),
        .causal_mode           (causal_mode),
        .dest_on_chip          (dest_on_chip),
        .a_on_chip             (a_on_chip),
        .fuse_mode             (fuse_mode),
        .opm_mode              (opm_mode),
        .group_width           (group_width),
        .batch_num             (batch_num),
        .group_size            (group_size),
        .window_size           (window_size),
        .kv_head_num           (kv_head_num),
        .op_b_prec             (op_b_prec_eff),
        .op_c_prec             (op_c_prec_eff),
        .outlier_num           (outlier_num),
        .hidden_dim            (hidden_dim),
        .seq_len               ({8'd0, seq_len}),
        .output_dim            (output_dim),
        .quant_precision       (quant_precision),
        .dest_addr1            (dest_addr1),
        .dest_addr2            (dest_addr2),
        .qkv_head_addr_offset       (qkv_head_addr_offset),
        .rope_token_pos        (rope_token_pos),
        .vec_load_start        (vec_load_start),
        .result_block_done     (result_block_done),
        .async_out_vld         (async_out_vld),
        .async_d_out           (async_d_out),
        .reduce_max_vld        (reduce_max_vld),
        .reduce_max_value      (reduce_max_value),
        .cpu_vrf_in_vld        (cpu_vrf_in_vld),
        .cpu_vrf_row_data      (cpu_vrf_row_data),
        .comb_sram_wen         (comb_sram_wen),
        .comb_sram_wdata       (comb_sram_wdata),
        .gqa_q_phase_done_out  (gqa_q_phase_done),
        .gqa_score_phase_done_out(gqa_score_phase_done),
        .core_compute_done_out (core_compute_done),
        .concat_phase_done_out (concat_phase_done),
        .residual_load_done_out(residual_load_done),
        .cpu_row_valid         (cpu_row_valid),
        .cpu_row_data          (cpu_row_data),
        .write_vld             (oc_write_vld),
        .start_write           (oc_start_write),
        .write_burst_length    (oc_write_burst_length),
        .write_init_addr       (oc_write_init_addr),
        .write_data            (oc_write_data),
        .write_is_code         (oc_write_is_code),
        .cmd_is_code           (oc_cmd_is_code)
    );

endmodule
