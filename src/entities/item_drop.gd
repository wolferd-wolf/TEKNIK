extends Area3D
class_name ItemDrop

## A floating pickup carrying one stack. Magnetises to the player, merges on pickup.

const GRAVITY := 22.0
const PICKUP_DIST := 1.4
const MAGNET_DIST := 2.6
const LIFETIME := 240.0

var item_id: int = 0
var count: int = 1
var durability: int = 0

var _vel := Vector3.ZERO
var _age := 0.0
var _spin_mesh: MeshInstance3D
var _cooldown := 0.4  # seconds before it can be picked up (just-dropped grace)


static func _drop_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ChunkMesher.atlas_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _init(p_id: int = 0, p_count: int = 1, p_durability: int = 0) -> void:
	item_id = p_id
	count = p_count
	durability = p_durability
	collision_layer = 8
	collision_mask = 1
	monitoring = false


func launch(vel: Vector3) -> void:
	_vel = vel


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	shape.shape = sphere
	add_child(shape)

	_spin_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	quad.orientation = PlaneMesh.FACE_Z
	_spin_mesh.mesh = quad
	var mat := _drop_material()
	var tile := ItemRegistry.tile_of(item_id)
	if tile >= 0:
		# per-instance uv shift so every drop shows its own tile
		var uv1 := Vector3()
		var col := tile % AtlasTiles.COLS
		var row := int(tile / float(AtlasTiles.COLS))
		uv1.x = float(col) / float(AtlasTiles.COLS)
		uv1.y = float(row) / float(AtlasTiles.ROWS)
		uv1.z = 1.0 / float(AtlasTiles.COLS)
		mat.uv1_scale = Vector3(1.0 / AtlasTiles.COLS, 1.0 / AtlasTiles.ROWS, 1.0)
		mat.uv1_offset = Vector3(uv1.x, uv1.y, 0.0)
	_spin_mesh.material_override = mat
	_spin_mesh.position.y = 0.3
	add_child(_spin_mesh)


func _physics_process(delta: float) -> void:
	_age += delta
	_cooldown -= delta
	if _age > LIFETIME:
		queue_free()
		return
	_vel.y -= GRAVITY * delta
	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := from + _vel * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] + Vector3(0, 0.02, 0)
		_vel = _vel.slide(hit["normal"]) * 0.4
		if _vel.length() < 0.6:
			_vel = Vector3.ZERO
	else:
		global_position = to

	_spin_mesh.rotation.y += delta * 2.0

	if _cooldown > 0.0:
		return
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		var player := p as Node3D
		var d := global_position.distance_to(player.global_position + Vector3(0, 0.8, 0))
		if d < PICKUP_DIST:
			if _try_pickup(player):
				return
		elif d < MAGNET_DIST:
			var dir := (player.global_position + Vector3(0, 0.8, 0) - global_position).normalized()
			global_position += dir * delta * 4.5


func _try_pickup(player: Node3D) -> bool:
	var inv: Inventory = player.get("inventory")
	if inv == null:
		return false
	var left := inv.add(item_id, count, durability)
	if left >= count:
		return false  # inventory full
	if left > 0:
		count = left
	else:
		queue_free()
	return true
