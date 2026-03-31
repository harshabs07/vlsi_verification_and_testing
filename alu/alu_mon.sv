class alu_monitor;
    
    virtual alu_intf vif;
    mailbox #(alu_transaction) mon2scb_mbx;
    alu_transaction pipeline_q[$];

    function new(virtual alu_intf vif, mailbox #(alu_transaction) mbx);
        this.vif = vif;
        this.mon2scb_mbx = mbx;
    endfunction

    task run();
        forever begin
            @(posedge vif.clk);
            
            if (pipeline_q.size() > 0) begin
                alu_transaction completed_trans;
                completed_trans = pipeline_q.pop_front();
                
                completed_trans.result = vif.result;
                completed_trans.carry  = vif.carry;
                completed_trans.zero   = vif.zero;
                
                mon2scb_mbx.put(completed_trans);
                completed_trans.display("[MON] Output Captured");
            end
            
            if (vif.valid) begin
                alu_transaction new_trans = new();
                
                new_trans.a  = vif.a;
                new_trans.b  = vif.b;
                new_trans.op = vif.op;
                
                pipeline_q.push_back(new_trans); 
            end
        end
    endtask

endclass
