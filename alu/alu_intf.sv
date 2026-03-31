interface alu_intf(
    input logic clk,
    input logic reset
);

    logic [7:0] a;
    logic [7:0] b;
    logic [3:0] op;

    logic [7:0] result;
    logic       carry;
    logic       zero;

    logic       valid;

endinterface
