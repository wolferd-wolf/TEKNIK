extends RefCounted
class_name FBM

## Deterministic multi-octave value noise built on FastNoiseLite.
## All noise instances derive from the world seed, so identical seeds
## always produce identical terrain regardless of generation order.

var _height: FastNoiseLite
var _detail: FastNoiseLite
var _rough: FastNoiseLite
var _temp: FastNoiseLite
var _rain: FastNoiseLite
var _cave_a: FastNoiseLite
var _cave_b: FastNoiseLite
var _ore: FastNoiseLite

var seed_value: int


func _init(world_seed: int) -> void:
	seed_value = world_seed
	_height = _make(world_seed + 1000, 0.0016, 3)
	_detail = _make(world_seed + 2000, 0.012, 3)
	_rough = _make(world_seed + 3000, 0.004, 4)
	_temp = _make(world_seed + 4000, 0.0011, 2)
	_rain = _make(world_seed + 5000, 0.0013, 2)
	_cave_a = _make(world_seed + 6000, 0.028, 2)
	_cave_b = _make(world_seed + 7000, 0.024, 2)
	_ore = _make(world_seed + 8000, 0.11, 2)


static func _make(nseed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = nseed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	n.fractal_gain = 0.5
	n.fractal_lacunarity = 2.0
	return n


func height_at(x: int, z: int) -> int:
	var base := _height.get_noise_2d(x, z)                 # -1..1 large landmasses
	var mountains := _rough.get_noise_2d(x, z)             # -1..1 regional roughness
	var detail := _detail.get_noise_2d(x, z) * 3.0
	var m := maxf(0.0, mountains - 0.18) / 0.82            # 0..1 mountain mask
	var h := 34.0 + base * 12.0 + detail + m * m * 52.0
	return clampi(int(h), 4, Chunk.HEIGHT - 24)


func temperature(x: int, z: int) -> float:
	return _temp.get_noise_2d(x * 0.75, z * 0.75)


func rainfall(x: int, z: int) -> float:
	return _rain.get_noise_2d(x * 0.8 + 1337.0, z * 0.8 - 421.0)


func cave_density(x: int, y: int, z: int) -> float:
	## Two crossing noise ridges -> worm-like tunnels.
	var a := absf(_cave_a.get_noise_3d(x, y * 1.6, z))
	var b := absf(_cave_b.get_noise_3d(x, y * 1.6, z))
	return (a < 0.055 and b < 0.055)


func ore_noise(x: int, y: int, z: int) -> float:
	return _ore.get_noise_3d(x, y, z)
