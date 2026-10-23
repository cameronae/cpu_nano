`timescale 1ns / 1ps

// One accepted request per cycle. The memory captures its address and returns
// data at that edge; IF/ID metadata captures in parallel with the memory output.
module FetchPC #(
    parameter [31:0] RESET_PC = 0
) (
    input clk, reset, enable, redirect,
    input [31:0] redirect_pc, predicted_next_pc,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if (reset) pc <= RESET_PC;
        else if (redirect) pc <= redirect_pc;
        else if (enable) pc <= predicted_next_pc;
    end
endmodule
