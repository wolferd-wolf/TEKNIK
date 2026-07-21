use crate::terrain::{fast_surface_color, AIR, PADDED_SIZE, SIZE};
use crate::{TeknikColor4, TeknikVec3};

pub struct MeshOutput {
    pub vertices: Vec<TeknikVec3>,
    pub normals: Vec<TeknikVec3>,
    pub colors: Vec<TeknikColor4>,
    pub indices: Vec<i32>,
    pub quads: u32,
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

pub fn build_mesh(
    padded: &[u8],
    world_origin: (i32, i32, i32),
    seed: i64,
) -> MeshOutput {
    let mut output = MeshOutput {
        vertices: Vec::new(),
        normals: Vec::new(),
        colors: Vec::new(),
        indices: Vec::new(),
        quads: 0,
    };
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
