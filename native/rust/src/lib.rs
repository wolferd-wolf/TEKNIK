mod mesher;
mod terrain;

use std::collections::HashMap;
use std::ffi::c_char;
use std::slice;
use std::time::Instant;

pub type ChunkKey = (i32, i32, i32);
pub type EditMap = HashMap<ChunkKey, HashMap<usize, u8>>;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct TeknikEdit {
    pub chunk_x: i32,
    pub chunk_y: i32,
    pub chunk_z: i32,
    pub index: u32,
    pub material: u8,
    pub padding: [u8; 3],
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct TeknikVec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct TeknikColor4 {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

pub struct TeknikChunkResult {
    voxels: Vec<u8>,
    vertices: Vec<TeknikVec3>,
    normals: Vec<TeknikVec3>,
    colors: Vec<TeknikColor4>,
    indices: Vec<i32>,
    quads: u32,
    applied_edits: u32,
    boundary_columns: u32,
    generation_usec: u64,
    mesh_usec: u64,
    voxel_checksum: u64,
}

static VERSION: &[u8] = b"teknik-rust-core-1\0";

fn checksum_bytes(bytes: &[u8]) -> u64 {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    for byte in bytes {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

fn build_edit_map(edits: &[TeknikEdit]) -> EditMap {
    let mut map: EditMap = HashMap::new();
    for edit in edits {
        let index = edit.index as usize;
        if index >= terrain::VOLUME {
            continue;
        }
        map.entry((edit.chunk_x, edit.chunk_y, edit.chunk_z))
            .or_default()
            .insert(index, edit.material);
    }
    map
}

#[no_mangle]
pub extern "C" fn teknik_core_version() -> *const c_char {
    VERSION.as_ptr().cast()
}

#[no_mangle]
pub unsafe extern "C" fn teknik_build_chunk(
    seed: i64,
    chunk_x: i32,
    chunk_y: i32,
    chunk_z: i32,
    edits: *const TeknikEdit,
    edit_count: usize,
) -> *mut TeknikChunkResult {
    if edit_count > 0 && edits.is_null() {
        return std::ptr::null_mut();
    }
    let edit_slice = if edit_count == 0 {
        &[]
    } else {
        slice::from_raw_parts(edits, edit_count)
    };
    let edit_map = build_edit_map(edit_slice);
    let coordinate = (chunk_x, chunk_y, chunk_z);

    let generation_started = Instant::now();
    let (voxels, applied_edits) = terrain::generate_chunk(seed, coordinate, &edit_map);
    let generation_usec = generation_started.elapsed().as_micros() as u64;

    let mesh_started = Instant::now();
    let (padded, boundary_columns) =
        terrain::build_padded(seed, coordinate, &voxels, &edit_map);
    let mesh = mesher::build_mesh(
        &padded,
        (
            chunk_x * terrain::SIZE as i32,
            chunk_y * terrain::SIZE as i32,
            chunk_z * terrain::SIZE as i32,
        ),
        seed,
    );
    let mesh_usec = mesh_started.elapsed().as_micros() as u64;
    let voxel_checksum = checksum_bytes(&voxels);

    Box::into_raw(Box::new(TeknikChunkResult {
        voxels,
        vertices: mesh.vertices,
        normals: mesh.normals,
        colors: mesh.colors,
        indices: mesh.indices,
        quads: mesh.quads,
        applied_edits,
        boundary_columns,
        generation_usec,
        mesh_usec,
        voxel_checksum,
    }))
}

#[no_mangle]
pub unsafe extern "C" fn teknik_free_chunk_result(result: *mut TeknikChunkResult) {
    if !result.is_null() {
        drop(Box::from_raw(result));
    }
}

macro_rules! pointer_getter {
    ($name:ident, $field:ident, $type:ty) => {
        #[no_mangle]
        pub unsafe extern "C" fn $name(result: *const TeknikChunkResult) -> *const $type {
            result
                .as_ref()
                .map(|value| value.$field.as_ptr())
                .unwrap_or(std::ptr::null())
        }
    };
}

macro_rules! count_getter {
    ($name:ident, $field:ident) => {
        #[no_mangle]
        pub unsafe extern "C" fn $name(result: *const TeknikChunkResult) -> usize {
            result
                .as_ref()
                .map(|value| value.$field.len())
                .unwrap_or(0)
        }
    };
}

pointer_getter!(teknik_result_voxels, voxels, u8);
count_getter!(teknik_result_voxel_count, voxels);
pointer_getter!(teknik_result_vertices, vertices, TeknikVec3);
count_getter!(teknik_result_vertex_count, vertices);
pointer_getter!(teknik_result_normals, normals, TeknikVec3);
count_getter!(teknik_result_normal_count, normals);
pointer_getter!(teknik_result_colors, colors, TeknikColor4);
count_getter!(teknik_result_color_count, colors);
pointer_getter!(teknik_result_indices, indices, i32);
count_getter!(teknik_result_index_count, indices);

#[no_mangle]
pub unsafe extern "C" fn teknik_result_quad_count(result: *const TeknikChunkResult) -> u32 {
    result.as_ref().map(|value| value.quads).unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn teknik_result_applied_edit_count(
    result: *const TeknikChunkResult,
) -> u32 {
    result
        .as_ref()
        .map(|value| value.applied_edits)
        .unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn teknik_result_boundary_column_count(
    result: *const TeknikChunkResult,
) -> u32 {
    result
        .as_ref()
        .map(|value| value.boundary_columns)
        .unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn teknik_result_generation_usec(
    result: *const TeknikChunkResult,
) -> u64 {
    result
        .as_ref()
        .map(|value| value.generation_usec)
        .unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn teknik_result_mesh_usec(result: *const TeknikChunkResult) -> u64 {
    result.as_ref().map(|value| value.mesh_usec).unwrap_or(0)
}

#[no_mangle]
pub unsafe extern "C" fn teknik_result_voxel_checksum(
    result: *const TeknikChunkResult,
) -> u64 {
    result
        .as_ref()
        .map(|value| value.voxel_checksum)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_chunk_build() {
        let edits = [TeknikEdit {
            chunk_x: 0,
            chunk_y: 0,
            chunk_z: 0,
            index: 7,
            material: terrain::AIR,
            padding: [0; 3],
        }];
        let map = build_edit_map(&edits);
        let (first, _) = terrain::generate_chunk(73_421, (0, 0, 0), &map);
        let (second, _) = terrain::generate_chunk(73_421, (0, 0, 0), &map);
        assert_eq!(first, second);
        assert_eq!(first.len(), terrain::VOLUME);
    }

    #[test]
    fn mesher_emits_indexed_geometry() {
        let edits = EditMap::new();
        let (voxels, _) = terrain::generate_chunk(73_421, (0, 0, 0), &edits);
        let (padded, _) = terrain::build_padded(73_421, (0, 0, 0), &voxels, &edits);
        let mesh = mesher::build_mesh(&padded, (0, 0, 0), 73_421);
        assert!(mesh.quads > 0);
        assert_eq!(mesh.vertices.len(), mesh.normals.len());
        assert_eq!(mesh.vertices.len(), mesh.colors.len());
        assert_eq!(mesh.indices.len(), mesh.quads as usize * 6);
    }
}
