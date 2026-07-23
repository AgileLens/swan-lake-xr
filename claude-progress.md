# claude-progress — swan-lake-xr

**Goal:** Overnight one-shot: polished "Swan Lake" XR experience for Pico Swan. Godot 4.7.1 + OpenXR vendors 5.1.0 (PICO loader), APK sideloadable, plus Meta-loader variant for Quest sanity tests. Proof = desktop-preview screenshots. Deliver: private AgileLens repo, KB docs, Telegram ping.

**Session:** knowledge-ea16cd69 (alex-mbp), started 2026-07-23 ~02:00 ET. Autorun slug: `pico-swan-lake`.

## Status

- [x] KB recon: Swan = NDA ByteDance/Pico headset, PICO OS/Android/OpenXR, adb sideload standard. No device attached tonight → verify via desktop preview + apk static checks.
- [x] Toolchain decision: Godot (Unity: no editor+login gate; UE-Mac-Android: slog + singleton busy).
- [x] Downloads: vendors addon 5.1.0 (PICO AARs confirmed, compat_min 4.6 ✓). Godot 4.7.1 editor + templates downloading (bg). JDK17 brew installing (bg).
- [ ] Godot installed + templates, headless verified
- [ ] Project scaffold (project.godot, XR rig, export presets ×2)
- [ ] Assets: swan GLB (Blender headless), PD music (archive.org), procedural env
- [ ] Experience code: water shader, flock, baton interaction, moods, music-reactivity
- [ ] Desktop preview screenshots verified (Read + honest assessment, iterate)
- [ ] Export SwanLake_pico.apk + SwanLake_quest.apk, static verify (aapt, signature)
- [ ] Private repo AgileLens/swan-lake-xr pushed
- [ ] KB: project doc + technique doc (godot-pico-apk-mac pipeline), daily log, timing log
- [ ] fleet_bus ping to Alex

## Failed Approaches

(none yet)

## Key facts / decisions

- Vendors 5.1.0 asset `godotopenxrvendorsaddon.zip` → `asset/addons/godotopenxrvendors/`, PICO AARs at `.bin/android/{debug,release}/godotopenxr-pico-*.aar`.
- Android SDK complete at ~/Library/Android/sdk (build-tools 34–36.1, platforms 34–36.1, cmdline-tools latest, licenses/ present).
- Renderer: Mobile (`renderer/rendering_method="mobile"` — NOT "forward_mobile", KB gotcha). Shadows off. Scale 1.0.
- Static viewpoint on dock → no comfort risk. Mood picker (Night/Dusk/Dawn) hedges subjective look per fleet rule.
