// SPDX-License-Identifier: Apache-2.0
module L6_CELL (
    input wire [31:0] high,
    input wire [31:0] low,
    input wire [5:0] num_one_high,
    input wire [5:0] num_one_low,
    output wire [63:0] out_data,
    output wire [6:0] out_num_one
);

    localparam L6_WEIGHT_KR_0                 = 1'd1;
    localparam L6_WEIGHT_KR_1                 = 6'd32;
    localparam L6_WEIGHT_KR_2                 = 9'd496;
    localparam L6_WEIGHT_KR_3                 = 13'd4960;
    localparam L6_WEIGHT_KR_4                 = 16'd35960;
    localparam L6_WEIGHT_KR_5                 = 18'd201376;
    localparam L6_WEIGHT_KR_6                 = 20'd906192;
    localparam L6_WEIGHT_KR_7                 = 22'd3365856;
    localparam L6_WEIGHT_KR_8                 = 24'd10518300;
    localparam L6_WEIGHT_KR_9                 = 25'd28048800;
    localparam L6_WEIGHT_KR_10                = 26'd64512240;
    localparam L6_WEIGHT_KR_11                = 27'd129024480;
    localparam L6_WEIGHT_KR_12                = 28'd225792840;
    localparam L6_WEIGHT_KR_13                = 29'd347373600;
    localparam L6_WEIGHT_KR_14                = 29'd471435600;
    localparam L6_WEIGHT_KR_15                = 30'd565722720;
    localparam L6_WEIGHT_KR_16                = 30'd601080390;

    localparam L6_OFFSET_K_1_KL_1                  = 6'd32;
    localparam L6_OFFSET_K_2_KL_1                  = 9'd496;
    localparam L6_OFFSET_K_2_KL_2                  = 11'd1520;
    localparam L6_OFFSET_K_3_KL_1                  = 13'd4960;
    localparam L6_OFFSET_K_3_KL_2                  = 15'd20832;
    localparam L6_OFFSET_K_3_KL_3                  = 16'd36704;
    localparam L6_OFFSET_K_4_KL_1                  = 16'd35960;
    localparam L6_OFFSET_K_4_KL_2                  = 18'd194680;
    localparam L6_OFFSET_K_4_KL_3                  = 19'd440696;
    localparam L6_OFFSET_K_4_KL_4                  = 20'd599416;
    localparam L6_OFFSET_K_5_KL_1                  = 18'd201376;
    localparam L6_OFFSET_K_5_KL_2                  = 21'd1352096;
    localparam L6_OFFSET_K_5_KL_3                  = 22'd3812256;
    localparam L6_OFFSET_K_5_KL_4                  = 23'd6272416;
    localparam L6_OFFSET_K_5_KL_5                  = 23'd7423136;
    localparam L6_OFFSET_K_6_KL_1                  = 20'd906192;
    localparam L6_OFFSET_K_6_KL_2                  = 23'd7350224;
    localparam L6_OFFSET_K_6_KL_3                  = 25'd25186384;
    localparam L6_OFFSET_K_6_KL_4                  = 26'd49787984;
    localparam L6_OFFSET_K_6_KL_5                  = 27'd67624144;
    localparam L6_OFFSET_K_6_KL_6                  = 27'd74068176;
    localparam L6_OFFSET_K_7_KL_1                  = 22'd3365856;
    localparam L6_OFFSET_K_7_KL_2                  = 25'd32364000;
    localparam L6_OFFSET_K_7_KL_3                  = 27'd132246496;
    localparam L6_OFFSET_K_7_KL_4                  = 29'd310608096;
    localparam L6_OFFSET_K_7_KL_5                  = 29'd488969696;
    localparam L6_OFFSET_K_7_KL_6                  = 30'd588852192;
    localparam L6_OFFSET_K_7_KL_7                  = 30'd617850336;
    localparam L6_OFFSET_K_8_KL_1                  = 24'd10518300;
    localparam L6_OFFSET_K_8_KL_2                  = 27'd118225692;
    localparam L6_OFFSET_K_8_KL_3                  = 30'd567696924;
    localparam L6_OFFSET_K_8_KL_4                  = 31'd1566521884;
    localparam L6_OFFSET_K_8_KL_5                  = 32'd2859643484;
    localparam L6_OFFSET_K_8_KL_6                  = 32'd3858468444;
    localparam L6_OFFSET_K_8_KL_7                  = 33'd4307939676;
    localparam L6_OFFSET_K_8_KL_8                  = 33'd4415647068;
    localparam L6_OFFSET_K_9_KL_1                  = 25'd28048800;
    localparam L6_OFFSET_K_9_KL_2                  = 29'd364634400;
    localparam L6_OFFSET_K_9_KL_3                  = 31'd2034098976;
    localparam L6_OFFSET_K_9_KL_4                  = 33'd6528811296;
    localparam L6_OFFSET_K_9_KL_5                  = 34'd13770292256;
    localparam L6_OFFSET_K_9_KL_6                  = 35'd21011773216;
    localparam L6_OFFSET_K_9_KL_7                  = 35'd25506485536;
    localparam L6_OFFSET_K_9_KL_8                  = 35'd27175950112;
    localparam L6_OFFSET_K_9_KL_9                  = 35'd27512535712;
    localparam L6_OFFSET_K_10_KL_1                 = 26'd64512240;
    localparam L6_OFFSET_K_10_KL_2                 = 30'd962073840;
    localparam L6_OFFSET_K_10_KL_3                 = 33'd6179150640;
    localparam L6_OFFSET_K_10_KL_4                 = 35'd22873796400;
    localparam L6_OFFSET_K_10_KL_5                 = 36'd55460460720;
    localparam L6_OFFSET_K_10_KL_6                 = 37'd96012754096;
    localparam L6_OFFSET_K_10_KL_7                 = 37'd128599418416;
    localparam L6_OFFSET_K_10_KL_8                 = 38'd145294064176;
    localparam L6_OFFSET_K_10_KL_9                 = 38'd150511140976;
    localparam L6_OFFSET_K_10_KL_10                = 38'd151408702576;
    localparam L6_OFFSET_K_11_KL_1                 = 27'd129024480;
    localparam L6_OFFSET_K_11_KL_2                 = 32'd2193416160;
    localparam L6_OFFSET_K_11_KL_3                 = 34'd16105620960;
    localparam L6_OFFSET_K_11_KL_4                 = 36'd68276388960;
    localparam L6_OFFSET_K_11_KL_5                 = 38'd189312570720;
    localparam L6_OFFSET_K_11_KL_6                 = 39'd371797890912;
    localparam L6_OFFSET_K_11_KL_7                 = 40'd554283211104;
    localparam L6_OFFSET_K_11_KL_8                 = 40'd675319392864;
    localparam L6_OFFSET_K_11_KL_9                 = 40'd727490160864;
    localparam L6_OFFSET_K_11_KL_10                = 40'd741402365664;
    localparam L6_OFFSET_K_11_KL_11                = 40'd743466757344;
    localparam L6_OFFSET_K_12_KL_1                 = 28'd225792840;
    localparam L6_OFFSET_K_12_KL_2                 = 33'd4354576200;
    localparam L6_OFFSET_K_12_KL_3                 = 36'd36352647240;
    localparam L6_OFFSET_K_12_KL_4                 = 38'd175474695240;
    localparam L6_OFFSET_K_12_KL_5                 = 40'd553712763240;
    localparam L6_OFFSET_K_12_KL_6                 = 41'd1231515381096;
    localparam L6_OFFSET_K_12_KL_7                 = 41'd2052699321960;
    localparam L6_OFFSET_K_12_KL_8                 = 42'd2730501939816;
    localparam L6_OFFSET_K_12_KL_9                 = 42'd3108740007816;
    localparam L6_OFFSET_K_12_KL_10                = 42'd3247862055816;
    localparam L6_OFFSET_K_12_KL_11                = 42'd3279860126856;
    localparam L6_OFFSET_K_12_KL_12                = 42'd3283988910216;
    localparam L6_OFFSET_K_13_KL_1                 = 29'd347373600;
    localparam L6_OFFSET_K_13_KL_2                 = 33'd7572744480;
    localparam L6_OFFSET_K_13_KL_3                 = 37'd71568886560;
    localparam L6_OFFSET_K_13_KL_4                 = 39'd391549596960;
    localparam L6_OFFSET_K_13_KL_5                 = 41'd1400184444960;
    localparam L6_OFFSET_K_13_KL_6                 = 42'd3518317625760;
    localparam L6_OFFSET_K_13_KL_7                 = 43'd6568429406112;
    localparam L6_OFFSET_K_13_KL_8                 = 44'd9618541186464;
    localparam L6_OFFSET_K_13_KL_9                 = 44'd11736674367264;
    localparam L6_OFFSET_K_13_KL_10                = 44'd12745309215264;
    localparam L6_OFFSET_K_13_KL_11                = 44'd13065289925664;
    localparam L6_OFFSET_K_13_KL_12                = 44'd13129286067744;
    localparam L6_OFFSET_K_13_KL_13                = 44'd13136511438624;
    localparam L6_OFFSET_K_14_KL_1                 = 29'd471435600;
    localparam L6_OFFSET_K_14_KL_2                 = 34'd11587390800;
    localparam L6_OFFSET_K_14_KL_3                 = 37'd123580639440;
    localparam L6_OFFSET_K_14_KL_4                 = 40'd763542060240;
    localparam L6_OFFSET_K_14_KL_5                 = 42'd3083402210640;
    localparam L6_OFFSET_K_14_KL_6                 = 43'd8731757359440;
    localparam L6_OFFSET_K_14_KL_7                 = 45'd18263356673040;
    localparam L6_OFFSET_K_14_KL_8                 = 45'd29592343285776;
    localparam L6_OFFSET_K_14_KL_9                 = 46'd39123942599376;
    localparam L6_OFFSET_K_14_KL_10                = 46'd44772297748176;
    localparam L6_OFFSET_K_14_KL_11                = 46'd47092157898576;
    localparam L6_OFFSET_K_14_KL_12                = 46'd47732119319376;
    localparam L6_OFFSET_K_14_KL_13                = 46'd47844112568016;
    localparam L6_OFFSET_K_14_KL_14                = 46'd47855228523216;
    localparam L6_OFFSET_K_15_KL_1                 = 30'd565722720;
    localparam L6_OFFSET_K_15_KL_2                 = 34'd15651661920;
    localparam L6_OFFSET_K_15_KL_3                 = 38'd187948967520;
    localparam L6_OFFSET_K_15_KL_4                 = 41'd1307881453920;
    localparam L6_OFFSET_K_15_KL_5                 = 43'd5947601754720;
    localparam L6_OFFSET_K_15_KL_6                 = 45'd18938818596960;
    localparam L6_OFFSET_K_15_KL_7                 = 46'd44356416766560;
    localparam L6_OFFSET_K_15_KL_8                 = 47'd79759499931360;
    localparam L6_OFFSET_K_15_KL_9                 = 47'd115162583096160;
    localparam L6_OFFSET_K_15_KL_10                = 47'd140580181265760;
    localparam L6_OFFSET_K_15_KL_11                = 48'd153571398108000;
    localparam L6_OFFSET_K_15_KL_12                = 48'd158211118408800;
    localparam L6_OFFSET_K_15_KL_13                = 48'd159331050895200;
    localparam L6_OFFSET_K_15_KL_14                = 48'd159503348200800;
    localparam L6_OFFSET_K_15_KL_15                = 48'd159518434140000;
    localparam L6_OFFSET_K_16_KL_1                 = 30'd601080390;
    localparam L6_OFFSET_K_16_KL_2                 = 35'd18704207430;
    localparam L6_OFFSET_K_16_KL_3                 = 38'd252536265030;
    localparam L6_OFFSET_K_16_KL_4                 = 41'd1975509321030;
    localparam L6_OFFSET_K_16_KL_5                 = 44'd10095019847430;
    localparam L6_OFFSET_K_16_KL_6                 = 46'd36077453531910;
    localparam L6_OFFSET_K_16_KL_7                 = 47'd94537929321990;
    localparam L6_OFFSET_K_16_KL_8                 = 48'd188946151094790;
    localparam L6_OFFSET_K_16_KL_9                 = 49'd299580785984790;
    localparam L6_OFFSET_K_16_KL_10                = 49'd393989007757590;
    localparam L6_OFFSET_K_16_KL_11                = 49'd452449483547670;
    localparam L6_OFFSET_K_16_KL_12                = 49'd478431917232150;
    localparam L6_OFFSET_K_16_KL_13                = 49'd486551427758550;
    localparam L6_OFFSET_K_16_KL_14                = 49'd488274400814550;
    localparam L6_OFFSET_K_16_KL_15                = 49'd488508232872150;
    localparam L6_OFFSET_K_16_KL_16                = 49'd488526335999190;
    localparam L6_OFFSET_K_17_KL_1                 = 30'd565722720;
    localparam L6_OFFSET_K_17_KL_2                 = 35'd19800295200;
    localparam L6_OFFSET_K_17_KL_3                 = 39'd300398764320;
    localparam L6_OFFSET_K_17_KL_4                 = 42'd2638719340320;
    localparam L6_OFFSET_K_17_KL_5                 = 44'd15130273996320;
    localparam L6_OFFSET_K_17_KL_6                 = 46'd60599532944160;
    localparam L6_OFFSET_K_17_KL_7                 = 48'd177520484524320;
    localparam L6_OFFSET_K_17_KL_8                 = 49'd394659394601760;
    localparam L6_OFFSET_K_17_KL_9                 = 50'd689685087641760;
    localparam L6_OFFSET_K_17_KL_10                = 50'd984710780681760;
    localparam L6_OFFSET_K_17_KL_11                = 51'd1201849690759200;
    localparam L6_OFFSET_K_17_KL_12                = 51'd1318770642339360;
    localparam L6_OFFSET_K_17_KL_13                = 51'd1364239901287200;
    localparam L6_OFFSET_K_17_KL_14                = 51'd1376731455943200;
    localparam L6_OFFSET_K_17_KL_15                = 51'd1379069776519200;
    localparam L6_OFFSET_K_17_KL_16                = 51'd1379350374988320;
    localparam L6_OFFSET_K_17_KL_17                = 51'd1379369609560800;
    localparam L6_OFFSET_K_18_KL_1                 = 29'd471435600;
    localparam L6_OFFSET_K_18_KL_2                 = 35'd18574562640;
    localparam L6_OFFSET_K_18_KL_3                 = 39'd316710436080;
    localparam L6_OFFSET_K_18_KL_4                 = 42'd3122695127280;
    localparam L6_OFFSET_K_18_KL_5                 = 45'd20075519303280;
    localparam L6_OFFSET_K_18_KL_6                 = 47'd90028225376880;
    localparam L6_OFFSET_K_18_KL_7                 = 49'd294639890642160;
    localparam L6_OFFSET_K_18_KL_8                 = 50'd728917710797040;
    localparam L6_OFFSET_K_18_KL_9                 = 51'd1407476804789040;
    localparam L6_OFFSET_K_18_KL_10                = 51'd2194211986229040;
    localparam L6_OFFSET_K_18_KL_11                = 52'd2872771080221040;
    localparam L6_OFFSET_K_18_KL_12                = 52'd3307048900375920;
    localparam L6_OFFSET_K_18_KL_13                = 52'd3511660565641200;
    localparam L6_OFFSET_K_18_KL_14                = 52'd3581613271714800;
    localparam L6_OFFSET_K_18_KL_15                = 52'd3598566095890800;
    localparam L6_OFFSET_K_18_KL_16                = 52'd3601372080582000;
    localparam L6_OFFSET_K_18_KL_17                = 52'd3601670216455440;
    localparam L6_OFFSET_K_18_KL_18                = 52'd3601688319582480;
    localparam L6_OFFSET_K_19_KL_1                 = 29'd347373600;
    localparam L6_OFFSET_K_19_KL_2                 = 34'd15433312800;
    localparam L6_OFFSET_K_19_KL_3                 = 39'd296031781920;
    localparam L6_OFFSET_K_19_KL_4                 = 42'd3277390516320;
    localparam L6_OFFSET_K_19_KL_5                 = 45'd23620779527520;
    localparam L6_OFFSET_K_19_KL_6                 = 47'd118556594913120;
    localparam L6_OFFSET_K_19_KL_7                 = 49'd433343772244320;
    localparam L6_OFFSET_K_19_KL_8                 = 51'd1193329957515360;
    localparam L6_OFFSET_K_19_KL_9                 = 52'd2550448145499360;
    localparam L6_OFFSET_K_19_KL_10                = 52'd4359939062811360;
    localparam L6_OFFSET_K_19_KL_11                = 53'd6169429980123360;
    localparam L6_OFFSET_K_19_KL_12                = 53'd7526548168107360;
    localparam L6_OFFSET_K_19_KL_13                = 53'd8286534353378400;
    localparam L6_OFFSET_K_19_KL_14                = 53'd8601321530709600;
    localparam L6_OFFSET_K_19_KL_15                = 53'd8696257346095200;
    localparam L6_OFFSET_K_19_KL_16                = 53'd8716600735106400;
    localparam L6_OFFSET_K_19_KL_17                = 53'd8719582093840800;
    localparam L6_OFFSET_K_19_KL_18                = 53'd8719862692309920;
    localparam L6_OFFSET_K_19_KL_19                = 53'd8719877778249120;
    localparam L6_OFFSET_K_20_KL_1                 = 28'd225792840;
    localparam L6_OFFSET_K_20_KL_2                 = 34'd11341748040;
    localparam L6_OFFSET_K_20_KL_3                 = 38'd245173805640;
    localparam L6_OFFSET_K_20_KL_4                 = 42'd3051158496840;
    localparam L6_OFFSET_K_20_KL_5                 = 45'd24666009321240;
    localparam L6_OFFSET_K_20_KL_6                 = 47'd138588987783960;
    localparam L6_OFFSET_K_20_KL_7                 = 50'd565800157019160;
    localparam L6_OFFSET_K_20_KL_8                 = 51'd1735009672820760;
    localparam L6_OFFSET_K_20_KL_9                 = 52'd4109966501792760;
    localparam L6_OFFSET_K_20_KL_10                = 53'd7728948336416760;
    localparam L6_OFFSET_K_20_KL_11                = 54'd11890777446234360;
    localparam L6_OFFSET_K_20_KL_12                = 54'd15509759280858360;
    localparam L6_OFFSET_K_20_KL_13                = 54'd17884716109830360;
    localparam L6_OFFSET_K_20_KL_14                = 55'd19053925625631960;
    localparam L6_OFFSET_K_20_KL_15                = 55'd19481136794867160;
    localparam L6_OFFSET_K_20_KL_16                = 55'd19595059773329880;
    localparam L6_OFFSET_K_20_KL_17                = 55'd19616674624154280;
    localparam L6_OFFSET_K_20_KL_18                = 55'd19619480608845480;
    localparam L6_OFFSET_K_20_KL_19                = 55'd19619714440903080;
    localparam L6_OFFSET_K_20_KL_20                = 55'd19619725556858280;
    localparam L6_OFFSET_K_21_KL_1                 = 27'd129024480;
    localparam L6_OFFSET_K_21_KL_2                 = 33'd7354395360;
    localparam L6_OFFSET_K_21_KL_3                 = 38'd179651700960;
    localparam L6_OFFSET_K_21_KL_4                 = 42'd2517972276960;
    localparam L6_OFFSET_K_21_KL_5                 = 45'd22861361288160;
    localparam L6_OFFSET_K_21_KL_6                 = 48'd143904525904800;
    localparam L6_OFFSET_K_21_KL_7                 = 50'd656557928987040;
    localparam L6_OFFSET_K_21_KL_8                 = 51'd2243342271860640;
    localparam L6_OFFSET_K_21_KL_9                 = 53'd5897122008740640;
    localparam L6_OFFSET_K_21_KL_10                = 54'd12230340219332640;
    localparam L6_OFFSET_K_21_KL_11                = 55'd20553998438967840;
    localparam L6_OFFSET_K_21_KL_12                = 55'd28877656658603040;
    localparam L6_OFFSET_K_21_KL_13                = 55'd35210874869195040;
    localparam L6_OFFSET_K_21_KL_14                = 56'd38864654606075040;
    localparam L6_OFFSET_K_21_KL_15                = 56'd40451438948948640;
    localparam L6_OFFSET_K_21_KL_16                = 56'd40964092352030880;
    localparam L6_OFFSET_K_21_KL_17                = 56'd41085135516647520;
    localparam L6_OFFSET_K_21_KL_18                = 56'd41105478905658720;
    localparam L6_OFFSET_K_21_KL_19                = 56'd41107817226234720;
    localparam L6_OFFSET_K_21_KL_20                = 56'd41107989523540320;
    localparam L6_OFFSET_K_21_KL_21                = 56'd41107996748911200;
    localparam L6_OFFSET_K_22_KL_1                 = 26'd64512240;
    localparam L6_OFFSET_K_22_KL_2                 = 32'd4193295600;
    localparam L6_OFFSET_K_22_KL_3                 = 37'd116186544240;
    localparam L6_OFFSET_K_22_KL_4                 = 41'd1839159600240;
    localparam L6_OFFSET_K_22_KL_5                 = 45'd18791983776240;
    localparam L6_OFFSET_K_22_KL_6                 = 47'd132714962238960;
    localparam L6_OFFSET_K_22_KL_7                 = 50'd677409203013840;
    localparam L6_OFFSET_K_22_KL_8                 = 52'd2581550414462160;
    localparam L6_OFFSET_K_22_KL_9                 = 53'd7540251485942160;
    localparam L6_OFFSET_K_22_KL_10                = 54'd17283664117622160;
    localparam L6_OFFSET_K_22_KL_11                = 55'd31850066001983760;
    localparam L6_OFFSET_K_22_KL_12                = 56'd48497382441254160;
    localparam L6_OFFSET_K_22_KL_13                = 56'd63063784325615760;
    localparam L6_OFFSET_K_22_KL_14                = 57'd72807196957295760;
    localparam L6_OFFSET_K_22_KL_15                = 57'd77765898028775760;
    localparam L6_OFFSET_K_22_KL_16                = 57'd79670039240224080;
    localparam L6_OFFSET_K_22_KL_17                = 57'd80214733480998960;
    localparam L6_OFFSET_K_22_KL_18                = 57'd80328656459461680;
    localparam L6_OFFSET_K_22_KL_19                = 57'd80345609283637680;
    localparam L6_OFFSET_K_22_KL_20                = 57'd80347332256693680;
    localparam L6_OFFSET_K_22_KL_21                = 57'd80347444249942320;
    localparam L6_OFFSET_K_22_KL_22                = 57'd80347448378725680;
    localparam L6_OFFSET_K_23_KL_1                 = 25'd28048800;
    localparam L6_OFFSET_K_23_KL_2                 = 31'd2092440480;
    localparam L6_OFFSET_K_23_KL_3                 = 36'd66088582560;
    localparam L6_OFFSET_K_23_KL_4                 = 41'd1186021068960;
    localparam L6_OFFSET_K_23_KL_5                 = 44'd13677575724960;
    localparam L6_OFFSET_K_23_KL_6                 = 47'd108613391110560;
    localparam L6_OFFSET_K_23_KL_7                 = 50'd621266794192800;
    localparam L6_OFFSET_K_23_KL_8                 = 52'd2644416831356640;
    localparam L6_OFFSET_K_23_KL_9                 = 53'd8594858117132640;
    localparam L6_OFFSET_K_23_KL_10                = 55'd21818060974412640;
    localparam L6_OFFSET_K_23_KL_11                = 56'd44227910027276640;
    localparam L6_OFFSET_K_23_KL_12                = 57'd73360713795999840;
    localparam L6_OFFSET_K_23_KL_13                = 57'd102493517564723040;
    localparam L6_OFFSET_K_23_KL_14                = 57'd124903366617587040;
    localparam L6_OFFSET_K_23_KL_15                = 57'd138126569474867040;
    localparam L6_OFFSET_K_23_KL_16                = 57'd144077010760643040;
    localparam L6_OFFSET_K_23_KL_17                = 58'd146100160797806880;
    localparam L6_OFFSET_K_23_KL_18                = 58'd146612814200889120;
    localparam L6_OFFSET_K_23_KL_19                = 58'd146707750016274720;
    localparam L6_OFFSET_K_23_KL_20                = 58'd146720241570930720;
    localparam L6_OFFSET_K_23_KL_21                = 58'd146721361503417120;
    localparam L6_OFFSET_K_23_KL_22                = 58'd146721425499559200;
    localparam L6_OFFSET_K_23_KL_23                = 58'd146721427563950880;
    localparam L6_OFFSET_K_24_KL_1                 = 24'd10518300;
    localparam L6_OFFSET_K_24_KL_2                 = 30'd908079900;
    localparam L6_OFFSET_K_24_KL_3                 = 35'd32906150940;
    localparam L6_OFFSET_K_24_KL_4                 = 40'd672867571740;
    localparam L6_OFFSET_K_24_KL_5                 = 43'd8792378098140;
    localparam L6_OFFSET_K_24_KL_6                 = 47'd78745084171740;
    localparam L6_OFFSET_K_24_KL_7                 = 49'd505956253406940;
    localparam L6_OFFSET_K_24_KL_8                 = 52'd2410097464855260;
    localparam L6_OFFSET_K_24_KL_9                 = 53'd8732441330992260;
    localparam L6_OFFSET_K_24_KL_10                = 55'd24600284759728260;
    localparam L6_OFFSET_K_24_KL_11                = 56'd55013651331472260;
    localparam L6_OFFSET_K_24_KL_12                = 57'd99833349437200260;
    localparam L6_OFFSET_K_24_KL_13                = 58'd150815756032465860;
    localparam L6_OFFSET_K_24_KL_14                = 58'd195635454138193860;
    localparam L6_OFFSET_K_24_KL_15                = 58'd226048820709937860;
    localparam L6_OFFSET_K_24_KL_16                = 58'd241916664138673860;
    localparam L6_OFFSET_K_24_KL_17                = 58'd248239008004810860;
    localparam L6_OFFSET_K_24_KL_18                = 58'd250143149216259180;
    localparam L6_OFFSET_K_24_KL_19                = 58'd250570360385494380;
    localparam L6_OFFSET_K_24_KL_20                = 58'd250640313091567980;
    localparam L6_OFFSET_K_24_KL_21                = 58'd250648432602094380;
    localparam L6_OFFSET_K_24_KL_22                = 58'd250649072563515180;
    localparam L6_OFFSET_K_24_KL_23                = 58'd250649104561586220;
    localparam L6_OFFSET_K_24_KL_24                = 58'd250649105459147820;
    localparam L6_OFFSET_K_25_KL_1                 = 22'd3365856;
    localparam L6_OFFSET_K_25_KL_2                 = 29'd339951456;
    localparam L6_OFFSET_K_25_KL_3                 = 34'd14252156256;
    localparam L6_OFFSET_K_25_KL_4                 = 39'd334232866656;
    localparam L6_OFFSET_K_25_KL_5                 = 43'd4973953167456;
    localparam L6_OFFSET_K_25_KL_6                 = 46'd50443212115296;
    localparam L6_OFFSET_K_25_KL_7                 = 49'd365230389446496;
    localparam L6_OFFSET_K_25_KL_8                 = 51'd1952014732320096;
    localparam L6_OFFSET_K_25_KL_9                 = 53'd7902456018096096;
    localparam L6_OFFSET_K_25_KL_10                = 55'd24762039661128096;
    localparam L6_OFFSET_K_25_KL_11                = 56'd61258079547220896;
    localparam L6_OFFSET_K_25_KL_12                = 57'd122084812690708896;
    localparam L6_OFFSET_K_25_KL_13                = 58'd200519284375732896;
    localparam L6_OFFSET_K_25_KL_14                = 58'd278953756060756896;
    localparam L6_OFFSET_K_25_KL_15                = 59'd339780489204244896;
    localparam L6_OFFSET_K_25_KL_16                = 59'd376276529090337696;
    localparam L6_OFFSET_K_25_KL_17                = 59'd393136112733369696;
    localparam L6_OFFSET_K_25_KL_18                = 59'd399086554019145696;
    localparam L6_OFFSET_K_25_KL_19                = 59'd400673338362019296;
    localparam L6_OFFSET_K_25_KL_20                = 59'd400988125539350496;
    localparam L6_OFFSET_K_25_KL_21                = 59'd401033594798298336;
    localparam L6_OFFSET_K_25_KL_22                = 59'd401038234518599136;
    localparam L6_OFFSET_K_25_KL_23                = 59'd401038554499309536;
    localparam L6_OFFSET_K_25_KL_24                = 59'd401038568411514336;
    localparam L6_OFFSET_K_25_KL_25                = 59'd401038568748099936;
    localparam L6_OFFSET_K_26_KL_1                 = 20'd906192;
    localparam L6_OFFSET_K_26_KL_2                 = 27'd108613584;
    localparam L6_OFFSET_K_26_KL_3                 = 33'd5325690384;
    localparam L6_OFFSET_K_26_KL_4                 = 38'd144447738384;
    localparam L6_OFFSET_K_26_KL_5                 = 42'd2464307888784;
    localparam L6_OFFSET_K_26_KL_6                 = 45'd28446741573264;
    localparam L6_OFFSET_K_26_KL_7                 = 48'd233058406838544;
    localparam L6_OFFSET_K_26_KL_8                 = 51'd1402267922640144;
    localparam L6_OFFSET_K_26_KL_9                 = 53'd6360968994120144;
    localparam L6_OFFSET_K_26_KL_10                = 55'd22228812422856144;
    localparam L6_OFFSET_K_26_KL_11                = 56'd61005854801829744;
    localparam L6_OFFSET_K_26_KL_12                = 57'd133997934574015344;
    localparam L6_OFFSET_K_26_KL_13                = 58'd240444717575119344;
    localparam L6_OFFSET_K_26_KL_14                = 59'd361113135552079344;
    localparam L6_OFFSET_K_26_KL_15                = 59'd467559918553183344;
    localparam L6_OFFSET_K_26_KL_16                = 59'd540551998325368944;
    localparam L6_OFFSET_K_26_KL_17                = 60'd579329040704342544;
    localparam L6_OFFSET_K_26_KL_18                = 60'd595196884133078544;
    localparam L6_OFFSET_K_26_KL_19                = 60'd600155585204558544;
    localparam L6_OFFSET_K_26_KL_20                = 60'd601324794720360144;
    localparam L6_OFFSET_K_26_KL_21                = 60'd601529406385625424;
    localparam L6_OFFSET_K_26_KL_22                = 60'd601555388819309904;
    localparam L6_OFFSET_K_26_KL_23                = 60'd601557708679460304;
    localparam L6_OFFSET_K_26_KL_24                = 60'd601557847801508304;
    localparam L6_OFFSET_K_26_KL_25                = 60'd601557853018585104;
    localparam L6_OFFSET_K_26_KL_26                = 60'd601557853126292496;
    localparam L6_OFFSET_K_27_KL_1                 = 18'd201376;
    localparam L6_OFFSET_K_27_KL_2                 = 25'd29199520;
    localparam L6_OFFSET_K_27_KL_3                 = 31'd1698664096;
    localparam L6_OFFSET_K_27_KL_4                 = 36'd53869432096;
    localparam L6_OFFSET_K_27_KL_5                 = 40'd1062504280096;
    localparam L6_OFFSET_K_27_KL_6                 = 44'd14053721122336;
    localparam L6_OFFSET_K_27_KL_7                 = 47'd130974672702496;
    localparam L6_OFFSET_K_27_KL_8                 = 50'd890960857973536;
    localparam L6_OFFSET_K_27_KL_9                 = 53'd4544740594853536;
    localparam L6_OFFSET_K_27_KL_10                = 54'd17767943452133536;
    localparam L6_OFFSET_K_27_KL_11                = 56'd54263983338226336;
    localparam L6_OFFSET_K_27_KL_12                = 57'd131818068096173536;
    localparam L6_OFFSET_K_27_KL_13                = 58'd259554207697498336;
    localparam L6_OFFSET_K_27_KL_14                = 59'd423318489237658336;
    localparam L6_OFFSET_K_27_KL_15                = 60'd587082770777818336;
    localparam L6_OFFSET_K_27_KL_16                = 60'd714818910379143136;
    localparam L6_OFFSET_K_27_KL_17                = 60'd792372995137090336;
    localparam L6_OFFSET_K_27_KL_18                = 60'd828869035023183136;
    localparam L6_OFFSET_K_27_KL_19                = 60'd842092237880463136;
    localparam L6_OFFSET_K_27_KL_20                = 60'd845746017617343136;
    localparam L6_OFFSET_K_27_KL_21                = 60'd846506003802614176;
    localparam L6_OFFSET_K_27_KL_22                = 60'd846622924754194336;
    localparam L6_OFFSET_K_27_KL_23                = 60'd846635915971036576;
    localparam L6_OFFSET_K_27_KL_24                = 60'd846636924605884576;
    localparam L6_OFFSET_K_27_KL_25                = 60'd846636976776652576;
    localparam L6_OFFSET_K_27_KL_26                = 60'd846636978446117152;
    localparam L6_OFFSET_K_27_KL_27                = 60'd846636978475115296;
    localparam L6_OFFSET_K_28_KL_1                 = 16'd35960;
    localparam L6_OFFSET_K_28_KL_2                 = 23'd6479992;
    localparam L6_OFFSET_K_28_KL_3                 = 29'd455951224;
    localparam L6_OFFSET_K_28_KL_4                 = 34'd17150596984;
    localparam L6_OFFSET_K_28_KL_5                 = 39'd395388664984;
    localparam L6_OFFSET_K_28_KL_6                 = 43'd6043743813784;
    localparam L6_OFFSET_K_28_KL_7                 = 46'd64504219603864;
    localparam L6_OFFSET_K_28_KL_8                 = 49'd498782039758744;
    localparam L6_OFFSET_K_28_KL_9                 = 52'd2873738868730744;
    localparam L6_OFFSET_K_28_KL_10                = 54'd12617151500410744;
    localparam L6_OFFSET_K_28_KL_11                = 56'd43030518072154744;
    localparam L6_OFFSET_K_28_KL_12                = 57'd116022597844340344;
    localparam L6_OFFSET_K_28_KL_13                = 58'd251742246170747944;
    localparam L6_OFFSET_K_28_KL_14                = 59'd448259384018939944;
    localparam L6_OFFSET_K_28_KL_15                = 60'd670510908966299944;
    localparam L6_OFFSET_K_28_KL_16                = 60'd867028046814491944;
    localparam L6_OFFSET_K_28_KL_17                = 60'd1002747695140899544;
    localparam L6_OFFSET_K_28_KL_18                = 60'd1075739774913085144;
    localparam L6_OFFSET_K_28_KL_19                = 60'd1106153141484829144;
    localparam L6_OFFSET_K_28_KL_20                = 60'd1115896554116509144;
    localparam L6_OFFSET_K_28_KL_21                = 60'd1118271510945481144;
    localparam L6_OFFSET_K_28_KL_22                = 60'd1118705788765636024;
    localparam L6_OFFSET_K_28_KL_23                = 60'd1118764249241426104;
    localparam L6_OFFSET_K_28_KL_24                = 60'd1118769897596574904;
    localparam L6_OFFSET_K_28_KL_25                = 60'd1118770275834642904;
    localparam L6_OFFSET_K_28_KL_26                = 60'd1118770292529288664;
    localparam L6_OFFSET_K_28_KL_27                = 60'd1118770292978759896;
    localparam L6_OFFSET_K_28_KL_28                = 60'd1118770292985203928;
    localparam L6_OFFSET_K_29_KL_1                 = 13'd4960;
    localparam L6_OFFSET_K_29_KL_2                 = 21'd1155680;
    localparam L6_OFFSET_K_29_KL_3                 = 27'd101038176;
    localparam L6_OFFSET_K_29_KL_4                 = 33'd4595750496;
    localparam L6_OFFSET_K_29_KL_5                 = 37'd125631932256;
    localparam L6_OFFSET_K_29_KL_6                 = 42'd2243765113056;
    localparam L6_OFFSET_K_29_KL_7                 = 45'd27661363282656;
    localparam L6_OFFSET_K_29_KL_8                 = 48'd244800273360096;
    localparam L6_OFFSET_K_29_KL_9                 = 51'd1601918461344096;
    localparam L6_OFFSET_K_29_KL_10                = 53'd7935136671936096;
    localparam L6_OFFSET_K_29_KL_11                = 55'd30344985724800096;
    localparam L6_OFFSET_K_29_KL_12                = 57'd91171718868288096;
    localparam L6_OFFSET_K_29_KL_13                = 58'd218907858469612896;
    localparam L6_OFFSET_K_29_KL_14                = 59'd427707317433316896;
    localparam L6_OFFSET_K_29_KL_15                = 60'd694409147370148896;
    localparam L6_OFFSET_K_29_KL_16                = 60'd961110977306980896;
    localparam L6_OFFSET_K_29_KL_17                = 61'd1169910436270684896;
    localparam L6_OFFSET_K_29_KL_18                = 61'd1297646575872009696;
    localparam L6_OFFSET_K_29_KL_19                = 61'd1358473309015497696;
    localparam L6_OFFSET_K_29_KL_20                = 61'd1380883158068361696;
    localparam L6_OFFSET_K_29_KL_21                = 61'd1387216376278953696;
    localparam L6_OFFSET_K_29_KL_22                = 61'd1388573494466937696;
    localparam L6_OFFSET_K_29_KL_23                = 61'd1388790633377015136;
    localparam L6_OFFSET_K_29_KL_24                = 61'd1388816050975184736;
    localparam L6_OFFSET_K_29_KL_25                = 61'd1388818169108365536;
    localparam L6_OFFSET_K_29_KL_26                = 61'd1388818290144547296;
    localparam L6_OFFSET_K_29_KL_27                = 61'd1388818294639259616;
    localparam L6_OFFSET_K_29_KL_28                = 61'd1388818294739142112;
    localparam L6_OFFSET_K_29_KL_29                = 61'd1388818294740292832;
    localparam L6_OFFSET_K_30_KL_1                 = 9'd496;
    localparam L6_OFFSET_K_30_KL_2                 = 18'd159216;
    localparam L6_OFFSET_K_30_KL_3                 = 25'd17995376;
    localparam L6_OFFSET_K_30_KL_4                 = 30'd1016820336;
    localparam L6_OFFSET_K_30_KL_5                 = 35'd33603484656;
    localparam L6_OFFSET_K_30_KL_6                 = 40'd711406102512;
    localparam L6_OFFSET_K_30_KL_7                 = 44'd10243005416112;
    localparam L6_OFFSET_K_30_KL_8                 = 47'd104651227188912;
    localparam L6_OFFSET_K_30_KL_9                 = 50'd783210321180912;
    localparam L6_OFFSET_K_30_KL_10                = 52'd4402192155804912;
    localparam L6_OFFSET_K_30_KL_11                = 55'd18968594040166512;
    localparam L6_OFFSET_K_30_KL_12                = 56'd63788292145894512;
    localparam L6_OFFSET_K_30_KL_13                = 58'd170235075146998512;
    localparam L6_OFFSET_K_30_KL_14                = 59'd366752212995190512;
    localparam L6_OFFSET_K_30_KL_15                = 60'd650122907303074512;
    localparam L6_OFFSET_K_30_KL_16                = 60'd970165103227272912;
    localparam L6_OFFSET_K_30_KL_17                = 61'd1253535797535156912;
    localparam L6_OFFSET_K_30_KL_18                = 61'd1450052935383348912;
    localparam L6_OFFSET_K_30_KL_19                = 61'd1556499718384452912;
    localparam L6_OFFSET_K_30_KL_20                = 61'd1601319416490180912;
    localparam L6_OFFSET_K_30_KL_21                = 61'd1615885818374542512;
    localparam L6_OFFSET_K_30_KL_22                = 61'd1619504800209166512;
    localparam L6_OFFSET_K_30_KL_23                = 61'd1620183359303158512;
    localparam L6_OFFSET_K_30_KL_24                = 61'd1620277767524931312;
    localparam L6_OFFSET_K_30_KL_25                = 61'd1620287299124244912;
    localparam L6_OFFSET_K_30_KL_26                = 61'd1620287976926862768;
    localparam L6_OFFSET_K_30_KL_27                = 61'd1620288009513527088;
    localparam L6_OFFSET_K_30_KL_28                = 61'd1620288010512352048;
    localparam L6_OFFSET_K_30_KL_29                = 61'd1620288010530188208;
    localparam L6_OFFSET_K_30_KL_30                = 61'd1620288010530346928;
    localparam L6_OFFSET_K_31_KL_1                 = 6'd32;
    localparam L6_OFFSET_K_31_KL_2                 = 14'd15904;
    localparam L6_OFFSET_K_31_KL_3                 = 22'd2476064;
    localparam L6_OFFSET_K_31_KL_4                 = 28'd180837664;
    localparam L6_OFFSET_K_31_KL_5                 = 33'd7422318624;
    localparam L6_OFFSET_K_31_KL_6                 = 38'd189907638816;
    localparam L6_OFFSET_K_31_KL_7                 = 42'd3240019419168;
    localparam L6_OFFSET_K_31_KL_8                 = 46'd38643102583968;
    localparam L6_OFFSET_K_31_KL_9                 = 49'd333668795623968;
    localparam L6_OFFSET_K_31_KL_10                = 51'd2143159712935968;
    localparam L6_OFFSET_K_31_KL_11                = 54'd10466817932571168;
    localparam L6_OFFSET_K_31_KL_12                = 56'd39599621701294368;
    localparam L6_OFFSET_K_31_KL_13                = 57'd118034093386318368;
    localparam L6_OFFSET_K_31_KL_14                = 58'd281798374926478368;
    localparam L6_OFFSET_K_31_KL_15                = 59'd548500204863310368;
    localparam L6_OFFSET_K_31_KL_16                = 60'd888545038032771168;
    localparam L6_OFFSET_K_31_KL_17                = 61'd1228589871202231968;
    localparam L6_OFFSET_K_31_KL_18                = 61'd1495291701139063968;
    localparam L6_OFFSET_K_31_KL_19                = 61'd1659055982679223968;
    localparam L6_OFFSET_K_31_KL_20                = 61'd1737490454364247968;
    localparam L6_OFFSET_K_31_KL_21                = 61'd1766623258132971168;
    localparam L6_OFFSET_K_31_KL_22                = 61'd1774946916352606368;
    localparam L6_OFFSET_K_31_KL_23                = 61'd1776756407269918368;
    localparam L6_OFFSET_K_31_KL_24                = 61'd1777051432962958368;
    localparam L6_OFFSET_K_31_KL_25                = 61'd1777086836046123168;
    localparam L6_OFFSET_K_31_KL_26                = 61'd1777089886157903520;
    localparam L6_OFFSET_K_31_KL_27                = 61'd1777090068643223712;
    localparam L6_OFFSET_K_31_KL_28                = 61'd1777090075884704672;
    localparam L6_OFFSET_K_31_KL_29                = 61'd1777090076063066272;
    localparam L6_OFFSET_K_31_KL_30                = 61'd1777090076065526432;
    localparam L6_OFFSET_K_31_KL_31                = 61'd1777090076065542304;
    localparam L6_OFFSET_K_32_KL_1                 = 1'd1;
    localparam L6_OFFSET_K_32_KL_2                 = 11'd1025;
    localparam L6_OFFSET_K_32_KL_3                 = 18'd247041;
    localparam L6_OFFSET_K_32_KL_4                 = 25'd24848641;
    localparam L6_OFFSET_K_32_KL_5                 = 31'd1317970241;
    localparam L6_OFFSET_K_32_KL_6                 = 36'd41870263617;
    localparam L6_OFFSET_K_32_KL_7                 = 40'd863054204481;
    localparam L6_OFFSET_K_32_KL_8                 = 44'd12192040817217;
    localparam L6_OFFSET_K_32_KL_9                 = 47'd122826675707217;
    localparam L6_OFFSET_K_32_KL_10                = 50'd909561857147217;
    localparam L6_OFFSET_K_32_KL_11                = 53'd5071390966964817;
    localparam L6_OFFSET_K_32_KL_12                = 55'd21718707406235217;
    localparam L6_OFFSET_K_32_KL_13                = 57'd72701114001500817;
    localparam L6_OFFSET_K_32_KL_14                = 58'd193369531978460817;
    localparam L6_OFFSET_K_32_KL_15                = 59'd415621056925820817;
    localparam L6_OFFSET_K_32_KL_16                = 60'd735663252850019217;
    localparam L6_OFFSET_K_32_KL_17                = 60'd1096960888092571317;
    localparam L6_OFFSET_K_32_KL_18                = 61'd1417003084016769717;
    localparam L6_OFFSET_K_32_KL_19                = 61'd1639254608964129717;
    localparam L6_OFFSET_K_32_KL_20                = 61'd1759923026941089717;
    localparam L6_OFFSET_K_32_KL_21                = 61'd1810905433536355317;
    localparam L6_OFFSET_K_32_KL_22                = 61'd1827552749975625717;
    localparam L6_OFFSET_K_32_KL_23                = 61'd1831714579085443317;
    localparam L6_OFFSET_K_32_KL_24                = 61'd1832501314266883317;
    localparam L6_OFFSET_K_32_KL_25                = 61'd1832611948901773317;
    localparam L6_OFFSET_K_32_KL_26                = 61'd1832623277888386053;
    localparam L6_OFFSET_K_32_KL_27                = 61'd1832624099072326917;
    localparam L6_OFFSET_K_32_KL_28                = 61'd1832624139624620293;
    localparam L6_OFFSET_K_32_KL_29                = 61'd1832624140917741893;
    localparam L6_OFFSET_K_32_KL_30                = 61'd1832624140942343493;
    localparam L6_OFFSET_K_32_KL_31                = 61'd1832624140942589509;
    localparam L6_OFFSET_K_32_KL_32                = 61'd1832624140942590533;

    wire [60:0] offset;
    assign offset =
        out_num_one == 7'd0 ? 61'd0 :
        out_num_one == 7'd1 ? (num_one_high == 6'd1 ? L6_OFFSET_K_1_KL_1 : 61'd0) :
        out_num_one == 7'd2 ? (num_one_high == 6'd1 ? L6_OFFSET_K_2_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_2_KL_2 : 61'd0) :
        out_num_one == 7'd3 ? (num_one_high == 6'd1 ? L6_OFFSET_K_3_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_3_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_3_KL_3 : 61'd0) :
        out_num_one == 7'd4 ? (num_one_high == 6'd1 ? L6_OFFSET_K_4_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_4_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_4_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_4_KL_4 : 61'd0) :
        out_num_one == 7'd5 ? (num_one_high == 6'd1 ? L6_OFFSET_K_5_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_5_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_5_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_5_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_5_KL_5 : 61'd0) :
        out_num_one == 7'd6 ? (num_one_high == 6'd1 ? L6_OFFSET_K_6_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_6_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_6_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_6_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_6_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_6_KL_6 : 61'd0) :
        out_num_one == 7'd7 ? (num_one_high == 6'd1 ? L6_OFFSET_K_7_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_7_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_7_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_7_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_7_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_7_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_7_KL_7 : 61'd0) :
        out_num_one == 7'd8 ? (num_one_high == 6'd1 ? L6_OFFSET_K_8_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_8_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_8_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_8_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_8_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_8_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_8_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_8_KL_8 : 61'd0) :
        out_num_one == 7'd9 ? (num_one_high == 6'd1 ? L6_OFFSET_K_9_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_9_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_9_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_9_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_9_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_9_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_9_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_9_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_9_KL_9 : 61'd0) :
        out_num_one == 7'd10 ? (num_one_high == 6'd1 ? L6_OFFSET_K_10_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_10_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_10_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_10_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_10_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_10_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_10_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_10_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_10_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_10_KL_10 : 61'd0) :
        out_num_one == 7'd11 ? (num_one_high == 6'd1 ? L6_OFFSET_K_11_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_11_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_11_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_11_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_11_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_11_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_11_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_11_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_11_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_11_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_11_KL_11 : 61'd0) :
        out_num_one == 7'd12 ? (num_one_high == 6'd1 ? L6_OFFSET_K_12_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_12_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_12_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_12_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_12_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_12_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_12_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_12_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_12_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_12_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_12_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_12_KL_12 : 61'd0) :
        out_num_one == 7'd13 ? (num_one_high == 6'd1 ? L6_OFFSET_K_13_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_13_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_13_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_13_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_13_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_13_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_13_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_13_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_13_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_13_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_13_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_13_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_13_KL_13 : 61'd0) :
        out_num_one == 7'd14 ? (num_one_high == 6'd1 ? L6_OFFSET_K_14_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_14_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_14_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_14_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_14_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_14_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_14_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_14_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_14_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_14_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_14_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_14_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_14_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_14_KL_14 : 61'd0) :
        out_num_one == 7'd15 ? (num_one_high == 6'd1 ? L6_OFFSET_K_15_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_15_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_15_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_15_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_15_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_15_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_15_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_15_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_15_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_15_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_15_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_15_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_15_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_15_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_15_KL_15 : 61'd0) :
        out_num_one == 7'd16 ? (num_one_high == 6'd1 ? L6_OFFSET_K_16_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_16_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_16_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_16_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_16_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_16_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_16_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_16_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_16_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_16_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_16_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_16_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_16_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_16_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_16_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_16_KL_16 : 61'd0) :
        out_num_one == 7'd17 ? (num_one_high == 6'd1 ? L6_OFFSET_K_17_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_17_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_17_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_17_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_17_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_17_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_17_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_17_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_17_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_17_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_17_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_17_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_17_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_17_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_17_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_17_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_17_KL_17 : 61'd0) :
        out_num_one == 7'd18 ? (num_one_high == 6'd1 ? L6_OFFSET_K_18_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_18_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_18_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_18_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_18_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_18_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_18_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_18_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_18_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_18_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_18_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_18_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_18_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_18_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_18_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_18_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_18_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_18_KL_18 : 61'd0) :
        out_num_one == 7'd19 ? (num_one_high == 6'd1 ? L6_OFFSET_K_19_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_19_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_19_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_19_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_19_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_19_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_19_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_19_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_19_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_19_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_19_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_19_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_19_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_19_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_19_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_19_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_19_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_19_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_19_KL_19 : 61'd0) :
        out_num_one == 7'd20 ? (num_one_high == 6'd1 ? L6_OFFSET_K_20_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_20_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_20_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_20_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_20_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_20_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_20_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_20_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_20_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_20_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_20_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_20_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_20_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_20_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_20_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_20_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_20_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_20_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_20_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_20_KL_20 : 61'd0) :
        out_num_one == 7'd21 ? (num_one_high == 6'd1 ? L6_OFFSET_K_21_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_21_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_21_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_21_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_21_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_21_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_21_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_21_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_21_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_21_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_21_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_21_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_21_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_21_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_21_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_21_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_21_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_21_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_21_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_21_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_21_KL_21 : 61'd0) :
        out_num_one == 7'd22 ? (num_one_high == 6'd1 ? L6_OFFSET_K_22_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_22_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_22_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_22_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_22_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_22_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_22_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_22_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_22_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_22_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_22_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_22_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_22_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_22_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_22_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_22_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_22_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_22_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_22_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_22_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_22_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_22_KL_22 : 61'd0) :
        out_num_one == 7'd23 ? (num_one_high == 6'd1 ? L6_OFFSET_K_23_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_23_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_23_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_23_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_23_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_23_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_23_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_23_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_23_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_23_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_23_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_23_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_23_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_23_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_23_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_23_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_23_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_23_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_23_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_23_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_23_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_23_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_23_KL_23 : 61'd0) :
        out_num_one == 7'd24 ? (num_one_high == 6'd1 ? L6_OFFSET_K_24_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_24_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_24_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_24_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_24_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_24_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_24_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_24_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_24_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_24_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_24_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_24_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_24_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_24_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_24_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_24_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_24_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_24_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_24_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_24_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_24_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_24_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_24_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_24_KL_24 : 61'd0) :
        out_num_one == 7'd25 ? (num_one_high == 6'd1 ? L6_OFFSET_K_25_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_25_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_25_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_25_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_25_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_25_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_25_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_25_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_25_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_25_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_25_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_25_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_25_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_25_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_25_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_25_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_25_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_25_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_25_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_25_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_25_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_25_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_25_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_25_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_25_KL_25 : 61'd0) :
        out_num_one == 7'd26 ? (num_one_high == 6'd1 ? L6_OFFSET_K_26_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_26_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_26_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_26_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_26_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_26_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_26_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_26_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_26_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_26_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_26_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_26_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_26_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_26_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_26_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_26_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_26_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_26_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_26_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_26_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_26_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_26_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_26_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_26_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_26_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_26_KL_26 : 61'd0) :
        out_num_one == 7'd27 ? (num_one_high == 6'd1 ? L6_OFFSET_K_27_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_27_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_27_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_27_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_27_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_27_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_27_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_27_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_27_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_27_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_27_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_27_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_27_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_27_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_27_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_27_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_27_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_27_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_27_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_27_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_27_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_27_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_27_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_27_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_27_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_27_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_27_KL_27 : 61'd0) :
        out_num_one == 7'd28 ? (num_one_high == 6'd1 ? L6_OFFSET_K_28_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_28_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_28_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_28_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_28_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_28_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_28_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_28_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_28_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_28_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_28_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_28_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_28_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_28_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_28_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_28_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_28_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_28_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_28_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_28_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_28_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_28_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_28_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_28_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_28_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_28_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_28_KL_27 : num_one_high == 6'd28 ? L6_OFFSET_K_28_KL_28 : 61'd0) :
        out_num_one == 7'd29 ? (num_one_high == 6'd1 ? L6_OFFSET_K_29_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_29_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_29_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_29_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_29_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_29_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_29_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_29_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_29_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_29_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_29_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_29_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_29_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_29_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_29_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_29_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_29_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_29_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_29_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_29_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_29_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_29_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_29_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_29_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_29_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_29_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_29_KL_27 : num_one_high == 6'd28 ? L6_OFFSET_K_29_KL_28 : num_one_high == 6'd29 ? L6_OFFSET_K_29_KL_29 : 61'd0) :
        out_num_one == 7'd30 ? (num_one_high == 6'd1 ? L6_OFFSET_K_30_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_30_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_30_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_30_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_30_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_30_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_30_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_30_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_30_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_30_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_30_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_30_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_30_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_30_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_30_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_30_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_30_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_30_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_30_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_30_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_30_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_30_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_30_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_30_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_30_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_30_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_30_KL_27 : num_one_high == 6'd28 ? L6_OFFSET_K_30_KL_28 : num_one_high == 6'd29 ? L6_OFFSET_K_30_KL_29 : num_one_high == 6'd30 ? L6_OFFSET_K_30_KL_30 : 61'd0) :
        out_num_one == 7'd31 ? (num_one_high == 6'd1 ? L6_OFFSET_K_31_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_31_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_31_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_31_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_31_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_31_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_31_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_31_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_31_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_31_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_31_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_31_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_31_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_31_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_31_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_31_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_31_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_31_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_31_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_31_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_31_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_31_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_31_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_31_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_31_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_31_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_31_KL_27 : num_one_high == 6'd28 ? L6_OFFSET_K_31_KL_28 : num_one_high == 6'd29 ? L6_OFFSET_K_31_KL_29 : num_one_high == 6'd30 ? L6_OFFSET_K_31_KL_30 : num_one_high == 6'd31 ? L6_OFFSET_K_31_KL_31 : 61'd0) :
        out_num_one == 7'd32 ? (num_one_high == 6'd1 ? L6_OFFSET_K_32_KL_1 : num_one_high == 6'd2 ? L6_OFFSET_K_32_KL_2 : num_one_high == 6'd3 ? L6_OFFSET_K_32_KL_3 : num_one_high == 6'd4 ? L6_OFFSET_K_32_KL_4 : num_one_high == 6'd5 ? L6_OFFSET_K_32_KL_5 : num_one_high == 6'd6 ? L6_OFFSET_K_32_KL_6 : num_one_high == 6'd7 ? L6_OFFSET_K_32_KL_7 : num_one_high == 6'd8 ? L6_OFFSET_K_32_KL_8 : num_one_high == 6'd9 ? L6_OFFSET_K_32_KL_9 : num_one_high == 6'd10 ? L6_OFFSET_K_32_KL_10 : num_one_high == 6'd11 ? L6_OFFSET_K_32_KL_11 : num_one_high == 6'd12 ? L6_OFFSET_K_32_KL_12 : num_one_high == 6'd13 ? L6_OFFSET_K_32_KL_13 : num_one_high == 6'd14 ? L6_OFFSET_K_32_KL_14 : num_one_high == 6'd15 ? L6_OFFSET_K_32_KL_15 : num_one_high == 6'd16 ? L6_OFFSET_K_32_KL_16 : num_one_high == 6'd17 ? L6_OFFSET_K_32_KL_17 : num_one_high == 6'd18 ? L6_OFFSET_K_32_KL_18 : num_one_high == 6'd19 ? L6_OFFSET_K_32_KL_19 : num_one_high == 6'd20 ? L6_OFFSET_K_32_KL_20 : num_one_high == 6'd21 ? L6_OFFSET_K_32_KL_21 : num_one_high == 6'd22 ? L6_OFFSET_K_32_KL_22 : num_one_high == 6'd23 ? L6_OFFSET_K_32_KL_23 : num_one_high == 6'd24 ? L6_OFFSET_K_32_KL_24 : num_one_high == 6'd25 ? L6_OFFSET_K_32_KL_25 : num_one_high == 6'd26 ? L6_OFFSET_K_32_KL_26 : num_one_high == 6'd27 ? L6_OFFSET_K_32_KL_27 : num_one_high == 6'd28 ? L6_OFFSET_K_32_KL_28 : num_one_high == 6'd29 ? L6_OFFSET_K_32_KL_29 : num_one_high == 6'd30 ? L6_OFFSET_K_32_KL_30 : num_one_high == 6'd31 ? L6_OFFSET_K_32_KL_31 : num_one_high == 6'd32 ? L6_OFFSET_K_32_KL_32 : 61'd0) :
        61'd0;

    wire [29:0] weight;
    assign weight =
        num_one_low == 6'd0 ? L6_WEIGHT_KR_0 :
        num_one_low == 6'd1 ? L6_WEIGHT_KR_1 :
        num_one_low == 6'd2 ? L6_WEIGHT_KR_2 :
        num_one_low == 6'd3 ? L6_WEIGHT_KR_3 :
        num_one_low == 6'd4 ? L6_WEIGHT_KR_4 :
        num_one_low == 6'd5 ? L6_WEIGHT_KR_5 :
        num_one_low == 6'd6 ? L6_WEIGHT_KR_6 :
        num_one_low == 6'd7 ? L6_WEIGHT_KR_7 :
        num_one_low == 6'd8 ? L6_WEIGHT_KR_8 :
        num_one_low == 6'd9 ? L6_WEIGHT_KR_9 :
        num_one_low == 6'd10 ? L6_WEIGHT_KR_10 :
        num_one_low == 6'd11 ? L6_WEIGHT_KR_11 :
        num_one_low == 6'd12 ? L6_WEIGHT_KR_12 :
        num_one_low == 6'd13 ? L6_WEIGHT_KR_13 :
        num_one_low == 6'd14 ? L6_WEIGHT_KR_14 :
        num_one_low == 6'd15 ? L6_WEIGHT_KR_15 :
        num_one_low == 6'd16 ? L6_WEIGHT_KR_16 :
        num_one_low == 6'd17 ? L6_WEIGHT_KR_15 :
        num_one_low == 6'd18 ? L6_WEIGHT_KR_14 :
        num_one_low == 6'd19 ? L6_WEIGHT_KR_13 :
        num_one_low == 6'd20 ? L6_WEIGHT_KR_12 :
        num_one_low == 6'd21 ? L6_WEIGHT_KR_11 :
        num_one_low == 6'd22 ? L6_WEIGHT_KR_10 :
        num_one_low == 6'd23 ? L6_WEIGHT_KR_9 :
        num_one_low == 6'd24 ? L6_WEIGHT_KR_8 :
        num_one_low == 6'd25 ? L6_WEIGHT_KR_7 :
        num_one_low == 6'd26 ? L6_WEIGHT_KR_6 :
        num_one_low == 6'd27 ? L6_WEIGHT_KR_5 :
        num_one_low == 6'd28 ? L6_WEIGHT_KR_4 :
        num_one_low == 6'd29 ? L6_WEIGHT_KR_3 :
        num_one_low == 6'd30 ? L6_WEIGHT_KR_2 :
        num_one_low == 6'd31 ? L6_WEIGHT_KR_1 :
        num_one_low == 6'd32 ? L6_WEIGHT_KR_0 :
        30'd0;

    assign out_num_one = num_one_high + num_one_low;
    assign out_data = offset + high * weight + low;

endmodule