// ============================================================================
// I2S Transmitter
// ============================================================================
module i2s_tx #(
    parameter BCLK_DIV = 17,  // 25.125MHz / 17 = 1.478 MHz BCLK -> 46.186kHz
    parameter VOLUME_SHIFT = 3  // Adjust volume by right shifting by 3 bits
) (
    input logic CLK,    // 25.125MHz system clock
    input logic RESET,
    input logic enable,

    // FIFO Interface (reads 2 bytes per sample: LSB then MSB)
    output logic       fifo_rd_en,
    input  logic [7:0] fifo_data,
    input  logic       fifo_empty,
    input  logic       fifo_rd_valid,

    // I2S Output
    output logic BCLK,
    output logic LRCLK,
    output logic DATA
);

    // -------------------------------------------------------------------------
    // Clock Divider for BCLK Generation
    // -------------------------------------------------------------------------

    localparam DIV_WIDTH = $clog2(BCLK_DIV);  // 25.125MHz / 17 = 1.478 MHz BCLK -> 46.186kHz
    logic [DIV_WIDTH-1:0] clk_div_cnt;

    always_ff @(posedge CLK) begin
        if (RESET || !enable) begin
            clk_div_cnt <= '0;
        end else begin
            if (clk_div_cnt == BCLK_DIV - 1) clk_div_cnt <= '0;
            else clk_div_cnt <= clk_div_cnt + 1'b1;
        end
    end

    // BCLK high for first half of divider period
    assign BCLK = enable ? (clk_div_cnt < (BCLK_DIV / 2)) : 1'b0;

    // Edge detection for internal timing
    wire bclk_rising = (clk_div_cnt == (BCLK_DIV / 2) - 1);
    wire bclk_falling = (clk_div_cnt == BCLK_DIV - 1);

    // -------------------------------------------------------------------------
    // Bit Counter and LRCLK Generation
    // -------------------------------------------------------------------------

    // 32 bits per frame: 0-15 = left channel, 16-31 = right channel
    logic [4:0] bit_cnt;

    always_ff @(posedge CLK) begin
        if (RESET || !enable) begin
            bit_cnt <= '0;
            LRCLK   <= 1'b0;
        end else if (bclk_falling) begin
            if (bit_cnt == 5'd31) begin
                bit_cnt <= '0;
                LRCLK   <= 1'b0;  // Start of left channel
            end else begin
                bit_cnt <= bit_cnt + 1'b1;
                if (bit_cnt == 5'd15) LRCLK <= 1'b1;  // Switch to right channel
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sample Assembly from Buffer
    // -------------------------------------------------------------------------

    typedef enum logic [1:0] {
        BYTE_IDLE,
        BYTE_WAIT_LSB,
        BYTE_WAIT_MSB,
        BYTE_READY
    } byte_state_t;

    byte_state_t byte_state;
    logic [7:0] sample_lsb;
    logic [15:0] sample;

    always_ff @(posedge CLK) begin
        if (RESET || !enable) begin
            byte_state <= BYTE_IDLE;
            sample_lsb <= '0;
            sample     <= '0;
            fifo_rd_en <= 1'b0;
        end else begin
            fifo_rd_en <= 1'b0;  // Default: no read

            case (byte_state)
                BYTE_IDLE: begin
                    // Start loading new sample at end of frame (before left channel)
                    if (bclk_falling && bit_cnt == 5'd31 && !fifo_empty) begin
                        fifo_rd_en <= 1'b1;
                        byte_state <= BYTE_WAIT_LSB;
                    end
                end

                BYTE_WAIT_LSB: begin
                    if (fifo_rd_valid) begin
                        sample_lsb <= fifo_data;
                        if (!fifo_empty) begin
                            fifo_rd_en <= 1'b1;
                            byte_state <= BYTE_WAIT_MSB;
                        end else begin
                            // FIFO underrun: use partial sample (LSB only)
                            sample     <= {8'h00, fifo_data};
                            byte_state <= BYTE_READY;
                        end
                    end
                end

                BYTE_WAIT_MSB: begin
                    if (fifo_rd_valid) begin
                        // Assemble 16-bit sample: {MSB, LSB}
                        sample     <= {fifo_data, sample_lsb};
                        byte_state <= BYTE_READY;
                    end
                end

                BYTE_READY: begin
                    byte_state <= BYTE_IDLE;
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Volume Attenuation
    // -------------------------------------------------------------------------

    function automatic [15:0] attenuate(input [15:0] s);
        case (VOLUME_SHIFT)
            0:       attenuate = s;  // 0dB (full volume)
            1:       attenuate = {{1{s[15]}}, s[15:1]};  // -6dB
            2:       attenuate = {{2{s[15]}}, s[15:2]};  // -12dB
            3:       attenuate = {{3{s[15]}}, s[15:3]};  // -18dB
            4:       attenuate = {{4{s[15]}}, s[15:4]};  // -24dB
            5:       attenuate = {{5{s[15]}}, s[15:5]};  // -30dB
            6:       attenuate = {{6{s[15]}}, s[15:6]};  // -36dB
            default: attenuate = {{4{s[15]}}, s[15:4]};  // Default -24dB
        endcase
    endfunction

    wire  [15:0] output_sample = attenuate(sample);


    // -------------------------------------------------------------------------
    // Shift Register for Serial Output
    // -------------------------------------------------------------------------

    logic [15:0] shift_reg;

    always_ff @(posedge CLK) begin
        if (RESET || !enable) begin
            shift_reg <= '0;
            DATA      <= 1'b0;
        end else if (bclk_falling) begin
            if (bit_cnt == 5'd0) begin
                // Start of left channel: load attenuated sample
                shift_reg <= output_sample;
                DATA      <= output_sample[15];  // MSB first
            end else if (bit_cnt == 5'd16) begin
                // Start of right channel: reload same sample (mono -> stereo)
                shift_reg <= output_sample;
                DATA      <= output_sample[15];
            end else begin
                // Shift out next bit
                shift_reg <= {shift_reg[14:0], 1'b0};
                DATA      <= shift_reg[14];  // Next bit after shift
            end
        end
    end

endmodule
