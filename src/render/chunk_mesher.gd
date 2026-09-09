extends RefCounted
class_name ChunkMesher

## Builds ArrayMeshes for a chunk: opaque pass, cutout pass (leaves/glass),
## liquid pass (water). Hidden faces are culled using neighbour chunks.
##
## Performance notes:
## - per-id block facts are flattened into lookup tables (no Dictionary access in loops)
## - neighbour resolution reads arrays directly; missing neighbours count as air
## - Godot front faces are CLOCKWISE; indices are emitted accordingly
## - PackedByteArray is copy-on-write, so snapshot jobs share chunk memory safely

const AIR := BlockRegistry.AIR
const STONE := BlockRegistry.STONE

# face order: 0 +x, 1 -x, 2 +y, 3 -y, 4 +z, 5 -z
const FACE_SHADE := [0.8, 0.8, 1.0, 0.55, 0.68, 0.68]
const UV_CORNERS := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]

const TILE_UV_STEP := 1.0 / float(AtlasTiles.COLS * AtlasTiles.TILE_PX)
const TILE_UV_SIZE := float(AtlasTiles.TILE_PX) / float(AtlasTiles.COLS * AtlasTiles.TILE_PX)

static var _atlas_tex: Texture2D
static var _tile_table := PackedInt32Array()   # id*6+face -> tile index
static var _pass_table := PackedInt32Array()   # id -> 0 air, 1 opaque, 2 cutout, 3 liquid
static var _water_flag := PackedByteArray()    # 1 if id is water
static var _corner_table := PackedVector3Array()  # face*4+i
static var _normal_table := PackedVector3Array()  # face
static var _solid_flag := PackedByteArray()       # id -> 1 if collision-solid


static func atlas_texture() -> Texture2D:
	if _atlas_tex == null:
		_atlas_tex = load("res://textures/atlas.png")
	return _atlas_tex


const _CORNER_DATA := [
	[Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)],
]
const _NORMAL_DATA := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
	Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
]


static func _tables_ready() -> bool:
	if not _tile_table.is_empty():
		return true
	_corner_table.resize(24)
	for f in range(6):
		for i in range(4):
			_corner_table[f * 4 + i] = _CORNER_DATA[f][i]
	_normal_table = PackedVector3Array(_NORMAL_DATA)
	var max_id := 0
	for id: int in BlockRegistry.DEFS:
		max_id = maxi(max_id, id)
	_tile_table.resize((max_id + 1) * 6)
	_tile_table.fill(-1)
	_pass_table.resize(max_id + 1)
	_water_flag.resize(max_id + 1)
	for id in range(max_id + 1):
		if not BlockRegistry.DEFS.has(id):
			_pass_table[id] = 0
			_water_flag[id] = 0
			continue
		if BlockRegistry.is_opaque(id):
			_pass_table[id] = 1
		elif BlockRegistry.is_cutout(id):
			_pass_table[id] = 2
		elif BlockRegistry.is_liquid(id):
			_pass_table[id] = 3
		else:
			_pass_table[id] = 0
		_water_flag[id] = 1 if id == BlockRegistry.WATER else 0
		_solid_flag.resize(max_id + 1)
		_solid_flag[id] = 1 if BlockRegistry.is_solid(id) else 0
		for f in range(6):
			_tile_table[id * 6 + f] = BlockRegistry.tile_for(id, f)
	return true


## Collision geometry as greedy-merged world-space AABBs (local to the chunk).
## Convex boxes are robust and fast for CharacterBody3D; concave triangle
## meshes can stall GodotPhysics on voxel-scale data.
static func build_collision_boxes(job: Job) -> Array:
	if not _tables_ready():
		return []
	var blocks := job.own
	var top_y := mini(Chunk.HEIGHT - 1, job.max_y)
	var solid := _solid_flag
	var S := Chunk.SIZE
	var A := S * S
	var visited := PackedByteArray()
	visited.resize((top_y + 1) * A)
	var boxes: Array = []

	for y in range(0, top_y + 1):
		var y_base := y * A
		for lz in range(S):
			var z_base := y_base + lz * S
			for lx in range(S):
				var base := z_base + lx
				if visited[base] == 1:
					continue
				var id0 := blocks[base]
				if id0 == AIR or solid[id0] == 0:
					continue
				visited[base] = 1
				# grow along x
				var x1 := lx
				while x1 + 1 < S:
					var i := z_base + x1 + 1
					if visited[i] == 1 or blocks[i] == AIR or solid[blocks[i]] == 0:
						break
					x1 += 1
					visited[i] = 1
				# grow along z
				var z1 := lz
				while z1 + 1 < S:
					var row_ok := true
					for x in range(lx, x1 + 1):
						var i2 := y_base + (z1 + 1) * S + x
						if visited[i2] == 1 or blocks[i2] == AIR or solid[blocks[i2]] == 0:
							row_ok = false
							break
					if not row_ok:
						break
					for x in range(lx, x1 + 1):
						visited[y_base + (z1 + 1) * S + x] = 1
					z1 += 1
				# grow along y
				var y1 := y
				while y1 + 1 <= top_y:
					var layer_ok := true
					for z in range(lz, z1 + 1):
						for x in range(lx, x1 + 1):
							var i3 := (y1 + 1) * A + z * S + x
							if visited[i3] == 1 or blocks[i3] == AIR or solid[blocks[i3]] == 0:
								layer_ok = false
								break
						if not layer_ok:
							break
					if not layer_ok:
						break
					for z in range(lz, z1 + 1):
						for x in range(lx, x1 + 1):
							visited[(y1 + 1) * A + z * S + x] = 1
					y1 += 1
				boxes.append(AABB(Vector3(lx, y, lz), Vector3(x1 - lx + 1, y1 - y + 1, z1 - lz + 1)))
	return boxes


## Border data for one meshing job. Arrays are COW-shared with the live chunks;
## jobs never write, edits copy-on-write, so no data race occurs.
class Job:
	var own := PackedByteArray()
	var west := PackedByteArray()   # neighbour at cx-1
	var east := PackedByteArray()   # neighbour at cx+1
	var south := PackedByteArray()  # neighbour at cz-1
	var north := PackedByteArray()  # neighbour at cz+1
	var max_y := 0


static func make_job(chunk: Chunk, west_chunks: Dictionary) -> Job:
	## `west_chunks` maps "cx,cz" -> Chunk; may be empty for tests.
	var job := Job.new()
	job.own = chunk.blocks
	job.max_y = chunk.max_y
	job.west = _ref(west_chunks.get(World.chunk_key(chunk.cx - 1, chunk.cz)))
	job.east = _ref(west_chunks.get(World.chunk_key(chunk.cx + 1, chunk.cz)))
	job.south = _ref(west_chunks.get(World.chunk_key(chunk.cx, chunk.cz - 1)))
	job.north = _ref(west_chunks.get(World.chunk_key(chunk.cx, chunk.cz + 1)))
	return job


static func _ref(chunk: Variant) -> PackedByteArray:
	if chunk is Chunk:
		return (chunk as Chunk).blocks
	return PackedByteArray()


static func build(chunk: Chunk, world: World) -> Dictionary:
	if not _tables_ready():
		return {}
	var neighbours := {}
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Chunk = world.chunks.get(World.chunk_key(chunk.cx + off.x, chunk.cz + off.y))
		if c != null:
			neighbours[World.chunk_key(chunk.cx + off.x, chunk.cz + off.y)] = c
	return _build_job(make_job(chunk, neighbours))


## Convenience for pure tests: neighbours treated as air.
static func build_solo(chunk: Chunk) -> Dictionary:
	if not _tables_ready():
		return {}
	return _build_job(make_job(chunk, {}))


## Threaded path: builds from a snapshot job on a worker thread.
static func build_solo_from_job(job: Job) -> Dictionary:
	if not _tables_ready():
		return {}
	return _build_job(job)


static func _build_job(job: Job) -> Dictionary:
	var opaque := _Pass.new()
	var cutout := _Pass.new()
	var liquid := _Pass.new()

	var blocks := job.own
	var top_y := mini(Chunk.HEIGHT - 1, job.max_y)
	var west: PackedByteArray = job.west
	var east: PackedByteArray = job.east
	var south: PackedByteArray = job.south
	var north: PackedByteArray = job.north
	var y_cap := Chunk.HEIGHT
	var tiles := _tile_table
	var pass_tbl := _pass_table

	for y in range(0, top_y + 1):
		var y_base := y * (Chunk.SIZE * Chunk.SIZE)
		for lz in range(Chunk.SIZE):
			var z_base := y_base + lz * Chunk.SIZE
			for lx in range(Chunk.SIZE):
				var id := blocks[z_base + lx]
				if id == AIR:
					continue
				var pt := pass_tbl[id]
				var target := opaque
				if pt == 3:
					target = liquid
				elif pt == 2:
					target = cutout
				var id6 := id * 6
				var tile_top := tiles[id6 + 2]
				var tile_bottom := tiles[id6 + 3]
				var tile_side := tiles[id6]
				var tile_front := tiles[id6 + 4]
				var is_water := _water_flag[id] == 1
				for f in range(6):
					var nid := AIR
					if f == 0:
						if lx == Chunk.SIZE - 1:
							nid = east[Chunk.index_of(0, y, lz)] if east.size() == Chunk.SIZE * Chunk.SIZE * Chunk.HEIGHT else AIR
						else:
							nid = blocks[z_base + lx + 1]
					elif f == 1:
						if lx == 0:
							nid = west[Chunk.index_of(Chunk.SIZE - 1, y, lz)] if west.size() == Chunk.SIZE * Chunk.SIZE * Chunk.HEIGHT else AIR
						else:
							nid = blocks[z_base + lx - 1]
					elif f == 2:
						if y == y_cap - 1:
							nid = AIR
						else:
							nid = blocks[z_base + lx + Chunk.SIZE * Chunk.SIZE]
					elif f == 3:
						if y == 0:
							continue  # bottom of the world is never visible
						nid = blocks[z_base + lx - Chunk.SIZE * Chunk.SIZE]
					elif f == 4:
						if lz == Chunk.SIZE - 1:
							nid = north[Chunk.index_of(lx, y, 0)] if north.size() == Chunk.SIZE * Chunk.SIZE * Chunk.HEIGHT else AIR
						else:
							nid = blocks[z_base + lx + Chunk.SIZE]
					else:
						if lz == 0:
							nid = south[Chunk.index_of(lx, y, Chunk.SIZE - 1)] if south.size() == Chunk.SIZE * Chunk.SIZE * Chunk.HEIGHT else AIR
						else:
							nid = blocks[z_base + lx - Chunk.SIZE]
					# cull: same id hides its inner faces, opaque neighbours hide theirs
					if nid == id:
						continue
					if nid != AIR and pass_tbl[nid] == 1:
						continue
					var tile := tile_side
					if f == 2:
						tile = tile_top
					elif f == 3:
						tile = tile_bottom
					elif f == 4 or f == 5:
						tile = tile_front
					_emit_face(target, f, lx, y, lz, tile, is_water)
	return {
		"opaque": opaque.to_mesh(),
		"cutout": cutout.to_mesh(),
		"liquid": liquid.to_mesh(),
	}


static func _emit_face(pass_target: RefCounted, f: int, lx: int, y: int, lz: int, tile: int, is_water: bool) -> void:
	if tile < 0:
		return
	var verts: PackedVector3Array = pass_target.verts
	var normals: PackedVector3Array = pass_target.normals
	var uvs: PackedVector2Array = pass_target.uvs
	var colors: PackedColorArray = pass_target.colors
	var indices: PackedInt32Array = pass_target.indices

	var col := tile % AtlasTiles.COLS
	var row := int(tile / float(AtlasTiles.COLS))
	var u0 := float(col) * AtlasTiles.TILE_PX * TILE_UV_STEP
	var v0 := float(row) * AtlasTiles.TILE_PX * TILE_UV_STEP

	var start := verts.size()
	var shade: float = FACE_SHADE[f]
	var f4 := f * 4
	# water tops sit slightly below the cell for a visible surface line
	var drop := 0.12 if is_water else 0.0
	var y_base := float(y)
	var ct := _corner_table
	verts.push_back(Vector3(lx + ct[f4].x, y_base + ct[f4].y - (drop if ct[f4].y > 0.5 else 0.0), lz + ct[f4].z))
	verts.push_back(Vector3(lx + ct[f4 + 1].x, y_base + ct[f4 + 1].y - (drop if ct[f4 + 1].y > 0.5 else 0.0), lz + ct[f4 + 1].z))
	verts.push_back(Vector3(lx + ct[f4 + 2].x, y_base + ct[f4 + 2].y - (drop if ct[f4 + 2].y > 0.5 else 0.0), lz + ct[f4 + 2].z))
	verts.push_back(Vector3(lx + ct[f4 + 3].x, y_base + ct[f4 + 3].y - (drop if ct[f4 + 3].y > 0.5 else 0.0), lz + ct[f4 + 3].z))
	var n := _normal_table[f]
	for i in range(4):
		normals.push_back(n)
		var c: Vector2 = UV_CORNERS[i]
		uvs.push_back(Vector2(
			u0 + (c.x * TILE_UV_SIZE * 0.998) + TILE_UV_STEP * 0.001,
			v0 + (c.y * TILE_UV_SIZE * 0.998) + TILE_UV_STEP * 0.001))
		colors.push_back(Color(shade, shade, shade))
	# Godot front faces are clockwise when viewed from outside
	indices.push_back(start)
	indices.push_back(start + 2)
	indices.push_back(start + 1)
	indices.push_back(start)
	indices.push_back(start + 3)
	indices.push_back(start + 2)


class _Pass:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func to_mesh() -> ArrayMesh:
		if verts.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
