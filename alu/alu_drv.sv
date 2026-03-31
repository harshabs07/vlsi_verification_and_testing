class alu_driver;
    
    virtual alu_intf vif;
    mailbox #(alu_transaction) gen2drv_mbx;

    function new(virtual alu_intf vif, mailbox #(alu_transaction) mbx);
        this.vif = vif;
        this.gen2drv_mbx = mbx;
    endfunction

    task run();
        vif.valid <= 0; 
        
        forever begin
            alu_transaction trans;
            
            gen2drv_mbx.get(trans); 
            
            @(posedge vif.clk);
            
            vif.valid <= 1; 
            vif.a     <= trans.a; 
            vif.b     <= trans.b; 
            vif.op    <= trans.op; 
            
            trans.display("[DRV] Transferred to DUT");
            
            @(posedge vif.clk);
            
            vif.valid <= 0; 
        end
    endtask

endclass
