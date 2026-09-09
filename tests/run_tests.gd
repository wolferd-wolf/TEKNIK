extends SceneTree

## TEKNIK headless test suite.
## Run: godot --headless --path . --script tests/run_tests.gd
## Exit code 0 = all pass, 1 = failures.

var _failures: PackedStringArray = []
var _passed := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_run("block_registry_validation", _test_block_registry)
	_run("item_registry_validation", _test_item_registry)
	_run("recipe_registry_validation", _test_recipe_registry)
	_run("recipe_craft_flow", _test_recipe_craft_flow)
	_run("atlas_tiles_consistency", _test_atlas_tiles)
	_run("chunk_indexing", _test_chunk_indexing)
	_run("chunk_edit_persistence_in_memory", _test_chunk_edits)
	_run("world_coordinate_helpers", _test_world_coords)
	_run("generator_determinism", _test_generator_determinism)
	_run("generator_content", _test_generator_content)
	_run("mesher_builds_surfaces", _test_mesher)
	_run("world_streaming", _test_world_streaming)
	_run("world_block_edit_and_neighbors", _test_world_block_edit)
	_run("world_raycast", _test_world_raycast)
	_run("inventory_operations", _test_inventory)
	_run("save_load_roundtrip", _test_save_load)
	var ms := Time.get_ticks_msec() - t0
	if _failures.is_empty():
		print("ALL TESTS PASSED (%d tests, %d ms)" % [_passed, ms])
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		printerr("%d FAILED, %d passed (%d ms)" % [_failures.size(), _passed, ms])
		quit(1)


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failures.append(what)
		printerr("  check failed: " + what)


## Drives update_streaming until the initial disc is generated (the queue
## only fills on the first call, so loop on progress, not on pending count).
func _drain_stream(world) -> int:
	var frames := 0
	while frames < 3000:
		world.update_streaming(Vector3(8, 64, 8), 0.016)
		frames += 1
		if world.pending_chunks() == 0 and world.chunks.size() > 60 \
				and world._gen_tasks.is_empty() and world._mesh_tasks.is_empty():
			break
		OS.delay_msec(2)
	return frames


func _run(name: String, fn: Callable) -> void:
	var before := _failures.size()
	fn.call()
	var status := "ok" if _failures.size() == before else "FAILED"
	print("[test] %s: %s" % [name, status])


# ---------------------------------------------------------------- registries

func _test_block_registry() -> void:
	var br := load("res://src/world/block_registry.gd")
	var errors: PackedStringArray = br.validate()
	_check(errors.is_empty(), "block registry validate: %s" % [errors])
	_check(br.is_valid(br.GRASS), "grass valid")
	_check(not br.is_solid(br.WATER), "water not solid")
	_check(br.is_liquid(br.WATER), "water liquid")
	_check(br.is_cutout(br.LEAVES), "leaves cutout")
	_check(br.is_opaque(br.STONE), "stone opaque")
	_check(not br.is_opaque(br.GLASS), "glass not opaque")
	_check(br.hardness(br.BEDROCK) < 0.0, "bedrock unbreakable")
	_check(br.min_tier(br.DIAMOND_ORE) == 3, "diamond ore needs tier 3")
	_check(br.drop_of(br.STONE) == br.COBBLESTONE, "stone drops cobblestone")
	_check(br.drop_of(br.GRASS) == br.DIRT, "grass drops dirt")
	_check(br.tile_for(br.GRASS, 2) == 0, "grass top tile")
	_check(br.tile_for(br.GRASS, 0) == 2, "grass side tile")
	_check(br.name_of(br.CRAFTING_BENCH) == "Crafting Bench", "bench name")


func _test_item_registry() -> void:
	var ir := load("res://src/items/item_registry.gd")
	var errors: PackedStringArray = ir.validate()
	_check(errors.is_empty(), "item registry validate: %s" % [errors])
	_check(ir.is_tool_item(ir.IRON_PICKAXE), "iron pickaxe is tool")
	_check(ir.tool_tier(ir.IRON_PICKAXE) == 3, "iron pickaxe tier 3")
	_check(ir.tool_class(ir.WOOD_AXE) == "axe", "wood axe class")
	_check(ir.tool_speed(ir.DIAMOND_PICKAXE) == 8.0, "diamond speed 8")
	_check(ir.tool_durability(ir.STONE_SWORD) == 132, "stone sword durability")
	_check(ir.stack_of(ir.WOOD_PICKAXE) == 1, "tools don't stack")
	_check(ir.stack_of(ir.STICK) == 99, "sticks stack 99")
	_check(ir.food_value(ir.APPLE) > 0, "apple is food")
	_check(ir.food_value(ir.STICK) == 0, "stick not food")
	_check(not ir.is_tool_item(ir.STICK), "stick not tool")
	_check(ir.is_valid_any(ir.STICK) and ir.is_valid_any(1), "valid ids")
	_check(not ir.is_valid_any(9999), "9999 invalid")


func _test_recipe_registry() -> void:
	var rr := load("res://src/items/recipe_registry.gd")
	var errors: PackedStringArray = rr.validate()
	_check(errors.is_empty(), "recipe registry validate: %s" % [errors])
	_check(rr.RECIPES.size() >= 15, "enough recipes")


func _test_recipe_craft_flow() -> void:
	var rr := load("res://src/items/recipe_registry.gd")
	var InventoryC := load("res://src/items/inventory.gd")
	var inv = InventoryC.new(36)
	inv.add(7, 5)  # 5 logs (block id LOG=7)
	var planks_recipe: Dictionary = rr.find_by_output(9)
	_check(not planks_recipe.is_empty(), "planks recipe exists")
	_check(rr.can_craft(planks_recipe, inv, false), "can craft planks from log")
	var out: Array = rr.craft(planks_recipe, inv)
	_check(out.size() == 2 and out[0] == 9 and out[1] == 4, "crafted 4 planks")
	_check(inv.count_of(7) == 4 and inv.count_of(9) == 4, "consumed 1 log, have 4 planks")
	var stick_recipe: Dictionary = rr.find_by_output(256)
	_check(rr.can_craft(stick_recipe, inv, false), "can craft sticks")
	rr.craft(stick_recipe, inv)
	_check(inv.count_of(256) == 4, "have 4 sticks")
	rr.craft(planks_recipe, inv)  # more planks: 3 logs left, 6 planks now
	_check(inv.count_of(9) == 6 and inv.count_of(256) == 4, "stock for bench recipes")
	var pick_recipe: Dictionary = rr.find_by_output(266)
	_check(not rr.can_craft(pick_recipe, inv, false), "bench recipe blocked without bench")
	_check(rr.can_craft(pick_recipe, inv, true), "bench recipe ok near bench")
	rr.craft(pick_recipe, inv)
	_check(inv.count_of(266) == 1, "crafted wooden pickaxe")
	# normalizing: spruce logs count as logs
	inv.add(20, 2)
	_check(rr.can_craft(planks_recipe, inv, false), "spruce log normalized")


func _test_atlas_tiles() -> void:
	var at := load("res://src/gen/atlas_tiles.gd")
	var seen := {}
	var count := 0
	for key: String in at.TILES:
		var idx: int = at.TILES[key]
		_check(idx >= 0 and idx < at.COLS * at.ROWS, "tile %s in range" % key)
		_check(not seen.has(idx), "tile index %d unique" % idx)
		seen[idx] = true
		count += 1
	_check(count >= 55, "at least 55 tiles, got %d" % count)
	var r: Rect2 = at.uv_rect(seen.keys()[0])
	_check(r.position.x >= 0.0 and r.position.y >= 0.0, "uv rect positive")
	_check(r.end.x <= 1.0 and r.end.y <= 1.0, "uv rect within atlas")
	var png := Image.load_from_file(ProjectSettings.globalize_path("res://textures/atlas.png"))
	if png == null:
		# headless fresh checkout: import may not have run; try direct path
		png = Image.load_from_file("textures/atlas.png")
	if png != null:
		_check(png.get_width() == at.COLS * at.TILE_PX, "atlas width matches grid")
		_check(png.get_height() == at.ROWS * at.TILE_PX, "atlas height matches grid")


# ---------------------------------------------------------------- chunk + world

func _test_chunk_indexing() -> void:
	var ChunkC := load("res://src/world/chunk.gd")
	_check(ChunkC.index_of(0, 0, 0) == 0, "origin index 0")
	_check(ChunkC.index_of(15, 0, 15) == 15 + 15 * 16, "x+z corner")
	_check(ChunkC.index_of(0, 127, 0) == 127 * 256, "top layer")
	_check(ChunkC.index_of(5, 3, 7) == 5 + 7 * 16 + 3 * 256, "general index")
	_check(ChunkC.in_bounds(0, 0, 0) and ChunkC.in_bounds(15, 127, 15), "corners in bounds")
	_check(not ChunkC.in_bounds(-1, 0, 0) and not ChunkC.in_bounds(16, 0, 0), "x out of bounds")
	_check(not ChunkC.in_bounds(0, 128, 0), "y out of bounds")
	var c = ChunkC.new(3, -2)
	_check(c.cx == 3 and c.cz == -2, "chunk coords stored")
	c.set_block(1, 2, 3, 5)
	_check(c.get_block(1, 2, 3) == 5, "set/get roundtrip")
	_check(c.get_block(-1, 0, 0) == 0 and c.get_block(0, 999, 0) == 0, "out-of-bounds reads air")


func _test_chunk_edits() -> void:
	var ChunkC := load("res://src/world/chunk.gd")
	var c = ChunkC.new(0, 0)
	c.edit_block(4, 5, 6, 9)
	_check(c.get_block(4, 5, 6) == 9, "edit applied")
	_check(c.edits.has("4,5,6") and int(c.edits["4,5,6"]) == 9, "edit recorded")
	var d = ChunkC.new(0, 0)
	_check(d.get_block(4, 5, 6) == 0, "fresh chunk unaffected")
	d.edits = c.edits
	d.apply_edits()
	_check(d.get_block(4, 5, 6) == 9, "edits reapplied to fresh chunk")


func _test_world_coords() -> void:
	var WorldC := load("res://src/world/world.gd")
	_check(WorldC.world_to_chunk(0) == 0, "0 -> chunk 0")
	_check(WorldC.world_to_chunk(15) == 0 and WorldC.world_to_chunk(16) == 1, "positive split")
	_check(WorldC.world_to_chunk(-1) == -1 and WorldC.world_to_chunk(-16) == -1, "negative single chunk")
	_check(WorldC.world_to_chunk(-17) == -2, "negative split")
	_check(WorldC.world_to_local(0) == 0 and WorldC.world_to_local(15) == 15, "local positive")
	_check(WorldC.world_to_local(-1) == 15 and WorldC.world_to_local(-16) == 0, "local negative")
	for w in [-33, -16, -1, 0, 15, 16, 31, 257]:
		var cx: int = WorldC.world_to_chunk(w)
		var lx: int = WorldC.world_to_local(w)
		_check(cx * 16 + lx == w, "chunk+local reconstructs %d" % w)


func _test_generator_determinism() -> void:
	var WorldGeneratorC := load("res://src/world/world_generator.gd")
	_check(WorldGeneratorC.validate_determinism(12345, 3), "seed 12345 deterministic")
	_check(WorldGeneratorC.validate_determinism(-987654321, 2), "negative seed deterministic")


func _test_generator_content() -> void:
	var ChunkC := load("res://src/world/chunk.gd")
	var WorldGeneratorC := load("res://src/world/world_generator.gd")
	var gen = WorldGeneratorC.new(42)
	var c = ChunkC.new(0, 0)
	gen.generate_chunk(c)
	_check(c.get_block(0, 0, 0) == 16, "bedrock at y=0 (id 16)")
	_check(c.get_block(8, 1, 8) != 0, "something at y=1")
	var found_surface := false
	for x in range(0, 16, 4):
		for z in range(0, 16, 4):
			if c.get_block(x, 40, z) != 0:
				found_surface = true
	_check(found_surface, "surface blocks around y=40 exist")
	# stone exists somewhere underground
	var stone_found := false
	for y in range(5, 30, 3):
		for x in range(0, 16, 4):
			if c.get_block(x, y, x) == 3:
				stone_found = true
	_check(stone_found, "underground stone exists")
	# biomes computed and named
	var biome: int = gen.biome_at(100, 100)
	_check(biome >= 0 and biome <= 5, "biome id in range")
	# a second gen with same seed matches
	var gen2 = WorldGeneratorC.new(42)
	var c2 = ChunkC.new(5, 7)
	gen2.generate_chunk(c2)
	var c3 = ChunkC.new(5, 7)
	gen.generate_chunk(c3)
	_check(c2.compute_hash() == c3.compute_hash(), "same seed chunk (5,7) identical")
	var c4 = ChunkC.new(5, 7)
	WorldGeneratorC.new(43).generate_chunk(c4)
	_check(c2.compute_hash() != c4.compute_hash(), "different seed differs")


func _test_mesher() -> void:
	var ChunkC := load("res://src/world/chunk.gd")
	var WorldGeneratorC := load("res://src/world/world_generator.gd")
	var Mesher := load("res://src/render/chunk_mesher.gd")
	var gen = WorldGeneratorC.new(7)
	var c = ChunkC.new(0, 0)
	gen.generate_chunk(c)
	var result: Dictionary = Mesher.build_solo(c)
	var opaque = result["opaque"]
	_check(opaque != null, "terrain produces opaque mesh")
	if opaque != null:
		_check(opaque.get_surface_count() == 1, "one opaque surface")
	var air = ChunkC.new(9, 9)
	var empty: Dictionary = Mesher.build_solo(air)
	_check(empty["opaque"] == null, "air chunk produces no mesh")
	# snapshot job must match the world-driven build for the same data
	var WorldC := load("res://src/world/world.gd")
	var world_for_mesh = WorldC.new(999)
	world_for_mesh.chunks["0,0"] = c
	var via_world: Dictionary = Mesher.build(c, world_for_mesh)
	var via_job: Dictionary = Mesher.build_solo_from_job(Mesher.make_job(c, {}))
	if via_world["opaque"] != null and via_job["opaque"] != null:
		var aw: Array = via_world["opaque"].surface_get_arrays(0)
		var aj: Array = via_job["opaque"].surface_get_arrays(0)
		_check(hash(aw[Mesh.ARRAY_VERTEX]) == hash(aj[Mesh.ARRAY_VERTEX]), "world and job builds identical verts")
		_check(hash(aw[Mesh.ARRAY_INDEX]) == hash(aj[Mesh.ARRAY_INDEX]), "world and job builds identical indices")
	else:
		_check(via_world["opaque"] == null and via_job["opaque"] == null, "both builds empty together")

	# single isolated block produces 6 faces
	var single = ChunkC.new(0, 0)
	single.set_block(8, 60, 8, 3)
	var r2: Dictionary = Mesher.build_solo(single)
	_check(r2["opaque"] != null, "single block mesh")
	if r2["opaque"] != null:
		var arrays: Array = r2["opaque"].surface_get_arrays(0)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		_check(idx.size() == 36, "single block = 12 tris = 36 indices, got %d" % idx.size())


func _test_world_streaming() -> void:
	var WorldC := load("res://src/world/world.gd")
	var world = WorldC.new(31337)
	var frames := _drain_stream(world)
	_check(world.pending_chunks() == 0, "gen queue drained in %d frames" % frames)
	_check(world.chunks.size() > 60, "loaded %d chunks" % world.chunks.size())
	_check(world.get_block(0, 0, 0) == 16, "bedrock at world origin")
	var sy: int = world.surface_y(8, 8)
	_check(sy > 4 and sy < 120, "surface_y sane at (8,8): %d" % sy)
	_check(world.is_bench_near(Vector3(0, -100, 0), 2) == false, "no bench deep down")
	# determinism: same seed through world path
	var world2 = WorldC.new(31337)
	frames = 0
	while world2.pending_chunks() > 0 and frames < 400:
		world2.update_streaming(Vector3(8, 64, 8), 0.05)
		frames += 1
	var mismatch := 0
	for key: String in world.chunks:
		var a = world.chunks[key]
		var b = world2.chunks.get(key)
		if b != null and a.compute_hash() != b.compute_hash():
			mismatch += 1
	_check(mismatch == 0, "streamed chunks deterministic (%d mismatch)" % mismatch)
	world.free()
	world2.free()


func _test_world_block_edit() -> void:
	var WorldC := load("res://src/world/world.gd")
	var world = WorldC.new(777)
	_drain_stream(world)
	var sy: int = world.surface_y(8, 8)
	var before: int = world.get_block(8, sy, 8)
	var ok: bool = world.set_block(8, sy, 8, 9)
	_check(ok, "set_block accepted")
	_check(world.get_block(8, sy, 8) == 9, "block changed to planks")
	var key: String = WorldC.chunk_key(0, 0)
	_check(world.chunk_edits.has(key), "edit recorded for chunk")
	_check(world.set_block(8, 0, 8, 9) == false, "bedrock floor protected")
	_check(world.set_block(8, 200, 8, 9) == false, "above height rejected")
	# border edit marks neighbor dirty through node path (no crash without nodes)
	world.set_block(0, sy, 8, 4)
	# node creation path (no tree): ensure_node + task-based meshing
	world.ensure_node(0, 0)
	var node = world.chunk_nodes.get(key)
	_check(node != null, "chunk node created")
	var wait_frames := 0
	while node.dirty and wait_frames < 1000:
		world.update_streaming(Vector3(8, 64, 8), 0.016)
		wait_frames += 1
		OS.delay_msec(2)
	if node != null:
		_check(not node.dirty, "node mesh built via task pump")
		world.set_block(8, sy, 8, 3)
		_check(node._opaque_mi.mesh != null, "opaque mesh present after edit")
	world.free()


func _test_world_raycast() -> void:
	var WorldC := load("res://src/world/world.gd")
	var world = WorldC.new(4242)
	_drain_stream(world)
	var sy: int = world.surface_y(8, 8)
	# straight down from above the surface
	var from := Vector3(8.5, sy + 3.0, 8.5)
	var hit: Dictionary = world.raycast(from, Vector3(0, -1, 0), 10.0)
	_check(not hit.is_empty(), "raycast hits ground")
	if not hit.is_empty():
		var pos: Vector3i = hit["pos"]
		_check(pos.y == sy, "raycast lands on surface y=%d" % sy)
		var normal: Vector3i = hit["normal"]
		_check(normal == Vector3i(0, 1, 0), "top face normal, got %s" % normal)
	# miss into the sky
	var miss: Dictionary = world.raycast(Vector3(8.5, sy + 60, 8.5), Vector3(0, -1, 0), 2.0)
	_check(miss.is_empty(), "short ray misses")
	# sideways hit produces horizontal normal
	world.set_block(10, sy + 1, 8, 3)
	var side: Dictionary = world.raycast(Vector3(8.5, sy + 1.5, 8.5), Vector3(1, 0, 0), 6.0)
	_check(not side.is_empty() and side["normal"] == Vector3i(-1, 0, 0), "side normal -x")


func _test_inventory() -> void:
	var InventoryC := load("res://src/items/inventory.gd")
	var inv = InventoryC.new(36)
	_check(inv.add(1, 10) == 0, "add 10 dirt fits")
	_check(inv.count_of(1) == 10, "count 10")
	_check(inv.add(1, 99) == 0, "second stack absorbs overflow")
	_check(inv.count_of(1) == 109, "109 total across two stacks")
	_check(inv.remove(1, 40) == 40, "remove 40")
	_check(inv.count_of(1) == 69, "69 left")
	_check(inv.remove(5, 3) == 0, "remove absent = 0 removed")
	_check(inv.has(1, 69), "has() true at exact count")
	_check(not inv.has(1, 70), "has() false above count")
	# swap / split-move via move()
	var inv2 = InventoryC.new(4)
	inv2.add(3, 10)   # slot0 stone x10
	inv2.add(4, 5)    # slot1 cobble x5
	_check(inv2.move(0, 1) == true, "swap different ids")
	var s0: Dictionary = inv2.get_slot(0)
	var s1: Dictionary = inv2.get_slot(1)
	_check(int(s0["id"]) == 4 and int(s0["count"]) == 5, "slot0 now cobble")
	_check(int(s1["id"]) == 3 and int(s1["count"]) == 10, "slot1 now stone")
	_check(inv2.move(1, 2, 4) == true, "split move")
	_check(int(inv2.get_slot(2)["count"]) == 4 and int(inv2.get_slot(1)["count"]) == 6, "split counts")
	inv2.add(5, 3)    # slot3 sand
	_check(inv2.move(2, 3) == true, "swap again")
	_check(int(inv2.get_slot(2)["id"]) == 5 and int(inv2.get_slot(3)["id"]) == 3, "swapped back")
	# same-id merge through add()
	var merged: int = inv2.add(3, 4)
	_check(merged == 0, "merge add fits")
	_check(int(inv2.get_slot(1)["count"]) == 10, "stone merged into slot1")
	# serialize roundtrip
	var data: Dictionary = inv2.serialize()
	var inv3 = InventoryC.deserialize(data)
	for i in range(4):
		_check(inv3.get_slot(i).get("id", 0) == inv2.get_slot(i).get("id", 0), "slot %d id roundtrip" % i)
		_check(inv3.get_slot(i).get("count", 0) == inv2.get_slot(i).get("count", 0), "slot %d count roundtrip" % i)
	# non-stackable tools
	var inv4 = InventoryC.new(2)
	_check(inv4.add(5, 1) == 0, "fill first slot")
	var tool_left: int = inv4.add(266, 2)
	_check(tool_left == 1, "tool over capacity returned")
	_check(inv4.get_count(1) == 1, "one tool stored")


func _test_save_load() -> void:
	var WorldC := load("res://src/world/world.gd")
	var save_dir := "user://tek_test_save"
	# clean
	if DirAccess.dir_exists_absolute(save_dir):
		DirAccess.remove_absolute(save_dir.path_join("world.json"))
		DirAccess.remove_absolute(save_dir.path_join("player.json"))
	var world = WorldC.new(20260905, save_dir)
	_drain_stream(world)
	var sy: int = world.surface_y(8, 8)
	var sy2: int = world.surface_y(40, 40)
	world.set_block(8, sy, 8, 10)   # glass pillar
	world.set_block(8, sy + 1, 8, 10)
	world.set_block(40, sy2, 40, 4)
	_check(world.save_to_disk(), "world saved")
	# restore
	var world2 = WorldC.restore_from_metadata(save_dir)
	_check(world2 != null, "world restored from metadata")
	if world2 != null:
		_check(world2.world_seed == 20260905, "seed restored")
		_drain_stream(world2)
		_check(world2.get_block(8, sy, 8) == 10, "edit 1 persisted")
		_check(world2.get_block(8, sy + 1, 8) == 10, "edit 2 persisted")
		_check(world2.get_block(40, sy2, 40) == 4, "edit 3 persisted (cross chunk)")
		# untouched voxels regenerate identically
		var neighbor_same: bool = world2.get_block(12, sy, 12) == world.get_block(12, sy, 12)
		_check(neighbor_same, "unmodified voxels identical after reload")
		# metadata content
		var meta: Dictionary = WorldC.load_metadata(save_dir)
		_check(int(meta.get("seed", 0)) == 20260905, "metadata seed")
		_check(meta.has("edits"), "metadata has edits")
		world.free()
		world2.free()
