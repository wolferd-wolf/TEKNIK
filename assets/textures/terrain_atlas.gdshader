shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Minecraft is used only as a scale/readability reference: logical 16x16 art,
// stable face orientation, nearest sampling and mipmaps for distant terrain.
uniform sampler2D terrain_atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 atlas_grid = vec2(8.0, 4.0);

const float TILE_TEXEL_INSET = 0.015625; // Half a texel inside each 32x32 atlas tile.

varying vec3 terrain_world_position;
varying vec3 terrain_local_normal;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_local_normal = NORMAL;
}

vec3 material_reference(float material_id, vec3 normal_value) {
	if (material_id < 1.5) {
		return vec3(0.409, 0.446, 0.432);
	}
	if (material_id < 2.5) {
		return vec3(0.468, 0.332, 0.211);
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return vec3(0.379, 0.557, 0.237);
		}
		return vec3(0.468, 0.332, 0.211);
	}
	if (material_id < 4.5) {
		return vec3(0.724, 0.619, 0.397);
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

		// Keep every face upright. The previous UV rotation made the grass fringe run
		// vertically and destroyed the perceived one-metre block scale.
		vec2 local_uv = fract(projected_uv(terrain_world_position, normal_value) + vec2(0.0001));
		local_uv = mix(vec2(TILE_TEXEL_INSET), vec2(1.0 - TILE_TEXEL_INSET), local_uv);
		vec2 atlas_uv = (tile_coordinate + local_uv) / atlas_grid;
		vec3 texture_color = texture(terrain_atlas, atlas_uv).rgb;
		vec3 reference = max(material_reference(material_id, normal_value), vec3(0.08));
		vec3 biome_tint = clamp(COLOR.rgb / reference, vec3(0.70), vec3(1.30));
		ALBEDO = clamp(texture_color * biome_tint, vec3(0.0), vec3(1.0));
		ROUGHNESS = material_id >= 5.0 ? 0.92 : 0.98;
	}
	METALLIC = 0.0;
}
