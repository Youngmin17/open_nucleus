// SPDX-License-Identifier: Apache-2.0
module L2_redecomp (
    input wire clk,
    input wire rst_n,
    input wire in_vld,
    input wire [60:0] val,
    input wire [6:0] k,
    output wire [29:0] val_l,
    output wire [29:0] val_r,
    output wire [5:0] kl,
    output wire [5:0] kr,
    output wire out_vld
);

    localparam L2_WEIGHT_KR_0                 = 1'd1;
    localparam L2_WEIGHT_KR_1                 = 6'd32;
    localparam L2_WEIGHT_KR_2                 = 9'd496;
    localparam L2_WEIGHT_KR_3                 = 13'd4960;
    localparam L2_WEIGHT_KR_4                 = 16'd35960;
    localparam L2_WEIGHT_KR_5                 = 18'd201376;
    localparam L2_WEIGHT_KR_6                 = 20'd906192;
    localparam L2_WEIGHT_KR_7                 = 22'd3365856;
    localparam L2_WEIGHT_KR_8                 = 24'd10518300;
    localparam L2_WEIGHT_KR_9                 = 25'd28048800;
    localparam L2_WEIGHT_KR_10                = 26'd64512240;
    localparam L2_WEIGHT_KR_11                = 27'd129024480;
    localparam L2_WEIGHT_KR_12                = 28'd225792840;
    localparam L2_WEIGHT_KR_13                = 29'd347373600;
    localparam L2_WEIGHT_KR_14                = 29'd471435600;
    localparam L2_WEIGHT_KR_15                = 30'd565722720;
    localparam L2_WEIGHT_KR_16                = 30'd601080390;

    localparam L2_REC_WEIGHT_KR_0        = 63'd4611686018427387904;
    localparam L2_REC_WEIGHT_KR_1        = 58'd144115188075855872;
    localparam L2_REC_WEIGHT_KR_2        = 54'd9297754069410056;
    localparam L2_REC_WEIGHT_KR_3        = 50'd929775406941005;
    localparam L2_REC_WEIGHT_KR_4        = 47'd128244883716000;
    localparam L2_REC_WEIGHT_KR_5        = 45'd22900872092142;
    localparam L2_REC_WEIGHT_KR_6        = 43'd5089082687142;
    localparam L2_REC_WEIGHT_KR_7        = 41'd1370137646538;
    localparam L2_REC_WEIGHT_KR_8        = 39'd438444046892;
    localparam L2_REC_WEIGHT_KR_9        = 38'd164416517584;
    localparam L2_REC_WEIGHT_KR_10       = 37'd71485442428;
    localparam L2_REC_WEIGHT_KR_11       = 36'd35742721214;
    localparam L2_REC_WEIGHT_KR_12       = 35'd20424412122;
    localparam L2_REC_WEIGHT_KR_13       = 34'd13275867879;
    localparam L2_REC_WEIGHT_KR_14       = 34'd9782218437;
    localparam L2_REC_WEIGHT_KR_15       = 33'd8151848697;
    localparam L2_REC_WEIGHT_KR_16       = 33'd7672328186;

    localparam L2_OFFSET_K_1_KL_1                  = 61'd32;
    localparam L2_OFFSET_K_2_KL_1                  = 61'd496;
    localparam L2_OFFSET_K_2_KL_2                  = 61'd1520;
    localparam L2_OFFSET_K_3_KL_1                  = 61'd4960;
    localparam L2_OFFSET_K_3_KL_2                  = 61'd20832;
    localparam L2_OFFSET_K_3_KL_3                  = 61'd36704;
    localparam L2_OFFSET_K_4_KL_1                  = 61'd35960;
    localparam L2_OFFSET_K_4_KL_2                  = 61'd194680;
    localparam L2_OFFSET_K_4_KL_3                  = 61'd440696;
    localparam L2_OFFSET_K_4_KL_4                  = 61'd599416;
    localparam L2_OFFSET_K_5_KL_1                  = 61'd201376;
    localparam L2_OFFSET_K_5_KL_2                  = 61'd1352096;
    localparam L2_OFFSET_K_5_KL_3                  = 61'd3812256;
    localparam L2_OFFSET_K_5_KL_4                  = 61'd6272416;
    localparam L2_OFFSET_K_5_KL_5                  = 61'd7423136;
    localparam L2_OFFSET_K_6_KL_1                  = 61'd906192;
    localparam L2_OFFSET_K_6_KL_2                  = 61'd7350224;
    localparam L2_OFFSET_K_6_KL_3                  = 61'd25186384;
    localparam L2_OFFSET_K_6_KL_4                  = 61'd49787984;
    localparam L2_OFFSET_K_6_KL_5                  = 61'd67624144;
    localparam L2_OFFSET_K_6_KL_6                  = 61'd74068176;
    localparam L2_OFFSET_K_7_KL_1                  = 61'd3365856;
    localparam L2_OFFSET_K_7_KL_2                  = 61'd32364000;
    localparam L2_OFFSET_K_7_KL_3                  = 61'd132246496;
    localparam L2_OFFSET_K_7_KL_4                  = 61'd310608096;
    localparam L2_OFFSET_K_7_KL_5                  = 61'd488969696;
    localparam L2_OFFSET_K_7_KL_6                  = 61'd588852192;
    localparam L2_OFFSET_K_7_KL_7                  = 61'd617850336;
    localparam L2_OFFSET_K_8_KL_1                  = 61'd10518300;
    localparam L2_OFFSET_K_8_KL_2                  = 61'd118225692;
    localparam L2_OFFSET_K_8_KL_3                  = 61'd567696924;
    localparam L2_OFFSET_K_8_KL_4                  = 61'd1566521884;
    localparam L2_OFFSET_K_8_KL_5                  = 61'd2859643484;
    localparam L2_OFFSET_K_8_KL_6                  = 61'd3858468444;
    localparam L2_OFFSET_K_8_KL_7                  = 61'd4307939676;
    localparam L2_OFFSET_K_8_KL_8                  = 61'd4415647068;
    localparam L2_OFFSET_K_9_KL_1                  = 61'd28048800;
    localparam L2_OFFSET_K_9_KL_2                  = 61'd364634400;
    localparam L2_OFFSET_K_9_KL_3                  = 61'd2034098976;
    localparam L2_OFFSET_K_9_KL_4                  = 61'd6528811296;
    localparam L2_OFFSET_K_9_KL_5                  = 61'd13770292256;
    localparam L2_OFFSET_K_9_KL_6                  = 61'd21011773216;
    localparam L2_OFFSET_K_9_KL_7                  = 61'd25506485536;
    localparam L2_OFFSET_K_9_KL_8                  = 61'd27175950112;
    localparam L2_OFFSET_K_9_KL_9                  = 61'd27512535712;
    localparam L2_OFFSET_K_10_KL_1                 = 61'd64512240;
    localparam L2_OFFSET_K_10_KL_2                 = 61'd962073840;
    localparam L2_OFFSET_K_10_KL_3                 = 61'd6179150640;
    localparam L2_OFFSET_K_10_KL_4                 = 61'd22873796400;
    localparam L2_OFFSET_K_10_KL_5                 = 61'd55460460720;
    localparam L2_OFFSET_K_10_KL_6                 = 61'd96012754096;
    localparam L2_OFFSET_K_10_KL_7                 = 61'd128599418416;
    localparam L2_OFFSET_K_10_KL_8                 = 61'd145294064176;
    localparam L2_OFFSET_K_10_KL_9                 = 61'd150511140976;
    localparam L2_OFFSET_K_10_KL_10                = 61'd151408702576;
    localparam L2_OFFSET_K_11_KL_1                 = 61'd129024480;
    localparam L2_OFFSET_K_11_KL_2                 = 61'd2193416160;
    localparam L2_OFFSET_K_11_KL_3                 = 61'd16105620960;
    localparam L2_OFFSET_K_11_KL_4                 = 61'd68276388960;
    localparam L2_OFFSET_K_11_KL_5                 = 61'd189312570720;
    localparam L2_OFFSET_K_11_KL_6                 = 61'd371797890912;
    localparam L2_OFFSET_K_11_KL_7                 = 61'd554283211104;
    localparam L2_OFFSET_K_11_KL_8                 = 61'd675319392864;
    localparam L2_OFFSET_K_11_KL_9                 = 61'd727490160864;
    localparam L2_OFFSET_K_11_KL_10                = 61'd741402365664;
    localparam L2_OFFSET_K_11_KL_11                = 61'd743466757344;
    localparam L2_OFFSET_K_12_KL_1                 = 61'd225792840;
    localparam L2_OFFSET_K_12_KL_2                 = 61'd4354576200;
    localparam L2_OFFSET_K_12_KL_3                 = 61'd36352647240;
    localparam L2_OFFSET_K_12_KL_4                 = 61'd175474695240;
    localparam L2_OFFSET_K_12_KL_5                 = 61'd553712763240;
    localparam L2_OFFSET_K_12_KL_6                 = 61'd1231515381096;
    localparam L2_OFFSET_K_12_KL_7                 = 61'd2052699321960;
    localparam L2_OFFSET_K_12_KL_8                 = 61'd2730501939816;
    localparam L2_OFFSET_K_12_KL_9                 = 61'd3108740007816;
    localparam L2_OFFSET_K_12_KL_10                = 61'd3247862055816;
    localparam L2_OFFSET_K_12_KL_11                = 61'd3279860126856;
    localparam L2_OFFSET_K_12_KL_12                = 61'd3283988910216;
    localparam L2_OFFSET_K_13_KL_1                 = 61'd347373600;
    localparam L2_OFFSET_K_13_KL_2                 = 61'd7572744480;
    localparam L2_OFFSET_K_13_KL_3                 = 61'd71568886560;
    localparam L2_OFFSET_K_13_KL_4                 = 61'd391549596960;
    localparam L2_OFFSET_K_13_KL_5                 = 61'd1400184444960;
    localparam L2_OFFSET_K_13_KL_6                 = 61'd3518317625760;
    localparam L2_OFFSET_K_13_KL_7                 = 61'd6568429406112;
    localparam L2_OFFSET_K_13_KL_8                 = 61'd9618541186464;
    localparam L2_OFFSET_K_13_KL_9                 = 61'd11736674367264;
    localparam L2_OFFSET_K_13_KL_10                = 61'd12745309215264;
    localparam L2_OFFSET_K_13_KL_11                = 61'd13065289925664;
    localparam L2_OFFSET_K_13_KL_12                = 61'd13129286067744;
    localparam L2_OFFSET_K_13_KL_13                = 61'd13136511438624;
    localparam L2_OFFSET_K_14_KL_1                 = 61'd471435600;
    localparam L2_OFFSET_K_14_KL_2                 = 61'd11587390800;
    localparam L2_OFFSET_K_14_KL_3                 = 61'd123580639440;
    localparam L2_OFFSET_K_14_KL_4                 = 61'd763542060240;
    localparam L2_OFFSET_K_14_KL_5                 = 61'd3083402210640;
    localparam L2_OFFSET_K_14_KL_6                 = 61'd8731757359440;
    localparam L2_OFFSET_K_14_KL_7                 = 61'd18263356673040;
    localparam L2_OFFSET_K_14_KL_8                 = 61'd29592343285776;
    localparam L2_OFFSET_K_14_KL_9                 = 61'd39123942599376;
    localparam L2_OFFSET_K_14_KL_10                = 61'd44772297748176;
    localparam L2_OFFSET_K_14_KL_11                = 61'd47092157898576;
    localparam L2_OFFSET_K_14_KL_12                = 61'd47732119319376;
    localparam L2_OFFSET_K_14_KL_13                = 61'd47844112568016;
    localparam L2_OFFSET_K_14_KL_14                = 61'd47855228523216;
    localparam L2_OFFSET_K_15_KL_1                 = 61'd565722720;
    localparam L2_OFFSET_K_15_KL_2                 = 61'd15651661920;
    localparam L2_OFFSET_K_15_KL_3                 = 61'd187948967520;
    localparam L2_OFFSET_K_15_KL_4                 = 61'd1307881453920;
    localparam L2_OFFSET_K_15_KL_5                 = 61'd5947601754720;
    localparam L2_OFFSET_K_15_KL_6                 = 61'd18938818596960;
    localparam L2_OFFSET_K_15_KL_7                 = 61'd44356416766560;
    localparam L2_OFFSET_K_15_KL_8                 = 61'd79759499931360;
    localparam L2_OFFSET_K_15_KL_9                 = 61'd115162583096160;
    localparam L2_OFFSET_K_15_KL_10                = 61'd140580181265760;
    localparam L2_OFFSET_K_15_KL_11                = 61'd153571398108000;
    localparam L2_OFFSET_K_15_KL_12                = 61'd158211118408800;
    localparam L2_OFFSET_K_15_KL_13                = 61'd159331050895200;
    localparam L2_OFFSET_K_15_KL_14                = 61'd159503348200800;
    localparam L2_OFFSET_K_15_KL_15                = 61'd159518434140000;
    localparam L2_OFFSET_K_16_KL_1                 = 61'd601080390;
    localparam L2_OFFSET_K_16_KL_2                 = 61'd18704207430;
    localparam L2_OFFSET_K_16_KL_3                 = 61'd252536265030;
    localparam L2_OFFSET_K_16_KL_4                 = 61'd1975509321030;
    localparam L2_OFFSET_K_16_KL_5                 = 61'd10095019847430;
    localparam L2_OFFSET_K_16_KL_6                 = 61'd36077453531910;
    localparam L2_OFFSET_K_16_KL_7                 = 61'd94537929321990;
    localparam L2_OFFSET_K_16_KL_8                 = 61'd188946151094790;
    localparam L2_OFFSET_K_16_KL_9                 = 61'd299580785984790;
    localparam L2_OFFSET_K_16_KL_10                = 61'd393989007757590;
    localparam L2_OFFSET_K_16_KL_11                = 61'd452449483547670;
    localparam L2_OFFSET_K_16_KL_12                = 61'd478431917232150;
    localparam L2_OFFSET_K_16_KL_13                = 61'd486551427758550;
    localparam L2_OFFSET_K_16_KL_14                = 61'd488274400814550;
    localparam L2_OFFSET_K_16_KL_15                = 61'd488508232872150;
    localparam L2_OFFSET_K_16_KL_16                = 61'd488526335999190;
    localparam L2_OFFSET_K_17_KL_1                 = 61'd565722720;
    localparam L2_OFFSET_K_17_KL_2                 = 61'd19800295200;
    localparam L2_OFFSET_K_17_KL_3                 = 61'd300398764320;
    localparam L2_OFFSET_K_17_KL_4                 = 61'd2638719340320;
    localparam L2_OFFSET_K_17_KL_5                 = 61'd15130273996320;
    localparam L2_OFFSET_K_17_KL_6                 = 61'd60599532944160;
    localparam L2_OFFSET_K_17_KL_7                 = 61'd177520484524320;
    localparam L2_OFFSET_K_17_KL_8                 = 61'd394659394601760;
    localparam L2_OFFSET_K_17_KL_9                 = 61'd689685087641760;
    localparam L2_OFFSET_K_17_KL_10                = 61'd984710780681760;
    localparam L2_OFFSET_K_17_KL_11                = 61'd1201849690759200;
    localparam L2_OFFSET_K_17_KL_12                = 61'd1318770642339360;
    localparam L2_OFFSET_K_17_KL_13                = 61'd1364239901287200;
    localparam L2_OFFSET_K_17_KL_14                = 61'd1376731455943200;
    localparam L2_OFFSET_K_17_KL_15                = 61'd1379069776519200;
    localparam L2_OFFSET_K_17_KL_16                = 61'd1379350374988320;
    localparam L2_OFFSET_K_17_KL_17                = 61'd1379369609560800;
    localparam L2_OFFSET_K_18_KL_1                 = 61'd471435600;
    localparam L2_OFFSET_K_18_KL_2                 = 61'd18574562640;
    localparam L2_OFFSET_K_18_KL_3                 = 61'd316710436080;
    localparam L2_OFFSET_K_18_KL_4                 = 61'd3122695127280;
    localparam L2_OFFSET_K_18_KL_5                 = 61'd20075519303280;
    localparam L2_OFFSET_K_18_KL_6                 = 61'd90028225376880;
    localparam L2_OFFSET_K_18_KL_7                 = 61'd294639890642160;
    localparam L2_OFFSET_K_18_KL_8                 = 61'd728917710797040;
    localparam L2_OFFSET_K_18_KL_9                 = 61'd1407476804789040;
    localparam L2_OFFSET_K_18_KL_10                = 61'd2194211986229040;
    localparam L2_OFFSET_K_18_KL_11                = 61'd2872771080221040;
    localparam L2_OFFSET_K_18_KL_12                = 61'd3307048900375920;
    localparam L2_OFFSET_K_18_KL_13                = 61'd3511660565641200;
    localparam L2_OFFSET_K_18_KL_14                = 61'd3581613271714800;
    localparam L2_OFFSET_K_18_KL_15                = 61'd3598566095890800;
    localparam L2_OFFSET_K_18_KL_16                = 61'd3601372080582000;
    localparam L2_OFFSET_K_18_KL_17                = 61'd3601670216455440;
    localparam L2_OFFSET_K_18_KL_18                = 61'd3601688319582480;
    localparam L2_OFFSET_K_19_KL_1                 = 61'd347373600;
    localparam L2_OFFSET_K_19_KL_2                 = 61'd15433312800;
    localparam L2_OFFSET_K_19_KL_3                 = 61'd296031781920;
    localparam L2_OFFSET_K_19_KL_4                 = 61'd3277390516320;
    localparam L2_OFFSET_K_19_KL_5                 = 61'd23620779527520;
    localparam L2_OFFSET_K_19_KL_6                 = 61'd118556594913120;
    localparam L2_OFFSET_K_19_KL_7                 = 61'd433343772244320;
    localparam L2_OFFSET_K_19_KL_8                 = 61'd1193329957515360;
    localparam L2_OFFSET_K_19_KL_9                 = 61'd2550448145499360;
    localparam L2_OFFSET_K_19_KL_10                = 61'd4359939062811360;
    localparam L2_OFFSET_K_19_KL_11                = 61'd6169429980123360;
    localparam L2_OFFSET_K_19_KL_12                = 61'd7526548168107360;
    localparam L2_OFFSET_K_19_KL_13                = 61'd8286534353378400;
    localparam L2_OFFSET_K_19_KL_14                = 61'd8601321530709600;
    localparam L2_OFFSET_K_19_KL_15                = 61'd8696257346095200;
    localparam L2_OFFSET_K_19_KL_16                = 61'd8716600735106400;
    localparam L2_OFFSET_K_19_KL_17                = 61'd8719582093840800;
    localparam L2_OFFSET_K_19_KL_18                = 61'd8719862692309920;
    localparam L2_OFFSET_K_19_KL_19                = 61'd8719877778249120;
    localparam L2_OFFSET_K_20_KL_1                 = 61'd225792840;
    localparam L2_OFFSET_K_20_KL_2                 = 61'd11341748040;
    localparam L2_OFFSET_K_20_KL_3                 = 61'd245173805640;
    localparam L2_OFFSET_K_20_KL_4                 = 61'd3051158496840;
    localparam L2_OFFSET_K_20_KL_5                 = 61'd24666009321240;
    localparam L2_OFFSET_K_20_KL_6                 = 61'd138588987783960;
    localparam L2_OFFSET_K_20_KL_7                 = 61'd565800157019160;
    localparam L2_OFFSET_K_20_KL_8                 = 61'd1735009672820760;
    localparam L2_OFFSET_K_20_KL_9                 = 61'd4109966501792760;
    localparam L2_OFFSET_K_20_KL_10                = 61'd7728948336416760;
    localparam L2_OFFSET_K_20_KL_11                = 61'd11890777446234360;
    localparam L2_OFFSET_K_20_KL_12                = 61'd15509759280858360;
    localparam L2_OFFSET_K_20_KL_13                = 61'd17884716109830360;
    localparam L2_OFFSET_K_20_KL_14                = 61'd19053925625631960;
    localparam L2_OFFSET_K_20_KL_15                = 61'd19481136794867160;
    localparam L2_OFFSET_K_20_KL_16                = 61'd19595059773329880;
    localparam L2_OFFSET_K_20_KL_17                = 61'd19616674624154280;
    localparam L2_OFFSET_K_20_KL_18                = 61'd19619480608845480;
    localparam L2_OFFSET_K_20_KL_19                = 61'd19619714440903080;
    localparam L2_OFFSET_K_20_KL_20                = 61'd19619725556858280;
    localparam L2_OFFSET_K_21_KL_1                 = 61'd129024480;
    localparam L2_OFFSET_K_21_KL_2                 = 61'd7354395360;
    localparam L2_OFFSET_K_21_KL_3                 = 61'd179651700960;
    localparam L2_OFFSET_K_21_KL_4                 = 61'd2517972276960;
    localparam L2_OFFSET_K_21_KL_5                 = 61'd22861361288160;
    localparam L2_OFFSET_K_21_KL_6                 = 61'd143904525904800;
    localparam L2_OFFSET_K_21_KL_7                 = 61'd656557928987040;
    localparam L2_OFFSET_K_21_KL_8                 = 61'd2243342271860640;
    localparam L2_OFFSET_K_21_KL_9                 = 61'd5897122008740640;
    localparam L2_OFFSET_K_21_KL_10                = 61'd12230340219332640;
    localparam L2_OFFSET_K_21_KL_11                = 61'd20553998438967840;
    localparam L2_OFFSET_K_21_KL_12                = 61'd28877656658603040;
    localparam L2_OFFSET_K_21_KL_13                = 61'd35210874869195040;
    localparam L2_OFFSET_K_21_KL_14                = 61'd38864654606075040;
    localparam L2_OFFSET_K_21_KL_15                = 61'd40451438948948640;
    localparam L2_OFFSET_K_21_KL_16                = 61'd40964092352030880;
    localparam L2_OFFSET_K_21_KL_17                = 61'd41085135516647520;
    localparam L2_OFFSET_K_21_KL_18                = 61'd41105478905658720;
    localparam L2_OFFSET_K_21_KL_19                = 61'd41107817226234720;
    localparam L2_OFFSET_K_21_KL_20                = 61'd41107989523540320;
    localparam L2_OFFSET_K_21_KL_21                = 61'd41107996748911200;
    localparam L2_OFFSET_K_22_KL_1                 = 61'd64512240;
    localparam L2_OFFSET_K_22_KL_2                 = 61'd4193295600;
    localparam L2_OFFSET_K_22_KL_3                 = 61'd116186544240;
    localparam L2_OFFSET_K_22_KL_4                 = 61'd1839159600240;
    localparam L2_OFFSET_K_22_KL_5                 = 61'd18791983776240;
    localparam L2_OFFSET_K_22_KL_6                 = 61'd132714962238960;
    localparam L2_OFFSET_K_22_KL_7                 = 61'd677409203013840;
    localparam L2_OFFSET_K_22_KL_8                 = 61'd2581550414462160;
    localparam L2_OFFSET_K_22_KL_9                 = 61'd7540251485942160;
    localparam L2_OFFSET_K_22_KL_10                = 61'd17283664117622160;
    localparam L2_OFFSET_K_22_KL_11                = 61'd31850066001983760;
    localparam L2_OFFSET_K_22_KL_12                = 61'd48497382441254160;
    localparam L2_OFFSET_K_22_KL_13                = 61'd63063784325615760;
    localparam L2_OFFSET_K_22_KL_14                = 61'd72807196957295760;
    localparam L2_OFFSET_K_22_KL_15                = 61'd77765898028775760;
    localparam L2_OFFSET_K_22_KL_16                = 61'd79670039240224080;
    localparam L2_OFFSET_K_22_KL_17                = 61'd80214733480998960;
    localparam L2_OFFSET_K_22_KL_18                = 61'd80328656459461680;
    localparam L2_OFFSET_K_22_KL_19                = 61'd80345609283637680;
    localparam L2_OFFSET_K_22_KL_20                = 61'd80347332256693680;
    localparam L2_OFFSET_K_22_KL_21                = 61'd80347444249942320;
    localparam L2_OFFSET_K_22_KL_22                = 61'd80347448378725680;
    localparam L2_OFFSET_K_23_KL_1                 = 61'd28048800;
    localparam L2_OFFSET_K_23_KL_2                 = 61'd2092440480;
    localparam L2_OFFSET_K_23_KL_3                 = 61'd66088582560;
    localparam L2_OFFSET_K_23_KL_4                 = 61'd1186021068960;
    localparam L2_OFFSET_K_23_KL_5                 = 61'd13677575724960;
    localparam L2_OFFSET_K_23_KL_6                 = 61'd108613391110560;
    localparam L2_OFFSET_K_23_KL_7                 = 61'd621266794192800;
    localparam L2_OFFSET_K_23_KL_8                 = 61'd2644416831356640;
    localparam L2_OFFSET_K_23_KL_9                 = 61'd8594858117132640;
    localparam L2_OFFSET_K_23_KL_10                = 61'd21818060974412640;
    localparam L2_OFFSET_K_23_KL_11                = 61'd44227910027276640;
    localparam L2_OFFSET_K_23_KL_12                = 61'd73360713795999840;
    localparam L2_OFFSET_K_23_KL_13                = 61'd102493517564723040;
    localparam L2_OFFSET_K_23_KL_14                = 61'd124903366617587040;
    localparam L2_OFFSET_K_23_KL_15                = 61'd138126569474867040;
    localparam L2_OFFSET_K_23_KL_16                = 61'd144077010760643040;
    localparam L2_OFFSET_K_23_KL_17                = 61'd146100160797806880;
    localparam L2_OFFSET_K_23_KL_18                = 61'd146612814200889120;
    localparam L2_OFFSET_K_23_KL_19                = 61'd146707750016274720;
    localparam L2_OFFSET_K_23_KL_20                = 61'd146720241570930720;
    localparam L2_OFFSET_K_23_KL_21                = 61'd146721361503417120;
    localparam L2_OFFSET_K_23_KL_22                = 61'd146721425499559200;
    localparam L2_OFFSET_K_23_KL_23                = 61'd146721427563950880;
    localparam L2_OFFSET_K_24_KL_1                 = 61'd10518300;
    localparam L2_OFFSET_K_24_KL_2                 = 61'd908079900;
    localparam L2_OFFSET_K_24_KL_3                 = 61'd32906150940;
    localparam L2_OFFSET_K_24_KL_4                 = 61'd672867571740;
    localparam L2_OFFSET_K_24_KL_5                 = 61'd8792378098140;
    localparam L2_OFFSET_K_24_KL_6                 = 61'd78745084171740;
    localparam L2_OFFSET_K_24_KL_7                 = 61'd505956253406940;
    localparam L2_OFFSET_K_24_KL_8                 = 61'd2410097464855260;
    localparam L2_OFFSET_K_24_KL_9                 = 61'd8732441330992260;
    localparam L2_OFFSET_K_24_KL_10                = 61'd24600284759728260;
    localparam L2_OFFSET_K_24_KL_11                = 61'd55013651331472260;
    localparam L2_OFFSET_K_24_KL_12                = 61'd99833349437200260;
    localparam L2_OFFSET_K_24_KL_13                = 61'd150815756032465860;
    localparam L2_OFFSET_K_24_KL_14                = 61'd195635454138193860;
    localparam L2_OFFSET_K_24_KL_15                = 61'd226048820709937860;
    localparam L2_OFFSET_K_24_KL_16                = 61'd241916664138673860;
    localparam L2_OFFSET_K_24_KL_17                = 61'd248239008004810860;
    localparam L2_OFFSET_K_24_KL_18                = 61'd250143149216259180;
    localparam L2_OFFSET_K_24_KL_19                = 61'd250570360385494380;
    localparam L2_OFFSET_K_24_KL_20                = 61'd250640313091567980;
    localparam L2_OFFSET_K_24_KL_21                = 61'd250648432602094380;
    localparam L2_OFFSET_K_24_KL_22                = 61'd250649072563515180;
    localparam L2_OFFSET_K_24_KL_23                = 61'd250649104561586220;
    localparam L2_OFFSET_K_24_KL_24                = 61'd250649105459147820;
    localparam L2_OFFSET_K_25_KL_1                 = 61'd3365856;
    localparam L2_OFFSET_K_25_KL_2                 = 61'd339951456;
    localparam L2_OFFSET_K_25_KL_3                 = 61'd14252156256;
    localparam L2_OFFSET_K_25_KL_4                 = 61'd334232866656;
    localparam L2_OFFSET_K_25_KL_5                 = 61'd4973953167456;
    localparam L2_OFFSET_K_25_KL_6                 = 61'd50443212115296;
    localparam L2_OFFSET_K_25_KL_7                 = 61'd365230389446496;
    localparam L2_OFFSET_K_25_KL_8                 = 61'd1952014732320096;
    localparam L2_OFFSET_K_25_KL_9                 = 61'd7902456018096096;
    localparam L2_OFFSET_K_25_KL_10                = 61'd24762039661128096;
    localparam L2_OFFSET_K_25_KL_11                = 61'd61258079547220896;
    localparam L2_OFFSET_K_25_KL_12                = 61'd122084812690708896;
    localparam L2_OFFSET_K_25_KL_13                = 61'd200519284375732896;
    localparam L2_OFFSET_K_25_KL_14                = 61'd278953756060756896;
    localparam L2_OFFSET_K_25_KL_15                = 61'd339780489204244896;
    localparam L2_OFFSET_K_25_KL_16                = 61'd376276529090337696;
    localparam L2_OFFSET_K_25_KL_17                = 61'd393136112733369696;
    localparam L2_OFFSET_K_25_KL_18                = 61'd399086554019145696;
    localparam L2_OFFSET_K_25_KL_19                = 61'd400673338362019296;
    localparam L2_OFFSET_K_25_KL_20                = 61'd400988125539350496;
    localparam L2_OFFSET_K_25_KL_21                = 61'd401033594798298336;
    localparam L2_OFFSET_K_25_KL_22                = 61'd401038234518599136;
    localparam L2_OFFSET_K_25_KL_23                = 61'd401038554499309536;
    localparam L2_OFFSET_K_25_KL_24                = 61'd401038568411514336;
    localparam L2_OFFSET_K_25_KL_25                = 61'd401038568748099936;
    localparam L2_OFFSET_K_26_KL_1                 = 61'd906192;
    localparam L2_OFFSET_K_26_KL_2                 = 61'd108613584;
    localparam L2_OFFSET_K_26_KL_3                 = 61'd5325690384;
    localparam L2_OFFSET_K_26_KL_4                 = 61'd144447738384;
    localparam L2_OFFSET_K_26_KL_5                 = 61'd2464307888784;
    localparam L2_OFFSET_K_26_KL_6                 = 61'd28446741573264;
    localparam L2_OFFSET_K_26_KL_7                 = 61'd233058406838544;
    localparam L2_OFFSET_K_26_KL_8                 = 61'd1402267922640144;
    localparam L2_OFFSET_K_26_KL_9                 = 61'd6360968994120144;
    localparam L2_OFFSET_K_26_KL_10                = 61'd22228812422856144;
    localparam L2_OFFSET_K_26_KL_11                = 61'd61005854801829744;
    localparam L2_OFFSET_K_26_KL_12                = 61'd133997934574015344;
    localparam L2_OFFSET_K_26_KL_13                = 61'd240444717575119344;
    localparam L2_OFFSET_K_26_KL_14                = 61'd361113135552079344;
    localparam L2_OFFSET_K_26_KL_15                = 61'd467559918553183344;
    localparam L2_OFFSET_K_26_KL_16                = 61'd540551998325368944;
    localparam L2_OFFSET_K_26_KL_17                = 61'd579329040704342544;
    localparam L2_OFFSET_K_26_KL_18                = 61'd595196884133078544;
    localparam L2_OFFSET_K_26_KL_19                = 61'd600155585204558544;
    localparam L2_OFFSET_K_26_KL_20                = 61'd601324794720360144;
    localparam L2_OFFSET_K_26_KL_21                = 61'd601529406385625424;
    localparam L2_OFFSET_K_26_KL_22                = 61'd601555388819309904;
    localparam L2_OFFSET_K_26_KL_23                = 61'd601557708679460304;
    localparam L2_OFFSET_K_26_KL_24                = 61'd601557847801508304;
    localparam L2_OFFSET_K_26_KL_25                = 61'd601557853018585104;
    localparam L2_OFFSET_K_26_KL_26                = 61'd601557853126292496;
    localparam L2_OFFSET_K_27_KL_1                 = 61'd201376;
    localparam L2_OFFSET_K_27_KL_2                 = 61'd29199520;
    localparam L2_OFFSET_K_27_KL_3                 = 61'd1698664096;
    localparam L2_OFFSET_K_27_KL_4                 = 61'd53869432096;
    localparam L2_OFFSET_K_27_KL_5                 = 61'd1062504280096;
    localparam L2_OFFSET_K_27_KL_6                 = 61'd14053721122336;
    localparam L2_OFFSET_K_27_KL_7                 = 61'd130974672702496;
    localparam L2_OFFSET_K_27_KL_8                 = 61'd890960857973536;
    localparam L2_OFFSET_K_27_KL_9                 = 61'd4544740594853536;
    localparam L2_OFFSET_K_27_KL_10                = 61'd17767943452133536;
    localparam L2_OFFSET_K_27_KL_11                = 61'd54263983338226336;
    localparam L2_OFFSET_K_27_KL_12                = 61'd131818068096173536;
    localparam L2_OFFSET_K_27_KL_13                = 61'd259554207697498336;
    localparam L2_OFFSET_K_27_KL_14                = 61'd423318489237658336;
    localparam L2_OFFSET_K_27_KL_15                = 61'd587082770777818336;
    localparam L2_OFFSET_K_27_KL_16                = 61'd714818910379143136;
    localparam L2_OFFSET_K_27_KL_17                = 61'd792372995137090336;
    localparam L2_OFFSET_K_27_KL_18                = 61'd828869035023183136;
    localparam L2_OFFSET_K_27_KL_19                = 61'd842092237880463136;
    localparam L2_OFFSET_K_27_KL_20                = 61'd845746017617343136;
    localparam L2_OFFSET_K_27_KL_21                = 61'd846506003802614176;
    localparam L2_OFFSET_K_27_KL_22                = 61'd846622924754194336;
    localparam L2_OFFSET_K_27_KL_23                = 61'd846635915971036576;
    localparam L2_OFFSET_K_27_KL_24                = 61'd846636924605884576;
    localparam L2_OFFSET_K_27_KL_25                = 61'd846636976776652576;
    localparam L2_OFFSET_K_27_KL_26                = 61'd846636978446117152;
    localparam L2_OFFSET_K_27_KL_27                = 61'd846636978475115296;
    localparam L2_OFFSET_K_28_KL_1                 = 61'd35960;
    localparam L2_OFFSET_K_28_KL_2                 = 61'd6479992;
    localparam L2_OFFSET_K_28_KL_3                 = 61'd455951224;
    localparam L2_OFFSET_K_28_KL_4                 = 61'd17150596984;
    localparam L2_OFFSET_K_28_KL_5                 = 61'd395388664984;
    localparam L2_OFFSET_K_28_KL_6                 = 61'd6043743813784;
    localparam L2_OFFSET_K_28_KL_7                 = 61'd64504219603864;
    localparam L2_OFFSET_K_28_KL_8                 = 61'd498782039758744;
    localparam L2_OFFSET_K_28_KL_9                 = 61'd2873738868730744;
    localparam L2_OFFSET_K_28_KL_10                = 61'd12617151500410744;
    localparam L2_OFFSET_K_28_KL_11                = 61'd43030518072154744;
    localparam L2_OFFSET_K_28_KL_12                = 61'd116022597844340344;
    localparam L2_OFFSET_K_28_KL_13                = 61'd251742246170747944;
    localparam L2_OFFSET_K_28_KL_14                = 61'd448259384018939944;
    localparam L2_OFFSET_K_28_KL_15                = 61'd670510908966299944;
    localparam L2_OFFSET_K_28_KL_16                = 61'd867028046814491944;
    localparam L2_OFFSET_K_28_KL_17                = 61'd1002747695140899544;
    localparam L2_OFFSET_K_28_KL_18                = 61'd1075739774913085144;
    localparam L2_OFFSET_K_28_KL_19                = 61'd1106153141484829144;
    localparam L2_OFFSET_K_28_KL_20                = 61'd1115896554116509144;
    localparam L2_OFFSET_K_28_KL_21                = 61'd1118271510945481144;
    localparam L2_OFFSET_K_28_KL_22                = 61'd1118705788765636024;
    localparam L2_OFFSET_K_28_KL_23                = 61'd1118764249241426104;
    localparam L2_OFFSET_K_28_KL_24                = 61'd1118769897596574904;
    localparam L2_OFFSET_K_28_KL_25                = 61'd1118770275834642904;
    localparam L2_OFFSET_K_28_KL_26                = 61'd1118770292529288664;
    localparam L2_OFFSET_K_28_KL_27                = 61'd1118770292978759896;
    localparam L2_OFFSET_K_28_KL_28                = 61'd1118770292985203928;
    localparam L2_OFFSET_K_29_KL_1                 = 61'd4960;
    localparam L2_OFFSET_K_29_KL_2                 = 61'd1155680;
    localparam L2_OFFSET_K_29_KL_3                 = 61'd101038176;
    localparam L2_OFFSET_K_29_KL_4                 = 61'd4595750496;
    localparam L2_OFFSET_K_29_KL_5                 = 61'd125631932256;
    localparam L2_OFFSET_K_29_KL_6                 = 61'd2243765113056;
    localparam L2_OFFSET_K_29_KL_7                 = 61'd27661363282656;
    localparam L2_OFFSET_K_29_KL_8                 = 61'd244800273360096;
    localparam L2_OFFSET_K_29_KL_9                 = 61'd1601918461344096;
    localparam L2_OFFSET_K_29_KL_10                = 61'd7935136671936096;
    localparam L2_OFFSET_K_29_KL_11                = 61'd30344985724800096;
    localparam L2_OFFSET_K_29_KL_12                = 61'd91171718868288096;
    localparam L2_OFFSET_K_29_KL_13                = 61'd218907858469612896;
    localparam L2_OFFSET_K_29_KL_14                = 61'd427707317433316896;
    localparam L2_OFFSET_K_29_KL_15                = 61'd694409147370148896;
    localparam L2_OFFSET_K_29_KL_16                = 61'd961110977306980896;
    localparam L2_OFFSET_K_29_KL_17                = 61'd1169910436270684896;
    localparam L2_OFFSET_K_29_KL_18                = 61'd1297646575872009696;
    localparam L2_OFFSET_K_29_KL_19                = 61'd1358473309015497696;
    localparam L2_OFFSET_K_29_KL_20                = 61'd1380883158068361696;
    localparam L2_OFFSET_K_29_KL_21                = 61'd1387216376278953696;
    localparam L2_OFFSET_K_29_KL_22                = 61'd1388573494466937696;
    localparam L2_OFFSET_K_29_KL_23                = 61'd1388790633377015136;
    localparam L2_OFFSET_K_29_KL_24                = 61'd1388816050975184736;
    localparam L2_OFFSET_K_29_KL_25                = 61'd1388818169108365536;
    localparam L2_OFFSET_K_29_KL_26                = 61'd1388818290144547296;
    localparam L2_OFFSET_K_29_KL_27                = 61'd1388818294639259616;
    localparam L2_OFFSET_K_29_KL_28                = 61'd1388818294739142112;
    localparam L2_OFFSET_K_29_KL_29                = 61'd1388818294740292832;
    localparam L2_OFFSET_K_30_KL_1                 = 61'd496;
    localparam L2_OFFSET_K_30_KL_2                 = 61'd159216;
    localparam L2_OFFSET_K_30_KL_3                 = 61'd17995376;
    localparam L2_OFFSET_K_30_KL_4                 = 61'd1016820336;
    localparam L2_OFFSET_K_30_KL_5                 = 61'd33603484656;
    localparam L2_OFFSET_K_30_KL_6                 = 61'd711406102512;
    localparam L2_OFFSET_K_30_KL_7                 = 61'd10243005416112;
    localparam L2_OFFSET_K_30_KL_8                 = 61'd104651227188912;
    localparam L2_OFFSET_K_30_KL_9                 = 61'd783210321180912;
    localparam L2_OFFSET_K_30_KL_10                = 61'd4402192155804912;
    localparam L2_OFFSET_K_30_KL_11                = 61'd18968594040166512;
    localparam L2_OFFSET_K_30_KL_12                = 61'd63788292145894512;
    localparam L2_OFFSET_K_30_KL_13                = 61'd170235075146998512;
    localparam L2_OFFSET_K_30_KL_14                = 61'd366752212995190512;
    localparam L2_OFFSET_K_30_KL_15                = 61'd650122907303074512;
    localparam L2_OFFSET_K_30_KL_16                = 61'd970165103227272912;
    localparam L2_OFFSET_K_30_KL_17                = 61'd1253535797535156912;
    localparam L2_OFFSET_K_30_KL_18                = 61'd1450052935383348912;
    localparam L2_OFFSET_K_30_KL_19                = 61'd1556499718384452912;
    localparam L2_OFFSET_K_30_KL_20                = 61'd1601319416490180912;
    localparam L2_OFFSET_K_30_KL_21                = 61'd1615885818374542512;
    localparam L2_OFFSET_K_30_KL_22                = 61'd1619504800209166512;
    localparam L2_OFFSET_K_30_KL_23                = 61'd1620183359303158512;
    localparam L2_OFFSET_K_30_KL_24                = 61'd1620277767524931312;
    localparam L2_OFFSET_K_30_KL_25                = 61'd1620287299124244912;
    localparam L2_OFFSET_K_30_KL_26                = 61'd1620287976926862768;
    localparam L2_OFFSET_K_30_KL_27                = 61'd1620288009513527088;
    localparam L2_OFFSET_K_30_KL_28                = 61'd1620288010512352048;
    localparam L2_OFFSET_K_30_KL_29                = 61'd1620288010530188208;
    localparam L2_OFFSET_K_30_KL_30                = 61'd1620288010530346928;
    localparam L2_OFFSET_K_31_KL_1                 = 61'd32;
    localparam L2_OFFSET_K_31_KL_2                 = 61'd15904;
    localparam L2_OFFSET_K_31_KL_3                 = 61'd2476064;
    localparam L2_OFFSET_K_31_KL_4                 = 61'd180837664;
    localparam L2_OFFSET_K_31_KL_5                 = 61'd7422318624;
    localparam L2_OFFSET_K_31_KL_6                 = 61'd189907638816;
    localparam L2_OFFSET_K_31_KL_7                 = 61'd3240019419168;
    localparam L2_OFFSET_K_31_KL_8                 = 61'd38643102583968;
    localparam L2_OFFSET_K_31_KL_9                 = 61'd333668795623968;
    localparam L2_OFFSET_K_31_KL_10                = 61'd2143159712935968;
    localparam L2_OFFSET_K_31_KL_11                = 61'd10466817932571168;
    localparam L2_OFFSET_K_31_KL_12                = 61'd39599621701294368;
    localparam L2_OFFSET_K_31_KL_13                = 61'd118034093386318368;
    localparam L2_OFFSET_K_31_KL_14                = 61'd281798374926478368;
    localparam L2_OFFSET_K_31_KL_15                = 61'd548500204863310368;
    localparam L2_OFFSET_K_31_KL_16                = 61'd888545038032771168;
    localparam L2_OFFSET_K_31_KL_17                = 61'd1228589871202231968;
    localparam L2_OFFSET_K_31_KL_18                = 61'd1495291701139063968;
    localparam L2_OFFSET_K_31_KL_19                = 61'd1659055982679223968;
    localparam L2_OFFSET_K_31_KL_20                = 61'd1737490454364247968;
    localparam L2_OFFSET_K_31_KL_21                = 61'd1766623258132971168;
    localparam L2_OFFSET_K_31_KL_22                = 61'd1774946916352606368;
    localparam L2_OFFSET_K_31_KL_23                = 61'd1776756407269918368;
    localparam L2_OFFSET_K_31_KL_24                = 61'd1777051432962958368;
    localparam L2_OFFSET_K_31_KL_25                = 61'd1777086836046123168;
    localparam L2_OFFSET_K_31_KL_26                = 61'd1777089886157903520;
    localparam L2_OFFSET_K_31_KL_27                = 61'd1777090068643223712;
    localparam L2_OFFSET_K_31_KL_28                = 61'd1777090075884704672;
    localparam L2_OFFSET_K_31_KL_29                = 61'd1777090076063066272;
    localparam L2_OFFSET_K_31_KL_30                = 61'd1777090076065526432;
    localparam L2_OFFSET_K_31_KL_31                = 61'd1777090076065542304;
    localparam L2_OFFSET_K_32_KL_1                 = 61'd1;
    localparam L2_OFFSET_K_32_KL_2                 = 61'd1025;
    localparam L2_OFFSET_K_32_KL_3                 = 61'd247041;
    localparam L2_OFFSET_K_32_KL_4                 = 61'd24848641;
    localparam L2_OFFSET_K_32_KL_5                 = 61'd1317970241;
    localparam L2_OFFSET_K_32_KL_6                 = 61'd41870263617;
    localparam L2_OFFSET_K_32_KL_7                 = 61'd863054204481;
    localparam L2_OFFSET_K_32_KL_8                 = 61'd12192040817217;
    localparam L2_OFFSET_K_32_KL_9                 = 61'd122826675707217;
    localparam L2_OFFSET_K_32_KL_10                = 61'd909561857147217;
    localparam L2_OFFSET_K_32_KL_11                = 61'd5071390966964817;
    localparam L2_OFFSET_K_32_KL_12                = 61'd21718707406235217;
    localparam L2_OFFSET_K_32_KL_13                = 61'd72701114001500817;
    localparam L2_OFFSET_K_32_KL_14                = 61'd193369531978460817;
    localparam L2_OFFSET_K_32_KL_15                = 61'd415621056925820817;
    localparam L2_OFFSET_K_32_KL_16                = 61'd735663252850019217;
    localparam L2_OFFSET_K_32_KL_17                = 61'd1096960888092571317;
    localparam L2_OFFSET_K_32_KL_18                = 61'd1417003084016769717;
    localparam L2_OFFSET_K_32_KL_19                = 61'd1639254608964129717;
    localparam L2_OFFSET_K_32_KL_20                = 61'd1759923026941089717;
    localparam L2_OFFSET_K_32_KL_21                = 61'd1810905433536355317;
    localparam L2_OFFSET_K_32_KL_22                = 61'd1827552749975625717;
    localparam L2_OFFSET_K_32_KL_23                = 61'd1831714579085443317;
    localparam L2_OFFSET_K_32_KL_24                = 61'd1832501314266883317;
    localparam L2_OFFSET_K_32_KL_25                = 61'd1832611948901773317;
    localparam L2_OFFSET_K_32_KL_26                = 61'd1832623277888386053;
    localparam L2_OFFSET_K_32_KL_27                = 61'd1832624099072326917;
    localparam L2_OFFSET_K_32_KL_28                = 61'd1832624139624620293;
    localparam L2_OFFSET_K_32_KL_29                = 61'd1832624140917741893;
    localparam L2_OFFSET_K_32_KL_30                = 61'd1832624140942343493;
    localparam L2_OFFSET_K_32_KL_31                = 61'd1832624140942589509;
    localparam L2_OFFSET_K_32_KL_32                = 61'd1832624140942590533;

    wire [61*32-1:0] offset_flat =
        k == 7'd0 ? {61*32{1'b1}} :
        k == 7'd1 ? {{61*31{1'b1}}, L2_OFFSET_K_1_KL_1} :
        k == 7'd2 ? {{61*30{1'b1}}, L2_OFFSET_K_2_KL_2, L2_OFFSET_K_2_KL_1} :
        k == 7'd3 ? {{61*29{1'b1}}, L2_OFFSET_K_3_KL_3, L2_OFFSET_K_3_KL_2, L2_OFFSET_K_3_KL_1} :
        k == 7'd4 ? {{61*28{1'b1}}, L2_OFFSET_K_4_KL_4, L2_OFFSET_K_4_KL_3, L2_OFFSET_K_4_KL_2, L2_OFFSET_K_4_KL_1} :
        k == 7'd5 ? {{61*27{1'b1}}, L2_OFFSET_K_5_KL_5, L2_OFFSET_K_5_KL_4, L2_OFFSET_K_5_KL_3, L2_OFFSET_K_5_KL_2, L2_OFFSET_K_5_KL_1} :
        k == 7'd6 ? {{61*26{1'b1}}, L2_OFFSET_K_6_KL_6, L2_OFFSET_K_6_KL_5, L2_OFFSET_K_6_KL_4, L2_OFFSET_K_6_KL_3, L2_OFFSET_K_6_KL_2, L2_OFFSET_K_6_KL_1} :
        k == 7'd7 ? {{61*25{1'b1}}, L2_OFFSET_K_7_KL_7, L2_OFFSET_K_7_KL_6, L2_OFFSET_K_7_KL_5, L2_OFFSET_K_7_KL_4, L2_OFFSET_K_7_KL_3, L2_OFFSET_K_7_KL_2, L2_OFFSET_K_7_KL_1} :
        k == 7'd8 ? {{61*24{1'b1}}, L2_OFFSET_K_8_KL_8, L2_OFFSET_K_8_KL_7, L2_OFFSET_K_8_KL_6, L2_OFFSET_K_8_KL_5, L2_OFFSET_K_8_KL_4, L2_OFFSET_K_8_KL_3, L2_OFFSET_K_8_KL_2, L2_OFFSET_K_8_KL_1} :
        k == 7'd9 ? {{61*23{1'b1}}, L2_OFFSET_K_9_KL_9, L2_OFFSET_K_9_KL_8, L2_OFFSET_K_9_KL_7, L2_OFFSET_K_9_KL_6, L2_OFFSET_K_9_KL_5, L2_OFFSET_K_9_KL_4, L2_OFFSET_K_9_KL_3, L2_OFFSET_K_9_KL_2, L2_OFFSET_K_9_KL_1} :
        k == 7'd10 ? {{61*22{1'b1}}, L2_OFFSET_K_10_KL_10, L2_OFFSET_K_10_KL_9, L2_OFFSET_K_10_KL_8, L2_OFFSET_K_10_KL_7, L2_OFFSET_K_10_KL_6, L2_OFFSET_K_10_KL_5, L2_OFFSET_K_10_KL_4, L2_OFFSET_K_10_KL_3, L2_OFFSET_K_10_KL_2, L2_OFFSET_K_10_KL_1} :
        k == 7'd11 ? {{61*21{1'b1}}, L2_OFFSET_K_11_KL_11, L2_OFFSET_K_11_KL_10, L2_OFFSET_K_11_KL_9, L2_OFFSET_K_11_KL_8, L2_OFFSET_K_11_KL_7, L2_OFFSET_K_11_KL_6, L2_OFFSET_K_11_KL_5, L2_OFFSET_K_11_KL_4, L2_OFFSET_K_11_KL_3, L2_OFFSET_K_11_KL_2, L2_OFFSET_K_11_KL_1} :
        k == 7'd12 ? {{61*20{1'b1}}, L2_OFFSET_K_12_KL_12, L2_OFFSET_K_12_KL_11, L2_OFFSET_K_12_KL_10, L2_OFFSET_K_12_KL_9, L2_OFFSET_K_12_KL_8, L2_OFFSET_K_12_KL_7, L2_OFFSET_K_12_KL_6, L2_OFFSET_K_12_KL_5, L2_OFFSET_K_12_KL_4, L2_OFFSET_K_12_KL_3, L2_OFFSET_K_12_KL_2, L2_OFFSET_K_12_KL_1} :
        k == 7'd13 ? {{61*19{1'b1}}, L2_OFFSET_K_13_KL_13, L2_OFFSET_K_13_KL_12, L2_OFFSET_K_13_KL_11, L2_OFFSET_K_13_KL_10, L2_OFFSET_K_13_KL_9, L2_OFFSET_K_13_KL_8, L2_OFFSET_K_13_KL_7, L2_OFFSET_K_13_KL_6, L2_OFFSET_K_13_KL_5, L2_OFFSET_K_13_KL_4, L2_OFFSET_K_13_KL_3, L2_OFFSET_K_13_KL_2, L2_OFFSET_K_13_KL_1} :
        k == 7'd14 ? {{61*18{1'b1}}, L2_OFFSET_K_14_KL_14, L2_OFFSET_K_14_KL_13, L2_OFFSET_K_14_KL_12, L2_OFFSET_K_14_KL_11, L2_OFFSET_K_14_KL_10, L2_OFFSET_K_14_KL_9, L2_OFFSET_K_14_KL_8, L2_OFFSET_K_14_KL_7, L2_OFFSET_K_14_KL_6, L2_OFFSET_K_14_KL_5, L2_OFFSET_K_14_KL_4, L2_OFFSET_K_14_KL_3, L2_OFFSET_K_14_KL_2, L2_OFFSET_K_14_KL_1} :
        k == 7'd15 ? {{61*17{1'b1}}, L2_OFFSET_K_15_KL_15, L2_OFFSET_K_15_KL_14, L2_OFFSET_K_15_KL_13, L2_OFFSET_K_15_KL_12, L2_OFFSET_K_15_KL_11, L2_OFFSET_K_15_KL_10, L2_OFFSET_K_15_KL_9, L2_OFFSET_K_15_KL_8, L2_OFFSET_K_15_KL_7, L2_OFFSET_K_15_KL_6, L2_OFFSET_K_15_KL_5, L2_OFFSET_K_15_KL_4, L2_OFFSET_K_15_KL_3, L2_OFFSET_K_15_KL_2, L2_OFFSET_K_15_KL_1} :
        k == 7'd16 ? {{61*16{1'b1}}, L2_OFFSET_K_16_KL_16, L2_OFFSET_K_16_KL_15, L2_OFFSET_K_16_KL_14, L2_OFFSET_K_16_KL_13, L2_OFFSET_K_16_KL_12, L2_OFFSET_K_16_KL_11, L2_OFFSET_K_16_KL_10, L2_OFFSET_K_16_KL_9, L2_OFFSET_K_16_KL_8, L2_OFFSET_K_16_KL_7, L2_OFFSET_K_16_KL_6, L2_OFFSET_K_16_KL_5, L2_OFFSET_K_16_KL_4, L2_OFFSET_K_16_KL_3, L2_OFFSET_K_16_KL_2, L2_OFFSET_K_16_KL_1} :
        k == 7'd17 ? {{61*15{1'b1}}, L2_OFFSET_K_17_KL_17, L2_OFFSET_K_17_KL_16, L2_OFFSET_K_17_KL_15, L2_OFFSET_K_17_KL_14, L2_OFFSET_K_17_KL_13, L2_OFFSET_K_17_KL_12, L2_OFFSET_K_17_KL_11, L2_OFFSET_K_17_KL_10, L2_OFFSET_K_17_KL_9, L2_OFFSET_K_17_KL_8, L2_OFFSET_K_17_KL_7, L2_OFFSET_K_17_KL_6, L2_OFFSET_K_17_KL_5, L2_OFFSET_K_17_KL_4, L2_OFFSET_K_17_KL_3, L2_OFFSET_K_17_KL_2, L2_OFFSET_K_17_KL_1} :
        k == 7'd18 ? {{61*14{1'b1}}, L2_OFFSET_K_18_KL_18, L2_OFFSET_K_18_KL_17, L2_OFFSET_K_18_KL_16, L2_OFFSET_K_18_KL_15, L2_OFFSET_K_18_KL_14, L2_OFFSET_K_18_KL_13, L2_OFFSET_K_18_KL_12, L2_OFFSET_K_18_KL_11, L2_OFFSET_K_18_KL_10, L2_OFFSET_K_18_KL_9, L2_OFFSET_K_18_KL_8, L2_OFFSET_K_18_KL_7, L2_OFFSET_K_18_KL_6, L2_OFFSET_K_18_KL_5, L2_OFFSET_K_18_KL_4, L2_OFFSET_K_18_KL_3, L2_OFFSET_K_18_KL_2, L2_OFFSET_K_18_KL_1} :
        k == 7'd19 ? {{61*13{1'b1}}, L2_OFFSET_K_19_KL_19, L2_OFFSET_K_19_KL_18, L2_OFFSET_K_19_KL_17, L2_OFFSET_K_19_KL_16, L2_OFFSET_K_19_KL_15, L2_OFFSET_K_19_KL_14, L2_OFFSET_K_19_KL_13, L2_OFFSET_K_19_KL_12, L2_OFFSET_K_19_KL_11, L2_OFFSET_K_19_KL_10, L2_OFFSET_K_19_KL_9, L2_OFFSET_K_19_KL_8, L2_OFFSET_K_19_KL_7, L2_OFFSET_K_19_KL_6, L2_OFFSET_K_19_KL_5, L2_OFFSET_K_19_KL_4, L2_OFFSET_K_19_KL_3, L2_OFFSET_K_19_KL_2, L2_OFFSET_K_19_KL_1} :
        k == 7'd20 ? {{61*12{1'b1}}, L2_OFFSET_K_20_KL_20, L2_OFFSET_K_20_KL_19, L2_OFFSET_K_20_KL_18, L2_OFFSET_K_20_KL_17, L2_OFFSET_K_20_KL_16, L2_OFFSET_K_20_KL_15, L2_OFFSET_K_20_KL_14, L2_OFFSET_K_20_KL_13, L2_OFFSET_K_20_KL_12, L2_OFFSET_K_20_KL_11, L2_OFFSET_K_20_KL_10, L2_OFFSET_K_20_KL_9, L2_OFFSET_K_20_KL_8, L2_OFFSET_K_20_KL_7, L2_OFFSET_K_20_KL_6, L2_OFFSET_K_20_KL_5, L2_OFFSET_K_20_KL_4, L2_OFFSET_K_20_KL_3, L2_OFFSET_K_20_KL_2, L2_OFFSET_K_20_KL_1} :
        k == 7'd21 ? {{61*11{1'b1}}, L2_OFFSET_K_21_KL_21, L2_OFFSET_K_21_KL_20, L2_OFFSET_K_21_KL_19, L2_OFFSET_K_21_KL_18, L2_OFFSET_K_21_KL_17, L2_OFFSET_K_21_KL_16, L2_OFFSET_K_21_KL_15, L2_OFFSET_K_21_KL_14, L2_OFFSET_K_21_KL_13, L2_OFFSET_K_21_KL_12, L2_OFFSET_K_21_KL_11, L2_OFFSET_K_21_KL_10, L2_OFFSET_K_21_KL_9, L2_OFFSET_K_21_KL_8, L2_OFFSET_K_21_KL_7, L2_OFFSET_K_21_KL_6, L2_OFFSET_K_21_KL_5, L2_OFFSET_K_21_KL_4, L2_OFFSET_K_21_KL_3, L2_OFFSET_K_21_KL_2, L2_OFFSET_K_21_KL_1} :
        k == 7'd22 ? {{61*10{1'b1}}, L2_OFFSET_K_22_KL_22, L2_OFFSET_K_22_KL_21, L2_OFFSET_K_22_KL_20, L2_OFFSET_K_22_KL_19, L2_OFFSET_K_22_KL_18, L2_OFFSET_K_22_KL_17, L2_OFFSET_K_22_KL_16, L2_OFFSET_K_22_KL_15, L2_OFFSET_K_22_KL_14, L2_OFFSET_K_22_KL_13, L2_OFFSET_K_22_KL_12, L2_OFFSET_K_22_KL_11, L2_OFFSET_K_22_KL_10, L2_OFFSET_K_22_KL_9, L2_OFFSET_K_22_KL_8, L2_OFFSET_K_22_KL_7, L2_OFFSET_K_22_KL_6, L2_OFFSET_K_22_KL_5, L2_OFFSET_K_22_KL_4, L2_OFFSET_K_22_KL_3, L2_OFFSET_K_22_KL_2, L2_OFFSET_K_22_KL_1} :
        k == 7'd23 ? {{61*9{1'b1}}, L2_OFFSET_K_23_KL_23, L2_OFFSET_K_23_KL_22, L2_OFFSET_K_23_KL_21, L2_OFFSET_K_23_KL_20, L2_OFFSET_K_23_KL_19, L2_OFFSET_K_23_KL_18, L2_OFFSET_K_23_KL_17, L2_OFFSET_K_23_KL_16, L2_OFFSET_K_23_KL_15, L2_OFFSET_K_23_KL_14, L2_OFFSET_K_23_KL_13, L2_OFFSET_K_23_KL_12, L2_OFFSET_K_23_KL_11, L2_OFFSET_K_23_KL_10, L2_OFFSET_K_23_KL_9, L2_OFFSET_K_23_KL_8, L2_OFFSET_K_23_KL_7, L2_OFFSET_K_23_KL_6, L2_OFFSET_K_23_KL_5, L2_OFFSET_K_23_KL_4, L2_OFFSET_K_23_KL_3, L2_OFFSET_K_23_KL_2, L2_OFFSET_K_23_KL_1} :
        k == 7'd24 ? {{61*8{1'b1}}, L2_OFFSET_K_24_KL_24, L2_OFFSET_K_24_KL_23, L2_OFFSET_K_24_KL_22, L2_OFFSET_K_24_KL_21, L2_OFFSET_K_24_KL_20, L2_OFFSET_K_24_KL_19, L2_OFFSET_K_24_KL_18, L2_OFFSET_K_24_KL_17, L2_OFFSET_K_24_KL_16, L2_OFFSET_K_24_KL_15, L2_OFFSET_K_24_KL_14, L2_OFFSET_K_24_KL_13, L2_OFFSET_K_24_KL_12, L2_OFFSET_K_24_KL_11, L2_OFFSET_K_24_KL_10, L2_OFFSET_K_24_KL_9, L2_OFFSET_K_24_KL_8, L2_OFFSET_K_24_KL_7, L2_OFFSET_K_24_KL_6, L2_OFFSET_K_24_KL_5, L2_OFFSET_K_24_KL_4, L2_OFFSET_K_24_KL_3, L2_OFFSET_K_24_KL_2, L2_OFFSET_K_24_KL_1} :
        k == 7'd25 ? {{61*7{1'b1}}, L2_OFFSET_K_25_KL_25, L2_OFFSET_K_25_KL_24, L2_OFFSET_K_25_KL_23, L2_OFFSET_K_25_KL_22, L2_OFFSET_K_25_KL_21, L2_OFFSET_K_25_KL_20, L2_OFFSET_K_25_KL_19, L2_OFFSET_K_25_KL_18, L2_OFFSET_K_25_KL_17, L2_OFFSET_K_25_KL_16, L2_OFFSET_K_25_KL_15, L2_OFFSET_K_25_KL_14, L2_OFFSET_K_25_KL_13, L2_OFFSET_K_25_KL_12, L2_OFFSET_K_25_KL_11, L2_OFFSET_K_25_KL_10, L2_OFFSET_K_25_KL_9, L2_OFFSET_K_25_KL_8, L2_OFFSET_K_25_KL_7, L2_OFFSET_K_25_KL_6, L2_OFFSET_K_25_KL_5, L2_OFFSET_K_25_KL_4, L2_OFFSET_K_25_KL_3, L2_OFFSET_K_25_KL_2, L2_OFFSET_K_25_KL_1} :
        k == 7'd26 ? {{61*6{1'b1}}, L2_OFFSET_K_26_KL_26, L2_OFFSET_K_26_KL_25, L2_OFFSET_K_26_KL_24, L2_OFFSET_K_26_KL_23, L2_OFFSET_K_26_KL_22, L2_OFFSET_K_26_KL_21, L2_OFFSET_K_26_KL_20, L2_OFFSET_K_26_KL_19, L2_OFFSET_K_26_KL_18, L2_OFFSET_K_26_KL_17, L2_OFFSET_K_26_KL_16, L2_OFFSET_K_26_KL_15, L2_OFFSET_K_26_KL_14, L2_OFFSET_K_26_KL_13, L2_OFFSET_K_26_KL_12, L2_OFFSET_K_26_KL_11, L2_OFFSET_K_26_KL_10, L2_OFFSET_K_26_KL_9, L2_OFFSET_K_26_KL_8, L2_OFFSET_K_26_KL_7, L2_OFFSET_K_26_KL_6, L2_OFFSET_K_26_KL_5, L2_OFFSET_K_26_KL_4, L2_OFFSET_K_26_KL_3, L2_OFFSET_K_26_KL_2, L2_OFFSET_K_26_KL_1} :
        k == 7'd27 ? {{61*5{1'b1}}, L2_OFFSET_K_27_KL_27, L2_OFFSET_K_27_KL_26, L2_OFFSET_K_27_KL_25, L2_OFFSET_K_27_KL_24, L2_OFFSET_K_27_KL_23, L2_OFFSET_K_27_KL_22, L2_OFFSET_K_27_KL_21, L2_OFFSET_K_27_KL_20, L2_OFFSET_K_27_KL_19, L2_OFFSET_K_27_KL_18, L2_OFFSET_K_27_KL_17, L2_OFFSET_K_27_KL_16, L2_OFFSET_K_27_KL_15, L2_OFFSET_K_27_KL_14, L2_OFFSET_K_27_KL_13, L2_OFFSET_K_27_KL_12, L2_OFFSET_K_27_KL_11, L2_OFFSET_K_27_KL_10, L2_OFFSET_K_27_KL_9, L2_OFFSET_K_27_KL_8, L2_OFFSET_K_27_KL_7, L2_OFFSET_K_27_KL_6, L2_OFFSET_K_27_KL_5, L2_OFFSET_K_27_KL_4, L2_OFFSET_K_27_KL_3, L2_OFFSET_K_27_KL_2, L2_OFFSET_K_27_KL_1} :
        k == 7'd28 ? {{61*4{1'b1}}, L2_OFFSET_K_28_KL_28, L2_OFFSET_K_28_KL_27, L2_OFFSET_K_28_KL_26, L2_OFFSET_K_28_KL_25, L2_OFFSET_K_28_KL_24, L2_OFFSET_K_28_KL_23, L2_OFFSET_K_28_KL_22, L2_OFFSET_K_28_KL_21, L2_OFFSET_K_28_KL_20, L2_OFFSET_K_28_KL_19, L2_OFFSET_K_28_KL_18, L2_OFFSET_K_28_KL_17, L2_OFFSET_K_28_KL_16, L2_OFFSET_K_28_KL_15, L2_OFFSET_K_28_KL_14, L2_OFFSET_K_28_KL_13, L2_OFFSET_K_28_KL_12, L2_OFFSET_K_28_KL_11, L2_OFFSET_K_28_KL_10, L2_OFFSET_K_28_KL_9, L2_OFFSET_K_28_KL_8, L2_OFFSET_K_28_KL_7, L2_OFFSET_K_28_KL_6, L2_OFFSET_K_28_KL_5, L2_OFFSET_K_28_KL_4, L2_OFFSET_K_28_KL_3, L2_OFFSET_K_28_KL_2, L2_OFFSET_K_28_KL_1} :
        k == 7'd29 ? {{61*3{1'b1}}, L2_OFFSET_K_29_KL_29, L2_OFFSET_K_29_KL_28, L2_OFFSET_K_29_KL_27, L2_OFFSET_K_29_KL_26, L2_OFFSET_K_29_KL_25, L2_OFFSET_K_29_KL_24, L2_OFFSET_K_29_KL_23, L2_OFFSET_K_29_KL_22, L2_OFFSET_K_29_KL_21, L2_OFFSET_K_29_KL_20, L2_OFFSET_K_29_KL_19, L2_OFFSET_K_29_KL_18, L2_OFFSET_K_29_KL_17, L2_OFFSET_K_29_KL_16, L2_OFFSET_K_29_KL_15, L2_OFFSET_K_29_KL_14, L2_OFFSET_K_29_KL_13, L2_OFFSET_K_29_KL_12, L2_OFFSET_K_29_KL_11, L2_OFFSET_K_29_KL_10, L2_OFFSET_K_29_KL_9, L2_OFFSET_K_29_KL_8, L2_OFFSET_K_29_KL_7, L2_OFFSET_K_29_KL_6, L2_OFFSET_K_29_KL_5, L2_OFFSET_K_29_KL_4, L2_OFFSET_K_29_KL_3, L2_OFFSET_K_29_KL_2, L2_OFFSET_K_29_KL_1} :
        k == 7'd30 ? {{61*2{1'b1}}, L2_OFFSET_K_30_KL_30, L2_OFFSET_K_30_KL_29, L2_OFFSET_K_30_KL_28, L2_OFFSET_K_30_KL_27, L2_OFFSET_K_30_KL_26, L2_OFFSET_K_30_KL_25, L2_OFFSET_K_30_KL_24, L2_OFFSET_K_30_KL_23, L2_OFFSET_K_30_KL_22, L2_OFFSET_K_30_KL_21, L2_OFFSET_K_30_KL_20, L2_OFFSET_K_30_KL_19, L2_OFFSET_K_30_KL_18, L2_OFFSET_K_30_KL_17, L2_OFFSET_K_30_KL_16, L2_OFFSET_K_30_KL_15, L2_OFFSET_K_30_KL_14, L2_OFFSET_K_30_KL_13, L2_OFFSET_K_30_KL_12, L2_OFFSET_K_30_KL_11, L2_OFFSET_K_30_KL_10, L2_OFFSET_K_30_KL_9, L2_OFFSET_K_30_KL_8, L2_OFFSET_K_30_KL_7, L2_OFFSET_K_30_KL_6, L2_OFFSET_K_30_KL_5, L2_OFFSET_K_30_KL_4, L2_OFFSET_K_30_KL_3, L2_OFFSET_K_30_KL_2, L2_OFFSET_K_30_KL_1} :
        k == 7'd31 ? {{61*1{1'b1}}, L2_OFFSET_K_31_KL_31, L2_OFFSET_K_31_KL_30, L2_OFFSET_K_31_KL_29, L2_OFFSET_K_31_KL_28, L2_OFFSET_K_31_KL_27, L2_OFFSET_K_31_KL_26, L2_OFFSET_K_31_KL_25, L2_OFFSET_K_31_KL_24, L2_OFFSET_K_31_KL_23, L2_OFFSET_K_31_KL_22, L2_OFFSET_K_31_KL_21, L2_OFFSET_K_31_KL_20, L2_OFFSET_K_31_KL_19, L2_OFFSET_K_31_KL_18, L2_OFFSET_K_31_KL_17, L2_OFFSET_K_31_KL_16, L2_OFFSET_K_31_KL_15, L2_OFFSET_K_31_KL_14, L2_OFFSET_K_31_KL_13, L2_OFFSET_K_31_KL_12, L2_OFFSET_K_31_KL_11, L2_OFFSET_K_31_KL_10, L2_OFFSET_K_31_KL_9, L2_OFFSET_K_31_KL_8, L2_OFFSET_K_31_KL_7, L2_OFFSET_K_31_KL_6, L2_OFFSET_K_31_KL_5, L2_OFFSET_K_31_KL_4, L2_OFFSET_K_31_KL_3, L2_OFFSET_K_31_KL_2, L2_OFFSET_K_31_KL_1} :
        k == 7'd32 ? {L2_OFFSET_K_32_KL_32, L2_OFFSET_K_32_KL_31, L2_OFFSET_K_32_KL_30, L2_OFFSET_K_32_KL_29, L2_OFFSET_K_32_KL_28, L2_OFFSET_K_32_KL_27, L2_OFFSET_K_32_KL_26, L2_OFFSET_K_32_KL_25, L2_OFFSET_K_32_KL_24, L2_OFFSET_K_32_KL_23, L2_OFFSET_K_32_KL_22, L2_OFFSET_K_32_KL_21, L2_OFFSET_K_32_KL_20, L2_OFFSET_K_32_KL_19, L2_OFFSET_K_32_KL_18, L2_OFFSET_K_32_KL_17, L2_OFFSET_K_32_KL_16, L2_OFFSET_K_32_KL_15, L2_OFFSET_K_32_KL_14, L2_OFFSET_K_32_KL_13, L2_OFFSET_K_32_KL_12, L2_OFFSET_K_32_KL_11, L2_OFFSET_K_32_KL_10, L2_OFFSET_K_32_KL_9, L2_OFFSET_K_32_KL_8, L2_OFFSET_K_32_KL_7, L2_OFFSET_K_32_KL_6, L2_OFFSET_K_32_KL_5, L2_OFFSET_K_32_KL_4, L2_OFFSET_K_32_KL_3, L2_OFFSET_K_32_KL_2, L2_OFFSET_K_32_KL_1} :
        {61*32{1'b1}};

    wire [60:0] offset_arr [0:32];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_offset_arr
            assign offset_arr[gi] = offset_flat[61*gi +: 61];
        end
    endgenerate
    assign offset_arr[32] = {61{1'b1}};

    wire [5:0] lo_0 = 6'd0;
    wire [5:0] hi_0 = 6'd32;
    wire [5:0] mid_0 = 6'd16;
    wire cmp_s0 = (val < offset_arr[mid_0]);
    wire [5:0] lo_1 = cmp_s0 ? lo_0 : (mid_0 + 6'd1);
    wire [5:0] hi_1 = cmp_s0 ? mid_0 : hi_0;

    wire [5:0] mid_1 = (lo_1 + hi_1) >> 1;
    wire cmp_s1 = (val < offset_arr[mid_1]);
    wire [5:0] lo_2 = cmp_s1 ? lo_1 : (mid_1 + 6'd1);
    wire [5:0] hi_2 = cmp_s1 ? mid_1 : hi_1;

    wire [5:0] mid_2 = (lo_2 + hi_2) >> 1;
    wire cmp_s2 = (val < offset_arr[mid_2]);
    wire [5:0] lo_3 = cmp_s2 ? lo_2 : (mid_2 + 6'd1);
    wire [5:0] hi_3 = cmp_s2 ? mid_2 : hi_2;

    wire [5:0] mid_3 = (lo_3 + hi_3) >> 1;
    wire cmp_s3 = (val < offset_arr[mid_3]);
    wire [5:0] lo_4 = cmp_s3 ? lo_3 : (mid_3 + 6'd1);
    wire [5:0] hi_4 = cmp_s3 ? mid_3 : hi_3;

    wire [5:0] mid_4 = (lo_4 + hi_4) >> 1;
    wire cmp_s4 = (val < offset_arr[mid_4]);
    wire [5:0] lo_5 = cmp_s4 ? lo_4 : (mid_4 + 6'd1);
    wire [5:0] hi_5 = cmp_s4 ? mid_4 : hi_4;

    wire [5:0] mid_5 = (lo_5 + hi_5) >> 1;
    wire cmp_s5 = (val < offset_arr[mid_5]);
    wire [5:0] kl_final = cmp_s5 ? mid_5 : (mid_5 + 6'd1);

    wire [5:0] kl_comb = kl_final;
    wire [5:0] kr_comb = k - kl_final;

    wire [60:0] offset_prev = (kl_final > 6'd0) ? offset_arr[kl_final - 6'd1] : 61'd0;
    wire [60:0] vali_comb = val - offset_prev;

    reg [5:0] kl_r, kr_r;
    reg [60:0] vali_r;
    reg out_vld_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kl_r <= 6'd0;
            kr_r <= 6'd0;
            vali_r <= 61'd0;
            out_vld_r <= 1'b0;
        end else begin
            out_vld_r <= in_vld;
            if (in_vld) begin
                kl_r <= kl_comb;
                kr_r <= kr_comb;
                vali_r <= vali_comb;
            end
        end
    end

    assign kl = kl_r;
    assign kr = kr_r;
    assign out_vld = out_vld_r;

    wire [60:0] vali = vali_r;

    wire [62:0] rec_weight_sel = kr_r == 6'd0 ? {L2_REC_WEIGHT_KR_0} :
                        kr_r == 6'd1 ? {{5{1'b0}}, L2_REC_WEIGHT_KR_1} :
                        kr_r == 6'd2 ? {{9{1'b0}}, L2_REC_WEIGHT_KR_2} :
                        kr_r == 6'd3 ? {{13{1'b0}}, L2_REC_WEIGHT_KR_3} :
                        kr_r == 6'd4 ? {{16{1'b0}}, L2_REC_WEIGHT_KR_4} :
                        kr_r == 6'd5 ? {{18{1'b0}}, L2_REC_WEIGHT_KR_5} :
                        kr_r == 6'd6 ? {{20{1'b0}}, L2_REC_WEIGHT_KR_6} :
                        kr_r == 6'd7 ? {{22{1'b0}}, L2_REC_WEIGHT_KR_7} :
                        kr_r == 6'd8 ? {{24{1'b0}}, L2_REC_WEIGHT_KR_8} :
                        kr_r == 6'd9 ? {{25{1'b0}}, L2_REC_WEIGHT_KR_9} :
                        kr_r == 6'd10 ? {{26{1'b0}}, L2_REC_WEIGHT_KR_10} :
                        kr_r == 6'd11 ? {{27{1'b0}}, L2_REC_WEIGHT_KR_11} :
                        kr_r == 6'd12 ? {{28{1'b0}}, L2_REC_WEIGHT_KR_12} :
                        kr_r == 6'd13 ? {{29{1'b0}}, L2_REC_WEIGHT_KR_13} :
                        kr_r == 6'd14 ? {{29{1'b0}}, L2_REC_WEIGHT_KR_14} :
                        kr_r == 6'd15 ? {{30{1'b0}}, L2_REC_WEIGHT_KR_15} :
                        kr_r == 6'd16 ? {{30{1'b0}}, L2_REC_WEIGHT_KR_16} :
                        kr_r == 6'd17 ? {{30{1'b0}}, L2_REC_WEIGHT_KR_15} :
                        kr_r == 6'd18 ? {{29{1'b0}}, L2_REC_WEIGHT_KR_14} :
                        kr_r == 6'd19 ? {{29{1'b0}}, L2_REC_WEIGHT_KR_13} :
                        kr_r == 6'd20 ? {{28{1'b0}}, L2_REC_WEIGHT_KR_12} :
                        kr_r == 6'd21 ? {{27{1'b0}}, L2_REC_WEIGHT_KR_11} :
                        kr_r == 6'd22 ? {{26{1'b0}}, L2_REC_WEIGHT_KR_10} :
                        kr_r == 6'd23 ? {{25{1'b0}}, L2_REC_WEIGHT_KR_9} :
                        kr_r == 6'd24 ? {{24{1'b0}}, L2_REC_WEIGHT_KR_8} :
                        kr_r == 6'd25 ? {{22{1'b0}}, L2_REC_WEIGHT_KR_7} :
                        kr_r == 6'd26 ? {{20{1'b0}}, L2_REC_WEIGHT_KR_6} :
                        kr_r == 6'd27 ? {{18{1'b0}}, L2_REC_WEIGHT_KR_5} :
                        kr_r == 6'd28 ? {{16{1'b0}}, L2_REC_WEIGHT_KR_4} :
                        kr_r == 6'd29 ? {{13{1'b0}}, L2_REC_WEIGHT_KR_3} :
                        kr_r == 6'd30 ? {{9{1'b0}}, L2_REC_WEIGHT_KR_2} :
                        kr_r == 6'd31 ? {{5{1'b0}}, L2_REC_WEIGHT_KR_1} :
                        {L2_REC_WEIGHT_KR_0};

    wire [30:0] vali_hi = vali[60:30];
    wire [30:0] rec_hi  = rec_weight_sel[62:32];
    wire [31:0] rec_lo  = rec_weight_sel[31:0];

    wire [91:0] prod_a = vali    * rec_hi;
    wire [62:0] prod_b = vali_hi * rec_lo;

    wire [65:0] contrib_a = prod_a[91:26];
    wire [34:0] contrib_b = prod_b[62:28];
    wire [65:0] sum_guard = contrib_a + {31'd0, contrib_b};
    wire [29:0] val_l_raw = sum_guard[33:4];

    wire [29:0] weight_sel = kr_r == 6'd0 ? L2_WEIGHT_KR_0 :
                        kr_r == 6'd1 ? L2_WEIGHT_KR_1 :
                        kr_r == 6'd2 ? L2_WEIGHT_KR_2 :
                        kr_r == 6'd3 ? L2_WEIGHT_KR_3 :
                        kr_r == 6'd4 ? L2_WEIGHT_KR_4 :
                        kr_r == 6'd5 ? L2_WEIGHT_KR_5 :
                        kr_r == 6'd6 ? L2_WEIGHT_KR_6 :
                        kr_r == 6'd7 ? L2_WEIGHT_KR_7 :
                        kr_r == 6'd8 ? L2_WEIGHT_KR_8 :
                        kr_r == 6'd9 ? L2_WEIGHT_KR_9 :
                        kr_r == 6'd10 ? L2_WEIGHT_KR_10 :
                        kr_r == 6'd11 ? L2_WEIGHT_KR_11 :
                        kr_r == 6'd12 ? L2_WEIGHT_KR_12 :
                        kr_r == 6'd13 ? L2_WEIGHT_KR_13 :
                        kr_r == 6'd14 ? L2_WEIGHT_KR_14 :
                        kr_r == 6'd15 ? L2_WEIGHT_KR_15 :
                        kr_r == 6'd16 ? L2_WEIGHT_KR_16 :
                        kr_r == 6'd17 ? L2_WEIGHT_KR_15 :
                        kr_r == 6'd18 ? L2_WEIGHT_KR_14 :
                        kr_r == 6'd19 ? L2_WEIGHT_KR_13 :
                        kr_r == 6'd20 ? L2_WEIGHT_KR_12 :
                        kr_r == 6'd21 ? L2_WEIGHT_KR_11 :
                        kr_r == 6'd22 ? L2_WEIGHT_KR_10 :
                        kr_r == 6'd23 ? L2_WEIGHT_KR_9 :
                        kr_r == 6'd24 ? L2_WEIGHT_KR_8 :
                        kr_r == 6'd25 ? L2_WEIGHT_KR_7 :
                        kr_r == 6'd26 ? L2_WEIGHT_KR_6 :
                        kr_r == 6'd27 ? L2_WEIGHT_KR_5 :
                        kr_r == 6'd28 ? L2_WEIGHT_KR_4 :
                        kr_r == 6'd29 ? L2_WEIGHT_KR_3 :
                        kr_r == 6'd30 ? L2_WEIGHT_KR_2 :
                        kr_r == 6'd31 ? L2_WEIGHT_KR_1 :
                        L2_WEIGHT_KR_0;

    wire [59:0] val_l_times_w = val_l_raw * weight_sel;
    wire [60:0] val_r_raw = vali - {1'b0, val_l_times_w};

    wire overflow = (val_r_raw[29:0] >= weight_sel) & (val_r_raw[60:30] == 31'd0);

    assign val_l = overflow ? (val_l_raw + 30'd1) : val_l_raw;
    assign val_r = overflow ? (val_r_raw[29:0] - weight_sel) : val_r_raw[29:0];
endmodule