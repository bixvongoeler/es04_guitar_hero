module score_title_gen (
    input logic [9:0] col,
    input logic [9:0] row,
    input logic valid,
    output logic [5:0] score_rgb
);

    logic [5:0] red = 6'b110000;
    logic [5:0] green = 6'b001100;
    logic [5:0] blue = 6'b000011;
    logic [5:0] yellow = 6'b111100;
    logic [5:0] orange = 6'b110100;
    logic [5:0] white = 6'b111111;
    logic [5:0] black = 6'd0;

    logic [6:0] s_offset = 7'd20;
    logic [6:0] c_offset = 7'd46;
    logic [6:0] o_offset = 7'd72;
    logic [6:0] r_offset = 7'd98;
    logic [6:0] e_offset = 7'd124;

    logic S = (20 < col) & (col <= (45));
    logic C = (46 < col) & (col <= (71));
    logic O = (72 < col) & (col <= (97));
    logic R = (98 < col) & (col <= (123));
    logic E = (124 < col) & (col <= (149));

    logic sectionA = (20 < row) & (row <= 30);
    logic sectionB = (30 < row) & (row <= 35);
    logic sectionC = (35 < row) & (row <= 45);
    logic sectionD = (45 < row) & (row <= 50);
    logic sectionE = (50 < row) & (row <= 60);

    always_comb begin
        if (valid == 1) begin
            if (S) begin
                if (sectionA | sectionC | sectionE) begin
                    score_rgb = white;
                end else if (sectionD) begin
                    if ((s_offset + 15) < col) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else if (sectionB) begin
                    if (col <= (s_offset + 10)) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else begin
                    score_rgb = black;
                end
            end else if (C) begin
                if (sectionA | sectionE) begin
                    score_rgb = white;
                end else if (sectionB | sectionD) begin
                    if(((c_offset < col) & (col <= (c_offset + 10))) |
                                (((c_offset + 15) < col) & (col <= (c_offset + 25)))) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else if (sectionC) begin
                    if (col <= (c_offset + 10)) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else begin
                    score_rgb = black;
                end
            end else if (O) begin
                if (sectionA | sectionE) begin
                    score_rgb = white;
                end else if (sectionB | sectionC | sectionD) begin
                    if(((o_offset < col) & (col <= (o_offset + 10))) |
                                (((o_offset + 15) < col) & (col <= (o_offset + 25)))) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else begin
                    score_rgb = black;
                end
            end else if (R) begin
                if (sectionA) begin
                    score_rgb = white;
                end else if (sectionB) begin
                    if(((r_offset < col) & (col <= (r_offset + 10))) |
                                (((r_offset + 15) < col) & (col <= (r_offset + 25)))) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else if (sectionC | sectionD | sectionE) begin
                    if (col <= (r_offset + 10)) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else begin
                    score_rgb = black;
                end
            end else if (E) begin
                if (sectionA | sectionC | sectionE) begin
                    score_rgb = white;
                end else if (sectionB | sectionD) begin
                    if (col <= (e_offset + 10)) begin
                        score_rgb = white;
                    end else begin
                        score_rgb = black;
                    end
                end else begin
                    score_rgb = black;
                end
            end else begin
                score_rgb = black;
            end

        end else begin
            score_rgb = black;
        end
    end
endmodule
