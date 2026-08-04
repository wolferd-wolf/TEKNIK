# Procedural world and surface ecology research

This milestone replaces fixed-grid feature placement with deterministic spatial ecology.

## Sources reviewed

- Robert Bridson, *Fast Poisson Disk Sampling in Arbitrary Dimensions* (SIGGRAPH 2007). The key practical idea is minimum-distance sampling accelerated by spatial cells.
- Auburn/FastNoiseLite (MIT). Its multiscale fractal noise and domain-warp feature set informed the field composition, while TEKNIK keeps a small parity-safe implementation using its existing deterministic value-noise sampler.
- Onrust and Bidarra, *Ecologically Sound Procedural Generation of Natural Environments* (2017). This supports separating environmental suitability from final plant placement.
- Gasch et al., *Procedural modeling of plant ecosystems maximizing vegetation cover* (2022). This supports terrain constraints and competition/spacing rather than independent random placement.
- Moeslund et al., *Topographically controlled soil moisture is the primary driver of local vegetation patterns* (2013). This supports using moisture, slope and local terrain context.
- Hawthorne and Miniat, *Topography may mitigate drought effects on vegetation along a hillslope gradient* (2018). This supports elevation/topographic position influencing moisture response and tree size.

## TEKNIK implementation

- Deterministic blue-noise candidate acceptance is seam-safe across streamed windows.
- Domain-warped multiscale fields create forest masses, clearings, meadow patches and outcrops.
- Tree probability combines habitat, moisture, temperature, elevation, slope and river distance.
- Species selection shifts toward conifers in cooler, drier and higher terrain.
- Understory is reduced beneath dense canopy and increased around forest edges.
- Boulders use separate outcrop fields and minimum-distance placement.
- All new trees, shrubs, grass clumps, logs and rocks use reusable cuboid voxel meshes.
- Surface detail scans fewer cells and performs expensive terrain queries only for accepted blue-noise candidates.

The implementation is original TEKNIK code. No third-party source file was copied into the project.
