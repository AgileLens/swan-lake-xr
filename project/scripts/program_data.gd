class_name ProgramData
extends RefCounted
# The Conductor's Program: its running order, staging and credits.
#
# Each movement has one thing your baton does, and time, weather and choreography of its own.
# Cue times are seconds into that movement's recording, placed from its loudness envelope. Rights
# for every recording are recorded in CREDITS.md, and a test checks that each clip is listed there.

const MOVEMENTS := [
	{
		"id": "prelude", "clip": "prelude", "numeral": "", "title": "Tuning",
		"piece": "Swan Lake theme (arranged for harp and oboe)", "composer": "P. I. Tchaikovsky",
		"performer": "Synthesized for this app", "source": "Own arrangement; score is public domain",
		"verb": "raise", "hint": "Before dawn. Raise your baton, and the lake will wake with you.",
		"formation": "sleep",
		"cues": [{"at": 0.0, "mood": "predawn", "dur": 0.0}, {"at": 0.0, "weather": "mist"}],
	},
	{
		"id": "dawn", "clip": "morning", "numeral": "I", "title": "Dawn",
		"piece": "Morning Mood, from Peer Gynt", "composer": "Edvard Grieg",
		"performer": "Musopen Symphony (Czech National Symphony Orchestra)", "source": "Wikimedia Commons, Musopen public domain dedication",
		"verb": "raise", "hint": "Lift the sun with your baton. Each high gesture wakes a swan.",
		"formation": "sleep",
		"cues": [
			{"at": 0.0, "mood": "dawn", "dur": 50.0},
			{"at": 75.0, "mood": "sunrise", "dur": 70.0},
			{"at": 150.0, "weather": "clear"},
			{"at": 170.0, "mood": "morning", "dur": 50.0},
		],
	},
	{
		"id": "regatta", "clip": "hornpipe", "numeral": "II", "title": "Regatta",
		"piece": "Alla Hornpipe, from Water Music", "composer": "G. F. Handel",
		"performer": "\"The President's Own\" U.S. Marine Chamber Orchestra", "source": "Wikimedia Commons, U.S. government work",
		"verb": "lead", "hint": "Point at the water and beat time. The line of swans follows your baton.",
		"formation": "regatta",
		"cues": [{"at": 0.0, "mood": "morning", "dur": 6.0}, {"at": 0.0, "weather": "breeze"}, {"at": 62.0, "formation": "wedge"}],
	},
	{
		"id": "storm", "clip": "storm", "numeral": "III", "title": "The Storm",
		"piece": "Gewitter, Sturm: Symphony No. 6, fourth movement", "composer": "L. van Beethoven",
		"performer": "Musopen", "source": "Wikimedia Commons, Musopen public domain dedication",
		"verb": "strike", "hint": "Strike down on the crashes. Your baton calls the lightning.",
		"formation": "huddle",
		"cues": [
			{"at": 0.0, "mood": "gathering", "dur": 18.0}, {"at": 16.0, "mood": "storm", "dur": 9.0},
			{"at": 22.0, "weather": "rain"}, {"at": 185.0, "mood": "gathering", "dur": 30.0}, {"at": 195.0, "weather": "clear"},
		],
	},
	{
		"id": "clearing", "clip": "clearing", "numeral": "IV", "title": "After the Rain",
		"piece": "Hirtengesang: Symphony No. 6, fifth movement", "composer": "L. van Beethoven",
		"performer": "Musopen", "source": "Wikimedia Commons, Musopen public domain dedication",
		"verb": "paint", "hint": "Sweep your baton across the sky to paint the rainbow.",
		"formation": "fan",
		"cues": [{"at": 0.0, "mood": "clearing", "dur": 16.0}, {"at": 0.0, "weather": "clear"}],
	},
	{
		"id": "cygne", "clip": "le_cygne", "numeral": "V", "title": "The Swan",
		"piece": "Le Cygne, from The Carnival of the Animals", "composer": "Camille Saint-Saëns",
		"performer": "Judith Bokor, cello. Recorded 1925", "source": "Wikimedia Commons, U.S. term expired",
		"verb": "legato", "hint": "Long, slow lines. She follows your hand across the still water.",
		"formation": "solo",
		"cues": [{"at": 0.0, "mood": "golden", "dur": 20.0}, {"at": 95.0, "mood": "dusk", "dur": 55.0}, {"at": 104.0, "formation": "pair"}],
	},
	{
		"id": "moonlight", "clip": "moonlight", "numeral": "VI", "title": "Moonrise",
		"piece": "Moonlight and the Dance of the Nymphs, from Vltava", "composer": "Bedřich Smetana",
		"performer": "Musopen Symphony (Czech National Symphony Orchestra)", "source": "Wikimedia Commons, Musopen public domain dedication",
		"verb": "stars", "hint": "Point your baton at the bright stars of the Swan and tap to light them.",
		"formation": "ring",
		"cues": [{"at": 0.0, "mood": "night", "dur": 14.0}],
	},
	{
		"id": "scene", "clip": "scene", "numeral": "VII", "title": "Scène",
		"piece": "Scène, from Swan Lake", "composer": "P. I. Tchaikovsky",
		"performer": "Concert orchestra, Mishel Piastro. U.S. Office of War Information, c. 1944", "source": "Internet Archive, U.S. government recording",
		"verb": "gather", "hint": "Hold grip, or pinch with both hands, to gather the flock into the moonbeam.",
		"formation": "ring",
		"cues": [{"at": 0.0, "mood": "night", "dur": 3.0}, {"at": 2.0, "weather": "snow"}, {"at": 38.0, "auto_gather": true}, {"at": 88.0, "formation": "pair"}],
	},
	{
		"id": "finale", "clip": "finale", "numeral": "VIII", "title": "Finale",
		"piece": "Finale of the 1812 Overture", "composer": "P. I. Tchaikovsky",
		"performer": "\"The President's Own\" U.S. Marine Band, 2019", "source": "Wikimedia Commons, U.S. government work",
		"verb": "launch", "hint": "Every downbeat launches a firework where you point. Give it everything!",
		"formation": "corps",
		"cues": [
			{"at": 0.0, "mood": "gala", "dur": 5.0}, {"at": 0.0, "weather": "clear"}, {"at": 0.0, "finale": true},
			{"at": 44.0, "flyby": 2}, {"at": 130.0, "flyby": 3}, {"at": 196.0, "show": "climax"},
		],
	},
]

static func index_of(id: String) -> int:
	for i in MOVEMENTS.size():
		if MOVEMENTS[i]["id"] == id:
			return i
	return -1
