`timescale 1ns / 1ps

// Harvard memories with registered read ports suitable for block-RAM inference.
// Capacities are powers of two: IMEM_WORDS=2^IMEM_ADDR_BITS, similarly for data.
module CpuSystem #(
    parameter IMEM_ADDR_BITS = 10,
    parameter DMEM_ADDR_BITS = 10,
    parameter PROGRAM_FILE = "programs/demo.hex",
    parameter PREDICTOR = 1
) (
    input clk, reset,
    output reg [31:0] led_value,
    output halted,
    output [3:0] fault_code,
    output [31:0] fault_pc,
    output retire_valid,
    output [31:0] retire_pc, retire_instruction,
    output retire_write,
    output [4:0] retire_destination,
    output [31:0] retire_data,
    output [3:0] retire_fault,
    output load_stall, redirect_event
);
    localparam IMEM_WORDS = 1 << IMEM_ADDR_BITS;
    localparam DMEM_WORDS = 1 << DMEM_ADDR_BITS;
    reg [31:0] instruction_memory [0:IMEM_WORDS-1];
    reg [31:0] data_memory [0:DMEM_WORDS-1];
    wire [31:0] ia, da, wd;
    wire ien, den;
    wire [3:0] strobes;
    reg [31:0] instruction, read_data;
    reg ifault;
    wire instruction_in_range = (ia >> (IMEM_ADDR_BITS+2)) == 0;
    wire data_in_range = (da >> (DMEM_ADDR_BITS+2)) == 0;
    wire led_select = da[31:2] == 30'h3fffc000;
    wire dfault = den && !data_in_range && !led_select;
    integer i, lane;
    initial begin
        for (i=0;i<IMEM_WORDS;i=i+1) instruction_memory[i]=32'hffffffff;
        for (i=0;i<DMEM_WORDS;i=i+1) data_memory[i]=0;
        if (PROGRAM_FILE != "") $readmemh(PROGRAM_FILE, instruction_memory);
    end
    // No array reset: reset loops over RAM prevent efficient B-SRAM inference.
    always @(posedge clk) begin
        if (ien) begin
            instruction <= instruction_in_range ? instruction_memory[ia[IMEM_ADDR_BITS+1:2]] : 0;
            ifault <= !instruction_in_range;
        end
        if (den && data_in_range) begin
            read_data <= data_memory[da[DMEM_ADDR_BITS+1:2]];
            for (lane=0;lane<4;lane=lane+1)
                if (strobes[lane]) data_memory[da[DMEM_ADDR_BITS+1:2]][lane*8 +: 8] <= wd[lane*8 +: 8];
        end else if (den && led_select) read_data <= led_value;
        if (reset) led_value <= 0;
        else if (den && led_select) begin
            for (lane=0;lane<4;lane=lane+1)
                if (strobes[lane]) led_value[lane*8 +: 8] <= wd[lane*8 +: 8];
        end
    end
    Datapath #(.PREDICTOR(PREDICTOR)) core (
        .clk(clk), .reset(reset), .instruction_address(ia), .instruction_enable(ien),
        .instruction_data(instruction), .instruction_fault(ifault),
        .data_address(da), .data_write_data(wd), .data_enable(den),
        .data_write_strobes(strobes), .data_read_data(read_data), .data_fault(dfault),
        .retire_valid(retire_valid), .retire_pc(retire_pc), .retire_instruction(retire_instruction),
        .retire_write(retire_write), .retire_destination(retire_destination), .retire_data(retire_data),
        .retire_fault(retire_fault), .halted(halted), .fault_code(fault_code), .fault_pc(fault_pc),
        .load_stall(load_stall), .redirect_event(redirect_event)
    );
endmodule
