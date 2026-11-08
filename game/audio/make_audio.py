#!/usr/bin/env python3
"""Synthesize every sound in Gunship Ace. No samples, no third-party audio.

Run: python3 game/audio/make_audio.py   (writes .wav files next to this script)
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
TAU = math.tau


def write(name, samples, rate=RATE):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.89 / peak if peak > 0.89 else 1.0
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print(name, "%.2fs" % (len(samples) / rate))


def n(sec):
    return int(sec * RATE)


class Noise:
    def __init__(self, seed):
        self.r = random.Random(seed)

    def __call__(self):
        return self.r.uniform(-1.0, 1.0)


def lowpass(samples, cutoff):
    out = []
    y = 0.0
    if callable(cutoff):
        for i, x in enumerate(samples):
            a = 1.0 - math.exp(-TAU * cutoff(i) / RATE)
            y += a * (x - y)
            out.append(y)
        return out
    a = 1.0 - math.exp(-TAU * cutoff / RATE)
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def env(i, total, attack=0.005, curve=4.0):
    t = i / RATE
    if t < attack:
        return t / attack
    return math.exp(-curve * (i / max(1, total)))


def mix(*tracks):
    size = max(len(t) for t in tracks)
    out = [0.0] * size
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


# ---------------------------------------------------------------- effects

def rotor():
    # One second, seven blade slaps, a low drone and a quiet turbine whine.
    total = n(1.0)
    noise = Noise(1)
    raw = [noise() for _ in range(total)]
    body = lowpass(raw, 260.0)
    out = []
    for i in range(total):
        t = i / RATE
        ph = (t * 7.0) % 1.0
        slap = math.exp(-ph * 9.0)
        drone = math.sin(TAU * 49.0 * t) * 0.25 + math.sin(TAU * 98.0 * t) * 0.1
        whine = math.sin(TAU * 1400.0 * t) * 0.025
        out.append(body[i] * (0.35 + slap * 2.4) + drone * (0.6 + slap * 0.4) + whine)
    # Make the loop seam match: crossfade the first 400 samples with the tail.
    fade = 400
    for i in range(fade):
        a = i / fade
        out[i] = out[i] * a + out[total - fade + i] * (1.0 - a)
    return out[: total - fade]


def gun():
    total = n(0.11)
    noise = Noise(2)
    raw = [noise() for _ in range(total)]
    crack = lowpass(raw, 3200.0)
    out = []
    for i in range(total):
        t = i / RATE
        thump = math.sin(TAU * (140.0 - t * 600.0) * t) * math.exp(-t * 40.0)
        out.append(crack[i] * math.exp(-t * 45.0) * 0.9 + thump * 0.8)
    return out


def enemy_gun():
    total = n(0.09)
    noise = Noise(3)
    raw = lowpass([noise() for _ in range(total)], 2400.0)
    return [raw[i] * math.exp(-(i / RATE) * 55.0) * 0.6 for i in range(total)]


def whoosh(sec, f0, f1, seed, tone=0.0):
    total = n(sec)
    noise = Noise(seed)
    raw = [noise() for _ in range(total)]
    swept = lowpass(raw, lambda i: f0 + (f1 - f0) * (i / total))
    swept = highpass(swept, 180.0)
    out = []
    ph = 0.0
    for i in range(total):
        t = i / total
        e = min(1.0, (i / RATE) / 0.02) * (1.0 - t) ** 1.4
        ph += TAU * (300.0 + 500.0 * t) / RATE
        out.append(swept[i] * e * 1.6 + math.sin(ph) * tone * e)
    return out


def boom(sec, cutoff, seed):
    total = n(sec)
    noise = Noise(seed)
    raw = [noise() for _ in range(total)]
    low = lowpass(lowpass(raw, cutoff), cutoff * 1.4)
    out = []
    for i in range(total):
        t = i / RATE
        e = min(1.0, t / 0.004) * math.exp(-t * (3.2 / sec))
        sub = math.sin(TAU * (55.0 - t * 20.0) * t) * math.exp(-t * 6.0)
        crackle = 1.0 + 0.6 * math.sin(TAU * 13.0 * t) * math.exp(-t * 4.0)
        out.append(low[i] * 3.2 * e * crackle + sub * 0.7)
    return out


def clank():
    total = n(0.35)
    noise = Noise(5)
    out = []
    parts = ((523.0, 1.0), (1187.0, 0.6), (1931.0, 0.4), (2873.0, 0.25))
    for i in range(total):
        t = i / RATE
        v = sum(math.sin(TAU * f * t) * a for f, a in parts) * math.exp(-t * 16.0)
        v += noise() * math.exp(-t * 60.0) * 0.8
        out.append(v * 0.5)
    return out


def crunch():
    total = n(0.45)
    noise = Noise(6)
    raw = lowpass([noise() for _ in range(total)], 900.0)
    out = []
    for i in range(total):
        t = i / RATE
        grit = 1.0 if (i // 220) % 3 else 0.4
        out.append(raw[i] * 3.0 * grit * math.exp(-t * 7.0) + math.sin(TAU * 80.0 * t) * math.exp(-t * 12.0) * 0.6)
    return out


def tone(freq, sec, shape="square", vol=0.4, decay=6.0):
    total = n(sec)
    out = []
    for i in range(total):
        t = i / RATE
        ph = (freq * t) % 1.0
        if shape == "square":
            v = 1.0 if ph < 0.5 else -1.0
        elif shape == "tri":
            v = 4.0 * abs(ph - 0.5) - 1.0
        else:
            v = math.sin(TAU * ph)
        out.append(v * vol * min(1.0, t / 0.004) * math.exp(-t * decay))
    return out


def seq(notes, gap, shape="square", vol=0.35, decay=7.0, tail=0.3):
    total = n(gap * len(notes) + tail)
    out = [0.0] * total
    for k, f in enumerate(notes):
        if f is None:
            continue
        t = tone(f, gap + tail, shape, vol, decay)
        start = n(gap * k)
        for i, v in enumerate(t):
            if start + i < total:
                out[start + i] += v
    return lowpass(out, 5000.0)


def warn():
    a = tone(1320.0, 0.09, "square", 0.3, 2.0)
    return a + [0.0] * n(0.04) + tone(1320.0, 0.09, "square", 0.3, 2.0)


def winch():
    total = n(0.6)
    out = []
    for i in range(total):
        t = i / RATE
        f = 180.0 + t * 260.0
        v = (1.0 if (f * t) % 1.0 < 0.3 else -0.3) * 0.25
        out.append(v * (1.0 - t / 0.6))
    return lowpass(out, 1800.0)


# ---------------------------------------------------------------- music

A_MINOR = {"A2": 110.0, "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0,
           "A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
           "G4": 392.0, "A4": 440.0, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
           "F2": 87.31, "G2": 98.0, "E2": 82.41, "D2": 73.42, "C2": 65.41}


def render_voice(total, events, shape, vol, decay, cutoff):
    out = [0.0] * total
    for start, length, freq in events:
        s0 = n(start)
        cnt = n(length)
        ph = 0.0
        for i in range(cnt):
            if s0 + i >= total:
                break
            t = i / RATE
            ph += freq / RATE
            p = ph % 1.0
            if shape == "square":
                v = 1.0 if p < 0.5 else -1.0
            elif shape == "pulse":
                v = 1.0 if p < 0.25 else -1.0
            elif shape == "saw":
                v = 2.0 * p - 1.0
            elif shape == "tri":
                v = 4.0 * abs(p - 0.5) - 1.0
            else:
                v = math.sin(TAU * p)
            e = min(1.0, t / 0.006) * math.exp(-t * decay)
            rel = min(1.0, (cnt - i) / (RATE * 0.02))
            out[s0 + i] += v * vol * e * rel
    return lowpass(out, cutoff)


def drums(total, beat, bars, pattern_kick, pattern_snare, hat_vol, seed):
    out = [0.0] * total
    noise = Noise(seed)
    step = beat / 4.0
    steps = bars * 16
    for k in range(steps):
        s0 = n(k * step)
        pos = k % 16
        if pos in pattern_kick:
            for i in range(n(0.25)):
                if s0 + i >= total:
                    break
                t = i / RATE
                out[s0 + i] += math.sin(TAU * (110.0 * math.exp(-t * 18.0) + 42.0) * t) * math.exp(-t * 11.0) * 0.9
        if pos in pattern_snare:
            for i in range(n(0.18)):
                if s0 + i >= total:
                    break
                t = i / RATE
                out[s0 + i] += (noise() * 0.55 + math.sin(TAU * 190.0 * t) * 0.3) * math.exp(-t * 20.0)
        if hat_vol > 0.0:
            for i in range(n(0.04)):
                if s0 + i >= total:
                    break
                t = i / RATE
                out[s0 + i] += noise() * hat_vol * math.exp(-t * 90.0) * (1.0 if pos % 2 == 0 else 0.5)
    return out


def mission_music():
    bpm = 132.0
    beat = 60.0 / bpm
    bars = 16
    total = n(beat * 4 * bars)
    roots = ["A2", "A2", "F2", "G2", "A2", "A2", "C3", "E2"] * 2
    bass = []
    for bar, root in enumerate(roots):
        f = A_MINOR[root]
        for k in range(8):
            octave = 2.0 if k in (3, 6) else 1.0
            bass.append((bar * 4 * beat + k * beat / 2.0, beat / 2.0 * 0.9, f * octave))
    lead_line = [
        "E4", None, "A4", None, "G4", "E4", None, "D4",
        "E4", None, None, "C4", "D4", None, "E4", None,
        "F4", None, "E4", None, "D4", "C4", None, "D4",
        "E4", None, "G4", None, "E4", None, None, None,
    ]
    lead = []
    for bar in range(8, 16):
        for k in range(8):
            note = lead_line[((bar - 8) * 8 + k) % len(lead_line)]
            if note:
                lead.append((bar * 4 * beat + k * beat / 2.0, beat * 0.9, A_MINOR[note]))
    arp = []
    chord = {"A2": ("A3", "C4", "E4"), "F2": ("F3", "A3", "C4"), "G2": ("G3", "B3", "D4"),
             "C3": ("C4", "E4", "G4"), "E2": ("E3", "G3", "B3")}
    for bar, root in enumerate(roots):
        if bar < 4:
            continue
        notes = chord[root]
        for k in range(16):
            arp.append((bar * 4 * beat + k * beat / 4.0, beat / 4.0 * 0.8, A_MINOR[notes[k % 3]] * 2.0))
    v_bass = render_voice(total, bass, "saw", 0.32, 3.0, 700.0)
    v_lead = render_voice(total, lead, "pulse", 0.16, 1.2, 3200.0)
    v_arp = render_voice(total, arp, "tri", 0.09, 9.0, 4000.0)
    v_drum = drums(total, beat, bars, (0, 6, 8, 11), (4, 12), 0.12, 11)
    return mix(v_bass, v_lead, v_arp, v_drum)


def title_music():
    bpm = 84.0
    beat = 60.0 / bpm
    bars = 8
    total = n(beat * 4 * bars)
    pads = []
    prog = [("A3", "C4", "E4"), ("F3", "A3", "C4"), ("G3", "B3", "D4"), ("E3", "G3", "B3")] * 2
    for bar, notes in enumerate(prog):
        for note in notes:
            pads.append((bar * 4 * beat, beat * 4 * 0.98, A_MINOR[note]))
    melody = ["E5", "D5", "C5", "B4", "C5", None, "A4", None]
    mel = []
    for bar in range(4, 8):
        for k in range(2):
            note = melody[((bar - 4) * 2 + k) % len(melody)]
            if note:
                mel.append((bar * 4 * beat + k * beat * 2.0, beat * 1.9, A_MINOR[note]))
    v_pad = render_voice(total, pads, "saw", 0.08, 0.35, 900.0)
    v_bass = render_voice(total, [(b * 4 * beat, beat * 3.8, A_MINOR[p[0]] / 2.0) for b, p in enumerate(prog)], "tri", 0.3, 0.4, 500.0)
    v_mel = render_voice(total, mel, "sine", 0.18, 0.7, 3000.0)
    v_drum = drums(total, beat, bars, (0, 10), (8,), 0.0, 12)
    return mix(v_pad, v_bass, v_mel, [d * 0.6 for d in v_drum])


def main():
    write("rotor.wav", rotor())
    write("gun.wav", gun())
    write("enemy_gun.wav", enemy_gun())
    write("rocket.wav", whoosh(0.55, 4200.0, 700.0, 7))
    write("atgm.wav", whoosh(0.8, 2600.0, 900.0, 8, tone=0.15))
    write("sam.wav", whoosh(1.1, 800.0, 3800.0, 9, tone=0.1))
    write("boom.wav", boom(1.3, 420.0, 10))
    write("boom_small.wav", boom(0.5, 900.0, 13))
    write("hit.wav", clank())
    write("flip.wav", crunch())
    write("warn.wav", warn())
    write("winch.wav", winch())
    write("pickup.wav", seq([660.0, 880.0, 1320.0], 0.06, "square", 0.3, 9.0))
    write("rescue.wav", seq([523.25, 783.99], 0.12, "tri", 0.5, 4.0))
    write("objective.wav", seq([523.25, 659.25, 783.99, 1046.5], 0.11, "square", 0.3, 4.0, 0.5))
    write("fail.wav", seq([392.0, 329.63, 261.63, 196.0], 0.18, "tri", 0.5, 3.0, 0.5))
    write("click.wav", tone(1800.0, 0.03, "square", 0.2, 60.0))
    write("music_mission.wav", mission_music())
    write("music_title.wav", title_music())


if __name__ == "__main__":
    main()
