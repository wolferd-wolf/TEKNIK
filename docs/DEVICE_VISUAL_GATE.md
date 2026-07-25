# Vivo T3x visual acceptance gate

This gate records the three defects demonstrated by the 2026-07-25 target-device recording. Automated tests can validate configuration and geometry, but only physical-phone gameplay can close these items.

## Sea-level artifact

- No moving black dome, fan, or oversized dark patch may appear near the player.
- Foundation water must remain opaque, unshaded, back-face culled, and unable to cast shadows.
- Test while walking above, beside, and below the sea-level plane and while mining holes near sea level.

## Block selector

- The selector must draw only the four edges of the surface under the crosshair.
- Hidden cube edges must not draw through terrain.
- The selector must update correctly for top, bottom, and all four side faces.

## Daylight sky

- The upper sky must read as blue rather than white or gray.
- The horizon must remain lighter than the upper sky without washing out terrain silhouettes.
- Terrain must remain readable in open ground and excavated areas.

Passing CI is not sufficient. A new Vivo T3x recording is required before these visual defects are marked resolved.
