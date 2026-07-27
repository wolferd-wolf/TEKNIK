use crate::EditMap;

#[path = "../terrain_base.rs"]
mod base;
mod cave_density;

pub use base::{
    fast_surface_color, material_from_column, sample_column, surface_height, Column, AIR, GRASS,
    MAX_SURFACE_HEIGHT, PADDED_SIZE, PADDED_VOLUME, SAND, SIZE, SOIL, STONE, VOLUME, WATER_LEVEL,
};

#[inline]
fn voxel_index(x: usize, y: usize, z: usize) -> usize {
    x + SIZE * (z + SIZE * y)
}

#[inline]
fn padded_index(x: usize, y: usize, z: usize) -> usize {
    x + PADDED_SIZE * (z + PADDED_SIZE * y)
}

#[inline]
fn generated_material(seed: i64, world: (i32, i32, i32), column: Column) -> u8 {
    let material = base::material_from_column(world.1, column);
    if material != AIR && cave_density::should_carve(seed, world, column.height) {
        AIR
    } else {
        material
    }
}

pub fn generate_chunk(
    seed: i64,
    coordinate: (i32, i32, i32),
    edits: &EditMap,
) -> (Vec<u8>, u32) {
    let empty_edits = EditMap::new();
    let (mut voxels, _) = base::generate_chunk(seed, coordinate, &empty_edits);
    let world_origin = (
        coordinate.0 * SIZE as i32,
        coordinate.1 * SIZE as i32,
        coordinate.2 * SIZE as i32,
    );

    for z in 0..SIZE {
        for x in 0..SIZE {
            let mut highest_local_y: i32 = -1;
            for y in (0..SIZE).rev() {
                if voxels[voxel_index(x, y, z)] != AIR {
                    highest_local_y = y as i32;
                    break;
                }
            }
            if highest_local_y < 0 {
                continue;
            }
            let surface_height = world_origin.1 + highest_local_y;
            for y in 0..=highest_local_y as usize {
                let index = voxel_index(x, y, z);
                if voxels[index] == AIR {
                    continue;
                }
                let world = (
                    world_origin.0 + x as i32,
                    world_origin.1 + y as i32,
                    world_origin.2 + z as i32,
                );
                if cave_density::should_carve(seed, world, surface_height) {
                    voxels[index] = AIR;
                }
            }
        }
    }

    let mut applied = 0_u32;
    if let Some(chunk_edits) = edits.get(&coordinate) {
        for (&index, &material) in chunk_edits {
            if index < VOLUME && voxels[index] != material {
                voxels[index] = material;
                applied += 1;
            }
        }
    }
    (voxels, applied)
}

fn edit_override(
    edits: &EditMap,
    coordinate: (i32, i32, i32),
    local_x: i32,
    local_y: i32,
    local_z: i32,
    generated: u8,
) -> u8 {
    if !(0..SIZE as i32).contains(&local_x)
        || !(0..SIZE as i32).contains(&local_y)
        || !(0..SIZE as i32).contains(&local_z)
    {
        return generated;
    }
    let index = voxel_index(local_x as usize, local_y as usize, local_z as usize);
    edits
        .get(&coordinate)
        .and_then(|chunk| chunk.get(&index))
        .copied()
        .unwrap_or(generated)
}

fn sample_world_voxel(
    seed: i64,
    world: (i32, i32, i32),
    current_y: i32,
    edits: &EditMap,
) -> u8 {
    if world.1 < current_y * SIZE as i32 {
        return STONE;
    }
    if world.1 >= (current_y + 1) * SIZE as i32 {
        return AIR;
    }
    let chunk_x = world.0.div_euclid(SIZE as i32);
    let chunk_z = world.2.div_euclid(SIZE as i32);
    let coordinate = (chunk_x, current_y, chunk_z);
    let local_x = world.0 - chunk_x * SIZE as i32;
    let local_y = world.1 - current_y * SIZE as i32;
    let local_z = world.2 - chunk_z * SIZE as i32;
    let column = base::sample_column(seed, world.0, world.2);
    let generated = generated_material(seed, world, column);
    edit_override(
        edits,
        coordinate,
        local_x,
        local_y,
        local_z,
        generated,
    )
}

pub fn build_padded(
    seed: i64,
    coordinate: (i32, i32, i32),
    voxels: &[u8],
    edits: &EditMap,
) -> (Vec<u8>, u32) {
    let mut padded = vec![AIR; PADDED_VOLUME];
    for y in 0..SIZE {
        for z in 0..SIZE {
            let chunk_row = SIZE * (z + SIZE * y);
            let padded_row = 1 + PADDED_SIZE * ((z + 1) + PADDED_SIZE * (y + 1));
            padded[padded_row..padded_row + SIZE]
                .copy_from_slice(&voxels[chunk_row..chunk_row + SIZE]);
        }
    }

    let world_origin = (
        coordinate.0 * SIZE as i32,
        coordinate.1 * SIZE as i32,
        coordinate.2 * SIZE as i32,
    );
    for y in 0..SIZE {
        for z in 0..SIZE {
            padded[padded_index(0, y + 1, z + 1)] = sample_world_voxel(
                seed,
                (world_origin.0 - 1, world_origin.1 + y as i32, world_origin.2 + z as i32),
                coordinate.1,
                edits,
            );
            padded[padded_index(SIZE + 1, y + 1, z + 1)] = sample_world_voxel(
                seed,
                (
                    world_origin.0 + SIZE as i32,
                    world_origin.1 + y as i32,
                    world_origin.2 + z as i32,
                ),
                coordinate.1,
                edits,
            );
        }
    }
    for z in 0..SIZE {
        for x in 0..SIZE {
            padded[padded_index(x + 1, 0, z + 1)] = STONE;
            padded[padded_index(x + 1, SIZE + 1, z + 1)] = AIR;
        }
    }
    for y in 0..SIZE {
        for x in 0..SIZE {
            padded[padded_index(x + 1, y + 1, 0)] = sample_world_voxel(
                seed,
                (world_origin.0 + x as i32, world_origin.1 + y as i32, world_origin.2 - 1),
                coordinate.1,
                edits,
            );
            padded[padded_index(x + 1, y + 1, SIZE + 1)] = sample_world_voxel(
                seed,
                (
                    world_origin.0 + x as i32,
                    world_origin.1 + y as i32,
                    world_origin.2 + SIZE as i32,
                ),
                coordinate.1,
                edits,
            );
        }
    }
    (padded, (SIZE * 4) as u32)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caves_exist_below_a_protected_roof() {
        let edits = EditMap::new();
        let (voxels, _) = generate_chunk(73_421, (0, 0, 0), &edits);
        let mut caves = 0_usize;
        for z in 0..SIZE {
            for x in 0..SIZE {
                let column = base::sample_column(73_421, x as i32, z as i32);
                let surface = column.height;
                for y in 0..SIZE {
                    let index = voxel_index(x, y, z);
                    let underground = y as i32 <= surface;
                    if underground && (y <= 1 || surface - y as i32 < 4) {
                        assert_ne!(voxels[index], AIR);
                    } else if underground && voxels[index] == AIR {
                        caves += 1;
                    }
                }
            }
        }
        assert!(caves > 100, "expected a useful underground cave volume");
    }

    #[test]
    fn padded_side_samples_match_neighbor_caves() {
        let edits = EditMap::new();
        let (center, _) = generate_chunk(73_421, (0, 0, 0), &edits);
        let (right, _) = generate_chunk(73_421, (1, 0, 0), &edits);
        let (padded, _) = build_padded(73_421, (0, 0, 0), &center, &edits);
        for y in 0..SIZE {
            for z in 0..SIZE {
                assert_eq!(
                    padded[padded_index(SIZE + 1, y + 1, z + 1)],
                    right[voxel_index(0, y, z)]
                );
            }
        }
    }
}
