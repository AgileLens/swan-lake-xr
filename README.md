# Swan Lake XR

An immersive twilight-lake vignette built for the **Pico Swan** headset: stylized swans glide across shader-water under a low moon while Tchaikovsky's *Swan Lake* plays, and you conduct the scene with your controller — ripple the water, draw the flock, trigger a crescendo. Built with Godot 4.7 + OpenXR (PICO vendor loader), fully standalone APK, no PCVR.

Static-viewpoint (dock/stage) design: zero locomotion, zero motion sickness — demo-friendly for LBE/VIP settings.

## Quickstart

Prereqs (already on alex-mbp): Godot 4.7.1 (`~/dev/tools/godot471`), Android SDK (`~/Library/Android/sdk`), OpenJDK 17 (brew).

```bash
cd /Users/alex/dev/swan-lake-xr && ./build.sh pico   # → out/SwanLake_pico.apk
```

```bash
cd /Users/alex/dev/swan-lake-xr && ./build.sh quest  # → out/SwanLake_quest.apk (same scene, Meta loader — for sanity-testing on any Quest)
```

Install on the Swan (developer mode on, USB or Wi-Fi adb):

```bash
adb install -r /Users/alex/dev/swan-lake-xr/out/SwanLake_pico.apk
```

Desktop preview (non-XR orbit camera, for look-dev on the Mac):

```bash
/Users/alex/dev/tools/godot471/Godot.app/Contents/MacOS/Godot --path /Users/alex/dev/swan-lake-xr/project -- --preview
```

## Things to Try

1. **Just stand still for 30 seconds.** The flock breathes with the music; a swan will stretch its wings on the next musical swell.
2. **Point at the water and pull the trigger.** A ripple burst blooms where you point and the swans bank toward it.
3. **Hold grip.** The flock gathers in a circle and bows — moon shaft brightens, fireflies swirl (the "crescendo" beat for demos).
4. **Tap A/X.** Cycle mood: Night → Dusk → Dawn. Same choreography, three completely different paintings — pick your favorite and tell Claude.
5. **On the Mac:** run the desktop preview command above and drag the mouse to orbit — same scene the headset renders.

## Notes

- **NDA:** Swan is unreleased ByteDance/Pico hardware — this repo stays private.
- Music: public-domain recording (see `CREDITS.md`).
- Renderer: Godot Mobile renderer, shadows off, foveation 2 — per KB technique `godot-metahuman-quest-standalone.md` (measured on XR2 Gen 2; Swan silicon is newer).
- Built by Agile Lens.
