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
#include <vector>

using namespace godot;

namespace {

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
            if (voxel_index < 0 || voxel_index >= 32 * 32 * 32) {
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
    if (voxel_count != 32 * 32 * 32 || normal_count != vertex_count || color_count != vertex_count) {
        report["success"] = false;
        report["error"] = "Rust chunk core returned inconsistent array sizes";
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

    report["success"] = true;
    report["native_backend"] = true;
    report["native_core_version"] = core_version();
    report["coordinate"] = coordinate;
    report["voxels"] = voxels;
    report["arrays"] = arrays;
    report["quads"] = static_cast<int64_t>(teknik_result_quad_count(guard.result));
    report["vertices"] = static_cast<int64_t>(vertex_count);
    report["triangles"] = static_cast<int64_t>(index_count / 3);
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
    return report;
}

String TeknikNativeChunkBuilder::core_version() const {
    const char *version = teknik_core_version();
    return version == nullptr ? String("unknown") : String::utf8(version);
}
