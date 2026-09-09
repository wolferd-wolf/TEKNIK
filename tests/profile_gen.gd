extends SceneTree

## Profiles generation vs meshing cost for one chunk.

func _initialize() -> void:
	var WorldC := load("res://src/world/world.gd")
	var world = WorldC.new(31337)
	var ChunkC := load("res://src/world/chunk.gd")

	var t0 := Time.get_ticks_usec()
	for i in range(8):
		var c = ChunkC.new(i, 0)
		world.generator.generate_chunk(c)
	var gen_us := (Time.get_ticks_usec() - t0) / 8

	var chunk = ChunkC.new(0, 0)
	world.generator.generate_chunk(chunk)
	var t1 := Time.get_ticks_usec()
	var mesher = load("res://src/render/chunk_mesher.gd")
	var result: Dictionary = mesher.build(chunk, world)
	var mesh_us := Time.get_ticks_usec() - t1
	var tris := 0
	var t2 := Time.get_ticks_usec()
	var point_count := 0
	var opaque: ArrayMesh = result["opaque"]
	if opaque != null:
		var arrays: Array = opaque.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx2: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		tris = idx2.size() / 3
		var points := PackedVector3Array()
		for j in range(0, idx2.size(), 3):
			points.push_back(verts[idx2[j]])
			points.push_back(verts[idx2[j + 1]])
			points.push_back(verts[idx2[j + 2]])
		point_count = points.size()
	var col_us := Time.get_ticks_usec() - t2
	print("gen: %d us/chunk | mesh: %d us (%d tris) | collision build: %d us (%d pts)" % [
		gen_us, mesh_us, tris, col_us, point_count])
	quit(0)
