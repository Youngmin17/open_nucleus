// SPDX-License-Identifier: Apache-2.0
module bitmask_transposer (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          int2_or_int4_mode,
    input  wire          in_vld,
    input  wire [2047:0] in_data,
    output reg           out_vld,
    output reg  [2047:0] out_data
);

    reg [127:0] mem [0:127];

    reg first_setting;

    reg read_mode, write_mode;

    reg [2:0] in_cnt;

    reg [3:0] out_cnt;
    reg out_done;

    integer i, j;

    wire read_en = read_mode == write_mode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_mode    <= 1'b0;
            in_cnt     <= 3'd0;
        end else begin
            if (in_vld) begin
                if (in_cnt == 3'd7) begin
                    in_cnt <= 3'd0;
                    write_mode <= ~write_mode;
                end else begin
                    in_cnt <= in_cnt + 3'd1;
                end

                if (!write_mode) begin
                    for (j = 0; j < 16; j = j + 1) begin
                        mem[in_cnt * 16 + j] <= in_data[j * 128 +: 128];
                    end
                end else begin
                    for (i = 0; i < 128; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            mem[i][in_cnt * 16 + j] <= in_data[j * 128 + i];
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_cnt <= 4'd0;
            out_done <= 1'b0;
            out_vld  <= 1'b0;
            out_data <= {2048{1'b0}};
            read_mode <= 1'b0;
            first_setting <= 1'b0;

        end else begin
            out_vld <= 1'b0;
            out_done <= 1'b0;

            if(!first_setting) begin
                first_setting <= 1'b1;
                read_mode <= 1'b1;
            end else if(read_en) begin
                out_vld <= int2_or_int4_mode ? !out_cnt[0] : 1'b1;
                out_cnt <= out_cnt + 4'd1;
                if ((!int2_or_int4_mode && out_cnt == 4'd7) || (int2_or_int4_mode && out_cnt == 4'd15)) begin
                    out_cnt <= 4'd0;
                    out_done <= 1'b1;
                    read_mode <= ~read_mode;
                end
                if (!read_mode) begin
                    for (j = 0; j < 16; j = j + 1) begin
                        out_data[j * 128 +: 128] <= !int2_or_int4_mode ? mem[out_cnt * 16 + j] : mem[out_cnt[3:1] * 16 + j];
                    end
                end else begin
                    for (i = 0; i < 128; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            out_data[j * 128 + i] <= !int2_or_int4_mode ? mem[i][out_cnt * 16 + j] : mem[i][out_cnt[3:1] * 16 + j];
                        end
                    end
                end
            end
        end
    end

endmodule