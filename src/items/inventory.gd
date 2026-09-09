extends RefCounted
class_name Inventory

## Generic slot-based container. Slot layout: [id, count, durability] or {} when empty.
## Used for the player inventory (hotbar 0..8, main 9..35) and future containers.

signal changed

var size: int
var slots: Array = []


func _init(p_size: int = 36) -> void:
	size = maxi(1, p_size)
	slots.resize(size)
	for i in range(size):
		slots[i] = {}


func is_valid_slot(i: int) -> bool:
	return i >= 0 and i < size


func get_slot(i: int) -> Dictionary:
	if not is_valid_slot(i):
		return {}
	return slots[i]


func get_id(i: int) -> int:
	var s: Dictionary = get_slot(i)
	return int(s.get("id", 0))


func get_count(i: int) -> int:
	var s: Dictionary = get_slot(i)
	return int(s.get("count", 0))


func get_durability(i: int) -> int:
	var s: Dictionary = get_slot(i)
	return int(s.get("dur", 0))


static func make_stack(id: int, count: int, durability: int = 0) -> Dictionary:
	if count <= 0 or not ItemRegistry.is_valid_any(id):
		return {}
	return { "id": id, "count": count, "dur": durability }


## Adds items, returns the amount that did NOT fit.
func add(id: int, count: int, durability: int = 0) -> int:
	if count <= 0 or not ItemRegistry.is_valid_any(id):
		return count
	var max_stack := ItemRegistry.stack_of(id)
	if max_stack <= 0:
		return count
	var remaining := count
	if max_stack > 1:
		for i in range(size):
			if remaining <= 0:
				break
			var s: Dictionary = slots[i]
			if not s.is_empty() and int(s["id"]) == id and int(s["count"]) < max_stack:
				var space := max_stack - int(s["count"])
				var move := mini(space, remaining)
				s["count"] = int(s["count"]) + move
				remaining -= move
	for i in range(size):
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var move := mini(max_stack, remaining)
			slots[i] = make_stack(id, move, durability)
			remaining -= move
	if remaining != count:
		changed.emit()
	return remaining


## Removes up to `count` of `id`; returns the amount actually removed.
func remove(id: int, count: int) -> int:
	if count <= 0:
		return 0
	var need := count
	for i in range(size):
		if need <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and int(s["id"]) == id:
			var have := int(s["count"])
			var take := mini(have, need)
			need -= take
			if have - take <= 0:
				slots[i] = {}
			else:
				s["count"] = have - take
	if need != count:
		changed.emit()
	return count - need


func count_of(id: int) -> int:
	var total := 0
	for s: Dictionary in slots:
		if not s.is_empty() and int(s["id"]) == id:
			total += int(s["count"])
	return total


func has(id: int, count: int = 1) -> bool:
	return count_of(id) >= count


## Swaps/splits/merges between slots. `amount` <= 0 means the whole stack.
func move(from: int, to: int, amount: int = 0) -> bool:
	if not is_valid_slot(from) or not is_valid_slot(to) or from == to:
		return false
	var src: Dictionary = slots[from]
	if src.is_empty():
		return false
	var src_count := int(src["count"])
	var n := src_count if amount <= 0 else mini(amount, src_count)
	if n <= 0:
		return false
	var dst: Dictionary = slots[to]
	var id := int(src["id"])
	var max_stack := ItemRegistry.stack_of(id)
	if dst.is_empty():
		if n >= src_count:
			slots[to] = src
			slots[from] = {}
		else:
			slots[to] = make_stack(id, n, int(src.get("dur", 0)))
			src["count"] = src_count - n
		changed.emit()
		return true
	if int(dst["id"]) == id and max_stack > 1:
		var dst_count := int(dst["count"])
		var space := max_stack - dst_count
		if space <= 0:
			return false
		var move := mini(space, n)
		dst["count"] = dst_count + move
		n -= move
		if n > 0:
			src["count"] = int(src["count"]) - n
		if int(src["count"]) <= 0:
			slots[from] = {}
		changed.emit()
		return true
	# different ids: swap
	slots[from] = dst
	slots[to] = src
	changed.emit()
	return true


func clear() -> void:
	for i in range(size):
		slots[i] = {}
	changed.emit()


func to_array() -> Array:
	var out: Array = []
	for s: Dictionary in slots:
		if s.is_empty():
			out.append(null)
		else:
			out.append([int(s["id"]), int(s["count"]), int(s.get("dur", 0))])
	return out


func from_array(arr: Array) -> void:
	clear()
	for i in range(mini(arr.size(), size)):
		var e: Variant = arr[i]
		if e is Array and (e as Array).size() >= 2:
			var id := int((e as Array)[0])
			var cnt := int((e as Array)[1])
			var dur := int((e as Array)[2]) if (e as Array).size() >= 3 else 0
			if cnt > 0 and ItemRegistry.is_valid_any(id):
				var capped := mini(cnt, ItemRegistry.stack_of(id))
				slots[i] = make_stack(id, capped, dur)
	changed.emit()


func serialize() -> Dictionary:
	return { "size": size, "slots": to_array() }


static func deserialize(data: Dictionary) -> Inventory:
	var inv := Inventory.new(int(data.get("size", 36)))
	inv.from_array(data.get("slots", []))
	return inv
