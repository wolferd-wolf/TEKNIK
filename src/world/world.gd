extends Node3D
class_name World

## Owns all chunk data, streaming, block access, meshing dispatch and persistence.
## Authoritative voxel store: Dictionary[String "cx,cz" -> Chunk].
##
## Streaming pipeline (threaded):
##   main thread            worker threads
##   -----------            --------------
##   gen queue ------> WorkerThreadPool: generate chunk data (pure)
##   data arrives <--- results via mutex-protected dictionaries
##   mesh queue -----> WorkerThreadPool: build meshes from COW snapshots
##   apply to nodes <- results applied on the main thread only

const VIEW_RADIUS := 5          # chunks around player kept rendered
const UNLOAD_RADIUS := VIEW_RADIUS + 2
const DIRTY_MESHES_PER_FRAME := 3
const MAX_GEN_TASKS := 2
const MAX_MESH_TASKS := 2

signal chunk_data_ready(cx: int, cz: int)
signal chunk_unloaded(cx: int, cz: int)

var world_seed: int
var generator: WorldGenerator
var chunks: Dictionary = {}          # "cx,cz" -> Chunk
var chunk_edits: Dictionary = {}     # "cx,cz" -> Dictionary edits (survives unload)
var chunk_nodes: Dictionary = {}     # "cx,cz" -> ChunkNode
var save_dir: String = ""

var _center := Vector2i(9999, 9999)
var _gen_queue: Array[Vector2i] = []
var _time_accum := 0.0
var _mesh_root := Node3D.new()
var _mutex := Mutex.new()
var _gen_tasks := {}      # key -> WorkerThreadPool task id
var _mesh_tasks := {}     # key -> task id
var _gen_done := {}       # key -> Chunk (written by workers)
var _mesh_done := {}      # key -> mesh Dictionary (written by workers)


func _init(p_seed: int = 1, p_save_dir: String = "") -> void:
	world_seed = p_seed
	generator = WorldGenerator.new(world_seed)
	save_dir = p_save_dir
	_mesh_root.name = "MeshRoot"


func _ready() -> void:
	add_child(_mesh_root)


func _exit_tree() -> void:
	_wait_workers()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_wait_workers()


func _wait_workers() -> void:
	# never leave workers touching a dying world
	var gen_ids := _gen_tasks.values()
	var mesh_ids := _mesh_tasks.values()
	_gen_tasks.clear()
	_mesh_tasks.clear()
	for id: int in gen_ids:
		WorkerThreadPool.wait_for_task_completion(id)
	for id: int in mesh_ids:
		WorkerThreadPool.wait_for_task_completion(id)


# ---------------------------------------------------------------- coordinate helpers

static func chunk_key(cx: int, cz: int) -> String:
	return "%d,%d" % [cx, cz]


static func world_to_chunk(w: int) -> int:
	return w >> 4  # arithmetic shift handles negatives; SIZE is 16


static func world_to_local(w: int) -> int:
	return w & 15


# ---------------------------------------------------------------- block access

func get_block(gx: int, gy: int, gz: int) -> int:
	if gy < 0:
		return BlockRegistry.STONE
	if gy >= Chunk.HEIGHT:
		return BlockRegistry.AIR
	var key := chunk_key(world_to_chunk(gx), world_to_chunk(gz))
	var chunk: Chunk = chunks.get(key)
	if chunk == null:
		return BlockRegistry.AIR
	return chunk.get_block(world_to_local(gx), gy, world_to_local(gz))


func set_block(gx: int, gy: int, gz: int, id: int, record := true) -> bool:
	if gy < 1 or gy >= Chunk.HEIGHT:  # bedrock floor untouchable
		return false
	var cx := world_to_chunk(gx)
	var cz := world_to_chunk(gz)
	var key := chunk_key(cx, cz)
	var chunk: Chunk = chunks.get(key)
	if chunk == null or not chunk.generated:
		return false
	var lx := world_to_local(gx)
	var lz := world_to_local(gz)
	if record:
		chunk.edit_block(lx, gy, lz, id)
		_mutex.lock()
		if not chunk_edits.has(key):
			chunk_edits[key] = {}
		chunk_edits[key]["%d,%d,%d" % [lx, gy, lz]] = id
		_mutex.unlock()
	else:
		chunk.set_block(lx, gy, lz, id)
		chunk.dirty_mesh = true
	_mark_mesh_dirty(cx, cz)
	# border edits remesh the adjacent chunk so culled faces update
	if lx == 0:
		_mark_mesh_dirty(cx - 1, cz)
	if lx == Chunk.SIZE - 1:
		_mark_mesh_dirty(cx + 1, cz)
	if lz == 0:
		_mark_mesh_dirty(cx, cz - 1)
	if lz == Chunk.SIZE - 1:
		_mark_mesh_dirty(cx, cz + 1)
	return true


func _mark_mesh_dirty(cx: int, cz: int) -> void:
	var node: ChunkNode = chunk_nodes.get(chunk_key(cx, cz))
	if node != null:
		node.dirty = true
		node.rebuild_now(self)


## Highest non-air, non-water block at column; -1 if chunk missing.
func surface_y(gx: int, gz: int) -> int:
	var key := chunk_key(world_to_chunk(gx), world_to_chunk(gz))
	var chunk: Chunk = chunks.get(key)
	if chunk == null:
		return -1
	var lx := world_to_local(gx)
	var lz := world_to_local(gz)
	for y in range(Chunk.HEIGHT - 1, -1, -1):
		var id := chunk.get_block(lx, y, lz)
		if id != BlockRegistry.AIR and not BlockRegistry.is_liquid(id):
			return y
	return -1


## Voxel DDA raycast against chunk data (works headless, deterministic).
## Returns {pos: Vector3i, normal: Vector3i, id} or empty Dictionary.
func raycast(from: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	if dir.length_squared() < 0.0000001:
		return {}
	var x := floori(from.x)
	var y := floori(from.y)
	var z := floori(from.z)
	var step_x := 1 if dir.x >= 0.0 else -1
	var step_y := 1 if dir.y >= 0.0 else -1
	var step_z := 1 if dir.z >= 0.0 else -1
	var t_delta_x := absf(1.0 / dir.x) if dir.x != 0.0 else INF
	var t_delta_y := absf(1.0 / dir.y) if dir.y != 0.0 else INF
	var t_delta_z := absf(1.0 / dir.z) if dir.z != 0.0 else INF
	var t_max_x := ((float(x) + (1.0 if step_x > 0 else 0.0)) - from.x) / dir.x if dir.x != 0.0 else INF
	var t_max_y := ((float(y) + (1.0 if step_y > 0 else 0.0)) - from.y) / dir.y if dir.y != 0.0 else INF
	var t_max_z := ((float(z) + (1.0 if step_z > 0 else 0.0)) - from.z) / dir.z if dir.z != 0.0 else INF
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_dist:
		var id := get_block(x, y, z)
		if id != BlockRegistry.AIR and not BlockRegistry.is_liquid(id):
			return { "pos": Vector3i(x, y, z), "normal": normal, "id": id }
		if t_max_x < t_max_y and t_max_x < t_max_z:
			x += step_x
			t = t_max_x
			t_max_x += t_delta_x
			normal = Vector3i(-step_x, 0, 0)
		elif t_max_y < t_max_z:
			y += step_y
			t = t_max_y
			t_max_y += t_delta_y
			normal = Vector3i(0, -step_y, 0)
		else:
			z += step_z
			t = t_max_z
			t_max_z += t_delta_z
			normal = Vector3i(0, 0, -step_z)
	return {}


func is_bench_near(pos: Vector3, radius: int = 4) -> bool:
	var px := floori(pos.x)
	var py := floori(pos.y)
	var pz := floori(pos.z)
	for y in range(maxi(0, py - radius), mini(Chunk.HEIGHT, py + radius + 1)):
		for z in range(pz - radius, pz + radius + 1):
			for x in range(px - radius, px + radius + 1):
				if get_block(x, y, z) == BlockRegistry.CRAFTING_BENCH:
					return true
	return false


# ---------------------------------------------------------------- streaming

func update_streaming(player_pos: Vector3, delta: float) -> void:
	_time_accum += delta
	var ccx := world_to_chunk(floori(player_pos.x))
	var ccz := world_to_chunk(floori(player_pos.z))
	var center := Vector2i(ccx, ccz)
	if center != _center or (_gen_queue.is_empty() and _gen_tasks.is_empty() and _time_accum > 1.0):
		_center = center
		_rebuild_gen_queue()
		_time_accum = 0.0
		_unload_far(ccx, ccz)
	_pump()


func pending_chunks() -> int:
	return _gen_queue.size() + _gen_tasks.size()


## Deterministic dry-land spawn near the origin, using pure generation data
## (no chunks required). Falls back to origin for weird seeds.
func find_land_spawn(max_radius: int = 160) -> Vector2i:
	if generator.noise.height_at(0, 0) > Chunk.SEA_LEVEL + 1:
		return Vector2i.ZERO
	for r in range(8, max_radius + 1, 8):
		var steps := maxi(8, r / 2)
		for i in range(steps):
			var ang := TAU * float(i) / float(steps)
			var sx := int(round(cos(ang) * float(r)))
			var sz := int(round(sin(ang) * float(r)))
			if generator.noise.height_at(sx, sz) > Chunk.SEA_LEVEL + 2:
				return Vector2i(sx, sz)
	return Vector2i.ZERO


func _rebuild_gen_queue() -> void:
	_gen_queue.clear()
	var r := VIEW_RADIUS
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + r:
				continue
			var cx := _center.x + dx
			var cz := _center.y + dz
			if not chunks.has(chunk_key(cx, cz)) and not _gen_tasks.has(chunk_key(cx, cz)):
				_gen_queue.push_back(Vector2i(cx, cz))
	_gen_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a.x - _center.x) * (a.x - _center.x) + (a.y - _center.y) * (a.y - _center.y)
		var db := (b.x - _center.x) * (b.x - _center.x) + (b.y - _center.y) * (b.y - _center.y)
		return da < db)


func _unload_far(ccx: int, ccz: int) -> void:
	for key: String in chunks.keys():
		var parts := (key as String).split(",")
		var dx := int(parts[0]) - ccx
		var dz := int(parts[1]) - ccz
		if dx * dx + dz * dz > UNLOAD_RADIUS * UNLOAD_RADIUS:
			chunks.erase(key)
			var node: ChunkNode = chunk_nodes.get(key)
			if node != null:
				node.queue_free()
				chunk_nodes.erase(key)
			chunk_unloaded.emit(int(parts[0]), int(parts[1]))
	for key: String in chunk_nodes.keys():
		var parts := (key as String).split(",")
		var dx := int(parts[0]) - ccx
		var dz := int(parts[1]) - ccz
		if dx * dx + dz * dz > (UNLOAD_RADIUS + 1) * (UNLOAD_RADIUS + 1):
			var node: ChunkNode = chunk_nodes[key]
			node.queue_free()
			chunk_nodes.erase(key)


func _pump() -> void:
	_collect_completed()
	_start_tasks()
	_mesh_dirty_nodes()


## Moves finished worker results onto the main thread.
func _collect_completed() -> void:
	var gens := {}
	var meshes := {}
	_mutex.lock()
	if not _gen_done.is_empty():
		gens = _gen_done.duplicate()
		_gen_done.clear()
	if not _mesh_done.is_empty():
		meshes = _mesh_done.duplicate()
		_mesh_done.clear()
	_mutex.unlock()

	for key: String in gens:
		var id: int = _gen_tasks.get(key, -1)
		_gen_tasks.erase(key)
		if id > 0:
			WorkerThreadPool.wait_for_task_completion(id)
		var chunk: Chunk = gens[key]
		# discard results the player already walked away from
		var parts := (key as String).split(",")
		var dx := int(parts[0]) - _center.x
		var dz := int(parts[1]) - _center.y
		if dx * dx + dz * dz > (UNLOAD_RADIUS + 1) * (UNLOAD_RADIUS + 1):
			continue
		chunks[key] = chunk
		for off in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nnode: ChunkNode = chunk_nodes.get(chunk_key(int(parts[0]) + off.x, int(parts[1]) + off.y))
			if nnode != null:
				nnode.dirty = true
		ensure_node(int(parts[0]), int(parts[1]))
		chunk_data_ready.emit(int(parts[0]), int(parts[1]))

	for key: String in meshes:
		var id: int = _mesh_tasks.get(key, -1)
		_mesh_tasks.erase(key)
		if id > 0:
			WorkerThreadPool.wait_for_task_completion(id)
		var node: ChunkNode = chunk_nodes.get(key)
		if node != null and is_instance_valid(node):
			node.apply_mesh_result(meshes[key])


func _start_tasks() -> void:
	var running_gen := _gen_tasks.size()
	while running_gen < MAX_GEN_TASKS and not _gen_queue.is_empty():
		var coord: Vector2i = _gen_queue.pop_front()
		var key := chunk_key(coord.x, coord.y)
		if chunks.has(key) or _gen_tasks.has(key):
			continue
		_gen_tasks[key] = WorkerThreadPool.add_task(
			_gen_task.bind(coord.x, coord.y, key), false, "gen " + key)
		running_gen += 1

	if _mesh_tasks.size() >= MAX_MESH_TASKS:
		return
	for key: String in chunk_nodes.keys():
		if _mesh_tasks.size() >= MAX_MESH_TASKS:
			break
		if _mesh_tasks.has(key):
			continue
		var node: ChunkNode = chunk_nodes[key]
		if not node.dirty:
			continue
		var chunk: Chunk = chunks.get(key)
		if chunk == null:
			continue
		var job := _make_job_for(chunk)
		_mesh_tasks[key] = WorkerThreadPool.add_task(
			_mesh_task.bind(key, job), false, "mesh " + key)
		node.dirty = false  # an edit during flight re-marks dirty


func _make_job_for(chunk: Chunk) -> ChunkMesher.Job:
	var neighbours := {}
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var c: Chunk = chunks.get(chunk_key(chunk.cx + off.x, chunk.cz + off.y))
		if c != null:
			neighbours[chunk_key(chunk.cx + off.x, chunk.cz + off.y)] = c
	return ChunkMesher.make_job(chunk, neighbours)


func _mesh_dirty_nodes() -> void:
	# synchronous fallback for nodes that missed the task window (e.g. tests, edits)
	var built := 0
	for key: String in chunk_nodes.keys():
		var node: ChunkNode = chunk_nodes[key]
		if not node.dirty or _mesh_tasks.has(key):
			continue
		var chunk: Chunk = chunks.get(key)
		if chunk == null:
			continue
		node.rebuild_now(self)
		built += 1
		if built >= DIRTY_MESHES_PER_FRAME:
			break


# ---------------------------------------------------------------- worker bodies

func _gen_task(cx: int, cz: int, key: String) -> void:
	var chunk := Chunk.new(cx, cz)
	generator.generate_chunk(chunk)
	_mutex.lock()
	if chunk_edits.has(key):
		chunk.edits = (chunk_edits[key] as Dictionary).duplicate()
		chunk.apply_edits()
	_gen_done[key] = chunk
	_mutex.unlock()


func _mesh_task(key: String, job: ChunkMesher.Job) -> void:
	var meshes := ChunkMesher.build_solo_from_job(job)
	var boxes: Array = ChunkMesher.build_collision_boxes(job)
	_mutex.lock()
	_mesh_done[key] = { "m": meshes, "c": boxes }
	_mutex.unlock()


# ---------------------------------------------------------------- nodes

func ensure_node(cx: int, cz: int) -> void:
	var key := chunk_key(cx, cz)
	if chunk_nodes.has(key):
		return
	var node := ChunkNode.new(cx, cz)
	_mesh_root.add_child(node)
	chunk_nodes[key] = node


func node_for(gx: int, gz: int) -> ChunkNode:
	return chunk_nodes.get(chunk_key(world_to_chunk(gx), world_to_chunk(gz)))


# ---------------------------------------------------------------- persistence

## Saves seed + modified chunks. Unmodified chunks regenerate from the seed on load.
func save_to_disk() -> bool:
	if save_dir.is_empty():
		return false
	var da := DirAccess.open("user://")
	if da != null:
		da.make_dir_recursive(save_dir.trim_prefix("user://"))
	var edits_out := {}
	_mutex.lock()
	for key: String in chunk_edits:
		var chunk_edits_map: Dictionary = chunk_edits[key]
		if not chunk_edits_map.is_empty():
			edits_out[key] = chunk_edits_map.duplicate()
	_mutex.unlock()
	var payload := {
		"seed": world_seed,
		"saved_at": int(Time.get_unix_time_from_system()),
		"edits": edits_out,
	}
	var f := FileAccess.open(save_dir.path_join("world.json"), FileAccess.WRITE)
	if f == null:
		push_error("World.save_to_disk: cannot write world.json (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	return true


static func load_metadata(save_dir: String) -> Dictionary:
	var f := FileAccess.open(save_dir.path_join("world.json"), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}


static func restore_from_metadata(save_dir: String) -> World:
	var meta := World.load_metadata(save_dir)
	if meta.is_empty() or not meta.has("seed"):
		return null
	var w := World.new(int(meta["seed"]), save_dir)
	var edits: Dictionary = meta.get("edits", {})
	for key: String in edits:
		var map: Dictionary = edits[key]
		var clean := {}
		for pos_key: String in map:
			clean[pos_key] = int(map[pos_key])
		w.chunk_edits[key] = clean
	return w


static func spawn_drop_at(parent: Node, pos: Vector3, id: int, count: int, durability: int = 0) -> void:
	var drop := ItemDrop.new(id, count, durability)
	parent.add_child(drop)
	drop.global_position = pos + Vector3(0, 0.1, 0)
	drop.launch(Vector3(randf() - 0.5, 2.2, randf() - 0.5) * 0.6)
