class alu_transaction;

    // Stimulus (Randomized Inputs)
    rand bit [7:0] a;   // Operand A
    rand bit [7:0] b;   // Operand B
    rand bit [3:0] op;  // Operation Code

    // Response (Observed Outputs)
    bit [7:0] result;
    bit       carry;
    bit       zero;

    // Constraints (Randomization Rules)

    // Constraint 1: Validity
    // Ensure 'op' is within the supported range [0:4]
    constraint valid_op_c { 
        op inside {[0:4]}; 
    }

    // Constraint 2: Corner Cases
    // Increase probability of A == B to test the Zero Flag (approx 20% chance)
    constraint corner_cases {
        (a == b) dist { 1 := 2, 0 := 8 }; 
    }

    // Utility Function to print packet contents
    function void display(string tag="");
        $display("[%s] Time=%0t | Op=%0d | A=%0d | B=%0d | Res=%0d | C=%b | Z=%b", 
                 tag, $time, op, a, b, result, carry, zero);
    endfunction

endclass
