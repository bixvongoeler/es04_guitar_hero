// ============================================================================
// Audio FIFO Buffer
// ============================================================================

module audio_fifo #(
    parameter DEPTH = 1024,
    parameter WIDTH = 8
) (
    input logic CLK,
    input logic RESET,

    // Write Interface
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    // Read Interface
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty,
    output logic             rd_valid,

    // Status
    output logic [$clog2(DEPTH):0] fill_level
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // -------------------------------------------------------------------------
    // Pointer Registers
    // -------------------------------------------------------------------------

    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // -------------------------------------------------------------------------
    // Memory Array
    // -------------------------------------------------------------------------

    logic [WIDTH-1:0] mem[0:DEPTH-1];

    // -------------------------------------------------------------------------
    // Address and Status Logic
    // -------------------------------------------------------------------------

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    // Full: pointers at same address but different wrap (MSB differs)
    assign full = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // Empty: pointers exactly equal (including MSB)
    assign empty = (wr_ptr == rd_ptr);

    // Fill level: simple subtraction works due to wrap-around arithmetic
    assign fill_level = wr_ptr - rd_ptr;

    // -------------------------------------------------------------------------
    // Write Logic
    // -------------------------------------------------------------------------

    always_ff @(posedge CLK) begin
        if (RESET) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Read Logic
    // -------------------------------------------------------------------------

    always_ff @(posedge CLK) begin
        if (RESET) begin
            rd_ptr   <= '0;
            rd_data  <= '0;
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= 1'b0;  // Default: no valid data

            if (rd_en && !empty) begin
                rd_data  <= mem[rd_addr];
                rd_ptr   <= rd_ptr + 1'b1;
                rd_valid <= 1'b1;
            end
        end
    end

endmodule
