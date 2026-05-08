`timescale 1ns / 1ps
// Company: Penn State
// Engineer: [Cameron Reiff]
// 
// Create Date: [4/09/2026]
// Design Name: Lab 5 - Write back stage
// Module Name: datapath
// Project Name: Lab 5 - Write back stage
// Target Devices: XC7Z010-CLG400-1
// Description: Implementation of MEM/WB of the CPU
// 
// Instructions to implement:
//   Address 100: lw $v0, 00($at)  ->  lw $2, 0($1)
//////////////////////////////////////////////////////////////////////////////////
//   Address 104: lw $v1, 04($at)  ->  lw $3, 4($1)
//   Assume register $at ($1) has value 0
//
//////////////////////////////////////////////////////////////////////////////////

//==============================================================================
// TOP-LEVEL DATAPATH MODULE
//==============================================================================
// This module connects all the pipeline stages together.
// Input:  clk - clock signal
// Output: None (all signals are internal)
//
// You need to:
// 1. Declare all internal wires to connect the modules
// 2. Instantiate all 9 modules and connect them properly
// 3. Decode the instruction fields (op, rs, rt, rd, func, imm) from dinstOut
//==============================================================================

module Datapath(
    input clk
);

    // TODO: Declare wires for IF stage
    // Hint: You need wires for pc, nextpc, instOut
    wire [31:0] pc, nextpc, instOut;
    
    // TODO: Declare wire for IF/ID pipeline register output
    // Hint: dinstOut holds the instruction in the ID stage
    wire [31:0] dinstOut;
    wire [5:0] op, func;
    wire[4:0] rs, rt, rd, shamt;
    wire [15:0] imm;
    // TODO: Decode instruction fields from dinstOut
    // Hint: Use assign statements to extract:
    //   Example: op    = dinstOut[31:26]  (6 bits - opcode)
    assign op = dinstOut[31:26];
    assign rs = dinstOut[25:21];
    assign rt = dinstOut[20:16];
    assign rd = dinstOut[15:11];
    assign shamt = dinstOut[10:6];
    assign func = dinstOut[5:0];
    assign imm = dinstOut[15:0];
    
    // TODO: Declare wires for control unit outputs
    // Hint: wreg, m2reg, wmem, aluc[3:0], aluimm, regrt
    wire wreg, m2reg, wmem, aluimm, regrt;
    wire [3:0] aluc;
    // TODO: Declare wires for ID stage
    // Hint: destReg[4:0], qa[31:0], qb[31:0], imm32[31:0]
    wire [4:0] destReg;
    wire [31:0] qa, qb, imm32;
    // TODO: Declare wires for ID/EXE pipeline register outputs
    // Hint: Use 'e' prefix for EXE stage signals (ewreg, em2reg, etc.)
    wire ewreg, em2reg, ewmem, ealuimm;
    wire [3:0] ealuc;
    wire [4:0] edestReg;
    wire [31:0] eqa, eqb, eimm32;

    //DECLARE wires for ALU MUX
    wire [31:0] b;
    

    //DECLARE wires for ALU, other wires already defined
    //only need add for now but can implement them all in this one
    wire [31:0] r;

    //DECLARE wires for EXEMEM pipelein reg
    wire mwreg, mm2reg, mwmem;
    wire [4:0] mdestReg;
    wire [31:0] mr, mqb;

    //DECLARE wires for Data memory
    wire [31:0] mdo;

    //wires for MEM/WB 
    wire wwreg, wm2reg;
    wire [4:0] wdestReg;
    wire [31:0] wr, wdo;

    //wires for WB mux
    wire [31:0] wbData;

    //wires for forwarding a mux
    wire [31:0] fqa;
    wire [1:0] fwda;
    //wires for fowarding b mux
    wire [31:0] fqb;
    wire [1:0] fwdb;
    //==========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF) - Instantiate modules
    //==========================================================================
    // TODO: Instantiate PC (Program Counter)
    PC pc_inst (
        .clk(clk),
        .nextpc(nextpc),
        .pc(pc)
        );
    // TODO: Instantiate PCAdd4 (PC + 4 Adder)
    PCAdd4 pcadd4_inst (
        .pc(pc),
        .nextpc(nextpc)
        );
    // TODO: Instantiate IM (Instruction Memory)        
    IM im_inst (
    .pc(pc),
    .instOut(instOut)
    );
    // TODO: Instantiate IFID (IF/ID Pipeline Register)
    IFID ifid_inst (
    .clk(clk),
    .instOut(instOut),
    .dinstOut(dinstOut)
    );
    //==========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID) - Instantiate modules
    //==========================================================================
    
    // TODO: Instantiate CU (Control Unit)
    CU cu_inst (
    .op(op),
    .func(func),
    .wreg(wreg),
    .m2reg(m2reg),
    .wmem(wmem),
    .aluc(aluc),
    .aluimm(aluimm),
    .regrt(regrt),
    .rs(rs),
    .rt(rt),
    .edestReg(edestReg), //GOING TO BE USED FOR FORWARDING IN THE CU, COMPARE TO RS AND RT TO DETECT HAZARDS
    .mdestReg(mdestReg), //GOING TO BE USED FOR FORWARDING IN THE CU, COMPARE TO RS AND RT TO DETECT HAZARDS
    .fwda(fwda), //FORWARDING A SELECT SIGNAL
    .fwdb(fwdb) //FORWARDING B SELECT SIGNAL
    );
    // TODO: Instantiate Regfile (Register File)
    Regfile regfile_inst (
    .rs(rs),
    .rt(rt),
    .qa(qa),
    .qb(qb),
    .wdestReg(wdestReg),
        .wbData(wbData),
        .wwreg(wwreg),
        .clk(clk)
    );
    // TODO: Instantiate Mux (Regrt Multiplexer)
    
    Mux mux_inst (
    .rd(rd),
    .rt(rt),
    .regrt(regrt),
    .destReg(destReg)
    );
    // TODO: Instantiate Ext (Sign Extender)
    Ext ext_inst (
    .imm(imm),
    .imm32(imm32)
    );
    // TODO: Instantiate IDEXE (ID/EXE Pipeline Register)
    IDEXE idexe_inst (
    .clk(clk),
    .wreg(wreg),
    .m2reg(m2reg),
    .wmem(wmem),
    .aluc(aluc),
    .aluimm(aluimm),
    .destReg(destReg),
    .qa(qa),
    .qb(qb),
    .imm32(imm32),
    .ewreg(ewreg),
    .em2reg(em2reg),
    .ewmem(ewmem),
    .ealuc(ealuc),
    .ealuimm(ealuimm),
    .edestReg(edestReg),
    .eqa(eqa),
    .eqb(eqb),
    .eimm32(eimm32)
    );

    //Instantiate ALU mux
    ALU_MUX alu_mux_inst (
        .eqb(eqb),
        .eimm32(eimm32),
        .ealuimm(ealuimm),
        .b(b)
    );

    //Instantiate ALU
    ALU alu_inst(
    .eqa(eqa),
    .b(b),
    .ealuc(ealuc),
    .r(r)
    );

    //Instantiate EXEMEM pipeline reg
    EXEMEM exemem_inst(
        .ewreg(ewreg),
        .em2reg(em2reg),
        .ewmem(ewmem),
        .edestReg(edestReg),
        .r(r),
        .eqb(eqb),
        .clk(clk),
        .mwreg(mwreg),
        .mm2reg(mm2reg),
        .mwmem(mwmem),
        .mdestReg(mdestReg),
        .mr(mr),
        .mqb(mqb)
    );

    //Instantiate Data memory
    DM dm_inst(
        .clk(clk),
        .mr(mr),
        .mwmem(mwmem),
        .mqb(mqb),
        .mdo(mdo)
    );

    MEMWB memwb_inst (
        .clk(clk),
        .mwreg(mwreg),
        .mm2reg(mm2reg),
        .mdestReg(mdestReg),
        .mr(mr),
        .mdo(mdo),
        .wwreg(wwreg),
        .wm2reg(wm2reg),
        .wdestReg(wdestReg),
        .wr(wr),
        .wdo(wdo)
    );

    WB_MUX wb_mux_inst (
        .wr(wr),
        .wdo(wdo),
        .wm2reg(wm2reg),
        .wbData(wbData)
    );

    //Instantiate forwarding muxes
    FW_MUXA fw_muxa_inst (
        .qa(qa),    
        .r(r), //alu output
        .mr(mr), //excecute output
        .mdo(mdo),//data mem output
        .fwda(fwda),
        .fqa(fqa)
    );
    FW_MUXB fw_muxb_inst (
        .qb(qb),
        .r(r), //alu output
        .mr(mr), //excecute output
        .mdo(mdo),//data mem output
        .fwdb(fwdb),
        .fqb(fqb)
    );

endmodule


//==============================================================================
// STAGE 1: INSTRUCTION FETCH (IF) MODULES
//==============================================================================

//------------------------------------------------------------------------------
// PC - Program Counter
//------------------------------------------------------------------------------
// Holds the address of the current instruction being fetched.
// Starts at address 100 as specified in the lab.
//
// Inputs:
//   clk     - clock signal (update PC on positive edge)
//   nextpc  - the next PC value (PC + 4)
//
// Outputs:
//   pc      - current program counter value (32 bits)
//
// Hints:
//   - Use an initial block to set pc = 100
//   - Use always @(posedge clk) to update pc with nextpc
//   - Use non-blocking assignment (<=) in sequential logic
//------------------------------------------------------------------------------

module PC(
    input clk,
    input [31:0] nextpc,
    output reg [31:0] pc
);
    // TODO: Implement the program counter
    // Initialize pc to 100, update to nextpc on each clock edge
    initial begin
    pc = 100;
    end
    always @(posedge clk) begin
        pc <= nextpc;
    end
endmodule


//------------------------------------------------------------------------------
// PCAdd4 - PC + 4 Adder
//------------------------------------------------------------------------------
// Calculates the address of the next sequential instruction.
//
// Inputs:
//   pc      - current program counter value (32 bits)
//
// Outputs:
//   nextpc  - next program counter value (pc + 4) (32 bits)
//
// Hints:
//   - This is combinational logic, use always @(*)
//------------------------------------------------------------------------------

module PCAdd4(
    input [31:0] pc,
    output reg [31:0] nextpc
);
    // TODO: Implement the PC + 4 adder
    always @(*) begin
        nextpc = pc + 4; //increment
    end
endmodule


//------------------------------------------------------------------------------
// IM - Instruction Memory
//------------------------------------------------------------------------------
// Stores the program instructions. Read-only memory.
// Address 100 (index 25) and 104 (index 26) contain the lw instructions.
//
// Inputs:
//   pc      - program counter (address to read from) (32 bits)
//
// Outputs:
//   instOut - instruction at the given address (32 bits)
//
// Hints:
//   - Declare a reg array: reg [31:0] instructions [0:127]
//   - Use initial block 
//------------------------------------------------------------------------------

//For lab 4 2 new instructions
module IM(
    input [31:0] pc,
    output reg [31:0] instOut
);
    // TODO: Declare instruction memory array
    reg [31:0] instructions [0:63];
    
    // TODO: Initialize instructions at index 25 and 26
    //LAB 4 init 27 and 28
    initial begin
    instructions[29] = 32'h004A3020; //hex eq of add $6, $2, $10
    instructions[28] = 32'h8C25000C; //hex eq of lw $5, 12($1)
    instructions[27] = 32'h8C240008; // hex eq of lw $4, 08($1)
    instructions[26] = 32'h8C230004; //hex equivalent of lw $v1, 04($at)
    instructions[25] = 32'h8C220000; //hex equivalent of lw $v0, 00($at)
    //new instruciton add 6, 2 10
    end
    // TODO: Read instruction based on pc (use pc >> 2 or pc / 4 as index)
    always @(*)begin
        instOut = instructions[pc >> 2];
    end
endmodule


//------------------------------------------------------------------------------
// IFID - IF/ID Pipeline Register
//------------------------------------------------------------------------------
// Stores the instruction fetched in IF stage for use in ID stage.
// Updates on the positive edge of the clock.
//
// Inputs:
//   clk     - clock signal
//   instOut - instruction from instruction memory (32 bits)
//
// Outputs:
//   dinstOut - instruction passed to ID stage (32 bits)
//
// Hints:
//   - Use always @(posedge clk)
//   - Use non-blocking assignment (<=)
//------------------------------------------------------------------------------

module IFID(
    input clk,
    input [31:0] instOut,
    output reg [31:0] dinstOut
);
    // TODO: Implement the IF/ID pipeline register
    always @(posedge clk) begin
        dinstOut <= instOut; //write the instruction to the output instruction
    end
endmodule


//==============================================================================
// STAGE 2: INSTRUCTION DECODE (ID) MODULES
//==============================================================================

//------------------------------------------------------------------------------
// CU - Control Unit
//------------------------------------------------------------------------------
// Generates control signals based on the opcode and function code.
//
// Inputs:
//   op      - opcode field from instruction (6 bits)
//   func    - function field from instruction (6 bits)
//
// Outputs:
//   wreg    - write enable for register file (1 bit)
//   m2reg   - memory to register (1 = load data from memory) (1 bit)
//   wmem    - write enable for data memory (1 bit)
//   aluc    - ALU control signals (4 bits)
//   aluimm  - ALU source B select (1 = use immediate) (1 bit)
//   regrt   - register destination select (0 = rd, 1 = rt) (1 bit)
//
// Hints:
//   - Use a case statement on the opcode
//   - Add a default case to handle undefined opcodes
//------------------------------------------------------------------------------

module CU(
    input [5:0] op,
    input [5:0] func,
    input [4:0] rs,
    input [4:0] rt,
    input [4:0] edestReg,
    input [4:0] mdestReg,
    output reg [1:0] fwda,
    output reg [1:0] fwdb,
    output reg wreg,90
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
    end
endmodule



//------------------------------------------------------------------------------
// Regfile - Register File
//------------------------------------------------------------------------------
// Contains 32 general-purpose registers. Provides two read ports.
// All registers should be initialized to 0.
//
// Inputs:
//   rs      - source register 1 address (5 bits)
//   rt      - source register 2 address (5 bits)
//
// Outputs:
//   qa      - data from register rs (32 bits)
//   qb      - data from register rt (32 bits)
//
// Hints:
//   - Declare a reg array: reg [31:0] registers [0:31]
//   - Use a for loop in initial block to set all registers to 0
//   - Use always @(*) for combinational read logic
//------------------------------------------------------------------------------

//Regfile has four new inputs for the WB lab
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
        registers[1] = 32'h00000000;
        registers[2] = 32'hA00000AA;
        registers[3] = 32'h10000011;
        registers[4] = 32'h20000022;
        registers[5] = 32'h30000033;
        registers[6] = 32'h40000044;
        registers[7] = 32'h50000055;
        registers[8] = 32'h60000066;
        registers[9] = 32'h70000077;
        registers[10] = 32'h80000088;
        registers[11] = 32'h90000099;

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


//------------------------------------------------------------------------------
// Mux - Regrt Multiplexer
//------------------------------------------------------------------------------
// Selects the destination register number.
// For R-type instructions, destination is rd.
// For I-type instructions (like lw), destination is rt.
//
// Inputs:
//   rd      - destination register for R-type (5 bits)
//   rt      - destination register for I-type (5 bits)
//   regrt   - select signal (0 = rd, 1 = rt)
//
// Outputs:
//   destReg - selected destination register (5 bits)
//
// Hints:
//   - Use if-else
//   - When regrt = 0, select rd
//   - When regrt = 1, select rt
//------------------------------------------------------------------------------

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


//------------------------------------------------------------------------------
// Ext - Immediate Extender
//------------------------------------------------------------------------------
// Extends the 16-bit immediate value to 32 bits using sign extension.
//
// Inputs:
//   imm     - 16-bit immediate value from instruction
//
// Outputs:
//   imm32   - 32-bit sign-extended immediate
//
// Hints:
//   - Use concatenation with replication
//   - imm[15] is the sign bit
//   - Replicate the sign bit 16 times and concatenate with original imm
//------------------------------------------------------------------------------

module Ext(
    input [15:0] imm,
    output reg [31:0] imm32
);
    // TODO: Implement sign extension
    always @(*) begin
        imm32 = {{16{imm[15]}}, imm}; //concatenates the 15th bit from imm
    end
endmodule


//------------------------------------------------------------------------------
// IDEXE - ID/EXE Pipeline Register
//------------------------------------------------------------------------------
// Stores all control signals and data from ID stage for use in EXE stage.
// Updates on the positive edge of the clock.
//
// Inputs:
//   clk     - clock signal
//   wreg    - write register enable (1 bit)
//   m2reg   - memory to register (1 bit)
//   wmem    - write memory enable (1 bit)
//   aluc    - ALU control (4 bits)
//   aluimm  - ALU immediate select (1 bit)
//   destReg - destination register (5 bits)
//   qa      - register data A (32 bits)
//   qb      - register data B (32 bits)
//   imm32   - sign-extended immediate (32 bits)
//
// Outputs (active in EXE stage, prefix 'e'):
//   ewreg   - write register enable
//   em2reg  - memory to register
//   ewmem   - write memory enable
//   ealuc   - ALU control
//   ealuimm - ALU immediate select
//   edestReg - destination register
//   eqa     - register data A
//   eqb     - register data B
//   eimm32  - sign-extended immediate
//
// Hints:
//   - Use always @(posedge clk)
//   - Use non-blocking assignments (<=)
//   - Transfer each input to its corresponding output
//------------------------------------------------------------------------------

module IDEXE(
    input clk,
    input wreg,
    input m2reg,
    input wmem,
    input [3:0] aluc,
    input aluimm,
    input [4:0] destReg,
    input [31:0] qa,
    input [31:0] qb,
    input [31:0] imm32,
    output reg ewreg,
    output reg em2reg,
    output reg ewmem,
    output reg [3:0] ealuc,
    output reg ealuimm,
    output reg [4:0] edestReg,
    output reg [31:0] eqa,
    output reg [31:0] eqb,
    output reg [31:0] eimm32
);
    // TODO: Implement the ID/EXE pipeline register
    always @(posedge clk) begin
        ewreg <= wreg;
        em2reg <= m2reg;
        ewmem <= wmem;
        ealuc <= aluc;
        ealuimm <= aluimm;
        edestReg <= destReg;
        eqa <= qa;
        eqb <= qb;
        eimm32 <= imm32;
    end
endmodule

//implement the alu mux 
//if ealuimm is 0 b = eqb else = eimm32
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

//Implement the ALU
//computes eqa and b bases on ealuc r is result
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

//instantiate Data Memory
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

//instantiate the EXEMEM
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

module FW_MUXA (
    input [31:0] qa,
    input [31:0] r, //alu output
    input [31:0] mr, //excecute output
    input [31:0] mdo,//data mem output
    input [1:0] fwda,
    output reg [31:0] fqa
);
always@(*) begin
    case(fwda)
        2'b00: fqa = qa;
        2'b01: fqa = r;
        2'b10: fqa = mr;
        2'b11: fqa = mdo;
        default: fqa = qa;
    endcase 
end
endmodule

module FW_MUXB (
    input [31:0] qb,
    input [31:0] r, //alu output
    input [31:0] mr, //excecute output
    input [31:0] mdo,//data mem output
    input [1:0] fwdb,
    output reg [31:0] fqb
);
always@(*) begin
    case(fwdb)
        2'b00: fqb = qb;
        2'b01: fqb = r;
        2'b10: fqb = mr;    
        2'b11: fqb = mdo;
        default: fqb = qb;
    endcase 
end
endmodule
