`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module PC(
    input clk,
    input [31:0] nextpc,
    input wpcir,
    output reg [31:0] pc
);
    // TODO: Implement the program counter
    // Initialize pc to 100, update to nextpc on each clock edge
    initial begin
    pc = 100;
    end
    always @(posedge clk) begin
        if(wpcir) //only update if no stall
            pc <= nextpc;
    end
endmodule




module PCAdd4(
    input [31:0] pc,
    output reg [31:0] nextpc
);
    // TODO: Implement the PC + 4 adder
    always @(*) begin
        nextpc = pc + 4; //increment
    end
endmodule




module IM(
    input [31:0] pc,
    output reg [31:0] instOut
);
    // TODO: Declare instruction memory array
    reg [31:0] instructions [0:63];
    
    // TODO: Initialize instructions at index 25 and 26
    //LAB 4 init 27 and 28
    initial begin
   instructions[25] = 32'h00221820; // add $3, $1, $2
   instructions[26] = 32'h01232022; // sub $4, $9, $3
   instructions[27] = 32'h00692825; // or  $5, $3, $9
   instructions[28] = 32'h00693026; // xor $6, $3, $9
   instructions[29] = 32'h00693824; // and $7, $3, $9  //new instruciton add 6, 2 10
    end
    // TODO: Read instruction based on pc (use pc >> 2 or pc / 4 as index)
    always @(*)begin
        instOut = instructions[pc >> 2];
    end
endmodule




module IFID(
    input clk,
    input [31:0] instOut,
    input [31:0] pc4,
    input wpcir,
    output reg [31:0] dpc4,
    output reg [31:0] dinstOut
);
    // TODO: Implement the IF/ID pipeline register
    always @(posedge clk) begin
        if (wpcir) begin    // only latch if no stall
            dinstOut <= instOut;
            dpc4     <= pc4;
        end
    end
endmodule



