#include "teknik_native_chunk_builder.h"

#include "../../rust/include/teknik_core.h"

#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstdint>
#include <cstring>
#include <vector>

using namespace godot;

namespace {

constexpr size_t DIRECTION_COUNT = 6;
constexpr size_t VOXEL_COUNT = 32 * 32 * 32;

struct ResultGuard {
    TeknikChunkResult *result = nullptr;
    ~ResultGuard() {
        if (result != nullptr) {
            teknik_free_chunk_result(result);
        }
    }
};

std::vector<TeknikEdit> flatten_edits(const Dictionary &snapshots) {
    std::vector<TeknikEdit> flattened;
    const Array chunk_keys = snapshots.keys();
    for (int64_t chunk_index = 0; chunk_index < chunk_keys.size(); ++chunk_index) {
        const Variant chunk_key_variant = chunk_keys[chunk_index];
        if (chunk_key_variant.get_type() != Variant::VECTOR3I) {
            continue;
        }
        const Vector3i chunk_coordinate = chunk_key_variant;
        const Variant edits_variant = snapshots[chunk_key_variant];
        if (edits_variant.get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary edits = edits_variant;
        const Array edit_keys = edits.keys();
        flattened.reserve(flattened.size() + static_cast<size_t>(edit_keys.size()));
        for (int64_t edit_index = 0; edit_index < edit_keys.size(); ++edit_index) {
            const Variant voxel_index_variant = edit_keys[edit_index];
            if (voxel_index_variant.get_type() != Variant::INT) {
                continue;
            }
            const int64_t voxel_index = voxel_index_variant;
            if (voxel_index < 0 || voxel_index >= static_cast<int64_t>(VOXEL_COUNT)) {
                continue;
            }
            const int64_t material = static_cast<int64_t>(edits[voxel_index_variant]);
            TeknikEdit edit{};
            edit.chunk_x = chunk_coordinate.x;
            edit.chunk_y = chunk_coordinate.y;
            edit.chunk_z = chunk_coordinate.z;
            edit.index = static_cast<uint32_t>(voxel_index);
            edit.material = static_cast<uint8_t>(CLAMP(material, 0, 255));
            flattened.push_back(edit);
        }
    }
    return flattened;
}

int32_t preserve_u32_bits(uint32_t value) {
    int32_t signed_value = 0;
    static_assert(sizeof(signed_value) == sizeof(value));
    std::memcpy(&signed_value, &value, sizeof(value));
    return signed_value;
}

PackedInt32Array copy_packed_faces(const TeknikPackedFace *source, size_t face_count) {
    PackedInt32Array words;
    words.resize(static_cast<int64_t>(face_count * 2));
    int32_t *target = words.ptrw();
    for (size_t index = 0; index < face_count; ++index) {
        target[index * 2] = preserve_u32_bits(source[index].geometry);
        target[index * 2 + 1] = preserve_u32_bits(source[index].appearance);
    }
    return words;
}

PackedInt32Array copy_u32_array(const uint32_t *source, size_t count) {
    PackedInt32Array values;
    values.resize(static_cast<int64_t>(count));
    int32_t *target = values.ptrw();
    for (size_t index = 0; index < count; ++index) {
        target[index] = static_cast<int32_t>(source[index]);
    }
    return values;
}

} // namespace

void TeknikNativeChunkBuilder::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("build_chunk", "seed", "coordinate", "edit_snapshots"),
        &TeknikNativeChunkBuilder::build_chunk
    );
    ClassDB::bind_method(D_METHOD("core_version"), &TeknikNativeChunkBuilder::core_version);
}

Dictionary TeknikNativeChunkBuilder::build_chunk(
    int64_t seed,
    Vector3i coordinate,
    Dictionary edit_snapshots
) const {
    Dictionary report;
    const std::vector<TeknikEdit> edits = flatten_edits(edit_snapshots);
    ResultGuard guard;
    guard.result = teknik_build_chunk(
        seed,
        coordinate.x,
        coordinate.y,
        coordinate.z,
        edits.empty() ? nullptr : edits.data(),
        edits.size()
    );
    if (guard.result == nullptr) {
        report["success"] = false;
        report["error"] = "Rust chunk core returned a null result";
        return report;
    }

    const size_t voxel_count = teknik_result_voxel_count(guard.result);
    const size_t vertex_count = teknik_result_vertex_count(guard.result);
    const size_t normal_count = teknik_result_normal_count(guard.result);
    const size_t color_count = teknik_result_color_count(guard.result);
    const size_t index_count = teknik_result_index_count(guard.result);
    const size_t packed_face_count = teknik_result_packed_face_count(guard.result);
    const size_t directional_face_count = teknik_result_directional_face_count(guard.result);
    const size_t direction_offset_count = teknik_result_direction_offset_count(guard.result);
    const size_t direction_count_count = teknik_result_direction_count_count(guard.result);
    const uint32_t quad_count = teknik_result_quad_count(guard.result);
    if (voxel_count != VOXEL_COUNT
        || normal_count != vertex_count
        || color_count != vertex_count
        || packed_face_count != quad_count
        || directional_face_count != packed_face_count
        || direction_offset_count != DIRECTION_COUNT
        || direction_count_count != DIRECTION_COUNT) {
        report["success"] = false;
        report["error"] = "Rust chunk core returned inconsistent legacy or packed array sizes";
        return report;
    }

    const uint32_t *source_direction_offsets = teknik_result_direction_offsets(guard.result);
    const uint32_t *source_direction_counts = teknik_result_direction_counts(guard.result);
    size_t partitioned_faces = 0;
    for (size_t direction = 0; direction < DIRECTION_COUNT; ++direction) {
        if (source_direction_offsets[direction] != partitioned_faces) {
            report["success"] = false;
            report["error"] = "Rust packed direction offsets are not contiguous";
            return report;
        }
        partitioned_faces += source_direction_counts[direction];
    }
    if (partitioned_faces != packed_face_count) {
        report["success"] = false;
        report["error"] = "Rust packed direction counts do not cover every face";
        return report;
    }

    PackedByteArray voxels;
    voxels.resize(static_cast<int64_t>(voxel_count));
    const uint8_t *source_voxels = teknik_result_voxels(guard.result);
    uint8_t *target_voxels = voxels.ptrw();
    for (size_t index = 0; index < voxel_count; ++index) {
        target_voxels[index] = source_voxels[index];
    }

    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedColorArray colors;
    PackedInt32Array indices;
    vertices.resize(static_cast<int64_t>(vertex_count));
    normals.resize(static_cast<int64_t>(normal_count));
    colors.resize(static_cast<int64_t>(color_count));
    indices.resize(static_cast<int64_t>(index_count));

    const TeknikVec3 *source_vertices = teknik_result_vertices(guard.result);
    const TeknikVec3 *source_normals = teknik_result_normals(guard.result);
    const TeknikColor4 *source_colors = teknik_result_colors(guard.result);
    const int32_t *source_indices = teknik_result_indices(guard.result);
    Vector3 *target_vertices = vertices.ptrw();
    Vector3 *target_normals = normals.ptrw();
    Color *target_colors = colors.ptrw();
    int32_t *target_indices = indices.ptrw();

    for (size_t index = 0; index < vertex_count; ++index) {
        const TeknikVec3 &vertex = source_vertices[index];
        const TeknikVec3 &normal = source_normals[index];
        const TeknikColor4 &color = source_colors[index];
        target_vertices[index] = Vector3(vertex.x, vertex.y, vertex.z);
        target_normals[index] = Vector3(normal.x, normal.y, normal.z);
        target_colors[index] = Color(color.r, color.g, color.b, color.a);
    }
    for (size_t index = 0; index < index_count; ++index) {
        target_indices[index] = source_indices[index];
    }

    Array arrays;
    arrays.resize(Mesh::ARRAY_MAX);
    arrays[Mesh::ARRAY_VERTEX] = vertices;
    arrays[Mesh::ARRAY_NORMAL] = normals;
    arrays[Mesh::ARRAY_COLOR] = colors;
    arrays[Mesh::ARRAY_INDEX] = indices;

    const TeknikPackedFace *source_packed_faces = teknik_result_packed_faces(guard.result);
    const TeknikPackedFace *source_directional_faces = teknik_result_directional_faces(guard.result);
    PackedInt32Array packed_faces = copy_packed_faces(source_packed_faces, packed_face_count);
    PackedInt32Array directional_faces = copy_packed_faces(
        source_directional_faces,
        directional_face_count
    );
    PackedInt32Array direction_offsets = copy_u32_array(
        source_direction_offsets,
        direction_offset_count
    );
    PackedInt32Array direction_counts = copy_u32_array(
        source_direction_counts,
        direction_count_count
    );

    const int64_t packed_face_bytes = static_cast<int64_t>(packed_face_count * sizeof(TeknikPackedFace));
    const int64_t legacy_mesh_bytes = static_cast<int64_t>(
        vertex_count * (sizeof(TeknikVec3) * 2 + sizeof(TeknikColor4))
        + index_count * sizeof(int32_t)
    );

    report["success"] = true;
    report["native_backend"] = true;
    report["native_core_version"] = core_version();
    report["coordinate"] = coordinate;
    report["voxels"] = voxels;
    report["arrays"] = arrays;
    report["quads"] = static_cast<int64_t>(quad_count);
    report["vertices"] = static_cast<int64_t>(vertex_count);
    report["triangles"] = static_cast<int64_t>(index_count / 3);
    report["packed_faces"] = packed_faces;
    report["packed_directional_faces"] = directional_faces;
    report["packed_direction_offsets"] = direction_offsets;
    report["packed_direction_counts"] = direction_counts;
    report["packed_face_count"] = static_cast<int64_t>(packed_face_count);
    report["packed_face_bytes"] = packed_face_bytes;
    report["legacy_mesh_bytes"] = legacy_mesh_bytes;
    report["packed_compression_ratio"] = packed_face_bytes > 0
        ? static_cast<double>(legacy_mesh_bytes) / static_cast<double>(packed_face_bytes)
        : 0.0;
    report["applied_edits"] = static_cast<int64_t>(
        teknik_result_applied_edit_count(guard.result)
    );
    report["boundary_column_count"] = static_cast<int64_t>(
        teknik_result_boundary_column_count(guard.result)
    );
    report["generation_usec"] = static_cast<int64_t>(
        teknik_result_generation_usec(guard.result)
    );
    report["mesh_worker_usec"] = static_cast<int64_t>(
        teknik_result_mesh_usec(guard.result)
    );
    report["voxel_checksum"] = static_cast<int64_t>(
        teknik_result_voxel_checksum(guard.result)
    );
    report["packed_face_checksum"] = static_cast<int64_t>(
        teknik_result_packed_face_checksum(guard.result)
    );
    return report;
}

String TeknikNativeChunkBuilder::core_version() const {
    const char *version = teknik_core_version();
    return version == nullptr ? String("unknown") : String::utf8(version);
}
