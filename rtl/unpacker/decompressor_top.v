// SPDX-License-Identifier: Apache-2.0
module decompressor_top (
    input wire                  clk,
    input wire                  rst_n,
    input wire                  isa_valid,

    input wire                  int2_or_int4_mode,
    input wire [6:0]            outlier_num,

    input wire                  rom_wen,
    input wire [101:0]          rom_wdata,

    input wire                  outlier_val_in_vld,
    input wire [4095:0]         outlier_val_in_data,

    input wire                  in_vld,
    input wire [102*16-1:0]     in_data,
    output wire                 out_vld,
    output wire [4096-1:0]      out_data
);

    genvar i;

    wire [15:0] out_vld_w;
    wire redecomp_vld = &out_vld_w;
    wire [2047:0] redecomp_data;

    reg [101:0] rom_data [31:0];

    reg [4:0] rom_waddr_cnt;
    reg rom_write_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_waddr_cnt <= 5'd0;
            rom_write_done <= 1'b0;
        end else begin
            if (isa_valid) begin
                rom_waddr_cnt <= 5'd0;
                rom_write_done <= 1'b0;
            end else if (!rom_write_done && rom_wen) begin
                rom_data[rom_waddr_cnt] <= rom_waddr_cnt >= outlier_num ? {102{1'b1}} : rom_wdata;
                rom_waddr_cnt <= rom_waddr_cnt + 5'd1;
                if (rom_waddr_cnt == 5'd31) begin
                    rom_write_done <= 1'b1;
                    rom_waddr_cnt <= 5'd0;
                end
            end
        end
    end

    wire [102*33-1:0] rom_flat;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_rom_flat
            assign rom_flat[102*i +: 102] = rom_data[i];
        end
    endgenerate
    assign rom_flat[102*32 +: 102] = {102{1'b1}};

    wire [101:0] rom_arr [0:32];
    generate
        for (i = 0; i < 33; i = i + 1) begin : gen_rom_arr
            assign rom_arr[i] = rom_flat[102*i +: 102];
        end
    endgenerate

    generate
    for(i=0; i<16; i=i+1) begin : REDecompressor_gen
        wire [101:0] ch_val = in_data[102*i +: 102];
        reg [101:0] ch_val_r;

        wire [5:0] lo_0 = 6'd0;
        wire [5:0] hi_0 = 6'd32;
        wire [5:0] mid_0 = 6'd16;
        wire cmp_s0 = (ch_val < rom_arr[mid_0]);
        wire [5:0] lo_1 = cmp_s0 ? lo_0 : (mid_0 + 6'd1);
        wire [5:0] hi_1 = cmp_s0 ? mid_0 : hi_0;

        wire [5:0] mid_1 = (lo_1 + hi_1) >> 1;
        wire cmp_s1 = (ch_val < rom_arr[mid_1]);
        wire [5:0] lo_2 = cmp_s1 ? lo_1 : (mid_1 + 6'd1);
        wire [5:0] hi_2 = cmp_s1 ? mid_1 : hi_1;

        wire [5:0] mid_2 = (lo_2 + hi_2) >> 1;
        wire cmp_s2 = (ch_val < rom_arr[mid_2]);
        wire [5:0] lo_3 = cmp_s2 ? lo_2 : (mid_2 + 6'd1);
        wire [5:0] hi_3 = cmp_s2 ? mid_2 : hi_2;
        reg [5:0] lo_3_r, hi_3_r;

        wire [5:0] mid_3 = (lo_3_r + hi_3_r) >> 1;
        wire cmp_s3 = (ch_val_r < rom_arr[mid_3]);
        wire [5:0] lo_4 = cmp_s3 ? lo_3_r : (mid_3 + 6'd1);
        wire [5:0] hi_4 = cmp_s3 ? mid_3 : hi_3_r;

        wire [5:0] mid_4 = (lo_4 + hi_4) >> 1;
        wire cmp_s4 = (ch_val_r < rom_arr[mid_4]);
        wire [5:0] lo_5 = cmp_s4 ? lo_4 : (mid_4 + 6'd1);
        wire [5:0] hi_5 = cmp_s4 ? mid_4 : hi_4;

        wire [5:0] mid_5 = (lo_5 + hi_5) >> 1;
        wire cmp_s5 = (ch_val_r < rom_arr[mid_5]);
        wire [5:0] kl_idx = cmp_s5 ? mid_5 : (mid_5 + 6'd1);

        wire [6:0] kl = {1'b0, kl_idx};
        wire [6:0] kr = outlier_num - kl;

        wire [101:0] offset_prev = (kl_idx > 6'd0) ? rom_arr[kl_idx - 6'd1] : 102'd0;
        wire [101:0] vali = ch_val_r - offset_prev;

        reg [101:0] vali_r;
        reg [6:0] kl_r;
        reg [6:0] kr_r;
        reg in_vld_r1, in_vld_r2;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                vali_r <= 102'd0;
                kl_r <= 7'd0;
                kr_r <= 7'd0;
                in_vld_r1 <= 1'b0;
                in_vld_r2 <= 1'b0;
                hi_3_r <= 6'd0;
                lo_3_r <= 6'd0;
                ch_val_r <= 102'd0;
            end else begin
                in_vld_r1 <= in_vld;
                in_vld_r2 <= in_vld_r1;
                if (in_vld) begin
                    ch_val_r <= ch_val;
                    lo_3_r <= lo_3;
                    hi_3_r <= hi_3;
                end
                if (in_vld_r1) begin
                    vali_r <= vali;
                    kl_r <= kl;
                    kr_r <= kr;
                end
            end
        end

        unit_redecomp u_unit_redecomp_inst (
            .clk(clk),
            .rst_n(rst_n),

            .in_vld(in_vld_r2),
            .vali(vali_r),
            .kl(kl_r),
            .kr(kr_r),
            .out_vld(out_vld_w[i]),
            .out_data(redecomp_data[128*i +: 128])
        );
    end
    endgenerate

    wire                bitmask_out_vld;
    wire [128*16-1:0]   bitmask_out_data;

    bitmask_transposer u_bitmask_transposer (
        .clk     (clk),
        .rst_n   (rst_n),
        .int2_or_int4_mode(int2_or_int4_mode),
        .in_vld  (redecomp_vld),
        .in_data (redecomp_data),
        .out_vld (bitmask_out_vld),
        .out_data(bitmask_out_data)
    );

    reg [1023:0] ovb_block [0:63];
    reg [3:0] outlier_val_in_vld_cnt;

    integer bi;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outlier_val_in_vld_cnt <= 4'd0;
            for (bi = 0; bi < 64; bi = bi + 1)
                ovb_block[bi] <= {1024{1'b0}};
        end else begin
            if(outlier_val_in_vld) begin
                ovb_block[{outlier_val_in_vld_cnt, 2'd0}]     <= outlier_val_in_data[0*1024 +: 1024];
                ovb_block[{outlier_val_in_vld_cnt, 2'd1}]     <= outlier_val_in_data[1*1024 +: 1024];
                ovb_block[{outlier_val_in_vld_cnt, 2'd2}]     <= outlier_val_in_data[2*1024 +: 1024];
                ovb_block[{outlier_val_in_vld_cnt, 2'd3}]     <= outlier_val_in_data[3*1024 +: 1024];
                outlier_val_in_vld_cnt <= outlier_val_in_vld_cnt + 4'd1;
                if(outlier_val_in_vld_cnt == 4'd15) begin
                    outlier_val_in_vld_cnt <= 4'd0;
                end
            end
        end
    end

    wire [2048*8-1:0] ps_out_flat;
    wire [9*8-1:0]    num_one_flat;

    generate
    for (i = 0; i < 8; i = i + 1) begin : partial_sum_instances
        partial_sum_unpacker u_partial_sum_unpacker (
            .in_data  (bitmask_out_data[256*i +: 256]),
            .out_data (ps_out_flat[i*2048 +: 2048]),
            .num_one  (num_one_flat[i*9 +: 9])
        );
    end
    endgenerate

    wire [11:0] chunk_base [0:7];
    assign chunk_base[0] = 12'd0;
    generate
    for (i = 1; i < 8; i = i + 1) begin : gen_chunk_base
        assign chunk_base[i] = chunk_base[i-1] + {3'd0, num_one_flat[(i-1)*9 +: 9]};
    end
    endgenerate
    wire [11:0] total_ones = chunk_base[7] + {3'd0, num_one_flat[7*9 +: 9]};

    reg [15:0] buf_pointer;

    reg [2047:0]     fifo_bitmask  [0:3];
    reg [12*8-1:0]   fifo_cb       [0:3];
    reg [15:0]       fifo_buf_ptr  [0:3];
    reg [2:0]        fifo_wr_ptr;
    reg [2:0]        fifo_rd_ptr;
    reg [2:0]        fifo_count;

    wire fifo_empty = (fifo_count == 3'd0);
    wire fifo_full  = (fifo_count == 3'd4);

    wire             fifo_rd_advance;

    integer ci;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_ptr <= 3'd0;
            fifo_rd_ptr <= 3'd0;
            fifo_count  <= 3'd0;
            buf_pointer <= 16'd0;
        end else begin
            case ({bitmask_out_vld && !fifo_full, fifo_rd_advance})
                2'b10: fifo_count <= fifo_count + 3'd1;
                2'b01: fifo_count <= fifo_count - 3'd1;
                default: ;
            endcase

            if (bitmask_out_vld && !fifo_full) begin
                fifo_bitmask[fifo_wr_ptr[1:0]] <= bitmask_out_data;
                fifo_buf_ptr[fifo_wr_ptr[1:0]] <= buf_pointer;
                for (ci = 0; ci < 8; ci = ci + 1)
                    fifo_cb[fifo_wr_ptr[1:0]][ci*12 +: 12] <= chunk_base[ci];
                fifo_wr_ptr <= (fifo_wr_ptr == 3'd3) ? 3'd0 : fifo_wr_ptr + 3'd1;
                buf_pointer <= buf_pointer + {4'd0, total_ones};
            end

            if (fifo_rd_advance) begin
                fifo_rd_ptr <= (fifo_rd_ptr == 3'd3) ? 3'd0 : fifo_rd_ptr + 3'd1;
            end
        end
    end

    wire [2047:0]     cur_bitmask  = fifo_bitmask[fifo_rd_ptr[1:0]];
    wire [12*8-1:0]   cur_cb       = fifo_cb[fifo_rd_ptr[1:0]];
    wire [15:0]       cur_buf_ptr  = fifo_buf_ptr[fifo_rd_ptr[1:0]];

    wire s1_fire = !fifo_empty;
    assign fifo_rd_advance = s1_fire;

    reg s2_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            s2_valid <= 1'b0;
        else
            s2_valid <= s1_fire;
    end

    wire [11:0] lane_chunk_base [0:7];
    assign lane_chunk_base[0] = cur_cb[0*12 +: 12];
    assign lane_chunk_base[1] = cur_cb[1*12 +: 12];
    assign lane_chunk_base[2] = cur_cb[2*12 +: 12];
    assign lane_chunk_base[3] = cur_cb[3*12 +: 12];
    assign lane_chunk_base[4] = cur_cb[4*12 +: 12];
    assign lane_chunk_base[5] = cur_cb[5*12 +: 12];
    assign lane_chunk_base[6] = cur_cb[6*12 +: 12];
    assign lane_chunk_base[7] = cur_cb[7*12 +: 12];

    wire [511:0]  lane_embed_int2 [0:7];
    wire [1023:0] lane_embed_int4 [0:7];

    generate
    for (i = 0; i < 8; i = i + 1) begin : gen_lane
        wire [15:0] l_chunk_ptr  = cur_buf_ptr + {4'd0, lane_chunk_base[i]};
        wire [17:0] l_bit_addr   = int2_or_int4_mode
                                     ? {l_chunk_ptr, 2'b00}
                                     : {1'b0, l_chunk_ptr, 1'b0};

        wire [5:0] l_blk_idx = l_bit_addr[15:10];
        wire [9:0] l_sub_off = l_bit_addr[9:0];

        wire [1023:0] l_block_A = ovb_block[l_blk_idx];
        wire [1023:0] l_block_B = ovb_block[l_blk_idx + 6'd1];

        reg [1023:0] l_block_A_r;
        reg [1023:0] l_block_B_r;
        reg [9:0]    l_sub_off_r;
        reg [255:0]  l_bitmask_r;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                l_block_A_r <= {1024{1'b0}};
                l_block_B_r <= {1024{1'b0}};
                l_sub_off_r <= 10'd0;
                l_bitmask_r <= {256{1'b0}};
            end else if (s1_fire) begin
                l_block_A_r <= l_block_A;
                l_block_B_r <= l_block_B;
                l_sub_off_r <= l_sub_off;
                l_bitmask_r <= cur_bitmask[i*256 +: 256];
            end
        end

        wire [2047:0] l_shifted = {l_block_B_r, l_block_A_r} >> l_sub_off_r;
        wire [1023:0] l_val_slice = l_shifted[1023:0];

        wire [2047:0] l_ps;
        wire [8:0]    l_num_one_unused;
        partial_sum_unpacker u_lane_psu (
            .in_data  (l_bitmask_r),
            .out_data (l_ps),
            .num_one  (l_num_one_unused)
        );

        wire [67:0] l_coarse_chunks [0:15];
        genvar c;
        for (c = 0; c < 15; c = c + 1) begin : gen_coarse
            assign l_coarse_chunks[c] = l_val_slice[c*64 +: 68];
        end
        assign l_coarse_chunks[15] = {4'b0, l_val_slice[960 +: 64]};

        genvar blk, p;
        for (blk = 0; blk < 32; blk = blk + 1) begin : gen_blk
            wire [7:0] blk_base_psum = l_ps[blk*64 +: 8];
            wire [9:0] blk_base_addr = int2_or_int4_mode
                                         ? {blk_base_psum, 2'b00}
                                         : {1'b0, blk_base_psum, 1'b0};
            wire [3:0] blk_base_ci = blk_base_addr[9:6];

            wire [67:0] blk_chunk_lo = l_coarse_chunks[blk_base_ci];
            wire [67:0] blk_chunk_hi = l_coarse_chunks[blk_base_ci + 4'd1];

            for (p = 0; p < 8; p = p + 1) begin : gen_pos
                localparam integer k = blk * 8 + p;
                wire [7:0] local_psum = l_ps[k*8 +: 8];
                wire       mask_bit   = l_bitmask_r[k];

                wire [9:0] addr = int2_or_int4_mode ? {local_psum, 2'b00}
                                                    : {1'b0, local_psum, 1'b0};
                wire [3:0] coarse_idx = addr[9:6];
                wire [5:0] fine_addr  = addr[5:0];

                wire sel_hi = (coarse_idx != blk_base_ci);
                wire [67:0] selected_chunk = sel_hi ? blk_chunk_hi : blk_chunk_lo;
                wire [3:0] fine_bits = selected_chunk[fine_addr +: 4];

                assign lane_embed_int2[i][k*2 +: 2] = mask_bit ? fine_bits[1:0] : 2'b00;
                assign lane_embed_int4[i][k*4 +: 4] = mask_bit ? fine_bits       : 4'b0000;
            end
        end
    end
    endgenerate

    reg [4095:0] accum_int2;
    reg [8191:0] accum_int4;
    reg          emit_vld;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            emit_vld    <= 1'b0;
            accum_int2  <= {4096{1'b0}};
            accum_int4  <= {8192{1'b0}};
        end else begin
            emit_vld <= 1'b0;

            if (s2_valid) begin
                accum_int2[0*512  +: 512]  <= lane_embed_int2[0];
                accum_int2[1*512  +: 512]  <= lane_embed_int2[1];
                accum_int2[2*512  +: 512]  <= lane_embed_int2[2];
                accum_int2[3*512  +: 512]  <= lane_embed_int2[3];
                accum_int2[4*512  +: 512]  <= lane_embed_int2[4];
                accum_int2[5*512  +: 512]  <= lane_embed_int2[5];
                accum_int2[6*512  +: 512]  <= lane_embed_int2[6];
                accum_int2[7*512  +: 512]  <= lane_embed_int2[7];
                accum_int4[0*1024 +: 1024] <= lane_embed_int4[0];
                accum_int4[1*1024 +: 1024] <= lane_embed_int4[1];
                accum_int4[2*1024 +: 1024] <= lane_embed_int4[2];
                accum_int4[3*1024 +: 1024] <= lane_embed_int4[3];
                accum_int4[4*1024 +: 1024] <= lane_embed_int4[4];
                accum_int4[5*1024 +: 1024] <= lane_embed_int4[5];
                accum_int4[6*1024 +: 1024] <= lane_embed_int4[6];
                accum_int4[7*1024 +: 1024] <= lane_embed_int4[7];
                emit_vld <= 1'b1;
            end
        end
    end

    reg emit_vld_d;
    reg int4_upper_pending;
    reg [4095:0] int4_upper_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            emit_vld_d         <= 1'b0;
            int4_upper_pending <= 1'b0;
            int4_upper_r       <= {4096{1'b0}};
        end else begin
            emit_vld_d         <= emit_vld;
            int4_upper_pending <= 1'b0;

            if (emit_vld_d && int2_or_int4_mode) begin
                int4_upper_r       <= accum_int4[8191:4096];
                int4_upper_pending <= 1'b1;
            end
        end
    end

    assign out_vld  = !int2_or_int4_mode ? emit_vld : (emit_vld_d || int4_upper_pending);
    assign out_data = int4_upper_pending ? int4_upper_r :
                      int2_or_int4_mode  ? accum_int4[4095:0] :
                      accum_int2;

endmodule
