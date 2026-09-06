// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
`default_nettype wire

module theta_lut_rom (
    input  wire [5:0]  d_in,
    output wire [31:0] d_out
);

    reg [31:0] rom_data;
    assign d_out = rom_data;

    always @(*) begin
        case (d_in)
            6'd0:  rom_data = 32'h3F800000;
            6'd1:  rom_data = 32'h3F508AC1;
            6'd2:  rom_data = 32'h3F29E1C5;
            6'd3:  rom_data = 32'h3F0A6384;
            6'd4:  rom_data = 32'h3EE177BB;
            6'd5:  rom_data = 32'h3EB7AB7D;
            6'd6:  rom_data = 32'h3E959EE3;
            6'd7:  rom_data = 32'h3E73C461;
            6'd8:  rom_data = 32'h3E4693AF;
            6'd9:  rom_data = 32'h3E21C3A0;
            6'd10: rom_data = 32'h3E03C69F;
            6'd11: rom_data = 32'h3DD6B19C;
            6'd12: rom_data = 32'h3DAEE4AD;
            6'd13: rom_data = 32'h3D8E7898;
            6'd14: rom_data = 32'h3D681E68;
            6'd15: rom_data = 32'h3D3D1684;
            6'd16: rom_data = 32'h3D1A08C8;
            6'd17: rom_data = 32'h3CFAF53F;
            6'd18: rom_data = 32'h3CCC6F49;
            6'd19: rom_data = 32'h3CA6893A;
            6'd20: rom_data = 32'h3C87A9C3;
            6'd21: rom_data = 32'h3C5D06EC;
            6'd22: rom_data = 32'h3C340D6C;
            6'd23: rom_data = 32'h3C12AC7F;
            6'd24: rom_data = 32'h3BEEF74E;
            6'd25: rom_data = 32'h3BC2AA75;
            6'd26: rom_data = 32'h3B9E9402;
            6'd27: rom_data = 32'h3B812E35;
            6'd28: rom_data = 32'h3B527720;
            6'd29: rom_data = 32'h3B2B72DD;
            6'd30: rom_data = 32'h3B0BAA41;
            6'd31: rom_data = 32'h3AE38C10;
            6'd32: rom_data = 32'h3AB95D22;
            6'd33: rom_data = 32'h3A970024;
            6'd34: rom_data = 32'h3A7603EA;
            6'd35: rom_data = 32'h3A486886;
            6'd36: rom_data = 32'h3A23418D;
            6'd37: rom_data = 32'h3A04FDBF;
            6'd38: rom_data = 32'h39D8AC81;
            6'd39: rom_data = 32'h39B08199;
            6'd40: rom_data = 32'h398FC8F8;
            6'd41: rom_data = 32'h396A4270;
            6'd42: rom_data = 32'h393ED4F4;
            6'd43: rom_data = 32'h391B7475;
            6'd44: rom_data = 32'h38FD45C2;
            6'd45: rom_data = 32'h38CE51F5;
            6'd46: rom_data = 32'h38A8126B;
            6'd47: rom_data = 32'h3888EA10;
            6'd48: rom_data = 32'h385F10C4;
            6'd49: rom_data = 32'h3835B687;
            6'd50: rom_data = 32'h381406CB;
            6'd51: rom_data = 32'h37F12B81;
            6'd52: rom_data = 32'h37C47611;
            6'd53: rom_data = 32'h37A00A69;
            6'd54: rom_data = 32'h37825F34;
            6'd55: rom_data = 32'h37546808;
            6'd56: rom_data = 32'h372D07A7;
            6'd57: rom_data = 32'h370CF401;
            6'd58: rom_data = 32'h36E5A54D;
            6'd59: rom_data = 32'h36BB12C7;
            6'd60: rom_data = 32'h369864A7;
            6'd61: rom_data = 32'h367848C2;
            6'd62: rom_data = 32'h364A41B0;
            6'd63: rom_data = 32'h3624C2FF;
            default: rom_data = 32'h3F800000;
        endcase
    end

endmodule

`default_nettype wire
