shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// 32x32 logical art is enlarged to 64x64 atlas cells. Nearest sampling keeps
// the voxel language crisp; mipmaps stop distant terrain from shimmering.
uniform sampler2D terrain_atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 atlas_grid = vec2(8.0, 4.0);

const float TILE_TEXEL_INSET = 0.0078125; // Half a texel inside each 64x64 cell.

varying vec3 terrain_world_position;
varying vec3 terrain_local_normal;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_local_normal = NORMAL;
}

vec3 material_reference(float material_id, vec3 normal_value) {
	if (material_id < 1.5) {
		return vec3(0.421, 0.453, 0.439);
	}
	if (material_id < 2.5) {
		return vec3(0.491, 0.350, 0.237);
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return vec3(0.386, 0.544, 0.247);
		}
		return vec3(0.465, 0.397, 0.240);
	}
	if (material_id < 4.5) {
		return vec3(0.725, 0.621, 0.406);
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

float atlas_tile(float material_id, vec3 normal_value, float variant) {
	if (material_id < 1.5) {
		return 12.0 + variant;
	}
	if (material_id < 2.5) {
		return 8.0 + variant;
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return variant;
		}
		if (normal_value.y < -0.5) {
			return 8.0 + variant;
		}
		return 4.0 + variant;
	}
	if (material_id < 4.5) {
		return 16.0 + variant;
	}
	if (material_id < 5.5) {
		return 20.0;
	}
	if (material_id < 6.5) {
		return 21.0;
	}
	if (material_id < 7.5) {
		return 22.0;
	}
	return 23.0;
}

vec2 projected_uv(vec3 position_value, vec3 normal_value) {
	vec3 absolute_normal = abs(normal_value);
	if (absolute_normal.y >= absolute_normal.x && absolute_normal.y >= absolute_normal.z) {
		return position_value.xz;
	}
	// Image V increases downward while world Y increases upward. Negating world Y
	// keeps the grass sod band at the physical TOP edge and lets the fringe hang down.
	if (absolute_normal.x >= absolute_normal.z) {
		return vec2(position_value.z, -position_value.y);
	}
	return vec2(position_value.x, -position_value.y);
}

float block_hash(vec3 cell) {
	vec3 value = fract(cell * vec3(0.1031, 0.11369, 0.13787));
	value += dot(value, value.yzx + 19.19);
	return fract((value.x + value.y) * value.z);
}

void fragment() {
	float material_id = floor(COLOR.a * 255.0 + 0.5);
	vec3 normal_value = terrain_local_normal;
	bool use_existing_color = material_id < 0.5 || material_id > 8.5;

	if (use_existing_color) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.96;
	} else {
		vec3 block_cell = floor(terrain_world_position - normal_value * 0.002);
		vec3 material_offset = vec3(material_id * 0.37, material_id * 0.61, material_id * 0.83);
		float variant = floor(block_hash(block_cell + material_offset) * 4.0);
		float tile = atlas_tile(material_id, normal_value, variant);
		vec2 tile_coordinate = vec2(mod(tile, atlas_grid.x), floor(tile / atlas_grid.x));
		vec2 local_uv = fract(projected_uv(terrain_world_position, normal_value) + vec2(0.0001));
		local_uv = mix(vec2(TILE_TEXEL_INSET), vec2(1.0 - TILE_TEXEL_INSET), local_uv);
		vec2 atlas_uv = (tile_coordinate + local_uv) / atlas_grid;
		vec3 texture_color = texture(terrain_atlas, atlas_uv).rgb;
		vec3 reference = max(material_reference(material_id, normal_value), vec3(0.08));
		vec3 biome_tint = clamp(COLOR.rgb / reference, vec3(0.76), vec3(1.24));
		ALBEDO = clamp(texture_color * biome_tint, vec3(0.0), vec3(1.0));
		ROUGHNESS = material_id >= 5.0 ? 0.92 : 0.98;
	}
	METALLIC = 0.0;
}
