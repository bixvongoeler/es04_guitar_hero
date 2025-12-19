# ES04 Final Project: Guitar Hero

_Project Group: Bix Von Goeler, Johnny Getman, Erica Huang, Kaiden Khalsha_

---

## Gameplay Demo:

https://github.com/user-attachments/assets/06ce64fe-b78c-4e6d-a678-70de533a19d3

## Circuit:

<p align="center">
  <img src="assets/circuit.png" width=50%>
</p>

## Project Structure

```sh
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
