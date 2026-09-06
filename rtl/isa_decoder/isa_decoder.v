// SPDX-License-Identifier: Apache-2.0

module isa_decoder #(
    parameter [5:0] DECODE_CORE_NUM = 6'd8
) (
    input wire clk,
    input wire rst_n,

    input wire [511:0] isa_in,
    input wire         isa_valid,
    output wire        isa_in_ready,

    input wire isa_finished,

    output reg  isa_triggered,
    output wire isa_latched,
    output wire is_mode_valid,

    output reg [7:0] read_id,
    output reg [7:0] finished_id,

    output wire [5:0]  decode_core_num,

    output reg        a_on_chip,
    output reg        dest_on_chip,
    output reg [3:0]  fuse_mode,
    output reg [1:0]  opm_mode,
    output reg [1:0]  group_width,
    output reg [2:0]  quant_precision,
    output reg [3:0]  op_a_prec,
    output reg [3:0]  op_b_prec,
    output reg [3:0]  op_c_prec,
    output reg [7:0]  batch_num,
    output reg [6:0]  q_head_num,
    output reg [6:0]  kv_head_num,
    output reg [23:0] rope_token_pos,
    output reg [15:0] hidden_dim,
    output reg [23:0] seq_len,
    output reg [15:0] output_dim,
    output reg [6:0]  outlier_num,
    output reg [39:0] op_a_base_addr,
    output reg [39:0] op_b_base_addr,
    output reg [39:0] op_c_base_addr,
    output reg [39:0] op_d_base_addr,
    output reg [39:0] op_e_base_addr,
    output reg [39:0] dest_addr1,
    output reg [39:0] dest_addr2,
    output reg [29:0] qkv_head_addr_offset,

    output reg [7:0]  expert_id,
    output reg [7:0]  request_id,

    output reg        addr_mode,
    output reg [2:0]  block_table_sel,
    output reg [1:0]  isa_version,
    output reg [1:0]  sparse_format,
    output reg        b_on_chip,
    output reg        c_on_chip,
    output reg [15:0] window_size,

    output reg [2:0]  op_b_fmt,
    output reg [2:0]  op_c_fmt,
    output reg        w_szp_ovr,
    output reg        causal_mode,
    output wire [4:0] op_b_prec_eff,
    output wire [4:0] op_c_prec_eff,
    output wire       op_b_fmt_explicit,
    output wire       op_c_fmt_explicit,

    output reg [5:0] group_size,
    output reg       is_proj_mode,
    output reg       is_gemm_mode,
    output reg       is_residual_mode,
    output reg       is_gating_mode,
    output reg       is_norm_mode
);

    localparam  GEMM_BYPASS   = 4'd1,
                GEMM_ROPE     = 4'd2,
                GEMM_RTQT     = 4'd3,
                GEMM_QT       = 4'd4,
                GEMM_PRERMS   = 4'd5,
                GEMM_SWIGLU   = 4'd6,
                GEMM_TRANSPOSE= 4'd7,
                GEMM_GQA      = 4'd8,
                GEMV_BYPASS   = 4'd9,
                GEMV_ROPE_Q   = 4'd10,
                GEMV_ROPE_K   = 4'd11,
                GEMV_PRERMS   = 4'd12,
                GEMV_SWIGLU   = 4'd13;

    assign decode_core_num = DECODE_CORE_NUM;

    function [4:0] fmt_to_prec;
        input [2:0] fmt;
        input [3:0] legacy_prec;
        case (fmt)
            3'b001: fmt_to_prec = 5'd0;
            3'b010: fmt_to_prec = 5'd1;
            3'b011: fmt_to_prec = 5'd3;
            3'b100: fmt_to_prec = 5'd7;
            3'b101: fmt_to_prec = 5'd15;
            default: fmt_to_prec = {1'b0, legacy_prec};
        endcase
    endfunction

    assign op_b_prec_eff     = fmt_to_prec(op_b_fmt, op_b_prec);
    assign op_c_prec_eff     = fmt_to_prec(op_c_fmt, op_c_prec);
    assign op_b_fmt_explicit = (op_b_fmt >= 3'b001) && (op_b_fmt <= 3'b101);
    assign op_c_fmt_explicit = (op_c_fmt >= 3'b001) && (op_c_fmt <= 3'b101);

    localparam FIFO_DEPTH = 32;
    reg [511:0] fifo [0:FIFO_DEPTH-1];
    reg [5:0]   wr_ptr;
    reg [5:0]   rd_ptr;
    reg [5:0]   fifo_count;

    wire fifo_full  = (fifo_count == FIFO_DEPTH);
    wire fifo_empty = (fifo_count == 6'd0);

    assign isa_in_ready = !fifo_full;

    wire fifo_wr_en = isa_valid && isa_in_ready && isa_in[511];
    wire fifo_rd_en = !isa_triggered && !fifo_empty;

    wire [511:0] fifo_out = fifo[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 6'd0;
        else if (fifo_wr_en) begin
            fifo[wr_ptr] <= isa_in;
            wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 6'd0 : wr_ptr + 6'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= 6'd0;
        else if (fifo_rd_en)
            rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? 6'd0 : rd_ptr + 6'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_count <= 6'd0;
        else begin
            case ({fifo_wr_en, fifo_rd_en})
                2'b10:   fifo_count <= fifo_count + 6'd1;
                2'b01:   fifo_count <= fifo_count - 6'd1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

    reg [3:0] latched_counter;

    assign isa_latched = (latched_counter > 4'd0 && latched_counter < 4'd3);

    assign is_mode_valid = isa_triggered;

    reg [7:0] current_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            isa_triggered       <= 1'b0;
            latched_counter     <= 4'd0;
            current_id          <= 8'd0;
            read_id             <= 8'd0;
            finished_id         <= 8'd0;

            a_on_chip           <= 1'b0;
            dest_on_chip        <= 1'b0;
            fuse_mode           <= 4'd0;
            opm_mode            <= 2'd0;
            group_width         <= 2'd0;
            quant_precision     <= 3'd0;
            op_a_prec           <= 4'd0;
            op_b_prec           <= 4'd0;
            op_c_prec           <= 4'd0;
            batch_num           <= 8'd0;
            q_head_num          <= 7'd0;
            kv_head_num         <= 7'd0;
            rope_token_pos      <= 24'd0;
            hidden_dim          <= 16'd0;
            seq_len             <= 24'd0;
            output_dim          <= 16'd0;
            outlier_num         <= 7'd0;
            op_a_base_addr      <= 40'd0;
            op_b_base_addr      <= 40'd0;
            op_c_base_addr      <= 40'd0;
            op_d_base_addr      <= 40'd0;
            op_e_base_addr      <= 40'd0;
            dest_addr1          <= 40'd0;
            dest_addr2          <= 40'd0;
            qkv_head_addr_offset     <= 30'd0;
            expert_id           <= 8'd0;
            request_id          <= 8'd0;
            addr_mode           <= 1'b0;
            block_table_sel     <= 3'd0;
            isa_version         <= 2'd0;
            sparse_format       <= 2'd0;
            b_on_chip           <= 1'b0;
            c_on_chip           <= 1'b0;
            window_size         <= 16'd0;
            op_b_fmt            <= 3'd0;
            op_c_fmt            <= 3'd0;
            w_szp_ovr           <= 1'b0;
            causal_mode         <= 1'b0;

            group_size          <= 6'd0;
            is_proj_mode        <= 1'b0;
            is_gemm_mode        <= 1'b0;
            is_residual_mode    <= 1'b0;
            is_gating_mode      <= 1'b0;
            is_norm_mode        <= 1'b0;
        end else begin
            read_id     <= 8'd0;
            finished_id <= 8'd0;

            if (latched_counter > 4'd0)
                latched_counter <= latched_counter - 4'd1;

            if (isa_finished && isa_triggered) begin
                isa_triggered <= 1'b0;
                finished_id   <= current_id;
            end
            else if (!isa_triggered && !fifo_empty) begin
                isa_triggered   <= 1'b1;
                latched_counter <= 4'd5;

                current_id <= fifo_out[7:0];
                read_id    <= fifo_out[7:0];

                a_on_chip           <= fifo_out[506];
                dest_on_chip        <= fifo_out[505];
                fuse_mode           <= fifo_out[504:501];
                opm_mode            <= fifo_out[500:499];
                group_width         <= fifo_out[498:497];
                quant_precision     <= fifo_out[496:494];
                op_a_prec           <= fifo_out[493:490];
                op_b_prec           <= fifo_out[489:486];
                op_c_prec           <= fifo_out[485:482];
                batch_num           <= fifo_out[481:474];
                q_head_num          <= fifo_out[473:467];
                kv_head_num         <= fifo_out[466:460];
                rope_token_pos      <= fifo_out[459:436];
                hidden_dim          <= fifo_out[435:420];
                seq_len             <= fifo_out[419:396];
                output_dim          <= fifo_out[395:380];
                outlier_num         <= fifo_out[379:373];
                op_a_base_addr      <= fifo_out[372:333];
                op_b_base_addr      <= fifo_out[332:293];
                op_c_base_addr      <= fifo_out[292:253];
                op_d_base_addr      <= fifo_out[252:213];
                op_e_base_addr      <= fifo_out[212:173];
                dest_addr1          <= fifo_out[172:133];
                dest_addr2          <= fifo_out[132:93];
                qkv_head_addr_offset     <= fifo_out[92:63];
                expert_id           <= fifo_out[62:55];
                request_id          <= fifo_out[54:47];
                addr_mode           <= fifo_out[46];
                block_table_sel     <= fifo_out[45:43];
                isa_version         <= fifo_out[42:41];
                sparse_format       <= fifo_out[40:39];
                b_on_chip           <= fifo_out[38];
                c_on_chip           <= fifo_out[37];
                window_size         <= fifo_out[36:21];
                op_b_fmt            <= fifo_out[20:18];
                op_c_fmt            <= fifo_out[17:15];
                w_szp_ovr           <= fifo_out[14];
                causal_mode         <= fifo_out[13];

                group_size          <= (fifo_out[466:460] != 7'd0) ?
                                       (fifo_out[473:467] / fifo_out[466:460]) : 6'd0;
                is_proj_mode        <= fifo_out[508];
                is_gemm_mode        <= fifo_out[507];
                is_norm_mode        <= fifo_out[510];
                is_residual_mode    <= fifo_out[509];
                is_gating_mode      <= (fifo_out[504:501] == GEMM_SWIGLU || fifo_out[504:501] == GEMV_SWIGLU);
            end
        end
    end

endmodule
