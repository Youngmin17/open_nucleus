// SPDX-License-Identifier: Apache-2.0
module partial_sum (
    input  wire [127:0] in_data,
    output wire [895:0] out_data
);

    wire [3:0] blk_pop [0:15];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_blk_pop
            assign blk_pop[i] = in_data[i*8+0] + in_data[i*8+1] + in_data[i*8+2] + in_data[i*8+3] +
                                in_data[i*8+4] + in_data[i*8+5] + in_data[i*8+6] + in_data[i*8+7];
        end
    endgenerate

    wire [6:0] block_prefix [0:15];

    wire [4:0] s0_1, s2_3, s4_5, s6_7, s8_9, s10_11, s12_13, s14_15;
    assign s0_1   = blk_pop[0]  + blk_pop[1];
    assign s2_3   = blk_pop[2]  + blk_pop[3];
    assign s4_5   = blk_pop[4]  + blk_pop[5];
    assign s6_7   = blk_pop[6]  + blk_pop[7];
    assign s8_9   = blk_pop[8]  + blk_pop[9];
    assign s10_11 = blk_pop[10] + blk_pop[11];
    assign s12_13 = blk_pop[12] + blk_pop[13];
    assign s14_15 = blk_pop[14] + blk_pop[15];

    wire [5:0] s0_3, s4_7, s8_11, s12_15;
    assign s0_3   = s0_1   + s2_3;
    assign s4_7   = s4_5   + s6_7;
    assign s8_11  = s8_9   + s10_11;
    assign s12_15 = s12_13 + s14_15;

    wire [6:0] s0_7, s8_15;
    assign s0_7  = s0_3  + s4_7;
    assign s8_15 = s8_11 + s12_15;

    assign block_prefix[0]  = 7'd0;
    assign block_prefix[1]  = {3'd0, blk_pop[0]};
    assign block_prefix[2]  = {2'd0, s0_1};
    assign block_prefix[3]  = {2'd0, s0_1} + {3'd0, blk_pop[2]};
    assign block_prefix[4]  = {1'd0, s0_3};
    assign block_prefix[5]  = {1'd0, s0_3} + {3'd0, blk_pop[4]};
    assign block_prefix[6]  = {1'd0, s0_3} + {2'd0, s4_5};
    assign block_prefix[7]  = {1'd0, s0_3} + {2'd0, s4_5} + {3'd0, blk_pop[6]};
    assign block_prefix[8]  = s0_7;
    assign block_prefix[9]  = s0_7 + {3'd0, blk_pop[8]};
    assign block_prefix[10] = s0_7 + {2'd0, s8_9};
    assign block_prefix[11] = s0_7 + {2'd0, s8_9} + {3'd0, blk_pop[10]};
    assign block_prefix[12] = s0_7 + {1'd0, s8_11};
    assign block_prefix[13] = s0_7 + {1'd0, s8_11} + {3'd0, blk_pop[12]};
    assign block_prefix[14] = s0_7 + {1'd0, s8_11} + {2'd0, s12_13};
    assign block_prefix[15] = s0_7 + {1'd0, s8_11} + {2'd0, s12_13} + {3'd0, blk_pop[14]};

    genvar k;
    generate
        for (k = 0; k < 128; k = k + 1) begin : gen_output
            wire [3:0] block_idx = k[6:3];
            wire [2:0] lane_idx  = k[2:0];

            reg [3:0] local_sum;
            integer j;

            always @(*) begin
                local_sum = 4'd0;
                for (j = 0; j < lane_idx; j = j + 1) begin
                    local_sum = local_sum + in_data[block_idx*8 + j];
                end
            end

            assign out_data[7*k +: 7] = block_prefix[block_idx] + local_sum;
        end
    endgenerate

endmodule
