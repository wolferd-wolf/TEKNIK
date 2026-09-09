extends Node3D
class_name GameWorld

signal quit_to_menu

## One play session: world streaming, player, mobs, day/night, HUD, save/load.
## Created by Main; destroyed on quit-to-menu.

const AUTOSAVE_INTERVAL := 45.0

var world: World
var player: Player
var hud: HUD
var day_night: DayNight
var spawner: MobSpawner
var save_dir: String
var slot_name: String

var _spawned := false
var _ground_ok := false
var _spawn_offset := Vector2i.ZERO
var _autosave := 0.0
var _generating_label: Label


func _init(p_slot_name: String, p_save_dir: String, restore: bool) -> void:
	slot_name = p_slot_name
	save_dir = p_save_dir
	if restore:
		world = World.restore_from_metadata(save_dir)
	if world == null:
		var seed_value := int(Time.get_unix_time_from_system()) % 2147483647
		world = World.new(seed_value, save_dir)


func _ready() -> void:
	# ALWAYS so Esc/E still reach _unhandled_input while the tree is paused;
	# the player/world stay pausable and freeze during menus
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(world)

	day_night = DayNight.new()
	add_child(day_night)

	player = Player.new()
	player.world = world
	add_child(player)
	player.add_to_group("player")

	spawner = MobSpawner.new()
	spawner.world = world
	spawner.day_night = day_night
	add_child(spawner)

	hud = HUD.new()
	add_child(hud)
	hud.player = player
	hud.world = world
	hud.day_night = day_night
	hud.quit_requested.connect(_on_quit_requested)
	hud.respawn_requested.connect(_on_respawn)
	hud.enable_touch(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))
	player.health_changed.connect(func(_hp: float, _m: float) -> void: hud.refresh_stats())
	player.hunger_changed.connect(func(_f: float, _m: float) -> void: hud.refresh_stats())
	player.message.connect(hud.show_message)
	player.held_changed.connect(hud.refresh_hotbar)
	player.died.connect(_on_player_died)

	_spawn_offset = world.find_land_spawn()

	_generating_label = Label.new()
	_generating_label.set_anchors_preset(Control.PRESET_CENTER)
	_generating_label.offset_left = -200
	_generating_label.offset_right = 200
	_generating_label.offset_top = -40
	_generating_label.offset_bottom = 0
	_generating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_generating_label.text = "Generating world..."
	_generating_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(_generating_label)

	_load_player_state()
	_capture_mouse()
	hud.refresh_stats()
	hud.refresh_hotbar()


func _capture_mouse() -> void:
	if not hud.pause_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if player == null:
		return
	if not _spawned:
		var sx := float(_spawn_offset.x) + 0.5
		var sz := float(_spawn_offset.y) + 0.5
		world.update_streaming(Vector3(sx, 64, sz), delta)
		var key := World.chunk_key(World.world_to_chunk(_spawn_offset.x), World.world_to_chunk(_spawn_offset.y))
		if world.chunks.has(key):
			var sy := world.surface_y(_spawn_offset.x, _spawn_offset.y)
			if sy >= 1:
				player.global_position = Vector3(sx, float(sy) + 1.05, sz)
				player.velocity = Vector3.ZERO
				_spawned = true
				_generating_label.visible = false
		return

	if get_tree().paused:
		return
	world.update_streaming(player.global_position, delta)

	# after restoring a save, hold the player frozen until the ground exists,
	# otherwise they fall through the not-yet-generated world
	if not _ground_ok:
		var sy := world.surface_y(floori(player.global_position.x), floori(player.global_position.z))
		if sy < 0:
			player.velocity = Vector3.ZERO
			return
		_ground_ok = true
	hud.refresh_time()
	hud.refresh_pos()

	_autosave += delta
	if _autosave >= AUTOSAVE_INTERVAL:
		_autosave = 0.0
		save_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if hud.pause_open():
			hud.close_pause()
		elif hud.inventory_open():
			hud.close_inventory()
		else:
			hud.open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if hud.inventory_open():
			hud.close_inventory()
		elif not hud.pause_open() and not player.dead:
			hud.open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_touch"):
		hud.toggle_touch()
	elif event is InputEventMouseButton and event.is_pressed() and not hud.pause_open() and not hud.inventory_open():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()


func _on_player_died() -> void:
	hud.show_death(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_respawn() -> void:
	hud.show_death(false)
	var sx := _spawn_offset.x
	var sz := _spawn_offset.y
	var sy := world.surface_y(sx, sz)
	if sy < 1:
		sy = 70
	player.respawn(Vector3(float(sx) + 0.5, float(sy) + 1.05, float(sz) + 0.5))
	hud.refresh_stats()
	hud.refresh_hotbar()
	_capture_mouse()


func save_all() -> bool:
	var ok := world.save_to_disk()
	ok = _save_player_state() and ok
	return ok


func _save_player_state() -> bool:
	var payload := {
		"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		"yaw": player.rotation.y,
		"pitch": player._pitch,
		"health": player.health,
		"hunger": player.hunger,
		"hotbar": player.hotbar_index,
		"inventory": player.inventory.to_array(),
		"time": day_night.time_of_day,
		"spawned": _spawned,
	}
	var f := FileAccess.open(save_dir.path_join("player.json"), FileAccess.WRITE)
	if f == null:
		push_error("GameWorld: cannot write player.json (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	return true


func _load_player_state() -> void:
	var f := FileAccess.open(save_dir.path_join("player.json"), FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("GameWorld: player.json malformed, starting fresh player")
		return
	var d: Dictionary = parsed
	var pos: Array = d.get("pos", [0.5, 80.0, 0.5])
	player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.rotation.y = float(d.get("yaw", 0.0))
	player.set_pitch(float(d.get("pitch", 0.0)))
	player.health = float(d.get("health", 20.0))
	player.hunger = float(d.get("hunger", 20.0))
	player.hotbar_index = int(d.get("hotbar", 0))
	player.inventory.from_array(d.get("inventory", []))
	day_night.time_of_day = float(d.get("time", 0.08))
	_spawned = bool(d.get("spawned", false))
	if _spawned:
		_generating_label.visible = false


func _on_quit_requested() -> void:
	save_all()
	get_tree().paused = false
	quit_to_menu.emit()
