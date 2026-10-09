extends SceneTree
## Regenerates res://ui/theme/nexus_theme.tres from the design tokens.
## Usage: godot --headless --path . -s res://tools/build_theme.gd

const Builder := preload("res://ui/theme/nx_theme_builder.gd")
const OUTPUT := "res://ui/theme/nexus_theme.tres"


func _init() -> void:
	var theme: Theme = Builder.build()
	var err := ResourceSaver.save(theme, OUTPUT)
	if err != OK:
		push_error("Theme generation failed: %s" % error_string(err))
	else:
		print("Theme written to ", OUTPUT)
	quit(err)
