`timescale 1ns / 1ps
// Bounded waveform smoke test. Full architectural checking: make test.
module testbench;
    reg clk;
    reg reset;
    wire [31:0] ia, da, wd;
    wire ien, den;
    wire [3:0] strobes;
    reg [31:0] instruction, read_data;
    reg [31:0] rom [0:63];
    reg [31:0] ram [0:63];
    wire retired, writeback, halted, stalled, redirected;
    wire [31:0] retired_pc, retired_instruction, retired_data, fault_pc;
    wire [4:0] dest;
    wire [3:0] fault, fault_code;
    integer i;
    Datapath dut (
        .clk(clk), .reset(reset), .instruction_address(ia), .instruction_enable(ien),
        .instruction_data(instruction), .instruction_fault(1'b0),
        .data_address(da), .data_write_data(wd), .data_enable(den),
        .data_write_strobes(strobes), .data_read_data(read_data), .data_fault(1'b0),
        .retire_valid(retired), .retire_pc(retired_pc), .retire_instruction(retired_instruction),
        .retire_write(writeback), .retire_destination(dest), .retire_data(retired_data),
        .retire_fault(fault), .halted(halted), .fault_code(fault_code), .fault_pc(fault_pc),
        .load_stall(stalled), .redirect_event(redirected)
    );
    always #5 clk=~clk;
    always @(posedge clk) begin
        if(ien) instruction <= ia<256 ? rom[ia[7:2]] : 32'hffffffff;
        if(den && da<256) begin
            read_data <= ram[da[7:2]];
            for(integer lane=0;lane<4;lane=lane+1)
                if(strobes[lane]) ram[da[7:2]][8*lane +: 8] <= wd[8*lane +: 8];
        end
    end
    initial begin
        clk=0; reset=1; instruction=0; read_data=0;
        for(i=0;i<64;i=i+1) begin rom[i]=32'hffffffff; ram[i]=0; end
        rom[0]=32'h24010007; // addiu $1,$0,7
        rom[1]=32'h00211021; // addu $2,$1,$1
        rom[2]=32'hac020000; // sw $2,0($0)
        rom[3]=32'h8c030000; // lw $3,0($0)
        rom[4]=32'h00612023; // subu $4,$3,$1
        #12 reset=0;
        #300;
        if(!halted || fault_code!=1 || fault_pc!=20 || ram[0]!=14)
            $fatal(1,"Smoke test failed");
        $display("PASS waveform smoke test");
        $finish;
    end
endmodule
