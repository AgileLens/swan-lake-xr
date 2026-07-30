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

# --- harp plucks (fish leaps) ---
# The fish previously used the water plop + a noise splash, which Alex heard in
# the headset as "a video game" cutting across the orchestra. A plucked string in
# the score's key reads as part of the music instead of an effect on top of it.
# Karplus-Strong: excite a delay line of length SR/f, then low-pass its feedback —
# that decay-brightness-over-time is what makes a pluck sound like a real string
# rather than a filtered sine.
def measure_f0(x, sr=SR, lo=80.0, hi=1400.0):
    """Autocorrelation pitch. A plucked string's 2nd partial is often louder than
    its fundamental, so an FFT peak reports the octave above and looks like a
    tuning error that isn't there."""
    seg = x[int(sr * 0.05) : int(sr * 0.55)]
    seg = seg - seg.mean()
    ac = np.correlate(seg, seg, mode="full")[len(seg) - 1 :]
    lag_lo, lag_hi = int(sr / hi), min(int(sr / lo), len(ac) - 1)
    lag = lag_lo + int(np.argmax(ac[lag_lo:lag_hi]))
    # parabolic interpolation around the peak for sub-sample precision
    if 0 < lag < len(ac) - 1:
        y0, y1, y2 = ac[lag - 1], ac[lag], ac[lag + 1]
        denom = 2 * (y0 - 2 * y1 + y2)
        if denom != 0:
            lag += -(y2 - y0) / denom
    return sr / lag


def harp_raw(f, dur, damp, bright):
    n = int(SR * dur)
    # The loop's 2-tap average adds ~half a sample of delay on top of the line.
    ln = max(2, int(round(SR / f - 0.5)))
    # noise burst shaped toward the high end = pick attack; less noise = softer touch
    buf = rng.normal(0, 1, ln)
    buf = buf * bright + lowpass(buf, 0.25) * (1.0 - bright)
    # The loop's averaging filter has unity gain at DC, so any offset in the
    # excitation survives every pass and accumulates — on the low notes (long
    # delay line) it grew large enough to bury the fundamental entirely.
    buf -= buf.mean()
    buf /= np.max(np.abs(buf)) + 1e-9
    y = np.zeros(n)
    # one-pole averaging in the loop; damp sets how fast highs are lost
    a = 0.5 + 0.5 * (1.0 - damp)
    prev = 0.0
    for i in range(n):
        v = buf[i % ln]
        y[i] = v
        filt = a * v + (1.0 - a) * prev
        prev = filt
        buf[i % ln] = filt * 0.998  # slight overall loss so it dies out
    # gentle body resonance + a soft attack so it blooms rather than clicks
    y = y * np.exp(-np.arange(n) / SR / (dur * 0.45))
    y[: int(SR * 0.004)] *= np.linspace(0, 1, int(SR * 0.004))
    y = y + lowpass(y, 0.12) * 0.25
    # DC-blocking one-pole highpass (~20Hz) — belt and braces after the loop
    return y - lowpass(y, 2.0 * np.pi * 20.0 / SR)


def harp(f, dur=2.4, damp=0.5, bright=0.5):
    """Karplus-Strong, then resampled onto the exact target pitch.

    The delay line is an integer number of samples, so the achievable pitches are
    quantized to SR/N — at 587Hz that lands 37 cents flat, which is audibly out of
    tune against the orchestra. Rather than add a fractional-delay filter, measure
    what came out and resample to correct it (offline, so cost is irrelevant).
    """
    y = harp_raw(f, dur, damp, bright)
    f_meas = measure_f0(y)
    ratio = f / f_meas
    if abs(1200 * np.log2(ratio)) > 1.0:
        pos = np.arange(0, len(y) - 1, ratio)
        y = np.interp(pos, np.arange(len(y)), y)
    return y


# B natural minor across two octaves — ascending fish leaps walk up this scale
harp_notes = [246.94, 293.66, 329.63, 369.99, 440.0, 493.88, 587.33, 659.25]
for i, f in enumerate(harp_notes):
    save(f"harp_{i+1}", harp(f, dur=2.2 if f < 400 else 1.8))

# softer, lower voice for the fish re-entering the water (landing)
for i, f in enumerate([123.47, 146.83, 185.0, 246.94]):
    save(f"harp_low_{i+1}", harp(f, dur=2.6, damp=0.75, bright=0.28) * 0.7)

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
