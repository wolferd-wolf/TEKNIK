extends SceneTree

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const TerrainTextureMaterial = preload("res://src/world/terrain_texture_material.gd")
const OreField = preload("res://src/world/ore_field.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")
const ItemRegistry = preload("res://src/survival/item_registry.gd")

var _failures: int = 0


func _init() -> void:
	_test_texture_assets()
	_test_material_encoding_and_shared_shader()
	_test_filtering_contracts()
	_test_ore_distribution_and_depth_rules()
	_test_ore_drops_without_hotbar_expansion()
	if _failures == 0:
		print(
			"TERRAIN_TEXTURE_ORE_TESTS_PASS texture_array_layers=9",
			" layer_size=128",
			" source=DevilsWorkshop-Essential-Isometric-v2",
			" mipmaps=runtime",
			" anisotropy=4x",
			" distance_fade=24-88",
			" grass_faces=top_side_soil_bottom",
			" ore_drops=concentrates",
			" hotbar_slots=", ItemRegistry.placeable_items().size()
		)
		quit(0)
	else:
		push_error("TERRAIN_TEXTURE_ORE_TESTS_FAILED count=%d" % _failures)
		quit(1)


func _test_texture_assets() -> void:
	_expect(TerrainTextureMaterial.LAYER_PATHS.size() == 9, "terrain array declares nine layers")
	for path: String in TerrainTextureMaterial.LAYER_PATHS:
		var texture := load(path) as Texture2D
		_expect(texture != null, "terrain layer loads: %s" % path)
		if texture != null:
			_expect(texture.get_width() == 128, "terrain layer width is 128: %s" % path)
			_expect(texture.get_height() == 128, "terrain layer height is 128: %s" % path)
	var manifest := FileAccess.open("res://assets/textures/terrain_layers/manifest.json", FileAccess.READ)
	_expect(manifest != null, "terrain layer provenance manifest exists")
	if manifest != null:
		var manifest_text: String = manifest.get_as_text()
		_expect("Essential Isometric 3D Block Pack v2.0" in manifest_text, "manifest records active texture pack")
		_expect("Ajay Karat | Devil's Work.shop" in manifest_text, "manifest records texture-pack author")
		_expect("source_archive_sha256" in manifest_text, "manifest pins uploaded source archive")
		_expect("all_layers_from_active_pack_style" in manifest_text, "manifest records cohesive layer adaptation")
		_expect("fc1fd0d4cd28d01ead280477ca2d0cbdacd9bf7f80a20df2a17b5e1fe367dc47" in manifest_text, "manifest pins adapted grass top")
		_expect("99d23a84a33d76ebe237b61d8b77d15cdad9296cb595fe83ce55f70613d28810" in manifest_text, "manifest pins adapted stone")
	var shader := load("res://assets/textures/terrain_texture_array.gdshader") as Shader
	_expect(shader != null, "terrain texture-array shader loads")
	if shader != null:
		_expect("sampler2DArray" in shader.code, "shader uses separate texture-array layers")
		_expect("filter_nearest_mipmap_anisotropic" in shader.code, "shader uses anisotropic mip filtering")
		_expect("CAMERA_POSITION_WORLD" in shader.code, "shader fades detail by camera distance")
		_expect("local_uv.y = 1.0 - local_uv.y" in shader.code, "side faces put grass at physical top")
		_expect("block_hash" not in shader.code, "per-block random variants are removed")


func _test_material_encoding_and_shared_shader() -> void:
	var chunk := VoxelChunk.new()
	var materials: Array[int] = [
		TerrainGenerator.STONE,
		TerrainGenerator.SOIL,
		TerrainGenerator.GRASS,
		TerrainGenerator.SAND,
		TerrainGenerator.ZINC_ORE,
		TerrainGenerator.COPPER_ORE,
		TerrainGenerator.IRON_ORE,
		TerrainGenerator.GOLD_ORE,
	]
	for index: int in range(materials.size()):
		chunk.set_voxel(Vector3i(index * 3, 4, 4), materials[index])
	var report: Dictionary = GreedyMesher.build_arrays(chunk)
	var arrays: Array = report.arrays
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_expect(not colors.is_empty(), "test materials produce mesh colors")
	MeshVisualSanitizer.flatten_quad_colors(arrays)
	colors = arrays[Mesh.ARRAY_COLOR]
	var encoded: Dictionary = {}
	var base: int = 0
	while base + 3 < colors.size():
		var material_id: int = roundi(colors[base].a * 255.0)
		encoded[material_id] = true
		_expect(roundi(colors[base + 3].a * 255.0) == material_id, "quad keeps one material id")
		base += 4
	for material: int in materials:
		_expect(encoded.has(material), "mesh alpha encodes material %d" % material)
	var mesh: ArrayMesh = GreedyMesher.mesh_from_arrays(arrays)
	_expect(mesh.get_surface_count() == 1, "terrain remains one draw surface")
	if mesh.get_surface_count() == 1:
		var shader_material := mesh.surface_get_material(0) as ShaderMaterial
		_expect(shader_material != null, "terrain surface uses shared shader material")
		if shader_material != null:
			var layer_parameter: Variant = shader_material.get_shader_parameter("terrain_layers")
			_expect(layer_parameter is Texture2DArray, "shader receives Texture2DArray")
			if layer_parameter is Texture2DArray:
				var layer_array := layer_parameter as Texture2DArray
				_expect(layer_array.get_layers() == 9, "texture array contains nine independent layers")
				_expect(layer_array.get_width() == 128, "texture array width is 128")
				_expect(layer_array.get_height() == 128, "texture array height is 128")
				_expect(layer_array.has_mipmaps(), "texture array has independent mip chains")


func _test_filtering_contracts() -> void:
	_expect(
		int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", -1)) == 4,
		"mobile anisotropic filtering is fixed at 4x"
	)
	_expect(
		is_equal_approx(float(ProjectSettings.get_setting("rendering/textures/default_filters/texture_mipmap_bias", 99.0)), 0.0),
		"mipmap bias stays neutral to avoid grain"
	)
	_expect(
		not bool(ProjectSettings.get_setting("rendering/textures/default_filters/use_nearest_mipmap_filter", true)),
		"mipmap levels blend instead of popping"
	)


func _test_ore_distribution_and_depth_rules() -> void:
	var counts: Dictionary = {
		TerrainGenerator.ZINC_ORE: 0,
		TerrainGenerator.COPPER_ORE: 0,
		TerrainGenerator.IRON_ORE: 0,
		TerrainGenerator.GOLD_ORE: 0,
	}
	for world_z: int in range(-64, 65):
		for world_x: int in range(-64, 65):
			for world_y: int in range(2, 25):
				var material: int = OreField.material_for_stone(
					73421,
					Vector3i(world_x, world_y, world_z),
					29
				)
				if counts.has(material):
					counts[material] = int(counts[material]) + 1
	for material_value: Variant in counts.keys():
		var material: int = int(material_value)
		_expect(int(counts[material]) > 0, "ore material %d appears deterministically" % material)
	_expect(OreField.material_for_stone(73421, Vector3i(4, 1, 4), 29) == TerrainGenerator.STONE, "bedrock floor is protected")
	_expect(OreField.material_for_stone(73421, Vector3i(4, 26, 4), 29) == TerrainGenerator.STONE, "ores stay below maximum depth")
	_expect(OreField.material_for_stone(73421, Vector3i(4, 27, 4), 29) == TerrainGenerator.STONE, "surface roof remains ore-free")


func _test_ore_drops_without_hotbar_expansion() -> void:
	var mappings: Dictionary = {
		ItemRegistry.ZINC_ORE: ItemRegistry.ITEM_ZINC_CONCENTRATE,
		ItemRegistry.COPPER_ORE: ItemRegistry.ITEM_COPPER_CONCENTRATE,
		ItemRegistry.IRON_ORE: ItemRegistry.ITEM_IRON_CONCENTRATE,
		ItemRegistry.GOLD_ORE: ItemRegistry.ITEM_GOLD_CONCENTRATE,
	}
	for material_value: Variant in mappings.keys():
		var material: int = int(material_value)
		var expected: StringName = StringName(str(mappings[material]))
		_expect(ItemRegistry.item_for_material(material) == expected, "ore maps to existing concentrate")
		_expect(ItemRegistry.material_for_item(expected) == ItemRegistry.AIR, "concentrate is not voxel-placeable")
	_expect(ItemRegistry.registered_items().size() == 36, "ore integration does not grow the item catalog")
	_expect(ItemRegistry.placeable_items().size() == 8, "ore integration preserves the stable hotbar")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("TERRAIN_TEXTURE_ORE_TEST_FAIL: " + message)
