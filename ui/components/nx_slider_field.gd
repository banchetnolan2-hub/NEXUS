class_name NxSliderField
extends HBoxContainer
## Horizontal slider with a live value read-out on its right.
##
## `formatter` turns the raw value into display text (percent by default).

signal value_changed(value: float)

var slider: HSlider
var value_label: Label
var formatter: Callable = func(v: float) -> String: return NxSliderField.format_percent(v)

var value: float:
	get:
		return slider.value
	set(v):
		slider.set_value_no_signal(v)
		_refresh_label()


func _init(min_value: float = 0.0, max_value: float = 1.0, step: float = 0.01) -> void:
	add_theme_constant_override("separation", NxPalette.SPACE_M)
	slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 180
	slider.focus_mode = Control.FOCUS_ALL
	add_child(slider)

	value_label = Label.new()
	value_label.theme_type_variation = &"ValueLabel"
	value_label.custom_minimum_size.x = 56
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		_refresh_label()
		value_changed.emit(v))
	_refresh_label()


func _refresh_label() -> void:
	value_label.text = formatter.call(slider.value)


static func format_percent(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)


static func format_multiplier(v: float) -> String:
	return "×%.2f" % v
