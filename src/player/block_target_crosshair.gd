class_name TeknikBlockTargetCrosshair
extends Control

const IDLE_COLOR := Color(0.96, 0.98, 1.0, 0.92)
const TARGET_COLOR := Color(1.0, 0.72, 0.18, 1.0)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.78)
const ARM_LENGTH: float = 10.0
const CENTER_GAP: float = 4.0

var _targeted: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_targeted(targeted: bool) -> void:
	if targeted == _targeted:
		return
	_targeted = targeted
	queue_redraw()


func is_targeted() -> bool:
	return _targeted


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var segments: Array[PackedVector2Array] = [
		PackedVector2Array([center + Vector2(-ARM_LENGTH, 0.0), center + Vector2(-CENTER_GAP, 0.0)]),
		PackedVector2Array([center + Vector2(CENTER_GAP, 0.0), center + Vector2(ARM_LENGTH, 0.0)]),
		PackedVector2Array([center + Vector2(0.0, -ARM_LENGTH), center + Vector2(0.0, -CENTER_GAP)]),
		PackedVector2Array([center + Vector2(0.0, CENTER_GAP), center + Vector2(0.0, ARM_LENGTH)]),
	]
	for segment: PackedVector2Array in segments:
		draw_line(segment[0], segment[1], SHADOW_COLOR, 5.0, true)
	var color: Color = TARGET_COLOR if _targeted else IDLE_COLOR
	for segment: PackedVector2Array in segments:
		draw_line(segment[0], segment[1], color, 2.2, true)
	draw_circle(center, 2.1, SHADOW_COLOR)
	draw_circle(center, 1.15, color)
