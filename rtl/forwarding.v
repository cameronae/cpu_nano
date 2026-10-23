`timescale 1ns / 1ps

module Forwarding (
    input [4:0] rs, rt, mem_dest, wb_dest,
    input mem_write_reg, mem_load, wb_write_reg,
    input [31:0] operand_a, operand_b, mem_result, wb_result,
    output [31:0] forwarded_a, forwarded_b
);
    // EX/MEM wins over MEM/WB. A load's address is never forwarded as data.
    assign forwarded_a = rs == 0 ? 32'b0 :
        (mem_write_reg && !mem_load && mem_dest != 0 && mem_dest == rs) ? mem_result :
        (wb_write_reg && wb_dest != 0 && wb_dest == rs) ? wb_result : operand_a;
    assign forwarded_b = rt == 0 ? 32'b0 :
        (mem_write_reg && !mem_load && mem_dest != 0 && mem_dest == rt) ? mem_result :
        (wb_write_reg && wb_dest != 0 && wb_dest == rt) ? wb_result : operand_b;
endmodule

module HazardDetection (
    input decode_valid, uses_rs, uses_rt,
    input [4:0] decode_rs, decode_rt,
    input execute_valid, execute_load,
    input [4:0] execute_dest,
    output load_use_stall
);
    assign load_use_stall = decode_valid && execute_valid && execute_load &&
        execute_dest != 0 && ((uses_rs && decode_rs == execute_dest) ||
                             (uses_rt && decode_rt == execute_dest));
endmodule
