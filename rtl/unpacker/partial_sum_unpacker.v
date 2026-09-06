// SPDX-License-Identifier: Apache-2.0
module partial_sum_unpacker (
    input  wire [255:0] in_data,
    output wire [2047:0] out_data,
    output wire [8:0] num_one
);

    wire [3:0] blk_pop [0:31];

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_blk_pop
            assign blk_pop[i] = in_data[i*8+0] + in_data[i*8+1] + in_data[i*8+2] + in_data[i*8+3] +
                                in_data[i*8+4] + in_data[i*8+5] + in_data[i*8+6] + in_data[i*8+7];
        end
    endgenerate

    wire [7:0] block_prefix [0:31];

    wire [4:0] s0_1, s2_3, s4_5, s6_7, s8_9, s10_11, s12_13, s14_15;
    wire [4:0] s16_17, s18_19, s20_21, s22_23, s24_25, s26_27, s28_29, s30_31;
    assign s0_1   = blk_pop[0]  + blk_pop[1];
    assign s2_3   = blk_pop[2]  + blk_pop[3];
    assign s4_5   = blk_pop[4]  + blk_pop[5];
    assign s6_7   = blk_pop[6]  + blk_pop[7];
    assign s8_9   = blk_pop[8]  + blk_pop[9];
    assign s10_11 = blk_pop[10] + blk_pop[11];
    assign s12_13 = blk_pop[12] + blk_pop[13];
    assign s14_15 = blk_pop[14] + blk_pop[15];
    assign s16_17 = blk_pop[16] + blk_pop[17];
    assign s18_19 = blk_pop[18] + blk_pop[19];
    assign s20_21 = blk_pop[20] + blk_pop[21];
    assign s22_23 = blk_pop[22] + blk_pop[23];
    assign s24_25 = blk_pop[24] + blk_pop[25];
    assign s26_27 = blk_pop[26] + blk_pop[27];
    assign s28_29 = blk_pop[28] + blk_pop[29];
    assign s30_31 = blk_pop[30] + blk_pop[31];

    wire [5:0] s0_3, s4_7, s8_11, s12_15, s16_19, s20_23, s24_27, s28_31;
    assign s0_3   = s0_1   + s2_3;
    assign s4_7   = s4_5   + s6_7;
    assign s8_11  = s8_9   + s10_11;
    assign s12_15 = s12_13 + s14_15;
    assign s16_19 = s16_17 + s18_19;
    assign s20_23 = s20_21 + s22_23;
    assign s24_27 = s24_25 + s26_27;
    assign s28_31 = s28_29 + s30_31;

    wire [6:0] s0_7, s8_15, s16_23, s24_31;
    assign s0_7   = s0_3  + s4_7;
    assign s8_15  = s8_11 + s12_15;
    assign s16_23 = s16_19 + s20_23;
    assign s24_31 = s24_27 + s28_31;

    wire [7:0] s0_15, s16_31;
    assign s0_15  = s0_7  + s8_15;
    assign s16_31 = s16_23 + s24_31;

    assign block_prefix[0]  = 8'd0;
    assign block_prefix[1]  = {4'd0, blk_pop[0]};
    assign block_prefix[2]  = {3'd0, s0_1};
    assign block_prefix[3]  = {3'd0, s0_1} + {4'd0, blk_pop[2]};
    assign block_prefix[4]  = {2'd0, s0_3};
    assign block_prefix[5]  = {2'd0, s0_3} + {4'd0, blk_pop[4]};
    assign block_prefix[6]  = {2'd0, s0_3} + {3'd0, s4_5};
    assign block_prefix[7]  = {2'd0, s0_3} + {3'd0, s4_5} + {4'd0, blk_pop[6]};
    assign block_prefix[8]  = {1'd0, s0_7};
    assign block_prefix[9]  = {1'd0, s0_7} + {4'd0, blk_pop[8]};
    assign block_prefix[10] = {1'd0, s0_7} + {3'd0, s8_9};
    assign block_prefix[11] = {1'd0, s0_7} + {3'd0, s8_9} + {4'd0, blk_pop[10]};
    assign block_prefix[12] = {1'd0, s0_7} + {2'd0, s8_11};
    assign block_prefix[13] = {1'd0, s0_7} + {2'd0, s8_11} + {4'd0, blk_pop[12]};
    assign block_prefix[14] = {1'd0, s0_7} + {2'd0, s8_11} + {3'd0, s12_13};
    assign block_prefix[15] = {1'd0, s0_7} + {2'd0, s8_11} + {3'd0, s12_13} + {4'd0, blk_pop[14]};
    assign block_prefix[16] = s0_15;
    assign block_prefix[17] = s0_15 + {4'd0, blk_pop[16]};
    assign block_prefix[18] = s0_15 + {3'd0, s16_17};
    assign block_prefix[19] = s0_15 + {3'd0, s16_17} + {4'd0, blk_pop[18]};
    assign block_prefix[20] = s0_15 + {2'd0, s16_19};
    assign block_prefix[21] = s0_15 + {2'd0, s16_19} + {4'd0, blk_pop[20]};
    assign block_prefix[22] = s0_15 + {2'd0, s16_19} + {3'd0, s20_21};
    assign block_prefix[23] = s0_15 + {2'd0, s16_19} + {3'd0, s20_21} + {4'd0, blk_pop[22]};
    assign block_prefix[24] = s0_15 + {1'd0, s16_23};
    assign block_prefix[25] = s0_15 + {1'd0, s16_23} + {4'd0, blk_pop[24]};
    assign block_prefix[26] = s0_15 + {1'd0, s16_23} + {3'd0, s24_25};
    assign block_prefix[27] = s0_15 + {1'd0, s16_23} + {3'd0, s24_25} + {4'd0, blk_pop[26]};
    assign block_prefix[28] = s0_15 + {1'd0, s16_23} + {2'd0, s24_27};
    assign block_prefix[29] = s0_15 + {1'd0, s16_23} + {2'd0, s24_27} + {4'd0, blk_pop[28]};
    assign block_prefix[30] = s0_15 + {1'd0, s16_23} + {2'd0, s24_27} + {3'd0, s28_29};
    assign block_prefix[31] = s0_15 + {1'd0, s16_23} + {2'd0, s24_27} + {3'd0, s28_29} + {4'd0, blk_pop[30]};

    genvar k;
    generate
        for (k = 0; k < 256; k = k + 1) begin : gen_output
            wire [4:0] block_idx = k[7:3];
            wire [2:0] lane_idx  = k[2:0];

            reg [3:0] local_sum;
            integer j;

            always @(*) begin
                local_sum = 4'd0;
                for (j = 0; j < lane_idx; j = j + 1) begin
                    local_sum = local_sum + in_data[block_idx*8 + j];
                end
            end

            assign out_data[8*k +: 8] = block_prefix[block_idx] + local_sum;
        end
    endgenerate

    assign num_one = out_data[2047:2040] + in_data[255];

endmodule
