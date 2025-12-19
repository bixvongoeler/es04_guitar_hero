module read_8_bit_pattern #(
    parameter WIDTH = 8,
    parameter DEPTH = 2240
) (
    input  logic             clk,
    input  logic             reset,
    output logic [WIDTH-1:0] data_out,
    output logic             valid
);
    // Memory holding lines of data
    // Format: [7:6]=green, [5:4]=yellow, [3:2]=blue, [1:0]=orange
    // Encoding: 00=none, 01=tail, 10=head
    logic [WIDTH-1:0] mem[0:DEPTH-1];
    integer index;

    initial begin
        $readmemb("binary_note_data.txt", mem);  // load 8-bit chart
        index = 0;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            index <= 0;
            valid <= 0;
        end else begin
            if (index < DEPTH) begin
                data_out <= mem[index];
                valid    <= 1;
                index    <= index + 1;
            end else begin
                valid <= 0;  // no more data
            end
        end
    end

endmodule
