`timescale 1ns / 1ps
module board_testbench;
    reg clk, reset_n;
    wire [5:0] led_n;
    TangNano20K dut (.clk(clk), .reset_n(reset_n), .led_n(led_n));
    always #5 clk=~clk;
    initial begin
        clk=0; reset_n=1;
        #100;
        if(led_n!=6'b111111) $fatal(1,"Startup reset did not clear LEDs");
        #2900;
        if(led_n!=6'b111110) $fatal(1,"Demo did not write LED MMIO after startup");
        reset_n=0; #50;
        if(led_n!=6'b111111) $fatal(1,"Synchronized button reset failed");
        reset_n=1; #200;
        if(led_n!=6'b111110) $fatal(1,"Demo did not restart after button reset");
        $display("PASS board startup, demo program, active-low LEDs, button reset");
        $finish;
    end
endmodule
