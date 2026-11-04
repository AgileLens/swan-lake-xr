# Receipt: Pico Swan Lake, The Conductor's Program

Slug `picoswanlake`. Branch `conductors-program`, cut from `AgileLens/swan-lake-xr` at `859809d`, with its history. Nothing pushed.
Attributed to Agile Lens by request. APK: `out/picoswanlake.apk`, package `com.agilelens.picoswanlake`, versionCode 500, versionName 5.0.0,
122 MB, sha256 `d0e71e12768f1056b5db6199728ea55007d70bcfd760f6428ddf11a10fbab3c3`. Built with Godot 4.7.2 and OpenXR Vendors 5.1.0.

**Nothing here has run on a headset, on an emulator, or through an OpenXR session.** Every result below comes from a desktop Mac or from a static check.

## What works (on the desktop and in the automated runs)

- **A complete program**: a tuning and eight movements, 24.6 minutes including the short announcements, then a curtain call and a free-play lake with encores.
- **Different staging and a different baton job per movement**: raise the sun and wake the flock, lead a regatta, strike lightning, paint a rainbow,
  draw long lines for a solo swan, light Cygnus, gather into the moonbeam, launch fireworks on the downbeat. 11 lighting stagings, 5 weather states.
- **A rebuilt swan**: a lofted hull, a tapered neck on a nine-bone chain, a head with knob, lores, nail and hinged jaw, about 155 real feathers per wing
  that fold, arch and spread, and a baked normal, occlusion and color atlas. Corps swans are decimated from the same model. The old metaball tiers are gone from the picker; origami stays.
- **Conducting that's judged kindly**: a real downstroke detector, plus trigger or pinch for anyone who can't or won't wave. Keeping time needs a run of three beats.
  Nothing lowers a grade. Doing nothing still earns the finale and the bow. Swans nod on your beats, and the curtain has four tiers.
- **A visible conductor**: a posed white glove and baton with a cuff and fading tailcoat sleeve, replacing the balloon mitten.
- **New scenery for daylight**: real terrain, 500-odd trees, far ridges, a planked dock with lanterns and rope, reeds, lily pads, a music stand with credits and hints.
- **Kept from v4**: rippling water, gathering, Cygnus, nest and cygnet, fireworks, fireflies, stereo planar reflections, orb menu, baton pose tuner, performance governor.

## How much content

24.6 minutes of programmed, staged music, then about 40 seconds of curtain and unlimited free play. The whole program runs with no input.

## Star estimate

**About 3.5 today, 4 if it holds up on a headset.** The content length, variety, finale and flock response are at a 4 by the rubric, and the stills look it.
What holds me back from saying 4 flatly: I've never seen it worn, I don't know the frame rate on the target GPU, I haven't heard any of it, and hand tracking has no evidence of ever having worked in this app. It isn't a 5: the scenery is stylized low-poly, the choreography is formations more than dance, and there's no story beyond the arc of a day.

## Test results (all run on this build's code, Godot 4.7.2)

`tools/test.sh`, rc 0:
- 37 of 37 logic checks pass (`project/tests/logic_tests.gd`).
- `--autotest` plays the full program through the real handlers on a virtual clock, headless, three ways. No audio plays in these runs.

| Run | Checks | Grace | Curtain tier |
|---|---|---|---|
| `off`: nobody touches anything | 13 of 13 | 0.22 | A quiet night on the lake |
| `wild`: random flailing and buttons | 13 of 13 | 0.64 | Bravo |
| `conduct`: scripted baton on the beat map | 17 of 17 | 0.93 | Standing ovation |

I broke the code four ways to check that the tests notice. All four failed the right check after one was strengthened: scoring lucky hits, punishing off-beat gestures,
a flock that never wakes (this slipped through at first, because later formations woke the swans anyway, so I rewrote that test), and lightning that does nothing.

- `~/knowledge/scripts/vibe-lab/check_apk.sh out/picoswanlake.apk`: exit 0. aapt shows `com.picovr.permission.HAND_TRACKING`, `pvr.app.type=vr`, the PICO loader and our own icon.
- Desktop run of the normal flow, on a window: reached the program with no script errors.
- Ten 3840x2160 Mobile renderer stills in `stills/`, no UI, no text, no post-processing, viewed before keeping. Two private 26 second clips at 1080p30 in `clips/` (not in git).

## Codex critique (independent, 3 rounds, acted on each)

| Round | Scores out of 10 | Verdict on the swan |
|---|---|---|
| 1 | Portrait 6, regatta 6, finale 5 | "Up close: still a toy" |
| 2 | Portrait 7, regatta 6.5, finale 6, dawn 7.5 | "Beautifully lit, still a toy" |
| 3 | Portrait 8.5, regatta 7.5, finale 7.5, dawn 8, rainbow 8 | "Yes, the swan is beautiful up close now" |

What changed because of it: a slimmer hull with straight flanks, a more slender neck, narrower and more numerous feathers, reduced broad-swell water and reflections, held-back whites by day, night fill, flock rafts with varied necks, and a much smaller arm.
Still open from round 3: the sleeve still takes up a lot of some frames, the far flock can still read as a band, and the moon streak is a bit chrome-like. After round 3 I softened the moon streak only. Codex saw stills, not motion, and never the headset. Treat these scores as one reader's advice, not as a rating.

## What isn't verified

- **Anything on a headset.** That includes everything in v4: its perf fix, baton fix and hand-tracking arbitration were never confirmed in a headset before the device left, and none of that has changed. No frame rate on target hardware exists for v4's fixes or for this build.
- **72 fps.** Desktop engine counters only, by movement, with stereo reflections on: 289 to 337 draws and 0.88 to 1.11 M primitives, against v4's recorded desktop 107 to 183 draws and 1.59 to 1.75 M. Primitives went down, but **draw calls roughly doubled**, and that's the risk I'd watch first. The governor still sheds crowd, fireflies, reflections, then hero detail, sky, shadows, sparkles and MSAA, but its ladder has never been seen working on target hardware. Skinned necks and blend-shape wings are new compute work that the old rigid swans didn't have.
- **Hand tracking.** The permission is now declared. See the section below. Whether hands engage on PICO is still unknown, and bare-hand gestures have never been exercised, nor has the skinned hand ever been seen tracking.
- **Controllers in the new flow.** Button handling compiles and shares one code path with the desktop's, but no controller has pressed anything in this build. The glove's grip and sleeve angle against a real controller, with the baton pitch tuner's default of -35°, may look wrong, and that's the first thing I'd check.
- **The audio, by ear.** I can't hear. Excerpts were cut from loudness envelopes and pitch tracking, so edit points might land badly: above all the 2:01 fade out of the Handel, the Vltava moonlight cuts and the 1812 entry. Rumble and hiss filtering on the 1925 and c. 1944 discs, the +21 dB lift on the Scène, and the synthesized harp and oboe of the Tuning are all unheard. The pitch analysis did confirm the Scène disc plays the Swan Lake theme, in tune, in B minor.
- **The beat maps.** They come from an automatic tracker on music with rubato. They've only been used in automated runs, so I can't say a real person's beats will feel fairly judged. The window is generous on purpose.
- **Comfort.** Lightning is deliberately soft and rate limited, the player never moves, and it should work seated, but none of that has been tried in a headset. The stand's seat-height fit is logic only.
- **Rights, in the end.** This is a documented good-faith check, not legal advice. Weakest link: the Scène's federal status rests on the disc's Office of War Information label, and I haven't seen the contract. The Musopen Beethoven's performer isn't named on its page. See `CREDITS.md`.

## Rights finding that needs Alex

**The recordings used through v4 aren't public domain in the U.S.** Commons tags the Ballet Francaise extracts `PD-EU-audio`: a 1958 LP. As I understand the Music Modernization Act, U.S. protection runs to 2067. They're out of this app, along with every other Swan Lake on Commons that carries the same tag. That's why the only Swan Lake here is the old OWI disc and the synthesized Tuning.
The public `AgileLens/swan-lake-xr` repo and its v4.0 release still ship those files and call them public domain. I didn't touch that repo. Worth a decision.
This program's Swan Lake moment is therefore a noisy 112 second wartime disc, and a clean recording would be the biggest single audio upgrade if someone can license or commission one.

## The hand-tracking gap in the earlier build

The parent asked what the earlier build's hand path really did. From source and the APK on disk:

- At `859809d`, `export_presets.cfg` has `custom_permissions=PackedStringArray()` and `hand_tracking=1`. `aapt dump permissions` on `/Users/alex/dev/swan-lake-xr/out/SwanLake_pico.apk` shows only the two OpenXR permissions. So **the v4 APK has the same gap**.
- Alex's "this is delightful" was on v1, per the KB. Hand tracking wasn't enabled in the project at all until v3 (commit `c733a15`), so that verdict was on controllers and can't have depended on hands.
- From v3 on, `hand_input.gd` tries hands first but needs real joint data. The KB's device logs record `XR_ERROR_PERMISSION_INSUFFICIENT`, then both hands stuck on "controller" for a whole session in v4. A controller-staleness heuristic was added after that and never verified.
- I found no evidence that any build ever engaged bare hands. A KB note from v3 says `aapt2` showed the permission in the manifest then. The v4 APK on disk doesn't have it, and I can't reconcile those two. Any "hands felt good" memory from those builds most likely was controller input. I can't verify more than this without a device.

## Godot 4.7.2

This build was developed, tested and exported on 4.7.2 from the start, so there's no 4.7.1 run of this code to compare with. No differences to report, and that comparison hasn't been made. The checked-in project opens and exports cleanly. The machine's shared editor settings point at a JDK path that no longer exists, so `build.sh` exports under a private copy of the settings, as the sibling apps do. During export, Godot tries to reach an adb daemon and logs "cannot connect to daemon". I made no adb calls myself.

## Departures from the brief

- Agile Lens attribution and `com.agilelens.picoswanlake`, as the task asked.
- The rigged hand mesh is MIT from Godot's demo projects, not CC0, public domain or original. It came with the project. Replacing it would take a new rigged hand.
- `--autotest` needs `tools/test.sh` to get the comparison between its three modes. A bare `--autotest` runs the conducted mode.

## Next three improvements

1. **A worn pass with counters**: fps per movement, governor behavior, glove and sleeve alignment on a controller, whether hands engage. Everything else depends on this. If draw calls hurt, merge wings and tail into the body and drop the stereo reflection first.
2. **A listening pass and a better Swan Lake**: a person checks every edit point and the two old discs, and someone sources a clean, licensable Scène.
3. **More dance, less formation**: real ensemble passages per movement, a proper pas de deux for The Swan and a true curtain choreography, plus more variety in the far flock.

## Visual change for the pitch hero, 2026-11-04

Sunrise mood fog density lowered from 0.0060 to 0.0034, in `project/scripts/mood.gd`, so the far ridges and forest keep their contrast at dawn instead of washing into one peach band (reviewers named the haze in every dawn frame). `tools/test.sh` rc 0 after the change. Desktop only, not seen on a headset. Rebuilt APK sha256 is listed in `hero/manifest.json`.
