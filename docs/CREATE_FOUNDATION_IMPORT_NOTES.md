# Create foundation import notes

This step prepares TEKNIK for the next Create-content phase without copying Minecraft, NeoForge or Create runtime code.

- The existing workbench is promoted to a **Crafting Bench** and remains the entry point for the data-driven recipe/progression system.
- A placeable **Furnace** uses a separate smelting recipe table, so later bulk-smelting, fan processing and machine automation can consume the same recipe definitions.
- Trees now provide persistent **Wood**, establishing the renewable material path needed by starter recipes.
- Stations remain world objects with interaction, collision, placement, collection and save data rather than menu-only shortcuts.
- Future Create components should be mapped into TEKNIK's item registry, recipe book, kinetic network and world-object interfaces one subsystem at a time. Reference behavior and recipe structure; implement original TEKNIK code and visuals.

The public Create project describes itself around visible, spatial contraptions rather than UI-only automation. TEKNIK should preserve that design doctrine while keeping one authoritative world, inventory and simulation state.
