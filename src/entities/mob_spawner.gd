extends Node
class_name MobSpawner

## Keeps mob populations around the player within caps. Distance-based
## activation: spawns near the player, despawns far away. Night => hostiles.

const PASSIVE_CAP := 6
const HOSTILE_CAP := 8
const SPAWN_RADIUS_MIN := 14.0
const SPAWN_RADIUS_MAX := 34.0
const DESPAWN_DIST := 58.0
const TICK_INTERVAL := 2.5

var world: World
var day_night: DayNight

var _tick := 0.0


func _process(delta: float) -> void:
	_tick += delta
	if _tick < TICK_INTERVAL:
		return
	_tick = 0.0
	if world == null:
		return
	var player := _player()
	if player == null:
		return

	var passive := 0
	var hostile := 0
	var mobs := get_tree().get_nodes_in_group("mobs")
	for m: Node in mobs:
		var dist: float = (m as Node3D).global_position.distance_to(player.global_position)
		if dist > DESPAWN_DIST:
			m.queue_free()
			continue
		if m is Tuft:
			passive += 1
		elif m is Grimb:
			hostile += 1

	if mobs.size() < PASSIVE_CAP + HOSTILE_CAP:
		var want_hostile := day_night != null and day_night.is_night() and hostile < HOSTILE_CAP
		var want_passive := passive < PASSIVE_CAP
		if want_hostile or want_passive:
			_try_spawn(player, want_hostile)


func _try_spawn(player: Node3D, hostile: bool) -> void:
	for _attempt in range(6):
		var ang := randf() * TAU
		var dist := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		var x := floori(player.global_position.x + cos(ang) * dist)
		var z := floori(player.global_position.z + sin(ang) * dist)
		var sy := world.surface_y(x, z)
		if sy < 1 or sy >= Chunk.HEIGHT - 3:
			continue
		var ground := world.get_block(x, sy, z)
		if BlockRegistry.is_liquid(ground) or ground == BlockRegistry.AIR:
			continue
		var feet := world.get_block(x, sy + 1, z)
		var head := world.get_block(x, sy + 2, z)
		if feet != BlockRegistry.AIR or head != BlockRegistry.AIR:
			continue
		if not hostile and ground != BlockRegistry.GRASS and ground != BlockRegistry.SNOW and ground != BlockRegistry.SAND:
			continue
		var mob := (Grimb.new() if hostile else Tuft.new()) as MobBase
		get_parent().add_child(mob)
		mob.global_position = Vector3(x + 0.5, sy + 1.1, z + 0.5)
		return


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null
