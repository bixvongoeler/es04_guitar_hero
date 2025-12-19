module digit_gen (
    input logic [9:0] col,
    input logic [9:0] row,
    input logic valid,
    input logic [6:0] offset,
    input logic [16:0] score,
    input logic [5:0] digit_color,
    output logic [5:0] digit_rgb
);
    logic [5:0] black = 6'd0;

    logic sectionA = (70 < row) & (row <= 80);
    logic sectionB = (80 < row) & (row <= 85);
    logic sectionC = (85 < row) & (row <= 95);
    logic sectionD = (95 < row) & (row <= 100);
    logic sectionE = (100 < row) & (row <= 110);

    logic [3:0] value;

    always_comb begin
        //extract the specific digit
        case (offset)
            7'd20:   value = (score / 10000) % 10;  //digit1
            7'd46:   value = (score / 1000) % 10;  //digit2
            7'd72:   value = (score / 100) % 10;  //digit3
            7'd98:   value = (score / 10) % 10;  //digit4
            7'd124:  value = (score / 1) % 10;  //digit5
            default: value = 4'd0;
        endcase

        if (valid == 1) begin
            case (value)
                0: begin
                    if (sectionA | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionB | sectionC | sectionD) begin
                        if(((offset < col) & (col <= (offset + 10))) |
                                (((offset + 15) < col) & (col <= (offset + 25)))) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                1: begin
                    if (sectionA) begin
                        if (col <= (offset + 20)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionB | sectionC | sectionD) begin
                        if (((offset + 5) < col) & (col < (offset + 20))) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionE) begin
                        digit_rgb = digit_color;
                    end else begin
                        digit_rgb = black;
                    end
                end

                2: begin
                    if (sectionA | sectionC | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionB) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionD) begin
                        if (col <= (offset + 10)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                3: begin
                    if (sectionA | sectionC | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionB | sectionD) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                4: begin
                    if (sectionA | sectionB) begin
                        if ((col <= (offset + 10)) | ((offset + 15) < col)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionC) begin
                        digit_rgb = digit_color;
                    end else if (sectionD | sectionE) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                5: begin
                    if (sectionA | sectionC | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionD) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionB) begin
                        if (col <= (offset + 10)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                6: begin
                    if (sectionA | sectionC | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionB) begin
                        if (col <= (offset + 10)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionD) begin
                        if ((col <= (offset + 10)) | ((offset + 15) < col)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                7: begin
                    if (sectionA) begin
                        digit_rgb = digit_color;
                    end else if (sectionB | sectionC | sectionD | sectionE) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                8: begin
                    if (sectionA | sectionC | sectionE) begin
                        digit_rgb = digit_color;
                    end else if (sectionB | sectionD) begin
                        if ((col <= (offset + 10)) | ((offset + 15) < col)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end

                9: begin
                    if (sectionA | sectionC) begin
                        digit_rgb = digit_color;
                    end else if (sectionB) begin
                        if ((col <= (offset + 10)) | ((offset + 15) < col)) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else if (sectionD | sectionE) begin
                        if ((offset + 15) < col) begin
                            digit_rgb = digit_color;
                        end else begin
                            digit_rgb = black;
                        end
                    end else begin
                        digit_rgb = black;
                    end
                end
                default: digit_rgb = black;
            endcase

        end else begin
            digit_rgb = black;
        end
    end
endmodule
