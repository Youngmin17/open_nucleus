// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps
`default_nettype wire

module scale_zp_register #(
    parameter AXI_CHNL = 128,
    parameter DATA_WIDTH = 16,
    parameter DATA_WIDTH_IN = 4096,
    parameter DATA_WIDTH_OUT = 4096
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire isa_valid,
    input  wire [1:0] group_width,
    input  wire in_vld,
    input  wire buf_change,
    input  wire [1024-1:0] scale_din,
    input  wire [2048-1:0] zp_din,
    output wire [4096-1:0] scale_dout,
    output wire [8192-1:0] zp_dout,
    output wire            zp_read_valid
);

    reg [4096-1:0] mem_sc2, mem_sc1 , mem_sc0;
    reg [8192-1:0] mem_zp2, mem_zp1, mem_zp0;
    reg [1:0] write_buf_sel;
    reg [1:0] fmat_buf_sel;
    reg [1:0] beat_cnt;
`ifdef PERCOL_SCALE
    reg       roll_write_pending;
`endif

    wire [1:0] total_beats = (group_width == 2'b01) ? 2'd3 :
                             (group_width == 2'b10) ? 2'd1 :
                             2'd0;

`ifdef PERCOL_SCALE
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_sc2 <= 4096'b0;
            mem_zp2 <= 8192'b0;
            mem_sc1 <= 4096'b0;
            mem_zp1 <= 8192'b0;
            mem_sc0 <= 4096'b0;
            mem_zp0 <= 8192'b0;
            write_buf_sel <= 2'b00;
            fmat_buf_sel <= 2'b00;
            beat_cnt <= 2'd0;
            roll_write_pending <= 1'b0;
        end else if (isa_valid) begin
            write_buf_sel <= 2'b00;
            fmat_buf_sel <= 2'b00;
            beat_cnt <= 2'd0;
            roll_write_pending <= 1'b0;
        end else begin
            if (in_vld) begin
                if (roll_write_pending) begin
                    roll_write_pending <= 1'b0;
                    write_buf_sel <= (write_buf_sel == 2'b10) ? 2'b00 : write_buf_sel + 2'd1;
                    if (write_buf_sel == 2'b10) begin
                        mem_sc0[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp0[2048*beat_cnt +: 2048] <= zp_din;
                    end else if (write_buf_sel == 2'b00) begin
                        mem_sc1[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp1[2048*beat_cnt +: 2048] <= zp_din;
                    end else begin
                        mem_sc2[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp2[2048*beat_cnt +: 2048] <= zp_din;
                    end
                end else begin
                    if (write_buf_sel == 2'b00) begin
                        mem_sc0[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp0[2048*beat_cnt +: 2048] <= zp_din;
                    end else if (write_buf_sel == 2'b01) begin
                        mem_sc1[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp1[2048*beat_cnt +: 2048] <= zp_din;
                    end else begin
                        mem_sc2[1024*beat_cnt +: 1024] <= scale_din;
                        mem_zp2[2048*beat_cnt +: 2048] <= zp_din;
                    end
                end
                if (beat_cnt == total_beats) begin
                    beat_cnt <= 2'd0;
                end else begin
                    beat_cnt <= beat_cnt + 2'd1;
                end
            end
            if (buf_change) begin
                fmat_buf_sel <= (fmat_buf_sel == 2'b10) ? 2'b00 : fmat_buf_sel + 2'd1;
                roll_write_pending <= 1'b1;
                beat_cnt <= 2'd0;
            end
        end
    end
`else
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_sc2 <= 4096'b0;
            mem_zp2 <= 8192'b0;
            mem_sc1 <= 4096'b0;
            mem_zp1 <= 8192'b0;
            mem_sc0 <= 4096'b0;
            mem_zp0 <= 8192'b0;
            write_buf_sel <= 1'b0;
            fmat_buf_sel <= 1'b0;
            beat_cnt <= 2'd0;
        end else if (isa_valid) begin
            write_buf_sel <= 1'b0;
            fmat_buf_sel <= 1'b0;
            beat_cnt <= 2'd0;
        end else begin
            if (in_vld) begin
                if (write_buf_sel == 2'b00) begin
                    mem_sc0[1024*beat_cnt +: 1024] <= scale_din;
                    mem_zp0[2048*beat_cnt +: 2048] <= zp_din;
                end else if (write_buf_sel == 2'b01) begin
                    mem_sc1[1024*beat_cnt +: 1024] <= scale_din;
                    mem_zp1[2048*beat_cnt +: 2048] <= zp_din;
                end else if (write_buf_sel == 2'b10) begin
                    mem_sc2[1024*beat_cnt +: 1024] <= scale_din;
                    mem_zp2[2048*beat_cnt +: 2048] <= zp_din;
                end

                if (beat_cnt == total_beats) begin
                    beat_cnt <= 2'd0;
                    write_buf_sel <= write_buf_sel + 2'd1;
                    if(write_buf_sel == 2'b10) begin
                        write_buf_sel <= 2'b00;
                    end
                end else begin
                    beat_cnt <= beat_cnt + 2'd1;
                end
            end
            if (buf_change) begin
                fmat_buf_sel <= fmat_buf_sel + 2'd1;
                if(fmat_buf_sel == 2'b10) begin
                    fmat_buf_sel <= 2'b00;
                end
            end
        end
    end
`endif

    wire [4095:0] mem_sc0_dout = group_width == 2'b01 ? mem_sc0[4095:0] :
                                 group_width == 2'b10 ? {mem_sc0[2047:1024], mem_sc0[2047:1024], mem_sc0[1023:0], mem_sc0[1023:0]} :
                                 group_width == 2'b11 ? {mem_sc0[1023:0], mem_sc0[1023:0], mem_sc0[1023:0], mem_sc0[1023:0]} :
                                 4096'b0;

    wire [4095:0] mem_sc1_dout = group_width == 2'b01 ? mem_sc1[4095:0] :
                                 group_width == 2'b10 ? {mem_sc1[2047:1024], mem_sc1[2047:1024], mem_sc1[1023:0], mem_sc1[1023:0]} :
                                 group_width == 2'b11 ? {mem_sc1[1023:0], mem_sc1[1023:0], mem_sc1[1023:0], mem_sc1[1023:0]} :
                                 4096'b0;

    wire [4095:0] mem_sc2_dout = group_width == 2'b01 ? mem_sc2[4095:0] :
                                 group_width == 2'b10 ? {mem_sc2[2047:1024], mem_sc2[2047:1024], mem_sc2[1023:0], mem_sc2[1023:0]} :
                                 group_width == 2'b11 ? {mem_sc2[1023:0], mem_sc2[1023:0], mem_sc2[1023:0], mem_sc2[1023:0]} :
                                 4096'b0;

    wire [8191:0] mem_zp0_dout = group_width == 2'b01 ? mem_zp0[8191:0] :
                                 group_width == 2'b10 ? {mem_zp0[4095:2048], mem_zp0[4095:2048], mem_zp0[2047:0], mem_zp0[2047:0]} :
                                 group_width == 2'b11 ? {mem_zp0[2047:0], mem_zp0[2047:0], mem_zp0[2047:0], mem_zp0[2047:0]} :
                                 8192'b0;

    wire [8191:0] mem_zp1_dout = group_width == 2'b01 ? mem_zp1[8191:0] :
                                 group_width == 2'b10 ? {mem_zp1[4095:2048], mem_zp1[4095:2048], mem_zp1[2047:0], mem_zp1[2047:0]} :
                                 group_width == 2'b11 ? {mem_zp1[2047:0], mem_zp1[2047:0], mem_zp1[2047:0], mem_zp1[2047:0]} :
                                 8192'b0;

    wire [8191:0] mem_zp2_dout = group_width == 2'b01 ? mem_zp2[8191:0] :
                                 group_width == 2'b10 ? {mem_zp2[4095:2048], mem_zp2[4095:2048], mem_zp2[2047:0], mem_zp2[2047:0]} :
                                 group_width == 2'b11 ? {mem_zp2[2047:0], mem_zp2[2047:0], mem_zp2[2047:0], mem_zp2[2047:0]} :
                                 8192'b0;

    assign scale_dout = fmat_buf_sel == 2'b00 ? mem_sc0_dout :
                        fmat_buf_sel == 2'b01 ? mem_sc1_dout :
                        mem_sc2_dout;
    assign zp_dout = fmat_buf_sel == 2'b00 ? mem_zp0_dout :
                     fmat_buf_sel == 2'b01 ? mem_zp1_dout :
                     mem_zp2_dout;

`ifdef PERCOL_ZP
    assign zp_read_valid = !roll_write_pending;
`else
    assign zp_read_valid = 1'b1;
`endif

endmodule

`default_nettype wire
