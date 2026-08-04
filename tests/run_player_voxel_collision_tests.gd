extends SceneTree

const VoxelPlayerMotion = preload("res://src/player/voxel_player_motion.gd")

var _failures: int = 0


class SolidProbe:
	extends RefCounted
	var solids: Dictionary = {}

	func is_solid(voxel: Vector3i) -> bool:
		return solids.has(voxel)


func _init() -> void:
	var probe := SolidProbe.new()
	for y: int in range(0, 2):
		for z: int in range(-1, 2):
			for x: int in range(-1, 2):
				if x == 0 and z == 0:
					continue
				probe.solids[Vector3i(x, y, z)] = true
	var query := Callable(probe, "is_solid")

	var centered: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.5, 2.0, 0.5),
		Vector3(0.0, -1.5, 0.0),
		query
	)
	_expect(is_equal_approx(centered.y, -1.5), "centered player falls straight through a one-block shaft")
	_expect(is_zero_approx(centered.x) and is_zero_approx(centered.z), "straight-down fall keeps the original horizontal column")

	var edge_supported: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.75, 2.0, 0.5),
		Vector3(0.0, -1.5, 0.0),
		query
	)
	_expect(is_zero_approx(edge_supported.y), "off-center player remains supported when the full box does not fit")

	var wall_clipped: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.5, 0.1, 0.5),
		Vector3(0.8, 0.0, 0.0),
		query
	)
	_expect(wall_clipped.x > 0.20 and wall_clipped.x < 0.22, "shaft wall clips horizontal motion without pushing the player outward")
	_expect(is_equal_approx(VoxelPlayerMotion.BODY_WIDTH, 0.58) and is_equal_approx(VoxelPlayerMotion.BODY_HEIGHT, 1.8), "player uses a Minecraft-like axis-aligned box")

	if _failures == 0:
		print("PLAYER_VOXEL_COLLISION_TEST_RESULT PASS")
		quit(0)
	else:
		print("PLAYER_VOXEL_COLLISION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
