# TEKNIK terrain texture source and filtering contract

## External source

The terrain layers are derived from **Cartoon Outdoor Tileable Textures** by
**profpatonildo**, published on OpenGameArt under **CC0 1.0 Universal**:

- source page: https://opengameart.org/content/cartoon-outdoor-tileable-textures
- grass: https://opengameart.org/sites/default/files/grass_62.png
- dirt: https://opengameart.org/sites/default/files/dirt_18.png
- stone: https://opengameart.org/sites/default/files/stone_16.png

CC0 permits use, modification, redistribution and commercial distribution without
an attribution requirement. This document remains in the repository as provenance.
No Minecraft artwork or resource-pack files are included.

The generator pins the exact downloaded source bytes and stops rather than silently
building from a changed remote file:

- grass SHA-256: `8bf522a2ee3953c205620d1de13faaa1e12e2811d7afb25225f531db700f1c2f`
- dirt SHA-256: `8267f53518e6f47f33639bef5e8de86eb9a46830019f7c8371357e8aeb330993`
- stone SHA-256: `a2f1876a25c2084cedaf47f7a3ce080095412149431f10b420d1145a581e4aa1`

## Derived layers

`tools/build_cc0_terrain_layers.py` downloads the three pinned CC0 source images
when regeneration is required and produces nine deterministic 128x128 layers:

1. grass top;
2. grass side;
3. dirt;
4. stone;
5. sand;
6. zinc ore;
7. copper ore;
8. iron ore;
9. gold ore.

The source images are blurred before downsampling so each block contains broad
material forms rather than high-frequency speckles. The grass-side layer is a
derivative composite with a continuous sod band at image V=0 and an irregular
fringe extending downward over the dirt source.

## Runtime contract

- The shader uses `sampler2DArray`, not an atlas. Each layer therefore owns an
  independent mip chain and cannot bleed into adjacent materials.
- No per-block texture variants, rotations or random UV offsets are used.
- Side-face V coordinates are inverted so the authored top edge maps to the
  physical top edge of the block.
- Filtering is nearest-mipmap anisotropic with 4x anisotropy on mobile.
- Mipmap bias is neutral (`0.0`).
- Texture detail fades toward the material/biome average from 24 to 88 world
  units. This removes distant grass static while preserving nearby material detail.
- Terrain remains one shared opaque surface and one texture sample per fragment.

The physical Vivo T3x gameplay capture remains the final visual and performance
acceptance gate. CI can verify resource construction, mip chains, shader contracts
and ARM64 packaging, but it cannot judge shimmer during real device movement.
