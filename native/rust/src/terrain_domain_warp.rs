const BROAD_CELL: f64 = 192.0;
const DETAIL_CELL: f64 = 83.0;
const BROAD_AMPLITUDE: f64 = 18.0;
const DETAIL_AMPLITUDE: f64 = 6.0;

#[inline]
fn lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}

#[inline]
fn smooth(value: f64) -> f64 {
    value * value * (3.0 - 2.0 * value)
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

pub fn offset(seed: i64, world_x: i32, world_z: i32) -> (f64, f64) {
    let broad_x = sample_value_noise(seed + 2_401, world_x as f64, world_z as f64, BROAD_CELL) * 2.0 - 1.0;
    let broad_z = sample_value_noise(seed + 2_417, world_x as f64, world_z as f64, BROAD_CELL) * 2.0 - 1.0;
    let detail_x = sample_value_noise(seed + 2_443, world_x as f64, world_z as f64, DETAIL_CELL) * 2.0 - 1.0;
    let detail_z = sample_value_noise(seed + 2_459, world_x as f64, world_z as f64, DETAIL_CELL) * 2.0 - 1.0;
    (
        broad_x * BROAD_AMPLITUDE + detail_x * DETAIL_AMPLITUDE,
        broad_z * BROAD_AMPLITUDE + detail_z * DETAIL_AMPLITUDE,
    )
}

pub fn coordinates(seed: i64, world_x: i32, world_z: i32) -> (f64, f64) {
    let displacement = offset(seed, world_x, world_z);
    (world_x as f64 + displacement.0, world_z as f64 + displacement.1)
}

pub fn warped_value_noise(
    seed: i64,
    world_x: i32,
    world_z: i32,
    cell_size: f64,
    seed_offset: i64,
) -> f64 {
    let warped = coordinates(seed, world_x, world_z);
    sample_value_noise(seed + seed_offset, warped.0, warped.1, cell_size)
}
