module hit_controller (
    input  logic clk,
    input  logic reset,
    // Button inputs (active low)
    input  logic green_btn,
    input  logic yellow_btn,
    input  logic blue_btn,
    input  logic orange_btn,
    input  logic strum_btn,
    // From note lanes - heads currently in hit zone
    input  logic green_head,
    input  logic yellow_head,
    input  logic blue_head,
    input  logic orange_head,
    // Outputs to note lanes - mark which lanes had successful hits
    output logic green_hit,
    output logic yellow_hit,
    output logic blue_hit,
    output logic orange_hit,
    // Outputs to score controller
    output logic hit_event,    // A successful hit occurred this cycle
    output logic miss_event    // A miss occurred this cycle (wrong combo or empty strum)
);

    // Strum edge detection
    logic strum_prev;
    logic strum_edge;

    always_ff @(posedge clk) begin
        if (reset) begin
            strum_prev <= 1'b1;
        end else begin
            strum_prev <= strum_btn;
        end
    end

    // button was high (released), now low (pressed)
    assign strum_edge = strum_prev && !strum_btn;
    logic [3:0] buttons_pressed;
    assign buttons_pressed = {~green_btn, ~yellow_btn, ~blue_btn, ~orange_btn};

    // What notes heads in hit zone
    logic [3:0] heads_required;
    assign heads_required = {green_head, yellow_head, blue_head, orange_head};

    // Exact match check
    logic exact_match;
    assign exact_match = (buttons_pressed == heads_required);

    // Determine Hit/miss
    always_ff @(posedge clk) begin
        if (reset) begin
            green_hit  <= 1'b0;
            yellow_hit <= 1'b0;
            blue_hit   <= 1'b0;
            orange_hit <= 1'b0;
            hit_event  <= 1'b0;
            miss_event <= 1'b0;
        end else begin
            green_hit  <= 1'b0;
            yellow_hit <= 1'b0;
            blue_hit   <= 1'b0;
            orange_hit <= 1'b0;
            hit_event  <= 1'b0;
            miss_event <= 1'b0;

            if (strum_edge) begin
                // make sure the buttons pressed match the notes in the hit zone
                if (exact_match && (heads_required != 4'b0000)) begin
                    // Successful hit
                    green_hit  <= green_head;
                    yellow_hit <= yellow_head;
                    blue_hit   <= blue_head;
                    orange_hit <= orange_head;
                    hit_event  <= 1'b1;
                end else begin
                    // Miss: wrong combination, extra buttons, or no notes to hit
                    miss_event <= 1'b1;
                end
            end
        end
    end
endmodule
