`timescale 1ns / 1ps
`include "cpu_defs.vh"

// Decode records exactly which source registers are read, for hazard detection.
module Decode (
    input [31:0] instruction,
    output reg reg_write, mem_read, mem_write, alu_imm,
    output reg shift, variable_shift, jump, jump_reg, link,
    output reg uses_rs, uses_rt, illegal,
    output reg [3:0] alu_op,
    output reg [3:0] hilo_op,
    output reg [2:0] branch,
    output reg [1:0] mem_size,
    output reg load_unsigned,
    output reg [4:0] destination,
    output reg [31:0] immediate
);
    wire [5:0] op = instruction[31:26];
    wire [5:0] funct = instruction[5:0];
    always @* begin
        reg_write = 0; mem_read = 0; mem_write = 0; alu_imm = 0;
        shift = 0; variable_shift = 0; jump = 0; jump_reg = 0; link = 0;
        uses_rs = 0; uses_rt = 0; illegal = 0;
        alu_op = `ALU_ADD; branch = `BR_NONE; hilo_op = `HI_NONE;
        mem_size = `SZ_WORD; load_unsigned = 0;
        destination = instruction[20:16];
        immediate = {{16{instruction[15]}}, instruction[15:0]};
        case (op)
            6'h00: begin
                destination = instruction[15:11];
                case (funct)
                    6'h20, 6'h21: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_ADD; end
                    6'h22, 6'h23: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_SUB; end
                    6'h24: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_AND; end
                    6'h25: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_OR; end
                    6'h26: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_XOR; end
                    6'h27: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_NOR; end
                    6'h2a: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_SLT; end
                    6'h2b: begin reg_write=1; uses_rs=1; uses_rt=1; alu_op=`ALU_SLTU; end
                    6'h00, 6'h02, 6'h03, 6'h04, 6'h06, 6'h07: begin
                        reg_write=1; uses_rt=1; shift=1;
                        variable_shift=funct[2]; uses_rs=funct[2];
                        case (funct[1:0])
                            2'b00: alu_op=`ALU_SLL;
                            2'b10: alu_op=`ALU_SRL;
                            default: alu_op=`ALU_SRA;
                        endcase
                    end
                    6'h08: begin jump_reg=1; uses_rs=1; end
                    6'h09: begin jump_reg=1; uses_rs=1; link=1; reg_write=1; end
                    6'h10: begin hilo_op=`HI_MFHI; reg_write=1; end
                    6'h12: begin hilo_op=`HI_MFLO; reg_write=1; end
                    6'h11: begin hilo_op=`HI_MTHI; uses_rs=1; end
                    6'h13: begin hilo_op=`HI_MTLO; uses_rs=1; end
                    6'h18: begin hilo_op=`HI_MULT; uses_rs=1; uses_rt=1; end
                    6'h19: begin hilo_op=`HI_MULTU; uses_rs=1; uses_rt=1; end
                    6'h1a: begin hilo_op=`HI_DIV; uses_rs=1; uses_rt=1; end
                    6'h1b: begin hilo_op=`HI_DIVU; uses_rs=1; uses_rt=1; end
                    default: illegal=1;
                endcase
            end
            6'h08, 6'h09: begin reg_write=1; alu_imm=1; uses_rs=1; end
            6'h0a: begin reg_write=1; alu_imm=1; uses_rs=1; alu_op=`ALU_SLT; end
            6'h0b: begin reg_write=1; alu_imm=1; uses_rs=1; alu_op=`ALU_SLTU; end
            6'h0c, 6'h0d, 6'h0e: begin
                reg_write=1; alu_imm=1; uses_rs=1;
                immediate={16'b0,instruction[15:0]};
                case (op)
                    6'h0c: alu_op=`ALU_AND;
                    6'h0d: alu_op=`ALU_OR;
                    default: alu_op=`ALU_XOR;
                endcase
            end
            6'h0f: begin reg_write=1; alu_imm=1; alu_op=`ALU_LUI; end
            6'h20, 6'h21, 6'h23, 6'h24, 6'h25: begin
                reg_write=1; mem_read=1; alu_imm=1; uses_rs=1;
                load_unsigned=op[2];
                case (op[1:0])
                    2'b00: mem_size=`SZ_BYTE;
                    2'b01: mem_size=`SZ_HALF;
                    default: mem_size=`SZ_WORD;
                endcase
            end
            6'h28, 6'h29, 6'h2b: begin
                mem_write=1; alu_imm=1; uses_rs=1; uses_rt=1;
                case (op[1:0])
                    2'b00: mem_size=`SZ_BYTE;
                    2'b01: mem_size=`SZ_HALF;
                    default: mem_size=`SZ_WORD;
                endcase
            end
            6'h04: begin uses_rs=1; uses_rt=1; branch=`BR_EQ; end
            6'h05: begin uses_rs=1; uses_rt=1; branch=`BR_NE; end
            6'h06: begin uses_rs=1; branch=`BR_LEZ; illegal=(instruction[20:16]!=0); end
            6'h07: begin uses_rs=1; branch=`BR_GTZ; illegal=(instruction[20:16]!=0); end
            6'h01: begin
                uses_rs=1;
                case (instruction[20:16])
                    5'd0: branch=`BR_LTZ;
                    5'd1: branch=`BR_GEZ;
                    default: illegal=1;
                endcase
            end
            6'h02: jump=1;
            6'h03: begin jump=1; link=1; reg_write=1; destination=5'd31; end
            default: illegal=1;
        endcase
    end
endmodule

// Same-edge WB->ID bypass avoids dependence on falling-edge register writes.
module Regfile (
    input clk, reset,
    input [4:0] rs, rt, write_reg,
    input [31:0] write_data,
    input write_enable,
    output [31:0] read_a, read_b
);
    reg [31:0] registers [0:31];
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i=0; i<32; i=i+1) registers[i] <= 0;
        end else if (write_enable && write_reg != 0)
            registers[write_reg] <= write_data;
    end
    assign read_a = rs == 0 ? 32'b0 :
                    (write_enable && write_reg == rs ? write_data : registers[rs]);
    assign read_b = rt == 0 ? 32'b0 :
                    (write_enable && write_reg == rt ? write_data : registers[rt]);
endmodule
