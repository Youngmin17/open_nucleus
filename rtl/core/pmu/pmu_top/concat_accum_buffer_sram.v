// SPDX-License-Identifier: Apache-2.0
`timescale 1ns / 1ps

module concat_accum_buffer_sram
#(
    parameter DATA_WIDTH  = 16,
    parameter ACC_WIDTH   = 24,
    parameter DATA_NUM    = 128,
    parameter BUFFER_ADDR = 128,
    parameter LOOP_NUM    = 2
)
(
    input  wire                              clk,
    input  wire                              rst_n,

    input  wire                              clear,

    input  wire [$clog2(BUFFER_ADDR)-1:0]    acc_addr,
    input  wire [2*ACC_WIDTH*DATA_NUM-1:0]   acc_data,
    input  wire                              acc_valid,
    input  wire                              overwrite,
    input  wire                              residual_phase,
    input  wire                              is_gemv_proj,

    input  wire                              ren,
    input  wire [$clog2(BUFFER_ADDR)-1:0]    raddr,
    output wire [DATA_WIDTH*DATA_NUM-1:0]    rdata,
    output reg                               rvalid,

    output wire                              pip_empty
);

    localparam ELEM_NUM         = 2 * DATA_NUM;
    localparam ADDER_NUM        = ELEM_NUM;
    localparam ROW_WIDTH        = ACC_WIDTH * DATA_NUM;
    localparam WIDE_WIDTH       = 2 * ROW_WIDTH;
    localparam EXT_ADDR_WIDTH   = $clog2(BUFFER_ADDR);
    localparam INT_DEPTH        = BUFFER_ADDR / 2;
    localparam INT_ADDR_WIDTH   = $clog2(INT_DEPTH);
    localparam ADD_PREC         = ACC_WIDTH;
    localparam SRAM_WIDTH       = ADD_PREC * ELEM_NUM;

    genvar i;
    integer l;

    reg clear_flag;
    reg rst_flag;

    reg [ROW_WIDTH-1:0]           even_data_latch;
    reg                           even_latched;

    reg [INT_ADDR_WIDTH-1:0]      res1_counter;

    reg [WIDE_WIDTH-1:0]          acc_data_pip1, acc_data_pip2;
    reg [INT_ADDR_WIDTH-1:0]      acc_int_addr_pip1, acc_int_addr_pip2;
    reg                           acc_valid_pip1, acc_valid_pip2, acc_valid_pip3;

    reg [INT_ADDR_WIDTH-1:0]      read_int_addr;
    reg                           read_half_sel;
    reg                           read_half_sel_pip1;
    reg                           ren_pip1;

    localparam SKID_DEPTH = 2;
    reg [WIDE_WIDTH-1:0]          rmw_skid_data [0:SKID_DEPTH-1];
    reg [INT_ADDR_WIDTH-1:0]      rmw_skid_addr [0:SKID_DEPTH-1];
    reg                           rmw_skid_ovw  [0:SKID_DEPTH-1];
    reg [1:0]                     rmw_skid_cnt;

    reg [ADD_PREC*ELEM_NUM-1:0]   inst1_reg1, inst2_reg1;
    reg [ADD_PREC*ELEM_NUM-1:0]   inst1_reg2, inst2_reg2;
    reg [INT_ADDR_WIDTH-1:0]      dest_addr1, dest_addr2;
    reg                           add_start;

    reg                           sram_in_vld_add;
    reg [INT_ADDR_WIDTH-1:0]      sram_in_addr_add;
    reg [INT_ADDR_WIDTH-1:0]      sram_in_addr_clear;
    reg [SRAM_WIDTH-1:0]          sram_data_in;
    wire                          sram_in_vld  = sram_in_vld_add ? 1'b1 : clear_flag;
    wire [INT_ADDR_WIDTH-1:0]     sram_in_addr = sram_in_vld_add ? sram_in_addr_add : sram_in_addr_clear;

    wire [SRAM_WIDTH-1:0]         rdata_tmp;

    assign pip_empty = !acc_valid_pip1 && !acc_valid_pip2 && !acc_valid_pip3;

    generate
        for(i = 0; i < DATA_NUM; i = i + 1) begin : rdata_lo
            assign rdata[DATA_WIDTH*i +: DATA_WIDTH] =
                read_half_sel_pip1 ?
                    rdata_tmp[ADD_PREC*(DATA_NUM + i) + ADD_PREC - DATA_WIDTH +: DATA_WIDTH] :
                    rdata_tmp[ADD_PREC*i             + ADD_PREC - DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    reg                     acc_internal_vld;
    reg                     overwrite_internal;
    reg                     overwrite_pip1, overwrite_pip2;
    reg [WIDE_WIDTH-1:0]    acc_internal_data;
    reg [INT_ADDR_WIDTH-1:0] acc_internal_addr;

    wire rmw_sel_skid = (rmw_skid_cnt != 2'd0);
    wire rmw_fire     = !ren && (rmw_sel_skid || acc_internal_vld);
    wire rmw_pop      = rmw_fire && rmw_sel_skid;
    wire rmw_push     = acc_internal_vld && (ren || rmw_sel_skid);
    wire [WIDE_WIDTH-1:0]     rmw_data_mux = rmw_sel_skid ? rmw_skid_data[0] : acc_internal_data;
    wire [INT_ADDR_WIDTH-1:0] rmw_addr_mux = rmw_sel_skid ? rmw_skid_addr[0] : acc_internal_addr;
    wire                      rmw_ovw_mux  = rmw_sel_skid ? rmw_skid_ovw[0]  : overwrite_internal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            even_data_latch  <= {ROW_WIDTH{1'b0}};
            even_latched     <= 1'b0;
            res1_counter     <= {INT_ADDR_WIDTH{1'b0}};
            acc_internal_vld <= 1'b0;
            overwrite_internal <= 1'b0;
            acc_internal_data <= {WIDE_WIDTH{1'b0}};
            acc_internal_addr <= {INT_ADDR_WIDTH{1'b0}};
        end else begin
            acc_internal_vld <= 1'b0;
            overwrite_internal <= 1'b0;

            if (clear) begin
                even_data_latch  <= {ROW_WIDTH{1'b0}};
                even_latched     <= 1'b0;
                res1_counter     <= {INT_ADDR_WIDTH{1'b0}};
            end else if (acc_valid) begin
                if (!residual_phase) begin
                    if (is_gemv_proj) begin
                        acc_internal_data <= acc_addr[0] ?
                            {acc_data[ROW_WIDTH-1:0], {ROW_WIDTH{1'b0}}} :
                            {{ROW_WIDTH{1'b0}}, acc_data[ROW_WIDTH-1:0]};
                        acc_internal_addr <= acc_addr[EXT_ADDR_WIDTH-1:1];
                        acc_internal_vld  <= 1'b1; overwrite_internal <= overwrite;
                    end else if (!acc_addr[0]) begin
                        even_data_latch <= acc_data[ROW_WIDTH-1:0];
                        even_latched    <= 1'b1;
                    end else begin
                        acc_internal_data <= {acc_data[ROW_WIDTH-1:0], even_data_latch};
                        acc_internal_addr <= acc_addr[EXT_ADDR_WIDTH-1:1];
                        acc_internal_vld  <= 1'b1; overwrite_internal <= overwrite;
                        even_latched      <= 1'b0;
                    end
                end else begin
                    acc_internal_data <= acc_data;
                    acc_internal_addr <= {acc_addr[EXT_ADDR_WIDTH-1:EXT_ADDR_WIDTH-2],
                                          res1_counter[INT_ADDR_WIDTH-3:0]};
                    acc_internal_vld  <= 1'b1;
                    res1_counter      <= res1_counter + 1'b1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_data_pip1     <= {WIDE_WIDTH{1'b0}};
            acc_data_pip2     <= {WIDE_WIDTH{1'b0}};
            acc_int_addr_pip1 <= {INT_ADDR_WIDTH{1'b0}};
            acc_int_addr_pip2 <= {INT_ADDR_WIDTH{1'b0}};
            acc_valid_pip1    <= 1'b0;
            acc_valid_pip2    <= 1'b0;
            overwrite_pip1    <= 1'b0;
            overwrite_pip2    <= 1'b0;
            acc_valid_pip3    <= 1'b0;
            read_int_addr     <= {INT_ADDR_WIDTH{1'b0}};
            read_half_sel     <= 1'b0;
            read_half_sel_pip1 <= 1'b0;
            ren_pip1          <= 1'b0;
            rmw_skid_cnt      <= 2'd0;
            for (l = 0; l < SKID_DEPTH; l = l + 1) begin
                rmw_skid_data[l] <= {WIDE_WIDTH{1'b0}};
                rmw_skid_addr[l] <= {INT_ADDR_WIDTH{1'b0}};
                rmw_skid_ovw[l]  <= 1'b0;
            end
            inst1_reg1        <= {ADD_PREC*ELEM_NUM{1'b0}};
            inst2_reg1        <= {ADD_PREC*ELEM_NUM{1'b0}};
            dest_addr1        <= {INT_ADDR_WIDTH{1'b0}};
            add_start         <= 1'b0;
            sram_in_addr_clear <= {INT_ADDR_WIDTH{1'b0}};
            clear_flag        <= 1'b0;
            rst_flag          <= 1'b0;
            rvalid            <= 1'b0;
        end else begin

            add_start <= 1'b0;

            acc_data_pip1     <= rmw_data_mux;
            acc_data_pip2     <= acc_data_pip1;
            acc_int_addr_pip1 <= rmw_addr_mux;
            acc_int_addr_pip2 <= acc_int_addr_pip1;
            acc_valid_pip1    <= rmw_fire;
            acc_valid_pip2    <= acc_valid_pip1;
            acc_valid_pip3    <= acc_valid_pip2;
            overwrite_pip1    <= rmw_ovw_mux;
            overwrite_pip2    <= overwrite_pip1;

            ren_pip1 <= ren;

            if (ren) begin
                read_int_addr <= raddr[EXT_ADDR_WIDTH-1:1];
                read_half_sel <= raddr[0];
            end else if (rmw_fire) begin
                read_int_addr <= rmw_addr_mux;
            end

            if (rmw_pop && rmw_skid_cnt == 2'd2) begin
                rmw_skid_data[0] <= rmw_skid_data[1];
                rmw_skid_addr[0] <= rmw_skid_addr[1];
                rmw_skid_ovw[0]  <= rmw_skid_ovw[1];
            end
            if (rmw_push) begin
                if (rmw_pop) begin
                    if (rmw_skid_cnt == 2'd2) begin
                        rmw_skid_data[1] <= acc_internal_data;
                        rmw_skid_addr[1] <= acc_internal_addr;
                        rmw_skid_ovw[1]  <= overwrite_internal;
                    end else begin
                        rmw_skid_data[0] <= acc_internal_data;
                        rmw_skid_addr[0] <= acc_internal_addr;
                        rmw_skid_ovw[0]  <= overwrite_internal;
                    end
                end else if (rmw_skid_cnt != 2'd2) begin
                    rmw_skid_data[rmw_skid_cnt[0]] <= acc_internal_data;
                    rmw_skid_addr[rmw_skid_cnt[0]] <= acc_internal_addr;
                    rmw_skid_ovw[rmw_skid_cnt[0]]  <= overwrite_internal;
                end
                // synopsys translate_off
                if (rmw_skid_cnt == 2'd2 && !rmw_pop)
                    $display("[RMWSKIDOVF] t=%0t addr=%0d DROPPED (RMW skid full, depth=%0d)",
                             $time, acc_internal_addr, SKID_DEPTH);
                // synopsys translate_on
            end
            rmw_skid_cnt <= rmw_skid_cnt
                            - (rmw_pop ? 2'd1 : 2'd0)
                            + ((rmw_push && !(rmw_skid_cnt == 2'd2 && !rmw_pop)) ? 2'd1 : 2'd0);

            if (acc_valid_pip2) begin
                inst1_reg1 <= overwrite_pip2 ? {SRAM_WIDTH{1'b0}} : rdata_tmp;
                for (l = 0; l < ELEM_NUM; l = l + 1) begin
                    inst2_reg1[ADD_PREC*l +: ADD_PREC] <= acc_data_pip2[ADD_PREC*l +: ADD_PREC];
                end
                dest_addr1 <= acc_int_addr_pip2;
                add_start  <= 1'b1;
            end

            rvalid <= 1'b0;
            read_half_sel_pip1 <= read_half_sel;

            if (ren_pip1) begin
                rvalid <= 1'b1;
            end

            if (!rst_flag) begin
                rst_flag          <= 1'b1;
                clear_flag        <= 1'b1;
                sram_in_addr_clear <= {INT_ADDR_WIDTH{1'b0}};
            end else if (clear_flag && !sram_in_vld_add && sram_in_addr_clear == INT_DEPTH - 1) begin
                clear_flag         <= 1'b0;
                sram_in_addr_clear <= {INT_ADDR_WIDTH{1'b0}};
            end else if (clear_flag && !sram_in_vld_add) begin
                sram_in_addr_clear <= sram_in_addr_clear + 1'b1;
            end else if (clear) begin
                clear_flag         <= 1'b1;
                sram_in_addr_clear <= {INT_ADDR_WIDTH{1'b0}};
            end
`ifdef RESPROBE
            if (is_gemv_proj && sram_in_vld && sram_in_addr < 4)
                $display("[SRW] t=%0t addr=%0d is_compute=%b clear_flag=%b clear_in=%b data_hi=%h",
                         $time, sram_in_addr, sram_in_vld_add, clear_flag, clear,
                         sram_data_in[ADD_PREC-DATA_WIDTH +: DATA_WIDTH]);
`endif
        end
    end

    // synopsys translate_off
    reg [1:0] rmw_skid_hiwater;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rmw_skid_hiwater <= 2'd0;
        else if (rmw_skid_cnt > rmw_skid_hiwater) begin
            rmw_skid_hiwater <= rmw_skid_cnt;
            $display("[RMWSKIDHW] t=%0t occupancy=%0d (depth=%0d)",
                     $time, rmw_skid_cnt, SKID_DEPTH);
        end
    end
    // synopsys translate_on

    reg add_vld;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_in_vld_add <= 1'b0;
            add_vld         <= 1'b0;
            inst1_reg2      <= {ADD_PREC*ELEM_NUM{1'b0}};
            inst2_reg2      <= {ADD_PREC*ELEM_NUM{1'b0}};
            dest_addr2      <= {INT_ADDR_WIDTH{1'b0}};
        end else begin
            sram_in_vld_add <= 1'b0;
            if (add_vld) begin
                add_vld         <= 1'b0;
                sram_in_vld_add <= 1'b1;
                sram_in_addr_add <= dest_addr2;
                if (add_start) begin
                    inst1_reg2 <= inst1_reg1;
                    inst2_reg2 <= inst2_reg1;
                    dest_addr2 <= dest_addr1;
                    add_vld    <= 1'b1;
                end
            end else if (add_start) begin
                inst1_reg2 <= inst1_reg1;
                inst2_reg2 <= inst2_reg1;
                dest_addr2 <= dest_addr1;
                add_vld    <= 1'b1;
            end
        end
    end

    generate
        for (i = 0; i < ADDER_NUM; i = i + 1) begin : adder_loop
            wire [ADD_PREC-1:0] z_bf16;
            DW_fp_add_inst #(
                .sig_width(15),
                .exp_width(8),
                .ieee_compliance(1)
            ) stage1_a0 (
                .inst_a(inst1_reg2[ADD_PREC*i +: ADD_PREC]),
                .inst_b(inst2_reg2[ADD_PREC*i +: ADD_PREC]),
                .inst_rnd(3'b000),
                .z_inst(z_bf16),
                .status_inst()
            );

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sram_data_in[ADD_PREC*i +: ADD_PREC] <= {ADD_PREC{1'b0}};
                end else begin
                    if (add_vld) begin
                        sram_data_in[ADD_PREC*i +: ADD_PREC] <= z_bf16;
                    end else if (clear) begin
                        sram_data_in[ADD_PREC*i +: ADD_PREC] <= {ADD_PREC{1'b0}};
                    end
                end
            end
        end
    endgenerate

    generate
    `ifdef VENDOR_MACRO
    `else
      if (INT_DEPTH <= 64) begin : g_sram64
        sram_64x6144_wrapper u_sram_64x6144 (
            .clk    (clk),
            .rst_n  (rst_n),
            .wen    (sram_in_vld),
            .waddr  (sram_in_addr),
            .wdata  (sram_data_in),
            .ren    (ren_pip1 || acc_valid_pip1),
            .raddr  (read_int_addr),
            .rdata  (rdata_tmp),
            .rvalid ()
        );
      end else begin : g_sram256
        sram_256x6144_wrapper u_sram_256x6144 (
            .clk    (clk),
            .rst_n  (rst_n),
            .wen    (sram_in_vld),
            .waddr  (sram_in_addr),
            .wdata  (sram_data_in),
            .ren    (ren_pip1 || acc_valid_pip1),
            .raddr  (read_int_addr),
            .rdata  (rdata_tmp),
            .rvalid ()
        );
      end
    `endif
    endgenerate

endmodule