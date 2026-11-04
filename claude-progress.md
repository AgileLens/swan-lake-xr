# claude-progress: Pico Swan Lake (Vibe Lab uplift of swan-lake-xr)

**Goal:** raise the app from about 3 to 4 stars on PICO Vibe Lab's rubric with The Conductor's Program and beautiful swans.
**State:** v5 built, on branch `conductors-program`, local only. Results and gaps: `RECEIPT.md`. Rights: `CREDITS.md`.
**Next:** a worn pass (see RECEIPT, next improvements). Everything so far is desktop-only.

## Rebuild from scratch

`assets_src/make_swan_hero.py` and `make_env.py` in Blender 4.2; `tools/fetch_recordings.py`, `assets_src/make_prelude.py`, then
`tools/make_program_audio.py` (needs numpy; the system python has none, so use a venv); `tools/test.sh`; `./build.sh`; `--stills`; `tools/clips.sh`.
Close-up look-dev for the bird: `tools/lab.sh --fast` for shape, `tools/lab.sh` with the 5 minute bake. Renders go to `out/swanlab`.

## Failed Approaches

- Blender Decimate with a vertex group to protect the head: weights mean "how much to collapse", so a zero-cost hull simply vanished. Plain quadric keeps the head dense anyway.
- Voxel remesh with feathers receiving shadows: 1 cm layers shadow each other in the depth map, giving a gray wing on a sunlit bird. Feathers don't receive shadows now.
- Procedural mitten: stacked balloons in the bottom of the view. It's a posed glove now.
- Commons "Public domain" as proof: `PD-EU-audio` means EU only, and `PD-old` often covers only the composition. Read the wikitext.
- Chroma key detection on orchestral recordings leans to the dominant (it called B minor F# minor). Known keys are overridden in `make_program_audio.py`.
- Skeleton poses set before a skeleton enters the tree don't stick; `look_at` outside the tree does nothing (this one left every Cygnus line upright since v2).
- Overlapping `Tween`s on one shader uniform: a 70 s sunrise kept overwriting the next movement's sky. `MoodKit.apply` kills live tweens first.
- Hard reflection cut at the mirror camera's frame: the panel's "vertical water boundaries". Fades to sky color now, and the frustum is wider.
- Scripted conducting with the stroke's low point at mid-beat scored everything off-beat. Bottom of the stroke goes on the beat.
