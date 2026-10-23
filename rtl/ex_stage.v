`timescale 1ns / 1ps
`include "cpu_defs.vh"

module CpuALU (
    input [31:0] a, b,
    input [3:0] operation,
    output reg [31:0] result
);
    always @* begin
        case (operation)
            `ALU_ADD: result = a + b;
            `ALU_SUB: result = a - b;
            `ALU_AND: result = a & b;
            `ALU_OR: result = a | b;
            `ALU_XOR: result = a ^ b;
            `ALU_NOR: result = ~(a | b);
            `ALU_SLT: result = {31'b0, $signed(a) < $signed(b)};
            `ALU_SLTU: result = {31'b0, a < b};
            `ALU_SLL: result = b << a[4:0];
            `ALU_SRL: result = b >> a[4:0];
            `ALU_SRA: result = $signed(b) >>> a[4:0];
            `ALU_LUI: result = {b[15:0], 16'b0};
            default: result = 0;
        endcase
    end
endmodule
