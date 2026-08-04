extends "res://scripts/ui/mobile_hud.gd"

const LOOK_REGION_LEFT_RATIO := 0.46
const LOOK_REGION_BOTTOM_RATIO := 0.60

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(player) and player.has_method("get_target_status_text"):
		stats_label.text += "\n%s" % player.get_target_status_text()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			var inside_look_region: bool = (
				event.position.x > viewport_size.x * LOOK_REGION_LEFT_RATIO
				and event.position.y < viewport_size.y * LOOK_REGION_BOTTOM_RATIO
			)
			if inside_look_region and look_touch < 0:
				look_touch = event.index
				last_look_position = event.position
				get_viewport().set_input_as_handled()
		elif event.index == look_touch:
			look_touch = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == look_touch:
		var delta_value: Vector2 = event.position - last_look_position
		last_look_position = event.position
		player.apply_touch_look(delta_value)
		get_viewport().set_input_as_handled()
