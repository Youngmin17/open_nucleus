// SPDX-License-Identifier: Apache-2.0
module transposer #(
    parameter BLOCK_SIZE = 128,
    parameter ROW_WIDTH = 2048,
    parameter TILE_NUM = 1
)(
    input wire clk,
    input wire rst_n,
    input wire [ROW_WIDTH-1:0] din,
    input wire din_vld,

    output wire [ROW_WIDTH-1:0] dout,
    output reg dout_vld
);

    localparam NUM_16x16_BLOCKS_PER_TILE = (ROW_WIDTH >> 8) * BLOCK_SIZE;
    localparam PARTITION_SIZE = ROW_WIDTH >> 4;
    localparam PARTITION_NUM = NUM_16x16_BLOCKS_PER_TILE * TILE_NUM / PARTITION_SIZE;
    localparam ADDR_MAX = (BLOCK_SIZE * ROW_WIDTH) / (NUM_16x16_BLOCKS_PER_TILE * TILE_NUM * 16);

    reg [5:0] row_partition, row_partition_pip;
    reg [NUM_16x16_BLOCKS_PER_TILE*TILE_NUM-1:0] sram_in_vld;
    reg [3:0] sram_in_addr;
    wire [16*NUM_16x16_BLOCKS_PER_TILE*TILE_NUM-1:0] sram_data_in;
    reg [ROW_WIDTH-1:0] sram_data_pip;
    reg store_done, sram_write_state;

    wire [15:0] read_data [NUM_16x16_BLOCKS_PER_TILE*TILE_NUM-1:0];
    reg [3:0] read_addr;
    reg [7:0] transpose_idx;
    reg [16*BLOCK_SIZE-1:0] dout_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_partition <= 0;
            sram_in_addr <= 0;
            sram_in_vld <= 0;
            store_done <= 0;
            sram_data_pip <= 0;
            row_partition_pip <= 0;
        end else begin
            sram_in_vld <= 0;
            store_done <= 0;
            if(din_vld) begin
                sram_in_vld[PARTITION_SIZE* row_partition +: PARTITION_SIZE] <= {PARTITION_SIZE{1'b1}};
                sram_data_pip <= din;
                row_partition_pip <= row_partition;
                if(row_partition == PARTITION_NUM-1) begin
                    row_partition <= 0;
                    sram_in_addr <= (sram_in_addr == ADDR_MAX-1) ? 0 : sram_in_addr + 1;
                    store_done <= (sram_in_addr == ADDR_MAX-1) ? 1'b1 : 1'b0;
                end else begin
                    row_partition <= row_partition + 1;
                end
            end
        end
    end

    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr <= 0;
            dout_reg <= 0;
            dout_vld <= 0;
            transpose_idx <= 0;
            sram_write_state <= 0;
        end else begin
            if(store_done) begin
                sram_write_state <= 1'b1;
            end
            if(sram_write_state) begin
                read_addr <= (read_addr == ADDR_MAX-1) ? 0 : read_addr + 1;
                transpose_idx <=    (read_addr == ADDR_MAX-1 && transpose_idx == 127) ? 0 :
                                    (read_addr == ADDR_MAX-1) ? transpose_idx + 1 : transpose_idx;
                sram_write_state <= (read_addr == ADDR_MAX-1 && transpose_idx == 127) ? 1'b0 : 1'b1;
                dout_vld <= (read_addr == ADDR_MAX-1) ? 1'b1 : 1'b0;
                for(j=0; j<16; j=j+1) begin
                    dout_reg[(j+16*transpose_idx)*16 +: 16] <= read_data[128*j+transpose_idx];
                end
            end else begin
                read_addr <= 0;
                transpose_idx <= 0;
                dout_vld <= 1'b0;
                dout_reg <= 0;
            end
        end
    end

    genvar i;

    generate
        for(i=0; i<BLOCK_SIZE; i=i+1) begin
            assign dout[i*16 +: 16] = dout_reg[i*16 +: 16];
        end
    endgenerate

    generate
    for(i=0; i<(NUM_16x16_BLOCKS_PER_TILE*TILE_NUM/(ROW_WIDTH>>4)); i=i+1) begin
        assign sram_data_in[ROW_WIDTH*i +: ROW_WIDTH] = (i == row_partition_pip) ? sram_data_pip : 0;
    end
    endgenerate

    generate
    for(i=0; i<NUM_16x16_BLOCKS_PER_TILE*TILE_NUM; i=i+1) begin: block
        sram_dp_16x16 sram_16x16(
            .dout_b  (read_data[i]),
            .addr_a  (sram_in_addr),
            .din_a   (sram_data_in[16*i +: 16]),
            .we_a    (sram_in_vld[i]),
            .en_a    (rst_n),
            .clk     (clk),
            .addr_b  (read_addr),
            .en_b    (rst_n)
        );
    end
    endgenerate

endmodule
