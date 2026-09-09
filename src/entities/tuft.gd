extends MobBase
class_name Tuft

## Passive woolly animal. Wanders, flees when hurt, drops raw meat.

var _flee_timer := 0.0
var _head: MeshInstance3D


func _setup() -> void:
	max_health = 10.0
	health = max_health
	move_speed = 1.6
	attack_damage = 0.0
	drops = [[ItemRegistry.RAW_MEAT, 1, 2]]
	var body_color := Color(0.93, 0.91, 0.86)
	var face_color := Color(0.55, 0.42, 0.3)
	_add_box(Vector3(0, 0.75, 0), Vector3(0.7, 0.55, 1.0), body_color)
	_head = _add_box(Vector3(0, 1.0, 0.62), Vector3(0.42, 0.42, 0.4), face_color)
	_add_box(Vector3(0.16, 1.28, 0.62), Vector3(0.1, 0.14, 0.1), face_color)
	_add_box(Vector3(-0.16, 1.28, 0.62), Vector3(0.1, 0.14, 0.1), face_color)
	_add_box(Vector3(0.22, 0.25, 0.3), Vector3(0.16, 0.5, 0.16), face_color)
	_add_box(Vector3(-0.22, 0.25, 0.3), Vector3(0.16, 0.5, 0.16), face_color)
	_add_box(Vector3(0.22, 0.25, -0.3), Vector3(0.16, 0.5, 0.16), face_color)
	_add_box(Vector3(-0.22, 0.25, -0.3), Vector3(0.16, 0.5, 0.16), face_color)


func _ai_extra(delta: float) -> void:
	if _flee_timer > 0.0:
		_flee_timer -= delta
		var p := player_ref()
		if p != null:
			_wander_dir = (global_position - p.global_position)
			_wander_dir.y = 0
			_wander_dir = _wander_dir.normalized()
			move_speed = 3.4
			_wander_timer = maxf(_wander_timer, 0.5)
		if _flee_timer <= 0.0:
			move_speed = 1.6
	elif _wander_timer <= 0.0:
		wander_tick(randf_range(1.5, 4.5), randf() > 0.35)


func take_damage(amount: float, from_pos: Vector3) -> void:
	_flee_timer = 4.0
	super.take_damage(amount, from_pos)
