#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TeknikEdit {
    int32_t chunk_x;
    int32_t chunk_y;
    int32_t chunk_z;
    uint32_t index;
    uint8_t material;
    uint8_t padding[3];
} TeknikEdit;

typedef struct TeknikVec3 {
    float x;
    float y;
    float z;
} TeknikVec3;

typedef struct TeknikColor4 {
    float r;
    float g;
    float b;
    float a;
} TeknikColor4;

typedef struct TeknikPackedFace {
    uint32_t geometry;
    uint32_t appearance;
} TeknikPackedFace;

typedef struct TeknikChunkResult TeknikChunkResult;

const char *teknik_core_version(void);

TeknikChunkResult *teknik_build_chunk(
    int64_t seed,
    int32_t chunk_x,
    int32_t chunk_y,
    int32_t chunk_z,
    const TeknikEdit *edits,
    size_t edit_count
);

void teknik_free_chunk_result(TeknikChunkResult *result);

const uint8_t *teknik_result_voxels(const TeknikChunkResult *result);
size_t teknik_result_voxel_count(const TeknikChunkResult *result);

const TeknikVec3 *teknik_result_vertices(const TeknikChunkResult *result);
size_t teknik_result_vertex_count(const TeknikChunkResult *result);

const TeknikVec3 *teknik_result_normals(const TeknikChunkResult *result);
size_t teknik_result_normal_count(const TeknikChunkResult *result);

const TeknikColor4 *teknik_result_colors(const TeknikChunkResult *result);
size_t teknik_result_color_count(const TeknikChunkResult *result);

const int32_t *teknik_result_indices(const TeknikChunkResult *result);
size_t teknik_result_index_count(const TeknikChunkResult *result);

const TeknikPackedFace *teknik_result_packed_faces(const TeknikChunkResult *result);
size_t teknik_result_packed_face_count(const TeknikChunkResult *result);

const TeknikPackedFace *teknik_result_directional_faces(const TeknikChunkResult *result);
size_t teknik_result_directional_face_count(const TeknikChunkResult *result);

const uint32_t *teknik_result_direction_offsets(const TeknikChunkResult *result);
size_t teknik_result_direction_offset_count(const TeknikChunkResult *result);

const uint32_t *teknik_result_direction_counts(const TeknikChunkResult *result);
size_t teknik_result_direction_count_count(const TeknikChunkResult *result);

uint32_t teknik_result_quad_count(const TeknikChunkResult *result);
uint32_t teknik_result_applied_edit_count(const TeknikChunkResult *result);
uint32_t teknik_result_boundary_column_count(const TeknikChunkResult *result);
uint64_t teknik_result_generation_usec(const TeknikChunkResult *result);
uint64_t teknik_result_mesh_usec(const TeknikChunkResult *result);
uint64_t teknik_result_voxel_checksum(const TeknikChunkResult *result);
uint64_t teknik_result_packed_face_checksum(const TeknikChunkResult *result);

#ifdef __cplusplus
}
#endif
