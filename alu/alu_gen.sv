class alu_generator;
    
    alu_transaction trans;
    mailbox #(alu_transaction) gen2drv_mbx;
    event done;
    int num_transactions;

    function new(mailbox #(alu_transaction) mbx);
        this.gen2drv_mbx = mbx;
    endfunction

    task run();
        $display("[GEN] Starting generation of %0d transactions...", num_transactions);

        for (int i = 0; i < num_transactions; i++) begin
            trans = new();
            
            if (!trans.randomize()) begin
                $fatal("[GEN] Randomization failed at transaction %0d", i);
            end
            
            gen2drv_mbx.put(trans);
        end
        
        $display("[GEN] Generation complete. Triggering 'done' event.");
        -> done; 
    endtask

endclass
