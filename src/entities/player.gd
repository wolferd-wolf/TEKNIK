extends CharacterBody3D
class_name Player

## First-person survival controller: movement, camera, interaction, survival stats.
## Mouse+keyboard on desktop, virtual controls on touch (fed via look_delta/joystick).

signal health_changed(hp: float, max_hp: float)
signal hunger_changed(food: float, max_food: float)
signal died
signal respawned
signal held_changed
signal message(text: String)

const WALK_SPEED := 4.3
const SPRINT_SPEED := 5.7
const CROUCH_SPEED := 2.0
const SWIM_SPEED := 2.6
const JUMP_VELOCITY := 8.2
const GRAVITY := 24.0
const WATER_GRAVITY := 5.0
const MAX_HEALTH := 20.0
const MAX_HUNGER := 20.0
const INTERACT_RANGE := 4.6
const EYE_HEIGHT := 1.62
const EYE_CROUCH := 1.28

var world: World
var inventory: Inventory
var hotbar_index := 0

var health := MAX_HEALTH
var hunger := MAX_HUNGER
var dead := false

var look_delta := Vector2()          # fed by touch layer
var joystick := Vector2()            # fed by touch layer
var touch_mining := false            # fed by touch layer
var touch_placing := false

var _camera: Camera3D
var _capsule: CollisionShape3D
var _capsule_shape: CapsuleShape3D
var _highlight: MeshInstance3D
var _held_quad: MeshInstance3D
var _pitch := 0.0
var _crouching := false
var _sprinting := false
var _in_water := false
var _break_progress := 0.0
var _break_target := Vector3i(999999, 0, 0)
var _place_cooldown := 0.0
var _eat_cooldown := 0.0
var _attack_swing := 0.0
var _hunger_timer := 0.0
var _regen_timer := 0.0
var _starve_timer := 0.0
var _fall_start_y := 0.0
var _was_on_floor := true
var _last_damage_dir := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	inventory = Inventory.new(36)

	_capsule_shape = CapsuleShape3D.new()
	_capsule_shape.radius = 0.3
	_capsule_shape.height = 1.8
	_capsule = CollisionShape3D.new()
	_capsule.shape = _capsule_shape
	_capsule.position.y = 0.9
	add_child(_capsule)

	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.08
	_camera.position.y = EYE_HEIGHT
	add_child(_camera)
	_camera.current = true

	_held_quad = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	quad.orientation = PlaneMesh.FACE_Z
	_held_quad.mesh = quad
	_held_quad.position = Vector3(0.42, -0.36, -0.62)
	_held_quad.rotation_degrees = Vector3(0, -18, 8)
	_camera.add_child(_held_quad)

	_highlight = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	_build_highlight_mesh(im)
	_highlight.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_highlight.material_override = mat
	_highlight.visible = false
	add_child(_highlight)

	inventory.changed.connect(func() -> void: held_changed.emit())
	held_changed.emit()


func _build_highlight_mesh(im: ImmediateMesh) -> void:
	var c := Color(0.05, 0.05, 0.05, 0.9)
	var e := 0.002
	var a := Vector3(-e, -e, -e)
	var b := Vector3(1 + e, 1 + e, 1 + e)
	var pts := [
		[a, Vector3(b.x, a.y, a.z)], [Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z)],
		[Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)], [Vector3(a.x, a.y, b.z), a],
		[Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z)], [Vector3(b.x, b.y, a.z), b],
		[Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)], [Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z)],
		[a, Vector3(a.x, b.y, a.z)], [Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z)],
		[Vector3(b.x, a.y, b.z), b], [Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z)],
	]
	for pair: Array in pts:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_set_color(c)
		im.surface_add_vertex(pair[0])
		im.surface_set_color(c)
		im.surface_add_vertex(pair[1])
		im.surface_end()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		apply_look(mm.relative * 0.0022)
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_hotbar((hotbar_index + 8) % 9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_hotbar((hotbar_index + 1) % 9)


func set_pitch(p: float) -> void:
	_pitch = clampf(p, -1.55, 1.55)
	_camera.rotation.x = _pitch


func get_pitch() -> float:
	return _pitch


func apply_look(delta: Vector2) -> void:
	if dead:
		return
	rotate_y(-delta.x)
	_pitch = clampf(_pitch - delta.y, -1.55, 1.55)
	_camera.rotation.x = _pitch


func _select_hotbar(i: int) -> void:
	hotbar_index = i
	held_changed.emit()


func held_item() -> Dictionary:
	return inventory.get_slot(hotbar_index)


func _physics_process(delta: float) -> void:
	if world == null or dead:
		return
	_place_cooldown = maxf(0.0, _place_cooldown - delta)
	_eat_cooldown = maxf(0.0, _eat_cooldown - delta)
	_attack_swing = maxf(0.0, _attack_swing - delta)
	_update_water_state()
	_update_movement(delta)
	_update_survival(delta)
	_update_interaction(delta)
	_update_held_visual()


func _update_water_state() -> void:
	var head_block := world.get_block(floori(global_position.x), floori(global_position.y + EYE_HEIGHT), floori(global_position.z))
	var body_block := world.get_block(floori(global_position.x), floori(global_position.y + 0.4), floori(global_position.z))
	_in_water = body_block == BlockRegistry.WATER or head_block == BlockRegistry.WATER


func _update_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if not dead:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if joystick.length_squared() > 0.01:
			input_dir = joystick
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	wish.y = 0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var wants_crouch := Input.is_action_pressed("crouch") or _touch_crouch
	_crouching = wants_crouch and not _in_water
	_sprinting = Input.is_action_pressed("sprint") and input_dir.y < -0.4 and not _crouching and not _in_water

	var speed := WALK_SPEED
	if _crouching:
		speed = CROUCH_SPEED
	elif _sprinting:
		speed = SPRINT_SPEED
	if _in_water:
		speed = SWIM_SPEED

	var jump_now := Input.is_action_pressed("jump")
	var jump_edge := jump_now and not _jump_prev
	_jump_prev = jump_now
	var touch_edge := _touch_jump and not _touch_jump_prev
	_touch_jump_prev = _touch_jump

	if _in_water:
		velocity.y -= WATER_GRAVITY * delta
		velocity.y = maxf(velocity.y, -3.5)
		if jump_now or _touch_jump:
			velocity.y = 3.2
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -28.0)  # terminal velocity: no tunneling
		if (jump_edge or touch_edge) and is_on_floor():
			velocity.y = JUMP_VELOCITY
			if dbg_trace:
				print("[jd] pre-slide vel=%s pos.y=%.4f floor=%s motion_mode=%d up=%s snap=%.3f" % [velocity, global_position.y, is_on_floor(), motion_mode, up_direction, floor_snap_length])
				_dbg_ticks = 3
			_add_hunger(-0.06)

	velocity.x = wish.x * speed
	velocity.z = wish.z * speed

	# crouch edge guard: don't walk off ledges while crouched
	if _crouching and _was_on_floor and velocity.y <= 0.0:
		var probe_to := global_position + Vector3(velocity.x, 0, velocity.z) * delta * 8.0
		if not _has_ground_below(probe_to):
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()
	if _dbg_ticks > 0:
		_dbg_ticks -= 1
		var col: String = "-"
		if get_slide_collision_count() > 0:
			col = str(get_slide_collision(0).get_collider())
		print("[jd] post vel=%s pos.y=%.4f floor=%s slides=%d col=%s" % [velocity, global_position.y, is_on_floor(), get_slide_collision_count(), col])

	if is_on_floor():
		if not _was_on_floor:
			var fall := _fall_start_y - global_position.y
			if fall > 3.5 and not _in_water:
				var dmg := floorf(fall - 3.5)
				if dmg > 0.0:
					take_damage(dmg, global_position + Vector3(0, -1, 0))
		_fall_start_y = global_position.y
		_was_on_floor = true
	else:
		_was_on_floor = false
		_fall_start_y = maxf(_fall_start_y, global_position.y)

	# capsule height
	var target_h := 1.5 if _crouching else 1.8
	if not is_equal_approx(_capsule_shape.height, target_h):
		_capsule_shape.height = target_h
	_capsule.position.y = target_h * 0.5
	var eye := EYE_CROUCH if _crouching else EYE_HEIGHT
	_camera.position.y = lerpf(_camera.position.y, eye, 14.0 * delta)


## Safety net: if the capsule span (feet..head) is embedded in solid voxels
## (bad spawn under a canopy, placement glitch, streaming race), push it up
## until at least the feet and head cells are free.
func _unstick() -> void:
	if world == null:
		return
	var x := floori(global_position.x)
	var y := floori(global_position.y)
	var z := floori(global_position.z)
	var feet := world.get_block(x, y, z)
	var head := world.get_block(x, y + 1, z)
	if not BlockRegistry.is_solid(feet) and not BlockRegistry.is_solid(head):
		return
	for up in range(1, 6):
		var ny := y + up
		if not BlockRegistry.is_solid(world.get_block(x, ny, z)) \
				and not BlockRegistry.is_solid(world.get_block(x, ny + 1, z)):
			global_position.y = float(ny) + 0.05
			velocity = Vector3.ZERO
			_fall_start_y = global_position.y
			return


func _has_ground_below(pos: Vector3) -> bool:
	var from := pos + Vector3(0, 0.2, 0)
	var to := pos + Vector3(0, -0.55, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


var _touch_jump := false
var _touch_crouch := false
var _jump_prev := false
var dbg_trace := false
var _dbg_ticks := 0
var _touch_jump_prev := false


func set_touch_state(jump: bool, crouch: bool) -> void:
	_touch_jump = jump
	_touch_crouch = crouch


# ---------------------------------------------------------------- survival

func _update_survival(delta: float) -> void:
	var drain := 0.018
	if _sprinting:
		drain += 0.05
	if _in_water:
		drain += 0.01
	_add_hunger(-drain * delta)

	_regen_timer += delta
	if hunger >= 17.0 and health < MAX_HEALTH and _regen_timer >= 3.5:
		_regen_timer = 0.0
		health = minf(MAX_HEALTH, health + 1.0)
		health_changed.emit(health, MAX_HEALTH)
		_add_hunger(-0.4)

	if hunger <= 0.0:
		_starve_timer += delta
		if _starve_timer >= 4.0:
			_starve_timer = 0.0
			if health > 2.0:
				take_damage(1.0, global_position)


func _add_hunger(v: float) -> void:
	var old := hunger
	hunger = clampf(hunger + v, 0.0, MAX_HUNGER)
	if not is_equal_approx(old, hunger):
		hunger_changed.emit(hunger, MAX_HUNGER)


func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead:
		return
	_last_damage_dir = (global_position - from_pos).normalized()
	health -= amount
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		health = 0.0
		_die()


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func eat_held() -> bool:
	var s := held_item()
	if s.is_empty():
		return false
	var id := int(s["id"])
	var food := ItemRegistry.food_value(id)
	if food <= 0 or hunger >= MAX_HUNGER - 0.5 or _eat_cooldown > 0.0:
		return false
	_eat_cooldown = 0.8
	_add_hunger(float(food))
	inventory.remove(id, 1)
	message.emit("Ate %s" % ItemRegistry.name_of(id))
	return true


func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	died.emit()


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	hunger = MAX_HUNGER
	dead = false
	_fall_start_y = at.y
	_was_on_floor = false
	inventory.clear()
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)
	respawned.emit()
	held_changed.emit()


# ---------------------------------------------------------------- interaction

func _update_interaction(delta: float) -> void:
	var mining := Input.is_action_pressed("mine") or touch_mining
	var placing := Input.is_action_pressed("place") or touch_placing
	var hit := world.raycast(_camera.global_position, -_camera.global_transform.basis.z, INTERACT_RANGE)

	_update_highlight(hit)

	if hit.is_empty():
		_break_progress = 0.0
		_break_target = Vector3i(999999, 0, 0)
		if mining:
			_try_attack_mob()
		if placing:
			_try_use()
		return

	var bpos: Vector3i = hit["pos"]
	if mining:
		if not _try_break(delta, bpos):
			_try_attack_mob()
	else:
		_break_progress = 0.0
	if placing:
		if not _try_place(bpos, hit["normal"]):
			_try_use()


func _try_break(delta: float, bpos: Vector3i) -> bool:
	var id := world.get_block(bpos.x, bpos.y, bpos.z)
	var hardness := BlockRegistry.hardness(id)
	if hardness < 0.0:
		return false  # unbreakable (bedrock/water)
	if bpos != _break_target:
		_break_target = bpos
		_break_progress = 0.0
	var s := held_item()
	var tool_id := int(s.get("id", 0))
	var speed := 1.0
	if ItemRegistry.tool_class(tool_id) == BlockRegistry.def(id)["tool"] and ItemRegistry.is_tool_item(tool_id):
		speed = ItemRegistry.tool_speed(tool_id)
	var time_needed := hardness / speed
	# pickaxe-required blocks without a proper pickaxe: slow and dropless
	var tier := ItemRegistry.tool_tier(tool_id)
	var needs_pick := String(BlockRegistry.def(id)["tool"]) == "pickaxe" and int(BlockRegistry.def(id)["min_tier"]) > 0
	var can_drop := (not needs_pick) or (ItemRegistry.tool_class(tool_id) == "pickaxe" and tier >= BlockRegistry.min_tier(id))
	if needs_pick and not can_drop:
		time_needed = hardness * 3.0
	_break_progress += delta / maxf(0.05, time_needed)
	_attack_swing = 0.25
	if _break_progress >= 1.0:
		_break_progress = 0.0
		world.set_block(bpos.x, bpos.y, bpos.z, BlockRegistry.AIR)
		_spawn_block_drop(bpos, id, can_drop)
		_damage_tool()
		return true
	return false


func _spawn_block_drop(bpos: Vector3i, id: int, can_drop: bool) -> void:
	if not can_drop:
		return
	var drop_id := BlockRegistry.drop_of(id)
	if drop_id == -2:
		# leaves: random fruit/stick drop
		var r := randf()
		if id == BlockRegistry.LEAVES:
			if r < 0.05:
				drop_id = ItemRegistry.APPLE
			elif r < 0.22:
				drop_id = ItemRegistry.STICK
			else:
				return
		else:
			if r < 0.18:
				drop_id = ItemRegistry.STICK
			else:
				return
	elif drop_id < 0:
		return
	World.spawn_drop_at(get_parent(), Vector3(bpos) + Vector3(0.5, 0.3, 0.5), drop_id, 1, ItemRegistry.tool_durability(drop_id))


func _damage_tool() -> void:
	var s := held_item()
	if s.is_empty() or not ItemRegistry.is_tool_item(int(s["id"])):
		return
	var dur := int(s.get("dur", 0)) - 1
	if dur <= 0:
		var id := int(s["id"])
		inventory.remove(id, 1)
		message.emit("%s broke!" % ItemRegistry.name_of(id))
		held_changed.emit()
	else:
		s["dur"] = dur


func _try_place(bpos: Vector3i, normal: Vector3i) -> bool:
	if _place_cooldown > 0.0:
		return false
	var s := held_item()
	if s.is_empty():
		return false
	var id := int(s["id"])
	if ItemRegistry.is_tool_item(id) or ItemRegistry.food_value(id) > 0:
		return false
	var target := bpos + normal
	if not Chunk.in_bounds(0, target.y, 0):
		return false
	var existing := world.get_block(target.x, target.y, target.z)
	if existing != BlockRegistry.AIR and not BlockRegistry.is_liquid(existing):
		return false
	# don't place inside player or mobs
	var box := AABB(Vector3(target) + Vector3(0.08, 0.08, 0.08), Vector3(0.84, 0.84, 0.84))
	if AABB(global_position + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.8, 0.6)).intersects(box):
		return false
	for m in get_tree().get_nodes_in_group("mobs"):
		var mb := m as CharacterBody3D
		if AABB(mb.global_position + Vector3(-0.45, 0, -0.45), Vector3(0.9, 1.6, 0.9)).intersects(box):
			return false
	if not world.set_block(target.x, target.y, target.z, id):
		return false
	inventory.remove(id, 1)
	_place_cooldown = 0.22
	return true


func _try_use() -> bool:
	# food
	var s := held_item()
	if not s.is_empty() and ItemRegistry.food_value(int(s["id"])) > 0:
		if eat_held():
			_place_cooldown = 0.4
			return true
	return false


func _try_attack_mob() -> bool:
	if _attack_swing > 0.0:
		return false
	_attack_swing = 0.35
	var s := held_item()
	var tool_id := int(s.get("id", 0))
	var damage := ItemRegistry.tool_damage(tool_id)
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * 3.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 4)  # mob layer
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var mob := hit["collider"] as MobBase
	if mob == null:
		return false
	mob.take_damage(damage, global_position)
	if ItemRegistry.is_tool_item(tool_id):
		_damage_tool()
	return true


func _update_highlight(hit: Dictionary) -> void:
	if hit.is_empty():
		_highlight.visible = false
		return
	_highlight.visible = true
	_highlight.global_position = Vector3(hit["pos"])


func _update_held_visual() -> void:
	var s := held_item()
	if s.is_empty():
		_held_quad.visible = false
		return
	var id := int(s["id"])
	var tile := ItemRegistry.tile_of(id)
	if tile < 0:
		_held_quad.visible = false
		return
	_held_quad.visible = true
	var mat := _held_quad.material_override as StandardMaterial3D
	if mat == null or int(mat.get_meta("tile", -1)) != tile:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = ChunkMesher.atlas_texture()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var col := tile % AtlasTiles.COLS
		var row := int(tile / float(AtlasTiles.COLS))
		mat.uv1_scale = Vector3(1.0 / AtlasTiles.COLS, 1.0 / AtlasTiles.ROWS, 1)
		mat.uv1_offset = Vector3(float(col) / AtlasTiles.COLS, float(row) / AtlasTiles.ROWS, 0)
		mat.set_meta("tile", tile)
		_held_quad.material_override = mat
	# swing bob
	_held_quad.position.y = -0.36 - sin(_attack_swing * 12.0) * 0.05


func camera_position() -> Vector3:
	return _camera.global_position


func camera_forward() -> Vector3:
	return -_camera.global_transform.basis.z
