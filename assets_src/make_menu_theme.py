#!/usr/bin/env python3
"""Generate Swan Lake's original menu nocturne. No samples or reference melody."""
import math, pathlib, struct, wave

RATE = 22050
SECONDS = 12
OUT = pathlib.Path(__file__).resolve().parent.parent / "project/assets/music/menu_theme.wav"
NOTES = (146.83, 185.00, 220.00, 277.18, 246.94, 185.00)
samples = []
for i in range(RATE * SECONDS):
    t = i / RATE
    k = int(t / 1.0) % len(NOTES)
    local = t % 1.0
    f = NOTES[k]
    harp = math.exp(-local / 0.42) * (math.sin(math.tau*f*t) + 0.28*math.sin(math.tau*f*2.01*t))
    lake = 0.18 * math.sin(math.tau*55*t + 0.35*math.sin(math.tau*0.08*t))
    high = 0.10 * math.sin(math.tau*(f*2)*t) * (0.5 + 0.5*math.sin(math.tau*0.12*t))
    samples.append((harp*0.25 + lake + high) * 0.62)
tail = RATE
for i in range(tail):
    a = i / tail
    samples[i] = samples[i]*a + samples[-tail+i]*(1-a)
OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s))*32767)) for s in samples))
print(OUT, SECONDS, "seconds")
