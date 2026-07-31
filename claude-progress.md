# claude-progress — swan-lake-xr

**Goal:** Polished "Swan Lake" XR experience for PICO Swan, ahead of a demo for
Dax (PICO) — must read as more than a tech demo.

**Sessions:** v1 (2026-07-23) → v2/v3 (2026-07-29/30, in-headset feedback
rounds) → v4 (2026-07-31, overnight beauty pass, alex-mbp).

## Status — v4 landed, awaiting device verification

- [x] Core experience: water/sky/beam shaders, flock AI, baton conducting,
      gather/finale, moods, weather, swan style ladder, Cygnus puzzle, nest/hatch
- [x] All SFX are plucked B-minor harp gestures (Karplus-Strong), measured to
      within a cent — nothing "video-gamey" left (fish, fireworks, plops, splash)
- [x] Controller ↔ bare-hand swap (Tank Commander pattern) + **real skinned
      hand mesh** via `XRHandModifier3D` (verified 0 script errors on a live
      simulated OpenXR session; on-Swan joint deformation unverified)
- [x] Swans dance to the music — neck/wing/beak driven by a beat/bar clock,
      per-swan phrase offset so the corps looks choreographed
- [x] Corps de ballet: audience (faces the dock, holds position) that becomes
      a chorus (sways/flaps in a wave) on musical swells, up to 5,000 instances
- [x] Living sky: moonlit cloud deck + music-reactive aurora, per-mood
- [x] GPU headroom spent on research-prioritized items: fireflies 130→2500
      w/ soft depth fade, reflection res 768→1024, wave-crest foam
- [x] Perf governor ladder: corps → fireflies → reflections → shadows →
      sparkles → MSAA, each independently steppable
- [x] Both APKs rebuilt (`out/SwanLake_{pico,quest}.apk`), build tag
      `v4 · 2026-07-31`
- [x] KB fully written up: projects/swan-lake-xr.md (v2/v3/v4 sections),
      pipeline addendum in intelligence/techniques/godot-pico-apk-pipeline-macos.md,
      2 standalone technique docs (Karplus-Strong synthesis, volumetric light shafts)
- [x] Auto-installer watcher armed (`swan_watcher.sh`, polls `adb devices`,
      installs `out/verified/SwanLake_pico.apk` + texts Alex on attach)

## Next (needs the real Swan headset)

1. **Hand tracking permission** — `XR_ERROR_PERMISSION_INSUFFICIENT` persists
   even with the manifest permission + `handtracking=1` meta-data present
   (confirmed via `aapt2 dump xmltree`). Leading hypothesis: a device-side
   Settings → Developer → Hand Tracking toggle, separate from the app's
   requested permission (this is how PICO 4/4 Ultra work; unconfirmed on Swan).
   `hand_input.gd` logs every source transition — `adb logcat | grep
   handinput` on-device will settle it.
2. **Mesh-hand visual verification** — does the real skinned hand actually
   deform correctly from live Swan joint data, and does the material tint read
   right against the mitten's ivory look?
3. **Full experience pass in-headset**: dance choreography readability, chorus
   wave timing, sky/aurora at actual headset brightness, firefly density/perf
   at 2500 on real hardware (desktop measured ~107fps/1.6-1.7M primitives —
   real Adreno numbers unknown).
4. Perf: confirm the corps→fireflies→reflections shedding ladder actually
   holds 72fps on-device without visibly thrashing.

## Failed Approaches

- ffmpeg vorbis re-encode (brew build lacks libvorbis) → use Commons originals as-is.
- Hard-typing child scripts against SwanLakeMain (cyclic class_name) → untyped back-refs.
- gradle via sandbox/IPv6 → local gradle dist + preferIPv4Stack.
- Committing project/android/ (112MB AAR > GitHub 100MB) → gitignored.
- FFT peak-picking for harp pitch verification → false octave errors (2nd
  partial louder than fundamental) → switched to autocorrelation.
- Aurora indexed by `atan(d.x,d.z)` → hard seam at the wrap point directly
  ahead of the viewer → indexed by normalized horizontal direction instead.
- Screenshot capture after `await process_frame` → silently duplicated frames
  (fires before drawing) → `await RenderingServer.frame_post_draw`.
- Literal lakebed caustics (from a research brief's suggestion) → doesn't fit
  a genuinely deep, opaque night lake with no visible floor → wave-crest foam
  instead, which reuses the already-computed ripple field.
