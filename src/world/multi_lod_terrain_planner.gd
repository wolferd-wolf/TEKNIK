class_name TeknikMultiLodTerrainPlanner
extends RefCounted

const BiomePlanner = preload("res://src/world/biome_distant_terrain_planner.gd")
const WorldWindowPlan = preload("res://src/world/world_window_plan.gd")

const INTERMEDIATE_RING_CHUNKS: int = 2
const INTERMEDIATE_STEP: int = 2


func build(
	seed: int,
	center: Vector3i,
	chunk_size: int,
	active_radius: int,
	world_radius: int,
	outer_step: int
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var intermediate_world_radius: int = (active_radius + INTERMEDIATE_RING_CHUNKS + 1) * chunk_size
	var intermediate: Dictionary = BiomePlanner.new().build(
		seed, center, chunk_size, active_radius, intermediate_world_radius, INTERMEDIATE_STEP
	)
	var outer: Dictionary = BiomePlanner.new().build(
		seed, center, chunk_size, active_radius, world_radius, outer_step
	)
	var exclusion_rect: Rect2i = WorldWindowPlan.active_world_rect(
		center, active_radius + INTERMEDIATE_RING_CHUNKS, chunk_size
	)
	var filtered_outer: Dictionary = _filter_plan_outside_rect(outer, exclusion_rect)
	var result: Dictionary = _merge_plans(intermediate, filtered_outer)
	result["center"] = center
	result["intermediate_step"] = INTERMEDIATE_STEP
	result["outer_step"] = outer_step
	result["intermediate_quads"] = int(intermediate.get("quads", 0))
	result["outer_quads"] = int(filtered_outer.get("quads", 0))
	result["intermediate_radius_chunks"] = active_radius + INTERMEDIATE_RING_CHUNKS
	result["generation_usec"] = Time.get_ticks_usec() - started_usec
	return result


func _filter_plan_outside_rect(plan: Dictionary, rect: Rect2i) -> Dictionary:
	var source_vertices: PackedVector3Array = plan.get("vertices", PackedVector3Array())
	var source_normals: PackedVector3Array = plan.get("normals", PackedVector3Array())
	var source_colors: PackedColorArray = plan.get("colors", PackedColorArray())
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var kept_quads: int = 0
	for base: int in range(0, source_vertices.size(), 4):
		if base + 3 >= source_vertices.size():
			break
		var center := Vector2.ZERO
		for corner: int in range(4):
			center += Vector2(source_vertices[base + corner].x, source_vertices[base + corner].z)
		center *= 0.25
		if rect.has_point(Vector2i(floori(center.x), floori(center.y))):
			continue
		var write_base: int = vertices.size()
		for corner: int in range(4):
			vertices.append(source_vertices[base + corner])
			normals.append(source_normals[base + corner])
			colors.append(source_colors[base + corner])
		indices.append_array(PackedInt32Array([
			write_base, write_base + 3, write_base + 2,
			write_base, write_base + 2, write_base + 1,
		]))
		kept_quads += 1
	return {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"quads": kept_quads,
	}


func _merge_plans(first: Dictionary, second: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = first.get("vertices", PackedVector3Array()).duplicate()
	var normals: PackedVector3Array = first.get("normals", PackedVector3Array()).duplicate()
	var colors: PackedColorArray = first.get("colors", PackedColorArray()).duplicate()
	var indices: PackedInt32Array = first.get("indices", PackedInt32Array()).duplicate()
	var second_vertices: PackedVector3Array = second.get("vertices", PackedVector3Array())
	var second_normals: PackedVector3Array = second.get("normals", PackedVector3Array())
	var second_colors: PackedColorArray = second.get("colors", PackedColorArray())
	var second_indices: PackedInt32Array = second.get("indices", PackedInt32Array())
	var offset: int = vertices.size()
	vertices.append_array(second_vertices)
	normals.append_array(second_normals)
	colors.append_array(second_colors)
	for index: int in second_indices:
		indices.append(index + offset)
	return {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"quads": int(first.get("quads", 0)) + int(second.get("quads", 0)),
	}
