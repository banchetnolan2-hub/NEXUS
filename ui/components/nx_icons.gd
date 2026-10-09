class_name NxIcons
extends RefCounted
## Access to the NEXUS icon set (res://resources/icons/*.svg).
##
## Icons are white strokes on a transparent background; tint them with
## `modulate` or through Button icon colours in the theme.

const ICON_DIR := "res://resources/icons/"

static var _cache: Dictionary = {}


static func get_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _cache.has(icon_name):
		return _cache[icon_name]
	var path := ICON_DIR + icon_name + ".svg"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_warning("NxIcons: missing icon '%s'." % icon_name)
	_cache[icon_name] = tex
	return tex


## Names of every icon shipped with the game.
static func list_icons() -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(ICON_DIR)
	if dir == null:
		return names
	for file in dir.get_files():
		# Exported builds list "*.svg.import" / remapped files instead of sources.
		var base := file.trim_suffix(".import").trim_suffix(".remap")
		if base.get_extension() == "svg" and not names.has(base.get_basename()):
			names.append(base.get_basename())
	names.sort()
	return names
