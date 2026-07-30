#!/usr/bin/env python3
"""Estimate tempo + eighth-note grid phase for the bundled Swan Lake recordings.

Feeds music.gd's per-track constants: the runtime quantizes one-shot SFX to an
eighth-note comb locked to playback position, so it needs each track's mean BPM
and the phase offset that best aligns the comb with the recording's onsets.
Orchestral rubato means a single BPM is an approximation by design — the goal is
"reads as intentional", not beat-perfect lock (see KB: godot-pico-apk-pipeline).

Usage: python3 tools/measure_tempo.py project/assets/music/*.ogg
Needs: ffmpeg (decode only) + numpy.
"""
import subprocess
import sys

import numpy as np

SR = 22050
HOP = 512
BPM_LO, BPM_HI = 40.0, 200.0


def decode(path: str) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR),
         "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def onset_envelope(x: np.ndarray) -> np.ndarray:
    win = np.hanning(2048)
    n_frames = max(0, (len(x) - 2048) // HOP)
    frames = np.lib.stride_tricks.as_strided(
        x, shape=(n_frames, 2048),
        strides=(x.strides[0] * HOP, x.strides[0])).copy()
    mag = np.abs(np.fft.rfft(frames * win, axis=1))
    flux = np.diff(mag, axis=0)
    flux[flux < 0] = 0.0
    env = flux.sum(axis=1)
    env -= env.mean()
    env /= (env.std() + 1e-9)
    return env


def comb_contrast(env: np.ndarray, bpm: float) -> float:
    """Best-phase minus worst-phase mean of the eighth-note comb over the envelope.

    High contrast = the comb genuinely aligns with recurring onsets (not just
    hitting many frames). This discriminates tempo octaves/1.5x harmonics where
    raw autocorrelation peak-picking fails (it chose 48.6 vs 72.96 arbitrarily
    until scored this way).
    """
    fps = SR / HOP
    step = 60.0 / bpm / 2.0 * fps
    means = []
    for k in range(32):
        idx = np.arange(step * k / 32.0, len(env), step).astype(int)
        means.append(float(env[idx].mean()))
    return max(means) - min(means)


def rank_bpm(env: np.ndarray) -> list:
    """Top candidates under raw contrast AND sqrt(n)-normalized contrast.

    Rubato orchestral recordings do not have one true answer — different metrics
    legitimately pick different tempo octaves (48.6 vs 104 vs 115 on the same
    act2 file). Report both rankings; a human adjudicates which family to lock.
    """
    fps = SR / HOP
    cands = np.arange(BPM_LO, BPM_HI, 0.5)
    raw = {float(b): comb_contrast(env, b) for b in cands}
    top_raw = sorted(raw, key=raw.get, reverse=True)[:5]
    norm = {b: raw[b] * np.sqrt(len(env) / (60.0 / b / 2.0 * fps)) for b in raw}
    top_norm = sorted(norm, key=norm.get, reverse=True)[:5]
    return [("raw", [(b, raw[b]) for b in top_raw]),
            ("norm", [(b, norm[b]) for b in top_norm])]


def grid_phase(env: np.ndarray, bpm: float) -> float:
    """Offset (sec) of the eighth-note comb that best hits the onset envelope."""
    fps = SR / HOP
    grid = 60.0 / bpm / 2.0
    step = grid * fps
    best_phase, best_score = 0.0, -1e18
    for k in range(32):
        phase = step * k / 32.0
        idx = np.arange(phase, len(env), step).astype(int)
        score = float(env[idx].sum())
        if score > best_score:
            best_score, best_phase = score, phase
    return best_phase / fps


def main() -> None:
    for path in sys.argv[1:]:
        x = decode(path)
        env = onset_envelope(x)
        print(f"{path}  ({len(x) / SR:.1f}s)")
        for label, ranked in rank_bpm(env):
            for b, score in ranked:
                print(f"  [{label:4}] bpm={b:6.2f} score={score:+.4f} "
                      f"grid_offset={grid_phase(env, b):.3f}s")


if __name__ == "__main__":
    main()
