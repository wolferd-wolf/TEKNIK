use crate::terrain::{fast_surface_color, AIR, PADDED_SIZE, SIZE};
use crate::{TeknikColor4, TeknikPackedFace, TeknikVec3};

pub const FACE_DIRECTION_COUNT: usize = 6;
pub const FACE_NEG_X: u32 = 0;
pub const FACE_POS_X: u32 = 1;
pub const FACE_NEG_Y: u32 = 2;
pub const FACE_POS_Y: u32 = 3;
pub const FACE_NEG_Z: u32 = 4;
pub const FACE_POS_Z: u32 = 5;

const X_SHIFT: u32 = 0;
const Y_SHIFT: u32 = 5;
const Z_SHIFT: u32 = 10;
const DIRECTION_SHIFT: u32 = 15;
const MATERIAL_SHIFT: u32 = 18;
const FLAGS_SHIFT: u32 = 26;
const WIDTH_SHIFT: u32 = 0;
const HEIGHT_SHIFT: u32 = 5;
const FIVE_BIT_MASK: u32 = 0x1f;
const THREE_BIT_MASK: u32 = 0x07;
const EIGHT_BIT_MASK: u32 = 0xff;
const SIX_BIT_MASK: u32 = 0x3f;

pub struct MeshOutput {
    pub vertices: Vec<TeknikVec3>,
    pub normals: Vec<TeknikVec3>,
    pub colors: Vec<TeknikColor4>,
    pub indices: Vec<i32>,
    pub packed_faces: Vec<TeknikPackedFace>,
    pub directional_faces: [Vec<TeknikPackedFace>; FACE_DIRECTION_COUNT],
    pub quads: u32,
}

impl MeshOutput {
    fn empty() -> Self {
        Self {
            vertices: Vec::new(),
            normals: Vec::new(),
            colors: Vec::new(),
            indices: Vec::new(),
            packed_faces: Vec::new(),
            directional_faces: std::array::from_fn(|_| Vec::new()),
            quads: 0,
        }
    }
}

#[inline]
fn padded_index(x: i32, y: i32, z: i32) -> usize {
    (x + PADDED_SIZE as i32 * (z + PADDED_SIZE as i32 * y)) as usize
}

#[inline]
fn vec3(values: [f32; 3]) -> TeknikVec3 {
    TeknikVec3 {
        x: values[0],
        y: values[1],
        z: values[2],
    }
}

#[inline]
fn add(a: [f32; 3], b: [f32; 3]) -> [f32; 3] {
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
}

#[inline]
fn direction_for(axis: usize, positive: bool) -> u32 {
    match (axis, positive) {
        (0, false) => FACE_NEG_X,
        (0, true) => FACE_POS_X,
        (1, false) => FACE_NEG_Y,
        (1, true) => FACE_POS_Y,
        (2, false) => FACE_NEG_Z,
        (2, true) => FACE_POS_Z,
        _ => unreachable!("voxel faces use exactly three axes"),
    }
}

#[inline]
fn direction_axis(direction: u32) -> Option<(usize, bool)> {
    match direction {
        FACE_NEG_X => Some((0, false)),
        FACE_POS_X => Some((0, true)),
        FACE_NEG_Y => Some((1, false)),
        FACE_POS_Y => Some((1, true)),
        FACE_NEG_Z => Some((2, false)),
        FACE_POS_Z => Some((2, true)),
        _ => None,
    }
}

#[inline]
fn pack_face(
    anchor: [u32; 3],
    direction: u32,
    material: u8,
    width: u32,
    height: u32,
    flags: u32,
) -> TeknikPackedFace {
    debug_assert!(anchor.into_iter().all(|value| value < SIZE as u32));
    debug_assert!(direction < FACE_DIRECTION_COUNT as u32);
    debug_assert!(material > AIR);
    debug_assert!((1..=SIZE as u32).contains(&width));
    debug_assert!((1..=SIZE as u32).contains(&height));
    debug_assert!(flags <= SIX_BIT_MASK);
    TeknikPackedFace {
        geometry: ((anchor[0] & FIVE_BIT_MASK) << X_SHIFT)
            | ((anchor[1] & FIVE_BIT_MASK) << Y_SHIFT)
            | ((anchor[2] & FIVE_BIT_MASK) << Z_SHIFT)
            | ((direction & THREE_BIT_MASK) << DIRECTION_SHIFT)
            | (((material as u32) & EIGHT_BIT_MASK) << MATERIAL_SHIFT)
            | ((flags & SIX_BIT_MASK) << FLAGS_SHIFT),
        appearance: (((width - 1) & FIVE_BIT_MASK) << WIDTH_SHIFT)
            | (((height - 1) & FIVE_BIT_MASK) << HEIGHT_SHIFT),
    }
}

#[inline]
pub fn unpack_face(face: TeknikPackedFace) -> Option<([u32; 3], u32, u8, u32, u32, u32)> {
    let anchor = [
        (face.geometry >> X_SHIFT) & FIVE_BIT_MASK,
        (face.geometry >> Y_SHIFT) & FIVE_BIT_MASK,
        (face.geometry >> Z_SHIFT) & FIVE_BIT_MASK,
    ];
    let direction = (face.geometry >> DIRECTION_SHIFT) & THREE_BIT_MASK;
    let material = ((face.geometry >> MATERIAL_SHIFT) & EIGHT_BIT_MASK) as u8;
    let flags = (face.geometry >> FLAGS_SHIFT) & SIX_BIT_MASK;
    let width = ((face.appearance >> WIDTH_SHIFT) & FIVE_BIT_MASK) + 1;
    let height = ((face.appearance >> HEIGHT_SHIFT) & FIVE_BIT_MASK) + 1;
    if direction_axis(direction).is_none()
        || material == AIR
        || width > SIZE as u32
        || height > SIZE as u32
    {
        return None;
    }
    Some((anchor, direction, material, width, height, flags))
}

fn append_legacy_quad(
    output: &mut MeshOutput,
    origin: [f32; 3],
    delta_u: [f32; 3],
    delta_v: [f32; 3],
    axis: usize,
    face: i32,
    world_origin: (i32, i32, i32),
    seed: i64,
) {
    let base = output.vertices.len() as i32;
    let positions = [
        origin,
        add(origin, delta_u),
        add(add(origin, delta_u), delta_v),
        add(origin, delta_v),
    ];
    let mut normal = [0.0_f32; 3];
    normal[axis] = if face > 0 { 1.0 } else { -1.0 };
    let face_light = if axis == 1 && face > 0 {
        1.03_f64
    } else if axis == 1 {
        0.76_f64
    } else {
        0.94_f64
    };

    for position in positions {
        let sample = (
            world_origin.0 + position[0].round() as i32,
            world_origin.1 + position[1].round() as i32,
            world_origin.2 + position[2].round() as i32,
        );
        let base_color = fast_surface_color(seed, face.unsigned_abs() as u8, sample);
        let phase = (sample.0 as f64 * 12.9898
            + sample.1 as f64 * 37.719
            + sample.2 as f64 * 78.233)
            .sin()
            * 43_758.5453;
        let variation = 0.96 + phase.rem_euclid(1.0) * 0.07;
        output.vertices.push(vec3(position));
        output.normals.push(vec3(normal));
        output.colors.push(TeknikColor4 {
            r: (base_color[0] as f64 * face_light * variation) as f32,
            g: (base_color[1] as f64 * face_light * variation) as f32,
            b: (base_color[2] as f64 * face_light * variation) as f32,
            a: 1.0,
        });
    }

    if face > 0 {
        output.indices.extend_from_slice(&[
            base,
            base + 3,
            base + 2,
            base,
            base + 2,
            base + 1,
        ]);
    } else {
        output.indices.extend_from_slice(&[
            base,
            base + 1,
            base + 2,
            base,
            base + 2,
            base + 3,
        ]);
    }
    output.quads += 1;
}

fn append_quad(
    output: &mut MeshOutput,
    origin: [f32; 3],
    delta_u: [f32; 3],
    delta_v: [f32; 3],
    axis: usize,
    face: i32,
    world_origin: (i32, i32, i32),
    seed: i64,
) {
    let positive = face > 0;
    let direction = direction_for(axis, positive);
    let axis_u = (axis + 1) % 3;
    let axis_v = (axis + 2) % 3;
    let mut anchor = [
        origin[0].round() as i32,
        origin[1].round() as i32,
        origin[2].round() as i32,
    ];
    if positive {
        anchor[axis] -= 1;
    }
    let width = delta_u[axis_u].round() as u32;
    let height = delta_v[axis_v].round() as u32;
    let packed = pack_face(
        [anchor[0] as u32, anchor[1] as u32, anchor[2] as u32],
        direction,
        face.unsigned_abs() as u8,
        width,
        height,
        0,
    );
    output.packed_faces.push(packed);
    output.directional_faces[direction as usize].push(packed);
    append_legacy_quad(
        output,
        origin,
        delta_u,
        delta_v,
        axis,
        face,
        world_origin,
        seed,
    );
}

pub fn decode_packed_faces(
    packed_faces: &[TeknikPackedFace],
    world_origin: (i32, i32, i32),
    seed: i64,
) -> Option<MeshOutput> {
    let mut output = MeshOutput::empty();
    output.packed_faces.reserve(packed_faces.len());
    for packed in packed_faces {
        let (anchor, direction, material, width, height, _flags) = unpack_face(*packed)?;
        let (axis, positive) = direction_axis(direction)?;
        let axis_u = (axis + 1) % 3;
        let axis_v = (axis + 2) % 3;
        let mut origin = [anchor[0] as f32, anchor[1] as f32, anchor[2] as f32];
        if positive {
            origin[axis] += 1.0;
        }
        let mut delta_u = [0.0_f32; 3];
        let mut delta_v = [0.0_f32; 3];
        delta_u[axis_u] = width as f32;
        delta_v[axis_v] = height as f32;
        let signed_face = if positive {
            material as i32
        } else {
            -(material as i32)
        };
        output.packed_faces.push(*packed);
        output.directional_faces[direction as usize].push(*packed);
        append_legacy_quad(
            &mut output,
            origin,
            delta_u,
            delta_v,
            axis,
            signed_face,
            world_origin,
            seed,
        );
    }
    Some(output)
}

pub fn build_mesh(
    padded: &[u8],
    world_origin: (i32, i32, i32),
    seed: i64,
) -> MeshOutput {
    let mut output = MeshOutput::empty();
    let mut mask = vec![0_i32; SIZE * SIZE];
    let dimensions = [SIZE as i32; 3];

    for axis in 0..3 {
        let axis_u = (axis + 1) % 3;
        let axis_v = (axis + 2) % 3;
        let mut cursor = [0_i32; 3];
        let mut step = [0_i32; 3];
        step[axis] = 1;
        cursor[axis] = -1;

        while cursor[axis] < dimensions[axis] {
            let mut mask_index = 0_usize;
            for coordinate_v in 0..dimensions[axis_v] {
                cursor[axis_v] = coordinate_v;
                for coordinate_u in 0..dimensions[axis_u] {
                    cursor[axis_u] = coordinate_u;
                    let padded_x = cursor[0] + 1;
                    let padded_y = cursor[1] + 1;
                    let padded_z = cursor[2] + 1;
                    let current = padded[padded_index(padded_x, padded_y, padded_z)];
                    let neighbor = padded[padded_index(
                        padded_x + step[0],
                        padded_y + step[1],
                        padded_z + step[2],
                    )];
                    mask[mask_index] = if (current == AIR) == (neighbor == AIR) {
                        0
                    } else if current != AIR {
                        current as i32
                    } else {
                        -(neighbor as i32)
                    };
                    mask_index += 1;
                }
            }

            cursor[axis] += 1;
            mask_index = 0;
            for coordinate_v in 0..dimensions[axis_v] {
                let mut coordinate_u = 0_i32;
                while coordinate_u < dimensions[axis_u] {
                    let face = mask[mask_index];
                    if face == 0 {
                        coordinate_u += 1;
                        mask_index += 1;
                        continue;
                    }

                    let mut width = 1_i32;
                    while coordinate_u + width < dimensions[axis_u]
                        && mask[mask_index + width as usize] == face
                    {
                        width += 1;
                    }

                    let mut height = 1_i32;
                    let mut height_valid = true;
                    while coordinate_v + height < dimensions[axis_v] && height_valid {
                        for offset_u in 0..width {
                            let index = mask_index
                                + offset_u as usize
                                + height as usize * dimensions[axis_u] as usize;
                            if mask[index] != face {
                                height_valid = false;
                                break;
                            }
                        }
                        if height_valid {
                            height += 1;
                        }
                    }

                    cursor[axis_u] = coordinate_u;
                    cursor[axis_v] = coordinate_v;
                    let origin = [cursor[0] as f32, cursor[1] as f32, cursor[2] as f32];
                    let mut delta_u = [0.0_f32; 3];
                    let mut delta_v = [0.0_f32; 3];
                    delta_u[axis_u] = width as f32;
                    delta_v[axis_v] = height as f32;
                    append_quad(
                        &mut output,
                        origin,
                        delta_u,
                        delta_v,
                        axis,
                        face,
                        world_origin,
                        seed,
                    );

                    for offset_v in 0..height {
                        for offset_u in 0..width {
                            let index = mask_index
                                + offset_u as usize
                                + offset_v as usize * dimensions[axis_u] as usize;
                            mask[index] = 0;
                        }
                    }
                    coordinate_u += width;
                    mask_index += width as usize;
                }
            }
        }
    }
    output
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::terrain::{PADDED_VOLUME, STONE};

    fn assert_vec3_equal(left: &[TeknikVec3], right: &[TeknikVec3]) {
        assert_eq!(left.len(), right.len());
        for (left_value, right_value) in left.iter().zip(right) {
            assert_eq!(left_value.x.to_bits(), right_value.x.to_bits());
            assert_eq!(left_value.y.to_bits(), right_value.y.to_bits());
            assert_eq!(left_value.z.to_bits(), right_value.z.to_bits());
        }
    }

    fn assert_colors_equal(left: &[TeknikColor4], right: &[TeknikColor4]) {
        assert_eq!(left.len(), right.len());
        for (left_value, right_value) in left.iter().zip(right) {
            assert_eq!(left_value.r.to_bits(), right_value.r.to_bits());
            assert_eq!(left_value.g.to_bits(), right_value.g.to_bits());
            assert_eq!(left_value.b.to_bits(), right_value.b.to_bits());
            assert_eq!(left_value.a.to_bits(), right_value.a.to_bits());
        }
    }

    #[test]
    fn packed_face_decoder_reproduces_legacy_arrays_exactly() {
        let mut padded = vec![AIR; PADDED_VOLUME];
        for y in 0..13_i32 {
            for z in 0..SIZE as i32 {
                for x in 0..SIZE as i32 {
                    padded[padded_index(x + 1, y + 1, z + 1)] = if y == 12 { 3 } else { STONE };
                }
            }
        }
        padded[padded_index(7, 14, 9)] = STONE;
        let original = build_mesh(&padded, (-64, 0, 96), 73_421);
        let decoded = decode_packed_faces(&original.packed_faces, (-64, 0, 96), 73_421)
            .expect("valid packed faces decode");
        assert_eq!(original.quads, decoded.quads);
        assert_eq!(original.indices, decoded.indices);
        assert_vec3_equal(&original.vertices, &decoded.vertices);
        assert_vec3_equal(&original.normals, &decoded.normals);
        assert_colors_equal(&original.colors, &decoded.colors);
    }

    #[test]
    fn packed_face_supports_positive_plane_32_and_full_extent() {
        let mut padded = vec![AIR; PADDED_VOLUME];
        for y in 0..SIZE as i32 {
            for z in 0..SIZE as i32 {
                for x in 0..SIZE as i32 {
                    padded[padded_index(x + 1, y + 1, z + 1)] = STONE;
                }
            }
        }
        let mesh = build_mesh(&padded, (0, 0, 0), 73_421);
        assert_eq!(mesh.quads, 6);
        assert_eq!(mesh.packed_faces.len(), 6);
        for packed in &mesh.packed_faces {
            let (anchor, direction, material, width, height, flags) =
                unpack_face(*packed).expect("solid-cube face decodes");
            assert!(anchor.into_iter().all(|value| value <= 31));
            assert!(direction < FACE_DIRECTION_COUNT as u32);
            assert_eq!(material, STONE);
            assert_eq!(width, 32);
            assert_eq!(height, 32);
            assert_eq!(flags, 0);
        }
        let positive_x = mesh
            .packed_faces
            .iter()
            .copied()
            .find(|face| unpack_face(*face).unwrap().1 == FACE_POS_X)
            .expect("positive X face exists");
        assert_eq!(unpack_face(positive_x).unwrap().0[0], 31);
    }

    #[test]
    fn directional_streams_partition_every_face() {
        let mut padded = vec![AIR; PADDED_VOLUME];
        padded[padded_index(2, 2, 2)] = STONE;
        padded[padded_index(3, 2, 2)] = STONE;
        let mesh = build_mesh(&padded, (0, 0, 0), 73_421);
        let total: usize = mesh.directional_faces.iter().map(Vec::len).sum();
        assert_eq!(total, mesh.packed_faces.len());
        for (direction, stream) in mesh.directional_faces.iter().enumerate() {
            for face in stream {
                assert_eq!(unpack_face(*face).unwrap().1 as usize, direction);
            }
        }
    }
}
