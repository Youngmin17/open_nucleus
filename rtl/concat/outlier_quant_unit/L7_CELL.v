// SPDX-License-Identifier: Apache-2.0
module L7_CELL (
    input wire clk,
    input wire rst_n,

    input wire isa_valid,
    input wire [6:0] outlier_num,

    input wire sram_wen,
    input wire [101:0] sram_wdata,

    input wire in_vld,
    input wire [63:0] high,
    input wire [63:0] low,
    input wire [6:0] num_one_high,
    input wire [6:0] num_one_low,
    output reg out_vld,
    output reg [101:0] out_data,
    output reg [7:0] out_num_one
);

    localparam L7_WEIGHT_KR_0                 = 1'd1;
    localparam L7_WEIGHT_KR_1                 = 7'd64;
    localparam L7_WEIGHT_KR_2                 = 11'd2016;
    localparam L7_WEIGHT_KR_3                 = 16'd41664;
    localparam L7_WEIGHT_KR_4                 = 20'd635376;
    localparam L7_WEIGHT_KR_5                 = 23'd7624512;
    localparam L7_WEIGHT_KR_6                 = 27'd74974368;
    localparam L7_WEIGHT_KR_7                 = 30'd621216192;
    localparam L7_WEIGHT_KR_8                 = 33'd4426165368;
    localparam L7_WEIGHT_KR_9                 = 35'd27540584512;
    localparam L7_WEIGHT_KR_10                = 38'd151473214816;
    localparam L7_WEIGHT_KR_11                = 40'd743595781824;
    localparam L7_WEIGHT_KR_12                = 42'd3284214703056;
    localparam L7_WEIGHT_KR_13                = 44'd13136858812224;
    localparam L7_WEIGHT_KR_14                = 46'd47855699958816;
    localparam L7_WEIGHT_KR_15                = 48'd159518999862720;
    localparam L7_WEIGHT_KR_16                = 49'd488526937079580;
    localparam L7_WEIGHT_KR_17                = 51'd1379370175283520;
    localparam L7_WEIGHT_KR_18                = 52'd3601688791018080;
    localparam L7_WEIGHT_KR_19                = 53'd8719878125622720;
    localparam L7_WEIGHT_KR_20                = 55'd19619725782651120;
    localparam L7_WEIGHT_KR_21                = 56'd41107996877935680;
    localparam L7_WEIGHT_KR_22                = 57'd80347448443237920;
    localparam L7_WEIGHT_KR_23                = 58'd146721427591999680;
    localparam L7_WEIGHT_KR_24                = 58'd250649105469666120;
    localparam L7_WEIGHT_KR_25                = 59'd401038568751465792;
    localparam L7_WEIGHT_KR_26                = 60'd601557853127198688;
    localparam L7_WEIGHT_KR_27                = 60'd846636978475316672;
    localparam L7_WEIGHT_KR_28                = 60'd1118770292985239888;
    localparam L7_WEIGHT_KR_29                = 61'd1388818294740297792;
    localparam L7_WEIGHT_KR_30                = 61'd1620288010530347424;
    localparam L7_WEIGHT_KR_31                = 61'd1777090076065542336;
    localparam L7_WEIGHT_KR_32                = 61'd1832624140942590534;

    reg [4:0] sram_waddr_cnt;
    reg sram_write_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_waddr_cnt <= 5'd0;
            sram_write_done <= 1'b0;
        end else begin
            if (isa_valid) begin
                sram_waddr_cnt <= 5'd0;
                sram_write_done <= 1'b0;
            end else if (!sram_write_done && sram_wen) begin
                if (sram_waddr_cnt == 5'd31) begin
                    sram_write_done <= 1'b1;
                    sram_waddr_cnt <= 5'd0;
                end else begin
                    sram_waddr_cnt <= sram_waddr_cnt + 5'd1;
                end
            end
        end
    end

    wire sram_wen_internal = sram_wen && !sram_write_done && !isa_valid;

    wire [5:0] k_sum = num_one_high[5:0] + num_one_low[5:0];
    wire [5:0] k_l = num_one_high[5:0];

    wire addr_valid = (k_sum >= 6'd1) && (k_sum <= outlier_num[5:0]) &&
                      (k_l >= 6'd1) && (k_l <= k_sum);

    wire [4:0] sram_raddr = k_l[4:0] - 5'd1;
    wire sram_ren = in_vld && addr_valid;

    wire [101:0] sram_rdata;

    sram_32x102 u_sram_32x102 (
        .rdata   (sram_rdata),
        .clk     (clk),
        .re_n    (~sram_ren),
        .we_n    (~sram_wen_internal),
        .raddr   (sram_raddr),
        .waddr   (sram_waddr_cnt),
        .wdata   (sram_wdata)
    );

    reg in_vld_d1, in_vld_d2;
    reg addr_valid_d1, addr_valid_d2;
    reg [63:0] high_d1, high_d2;
    reg [63:0] low_d1, low_d2;
    reg [6:0] num_one_high_d1, num_one_high_d2;
    reg [6:0] num_one_low_d1, num_one_low_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_vld_d1 <= 1'b0;
            in_vld_d2 <= 1'b0;
            addr_valid_d1 <= 1'b0;
            addr_valid_d2 <= 1'b0;
            high_d1 <= 64'd0;
            high_d2 <= 64'd0;
            low_d1 <= 64'd0;
            low_d2 <= 64'd0;
            num_one_high_d1 <= 7'd0;
            num_one_high_d2 <= 7'd0;
            num_one_low_d1 <= 7'd0;
            num_one_low_d2 <= 7'd0;
        end else begin
            in_vld_d1 <= in_vld;
            in_vld_d2 <= in_vld_d1;
            addr_valid_d1 <= addr_valid;
            addr_valid_d2 <= addr_valid_d1;
            high_d1 <= high;
            high_d2 <= high_d1;
            low_d1 <= low;
            low_d2 <= low_d1;
            num_one_high_d1 <= num_one_high;
            num_one_high_d2 <= num_one_high_d1;
            num_one_low_d1 <= num_one_low;
            num_one_low_d2 <= num_one_low_d1;
        end
    end

    reg [63:0] weight;
    always @(*) begin
        case (num_one_low_d2[5:0])
            6'd0:  weight = L7_WEIGHT_KR_0;
            6'd1:  weight = L7_WEIGHT_KR_1;
            6'd2:  weight = L7_WEIGHT_KR_2;
            6'd3:  weight = L7_WEIGHT_KR_3;
            6'd4:  weight = L7_WEIGHT_KR_4;
            6'd5:  weight = L7_WEIGHT_KR_5;
            6'd6:  weight = L7_WEIGHT_KR_6;
            6'd7:  weight = L7_WEIGHT_KR_7;
            6'd8:  weight = L7_WEIGHT_KR_8;
            6'd9:  weight = L7_WEIGHT_KR_9;
            6'd10: weight = L7_WEIGHT_KR_10;
            6'd11: weight = L7_WEIGHT_KR_11;
            6'd12: weight = L7_WEIGHT_KR_12;
            6'd13: weight = L7_WEIGHT_KR_13;
            6'd14: weight = L7_WEIGHT_KR_14;
            6'd15: weight = L7_WEIGHT_KR_15;
            6'd16: weight = L7_WEIGHT_KR_16;
            6'd17: weight = L7_WEIGHT_KR_17;
            6'd18: weight = L7_WEIGHT_KR_18;
            6'd19: weight = L7_WEIGHT_KR_19;
            6'd20: weight = L7_WEIGHT_KR_20;
            6'd21: weight = L7_WEIGHT_KR_21;
            6'd22: weight = L7_WEIGHT_KR_22;
            6'd23: weight = L7_WEIGHT_KR_23;
            6'd24: weight = L7_WEIGHT_KR_24;
            6'd25: weight = L7_WEIGHT_KR_25;
            6'd26: weight = L7_WEIGHT_KR_26;
            6'd27: weight = L7_WEIGHT_KR_27;
            6'd28: weight = L7_WEIGHT_KR_28;
            6'd29: weight = L7_WEIGHT_KR_29;
            6'd30: weight = L7_WEIGHT_KR_30;
            6'd31: weight = L7_WEIGHT_KR_31;
            6'd32: weight = L7_WEIGHT_KR_32;
            default: weight = 64'd0;
        endcase
    end

    wire [101:0] offset = addr_valid_d2 ? sram_rdata : 102'd0;
    wire [5:0] out_num_one_w = num_one_high_d2[5:0] + num_one_low_d2[5:0];
    wire [101:0] out_data_w = offset + high_d2 * weight + low_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_data <= 102'd0;
            out_num_one <= 8'd0;
        end else begin
            out_vld <= in_vld_d2;
            out_data <= out_data_w;
            out_num_one <= {2'd0, out_num_one_w};
        end
    end

endmodule
