// =============================================================================
// File        : ram.sv
// Description : Synchronous RAM with configurable width/depth
//               Read policy  : WRITE_FIRST (same-cycle write data forwarded)
//               Reset policy : rdata = 0; memory contents don't-care
// =============================================================================

module ram #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata
);

    // Internal memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // --------------------------------------------------------------------------
    // Synchronous write + WRITE_FIRST read
    // --------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            rdata <= '0;
        end else begin
            if (we) begin
                mem[addr] <= wdata;
                // WRITE_FIRST: forward written data to rdata on the same edge
                rdata     <= wdata;
            end else begin
                rdata <= mem[addr];
            end
        end
    end

endmodule


// ─────────────────────────────────────────────────────────────────────────────
// 2. SCOREBOARD — prev-cycle approach (UPDATED FOR CONSOLE OUTPUT)
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

        // Compare and Print (UPDATED TO SHOW wdata)
        if (^t.rdata === 1'bx) begin
            skip_cnt++;
            $display("[SKIP] t=%0t | %s addr=%0h | rdata=x", $time, op_s, prev_addr);
        end else if (t.rdata === expected) begin
            pass_cnt++;
            if (prev_we)
                $display("[PASS] t=%0t | WRITE addr=%0h | wdata=%0h | rdata=%0h (exp=%0h)", 
                         $time, prev_addr, prev_wdata, t.rdata, expected);
            else
                $display("[PASS] t=%0t | READ  addr=%0h | rdata=%0h (exp=%0h)", 
                         $time, prev_addr, t.rdata, expected);
        end else begin
            fail_cnt++;
            if (prev_we)
                $display("[FAIL] t=%0t | WRITE addr=%0h | wdata=%0h | rdata=%0h (exp=%0h) <<<", 
                         $time, prev_addr, prev_wdata, t.rdata, expected);
            else
                $display("[FAIL] t=%0t | READ  addr=%0h | rdata=%0h (exp=%0h) <<<", 
                         $time, prev_addr, t.rdata, expected);
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
