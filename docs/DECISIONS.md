# Architecture Decisions

## ADR-001: Start from a clean branch

**Decision:** The playable-world branch contains a fresh implementation. Previous prototype gameplay files are not imported.

**Reason:** Repeated patching obscured ownership and made success difficult to verify.

## ADR-002: Keep Godot conditionally

**Decision:** Use Godot 4.7.1 for the Android shell, rendering, input, UI and the initial terrain benchmark.

**Exit condition:** If a clean, data-oriented implementation cannot pass the target-phone performance and stability gates, the engine decision is reopened before advanced systems are built.

## ADR-003: One mesh per chunk

**Decision:** Blocks remain data. Visible faces are packed into chunk meshes.

**Reason:** A node or body per block is unacceptable for mobile scale.

## ADR-004: Collision-first streaming

**Decision:** The nearby collision band is loaded before distant visual chunks.

**Reason:** A beautiful distant world is worthless if the player falls through an unloaded boundary.

## ADR-005: Delay physics contraptions

**Decision:** Do not build machine or vehicle physics until the base world passes all quality gates.

**Reason:** Advanced systems cannot compensate for an unstable foundation.
