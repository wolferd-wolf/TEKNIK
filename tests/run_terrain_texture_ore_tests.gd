extends SceneTree

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const OreField = preload("res://src/world/ore_field.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")
const ItemRegistry = preload("res://src/survival/item_registry.gd")

var _failures: int = 0


func _init() -> void:
	_test_texture_assets()
	_test_material_encoding_and_shared_shader()
	_test_ore_distribution_and_depth_rules()
	_test_ore_drops_without_hotbar_expansion()
	if _failures == 0:
		print(
			"TERRAIN_TEXTURE_ORE_TESTS_PASS atlas=128x64",
			" materials=8",
			" grass_faces=top_side_soil_bottom",
			" ore_drops=concentrates",
			" hotbar_slots=", ItemRegistry.placeable_items().size()
		)
		quit(0)
	else:
		push_error("TERRAIN_TEXTURE_ORE_TESTS_FAILED count=%d" % _failures)
		quit(1)


func _test_texture_assets() -> void:
	var atlas := load("res://assets/textures/terrain_atlas.png") as Texture2D
	_expect(atlas != null, "terrain atlas loads")
	if atlas != null:
		_expect(atlas.get_width() == 128, "atlas width is four 32-pixel tiles")
		_expect(atlas.get_height() == 64, "atlas height is two 32-pixel rows")
	var shader := load("res://assets/textures/terrain_atlas.gdshader") as Shader
	_expect(shader != null, "terrain atlas shader loads")
	if shader != null:
		_expect("filter_nearest" in shader.code, "shader preserves crisp pixel sampling")
		_expect("projected_uv" in shader.code, "shader repeats texture per voxel face")


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
		var material := mesh.surface_get_material(0) as ShaderMaterial
		_expect(material != null, "terrain surface uses shared shader material")
		if material != null:
			_expect(material.get_shader_parameter("terrain_atlas") is Texture2D, "shader receives atlas texture")


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
	for material: int in counts.keys():
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
	for material: int in mappings.keys():
		var expected := StringName(mappings[material])
		_expect(ItemRegistry.item_for_material(material) == expected, "ore maps to existing concentrate")
		_expect(ItemRegistry.material_for_item(expected) == ItemRegistry.AIR, "concentrate is not voxel-placeable")
	_expect(ItemRegistry.registered_items().size() == 36, "ore integration does not grow the item catalog")
	_expect(ItemRegistry.placeable_items().size() == 8, "ore integration preserves the stable hotbar")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("TERRAIN_TEXTURE_ORE_TEST_FAIL: " + message)
