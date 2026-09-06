// SPDX-License-Identifier: Apache-2.0
module cns_compressor (
    input wire clk,
    input wire rst_n,
    input wire isa_valid,
    input wire wen,
    input wire [101:0] wdata,

    input wire in_vld,
    input wire bitmask_mode,
    input wire [6:0] outlier_num,
    input wire [128-1:0] in_data,
    output wire out_vld,
    output wire [128-1:0] out_data
);

    genvar i;

    reg [128-1:0] in_data_lat;

    reg [2:0] L1_3_sub_cnt;
    reg       L1_3_sub_vld;
    reg       L1_3_done_vld;

    reg [7:0] L1_3_in [0:3];
    always @(*) begin
        case (L1_3_sub_cnt)
            3'd4: begin L1_3_in[0] = in_data_lat[ 0*8 +: 8]; L1_3_in[1] = in_data_lat[ 1*8 +: 8]; L1_3_in[2] = in_data_lat[ 2*8 +: 8]; L1_3_in[3] = in_data_lat[ 3*8 +: 8]; end
            3'd3: begin L1_3_in[0] = in_data_lat[ 4*8 +: 8]; L1_3_in[1] = in_data_lat[ 5*8 +: 8]; L1_3_in[2] = in_data_lat[ 6*8 +: 8]; L1_3_in[3] = in_data_lat[ 7*8 +: 8]; end
            3'd2: begin L1_3_in[0] = in_data_lat[ 8*8 +: 8]; L1_3_in[1] = in_data_lat[ 9*8 +: 8]; L1_3_in[2] = in_data_lat[10*8 +: 8]; L1_3_in[3] = in_data_lat[11*8 +: 8]; end
            default: begin L1_3_in[0] = in_data_lat[12*8 +: 8]; L1_3_in[1] = in_data_lat[13*8 +: 8]; L1_3_in[2] = in_data_lat[14*8 +: 8]; L1_3_in[3] = in_data_lat[15*8 +: 8]; end
        endcase
    end

    wire [7:0] L1_3_out_w   [0:3];
    wire [3:0] L1_3_out_num_w [0:3];

    generate
    for(i=0; i<4; i=i+1) begin : L1_3_GEN
        L1_3_LUT u_L1_3_LUT (
            .in_data(L1_3_in[i]),
            .out_data(L1_3_out_w[i]),
            .num_one(L1_3_out_num_w[i])
        );
    end
    endgenerate

    reg [16*8-1:0]  L1_3_out_data;
    reg [16*4-1:0]  L1_3_out_num_one;

    reg [16*8-1:0]  L4_in_data;
    reg [16*4-1:0]  L4_in_num_one;
    reg [2:0] L4_sub_cnt;
    reg       L4_sub_vld;
    reg       L4_done_vld;

    reg [8*16-1:0] L4_out_data;
    reg [8*5-1:0]  L4_out_num_one;

    reg [8*16-1:0] L5_in_data;
    reg [8*5-1:0]  L5_in_num_one;
    reg [2:0] L5_sub_cnt;
    reg       L5_sub_vld;
    reg       L5_done_vld;

    reg [4*32-1:0] L5_out_data;
    reg [4*6-1:0]  L5_out_num_one;

    reg [4*32-1:0] L6_in_data;
    reg [4*6-1:0]  L6_in_num_one;
    reg [1:0] L6_sub_cnt;
    reg       L6_sub_vld;
    reg       L6_done_vld;

    reg [2*64-1:0] L6_out_data;
    reg [2*7-1:0]  L6_out_num_one;

    reg       L1_3_done_vld_d1;
    reg       L4_done_vld_d1;
    reg       L5_done_vld_d1;
    reg       L6_done_vld_d1;

    reg [2*64-1:0] L7_in_data;
    reg [2*7-1:0]  L7_in_num_one;
    wire [101:0] L7_out_data_w;
    wire [7:0]   L7_out_num_one_w;
    wire         L7_out_vld_w;

    assign out_vld  = L7_out_vld_w;
    assign out_data = {26'd0, L7_out_data_w};

    reg [7:0]  L4_inst0_high, L4_inst0_low;
    reg [3:0]  L4_inst0_noh, L4_inst0_nol;
    always @(*) begin
        case (L4_sub_cnt)
            3'd4: begin L4_inst0_high = L4_in_data[0*16+8 +: 8]; L4_inst0_low = L4_in_data[0*16 +: 8]; L4_inst0_noh = L4_in_num_one[0*8+4 +: 4]; L4_inst0_nol = L4_in_num_one[0*8 +: 4]; end
            3'd3: begin L4_inst0_high = L4_in_data[2*16+8 +: 8]; L4_inst0_low = L4_in_data[2*16 +: 8]; L4_inst0_noh = L4_in_num_one[2*8+4 +: 4]; L4_inst0_nol = L4_in_num_one[2*8 +: 4]; end
            3'd2: begin L4_inst0_high = L4_in_data[4*16+8 +: 8]; L4_inst0_low = L4_in_data[4*16 +: 8]; L4_inst0_noh = L4_in_num_one[4*8+4 +: 4]; L4_inst0_nol = L4_in_num_one[4*8 +: 4]; end
            default: begin L4_inst0_high = L4_in_data[6*16+8 +: 8]; L4_inst0_low = L4_in_data[6*16 +: 8]; L4_inst0_noh = L4_in_num_one[6*8+4 +: 4]; L4_inst0_nol = L4_in_num_one[6*8 +: 4]; end
        endcase
    end

    reg [7:0]  L4_inst1_high, L4_inst1_low;
    reg [3:0]  L4_inst1_noh, L4_inst1_nol;
    always @(*) begin
        case (L4_sub_cnt)
            3'd4: begin L4_inst1_high = L4_in_data[1*16+8 +: 8]; L4_inst1_low = L4_in_data[1*16 +: 8]; L4_inst1_noh = L4_in_num_one[1*8+4 +: 4]; L4_inst1_nol = L4_in_num_one[1*8 +: 4]; end
            3'd3: begin L4_inst1_high = L4_in_data[3*16+8 +: 8]; L4_inst1_low = L4_in_data[3*16 +: 8]; L4_inst1_noh = L4_in_num_one[3*8+4 +: 4]; L4_inst1_nol = L4_in_num_one[3*8 +: 4]; end
            3'd2: begin L4_inst1_high = L4_in_data[5*16+8 +: 8]; L4_inst1_low = L4_in_data[5*16 +: 8]; L4_inst1_noh = L4_in_num_one[5*8+4 +: 4]; L4_inst1_nol = L4_in_num_one[5*8 +: 4]; end
            default: begin L4_inst1_high = L4_in_data[7*16+8 +: 8]; L4_inst1_low = L4_in_data[7*16 +: 8]; L4_inst1_noh = L4_in_num_one[7*8+4 +: 4]; L4_inst1_nol = L4_in_num_one[7*8 +: 4]; end
        endcase
    end

    wire [15:0] L4_inst0_out_data;
    wire [4:0]  L4_inst0_out_num;
    wire [15:0] L4_inst1_out_data;
    wire [4:0]  L4_inst1_out_num;

    L4_CELL u_L4_CELL_0 (
        .high(L4_inst0_high),
        .low(L4_inst0_low),
        .num_one_high(L4_inst0_noh),
        .num_one_low(L4_inst0_nol),
        .out_data(L4_inst0_out_data),
        .out_num_one(L4_inst0_out_num)
    );

    L4_CELL u_L4_CELL_1 (
        .high(L4_inst1_high),
        .low(L4_inst1_low),
        .num_one_high(L4_inst1_noh),
        .num_one_low(L4_inst1_nol),
        .out_data(L4_inst1_out_data),
        .out_num_one(L4_inst1_out_num)
    );

    reg [15:0] L5_inst_high, L5_inst_low;
    reg [4:0]  L5_inst_noh, L5_inst_nol;
    always @(*) begin
        case (L5_sub_cnt)
            3'd4: begin L5_inst_high = L5_in_data[0*32+16 +: 16]; L5_inst_low = L5_in_data[0*32 +: 16]; L5_inst_noh = L5_in_num_one[0*10+5 +: 5]; L5_inst_nol = L5_in_num_one[0*10 +: 5]; end
            3'd3: begin L5_inst_high = L5_in_data[1*32+16 +: 16]; L5_inst_low = L5_in_data[1*32 +: 16]; L5_inst_noh = L5_in_num_one[1*10+5 +: 5]; L5_inst_nol = L5_in_num_one[1*10 +: 5]; end
            3'd2: begin L5_inst_high = L5_in_data[2*32+16 +: 16]; L5_inst_low = L5_in_data[2*32 +: 16]; L5_inst_noh = L5_in_num_one[2*10+5 +: 5]; L5_inst_nol = L5_in_num_one[2*10 +: 5]; end
            default: begin L5_inst_high = L5_in_data[3*32+16 +: 16]; L5_inst_low = L5_in_data[3*32 +: 16]; L5_inst_noh = L5_in_num_one[3*10+5 +: 5]; L5_inst_nol = L5_in_num_one[3*10 +: 5]; end
        endcase
    end

    wire [31:0] L5_inst_out_data;
    wire [5:0]  L5_inst_out_num;

    L5_CELL u_L5_CELL (
        .high(L5_inst_high),
        .low(L5_inst_low),
        .num_one_high(L5_inst_noh),
        .num_one_low(L5_inst_nol),
        .out_data(L5_inst_out_data),
        .out_num_one(L5_inst_out_num)
    );

    reg [31:0] L6_inst_high, L6_inst_low;
    reg [5:0]  L6_inst_noh, L6_inst_nol;
    always @(*) begin
        case (L6_sub_cnt)
            2'd2: begin L6_inst_high = L6_in_data[0*64+32 +: 32]; L6_inst_low = L6_in_data[0*64 +: 32]; L6_inst_noh = L6_in_num_one[0*12+6 +: 6]; L6_inst_nol = L6_in_num_one[0*12 +: 6]; end
            default: begin L6_inst_high = L6_in_data[1*64+32 +: 32]; L6_inst_low = L6_in_data[1*64 +: 32]; L6_inst_noh = L6_in_num_one[1*12+6 +: 6]; L6_inst_nol = L6_in_num_one[1*12 +: 6]; end
        endcase
    end

    wire [63:0] L6_inst_out_data;
    wire [6:0]  L6_inst_out_num;

    L6_CELL u_L6_CELL (
        .high(L6_inst_high),
        .low(L6_inst_low),
        .num_one_high(L6_inst_noh),
        .num_one_low(L6_inst_nol),
        .out_data(L6_inst_out_data),
        .out_num_one(L6_inst_out_num)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_data_lat    <= {128{1'b0}};
            L1_3_sub_cnt   <= 3'd0;
            L1_3_sub_vld   <= 1'b0;
            L1_3_done_vld  <= 1'b0;
            L1_3_done_vld_d1 <= 1'b0;
            L1_3_out_data  <= {16*8{1'b0}};
            L1_3_out_num_one <= {16*4{1'b0}};

            L4_sub_cnt     <= 3'd0;
            L4_sub_vld     <= 1'b0;
            L4_done_vld    <= 1'b0;
            L4_done_vld_d1 <= 1'b0;
            L4_out_data    <= {8*16{1'b0}};
            L4_out_num_one <= {8*5{1'b0}};

            L5_sub_cnt     <= 3'd0;
            L5_sub_vld     <= 1'b0;
            L5_done_vld    <= 1'b0;
            L5_done_vld_d1 <= 1'b0;
            L5_out_data    <= {4*32{1'b0}};
            L5_out_num_one <= {4*6{1'b0}};

            L6_sub_cnt     <= 2'd0;
            L6_sub_vld     <= 1'b0;
            L6_done_vld    <= 1'b0;
            L6_done_vld_d1 <= 1'b0;
            L6_out_data    <= {2*64{1'b0}};
            L6_out_num_one <= {2*7{1'b0}};
        end else begin
            L1_3_done_vld_d1 <= L1_3_done_vld;
            L4_done_vld_d1   <= L4_done_vld;
            L5_done_vld_d1   <= L5_done_vld;
            L6_done_vld_d1   <= L6_done_vld;

            L1_3_done_vld <= 1'b0;
            if (L1_3_sub_cnt == 3'd1) begin
                L1_3_sub_cnt <= 3'd0;
                L1_3_sub_vld <= 1'b0;
                L1_3_done_vld <= 1'b1;
                if (in_vld) begin
                    in_data_lat <= in_data;
                    L1_3_sub_cnt <= 3'd4;
                    L1_3_sub_vld <= 1'b1;
                end
            end else if (L1_3_sub_cnt > 3'd1) begin
                L1_3_sub_cnt <= L1_3_sub_cnt - 3'd1;
            end else begin
                if (in_vld) begin
                    in_data_lat <= in_data;
                    L1_3_sub_cnt <= 3'd4;
                    L1_3_sub_vld <= 1'b1;
                end
            end

            if (L1_3_sub_vld) begin
                case (L1_3_sub_cnt)
                    3'd4: begin
                        L1_3_out_data[ 0*8 +: 8] <= L1_3_out_w[0]; L1_3_out_num_one[ 0*4 +: 4] <= L1_3_out_num_w[0];
                        L1_3_out_data[ 1*8 +: 8] <= L1_3_out_w[1]; L1_3_out_num_one[ 1*4 +: 4] <= L1_3_out_num_w[1];
                        L1_3_out_data[ 2*8 +: 8] <= L1_3_out_w[2]; L1_3_out_num_one[ 2*4 +: 4] <= L1_3_out_num_w[2];
                        L1_3_out_data[ 3*8 +: 8] <= L1_3_out_w[3]; L1_3_out_num_one[ 3*4 +: 4] <= L1_3_out_num_w[3];
                    end
                    3'd3: begin
                        L1_3_out_data[ 4*8 +: 8] <= L1_3_out_w[0]; L1_3_out_num_one[ 4*4 +: 4] <= L1_3_out_num_w[0];
                        L1_3_out_data[ 5*8 +: 8] <= L1_3_out_w[1]; L1_3_out_num_one[ 5*4 +: 4] <= L1_3_out_num_w[1];
                        L1_3_out_data[ 6*8 +: 8] <= L1_3_out_w[2]; L1_3_out_num_one[ 6*4 +: 4] <= L1_3_out_num_w[2];
                        L1_3_out_data[ 7*8 +: 8] <= L1_3_out_w[3]; L1_3_out_num_one[ 7*4 +: 4] <= L1_3_out_num_w[3];
                    end
                    3'd2: begin
                        L1_3_out_data[ 8*8 +: 8] <= L1_3_out_w[0]; L1_3_out_num_one[ 8*4 +: 4] <= L1_3_out_num_w[0];
                        L1_3_out_data[ 9*8 +: 8] <= L1_3_out_w[1]; L1_3_out_num_one[ 9*4 +: 4] <= L1_3_out_num_w[1];
                        L1_3_out_data[10*8 +: 8] <= L1_3_out_w[2]; L1_3_out_num_one[10*4 +: 4] <= L1_3_out_num_w[2];
                        L1_3_out_data[11*8 +: 8] <= L1_3_out_w[3]; L1_3_out_num_one[11*4 +: 4] <= L1_3_out_num_w[3];
                    end
                    3'd1: begin
                        L1_3_out_data[12*8 +: 8] <= L1_3_out_w[0]; L1_3_out_num_one[12*4 +: 4] <= L1_3_out_num_w[0];
                        L1_3_out_data[13*8 +: 8] <= L1_3_out_w[1]; L1_3_out_num_one[13*4 +: 4] <= L1_3_out_num_w[1];
                        L1_3_out_data[14*8 +: 8] <= L1_3_out_w[2]; L1_3_out_num_one[14*4 +: 4] <= L1_3_out_num_w[2];
                        L1_3_out_data[15*8 +: 8] <= L1_3_out_w[3]; L1_3_out_num_one[15*4 +: 4] <= L1_3_out_num_w[3];
                    end
                    default: ;
                endcase
            end

            L4_done_vld <= 1'b0;
            if (L4_sub_cnt == 3'd1) begin
                L4_sub_cnt <= 3'd0;
                L4_sub_vld <= 1'b0;
                L4_done_vld <= 1'b1;
                if (L1_3_done_vld) begin
                    L4_in_data <= L1_3_out_data;
                    L4_in_num_one <= L1_3_out_num_one;
                    L4_sub_cnt <= 3'd4;
                    L4_sub_vld <= 1'b1;
                end
            end else if (L4_sub_cnt > 3'd1) begin
                L4_sub_cnt <= L4_sub_cnt - 3'd1;
            end else begin
                if (L1_3_done_vld) begin
                    L4_in_data <= L1_3_out_data;
                    L4_in_num_one <= L1_3_out_num_one;
                    L4_sub_cnt <= 3'd4;
                    L4_sub_vld <= 1'b1;
                end
            end

            if (L4_sub_vld) begin
                case (L4_sub_cnt)
                    3'd4: begin
                        L4_out_data[0*16 +: 16]    <= L4_inst0_out_data;
                        L4_out_num_one[0*5 +: 5]   <= L4_inst0_out_num;
                        L4_out_data[1*16 +: 16]    <= L4_inst1_out_data;
                        L4_out_num_one[1*5 +: 5]   <= L4_inst1_out_num;
                    end
                    3'd3: begin
                        L4_out_data[2*16 +: 16]    <= L4_inst0_out_data;
                        L4_out_num_one[2*5 +: 5]   <= L4_inst0_out_num;
                        L4_out_data[3*16 +: 16]    <= L4_inst1_out_data;
                        L4_out_num_one[3*5 +: 5]   <= L4_inst1_out_num;
                    end
                    3'd2: begin
                        L4_out_data[4*16 +: 16]    <= L4_inst0_out_data;
                        L4_out_num_one[4*5 +: 5]   <= L4_inst0_out_num;
                        L4_out_data[5*16 +: 16]    <= L4_inst1_out_data;
                        L4_out_num_one[5*5 +: 5]   <= L4_inst1_out_num;
                    end
                    3'd1: begin
                        L4_out_data[6*16 +: 16]    <= L4_inst0_out_data;
                        L4_out_num_one[6*5 +: 5]   <= L4_inst0_out_num;
                        L4_out_data[7*16 +: 16]    <= L4_inst1_out_data;
                        L4_out_num_one[7*5 +: 5]   <= L4_inst1_out_num;
                    end
                    default: ;
                endcase
            end

            L5_done_vld <= 1'b0;
            if (L5_sub_cnt == 3'd1) begin
                L5_sub_cnt <= 3'd0;
                L5_sub_vld <= 1'b0;
                L5_done_vld <= 1'b1;
                if (L4_done_vld) begin
                    L5_in_data <= L4_out_data;
                    L5_in_num_one <= L4_out_num_one;
                    L5_sub_cnt <= 3'd4;
                    L5_sub_vld <= 1'b1;
                end
            end else if (L5_sub_cnt > 3'd1) begin
                L5_sub_cnt <= L5_sub_cnt - 3'd1;
            end else begin
                if (L4_done_vld) begin
                    L5_in_data <= L4_out_data;
                    L5_in_num_one <= L4_out_num_one;
                    L5_sub_cnt <= 3'd4;
                    L5_sub_vld <= 1'b1;
                end
            end

            if (L5_sub_vld) begin
                case (L5_sub_cnt)
                    3'd4: begin
                        L5_out_data[0*32 +: 32]    <= L5_inst_out_data;
                        L5_out_num_one[0*6 +: 6]   <= L5_inst_out_num;
                    end
                    3'd3: begin
                        L5_out_data[1*32 +: 32]    <= L5_inst_out_data;
                        L5_out_num_one[1*6 +: 6]   <= L5_inst_out_num;
                    end
                    3'd2: begin
                        L5_out_data[2*32 +: 32]    <= L5_inst_out_data;
                        L5_out_num_one[2*6 +: 6]   <= L5_inst_out_num;
                    end
                    3'd1: begin
                        L5_out_data[3*32 +: 32]    <= L5_inst_out_data;
                        L5_out_num_one[3*6 +: 6]   <= L5_inst_out_num;
                    end
                    default: ;
                endcase
            end

            L6_done_vld <= 1'b0;
            if (L6_sub_cnt == 2'd1) begin
                L6_sub_cnt <= 2'd0;
                L6_sub_vld <= 1'b0;
                L6_done_vld <= 1'b1;
                if (L5_done_vld) begin
                    L6_in_data <= L5_out_data;
                    L6_in_num_one <= L5_out_num_one;
                    L6_sub_cnt <= 2'd2;
                    L6_sub_vld <= 1'b1;
                end
            end else if (L6_sub_cnt > 2'd1) begin
                L6_sub_cnt <= L6_sub_cnt - 2'd1;
            end else begin
                if (L5_done_vld) begin
                    L6_in_data <= L5_out_data;
                    L6_in_num_one <= L5_out_num_one;
                    L6_sub_cnt <= 2'd2;
                    L6_sub_vld <= 1'b1;
                end
            end

            if (L6_sub_vld) begin
                case (L6_sub_cnt)
                    2'd2: begin
                        L6_out_data[0*64 +: 64]    <= L6_inst_out_data;
                        L6_out_num_one[0*7 +: 7]   <= L6_inst_out_num;
                    end
                    2'd1: begin
                        L6_out_data[1*64 +: 64]    <= L6_inst_out_data;
                        L6_out_num_one[1*7 +: 7]   <= L6_inst_out_num;
                    end
                    default: ;
                endcase
            end

            if(L6_done_vld) begin
                L7_in_data <= L6_out_data;
                L7_in_num_one <= L6_out_num_one;
            end
        end
    end

    L7_CELL u_L7_CELL (
        .clk(clk),
        .rst_n(rst_n),
        .sram_wen(wen),
        .sram_wdata(wdata),
        .isa_valid(isa_valid),
        .outlier_num(outlier_num),

        .in_vld(L6_done_vld_d1),
        .high(L7_in_data[64 +: 64]),
        .low(L7_in_data[0 +: 64]),
        .num_one_high(L7_in_num_one[7 +: 7]),
        .num_one_low(L7_in_num_one[0 +: 7]),

        .out_vld(L7_out_vld_w),
        .out_data(L7_out_data_w),
        .out_num_one(L7_out_num_one_w)
    );

endmodule