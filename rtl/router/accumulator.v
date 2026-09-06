// SPDX-License-Identifier: Apache-2.0

module accumulator
#(
    parameter CORE_NUM   = 8,
    parameter DATA_WIDTH = 16,
    parameter DATA_NUM   = 64,
    parameter LOOP_NUM   = 1
) (
    input  wire                                    clk,
    input  wire                                    rst_n,

    input  wire [3:0]                              fuse_mode,
    input  wire                                    is_gemm_mode,
    input  wire                                    is_proj_mode,
    input  wire                                    isa_valid,

    input  wire [5:0]                              decode_core_num,

    input  wire [CORE_NUM*DATA_WIDTH*DATA_NUM-1:0] d_in,
    input  wire [CORE_NUM-1:0]                     in_vld,

    input  wire [CORE_NUM-1:0]                     core_compute_done,
    input  wire [CORE_NUM-1:0]                     gqa_q_phase_done,
    input  wire [CORE_NUM-1:0]                     gqa_score_phase_done,
    input  wire [CORE_NUM-1:0]                     gqa_compute_stop,

    output reg                                     core_row_valid,
    output reg [DATA_WIDTH*(DATA_NUM*2)-1:0]       core_row_data,
    output reg [DATA_WIDTH*(DATA_NUM*2)-1:0]       core_row_data_swig_val,

    output reg                                     gqa_q_phase_done_out,
    output reg                                     gqa_score_phase_done_out,
    output reg                                     core_compute_done_out,
    output reg                                     gqa_compute_stop_out
);

    localparam GEMM_BYPASS    = 4'd1,
               GEMM_ROPE      = 4'd2,
               GEMM_RTQT      = 4'd3,
               GEMM_QT        = 4'd4,
               GEMM_PRERMS    = 4'd5,
               GEMM_SWIGELU   = 4'd6,
               GEMM_TRANSPOSE = 4'd7,
               GEMM_GQA       = 4'd8,
               GEMV_BYPASS    = 4'd9,
               GEMV_ROPE      = 4'd10,
               GEMV_PRERMS    = 4'd11,
               GEMV_SWIGELU   = 4'd13;

    localparam HALF_ROW = DATA_WIDTH * DATA_NUM;
    localparam ROW_WIDTH = DATA_WIDTH * DATA_NUM * 2;

    integer kk;
    genvar  i;

    wire is_gemm_proj = is_gemm_mode &&  is_proj_mode;
    wire is_gemv_proj = !is_gemm_mode &&  is_proj_mode;
    wire is_ffn_mode  = (fuse_mode == GEMM_SWIGELU) || (fuse_mode == GEMV_SWIGELU);

    wire [HALF_ROW-1:0] core_lane        [0:CORE_NUM-1];
    wire [HALF_ROW-1:0] core_lane_masked [0:CORE_NUM-1];
    generate
        for (i = 0; i < CORE_NUM; i = i + 1) begin : gen_slice
            assign core_lane[i]        = d_in[i*HALF_ROW +: HALF_ROW];
            assign core_lane_masked[i] = in_vld[i] ? core_lane[i] : {HALF_ROW{1'b0}};
        end
    endgenerate

    localparam integer DEPTH = ($clog2(CORE_NUM) < 1) ? 1 : $clog2(CORE_NUM);
    reg [HALF_ROW-1:0] t_lane [0:DEPTH][0:CORE_NUM-1];
    reg                t_vld  [0:DEPTH][0:CORE_NUM-1];
    reg                t_ffn  [0:DEPTH];

    genvar gr, gn;
    generate
        for (gr = 1; gr <= DEPTH-1; gr = gr + 1) begin : g_reduce
            localparam integer NN = CORE_NUM >> gr;
            for (gn = 0; gn < NN; gn = gn + 1) begin : g_node
                wire [HALF_ROW-1:0] ch0, ch1;
                wire                cv0, cv1;
                if (gr == 1) begin : src_in
                    assign ch0 = core_lane_masked[2*gn];   assign ch1 = core_lane_masked[2*gn+1];
                    assign cv0 = in_vld[2*gn];             assign cv1 = in_vld[2*gn+1];
                end else begin : src_red
                    assign ch0 = t_lane[gr-1][2*gn];       assign ch1 = t_lane[gr-1][2*gn+1];
                    assign cv0 = t_vld[gr-1][2*gn];        assign cv1 = t_vld[gr-1][2*gn+1];
                end
                always @(posedge clk or negedge rst_n)
                    if (!rst_n || isa_valid) begin
                        t_lane[gr][gn] <= {HALF_ROW{1'b0}};
                        t_vld[gr][gn]  <= 1'b0;
                    end else begin
                        t_lane[gr][gn] <= ch0 | ch1;
                        t_vld[gr][gn]  <= cv0 | cv1;
                    end
            end
            always @(posedge clk or negedge rst_n)
                if (!rst_n || isa_valid) t_ffn[gr] <= 1'b0;
                else                     t_ffn[gr] <= (gr == 1) ? is_ffn_mode : t_ffn[gr-1];
        end
    endgenerate

    wire [HALF_ROW-1:0] cin0, cin1;
    wire                cvin0, cvin1, cffn;
    generate
        if (DEPTH >= 2) begin : c_from_reduce
            assign cin0 = t_lane[DEPTH-1][0]; assign cin1 = t_lane[DEPTH-1][1];
            assign cvin0 = t_vld[DEPTH-1][0]; assign cvin1 = t_vld[DEPTH-1][1];
            assign cffn = t_ffn[DEPTH-1];
        end else if (CORE_NUM == 1) begin : c_from_input_single
            assign cin0 = core_lane_masked[0]; assign cin1 = {HALF_ROW{1'b0}};
            assign cvin0 = in_vld[0]; assign cvin1 = 1'b0;
            assign cffn = is_ffn_mode;
        end else begin : c_from_input
            assign cin0 = core_lane_masked[0]; assign cin1 = core_lane_masked[1];
            assign cvin0 = in_vld[0]; assign cvin1 = in_vld[1];
            assign cffn = is_ffn_mode;
        end
    endgenerate

    reg [HALF_ROW-1:0] c_gate_lane;
    reg [HALF_ROW-1:0] c_val_lane;
    reg                c_gate_vld;
    reg                c_val_vld;
    reg                c_is_ffn;

    wire [HALF_ROW-1:0] c_gate_lane_w = cffn ? cin0 : (cin0 | cin1);
    wire [HALF_ROW-1:0] c_val_lane_w  = cffn ? cin1 : {HALF_ROW{1'b0}};
    wire                c_gate_vld_w  = cffn ? cvin0 : (cvin0 | cvin1);
    wire                c_val_vld_w   = cffn ? cvin1 : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_gate_lane <= {HALF_ROW{1'b0}};
            c_val_lane  <= {HALF_ROW{1'b0}};
            c_gate_vld  <= 1'b0;
            c_val_vld   <= 1'b0;
            c_is_ffn    <= 1'b0;
        end else if (isa_valid) begin
            c_gate_lane <= {HALF_ROW{1'b0}};
            c_val_lane  <= {HALF_ROW{1'b0}};
            c_gate_vld  <= 1'b0;
            c_val_vld   <= 1'b0;
            c_is_ffn    <= 1'b0;
        end else begin
            c_gate_lane <= c_gate_lane_w;
            c_val_lane  <= c_val_lane_w;
            c_gate_vld  <= c_gate_vld_w;
            c_val_vld   <= c_val_vld_w;
            c_is_ffn    <= cffn;
        end
    end

    reg                pack_half;
    reg [HALF_ROW-1:0] gate_low_buf;
    reg [HALF_ROW-1:0] val_low_buf;

    wire dsw_ffn = is_gemv_proj && is_ffn_mode;
    reg                gate_half;
    reg                val_half;
    reg                gate_row_ready;
    reg                val_row_ready;
    reg [ROW_WIDTH-1:0] dsw_gate_row;
    reg [ROW_WIDTH-1:0] dsw_val_row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pack_half              <= 1'b0;
            gate_low_buf           <= {HALF_ROW{1'b0}};
            val_low_buf            <= {HALF_ROW{1'b0}};
            core_row_valid         <= 1'b0;
            core_row_data          <= {ROW_WIDTH{1'b0}};
            core_row_data_swig_val <= {ROW_WIDTH{1'b0}};
            gate_half              <= 1'b0;
            val_half               <= 1'b0;
            gate_row_ready         <= 1'b0;
            val_row_ready          <= 1'b0;
            dsw_gate_row           <= {ROW_WIDTH{1'b0}};
            dsw_val_row            <= {ROW_WIDTH{1'b0}};
        end else if (isa_valid) begin
            pack_half              <= 1'b0;
            gate_low_buf           <= {HALF_ROW{1'b0}};
            val_low_buf            <= {HALF_ROW{1'b0}};
            core_row_valid         <= 1'b0;
            core_row_data          <= {ROW_WIDTH{1'b0}};
            core_row_data_swig_val <= {ROW_WIDTH{1'b0}};
            gate_half              <= 1'b0;
            val_half               <= 1'b0;
            gate_row_ready         <= 1'b0;
            val_row_ready          <= 1'b0;
            dsw_gate_row           <= {ROW_WIDTH{1'b0}};
            dsw_val_row            <= {ROW_WIDTH{1'b0}};
        end else begin
            core_row_valid <= 1'b0;

            if (dsw_ffn) begin
                if (c_gate_vld) begin
                    if (gate_half == 1'b0) begin
                        gate_low_buf <= c_gate_lane;
                        gate_half    <= 1'b1;
                    end else begin
                        dsw_gate_row   <= {c_gate_lane, gate_low_buf};
                        gate_row_ready <= 1'b1;
                        gate_half      <= 1'b0;
                    end
                end
                if (c_val_vld) begin
                    if (val_half == 1'b0) begin
                        val_low_buf <= c_val_lane;
                        val_half    <= 1'b1;
                    end else begin
                        dsw_val_row   <= {c_val_lane, val_low_buf};
                        val_row_ready <= 1'b1;
                        val_half      <= 1'b0;
                    end
                end
                if ((gate_row_ready || (c_gate_vld && gate_half)) &&
                    (val_row_ready  || (c_val_vld  && val_half ))) begin
                    core_row_valid         <= 1'b1;
                    core_row_data          <= (c_gate_vld && gate_half) ? {c_gate_lane, gate_low_buf} : dsw_gate_row;
                    core_row_data_swig_val <= (c_val_vld  && val_half ) ? {c_val_lane,  val_low_buf } : dsw_val_row;
                    gate_row_ready <= 1'b0;
                    val_row_ready  <= 1'b0;
                end
            end else if (c_gate_vld) begin
                if (pack_half == 1'b0) begin
                    gate_low_buf <= c_gate_lane;
                    if (c_is_ffn) val_low_buf <= c_val_lane;
                    pack_half    <= 1'b1;
                end else begin
                    pack_half      <= 1'b0;
                    core_row_valid <= 1'b1;
                    core_row_data  <= {c_gate_lane, gate_low_buf};
                    if (c_is_ffn) begin
                        core_row_data_swig_val <= {c_val_lane, val_low_buf};
                    end else begin
                        core_row_data_swig_val <= {ROW_WIDTH{1'b0}};
                    end
                end
            end
        end
    end

    reg [CORE_NUM-1:0] cc_mask;
    always @* begin
        cc_mask = {CORE_NUM{1'b0}};
        if (is_gemm_proj) begin
            cc_mask = {CORE_NUM{1'b1}};
        end else if (is_gemv_proj) begin
            for (kk = 0; kk < CORE_NUM; kk = kk + 1) begin
                if (kk < decode_core_num) cc_mask[kk] = 1'b1;
                if (is_ffn_mode && kk >= (CORE_NUM/2) &&
                    kk < (CORE_NUM/2) + decode_core_num) cc_mask[kk] = 1'b1;
            end
        end
    end

    reg  [CORE_NUM-1:0] cc_latch;
    wire [CORE_NUM-1:0] cc_latch_next = cc_latch | core_compute_done;
    wire use_proj_latch = is_gemm_proj || is_gemv_proj;
    wire mask_nonzero   = |cc_mask;
    wire all_proj_done  = mask_nonzero && ((cc_latch_next & cc_mask) == cc_mask);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cc_latch                 <= {CORE_NUM{1'b0}};
            core_compute_done_out    <= 1'b0;
            gqa_q_phase_done_out     <= 1'b0;
            gqa_score_phase_done_out <= 1'b0;
            gqa_compute_stop_out     <= 1'b0;
        end else if (isa_valid) begin
            cc_latch                 <= {CORE_NUM{1'b0}};
            core_compute_done_out    <= 1'b0;
            gqa_q_phase_done_out     <= 1'b0;
            gqa_score_phase_done_out <= 1'b0;
            gqa_compute_stop_out     <= 1'b0;
        end else begin
            gqa_q_phase_done_out     <= |gqa_q_phase_done;
            gqa_score_phase_done_out <= |gqa_score_phase_done;
            gqa_compute_stop_out     <= |gqa_compute_stop;

            if (use_proj_latch) begin
                if (all_proj_done) begin
                    core_compute_done_out <= 1'b1;
                    cc_latch              <= {CORE_NUM{1'b0}};
                end else begin
                    core_compute_done_out <= 1'b0;
                    cc_latch              <= cc_latch_next;
                end
            end else begin
                core_compute_done_out <= |core_compute_done;
                cc_latch              <= {CORE_NUM{1'b0}};
            end
        end
    end

endmodule
