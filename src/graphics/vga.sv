module vga (
    input logic clk,
    output logic HSYNC,
    output logic VSYNC,
    output logic valid,
    output logic [9:0] curr_col = 0,
    output logic [9:0] curr_row = 0
);

    //640x480 --> width x height

    int width = 800;  //96 48 640 16
    int height = 525;  //2 33 480 10

    // set up counters representing the column count (incremented once
    // on every pixel clock cycle) and the row count (incremented once every row)

    always_ff @(posedge clk) begin
        if (curr_col == (width - 1)) begin
            curr_row <= (curr_row + 1) % height;
        end

        curr_col <= (curr_col + 1) % width;
    end



    //Use combinational logic to drive the HSYNC and VSYNC signals as a function of the row and
    // column count, and the numbers you recorded in the prelab. We strongly recommend that you
    // make ‘0’ be the first pixel of the visible area and count from there.

    always_comb begin
        //pulse HSYNC
        if ((656 <= curr_col) && (curr_col < 752)) begin
            HSYNC = 0;
        end else begin
            HSYNC = 1;
        end

        //pulse VSYNC
        if ((490 <= curr_row) && (curr_row < 492)) begin
            VSYNC = 0;
        end else begin
            VSYNC = 1;
        end

        //visible area
        if ((curr_col < 640) && (curr_row < 480)) begin
            valid = 1;
        end else begin
            valid = 0;
        end

    end

endmodule
