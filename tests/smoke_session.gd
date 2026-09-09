extends SceneTree

## Headless boot smoke test: builds the real Main scene, starts a session,
## simulates input, streams the world, saves, and reports.
## Run: godot --headless --path . --script tests/smoke_session.gd

var _frames := 0
var _main: Node
var _session: GameWorld
var _failed := false
var _start_pos := Vector3.ZERO
var _saved_ok := false


func _initialize() -> void:
	print("[smoke] booting main scene")
	_main = (load("res://src/main.gd") as GDScript).new()
	root.add_child(_main)
	process_frame.connect(_tick)


func _fail(msg: String) -> void:
	printerr("[smoke] FAIL: " + msg)
	_failed = true
	quit(1)


func _tick() -> void:
	_frames += 1
	if _failed:
		return

	if _frames == 5:
		if _main == null or not _main.is_inside_tree():
			_fail("main not in tree")
		print("[smoke] menu up, starting session")

	if _frames == 10:
		_main._start_session(0, false)
		return

	if _frames < 20:
		return

	if _session == null:
		_session = _main._current
		if _session == null:
			if _frames > 100:
				_fail("session never started")
			return
		print("[smoke] session started")

	var player := _session.player
	if player == null:
		_fail("no player")
		return

	if not _session._spawned:
		if _frames > 900:
			_fail("player never spawned (pending=%d)" % _session.world.pending_chunks())
		return

	if _frames == 30 or _start_pos == Vector3.ZERO and _frames < 200:
		_start_pos = player.global_position
		print("[smoke] player spawned at %s, pending chunks: %d" % [_start_pos, _session.world.pending_chunks()])
		Input.action_press("move_forward")

	# stream while walking
	_session.world.update_streaming(player.global_position, 1.0 / 60.0)

	if _frames == 400:
		var moved := player.global_position.distance_to(_start_pos)
		print("[smoke] walked %.1f m, chunks=%d, pending=%d" % [
			moved, _session.world.chunks.size(), _session.world.pending_chunks()])
		if moved < 0.5:
			_fail("player did not move with input held")
			return
		# interaction: mine the block underfoot-ish via API
		var sy := _session.world.surface_y(int(player.global_position.x), int(player.global_position.z))
		var px := int(player.global_position.x) + 2
		var pz := int(player.global_position.z)
		var target_y := _session.world.surface_y(px, pz)
		if target_y > 0:
			var ok := _session.world.set_block(px, target_y, pz, 0)
			if not ok:
				_fail("set_block failed")
				return
			if _session.world.get_block(px, target_y, pz) != 0:
				_fail("block not removed")
				return
			_session.world.set_block(px, target_y, pz, 4)
		print("[smoke] block edit ok")
		_saved_ok = _session.save_all()
		if not _saved_ok:
			_fail("save_all failed")
			return
		print("[smoke] save ok, inventory size=%d" % player.inventory.size)
		print("[smoke] SMOKE TEST PASSED")
		quit(0)

	if _frames > 1200:
		_fail("timeout waiting for full flow")
