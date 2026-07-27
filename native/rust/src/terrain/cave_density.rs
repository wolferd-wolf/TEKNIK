const FIXED_SCALE: i64 = 4096;
const NOISE_MID: i64 = 32_768;
const TUNNEL_BAND_A: i64 = 8_000;
const TUNNEL_BAND_B: i64 = 10_000;
const CHAMBER_THRESHOLD: i64 = 61_500;
const MIN_WORLD_Y: i32 = 2;
const SURFACE_ROOF: i32 = 4;

#[inline]
pub fn should_carve(seed: i64, world: (i32, i32, i32), surface_height: i32) -> bool {
    let depth = surface_height - world.1;
    if world.1 < MIN_WORLD_Y || depth < SURFACE_ROOF {
        return false;
    }

    let safety = (depth - (SURFACE_ROOF - 1)).min(world.1 - 1) as i64;
    let band_a = TUNNEL_BAND_A.min(5_000 + safety * 700);
    let band_b = TUNNEL_BAND_B.min(6_500 + safety * 800);
    let stretched_y = world.1 * 2;
    let field_a = sample_noise_3d(seed + 3_001, world.0, stretched_y, world.2, 18);
    let field_b = sample_noise_3d(
        seed + 3_019,
        world.0 + 7,
        stretched_y - 5,
        world.2 - 11,
        23,
    );
    if (field_a - NOISE_MID).abs() < band_a && (field_b - NOISE_MID).abs() < band_b {
        return true;
    }

    if depth < 8 || world.1 < 3 {
        return false;
    }
    let chamber = sample_noise_3d(seed + 3_079, world.0, world.1, world.2, 30);
    if chamber <= CHAMBER_THRESHOLD {
        return false;
    }
    sample_noise_3d(seed + 3_137, world.0 - 19, world.1, world.2 + 13, 15) > 40_000
}

#[inline]
fn sample_noise_3d(seed: i64, x: i32, y: i32, z: i32, cell_size: i32) -> i64 {
    let cell_x = x.div_euclid(cell_size);
    let cell_y = y.div_euclid(cell_size);
    let cell_z = z.div_euclid(cell_size);
    let blend_x = smooth_fixed(x.rem_euclid(cell_size) as i64, cell_size as i64);
    let blend_y = smooth_fixed(y.rem_euclid(cell_size) as i64, cell_size as i64);
    let blend_z = smooth_fixed(z.rem_euclid(cell_size) as i64, cell_size as i64);

    let x00 = lerp_fixed(
        sample_hash(seed, cell_x, cell_y, cell_z),
        sample_hash(seed, cell_x + 1, cell_y, cell_z),
        blend_x,
    );
    let x10 = lerp_fixed(
        sample_hash(seed, cell_x, cell_y + 1, cell_z),
        sample_hash(seed, cell_x + 1, cell_y + 1, cell_z),
        blend_x,
    );
    let x01 = lerp_fixed(
        sample_hash(seed, cell_x, cell_y, cell_z + 1),
        sample_hash(seed, cell_x + 1, cell_y, cell_z + 1),
        blend_x,
    );
    let x11 = lerp_fixed(
        sample_hash(seed, cell_x, cell_y + 1, cell_z + 1),
        sample_hash(seed, cell_x + 1, cell_y + 1, cell_z + 1),
        blend_x,
    );
    let y0 = lerp_fixed(x00, x10, blend_y);
    let y1 = lerp_fixed(x01, x11, blend_y);
    lerp_fixed(y0, y1, blend_z)
}

#[inline]
fn sample_hash(seed: i64, x: i32, y: i32, z: i32) -> i64 {
    let wrapped_x = (x as i64) & 0x1f_ffff;
    let wrapped_y = (y as i64) & 0x1f_ffff;
    let wrapped_z = (z as i64) & 0x1f_ffff;
    let mut value = (wrapped_x * 374_761_393
        + wrapped_y * 1_442_695_041
        + wrapped_z * 668_265_263
        + seed * 69_069)
        & 0x7fff_ffff;
    value = ((value ^ (value >> 13)) * 1_274_126_177) & 0x7fff_ffff;
    ((value ^ (value >> 16)) & 0x7fff_ffff) & 0xffff
}

#[inline]
fn smooth_fixed(remainder: i64, cell_size: i64) -> i64 {
    let t = remainder * FIXED_SCALE / cell_size;
    t * t * (3 * FIXED_SCALE - 2 * t) / (FIXED_SCALE * FIXED_SCALE)
}

#[inline]
fn lerp_fixed(from: i64, to: i64, weight: i64) -> i64 {
    from + (to - from) * weight / FIXED_SCALE
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn field_is_deterministic_and_keeps_roof() {
        let position = (17, 9, -23);
        assert_eq!(
            should_carve(73_421, position, 21),
            should_carve(73_421, position, 21)
        );
        assert!(!should_carve(73_421, (17, 18, -23), 21));
        assert!(!should_carve(73_421, (17, 1, -23), 21));
    }
}
