`timescale 1ns / 1ps

module alu(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [3:0] op,
    output logic [7:0] result,
    output logic       carry,
    output logic       zero
);

    typedef enum logic [3:0] {
        OP_ADD = 4'b0000,
        OP_SUB = 4'b0001,
        OP_AND = 4'b0010,
        OP_OR  = 4'b0011,
        OP_XOR = 4'b0100
    } opcode_t;

    logic [8:0] next_result_full;
    logic [7:0] next_result_8bit;
    logic       next_carry;
    logic       next_zero;

    always_comb begin
        next_result_full = 9'b0;

        case (op)
            OP_ADD:  next_result_full = a + b;
            OP_SUB:  next_result_full = a - b;
            OP_AND:  next_result_full = {1'b0, a & b};
            OP_OR :  next_result_full = {1'b0, a | b};
            OP_XOR:  next_result_full = {1'b0, a ^ b};
            default: next_result_full = 9'b0;
        endcase

        next_carry       = next_result_full[8];
        next_result_8bit = next_result_full[7:0];
        next_zero        = (next_result_8bit == 8'b0);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 8'b0;
            carry  <= 1'b0;
            zero   <= 1'b0;
        end else begin
            result <= next_result_8bit;
            carry  <= next_carry;
            zero   <= next_zero; 
        end
    end

endmodule
