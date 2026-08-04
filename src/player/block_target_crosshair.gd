class_name TeknikBlockTargetCrosshair
extends Control

# Keep the reticle visually stable. Target state and mining progress are shown
# on the block itself through its outline and crack overlay, not by changing the
# crosshair into large coloured warning graphics.
const RETICLE_COLOR := Color(0.98, 0.99, 1.0, 0.96)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.88)
const ARM_LENGTH: float = 10.0
const CENTER_GAP: float = 3.5

var _targeted: bool = false
var _pending: bool = false
var _mining_progress: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_targeted(targeted: bool) -> void:
	_targeted = targeted


func set_pending(pending: bool) -> void:
	_pending = pending


func set_mining_progress(progress: float) -> void:
	_mining_progress = clampf(progress, 0.0, 1.0)


func is_targeted() -> bool:
	return _targeted


func is_pending() -> bool:
	return _pending


func mining_progress() -> float:
	return _mining_progress


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var segments: Array[PackedVector2Array] = [
		PackedVector2Array([center + Vector2(-ARM_LENGTH, 0.0), center + Vector2(-CENTER_GAP, 0.0)]),
		PackedVector2Array([center + Vector2(CENTER_GAP, 0.0), center + Vector2(ARM_LENGTH, 0.0)]),
		PackedVector2Array([center + Vector2(0.0, -ARM_LENGTH), center + Vector2(0.0, -CENTER_GAP)]),
		PackedVector2Array([center + Vector2(0.0, CENTER_GAP), center + Vector2(0.0, ARM_LENGTH)]),
	]
	for segment: PackedVector2Array in segments:
		draw_line(segment[0], segment[1], SHADOW_COLOR, 4.0, true)
	for segment: PackedVector2Array in segments:
		draw_line(segment[0], segment[1], RETICLE_COLOR, 1.8, true)
	draw_circle(center, 2.0, SHADOW_COLOR)
	draw_circle(center, 0.9, RETICLE_COLOR)
