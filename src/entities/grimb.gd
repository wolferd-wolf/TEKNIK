extends MobBase
class_name Grimb

## Hostile night stalker. Chases the player, melee attack, withers in daylight.

const CHASE_SPEED := 3.1
const SIGHT_RANGE := 22.0


func _setup() -> void:
	max_health = 16.0
	health = max_health
	move_speed = CHASE_SPEED
	attack_damage = 3.0
	drops = [[ItemRegistry.COAL, 0, 2]]
	var skin := Color(0.24, 0.4, 0.28)
	var dark := Color(0.16, 0.28, 0.2)
	_add_box(Vector3(0, 1.0, 0), Vector3(0.55, 0.7, 0.32), skin)      # torso
	_add_box(Vector3(0, 1.52, 0), Vector3(0.4, 0.36, 0.36), dark)     # head
	_add_box(Vector3(0.14, 1.6, -0.19), Vector3(0.1, 0.1, 0.02), Color(0.9, 0.85, 0.4))  # eye
	_add_box(Vector3(-0.14, 1.6, -0.19), Vector3(0.1, 0.1, 0.02), Color(0.9, 0.85, 0.4))
	_add_box(Vector3(0.38, 1.15, 0.14), Vector3(0.18, 0.62, 0.18), skin)  # arms forward
	_add_box(Vector3(-0.38, 1.15, 0.14), Vector3(0.18, 0.62, 0.18), skin)
	_add_box(Vector3(0.15, 0.34, 0), Vector3(0.2, 0.68, 0.2), dark)   # legs
	_add_box(Vector3(-0.15, 0.34, 0), Vector3(0.2, 0.68, 0.2), dark)


func _ai_extra(delta: float) -> void:
	var p := player_ref()
	if p != null:
		var dist := global_position.distance_to(p.global_position)
		if dist < SIGHT_RANGE:
			var to_p := p.global_position - global_position
			to_p.y = 0
			_wander_dir = to_p.normalized()
			_wander_timer = 0.4
			if dist < attack_range and _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				var player := p as Node
				if player.has_method("take_damage"):
					player.take_damage(attack_damage, global_position)
		elif _wander_timer <= 0.0:
			wander_tick(randf_range(2.0, 5.0), randf() > 0.4)
	else:
		wander_tick(2.0, false)
	_burn_timer += delta
	if _is_daylight() and _burn_timer > 2.0:
		_burn_timer = 0.0
		take_damage(2.0, global_position + Vector3(randf() - 0.5, 0, randf() - 0.5))


func _is_daylight() -> bool:
	var g := get_tree().get_first_node_in_group("day_night")
	if g != null and g.has_method("is_day"):
		return g.is_day()
	return true
