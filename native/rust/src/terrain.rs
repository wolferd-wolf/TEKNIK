use crate::EditMap;

pub const SIZE: usize = 32;
pub const VOLUME: usize = SIZE * SIZE * SIZE;
pub const PADDED_SIZE: usize = SIZE + 2;
pub const PADDED_VOLUME: usize = PADDED_SIZE * PADDED_SIZE * PADDED_SIZE;
pub const AIR: u8 = 0;
pub const STONE: u8 = 1;
pub const SOIL: u8 = 2;
pub const GRASS: u8 = 3;
pub const SAND: u8 = 4;
pub const WATER_LEVEL: i32 = 7;
pub const MAX_SURFACE_HEIGHT: i32 = 29;
const COLUMN_GRID_SIZE: usize = SIZE + 2;

#[derive(Clone, Copy, Debug)]
pub struct Column {
    pub height: i32,
    pub top_material: u8,
}

#[derive(Clone, Copy)]
struct HeightProfile {
    height: i32,
    ridge: f64,
    escarpment: f64,
    river_gap: f64,
}

#[inline]
fn voxel_index(x: usize, y: usize, z: usize) -> usize {
    x + SIZE * (z + SIZE * y)
}

#[inline]
fn padded_index(x: usize, y: usize, z: usize) -> usize {
    x + PADDED_SIZE * (z + PADDED_SIZE * y)
}

#[inline]
fn lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}

#[inline]
fn smooth(value: f64) -> f64 {
    value * value * (3.0 - 2.0 * value)
}

#[inline]
fn smoothstep(edge0: f64, edge1: f64, value: f64) -> f64 {
    if edge0 == edge1 {
        return if value < edge0 { 0.0 } else { 1.0 };
    }
    let t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

#[inline]
fn hash_2d(seed: i64, x: i32, z: i32) -> i64 {
    let wrapped_x = (x as i64) & 0x1f_ffff;
    let wrapped_z = (z as i64) & 0x1f_ffff;
    let mut value = (wrapped_x * 374_761_393 + wrapped_z * 668_265_263 + seed * 69_069)
        & 0x7fff_ffff;
    value = ((value ^ (value >> 13)) * 1_274_126_177) & 0x7fff_ffff;
    (value ^ (value >> 16)) & 0x7fff_ffff
}

#[inline]
fn sample_unit(seed: i64, x: i32, z: i32) -> f64 {
    (hash_2d(seed, x, z) % 1_000_000) as f64 / 999_999.0
}

fn sample_value_noise(seed: i64, x: f64, z: f64, cell_size: f64) -> f64 {
    let grid_x = x / cell_size;
    let grid_z = z / cell_size;
    let x0 = grid_x.floor() as i32;
    let z0 = grid_z.floor() as i32;
    let blend_x = smooth(grid_x - x0 as f64);
    let blend_z = smooth(grid_z - z0 as f64);
    let north = lerp(
        sample_unit(seed, x0, z0),
        sample_unit(seed, x0 + 1, z0),
        blend_x,
    );
    let south = lerp(
        sample_unit(seed, x0, z0 + 1),
        sample_unit(seed, x0 + 1, z0 + 1),
        blend_x,
    );
    lerp(north, south, blend_z)
}

fn terrain_landmark_profile(seed: i64, world_x: i32, world_z: i32) -> (f64, f64, f64) {
    let ridge_noise = sample_value_noise(seed + 1_709, world_x as f64, world_z as f64, 118.0);
    let ridge = (ridge_noise * 2.0 - 1.0).abs().powf(2.35);
    let basin_noise = sample_value_noise(seed + 1_783, world_x as f64, world_z as f64, 164.0);
    let basin = smoothstep(0.58, 0.84, basin_noise);
    let escarpment_noise =
        sample_value_noise(seed + 1_861, world_x as f64, world_z as f64, 76.0);
    let escarpment = smoothstep(0.60, 0.88, escarpment_noise) * ridge;
    (ridge, basin, escarpment)
}

fn river_center_z(seed: i64, world_x: i32) -> f64 {
    let broad = sample_value_noise(seed + 541, world_x as f64, 0.0, 74.0);
    let smaller = sample_value_noise(seed + 617, world_x as f64, 0.0, 31.0);
    (broad - 0.5) * 30.0 + (smaller - 0.5) * 8.0
}

fn river_distance(seed: i64, world_x: i32, world_z: i32) -> f64 {
    (world_z as f64 - river_center_z(seed, world_x)).abs()
}

fn terrain_height_profile(seed: i64, world_x: i32, world_z: i32) -> HeightProfile {
    let continental = sample_value_noise(seed + 19, world_x as f64, world_z as f64, 88.0);
    let rolling = sample_value_noise(seed + 131, world_x as f64, world_z as f64, 34.0);
    let detail = sample_value_noise(seed + 227, world_x as f64, world_z as f64, 17.0);
    let (ridge, basin, escarpment) = terrain_landmark_profile(seed, world_x, world_z);
    let upland_height = 10.0
        + continental * 7.5
        + (rolling - 0.5) * 3.5
        + (detail - 0.5) * 1.25
        + ridge * 7.5
        + escarpment * 2.5
        - basin * 3.0;
    let distance_to_river = river_distance(seed, world_x, world_z);
    let channel_floor = (WATER_LEVEL - 2) as f64;
    let inner_bank = smoothstep(3.5, 9.5, distance_to_river);
    let outer_bank = smoothstep(9.5, 27.0, distance_to_river);
    let bank_height = lerp(channel_floor, (WATER_LEVEL + 2) as f64, inner_bank);
    let mut carved_height = lerp(bank_height, upland_height, outer_bank);
    if distance_to_river < 3.5 {
        carved_height = carved_height.min(channel_floor);
    }
    HeightProfile {
        height: (carved_height.round() as i32).clamp(2, MAX_SURFACE_HEIGHT),
        ridge,
        escarpment,
        river_gap: distance_to_river,
    }
}

pub fn surface_height(seed: i64, world_x: i32, world_z: i32) -> i32 {
    terrain_height_profile(seed, world_x, world_z).height
}

fn surface_slope(seed: i64, world_x: i32, world_z: i32) -> i32 {
    let center = surface_height(seed, world_x, world_z);
    [
        surface_height(seed, world_x + 1, world_z),
        surface_height(seed, world_x - 1, world_z),
        surface_height(seed, world_x, world_z + 1),
        surface_height(seed, world_x, world_z - 1),
    ]
    .into_iter()
    .map(|height| (center - height).abs())
    .max()
    .unwrap_or(0)
}

fn surface_material_cached(
    height: i32,
    slope: i32,
    ridge: f64,
    escarpment: f64,
    river_gap: f64,
) -> u8 {
    if height <= WATER_LEVEL + 1 || (river_gap < 10.5 && height <= WATER_LEVEL + 3) {
        return SAND;
    }
    if slope >= 2 && (height >= 15 || escarpment > 0.38) {
        return STONE;
    }
    if height >= 24 && ridge > 0.62 {
        return STONE;
    }
    GRASS
}

pub fn sample_column(seed: i64, world_x: i32, world_z: i32) -> Column {
    let height = surface_height(seed, world_x, world_z);
    let river_gap = river_distance(seed, world_x, world_z);
    if height <= WATER_LEVEL + 1 || (river_gap < 10.5 && height <= WATER_LEVEL + 3) {
        return Column {
            height,
            top_material: SAND,
        };
    }
    let slope = surface_slope(seed, world_x, world_z);
    let (ridge, _, escarpment) = terrain_landmark_profile(seed, world_x, world_z);
    Column {
        height,
        top_material: surface_material_cached(height, slope, ridge, escarpment, river_gap),
    }
}

#[inline]
pub fn material_from_column(world_y: i32, column: Column) -> u8 {
    if world_y > column.height {
        AIR
    } else if world_y == column.height {
        column.top_material
    } else if column.top_material == SAND && world_y >= column.height - 3 {
        SAND
    } else if column.top_material != STONE && world_y >= column.height - 2 {
        SOIL
    } else {
        STONE
    }
}

pub fn generate_chunk(
    seed: i64,
    coordinate: (i32, i32, i32),
    edits: &EditMap,
) -> (Vec<u8>, u32) {
    let world_origin = (
        coordinate.0 * SIZE as i32,
        coordinate.1 * SIZE as i32,
        coordinate.2 * SIZE as i32,
    );
    let grid_volume = COLUMN_GRID_SIZE * COLUMN_GRID_SIZE;
    let mut heights = vec![0_i32; grid_volume];
    let mut ridges = vec![0.0_f64; grid_volume];
    let mut escarpments = vec![0.0_f64; grid_volume];
    let mut river_gaps = vec![0.0_f64; grid_volume];

    for grid_z in 0..COLUMN_GRID_SIZE {
        for grid_x in 0..COLUMN_GRID_SIZE {
            let world_x = world_origin.0 + grid_x as i32 - 1;
            let world_z = world_origin.2 + grid_z as i32 - 1;
            let profile = terrain_height_profile(seed, world_x, world_z);
            let index = grid_z * COLUMN_GRID_SIZE + grid_x;
            heights[index] = profile.height;
            ridges[index] = profile.ridge;
            escarpments[index] = profile.escarpment;
            river_gaps[index] = profile.river_gap;
        }
    }

    let mut voxels = vec![AIR; VOLUME];
    for z in 0..SIZE {
        for x in 0..SIZE {
            let grid_x = x + 1;
            let grid_z = z + 1;
            let grid_index = grid_z * COLUMN_GRID_SIZE + grid_x;
            let height = heights[grid_index];
            let slope = [
                heights[grid_index - 1],
                heights[grid_index + 1],
                heights[grid_index - COLUMN_GRID_SIZE],
                heights[grid_index + COLUMN_GRID_SIZE],
            ]
            .into_iter()
            .map(|neighbor| (height - neighbor).abs())
            .max()
            .unwrap_or(0);
            let top_material = surface_material_cached(
                height,
                slope,
                ridges[grid_index],
                escarpments[grid_index],
                river_gaps[grid_index],
            );
            let highest_local_y = (height - world_origin.1).min(SIZE as i32 - 1);
            if highest_local_y < 0 {
                continue;
            }
            for y in 0..=highest_local_y as usize {
                let world_y = world_origin.1 + y as i32;
                let material = material_from_column(
                    world_y,
                    Column {
                        height,
                        top_material,
                    },
                );
                if material != AIR {
                    voxels[voxel_index(x, y, z)] = material;
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
    world_position: (i32, i32, i32),
    current_y: i32,
    edits: &EditMap,
) -> u8 {
    if world_position.1 < current_y * SIZE as i32 {
        return STONE;
    }
    if world_position.1 >= (current_y + 1) * SIZE as i32 {
        return AIR;
    }
    let chunk_x = world_position.0.div_euclid(SIZE as i32);
    let chunk_z = world_position.2.div_euclid(SIZE as i32);
    let coordinate = (chunk_x, current_y, chunk_z);
    let local_x = world_position.0 - chunk_x * SIZE as i32;
    let local_y = world_position.1 - current_y * SIZE as i32;
    let local_z = world_position.2 - chunk_z * SIZE as i32;
    let column = sample_column(seed, world_position.0, world_position.2);
    let generated = material_from_column(world_position.1, column);
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

#[inline]
fn color(hex: u32) -> [f64; 4] {
    [
        ((hex >> 16) & 0xff) as f64 / 255.0,
        ((hex >> 8) & 0xff) as f64 / 255.0,
        (hex & 0xff) as f64 / 255.0,
        1.0,
    ]
}

#[inline]
fn color_lerp(a: [f64; 4], b: [f64; 4], t: f64) -> [f64; 4] {
    [
        lerp(a[0], b[0], t),
        lerp(a[1], b[1], t),
        lerp(a[2], b[2], t),
        lerp(a[3], b[3], t),
    ]
}

pub fn fast_surface_color(
    seed: i64,
    material: u8,
    world_position: (i32, i32, i32),
) -> [f32; 4] {
    let elevation = ((world_position.1 as f64 - 8.0) / (MAX_SURFACE_HEIGHT as f64 - 8.0))
        .clamp(0.0, 1.0);
    let micro = sample_unit(
        seed + 2_143,
        world_position.0 * 3 + world_position.1,
        world_position.2 * 3 - world_position.1,
    );
    let tint = (micro - 0.5) * 0.09;
    let mut value = match material {
        GRASS => color_lerp(color(0x4d7543), color(0x456653), elevation * 0.38),
        SOIL => color_lerp(color(0x604536), color(0x493f38), elevation * 0.34),
        SAND => {
            let wetness = 1.0 - smoothstep(
                5.0,
                18.0,
                river_distance(seed, world_position.0, world_position.2),
            );
            color_lerp(color(0xa58c5c), color(0x746b54), wetness * 0.62)
        }
        STONE => {
            let strata = (world_position.1 as f64 + micro * 2.0).rem_euclid(5.0) / 5.0;
            color_lerp(
                color(0x5d6865),
                color(0x7c8580),
                elevation * 0.36 + (strata - 0.5).abs() * 0.12,
            )
        }
        _ => color(0x8c7e69),
    };
    if tint > 0.0 {
        value = color_lerp(value, [1.0, 1.0, 1.0, value[3]], tint);
    } else if tint < 0.0 {
        value = color_lerp(value, [0.0, 0.0, 0.0, value[3]], -tint);
    }
    [
        value[0] as f32,
        value[1] as f32,
        value[2] as f32,
        value[3] as f32,
    ]
}
