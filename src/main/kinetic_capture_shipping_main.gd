extends "res://src/main/survival_vitals_main.gd"

const MiningDemoDirector = preload("res://src/qa/mining_demo_director.gd")

# Shipping inheritance remains survival_vitals_main.gd -> placement_preview_main.gd
# -> targeted_interaction_main.gd -> interactive kinetic and survival systems.


func _ready() -> void:
	super._ready()
	if "--qa-mining-demo" in OS.get_cmdline_user_args() and is_instance_valid(_player):
		var director: TeknikMiningDemoDirector = MiningDemoDirector.new()
		director.name = "MiningDemoDirector"
		add_child(director)
		director.begin(self, _player)


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
