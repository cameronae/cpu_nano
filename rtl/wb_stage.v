`timescale 1ns / 1ps
`include "cpu_defs.vh"

module LoadAlign (
    input [31:0] word_data,
    input [1:0] offset, size,
    input unsigned_load,
    output [31:0] value
);
    wire [31:0] shifted = word_data >> {offset, 3'b000};
    assign value = size == `SZ_BYTE ?
        {{24{!unsigned_load && shifted[7]}}, shifted[7:0]} :
        size == `SZ_HALF ? {{16{!unsigned_load && shifted[15]}}, shifted[15:0]} :
        word_data;
endmodule
