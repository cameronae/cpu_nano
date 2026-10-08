`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module EXEMEM (
    input clk,
    input ewreg,
    input em2reg,
    input ewmem,
    input [4:0] edestReg,
    input [31:0] r,
    input [31:0] eqb,
    output reg mwreg,
    output reg mm2reg,
    output reg mwmem, 
    output reg [4:0] mdestReg,
    output reg [31:0] mr,
    output reg [31:0] mqb
);
always @ (posedge clk) begin
    mwreg <= ewreg;
    mm2reg <= em2reg;
    mwmem <= ewmem;
    mdestReg <= edestReg;
    mr <= r;
    mqb <= eqb;
end
endmodule



module DM (
    input [31:0] mr,
    input [31:0] mqb,
    input mwmem,
    input clk,
    output reg [31:0] mdo
);
//if mwmem is 1 memory array at position mr is set to mqb at NEGATIVE EDGE
//mdo is set to value of emmory array at position mr
//do not zero fill the entire array this time
//init values from part 8 in lab doc
reg [31:0] data_mem [0:63];

//initialize first 10 words in data memory
initial begin
    data_mem[0] = 32'hA00000AA;
    data_mem[1] = 32'h10000011;
    data_mem[2] = 32'h20000022;
    data_mem[3] = 32'h30000033;
    data_mem[4] = 32'h40000044;
    data_mem[5] = 32'h50000055;
    data_mem[6] = 32'h60000066;
    data_mem[7] = 32'h70000077;
    data_mem[8] = 32'h80000088;
    data_mem[9] = 32'h90000099;
end
//reading block
always @ (*) begin
    mdo = data_mem[mr >> 2];
end
//writing block
always @ (negedge clk) begin
    if(mwmem == 1) //if mem write is 1 then write to memory
        data_mem[mr >> 2] = mqb; 
end
endmodule


