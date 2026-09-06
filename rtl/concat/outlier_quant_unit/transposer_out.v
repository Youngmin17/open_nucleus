// SPDX-License-Identifier: Apache-2.0

module transposer_out #(
    parameter BLOCK_SIZE = 128,
    parameter ROW_WIDTH  = 2048
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  mode,
    input  wire        indicate_kv,

    input  wire        din_vld,
    input  wire [1023:0] fp_din,
    input  wire [511:0]  int_din,
    input  wire [128*5-1:0] outlier_din,

    output wire [ROW_WIDTH-1:0] dout,
    output reg         dout_vld,
    output reg  [1:0]  dout_kind,
    output wire [128*5-1:0] outlier_dout,
    output reg         outlier_dout_vld,
    output reg         prefill_start_write,
    output wire        prefill_write_done,
    output reg         decode_start_write,
    output wire        decode_write_done
);

    genvar gi;
    integer j;

    localparam FP_BANK_NUM       = 64;
    localparam INT_BANK_NUM      = 32;
    localparam OUTLIER_BANK_NUM  = 32;
    localparam BANK_WIDTH        = 32;
    localparam OUTLIER_BANK_WIDTH = 40;

    wire is_int2     = (mode == 3'b010);
    wire is_int2_fp4 = (mode == 3'b011);
    wire is_int4     = (mode == 3'b100);
    wire is_int4_fp8 = (mode == 3'b101);
    wire is_int2_fp8 = (mode == 3'b110);
    wire is_int4_fp4 = (mode == 3'b111);

    wire has_fp      = is_int2_fp4 | is_int4_fp8 | is_int2_fp8 | is_int4_fp4;
    wire has_int     = 1'b1;

    wire is_fp4      = is_int2_fp4 | is_int4_fp4;
    wire is_fp8      = is_int4_fp8 | is_int2_fp8;
    wire is_int2_mode = is_int2 | is_int2_fp4 | is_int2_fp8;
    wire is_int4_mode = is_int4 | is_int4_fp8 | is_int4_fp4;

    reg  [FP_BANK_NUM*BANK_WIDTH-1:0] fp_wdata;
    reg  [FP_BANK_NUM-1:0]            fp_wen;
    reg  [5:0]                         fp_zero_waddr;
    reg  [2:0]                         fp_wgroup;
    reg  [5:0]                         fp_raddr;
    reg  [FP_BANK_NUM-1:0]            fp_ren;
    wire [FP_BANK_NUM*BANK_WIDTH-1:0] fp_rdata;

    reg  [INT_BANK_NUM*BANK_WIDTH-1:0] int_wdata;
    reg  [INT_BANK_NUM-1:0]            int_wen;
    reg  [4:0]                         int_zero_waddr;
    reg  [3:0]                         int_wgroup;
    reg  [5:0]                         int_raddr;
    reg  [INT_BANK_NUM-1:0]            int_ren;
    wire [INT_BANK_NUM*BANK_WIDTH-1:0] int_rdata;

    reg  [OUTLIER_BANK_NUM*OUTLIER_BANK_WIDTH-1:0] outlier_wdata;
    reg  [OUTLIER_BANK_NUM-1:0]                     outlier_wen;
    reg  [4:0]                                       outlier_zero_waddr;
    reg  [3:0]                                       outlier_wgroup;
    reg  [5:0]                                       outlier_raddr;
    reg  [OUTLIER_BANK_NUM-1:0]                     outlier_ren;
    wire [OUTLIER_BANK_NUM*OUTLIER_BANK_WIDTH-1:0]  outlier_rdata;

    reg  [5:0] fp_row_partition;
    reg  [4:0] int_row_partition;
    reg  [4:0] outlier_row_partition;
    reg  [2:0] fp_loop_cnt;
    reg  [3:0] int_loop_cnt;
    reg  [3:0] outlier_loop_cnt;
    reg  fp_store_done, int_store_done, outlier_store_done;

    reg  sram_read_state;
    reg  fp_read_active, int_read_active, outlier_read_active;

    reg  [1:0] fp_read_row_cnt;
    reg  [1:0] fp_read_row_cnt_pip1;
    reg  [1:0] fp_read_row_cnt_pip2;
    reg  [4:0] fp_rgroup;
    reg  [4:0] fp_rgroup_pip1;
    reg  [4:0] fp_rgroup_pip2;
    reg  [0:0] fp_read_loop_cnt;
    reg  [0:0] fp_read_loop_cnt_pip1;
    reg  [0:0] fp_read_loop_cnt_pip2;
    reg  [5:0] fp_read_group_cnt;

    reg  [1:0] int_read_row_cnt;
    reg  [1:0] int_read_row_cnt_pip1;
    reg  [1:0] int_read_row_cnt_pip2;
    reg  [3:0] int_rgroup;
    reg  [3:0] int_rgroup_pip1;
    reg  [3:0] int_rgroup_pip2;
    reg  [0:0] int_read_loop_cnt;
    reg  [0:0] int_read_loop_cnt_pip1;
    reg  [0:0] int_read_loop_cnt_pip2;
    reg  [4:0] int_read_group_cnt;

    reg  [1:0] outlier_read_row_cnt;
    reg  [1:0] outlier_read_row_cnt_pip1;
    reg  [1:0] outlier_read_row_cnt_pip2;
    reg  [3:0] outlier_rgroup;
    reg  [3:0] outlier_rgroup_pip1;
    reg  [3:0] outlier_rgroup_pip2;
    reg  [0:0] outlier_read_loop_cnt;
    reg  [0:0] outlier_read_loop_cnt_pip1;
    reg  [0:0] outlier_read_loop_cnt_pip2;
    reg  [6:0] outlier_read_group_cnt;

    reg  [FP_BANK_NUM-1:0]      fp_ren_d1;
    reg  [INT_BANK_NUM-1:0]     int_ren_d1;
    reg  [OUTLIER_BANK_NUM-1:0] outlier_ren_d1;

    reg  [ROW_WIDTH-1:0]    dout_reg;
    reg  [128*5-1:0]        outlier_dout_reg;

    reg  [159:0] outlier_col_buf_A [0:3][0:3];
    reg  [159:0] outlier_col_buf_B [0:3][0:3];
    reg          outlier_fill_sel;
    reg          outlier_emit_active;
    reg  [1:0]   outlier_emit_cnt;
    reg          outlier_emit_sel;
    reg          outlier_drain_active;

    reg  fp_read_start, int_read_start;
    reg  fp_read_done, int_read_done, outlier_read_done;
    reg  fp_read_done_pip1, fp_read_done_pip2, fp_read_done_pip3, fp_read_done_pip4;
    reg  fp_interm, int_interm;
    reg  [3:0] fp_interm_cnt, int_interm_cnt;

    assign prefill_write_done = fp_read_done;
    assign decode_write_done  = !indicate_kv ? outlier_read_done : int_read_done;
    assign dout               = dout_reg;
    assign outlier_dout       = outlier_dout_reg;

    wire [4:0] fp_rgroup_max  = is_fp4 ? 5'd15 : 5'd31;
    wire [3:0] int_rgroup_max = is_int2_mode ? 4'd7 : 4'd15;
    wire [1:0] fp_row_cnt_max  = 2'd1;
    wire [1:0] int_row_cnt_max = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fp_row_partition <= 6'd0;
            fp_wdata  <= {(FP_BANK_NUM*BANK_WIDTH){1'b0}};
            fp_zero_waddr <= 6'd0;
            fp_wgroup <= 3'd0;
            fp_loop_cnt <= 3'd0;
            fp_wen    <= {FP_BANK_NUM{1'b0}};
            fp_store_done <= 1'b0;
        end else begin
            fp_wen <= {FP_BANK_NUM{1'b0}};
            fp_store_done <= 1'b0;

            if (din_vld && has_fp) begin
                if (is_fp4) begin
                    for (j = 0; j < FP_BANK_NUM; j = j + 1) begin
                        if (((j[5:0] - fp_row_partition) & 6'h3F) < 16) begin
                            fp_wen[j] <= 1'b1;
                            fp_wdata[j*BANK_WIDTH +: BANK_WIDTH] <=
                                fp_din[((j[5:0] - fp_row_partition) & 6'h3F) * BANK_WIDTH +: BANK_WIDTH];
                        end
                    end
                end else begin
                    for (j = 0; j < FP_BANK_NUM; j = j + 1) begin
                        if (((j[5:0] - fp_row_partition) & 6'h3F) < 32) begin
                            fp_wen[j] <= 1'b1;
                            fp_wdata[j*BANK_WIDTH +: BANK_WIDTH] <=
                                fp_din[((j[5:0] - fp_row_partition) & 6'h3F) * BANK_WIDTH +: BANK_WIDTH];
                        end
                    end
                end

                fp_zero_waddr <= fp_row_partition;
                fp_wgroup     <= fp_loop_cnt;
                fp_row_partition <= fp_row_partition + 6'd1;

                if (fp_row_partition == 6'd63) begin
                    fp_row_partition <= 6'd0;
                    fp_loop_cnt <= fp_loop_cnt + 3'd1;
                    if (fp_loop_cnt == 3'd1) begin
                        fp_loop_cnt   <= 3'd0;
                        fp_store_done <= 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_row_partition <= 5'd0;
            int_wdata  <= {(INT_BANK_NUM*BANK_WIDTH){1'b0}};
            int_zero_waddr <= 5'd0;
            int_wgroup <= 4'd0;
            int_loop_cnt <= 4'd0;
            int_wen    <= {INT_BANK_NUM{1'b0}};
            int_store_done <= 1'b0;
        end else begin
            int_wen <= {INT_BANK_NUM{1'b0}};
            int_store_done <= 1'b0;

            if (din_vld && has_int) begin
                if (is_int2_mode) begin
                    for (j = 0; j < INT_BANK_NUM; j = j + 1) begin
                        if (((j[4:0] - int_row_partition) & 5'h1F) < 8) begin
                            int_wen[j] <= 1'b1;
                            int_wdata[j*BANK_WIDTH +: BANK_WIDTH] <=
                                int_din[((j[4:0] - int_row_partition) & 5'h1F) * BANK_WIDTH +: BANK_WIDTH];
                        end
                    end
                end else begin
                    for (j = 0; j < INT_BANK_NUM; j = j + 1) begin
                        if (((j[4:0] - int_row_partition) & 5'h1F) < 16) begin
                            int_wen[j] <= 1'b1;
                            int_wdata[j*BANK_WIDTH +: BANK_WIDTH] <=
                                int_din[((j[4:0] - int_row_partition) & 5'h1F) * BANK_WIDTH +: BANK_WIDTH];
                        end
                    end
                end

                int_zero_waddr <= int_row_partition;
                int_wgroup     <= int_loop_cnt;
                int_row_partition <= int_row_partition + 5'd1;

                if (int_row_partition == 5'd31) begin
                    int_row_partition <= 5'd0;
                    int_loop_cnt <= int_loop_cnt + 4'd1;
                    if (int_loop_cnt == 4'd3) begin
                        int_loop_cnt   <= 4'd0;
                        int_store_done <= 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outlier_row_partition <= 5'd0;
            outlier_wdata  <= {(OUTLIER_BANK_NUM*OUTLIER_BANK_WIDTH){1'b0}};
            outlier_zero_waddr <= 5'd0;
            outlier_wgroup <= 4'd0;
            outlier_loop_cnt <= 4'd0;
            outlier_wen    <= {OUTLIER_BANK_NUM{1'b0}};
            outlier_store_done <= 1'b0;
        end else begin
            outlier_wen <= {OUTLIER_BANK_NUM{1'b0}};
            outlier_store_done <= 1'b0;

            if (din_vld && !indicate_kv) begin
                for (j = 0; j < OUTLIER_BANK_NUM; j = j + 1) begin
                    if (((j[4:0] - outlier_row_partition) & 5'h1F) < 16) begin
                        outlier_wen[j] <= 1'b1;
                        outlier_wdata[j*OUTLIER_BANK_WIDTH +: OUTLIER_BANK_WIDTH] <=
                            outlier_din[((j[4:0] - outlier_row_partition) & 5'h1F) * OUTLIER_BANK_WIDTH +: OUTLIER_BANK_WIDTH];
                    end
                end

                outlier_zero_waddr <= outlier_row_partition;
                outlier_wgroup     <= outlier_loop_cnt;
                outlier_row_partition <= outlier_row_partition + 5'd1;

                if (outlier_row_partition == 5'd31) begin
                    outlier_row_partition <= 5'd0;
                    outlier_loop_cnt <= outlier_loop_cnt + 4'd1;
                    if (outlier_loop_cnt == 4'd3) begin
                        outlier_loop_cnt   <= 4'd0;
                        outlier_store_done <= 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_read_state     <= 1'b0;
            fp_read_active      <= 1'b0;
            int_read_active     <= 1'b0;
            outlier_read_active <= 1'b0;
            fp_ren  <= {FP_BANK_NUM{1'b0}};
            int_ren <= {INT_BANK_NUM{1'b0}};
            outlier_ren <= {OUTLIER_BANK_NUM{1'b0}};
            fp_ren_d1  <= {FP_BANK_NUM{1'b0}};
            int_ren_d1 <= {INT_BANK_NUM{1'b0}};
            outlier_ren_d1 <= {OUTLIER_BANK_NUM{1'b0}};
            fp_raddr <= 6'd0;
            int_raddr <= 6'd0;
            outlier_raddr <= 6'd0;

            fp_read_row_cnt       <= 2'd0;
            fp_read_row_cnt_pip1  <= 2'd0;
            fp_read_row_cnt_pip2  <= 2'd0;
            fp_rgroup             <= 5'd0;
            fp_rgroup_pip1        <= 5'd0;
            fp_rgroup_pip2        <= 5'd0;
            fp_read_loop_cnt      <= 1'b0;
            fp_read_loop_cnt_pip1 <= 1'b0;
            fp_read_loop_cnt_pip2 <= 1'b0;
            fp_read_group_cnt     <= 6'd0;

            int_read_row_cnt       <= 2'd0;
            int_read_row_cnt_pip1  <= 2'd0;
            int_read_row_cnt_pip2  <= 2'd0;
            int_rgroup             <= 4'd0;
            int_rgroup_pip1        <= 4'd0;
            int_rgroup_pip2        <= 4'd0;
            int_read_loop_cnt      <= 1'b0;
            int_read_loop_cnt_pip1 <= 1'b0;
            int_read_loop_cnt_pip2 <= 1'b0;
            int_read_group_cnt     <= 5'd0;

            outlier_read_row_cnt       <= 2'd0;
            outlier_read_row_cnt_pip1  <= 2'd0;
            outlier_read_row_cnt_pip2  <= 2'd0;
            outlier_rgroup             <= 4'd0;
            outlier_rgroup_pip1        <= 4'd0;
            outlier_rgroup_pip2        <= 4'd0;
            outlier_read_loop_cnt      <= 1'b0;
            outlier_read_loop_cnt_pip1 <= 1'b0;
            outlier_read_loop_cnt_pip2 <= 1'b0;
            outlier_read_group_cnt     <= 7'd0;

            dout_reg        <= {ROW_WIDTH{1'b0}};
            outlier_dout_reg <= {(128*5){1'b0}};
            dout_vld        <= 1'b0;
            dout_kind       <= 2'b00;
            outlier_dout_vld <= 1'b0;

            outlier_fill_sel     <= 1'b0;
            outlier_emit_active  <= 1'b0;
            outlier_emit_cnt     <= 2'd0;
            outlier_emit_sel     <= 1'b0;
            outlier_drain_active <= 1'b0;

            prefill_start_write <= 1'b0;
            decode_start_write  <= 1'b0;
            fp_read_start  <= 1'b0;
            int_read_start <= 1'b0;
            fp_read_done   <= 1'b0;
            fp_read_done_pip1 <= 1'b0;
            fp_read_done_pip2 <= 1'b0;
            fp_read_done_pip3 <= 1'b0;
            fp_read_done_pip4 <= 1'b0;
            int_read_done  <= 1'b0;
            fp_interm      <= 1'b0;
            int_interm     <= 1'b0;
            fp_interm_cnt  <= 4'd0;
            int_interm_cnt <= 4'd0;
        end else begin
            fp_ren  <= {FP_BANK_NUM{1'b0}};
            int_ren <= {INT_BANK_NUM{1'b0}};
            outlier_ren <= {OUTLIER_BANK_NUM{1'b0}};
            fp_ren_d1      <= fp_ren;
            int_ren_d1     <= int_ren;
            outlier_ren_d1 <= outlier_ren;

            fp_read_row_cnt_pip1  <= fp_read_row_cnt;
            fp_read_row_cnt_pip2  <= fp_read_row_cnt_pip1;
            fp_rgroup_pip1        <= fp_rgroup;
            fp_rgroup_pip2        <= fp_rgroup_pip1;
            fp_read_loop_cnt_pip1 <= fp_read_loop_cnt;
            fp_read_loop_cnt_pip2 <= fp_read_loop_cnt_pip1;

            int_read_row_cnt_pip1  <= int_read_row_cnt;
            int_read_row_cnt_pip2  <= int_read_row_cnt_pip1;
            int_rgroup_pip1        <= int_rgroup;
            int_rgroup_pip2        <= int_rgroup_pip1;
            int_read_loop_cnt_pip1 <= int_read_loop_cnt;
            int_read_loop_cnt_pip2 <= int_read_loop_cnt_pip1;

            outlier_read_row_cnt_pip1  <= outlier_read_row_cnt;
            outlier_read_row_cnt_pip2  <= outlier_read_row_cnt_pip1;
            outlier_rgroup_pip1        <= outlier_rgroup;
            outlier_rgroup_pip2        <= outlier_rgroup_pip1;
            outlier_read_loop_cnt_pip1 <= outlier_read_loop_cnt;
            outlier_read_loop_cnt_pip2 <= outlier_read_loop_cnt_pip1;

            dout_vld        <= 1'b0;
            dout_kind       <= 2'b00;
            outlier_dout_vld <= 1'b0;

            fp_read_start  <= 1'b0;
            int_read_start <= 1'b0;
            fp_read_done   <= 1'b0;
            fp_read_done_pip1 <= fp_read_done;
            fp_read_done_pip2 <= fp_read_done_pip1;
            fp_read_done_pip3 <= fp_read_done_pip2;
            fp_read_done_pip4 <= fp_read_done_pip3;

            int_read_done  <= 1'b0;
            outlier_read_done <= 1'b0;
            prefill_start_write <= 1'b0;
            decode_start_write  <= 1'b0;

            if (fp_read_start) begin
                sram_read_state <= 1'b1;
                fp_read_active  <= 1'b1;
                int_read_active <= 1'b0;
                fp_read_row_cnt <= 2'd0;
                fp_rgroup       <= 5'd0;
                fp_read_loop_cnt <= 1'b0;
                fp_read_group_cnt <= 6'd0;
            end else if (int_read_start) begin
                sram_read_state     <= 1'b1;
                fp_read_active      <= 1'b0;
                int_read_active     <= 1'b1;
                outlier_read_active <= !indicate_kv;
                int_read_row_cnt    <= 2'd0;
                int_rgroup          <= 4'd0;
                int_read_loop_cnt   <= 1'b0;
                int_read_group_cnt  <= 5'd0;
                outlier_read_row_cnt   <= 2'd0;
                outlier_rgroup         <= 4'd0;
                outlier_read_loop_cnt  <= 1'b0;
                outlier_read_group_cnt <= 7'd0;
            end else if (fp_interm) begin
                fp_interm_cnt <= fp_interm_cnt + 4'd1;
                if (fp_interm_cnt == 4'd0)
                    prefill_start_write <= 1'b1;
                else if (fp_interm_cnt == 4'd7) begin
                    fp_interm_cnt <= 4'd0;
                    fp_interm     <= 1'b0;
                    fp_read_start <= 1'b1;
                end
            end else if (int_interm) begin
                int_interm_cnt <= int_interm_cnt + 4'd1;
                if (int_interm_cnt == 4'd0)
                    decode_start_write <= 1'b1;
                else if (int_interm_cnt == 4'd7) begin
                    int_interm_cnt <= 4'd0;
                    int_interm     <= 1'b0;
                    int_read_start <= 1'b1;
                end
            end else if (has_fp && fp_store_done)
                fp_interm <= 1'b1;
            else if (has_fp && fp_read_done_pip4)
                int_interm <= 1'b1;
            else if (!has_fp && int_store_done)
                int_interm <= 1'b1;

            if (sram_read_state && fp_read_active) begin
                fp_ren <= {FP_BANK_NUM{1'b1}};

                if (is_fp4)
                    fp_raddr <= {1'b0, fp_read_row_cnt[0], fp_rgroup[3:0]};
                else
                    fp_raddr <= {fp_read_row_cnt[0], fp_rgroup[4:0]};

                fp_read_row_cnt <= fp_read_row_cnt + 2'd1;
                if (fp_read_row_cnt == fp_row_cnt_max) begin
                    fp_read_row_cnt <= 2'd0;
                    fp_read_loop_cnt <= fp_read_loop_cnt + 1'b1;
                    if (fp_read_loop_cnt == 1'b1) begin
                        fp_read_loop_cnt <= 1'b0;
                        fp_rgroup <= fp_rgroup + 5'd1;
                        if (fp_rgroup == fp_rgroup_max) begin
                            fp_rgroup <= 5'd0;
                        end
                    end
                end
            end

            if (fp_read_active && (|fp_ren_d1)) begin
                for (j = 0; j < FP_BANK_NUM; j = j + 1) begin
                    if (is_fp4) begin
                        dout_reg[{fp_read_row_cnt_pip2[0], 8'b0} + j*4 +: 4] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} +: 4];
                        dout_reg[{fp_read_row_cnt_pip2[0], 8'b0} + j*4 + 512 +: 4] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} + 4 +: 4];
                        dout_reg[{fp_read_row_cnt_pip2[0], 8'b0} + j*4 + 1024 +: 4] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} + 8 +: 4];
                        dout_reg[{fp_read_row_cnt_pip2[0], 8'b0} + j*4 + 1536 +: 4] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} + 12 +: 4];
                    end else begin
                        dout_reg[{fp_read_row_cnt_pip2[0], 9'b0} + j*8 +: 8] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} +: 8];
                        dout_reg[{fp_read_row_cnt_pip2[0], 9'b0} + j*8 + 1024 +: 8] <=
                            fp_rdata[((j[5:0] + {1'b0, fp_rgroup_pip2}) & 6'h3F)*BANK_WIDTH
                                + {fp_read_loop_cnt_pip2, 4'b0} + 8 +: 8];
                    end
                end

                if (fp_read_row_cnt_pip2 == fp_row_cnt_max) begin
                    dout_vld  <= 1'b1;
                    dout_kind <= 2'b01;
                    fp_read_group_cnt <= fp_read_group_cnt + 6'd1;

                    if (is_fp4 && fp_read_group_cnt == 6'd31) begin
                        fp_read_active <= 1'b0;
                        fp_read_done   <= 1'b1;
                    end else if (is_fp8 && fp_read_group_cnt == 6'd63) begin
                        fp_read_active <= 1'b0;
                        fp_read_done   <= 1'b1;
                    end
                end
            end

            if (sram_read_state && int_read_active) begin
                int_ren <= {INT_BANK_NUM{1'b1}};

                if (is_int2_mode)
                    int_raddr <= {1'b0, int_read_row_cnt[1:0], int_rgroup[2:0]};
                else
                    int_raddr <= {int_read_row_cnt[1:0], int_rgroup[3:0]};

                int_read_row_cnt <= int_read_row_cnt + 2'd1;
                if (int_read_row_cnt == int_row_cnt_max) begin
                    int_read_row_cnt <= 2'd0;
                    int_read_loop_cnt <= int_read_loop_cnt + 1'b1;
                    if (int_read_loop_cnt == 1'b1) begin
                        int_read_loop_cnt <= 1'b0;
                        int_rgroup <= int_rgroup + 4'd1;
                        if (int_rgroup == int_rgroup_max) begin
                            int_rgroup <= 4'd0;
                        end
                    end
                end
            end

            if (sram_read_state && outlier_read_active) begin
                outlier_ren <= {OUTLIER_BANK_NUM{1'b1}};
                outlier_raddr <= {outlier_read_row_cnt[1:0], outlier_rgroup[3:0]};

                outlier_read_row_cnt <= outlier_read_row_cnt + 2'd1;
                if (outlier_read_row_cnt == 2'd3) begin
                    outlier_read_row_cnt <= 2'd0;
                    outlier_read_loop_cnt <= outlier_read_loop_cnt + 1'b1;
                    if (outlier_read_loop_cnt == 1'b1) begin
                        outlier_read_loop_cnt <= 1'b0;
                        outlier_rgroup <= outlier_rgroup + 4'd1;
                        if (outlier_rgroup == 4'd15) begin
                            outlier_rgroup <= 4'd0;
                            outlier_read_active <= 1'b0;
                            if (!int_read_active)
                                sram_read_state <= 1'b0;
                        end
                    end
                end
            end

            if (int_read_active && (|int_ren_d1)) begin
                for (j = 0; j < INT_BANK_NUM; j = j + 1) begin
                    if (is_int2_mode) begin
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 256 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 2 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 512 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 4 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 768 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 6 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 1024 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 8 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 1280 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 10 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 1536 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 12 +: 2];
                        dout_reg[{int_read_row_cnt_pip2, 6'b0} + j*2 + 1792 +: 2] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 14 +: 2];
                    end else begin
                        dout_reg[{int_read_row_cnt_pip2, 7'b0} + j*4 +: 4] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} +: 4];
                        dout_reg[{int_read_row_cnt_pip2, 7'b0} + j*4 + 512 +: 4] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 4 +: 4];
                        dout_reg[{int_read_row_cnt_pip2, 7'b0} + j*4 + 1024 +: 4] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 8 +: 4];
                        dout_reg[{int_read_row_cnt_pip2, 7'b0} + j*4 + 1536 +: 4] <=
                            int_rdata[((j[4:0] + {1'b0, int_rgroup_pip2}) & 5'h1F)*BANK_WIDTH
                                + {int_read_loop_cnt_pip2, 4'b0} + 12 +: 4];
                    end
                end

                if (int_read_row_cnt_pip2 == int_row_cnt_max) begin
                    dout_vld  <= 1'b1;
                    dout_kind <= 2'b10;
                    int_read_group_cnt <= int_read_group_cnt + 5'd1;

                    if (is_int2_mode && int_read_group_cnt == 5'd15) begin
                        int_read_active <= 1'b0;
                        int_read_done   <= 1'b1;
                        if (!outlier_read_active)
                            sram_read_state <= 1'b0;
                    end else if (is_int4_mode && int_read_group_cnt == 5'd31) begin
                        int_read_active <= 1'b0;
                        int_read_done   <= 1'b1;
                        if (!outlier_read_active)
                            sram_read_state <= 1'b0;
                    end
                end
            end

            if (outlier_emit_active) begin
                case ({outlier_emit_sel, outlier_emit_cnt})
                    3'b000: outlier_dout_reg <= {outlier_col_buf_A[0][3], outlier_col_buf_A[0][2],
                                                  outlier_col_buf_A[0][1], outlier_col_buf_A[0][0]};
                    3'b001: outlier_dout_reg <= {outlier_col_buf_A[1][3], outlier_col_buf_A[1][2],
                                                  outlier_col_buf_A[1][1], outlier_col_buf_A[1][0]};
                    3'b010: outlier_dout_reg <= {outlier_col_buf_A[2][3], outlier_col_buf_A[2][2],
                                                  outlier_col_buf_A[2][1], outlier_col_buf_A[2][0]};
                    3'b011: outlier_dout_reg <= {outlier_col_buf_A[3][3], outlier_col_buf_A[3][2],
                                                  outlier_col_buf_A[3][1], outlier_col_buf_A[3][0]};
                    3'b100: outlier_dout_reg <= {outlier_col_buf_B[0][3], outlier_col_buf_B[0][2],
                                                  outlier_col_buf_B[0][1], outlier_col_buf_B[0][0]};
                    3'b101: outlier_dout_reg <= {outlier_col_buf_B[1][3], outlier_col_buf_B[1][2],
                                                  outlier_col_buf_B[1][1], outlier_col_buf_B[1][0]};
                    3'b110: outlier_dout_reg <= {outlier_col_buf_B[2][3], outlier_col_buf_B[2][2],
                                                  outlier_col_buf_B[2][1], outlier_col_buf_B[2][0]};
                    3'b111: outlier_dout_reg <= {outlier_col_buf_B[3][3], outlier_col_buf_B[3][2],
                                                  outlier_col_buf_B[3][1], outlier_col_buf_B[3][0]};
                endcase

                outlier_dout_vld <= 1'b1;
                outlier_emit_cnt <= outlier_emit_cnt + 2'd1;

                if (outlier_emit_cnt == 2'd3) begin
                    outlier_emit_active <= 1'b0;
                end
            end

            if ((|outlier_ren_d1)) begin
                for (j = 0; j < OUTLIER_BANK_NUM; j = j + 1) begin
                    if (!outlier_fill_sel) begin
                        outlier_col_buf_A[0][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 +: 5];
                        outlier_col_buf_A[1][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 5 +: 5];
                        outlier_col_buf_A[2][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 10 +: 5];
                        outlier_col_buf_A[3][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 15 +: 5];
                    end else begin
                        outlier_col_buf_B[0][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 +: 5];
                        outlier_col_buf_B[1][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 5 +: 5];
                        outlier_col_buf_B[2][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 10 +: 5];
                        outlier_col_buf_B[3][outlier_read_row_cnt_pip2][j*5 +: 5] <=
                            outlier_rdata[((j[4:0] + {1'b0, outlier_rgroup_pip2}) & 5'h1F)*OUTLIER_BANK_WIDTH
                                + {outlier_read_loop_cnt_pip2, 4'b0} + outlier_read_loop_cnt_pip2*4 + 15 +: 5];
                    end
                end

                if (outlier_read_row_cnt_pip2 == 2'd3) begin
                    outlier_emit_active <= 1'b1;
                    outlier_emit_cnt    <= 2'd0;
                    outlier_emit_sel    <= outlier_fill_sel;
                    outlier_fill_sel    <= ~outlier_fill_sel;

                    outlier_read_group_cnt <= outlier_read_group_cnt + 7'd1;
                    if (outlier_read_group_cnt == 7'd31) begin
                        outlier_drain_active <= 1'b1;
                    end
                end
            end

            if (outlier_drain_active && !outlier_emit_active && !outlier_read_active) begin
                outlier_drain_active <= 1'b0;
                outlier_read_done <= 1'b1;
            end

            if (!sram_read_state) begin
                fp_raddr      <= 6'd0;
                int_raddr     <= 6'd0;
                outlier_raddr <= 6'd0;
            end
        end
    end

    generate
    for (gi = 0; gi < FP_BANK_NUM; gi = gi + 1) begin : FP_DIAGONAL_TRANSPOSER
        wire [5:0] fp_d_raw = (gi[5:0] - fp_zero_waddr) & 6'h3F;
        wire [5:0] fp_waddr_calc = is_fp4 ?
            {2'b0, fp_wgroup[0], fp_d_raw[3:0]}   :
            {1'b0, fp_wgroup[0], fp_d_raw[4:0]};

        sram_64x32 u_fp_sram (
            .rdata    (fp_rdata[gi*BANK_WIDTH +: BANK_WIDTH]),
            .clk      (clk),
            .re_n     (~fp_ren[gi]),
            .we_n     (~fp_wen[gi]),
            .raddr    (fp_raddr),
            .waddr    (fp_waddr_calc),
            .wdata    (fp_wdata[gi*BANK_WIDTH +: BANK_WIDTH])
        );
    end
    endgenerate

    generate
    for (gi = 0; gi < INT_BANK_NUM; gi = gi + 1) begin : INT_DIAGONAL_TRANSPOSER
        wire [4:0] int_d_raw = (gi[4:0] - int_zero_waddr) & 5'h1F;
        wire [5:0] int_waddr_calc = is_int2_mode ?
            {1'b0, int_wgroup[1:0], int_d_raw[2:0]}  :
            {int_wgroup[1:0], int_d_raw[3:0]};

        sram_64x32 u_int_sram (
            .rdata    (int_rdata[gi*BANK_WIDTH +: BANK_WIDTH]),
            .clk      (clk),
            .re_n     (~int_ren[gi]),
            .we_n     (~int_wen[gi]),
            .raddr    (int_raddr),
            .waddr    (int_waddr_calc),
            .wdata    (int_wdata[gi*BANK_WIDTH +: BANK_WIDTH])
        );
    end
    endgenerate

    generate
    for (gi = 0; gi < OUTLIER_BANK_NUM; gi = gi + 1) begin : OUTLIER_DIAGONAL_TRANSPOSER
        wire [4:0] outlier_d_raw = (gi[4:0] - outlier_zero_waddr) & 5'h1F;
        wire [5:0] outlier_waddr_calc = {outlier_wgroup[1:0], outlier_d_raw[3:0]};

        sram_64x40 u_outlier_sram (
            .rdata    (outlier_rdata[gi*OUTLIER_BANK_WIDTH +: OUTLIER_BANK_WIDTH]),
            .clk      (clk),
            .re_n     (~outlier_ren[gi]),
            .we_n     (~outlier_wen[gi]),
            .raddr    (outlier_raddr),
            .waddr    (outlier_waddr_calc),
            .wdata    (outlier_wdata[gi*OUTLIER_BANK_WIDTH +: OUTLIER_BANK_WIDTH])
        );
    end
    endgenerate

endmodule
