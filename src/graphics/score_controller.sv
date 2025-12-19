module score_controller (
    input  logic        clk,
    input  logic        reset,
    // From hit_controller
    input  logic        hit_event,
    input  logic        miss_event,
    input  logic [ 3:0] lane_hits,       // {green, yellow, blue, orange} hit this cycle
    // From note_lanes - zone status
    input  logic [ 3:0] heads_in_zone,   // {g,y,b,o} has head in zone
    input  logic [ 3:0] tails_in_zone,   // {g,y,b,o} has tail in zone
    input  logic [ 3:0] heads_were_hit,  // {g,y,b,o} head in zone was hit (from note_lane)
    // Button state for tail scoring (active high)
    input  logic [ 3:0] buttons_held,    // {g,y,b,o} button currently held
    // missed notes
    input  logic [ 3:0] notes_missed,    // {g,y,b,o} note missed this cycle
    // Output
    output logic [16:0] score
);

    // Scoring constants
    localparam logic [16:0] HEAD_HIT_POINTS = 17'd10;
    localparam logic [16:0] MISS_PENALTY = 17'd1;
    localparam logic [16:0] TAIL_POINTS = 17'd1;

    // Per-lane tracking
    logic [3:0] lane_head_success;

    // Count tails scoring this cycle
    logic [2:0] tail_score_count;

    // Count notes missed this cycle
    logic [2:0] missed_count;

    always_comb begin
        tail_score_count = 3'd0;
        missed_count = 3'd0;
        for (int i = 0; i < 4; i++) begin
            // Tail scores if: tail in zone, button held, and last head was hit
            if (tails_in_zone[i] && buttons_held[i] && lane_head_success[i]) begin
                tail_score_count = tail_score_count + 3'd1;
            end
            // Count missed notes
            if (notes_missed[i]) begin
                missed_count = missed_count + 3'd1;
            end
        end
    end

    // Score accumulation and state tracking
    always_ff @(posedge clk) begin
        if (reset) begin
            score <= 17'd0;
            lane_head_success <= 4'b0000;
        end else begin
            // Update lane_head_success tracking
            for (int i = 0; i < 4; i++) begin
                if (lane_hits[i]) begin
                    // Head was just hit in this lane
                    lane_head_success[i] <= 1'b1;
                end else if (heads_in_zone[i] && !heads_were_hit[i]) begin
                    // New unhit head entered zone - reset the flag
                    lane_head_success[i] <= 1'b0;
                end
            end

            // Score updates, head hits priority, then misses, then tails
            if (hit_event) begin
                // Successful hit - add points
                if (score <= (17'd99999 - HEAD_HIT_POINTS)) begin
                    score <= score + HEAD_HIT_POINTS;
                end else begin
                    score <= 17'd99999;
                end
            end else if (miss_event) begin
                // Miss penalty
                if (score >= MISS_PENALTY) begin
                    score <= score - MISS_PENALTY;
                end else begin
                    score <= 17'd0;
                end
            end

            // Tail scoring every cycle tails are held
            if (tail_score_count > 0) begin
                if (score <= (17'd99999 - {14'd0, tail_score_count})) begin
                    score <= score + {14'd0, tail_score_count};
                end else begin
                    score <= 17'd99999;
                end
            end

            // Missed note penalty
            if (missed_count > 0) begin
                logic [16:0] penalty;
                penalty = {14'd0, missed_count} * MISS_PENALTY;
                if (score >= penalty) begin
                    score <= score - penalty;
                end else begin
                    score <= 17'd0;
                end
            end
        end
    end

endmodule
