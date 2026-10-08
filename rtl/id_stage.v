`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module CU(
    input [5:0] op,
    input [5:0] func,
    input [4:0] rs,
    input [4:0] rt,
    input [4:0] edestReg,
    input [4:0] mdestReg,
    input rsrtequ, //for branch predict logic
    output reg [1:0] pcsrc, //for branch predict logic
    output reg [1:0] fwda,
    output reg [1:0] fwdb,
    output reg wreg,
    output reg m2reg,
    output reg wmem,
    output reg [3:0] aluc,
    output reg aluimm,
    output reg regrt
);
    // TODO: Implement the control unit using a case statement
    always @(*) begin
        case(op)
            6'b000000: //r-type
            begin
                case (func)
                    6'b100000: //add instruction 
                    begin
                        wreg = 1;
                        m2reg = 0;
                        wmem = 0;
                        aluc = 4'b0010;
                        aluimm = 0;
                        regrt = 0;
                    end
                default: begin //default case all to 0
                wreg = 0;
                m2reg = 0;
                wmem = 0;
                aluc = 4'b0000;
                aluimm = 0;
                regrt = 0;
                end
            endcase             
           end
            6'b100011: //LW instruction
            begin
                wreg = 1;
                m2reg = 1;
                wmem = 0;
                aluc = 4'b0010;
                aluimm = 1;
                regrt = 1;
            end
            default: begin
                wreg = 0;
                m2reg = 0;
                wmem = 0;
                aluc = 4'b0000;
                aluimm = 0;
                regrt = 0;
            end
        endcase
        //forwarding logic
        //if rs or rt match destreg then its a stall then forward
        //if rs or rt match the edestReg then ALU to ALU forward
       if (rs == edestReg && edestReg != 0) begin
            fwda = 2'b01; // forward from ALU output
        end else if (rs == mdestReg && mdestReg != 0) begin
            fwda = 2'b10; // forward from memory output
        end else begin
            fwda = 2'b00; // no forwarding
        end

        // Forwarding B (rt)
        if (rt == edestReg && edestReg != 0) begin
            fwdb = 2'b01; 
        end else if (rt == mdestReg && mdestReg != 0) begin
            fwdb = 2'b10; 
        end else begin
            fwdb = 2'b00; 
        end

        if (op == 6'h02 || op == 6'h03)  
            pcsrc = 2'b11; // j, jal
        else if (op == 6'h00 && func == 6'h08)         
            pcsrc = 2'b10; // jr
        else if ((op == 6'h04 &&  rsrtequ) || (op == 6'h05 && !rsrtequ))
            pcsrc = 2'b01; // beq/bne taken
        else  
            pcsrc = 2'b00; // pc+4
    end
endmodule





module Regfile(
    input [4:0] rs,
    input [4:0] rt,
    input [31:0] wbData,
    input [4:0] wdestReg,
    input wwreg,
    input clk,
    output reg [31:0] qa,
    output reg [31:0] qb
);
    // TODO: Declare register array
    reg [31:0] registers [0:31];
    // TODO: Initialize all 32 registers to 0
    integer i;
    initial begin
        for(i = 0; i < 32; i = i + 1) begin //iterate through register array and init all to 0
            registers[i] = 0;
        end
    end

    initial begin
        registers[0] = 32'h00000000;
        registers[1] = 32'hA00000AA;
        registers[2] = 32'h10000011;
        registers[3] = 32'h20000022;
        registers[4] = 32'h30000033;
        registers[5] = 32'h40000044;
        registers[6] = 32'h50000055;
        registers[7] = 32'h60000066;
        registers[8] = 32'h70000077;
        registers[9] = 32'h80000088;
        registers[10] = 32'h90000099;

    end
  
    // TODO: Read registers based on rs and rt
    //qa is rs and qb is rt
    always @(*) begin
        qa <= registers[rs];
        qb <= registers[rt];
    end
    //if write back is 1 then set the desired register to the write back data
    always @(negedge clk) begin
        if(wwreg == 1)
            registers[wdestReg] <= wbData;
    end
endmodule




module Mux(
    input [4:0] rd,
    input [4:0] rt,
    input regrt,
    output reg [4:0] destReg
);
    // TODO: Implement the multiplexer
    always @(*) begin
        if(regrt == 0) 
            destReg = rd;
        else
            destReg = rt;
    end
endmodule




module Ext(
    input [15:0] imm,
    output reg [31:0] imm32
);
    // TODO: Implement sign extension
    always @(*) begin
        imm32 = {{16{imm[15]}}, imm}; //concatenates the 15th bit from imm
    end
endmodule



