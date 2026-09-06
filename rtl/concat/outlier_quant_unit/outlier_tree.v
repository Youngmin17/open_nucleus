// SPDX-License-Identifier: Apache-2.0
module outlier_tree #(
    parameter PRECISION         = 16,
    parameter DATA_NUM          = 128,
    parameter LOOP_NUM          = 4
)
(
    input wire                          clk,
    input wire                          rst_n,
    input wire                          in_vld,
    input wire [1:0]                    group_size,
    input wire [6:0]                    outlier_num,
    input wire [PRECISION*DATA_NUM-1:0] d_in,

    output reg                          out_vld,
    output reg [DATA_NUM-1:0]           outlier_pos,
    output reg [DATA_NUM*PRECISION-1:0] outlier_val,
    output wire [4*PRECISION-1:0]       outlier_excluded_max,
    output wire [4*PRECISION-1:0]       outlier_excluded_min
);

    genvar i;
    integer idx;

    reg [5:0] topk_in_cnt;
    reg topk_in_vld, topk_out_vld_pip1;
    reg [PRECISION*DATA_NUM-1:0] d_in_reg, d_in_reg_pip1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            topk_in_cnt <= 6'd0;
            topk_in_vld <= 1'b0;
            out_vld <= 1'b0;
            d_in_reg <= {PRECISION*DATA_NUM{1'b0}};
            d_in_reg_pip1 <= {PRECISION*DATA_NUM{1'b0}};

        end else begin
            out_vld <= 1'b0;
            d_in_reg_pip1 <= d_in_reg;

            if(topk_in_cnt == 6'd1) begin
                topk_in_cnt <= 6'd0;
                topk_in_vld <= 1'b0;
                out_vld <= 1'b1;
                if(in_vld) begin
                    topk_in_cnt <= LOOP_NUM[5:0];
                    topk_in_vld <= 1'b1;
                    d_in_reg <= d_in;
                end
            end else if(topk_in_cnt > 6'd1) begin
                topk_in_cnt <= topk_in_cnt - 6'd1;
            end else if(topk_in_cnt == 6'd0) begin
                if(in_vld) begin
                    topk_in_cnt <= LOOP_NUM[5:0];
                    topk_in_vld <= 1'b1;
                    d_in_reg <= d_in;
                end
            end

        end
    end

    generate
    for(i=0; i<32; i=i+1) begin : topk_extractor
        wire valid_out;
        topk_checker #(
            .DATA_WIDTH(PRECISION),
            .DATA_NUM(DATA_NUM)
        ) u_topk_checker (
            .a(d_in_reg[(i+32*(LOOP_NUM[5:0]-topk_in_cnt))*PRECISION +: PRECISION]),
            .b(d_in_reg),
            .k(outlier_num),
            .my_pos(i[6:0] + ((LOOP_NUM[5:0]-topk_in_cnt) << 5)),
            .valid(valid_out)
        );

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                for(idx=0; idx<4; idx=idx+1) begin
                    outlier_pos[i+32*idx] <= 1'b0;
                    outlier_val[(i+32*idx)*PRECISION +: PRECISION] <= {PRECISION{1'b0}};
                end
            end else begin
                if(topk_in_vld) begin
                    outlier_pos[i+32*(LOOP_NUM[5:0]-topk_in_cnt)] <= valid_out;
                    outlier_val[(i+32*(LOOP_NUM[5:0]-topk_in_cnt))*PRECISION +: PRECISION] <= valid_out ? d_in_reg[(i+32*(LOOP_NUM[5:0]-topk_in_cnt))*PRECISION +: PRECISION] : {PRECISION{1'b0}};
                end
            end
        end
    end
    endgenerate

    wire [1:0] outlier_pos_add_1st [DATA_NUM/2-1:0];
    wire [2:0] outlier_pos_add_2nd [DATA_NUM/4-1:0];
    wire [3:0] outlier_pos_add_3rd [DATA_NUM/8-1:0];
    wire [4:0] outlier_pos_add_4th [DATA_NUM/16-1:0];
    wire [5:0] outlier_pos_add_5th [DATA_NUM/32-1:0];
    wire [6:0] outlier_pos_add_6th [DATA_NUM/64-1:0];
    wire [7:0] outlier_pos_num;

    generate
    for(i=0; i<DATA_NUM/2; i=i+1) begin : outlier_pos_add_1st_stage
        assign outlier_pos_add_1st[i] = outlier_pos[2*i] + outlier_pos[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/4; i=i+1) begin : outlier_pos_add_2nd_stage
        assign outlier_pos_add_2nd[i] = outlier_pos_add_1st[2*i] + outlier_pos_add_1st[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/8; i=i+1) begin : outlier_pos_add_3rd_stage
        assign outlier_pos_add_3rd[i] = outlier_pos_add_2nd[2*i] + outlier_pos_add_2nd[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/16; i=i+1) begin : outlier_pos_add_4th_stage
        assign outlier_pos_add_4th[i] = outlier_pos_add_3rd[2*i] + outlier_pos_add_3rd[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/32; i=i+1) begin : outlier_pos_add_5th_stage
        assign outlier_pos_add_5th[i] = outlier_pos_add_4th[2*i] + outlier_pos_add_4th[2*i+1];
    end
    endgenerate

    generate
    for(i=0; i<DATA_NUM/64; i=i+1) begin : outlier_pos_add_6th_stage
        assign outlier_pos_add_6th[i] = outlier_pos_add_5th[2*i] + outlier_pos_add_5th[2*i+1];
    end
    endgenerate

    assign outlier_pos_num = outlier_pos_add_6th[0] + outlier_pos_add_6th[1];

    wire [PRECISION-1:0] d1_max [(DATA_NUM>>1)-1:0];
    wire [PRECISION-1:0] d1_min [(DATA_NUM>>1)-1:0];
    wire [PRECISION-1:0] d2_max [(DATA_NUM>>2)-1:0];
    wire [PRECISION-1:0] d2_min [(DATA_NUM>>2)-1:0];
    wire [PRECISION-1:0] d3_max [(DATA_NUM>>3)-1:0];
    wire [PRECISION-1:0] d3_min [(DATA_NUM>>3)-1:0];
    wire [PRECISION-1:0] d4_max [(DATA_NUM>>4)-1:0];
    wire [PRECISION-1:0] d4_min [(DATA_NUM>>4)-1:0];
    wire [PRECISION-1:0] d5_max [(DATA_NUM>>5)-1:0];
    wire [PRECISION-1:0] d5_min [(DATA_NUM>>5)-1:0];
    wire [PRECISION-1:0] d6_max [(DATA_NUM>>6)-1:0];
    wire [PRECISION-1:0] d6_min [(DATA_NUM>>6)-1:0];
    wire [PRECISION-1:0] d7_max [(DATA_NUM>>7)-1:0];
    wire [PRECISION-1:0] d7_min [(DATA_NUM>>7)-1:0];

    generate
    for (i=0; i<(DATA_NUM>>1); i=i+1)
    begin : first_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_1st (
            .max_min(1'b1),
            .a_in(!outlier_pos[2*i] ? d_in_reg_pip1[(2*i)*PRECISION +: PRECISION] : {PRECISION{1'b0}}),
            .b_in(!outlier_pos[2*i+1] ? d_in_reg_pip1[(2*i+1)*PRECISION +: PRECISION] : {PRECISION{1'b0}}),
            .d_out(d1_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>2); i=i+1)
    begin : second_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_2nd (
            .max_min(1'b1),
            .a_in(d1_max[2*i]),
            .b_in(d1_max[2*i+1]),
            .d_out(d2_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>3); i=i+1)
    begin : third_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_3rd (
            .max_min(1'b1),
            .a_in(d2_max[2*i]),
            .b_in(d2_max[2*i+1]),
            .d_out(d3_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>4); i=i+1)
    begin : fourth_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_4th (
            .max_min(1'b1),
            .a_in(d3_max[2*i]),
            .b_in(d3_max[2*i+1]),
            .d_out(d4_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>5); i=i+1)
    begin : fifth_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_5th (
            .max_min(1'b1),
            .a_in(d4_max[2*i]),
            .b_in(d4_max[2*i+1]),
            .d_out(d5_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>6); i=i+1)
    begin : sixth_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_6th (
            .max_min(1'b1),
            .a_in(d5_max[2*i]),
            .b_in(d5_max[2*i+1]),
            .d_out(d6_max[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>7); i=i+1)
    begin : seventh_layer_comptree_max
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_7th (
            .max_min(1'b1),
            .a_in(d6_max[2*i]),
            .b_in(d6_max[2*i+1]),
            .d_out(d7_max[i]),
            .pos()
        );
    end
    endgenerate

    assign outlier_excluded_max =  group_size == 2'b01 ? {d5_max[3], d5_max[2], d5_max[1], d5_max[0]} :
                        group_size == 2'b10 ? {16'b0, d6_max[1], 16'b0, d6_max[0]} :
                        group_size == 2'b11 ? {48'b0, d7_max[0]} :
                        {4*PRECISION{1'b0}};

    generate
    for (i=0; i<(DATA_NUM>>1); i=i+1)
    begin : first_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_1st (
            .max_min(1'b0),
            .a_in(!outlier_pos[2*i] ? d_in_reg_pip1[(2*i)*PRECISION +: PRECISION] : {PRECISION{1'b0}}),
            .b_in(!outlier_pos[2*i+1] ? d_in_reg_pip1[(2*i+1)*PRECISION +: PRECISION] : {PRECISION{1'b0}}),
            .d_out(d1_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>2); i=i+1)
    begin : second_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_2nd (
            .max_min(1'b0),
            .a_in(d1_min[2*i]),
            .b_in(d1_min[2*i+1]),
            .d_out(d2_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>3); i=i+1)
    begin : third_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_3rd (
            .max_min(1'b0),
            .a_in(d2_min[2*i]),
            .b_in(d2_min[2*i+1]),
            .d_out(d3_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>4); i=i+1)
    begin : fourth_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_4th (
            .max_min(1'b0),
            .a_in(d3_min[2*i]),
            .b_in(d3_min[2*i+1]),
            .d_out(d4_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>5); i=i+1)
    begin : fifth_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_5th (
            .max_min(1'b0),
            .a_in(d4_min[2*i]),
            .b_in(d4_min[2*i+1]),
            .d_out(d5_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>6); i=i+1)
    begin : sixth_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_6th (
            .max_min(1'b0),
            .a_in(d5_min[2*i]),
            .b_in(d5_min[2*i+1]),
            .d_out(d6_min[i]),
            .pos()
        );
    end
    endgenerate

    generate
    for (i=0; i<(DATA_NUM>>7); i=i+1)
    begin : seventh_layer_comptree_min
        comparator_oq #(
            .PRECISION(PRECISION)
        ) comp_7th (
            .max_min(1'b0),
            .a_in(d6_min[2*i]),
            .b_in(d6_min[2*i+1]),
            .d_out(d7_min[i]),
            .pos()
        );
    end
    endgenerate

    assign outlier_excluded_min =  group_size == 2'b01 ? {d5_min[3], d5_min[2], d5_min[1], d5_min[0]} :
                        group_size == 2'b10 ? {16'b0, d6_min[1], 16'b0, d6_min[0]} :
                        group_size == 2'b11 ? {48'b0, d7_min[0]} :
                        {4*PRECISION{1'b0}};

endmodule