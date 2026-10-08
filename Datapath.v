`timescale 1ns / 1ps
// Top-level five-stage pipelined CPU datapath.
// Supporting modules are organized in the rtl/ directory.
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

    //wires for branch predict
    wire rsrtequ; //output of the equ comparator INPUT OF CU 
    wire [31:0] bpc; //branch pc counter, addr + imm 
    wire [31:0] jpc; //jump pc counter, just addr
    wire [31:0] dpc4; //pc + 4 from the id stage
    wire [31:0] epc8; //pc + 8 from the exe stage = dpc4 + 4
    wire [31:0] npc; //next pc value after branch predict logic
    wire [1:0] pcsrc; //pc source select signal from the control unit

    wire [31:0] pc4;        // pc + 4 (combinational, before IF/ID)
    wire [31:0] epc4;       // dpc4 passed through ID/EXE register
    wire [4:0]  ern, ern0;  // exe stage dest reg (after jal mux)
    wire [5:0]  eop;        // exe stage opcode (passed through ID/EXE)
    wire ejal;       // is current EXE instruction a jal
    wire [31:0] ealu;       // final ALU/jal result
    wire stall, wpcir;
    wire i_rs, i_rt;
    assign pc4 = pc + 4; //combinational logic for pc + 4
    

    assign rsrtequ = ~|(fqa ^ fqb); //if qa and qb are equal then rsrtequ is 1 else 0
    // CU outputs feed INTO these
    assign npc = (pcsrc == 2'b00) ? pc4  :
             (pcsrc == 2'b01) ? bpc  :
             (pcsrc == 2'b10) ? fqa  :
                                jpc  ;
    assign bpc = dpc4 + {{14{dinstOut[15]}}, dinstOut[15:0], 2'b00};
    assign jpc = {dpc4[31:28], dinstOut[25:0], 2'b00};

    // i_rs: instructions that read rs
assign i_rs = (op == 6'h00) | (op == 6'h23) | (op == 6'h2b) |
              (op == 6'h04) | (op == 6'h05) | (op == 6'h08) |
              (op == 6'h09) | (op == 6'h0c) | (op == 6'h0d) |
              (op == 6'h0e) | (op == 6'h02) | (op == 6'h03);

assign i_rt = (op == 6'h00) | (op == 6'h2b) |
              (op == 6'h04) | (op == 6'h05);

assign stall = ewreg & em2reg & (edestReg != 5'b0) &
               ((i_rs & (edestReg == rs)) | (i_rt & (edestReg == rt)));
assign wpcir = ~stall;
           assign epc8 = epc4 + 4;
assign ejal = (eop == 6'h03);
assign ern  = ejal ? 5'd31 : edestReg;  // ern0 is just edestReg
assign ealu = ejal ? epc8  : r;         // r is your ALU output wire
    //==========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF) - Instantiate modules
    //==========================================================================
    // TODO: Instantiate PC (Program Counter)
    PC pc_inst (
        .clk(clk),
        .nextpc(npc),
        .wpcir(wpcir),
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
    .wpcir(wpcir),
    .dpc4(dpc4),
    .pc4(pc4),
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
    .rsrtequ(rsrtequ),
    .pcsrc(pcsrc),
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
    .stall(stall),
    .wreg(wreg),
    .m2reg(m2reg),
    .wmem(wmem),
    .aluc(aluc),
    .aluimm(aluimm),
    .destReg(destReg),
    .qa(fqa), //forwarding logic
    .qb(fqb), //forwarding logic
    .op(op), //for branch predict logic
    .dpc4(dpc4), //for branch target calculation
    .epc4(epc4), //passed through for jal link address
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
        .edestReg(ern),
        .r(ealu),
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



