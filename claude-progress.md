# claude-progress — swan-lake-xr

**Goal:** Overnight one-shot: polished "Swan Lake" XR experience for Pico Swan. **DONE** (device test pending — no Swan adb-reachable overnight).

**Session:** knowledge-ea16cd69 (alex-mbp), 2026-07-23 ~02:00–07:30 ET.

## Status — all core items landed

- [x] KB recon → concept "Swan Lake on the Swan" (theater DNA, name synergy, LBE-safe static dock)
- [x] Toolchain: Godot 4.7.1 + vendors 5.1.0 (PICO AARs), Android SDK/JDK17 already on machine
- [x] Assets: procedural swan GLB (Blender headless, 1720 polys), PD music (Commons, license-verified), procedural env
- [x] Experience: water/sky/beam shaders, 8-swan flock AI (wander/attract/gather/bow/flap), baton ripples, moon-streak water, fireflies, 3 moods, music-energy reactivity, Act 4 finale button
- [x] Look-dev verified via screenshots (3 iterations: swan head materials, beam scale/position, firefly sprites, gather spacing)
- [x] `out/SwanLake_pico.apk` + `out/SwanLake_quest.apk` — built headless, statically verified (loaders, manifest, pico AAR in dex)
- [x] Private repo https://github.com/AgileLens/swan-lake-xr (main @ pushed), build.sh reproducible
- [x] KB: projects/swan-lake-xr.md, intelligence/techniques/godot-pico-apk-pipeline-macos.md, daily log, timing log

## Next (needs human/hardware)

1. Sideload on Swan: `adb install -r /Users/alex/dev/swan-lake-xr/out/SwanLake_pico.apk` (dev mode). Quest sanity: same with `_quest.apk`.
2. In headset: check perf (target 72+), controller bindings (trigger/grip/A/B), audio, comfort.
3. Taste pass: pick mood default (A/X cycles), tune swan speed/wake if wanted.

## Failed Approaches

- ffmpeg vorbis re-encode (this brew build lacks libvorbis; native encoder produced 62MB ogg) → use Commons originals as-is.
- Hard-typing child scripts against SwanLakeMain (cyclic class_name → "Could not resolve external class member") → untyped back-refs.
- gradle via sandbox/IPv6 (timeout, then "no route to host" on dl.google.com) → local gradle dist + preferIPv4Stack.
- Committing project/android/ (112MB AAR > GitHub 100MB pre-receive) → gitignored, amended before push.
