extends CanvasLayer

const UPDATE_INTERVAL_SECONDS: float = 0.35

var _label: Label
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.name = "FPSCounterLabel"
	_label.position = Vector2(10.0, 8.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "FPS --"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.94, 0.92))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL_SECONDS:
		return
	_elapsed = 0.0
	_label.text = "FPS %d" % Engine.get_frames_per_second()
