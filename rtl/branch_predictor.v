`timescale 1ns / 1ps

// MODE 0: sequential fetch, 1: bimodal, 2: resolved-history gshare.
// 64 direct-mapped tagged targets + 64 two-bit direction counters.
module BranchPredictor #(
    parameter MODE = 1
) (
    input clk, reset,
    input [31:0] fetch_pc,
    output [31:0] predicted_next_pc,
    output [5:0] prediction_index,
    input update,
    input [31:0] resolved_pc, resolved_target,
    input resolved_conditional, resolved_taken,
    input [5:0] resolved_index
);
    generate if (MODE == 0) begin: disabled
        assign predicted_next_pc = fetch_pc + 32'd4;
        assign prediction_index = 0;
    end else begin: enabled
        reg [63:0] valid;
        reg [23:0] tags [0:63];
        reg [29:0] targets [0:63];
        reg conditional [0:63];
        reg [1:0] counters [0:63];
        reg [5:0] history;
        wire [5:0] fetch_slot = fetch_pc[7:2];
        wire [5:0] update_slot = resolved_pc[7:2];
        wire hit = valid[fetch_slot] && tags[fetch_slot] == fetch_pc[31:8];
        assign prediction_index = MODE == 2 ? fetch_slot ^ history : fetch_slot;
        wire taken = hit && (!conditional[fetch_slot] || counters[prediction_index][1]);
        assign predicted_next_pc = taken ? {targets[fetch_slot],2'b00} : fetch_pc + 32'd4;
        integer i;
        always @(posedge clk) begin
            if (reset) begin
                valid <= 0; history <= 0;
                // Target/tag contents need no reset: valid gates every lookup.
                for (i=0;i<64;i=i+1) counters[i] <= 2'b01;
            end else if (update) begin
                valid[update_slot] <= 1;
                tags[update_slot] <= resolved_pc[31:8];
                targets[update_slot] <= resolved_target[31:2];
                conditional[update_slot] <= resolved_conditional;
                if (resolved_conditional) begin
                    if (resolved_taken && counters[resolved_index] != 2'b11)
                        counters[resolved_index] <= counters[resolved_index] + 1'b1;
                    else if (!resolved_taken && counters[resolved_index] != 2'b00)
                        counters[resolved_index] <= counters[resolved_index] - 1'b1;
                    // History is deliberately non-speculative, simplifying recovery.
                    history <= {history[4:0],resolved_taken};
                end
            end
        end
    end endgenerate
endmodule
