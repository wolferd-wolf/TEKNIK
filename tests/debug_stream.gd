extends SceneTree

var _frames := 0
var _main: Node
var _session: GameWorld
var _pressed := false
var _p: Player


func _initialize() -> void:
	_main = (load("res://src/main.gd") as GDScript).new()
	root.add_child(_main)
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames == 10:
		_main._start_session(0, false)
		return
	if _main._current == null or not _main._current._spawned:
		return
	_session = _main._current
	_p = _session.player
	if not _p.is_on_floor():
		return
	if not _pressed:
		_pressed = true
		var w: World = _session.world
		var bx := floori(_p.global_position.x)
		var bz := floori(_p.global_position.z)
		for y in range(floori(_p.global_position.y) - 1, floori(_p.global_position.y) + 8):
			print("[probe] block(%d,%d,%d)=%d" % [bx, y, bz, w.get_block(bx, y, bz)])
		print("[probe] pos=%s chunk0=%s" % [_p.global_position, _session.world.chunks.has("0,0")])
		var stack: Array[Node] = [_session]
		var found := 0
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is CollisionShape3D and n.shape is BoxShape3D:
				var bp: Vector3 = (n as CollisionShape3D).global_position
				var bs: Vector3 = (n.shape as BoxShape3D).size
				if bp.y < 43.0 and bp.y + bs.y * 0.5 > 33.0 and bp.x - bs.x * 0.5 < 3.0 and bp.z - bs.z * 0.5 < 3.0 and bp.x + bs.x * 0.5 > -1.0 and bp.z + bs.z * 0.5 > -1.0:
					print("[shapes] %s gpos=%s size=%s parent=%s" % [n.get_path(), bp, bs, n.get_parent().name])
					found += 1
		print("[shapes] total overlapping column: %d" % found)
		_p.dbg_trace = true
		Input.action_press("jump")
	else:
		if Engine.get_physics_frames() % 4 == 0:
			print("[probe] f=%d y=%.3f vel_y=%.2f floor=%s" % [_frames, _p.global_position.y, _p.velocity.y, _p.is_on_floor()])
		if _frames > 110:
			quit(0)
