#[path = "../src/terrain_domain_warp.rs"]
mod terrain_domain_warp;

fn distance(a: (f64, f64), b: (f64, f64)) -> f64 {
    let dx = a.0 - b.0;
    let dz = a.1 - b.1;
    (dx * dx + dz * dz).sqrt()
}

#[test]
fn warp_is_deterministic_and_seeded() {
    let a = terrain_domain_warp::coordinates(91_337, -247, 613);
    let b = terrain_domain_warp::coordinates(91_337, -247, 613);
    let c = terrain_domain_warp::coordinates(91_338, -247, 613);
    assert_eq!(a, b);
    assert!(distance(a, c) > 0.01);
}

#[test]
fn warp_remains_bounded_and_continuous() {
    for z in (-1024..=1024).step_by(73) {
        for x in (-1024..=1024).step_by(67) {
            let origin = terrain_domain_warp::coordinates(91_337, x, z);
            let next_x = terrain_domain_warp::coordinates(91_337, x + 1, z);
            let next_z = terrain_domain_warp::coordinates(91_337, x, z + 1);
            let offset = terrain_domain_warp::offset(91_337, x, z);
            assert!(offset.0.abs() <= 24.000_001);
            assert!(offset.1.abs() <= 24.000_001);
            assert!(distance(origin, next_x) < 1.8);
            assert!(distance(origin, next_z) < 1.8);
        }
    }
}

#[test]
fn warped_noise_is_normalized_and_material() {
    let mut minimum = 1.0_f64;
    let mut maximum = 0.0_f64;
    for z in (-768..=768).step_by(48) {
        for x in (-768..=768).step_by(48) {
            let value = terrain_domain_warp::warped_value_noise(91_337, x, z, 88.0, 19);
            assert!((0.0..=1.0).contains(&value));
            minimum = minimum.min(value);
            maximum = maximum.max(value);
        }
    }
    assert!(maximum - minimum > 0.35);
}
