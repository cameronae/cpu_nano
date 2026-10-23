`timescale 1ns / 1ps

// Shared iterative unit: no combinational '/' or large inferred multiplier.
// 32 shift/add or restoring-division steps; EX is held until done.
module MulDiv (
    input clk, reset, start, divide, signed_mode,
    input [31:0] a, b,
    output reg busy, done,
    output reg [31:0] result_hi, result_lo
);
    reg dividing, negate_product, negate_quotient, negate_remainder;
    reg [5:0] count;
    reg [63:0] product, multiplicand;
    reg [31:0] multiplier, quotient, divisor;
    reg [32:0] remainder;
    wire [31:0] abs_a = signed_mode && a[31] ? (~a + 32'd1) : a;
    wire [31:0] abs_b = signed_mode && b[31] ? (~b + 32'd1) : b;
    wire [63:0] next_product = product + (multiplier[0] ? multiplicand : 64'b0);
    wire [63:0] final_product = negate_product ? (~next_product + 64'd1) : next_product;
    wire [32:0] shifted_remainder = {remainder[31:0], quotient[31]};
    wire subtract_divisor = shifted_remainder >= {1'b0,divisor};
    wire [32:0] next_remainder = subtract_divisor ?
        shifted_remainder - {1'b0,divisor} : shifted_remainder;
    wire [31:0] next_quotient = {quotient[30:0], subtract_divisor};
    always @(posedge clk) begin
        if (reset) begin
            busy<=0; done<=0; result_hi<=0; result_lo<=0;
            dividing<=0; negate_product<=0; negate_quotient<=0; negate_remainder<=0;
            count<=0; product<=0; multiplicand<=0; multiplier<=0;
            quotient<=0; divisor<=0; remainder<=0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                dividing <= divide;
                negate_product <= signed_mode && (a[31] ^ b[31]);
                negate_quotient <= signed_mode && (a[31] ^ b[31]);
                negate_remainder <= signed_mode && a[31];
                count <= 0; product <= 0;
                multiplicand <= {32'b0,abs_a}; multiplier <= abs_b;
                quotient <= abs_a; divisor <= abs_b; remainder <= 0;
                if (divide && b == 0) begin
                    // Defined educational behavior, not a MIPS exception.
                    result_hi <= a; result_lo <= 32'hffffffff; done <= 1;
                end else busy <= 1;
            end else if (busy) begin
                count <= count + 1'b1;
                if (dividing) begin
                    quotient <= next_quotient; remainder <= next_remainder;
                    if (count == 31) begin
                        result_lo <= negate_quotient ? (~next_quotient + 32'd1) : next_quotient;
                        result_hi <= negate_remainder ? (~next_remainder[31:0] + 32'd1) : next_remainder[31:0];
                    end
                end else begin
                    product <= next_product;
                    multiplicand <= multiplicand << 1; multiplier <= multiplier >> 1;
                    if (count == 31) begin result_hi <= final_product[63:32]; result_lo <= final_product[31:0]; end
                end
                if (count == 31) begin busy <= 0; done <= 1; end
            end
        end
    end
endmodule
