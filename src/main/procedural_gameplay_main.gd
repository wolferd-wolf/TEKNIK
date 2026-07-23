extends "res://src/main/procedural_world_main.gd"


func _camera_position() -> Vector3:
	if not _qa_screenshot_path().is_empty():
		return super._camera_position()
	if _player != null:
		return _player.global_position
	return _planned_spawn
