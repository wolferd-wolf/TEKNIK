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
	var quads: int = 0
	for world_z: int in range(distant_rect.position.y, distant_rect.end.y, step):
		for world_x: int in range(distant_rect.position.x, distant_rect.end.x, step):
			if (
				world_x >= active_rect.position.x
				and world_x < active_rect.end.x
				and world_z >= active_rect.position.y
				and world_z < active_rect.end.y
			):
				continue
			var base: int = vertices.size()
			var corners: Array[Vector2i] = [
				Vector2i(world_x, world_z),
				Vector2i(world_x + step, world_z),
				Vector2i(world_x + step, world_z + step),
				Vector2i(world_x, world_z + step),
			]
			for corner: Vector2i in corners:
				var height: int = TerrainGenerator.surface_height(seed, corner.x, corner.y)
				vertices.append(Vector3(float(corner.x), float(height) + 0.04, float(corner.y)))
				normals.append(Vector3.UP)
				var biome_color: Color = TerrainGenerator.surface_color(
					seed,
					TerrainGenerator.GRASS,
					Vector3i(corner.x, height, corner.y)
				)
				colors.append(biome_color.lerp(Color("455f42"), 0.42))
			indices.append_array(PackedInt32Array([
				base, base + 3, base + 2,
				base, base + 2, base + 1,
			]))
			quads += 1
	return {
		"center": center,
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"quads": quads,
		"generation_usec": Time.get_ticks_usec() - started_usec,
	}
