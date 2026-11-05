class_name SwanPresentation
extends RefCounted
# Small deterministic presentation policy shared by runtime and headless tests.

const STYLE_NAMES := ["LIT", "TOON", "WATERCOLOR", "PAPERCRAFT", "WHITEBOX AO"]
const VOLUME_LABELS := ["20%", "40%", "60%", "80%", "100%"]

static func style_name(index: int) -> String:
	return STYLE_NAMES[clampi(index, 0, STYLE_NAMES.size() - 1)]

static func next_style(index: int) -> int:
	return posmod(index + 1, STYLE_NAMES.size())

static func volume_label(index: int, muted: bool) -> String:
	return "MUTED" if muted else VOLUME_LABELS[clampi(index, 0, VOLUME_LABELS.size() - 1)]

static func next_volume(index: int) -> int:
	return posmod(index + 1, VOLUME_LABELS.size())

static func real_hand_compositing_supported() -> bool:
	# The current PICO/Godot stack supplies tracked joints, not a camera cutout layer.
	return false
