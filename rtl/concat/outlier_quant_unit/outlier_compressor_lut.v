// SPDX-License-Identifier: Apache-2.0
module outlier_compressor_lut (
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire [6:0] outlier_num,
    output reg [7:0] compress_bits,
    output reg [13:0] out_shift_bits,
    output reg [10:0] bookmark_capacity
);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            compress_bits <= 8'd0;
            out_shift_bits <= 14'd0;
            bookmark_capacity <= 11'd0;
        end else begin
            if(isa_valid) begin
                case(outlier_num)
                    7'd0: begin
                        compress_bits <= 8'd0;
                        out_shift_bits <= 14'd0;
                        bookmark_capacity <= 11'd0;
                    end
                    7'd3, 7'd4, 7'd5,
                    7'd123, 7'd124, 7'd125: begin
                        compress_bits <= 8'd32;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd256;
                    end
                    7'd6, 7'd7, 7'd8, 7'd9,
                    7'd119, 7'd120, 7'd121, 7'd122: begin
                        compress_bits <= 8'd46;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd176;
                    end
                    7'd10, 7'd11, 7'd12, 7'd13, 7'd14, 7'd15,
                    7'd113, 7'd114, 7'd115, 7'd116, 7'd117, 7'd118: begin
                        compress_bits <= 8'd64;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd128;
                    end
                    7'd16, 7'd17, 7'd18,
                    7'd110, 7'd111, 7'd112: begin
                        compress_bits <= 8'd73;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd112;
                    end
                    7'd21, 7'd22, 7'd23,
                    7'd105, 7'd106, 7'd107: begin
                        compress_bits <= 8'd85;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd96;
                    end
                    7'd29, 7'd30, 7'd31, 7'd32,
                    7'd96, 7'd97, 7'd98, 7'd99: begin
                        compress_bits <= 8'd102;
                        out_shift_bits <= 14'd8192;
                        bookmark_capacity <= 11'd80;
                    end
                    default: begin
                        compress_bits <= 8'd0;
                        out_shift_bits <= 14'd0;
                        bookmark_capacity <= 11'd0;
                    end
                endcase
            end
        end
    end

endmodule