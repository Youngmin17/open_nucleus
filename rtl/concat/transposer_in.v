// SPDX-License-Identifier: Apache-2.0
module transposer_in #(
    parameter BLOCK_SIZE = 128,
    parameter ROW_WIDTH = 2048
)(
    input wire clk,
    input wire rst_n,
    input wire [ROW_WIDTH-1:0] din,
    input wire din_vld,

    output wire [ROW_WIDTH-1:0] dout,
    output reg dout_vld
);

    genvar i;

    localparam BANDWIDTH = 4096;
    localparam BANK_NUM = 32;
    localparam BANK_WIDTH = BANDWIDTH / BANK_NUM;

    reg [BANDWIDTH-1:0] wdata;
    reg [4:0] row_partition;

    reg [31:0] wen;
    reg [4:0] zero_waddr;
    reg [1:0] wgroup;
    reg [1:0] loop_cnt;
    reg store_done, sram_read_state;

    reg [31:0] ren;
    reg [31:0] ren_d1;
    wire [BANDWIDTH-1:0] rdata;
    reg [5:0] raddr;
    reg [1:0] read_row_cnt;
    reg [1:0] read_row_cnt_pip1;
    reg [1:0] read_row_cnt_pip2;
    reg [2:0] read_row_partition_cnt;
    reg [3:0] rgroup;
    reg [2:0] read_row_loop_cnt;
    reg [3:0] read_group_loop_cnt;

    reg [ROW_WIDTH-1:0] dout_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_partition <= 5'd0;
            wdata <= {BANDWIDTH{1'b0}};
            zero_waddr <= 5'd0;
            wgroup <= 2'd0;
            loop_cnt <= 2'd0;
            wen <= 32'd0;
            store_done <= 1'b0;

        end else begin
            wen <= 32'd0;
            store_done <= 1'b0;

            if(din_vld) begin
                if(row_partition <= BANK_NUM/2) begin
                    wen <= 32'hFFFF << row_partition;
                    wdata <= {{(BANDWIDTH-ROW_WIDTH){1'b0}}, din} << (row_partition * BANK_WIDTH);
                end else begin
                    wen <= (32'hFFFF << row_partition) | (32'hFFFF >> (BANK_NUM - row_partition));
                    wdata <= ({{(BANDWIDTH-ROW_WIDTH){1'b0}}, din} << (row_partition * BANK_WIDTH)) |
                             ({{(BANDWIDTH-ROW_WIDTH){1'b0}}, din} >> ((BANK_NUM - row_partition) * BANK_WIDTH));
                end

                zero_waddr <= row_partition;
                wgroup <= loop_cnt;
                row_partition <= row_partition + 5'd1;
                if(row_partition == BANK_NUM-1) begin
                    row_partition <= 5'd0;
                    loop_cnt <= loop_cnt + 2'd1;
                    if(loop_cnt == 2'd3) begin
                        loop_cnt <= 2'd0;
                        store_done <= 1'b1;
                    end
                end
            end
        end
    end

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ren <= 32'd0;
            read_row_cnt <= 2'd0;
            read_row_cnt_pip1 <= 2'd0;
            read_row_cnt_pip2 <= 2'd0;
            read_row_partition_cnt <= 3'd0;
            rgroup <= 4'd0;
            raddr <= 6'd0;
            sram_read_state <= 1'b0;
            read_row_loop_cnt <= 3'd0;
            read_group_loop_cnt <= 4'd0;
            dout_reg <= {ROW_WIDTH{1'b0}};
            dout_vld <= 1'b0;
            ren_d1 <= 32'd0;

        end else begin
            ren <= 32'd0;
            ren_d1 <= ren;
            read_row_cnt_pip1 <= read_row_cnt;
            read_row_cnt_pip2 <= read_row_cnt_pip1;
            dout_vld <= 1'b0;

            if(store_done) begin
                sram_read_state <= 1'b1;
                rgroup <= 4'd0;
                read_row_cnt <= 2'd0;
                read_row_partition_cnt <= 3'd0;
            end

            if(sram_read_state) begin
                ren <= 32'hFFFF_FFFF;
                raddr <= {read_row_cnt, rgroup};
                read_row_cnt <= read_row_cnt + 2'd1;
                if(read_row_cnt == 2'd3) begin
                    read_row_cnt <= 2'd0;
                    read_row_partition_cnt <= read_row_partition_cnt + 3'd1;
                    if(read_row_partition_cnt == 3'd7) begin
                        read_row_partition_cnt <= 3'd0;
                        rgroup <= rgroup + 4'd1;
                        if(rgroup == 4'd15) begin
                            rgroup <= 4'd0;
                        end
                    end
                end
            end else begin
                raddr <= 6'd0;
                read_row_cnt <= 2'd0;
                rgroup <= 4'd0;
                read_row_partition_cnt <= 3'd0;
            end

            if(&ren_d1 && sram_read_state) begin
                for(j=0; j<32; j=j+1) begin
                    dout_reg[j*16 + {read_row_cnt_pip2, 9'b0} +: 16] <= rdata[((j + read_group_loop_cnt) & 5'h1F)*BANK_WIDTH + {read_row_loop_cnt, 4'b0} +: 16];
                end

                if(read_row_cnt_pip2 == 2'd3) begin
                    read_row_loop_cnt <= read_row_loop_cnt + 3'd1;
                    dout_vld <= 1'b1;

                    if(read_row_loop_cnt == 3'd7) begin
                        read_row_loop_cnt <= 3'd0;
                        read_group_loop_cnt <= read_group_loop_cnt + 4'd1;
                        if(read_group_loop_cnt == 4'd15) begin
                            read_group_loop_cnt <= 4'd0;
                            sram_read_state <= 1'b0;
                        end
                    end
                end
            end
        end
    end

    assign dout = dout_reg;

    generate
    for(i=0; i<32; i=i+1) begin : DIAGONAL_TRANSPOSER
        sram_64x128 u_sram_64x128(
            .rdata   (rdata[i*128 +: 128]),
            .clk     (clk),
            .re_n    (~ren[i]),
            .we_n    (~wen[i]),
            .raddr   (raddr),
            .waddr   ({wgroup, 4'b0} | ((i[4:0] - zero_waddr) & 5'h0F)),
            .wdata   (wdata[i*128 +: 128])
        );
    end
    endgenerate

endmodule
