class_name TeknikTerrainTextureMaterial
extends RefCounted

const TERRAIN_SHADER: Shader = preload("res://assets/textures/terrain_atlas.gdshader")
const TERRAIN_ATLAS: Texture2D = preload("res://assets/textures/terrain_atlas.png")

static var _shared_material: ShaderMaterial


static func shared_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = TERRAIN_SHADER
		_shared_material.set_shader_parameter("terrain_atlas", TERRAIN_ATLAS)
		_shared_material.set_shader_parameter("atlas_grid", Vector2(4.0, 2.0))
	return _shared_material
