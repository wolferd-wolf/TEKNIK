extends SceneTree

const WorldSeed = preload("res://src/world/world_seed.gd")
const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")

var _failures: int = 0


func _init() -> void:
	_test_world_seed()
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

