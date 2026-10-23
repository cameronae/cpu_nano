`timescale 1ns / 1ps
module system_testbench;
    reg clk;
    reg reset;
    wire [31:0] led_value, fault_pc, retired_pc, retired_instruction, retired_data;
    wire [3:0] fault_code, retired_fault;
    wire [4:0] destination;
    wire halted, retired, writeback, stalled, redirected;
    CpuSystem #(.PROGRAM_FILE("programs/selftest.hex")) dut (
        .clk(clk), .reset(reset), .led_value(led_value), .halted(halted),
        .fault_code(fault_code), .fault_pc(fault_pc), .retire_valid(retired),
        .retire_pc(retired_pc), .retire_instruction(retired_instruction),
        .retire_write(writeback), .retire_destination(destination), .retire_data(retired_data),
        .retire_fault(retired_fault), .load_stall(stalled), .redirect_event(redirected)
    );
    always #5 clk=~clk;
    integer count;
    initial begin
        clk=0; reset=1; count=0;
        #12 reset=0;
        // 128*128 in the iterative unit => LED/MMIO value 16384.
        while(!halted && count<500) begin #10; count=count+1; end
        if(!halted || fault_code!=1 || fault_pc!=52 || led_value!=16384 ||
            dut.data_memory[0]!=32'h0080ff80 || dut.data_memory[1]!=16384)
            $fatal(1,"Synchronous RAM/MMIO integration failed");
        #50;
        if(led_value!=16384) $fatal(1,"Younger MMIO store escaped fault squash");
        reset=1; #20;
        if(led_value!=0 || halted) $fatal(1,"System reset failed");
        $display("PASS synchronous RAM, byte lanes, MMIO, fault squash, reset");
        $finish;
    end
endmodule
