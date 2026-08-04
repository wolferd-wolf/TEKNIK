class_name TeknikMeshVisualSanitizer
extends RefCounted


static func flatten_quad_colors(arrays: Array) -> void:
	if arrays.size() <= Mesh.ARRAY_COLOR:
		return
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if colors.is_empty():
		return
	var base: int = 0
	while base + 3 < colors.size():
		# Alpha carries the exact voxel material ID for the terrain atlas shader.
		# Averaging preserves that constant face value instead of destroying it.
		var flat_color: Color = (
			colors[base]
			+ colors[base + 1]
			+ colors[base + 2]
			+ colors[base + 3]
		) * 0.25
		colors[base] = flat_color
		colors[base + 1] = flat_color
		colors[base + 2] = flat_color
		colors[base + 3] = flat_color
		base += 4
	arrays[Mesh.ARRAY_COLOR] = colors
