#!/usr/bin/env python3
"""Synthesize every sound effect and the ambient music loop into assets/audio/*.wav.

Everything is generated from simple additive synthesis so the project ships with no
third-party audio. Requires numpy.   Usage: python3 tools/generate_audio.py
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(3)


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
             "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.005, decay=0.4):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def bell(freq, dur=1.2, decay=0.35, bright=0.35):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * freq * t)
    s += bright * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / (decay * 0.5))
    s += bright * 0.5 * np.sin(2 * np.pi * freq * 3.98 * t) * np.exp(-t / (decay * 0.25))
    return s * env(dur, 0.004, decay)


def marimba(freq, dur=0.7):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.28)
    s += 0.45 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / 0.05)
    s += 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / 0.015)
    a = np.clip(t / 0.003, 0, 1)
    return s * a


def reverb(x, size=1.4, mix=0.25):
    n = int(SR * size)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / (size / 5))
    # soften the tail
    ir = np.convolve(ir, np.ones(8) / 8, mode="same")
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(x) + n
    nfft = 1 << (L - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:L]
    dry = np.concatenate([x, np.zeros(n)])
    return dry + mix * wet


def place(buf, sig, at):
    i = int(at * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def trim(x, thresh=1e-4):
    idx = np.where(np.abs(x) > thresh)[0]
    return x[: idx[-1] + 1] if len(idx) else x


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = trim(x)
    fade = min(len(x), int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote", name, f"{len(x) / SR:.2f}s")


def main():
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6"]
    for i, n in enumerate(scale):
        save(f"select_{i}", reverb(marimba(note(n)), 0.8, 0.18), 0.55)

    buf = np.zeros(int(SR * 1.6))
    for i, n in enumerate(["G5", "C6", "E6", "G6"]):
        place(buf, bell(note(n), 1.2, 0.4), i * 0.07)
    save("word_found", reverb(buf, 1.2, 0.3), 0.7)

    buf = np.zeros(int(SR * 1.4))
    for i in range(9):
        f = note(rng.choice(["C7", "D7", "E7", "G7", "A7", "C8"]))
        place(buf, bell(f, 0.6, 0.12, 0.2) * (1 - i / 12), i * 0.045)
    save("bonus_word", reverb(buf, 1.0, 0.35), 0.5)

    t = t_axis(0.35)
    wrong = (np.sin(2 * np.pi * 180 * t) + 0.5 * np.sin(2 * np.pi * 135 * t)) * env(0.35, 0.005, 0.09)
    save("wrong", reverb(wrong, 0.5, 0.12), 0.55)

    buf = np.zeros(int(SR * 0.5))
    place(buf, marimba(note("E5"), 0.3), 0.0)
    place(buf, marimba(note("E5"), 0.3), 0.11)
    save("already_found", buf, 0.45)

    t = t_axis(0.9)
    f = 600 + 1400 * t / 0.9
    phase = 2 * np.pi * np.cumsum(f) / SR
    shimmer = np.sin(phase) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t)) * env(0.9, 0.05, 0.4)
    save("hint", reverb(shimmer, 1.0, 0.4), 0.45)

    buf = np.zeros(int(SR * 0.6))
    place(buf, bell(note("B6"), 0.2, 0.05, 0.6), 0.0)
    place(buf, bell(note("E7"), 0.5, 0.15, 0.6), 0.07)
    save("coin", reverb(buf, 0.6, 0.15), 0.4)

    buf = np.zeros(int(SR * 3.2))
    for i, n in enumerate(["C5", "E5", "G5", "B5", "D6", "E6", "G6", "C7"]):
        place(buf, bell(note(n), 2.4, 0.9, 0.25), i * 0.09)
    for n in ["C4", "G4", "E5"]:
        place(buf, bell(note(n), 3.0, 1.2, 0.1) * 0.6, 0.7)
    save("level_complete", reverb(buf, 2.0, 0.35), 0.7)

    buf = np.zeros(int(SR * 4.0))
    seq = ["C5", "E5", "G5", "C6", "D5", "F5", "A5", "D6", "E5", "G5", "C6", "E6"]
    for i, n in enumerate(seq):
        place(buf, bell(note(n), 1.0, 0.4, 0.3) * 0.7, i * 0.08)
    for n in ["C4", "G4", "C5", "E5", "G5", "C6"]:
        place(buf, bell(note(n), 3.0, 1.4, 0.15) * 0.6, 1.0)
    save("chapter_complete", reverb(buf, 2.4, 0.35), 0.75)

    t = t_axis(0.06)
    click = np.sin(2 * np.pi * 1200 * t) * env(0.06, 0.001, 0.012)
    save("click", click, 0.35)

    t = t_axis(0.45)
    noise = rng.standard_normal(len(t))
    k = np.ones(30) / 30
    noise = np.convolve(noise, k, mode="same") - np.convolve(noise, np.ones(4) / 4, mode="same") * 0.2
    whoosh = noise * np.sin(np.pi * t / 0.45) ** 2
    save("shuffle", whoosh, 0.35)

    music()


def pad_voice(freq, dur, attack, release):
    t = t_axis(dur)
    s = np.zeros_like(t)
    for detune in (-0.12, 0.0, 0.11):
        f = freq * 2 ** (detune / 12)
        s += np.sin(2 * np.pi * f * t + rng.random() * 6.28)
        s += 0.18 * np.sin(2 * np.pi * 2 * f * t)
    e = np.minimum(np.clip(t / attack, 0, 1), np.clip((dur - t) / release, 0, 1))
    return s * e * (0.85 + 0.15 * np.sin(2 * np.pi * 0.17 * t))


def music():
    chords = [["C3", "G3", "B3", "E4"], ["A2", "E3", "G3", "C4"],
              ["F2", "C3", "E3", "A3"], ["G2", "D3", "A3", "B3"]]
    bar = 8.0
    total = bar * len(chords)
    buf = np.zeros(int(SR * (total + 6)))
    for i, ch in enumerate(chords):
        for n in ch:
            place(buf, pad_voice(note(n), bar + 3.0, 2.5, 3.0) * 0.16, i * bar)
    penta = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    tm = 0.6
    while tm < total - 0.5:
        f = note(rng.choice(penta))
        place(buf, bell(f, 3.0, 1.1, 0.15) * (0.10 + 0.08 * rng.random()), tm)
        tm += rng.choice([1.0, 1.5, 2.0, 2.0, 3.0])
    buf = reverb(buf, 3.0, 0.5)
    # Fold the tail back onto the start so the loop is seamless.
    n = int(SR * total)
    loop = buf[:n].copy()
    tail = buf[n:]
    loop[: len(tail)] += tail[: n]
    data = loop / np.max(np.abs(loop)) * 0.6
    # Music at 22.05 kHz keeps the file small.
    data = data[::2]
    pcm = (data * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, "music_zen.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR // 2)
        w.writeframes(pcm)
    print("wrote music_zen", total, "s")


if __name__ == "__main__":
    main()
