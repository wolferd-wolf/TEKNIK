extends StaticBody3D
class_name ChunkNode

## Render + physics representation of one chunk. Replaceable at any time;
## never the source of truth for voxel data.

var cx: int
var cz: int
var dirty := true

var _opaque_mi: MeshInstance3D
var _cutout_mi: MeshInstance3D
var _liquid_mi: MeshInstance3D
var _collision_shapes: Array[CollisionShape3D] = []

static var _mat_opaque: StandardMaterial3D
static var _mat_cutout: StandardMaterial3D
static var _mat_liquid: StandardMaterial3D


static func _materials_ready() -> bool:
	if _mat_opaque != null:
		return true
	var tex := ChunkMesher.atlas_texture()
	if tex == null:
		return false
	_mat_opaque = StandardMaterial3D.new()
	_mat_opaque.albedo_texture = tex
	_mat_opaque.vertex_color_use_as_albedo = true
	_mat_opaque.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mat_opaque.roughness = 1.0
	_mat_opaque.metallic_specular = 0.1

	_mat_cutout = StandardMaterial3D.new()
	_mat_cutout.albedo_texture = tex
	_mat_cutout.vertex_color_use_as_albedo = true
	_mat_cutout.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mat_cutout.roughness = 1.0
	_mat_cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_cutout.alpha_scissor_threshold = 0.5
	_mat_cutout.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mat_liquid = StandardMaterial3D.new()
	_mat_liquid.albedo_texture = tex
	_mat_liquid.vertex_color_use_as_albedo = true
	_mat_liquid.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat_liquid.roughness = 0.15
	_mat_liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_liquid.cull_mode = BaseMaterial3D.CULL_DISABLED
	return true


func _init(p_cx: int = 0, p_cz: int = 0) -> void:
	cx = p_cx
	cz = p_cz
	position = Vector3(cx * Chunk.SIZE, 0, cz * Chunk.SIZE)
	collision_layer = 1
	collision_mask = 0
	_opaque_mi = MeshInstance3D.new()
	_opaque_mi.name = "Opaque"
	add_child(_opaque_mi)
	_cutout_mi = MeshInstance3D.new()
	_cutout_mi.name = "Cutout"
	_cutout_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cutout_mi)
	_liquid_mi = MeshInstance3D.new()
	_liquid_mi.name = "Liquid"
	_liquid_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_liquid_mi)


## Immediate rebuild (interactive block edits): synchronous by design.
func rebuild_now(world: World) -> void:
	var chunk: Chunk = world.chunks.get(World.chunk_key(cx, cz))
	if chunk == null:
		return
	var meshes := ChunkMesher.build(chunk, world)
	if meshes.is_empty():
		dirty = true
		return
	var boxes: Array = ChunkMesher.build_collision_boxes(ChunkMesher.make_job(chunk, {}))
	apply_full(meshes, boxes)


## Streaming path: takes worker output {meshes, boxes}. If an edit happened
## while the task ran, `dirty` is still set and the pump re-enqueues us.
func apply_mesh_result(result: Dictionary) -> void:
	if result.is_empty() or not result.has("m"):
		dirty = true
		return
	apply_full(result["m"], result.get("c", []))


func apply_full(meshes: Dictionary, boxes: Array) -> void:
	if not _materials_ready():
		dirty = true
		return
	_opaque_mi.mesh = meshes["opaque"]
	_opaque_mi.material_override = _mat_opaque
	_cutout_mi.mesh = meshes["cutout"]
	_cutout_mi.material_override = _mat_cutout
	_liquid_mi.mesh = meshes["liquid"]
	_liquid_mi.material_override = _mat_liquid
	_apply_collision_boxes(boxes)
	dirty = false


func _apply_collision_boxes(boxes: Array) -> void:
	for c in _collision_shapes:
		c.queue_free()
	_collision_shapes.clear()
	for aabb: AABB in boxes:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = aabb.size
		cs.shape = box
		cs.position = aabb.position + aabb.size * 0.5
		add_child(cs)
		_collision_shapes.append(cs)


func clear_mesh() -> void:
	_opaque_mi.mesh = null
	_cutout_mi.mesh = null
	_liquid_mi.mesh = null
	for c in _collision_shapes:
		c.queue_free()
	_collision_shapes.clear()
	dirty = true


func _exit_tree() -> void:
	# release GPU memory promptly when streaming unloads chunks
	clear_mesh()
