# claude-progress — swan-lake-xr

**Goal:** Polished "Swan Lake" XR experience for PICO Swan, ahead of a demo for
Dax (PICO) — must read as more than a tech demo.

**Sessions:** v1 (2026-07-23) → v2/v3 (2026-07-29/30, in-headset feedback
rounds) → v4 (2026-07-31, overnight beauty pass, alex-mbp) → v4 live-demo round
(2026-07-31/08-01, live with Dax, alex-mbp) → **device handed to Jun (PICO),
distribution now via GitHub Releases.**

## Status — v4.0 released, physical device no longer with Alex

**Alex no longer has adb access to a Swan headset.** Jun (PICO) has the
physical unit. Any future updates must ship as a
[GitHub Release](https://github.com/AgileLens/swan-lake-xr/releases) —
`out/SwanLake_{pico,quest}.apk` — announced in Slack `#pico-int` via the
`xoxb` bot token (`chat.postMessage`, posts as "Claude MCP"). **Never use the
OAuth `slack_send_message` connector for this project** — it posts as Alex's
own identity, which he explicitly does not want.

Live in-headset session with Dax fixed, same-session: reflections/shadows
default on, corps 200→800 organic, a 37fps perf regression (leftover
`Sky.radiance_size` 256 from an abandoned seam-bug hypothesis — reverted,
100-110fps confirmed), baton flip (pitch clamp reaching -90° — tightened to
-78), baton grip point (recomputed from hand-generator formulas), hand-tracking
never engaging (controller-staleness heuristic added), and fireflies rewritten
as a beat-synced pulsing shader. Diagnosed but NOT fixed in code: "head feels
3DoF" is an unconfigured Guardian boundary on this physical unit
(`tracking_6dof_stopped: true` + null boundary in the system log) — needs the
standard PICO room-scale setup flow run once, not an app change.

**None of the above fixes were verified in-headset before the device left.**
They're compile-clean / error-free in a simulated OpenXR session only.

Cross-session collaboration with a Fort session (their MetaHuman/Unreal
companion apps, same physical Swan) found: a Meta-only extension instantiated
unguarded silently killed their whole face/eye/voice setup chain with no error
output, and PICO implements face tracking via the HTC OpenXR extension, not
Meta's. Full writeup: `~/knowledge/intelligence/techniques/pico-openxr-runtime-debugging-patterns.md`.
Fort's chain-fix APK (`MHSwanLIVE-CHAINFIX-2026-07-31.apk`) was never run
against a live device — `swan_watch.sh` timed out twice waiting for reconnect
before Jun took the headset.

## Status — v4 landed, awaiting device verification (superseded above)

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
