extends "res://scripts/player/player_controller.gd"

const INTERACTION_COOLDOWN_MSEC := 110

var force_mobile_input_for_test := false
var last_interaction_msec := -INTERACTION_COOLDOWN_MSEC

func _unhandled_input(event: InputEvent) -> void:
	# Android converts screen taps into mouse-button events as well as touch events.
	# Never let those emulated mouse events enter the desktop mining/placement path.
	if _uses_touch_only_actions():
		return
	super._unhandled_input(event)

func request_mine() -> void:
	if not _consume_interaction_slot():
		return
	mine_requested = true

func request_place() -> void:
	if not _consume_interaction_slot():
		return
	place_requested = true

func _consume_interaction_slot() -> bool:
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_interaction_msec < INTERACTION_COOLDOWN_MSEC:
		return false
	last_interaction_msec = now_msec
	return true

func _uses_touch_only_actions() -> bool:
	return OS.has_feature("mobile") or force_mobile_input_for_test
