#!/usr/bin/env python3
"""Synthesize four original 24-second music beds. No samples, no third-party audio."""
import math
import os
import random
import struct
import subprocess
import wave

SR = 44100
DURATION = 24.0
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Reelcraft/Resources/Sounds")
os.makedirs(OUT, exist_ok=True)

NOTE = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00, "B3": 246.94,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
}


def blank():
    return [0.0] * int(SR * DURATION)


def add_note(buf, start, length, freq, amp=0.2, harmonics=(1.0, 0.35, 0.12), attack=0.02, release=0.4, detune=0.0):
    n0 = int(start * SR)
    n = int(length * SR)
    for i in range(n):
        idx = n0 + i
        if idx >= len(buf):
            break
        t = i / SR
        env = 1.0
        if t < attack:
            env = t / attack
        if t > length - release:
            env *= max(0.0, (length - t) / release)
        # gentle overall decay
        env *= math.exp(-t * 0.18)
        value = 0.0
        for h, level in enumerate(harmonics, start=1):
            value += level * math.sin(2 * math.pi * freq * h * t + detune * h)
        buf[idx] += value * amp * env


def add_noise(buf, start, length, amp=0.03, decay=0.06):
    n0 = int(start * SR)
    n = int(length * SR)
    for i in range(n):
        idx = n0 + i
        if idx >= len(buf):
            break
        t = i / SR
        env = math.exp(-t / decay)
        buf[idx] += (random.random() * 2 - 1) * amp * env


def add_kick(buf, start, amp=0.35):
    n0 = int(start * SR)
    length = int(0.28 * SR)
    for i in range(length):
        idx = n0 + i
        if idx >= len(buf):
            break
        t = i / SR
        freq = 110 * math.exp(-t * 18) + 45
        env = math.exp(-t * 12)
        buf[idx] += math.sin(2 * math.pi * freq * t) * amp * env


def normalize(buf, peak=0.86):
    high = max(1e-6, max(abs(x) for x in buf))
    gain = peak / high
    return [x * gain for x in buf]


def write_wav(name, buf):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for sample in buf:
            clipped = max(-1.0, min(1.0, sample))
            value = int(clipped * 32767)
            frames += struct.pack("<hh", value, value)
        w.writeframes(bytes(frames))
    return path


def drift():
    buf = blank()
    chords = [
        ("C3", ["E4", "G4", "B4"]),
        ("A3", ["C4", "E4", "G4"]),
        ("F3", ["A3", "C4", "E4"]),
        ("G3", ["B3", "D4", "A4"]),
    ]
    bar = 6.0
    for rep in range(4):
        root, notes = chords[rep % len(chords)]
        base = rep * bar
        add_note(buf, base, bar, NOTE[root], amp=0.18, attack=0.9, release=1.6, harmonics=(1.0, 0.4, 0.18, 0.07))
        for j, note in enumerate(notes):
            add_note(buf, base + 0.35 * j, bar - 0.5, NOTE[note] * 1.002, amp=0.10,
                     attack=0.8, release=1.2, harmonics=(1.0, 0.3, 0.1), detune=0.4)
    return normalize(buf, 0.7)


def hush():
    buf = blank()
    progression = [("C4", ["E4", "G4"]), ("A3", ["C4", "E4"]), ("F3", ["A3", "C4"]), ("G3", ["B3", "D4"])]
    step = 1.5
    for i in range(int(DURATION / step)):
        root, notes = progression[(i // 2) % len(progression)]
        base = i * step
        add_note(buf, base, step * 0.9, NOTE[root], amp=0.16, attack=0.01, release=0.8,
                 harmonics=(1.0, 0.5, 0.2, 0.08))
        note = notes[i % len(notes)]
        add_note(buf, base + step / 2, step * 0.8, NOTE[note], amp=0.11, attack=0.01, release=0.7,
                 harmonics=(1.0, 0.35, 0.12))
    # soft vinyl-ish air
    for i in range(0, int(DURATION * 4)):
        add_noise(buf, i * 0.25, 0.02, amp=0.004, decay=0.01)
    return normalize(buf, 0.66)


def pulse():
    buf = blank()
    beat = 0.5
    bass_notes = ["C3", "C3", "A3", "A3", "F3", "F3", "G3", "G3"]
    for i in range(int(DURATION / beat)):
        t = i * beat
        if i % 2 == 0:
            add_kick(buf, t, amp=0.5)
            add_noise(buf, t + 0.25, 0.05, amp=0.09, decay=0.03)
        else:
            add_noise(buf, t, 0.05, amp=0.06, decay=0.03)
        root = bass_notes[(i // 4) % len(bass_notes)]
        add_note(buf, t, beat * 0.85, NOTE[root], amp=0.13, attack=0.005, release=0.2,
                 harmonics=(1.0, 0.25, 0.08))
        if i % 4 == 2:
            add_note(buf, t, 0.4, NOTE["C5"], amp=0.05, attack=0.005, release=0.25, harmonics=(1.0, 0.2))
    return normalize(buf, 0.8)


def bloom():
    buf = blank()
    notes = ["C5", "E5", "G5", "E5", "D5", "G4", "B4", "D5"]
    step = 0.25
    for i in range(int(DURATION / step)):
        t = i * step
        note = notes[i % len(notes)]
        amp = 0.09 if i % 4 else 0.13
        add_note(buf, t, 0.45, NOTE[note], amp=amp, attack=0.005, release=0.3,
                 harmonics=(1.0, 0.3, 0.1))
        if i % 8 == 0:
            add_note(buf, t, 1.6, NOTE["C4"], amp=0.10, attack=0.05, release=0.9, harmonics=(1.0, 0.4, 0.2))
    # echo tail
    echo = [0.0] * len(buf)
    delay = int(0.375 * SR)
    for i in range(delay, len(buf)):
        echo[i] = buf[i] + echo[i - delay] * 0.28
    return normalize(echo, 0.72)


def main():
    tracks = {"drift": drift(), "hush": hush(), "pulse": pulse(), "bloom": bloom()}
    for name, buf in tracks.items():
        wav = write_wav(name, buf)
        m4a = os.path.join(OUT, name + ".m4a")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "128000", wav, m4a], check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        os.remove(wav)
        print(name, os.path.getsize(m4a), "bytes")


if __name__ == "__main__":
    main()
