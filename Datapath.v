`timescale 1ns / 1ps
`include "cpu_defs.vh"

// Single-issue IF / ID / EX / MEM / WB core. All state uses the rising edge.
// Memory contract: instruction and data reads return REGISTERED data on the
// request edge, hold it when disabled, and never add wait states. See docs/isa.md.
module Datapath #(
    parameter [31:0] RESET_PC = 0,
    parameter PREDICTOR = 1
) (
    input clk, reset,
    output [31:0] instruction_address,
    output instruction_enable,
    input [31:0] instruction_data,
    input instruction_fault,
    output [31:0] data_address, data_write_data,
    output data_enable,
    output [3:0] data_write_strobes,
    input [31:0] data_read_data,
    input data_fault,
    output retire_valid,
    output [31:0] retire_pc, retire_instruction,
    output retire_write,
    output [4:0] retire_destination,
    output [31:0] retire_data,
    output [3:0] retire_fault,
    output reg halted,
    output reg [3:0] fault_code,
    output reg [31:0] fault_pc,
    output load_stall, redirect_event
);
    wire [31:0] f_pc;
    wire [31:0] f_next_pc;
    wire [5:0] f_prediction_index;
    reg stopped;

    // IF/ID instruction storage is the synchronous instruction memory output.
    reg d_valid;
    reg [31:0] d_pc, d_predicted_next_pc;
    reg [5:0] d_prediction_index;
    wire [31:0] d_instruction = instruction_data;
    wire [4:0] d_rs = d_instruction[25:21];
    wire [4:0] d_rt = d_instruction[20:16];
    wire d_write, d_load, d_store, d_imm, d_shift, d_variable;
    wire d_jump, d_jr, d_link, d_uses_rs, d_uses_rt, d_illegal, d_unsigned;
    wire [3:0] d_alu, d_hilo;
    wire [2:0] d_branch;
    wire [1:0] d_size;
    wire [4:0] d_dest;
    wire [31:0] d_immediate, d_a, d_b;

    // ID/EX state.
    reg e_valid, e_write, e_load, e_store, e_imm, e_shift, e_variable;
    reg e_jump, e_jr, e_link, e_unsigned;
    reg [3:0] e_alu, e_fault, e_hilo;
    reg [2:0] e_branch;
    reg [1:0] e_size;
    reg [4:0] e_rs, e_rt, e_dest;
    reg [31:0] e_pc, e_instruction, e_a, e_b, e_immediate;
    reg [31:0] e_predicted_next_pc;
    reg [5:0] e_prediction_index;

    // EX/MEM state.
    reg m_valid, m_write, m_load, m_store, m_unsigned;
    reg [3:0] m_fault;
    reg [1:0] m_size;
    reg [4:0] m_dest;
    reg [31:0] m_pc, m_instruction, m_result, m_store_value;

    // MEM/WB state. Synchronous data memory output is the load-data register.
    reg w_valid, w_write, w_load, w_unsigned;
    reg [3:0] w_fault;
    reg [1:0] w_size, w_offset;
    reg [4:0] w_dest;
    reg [31:0] w_pc, w_instruction, w_result;
    reg [31:0] hi, lo;
    wire [31:0] w_load_value;
    wire [31:0] w_value = w_load ? w_load_value : w_result;
    wire w_enable = w_valid && w_write && w_fault == 0 && !reset;
    wire m_access_fault = m_valid && m_fault == 0 && (m_load || m_store) && data_fault;

    Decode decode_inst (
        .instruction(d_instruction), .reg_write(d_write), .mem_read(d_load),
        .mem_write(d_store), .alu_imm(d_imm), .shift(d_shift),
        .variable_shift(d_variable), .jump(d_jump), .jump_reg(d_jr), .link(d_link),
        .uses_rs(d_uses_rs), .uses_rt(d_uses_rt), .illegal(d_illegal),
        .alu_op(d_alu), .hilo_op(d_hilo), .branch(d_branch), .mem_size(d_size),
        .load_unsigned(d_unsigned), .destination(d_dest), .immediate(d_immediate)
    );
    Regfile regfile_inst (
        .clk(clk), .reset(reset), .rs(d_rs), .rt(d_rt), .write_reg(w_dest),
        .write_data(w_value), .write_enable(w_enable), .read_a(d_a), .read_b(d_b)
    );
    HazardDetection hazards (
        .decode_valid(d_valid), .uses_rs(d_uses_rs), .uses_rt(d_uses_rt),
        .decode_rs(d_rs), .decode_rt(d_rt), .execute_valid(e_valid),
        .execute_load(e_load), .execute_dest(e_dest), .load_use_stall(load_stall)
    );
    wire [31:0] e_forward_a, e_forward_b;
    Forwarding forwarding_inst (
        .rs(e_rs), .rt(e_rt), .mem_dest(m_dest), .wb_dest(w_dest),
        .mem_write_reg(m_valid && m_write && m_fault == 0 && !m_access_fault),
        .mem_load(m_load), .wb_write_reg(w_enable),
        .operand_a(e_a), .operand_b(e_b), .mem_result(m_result), .wb_result(w_value),
        .forwarded_a(e_forward_a), .forwarded_b(e_forward_b)
    );
    wire [31:0] e_alu_a = e_shift ?
        (e_variable ? {27'b0,e_forward_a[4:0]} : {27'b0,e_instruction[10:6]}) : e_forward_a;
    wire [31:0] e_alu_b = e_imm ? e_immediate : e_forward_b;
    wire [31:0] e_alu_result;
    CpuALU alu_inst (.a(e_alu_a), .b(e_alu_b), .operation(e_alu), .result(e_alu_result));
    wire [31:0] e_pc4 = e_pc + 32'd4;
    wire [31:0] e_result = e_link ? e_pc4 :
        e_hilo == `HI_MFHI ? hi : e_hilo == `HI_MFLO ? lo : e_alu_result;
    wire multiply_instruction = e_hilo >= `HI_MULT;
    wire md_busy, md_done;
    wire [31:0] md_hi, md_lo;
    wire execute_hold = e_valid && multiply_instruction && !md_done;
    MulDiv muldiv_inst (
        .clk(clk), .reset(reset || m_access_fault),
        .start(e_valid && multiply_instruction && !md_busy && !md_done &&
               !m_access_fault && !stopped),
        .divide(e_hilo == `HI_DIV || e_hilo == `HI_DIVU),
        .signed_mode(e_hilo == `HI_MULT || e_hilo == `HI_DIV),
        .a(e_forward_a), .b(e_forward_b), .busy(md_busy), .done(md_done),
        .result_hi(md_hi), .result_lo(md_lo)
    );
    wire [31:0] e_branch_target = e_pc4 + (e_immediate << 2);
    reg e_taken;
    always @* begin
        case (e_branch)
            `BR_EQ: e_taken = e_forward_a == e_forward_b;
            `BR_NE: e_taken = e_forward_a != e_forward_b;
            `BR_LEZ: e_taken = $signed(e_forward_a) <= 0;
            `BR_GTZ: e_taken = $signed(e_forward_a) > 0;
            `BR_LTZ: e_taken = e_forward_a[31];
            `BR_GEZ: e_taken = !e_forward_a[31];
            default: e_taken = 0;
        endcase
    end
    wire [31:0] e_target = e_jr ? e_forward_a :
        e_jump ? {e_pc4[31:28],e_instruction[25:0],2'b00} : e_branch_target;
    wire e_transfer = e_jump || e_jr || e_taken;
    reg [3:0] e_detected_fault;
    always @* begin
        e_detected_fault = e_fault;
        if (e_fault == 0) begin
            if (e_transfer && e_target[1:0] != 0) e_detected_fault = `FAULT_IF_ALIGN;
            else if ((e_load || e_store) &&
                ((e_size == `SZ_WORD && e_result[1:0] != 0) ||
                 (e_size == `SZ_HALF && e_result[0])))
                e_detected_fault = e_store ? `FAULT_ST_ALIGN : `FAULT_LD_ALIGN;
        end
    end
    wire e_bad = e_valid && e_detected_fault != 0;
    wire [31:0] e_actual_next_pc = e_transfer ? e_target : e_pc4;
    // Check every instruction, so stale BTB predictions of non-branches recover.
    assign redirect_event = e_valid && !e_bad && !execute_hold &&
        e_actual_next_pc != e_predicted_next_pc && !m_access_fault && !reset;
    BranchPredictor #(.MODE(PREDICTOR)) predictor_inst (
        .clk(clk), .reset(reset), .fetch_pc(f_pc), .predicted_next_pc(f_next_pc),
        .prediction_index(f_prediction_index),
        .update(e_valid && !e_bad && !execute_hold && !m_access_fault && !stopped &&
                (e_branch != `BR_NONE || e_jump || e_jr)),
        .resolved_pc(e_pc), .resolved_target(e_target),
        .resolved_conditional(e_branch != `BR_NONE), .resolved_taken(e_taken),
        .resolved_index(e_prediction_index)
    );
    assign instruction_address = f_pc;
    assign instruction_enable = !reset && !stopped && !load_stall && !execute_hold &&
                                !redirect_event && !e_bad && !m_access_fault;
    FetchPC #(.RESET_PC(RESET_PC)) fetch_pc (
        .clk(clk), .reset(reset), .enable(instruction_enable),
        .redirect(redirect_event), .redirect_pc(e_actual_next_pc),
        .predicted_next_pc(f_next_pc), .pc(f_pc)
    );
    assign data_address = m_result;
    assign data_enable = !reset && m_valid && m_fault == 0 && (m_load || m_store);
    wire [3:0] store_strobes;
    StoreAlign store_align (.value(m_store_value), .offset(m_result[1:0]),
        .size(m_size), .data(data_write_data), .strobes(store_strobes));
    // The memory must also suppress physical writes when it reports a fault.
    assign data_write_strobes = data_enable && m_store ? store_strobes : 4'b0;
    LoadAlign load_align (.word_data(data_read_data), .offset(w_offset),
        .size(w_size), .unsigned_load(w_unsigned), .value(w_load_value));
    assign retire_valid = w_valid && !reset;
    assign retire_pc = w_pc;
    assign retire_instruction = w_instruction;
    assign retire_write = w_enable && w_dest != 0;
    assign retire_destination = w_dest;
    assign retire_data = w_value;
    assign retire_fault = w_fault;

    always @(posedge clk) begin
        if (reset) begin
            stopped <= 0; halted <= 0; fault_code <= 0; fault_pc <= 0;
            hi <= 0; lo <= 0; e_hilo <= 0;
            d_valid <= 0; d_pc <= 0;
            d_predicted_next_pc <= 0; d_prediction_index <= 0;
            e_predicted_next_pc <= 0; e_prediction_index <= 0;
            e_valid <= 0; e_write <= 0; e_load <= 0; e_store <= 0;
            e_imm <= 0; e_shift <= 0; e_variable <= 0; e_jump <= 0; e_jr <= 0;
            e_link <= 0; e_unsigned <= 0; e_alu <= 0; e_fault <= 0;
            e_branch <= 0; e_size <= 0; e_rs <= 0; e_rt <= 0; e_dest <= 0;
            e_pc <= 0; e_instruction <= 0; e_a <= 0; e_b <= 0; e_immediate <= 0;
            m_valid <= 0; m_write <= 0; m_load <= 0; m_store <= 0; m_unsigned <= 0;
            m_fault <= 0; m_size <= 0; m_dest <= 0; m_pc <= 0;
            m_instruction <= 0; m_result <= 0; m_store_value <= 0;
            w_valid <= 0; w_write <= 0; w_load <= 0; w_unsigned <= 0;
            w_fault <= 0; w_size <= 0; w_offset <= 0; w_dest <= 0;
            w_pc <= 0; w_instruction <= 0; w_result <= 0;
        end else begin
            if (e_valid && !m_access_fault && !e_bad && !execute_hold) begin
                if (e_hilo == `HI_MTHI) hi <= e_forward_a;
                if (e_hilo == `HI_MTLO) lo <= e_forward_a;
                if (multiply_instruction && md_done) begin hi <= md_hi; lo <= md_lo; end
            end
            if (w_valid && w_fault != 0) begin
                halted <= 1; fault_code <= w_fault; fault_pc <= w_pc;
            end
            // Older instructions drain even when decode stalls or EX redirects.
            w_valid <= m_valid; w_write <= m_write; w_load <= m_load;
            w_unsigned <= m_unsigned; w_size <= m_size; w_offset <= m_result[1:0];
            w_dest <= m_dest; w_pc <= m_pc; w_instruction <= m_instruction;
            w_result <= m_result;
            w_fault <= m_access_fault ? (m_store ? `FAULT_ST_ACCESS : `FAULT_LD_ACCESS) : m_fault;

            m_valid <= e_valid && !execute_hold; m_write <= e_write; m_load <= e_load;
            m_store <= e_store; m_unsigned <= e_unsigned; m_fault <= e_detected_fault;
            m_size <= e_size; m_dest <= e_dest; m_pc <= e_pc;
            m_instruction <= e_instruction; m_result <= e_result; m_store_value <= e_forward_b;

            if (m_access_fault) begin
                stopped <= 1; d_valid <= 0; e_valid <= 0; m_valid <= 0;
            end else if (e_bad || redirect_event || stopped) begin
                if (e_bad) stopped <= 1;
                d_valid <= 0; e_valid <= 0;
            end else begin
                if (execute_hold) begin
                    // Keep operands after a forwarded producer leaves WB/MEM.
                    e_a <= e_forward_a; e_b <= e_forward_b;
                end else if (load_stall) e_valid <= 0;
                else begin
                    e_valid <= d_valid;
                    e_pc <= d_pc; e_instruction <= d_instruction;
                    e_predicted_next_pc <= d_predicted_next_pc;
                    e_prediction_index <= d_prediction_index;
                    e_write <= d_write; e_load <= d_load; e_store <= d_store;
                    e_imm <= d_imm; e_shift <= d_shift; e_variable <= d_variable;
                    e_jump <= d_jump; e_jr <= d_jr; e_link <= d_link;
                    e_unsigned <= d_unsigned; e_alu <= d_alu; e_branch <= d_branch;
                    e_hilo <= d_hilo;
                    e_size <= d_size; e_rs <= d_rs; e_rt <= d_rt; e_dest <= d_dest;
                    e_immediate <= d_immediate; e_a <= d_a; e_b <= d_b;
                    e_fault <= instruction_fault ? `FAULT_IF_ACCESS :
                        d_pc[1:0] != 0 ? `FAULT_IF_ALIGN :
                        d_illegal ? `FAULT_ILLEGAL : `FAULT_NONE;
                end
                if (instruction_enable) begin
                    d_valid <= 1; d_pc <= f_pc;
                    d_predicted_next_pc <= f_next_pc; d_prediction_index <= f_prediction_index;
                end
            end
        end
    end
endmodule
