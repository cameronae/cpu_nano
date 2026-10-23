`timescale 1ns / 1ps
`include "cpu_defs.vh"

// Little-endian byte lanes, for synchronous 32-bit memory with write enables.
module StoreAlign (
    input [31:0] value,
    input [1:0] offset, size,
    output [31:0] data,
    output [3:0] strobes
);
    assign data = value << {offset, 3'b000};
    assign strobes = size == `SZ_BYTE ? (4'b0001 << offset) :
                     size == `SZ_HALF ? (4'b0011 << offset) : 4'b1111;
endmodule
