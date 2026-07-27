shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 2.0);

varying vec3 terrain_world_position;
varying vec3 terrain_local_normal;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_local_normal = NORMAL;
}

vec3 material_reference(float material_id, vec3 normal_value) {
	if (material_id < 1.5) {
		return vec3(0.365, 0.408, 0.396);
	}
	if (material_id < 2.5) {
		return vec3(0.376, 0.271, 0.212);
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return vec3(0.302, 0.459, 0.263);
		}
		return vec3(0.376, 0.271, 0.212);
	}
	if (material_id < 5.5) {
		return vec3(0.604, 0.651, 0.635);
	}
	if (material_id < 6.5) {
		return vec3(0.718, 0.408, 0.271);
	}
	if (material_id < 7.5) {
		return vec3(0.604, 0.435, 0.345);
	}
	return vec3(0.824, 0.643, 0.220);
}

float atlas_tile(float material_id, vec3 normal_value) {
	if (material_id < 1.5) {
		return 3.0;
	}
	if (material_id < 2.5) {
		return 2.0;
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return 0.0;
		}
		if (normal_value.y < -0.5) {
			return 2.0;
		}
		return 1.0;
	}
	if (material_id < 5.5) {
		return 4.0;
	}
	if (material_id < 6.5) {
		return 5.0;
	}
	if (material_id < 7.5) {
		return 6.0;
	}
	return 7.0;
}

vec2 projected_uv(vec3 position_value, vec3 normal_value) {
	vec3 absolute_normal = abs(normal_value);
	if (absolute_normal.y >= absolute_normal.x && absolute_normal.y >= absolute_normal.z) {
		return position_value.xz;
	}
	if (absolute_normal.x >= absolute_normal.z) {
		return position_value.zy;
	}
	return position_value.xy;
}

float block_hash(vec3 cell) {
	vec3 value = fract(cell * vec3(0.1031, 0.11369, 0.13787));
	value += dot(value, value.yzx + 19.19);
	return fract((value.x + value.y) * value.z);
}

vec2 varied_tile_uv(vec2 uv, float variation) {
	float variant = floor(variation * 8.0);
	if (variant >= 4.0) {
		uv = uv.yx;
	}
	if (mod(variant, 2.0) >= 1.0) {
		uv.x = 1.0 - uv.x;
	}
	if (mod(floor(variant * 0.5), 2.0) >= 1.0) {
		uv.y = 1.0 - uv.y;
	}
	vec2 quarter_offset = vec2(
		floor(fract(variation * 13.73) * 4.0),
		floor(fract(variation * 47.17) * 4.0)
	) * 0.25;
	return fract(uv + quarter_offset);
}

void fragment() {
	float material_id = floor(COLOR.a * 255.0 + 0.5);
	vec3 normal_value = terrain_local_normal;
	bool use_existing_color = material_id < 0.5
		|| (material_id > 3.5 && material_id < 4.5)
		|| material_id > 8.5;

	if (use_existing_color) {
		// Sand and any future untextured material retain the existing biome color.
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.95;
	} else {
		float tile = atlas_tile(material_id, normal_value);
		vec2 tile_coordinate = vec2(mod(tile, atlas_grid.x), floor(tile / atlas_grid.x));
		vec3 block_cell = floor(terrain_world_position - normal_value * 0.002);
		vec3 material_offset = vec3(material_id * 0.37, material_id * 0.61, material_id * 0.83);
		float variation = block_hash(block_cell + material_offset);
		float macro_variation = block_hash(floor(block_cell / 4.0) + material_offset * 2.0);
		vec2 local_uv = fract(projected_uv(terrain_world_position, normal_value) + vec2(0.0001));
		local_uv = varied_tile_uv(local_uv, variation);
		vec2 atlas_uv = (tile_coordinate + local_uv) / atlas_grid;
		vec3 texture_color = texture(terrain_atlas, atlas_uv).rgb;
		vec3 reference = max(material_reference(material_id, normal_value), vec3(0.08));
		vec3 biome_and_face_tint = clamp(COLOR.rgb / reference, vec3(0.58), vec3(1.42));
		float fine_tint = mix(0.955, 1.045, variation);
		float macro_tint = mix(0.965, 1.035, macro_variation);
		ALBEDO = clamp(texture_color * biome_and_face_tint * fine_tint * macro_tint, vec3(0.0), vec3(1.0));
		ROUGHNESS = material_id >= 5.0 ? 0.88 : 0.96;
	}
	METALLIC = 0.0;
}
