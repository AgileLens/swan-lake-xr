#!/usr/bin/env python3
"""Cut and level the program's recordings, then bake a beat map and loudness envelope.

Needs numpy, plus ffmpeg on PATH. Inputs: assets_src/downloads/ (tools/fetch_recordings.py).
Outputs: project/assets/music/<id>.mp3 and project/assets/music/<id>.json.

Godot cannot decode Opus or FLAC, and this ffmpeg has no libvorbis, so everything becomes MP3.
Levels are matched by integrated loudness. Old discs get light cleanup: rumble and surface hiss
are filtered, and nothing else is touched. No one has listened to these cuts: they were chosen
by envelope and pitch analysis, so a human should check the edit points.
"""
import json, pathlib, re, subprocess, sys
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "assets_src" / "downloads"
OUT = ROOT / "project" / "assets" / "music"
TARGET_LUFS = -18.0

CLEAN_78 = "highpass=f=70,lowpass=f=6500,afftdn=nf=-30"
# id, file, start, end (None = to the end), fade in, fade out, filter, beat prior bpm
CLIPS = [
    ("prelude", "prelude.wav", 0.0, None, 0.0, 0.0, "", 66),
    ("morning", "grieg_morning.ogg", 0.0, None, 0.0, 1.5, "", 66),
    ("hornpipe", "handel_hornpipe.opus", 0.0, 121.0, 0.0, 3.5, "", 96),
    ("storm", "beethoven_storm.ogg", 0.0, None, 0.0, 0.5, "", 96),
    ("clearing", "beethoven_shepherd.ogg", 0.0, 125.0, 0.3, 3.5, "", 66),
    ("le_cygne", "saintsaens_bokor.flac", 1.0, None, 0.6, 1.5, CLEAN_78, 60),
    ("moonlight", "smetana_vltava.ogg", 320.0, 484.0, 2.0, 3.5, "", 72),
    ("scene", "owi_swanlake.flac", 7.5, 120.0, 0.8, 2.0, CLEAN_78, 69),
    ("finale", "tchaikovsky_1812.opus", 515.0, None, 2.5, 1.0, "", 100),
]

# Scores we know beat the chroma estimate, which leans toward a key's dominant (it calls the Scene
# F# minor, not B minor). Semitones from the SFX kit's D major set. Tuning still comes from measurement.
KEY_OVERRIDE = {"prelude": 0, "scene": 0, "hornpipe": 0, "storm": -6, "clearing": 3, "moonlight": 1, "finale": 1, "morning": 2}

def run(*a):
    return subprocess.run(a, capture_output=True, text=True)

def lufs(path, flt=""):
    af = (flt + "," if flt else "") + "ebur128=framelog=quiet"
    r = run("ffmpeg", "-nostdin", "-hide_banner", "-i", str(path), "-af", af, "-f", "null", "-")
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1])

def decode(path, sr=22050):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(sr),
                          "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32), sr

def beat_track(x, sr, prior_bpm):
    """Ellis-style dynamic-programming beat tracker on spectral flux. Tracks rubato well enough
    to judge a gesture against, and that is all it is used for."""
    n, h = 1024, 256
    win = np.hanning(n)
    frames = (len(x) - n) // h
    prev = None
    flux = np.zeros(frames)
    for i in range(frames):
        s = np.log1p(np.abs(np.fft.rfft(x[i * h:i * h + n] * win))[:220] * 20.0)
        if prev is not None:
            flux[i] = np.maximum(s - prev, 0.0).sum()
        prev = s
    fps = sr / h
    flux = flux - np.convolve(flux, np.ones(int(fps)) / int(fps), mode="same")
    flux = np.maximum(flux, 0.0)
    flux = flux / (np.std(flux) + 1e-6)
    # Global tempo: autocorrelation weighted toward a conducting-friendly prior.
    ac = np.correlate(flux[:min(len(flux), int(fps * 90))], flux[:min(len(flux), int(fps * 90))], mode="full")
    ac = ac[len(ac) // 2:]
    lags = np.arange(int(fps * 60 / 180), int(fps * 60 / 36))
    weight = np.exp(-0.5 * (np.log2((60.0 * fps / lags) / prior_bpm) / 0.45) ** 2)
    period = lags[int(np.argmax(ac[lags] * weight))]
    # Dynamic programming: maximize onset strength while keeping inter-beat spacing regular.
    tight = 90.0
    score = flux.astype(np.float64).copy()
    back = -np.ones(len(flux), dtype=int)
    lo, hi = int(period * 0.6), int(period * 1.6)
    ps = np.arange(lo, hi + 1)
    pen = -tight * np.log(ps / period) ** 2
    for t in range(hi, len(flux)):
        c = score[t - ps] + pen
        k = int(np.argmax(c))
        score[t] = flux[t] + c[k]
        back[t] = t - ps[k]
    t = int(np.argmax(score[-int(period * 2):])) + len(flux) - int(period * 2)
    beats = []
    while t > 0:
        beats.append(t)
        t = back[t]
    return np.array(beats[::-1]) / fps, 60.0 * fps / period

def key_ratio(x, sr):
    """The SFX kit is tuned to D major/B minor. Returns the exact transposition (a frequency
    ratio) that lands it in this clip's key, including any tuning error in an old recording."""
    n = 8192
    hop = 8192
    freqs = np.fft.rfftfreq(n, 1 / sr)
    band = (freqs > 110) & (freqs < 2200)
    midi = 69 + 12 * np.log2(freqs[band] / 440.0)
    chroma = np.zeros(12)
    hist = np.zeros(100)
    win = np.hanning(n)
    for i in range(0, len(x) - n, hop):
        s = np.abs(np.fft.rfft(x[i:i + n] * win))[band] ** 2
        np.add.at(chroma, np.round(midi).astype(int) % 12, s)
        cents = ((midi - np.round(midi)) * 100 + 50).astype(int) % 100
        peak = s > s.max() * 0.08
        np.add.at(hist, cents[peak], s[peak])
    major = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
    minor = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
    best, best_k, mode = -2, 0, "major"
    for k in range(12):
        c1 = np.corrcoef(np.roll(major, k), chroma)[0, 1]
        c2 = np.corrcoef(np.roll(minor, k), chroma)[0, 1]
        if c1 > best:
            best, best_k, mode = c1, k, "major"
        if c2 > best:
            best, best_k, mode = c2, k, "minor"
    # Relative major of a minor key shares its notes, and that's what the kit needs.
    tonic_major = best_k if mode == "major" else (best_k + 3) % 12
    semis = ((tonic_major - 2 + 6) % 12) - 6  # D is pitch class 2, keep the shift within a tritone
    smooth = np.convolve(np.r_[hist, hist, hist], np.ones(9) / 9, mode="same")[100:200]
    cents_off = float(np.argmax(smooth) - 50)
    names = "C C# D D# E F F# G G# A A# B".split()
    return semis, cents_off, f"{names[best_k]} {mode}"

def envelope(x, sr, rate=10):
    hop = sr // rate
    n = len(x) // hop
    rms = np.sqrt(np.array([np.mean(x[i * hop:(i + 1) * hop] ** 2) for i in range(n)]))
    # Shape so the quiet passages still register, and scale to the clip's own loud moments.
    ref = np.percentile(rms, 97) + 1e-6
    env = np.clip(rms / ref, 0.0, 1.2) ** 0.6
    return env

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    for cid, fn, start, end, fi, fo, flt, prior in CLIPS:
        if only and cid not in only:
            continue
        src = SRC / fn
        tmp = OUT / (cid + ".tmp.wav")
        dur_args = ["-t", str(end - start)] if end else []
        r = subprocess.run(["ffmpeg", "-nostdin", "-y", "-v", "error", "-ss", str(start), "-i", str(src), *dur_args,
                            "-map", "0:a:0", "-ac", "2", "-ar", "44100"] + (["-af", flt] if flt else []) + [str(tmp)])
        assert r.returncode == 0, cid
        got = float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(tmp)).stdout)
        gain = TARGET_LUFS - lufs(tmp)
        af = f"volume={gain:.2f}dB,alimiter=limit=0.97:level=false"
        if fi > 0:
            af += f",afade=t=in:d={fi}"
        if fo > 0:
            af += f",afade=t=out:st={max(got - fo, 0.0):.2f}:d={fo}"
        mp3 = OUT / (cid + ".mp3")
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-v", "error", "-i", str(tmp), "-af", af, "-c:a", "libmp3lame",
                        "-q:a", "3", str(mp3)], check=True)
        tmp.unlink()
        x, sr = decode(mp3)
        beats, bpm = beat_track(x, sr, prior)
        env = envelope(x, sr)
        semis, cents, key_name = key_ratio(x, sr)
        semis = KEY_OVERRIDE.get(cid, semis)
        kr = 2.0 ** ((semis + cents / 100.0) / 12.0)
        data = {"id": cid, "duration": round(len(x) / sr, 3), "bpm": round(float(bpm), 2),
                "key": key_name, "tuning_cents": cents, "key_ratio": round(kr, 4),
                "beats": [round(float(b), 3) for b in beats],
                "env_rate": 10, "env": [round(float(e), 3) for e in env]}
        (OUT / (cid + ".json")).write_text(json.dumps(data, separators=(",", ":")))
        print(f"{cid:10} {data['duration']:7.1f}s  gain {gain:+.1f} dB  {bpm:6.1f} bpm  {len(beats):4d} beats  {key_name:9} {cents:+4.0f}c  {mp3.stat().st_size / 1048576:.1f} MB")

main()
