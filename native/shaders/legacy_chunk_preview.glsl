#[vertex]
#version 450

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec3 normal;

layout(set = 0, binding = 0, std430) readonly buffer ChunkOriginBuffer {
    ivec4 chunk_origins[];
};

layout(location = 0) out vec3 vertex_normal;

vec4 project_chunk_position(vec3 local_position) {
    vec3 world_position = vec3(chunk_origins[0].xyz) + local_position;
    vec3 chunk_center = vec3(chunk_origins[0].xyz) + vec3(16.0, 12.0, 16.0);
    vec3 centered = world_position - chunk_center;
    vec3 view_right = normalize(vec3(1.0, 0.0, -1.0));
    vec3 view_forward = normalize(vec3(1.0, 0.85, 1.0));
    vec3 view_up = normalize(cross(view_forward, view_right));
    float clip_x = dot(centered, view_right) / 48.0;
    float clip_y = dot(centered, view_up) / 48.0;
    float clip_z = 0.5 + dot(centered, view_forward) / 128.0;
    return vec4(clip_x, clip_y, clip_z, 1.0);
}

void main() {
    vertex_normal = normal;
    gl_Position = project_chunk_position(vertex_position);
}

#[fragment]
#version 450

layout(location = 0) in vec3 vertex_normal;
layout(location = 0) out vec4 fragment_color;

void main() {
    vec3 direction_color = vec3(0.16) + abs(normalize(vertex_normal)) * 0.78;
    fragment_color = vec4(direction_color, 1.0);
}
