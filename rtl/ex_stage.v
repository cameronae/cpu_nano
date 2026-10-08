`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module IDEXE(
    input clk,
    input stall,          // ADD for bubble injection
    input wreg, m2reg, wmem,
    input [3:0] aluc,
    input aluimm,
    input [4:0] destReg,
    input [31:0] qa, qb, imm32,
    input [31:0] dpc4,
    input [5:0] op,       // ADD to pass opcode through
    output reg ewreg, em2reg, ewmem,
    output reg [3:0] ealuc,
    output reg ealuimm,
    output reg [4:0] edestReg,
    output reg [31:0] eqa, eqb, eimm32,
    output reg [31:0] epc4,   // ADD (was wrongly epc8 before)
    output reg [5:0] eop      // ADD
);
    always @(posedge clk) begin
        if (stall) begin
            // inject bubble — zero all state-modifying controls
            ewreg  <= 0;
            em2reg <= 0;
            ewmem  <= 0;
            ealuc  <= 0;
            ealuimm <= 0;
            edestReg <= 0;
            eqa    <= 0;
            eqb    <= 0;
            eimm32 <= 0;
            epc4   <= 0;
            eop    <= 0;
        end else begin
            ewreg    <= wreg;
            em2reg   <= m2reg;
            ewmem    <= wmem;
            ealuc    <= aluc;
            ealuimm  <= aluimm;
            edestReg <= destReg;
            eqa      <= qa;
            eqb      <= qb;
            eimm32   <= imm32;
            epc4     <= dpc4;   // pass dpc4 forward as epc4
            eop      <= op;
        end
    end
endmodule


module ALU_MUX (
    input [31:0] eqb,
    input [31:0] eimm32,
    input ealuimm,
    output reg [31:0] b
);
    always @ (*) begin
        if(ealuimm == 0)
            b = eqb;
        else
            b = eimm32;
    end
endmodule



module ALU (
    input [31:0] eqa,
    input [31:0] b,
    input [3:0] ealuc,
    output reg [31:0] r 
);
    always @(*) begin
        case(ealuc) 
        4'b0000: begin //AND 
            r = eqa & b;
        end
        4'b0001: begin // OR
            r = eqa | b;
        end
        4'b0010: begin //ADD
            r = eqa + b;
        end
        4'b0110: begin //SUB
            r = eqa - b;
        end
        default: r = 32'b0;
        endcase
    end
endmodule


