// --- Interface ---
interface ram_intf #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4) (input logic clk, rst);
    logic                we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
endinterface

// --- Transaction Class ---
class ram_transaction #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    rand logic                we;
    rand logic [ADDR_WIDTH-1:0] addr;
    rand logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0]      rdata;

    constraint c_dist_addr {
        addr dist {
            [0:3]   :/ 12.5, [4:7]   :/ 12.5,
            [8:11]  :/ 12.5, [12:15] :/ 12.5,
            [16:19] :/ 12.5, [20:23] :/ 12.5,
            [24:27] :/ 12.5, [28:31] :/ 12.5
        };
    }

    constraint c_rw_mix {
        we dist { 0 := 50, 1 := 50 };
    }

    function void display(string tag="");
        $display("[%s] Time=%0t | WE=%b | Addr=%0d | WData=%h | RData=%h",
                 tag, $time, we, addr, wdata, rdata);
    endfunction
endclass

// --- Coverage ---
class coverage #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx;
    ram_transaction #(DATA_WIDTH, ADDR_WIDTH) tr;

    covergroup cg_ram;
        option.per_instance = 1;
        cp_we: coverpoint tr.we {
            bins read  = {0};
            bins write = {1};
        }
        cp_addr: coverpoint tr.addr {
            bins addr_zero = {0};
            bins addr_max  = {((1 << ADDR_WIDTH) - 1)};
            bins seg1 = {[0:3]};
            bins seg2 = {[4:8]};
            bins seg3 = {[9:12]};
            bins seg4 = {[13:16]};
            bins seg5 = {[17:20]};
            bins seg6 = {[21:24]};
            bins seg7 = {[25:28]};
            bins seg8 = {[29:31]};
        }
        cross_we_addr: cross cp_we, cp_addr;
    endgroup

    function new(mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx);
        this.mbx = mbx;
        cg_ram = new();
    endfunction

    task run();
        begin
            forever begin
                mbx.get(tr);
                cg_ram.sample();
            end
        end
    endtask
endclass

// --- Generator ---
class ram_generator #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    ram_transaction #(DATA_WIDTH, ADDR_WIDTH) trans;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) gen2drv_mbx;
    event done;
    int num_transactions;
    int total_sent = 0;

    function new(mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx);
        this.gen2drv_mbx = mbx;
    endfunction

    task run();
        begin
            $display("[GEN] Starting Directed Tests...");
            for(int i=0; i<2; i++) begin
                trans = new();
                void'(trans.randomize() with {addr == 5; we == (i==0);});
                gen2drv_mbx.put(trans);
                total_sent++;
            end

            repeat(num_transactions) begin
                trans = new();
                if (!trans.randomize()) $fatal("[GEN] Randomization Error!");
                gen2drv_mbx.put(trans);
                total_sent++;
            end
            -> done;
        end
    endtask
endclass

// --- Driver ---
class ram_driver #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) gen2drv_mbx;

    function new(virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif,
                 mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx);
        this.vif = vif;
        this.gen2drv_mbx = mbx;
    endfunction

    task run();
        begin
            vif.we <= 0;
            forever begin
                ram_transaction #(DATA_WIDTH, ADDR_WIDTH) drv_trans;
                gen2drv_mbx.get(drv_trans);
                @(posedge vif.clk);
                vif.we    <= drv_trans.we;
                vif.addr  <= drv_trans.addr;
                vif.wdata <= drv_trans.wdata;
            end
        end
    endtask
endclass

// --- Monitor ---
class ram_monitor #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mon2scb_mbx;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx_cov;
    ram_transaction #(DATA_WIDTH, ADDR_WIDTH) pipeline_q[$];

    function new(virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif,
                 mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx,
                 mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) cov_mbx);
        this.vif = vif;
        this.mon2scb_mbx = mbx;
        this.mbx_cov = cov_mbx;
    endfunction

    task run();
        begin
            forever begin
                @(posedge vif.clk);
                #1;
                if (pipeline_q.size() > 0) begin
                    ram_transaction #(DATA_WIDTH, ADDR_WIDTH) out_trans;
                    out_trans = pipeline_q.pop_front();
                    out_trans.rdata = vif.rdata;
                    mon2scb_mbx.put(out_trans);
                    mbx_cov.put(out_trans);
                end
                begin
                    ram_transaction #(DATA_WIDTH, ADDR_WIDTH) new_trans = new();
                    new_trans.we    = vif.we;
                    new_trans.addr  = vif.addr;
                    new_trans.wdata = vif.wdata;
                    pipeline_q.push_back(new_trans);
                end
            end
        end
    endtask
endclass

// --- Scoreboard ---
class ram_scoreboard #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mon2scb_mbx;
    logic [DATA_WIDTH-1:0] shadow_mem [int];
    int transactions_checked = 0;

    function new(mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mbx);
        this.mon2scb_mbx = mbx;
    endfunction

    task run();
        begin
            forever begin
                ram_transaction #(DATA_WIDTH, ADDR_WIDTH) scb_trans;
                logic [DATA_WIDTH-1:0] expected_rdata;
                mon2scb_mbx.get(scb_trans);

                if (scb_trans.we) begin
                    shadow_mem[scb_trans.addr] = scb_trans.wdata;
                    expected_rdata = scb_trans.wdata;
                    if (scb_trans.rdata !== expected_rdata)
                        $error("[SCB] @%0t | FAIL! Addr:%0d WE:1 Exp:%h Act:%h", $time, scb_trans.addr, expected_rdata, scb_trans.rdata);
                    else
                        $display("[SCB] @%0t | PASS! Addr:%0d WE:1 Data:%h", $time, scb_trans.addr, scb_trans.rdata);
                    transactions_checked++;
                end else begin
                    if (shadow_mem.exists(scb_trans.addr)) begin
                        expected_rdata = shadow_mem[scb_trans.addr];
                        if (scb_trans.rdata !== expected_rdata)
                            $error("[SCB] @%0t | FAIL! Addr:%0d WE:0 Exp:%h Act:%h", $time, scb_trans.addr, expected_rdata, scb_trans.rdata);
                        else
                            $display("[SCB] @%0t | PASS! Addr:%0d WE:0 Data:%h", $time, scb_trans.addr, scb_trans.rdata);
                        transactions_checked++;
                    end else begin
                        $display("[SCB] @%0t | Skipping check: Addr %0d uninitialized", $time, scb_trans.addr);
                        transactions_checked++;
                    end
                end
            end
        end
    endtask
endclass

// --- Environment ---
class ram_env #(parameter int DATA_WIDTH = 8, parameter int ADDR_WIDTH = 4);
    ram_generator  #(DATA_WIDTH, ADDR_WIDTH) gen;
    ram_driver     #(DATA_WIDTH, ADDR_WIDTH) drv;
    ram_monitor    #(DATA_WIDTH, ADDR_WIDTH) mon;
    ram_scoreboard #(DATA_WIDTH, ADDR_WIDTH) scb;
    coverage       #(DATA_WIDTH, ADDR_WIDTH) cov;
   
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) gen2drv_mbx;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mon2scb_mbx;
    mailbox #(ram_transaction #(DATA_WIDTH, ADDR_WIDTH)) mon2cov_mbx;
   
    virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif;

    function new(virtual ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif);
        this.vif = vif;
        gen2drv_mbx = new();
        mon2scb_mbx = new();
        mon2cov_mbx = new();
       
        gen = new(gen2drv_mbx);
        drv = new(vif, gen2drv_mbx);
        mon = new(vif, mon2scb_mbx, mon2cov_mbx);
        scb = new(mon2scb_mbx);
        cov = new(mon2cov_mbx);
    endfunction

    task run();
        begin
            fork
                gen.run();
                drv.run();
                mon.run();
                scb.run();
                cov.run();
            join_any
           
            wait(gen.done.triggered);
            repeat(5) @(posedge vif.clk);
            wait(gen.total_sent == scb.transactions_checked);
           
            $display("[ENV] Verification Complete: %0d transactions processed.", scb.transactions_checked);
            $finish;
        end
    endtask
endclass

// --- Top ---
module testbench_top;
    bit clk;
    bit reset;
   
    parameter int DATA_WIDTH = 16;
    parameter int DEPTH      = 32;
    localparam int ADDR_WIDTH = 5; // Manually set to match $clog2(32)
    parameter CLK_PERIOD = 10;

    always #(CLK_PERIOD/2) clk = ~clk;

    ram_intf #(DATA_WIDTH, ADDR_WIDTH) vif(clk, reset);

    sync_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk   (vif.clk),
        .rst   (vif.rst),
        .we    (vif.we),
        .addr  (vif.addr),
        .wdata (vif.wdata),
        .rdata (vif.rdata)
    );

    ram_env #(DATA_WIDTH, ADDR_WIDTH) env;

    initial begin
        clk   = 0;
        reset = 1;
        #CLK_PERIOD reset = 0;

        env = new(vif);
        env.gen.num_transactions = 250;
        env.run();
    end
endmodule
