#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace godot {

class TeknikTerrainRenderer : public RefCounted {
    GDCLASS(TeknikTerrainRenderer, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary probe_renderer() const;
    Dictionary render_chunk_parity_preview(
        PackedInt32Array packed_faces,
        PackedVector3Array legacy_vertices,
        PackedVector3Array legacy_normals,
        PackedInt32Array legacy_indices,
        Vector3i chunk_origin,
        int64_t image_size = 256
    ) const;
};

} // namespace godot
