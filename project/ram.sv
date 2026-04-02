









module sync_ram #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   we,    // Write Enable
    input  logic [ADDR_WIDTH-1:0]  addr,  // Address
    input  logic [DATA_WIDTH-1:0]  wdata, // Write Data
    output logic [DATA_WIDTH-1:0]  rdata  // Read Data
);

    logic [DATA_WIDTH-1:0] mem [DEPTH];


    always_ff @(posedge clk) begin
        if (rst) begin
            rdata <= '0;
			
			for (int i=0; i < DEPTH; i++) begin
				mem[i] = 0;
			end
        end
        else begin
            if (we) begin
                mem[addr] <= wdata;

                rdata <= wdata;
            end
            else begin
                rdata <= mem[addr];
            end
        end
    end

    initial begin
        assert (DEPTH > 0) else $fatal("RAM DEPTH must be greater than 0");
    end
endmodule
