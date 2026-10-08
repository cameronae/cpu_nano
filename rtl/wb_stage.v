`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module MEMWB (  
    input clk,
    input mwreg,
    input mm2reg,
    input [4:0] mdestReg,
    input [31:0] mr,
    input [31:0] mdo,
    output reg wwreg,
    output reg wm2reg,
    output reg [4:0] wdestReg,
    output reg [31:0] wr,
    output reg [31:0] wdo
);
always @ (posedge clk) begin
    wwreg <= mwreg;
    wm2reg <= mm2reg;
    wdestReg <= mdestReg;
    wr <= mr;
    wdo <= mdo;
end
endmodule



module WB_MUX (
    input [31:0] wr,
    input [31:0] wdo,
    input wm2reg,
    output reg [31:0] wbData
);

always @(*) begin
     if(wm2reg == 0)
        wbData = wr;
    else
        wbData = wdo;  
end
endmodule


