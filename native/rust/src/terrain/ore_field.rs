use super::{COPPER_ORE, GOLD_ORE, IRON_ORE, STONE, ZINC_ORE};

const CELL_SIZE: i32 = 8;
const MAX_ORE_Y: i32 = 24;
const SURFACE_ROOF: i32 = 4;
const HASH_MASK: i64 = 0x7fff_ffff;

#[inline]
pub fn material_for_stone(seed: i64, world: (i32, i32, i32), surface_height: i32) -> u8 {
    if world.1 <= 1 || world.1 > MAX_ORE_Y || surface_height - world.1 < SURFACE_ROOF {
        return STONE;
    }

    let cell = (
        world.0.div_euclid(CELL_SIZE),
        world.1.div_euclid(CELL_SIZE),
        world.2.div_euclid(CELL_SIZE),
    );
    let value = hash_3d(seed + 4_201, cell.0, cell.1, cell.2);
    let selector = value % 1_000;
    let material = if world.1 <= 7 && selector < 35 {
        GOLD_ORE
    } else if world.1 <= 14 && selector < 140 {
        IRON_ORE
    } else if world.1 <= 20 && selector < 240 {
        COPPER_ORE
    } else if selector < 330 {
        ZINC_ORE
    } else {
        return STONE;
    };

    let center = (
        1 + ((value >> 10) % 6) as i32,
        1 + ((value >> 13) % 6) as i32,
        1 + ((value >> 16) % 6) as i32,
    );
    let local = (
        world.0 - cell.0 * CELL_SIZE,
        world.1 - cell.1 * CELL_SIZE,
        world.2 - cell.2 * CELL_SIZE,
    );
    let radius = if ((value >> 20) & 3) == 0 { 3 } else { 2 };
    let dx = local.0 - center.0;
    let dy = local.1 - center.1;
    let dz = local.2 - center.2;
    if dx * dx + dy * dy + dz * dz <= radius * radius {
        material
    } else {
        STONE
    }
}

#[inline]
fn hash_3d(seed: i64, x: i32, y: i32, z: i32) -> i64 {
    let wrapped_x = (x as i64) & 0x1f_ffff;
    let wrapped_y = (y as i64) & 0x1f_ffff;
    let wrapped_z = (z as i64) & 0x1f_ffff;
    let mut value = (wrapped_x * 374_761_393
        + wrapped_z * 668_265_263
        + wrapped_y * 1_442_695_041
        + seed * 69_069)
        & HASH_MASK;
    value = ((value ^ (value >> 13)) * 1_274_126_177) & HASH_MASK;
    (value ^ (value >> 16)) & HASH_MASK
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_ore_types_exist_below_the_protected_roof() {
        let mut counts = [0_usize; 9];
        for z in -64..=64 {
            for x in -64..=64 {
                for y in 2..=24 {
                    let material = material_for_stone(73_421, (x, y, z), 29);
                    counts[material as usize] += 1;
                }
            }
        }
        assert!(counts[ZINC_ORE as usize] > 100);
        assert!(counts[COPPER_ORE as usize] > 100);
        assert!(counts[IRON_ORE as usize] > 100);
        assert!(counts[GOLD_ORE as usize] > 10);
        assert_eq!(material_for_stone(73_421, (4, 1, 4), 29), STONE);
        assert_eq!(material_for_stone(73_421, (4, 26, 4), 29), STONE);
    }
}
