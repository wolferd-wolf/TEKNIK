extends CharacterBody3D
class_name MobBase

## Shared mob framework: health, gravity, wandering, water float, damage, drops.
## Species implement _setup() and optionally _ai_extra(delta).

const GRAVITY := 26.0
const WANDER_SPEED := 2.2
const TURN_SPEED := 8.0

var max_health := 10.0
var health := 10.0
var move_speed := WANDER_SPEED
var attack_damage := 0.0
var attack_range := 1.3
var attack_cooldown := 1.2
var drops: Array = []  # [[id, min, max], ...]

var _wander_dir := Vector3.ZERO
var _wander_timer := 0.0
var _attack_timer := 0.0
var _hurt_flash := 0.0
var _burn_timer := 0.0
var _body_root: Node3D

@onready var _shape: CollisionShape3D = CollisionShape3D.new()


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 4
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	_shape.shape = capsule
	_shape.position.y = 0.8
	add_child(_shape)
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	_setup()


## Species build their body meshes and stats here.
func _setup() -> void:
	pass


func _add_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = pos
	_body_root.add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_update_body_tint()

	var in_water := _block_at(global_position + Vector3(0, 0.4, 0)) == BlockRegistry.WATER
	if in_water:
		velocity.y += (14.0 - velocity.y) * delta * 3.0  # bob up
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)

	_ai_extra(delta)

	if _wander_timer > 0.0:
		_wander_timer -= delta
		var flat := Vector3(velocity.x, 0, velocity.z)
		var target := _wander_dir * move_speed
		velocity.x = move_toward(flat.x, target.x, 20.0 * delta)
		velocity.z = move_toward(flat.z, target.z, 20.0 * delta)
		if _wander_dir != Vector3.ZERO:
			var yaw := atan2(_wander_dir.x, _wander_dir.z)
			rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	move_and_slide()

	# step up single blocks automatically
	if is_on_wall() and is_on_floor():
		var fwd := Vector3(velocity.x, 0, velocity.z)
		if fwd.length() > 0.1:
			velocity.y = 7.0

	# keep mobs from walking into the void of ungenerated chunks
	var ahead := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * 0.8
	if _column_missing(ahead):
		_wander_dir = -_wander_dir
		velocity.x = 0
		velocity.z = 0


func _ai_extra(_delta: float) -> void:
	pass


func wander_tick(duration: float, running: bool = true) -> void:
	_wander_timer = duration
	if running:
		var a := randf() * TAU
		_wander_dir = Vector3(sin(a), 0, cos(a))
	else:
		_wander_dir = Vector3.ZERO


func player_ref() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func take_damage(amount: float, from_pos: Vector3) -> void:
	health -= amount
	_hurt_flash = 0.25
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		velocity += away.normalized() * 6.0 + Vector3(0, 3.5, 0)
	if health <= 0.0:
		_die()


func _die() -> void:
	for d: Array in drops:
		var n := randi_range(int(d[1]), int(d[2]))
		if n > 0:
			World.spawn_drop_at(get_parent(), global_position + Vector3(0, 0.5, 0), int(d[0]), n)
	queue_free()


func _update_body_tint() -> void:
	if _body_root == null:
		return
	var f := 1.0 - clampf(_hurt_flash * 4.0, 0.0, 0.65)
	_body_root.scale = Vector3.ONE
	for mi: MeshInstance3D in _body_root.get_children():
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_enabled = _hurt_flash > 0.0
			mat.emission = Color(1, 0.2, 0.2, 1) * clampf(_hurt_flash * 4.0, 0.0, 1.0) * f


func _block_at(pos: Vector3) -> int:
	var world := _world()
	if world == null:
		return BlockRegistry.AIR
	return world.get_block(floori(pos.x), floori(pos.y), floori(pos.z))


func _column_missing(pos: Vector3) -> bool:
	var world := _world()
	if world == null:
		return false
	return world.surface_y(floori(pos.x), floori(pos.z)) < 0


func _world() -> World:
	var p := get_parent()
	while p != null and not (p is World):
		p = p.get_parent()
	return p as World


func distance_to_player() -> float:
	var p := player_ref()
	if p == null:
		return INF
	return global_position.distance_to(p.global_position)
