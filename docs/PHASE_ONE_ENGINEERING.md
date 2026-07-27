# TEKNIK Phase 1 Engineering Foundation

## Reference boundary

The user-provided `create-1.21.1-6.0.10.jar` was used only to identify familiar engineering item roles and broad dependency relationships. TEKNIK does not include or redistribute Create source code, textures, models, sounds, translations, animations, data files, or other assets.

All implementation code, recipes, progression rules, descriptions, colors, UI data, tests, cave generation and future models are original TEKNIK work. If a later subsystem genuinely requires studying upstream behavior, the implementation must still be independently written and documented.

## Phase 1 catalog

The nineteen requested Create-inspired item roles are:

1. Andesite Alloy
2. Zinc Ingot
3. Brass Ingot
4. Copper Sheet
5. Brass Sheet
6. Iron Sheet
7. Gold Sheet
8. Andesite Casing
9. Brass Casing
10. Shaft
11. Cogwheel
12. Large Cogwheel
13. Belt Connector
14. Mechanical Bearing
15. Hand Crank
16. Wrench
17. Electron Tube
18. Precision Mechanism
19. Empty Blaze Burner

All nineteen are registered inventory items with original TEKNIK metadata and recipes. Hand Crank remains connected to the existing starter kinetic simulation. The remaining components are inventory/crafting foundations for subsequent physical-machine milestones; they must not be presented as functional world machines until their corresponding systems exist.

## Current original progression

The current stable world has no dedicated metal-ore processing system. Phase 1 therefore uses temporary TEKNIK mineral concentrates made from existing stone, soil and sand resources. This makes every item obtainable now without pretending that unfinished ore, heat or pressing systems already exist.

Progression order:

- Hand crafting: Stone Gear, Stone Workbench, Plant Fiber
- Workbench: Crushed Stone and mineral separation
- Stone processing: Zinc/Copper/Iron/Gold refinement and sheet forming
- Andesite engineering: shafts, cogwheels, belt material, casing, bearing, wrench and crank
- Brass engineering: brass casing, electron tube, precision mechanism and empty burner frame
- Kinetic starter: existing Stone Crusher loop

These recipes are temporary gameplay-balanced TEKNIK recipes. They can later migrate to physical crushing, washing, heating, pressing and sequenced assembly while preserving item IDs and saved inventories.

## Mobile and save constraints

- Registered inventory types: 36
- Inventory storage slots: 36
- Legacy 12-slot saves migrate to schema 2 without losing items
- The stable mobile hotbar remains eight slots
- The scrollable inventory and workbench recipe list must pass real drag-offset QA before APK export

## Cave foundation

The cave system is an original fixed-point 3D value-noise implementation shared by Godot and Rust. It creates cross-chunk tunnels and sparse chambers, protects two floor layers and a four-block surface roof, and applies saved voxel edits after generation. Cave parity is tested before every Phase 1 APK export.
