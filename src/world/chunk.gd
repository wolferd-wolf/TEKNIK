extends RefCounted
class_name Chunk

## Pure voxel data for one world column. No rendering, no physics.
## Layout: flat PackedByteArray, index = x + z * SIZE + y * SIZE * SIZE.

const SIZE := 16
const HEIGHT := 128
const SEA_LEVEL := 30

const IDX_MASK := SIZE - 1  # SIZE must remain a power of two

var cx: int
var cz: int
var blocks := PackedByteArray()
var generated := false
## Highest non-air y + margin; meshing only scans up to here.
var max_y := 0

## Player modifications: key "x,y,z" (local coords) -> block id.
## Chunks with edits are saved to disk; untouched chunks regenerate from the seed.
var edits: Dictionary = {}

## Book-keeping for the streaming pipeline.
var dirty_mesh := true


func _init(p_cx: int = 0, p_cz: int = 0) -> void:
	cx = p_cx
	cz = p_cz
	if blocks.size() != SIZE * SIZE * HEIGHT:
		blocks.resize(SIZE * SIZE * HEIGHT)
		blocks.fill(BlockRegistry.AIR)


static func index_of(x: int, y: int, z: int) -> int:
	return x + z * SIZE + y * SIZE * SIZE


static func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < SIZE and z >= 0 and z < SIZE and y >= 0 and y < HEIGHT


func get_block(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return BlockRegistry.AIR
	return blocks[index_of(x, y, z)]


func set_block(x: int, y: int, z: int, id: int) -> void:
	if not in_bounds(x, y, z):
		return
	blocks[index_of(x, y, z)] = id
	if id != BlockRegistry.AIR and y > max_y:
		max_y = y


func edit_block(x: int, y: int, z: int, id: int) -> void:
	## Player-driven change: writes data and records the edit for persistence.
	if not in_bounds(x, y, z):
		return
	set_block(x, y, z, id)
	edits["%d,%d,%d" % [x, y, z]] = id
	dirty_mesh = true


func apply_edits() -> void:
	for key: String in edits:
		var parts := key.split(",")
		set_block(int(parts[0]), int(parts[1]), int(parts[2]), int(edits[key]))
	dirty_mesh = true


func compute_hash() -> int:
	return hash(blocks)
