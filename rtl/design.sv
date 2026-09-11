`timescale 1ns / 1ps

// Basic ALU
module alu (
    input  logic clk,
    input  logic rstn,
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [2:0] op,

    output logic [7:0] result,
    output logic       carry
);

    always @(posedge clk or negedge rstn) begin
       if (!rstn) begin
            result <= 8'h0;
            carry  <= 1'b0;
        end

        else begin
            case (op)
                3'b000: begin
                    {carry, result} <= a + b;
                end
                3'b001: begin
                    result <= a - b;
                    carry <= a < b;
                end
                3'b010: begin
                    result <= a & b;
                    carry <= 1'b0;
                end
                3'b011: begin
                    result <= a | b;
                    carry <= 1'b0;
                end
                3'b100: begin
                    result <= a ^ b;
                    carry <= 1'b0;
                end
                default: begin
                    result <= 8'h00;
                    carry  <= 1'b0;
                end
            endcase
        end
    end
endmodule
