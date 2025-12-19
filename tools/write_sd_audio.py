"""
Write Raw Audio to SD Card for FPGA Playback

Usage: sudo python write_sd_audio.py <audio_file> <device>
Example: sudo python write_sd_audio.py song.mp3 /dev/disk4

Output: 16-bit signed LE mono PCM at 46186Hz, starting at sector 0.
Update MAX_SECTORS in audio_controller.sv with the printed value.
"""

import os
import subprocess
import sys
import tempfile

# 25.125MHz PLL / 17 (BCLK_DIV) / 32 (bits per frame) = 46186Hz
SAMPLE_RATE = 46186
BITS_PER_SAMPLE = 16
CHANNELS = 1
SECTOR_SIZE = 512


def convert_audio(input_file: str) -> bytes:
    """Convert audio file to raw 16-bit mono PCM using ffmpeg."""
    print(f"Loading: {input_file}")

    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        # Try soxr resampler first, fall back to default
        cmd_base = [
            "ffmpeg",
            "-y",
            "-i",
            input_file,
            "-ac",
            str(CHANNELS),
            "-ar",
            str(SAMPLE_RATE),
            "-sample_fmt",
            "s16",
            "-f",
            "s16le",
            tmp_path,
        ]
        cmd_soxr = cmd_base.copy()
        cmd_soxr.insert(-2, "-af")
        cmd_soxr.insert(-2, "aresample=resampler=soxr:precision=28")

        print("Converting with ffmpeg (soxr resampler)...")
        result = subprocess.run(cmd_soxr, capture_output=True, text=True)

        if result.returncode != 0:
            print("Note: soxr not available, using default resampler")
            result = subprocess.run(cmd_base, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"ffmpeg error: {result.stderr}")
                sys.exit(1)

        with open(tmp_path, "rb") as f:
            raw_data = f.read()

        duration_sec = len(raw_data) / (SAMPLE_RATE * 2)
        print(f"Duration: {duration_sec:.2f} seconds")
        print(f"Format: {SAMPLE_RATE}Hz, {BITS_PER_SAMPLE}-bit, mono")

        return raw_data

    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def write_to_device(raw_data: bytes, device_path: str) -> None:
    """Write raw audio data directly to SD card starting at sector 0."""
    padding_needed = (SECTOR_SIZE - (len(raw_data) % SECTOR_SIZE)) % SECTOR_SIZE
    if padding_needed > 0:
        raw_data = raw_data + (b"\x00" * padding_needed)

    total_sectors = len(raw_data) // SECTOR_SIZE
    total_bytes = len(raw_data)

    print(f"\nData size: {total_bytes:,} bytes ({total_sectors:,} sectors)")
    print(f"Device: {device_path}")
    print(f"\n{'=' * 50}")
    print(f"MAX_SECTORS = {total_sectors}")
    print(f"{'=' * 50}")
    print("\nUpdate audio_controller.sv with this value!")

    print(f"\nWARNING: This will DESTROY ALL DATA on {device_path}")
    confirm = input("Type 'YES' to confirm: ")
    if confirm != "YES":
        print("Aborted.")
        sys.exit(1)

    print(f"\nWriting {total_sectors:,} sectors...")

    try:
        with open(device_path, "r+b") as f:
            bytes_written = 0
            sector = 0

            while bytes_written < total_bytes:
                chunk = raw_data[bytes_written : bytes_written + SECTOR_SIZE]
                f.write(chunk)
                bytes_written += len(chunk)
                sector += 1

                if sector % 1000 == 0:
                    pct = (bytes_written / total_bytes) * 100
                    print(f"  Sector {sector:,} / {total_sectors:,} ({pct:.1f}%)")

            f.flush()
            os.fsync(f.fileno())

        print(f"\nSuccess! Wrote {total_sectors:,} sectors to {device_path}")
        print(f"\nRemember to set MAX_SECTORS = {total_sectors} in audio_controller.sv")

    except PermissionError:
        print("Error: Permission denied. Try running with sudo:")
        print(f"  sudo python {sys.argv[0]} {sys.argv[1]} {sys.argv[2]}")
        sys.exit(1)
    except Exception as e:
        print(f"Error writing to device: {e}")
        sys.exit(1)


def validate_device_path(device_path: str) -> None:
    """Validate device path and warn about system disks."""
    if not device_path.startswith("/dev/"):
        print(f"Error: Device path should start with /dev/ (got: {device_path})")
        sys.exit(1)

    dangerous_patterns = ["disk0", "disk1", "sda", "sdb", "nvme0"]
    for pattern in dangerous_patterns:
        if pattern in device_path:
            print(f"\nDANGER: {device_path} looks like a system disk!")
            print("SD cards are typically /dev/disk2 or higher on macOS")
            print("Use 'diskutil list' to identify your SD card")
            confirm = input("Type 'I UNDERSTAND THE RISK' to continue: ")
            if confirm != "I UNDERSTAND THE RISK":
                print("Aborted.")
                sys.exit(1)


def check_ffmpeg() -> None:
    """Verify ffmpeg is installed."""
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
    except FileNotFoundError:
        print("Error: ffmpeg not found. Install with: brew install ffmpeg")
        sys.exit(1)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    input_file = sys.argv[1]
    device_path = sys.argv[2]

    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    validate_device_path(device_path)
    check_ffmpeg()

    raw_data = convert_audio(input_file)
    write_to_device(raw_data, device_path)


if __name__ == "__main__":
    main()
