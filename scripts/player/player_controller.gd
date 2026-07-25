extends CharacterBody3D

const WALK_SPEED := 5.4
const SPRINT_SPEED := 7.2
const GROUND_ACCELERATION := 28.0
const AIR_ACCELERATION := 8.0
const JUMP_VELOCITY := 6.8
const LOOK_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.0032
const INTERACTION_DISTANCE := 6.0
const STREAM_LOOKAHEAD_SECONDS := 0.22
const COLLISION_FOOTPRINT_RADIUS := 0.42

var world: Node
var mobile_move := Vector2.ZERO
var yaw := 0.0
var pitch := -0.18
var jump_requested := false
var mine_requested := false
var place_requested := false
var camera: Camera3D
var stream_hold_count := 0
var stream_hold_active := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(48.0)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.78
	collision.shape = capsule
	collision.position.y = 0.89
	add_child(collision)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.58
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = 76.0
	camera.near = 0.05
	head.add_child(camera)

	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	if not is_on_floor():
		velocity.y -= gravity * delta

	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W):
		keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S):
		keyboard.y -= 1.0
	keyboard = keyboard.normalized()

	var move_input := mobile_move
	if keyboard.length_squared() > 0.0:
		move_input = keyboard

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var desired_direction := (right * move_input.x + forward * move_input.y).normalized()
	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	var desired_velocity := desired_direction * speed
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)

	stream_hold_active = false
	if desired_direction.length_squared() > 0.0 and is_instance_valid(world):
		var predicted_position := global_position + Vector3(velocity.x, 0.0, velocity.z) * STREAM_LOOKAHEAD_SECONDS
		if not _is_collision_ready_for_position(predicted_position):
			velocity.x = 0.0
			velocity.z = 0.0
			stream_hold_active = true
			stream_hold_count += 1

	if (jump_requested or Input.is_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	jump_requested = false

	move_and_slide()

	if global_position.y < -20.0 and is_instance_valid(world):
		global_position = world.get_recovery_position(global_position)
		velocity = Vector3.ZERO

	if mine_requested:
		_interact(false)
		mine_requested = false
	if place_requested:
		_interact(true)
		place_requested = false

func _is_collision_ready_for_position(position: Vector3) -> bool:
	if not is_instance_valid(world):
		return false
	var footprint_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(COLLISION_FOOTPRINT_RADIUS, 0.0, 0.0),
		Vector3(-COLLISION_FOOTPRINT_RADIUS, 0.0, 0.0),
		Vector3(0.0, 0.0, COLLISION_FOOTPRINT_RADIUS),
		Vector3(0.0, 0.0, -COLLISION_FOOTPRINT_RADIUS)
	]
	for offset in footprint_offsets:
		var coord: Vector2i = world.world_to_chunk(position + offset)
		if not world.loaded_chunks.has(coord):
			return false
		var entry: Dictionary = world.loaded_chunks[coord]
		if not is_instance_valid(entry["collision"]):
			return false
	return true

func get_stream_status_text() -> String:
	return "stream-hold %s  total %d" % ["ON" if stream_hold_active else "off", stream_hold_count]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(event.relative * LOOK_SENSITIVITY)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			request_mine()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			request_place()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func set_mobile_move(value: Vector2) -> void:
	mobile_move = value.limit_length(1.0)

func apply_look_delta(delta_value: Vector2) -> void:
	yaw -= delta_value.x
	pitch = clamp(pitch - delta_value.y, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotation.y = yaw
	if is_instance_valid(camera):
		camera.get_parent().rotation.x = pitch

func apply_touch_look(pixel_delta: Vector2) -> void:
	apply_look_delta(pixel_delta * TOUCH_LOOK_SENSITIVITY)

func request_jump() -> void:
	jump_requested = true

func request_mine() -> void:
	mine_requested = true

func request_place() -> void:
	place_requested = true

func _interact(place_block: bool) -> void:
	if not is_instance_valid(world) or not is_instance_valid(camera):
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	world.edit_from_ray(origin, direction, INTERACTION_DISTANCE, place_block, global_position)
