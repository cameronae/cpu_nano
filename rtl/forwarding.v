`timescale 1ns / 1ps
// RTL modules grouped by pipeline stage/function.

module FW_MUXA (
    input [31:0] qa,
    input [31:0] r, //alu output
    input [31:0] mr, //excecute output
    input [31:0] mdo,//data mem output
    input [1:0] fwda,
    output reg [31:0] fqa
);
always@(*) begin
    case(fwda)
        2'b00: fqa = qa;
        2'b01: fqa = r;
        2'b10: fqa = mr;
        2'b11: fqa = mdo;
        default: fqa = qa;
    endcase 
end
endmodule



module FW_MUXB (
    input [31:0] qb,
    input [31:0] r, //alu output
    input [31:0] mr, //excecute output
    input [31:0] mdo,//data mem output
    input [1:0] fwdb,
    output reg [31:0] fqb
);
always@(*) begin
    case(fwdb)
        2'b00: fqb = qb;
        2'b01: fqb = r;
        2'b10: fqb = mr;    
        2'b11: fqb = mdo;
        default: fqb = qb;
    endcase 
end
endmodule

