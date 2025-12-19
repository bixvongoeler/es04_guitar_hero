module screen_gen (
    input  logic [9:0] col,
    input  logic [9:0] row,
    input  logic       valid,
    output logic [5:0] rgb,
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] note,           // 8-bit: [7:6]=green, [5:4]=yellow, [3:2]=blue, [1:0]=orange
    input  logic       valid_note,
    input  logic       green_button,
    input  logic       yellow_button,
    input  logic       blue_button,
    input  logic       orange_button,
    input  logic       white_button    // Strum button
);
    // COLORS
    logic [ 5:0] red = 6'b110000;
    logic [ 5:0] green = 6'b001100;
    logic [ 5:0] blue = 6'b000011;
    logic [ 5:0] yellow = 6'b111100;
    logic [ 5:0] orange = 6'b110100;
    logic [ 5:0] white = 6'b111111;
    logic [ 5:0] black = 6'd0;
    logic [ 5:0] gray = 6'b101010;
    logic [ 5:0] brown = 6'b101001;

    // Score flash detection
    logic [16:0] prev_score;
    logic [ 7:0] flash_counter;
    logic [ 5:0] score_color;
    logic [ 5:0] score_green = 6'b001100;
    logic [ 5:0] score_red = 6'b110000;
    localparam FLASH_DURATION = 8'd10;

    // DIGIT INFO
    logic [5:0] digit1;
    logic [6:0] digit1_offset = 7'd20;

    logic [5:0] digit2;
    logic [6:0] digit2_offset = 7'd46;

    logic [5:0] digit3;
    logic [6:0] digit3_offset = 7'd72;

    logic [5:0] digit4;
    logic [6:0] digit4_offset = 7'd98;

    logic [5:0] digit5;
    logic [6:0] digit5_offset = 7'd124;

    // Hit zone status from lanes
    logic green_has_head, yellow_has_head, blue_has_head, orange_has_head;
    logic green_has_tail, yellow_has_tail, blue_has_tail, orange_has_tail;
    logic green_head_hit, yellow_head_hit, blue_head_hit, orange_head_hit;

    // Missed note signals from lanes
    logic green_missed, yellow_missed, blue_missed, orange_missed;

    // Hit controller signals
    logic green_mark_hit, yellow_mark_hit, blue_mark_hit, orange_mark_hit;
    logic hit_event, miss_event;

    // SCORE from unified controller
    logic [16:0] score_val;

    // Hit controller - detects strums and exact button matches
    hit_controller u_hit_ctrl (
        .clk        (clk),
        .reset      (reset),
        .green_btn  (green_button),
        .yellow_btn (yellow_button),
        .blue_btn   (blue_button),
        .orange_btn (orange_button),
        .strum_btn  (white_button),
        .green_head (green_has_head),
        .yellow_head(yellow_has_head),
        .blue_head  (blue_has_head),
        .orange_head(orange_has_head),
        .green_hit  (green_mark_hit),   //output
        .yellow_hit (yellow_mark_hit),  //output
        .blue_hit   (blue_mark_hit),    //output
        .orange_hit (orange_mark_hit),  //output
        .hit_event  (hit_event),        //output
        .miss_event (miss_event)        //output
    );

    // Score controller - unified scoring with tail support
    score_controller u_score_ctrl (
        .clk(clk),
        .reset(reset),
        .hit_event(hit_event),
        .miss_event(miss_event),
        .lane_hits({green_mark_hit, yellow_mark_hit, blue_mark_hit, orange_mark_hit}),
        .heads_in_zone({green_has_head, yellow_has_head, blue_has_head, orange_has_head}),
        .tails_in_zone({green_has_tail, yellow_has_tail, blue_has_tail, orange_has_tail}),
        .heads_were_hit({green_head_hit, yellow_head_hit, blue_head_hit, orange_head_hit}),
        .buttons_held({~green_button, ~yellow_button, ~blue_button, ~orange_button}),
        .notes_missed({green_missed, yellow_missed, blue_missed, orange_missed}),
        .score(score_val)  //output
    );

    // Score change detection and flash timer
    always_ff @(posedge clk) begin
        if (reset) begin
            prev_score <= 17'd0;
            flash_counter <= 8'd0;
            score_color <= white;
        end else begin
            if (score_val != prev_score) begin
                if (score_val > prev_score) begin
                    score_color <= score_green;
                end else begin
                    score_color <= score_red;
                end
                flash_counter <= FLASH_DURATION;
            end else if (flash_counter > 0) begin
                flash_counter <= flash_counter - 1;
            end else begin
                score_color <= white;
            end
            prev_score <= score_val;
        end
    end

    // DIGIT GENERATORS
    digit_gen digit1_gen (
        .col        (col),
        .row        (row),
        .valid      (valid),
        .offset     (digit1_offset),
        .score      (score_val),
        .digit_color(score_color),
        .digit_rgb  (digit1)          //output
    );

    digit_gen digit2_gen (
        .col        (col),
        .row        (row),
        .valid      (valid),
        .offset     (digit2_offset),
        .score      (score_val),
        .digit_color(score_color),
        .digit_rgb  (digit2)          //output
    );

    digit_gen digit3_gen (
        .col        (col),
        .row        (row),
        .valid      (valid),
        .offset     (digit3_offset),
        .score      (score_val),
        .digit_color(score_color),
        .digit_rgb  (digit3)          //output
    );

    digit_gen digit4_gen (
        .col        (col),
        .row        (row),
        .valid      (valid),
        .offset     (digit4_offset),
        .score      (score_val),
        .digit_color(score_color),
        .digit_rgb  (digit4)          //output
    );

    digit_gen digit5_gen (
        .col        (col),
        .row        (row),
        .valid      (valid),
        .offset     (digit5_offset),
        .score      (score_val),
        .digit_color(score_color),
        .digit_rgb  (digit5)          //output
    );

    // "SCORE" GENERATOR
    logic [5:0] score_title;
    score_title_gen score_title_gen_inst (
        .col      (col),
        .row      (row),
        .valid    (valid),
        .score_rgb(score_title)  //output
    );

    // LANE LAYOUT INFO
    localparam STRIPE_WIDTH = 35;
    localparam STRIPE_GAP = 20;

    // Lane starting columns
    logic [9:0] green_begin = 10'd220;
    logic [9:0] yellow_begin = 10'd275;  // green_begin + STRIPE_WIDTH + STRIPE_GAP
    logic [9:0] blue_begin = 10'd330;  // yellow_begin + STRIPE_WIDTH + STRIPE_GAP
    logic [9:0] orange_begin = 10'd385;  // blue_begin + STRIPE_WIDTH + STRIPE_GAP
    logic [9:0] lane_end = 10'd420;  // orange_begin + STRIPE_WIDTH

    // Lane RGB outputs
    logic [5:0] green_block;
    logic [5:0] yellow_block;
    logic [5:0] blue_block;
    logic [5:0] orange_block;

    note_lane #(
        .STRIPE_WIDTH(STRIPE_WIDTH)
    ) u_green_lane (
        .col             (col),
        .row             (row),
        .valid           (valid),
        .clk             (clk),
        .block_color     (green),
        .drop_note       (note[7:6]),       // 2-bit from chart
        .lane_left_col   (green_begin),
        .mark_hit        (green_mark_hit),
        .button_held     (~green_button),   // Active high for tail clearing
        .lane_rgb        (green_block),     //output
        .has_head_in_zone(green_has_head),  //output
        .has_tail_in_zone(green_has_tail),  //output
        .head_was_hit    (green_head_hit),  //output
        .note_missed     (green_missed)     //output
    );

    note_lane #(
        .STRIPE_WIDTH(STRIPE_WIDTH)
    ) u_yellow_lane (
        .col             (col),
        .row             (row),
        .valid           (valid),
        .clk             (clk),
        .block_color     (yellow),
        .drop_note       (note[5:4]),
        .lane_left_col   (yellow_begin),
        .mark_hit        (yellow_mark_hit),
        .button_held     (~yellow_button),
        .lane_rgb        (yellow_block),     //output
        .has_head_in_zone(yellow_has_head),  //output
        .has_tail_in_zone(yellow_has_tail),  //output
        .head_was_hit    (yellow_head_hit),  //output
        .note_missed     (yellow_missed)     //output
    );

    note_lane #(
        .STRIPE_WIDTH(STRIPE_WIDTH)
    ) u_blue_lane (
        .col             (col),
        .row             (row),
        .valid           (valid),
        .clk             (clk),
        .block_color     (blue),
        .drop_note       (note[3:2]),
        .lane_left_col   (blue_begin),
        .mark_hit        (blue_mark_hit),
        .button_held     (~blue_button),
        .lane_rgb        (blue_block),     //output
        .has_head_in_zone(blue_has_head),  //output
        .has_tail_in_zone(blue_has_tail),  //output
        .head_was_hit    (blue_head_hit),  //output
        .note_missed     (blue_missed)     //output
    );

    note_lane #(
        .STRIPE_WIDTH(STRIPE_WIDTH)
    ) u_orange_lane (
        .col             (col),
        .row             (row),
        .valid           (valid),
        .clk             (clk),
        .block_color     (orange),
        .drop_note       (note[1:0]),
        .lane_left_col   (orange_begin),
        .mark_hit        (orange_mark_hit),
        .button_held     (~orange_button),
        .lane_rgb        (orange_block),     //output
        .has_head_in_zone(orange_has_head),  //output
        .has_tail_in_zone(orange_has_tail),  //output
        .head_was_hit    (orange_head_hit),  //output
        .note_missed     (orange_missed)     //output
    );

    // Hit zone flash signals (flash lane color when button+strum pressed)
    logic flash_green, flash_yellow, flash_blue, flash_orange;
    assign flash_green  = !green_button && !white_button;
    assign flash_yellow = !yellow_button && !white_button;
    assign flash_blue   = !blue_button && !white_button;
    assign flash_orange = !orange_button && !white_button;

    // SCREEN COMPOSITION
    always_comb begin
        rgb = black;  // default/background color

        if (valid == 1) begin
            // LEFT & RIGHT EDGE BORDERS
            if ((col == 1) || (col == 639)) begin
                rgb = white;
                // LANE SEPARATOR BORDERS
            end else if ((col == 210) || (col == (lane_end + 10))) begin
                rgb = white;
                // HIT ZONE (segmented per lane with flash effect)
            end else if (435 <= row && row < 445) begin
                // Green segment
                if ((green_begin < col) && (col < (green_begin + STRIPE_WIDTH))) begin
                    rgb = flash_green ? green : gray;
                    // Yellow segment
                end else if ((yellow_begin < col) && (col < (yellow_begin + STRIPE_WIDTH))) begin
                    rgb = flash_yellow ? yellow : gray;
                    // Blue segment
                end else if ((blue_begin < col) && (col < (blue_begin + STRIPE_WIDTH))) begin
                    rgb = flash_blue ? blue : gray;
                    // Orange segment
                end else if ((orange_begin < col) && (col < (orange_begin + STRIPE_WIDTH))) begin
                    rgb = flash_orange ? orange : gray;
                end
                // "SCORE" && SCORE VALUE
            end else if ((20 < col) && (col < 150)) begin
                // "SCORE" title
                if ((20 < row) && (row < 60)) begin
                    rgb = score_title;
                    // SCORE VALUE (5 digits)
                end else if ((70 < row) && (row < 110)) begin
                    if ((20 < col) && (col <= 45)) begin
                        rgb = digit1;
                    end else if ((46 < col) && (col <= 71)) begin
                        rgb = digit2;
                    end else if ((72 < col) && (col <= 97)) begin
                        rgb = digit3;
                    end else if ((98 < col) && (col <= 123)) begin
                        rgb = digit4;
                    end else if ((124 < col) && (col <= 149)) begin
                        rgb = digit5;
                    end
                end
                // NOTE LANES
            end else if ((green_begin < col) && (col < (green_begin + STRIPE_WIDTH))) begin
                rgb = green_block;
            end else if ((yellow_begin < col) && (col < (yellow_begin + STRIPE_WIDTH))) begin
                rgb = yellow_block;
            end else if ((blue_begin < col) && (col < (blue_begin + STRIPE_WIDTH))) begin
                rgb = blue_block;
            end else if ((orange_begin < col) && (col < (orange_begin + STRIPE_WIDTH))) begin
                rgb = orange_block;
            end
            // REST OF SCREEN - black background (default)
        end
    end

endmodule
