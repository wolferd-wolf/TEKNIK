# TEKNIK

TEKNIK is an original single-player voxel survival sandbox built with **Godot 4.7.1**, targeting **Android first** (GL Compatibility renderer) with desktop as the development platform. All code, textures, names, and assets are original — generated procedurally, no third-party game content.

## Current state

Implemented and tested (see `tests/`):

- **Voxel world**: 16×16×128 chunks, deterministic seeded generation (value-noise FBM heightmaps, biomes, caves, ores, water, beaches), cross-chunk trees/structures, underground ruins.
- **Streaming**: radius-based chunk generate/mesh/unload with a per-frame time budget; edits persist per chunk; unmodified chunks regenerate from seed.
- **Rendering**: face-culled chunk meshes (opaque / cutout / liquid passes), one shared texture atlas (generated pixel art), vertex-lit shading, fog + day/night sky.
- **Player**: first-person controller (walk/sprint/crouch/jump/swim, fall damage, edge guard while crouched), voxel DDA raycast interaction, block breaking with hardness/tool/tier rules, placement with occupancy checks, item drops with magnet pickup.
- **Survival**: health, hunger drain, regeneration, starvation, death/respawn, food.
- **Inventory/crafting**: 36-slot inventory (9 hotbar), tap-to-move stacks, durability, 20+ recipes, bench-gated advanced recipes.
- **Mobs**: passive (Tuft) and night-hostile (Grimb) with wander/chase/attack, spawn caps, distance despawn, drops.
- **Day/night**: sun/moon cycle driving light, sky, fog, and hostile spawn windows.
- **Save/load**: 3 world slots; seed + player + edited-block diffs saved as JSON; autosave.
- **Touch controls**: virtual joystick, look-drag, hold-to-mine/place, jump/crouch/bag buttons; desktop keyboard/mouse fully supported.
- **Tests**: headless unit suite (`tests/run_tests.gd`) + boot/session smoke test (`tests/smoke_session.gd`).

## Layout

```
src/world/     chunk data, generator, noise, streaming world, day/night
src/render/    chunk mesher + chunk scene node
src/entities/  player, mobs, item drops, spawner
src/items/     item/block registries, inventory, recipes
src/ui/        HUD, inventory screen, touch controls
src/game/      session assembly (GameWorld)
src/main.gd    menu, session flow, input map
src/gen/       generated GDScript (atlas tile indices)
tools_dev/     texture atlas generator (Python + Pillow)
tests/         headless unit tests + smoke test
```

## Local validation

With Godot 4.7.1 available as `godot`:

```bash
# generate the texture atlas (deterministic)
python3 tools_dev/gen_atlas.py

# import + compile check
godot --headless --path . --editor --quit

# unit tests
godot --headless --path . --script tests/run_tests.gd

# boot + play-session smoke test
godot --headless --path . --script tests/smoke_session.gd
```

## Android

`export_presets.cfg` defines an Android (arm64) preset; CI exports a debug APK. Performance targets 50–60 FPS on low/mid-range devices: GL Compatibility renderer, budgeted chunk streaming, shared atlas, low draw-call chunk meshes, capped mob counts.

## CI

The `TEKNIK CI` workflow installs Godot 4.7.1, regenerates the atlas, runs the import + unit tests + smoke test, and uploads an Android debug APK artifact.
