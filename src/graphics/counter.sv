module counter (
    input  logic in_clk,
    output logic out_clk
);

    logic [19:0] count;

    always_comb begin
        if (count[19] == 1'b1) begin  //HOB on
            out_clk = 1;
        end else begin  //HOB low
            out_clk = 0;
        end
    end

    always_ff @(posedge in_clk) begin
        if (count == 20'b1100_0111_1110_1111_1001) begin  //HOX >= 8 or else HOB wont be 1
            count <= 0;  //reset to 0 if max val
        end else begin
            count <= count + 1;  //increment by 1
        end
    end

endmodule
