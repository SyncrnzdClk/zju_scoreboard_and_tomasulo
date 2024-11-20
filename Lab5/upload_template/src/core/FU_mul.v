`timescale 1ns / 1ps

module FU_mul(
    input clk, EN,
    input[31:0] A, B,
    output[31:0] res
);

    reg[6:0] state; // set laytency as 6 cycles (please refer to config.json)
    initial begin
        state = 0;
    end
    
    reg TO_BE_FILLED = 0;
    reg[31:0] A_reg, B_reg;
    
    always@(posedge clk) begin
        if(EN & ~|state) begin // the condition is true when state is TRUE
            A_reg <= A;
            B_reg <= B;
            state <= 7'b1000000; // reset the state
        end
        // here we use left shift operation to maintain a counter (maybe faster than minus operation)
        else state <= {1'b0, {state[6:1]}};//这里的作用就是强行将这个模块延迟N个周期再输出结果，使其符合config.json的设�?
    end
    


    wire [63:0] mulres;
    multiplier mul(.CLK(clk),.A(A_reg),.B(B_reg),.P(mulres));

    assign res = mulres[31:0]; // output `res` has only 32 bits

endmodule