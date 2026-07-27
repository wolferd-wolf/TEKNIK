class_name TeknikTerrainTextureMaterial
extends RefCounted

const TERRAIN_SHADER: Shader = preload("res://assets/textures/terrain_texture_array.gdshader")
const LAYER_SIZE: int = 128
const LAYER_PATHS: PackedStringArray = PackedStringArray([
	"res://assets/textures/terrain_layers/grass_top.png",
	"res://assets/textures/terrain_layers/grass_side.png",
	"res://assets/textures/terrain_layers/dirt.png",
	"res://assets/textures/terrain_layers/stone.png",
	"res://assets/textures/terrain_layers/sand.png",
	"res://assets/textures/terrain_layers/zinc_ore.png",
	"res://assets/textures/terrain_layers/copper_ore.png",
	"res://assets/textures/terrain_layers/iron_ore.png",
	"res://assets/textures/terrain_layers/gold_ore.png",
])

static var _shared_material: ShaderMaterial
static var _terrain_layers: Texture2DArray


static func shared_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = TERRAIN_SHADER
		_shared_material.set_shader_parameter("terrain_layers", texture_layers())
		_shared_material.set_shader_parameter("detail_fade_start", 24.0)
		_shared_material.set_shader_parameter("detail_fade_end", 88.0)
		_shared_material.set_shader_parameter("detail_fade_strength", 0.88)
	return _shared_material


static func texture_layers() -> Texture2DArray:
	if _terrain_layers != null:
		return _terrain_layers
	var images: Array[Image] = []
	for path: String in LAYER_PATHS:
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("TEKNIK terrain texture layer failed to load: %s" % path)
			return null
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			push_error("TEKNIK terrain texture layer has no image data: %s" % path)
			return null
		if image.get_width() != LAYER_SIZE or image.get_height() != LAYER_SIZE:
			image.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_LANCZOS)
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		if not image.has_mipmaps():
			var mipmap_error: Error = image.generate_mipmaps()
			if mipmap_error != OK:
				push_error("TEKNIK terrain layer mipmap generation failed: %s" % path)
				return null
		images.append(image)

	_terrain_layers = Texture2DArray.new()
	var create_error: Error = _terrain_layers.create_from_images(images)
	if create_error != OK:
		push_error("TEKNIK terrain Texture2DArray creation failed: %s" % error_string(create_error))
		_terrain_layers = null
	return _terrain_layers
