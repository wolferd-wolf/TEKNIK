extends "res://scripts/world/atomic_voxel_world.gd"

const SAVE_TEMP_PATH := "user://teknik_world_v1.pending.json"
const SAVE_ROLLBACK_PATH := "user://teknik_world_v1.rollback.json"
const WATER_RECENTER_GRID := CHUNK_SIZE * 2

var save_commit_count := 0
var save_commit_failures := 0
var lifecycle_flush_requests := 0
var lifecycle_flush_commits := 0
var lifecycle_flush_failures := 0
var last_lifecycle_flush_reason := "none"
var water_center_grid := Vector2i(999999, 999999)
var water_recenter_count := 0

func _ready() -> void:
	super._ready()
	shared_material.albedo_texture = null
	shared_material.vertex_color_use_as_albedo = true
	shared_material.roughness = 0.94
	shared_material.metallic = 0.0

func _process(delta: float) -> void:
	# Keep the foundation water centred without rewriting its transform every frame.
	# A two-chunk snap grid preserves coverage while avoiding continuous renderer churn.
	if is_instance_valid(player):
		var player_chunk: Vector2i = world_to_chunk(player.global_position)
		if player_chunk != current_center:
			_set_center(player_chunk)
		_update_water_center(player.global_position)

	_pump_build_queue()
	_refresh_collision_queues()
	_pump_collision_queues()
	_try_emit_spawn()

	if dirty_save:
		save_delay -= delta
		if save_delay <= 0.0:
			_save_world()

func _create_water() -> void:
	# The earlier large transparent, double-sided plane rendered as a moving black
	# dome on the target phone when viewed near sea level. Keep foundation water
	# deliberately simple and opaque until a dedicated mobile water pass exists.
	water = MeshInstance3D.new()
	water.name = "Water"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var plane := PlaneMesh.new()
	plane.size = Vector2(512.0, 512.0)
	water.mesh = plane
	water.position = Vector3(0.0, SEA_LEVEL + 0.54, 0.0)

	var water_material := StandardMaterial3D.new()
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water_material.albedo_color = Color(0.18, 0.48, 0.68, 1.0)
	water_material.roughness = 1.0
	water_material.metallic = 0.0
	water_material.cull_mode = BaseMaterial3D.CULL_BACK
	plane.material = water_material
	add_child(water)
	_update_water_center(Vector3.ZERO)

func _update_water_center(position: Vector3) -> void:
	if not is_instance_valid(water):
		return
	var half_grid := float(WATER_RECENTER_GRID) * 0.5
	var next_grid := Vector2i(
		floori((position.x + half_grid) / float(WATER_RECENTER_GRID)),
		floori((position.z + half_grid) / float(WATER_RECENTER_GRID))
	)
	if next_grid == water_center_grid:
		return
	water_center_grid = next_grid
	water.position.x = float(next_grid.x * WATER_RECENTER_GRID)
	water.position.z = float(next_grid.y * WATER_RECENTER_GRID)
	water_recenter_count += 1

func get_water_stream_metrics() -> Dictionary:
	return {
		"water_recenter_grid": WATER_RECENTER_GRID,
		"water_recenter_count": water_recenter_count,
		"water_grid_x": water_center_grid.x,
		"water_grid_z": water_center_grid.y
	}

func _block_color(block: int, cell: Vector3i, shade: float) -> Color:
	var base_color: Color
	match block:
		BLOCK_GRASS:
			# Top faces are clean green; side and underside faces become earthy.
			base_color = Color(0.34, 0.68, 0.25) if shade >= 0.98 else Color(0.38, 0.48, 0.23)
		BLOCK_DIRT:
			base_color = Color(0.50, 0.34, 0.20)
		BLOCK_STONE:
			base_color = Color(0.56, 0.58, 0.60)
		BLOCK_SAND:
			base_color = Color(0.82, 0.75, 0.54)
		_:
			base_color = Color.WHITE

	var hash_value: int = absi((cell.x * 73856093) ^ (cell.y * 83492791) ^ (cell.z * 19349663))
	var variation: float = 0.97 + float(hash_value % 7) * 0.01
	var factor: float = shade * variation
	return Color(
		clampf(base_color.r * factor, 0.0, 1.0),
		clampf(base_color.g * factor, 0.0, 1.0),
		clampf(base_color.b * factor, 0.0, 1.0),
		1.0
	)

func _face_shade(face_index: int) -> float:
	match face_index:
		0:
			return 1.0
		1:
			return 0.78
		2, 3:
			return 0.92
		_:
			return 0.86

func flush_pending_save(reason: String) -> bool:
	lifecycle_flush_requests += 1
	last_lifecycle_flush_reason = reason
	if not dirty_save:
		return true

	var commits_before := save_commit_count
	var failures_before := save_commit_failures
	_save_world()
	var committed := not dirty_save and save_commit_count > commits_before
	if committed:
		lifecycle_flush_commits += 1
		return true

	if save_commit_failures > failures_before or dirty_save:
		lifecycle_flush_failures += 1
	return false

func _save_world() -> void:
	var payload := JSON.stringify({
		"version": 1,
		"seed": WORLD_SEED,
		"overrides": block_overrides
	})
	_cleanup_transaction_file(SAVE_TEMP_PATH)

	var pending := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if pending == null:
		_record_save_failure("Unable to open pending world save")
		return
	pending.store_string(payload)
	pending.flush()
	pending = null

	if not _validate_pending_save():
		_cleanup_transaction_file(SAVE_TEMP_PATH)
		_record_save_failure("Pending world save failed validation")
		return

	_cleanup_transaction_file(SAVE_ROLLBACK_PATH)
	var primary_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var pending_absolute := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var rollback_absolute := ProjectSettings.globalize_path(SAVE_ROLLBACK_PATH)
	var had_primary := FileAccess.file_exists(SAVE_PATH)

	if had_primary:
		var rollback_error := DirAccess.rename_absolute(primary_absolute, rollback_absolute)
		if rollback_error != OK:
			_cleanup_transaction_file(SAVE_TEMP_PATH)
			_record_save_failure("Unable to stage previous world save")
			return

	var promote_error := DirAccess.rename_absolute(pending_absolute, primary_absolute)
	if promote_error != OK:
		if had_primary and FileAccess.file_exists(SAVE_ROLLBACK_PATH):
			DirAccess.rename_absolute(rollback_absolute, primary_absolute)
		_cleanup_transaction_file(SAVE_TEMP_PATH)
		_record_save_failure("Unable to promote pending world save")
		return

	_cleanup_transaction_file(SAVE_ROLLBACK_PATH)
	dirty_save = false
	save_commit_count += 1

func _validate_pending_save() -> bool:
	var file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	return (
		int(data.get("version", 0)) == 1
		and int(data.get("seed", -1)) == WORLD_SEED
		and data.get("overrides", null) is Dictionary
	)

func _cleanup_transaction_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _record_save_failure(message: String) -> void:
	save_commit_failures += 1
	push_warning(message)

func get_status_text() -> String:
	return "%s\nwater-shifts %d  grid %dm\nsave-commits %d  failures %d\nlifecycle-save %d/%d  failures %d  %s" % [
		super.get_status_text(),
		water_recenter_count,
		WATER_RECENTER_GRID,
		save_commit_count,
		save_commit_failures,
		lifecycle_flush_commits,
		lifecycle_flush_requests,
		lifecycle_flush_failures,
		last_lifecycle_flush_reason
	]
