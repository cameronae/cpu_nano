`timescale 1ns / 1ps

module TangNano20K #(
    parameter PREDICTOR = 1,
    parameter IMEM_ADDR_BITS = 10,
    parameter DMEM_ADDR_BITS = 10
) (
    input clk,        // Board 27 MHz oscillator, pin 4.
    input reset_n,    // S1, active low, pin 88.
    output [5:0] led_n
);
    // Configuration initializes the startup counter; the CPU has explicit reset.
    reg [7:0] startup;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;
    initial begin startup=0; reset_sync=0; end
    always @(posedge clk) begin
        if (!(&startup)) startup <= startup + 1'b1;
        reset_sync <= {reset_sync[0],reset_n};
    end
    wire reset = !(&startup) || !reset_sync[1];
    wire [31:0] led_value, fault_pc, retire_pc, retire_instruction, retire_data;
    wire [3:0] fault_code, retire_fault;
    wire [4:0] retire_destination;
    wire halted, retire_valid, retire_write, load_stall, redirect_event;
    CpuSystem #(.PREDICTOR(PREDICTOR), .IMEM_ADDR_BITS(IMEM_ADDR_BITS),
                .DMEM_ADDR_BITS(DMEM_ADDR_BITS)) system_inst (
        .clk(clk), .reset(reset), .led_value(led_value), .halted(halted),
        .fault_code(fault_code), .fault_pc(fault_pc), .retire_valid(retire_valid),
        .retire_pc(retire_pc), .retire_instruction(retire_instruction),
        .retire_write(retire_write), .retire_destination(retire_destination),
        .retire_data(retire_data), .retire_fault(retire_fault),
        .load_stall(load_stall), .redirect_event(redirect_event)
    );
    // A halt lights LEDs 4/5 and displays the fault code in the lower four.
    assign led_n = halted ? ~{2'b11,fault_code} : ~led_value[5:0];
endmodule
