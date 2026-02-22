class alu_env;
    
    alu_generator  gen;
    alu_driver      drv;
    alu_monitor    mon;
    alu_scoreboard scb;
    
    mailbox #(alu_transaction) gen2drv_mbx;
    mailbox #(alu_transaction) mon2scb_mbx;
    
    virtual alu_intf vif;
    
    function new(virtual alu_intf vif);
        this.vif = vif;
        
        gen2drv_mbx = new();
        mon2scb_mbx = new();
        
        gen = new(gen2drv_mbx);
        drv = new(vif, gen2drv_mbx);
        mon = new(vif, mon2scb_mbx);
        scb = new(mon2scb_mbx);
    endfunction

    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any
    endtask
    
    task post_test();
        wait(gen.done.triggered);
        wait(gen.num_transactions == scb.transactions_checked);
        
        $display("---------------------------------------");
        $display(" [ENV] Verification Complete. Checked: %0d", scb.transactions_checked);
        $display("---------------------------------------");
    endtask

    task run();
        test();
        post_test();
        $finish;
    endtask

endclass
