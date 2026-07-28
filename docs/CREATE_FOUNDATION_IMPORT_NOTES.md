# Create foundation import notes

TEKNIK uses Create's public generated recipe data as a behavioral reference while keeping original runtime code, UI, world state and visuals.

## Separate station interfaces

- **Inventory** only displays stored items and placement categories.
- **Portable Crafting** contains hand recipes such as planks, the Crafting Table, Furnace, paper and dependency preparation.
- **Crafting Table** contains the Phase 1 engineering recipe catalog and progression-gated components.
- **Furnace** contains selectable smelting, kelp-drying and heated brass-alloying operations. Every current operation consumes one Wood fuel.

All four interfaces are independent mobile windows with their own scroll state and touch-drag driver. Placed Crafting Tables and Furnaces open their matching station UI rather than acting as menu-less shortcuts.

## Create recipe relationships retained

The following source relationships are represented in `src/survival/recipe_book.gd`:

- `crafting/materials/andesite_alloy.json`: Andesite + Iron Nuggets.
- `crafting/kinetics/shaft.json`: two Andesite Alloy produce eight Shafts.
- `crafting/kinetics/cogwheel.json`: Shaft + Planks.
- `crafting/kinetics/large_cogwheel.json`: Shaft + two Planks.
- `crafting/kinetics/hand_crank.json`: three Planks + Andesite Alloy.
- `crafting/kinetics/mechanical_bearing.json`: Wooden Slab + Andesite Casing + Shaft.
- `crafting/kinetics/belt_connector.json`: six Dried Kelp.
- `item_application/andesite_casing_from_wood.json`: Stripped Wood + Andesite Alloy.
- `item_application/brass_casing_from_wood.json`: Stripped Wood + Brass Ingot.
- `crafting/kinetics/wrench.json`: Gold Sheets + Cogwheel + Wooden Rod.
- `crafting/materials/electron_tube.json`: Polished Rose Quartz + Iron Sheet.
- `sequenced_assembly/precision_mechanism.json`: Gold Sheet base followed by five loops of Cogwheel, Large Cogwheel and Iron Nugget deployment.
- `crafting/kinetics/empty_blaze_burner.json`: four Iron Sheets surrounding Netherrack.
- `mixing/brass_ingot.json`: heated Copper + Zinc producing two Brass Ingots.

Dependencies not previously present were added as normal TEKNIK items: Planks, Stripped Wood, Wooden Slabs, Wooden Rods, Andesite, Kelp, Dried Kelp, Paper, Sand Paper, Quartz, Redstone, Rose Quartz, Polished Rose Quartz, Netherrack, metal Nuggets and the Incomplete Precision Mechanism.

## Temporary processing adaptations

Create processes that require machinery not yet implemented are intentionally routed through the closest current station:

- Mechanical Press sheet recipes use the Crafting Table until the press exists.
- Item Application casing recipes use the Crafting Table until deployers or direct application exist.
- Sequenced Assembly uses an explicit Incomplete Precision Mechanism and five-loop ingredient totals until belts and deployers exist.
- Heated brass mixing uses the Furnace until basins, mixers and heat tiers exist.

These recipes retain source metadata so they can migrate to the real machine subsystem without changing item identity or save data.

The next Create phase should add machines in dependency order and move adapted recipes from stations into spatial processing while preserving one authoritative inventory, recipe and world simulation state.
