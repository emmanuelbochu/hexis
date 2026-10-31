#!/usr/bin/env python3
"""Synthesizes the app sounds into Hexis/Resources/Sounds/*.caf (numpy + macOS afconvert).

One family: a soft "glass marimba" (modal synthesis: a few partials, the high ones dying first), all notes in D major,
mid register (D4 to A5, nothing shrill), rounded attacks, a low-pass, and a small stereo room. Loudness follows the
importance of the moment: the set tick is a whisper, the rest end and the record are clear above music.
Run: python3 Tools/sounds.py
"""
import os, subprocess, tempfile, wave

import numpy as np

RATE = 48_000
OUT = os.path.join(os.path.dirname(__file__), "..", "Hexis", "Resources", "Sounds")
rng = np.random.default_rng(7)  # fixed: the same sounds on every run

# D major, mid register.
D4, E4, Fs4, A4, B4, D5, E5, Fs5, A5 = 293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25, 739.99, 880.0


def t(dur):
    return np.arange(int(RATE * dur)) / RATE


def lowpass(x, cutoff):
    """One-pole low-pass applied twice (12 dB/oct): takes the edge off the highs."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def glass(freq, dur=0.9, decay=5.0, bright=0.35):
    """Glass marimba note: fundamental + soft partials (2, 3, 4.2) dying faster, two voices detuned by 2 cents."""
    x = t(dur)
    attack = np.minimum(x / 0.006, 1) ** 2  # rounded 6 ms attack: no click
    out = np.zeros_like(x)
    for ratio, level, speed in [(1, 1.0, 1.0), (2, bright, 2.2), (3, bright * 0.35, 3.5), (4.2, bright * 0.12, 5.0)]:
        for cents in (-2, 2):
            f = freq * ratio * 2 ** (cents / 1200)
            out += level * np.sin(2 * np.pi * f * x + rng.uniform(0, 6.28)) * np.exp(-decay * speed * x)
    return attack * out / 2


def tap(dur=0.05, cutoff=1800):
    """Soft felt tap: a breath of low-passed noise, the tactile part of a tick."""
    x = t(dur)
    noise = lowpass(rng.standard_normal(len(x)) * 0.3, cutoff)
    return noise * np.exp(-x * 90)


def place(parts, tail=0.6):
    """parts: (start seconds, samples, gain) → one mono buffer."""
    total = max(int(RATE * s) + len(x) for s, x, _ in parts) + int(RATE * tail)
    buf = np.zeros(total)
    for s, x, g in parts:
        o = int(RATE * s)
        buf[o:o + len(x)] += g * x
    return buf


def room(mono, wet=0.16, size=0.35):
    """Small stereo room: convolution with two decaying low-passed noise tails (left and right differ = width)."""
    n = int(RATE * size * 3)
    x = np.arange(n) / RATE
    channels = []
    for _ in range(2):
        ir = lowpass(rng.standard_normal(n), 3200) * np.exp(-x / size)
        ir[: int(RATE * 0.012)] = 0  # pre-delay
        ir /= np.sqrt(np.sum(ir ** 2))
        reverb = np.convolve(mono, ir)[: len(mono)]
        channels.append((1 - wet) * mono + wet * reverb)
    return np.stack(channels, axis=1)


def finish(stereo, peak_db, cutoff=5200):
    """Low-pass, fade the tail, set the loudness by peak."""
    stereo = np.stack([lowpass(stereo[:, c], cutoff) for c in range(2)], axis=1)
    fade = int(RATE * 0.08)
    stereo[-fade:] *= np.linspace(1, 0, fade)[:, None]
    stereo /= np.max(np.abs(stereo)) or 1
    return stereo * 10 ** (peak_db / 20)


def save(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE)
            w.writeframes((np.clip(stereo, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", path, os.path.join(OUT, name + ".caf")], check=True)
    print(f"{name}: {len(stereo) / RATE:.2f} s")


def sound(name, parts, peak_db, tail=0.5, wet=0.16, cutoff=5200):
    save(name, finish(room(place(parts, tail), wet), peak_db, cutoff))


# Set checked: a whisper. Felt tap + a short low note, almost no room.
sound("set_done", [(0, tap(cutoff=1200), 0.8), (0.004, glass(Fs4, 0.25, decay=16, bright=0.2), 0.6)], -16, tail=0.1, wet=0.08, cutoff=4000)
# Exercise finished (all its sets): two quick rising notes, a fifth.
sound("exercise_done", [(0, tap(), 0.5), (0, glass(D5, 0.4, decay=11), 0.7), (0.09, glass(A5, 0.5, decay=9, bright=0.25), 0.6)], -12, tail=0.25)
# Rest over: three soft rising glass notes, clear above music without being sharp.
sound("rest_end", [(0, glass(D5, 0.8, decay=5), 0.8), (0.13, glass(Fs5, 0.8, decay=5), 0.75), (0.26, glass(A5, 1.1, decay=3.6, bright=0.3), 0.8)], -6)
# Session starting: a low fifth that opens, slow and calm.
sound("session_start", [(0, glass(D4, 1.2, decay=3, bright=0.25), 0.8), (0.07, glass(A4, 1.2, decay=3, bright=0.25), 0.6), (0.14, glass(D5, 1.2, decay=3.2, bright=0.2), 0.45)], -9, tail=0.7, wet=0.22)
# Session over: the full chord rolled upward, warm and resolved.
sound("session_end", [(0.00, glass(D4, 1.6, decay=2.6), 0.7), (0.08, glass(Fs4, 1.6, decay=2.6), 0.55), (0.16, glass(A4, 1.6, decay=2.6), 0.55),
                      (0.24, glass(D5, 1.8, decay=2.2, bright=0.3), 0.6)], -7, tail=0.9, wet=0.24)
# Record: the chord climbing higher, with a sparkle on top (the brightest sound of the app, still under A5 + partials).
sound("record", [(0.00, glass(D5, 1.0, decay=4), 0.6), (0.08, glass(Fs5, 1.0, decay=4), 0.6), (0.16, glass(A5, 1.0, decay=4), 0.6),
                 (0.30, glass(D5 * 2, 1.4, decay=3, bright=0.15), 0.4), (0.30, glass(A4, 1.6, decay=2.4), 0.5)], -6, tail=0.9, wet=0.26, cutoff=6500)
# Meal eaten: a round bubble, two close notes.
sound("meal_done", [(0, glass(B4, 0.35, decay=12, bright=0.2), 0.7), (0.06, glass(E5, 0.45, decay=10, bright=0.2), 0.6)], -13, tail=0.2)
