"""
Convert a MIDI file to a custom 8 bit text chart format to be uploaded to FPGA.

Each row represents a fixed time interval (subdivision of a beat).

Each row contains 4 lanes (for 4 buttons).

Each lane uses 2 bits per row:
    00 = no note
    01 = tail
    10 = head
    11 = unused
"""

import mido


def midi_to_chart(midi_path, output_path, lane_notes, subdivision=4, rows_per_step=4):
    mid = mido.MidiFile(midi_path)
    ticks_per_beat = mid.ticks_per_beat
    ticks_per_step = ticks_per_beat // subdivision

    # Collect note-on and note-off events with absolute timing
    notes = []  # (start_tick, end_tick, note)
    active = {}  # note -> start_tick

    for track in mid.tracks:
        abs_time = 0
        for msg in track:
            abs_time += msg.time
            if msg.type == "note_on" and msg.velocity > 0:
                active[msg.note] = abs_time
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                if msg.note in active:
                    notes.append((active[msg.note], abs_time, msg.note))
                    del active[msg.note]

    if not notes:
        print("No notes found")
        return

    # Find chart length in rows
    max_tick = max(end for _, end, _ in notes)
    num_steps = (max_tick // ticks_per_step) + 1
    num_rows = num_steps * rows_per_step

    # Build chart: 0 = none, 1 = tail, 2 = head
    chart = [[0, 0, 0, 0] for _ in range(num_rows)]

    for start_tick, end_tick, note in notes:
        if note not in lane_notes:
            continue
        lane = lane_notes.index(note)

        start_step = start_tick // ticks_per_step
        end_step = end_tick // ticks_per_step

        start_row = start_step * rows_per_step
        end_row = end_step * rows_per_step

        # First 4 rows are head (2), rest are tail (1)
        for row in range(start_row, end_row):
            if row < num_rows:
                if row < start_row + rows_per_step:
                    chart[row][lane] = 2  # head
                else:
                    chart[row][lane] = 1  # tail

    # Write output (2 bits per lane)
    with open(output_path, "w") as f:
        for row in chart:
            line = "".join(f"{val:02b}" for val in row)
            f.write(line + "\n")


midi_to_chart(
    "midi_track_chorded.mid",
    "chart_chorded_v2.txt",
    lane_notes=[60, 61, 62, 63],
    subdivision=4,
)
