# Procedural SFX kit for Swan Lake XR — pure numpy, writes 16-bit mono WAVs.
# Run: python3 make_sfx.py
import numpy as np, wave, os

SR = 22050
OUT = "/Users/alex/dev/swan-lake-xr/project/assets/sfx"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def save(name, x, sr=SR):
    x = np.clip(x / (np.max(np.abs(x)) + 1e-9) * 0.85, -1, 1)
    w = wave.open(f"{OUT}/{name}.wav", "wb")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes((x * 32767).astype(np.int16).tobytes()); w.close()
    print("wrote", name, len(x) / sr, "s")

def env(n, a, d):  # attack/decay exp envelope
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-np.maximum(t - a, 0) / d)
    return e

def lowpass(x, alpha):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc); y[i] = acc
    return y

# --- water plops (4 variants): sine pitch-drop + bubble resonance ---
chord = [123.47, 146.83, 185.0, 246.94]  # B2 D3 F#3 B3
for i, f1 in enumerate(chord):
    n = int(SR * 0.30); t = np.arange(n) / SR
    f = f1 * 2.6 * np.exp(-t * 16) + f1          # quick drop onto the chord tone
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env(n, 0.003, 0.07)
    octv = np.sin(2 * np.pi * f1 * 2.0 * t) * env(n, 0.01, 0.05) * 0.3
    click = rng.normal(0, 1, n) * env(n, 0.001, 0.004) * 0.18
    save(f"plop_{i+1}", lowpass(body + octv + click, 0.35))

# --- splash (fish / landing) ---
n = int(SR * 0.6); t = np.arange(n) / SR
noise = rng.normal(0, 1, n)
sweep = lowpass(noise, 0.5) * env(n, 0.006, 0.16)
spray = lowpass(rng.normal(0, 1, n), 0.85) * env(n, 0.05, 0.28) * 0.5
save("splash", sweep + spray)

# --- pentatonic chimes (constellation notes + hatch chord), soft FM bells ---
freqs = [246.94, 293.66, 329.63, 369.99, 440.0, 493.88, 587.33]  # B3 D4 E4 F#4 A4 B4 D5 (B minor pent.)
for i, f in enumerate(freqs):
    n = int(SR * 1.4); t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 3.01 * t) * 2.2 * np.exp(-t * 3)
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 2.6)
    x += np.sin(2 * np.pi * f * 2.004 * t) * np.exp(-t * 4.5) * 0.35
    save(f"chime_{i+1}", x)

# hatch chord = 1+3+5 pentatonic stack
n = int(SR * 2.2); t = np.arange(n) / SR
x = np.zeros(n)
for f, g in [(246.94, 1.0), (293.66, 0.8), (369.99, 0.7), (493.88, 0.5)]:
    x += np.sin(2 * np.pi * f * t + 1.8 * np.sin(2 * np.pi * f * 3.02 * t) * np.exp(-t * 2.5)) * np.exp(-t * 1.7) * g
save("hatch_chord", x)

# --- firework: whoosh (launch) + crackle (burst) ---
n = int(SR * 0.7); t = np.arange(n) / SR
noise = rng.normal(0, 1, n)
f_c = 300 + 2400 * (t / t[-1]) ** 1.6
carrier = np.sin(2 * np.pi * np.cumsum(f_c) / SR)
save("whoosh", lowpass(noise, 0.25) * carrier * env(n, 0.05, 0.4))

n = int(SR * 1.3); x = np.zeros(n)
boom = np.sin(2 * np.pi * 55 * np.arange(int(SR*0.5)) / SR) * env(int(SR*0.5), 0.002, 0.12)
x[:len(boom)] += boom * 1.2
for _ in range(90):
    p = int(rng.uniform(0.03, 1.0) * (n - 400))
    ln = int(rng.uniform(0.004, 0.02) * SR)
    pop = rng.normal(0, 1, ln) * np.exp(-np.arange(ln) / (0.003 * SR)) * rng.uniform(0.2, 1.0) * np.exp(-p / (0.45 * SR * 1.0))
    x[p:p+ln] += pop
save("crackle", lowpass(x, 0.6))

# --- loopable weather beds (crossfade tail into head for seamless loop) ---
def loopify(x, fade=0.4):
    nf = int(SR * fade)
    x[:nf] = x[:nf] * np.linspace(0, 1, nf) + x[-nf:] * np.linspace(1, 0, nf)
    return x[:-nf]

n = int(SR * 5.0); t = np.arange(n) / SR
wind = lowpass(rng.normal(0, 1, n), 0.06) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.13 * t + 1))
save("wind_loop", loopify(wind))

n = int(SR * 4.0)
rain = lowpass(rng.normal(0, 1, n), 0.55) * 0.5
ticks = np.zeros(n)
for _ in range(900):
    p = rng.integers(0, n - 60); ln = rng.integers(15, 60)
    ticks[p:p+ln] += rng.normal(0, 1, ln) * np.exp(-np.arange(ln) / 8.0) * rng.uniform(0.1, 0.5)
save("rain_loop", loopify(rain + lowpass(ticks, 0.8)))
print("SFX_DONE")
