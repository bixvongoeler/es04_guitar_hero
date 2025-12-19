// ============================================================================
// Audio Controller
// ============================================================================

module audio_controller #(
    parameter MAX_SECTORS = 13943  // Total Sd Card sectors of audio Data
) (
    input logic CLK,
    input logic RESET,

    // Button inputs
    input logic btn_play_n,
    input logic btn_reset_n,

    // SD Card Sector Reader Interface
    output logic        sd_rstn,       // Active-low reset for SD reader
    input  logic [ 3:0] card_stat,     // Card state (CARD_IDLE = ready)
    output logic        sector_start,  // Pulse high to request sector read
    output logic [31:0] sector_no,     // Sector number to read
    input  logic        sector_done,   // Pulses when sector read completes

    // SD Card Data Interface
    input logic       sd_rvalid,  // Byte valid strobe
    input logic [7:0] sd_rdata,   // Byte data from SD

    // FIFO Interface
    output logic        fifo_wr_en,
    output logic [ 7:0] fifo_wr_data,
    input  logic        fifo_full,
    input  logic        fifo_empty,
    input  logic [10:0] fifo_fill_level,

    // I2S Control
    output logic i2s_enable,

    // Debug LEDs
    output logic [3:0] led_status
);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    // SD card reader reports this state when ready for commands
    localparam CARD_IDLE = 4'd8;

    // FIFO threshold: start reading when we have room for a full sector
    localparam FIFO_THRESHOLD = 11'd512;

    // -------------------------------------------------------------------------
    // State Machine
    // -------------------------------------------------------------------------

    typedef enum logic {
        IDLE,
        PLAYING
    } state_t;

    state_t        state;

    // -------------------------------------------------------------------------
    // Sector Tracking
    // -------------------------------------------------------------------------

    logic   [31:0] current_sector;
    logic          sector_reading;  // True while a sector read is in progress
    logic          start_request;  // Registered request signal

    wire           last_sector = (current_sector >= MAX_SECTORS);

    assign sector_no    = current_sector;
    assign sector_start = start_request;

    // -------------------------------------------------------------------------
    // Main State Machine
    // -------------------------------------------------------------------------

    always_ff @(posedge CLK) begin
        if (RESET) begin
            state          <= IDLE;
            sd_rstn        <= 1'b0;
            i2s_enable     <= 1'b0;
            current_sector <= 32'd0;
            sector_reading <= 1'b0;
            start_request  <= 1'b0;
        end else begin
            case (state)
                // -------------------------------------------------------------
                // IDLE: Wait for PLAY button
                // -------------------------------------------------------------
                IDLE: begin
                    sd_rstn        <= 1'b0;  // Keep SD card in reset
                    i2s_enable     <= 1'b0;
                    current_sector <= 32'd0;
                    sector_reading <= 1'b0;
                    start_request  <= 1'b0;

                    if (!btn_play_n) begin
                        state   <= PLAYING;
                        sd_rstn <= 1'b1;  // Release SD reset to begin init
                    end
                end

                // -------------------------------------------------------------
                // PLAYING: Stream audio from SD to I2S
                // -------------------------------------------------------------
                PLAYING: begin
                    sd_rstn    <= 1'b1;
                    i2s_enable <= 1'b1;

                    // Stop conditions: RESET button or end of audio
                    if (!btn_reset_n || last_sector) begin
                        state <= IDLE;
                    end else begin
                        // Handle sector completion
                        if (sector_done) begin
                            current_sector <= current_sector + 1'b1;
                            sector_reading <= 1'b0;
                            start_request  <= 1'b0;
                        end

                        // Request next sector when:
                        // 1. SD card is ready (CARD_IDLE)
                        // 2. FIFO has room for 512 bytes (double-buffering)
                        // 3. Not already reading a sector
                        if (card_stat == CARD_IDLE &&
                            fifo_fill_level <= FIFO_THRESHOLD &&
                            !sector_reading) begin
                            sector_reading <= 1'b1;
                            start_request  <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // FIFO Write Logic
    // -------------------------------------------------------------------------

    // Pass SD data directly to FIFO (only when playing and FIFO has room)
    assign fifo_wr_en   = sd_rvalid && !fifo_full && (state == PLAYING);
    assign fifo_wr_data = sd_rdata;

    // -------------------------------------------------------------------------
    // Debug LED Display
    // ---------------------                ----------------------------------------------------

    // Stretch sector_done pulse for LED visibility (~40ms at 25MHz)
    logic [19:0] done_stretch;

    always_ff @(posedge CLK) begin
        if (RESET) done_stretch <= '0;
        else if (sector_done) done_stretch <= '1;
        else if (done_stretch > 0) done_stretch <= done_stretch - 1'b1;
    end

    // LED mapping: [3]=Red, [2]=Yellow, [1]=Green, [0]=Blue
    assign led_status = (state == IDLE) ? 4'b0001 :  // Blue: idle
        (done_stretch > 0) ? 4'b0100 :  // Yellow: sector activity
        card_stat;  // Show card state

endmodule
