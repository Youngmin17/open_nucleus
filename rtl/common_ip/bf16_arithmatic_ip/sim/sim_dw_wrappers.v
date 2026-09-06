// SPDX-License-Identifier: Apache-2.0
`timescale 1ns/1ps

module DW_fp_add_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter en_ubr_flag     = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input  [2:0]                   inst_rnd,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_add #(.sig_width(sig_width), .exp_width(exp_width),
                .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_sub_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter en_ubr_flag     = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input  [2:0]                   inst_rnd,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_sub #(.sig_width(sig_width), .exp_width(exp_width),
                .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_mult_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 1,
    parameter en_ubr_flag     = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input  [2:0]                   inst_rnd,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_mult #(.sig_width(sig_width), .exp_width(exp_width),
                 .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_div_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter faithful_round  = 0,
    parameter en_ubr_flag     = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input  [2:0]                   inst_rnd,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_div #(.sig_width(sig_width), .exp_width(exp_width),
                .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_addsub_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter en_ubr_flag     = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input  [2:0]                   inst_rnd,
    input                          inst_op,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_addsub #(.sig_width(sig_width), .exp_width(exp_width),
                   .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .rnd(inst_rnd), .op(inst_op),
         .z(z_inst), .status(status_inst));
endmodule

module DW_fp_cmp_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0
)(
    input  [sig_width+exp_width:0] inst_a,
    input  [sig_width+exp_width:0] inst_b,
    input                          inst_zctr,
    output                         aeqb_inst,
    output                         altb_inst,
    output                         agtb_inst,
    output                         unordered_inst,
    output [sig_width+exp_width:0] z0_inst,
    output [sig_width+exp_width:0] z1_inst,
    output [7:0]                   status0_inst,
    output [7:0]                   status1_inst
);
    DW_fp_cmp #(.sig_width(sig_width), .exp_width(exp_width),
                .ieee_compliance(ieee_compliance)) U1
        (.a(inst_a), .b(inst_b), .zctr(inst_zctr),
         .aeqb(aeqb_inst), .altb(altb_inst), .agtb(agtb_inst),
         .unordered(unordered_inst), .z0(z0_inst), .z1(z1_inst),
         .status0(status0_inst), .status1(status1_inst));
endmodule

module DW_fp_sqrt_inst #(
    parameter inst_sig_width       = 7,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0
)(
    input  [inst_sig_width+inst_exp_width:0] inst_a,
    input  [2:0]                             inst_rnd,
    output [inst_sig_width+inst_exp_width:0] z_inst,
    output [7:0]                             status_inst
);
    DW_fp_sqrt #(.sig_width(inst_sig_width), .exp_width(inst_exp_width),
                 .ieee_compliance(inst_ieee_compliance)) U1
        (.a(inst_a), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_exp_inst #(
    parameter inst_sig_width       = 7,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 2
)(
    input  [inst_sig_width+inst_exp_width:0] inst_a,
    output [inst_sig_width+inst_exp_width:0] z_inst,
    output [7:0]                             status_inst
);
    DW_fp_exp #(.sig_width(inst_sig_width), .exp_width(inst_exp_width),
                .ieee_compliance(inst_ieee_compliance), .arch(inst_arch)) U1
        (.a(inst_a), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_exp2_inst #(
    parameter inst_sig_width       = 7,
    parameter inst_exp_width       = 8,
    parameter inst_ieee_compliance = 0,
    parameter inst_arch            = 2
)(
    input  [inst_sig_width+inst_exp_width:0] inst_a,
    output [inst_sig_width+inst_exp_width:0] z_inst,
    output [7:0]                             status_inst
);
    DW_fp_exp2 #(.sig_width(inst_sig_width), .exp_width(inst_exp_width),
                 .ieee_compliance(inst_ieee_compliance), .arch(inst_arch)) U1
        (.a(inst_a), .z(z_inst), .status(status_inst));
endmodule

module DW_fp_sincos_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter pi_multiple     = 1,
    parameter arch            = 0,
    parameter err_range       = 1
)(
    input  [sig_width+exp_width:0] inst_a,
    input                          inst_sin_cos,
    output [sig_width+exp_width:0] z_inst,
    output [7:0]                   status_inst
);
    DW_fp_sincos #(.sig_width(sig_width), .exp_width(exp_width),
                   .ieee_compliance(ieee_compliance), .pi_multiple(pi_multiple),
                   .arch(arch), .err_range(err_range)) U1
        (.a(inst_a), .sin_cos(inst_sin_cos), .z(z_inst), .status(status_inst));
endmodule

module DW_fp32_add_inst (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  rnd,
    output wire [31:0] z,
    output wire [7:0]  status
);
    DW_fp_add #(.sig_width(23), .exp_width(8), .ieee_compliance(1)) u_fp32_add
        (.a(a), .b(b), .rnd(rnd), .z(z), .status(status));
endmodule

module DW_fp32_mult_pipe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  rnd,
    input  wire        in_vld,
    output reg  [31:0] z,
    output reg         out_vld
);
    wire [31:0] z_comb;
    wire [7:0]  status_comb;
    DW_fp_mult #(.sig_width(23), .exp_width(8), .ieee_compliance(0)) u_fp32_mult
        (.a(a), .b(b), .rnd(rnd), .z(z_comb), .status(status_comb));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z       <= 32'd0;
            out_vld <= 1'b0;
        end else begin
            z       <= z_comb;
            out_vld <= in_vld;
        end
    end
endmodule

module DW_fp32_sincos_pipe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] a,
    input  wire        sin_cos,
    input  wire        in_vld,
    output wire [31:0] z,
    output wire        out_vld
);
    wire [31:0] z_comb;
    wire [7:0]  status_comb;
    DW_fp_sincos #(.sig_width(23), .exp_width(8), .ieee_compliance(1),
                   .pi_multiple(0), .arch(0), .err_range(1)) u_fp32_sincos
        (.a(a), .sin_cos(sin_cos), .z(z_comb), .status(status_comb));

    reg [31:0] pipe_z [0:6];
    reg        pipe_v [0:6];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 7; i = i + 1) begin
                pipe_z[i] <= 32'd0;
                pipe_v[i] <= 1'b0;
            end
        end else begin
            pipe_z[0] <= z_comb;
            pipe_v[0] <= in_vld;
            for (i = 1; i < 7; i = i + 1) begin
                pipe_z[i] <= pipe_z[i-1];
                pipe_v[i] <= pipe_v[i-1];
            end
        end
    end
    assign z       = pipe_z[6];
    assign out_vld = pipe_v[6];
endmodule

module DW_lp_piped_fp_div_inst #(
    parameter sig_width       = 7,
    parameter exp_width       = 8,
    parameter ieee_compliance = 0,
    parameter faithful_round  = 0,
    parameter op_iso_mode     = 0,
    parameter id_width        = 2,
    parameter in_reg          = 1,
    parameter stages          = 5,
    parameter out_reg         = 1,
    parameter no_pm           = 1,
    parameter rst_mode        = 0
)(
    input                           inst_clk,
    input                           inst_rst_n,
    input  [sig_width+exp_width:0]  inst_a,
    input  [sig_width+exp_width:0]  inst_b,
    input  [2:0]                    inst_rnd,
    output [sig_width+exp_width:0]  z_inst,
    output [7:0]                    status_inst,
    input                           inst_launch,
    input  [id_width-1:0]           inst_launch_id,
    output                          pipe_full_inst,
    output                          pipe_ovf_inst,
    input                           inst_accept_n,
    output                          arrive_inst,
    output [id_width-1:0]           arrive_id_inst,
    output                          push_out_n_inst,
    output [7:0]                    pipe_census_inst
);
    reg                          launch_q;
    reg [sig_width+exp_width:0]  a_q;
    reg [sig_width+exp_width:0]  b_q;
    reg [id_width-1:0]           id_q;

    always @(posedge inst_clk or negedge inst_rst_n) begin
        if (!inst_rst_n) begin
            launch_q <= 1'b0;
            a_q      <= {sig_width+exp_width+1{1'b0}};
            b_q      <= {sig_width+exp_width+1{1'b0}};
            id_q     <= {id_width{1'b0}};
        end else begin
            launch_q <= inst_launch & ~inst_accept_n;
            if (inst_launch & ~inst_accept_n) begin
                a_q  <= inst_a;
                b_q  <= inst_b;
                id_q <= inst_launch_id;
            end
        end
    end

    assign arrive_inst      = launch_q;
    assign arrive_id_inst   = id_q;
    assign pipe_full_inst   = 1'b0;
    assign pipe_ovf_inst    = 1'b0;
    assign push_out_n_inst  = 1'b0;
    assign pipe_census_inst = 8'd0;

    DW_fp_div #(.sig_width(sig_width), .exp_width(exp_width),
                .ieee_compliance(ieee_compliance)) U_DW_DIV
        (.a(a_q), .b(b_q), .rnd(inst_rnd), .z(z_inst), .status(status_inst));
endmodule

module DW_ram_r_w_s_dff #(
    parameter data_width = 8,
    parameter depth      = 8,
    parameter rst_mode   = 0
)(
    input                          clk,
    input                          rst_n,
    input                          cs_n,
    input                          wr_n,
    input  [$clog2(depth)-1:0]     rd_addr,
    input  [$clog2(depth)-1:0]     wr_addr,
    input  [data_width-1:0]        data_in,
    output [data_width-1:0]        data_out
);
    reg [data_width-1:0] mem [0:depth-1];

    always @(posedge clk) begin
        if (!cs_n && !wr_n)
            mem[wr_addr] <= data_in;
    end

    assign data_out = mem[rd_addr];
endmodule
