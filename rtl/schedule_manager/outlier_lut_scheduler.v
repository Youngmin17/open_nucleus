// SPDX-License-Identifier: Apache-2.0
module outlier_lut_scheduler (
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire [6:0] outlier_num,
    output reg [6:0] outlier_pos_length,
    output reg [6:0] outlier_val_length
);

    wire [7:0] effective_k = (outlier_num <= 7'd64) ? {1'b0, outlier_num} : (8'd128 - {1'b0, outlier_num});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outlier_pos_length <= 7'd0;
        end else if (isa_valid) begin
            if (effective_k[6:0] == 7'd0)
                outlier_pos_length <= 7'd0;
            else if (effective_k[6:0] <= 7'd2)
                outlier_pos_length <= 7'd1;
            else if (effective_k[6:0] <= 7'd5)
                outlier_pos_length <= 7'd2;
            else if (effective_k[6:0] <= 7'd9)
                outlier_pos_length <= 7'd3;
            else if (effective_k[6:0] <= 7'd15)
                outlier_pos_length <= 7'd4;
            else if (effective_k[6:0] <= 7'd20)
                outlier_pos_length <= 7'd5;
            else if (effective_k[6:0] <= 7'd28)
                outlier_pos_length <= 7'd6;
            else if (effective_k[6:0] <= 7'd32)
                outlier_pos_length <= 7'd7;
            else
                outlier_pos_length <= 7'd8;
        end
    end

    wire [7:0] outlier_num_plus7 = {1'b0, outlier_num} + 8'd7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outlier_val_length <= 7'd0;
        end else if (isa_valid) begin
            if (outlier_num == 7'd0)
                outlier_val_length <= 7'd0;
            else
                outlier_val_length <= {2'b0, outlier_num_plus7[7:3]};
        end
    end

endmodule