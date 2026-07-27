const CHUNK_SIZE: usize = 32;
const CHUNK_VOLUME: usize = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;
const REGION_SIZE: i32 = 48;
const WORMS_PER_REGION: i32 = 2;
const WORM_STEPS: i32 = 18;
const MAX_RADIUS: i32 = 4;
const MAX_REACH: i32 = WORM_STEPS * 3 + MAX_RADIUS + 2;
const MIN_WORLD_Y: i32 = 2;
const SURFACE_ROOF: i32 = 4;

#[inline]
fn voxel_index(x: usize, y: usize, z: usize) -> usize {
    x + CHUNK_SIZE * (z + CHUNK_SIZE * y)
}

pub fn build_chunk_mask(seed: i64, coordinate: (i32, i32, i32)) -> Vec<u8> {
    let mut mask = vec![0_u8; CHUNK_VOLUME];
    let world_origin = (
        coordinate.0 * CHUNK_SIZE as i32,
        coordinate.1 * CHUNK_SIZE as i32,
        coordinate.2 * CHUNK_SIZE as i32,
    );
    let min_region_x = (world_origin.0 - MAX_REACH).div_euclid(REGION_SIZE);
    let max_region_x =
        (world_origin.0 + CHUNK_SIZE as i32 - 1 + MAX_REACH).div_euclid(REGION_SIZE);
    let min_region_z = (world_origin.2 - MAX_REACH).div_euclid(REGION_SIZE);
    let max_region_z =
        (world_origin.2 + CHUNK_SIZE as i32 - 1 + MAX_REACH).div_euclid(REGION_SIZE);

    for region_z in min_region_z..=max_region_z {
        for region_x in min_region_x..=max_region_x {
            for worm_index in 0..WORMS_PER_REGION {
                rasterize_worm(
                    &mut mask,
                    world_origin,
                    seed,
                    region_x,
                    region_z,
                    worm_index,
                );
            }
        }
    }
    mask
}

#[inline]
pub fn mask_carves(mask: &[u8], index: usize, world_y: i32, surface_height: i32) -> bool {
    world_y >= MIN_WORLD_Y
        && surface_height - world_y >= SURFACE_ROOF
        && mask.get(index).copied().unwrap_or(0) != 0
}

pub fn should_carve(seed: i64, world: (i32, i32, i32), surface_height: i32) -> bool {
    if world.1 < MIN_WORLD_Y || surface_height - world.1 < SURFACE_ROOF {
        return false;
    }
    let coordinate = (
        world.0.div_euclid(CHUNK_SIZE as i32),
        world.1.div_euclid(CHUNK_SIZE as i32),
        world.2.div_euclid(CHUNK_SIZE as i32),
    );
    let local = (
        world.0.rem_euclid(CHUNK_SIZE as i32) as usize,
        world.1.rem_euclid(CHUNK_SIZE as i32) as usize,
        world.2.rem_euclid(CHUNK_SIZE as i32) as usize,
    );
    let mask = build_chunk_mask(seed, coordinate);
    mask_carves(
        &mask,
        voxel_index(local.0, local.1, local.2),
        world.1,
        surface_height,
    )
}

fn rasterize_worm(
    mask: &mut [u8],
    world_origin: (i32, i32, i32),
    seed: i64,
    region_x: i32,
    region_z: i32,
    worm_index: i32,
) {
    let worm_seed = seed + 4_001 + i64::from(worm_index) * 977;
    if worm_index > 0 && (sample_hash(worm_seed, region_x, worm_index, region_z) & 3) == 0 {
        return;
    }
    let region_origin_x = region_x * REGION_SIZE;
    let region_origin_z = region_z * REGION_SIZE;
    let start_span = REGION_SIZE - 16;
    let mut center = (
        region_origin_x
            + 8
            + sample_hash(worm_seed + 11, region_x, worm_index, region_z)
                .rem_euclid(i64::from(start_span)) as i32,
        4 + sample_hash(worm_seed + 37, region_x, worm_index, region_z).rem_euclid(13)
            as i32,
        region_origin_z
            + 8
            + sample_hash(worm_seed + 23, region_x, worm_index, region_z)
                .rem_euclid(i64::from(start_span)) as i32,
    );
    let mut heading =
        sample_hash(worm_seed + 41, region_x, worm_index, region_z).rem_euclid(8) as i32;

    for step in 0..WORM_STEPS {
        let step_hash = sample_hash(
            worm_seed + i64::from(step) * 53,
            region_x,
            step + worm_index * 31,
            region_z,
        );
        let mut radius = 2 + (step_hash & 1) as i32;
        if step % 7 == 3 && ((step_hash >> 3) & 3) == 3 {
            radius = MAX_RADIUS;
        }
        carve_sphere(mask, world_origin, center, radius);

        match (step_hash >> 5).rem_euclid(5) {
            0 => heading = (heading + 7) % 8,
            4 => heading = (heading + 1) % 8,
            _ => {}
        }
        let mut vertical_step = ((step_hash >> 9).rem_euclid(3) as i32) - 1;
        if center.1 <= 5 && vertical_step < 0 {
            vertical_step = 0;
        } else if center.1 >= 18 && vertical_step > 0 {
            vertical_step = 0;
        }
        let direction = direction(heading);
        center.0 += direction.0;
        center.1 += vertical_step;
        center.2 += direction.1;
    }
}

fn carve_sphere(
    mask: &mut [u8],
    world_origin: (i32, i32, i32),
    center: (i32, i32, i32),
    radius: i32,
) {
    if center.0 + radius < world_origin.0
        || center.0 - radius >= world_origin.0 + CHUNK_SIZE as i32
        || center.1 + radius < world_origin.1
        || center.1 - radius >= world_origin.1 + CHUNK_SIZE as i32
        || center.2 + radius < world_origin.2
        || center.2 - radius >= world_origin.2 + CHUNK_SIZE as i32
    {
        return;
    }

    let min_x = (center.0 - radius - world_origin.0).max(0) as usize;
    let max_x = (center.0 + radius - world_origin.0).min(CHUNK_SIZE as i32 - 1) as usize;
    let min_y = (center.1 - radius - world_origin.1).max(0) as usize;
    let max_y = (center.1 + radius - world_origin.1).min(CHUNK_SIZE as i32 - 1) as usize;
    let min_z = (center.2 - radius - world_origin.2).max(0) as usize;
    let max_z = (center.2 + radius - world_origin.2).min(CHUNK_SIZE as i32 - 1) as usize;
    let radius_squared = radius * radius;

    for local_y in min_y..=max_y {
        let delta_y = world_origin.1 + local_y as i32 - center.1;
        for local_z in min_z..=max_z {
            let delta_z = world_origin.2 + local_z as i32 - center.2;
            for local_x in min_x..=max_x {
                let delta_x = world_origin.0 + local_x as i32 - center.0;
                if delta_x * delta_x + delta_y * delta_y + delta_z * delta_z
                    <= radius_squared
                {
                    mask[voxel_index(local_x, local_y, local_z)] = 1;
                }
            }
        }
    }
}

#[inline]
fn direction(heading: i32) -> (i32, i32) {
    match heading & 7 {
        0 => (3, 0),
        1 => (2, 2),
        2 => (0, 3),
        3 => (-2, 2),
        4 => (-3, 0),
        5 => (-2, -2),
        6 => (0, -3),
        _ => (2, -2),
    }
}

#[inline]
fn sample_hash(seed: i64, x: i32, y: i32, z: i32) -> i64 {
    let wrapped_x = i64::from(x) & 0x1f_ffff;
    let wrapped_y = i64::from(y) & 0x1f_ffff;
    let wrapped_z = i64::from(z) & 0x1f_ffff;
    let mut value = (wrapped_x * 374_761_393
        + wrapped_y * 1_442_695_041
        + wrapped_z * 668_265_263
        + seed * 69_069)
        & 0x7fff_ffff;
    value = ((value ^ (value >> 13)) * 1_274_126_177) & 0x7fff_ffff;
    (value ^ (value >> 16)) & 0x7fff_ffff
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn masks_are_deterministic_and_keep_the_protected_shell() {
        let first = build_chunk_mask(73_421, (0, 0, 0));
        let second = build_chunk_mask(73_421, (0, 0, 0));
        assert_eq!(first, second);
        assert!(first.iter().any(|&value| value != 0));
        assert!(!should_carve(73_421, (17, 18, -23), 21));
        assert!(!should_carve(73_421, (17, 1, -23), 21));
    }

    #[test]
    fn neighboring_chunks_share_world_space_worms() {
        let left = build_chunk_mask(73_421, (-1, 0, 0));
        let center = build_chunk_mask(73_421, (0, 0, 0));
        assert!(left.iter().filter(|&&value| value != 0).count() > 100);
        assert!(center.iter().filter(|&&value| value != 0).count() > 100);
    }
}
