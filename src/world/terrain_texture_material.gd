class_name TeknikTerrainTextureMaterial
extends RefCounted

const TERRAIN_SHADER: Shader = preload("res://assets/textures/terrain_texture_array.gdshader")
const LAYER_SIZE: int = 128
const LAYER_PATHS: Array[String] = [
	"res://assets/textures/terrain_layers/grass_top.png",
	"res://assets/textures/terrain_layers/grass_side.png",
	"res://assets/textures/terrain_layers/dirt.png",
	"res://assets/textures/terrain_layers/stone.png",
	"res://assets/textures/terrain_layers/sand.png",
	"res://assets/textures/terrain_layers/zinc_ore.png",
	"res://assets/textures/terrain_layers/copper_ore.png",
	"res://assets/textures/terrain_layers/iron_ore.png",
	"res://assets/textures/terrain_layers/gold_ore.png",
]

static var _shared_material: ShaderMaterial
static var _terrain_layers: Texture2DArray


static func shared_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = TERRAIN_SHADER
		_shared_material.set_shader_parameter("terrain_layers", texture_layers())
		_shared_material.set_shader_parameter("detail_fade_start", 22.0)
		_shared_material.set_shader_parameter("detail_fade_end", 76.0)
		_shared_material.set_shader_parameter("detail_fade_strength", 0.72)
	return _shared_material


static func texture_layers() -> Texture2DArray:
	if _terrain_layers != null:
		return _terrain_layers
	var images: Array[Image] = [
		_build_grass_top(),
		_build_grass_side(),
		_build_soil(),
		_build_stone(),
		_build_sand(),
	]
	for index: int in range(5, LAYER_PATHS.size()):
		var texture := load(LAYER_PATHS[index]) as Texture2D
		if texture == null:
			push_error("TEKNIK terrain ore texture failed to load: %s" % LAYER_PATHS[index])
			return null
		var image: Image = texture.get_image()
		if image.get_width() != LAYER_SIZE or image.get_height() != LAYER_SIZE:
			image.resize(LAYER_SIZE, LAYER_SIZE, Image.INTERPOLATE_LANCZOS)
		images.append(image)
	for image: Image in images:
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		if not image.has_mipmaps():
			var mipmap_error: Error = image.generate_mipmaps()
			if mipmap_error != OK:
				push_error("TEKNIK terrain mipmap generation failed")
				return null
	_terrain_layers = Texture2DArray.new()
	var create_error: Error = _terrain_layers.create_from_images(images)
	if create_error != OK:
		push_error("TEKNIK terrain Texture2DArray creation failed: %s" % error_string(create_error))
		_terrain_layers = null
	return _terrain_layers


static func _new_image() -> Image:
	return Image.create(LAYER_SIZE, LAYER_SIZE, false, Image.FORMAT_RGBA8)


static func _hash(x: int, y: int, seed: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + seed * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


static func _tile_noise(x: int, y: int, seed: int, scale: int) -> float:
	var sx: int = posmod(x, LAYER_SIZE)
	var sy: int = posmod(y, LAYER_SIZE)
	var gx: int = sx / scale
	var gy: int = sy / scale
	var fx: float = float(sx % scale) / float(scale)
	var fy: float = float(sy % scale) / float(scale)
	var cells: int = LAYER_SIZE / scale
	var x1: int = posmod(gx + 1, cells)
	var y1: int = posmod(gy + 1, cells)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a: float = lerpf(_hash(gx, gy, seed), _hash(x1, gy, seed), fx)
	var b: float = lerpf(_hash(gx, y1, seed), _hash(x1, y1, seed), fx)
	return lerpf(a, b, fy)


static func _layered_noise(x: int, y: int, seed: int) -> float:
	return _tile_noise(x, y, seed, 32) * 0.50 + _tile_noise(x, y, seed + 11, 16) * 0.30 + _tile_noise(x, y, seed + 29, 8) * 0.20


static func _build_grass_top() -> Image:
	var image := _new_image()
	for y: int in range(LAYER_SIZE):
		for x: int in range(LAYER_SIZE):
			var n: float = _layered_noise(x, y, 7)
			var fine: float = _hash(x, y, 101)
			var color := Color("4d7a37").lerp(Color("769447"), n)
			if fine > 0.965:
				color = color.lightened(0.13)
			elif fine < 0.025:
				color = color.darkened(0.12)
			image.set_pixel(x, y, color)
	return image


static func _build_soil() -> Image:
	var image := _new_image()
	for y: int in range(LAYER_SIZE):
		for x: int in range(LAYER_SIZE):
			var n: float = _layered_noise(x, y, 19)
			var color := Color("5a3c29").lerp(Color("826044"), n)
			var speck: float = _hash(x, y, 211)
			if speck > 0.982:
				color = Color("9a8b73")
			elif speck < 0.018:
				color = color.darkened(0.18)
			image.set_pixel(x, y, color)
	return image


static func _build_grass_side() -> Image:
	var image := _build_soil()
	for y: int in range(30):
		for x: int in range(LAYER_SIZE):
			var edge: int = 14 + int(round((_tile_noise(x, 0, 41, 16) - 0.5) * 14.0))
			if y <= edge:
				var n: float = _layered_noise(x, y, 43)
				var color := Color("426f31").lerp(Color("739244"), n)
				if y > edge - 3:
					color = color.darkened(0.08)
				image.set_pixel(x, y, color)
	return image


static func _build_stone() -> Image:
	var image := _new_image()
	for y: int in range(LAYER_SIZE):
		for x: int in range(LAYER_SIZE):
			var n: float = _layered_noise(x, y, 53)
			var strata: float = sin(float(y) * 0.18 + _tile_noise(x, y, 61, 32) * 3.0) * 0.035
			var color := Color("59605e").lerp(Color("808582"), clampf(n + strata, 0.0, 1.0))
			var pit: float = _hash(x, y, 71)
			if pit < 0.012:
				color = color.darkened(0.22)
			elif pit > 0.991:
				color = color.lightened(0.10)
			image.set_pixel(x, y, color)
	return image


static func _build_sand() -> Image:
	var image := _new_image()
	for y: int in range(LAYER_SIZE):
		for x: int in range(LAYER_SIZE):
			var n: float = _layered_noise(x, y, 83)
			var ripple: float = sin(float(x + y) * 0.11 + _tile_noise(x, y, 89, 32) * 4.0) * 0.055
			var color := Color("b69a62").lerp(Color("d4bd82"), clampf(n + ripple, 0.0, 1.0))
			var grain: float = _hash(x, y, 97)
			if grain > 0.985:
				color = color.lightened(0.12)
			elif grain < 0.018:
				color = color.darkened(0.12)
			image.set_pixel(x, y, color)
	return image
