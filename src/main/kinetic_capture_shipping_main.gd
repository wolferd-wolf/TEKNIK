extends "res://src/main/survival_vitals_main.gd"


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if not is_instance_valid(_player):
		return
	_player.set_scripted_mode(true)
	_player.set_scripted_move(Vector2.ZERO)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_runtime_log.event("info", "qa", "kinetic_evidence_player_frozen", {
		"position": str(_player.global_position),
		"machine_instances": _machine_root.get_child_count() if _machine_root != null else 0,
		"interaction_enabled": true,
		"animated_visuals": _rotating_visuals.size(),
	})
