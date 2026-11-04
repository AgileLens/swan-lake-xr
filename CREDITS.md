# Credits and rights

Every recording in The Conductor's Program was checked for the **recording's** status, not only the composition's.
A composer's death date says nothing about who owns a performance, so "Tchaikovsky is public domain" was never enough.

Each row states what the claim rests on. Hashes and the license text read at download time are written to
`assets_src/downloads/rights_manifest.json` by `tools/fetch_recordings.py`. The cut times and processing are in
`tools/make_program_audio.py`. I'm not a lawyer: this is a documented good-faith check, and a rights review is still
worth doing before a commercial release.

## Recordings

| Clip | Movement | Work and composer | Performer | Basis for the recording being public domain | Source |
|---|---|---|---|---|---|
| `morning` | I. Dawn | Morning Mood, *Peer Gynt* Suite No. 1, Edvard Grieg (d. 1907) | Musopen Symphony (Czech National Symphony Orchestra), 2012 | Rights holder's dedication: `{{PD-author|Musopen}}`, Musopen Kickstarter recordings | [Commons](https://commons.wikimedia.org/wiki/File:Musopen_-_Morning.ogg) |
| `hornpipe` | II. Regatta | Alla Hornpipe, *Water Music*, G. F. Handel (d. 1759) | "The President's Own" U.S. Marine Chamber Orchestra | U.S. federal government work (`PD-USGov-Military-Marines`) | [Commons](https://commons.wikimedia.org/wiki/File:Handel%27s_Water_Music_-_12._Alla_hornpipe_-_Chamber_Orchestra_-_United_States_Marine_Band.opus) |
| `storm` | III. The Storm | Symphony No. 6, fourth movement, Beethoven (d. 1827) | Musopen (performer not named on the page) | Rights holder's dedication, `{{PD-author|Musopen}}`, with Wikimedia permission ticket 2008012110017088 | [Commons](https://commons.wikimedia.org/wiki/File:Ludwig_van_Beethoven_-_symphony_no._6_in_f_major_%27pastoral%27,_op._68_-_iv._allegro.ogg) |
| `clearing` | IV. After the Rain | Symphony No. 6, fifth movement (opening), Beethoven | Musopen (performer not named on the page) | Same as above | [Commons](https://commons.wikimedia.org/wiki/File:Ludwig_van_Beethoven_-_symphony_no._6_in_f_major_%27pastoral%27,_op._68_-_v._allegretto.ogg) |
| `le_cygne` | V. The Swan | *Le Cygne*, Camille Saint-Saëns (d. 1921) | Judith Bokor, cello; Columbia, recorded 5 June 1925 | Term expired: published before 1926 in the U.S. (`PD-US-expired`) and past the term in the EU | [Commons](https://commons.wikimedia.org/wiki/File:Judith_Bokor_plays_Le_Cygne_by_Saint-Sa%C3%ABns.flac) |
| `moonlight` | VI. Moonrise | Moonlight section of *Vltava*, Bedřich Smetana (d. 1884) | Musopen Symphony (Czech National Symphony Orchestra) | Rights holder's dedication (`PD-author`), and `CC0` on the OGG copy | [Commons](https://commons.wikimedia.org/wiki/File:Smetana,_M%C3%A1_vlast_-_Vltava_-_The_Moldau.ogg) |
| `scene` | VII. Scène | Scène (No. 10), *Swan Lake*, P. I. Tchaikovsky (d. 1893) | Concert Orchestra, Mishel Piastro; *Salon Music* No. 29, matrix 13-5902 | Published by the U.S. Office of War Information, Overseas Branch, a federal agency, c. 1942-45. See the note below | [Internet Archive](https://archive.org/details/78_swan-lake_tschaikowsky-piastro_gbia7039886a) |
| `finale` | VIII. Finale | *1812 Overture* (close), P. I. Tchaikovsky; transcribed by MGySgt Donald Patterson | "The President's Own" U.S. Marine Band, Col. Jason K. Fettig, 26 May 2019 | U.S. federal government work: transcription, performance and recording (`PD-USGov-Military-Marines`) | [Commons](https://commons.wikimedia.org/wiki/File:1812_Overture_-_United_States_Marine_Band.opus) |
| `prelude` | Tuning | Swan Lake theme, arranged for harp and oboe | Synthesized in `assets_src/make_prelude.py` | Original synthesized performance of a public domain score. No recording involved | This repository |

The clips also carry Internet Archive's and Commons's transfer work. Bokor and the Office of War Information disc are old
78 rpm transfers: I filtered rumble and hiss and matched loudness, and did nothing else to them.

**What I'm less sure of.** The `scene` disc's federal status rests on its label: an Office of War Information pressing with an
OWI program and matrix number. I believe it's a government production, but I have not seen OWI's contract with the orchestra.
It's the one rights claim here that rests on inference. It's also the only *Swan Lake* in the program.

## Recordings deliberately not used

| Recording | Why |
|---|---|
| Ballet Francaise Symphony Orchestra, Act 2 and Act 4 extracts (Valiant, 1958). **The tracks used through v4 of Swan Lake XR** | Commons tags them `PD-EU-audio`. That says public domain in the EU. A 1958 recording stays protected in the U.S. until 2067 under the Music Modernization Act. Removed from this app. |
| John Barbirolli and the LPO, 1933, Swan Lake (Commons) | `PD-EU-audio`. U.S. protection runs to 2034 |
| Antal Dorati and the LPO, 1938, Act 4 Finale (Commons) | `PD-EU-audio`. U.S. protection runs to 2039 |
| "Swan lake act IV no. 29 Scene finale.flac" (Commons) | Tag covers only the composition. The source is a modern radio station download, so this one looks mislabeled |
| "European Archive" Swan Lake (Commons, Musopen) | `PD-old` covers only the composition. Performer and date are unknown |
| Alisa Weilerstein and Jason Yoder, *Le Cygne*, White House 2009 (Commons) | The recording is federal, but the page gives the performance as CC BY and only "assumably" released. Not clean enough to call public domain |
| Debussy, *Clair de lune*, 1905 piano file (Commons) | Tag covers only the composition, and the source is an unattributed YouTube upload |

## Code, engine and art

- Godot Engine 4.7.2 (MIT): godotengine.org
- Godot OpenXR Vendors plugin 5.1.0 (MIT): github.com/GodotVR/godot_openxr_vendors
- Rigged hand mesh (`project/assets/hand_mesh/`), from `godotengine/godot-demo-projects`, MIT, Godot Engine contributors. This drives
  bare-hand tracking and, posed around the baton, the white glove. This is the one asset that is not procedural.
- Swans, scenery, baton, sleeve, water, sky, rainbow and lightning: procedural and authored in this repository
  (`assets_src/make_swan_hero.py`, `assets_src/make_env.py`, `project/shaders/`). © Agile Lens.
- Sound effects: synthesized in this repository (`assets_src/make_sfx.py`). © Agile Lens.
