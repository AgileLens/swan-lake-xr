# Credits & Licenses

## Music

- **Pyotr Ilyich Tchaikovsky — Swan Lake, Op. 20** (composition: public domain, composer d. 1893)
- Recordings: **Ballet Francaise Symphony Orchestra**, sourced from Wikimedia Commons, license **Public Domain** (verified via Commons `extmetadata` 2026-07-23):
  - Act 2 extract (Scène): https://commons.wikimedia.org/wiki/File:Peter_Ilyich_Tchaikovsky-_Swan_Lake-_Extract_from_Act_2.ogg
  - Act 4 extract: https://commons.wikimedia.org/wiki/File:Peter_Ilyich_Tchaikovsky-_Swan_Lake-_Extract_from_Act_4.ogg

## Code / Engine

- Godot Engine 4.7.1 (MIT) — godotengine.org
- Godot OpenXR Vendors plugin 5.1.0 (MIT) — github.com/GodotVR/godot_openxr_vendors (PICO + Meta loaders)

## Assets

- Swan model, water/sky shaders, environment: procedural, authored in-repo (Blender headless script + GDScript/Godot shaders). © Agile Lens.
- Rigged hand mesh (`project/assets/hand_mesh/{Left,Right}HandHumanoid.gltf`, `hand.png`) — from
  `godotengine/godot-demo-projects`, `xr/openxr_hand_tracking_demo/assets/gltf/`, License **MIT**
  (Godot Engine contributors). Drives `XRHandModifier3D` for real per-joint hand tracking on Swan.
