extends Node3D
class_name DayNight

## Sun/moon cycle: rotates the directional light and lerps sky, fog and ambient.
## time_of_day: 0 = dawn, 0.25 = noon, 0.5 = dusk, 0.75 = midnight.

signal time_changed(time_of_day: float)

const DAY_LENGTH := 600.0  # seconds per full cycle (configurable)

var time_of_day := 0.08
var day_length := DAY_LENGTH

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

const DAY_TOP := Color(0.36, 0.58, 0.88)
const DAY_HORIZON := Color(0.72, 0.82, 0.92)
const DUSK_TOP := Color(0.24, 0.22, 0.42)
const DUSK_HORIZON := Color(0.92, 0.56, 0.32)
const NIGHT_TOP := Color(0.015, 0.02, 0.05)
const NIGHT_HORIZON := Color(0.05, 0.06, 0.10)


func _ready() -> void:
	add_to_group("day_night")

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-60, 30, 0)
	_sun.light_energy = 1.1
	_sun.light_color = Color(1.0, 0.98, 0.92)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 90.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(_sun)

	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(40, -140, 0)
	_moon.light_energy = 0.12
	_moon.light_color = Color(0.62, 0.7, 0.9)
	_moon.shadow_enabled = false
	add_child(_moon)

	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 20.0
	_sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.0
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_density = 0.0
	_env.fog_depth_begin = 60.0
	_env.fog_depth_end = 150.0
	_env.fog_light_color = DAY_HORIZON
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_apply(0.0)


func _process(delta: float) -> void:
	var prev := time_of_day
	time_of_day = fmod(time_of_day + delta / day_length, 1.0)
	if absf(time_of_day - prev) > 0.0001:
		_apply(delta)
		time_changed.emit(time_of_day)


func is_day() -> bool:
	return time_of_day < 0.5


func is_night() -> bool:
	return time_of_day >= 0.55


func _apply(_delta: float) -> void:
	var angle := time_of_day * TAU
	# sun orbits in the X-Y plane, tilted
	var sun_dir := Vector3(cos(angle), sin(angle), 0.22).normalized()
	_sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP)
	_sun.visible = sun_dir.y > -0.08
	var moon_dir := -sun_dir
	_moon.look_at_from_position(moon_dir * 100.0, Vector3.ZERO, Vector3.UP)
	_moon.visible = moon_dir.y > -0.08

	var dayness := clampf(sun_dir.y * 2.2, 0.0, 1.0)             # 0 night, 1 high noon
	# dusk glow peaks when the sun sits near the horizon, fades out at night
	var duskness := clampf(1.0 - absf(sun_dir.y) * 4.0, 0.0, 1.0) * clampf((sun_dir.y + 0.12) * 8.0, 0.0, 1.0)

	var top := NIGHT_TOP.lerp(DAY_TOP, dayness).lerp(DUSK_TOP, duskness * 0.6)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, dayness).lerp(DUSK_HORIZON, duskness * 0.8)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.lerp(Color(0.1, 0.1, 0.12), 0.5)
	_sky_mat.ground_horizon_color = horizon

	_sun.light_energy = 1.15 * dayness + 0.02
	_sun.light_color = Color(1.0, 0.98, 0.92).lerp(Color(1.0, 0.6, 0.3), duskness)
	_env.ambient_light_energy = 0.25 + 0.75 * dayness
	_env.fog_light_color = horizon
	_env.fog_sun_scatter = duskness * 0.4
	RenderingServer.set_default_clear_color(horizon)
