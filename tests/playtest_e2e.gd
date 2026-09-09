extends SceneTree

## Automated full playtest (gauntlet section 28): drives the real player
## interaction paths end to end in headless mode.
## Run: godot --headless --path . --script tests/playtest_e2e.gd

var _frames := 0
var _main: Node
var _session: GameWorld
var _stage := "boot"
var _stage_frame := 0
var _failed := false
var _bookmarks := {}
var _checkpoint := {}


func _initialize() -> void:
	_main = (load("res://src/main.gd") as GDScript).new()
	root.add_child(_main)
	process_frame.connect(_tick)


func _fail(msg: String) -> void:
	printerr("[e2e] FAIL at stage '%s': %s" % [_stage, msg])
	_failed = true
	quit(1)


func _pass_stage(next: String) -> void:
	print("[e2e] ok: %s" % _stage)
	_stage = next
	_stage_frame = 0


func _player() -> Player:
	return _session.player if _session != null else null


func _drops() -> Array:
	var out := []
	for c in _session.get_children():
		if c is ItemDrop:
			out.append(c)
	return out


func _mobs() -> Array:
	return get_nodes_in_group("mobs") if _session != null else []


func _tick() -> void:
	_frames += 1
	_stage_frame += 1
	if _failed:
		return
	if _stage_frame > 4000:
		_fail("stage timeout")
		return

	match _stage:
		"boot":
			if _frames == 10:
				_main._start_session(0, false)  # fresh world, wipes slot
				_pass_stage("wait_session")
		"wait_session":
			if _main._current != null:
				_session = _main._current
				_pass_stage("wait_spawn")
		"wait_spawn":
			if _session._spawned and _session.world.pending_chunks() == 0:
				if _player() == null:
					_fail("player missing")
					return
				_bookmarks["home"] = _player().global_position
				_pass_stage("look_around")
		"look_around":
			# rotate view and pitch down
			var p := _player()
			p.rotation.y = 0.0
			p.set_pitch(-1.4)  # look down at feet
			var hit: Dictionary = _session.world.raycast(p.camera_position(), p.camera_forward(), 4.6)
			if hit.is_empty():
				_fail("cannot see ground beneath feet")
				return
			_bookmarks["ground"] = hit["pos"]
			_pass_stage("walk")
		"walk":
			var p := _player()
			if _stage_frame == 1:
				_bookmarks["walk_start"] = p.global_position
				Input.action_press("move_forward")
			var moved: float = p.global_position.distance_to(_bookmarks["walk_start"])
			if moved >= 1.5:
				Input.action_release("move_forward")
				print("[e2e] walked %.2f m" % moved)
				_pass_stage("jump")
			elif _stage_frame > 300:
				Input.action_release("move_forward")
				_fail("walk moved only %.2f m in 300 frames" % moved)
		"jump":
			var p := _player()
			# only jump from solid ground; if the walk ended over water/air,
			# return to the known-good spawn column first
			if not bool(_bookmarks.get("jump_armed", false)):
				if not p.is_on_floor():
					if _stage_frame == 120:
						p.global_position = _bookmarks["home"]
						p.velocity = Vector3.ZERO
					if _stage_frame > 360:
						_fail("player never settled on floor before jump")
					return
				_bookmarks["jump_armed"] = true
				_bookmarks["jump_frame"] = _stage_frame
				_bookmarks["jump_y"] = p.global_position.y
				_bookmarks["jump_peak"] = p.global_position.y
				_bookmarks["jump_air"] = false
				Input.action_press("jump")
				return
			# armed: track the arc; success = peak lift, measured whenever
			# the body is seen airborne then grounded again (or timeout)
			if not p.is_on_floor():
				_bookmarks["jump_air"] = true
			_bookmarks["jump_peak"] = maxf(float(_bookmarks["jump_peak"]), p.global_position.y)
			var elapsed: int = _stage_frame - int(_bookmarks["jump_frame"])
			if (bool(_bookmarks["jump_air"]) and p.is_on_floor()) or elapsed > 90:
				Input.action_release("jump")
				_bookmarks["jump_armed"] = false
				var lift: float = float(_bookmarks["jump_peak"]) - float(_bookmarks["jump_y"])
				if lift < 0.25:
					_fail("jump lifted only %.2f m" % lift)
					return
				print("[e2e] jump lifted %.2f m" % lift)
				_pass_stage("break_block")
		"break_block":
			# aim straight down at whatever is underfoot now and hold mine
			var p := _player()
			p.set_pitch(-1.5)
			if _stage_frame == 1:
				var hit0: Dictionary = _session.world.raycast(p.camera_position(), p.camera_forward(), 4.6)
				if hit0.is_empty():
					_fail("nothing underfoot to mine")
					return
				_bookmarks["mine_target"] = hit0["pos"]
				p.touch_mining = true
			var t: Vector3i = _bookmarks.get("mine_target", Vector3i.ZERO)
			if _session.world.get_block(t.x, t.y, t.z) == 0:
				p.touch_mining = false
				print("[e2e] broke block %s by mining" % t)
				_pass_stage("collect_drop")
			elif _stage_frame > 600:
				_fail("mining never broke %s (progress %.2f)" % [t, p._break_progress])
		"collect_drop":
			# the drop spawns underfoot and may be picked up within a frame or two,
			# so success is either a live drop or the item already in the inventory
			var p := _player()
			var drops := _drops()
			if not drops.is_empty():
				var d: ItemDrop = drops[0]
				d.global_position = p.global_position + Vector3(0, 0.5, 0)
				d._cooldown = 0.0
			if p.inventory.count_of(BlockRegistry.DIRT) > 0 or p.inventory.count_of(ItemRegistry.STICK) > 0:
				print("[e2e] mining drop collected (dirt=%d stick=%d)" % [
					p.inventory.count_of(BlockRegistry.DIRT), p.inventory.count_of(ItemRegistry.STICK)])
				_pass_stage("craft")
			elif drops.is_empty() and _stage_frame > 240:
				_fail("no drop and nothing collected after mining")
		"craft":
			var p := _player()
			p.inventory.add(BlockRegistry.LOG, 3)
			var rr = load("res://src/items/recipe_registry.gd")
			var planks: Dictionary = rr.find_by_output(BlockRegistry.PLANKS)
			var sticks: Dictionary = rr.find_by_output(ItemRegistry.STICK)
			var pick: Dictionary = rr.find_by_output(ItemRegistry.WOOD_PICKAXE)
			while rr.can_craft(planks, p.inventory, false):
				rr.craft(planks, p.inventory)
			rr.craft(sticks, p.inventory)
			if not rr.can_craft(pick, p.inventory, true):
				_fail("cannot craft pickaxe after preparing materials")
				return
			rr.craft(pick, p.inventory)
			if p.inventory.count_of(ItemRegistry.WOOD_PICKAXE) != 1:
				_fail("pickaxe not in inventory")
				return
			_pass_stage("equip_tool")
		"equip_tool":
			var p := _player()
			for i in range(9):
				if p.inventory.get_id(i) == ItemRegistry.WOOD_PICKAXE:
					p.hotbar_index = i
					break
			if p.held_item().get("id", 0) != ItemRegistry.WOOD_PICKAXE:
				_fail("held item is not the pickaxe")
				return
			_pass_stage("mine_stone")
		"mine_stone":
			# conjure a stone block on the crosshair ray, then mine it.
			# arm late (camera lerp / fall settle); re-place only until mining
			# starts, so the stage cannot resurrect a stone it already broke.
			var p := _player()
			var t: Vector3i = _bookmarks.get("stone", Vector3i(1 << 20, 1 << 20, 1 << 20))
			var placed: bool = _bookmarks.has("stone_placed")
			if placed and _session.world.get_block(t.x, t.y, t.z) == BlockRegistry.AIR:
				p.touch_mining = false
				print("[e2e] stone broken by mining")
				_pass_stage("mine_wait")
				return
			var mining: bool = bool(_bookmarks.get("stone_mining", false))
			var hit: Dictionary = _session.world.raycast(p.camera_position(), p.camera_forward(), 4.6)
			var aligned: bool = not hit.is_empty() and hit["pos"] == t
			var last: int = int(_bookmarks.get("stone_placed", -1000))
			var settled: bool = p.is_on_floor() and p.velocity.length_squared() < 0.0001 \
					and absf(p.camera_position().y - (p.global_position.y + p.EYE_HEIGHT)) < 0.05
			if not aligned and not mining and settled and _stage_frame >= 20 and _stage_frame - last >= 30:
				p.set_pitch(-0.5)
				var eye: Vector3 = p.camera_position()
				var fwd: Vector3 = p.camera_forward()
				for d: float in [0.7, 1.1, 1.5, 1.9]:
					var c := eye + fwd * d
					_session.world.set_block(floori(c.x), floori(c.y), floori(c.z), BlockRegistry.AIR)
				var aim := eye + fwd * 2.0
				t = Vector3i(floori(aim.x), floori(aim.y), floori(aim.z))
				_session.world.set_block(t.x, t.y, t.z, BlockRegistry.STONE)
				_bookmarks["stone"] = t
				_bookmarks["stone_placed"] = _stage_frame
				hit = _session.world.raycast(eye, fwd, 4.6)
				aligned = not hit.is_empty() and hit["pos"] == t
			if aligned or mining:
				_bookmarks["stone_mining"] = true
				p.touch_mining = true
			else:
				if _stage_frame > 150:
					_fail("stone %s not visible for mining (hit %s)" % [t, hit.get("pos", "none")])
				return
			if _stage_frame > 400:
				_fail("stone never broke (progress %.2f)" % p._break_progress)
		"mine_wait":
			# cobble drop spawns ~1.6 m ahead -> magnet range -> auto pickup
			var p := _player()
			if p.inventory.count_of(BlockRegistry.COBBLESTONE) > 0:
				print("[e2e] mined stone with pickaxe -> cobblestone collected")
				_pass_stage("place_block")
			elif _stage_frame > 300:
				_fail("stone broke but no cobble collected")
		"place_block":
			var p := _player()
			p.touch_mining = false
			# hold planks in the hotbar
			if not _bookmarks.has("place_before"):
				var slot := -1
				for i in range(9):
					if p.inventory.get_id(i) == BlockRegistry.PLANKS:
						slot = i
				if slot == -1:
					p.inventory.add(BlockRegistry.PLANKS, 4)
					slot = 0
					# add() may stack elsewhere; move to slot 0 if needed
					if p.inventory.get_id(0) != BlockRegistry.PLANKS:
						for i in range(9):
							if p.inventory.get_id(i) == BlockRegistry.PLANKS:
								p.inventory.move(i, 0)
								break
				p.hotbar_index = slot
				if p.held_item().get("id", 0) != BlockRegistry.PLANKS:
					var dump := []
					for i in range(9):
						dump.append(p.inventory.get_id(i))
					_fail("could not hold planks (slots=%s held=%s)" % [dump, p.held_item()])
					return
				_bookmarks["place_before"] = _count_blocks(BlockRegistry.PLANKS)
			if _count_blocks(BlockRegistry.PLANKS) > int(_bookmarks["place_before"]):
				p.touch_placing = false
				print("[e2e] block placed")
				_pass_stage("explore")
				return
			# (re)aim: find a pitch whose face-adjacent target is free and
			# does not overlap the player capsule
			if _stage_frame % 60 == 1:
				for pitch: float in [-0.7, -0.85, -1.0, -1.15, -1.3]:
					p.set_pitch(pitch)
					var h := _session.world.raycast(p.camera_position(), p.camera_forward(), 4.6)
					if h.is_empty():
						continue
					var tgt: Vector3i = h["pos"] + h["normal"]
					if _session.world.get_block(tgt.x, tgt.y, tgt.z) != BlockRegistry.AIR:
						continue
					var pbox := AABB(Vector3(tgt) + Vector3(0.08, 0.08, 0.08), Vector3(0.84, 0.84, 0.84))
					if AABB(p.global_position + Vector3(-0.3, 0, -0.3), Vector3(0.6, 1.8, 0.6)).intersects(pbox):
						continue
					break
			p.touch_placing = true
			if _stage_frame > 400:
				p.touch_placing = false
				var dh: Dictionary = _session.world.raycast(p.camera_position(), p.camera_forward(), 4.6)
				_fail("placement never succeeded (hit=%s held=%s pos=%s)" % [dh.get("pos", "none"), p.held_item(), p.global_position])
		"explore":
			# teleport far, let streaming follow, come back, verify regeneration
			var p := _player()
			if _stage_frame == 1:
				_bookmarks["home"] = p.global_position
				_checkpoint["origin_hash"] = _region_hash(0, 0)
				p.global_position = Vector3(512.5, 80.0, 512.5)
			# hover frozen while the far region streams in (no fall damage/tunneling)
			p.velocity = Vector3.ZERO
			p.global_position.y = 80.0
			var far_loaded: bool = _session.world.pending_chunks() == 0 \
					and _session.world.chunks.has(_session.world.chunk_key(32, 32)) \
					and _session.world.chunks.size() > 60
			if far_loaded:
				var sy: int = _session.world.surface_y(512, 512)
				print("[e2e] streamed far region, surface y=%d" % sy)
				p.global_position = _bookmarks["home"]
				_pass_stage("return_check")
		"return_check":
			if _session.world.pending_chunks() == 0:
				var h := _region_hash(0, 0)
				if h != int(_checkpoint["origin_hash"]):
					_fail("home region changed after round trip")
					return
				print("[e2e] home region identical after 512-block round trip")
				_pass_stage("save_quit")
		"save_quit":
			var p := _player()
			var sy: int = _session.world.surface_y(floori(p.global_position.x), floori(p.global_position.z))
			if sy >= 0 and absf(p.global_position.y - float(sy)) > 6.0:
				p.global_position.y = float(sy) + 1.05  # settle before saving
			if not _session.save_all():
				_fail("save_all failed")
				return
			_bookmarks["saved_pos"] = p.global_position
			_bookmarks["saved_blocks"] = _count_blocks(BlockRegistry.PLANKS)
			_session.queue_free()
			_session = null
			_pass_stage("relaunch")
		"relaunch":
			if _stage_frame < 30:
				return  # let the old session free
			_main._current = null
			_main._start_session(0, true)  # restore
			_pass_stage("load_verify")
		"load_verify":
			if _main._current == null:
				return
			_session = _main._current
			if not _session._spawned:
				return
			var p := _player()
			var pos_ok: bool = p.global_position.distance_to(_bookmarks["saved_pos"]) < 2.0
			var blocks_ok: bool = _count_blocks(BlockRegistry.PLANKS) >= int(_bookmarks["saved_blocks"])
			if not pos_ok:
				if _stage_frame > 600:
					_fail("player position not restored (%s vs %s)" % [p.global_position, _bookmarks["saved_pos"]])
				return
			if not blocks_ok:
				# edits re-apply as chunks regenerate (threaded); give it time
				if _stage_frame > 600:
					_fail("placed blocks not persisted")
				return
			print("[e2e] save/load verified (pos + placed blocks)")
			_pass_stage("day_night")
		"day_night":
			var dn: DayNight = _session.day_night
			dn.time_of_day = 0.25
			if not dn.is_day():
				_fail("0.25 should be day")
				return
			dn.time_of_day = 0.75
			if not dn.is_night():
				_fail("0.75 should be night")
				return
			print("[e2e] day/night cycle verified")
			_pass_stage("mobs")
		"mobs":
			var p := _player()
			if _mobs().is_empty():
				if _stage_frame == 1:
					var tuft := Tuft.new()
					_session.add_child(tuft)
					tuft.global_position = p.global_position + Vector3(3, 0.5, 0)
				if _stage_frame > 400:
					_fail("mob never spawned/appeared")
				return
			# any mob with horizontal velocity proves AI + physics are alive
			var moving := false
			for m in _mobs():
				var mb := m as MobBase
				if mb != null and Vector2(mb.velocity.x, mb.velocity.z).length() > 0.2:
					moving = true
					break
			if not moving:
				if _stage_frame > 600:
					_fail("no mob ever moved (n=%d)" % _mobs().size())
				return
			print("[e2e] mob movement verified (n=%d)" % _mobs().size())
			# hostile behaviour: spawn a Grimb at night next to the player
			var grimb := Grimb.new()
			_session.add_child(grimb)
			grimb.global_position = p.global_position + Vector3(2, 0.5, 0)
			_session.day_night.time_of_day = 0.75
			_pass_stage("mob_combat")
		"mob_combat":
			var p := _player()
			var grimbs := []
			for m in _mobs():
				if m is Grimb:
					grimbs.append(m)
			if grimbs.is_empty():
				_fail("grimb missing")
				return
			var g := grimbs[0] as Grimb
			g.global_position = p.global_position + Vector3(0.8, 0.3, 0)
			if p.health < Player.MAX_HEALTH:
				print("[e2e] hostile mob attacked player (hp %.0f)" % p.health)
				_pass_stage("kill_mob")
			elif _stage_frame > 400:
				_fail("grimb never attacked")
		"kill_mob":
			var grimbs := []
			for m in _mobs():
				if m is Grimb:
					grimbs.append(m)
			if grimbs.is_empty():
				print("[e2e] mob died and dropped")
				_pass_stage("death_respawn")
				return
			var g := grimbs[0] as MobBase
			g.take_damage(50.0, _player().global_position)
			if _stage_frame > 100:
				_fail("mob would not die")
		"death_respawn":
			var p := _player()
			if _stage_frame == 1:
				p.take_damage(1000.0, p.global_position + Vector3(1, 0, 0))
			if not p.dead:
				if _stage_frame > 100:
					_fail("player did not die from lethal damage")
				return
			if _stage_frame == 10:
				_session._on_respawn()
			if not p.dead and p.health >= Player.MAX_HEALTH:
				print("[e2e] death + respawn verified")
				_pass_stage("final")
		"final":
			var inv := _player().inventory
			print("[e2e] final inventory slots used: %d, hp=%.0f hunger=%.1f" % [
				inv.size - inv.to_array().count(null), _player().health, _player().hunger])
			print("[e2e] PLAYTEST E2E PASSED")
			quit(0)


func _count_blocks(id: int) -> int:
	var count := 0
	for key: String in _session.world.chunks:
		var c: Chunk = _session.world.chunks[key]
		for v: int in c.edits.values():
			if v == id:
				count += 1
	return count


func _region_hash(ccx: int, ccz: int) -> int:
	var combined := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c: Chunk = _session.world.chunks.get(_session.world.chunk_key(ccx + dx, ccz + dz))
			if c != null:
				combined = hash([combined, c.compute_hash()])
	return combined
