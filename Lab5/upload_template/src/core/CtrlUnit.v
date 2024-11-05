`timescale 1ns / 1ps

module CtrlUnit(
    input clk,
    input rst,

    input[31:0] inst,
    input valid_ID,
    
    input cmp_res_FU,

    // IF
    output reg_IF_en, branch_ctrl,

    // ID
    output reg_ID_en, reg_ID_flush,
    output[2:0] ImmSel,
    output ALU_en, MEM_en, MUL_en, DIV_en, JUMP_en,
    
    // FU
    output[3:0] JUMP_op,
    output[3:0] ALU_op,
    output ALUSrcA,
    output ALUSrcB,
    output MEM_we,
    
    // WB
    output reg[2:0] write_sel,
    output reg[4:0] rd_ctrl,
    output reg reg_write
);
    reg TO_BE_FILLED = 0;
    always  @(posedge clk or posedge rst) begin
        if(rst) begin
            reg_write <= 0;
            rd_ctrl <= 0;
            write_sel <= 0;
        end else begin
            reg_write <= FU_writeback_en[reservation_reg[0]];
            rd_ctrl <= FU_write_to[reservation_reg[0]];
            write_sel <= reservation_reg[0];
        end
    end

    // instruction field
    wire[6:0] funct7 = inst[31:25];
    wire[2:0] funct3 = inst[14:12];
    wire[6:0] opcode = inst[6:0];
    wire[4:0] rd = inst[11:7];
    wire[4:0] rs1 = inst[19:15];
    wire[4:0] rs2 = inst[24:20];

    // type specification
    wire Rop = opcode == 7'b0110011;
    wire Iop = opcode == 7'b0010011;
    wire Bop = opcode == 7'b1100011;
    wire Lop = opcode == 7'b0000011;
    wire Sop = opcode == 7'b0100011;

    wire funct7_0  = funct7 == 7'h0;
    wire funct7_1  = funct7 == 7'h1;
    wire funct7_32 = funct7 == 7'h20;

    wire funct3_0 = funct3 == 3'h0;
    wire funct3_1 = funct3 == 3'h1;
    wire funct3_2 = funct3 == 3'h2;
    wire funct3_3 = funct3 == 3'h3;
    wire funct3_4 = funct3 == 3'h4;
    wire funct3_5 = funct3 == 3'h5;
    wire funct3_6 = funct3 == 3'h6;
    wire funct3_7 = funct3 == 3'h7;

    wire ADD  = Rop & funct3_0 & funct7_0;
    wire SUB  = Rop & funct3_0 & funct7_32;
    wire SLL  = Rop & funct3_1 & funct7_0;
    wire SLT  = Rop & funct3_2 & funct7_0;
    wire SLTU = Rop & funct3_3 & funct7_0;
    wire XOR  = Rop & funct3_4 & funct7_0;
    wire SRL  = Rop & funct3_5 & funct7_0;
    wire SRA  = Rop & funct3_5 & funct7_32;
    wire OR   = Rop & funct3_6 & funct7_0;
    wire AND  = Rop & funct3_7 & funct7_0;

    wire MUL    = Rop & funct3_0 & funct7_1;
    wire MULH   = Rop & funct3_1 & funct7_1;
    wire MULHSU = Rop & funct3_2 & funct7_1;
    wire MULHU  = Rop & funct3_3 & funct7_1;
    wire DIV    = Rop & funct3_4 & funct7_1;
    wire DIVU   = Rop & funct3_5 & funct7_1;
    wire REM    = Rop & funct3_6 & funct7_1;
    wire REMU    = Rop & funct3_7 & funct7_1;

    wire ADDI  = Iop & funct3_0;	
    wire SLTI  = Iop & funct3_2;
    wire SLTIU = Iop & funct3_3;
    wire XORI  = Iop & funct3_4;
    wire ORI   = Iop & funct3_6;
    wire ANDI  = Iop & funct3_7;
    wire SLLI  = Iop & funct3_1 & funct7_0;
    wire SRLI  = Iop & funct3_5 & funct7_0;
    wire SRAI  = Iop & funct3_5 & funct7_32;

    wire BEQ = Bop & funct3_0;
    wire BNE = Bop & funct3_1;
    wire BLT = Bop & funct3_4;
    wire BGE = Bop & funct3_5;
    wire BLTU = Bop & funct3_6;
    wire BGEU = Bop & funct3_7;

    wire LB =  Lop & funct3_0;
    wire LH =  Lop & funct3_1;
    wire LW =  Lop & funct3_2;
    wire LBU = Lop & funct3_4;
    wire LHU = Lop & funct3_5;

    wire SB = Sop & funct3_0;
    wire SH = Sop & funct3_1;
    wire SW = Sop & funct3_2;

    wire LUI   = opcode == 7'b0110111;
    wire AUIPC = opcode == 7'b0010111;

    wire JAL  =  opcode == 7'b1101111;
    wire JALR = (opcode == 7'b1100111) && funct3_0;

    wire R_valid = AND | OR | ADD | XOR | SLL | SRL | SRA | SUB | SLT | SLTU 
        | MUL | MULH | MULHSU | MULHU | DIV | DIVU | REM | REMU;
    wire I_valid = ANDI | ORI | ADDI | XORI | SLLI | SRLI | SRAI | SLTI | SLTIU;
    wire B_valid = BEQ | BNE | BLT | BGE | BLTU | BGEU;
    wire L_valid = LW | LH | LB | LHU | LBU;
    wire S_valid = SW | SH | SB;

    wire rd_used = R_valid | I_valid | JAL | JALR | L_valid | LUI | AUIPC;

    wire use_ALU = AND | OR | ADD | XOR | SLL | SRL | SRA | SUB | SLT | SLTU
        | I_valid | LUI | AUIPC;
    wire use_MEM = L_valid | S_valid;
    wire use_MUL = MUL | MULH | MULHSU | MULHU;
    wire use_DIV = DIV | DIVU | REM | REMU;
    wire use_JUMP = B_valid | JAL | JALR;

    wire[2:0] use_FU =  {3{use_ALU}}  & 3'd1 |
                        {3{use_MEM}}  & 3'd2 |
                        {3{use_MUL}}  & 3'd3 |
                        {3{use_DIV}}  & 3'd4 |
                        {3{use_JUMP}} & 3'd5 ;

    reg B_in_FU, J_in_FU; // branch and jump
    reg[5:0] FU_status; // flag for each FU, 1 is busy, 0 is free.
    reg[2:0] reservation_reg [0:31]; // please refer to implementation notes
    reg[4:0] FU_write_to [5:0]; // the destination register of the FU
    reg[5:0] FU_writeback_en; // enable FU to write back when there is no hazard 
    reg[4:0] FU_delay_cycles [5:0]; // record the FU's delay cycles
    reg reg_ID_flush_next;
    integer i;

    // map the FU to it's current latency using brute force 
    wire [4:0] latency [5:0];
    assign latency[1] = reservation_reg[0] == 3'd1 ? 0 :
                 reservation_reg[1] == 3'd1 ? 1 :
                 reservation_reg[2] == 3'd1 ? 2 :
                 reservation_reg[3] == 3'd1 ? 3 :
                 reservation_reg[4] == 3'd1 ? 4 :
                 reservation_reg[5] == 3'd1 ? 5 :
                 reservation_reg[6] == 3'd1 ? 6 :
                 reservation_reg[7] == 3'd1 ? 7 :
                 reservation_reg[8] == 3'd1 ? 8 :
                 reservation_reg[9] == 3'd1 ? 9 :
                 reservation_reg[10] == 3'd1 ? 10 :
                 reservation_reg[11] == 3'd1 ? 11 :
                 reservation_reg[12] == 3'd1 ? 12 :
                 reservation_reg[13] == 3'd1 ? 13 :
                 reservation_reg[14] == 3'd1 ? 14 :
                 reservation_reg[15] == 3'd1 ? 15 :
                 reservation_reg[16] == 3'd1 ? 16 :
                 reservation_reg[17] == 3'd1 ? 17 :
                 reservation_reg[18] == 3'd1 ? 18 :
                 reservation_reg[19] == 3'd1 ? 19 :
                 reservation_reg[20] == 3'd1 ? 20 :
                 reservation_reg[21] == 3'd1 ? 21 :
                 reservation_reg[22] == 3'd1 ? 22 :
                 reservation_reg[23] == 3'd1 ? 23 :
                 reservation_reg[24] == 3'd1 ? 24 :
                 reservation_reg[25] == 3'd1 ? 25 :
                 reservation_reg[26] == 3'd1 ? 26 :
                 reservation_reg[27] == 3'd1 ? 27 :
                 reservation_reg[28] == 3'd1 ? 28 :
                 reservation_reg[29] == 3'd1 ? 29 :
                 reservation_reg[30] == 3'd1 ? 30 :
                 reservation_reg[31] == 3'd1 ? 31 : 0;

    assign latency[2] = reservation_reg[0] == 3'd2 ? 0 :
                 reservation_reg[1] == 3'd2 ? 1 :
                 reservation_reg[2] == 3'd2 ? 2 :
                 reservation_reg[3] == 3'd2 ? 3 :
                 reservation_reg[4] == 3'd2 ? 4 :
                 reservation_reg[5] == 3'd2 ? 5 :
                 reservation_reg[6] == 3'd2 ? 6 :
                 reservation_reg[7] == 3'd2 ? 7 :
                 reservation_reg[8] == 3'd2 ? 8 :
                 reservation_reg[9] == 3'd2 ? 9 :
                 reservation_reg[10] == 3'd2 ? 10 :
                 reservation_reg[11] == 3'd2 ? 11 :
                 reservation_reg[12] == 3'd2 ? 12 :
                 reservation_reg[13] == 3'd2 ? 13 :
                 reservation_reg[14] == 3'd2 ? 14 :
                 reservation_reg[15] == 3'd2 ? 15 :
                 reservation_reg[16] == 3'd2 ? 16 :
                 reservation_reg[17] == 3'd2 ? 17 :
                 reservation_reg[18] == 3'd2 ? 18 :
                 reservation_reg[19] == 3'd2 ? 19 :
                 reservation_reg[20] == 3'd2 ? 20 :
                 reservation_reg[21] == 3'd2 ? 21 :
                 reservation_reg[22] == 3'd2 ? 22 :
                 reservation_reg[23] == 3'd2 ? 23 :
                 reservation_reg[24] == 3'd2 ? 24 :
                 reservation_reg[25] == 3'd2 ? 25 :
                 reservation_reg[26] == 3'd2 ? 26 :
                 reservation_reg[27] == 3'd2 ? 27 :
                 reservation_reg[28] == 3'd2 ? 28 :
                 reservation_reg[29] == 3'd2 ? 29 :
                 reservation_reg[30] == 3'd2 ? 30 :
                 reservation_reg[31] == 3'd2 ? 31 : 0;

    assign latency[3] = reservation_reg[0] == 3'd3 ? 0 :
                 reservation_reg[1] == 3'd3 ? 1 :
                 reservation_reg[2] == 3'd3 ? 2 :
                 reservation_reg[3] == 3'd3 ? 3 :
                 reservation_reg[4] == 3'd3 ? 4 :
                 reservation_reg[5] == 3'd3 ? 5 :
                 reservation_reg[6] == 3'd3 ? 6 :
                 reservation_reg[7] == 3'd3 ? 7 :
                 reservation_reg[8] == 3'd3 ? 8 :
                 reservation_reg[9] == 3'd3 ? 9 :
                 reservation_reg[10] == 3'd3 ? 10 :
                 reservation_reg[11] == 3'd3 ? 11 :
                 reservation_reg[12] == 3'd3 ? 12 :
                 reservation_reg[13] == 3'd3 ? 13 :
                 reservation_reg[14] == 3'd3 ? 14 :
                 reservation_reg[15] == 3'd3 ? 15 :
                 reservation_reg[16] == 3'd3 ? 16 :
                 reservation_reg[17] == 3'd3 ? 17 :
                 reservation_reg[18] == 3'd3 ? 18 :
                 reservation_reg[19] == 3'd3 ? 19 :
                 reservation_reg[20] == 3'd3 ? 20 :
                 reservation_reg[21] == 3'd3 ? 21 :
                 reservation_reg[22] == 3'd3 ? 22 :
                 reservation_reg[23] == 3'd3 ? 23 :
                 reservation_reg[24] == 3'd3 ? 24 :
                 reservation_reg[25] == 3'd3 ? 25 :
                 reservation_reg[26] == 3'd3 ? 26 :
                 reservation_reg[27] == 3'd3 ? 27 :
                 reservation_reg[28] == 3'd3 ? 28 :
                 reservation_reg[29] == 3'd3 ? 29 :
                 reservation_reg[30] == 3'd3 ? 30 :
                 reservation_reg[31] == 3'd3 ? 31 : 0;

    assign latency[4] = reservation_reg[0] == 3'd4 ? 0 :
                 reservation_reg[1] == 3'd4 ? 1 :
                 reservation_reg[2] == 3'd4 ? 2 :
                 reservation_reg[3] == 3'd4 ? 3 :
                 reservation_reg[4] == 3'd4 ? 4 :
                 reservation_reg[5] == 3'd4 ? 5 :
                 reservation_reg[6] == 3'd4 ? 6 :
                 reservation_reg[7] == 3'd4 ? 7 :
                 reservation_reg[8] == 3'd4 ? 8 :
                 reservation_reg[9] == 3'd4 ? 9 :
                 reservation_reg[10] == 3'd4 ? 10 :
                 reservation_reg[11] == 3'd4 ? 11 :
                 reservation_reg[12] == 3'd4 ? 12 :
                 reservation_reg[13] == 3'd4 ? 13 :
                 reservation_reg[14] == 3'd4 ? 14 :
                 reservation_reg[15] == 3'd4 ? 15 :
                 reservation_reg[16] == 3'd4 ? 16 :
                 reservation_reg[17] == 3'd4 ? 17 :
                 reservation_reg[18] == 3'd4 ? 18 :
                 reservation_reg[19] == 3'd4 ? 19 :
                 reservation_reg[20] == 3'd4 ? 20 :
                 reservation_reg[21] == 3'd4 ? 21 :
                 reservation_reg[22] == 3'd4 ? 22 :
                 reservation_reg[23] == 3'd4 ? 23 :
                 reservation_reg[24] == 3'd4 ? 24 :
                 reservation_reg[25] == 3'd4 ? 25 :
                 reservation_reg[26] == 3'd4 ? 26 :
                 reservation_reg[27] == 3'd4 ? 27 :
                 reservation_reg[28] == 3'd4 ? 28 :
                 reservation_reg[29] == 3'd4 ? 29 :
                 reservation_reg[30] == 3'd4 ? 30 :
                 reservation_reg[31] == 3'd4 ? 31 : 0;

    assign latency[5] = reservation_reg[0] == 3'd5 ? 0 :
                 reservation_reg[1] == 3'd5 ? 1 :
                 reservation_reg[2] == 3'd5 ? 2 :
                 reservation_reg[3] == 3'd5 ? 3 :
                 reservation_reg[4] == 3'd5 ? 4 :
                 reservation_reg[5] == 3'd5 ? 5 :
                 reservation_reg[6] == 3'd5 ? 6 :
                 reservation_reg[7] == 3'd5 ? 7 :
                 reservation_reg[8] == 3'd5 ? 8 :
                 reservation_reg[9] == 3'd5 ? 9 :
                 reservation_reg[10] == 3'd5 ? 10 :
                 reservation_reg[11] == 3'd5 ? 11 :
                 reservation_reg[12] == 3'd5 ? 12 :
                 reservation_reg[13] == 3'd5 ? 13 :
                 reservation_reg[14] == 3'd5 ? 14 :
                 reservation_reg[15] == 3'd5 ? 15 :
                 reservation_reg[16] == 3'd5 ? 16 :
                 reservation_reg[17] == 3'd5 ? 17 :
                 reservation_reg[18] == 3'd5 ? 18 :
                 reservation_reg[19] == 3'd5 ? 19 :
                 reservation_reg[20] == 3'd5 ? 20 :
                 reservation_reg[21] == 3'd5 ? 21 :
                 reservation_reg[22] == 3'd5 ? 22 :
                 reservation_reg[23] == 3'd5 ? 23 :
                 reservation_reg[24] == 3'd5 ? 24 :
                 reservation_reg[25] == 3'd5 ? 25 :
                 reservation_reg[26] == 3'd5 ? 26 :
                 reservation_reg[27] == 3'd5 ? 27 :
                 reservation_reg[28] == 3'd5 ? 28 :
                 reservation_reg[29] == 3'd5 ? 29 :
                 reservation_reg[30] == 3'd5 ? 30 :
                 reservation_reg[31] == 3'd5 ? 31 : 0;
    
    // wire WAW = TO_BE_FILLED; //这里判断预约寄存器的代码可能非常长
    // please refer to implementation notes
    wire WAW = (FU_status[1] & rd != 5'b0 & rd_used & rd == FU_write_to[1] & FU_delay_cycles[use_FU] < latency[1]) ? 1'b1 :
               (FU_status[2] & rd != 5'b0 & rd_used & rd == FU_write_to[2] & FU_delay_cycles[use_FU] < latency[2]) ? 1'b1 :
               (FU_status[3] & rd != 5'b0 & rd_used & rd == FU_write_to[3] & FU_delay_cycles[use_FU] < latency[3]) ? 1'b1 :
               (FU_status[4] & rd != 5'b0 & rd_used & rd == FU_write_to[4] & FU_delay_cycles[use_FU] < latency[4]) ? 1'b1 :
               (FU_status[5] & rd != 5'b0 & rd_used & rd == FU_write_to[5] & FU_delay_cycles[use_FU] < latency[5]) ? 1'b1 : 1'b0;

    // please refer to implementation notes
    wire RAW_rs1 = (FU_status[1] & rs1 != 5'b0 & rs1 == FU_write_to[1]) ? 1'b1 : 
                   (FU_status[2] & rs1 != 5'b0 & rs1 == FU_write_to[2]) ? 1'b1 :
                   (FU_status[3] & rs1 != 5'b0 & rs1 == FU_write_to[3]) ? 1'b1 :
                   (FU_status[4] & rs1 != 5'b0 & rs1 == FU_write_to[4]) ? 1'b1 :
                   (FU_status[5] & rs1 != 5'b0 & rs1 == FU_write_to[5]) ? 1'b1 : 1'b0;
    
    // please refer to implementation notes
    wire RAW_rs2 = (FU_status[1] & rs2 != 5'b0 & rs2 == FU_write_to[1]) ? 1'b1 :
                   (FU_status[2] & rs2 != 5'b0 & rs2 == FU_write_to[2]) ? 1'b1 :
                   (FU_status[3] & rs2 != 5'b0 & rs2 == FU_write_to[3]) ? 1'b1 :
                   (FU_status[4] & rs2 != 5'b0 & rs2 == FU_write_to[4]) ? 1'b1 :
                   (FU_status[5] & rs2 != 5'b0 & rs2 == FU_write_to[5]) ? 1'b1 : 1'b0;
    wire WB_structure_hazard = |reservation_reg[FU_delay_cycles[use_FU]+1'b1] ? 1'b1 : 1'b0;
    wire FU_structure_hazard = FU_status[use_FU] ? 1'b1 : 1'b0;
    wire FU_hazard = WAW|RAW_rs1|RAW_rs2|WB_structure_hazard|FU_structure_hazard;

    initial begin
        B_in_FU = 0;
        J_in_FU = 0;
        FU_status <= 6'b0;
        FU_writeback_en <= 6'b0;
        for (i=0; i<32; i=i+1)
		    reservation_reg[i] <= 0;
        for (i=0; i<6; i=i+1)
		    FU_write_to[i] <= 0;
        FU_delay_cycles[1] <= 5'd1;         // ALU cycles
        FU_delay_cycles[2] <= 5'd2;         // MEM cycles
        FU_delay_cycles[3] <= 5'd7;         // MUL cycles
        FU_delay_cycles[4] <= 5'd24;        // DIV cycles
        FU_delay_cycles[5] <= 5'd2;         // JUMP cycles
        for (i=0; i<6; i=i+1)
            FU_writeback_reg[i] <= 5'b0;     // initialize the rd of each FU
        reg_ID_flush_next <= 0;
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            B_in_FU <= 0;
            J_in_FU <= 0;
            FU_status <= 6'b0;
            FU_writeback_en <= 6'b0;
            for (i=0; i<32; i=i+1)
                reservation_reg[i] <= 0;
            for (i=0; i<6; i=i+1)
                FU_write_to[i] <= 0;
            FU_delay_cycles[1] <= 5'd1;         // ALU cycles
            FU_delay_cycles[2] <= 5'd2;         // MEM cycles
            FU_delay_cycles[3] <= 5'd7;         // MUL cycles
            FU_delay_cycles[4] <= 5'd24;        // DIV cycles
            FU_delay_cycles[5] <= 5'd2;         // JUMP cycles
        end
        else begin // some FU finishes it's computation here, write the result back
            if (reservation_reg[0] != 0) begin  // FU写回将在这周期完成，这里需要联系39行
                FU_writeback_en[reservation_reg[0]] <= 1'b1; // enable the corresponding FU write back signal
                FU_status[reservation_reg[0]] <= 1'b0; // free the corresponding FU
                FU_write_to[reservation_reg[0]] <= 5'b0; // free the corresponding FU
            end
            if (use_FU == 0 | reg_ID_flush_next) begin
                for (i=0; i<31; i=i+1)
                    reservation_reg[i] <= reservation_reg[i+1]
                reservation_reg[31] = 32'b0
                // TO_BE_FILLED <= 0; //这里需要编写多行代码，完成reservation_reg的移位操作，第2位移到第1位，第3位移到第2位，以此类推。最后一位清零。推荐尝试for循环（当然手写三十多行赋值也可以）。
                B_in_FU <= 0;
                J_in_FU <= 0;
            end
            else if (FU_hazard  | reg_ID_flush) begin
                for (i=0; i<31; i=i+1)
                    reservation_reg[i] <= reservation_reg[i+1]
                reservation_reg[31] = 32'b0
                // TO_BE_FILLED <= 0; //这里需要编写多行代码，完成reservation_reg的移位操作，第2位移到第1位，第3位移到第2位，以此类推。最后一位清零。推荐尝试for循环（当然手写三十多行赋值也可以）。
                B_in_FU <= 0;
                J_in_FU <= 0;
                end
            else if(valid_ID) begin  // register FU operation
                for (i=0; i<31; i=i+1)
                    reservation_reg[i] <= (i==FU_delay_cycles[use_FU] ? use_FU : reservation_reg[i+1])
                reservation_reg[31] <= 32'b0
                // TO_BE_FILLED <= 0; //这里需要编写多行代码，完成reservation_reg的移位操作，第2位移到第1位，第3位移到第2位，以此类推。最后一位清零。推荐尝试for循环（当然手写三十多行赋值也可以）。
                FU_status[use_FU] <= 1'b1; // set the corresponding FU busy
                if(rd_used)begin
                    FU_write_to[use_FU] <= rd;
                    FU_writeback_en[use_FU] <= 1'b0;
                end
                B_in_FU <= B_valid;
                J_in_FU <= JAL | JALR;
            end
        end
    end

    assign reg_IF_en = ~FU_hazard | branch_ctrl;

    assign reg_ID_en = reg_IF_en;

    assign branch_ctrl = (B_in_FU & cmp_res_FU) |  J_in_FU;

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            reg_ID_flush_next <= 0;
        end
        else begin
            reg_ID_flush_next <= branch_ctrl;
        end
    end
    assign reg_ID_flush = branch_ctrl;

    localparam Imm_type_I = 3'b001;
    localparam Imm_type_B = 3'b010;
    localparam Imm_type_J = 3'b011;
    localparam Imm_type_S = 3'b100;
    localparam Imm_type_U = 3'b101;
    assign ImmSel = {3{JALR | L_valid | I_valid}} & Imm_type_I |
                    {3{B_valid}}                  & Imm_type_B |
                    {3{JAL}}                      & Imm_type_J |
                    {3{S_valid}}                  & Imm_type_S |
                    {3{LUI | AUIPC}}              & Imm_type_U ;
    
    assign ALU_en = reg_IF_en & use_ALU & valid_ID & ~reg_ID_flush;
    assign MEM_en = reg_IF_en & use_MEM & valid_ID & ~reg_ID_flush;
    assign MUL_en = reg_IF_en & use_MUL & valid_ID & ~reg_ID_flush;
    assign DIV_en = reg_IF_en & use_DIV & valid_ID & ~reg_ID_flush;
    assign JUMP_en = reg_IF_en & use_JUMP & valid_ID & ~reg_ID_flush;

    localparam JUMP_BEQ  = 4'b0_001;
    localparam JUMP_BNE  = 4'b0_010;
    localparam JUMP_BLT  = 4'b0_011;
    localparam JUMP_BGE  = 4'b0_100;
    localparam JUMP_BLTU = 4'b0_101;
    localparam JUMP_BGEU = 4'b0_110;
    localparam JUMP_JAL  = 4'b0_000;
    localparam JUMP_JALR = 4'b1_000;
    assign JUMP_op ={4{BEQ}}  & JUMP_BEQ  |
                    {4{BNE}}  & JUMP_BNE  |
                    {4{BLT}}  & JUMP_BLT  |
                    {4{BGE}}  & JUMP_BGE  |
                    {4{BLTU}} & JUMP_BLTU |
                    {4{BGEU}} & JUMP_BGEU |
                    {4{JAL}}  & JUMP_JAL  |
                    {4{JALR}} & JUMP_JALR ;
    
    localparam ALU_ADD  = 4'b0001;
    localparam ALU_SUB  = 4'b0010;
    localparam ALU_AND  = 4'b0011;
    localparam ALU_OR   = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SLL  = 4'b0110;
    localparam ALU_SRL  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_SRA  = 4'b1010;
    localparam ALU_Ap4  = 4'b1011;
    localparam ALU_Bout = 4'b1100;
    assign ALU_op = {4{ADD | ADDI | AUIPC}} & ALU_ADD  |
                    {4{SUB}}                & ALU_SUB  |
                    {4{AND | ANDI}}         & ALU_AND  |
                    {4{OR | ORI}}           & ALU_OR   |
                    {4{XOR | XORI}}         & ALU_XOR  |
                    {4{SLL | SLLI}}         & ALU_SLL  |
                    {4{SRL | SRLI}}         & ALU_SRL  |
                    {4{SLT | SLTI}}         & ALU_SLT  |
                    {4{SLTU | SLTIU}}       & ALU_SLTU |
                    {4{SRA | SRAI}}         & ALU_SRA  |
                    {4{LUI}}                & ALU_Bout ;

    assign ALUSrcA = AUIPC;

    assign ALUSrcB = I_valid | LUI | AUIPC;

    assign MEM_we = S_valid;
endmodule