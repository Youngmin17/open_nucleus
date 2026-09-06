// SPDX-License-Identifier: Apache-2.0
module unit_redecomp (
    input wire clk,
    input wire rst_n,

    input wire in_vld,
    input wire [101:0] vali,
    input wire [6:0] kl,
    input wire [6:0] kr,
    output wire out_vld,
    output wire [128-1:0] out_data
);

    genvar i;

    localparam L1_WEIGHT_KR_0                 = 1'd1;
    localparam L1_WEIGHT_KR_1                 = 7'd64;
    localparam L1_WEIGHT_KR_2                 = 11'd2016;
    localparam L1_WEIGHT_KR_3                 = 16'd41664;
    localparam L1_WEIGHT_KR_4                 = 20'd635376;
    localparam L1_WEIGHT_KR_5                 = 23'd7624512;
    localparam L1_WEIGHT_KR_6                 = 27'd74974368;
    localparam L1_WEIGHT_KR_7                 = 30'd621216192;
    localparam L1_WEIGHT_KR_8                 = 33'd4426165368;
    localparam L1_WEIGHT_KR_9                 = 35'd27540584512;
    localparam L1_WEIGHT_KR_10                = 38'd151473214816;
    localparam L1_WEIGHT_KR_11                = 40'd743595781824;
    localparam L1_WEIGHT_KR_12                = 42'd3284214703056;
    localparam L1_WEIGHT_KR_13                = 44'd13136858812224;
    localparam L1_WEIGHT_KR_14                = 46'd47855699958816;
    localparam L1_WEIGHT_KR_15                = 48'd159518999862720;
    localparam L1_WEIGHT_KR_16                = 49'd488526937079580;
    localparam L1_WEIGHT_KR_17                = 51'd1379370175283520;
    localparam L1_WEIGHT_KR_18                = 52'd3601688791018080;
    localparam L1_WEIGHT_KR_19                = 53'd8719878125622720;
    localparam L1_WEIGHT_KR_20                = 55'd19619725782651120;
    localparam L1_WEIGHT_KR_21                = 56'd41107996877935680;
    localparam L1_WEIGHT_KR_22                = 57'd80347448443237920;
    localparam L1_WEIGHT_KR_23                = 58'd146721427591999680;
    localparam L1_WEIGHT_KR_24                = 58'd250649105469666120;
    localparam L1_WEIGHT_KR_25                = 59'd401038568751465792;
    localparam L1_WEIGHT_KR_26                = 60'd601557853127198688;
    localparam L1_WEIGHT_KR_27                = 60'd846636978475316672;
    localparam L1_WEIGHT_KR_28                = 60'd1118770292985239888;
    localparam L1_WEIGHT_KR_29                = 61'd1388818294740297792;
    localparam L1_WEIGHT_KR_30                = 61'd1620288010530347424;
    localparam L1_WEIGHT_KR_31                = 61'd1777090076065542336;
    localparam L1_WEIGHT_KR_32                = 61'd1832624140942590534;

    localparam L1_REC_WEIGHT_KR_0            = 103'd5070602400912917605986812821504;
    localparam L1_REC_WEIGHT_KR_1            = 97'd79228162514264337593543950336;
    localparam L1_REC_WEIGHT_KR_2            = 92'd2515179762357598018842665090;
    localparam L1_REC_WEIGHT_KR_3            = 87'd121702246565690226718193472;
    localparam L1_REC_WEIGHT_KR_4            = 83'd7980475184635424702832358;
    localparam L1_REC_WEIGHT_KR_5            = 80'd665039598719618725236029;
    localparam L1_REC_WEIGHT_KR_6            = 76'd67631145632503599176545;
    localparam L1_REC_WEIGHT_KR_7            = 73'd8162379645302158521307;
    localparam L1_REC_WEIGHT_KR_8            = 70'd1145597143200302950358;
    localparam L1_REC_WEIGHT_KR_9            = 68'd184113826585762974164;
    localparam L1_REC_WEIGHT_KR_10           = 65'd33475241197411449848;
    localparam L1_REC_WEIGHT_KR_11           = 63'd6819030614287517561;
    localparam L1_REC_WEIGHT_KR_12           = 61'd1543931459838683221;
    localparam L1_REC_WEIGHT_KR_13           = 59'd385982864959670805;
    localparam L1_REC_WEIGHT_KR_14           = 57'd105956080577164534;
    localparam L1_REC_WEIGHT_KR_15           = 55'd31786824173149360;
    localparam L1_REC_WEIGHT_KR_16           = 54'd10379371158579383;
    localparam L1_REC_WEIGHT_KR_17           = 52'd3676027285330198;
    localparam L1_REC_WEIGHT_KR_18           = 51'd1407840236934969;
    localparam L1_REC_WEIGHT_KR_19           = 50'd581499228299226;
    localparam L1_REC_WEIGHT_KR_20           = 48'd258444101466322;
    localparam L1_REC_WEIGHT_KR_21           = 47'd123348321154381;
    localparam L1_REC_WEIGHT_KR_22           = 46'd63108443381311;
    localparam L1_REC_WEIGHT_KR_23           = 45'd34559385661194;
    localparam L1_REC_WEIGHT_KR_24           = 45'd20229884289479;
    localparam L1_REC_WEIGHT_KR_25           = 44'd12643677680924;
    localparam L1_REC_WEIGHT_KR_26           = 43'd8429118453949;
    localparam L1_REC_WEIGHT_KR_27           = 43'd5989110480438;
    localparam L1_REC_WEIGHT_KR_28           = 43'd4532299823034;
    localparam L1_REC_WEIGHT_KR_29           = 42'd3651019301888;
    localparam L1_REC_WEIGHT_KR_30           = 42'd3129445115904;
    localparam L1_REC_WEIGHT_KR_31           = 42'd2853317605677;
    localparam L1_REC_WEIGHT_KR_32           = 42'd2766853435808;

    wire [102:0] rec_weight_sel =
                        kr == 7'd0 ? L1_REC_WEIGHT_KR_0 :
                        kr == 7'd1 ? {{6{1'b0}}, L1_REC_WEIGHT_KR_1} :
                        kr == 7'd2 ? {{11{1'b0}}, L1_REC_WEIGHT_KR_2} :
                        kr == 7'd3 ? {{16{1'b0}}, L1_REC_WEIGHT_KR_3} :
                        kr == 7'd4 ? {{20{1'b0}}, L1_REC_WEIGHT_KR_4} :
                        kr == 7'd5 ? {{23{1'b0}}, L1_REC_WEIGHT_KR_5} :
                        kr == 7'd6 ? {{27{1'b0}}, L1_REC_WEIGHT_KR_6} :
                        kr == 7'd7 ? {{30{1'b0}}, L1_REC_WEIGHT_KR_7} :
                        kr == 7'd8 ? {{33{1'b0}}, L1_REC_WEIGHT_KR_8} :
                        kr == 7'd9 ? {{35{1'b0}}, L1_REC_WEIGHT_KR_9} :
                        kr == 7'd10 ? {{38{1'b0}}, L1_REC_WEIGHT_KR_10} :
                        kr == 7'd11 ? {{40{1'b0}}, L1_REC_WEIGHT_KR_11} :
                        kr == 7'd12 ? {{42{1'b0}}, L1_REC_WEIGHT_KR_12} :
                        kr == 7'd13 ? {{44{1'b0}}, L1_REC_WEIGHT_KR_13} :
                        kr == 7'd14 ? {{46{1'b0}}, L1_REC_WEIGHT_KR_14} :
                        kr == 7'd15 ? {{48{1'b0}}, L1_REC_WEIGHT_KR_15} :
                        kr == 7'd16 ? {{49{1'b0}}, L1_REC_WEIGHT_KR_16} :
                        kr == 7'd17 ? {{51{1'b0}}, L1_REC_WEIGHT_KR_17} :
                        kr == 7'd18 ? {{52{1'b0}}, L1_REC_WEIGHT_KR_18} :
                        kr == 7'd19 ? {{53{1'b0}}, L1_REC_WEIGHT_KR_19} :
                        kr == 7'd20 ? {{55{1'b0}}, L1_REC_WEIGHT_KR_20} :
                        kr == 7'd21 ? {{56{1'b0}}, L1_REC_WEIGHT_KR_21} :
                        kr == 7'd22 ? {{57{1'b0}}, L1_REC_WEIGHT_KR_22} :
                        kr == 7'd23 ? {{58{1'b0}}, L1_REC_WEIGHT_KR_23} :
                        kr == 7'd24 ? {{58{1'b0}}, L1_REC_WEIGHT_KR_24} :
                        kr == 7'd25 ? {{59{1'b0}}, L1_REC_WEIGHT_KR_25} :
                        kr == 7'd26 ? {{60{1'b0}}, L1_REC_WEIGHT_KR_26} :
                        kr == 7'd27 ? {{60{1'b0}}, L1_REC_WEIGHT_KR_27} :
                        kr == 7'd28 ? {{60{1'b0}}, L1_REC_WEIGHT_KR_28} :
                        kr == 7'd29 ? {{61{1'b0}}, L1_REC_WEIGHT_KR_29} :
                        kr == 7'd30 ? {{61{1'b0}}, L1_REC_WEIGHT_KR_30} :
                        kr == 7'd31 ? {{61{1'b0}}, L1_REC_WEIGHT_KR_31} :
                        {{61{1'b0}}, L1_REC_WEIGHT_KR_32};

    wire [50:0] vali_hi = vali[101:51];
    wire [51:0] rec_hi  = rec_weight_sel[102:51];
    wire [50:0] rec_lo  = rec_weight_sel[50:0];

    wire [153:0] prod_a = vali * rec_hi;
    wire [101:0] prod_b = vali_hi * rec_lo;

    wire [108:0] contrib_a = prod_a[153:45];
    wire [56:0]  contrib_b = prod_b[101:45];
    wire [108:0] sum_guard = contrib_a + {52'd0, contrib_b};
    wire [60:0] val_l_raw = sum_guard[66:6];

    wire [60:0] weight_sel = kr == 7'd0 ? L1_WEIGHT_KR_0 :
                        kr == 7'd1 ? L1_WEIGHT_KR_1 :
                        kr == 7'd2 ? L1_WEIGHT_KR_2 :
                        kr == 7'd3 ? L1_WEIGHT_KR_3 :
                        kr == 7'd4 ? L1_WEIGHT_KR_4 :
                        kr == 7'd5 ? L1_WEIGHT_KR_5 :
                        kr == 7'd6 ? L1_WEIGHT_KR_6 :
                        kr == 7'd7 ? L1_WEIGHT_KR_7 :
                        kr == 7'd8 ? L1_WEIGHT_KR_8 :
                        kr == 7'd9 ? L1_WEIGHT_KR_9 :
                        kr == 7'd10 ? L1_WEIGHT_KR_10 :
                        kr == 7'd11 ? L1_WEIGHT_KR_11 :
                        kr == 7'd12 ? L1_WEIGHT_KR_12 :
                        kr == 7'd13 ? L1_WEIGHT_KR_13 :
                        kr == 7'd14 ? L1_WEIGHT_KR_14 :
                        kr == 7'd15 ? L1_WEIGHT_KR_15 :
                        kr == 7'd16 ? L1_WEIGHT_KR_16 :
                        kr == 7'd17 ? L1_WEIGHT_KR_17 :
                        kr == 7'd18 ? L1_WEIGHT_KR_18 :
                        kr == 7'd19 ? L1_WEIGHT_KR_19 :
                        kr == 7'd20 ? L1_WEIGHT_KR_20 :
                        kr == 7'd21 ? L1_WEIGHT_KR_21 :
                        kr == 7'd22 ? L1_WEIGHT_KR_22 :
                        kr == 7'd23 ? L1_WEIGHT_KR_23 :
                        kr == 7'd24 ? L1_WEIGHT_KR_24 :
                        kr == 7'd25 ? L1_WEIGHT_KR_25 :
                        kr == 7'd26 ? L1_WEIGHT_KR_26 :
                        kr == 7'd27 ? L1_WEIGHT_KR_27 :
                        kr == 7'd28 ? L1_WEIGHT_KR_28 :
                        kr == 7'd29 ? L1_WEIGHT_KR_29 :
                        kr == 7'd30 ? L1_WEIGHT_KR_30 :
                        kr == 7'd31 ? L1_WEIGHT_KR_31 :
                        L1_WEIGHT_KR_32;

    wire [121:0] val_l_times_w = val_l_raw * weight_sel;
    wire [101:0] val_r_raw = vali - val_l_times_w[101:0];

    wire overflow_r = (val_r_raw[60:0] >= weight_sel) & (val_r_raw[101:61] == 41'd0);

    wire [60:0] val_l_w = overflow_r ? (val_l_raw + 61'd1) : val_l_raw;
    wire [60:0] val_r_w = overflow_r ? (val_r_raw[60:0] - weight_sel) : val_r_raw[60:0];

    reg [60:0] val_l_r;
    reg [60:0] val_r_r;
    reg [6:0] kl_r;
    reg [6:0] kr_r;

    wire [30*2-1:0] L2_out_data_w [1:0];
    wire [6*2-1:0] L2_out_k_w [1:0];
    wire [1:0] L2_out_vld_w;
    wire [14*2-1:0] L3_out_data_w [3:0];
    wire [5*2-1:0] L3_out_k_w [3:0];
    wire [3:0] L3_out_vld_w;
    wire [7*2-1:0] L4_out_data_w [7:0];
    wire [4*2-1:0] L4_out_k_w [7:0];

    reg [30*2-1:0] L2_out_data [1:0];
    reg [6*2-1:0] L2_out_k [1:0];
    reg [14*2-1:0] L3_out_data [3:0];
    reg [5*2-1:0] L3_out_k [3:0];
    reg [6:0] L4_out_data [7:0];
    reg [3:0] L4_out_k [7:0];

    reg L1_out_vld, L2_out_vld, L3_out_vld, out_vld_r;

    assign out_vld = out_vld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            val_l_r <= 64'd0;
            val_r_r <= 64'd0;
            kl_r <= 7'd0;
            kr_r <= 7'd0;
            L1_out_vld <= 1'b0;
            L2_out_vld <= 1'b0;
            L3_out_vld <= 1'b0;
            out_vld_r <= 1'b0;
        end else begin
            L1_out_vld <= in_vld;
            L2_out_vld <= L2_out_vld_w[0];
            L3_out_vld <= L3_out_vld_w[0];
            out_vld_r <= L3_out_vld_w[0];
            if(in_vld) begin
                val_l_r <= val_l_w;
                val_r_r <= val_r_w;
                kl_r <= kl;
                kr_r <= kr;
            end
            if(L2_out_vld_w[0]) begin
                L2_out_data[0] <= L2_out_data_w[0];
                L2_out_data[1] <= L2_out_data_w[1];
                L2_out_k[0] <= L2_out_k_w[0];
                L2_out_k[1] <= L2_out_k_w[1];
            end
            if(L3_out_vld_w[0]) begin
                L3_out_data[0] <= L3_out_data_w[0];
                L3_out_data[1] <= L3_out_data_w[1];
                L3_out_data[2] <= L3_out_data_w[2];
                L3_out_data[3] <= L3_out_data_w[3];
                L3_out_k[0] <= L3_out_k_w[0];
                L3_out_k[1] <= L3_out_k_w[1];
                L3_out_k[2] <= L3_out_k_w[2];
                L3_out_k[3] <= L3_out_k_w[3];
            end
        end
    end

    generate
    for(i=0; i<2; i=i+1) begin : l2_gen
        L2_redecomp u_L2_redecomp_inst (
            .clk(clk),
            .rst_n(rst_n),
            .in_vld(L1_out_vld),
            .val(i == 0 ? val_r_r : val_l_r),
            .k(i == 0 ? kr_r : kl_r),
            .val_l(L2_out_data_w[i][30+:30]),
            .val_r(L2_out_data_w[i][0+:30]),
            .kl(L2_out_k_w[i][6+:6]),
            .kr(L2_out_k_w[i][0+:6]),
            .out_vld(L2_out_vld_w[i])
        );
    end
    endgenerate

    generate
    for(i=0; i<4; i=i+1) begin : l3_gen
        L3_redecomp u_L3_redecomp_inst (
            .clk(clk),
            .rst_n(rst_n),
            .in_vld(L2_out_vld),
            .val(L2_out_data[i/2][i%2*30 +: 30]),
            .k(L2_out_k[i/2][i%2*6 +: 6]),
            .val_l(L3_out_data_w[i][14+:14]),
            .val_r(L3_out_data_w[i][0+:14]),
            .kl(L3_out_k_w[i][5+:5]),
            .kr(L3_out_k_w[i][0+:5]),
            .out_vld(L3_out_vld_w[i])
        );
    end
    endgenerate

    generate
    for(i=0; i<8; i=i+1) begin : l4_gen
        L4_redecomp u_L4_redecomp_inst (
            .val(L3_out_data[i/2][i%2*14 +: 14]),
            .k(L3_out_k[i/2][i%2*5 +: 5]),
            .val_l(L4_out_data_w[i][7+:7]),
            .val_r(L4_out_data_w[i][0+:7]),
            .kl(L4_out_k_w[i][4+:4]),
            .kr(L4_out_k_w[i][0+:4])
        );
    end
    endgenerate

    generate
    for(i=0; i<16; i=i+1) begin : l5_7_gen
        L5_7_redecomp u_L5_7_redecomp_inst (
            .val(L4_out_data_w[i/2][i%2*7 +: 7]),
            .k(L4_out_k_w[i/2][i%2*4 +: 4]),
            .val_out(out_data[i*8 +: 8])
        );
    end
    endgenerate

endmodule