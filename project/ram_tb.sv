// =============================================================================
// ram_tb.sv — Layered SystemVerilog Testbench for synchronous RAM
// Scoreboard: PREV-CYCLE approach
//   At posedge+1ps: inputs = current cmd, rdata = result of PREVIOUS cmd
//   So: expected rdata[N] = f(cmd[N-1])
// Coverage: stripped out per request — scoreboard + functional verification only
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// 1. TRANSACTION
// ─────────────────────────────────────────────────────────────────────────────
class ram_transaction #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
);
    typedef enum logic { READ=0, WRITE=1 } op_e;

    rand op_e                    op;
    rand logic [ADDR_WIDTH-1:0]  addr;
    rand logic [DATA_WIDTH-1:0]  wdata;
         logic [DATA_WIDTH-1:0]  rdata;
         logic                   rst;

    constraint valid_addr_c { addr < DEPTH; }

    function ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) copy();
        copy       = new();
        copy.op    = this.op;
        copy.addr  = this.addr;
        copy.wdata = this.wdata;
        copy.rdata = this.rdata;
        copy.rst   = this.rst;
    endfunction
endclass


// ─────────────────────────────────────────────────────────────────────────────
// 2. SCOREBOARD — prev-cycle approach
//
//   monitor_cb input #1 means at posedge+1ps:
//     inputs (we/addr/wdata/rst) = NEW values just driven by driver
//     rdata                      = OLD value, result of PREVIOUS posedge
//
//   Therefore: store prev-cycle command, predict rdata from that, compare.
// ─────────────────────────────────────────────────────────────────────────────
class ram_scoreboard #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
);
    typedef ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) trans_t;

    // Golden memory model
    logic [DATA_WIDTH-1:0] shadow [0:DEPTH-1];

    int pass_cnt = 0;
    int fail_cnt = 0;
    int skip_cnt = 0;

    // Previous-cycle command registers
    logic                   prev_we;
    logic [ADDR_WIDTH-1:0]  prev_addr;
    logic [DATA_WIDTH-1:0]  prev_wdata;
    logic                   prev_rst;
    logic                   first_txn = 1;

    function new();
        for (int i = 0; i < DEPTH; i++) shadow[i] = '0;
        prev_we    = 0;
        prev_addr  = '0;
        prev_wdata = '0;
        prev_rst   = 0;
    endfunction

    function void check(trans_t t);
        logic [DATA_WIDTH-1:0] expected;
        string op_s = prev_we ? "WRITE" : "READ ";

        // First call: no previous command exists, nothing to check
        if (first_txn) begin
            first_txn  = 0;
            skip_cnt++;
            $display("[SKIP] t=%0t | first txn — no prev command", $time);
            // Shift registers and return
            prev_we    = (t.op == trans_t::WRITE);
            prev_addr  = t.addr;
            prev_wdata = t.wdata;
            prev_rst   = t.rst;
            return;
        end

        // Compute expected rdata from PREVIOUS command
        if (prev_rst) begin
            expected = '0;
        end else if (prev_we) begin
            expected          = prev_wdata;   // WRITE_FIRST: rdata = wdata
            shadow[prev_addr] = prev_wdata;   // update golden model
        end else begin
            expected = shadow[prev_addr];     // READ result
        end

        // Compare
        if (^t.rdata === 1'bx) begin
            skip_cnt++;
            $display("[SKIP] t=%0t | %s addr=%0h | rdata=x",
                     $time, op_s, prev_addr);
        end else if (t.rdata === expected) begin
            pass_cnt++;
            $display("[PASS] t=%0t | %s addr=%0h | rdata=%0h (exp=%0h)",
                     $time, op_s, prev_addr, t.rdata, expected);
        end else begin
            fail_cnt++;
            $display("[FAIL] t=%0t | %s addr=%0h | rdata=%0h (exp=%0h) <<<",
                     $time, op_s, prev_addr, t.rdata, expected);
        end

        // Shift registers for next cycle
        prev_we    = (t.op == trans_t::WRITE);
        prev_addr  = t.addr;
        prev_wdata = t.wdata;
        prev_rst   = t.rst;
    endfunction

    function void report();
        $display("─────────────────────────────────────────");
        $display("  SCOREBOARD SUMMARY");
        $display("  PASS : %0d", pass_cnt);
        $display("  FAIL : %0d", fail_cnt);
        $display("  SKIP : %0d", skip_cnt);
        if (fail_cnt == 0)
            $display("  RESULT : *** ALL CHECKS PASSED ***");
        else
            $display("  RESULT : *** %0d FAILURES DETECTED ***", fail_cnt);
        $display("─────────────────────────────────────────");
    endfunction
endclass


// ─────────────────────────────────────────────────────────────────────────────
// 3. DRIVER
// ─────────────────────────────────────────────────────────────────────────────
class ram_driver #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
);
    typedef ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) trans_t;
    virtual ram_if #(DATA_WIDTH, ADDR_WIDTH) vif;

    function new(virtual ram_if #(DATA_WIDTH, ADDR_WIDTH) vif);
        this.vif = vif;
    endfunction

    task drive(trans_t t);
        @(vif.driver_cb);
        vif.driver_cb.rst   <= t.rst;
        vif.driver_cb.we    <= (t.op == trans_t::WRITE);
        vif.driver_cb.addr  <= t.addr;
        vif.driver_cb.wdata <= t.wdata;
    endtask
endclass


// ─────────────────────────────────────────────────────────────────────────────
// 4. MONITOR
// ─────────────────────────────────────────────────────────────────────────────
class ram_monitor #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
);
    typedef ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) trans_t;
    virtual ram_if #(DATA_WIDTH, ADDR_WIDTH) vif;
    mailbox #(trans_t) mbx;

    function new(virtual ram_if #(DATA_WIDTH, ADDR_WIDTH) vif,
                 mailbox #(trans_t) mbx);
        this.vif = vif;
        this.mbx = mbx;
    endfunction

    task run(int num_cycles);
        trans_t t;
        repeat (num_cycles) begin
            @(vif.monitor_cb);
            t       = new();
            t.op    = vif.monitor_cb.we ? trans_t::WRITE : trans_t::READ;
            t.addr  = vif.monitor_cb.addr;
            t.wdata = vif.monitor_cb.wdata;
            t.rdata = vif.monitor_cb.rdata;
            t.rst   = vif.monitor_cb.rst;
            mbx.put(t);
        end
    endtask
endclass


// ─────────────────────────────────────────────────────────────────────────────
// 5. GENERATOR
// ─────────────────────────────────────────────────────────────────────────────
class ram_generator #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4,
    parameter int DEPTH      = 16
);
    typedef ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) trans_t;
    mailbox #(trans_t) mbx;
    int num_random = 30;

    function new(mailbox #(trans_t) mbx);
        this.mbx = mbx;
    endfunction

    function trans_t make_trans(
        logic                   we,
        logic [ADDR_WIDTH-1:0]  addr,
        logic [DATA_WIDTH-1:0]  wdata = '0,
        logic                   rst   = 0
    );
        trans_t t = new();
        t.op    = we ? trans_t::WRITE : trans_t::READ;
        t.addr  = addr;
        t.wdata = wdata;
        t.rst   = rst;
        return t;
    endfunction

    task run();
        trans_t t;

        $display("\n=== PRE-SCENARIO: Memory Initialization ===");
        for (int i = 0; i < DEPTH; i++)
            mbx.put(make_trans(1, i[ADDR_WIDTH-1:0], 8'h00));

        $display("\n=== SCENARIO: Reset Validation ===");
        mbx.put(make_trans(1, 4'h5, 8'hAB));
        mbx.put(make_trans(0, 4'h5));
        t = new(); t.rst=1; t.op=trans_t::READ; t.addr=4'h5; mbx.put(t);
        t = new(); t.rst=1; t.op=trans_t::READ; t.addr=4'h5; mbx.put(t);
        mbx.put(make_trans(0, 4'h5));

        $display("\n=== SCENARIO: Write then Read Same Address ===");
        mbx.put(make_trans(1, 4'h2, 8'hCA));
        mbx.put(make_trans(0, 4'h2));

        $display("\n=== SCENARIO: WRITE_FIRST (read-during-write) ===");
        mbx.put(make_trans(1, 4'h3, 8'h55));

        $display("\n=== SCENARIO: Back-to-Back RR ===");
        mbx.put(make_trans(1, 4'h0, 8'h11));
        mbx.put(make_trans(0, 4'h0));
        mbx.put(make_trans(0, 4'h0));

        $display("\n=== SCENARIO: Back-to-Back WW ===");
        mbx.put(make_trans(1, 4'h1, 8'h22));
        mbx.put(make_trans(1, 4'h1, 8'h33));
        mbx.put(make_trans(0, 4'h1));

        $display("\n=== SCENARIO: Back-to-Back RW ===");
        mbx.put(make_trans(0, 4'h2));
        mbx.put(make_trans(1, 4'h2, 8'hFF));

        $display("\n=== SCENARIO: Back-to-Back WR ===");
        mbx.put(make_trans(1, 4'hA, 8'h77));
        mbx.put(make_trans(0, 4'hA));

        $display("\n=== SCENARIO: Boundary Addresses ===");
        mbx.put(make_trans(1, 4'h0, 8'h00));
        mbx.put(make_trans(1, 4'hF, 8'hFF));
        mbx.put(make_trans(0, 4'h0));
        mbx.put(make_trans(0, 4'hF));

        $display("\n=== SCENARIO: Extreme Data Values ===");
        mbx.put(make_trans(1, 4'hB, 8'h00));
        mbx.put(make_trans(0, 4'hB));
        mbx.put(make_trans(1, 4'hC, 8'hFF));
        mbx.put(make_trans(0, 4'hC));

        $display("\n=== SCENARIO: Constrained-Random (%0d txns) ===", num_random);
        repeat (num_random) begin
            t = new();
            if (!t.randomize()) $fatal(1, "Randomize failed");
            t.rst = 0;
            mbx.put(t);
        end
    endtask
endclass


// ─────────────────────────────────────────────────────────────────────────────
// 6. TOP MODULE
// ─────────────────────────────────────────────────────────────────────────────
module ram_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    typedef ram_transaction #(DATA_WIDTH, ADDR_WIDTH, DEPTH) trans_t;

    logic clk = 0;
    always #5 clk = ~clk;

    ram_if #(DATA_WIDTH, ADDR_WIDTH) intf (.clk(clk));

    ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk   (intf.clk),
        .rst   (intf.rst),
        .we    (intf.we),
        .addr  (intf.addr),
        .wdata (intf.wdata),
        .rdata (intf.rdata)
    );

    ram_generator  #(DATA_WIDTH, ADDR_WIDTH, DEPTH) gen;
    ram_driver     #(DATA_WIDTH, ADDR_WIDTH, DEPTH) drv;
    ram_monitor    #(DATA_WIDTH, ADDR_WIDTH, DEPTH) mon;
    ram_scoreboard #(DATA_WIDTH, ADDR_WIDTH, DEPTH) scb;

    mailbox #(trans_t) gen2drv = new();
    mailbox #(trans_t) mon2scb = new();
    int total_txns;

    task run_scoreboard(int n);
        trans_t t;
        repeat (n) begin
            mon2scb.get(t);
            scb.check(t);
        end
    endtask

    initial begin
        gen = new(gen2drv);
        drv = new(intf);
        scb = new();

        // Reset DUT for 2 cycles
        intf.rst   = 1;
        intf.we    = 0;
        intf.addr  = '0;
        intf.wdata = '0;
        @(posedge clk); @(posedge clk);
        intf.rst = 0;

        // Fill mailbox with all transactions
        gen.run();
        total_txns = gen2drv.num();

        mon = new(intf, mon2scb);

        fork
            // Driver thread
            begin
                trans_t t;
                repeat (total_txns) begin
                    gen2drv.get(t);
                    drv.drive(t);
                end
                // One extra idle cycle to flush last rdata through monitor
                @(intf.driver_cb);
                intf.driver_cb.we   <= 0;
                intf.driver_cb.rst  <= 0;
                intf.driver_cb.addr <= '0;
            end
            // Monitor thread
            mon.run(total_txns + 1);
            // Scoreboard thread
            run_scoreboard(total_txns + 1);
        join

        $display("\n");
        scb.report();
        $finish;
    end

    initial begin
        #200000;
        $display("[TIMEOUT]");
        $finish;
    end

    initial begin
        $dumpfile("ram_tb.vcd");
        $dumpvars(0, ram_tb);
    end

endmodule
