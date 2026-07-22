#[vertex]
#version 450

layout(set = 0, binding = 0, std430) readonly buffer FaceBuffer {
    uvec2 faces[];
};

layout(set = 0, binding = 1, std430) readonly buffer ChunkOriginBuffer {
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

uint triangle_corner(uint vertex_id, bool positive) {
    const uint positive_order[6] = uint[6](0u, 3u, 2u, 0u, 2u, 1u);
    const uint negative_order[6] = uint[6](0u, 1u, 2u, 0u, 2u, 3u);
    return positive ? positive_order[vertex_id] : negative_order[vertex_id];
}

void main() {
    uvec2 packed = faces[gl_InstanceIndex];
    uint geometry = packed.x;
    uint appearance = packed.y;
    vec3 plane = vec3(
        float((geometry >> 0u) & 63u),
        float((geometry >> 6u) & 63u),
        float((geometry >> 12u) & 63u)
    );
    uint direction = (geometry >> 18u) & 7u;
    float width = float((appearance & 31u) + 1u);
    float height = float(((appearance >> 5u) & 31u) + 1u);
    uint axis = direction / 2u;
    bool positive = (direction & 1u) != 0u;
    uint axis_u = (axis + 1u) % 3u;
    uint axis_v = (axis + 2u) % 3u;
    uint corner = triangle_corner(uint(gl_VertexIndex), positive);

    vec3 local_position = plane;
    if (corner == 1u || corner == 2u) {
        local_position[axis_u] += width;
    }
    if (corner == 2u || corner == 3u) {
        local_position[axis_v] += height;
    }

    vertex_normal = vec3(0.0);
    vertex_normal[axis] = positive ? 1.0 : -1.0;
    gl_Position = project_chunk_position(local_position);
}

#[fragment]
#version 450

layout(location = 0) in vec3 vertex_normal;
layout(location = 0) out vec4 fragment_color;

void main() {
    vec3 direction_color = vec3(0.16) + abs(normalize(vertex_normal)) * 0.78;
    fragment_color = vec4(direction_color, 1.0);
}
