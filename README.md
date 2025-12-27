# ES04 Final Project: Guitar Hero

A Guitar Hero inspired rhythm arcade game implemented entirely in SystemVerilog on an iCE40 Upduino-3.1 FPGA. The simulated hardware is comprised of four major subsystems:

1. A graphics engine that outputs analog VGA signals using shift registers for note rendering and animation
2. 46 kHz audio playback through an I2S audio amp using buffered 16-bit sample data read directly from a Micro SD card.
3. Game logic handling real-time hit detection, scoring, and note chart parsing from 8-bit patterns flashed into fpga memory.
4. A controller interface capturing fret button and strum inputs with strum-gated note registration.

Audio and visuals are synchronized via clock division from a 25.125 MHz PLL system clock. Note charts are encoded and generated using a Python script converting MIDI files to 8-bit patterns (2-bits per lane). Using an additional python script, audio is resampled, converted, and written directly to the MicroSD card sectors (bypassing the standard file structure due to FPGA resource contraints).

---

## Gameplay Demo:

https://github.com/user-attachments/assets/06ce64fe-b78c-4e6d-a678-70de533a19d3

## Circuit:

<p align="center">
  <img src="assets/circuit.png" width=50%>
</p>

## Project Structure

```bash
es04_guitar_hero/
├── src/                           # SystemVerilog source files & build
│   ├── apio.ini                   # Apio build configuration
│   ├── audio/                     # Audio subsystem
│   │   ├── RTL/                   # SD card SPI controller library
│   │   ├── audio_controller.sv    # SD sector streaming state machine
│   │   ├── audio_fifo.sv          # FIFO Audio buffer
│   │   └── i2s_tx.sv              # I2S transmitter
│   ├── graphics/                  # Graphics & game logic subsystem
│   │   ├── binary_note_data.txt   # Chart data loaded into BRAM
│   │   ├── counter.sv             # Clock divider for chart timing
│   │   ├── digit_gen.sv           # 7-segment score digit rendering
│   │   ├── hit_controller.sv      # Strum detection & note matching
│   │   ├── note_lane.sv           # Per lane shift register
│   │   ├── read_8_bit_pattern.sv  # Chart ROM reader
│   │   ├── score_controller.sv    # Scoring logic
│   │   ├── score_title_gen.sv     # Score display
│   │   ├── screen_gen.sv          # Top graphics orchestrator
│   │   └── vga.sv                 # 640x480 @ 60Hz timing
│   ├── guitar_hero.pcf            # Pin constraint file
│   ├── guitar_hero.sv             # Top-level module
│   └── mypll.sv                   # PLL (12 MHz -> 25.125 MHz)
├── tools/                         # Python utilities
│   ├── acdc_highway_to_hell/      # song assets
│   ├── midi_to_txt.py             # MIDI -> chart format converter
│   └── write_sd_audio.py          # WAV -> SD card image generator
└── README.md
```

## Build

```bash
cd src && apio build    # Synthesize
cd src && apio upload   # Flash to FPGA
```

## Libraries Used

[FPGA-SDcard-Reader-SPI](https://github.com/WangXuan95/FPGA-SDcard-Reader-SPI/tree/master)
