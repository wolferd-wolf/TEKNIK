shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Every material owns an independent mip chain. This prevents atlas-layer
// bleeding and stabilizes distant ground viewed at shallow angles.
uniform sampler2DArray terrain_layers : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform float detail_fade_start = 24.0;
uniform float detail_fade_end = 88.0;
uniform float detail_fade_strength = 0.88;

const float LAYER_TEXEL_INSET = 0.00390625; // Half a texel inside a 128x128 layer.

varying vec3 terrain_world_position;
varying vec3 terrain_local_normal;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_local_normal = NORMAL;
}

vec3 material_reference(float material_id, vec3 normal_value) {
	// References match the adapted Devil's Work.shop face averages. The distance
	// fade therefore removes shimmer without changing the pack's authored palette.
	if (material_id < 1.5) {
		return vec3(0.475, 0.475, 0.450);
	}
	if (material_id < 2.5) {
		return vec3(0.640, 0.378, 0.205);
	}
	if (material_id < 3.5) {
		if (normal_value.y > 0.5) {
			return vec3(0.522, 0.840, 0.231);
		}
		if (normal_value.y < -0.5) {
			return vec3(0.640, 0.378, 0.205);
		}
		return vec3(0.664, 0.483, 0.238);
	}
	if (material_id < 4.5) {
		return vec3(0.696, 0.610, 0.394);
	}
	if (material_id < 5.5) {
		return vec3(0.469, 0.474, 0.450);
	}
	if (material_id < 6.5) {
		return vec3(0.478, 0.472, 0.444);
	}
	if (material_id < 7.5) {
		return vec3(0.478, 0.474, 0.447);
	}
	return vec3(0.481, 0.477, 0.442);
}

float texture_layer(float material_id, vec3 normal_value) {
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
	if (material_id < 4.5) {
		return 4.0;
	}
	if (material_id < 5.5) {
		return 5.0;
	}
	if (material_id < 6.5) {
		return 6.0;
	}
	if (material_id < 7.5) {
		return 7.0;
	}
	return 8.0;
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

vec3 suppress_micro_tint(vec3 tint) {
	// Both the legacy and native mesh paths historically baked small pseudo-random
	// vertex brightness changes into COLOR. Preserve real biome differences, but
	// dead-zone those tiny deviations so they cannot become distant checker noise.
	vec3 deviation = tint - vec3(1.0);
	vec3 keep = smoothstep(vec3(0.08), vec3(0.20), abs(deviation));
	return vec3(1.0) + deviation * keep;
}

void fragment() {
	float material_id = floor(COLOR.a * 255.0 + 0.5);
	vec3 normal_value = normalize(terrain_local_normal);
	bool use_existing_color = material_id < 0.5 || material_id > 8.5;

	if (use_existing_color) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.97;
	} else {
		// The adapted grass-side layer is already authored top-to-bottom. Keep
		// projected V unchanged so its green band stays on the physical top edge.
		vec2 local_uv = fract(projected_uv(terrain_world_position, normal_value) + vec2(0.0001));
		local_uv = clamp(local_uv, vec2(LAYER_TEXEL_INSET), vec2(1.0 - LAYER_TEXEL_INSET));

		float layer = texture_layer(material_id, normal_value);
		vec3 texture_color = texture(terrain_layers, vec3(local_uv, layer)).rgb;
		vec3 reference = max(material_reference(material_id, normal_value), vec3(0.08));
		vec3 biome_tint = clamp(COLOR.rgb / reference, vec3(0.72), vec3(1.28));
		vec3 macro_biome_tint = suppress_micro_tint(biome_tint);
		vec3 textured_color = texture_color * macro_biome_tint;
		vec3 stable_distance_tint = mix(vec3(1.0), macro_biome_tint, 0.62);
		vec3 stable_distance_color = reference * stable_distance_tint;

		float camera_distance = distance(terrain_world_position, CAMERA_POSITION_WORLD);
		float distance_fade = smoothstep(detail_fade_start, detail_fade_end, camera_distance);
		ALBEDO = clamp(
			mix(textured_color, stable_distance_color, distance_fade * detail_fade_strength),
			vec3(0.0),
			vec3(1.0)
		);
		ROUGHNESS = material_id >= 5.0 ? 0.93 : 0.98;
	}
	METALLIC = 0.0;
}
