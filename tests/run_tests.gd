extends SceneTree

const WorldSeed = preload("res://src/world/world_seed.gd")
const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")

var _failures: int = 0


func _init() -> void:
	_test_world_seed()
	_test_voxel_chunk()
	_test_greedy_mesher()
	_test_kinetic_network()
	_test_product_constraints()

	if _failures == 0:
		print("TEST_RESULT PASS")
		quit(0)
	else:
		print("TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_world_seed() -> void:
	var first: int = WorldSeed.hash_2d(42, 100, -25)
	var second: int = WorldSeed.hash_2d(42, 100, -25)
	var neighbor: int = WorldSeed.hash_2d(42, 101, -25)
	_expect(first == second, "world hash is deterministic")
	_expect(first != neighbor, "neighboring coordinates vary")
	var sample: float = WorldSeed.sample_preview_height(42, 4, 7)
	_expect(sample >= 0.0 and sample <= 1.0, "height sample stays normalized")


func _test_kinetic_network() -> void:
	var network := KineticNetwork.new()
	network.configure_source(20.0, 5.0)
	network.add_consumer(&"press", 2.0, 1.5)
	network.add_consumer(&"belt", -0.5, 1.0)
	var report: Dictionary = network.report()
	_expect(is_equal_approx(float(report.capacity), 100.0), "capacity scales with source RPM")
	_expect(is_equal_approx(float(report.stress), 70.0), "consumer stress uses geared RPM")
	_expect(not bool(report.overstressed), "network remains active under capacity")
	network.add_consumer(&"crusher", 2.0, 2.0)
	_expect(bool(network.report().overstressed), "network reports overload")


func _test_voxel_chunk() -> void:
	var chunk := VoxelChunk.new()
	_expect(chunk.voxels.size() == VoxelChunk.VOLUME, "voxel chunk allocates 32 cubed cells")
	_expect(chunk.set_voxel(Vector3i(2, 3, 4), 7), "voxel mutation succeeds in bounds")
	_expect(chunk.get_voxel(Vector3i(2, 3, 4)) == 7, "voxel mutation round-trips")
	_expect(not chunk.set_voxel(Vector3i(-1, 3, 4), 7), "out-of-bounds mutation is rejected")
	_expect(chunk.get_voxel(Vector3i(-1, 3, 4)) == VoxelChunk.AIR, "out-of-bounds reads are air")
	var generated_a: TeknikVoxelChunk = TerrainGenerator.generate_chunk(99, Vector3i.ZERO)
	var generated_b: TeknikVoxelChunk = TerrainGenerator.generate_chunk(99, Vector3i.ZERO)
	_expect(generated_a.voxels == generated_b.voxels, "voxel terrain is deterministic")
	_expect(generated_a.count_solid() > 0, "voxel terrain contains solid material")


func _test_greedy_mesher() -> void:
	var chunk := VoxelChunk.new()
	chunk.set_voxel(Vector3i(4, 4, 4), 1)
	var single: Dictionary = GreedyMesher.build_mesh(chunk)
	_expect(int(single.quads) == 6, "one voxel produces six greedy quads")
	_expect(int(single.triangles) == 12, "one voxel produces twelve triangles")
	chunk.set_voxel(Vector3i(5, 4, 4), 1)
	var joined: Dictionary = GreedyMesher.build_mesh(chunk)
	_expect(int(joined.quads) == 6, "adjacent equal voxels merge into a cuboid")
	var solid := VoxelChunk.new(1)
	var solid_mesh: Dictionary = GreedyMesher.build_mesh(solid)
	_expect(int(solid_mesh.quads) == 6, "solid chunk collapses to six boundary quads")


func _test_product_constraints() -> void:
	var project_text: String = FileAccess.get_file_as_string("res://project.godot").to_lower()
	_expect(project_text.find("creative") == -1, "project exposes no creative mode")
	_expect(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 30, "physics rate is mobile-budgeted")
	_expect(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "mobile renderer is selected")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
