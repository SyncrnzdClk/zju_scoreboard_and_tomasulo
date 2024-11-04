`timescale 1ns / 1ps

module FU_div(
    input clk, EN,
    input[31:0] A, B,
    output[31:0] res
);
    reg TO_BE_FILLED = 0;
    wire res_valid;
    wire[63:0] divres;
    
    reg [23:0] state; // set laytency as 23 (please refer to config.json)
    initial begin
        state = 0;
    end

    reg A_valid, B_valid;
    reg[31:0] A_reg, B_reg;

    always@(posedge clk) begin
        if(EN & ~state) begin
            A_reg <= A;
            B_reg <= B;
            A_valid <= 1;
            B_valid <= 1;
            state <= 24'b1 << 23; // not sure whether this is the same as just setting a long number (maybe this takes more time in one cycle?)
        end
        else if(res_valid) begin
            A_valid <= 0;
            B_valid <= 0;
            state <= 0;
        end
    end
    

    divider div(.aclk(clk),
        .s_axis_dividend_tvalid(A_valid),
        .s_axis_dividend_tdata(A_reg),
        .s_axis_divisor_tvalid(B_valid), 
        .s_axis_divisor_tdata(B_reg),
        .m_axis_dout_tvalid(res_valid), 
        .m_axis_dout_tdata(divres)
    );

    assign res = divres[31:0]; // the output `res` has only 32 bits

endmodule