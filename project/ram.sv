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
