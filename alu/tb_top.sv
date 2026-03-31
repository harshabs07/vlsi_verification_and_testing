module testbench_top;
    
    bit clk;
    bit reset;
    parameter CLK_PERIOD = 10;

    always #(CLK_PERIOD/2) clk = ~clk;

    alu_intf vif(clk, reset);

    alu dut (
        .clk    (vif.clk),
        .reset  (vif.reset),
        .a      (vif.a),
        .b      (vif.b),
        .op     (vif.op),
        .result (vif.result),
        .carry  (vif.carry),
        .zero   (vif.zero)
    );

    alu_env env;

    initial begin
        $dumpfile("dump.vcd"); 
        $dumpvars;

        clk   = 0;
        reset = 1;
        
        #(CLK_PERIOD) reset = 0;

        env = new(vif);
        
        env.gen.num_transactions = 20; 

        env.run();

        $display("Testbench: All transactions complete. Finishing simulation.");
        $finish; 
    end

endmodule
