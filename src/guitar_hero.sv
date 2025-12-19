/*******************************************************************************
 *  @file: guitar_hero
 * @brief: Top-level module for Guitar Hero FPGA implementation.
 ******************************************************************************/

module guitar_hero (
    // Clock
    input  logic       osc,            // 12MHz external oscillator
    // Buttons (active low with internal pull-ups)
    input  logic       BTN_PLAY,       // Start playback
    input  logic       BTN_RESET,      // Stop playback
    // I2S Amplifier (MAX98357)
    output logic       AMP_LRC,        // Left/Right clock (LRCLK)
    output logic       AMP_BCLK,       // Bit clock
    output logic       AMP_DIN,        // Serial data
    // SD Card (SPI Mode)
    output logic       SD_CS,          // Chip select (active low)
    output logic       SD_SCK,         // SPI clock
    output logic       SD_MOSI,        // Master out, slave in
    input  logic       SD_MISO,        // Master in, slave out
    // VGA Adapter
    output logic       HSYNC,          //go to vga adapter
    output logic       VSYNC,          //go to vga adapter
    output logic [5:0] rgb,            //go to vga adapter
    output logic       locked,         //leave floating
    // Guitar Hero Controller
    input  logic       green_button,
    input  logic       yellow_button,
    input  logic       blue_button,
    input  logic       orange_button,
    input  logic       white_button,
    // Debug LEDs [3:0] = {Red, Yellow, Green, Blue}
    output logic [3:0] DLEDS
);
    assign locked = 1'b0;
    localparam VOLUME_SHIFT = 1;

    // =========================================================================
    // Internal Signals
    // =========================================================================

    // Clock and Reset
    logic       clk;  // 25.125MHz system clock
    logic       pll_locked;
    logic       reset;
    logic [7:0] reset_cnt;

    // Button Synchronizers (2-FF for metastability protection)
    logic btn_play_sync1, btn_play_sync2;
    logic btn_reset_sync1, btn_reset_sync2;

    // SD Card Interface
    logic        sd_rstn;
    logic [ 1:0] card_type;
    logic [ 3:0] card_stat;
    logic        sector_start;
    logic [31:0] sector_no;
    logic        sector_done;
    logic        sd_rvalid;
    logic [ 8:0] sd_raddr;  // Not used (controller reads via rvalid/rdata)
    logic [ 7:0] sd_rdata;

    // Audio FIFO
    logic        fifo_wr_en;
    logic [ 7:0] fifo_wr_data;
    logic        fifo_full;
    logic        fifo_rd_en;
    logic [ 7:0] fifo_rd_data;
    logic        fifo_empty;
    logic        fifo_rd_valid;
    logic [10:0] fifo_fill_level;

    // I2S and Audio Control
    logic        i2s_enable;
    logic [ 3:0] led_status;

    // =========================================================================
    // PLL: 12MHz -> 25.125MHz
    // =========================================================================

    mypll pll_inst (
        .clock_in (osc),
        .clock_out(clk),
        .locked   (pll_locked)
    );

    // =========================================================================
    // Power-On Reset Generator
    // =========================================================================

    always_ff @(posedge clk) begin
        if (!pll_locked) begin
            reset_cnt <= '0;
            reset     <= 1'b1;
        end else if (reset_cnt < 8'hFF) begin
            reset_cnt <= reset_cnt + 1'b1;
            reset     <= 1'b1;
        end else begin
            reset <= 1'b0;
        end
    end

    // =========================================================================
    // Button Synchronizers
    // =========================================================================

    always_ff @(posedge clk) begin
        if (reset) begin
            btn_play_sync1  <= 1'b1;
            btn_play_sync2  <= 1'b1;
            btn_reset_sync1 <= 1'b1;
            btn_reset_sync2 <= 1'b1;
        end else begin
            btn_play_sync1  <= BTN_PLAY;
            btn_play_sync2  <= btn_play_sync1;
            btn_reset_sync1 <= BTN_RESET;
            btn_reset_sync2 <= btn_reset_sync1;
        end
    end

    // =========================================================================
    // SD Card Sector Reader
    // =========================================================================

    sd_spi_sector_reader #(
        .SPI_CLK_DIV(3)  // 25.125MHz / 6 = 4.2 MHz SPI clock
    ) sd_reader_inst (
        .rstn     (sd_rstn),
        .clk      (clk),
        .spi_ssn  (SD_CS),
        .spi_sck  (SD_SCK),
        .spi_mosi (SD_MOSI),
        .spi_miso (SD_MISO),
        .card_type(card_type),
        .card_stat(card_stat),
        .start    (sector_start),
        .sector_no(sector_no),
        .done     (sector_done),
        .rvalid   (sd_rvalid),
        .raddr    (sd_raddr),
        .rdata    (sd_rdata)
    );

    // =========================================================================
    // Audio FIFO (Double-Buffered)
    // =========================================================================

    audio_fifo #(
        .DEPTH(1024),
        .WIDTH(8)
    ) audio_fifo_inst (
        .CLK       (clk),
        .RESET     (reset || !sd_rstn),
        .wr_en     (fifo_wr_en),
        .wr_data   (fifo_wr_data),
        .full      (fifo_full),
        .rd_en     (fifo_rd_en),
        .rd_data   (fifo_rd_data),
        .empty     (fifo_empty),
        .rd_valid  (fifo_rd_valid),
        .fill_level(fifo_fill_level)
    );

    // =========================================================================
    // Audio Controller
    // =========================================================================

    audio_controller audio_controller_inst (
        .CLK            (clk),
        .RESET          (reset),
        .btn_play_n     (btn_play_sync2),
        .btn_reset_n    (btn_reset_sync2),
        .sd_rstn        (sd_rstn),
        .card_stat      (card_stat),
        .sector_start   (sector_start),
        .sector_no      (sector_no),
        .sector_done    (sector_done),
        .sd_rvalid      (sd_rvalid),
        .sd_rdata       (sd_rdata),
        .fifo_wr_en     (fifo_wr_en),
        .fifo_wr_data   (fifo_wr_data),
        .fifo_full      (fifo_full),
        .fifo_empty     (fifo_empty),
        .fifo_fill_level(fifo_fill_level),
        .i2s_enable     (i2s_enable),
        .led_status     (led_status)
    );

    // =========================================================================
    // I2S Transmitter
    // =========================================================================

    i2s_tx #(
        .BCLK_DIV    (17),           // 25.125MHz / 17 / 32 = 46.186kHz sample rate
        .VOLUME_SHIFT(VOLUME_SHIFT)
    ) i2s_tx_inst (
        .CLK          (clk),
        .RESET        (reset),
        .enable       (i2s_enable),
        .fifo_rd_en   (fifo_rd_en),
        .fifo_data    (fifo_rd_data),
        .fifo_empty   (fifo_empty),
        .fifo_rd_valid(fifo_rd_valid),
        .BCLK         (AMP_BCLK),
        .LRCLK        (AMP_LRC),
        .DATA         (AMP_DIN)
    );

    // =========================================================================
    // VGA Code
    // =========================================================================

    logic [9:0] curr_col;
    logic [9:0] curr_row;
    logic valid;

    vga u_vga (
        .clk     (clk),
        .HSYNC   (HSYNC),
        .VSYNC   (VSYNC),
        .valid   (valid),
        .curr_col(curr_col),
        .curr_row(curr_row)
    );

    logic counter_clk;
    counter u_counter (
        .in_clk (clk),
        .out_clk(counter_clk)
    );

    logic [7:0] note;  // 8-bit: [7:6]=green, [5:4]=yellow, [3:2]=blue, [1:0]=orange
    logic valid_read;
    logic should_reset = ~btn_reset_sync2 | ~btn_play_sync2;

    screen_gen u_screen_gen (
        .col          (curr_col),
        .row          (curr_row),
        .valid        (valid),
        .rgb          (rgb),
        .clk          (counter_clk),
        .reset        (should_reset),
        .note         (note),
        .valid_note   (valid_read),
        .green_button (green_button),
        .yellow_button(yellow_button),
        .blue_button  (blue_button),
        .orange_button(orange_button),
        .white_button (white_button)
    );

    read_8_bit_pattern #(
        .WIDTH(8),    // 2 bits per lane x 4 lanes
        .DEPTH(2240)  // Chart length
    ) reader (
        .clk     (counter_clk),
        .reset   (should_reset),
        .data_out(note),
        .valid   (valid_read)
    );

    // Debug LED Output
    assign DLEDS = led_status;

endmodule
