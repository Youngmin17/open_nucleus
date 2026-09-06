// SPDX-License-Identifier: Apache-2.0
module L5_7_redecomp (
    input wire [6:0] val,
    input wire [3:0] k,
    output reg [7:0] val_out
);

    always @(*) begin
        val_out = 8'd0;
        case (k)
            4'd0: begin
                val_out = 8'd0;
            end
            4'd1: begin
                case (val)
                    7'd0  : val_out = 8'd1;
                    7'd1  : val_out = 8'd2;
                    7'd2  : val_out = 8'd4;
                    7'd3  : val_out = 8'd8;
                    7'd4  : val_out = 8'd16;
                    7'd5  : val_out = 8'd32;
                    7'd6  : val_out = 8'd64;
                    7'd7  : val_out = 8'd128;
                    default: val_out = 8'd0;
                endcase
            end
            4'd2: begin
                case (val)
                    7'd0  : val_out = 8'd3;
                    7'd1  : val_out = 8'd5;
                    7'd2  : val_out = 8'd6;
                    7'd3  : val_out = 8'd9;
                    7'd4  : val_out = 8'd10;
                    7'd5  : val_out = 8'd12;
                    7'd6  : val_out = 8'd17;
                    7'd7  : val_out = 8'd18;
                    7'd8  : val_out = 8'd20;
                    7'd9  : val_out = 8'd24;
                    7'd10 : val_out = 8'd33;
                    7'd11 : val_out = 8'd34;
                    7'd12 : val_out = 8'd36;
                    7'd13 : val_out = 8'd40;
                    7'd14 : val_out = 8'd65;
                    7'd15 : val_out = 8'd66;
                    7'd16 : val_out = 8'd68;
                    7'd17 : val_out = 8'd72;
                    7'd18 : val_out = 8'd129;
                    7'd19 : val_out = 8'd130;
                    7'd20 : val_out = 8'd132;
                    7'd21 : val_out = 8'd136;
                    7'd22 : val_out = 8'd48;
                    7'd23 : val_out = 8'd80;
                    7'd24 : val_out = 8'd96;
                    7'd25 : val_out = 8'd144;
                    7'd26 : val_out = 8'd160;
                    7'd27 : val_out = 8'd192;
                    default: val_out = 8'd0;
                endcase
            end
            4'd3: begin
                case (val)
                    7'd0  : val_out = 8'd7;
                    7'd1  : val_out = 8'd11;
                    7'd2  : val_out = 8'd13;
                    7'd3  : val_out = 8'd14;
                    7'd4  : val_out = 8'd19;
                    7'd5  : val_out = 8'd21;
                    7'd6  : val_out = 8'd22;
                    7'd7  : val_out = 8'd25;
                    7'd8  : val_out = 8'd26;
                    7'd9  : val_out = 8'd28;
                    7'd10 : val_out = 8'd35;
                    7'd11 : val_out = 8'd37;
                    7'd12 : val_out = 8'd38;
                    7'd13 : val_out = 8'd41;
                    7'd14 : val_out = 8'd42;
                    7'd15 : val_out = 8'd44;
                    7'd16 : val_out = 8'd67;
                    7'd17 : val_out = 8'd69;
                    7'd18 : val_out = 8'd70;
                    7'd19 : val_out = 8'd73;
                    7'd20 : val_out = 8'd74;
                    7'd21 : val_out = 8'd76;
                    7'd22 : val_out = 8'd131;
                    7'd23 : val_out = 8'd133;
                    7'd24 : val_out = 8'd134;
                    7'd25 : val_out = 8'd137;
                    7'd26 : val_out = 8'd138;
                    7'd27 : val_out = 8'd140;
                    7'd28 : val_out = 8'd49;
                    7'd29 : val_out = 8'd50;
                    7'd30 : val_out = 8'd52;
                    7'd31 : val_out = 8'd56;
                    7'd32 : val_out = 8'd81;
                    7'd33 : val_out = 8'd82;
                    7'd34 : val_out = 8'd84;
                    7'd35 : val_out = 8'd88;
                    7'd36 : val_out = 8'd97;
                    7'd37 : val_out = 8'd98;
                    7'd38 : val_out = 8'd100;
                    7'd39 : val_out = 8'd104;
                    7'd40 : val_out = 8'd145;
                    7'd41 : val_out = 8'd146;
                    7'd42 : val_out = 8'd148;
                    7'd43 : val_out = 8'd152;
                    7'd44 : val_out = 8'd161;
                    7'd45 : val_out = 8'd162;
                    7'd46 : val_out = 8'd164;
                    7'd47 : val_out = 8'd168;
                    7'd48 : val_out = 8'd193;
                    7'd49 : val_out = 8'd194;
                    7'd50 : val_out = 8'd196;
                    7'd51 : val_out = 8'd200;
                    7'd52 : val_out = 8'd112;
                    7'd53 : val_out = 8'd176;
                    7'd54 : val_out = 8'd208;
                    7'd55 : val_out = 8'd224;
                    default: val_out = 8'd0;
                endcase
            end
            4'd4: begin
                case (val)
                    7'd0  : val_out = 8'd15;
                    7'd1  : val_out = 8'd23;
                    7'd2  : val_out = 8'd27;
                    7'd3  : val_out = 8'd29;
                    7'd4  : val_out = 8'd30;
                    7'd5  : val_out = 8'd39;
                    7'd6  : val_out = 8'd43;
                    7'd7  : val_out = 8'd45;
                    7'd8  : val_out = 8'd46;
                    7'd9  : val_out = 8'd71;
                    7'd10 : val_out = 8'd75;
                    7'd11 : val_out = 8'd77;
                    7'd12 : val_out = 8'd78;
                    7'd13 : val_out = 8'd135;
                    7'd14 : val_out = 8'd139;
                    7'd15 : val_out = 8'd141;
                    7'd16 : val_out = 8'd142;
                    7'd17 : val_out = 8'd51;
                    7'd18 : val_out = 8'd53;
                    7'd19 : val_out = 8'd54;
                    7'd20 : val_out = 8'd57;
                    7'd21 : val_out = 8'd58;
                    7'd22 : val_out = 8'd60;
                    7'd23 : val_out = 8'd83;
                    7'd24 : val_out = 8'd85;
                    7'd25 : val_out = 8'd86;
                    7'd26 : val_out = 8'd89;
                    7'd27 : val_out = 8'd90;
                    7'd28 : val_out = 8'd92;
                    7'd29 : val_out = 8'd99;
                    7'd30 : val_out = 8'd101;
                    7'd31 : val_out = 8'd102;
                    7'd32 : val_out = 8'd105;
                    7'd33 : val_out = 8'd106;
                    7'd34 : val_out = 8'd108;
                    7'd35 : val_out = 8'd147;
                    7'd36 : val_out = 8'd149;
                    7'd37 : val_out = 8'd150;
                    7'd38 : val_out = 8'd153;
                    7'd39 : val_out = 8'd154;
                    7'd40 : val_out = 8'd156;
                    7'd41 : val_out = 8'd163;
                    7'd42 : val_out = 8'd165;
                    7'd43 : val_out = 8'd166;
                    7'd44 : val_out = 8'd169;
                    7'd45 : val_out = 8'd170;
                    7'd46 : val_out = 8'd172;
                    7'd47 : val_out = 8'd195;
                    7'd48 : val_out = 8'd197;
                    7'd49 : val_out = 8'd198;
                    7'd50 : val_out = 8'd201;
                    7'd51 : val_out = 8'd202;
                    7'd52 : val_out = 8'd204;
                    7'd53 : val_out = 8'd113;
                    7'd54 : val_out = 8'd114;
                    7'd55 : val_out = 8'd116;
                    7'd56 : val_out = 8'd120;
                    7'd57 : val_out = 8'd177;
                    7'd58 : val_out = 8'd178;
                    7'd59 : val_out = 8'd180;
                    7'd60 : val_out = 8'd184;
                    7'd61 : val_out = 8'd209;
                    7'd62 : val_out = 8'd210;
                    7'd63 : val_out = 8'd212;
                    7'd64 : val_out = 8'd216;
                    7'd65 : val_out = 8'd225;
                    7'd66 : val_out = 8'd226;
                    7'd67 : val_out = 8'd228;
                    7'd68 : val_out = 8'd232;
                    7'd69 : val_out = 8'd240;
                    default: val_out = 8'd0;
                endcase
            end
            4'd5: begin
                case (val)
                    7'd0  : val_out = 8'd31;
                    7'd1  : val_out = 8'd47;
                    7'd2  : val_out = 8'd79;
                    7'd3  : val_out = 8'd143;
                    7'd4  : val_out = 8'd55;
                    7'd5  : val_out = 8'd59;
                    7'd6  : val_out = 8'd61;
                    7'd7  : val_out = 8'd62;
                    7'd8  : val_out = 8'd87;
                    7'd9  : val_out = 8'd91;
                    7'd10 : val_out = 8'd93;
                    7'd11 : val_out = 8'd94;
                    7'd12 : val_out = 8'd103;
                    7'd13 : val_out = 8'd107;
                    7'd14 : val_out = 8'd109;
                    7'd15 : val_out = 8'd110;
                    7'd16 : val_out = 8'd151;
                    7'd17 : val_out = 8'd155;
                    7'd18 : val_out = 8'd157;
                    7'd19 : val_out = 8'd158;
                    7'd20 : val_out = 8'd167;
                    7'd21 : val_out = 8'd171;
                    7'd22 : val_out = 8'd173;
                    7'd23 : val_out = 8'd174;
                    7'd24 : val_out = 8'd199;
                    7'd25 : val_out = 8'd203;
                    7'd26 : val_out = 8'd205;
                    7'd27 : val_out = 8'd206;
                    7'd28 : val_out = 8'd115;
                    7'd29 : val_out = 8'd117;
                    7'd30 : val_out = 8'd118;
                    7'd31 : val_out = 8'd121;
                    7'd32 : val_out = 8'd122;
                    7'd33 : val_out = 8'd124;
                    7'd34 : val_out = 8'd179;
                    7'd35 : val_out = 8'd181;
                    7'd36 : val_out = 8'd182;
                    7'd37 : val_out = 8'd185;
                    7'd38 : val_out = 8'd186;
                    7'd39 : val_out = 8'd188;
                    7'd40 : val_out = 8'd211;
                    7'd41 : val_out = 8'd213;
                    7'd42 : val_out = 8'd214;
                    7'd43 : val_out = 8'd217;
                    7'd44 : val_out = 8'd218;
                    7'd45 : val_out = 8'd220;
                    7'd46 : val_out = 8'd227;
                    7'd47 : val_out = 8'd229;
                    7'd48 : val_out = 8'd230;
                    7'd49 : val_out = 8'd233;
                    7'd50 : val_out = 8'd234;
                    7'd51 : val_out = 8'd236;
                    7'd52 : val_out = 8'd241;
                    7'd53 : val_out = 8'd242;
                    7'd54 : val_out = 8'd244;
                    7'd55 : val_out = 8'd248;
                    default: val_out = 8'd0;
                endcase
            end
            4'd6: begin
                case (val)
                    7'd0  : val_out = 8'd63;
                    7'd1  : val_out = 8'd95;
                    7'd2  : val_out = 8'd111;
                    7'd3  : val_out = 8'd159;
                    7'd4  : val_out = 8'd175;
                    7'd5  : val_out = 8'd207;
                    7'd6  : val_out = 8'd119;
                    7'd7  : val_out = 8'd123;
                    7'd8  : val_out = 8'd125;
                    7'd9  : val_out = 8'd126;
                    7'd10 : val_out = 8'd183;
                    7'd11 : val_out = 8'd187;
                    7'd12 : val_out = 8'd189;
                    7'd13 : val_out = 8'd190;
                    7'd14 : val_out = 8'd215;
                    7'd15 : val_out = 8'd219;
                    7'd16 : val_out = 8'd221;
                    7'd17 : val_out = 8'd222;
                    7'd18 : val_out = 8'd231;
                    7'd19 : val_out = 8'd235;
                    7'd20 : val_out = 8'd237;
                    7'd21 : val_out = 8'd238;
                    7'd22 : val_out = 8'd243;
                    7'd23 : val_out = 8'd245;
                    7'd24 : val_out = 8'd246;
                    7'd25 : val_out = 8'd249;
                    7'd26 : val_out = 8'd250;
                    7'd27 : val_out = 8'd252;
                    default: val_out = 8'd0;
                endcase
            end
            4'd7: begin
                case (val)
                    7'd0  : val_out = 8'd127;
                    7'd1  : val_out = 8'd191;
                    7'd2  : val_out = 8'd223;
                    7'd3  : val_out = 8'd239;
                    7'd4  : val_out = 8'd247;
                    7'd5  : val_out = 8'd251;
                    7'd6  : val_out = 8'd253;
                    7'd7  : val_out = 8'd254;
                    default: val_out = 8'd0;
                endcase
            end
            4'd8: begin
                val_out = 8'd255;
            end
            default: val_out = 8'd0;
        endcase
    end

endmodule