// =============================================================================
// File        : ram_if.sv
// =============================================================================

interface ram_if #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    input logic clk
);

    logic                  rst;
    logic                  we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;

    // Driver: drives outputs #1 after posedge
    clocking driver_cb @(posedge clk);
        default input #1 output #1;
        output rst, we, addr, wdata;
        input  rdata;
    endclocking

    // Monitor: samples at negedge — rdata is stable mid-cycle
    // This correctly captures rdata produced by the PREVIOUS posedge
    clocking monitor_cb @(negedge clk);
        default input #1;
        input rst, we, addr, wdata, rdata;
    endclocking

    modport driver_mp  (clocking driver_cb,  input clk);
    modport monitor_mp (clocking monitor_cb, input clk);

endinterface
