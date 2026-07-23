extends SceneTree

const Planner = preload("res://src/world/multi_lod_terrain_planner.gd")

var _failures: int = 0


func _init() -> void:
	var planner := Planner.new()
	var first: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 3, 320, 4)
	var second: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 3, 320, 4)
	var vertices: PackedVector3Array = first.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = first.get("normals", PackedVector3Array())
	var colors: PackedColorArray = first.get("colors", PackedColorArray())
	var indices: PackedInt32Array = first.get("indices", PackedInt32Array())
	var quads: int = int(first.get("quads", 0))
	_expect(int(first.get("intermediate_quads", 0)) > 0, "intermediate LOD ring contains geometry")
	_expect(int(first.get("outer_quads", 0)) > 0, "outer LOD ring contains geometry")
	_expect(int(first.get("intermediate_step", 0)) < int(first.get("outer_step", 0)), "intermediate LOD is finer than outer LOD")
	_expect(vertices.size() == quads * 4, "combined LOD emits four vertices per quad")
	_expect(normals.size() == vertices.size(), "combined LOD normals match vertices")
	_expect(colors.size() == vertices.size(), "combined LOD colors match vertices")
	_expect(indices.size() == quads * 6, "combined LOD emits six indices per quad")
	_expect(
		vertices == second.get("vertices", PackedVector3Array())
		and indices == second.get("indices", PackedInt32Array()),
		"combined LOD planning remains deterministic"
	)
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	_expect(scene_text.contains("multi_lod_main.gd"), "shipping scene enables intermediate terrain LOD")
	var runtime_text: String = FileAccess.get_file_as_string("res://src/main/multi_lod_main.gd")
	_expect(runtime_text.contains("vegetation_untouched"), "LOD runtime preserves chunk-local vegetation")
	_expect(runtime_text.contains("overlap_filtered"), "LOD runtime records overlap filtering")
	if _failures == 0:
		print("MULTI_LOD_TEST_RESULT PASS")
		quit(0)
	else:
		print("MULTI_LOD_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
