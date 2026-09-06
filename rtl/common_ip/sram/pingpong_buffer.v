// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps
module pingpong_buffer
# (
    parameter DATA_WIDTH_BRAM = 2048,
    parameter AXI_CHNL = 128,
    parameter AXI_DATA_WIDTH = 16,
    parameter BUFFER_ADDR = 128
)
(
    input clk,
    input rst_n,
    input rewind,
    input one_shot,

    input [AXI_DATA_WIDTH*AXI_CHNL-1:0] up_dat,
    input up_vld,

    output [AXI_DATA_WIDTH*AXI_CHNL-1:0] dn_dat,
    output dn_vld
);

    localparam num_rams = (AXI_DATA_WIDTH*AXI_CHNL)/DATA_WIDTH_BRAM;

    reg [$clog2(BUFFER_ADDR):0] pingpong_we_cnt;
    reg pingpong_wen_sel;
    reg wen_done;

    always @(posedge clk)
    if(!rst_n) begin
        pingpong_we_cnt <= 0;
        pingpong_wen_sel <= 1'b0;
        wen_done <= 1'b0;
    end
    else begin
        if (up_vld) begin
            if (one_shot) begin
                pingpong_we_cnt <= 0;
                pingpong_wen_sel <= !pingpong_wen_sel;
                wen_done <= 1'b1;
            end else if (pingpong_we_cnt == BUFFER_ADDR-1) begin
                pingpong_we_cnt <= 0;
                pingpong_wen_sel <= !pingpong_wen_sel;
                wen_done <= 1'b1;
            end
            else begin
                pingpong_we_cnt <= pingpong_we_cnt + 1;
                pingpong_wen_sel <= pingpong_wen_sel;
                wen_done <= wen_done;
            end
        end
        else begin
            pingpong_we_cnt <= pingpong_we_cnt;
            pingpong_wen_sel <= pingpong_wen_sel;
            wen_done <= wen_done;
        end
    end

    reg write_vld_A;
    reg write_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] write_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] write_addr_B;
    reg [DATA_WIDTH_BRAM*num_rams-1:0] ram_up_dat_A;
    reg [DATA_WIDTH_BRAM*num_rams-1:0] ram_up_dat_B;

    always @(posedge clk)
    if (!rst_n) begin
        write_vld_A <= 1'b0;
        write_addr_A <= 0;
        ram_up_dat_A <= 0;

        write_vld_B <= 1'b0;
        write_addr_B <= 0;
        ram_up_dat_B <= 0;
    end
    else begin
        if (up_vld) begin
            if (pingpong_wen_sel) begin
                write_vld_A <= 1'b0;
                ram_up_dat_A <= 0;
                write_addr_A <= 0;

                write_vld_B <= 1'b1;
                ram_up_dat_B <= up_dat;
                write_addr_B <= one_shot ? 0 : (write_addr_B + 1);
            end
            else begin
                write_vld_A <= 1'b1;
                ram_up_dat_A <= up_dat;
                write_addr_A <= one_shot ? 0 : (write_addr_A + 1);

                write_vld_B <= 1'b0;
                ram_up_dat_B <= 0;
                write_addr_B <= 0;
            end
        end
        else begin
            write_vld_A <= 1'b0;
            write_addr_A <= write_addr_A;

            write_vld_B <= 1'b0;
            write_addr_B <= write_addr_B;
        end
    end

    reg [$clog2(BUFFER_ADDR):0] pingpong_re_cnt;
    reg pingpong_ren_sel;
    reg pingpong_ren_sel_next;

    wire read_adv_A;
    wire read_adv_B;
    wire read_adv_sel = (pingpong_ren_sel ? read_adv_B : read_adv_A);
    always @(*) begin
        pingpong_ren_sel_next = pingpong_ren_sel;
        if (!rst_n) begin
            pingpong_ren_sel_next = 1'b0;
        end else if (rewind) begin
            pingpong_ren_sel_next = ~pingpong_wen_sel;
        end else if (read_adv_sel && wen_done) begin
            if (pingpong_re_cnt == BUFFER_ADDR-1) begin
                pingpong_ren_sel_next = !pingpong_ren_sel;
            end else begin
                pingpong_ren_sel_next = pingpong_ren_sel;
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pingpong_re_cnt <= 0;
            pingpong_ren_sel <= 1'b0;
        end else begin
            if (rewind) begin
                pingpong_re_cnt <= 0;
            end else if (read_adv_sel && wen_done) begin
                if (pingpong_re_cnt == BUFFER_ADDR-1) begin
                    pingpong_re_cnt <= 0;
                end else begin
                    pingpong_re_cnt <= pingpong_re_cnt + 1;
                end
            end
            pingpong_ren_sel <= pingpong_ren_sel_next;
        end
    end

    reg read_vld_A;
    reg read_vld_B;
    reg [$clog2(BUFFER_ADDR)-1:0] read_addr_A;
    reg [$clog2(BUFFER_ADDR)-1:0] read_addr_B;
    reg pingpong_ren_sel_d;

    always @(posedge clk)
    if (!rst_n) begin
        read_vld_A <= 1'b0;
        read_addr_A <= 0;

        read_vld_B <= 1'b0;
        read_addr_B <= 0;
        pingpong_ren_sel_d <= 1'b0;
    end
    else begin
        if (rewind) begin
            read_addr_A <= 0;
            read_addr_B <= 0;
            if (~pingpong_wen_sel) begin
                read_vld_A <= 1'b1;
                read_vld_B <= 1'b0;
            end else begin
                read_vld_A <= 1'b0;
                read_vld_B <= 1'b1;
            end
            pingpong_ren_sel_d <= ~pingpong_wen_sel;
        end else begin
        if (pingpong_ren_sel != pingpong_ren_sel_d) begin
            if (pingpong_ren_sel) begin
                read_vld_A <= 1'b0;
                read_addr_B <= 0;
                read_vld_B <= 1'b1;
            end else begin
                read_vld_B <= 1'b0;
                read_addr_A <= 0;
                read_vld_A <= 1'b1;
            end
            pingpong_ren_sel_d <= pingpong_ren_sel;
        end else if (wen_done) begin
            if (pingpong_ren_sel) begin
                if (read_adv_B && !one_shot) read_addr_B <= read_addr_B + 1;
                read_vld_B <= 1'b1;
                read_vld_A <= 1'b0;
            end else begin
                if (read_adv_A && !one_shot) read_addr_A <= read_addr_A + 1;
                read_vld_A <= 1'b1;
                read_vld_B <= 1'b0;
            end
        end else begin
            read_vld_A <= read_vld_A;
            read_vld_B <= read_vld_B;
        end
        end
    end

    wire [DATA_WIDTH_BRAM*num_rams-1:0] ram_dn_dat_A;
    wire [DATA_WIDTH_BRAM*num_rams-1:0] ram_dn_dat_B;
    wire ram_dn_vld_A;
    wire ram_dn_vld_B;
    wire [num_rams*$clog2(BUFFER_ADDR)-1:0] read_addr_r_A_w;
    wire [num_rams*$clog2(BUFFER_ADDR)-1:0] read_addr_r_B_w;

    pingpong_ram_2d # (
        .num_rams(num_rams),
        .w(DATA_WIDTH_BRAM),
        .d(BUFFER_ADDR)
    )
    u_pingpong_ram_2d (
        .clk(clk),
        .rst_n(rst_n),

        .wen_A(write_vld_A),
        .write_addr_A({num_rams{write_addr_A}}),
        .din_A(ram_up_dat_A),
        .ren_A(read_vld_A),
        .read_addr_A({num_rams{read_addr_A}}),
        .read_addr_r_A(read_addr_r_A_w),
        .dout_vld_A(ram_dn_vld_A),
        .dout_A(ram_dn_dat_A),

        .wen_B(write_vld_B),
        .write_addr_B({num_rams{write_addr_B}}),
        .din_B(ram_up_dat_B),
        .ren_B(read_vld_B),
        .read_addr_B({num_rams{read_addr_B}}),
        .read_addr_r_B(read_addr_r_B_w),
        .dout_vld_B(ram_dn_vld_B),
        .dout_B(ram_dn_dat_B)
    );
    assign read_adv_A = ram_dn_vld_A;
    assign read_adv_B = ram_dn_vld_B;

    reg [AXI_DATA_WIDTH*AXI_CHNL-1:0] dn_dat_r;
    reg dn_vld_r;

    always @(posedge clk)
    if (!rst_n) begin
        dn_vld_r <= 0;
        dn_dat_r <= 0;
    end
    else begin
        if (pingpong_ren_sel) begin
            dn_vld_r <= ram_dn_vld_B;
            if (ram_dn_vld_B) dn_dat_r <= ram_dn_dat_B;
        end else begin
            dn_vld_r <= ram_dn_vld_A;
            if (ram_dn_vld_A) dn_dat_r <= ram_dn_dat_A;
        end
    end

    assign dn_vld = dn_vld_r;
    assign dn_dat = dn_dat_r;

endmodule
