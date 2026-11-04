#!/usr/bin/env python3
"""The Prelude: a tuning A, then the Swan Lake theme on a synthesized harp and oboe.

Tchaikovsky's score is public domain and this performance is generated here, so nothing in it comes
from any recording. Output: assets_src/downloads/prelude.wav, which tools/make_program_audio.py cuts to MP3.
Written to be in tune against B minor, the key of the Scene later in the program. No one has heard
this on a headset, or at all: it was checked by pitch analysis only."""
import numpy as np, pathlib, subprocess, sys, wave
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets_src" / "downloads"
SR = 44100
NOTE = {n: i for i, n in enumerate("C C# D D# E F F# G G# A A# B".split())}
def hz(name):
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + 12 * (o + 1) - 69) / 12)

def pluck(f, dur, amp=0.5):
    """Karplus-Strong with a fractional delay, DC blocked, so it stays in tune low down."""
    n = int(dur * SR)
    period = SR / f
    d = int(period - 0.5)
    frac = period - 0.5 - d
    rng = np.random.default_rng(int(f * 10))
    buf = rng.uniform(-1, 1, d + 2)
    buf = np.convolve(buf, np.ones(4) / 4, mode="same")
    buf -= buf.mean()
    out = np.zeros(n)
    decay = 0.9965 if f < 300 else 0.9945
    line = list(buf)
    i = 0
    L = len(line)
    last = 0.0
    for k in range(n):
        a = line[i % L]
        b = line[(i + 1) % L]
        s = (1 - frac) * a + frac * b
        new = decay * (0.5 * s + 0.5 * last)
        last = s
        out[k] = a
        line[i % L] = new
        i = i + 1
    # gentle body: remove DC accumulated, soft attack click
    out = out - np.convolve(out, np.ones(2048) / 2048, mode="same")
    env = np.minimum(np.arange(n) / (0.002 * SR), 1.0)
    return out * env * amp

def oboe(f, dur, amp=0.32):
    """Additive reed: strong odd-ish upper partials, slow vibrato, breath and swell."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib_on = np.clip((t - 0.25) / 0.5, 0.0, 1.0)
    vib = 1.0 + 0.0042 * vib_on * np.sin(2 * np.pi * 5.2 * t + 0.4)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    partials = [1.0, 0.85, 0.72, 0.42, 0.30, 0.22, 0.13, 0.08, 0.05]
    s = sum(a * np.sin((i + 1) * ph + i * 0.7) for i, a in enumerate(partials) if (i + 1) * f < 9000)
    # Formant emphasis around 1.2 kHz, the oboe's nasal color: a one-pole shelf is enough here.
    env = np.minimum(t / 0.07, 1.0) * np.minimum((dur - t) / 0.09, 1.0)
    swell = 0.82 + 0.18 * np.sin(np.pi * np.clip(t / dur, 0, 1))
    rng = np.random.default_rng(int(f))
    breath = rng.normal(0, 0.012, n)
    breath = np.convolve(breath, np.ones(6) / 6, mode="same")
    return (s / 2.4 + breath) * env * swell * amp

def place(buf, sig, at):
    i = int(at * SR)
    j = min(i + len(sig), len(buf))
    buf[i:j] += sig[: j - i]

beat = 60.0 / 66.0  # quarter note
TUNE = 6.5
total = TUNE + beat * 4 * 12 + 4.0
harp = np.zeros(int(total * SR))
wind = np.zeros(int(total * SR))
# The oboe gives the tuning A, as it does in a pit.
place(wind, oboe(hz("A4"), 4.6, 0.26), 0.6)
# Theme: (note, beats). Opening of the Scene, then its answer.
THEME = [("F#4", 3), ("B3", 0.5), ("C#4", 0.5), ("D4", 0.5), ("E4", 0.5),
         ("F#4", 1.5), ("D4", 0.5), ("F#4", 1.5), ("D4", 0.5),
         ("F#4", 1.5), ("B3", 0.5), ("D4", 0.5), ("B3", 0.5), ("G3", 0.5), ("D4", 0.5),
         ("B3", 4),
         ("C#4", 0.5), ("D4", 0.5), ("E4", 0.5), ("F#4", 0.5), ("G4", 1.5), ("F#4", 0.5),
         ("E4", 1.5), ("D4", 0.5), ("C#4", 2),
         ("F#4", 3), ("B3", 0.5), ("C#4", 0.5), ("D4", 0.5), ("E4", 0.5),
         ("F#4", 1.5), ("D4", 0.5), ("F#4", 1.5), ("D4", 0.5),
         ("F#4", 1.5), ("B3", 0.5), ("D4", 0.5), ("B3", 0.5), ("G3", 0.5), ("D4", 0.5),
         ("B3", 4)]
t0 = TUNE + beat * 4
t = t0
for n, b in THEME:
    place(wind, oboe(hz(n), b * beat * 1.02, 0.24), t)
    t += b * beat
end_theme = t
# Harp: the rippling arpeggio underneath, in eighths. Chords by bar.
CHORDS = [["B2", "F#3", "B3", "D4", "F#4"], ["B2", "F#3", "B3", "D4", "F#4"], ["G2", "D3", "G3", "B3", "D4"], ["B2", "F#3", "B3", "D4", "F#4"],
          ["E3", "G3", "B3", "E4", "G4"], ["F#2", "C#3", "A#3", "C#4", "F#4"],
          ["B2", "F#3", "B3", "D4", "F#4"], ["B2", "F#3", "B3", "D4", "F#4"], ["G2", "D3", "G3", "B3", "D4"], ["B2", "F#3", "B3", "D4", "F#4"], ["B2", "F#3", "B3", "D4", "F#4"]]
t = TUNE
bar = 0
cache = {}
while t < end_theme - 0.01:
    c = CHORDS[min(bar, len(CHORDS) - 1)]
    pat = [0, 1, 2, 3, 4, 3, 2, 1]
    for k, i in enumerate(pat):
        nm = c[i]
        if nm not in cache:
            cache[nm] = pluck(hz(nm), 3.0, 0.5)
        place(harp, cache[nm] * (0.85 if k else 1.0), t + k * beat * 0.5)
    t += beat * 4
    bar += 1
place(harp, pluck(hz("B2"), 3.5, 0.6) + pluck(hz("B3"), 3.5, 0.45), end_theme)
total_used = end_theme + 3.5
mono = (wind + harp * 0.42)[: int(total_used * SR)]
# Reverb: exponentially decaying filtered noise, stereo. The lake at night, not a concert hall.
rng = np.random.default_rng(5)
ir_n = int(2.6 * SR)
env = np.exp(-np.arange(ir_n) / (0.7 * SR))
def conv(x, ir):
    n = len(x) + len(ir)
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x)]
irL = rng.normal(0, 1, ir_n) * env
irR = rng.normal(0, 1, ir_n) * env
irL = np.convolve(irL, np.ones(5) / 5, mode="same")
irR = np.convolve(irR, np.ones(5) / 5, mode="same")
L = mono + 0.022 * conv(mono, irL)
R = mono + 0.022 * conv(mono, irR)
st = np.stack([L, R], axis=1)
st = st / (np.abs(st).max() + 1e-6) * 0.9
fade = int(1.5 * SR)
st[-fade:] *= np.linspace(1, 0, fade)[:, None]
OUT.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT / "prelude.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((st * 32767).astype(np.int16).tobytes())
print("prelude seconds", round(len(st) / SR, 1))
