// SPDX-License-Identifier: Apache-2.0
module outlier_compressor #(
    parameter PREC = 16,
    parameter DATA_NUM = 128,
    parameter A_XFERS = 1,
    parameter W_XFERS = 1
)
(
    input wire                              clk,
    input wire                              rst_n,
    input wire                              isa_valid,

    input wire [2:0]                        mode,
    input wire [6:0]                        outlier_num,
    input wire                              outlier_pos_write_phase,

    input wire                              in_vld,
    input wire                              in_pos_or_val,
    input wire [128*5-1:0]                  in_data,
    input wire                              proj_done,
    input wire                              scale_zp_emit_done,

    input wire                              comb_sram_wen,
    input wire [101:0]                      comb_sram_wdata,

    output reg                              out_vld,
    output reg [PREC*DATA_NUM-1:0]          out_data,
    output wire                             outlier_pos_start_write,
    output wire                             outlier_val_start_write,
    output wire [1:0]                       outlier_val_burst_length,
    output wire [$clog2(W_XFERS)-1:0]       outlier_pos_emit_bundle,
    output wire [$clog2(W_XFERS)-1:0]       outlier_val_emit_bundle
);

    genvar i;
    integer idx;

    localparam ROW_WIDTH = PREC*DATA_NUM;
    localparam BANDWIDTH = 8192;

    wire [13:0] out_shift_bits;
    wire [7:0] compress_bits;
    wire [10:0] pos_bookmark_capacity;

    wire int2_mode = (mode == 3'b010 || mode == 3'b011 || mode == 3'b110);
    wire int4_mode = (mode == 3'b100 || mode == 3'b101 || mode == 3'b111);
    wire bitmask_mode = outlier_num > 7'd32 && outlier_num < 7'd96;
    wire numerous_outlier_mode = outlier_num >= 7'd96;

    wire [12:0] val_bookmark_capacity =
        int2_mode ? 13'd4096 :
        int4_mode ? 13'd2048 :
        13'd0;

    outlier_compressor_lut u_outlier_compressor_lut (
        .clk              (clk),
        .rst_n            (rst_n),
        .isa_valid        (isa_valid),
        .outlier_num      (outlier_num),
        .compress_bits    (compress_bits),
        .out_shift_bits   (out_shift_bits),
        .bookmark_capacity(pos_bookmark_capacity)
    );

    reg [128*7-1:0] n_vector;
    reg [128-1:0] bitmask_vector;
    reg pos_vector_vld, val_vector_vld;
    reg [128-1:0] compress_vector, compress_vector_out;
    reg compress_out_vld;

    reg [128*4-1:0] val_vector;
    wire [128*2-1:0] val_vector_int2;

    generate
    for(i=0; i<128; i=i+1) begin : GEN_VAL_VECTOR_INT2
        assign val_vector_int2[2*i +: 2] = val_vector[4*i +: 2];
    end
    endgenerate

    reg [8192+2048-1:0] outlier_pos_buf [0:W_XFERS-1];

    reg [24576+2048-1:0] outlier_val_buf [0:W_XFERS-1];

    reg [12:0] pos_bookmark [0:W_XFERS-1];

    reg wen;
    reg [ROW_WIDTH-1:0] wdata;
    reg [BANDWIDTH-1:0] out_data_interm;
    reg [5:0] waddr;
    reg [5:0] write_cnt;

    reg ren;
    reg [5:0] raddr;
    reg [5:0] read_cnt;
    reg read_phase;
    reg [5:0] read_target_cnt;
    wire rvalid;
    wire [ROW_WIDTH-1:0] rdata;

    reg pos_comp_in_vld;
    reg [128-1:0] pos_comp_in_data;
    wire pos_comp_out_vld;
    wire [128-1:0] pos_comp_out_data;

    reg [5:0] reset_phase_cnt;

    reg proj_done_latch;

    reg pos_bookmark_reset_start;
    reg pos_bookmark_reset_start_latch;
    reg pos_bookmark_write_phase;

    reg [14:0] val_bookmark [0:W_XFERS-1];
    reg [12:0] val_bookmark_increment;
    reg val_bookmark_reset_start;
    reg val_bookmark_reset_start_latch;
    reg val_bookmark_write_phase;

    reg [1:0] val_burst_cnt;
    reg [1:0] val_burst_idx;
    reg [1:0] burst_length_reg;

    reg [8:0] comp_out_vld_cnt;
    reg [3:0] pos_w_cnt;
    reg [8:0] val_in_vld_cnt;
    reg [3:0] val_w_cnt;
    reg [3:0] val_emit_w_cnt;
    reg [3:0] val_wr_buf_idx;

    localparam PF_IDLE = 2'd0, PF_POS = 2'd1, PF_VAL = 2'd2;
    reg [1:0] proj_flush_state;
    reg [3:0] proj_flush_w_idx;
    reg [3:0] pos_emit_buf_idx;

    wire [12:0] pos_bookmark_cur  = pos_bookmark[pos_w_cnt];
    wire [14:0] val_bookmark_emit = val_bookmark[val_emit_w_cnt];

    wire pos_bookmark_reset = (pos_bookmark_capacity != 11'd0)
                           && (pos_bookmark_cur >= {2'd0, pos_bookmark_capacity});

    wire [10:0] pos_half_cap = pos_bookmark_capacity >> 1;
    wire pos_in_upper = pos_bookmark_cur >= {2'd0, pos_half_cap};
    wire [12:0] pos_local_idx = pos_in_upper ? (pos_bookmark_cur - {2'd0, pos_half_cap}) : pos_bookmark_cur;
    wire [20:0] pos_pack_offset = (pos_in_upper ? 21'd4096 : 21'd0) + {13'd0, compress_bits} * {8'd0, pos_local_idx};

    function [1:0] calc_val_bursts;
        input [14:0] bm;
        input [12:0] cap;
        reg [15:0] cap1;
        reg [15:0] cap2;
        begin
            cap1 = {3'b0, cap};
            cap2 = {2'b0, cap, 1'b0};
            if(bm == 15'd0)              calc_val_bursts = 2'd0;
            else if({1'b0, bm} <= cap1)  calc_val_bursts = 2'd1;
            else if({1'b0, bm} <= cap2)  calc_val_bursts = 2'd2;
            else                         calc_val_bursts = 2'd3;
        end
    endfunction

    assign outlier_pos_start_write = pos_bookmark_reset_start;
    assign outlier_val_start_write = val_bookmark_reset_start;
    assign outlier_val_burst_length = burst_length_reg;
    assign outlier_pos_emit_bundle  = pos_emit_buf_idx[$clog2(W_XFERS)-1:0];
    assign outlier_val_emit_bundle  = val_wr_buf_idx[$clog2(W_XFERS)-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_vector_vld <= 1'b0;
            out_vld <= 1'b0;
            out_data <= {ROW_WIDTH{1'b0}};

            compress_vector <= 128'd0;
            compress_vector_out <= 128'd0;
            compress_out_vld <= 1'b0;

            for(idx=0; idx<W_XFERS; idx=idx+1) begin
                outlier_pos_buf[idx] <= {(8192+2048){1'b0}};
                outlier_val_buf[idx] <= {(24576+2048){1'b0}};
                pos_bookmark[idx] <= 13'd0;
                val_bookmark[idx] <= 15'd0;
            end

            comp_out_vld_cnt <= 9'd0;
            pos_w_cnt        <= 4'd0;
            val_in_vld_cnt   <= 9'd0;
            val_w_cnt        <= 4'd0;
            val_emit_w_cnt   <= 4'd0;
            val_wr_buf_idx   <= 4'd0;
            proj_flush_state <= PF_IDLE;
            proj_flush_w_idx <= 4'd0;
            pos_emit_buf_idx <= 4'd0;

            wen <= 1'b0;
            wdata <= {ROW_WIDTH{1'b0}};
            out_data_interm <= {BANDWIDTH{1'b0}};
            waddr <= 6'd0;
            write_cnt <= 6'd0;

            ren <= 1'b0;
            raddr <= 6'd0;
            read_cnt <= 6'd0;
            read_phase <= 1'b0;
            read_target_cnt <= 6'd0;

            pos_comp_in_vld <= 1'b0;
            pos_comp_in_data <= {(128){1'b0}};

            reset_phase_cnt <= 6'd0;

            proj_done_latch <= 1'b0;

            pos_bookmark_reset_start <= 1'b0;
            pos_bookmark_reset_start_latch <= 1'b0;
            pos_bookmark_write_phase <= 1'b0;

            val_vector_vld <= 1'b0;
            val_bookmark_reset_start <= 1'b0;
            val_bookmark_reset_start_latch <= 1'b0;
            val_bookmark_write_phase <= 1'b0;

            val_burst_cnt <= 2'd0;
            val_burst_idx <= 2'd0;
            burst_length_reg <= 2'd0;

        end else begin
            compress_out_vld <= 1'b0;
            out_vld <= 1'b0;
            ren <= 1'b0;
            wen <= 1'b0;
            pos_comp_in_vld <= 1'b0;
            val_bookmark_reset_start <= 1'b0;

            pos_vector_vld <= in_vld && !in_pos_or_val;
            val_vector_vld <= in_vld && in_pos_or_val;

            if(pos_vector_vld) begin
                pos_comp_in_vld <= 1'b1;
                pos_comp_in_data <= bitmask_vector;
            end

            if(pos_comp_out_vld) begin
                compress_out_vld <= 1'b1;
                compress_vector_out <= pos_comp_out_data;
            end

            if(compress_out_vld) begin
                comp_out_vld_cnt <= comp_out_vld_cnt + 9'd1;
                if(comp_out_vld_cnt == (A_XFERS << 7) - 1) begin
                    comp_out_vld_cnt <= 9'd0;
                    pos_w_cnt <= (pos_w_cnt == W_XFERS-1) ? 4'd0 : pos_w_cnt + 4'd1;
                end
                if(pos_bookmark_reset && outlier_pos_write_phase) begin
                    pos_bookmark_reset_start <= 1'b1;
                    pos_emit_buf_idx <= pos_w_cnt;
                    out_data_interm <= outlier_pos_buf[pos_w_cnt][BANDWIDTH-1:0];
                    outlier_pos_buf[pos_w_cnt] <= (outlier_pos_buf[pos_w_cnt] >> out_shift_bits) |
                                                  ({{(8192){1'b0}}, compress_vector_out} << (compress_bits * (pos_bookmark_cur - {2'd0, pos_bookmark_capacity})));
                    pos_bookmark[pos_w_cnt] <= pos_bookmark_cur + 13'd1 - {2'd0, pos_bookmark_capacity};
                end else begin
                    outlier_pos_buf[pos_w_cnt] <= outlier_pos_buf[pos_w_cnt] | ({{(8192){1'b0}}, compress_vector_out} << pos_pack_offset);
                    pos_bookmark[pos_w_cnt] <= pos_bookmark_cur + 13'd1;
                end
            end

            if(proj_done) begin
                proj_done_latch <= 1'b1;
            end

            if(!pos_bookmark_write_phase && !pos_bookmark_reset_start && !pos_bookmark_reset_start_latch &&
               !val_bookmark_write_phase && !val_bookmark_reset_start && !val_bookmark_reset_start_latch) begin
                case(proj_flush_state)
                    PF_IDLE: begin
                        if(proj_done_latch) begin
                            proj_flush_state <= PF_POS;
                            proj_flush_w_idx <= 4'd0;
                        end
                    end
                    PF_POS: begin
                        if(pos_bookmark[proj_flush_w_idx] != 13'd0) begin
                            pos_bookmark_reset_start <= 1'b1;
                            pos_emit_buf_idx <= proj_flush_w_idx;
                            out_data_interm <= outlier_pos_buf[proj_flush_w_idx][BANDWIDTH-1:0];
                            outlier_pos_buf[proj_flush_w_idx] <= {(8192+2048){1'b0}};
                            pos_bookmark[proj_flush_w_idx] <= 13'd0;
                        end
                        if(proj_flush_w_idx == W_XFERS-1) begin
                            proj_flush_state <= PF_VAL;
                            proj_flush_w_idx <= 4'd0;
                        end else begin
                            proj_flush_w_idx <= proj_flush_w_idx + 4'd1;
                        end
                    end
                    PF_VAL: begin
                        if(val_bookmark[proj_flush_w_idx] != 15'd0) begin
                            val_wr_buf_idx   <= proj_flush_w_idx;
                            val_burst_cnt    <= calc_val_bursts(val_bookmark[proj_flush_w_idx], val_bookmark_capacity);
                            burst_length_reg <= calc_val_bursts(val_bookmark[proj_flush_w_idx], val_bookmark_capacity);
                            val_burst_idx    <= 2'd0;
                            val_bookmark_reset_start <= 1'b1;
                            // synthesis translate_off
                            $display("[%0t] DBG_VAL_EMIT: PF_VAL buf=%0d bookmark=%0d bursts=%0d",
                                $time, proj_flush_w_idx, val_bookmark[proj_flush_w_idx],
                                calc_val_bursts(val_bookmark[proj_flush_w_idx], val_bookmark_capacity));
                            // synthesis translate_on
                        end
                        if(proj_flush_w_idx == W_XFERS-1) begin
                            proj_flush_state <= PF_IDLE;
                            proj_done_latch  <= 1'b0;
                            comp_out_vld_cnt <= 9'd0;
                            pos_w_cnt        <= 4'd0;
                            val_in_vld_cnt   <= 9'd0;
                            val_w_cnt        <= 4'd0;
                            val_emit_w_cnt   <= 4'd0;
                        end else begin
                            proj_flush_w_idx <= proj_flush_w_idx + 4'd1;
                        end
                    end
                    default: begin
                        proj_flush_state <= PF_IDLE;
                    end
                endcase
            end

            if(pos_bookmark_write_phase) begin
                out_vld <= 1'b1;
                out_data <= out_data_interm[ROW_WIDTH*write_cnt[1:0] +: ROW_WIDTH];
                write_cnt <= write_cnt + 6'd1;
                if(write_cnt == 6'd3) begin
                    write_cnt <= 6'd0;
                    pos_bookmark_write_phase <= 1'b0;
                end
            end else if(pos_bookmark_reset_start_latch) begin
                reset_phase_cnt <= reset_phase_cnt + 6'd1;
                if(reset_phase_cnt == 6'd6) begin
                    reset_phase_cnt <= 6'd0;
                    pos_bookmark_write_phase <= pos_bookmark_reset_start_latch;
                    pos_bookmark_reset_start_latch <= 1'b0;
                end
            end else if(pos_bookmark_reset_start) begin
                pos_bookmark_reset_start_latch <= pos_bookmark_reset_start;
                pos_bookmark_reset_start <= 1'b0;
            end

            if(val_vector_vld) begin
                val_in_vld_cnt <= val_in_vld_cnt + 9'd1;
                if(val_in_vld_cnt == (A_XFERS << 7) - 1) begin
                    val_in_vld_cnt <= 9'd0;
                    val_w_cnt <= (val_w_cnt == W_XFERS-1) ? 4'd0 : val_w_cnt + 4'd1;
                end
                val_bookmark[val_w_cnt] <= val_bookmark[val_w_cnt] + {2'd0, val_bookmark_increment};
                if(int2_mode) begin
                    outlier_val_buf[val_w_cnt] <= outlier_val_buf[val_w_cnt] | ({{(24576){1'b0}}, val_vector_int2} << (2 * val_bookmark[val_w_cnt]));
                end else if(int4_mode) begin
                    outlier_val_buf[val_w_cnt] <= outlier_val_buf[val_w_cnt] | ({{(24576){1'b0}}, val_vector} << (4 * val_bookmark[val_w_cnt]));
                end
            end

            if(scale_zp_emit_done) begin
                val_wr_buf_idx   <= val_emit_w_cnt;
                val_burst_cnt    <= calc_val_bursts(val_bookmark_emit, val_bookmark_capacity);
                burst_length_reg <= calc_val_bursts(val_bookmark_emit, val_bookmark_capacity);
                val_burst_idx    <= 2'd0;
                if(val_bookmark_emit != 15'd0) begin
                    val_bookmark_reset_start <= 1'b1;
                end
                val_emit_w_cnt <= (val_emit_w_cnt == W_XFERS-1) ? 4'd0 : val_emit_w_cnt + 4'd1;
                // synthesis translate_off
                $display("[%0t] DBG_VAL_EMIT: scale_zp_emit_done buf=%0d bookmark=%0d bursts=%0d",
                    $time, val_emit_w_cnt, val_bookmark_emit,
                    calc_val_bursts(val_bookmark_emit, val_bookmark_capacity));
                // synthesis translate_on
            end

            if(val_bookmark_write_phase) begin
                out_vld <= 1'b1;
                out_data <= outlier_val_buf[val_wr_buf_idx][ROW_WIDTH*({4'd0, val_burst_idx} * 6'd4 + write_cnt) +: ROW_WIDTH];
                write_cnt <= write_cnt + 6'd1;
                if(write_cnt == 6'd3) begin
                    write_cnt <= 6'd0;
                    val_burst_idx <= val_burst_idx + 2'd1;
                    if(val_burst_idx + 2'd1 >= val_burst_cnt) begin
                        val_bookmark_write_phase <= 1'b0;
                        outlier_val_buf[val_wr_buf_idx] <= {(24576+2048){1'b0}};
                        val_bookmark[val_wr_buf_idx] <= 15'd0;
                    end
                end
            end else if(val_bookmark_reset_start_latch) begin
                reset_phase_cnt <= reset_phase_cnt + 6'd1;
                if(reset_phase_cnt == 6'd6) begin
                    reset_phase_cnt <= 6'd0;
                    val_bookmark_write_phase <= val_bookmark_reset_start_latch;
                    val_bookmark_reset_start_latch <= 1'b0;
                end
            end else if(val_bookmark_reset_start) begin
                val_bookmark_reset_start_latch <= val_bookmark_reset_start;
                val_bookmark_reset_start <= 1'b0;
            end
        end
    end

    wire [127:0] ps_in;
    wire [127:0] int2_ps_in;
    wire [127:0] int4_ps_in;
    wire [128*7-1:0] ps_out;

    generate
    for(i = 0; i < 128; i = i + 1) begin : gen_int2_ps_in
        assign int2_ps_in[i] = in_data[5*i+2];
    end
    endgenerate

    generate
    for(i = 0; i < 128; i = i + 1) begin : gen_int4_ps_in
        assign int4_ps_in[i] = in_data[5*i+4];
    end
    endgenerate

    assign ps_in =
        numerous_outlier_mode && int2_mode ? ~int2_ps_in :
        numerous_outlier_mode && int4_mode ? ~int4_ps_in :
        int2_mode ? int2_ps_in :
        int4_mode ? int4_ps_in :
        128'd0;

    partial_sum ps_inst (
        .in_data(ps_in),
        .out_data(ps_out)
    );

    wire [128*7-1:0] n_vector_next;
    wire [128*4-1:0] val_vector_next;

    generate
    for(i = 0; i < 128; i = i + 1) begin : reverse_map_gen
        wire [3:0] found_val;
        wire [127:0] match_mask;
        wire [3:0] val_contributions [0:127];

        genvar j;
        for(j = 0; j < 128; j = j + 1) begin : check_src
            assign match_mask[j] = ps_in[j] && (ps_out[7*j +: 7] == i[6:0]);
            assign val_contributions[j] = match_mask[j] ?
                (int2_mode ? {2'b0, in_data[5*j +: 2]} : in_data[5*j +: 4]) : 4'd0;
        end

        assign found_val = val_contributions[0] | val_contributions[1] | val_contributions[2] | val_contributions[3] |
                           val_contributions[4] | val_contributions[5] | val_contributions[6] | val_contributions[7] |
                           val_contributions[8] | val_contributions[9] | val_contributions[10] | val_contributions[11] |
                           val_contributions[12] | val_contributions[13] | val_contributions[14] | val_contributions[15] |
                           val_contributions[16] | val_contributions[17] | val_contributions[18] | val_contributions[19] |
                           val_contributions[20] | val_contributions[21] | val_contributions[22] | val_contributions[23] |
                           val_contributions[24] | val_contributions[25] | val_contributions[26] | val_contributions[27] |
                           val_contributions[28] | val_contributions[29] | val_contributions[30] | val_contributions[31] |
                           val_contributions[32] | val_contributions[33] | val_contributions[34] | val_contributions[35] |
                           val_contributions[36] | val_contributions[37] | val_contributions[38] | val_contributions[39] |
                           val_contributions[40] | val_contributions[41] | val_contributions[42] | val_contributions[43] |
                           val_contributions[44] | val_contributions[45] | val_contributions[46] | val_contributions[47] |
                           val_contributions[48] | val_contributions[49] | val_contributions[50] | val_contributions[51] |
                           val_contributions[52] | val_contributions[53] | val_contributions[54] | val_contributions[55] |
                           val_contributions[56] | val_contributions[57] | val_contributions[58] | val_contributions[59] |
                           val_contributions[60] | val_contributions[61] | val_contributions[62] | val_contributions[63] |
                           val_contributions[64] | val_contributions[65] | val_contributions[66] | val_contributions[67] |
                           val_contributions[68] | val_contributions[69] | val_contributions[70] | val_contributions[71] |
                           val_contributions[72] | val_contributions[73] | val_contributions[74] | val_contributions[75] |
                           val_contributions[76] | val_contributions[77] | val_contributions[78] | val_contributions[79] |
                           val_contributions[80] | val_contributions[81] | val_contributions[82] | val_contributions[83] |
                           val_contributions[84] | val_contributions[85] | val_contributions[86] | val_contributions[87] |
                           val_contributions[88] | val_contributions[89] | val_contributions[90] | val_contributions[91] |
                           val_contributions[92] | val_contributions[93] | val_contributions[94] | val_contributions[95] |
                           val_contributions[96] | val_contributions[97] | val_contributions[98] | val_contributions[99] |
                           val_contributions[100] | val_contributions[101] | val_contributions[102] | val_contributions[103] |
                           val_contributions[104] | val_contributions[105] | val_contributions[106] | val_contributions[107] |
                           val_contributions[108] | val_contributions[109] | val_contributions[110] | val_contributions[111] |
                           val_contributions[112] | val_contributions[113] | val_contributions[114] | val_contributions[115] |
                           val_contributions[116] | val_contributions[117] | val_contributions[118] | val_contributions[119] |
                           val_contributions[120] | val_contributions[121] | val_contributions[122] | val_contributions[123] |
                           val_contributions[124] | val_contributions[125] | val_contributions[126] | val_contributions[127];

        assign val_vector_next[4*i +: 4] = found_val;
    end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bitmask_vector <= 128'd0;
            val_vector <= {(128*4){1'b0}};
            val_bookmark_increment <= 13'd0;
        end else begin
            if(in_vld && !in_pos_or_val) begin
                bitmask_vector <= ps_in;
            end else if(in_vld && in_pos_or_val) begin
                val_vector <= val_vector_next;
                val_bookmark_increment <= {6'd0, ps_out[7*127 +: 7]} + {12'd0, ps_in[127]};
            end
        end
    end

    cns_compressor u_cns_compressor (
        .clk    (clk),
        .rst_n  (rst_n),
        .isa_valid(isa_valid),
        .wen    (comb_sram_wen),
        .wdata  (comb_sram_wdata),
        .in_vld (pos_comp_in_vld),
        .bitmask_mode(bitmask_mode),
        .outlier_num(outlier_num),
        .in_data(pos_comp_in_data),
        .out_vld (pos_comp_out_vld),
        .out_data(pos_comp_out_data)
    );

endmodule
