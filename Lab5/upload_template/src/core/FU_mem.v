`timescale 1ns / 1ps

module FU_mem(
    input clk, EN, mem_w,
    input[2:0] bhw,
    input[31:0] rs1_data, rs2_data, imm,
    output[31:0] mem_data
);

//    reg[1:0] state;//用来强行延迟执行来模拟latency
//    initial begin
//        state = 0;
//    end

//    reg mem_w_reg;
//    reg[2:0] bhw_reg;
//    reg[31:0] rs1_data_reg, rs2_data_reg, imm_reg,addr;
//    wire ack,stall;
//    wire[31:0] mem_data_wire;
//    reg [31:0] mem_data_reg;
    
//    always@(posedge clk) begin
//        if(EN & ~|state) begin // the condition is true when state is TRUE
//            mem_w_reg = mem_w;
//            bhw_reg = bhw;
//            rs1_data_reg = rs1_data;
//            rs2_data_reg = rs2_data;
//            imm_reg = imm;
//            addr = rs1_data_reg + imm_reg;
//            mem_data_reg = mem_data_wire;
//            state = 2'b10;
//        end
//        else state = {1'b0, {state[1]}};//这里的作用就是强行将这个模块延迟N个周期再输出结果，使其符合config.json的设�?
//    end


    reg state;//用来强行延迟执行来模拟latency
    initial begin
        state = 1'b0;
    end

    reg mem_w_reg;
    reg[2:0] bhw_reg;
    reg[31:0] rs1_data_reg, rs2_data_reg, imm_reg,addr;
    wire ack,stall;
    wire[31:0] mem_data_wire;
    reg [31:0] mem_data_reg;
    
    always@(posedge clk) begin
        if(EN & ~|state) begin // the condition is true when state is FALSE
            mem_w_reg <= mem_w;
            bhw_reg <= bhw;
            rs1_data_reg <= rs1_data;
            rs2_data_reg <= rs2_data;
            imm_reg <= imm;
            state <= 1'b1;
            mem_data_reg <= mem_data_wire;
        end
        else begin
            addr <= rs1_data_reg + imm_reg;
            state <= 1'b0;//这里的作用就是强行将这个模块延迟N个周期再输出结果，使其符合config.json的设�?
            mem_data_reg <= mem_data_wire;
        end
    end


    RAM_B ram(
        .clk(clk),
        .rst(1'b0),
        .cs(state == {1'b1}),
        .we(mem_w_reg),
        .addr(addr),
        .din(rs2_data_reg),
        .dout(mem_data_wire),
        .stall(stall),
        .ack(ack));
    assign mem_data = mem_data_reg;

endmodule