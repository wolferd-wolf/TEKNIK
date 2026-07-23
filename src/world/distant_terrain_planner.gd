class_name TeknikDistantTerrainPlanner
extends RefCounted

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const WorldWindowPlan = preload("res://src/world/world_window_plan.gd")


func build(
	seed: int,
	center: Vector3i,
	chunk_size: int,
	active_radius: int,
	world_radius: int,
	step: int
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var safe_step: int = maxi(1, step)
	var active_rect: Rect2i = WorldWindowPlan.active_world_rect(
		center, active_radius, chunk_size
	)
	var distant_rect: Rect2i = WorldWindowPlan.distant_world_rect(
		center, chunk_size, world_radius
	)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var height_cache: Dictionary = {}
	var top_quads: int = 0
	var side_quads: int = 0

	for world_z: int in range(distant_rect.position.y, distant_rect.end.y, safe_step):
		for world_x: int in range(distant_rect.position.x, distant_rect.end.x, safe_step):
			if _cell_is_inside_active_window(world_x, world_z, active_rect):
				continue

			var height: int = _cell_height(
				seed, world_x, world_z, safe_step, height_cache
			)
			var top_y: float = float(height) + 0.04
			var top_color: Color = _cell_color(
				seed, world_x, world_z, safe_step, height
			)
			_append_quad(
				vertices,
				normals,
				colors,
				indices,
				[
					Vector3(float(world_x), top_y, float(world_z)),
					Vector3(float(world_x + safe_step), top_y, float(world_z)),
					Vector3(float(world_x + safe_step), top_y, float(world_z + safe_step)),
					Vector3(float(world_x), top_y, float(world_z + safe_step)),
				],
				Vector3.UP,
				top_color
			)
			top_quads += 1

			var north_z: int = world_z - safe_step
			if not _cell_is_inside_active_window(world_x, north_z, active_rect):
				var north_height: int = _cell_height(
					seed, world_x, north_z, safe_step, height_cache
				)
				if height > north_height:
					_append_north_wall(
						vertices, normals, colors, indices,
						world_x, world_z, safe_step, top_y,
						float(north_height) + 0.04, top_color
					)
					side_quads += 1

			var south_z: int = world_z + safe_step
			if not _cell_is_inside_active_window(world_x, south_z, active_rect):
				var south_height: int = _cell_height(
					seed, world_x, south_z, safe_step, height_cache
				)
				if height > south_height:
					_append_south_wall(
						vertices, normals, colors, indices,
						world_x, world_z, safe_step, top_y,
						float(south_height) + 0.04, top_color
					)
					side_quads += 1

			var west_x: int = world_x - safe_step
			if not _cell_is_inside_active_window(west_x, world_z, active_rect):
				var west_height: int = _cell_height(
					seed, west_x, world_z, safe_step, height_cache
				)
				if height > west_height:
					_append_west_wall(
						vertices, normals, colors, indices,
						world_x, world_z, safe_step, top_y,
						float(west_height) + 0.04, top_color
					)
					side_quads += 1

			var east_x: int = world_x + safe_step
			if not _cell_is_inside_active_window(east_x, world_z, active_rect):
				var east_height: int = _cell_height(
					seed, east_x, world_z, safe_step, height_cache
				)
				if height > east_height:
					_append_east_wall(
						vertices, normals, colors, indices,
						world_x, world_z, safe_step, top_y,
						float(east_height) + 0.04, top_color
					)
					side_quads += 1

	return {
		"center": center,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"quads": top_quads + side_quads,
		"top_quads": top_quads,
		"side_quads": side_quads,
		"generation_usec": Time.get_ticks_usec() - started_usec,
	}


func _cell_is_inside_active_window(
	world_x: int,
	world_z: int,
	active_rect: Rect2i
) -> bool:
	return (
		world_x >= active_rect.position.x
		and world_x < active_rect.end.x
		and world_z >= active_rect.position.y
		and world_z < active_rect.end.y
	)


func _cell_height(
	seed: int,
	world_x: int,
	world_z: int,
	step: int,
	cache: Dictionary
) -> int:
	var key := Vector2i(world_x, world_z)
	if cache.has(key):
		return int(cache[key])
	var half_step: int = step >> 1
	var height: int = TerrainGenerator.surface_height(
		seed,
		world_x + half_step,
		world_z + half_step
	)
	cache[key] = height
	return height


func _cell_color(
	seed: int,
	world_x: int,
	world_z: int,
	step: int,
	height: int
) -> Color:
	var half_step: int = step >> 1
	var sample_x: int = world_x + half_step
	var sample_z: int = world_z + half_step
	var biome_color: Color = TerrainGenerator.surface_color(
		seed,
		TerrainGenerator.GRASS,
		Vector3i(sample_x, height, sample_z)
	)
	return biome_color.lerp(Color("455f42"), 0.42)


func _append_north_wall(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	world_x: int,
	world_z: int,
	step: int,
	top_y: float,
	bottom_y: float,
	top_color: Color
) -> void:
	_append_quad(
		vertices, normals, colors, indices,
		[
			Vector3(float(world_x + step), top_y, float(world_z)),
			Vector3(float(world_x), top_y, float(world_z)),
			Vector3(float(world_x), bottom_y, float(world_z)),
			Vector3(float(world_x + step), bottom_y, float(world_z)),
		],
		Vector3.FORWARD,
		top_color.darkened(0.20)
	)


func _append_south_wall(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	world_x: int,
	world_z: int,
	step: int,
	top_y: float,
	bottom_y: float,
	top_color: Color
) -> void:
	var edge_z: float = float(world_z + step)
	_append_quad(
		vertices, normals, colors, indices,
		[
			Vector3(float(world_x), top_y, edge_z),
			Vector3(float(world_x + step), top_y, edge_z),
			Vector3(float(world_x + step), bottom_y, edge_z),
			Vector3(float(world_x), bottom_y, edge_z),
		],
		Vector3.BACK,
		top_color.darkened(0.24)
	)


func _append_west_wall(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	world_x: int,
	world_z: int,
	step: int,
	top_y: float,
	bottom_y: float,
	top_color: Color
) -> void:
	_append_quad(
		vertices, normals, colors, indices,
		[
			Vector3(float(world_x), top_y, float(world_z)),
			Vector3(float(world_x), top_y, float(world_z + step)),
			Vector3(float(world_x), bottom_y, float(world_z + step)),
			Vector3(float(world_x), bottom_y, float(world_z)),
		],
		Vector3.LEFT,
		top_color.darkened(0.22)
	)


func _append_east_wall(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	world_x: int,
	world_z: int,
	step: int,
	top_y: float,
	bottom_y: float,
	top_color: Color
) -> void:
	var edge_x: float = float(world_x + step)
	_append_quad(
		vertices, normals, colors, indices,
		[
			Vector3(edge_x, top_y, float(world_z + step)),
			Vector3(edge_x, top_y, float(world_z)),
			Vector3(edge_x, bottom_y, float(world_z)),
			Vector3(edge_x, bottom_y, float(world_z + step)),
		],
		Vector3.RIGHT,
		top_color.darkened(0.18)
	)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	corners: Array,
	normal: Vector3,
	color: Color
) -> void:
	var base: int = vertices.size()
	for corner: Variant in corners:
		vertices.append(corner as Vector3)
		normals.append(normal)
		colors.append(color)
	indices.append_array(PackedInt32Array([
		base, base + 3, base + 2,
		base, base + 2, base + 1,
	]))
