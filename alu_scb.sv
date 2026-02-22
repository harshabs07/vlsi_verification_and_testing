class alu_scoreboard;
    
    mailbox #(alu_transaction) mon2scb_mbx;
    int transactions_checked = 0;

    function new(mailbox #(alu_transaction) mbx);
        this.mon2scb_mbx = mbx;
    endfunction

    task run();
        forever begin
            alu_transaction trans;
            
            logic [7:0] expected_result;
            logic       expected_carry;
            logic       expected_zero;
            
            mon2scb_mbx.get(trans);

            case(trans.op)
                4'b0000: {expected_carry, expected_result} = trans.a + trans.b;
                4'b0001: {expected_carry, expected_result} = trans.a - trans.b;
                4'b0010: {expected_carry, expected_result} = {1'b0, trans.a & trans.b};
                4'b0011: {expected_carry, expected_result} = {1'b0, trans.a | trans.b};
                4'b0100: {expected_carry, expected_result} = {1'b0, trans.a ^ trans.b};
                default: {expected_carry, expected_result} = 9'b0;
            endcase
            
            expected_zero = (expected_result == 0);

            if ((trans.result != expected_result) || 
                (trans.carry  != expected_carry)  || 
                (trans.zero   != expected_zero)) begin
                
                $error("[SCB] FAIL! Operation: %0d (%s)", trans.op, get_op_name(trans.op));
                $error("      Inputs:   A=%0d, B=%0d", trans.a, trans.b);
                $error("      Expected: Res=%0d, Carry=%0b, Zero=%0b", expected_result, expected_carry, expected_zero);
                $error("      Actual:   Res=%0d, Carry=%0b, Zero=%0b", trans.result, trans.carry, trans.zero);
            
            end else begin
                $display("[SCB] PASS: A=%0d, B=%0d, Op=%0d -> Res=%0d", 
                         trans.a, trans.b, trans.op, trans.result);
            end
            
            transactions_checked++;
        end
    endtask
    
    function string get_op_name(logic [3:0] op);
        case(op)
            4'b0000: return "ADD";
            4'b0001: return "SUB";
            4'b0010: return "AND";
            4'b0011: return "OR";
            4'b0010: return "XOR";
            default: return "UNKNOWN";
        endcase
    endfunction

endclass
