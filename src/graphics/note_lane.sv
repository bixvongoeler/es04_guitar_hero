module note_lane #(
    parameter STRIPE_WIDTH = 35
) (
    input  logic [9:0] col,
    input  logic [9:0] row,
    input  logic       valid,
    input  logic       clk,
    input  logic [5:0] block_color,
    input  logic [1:0] drop_note,         // 2-bit: 00=none, 01=tail, 10=head
    input  logic [9:0] lane_left_col,     // Left edge column of this lane
    input  logic       mark_hit,          // Signal to mark heads in zone as hit
    input  logic       button_held,       // Button is being held (for tail clearing)
    output logic [5:0] lane_rgb,
    output logic       has_head_in_zone,
    output logic       has_tail_in_zone,
    output logic       head_was_hit,      // Any head in zone was successfully hit
    output logic       note_missed        // Pulses when an unhit head exits the screen
);

    // 3-bit per stage: [2:1] = note_type, [0] = was_hit flag
    // note_type: 00=none, 01=tail, 10=head
    logic [2:0] shift_reg[96];

    // Track whether we're in a tail-clearing sequence
    logic tail_clear_active;

    // Hit zone spans stages 84-92 (9 stages)
    localparam HIT_ZONE_START = 83;
    localparam HIT_ZONE_END = 92;

    // Extract hit zone status, only check 7 stages
    logic zone_has_head_any;
    logic zone_has_tail_any;
    logic zone_head_hit_any;

    always_comb begin
        zone_has_head_any = 1'b0;
        zone_has_tail_any = 1'b0;
        zone_head_hit_any = 1'b0;
        for (int z = HIT_ZONE_START; z <= HIT_ZONE_END; z++) begin
            if (shift_reg[z][2:1] == 2'b10) begin
                zone_has_head_any = 1'b1;
                if (shift_reg[z][0]) zone_head_hit_any = 1'b1;
            end
            if (shift_reg[z][2:1] == 2'b01) zone_has_tail_any = 1'b1;
        end
    end

    assign has_head_in_zone = zone_has_head_any;
    assign has_tail_in_zone = zone_has_tail_any;
    assign head_was_hit     = zone_head_hit_any;

    // stage = row / 5, each stage is 5 pixels tall
    logic [6:0] current_stage;
    assign current_stage = row[9:0] / 5;  // Divide by 5

    // Calculate relative column position within lane
    logic [5:0] rel_col;
    assign rel_col = col - lane_left_col[5:0];

    logic is_left_edge, is_right_edge;
    assign is_left_edge  = (rel_col == 0);
    assign is_right_edge = (rel_col == STRIPE_WIDTH - 1);

    // Center region for tail rendering
    logic is_center;
    assign is_center = (rel_col >= (STRIPE_WIDTH / 2 - 1)) && (rel_col <= (STRIPE_WIDTH / 2 + 1));

    // Row position within the 5-pixel block
    logic [2:0] rel_row;
    assign rel_row = row - (current_stage * 5);

    logic is_top_edge, is_bottom_edge;
    assign is_top_edge    = (rel_row == 0);
    assign is_bottom_edge = (rel_row == 4);

    // Rendering logic
    always_comb begin
        lane_rgb = 6'd0;
        if (current_stage < 96) begin
            logic [1:0] note_type;
            logic       was_hit;
            note_type = shift_reg[current_stage][2:1];
            was_hit   = shift_reg[current_stage][0];
            case (note_type)
                2'b10: begin  // HEAD
                    if (was_hit) begin
                        // Flash white before disappearing
                        lane_rgb = 6'b111111;
                    end else begin
                        // Solid block
                        lane_rgb = block_color;
                    end
                end
                2'b01: begin  // TAIL
                    // Thin vertical line in center
                    if (is_center) begin
                        if (was_hit) begin
                            lane_rgb = 6'b111111;  // White flash when being cleared
                        end else begin
                            lane_rgb = block_color;
                        end
                    end
                end
                default: begin
                    // grey center line when empty for string
                    if (is_center) begin
                        lane_rgb = 6'b010101;
                    end
                end
            endcase
        end
    end

    // shift register update logic
    always_ff @(posedge clk) begin
        // Detect missed notes, check if stage 95 has an unhit head
        if (shift_reg[95][2:1] == 2'b10 && shift_reg[95][0] == 1'b0) begin
            note_missed <= 1'b1;
        end else begin
            note_missed <= 1'b0;
        end

        // Stage 0 - load new notes from chart
        shift_reg[0][2:1] <= drop_note;
        shift_reg[0][0]   <= 1'b0;  // New notes are not hit

        // Update tail_clear_active state
        if (mark_hit && zone_has_head_any) begin
            // A head was just hit - start clearing tails
            tail_clear_active <= 1'b1;
        end else if (zone_has_head_any && !zone_head_hit_any) begin
            // New unhit head in zone - stop clearing tails
            tail_clear_active <= 1'b0;
        end else if (!zone_has_head_any && !zone_has_tail_any) begin
            // Zone is empty - reset
            tail_clear_active <= 1'b0;
        end

        // Stages 1-95 - shift with hit marking and clearing
        for (int i = 1; i < 96; i++) begin
            logic [1:0] prev_type;
            logic       prev_hit;
            logic       in_zone;
            logic       is_head;
            logic       is_tail;

            prev_type = shift_reg[i-1][2:1];
            prev_hit  = shift_reg[i-1][0];
            in_zone   = (i >= HIT_ZONE_START) && (i <= HIT_ZONE_END);
            is_head   = (prev_type == 2'b10);
            is_tail   = (prev_type == 2'b01);

            // If previous stage had a hit note, clear it
            if (prev_hit && (is_head || is_tail)) begin
                shift_reg[i][2:1] <= 2'b00;
                shift_reg[i][0]   <= 1'b0;
                // Mark tails as hit when button held after head hit
            end else if ((i >= HIT_ZONE_START) && is_tail && tail_clear_active && button_held) begin
                shift_reg[i][2:1] <= prev_type;
                shift_reg[i][0]   <= 1'b1;  // Mark as hit for clear next cycle
            end else begin
                shift_reg[i][2:1] <= prev_type;
                // Mark hit if: mark_hit signal, destination in hit zone, is a head, not already hit
                if (mark_hit && in_zone && is_head && !prev_hit) begin
                    shift_reg[i][0] <= 1'b1;
                end else begin
                    shift_reg[i][0] <= prev_hit;
                end
            end
        end
    end
endmodule
