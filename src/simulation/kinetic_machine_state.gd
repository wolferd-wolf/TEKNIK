class_name TeknikKineticMachineState
extends RefCounted

const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const SCHEMA: int = 1
const TYPE_WORKBENCH: StringName = &"workbench"
const TYPE_SHAFT: StringName = &"shaft"
const TYPE_CRANK: StringName = &"hand_crank"
const TYPE_CRUSHER: StringName = &"stone_crusher"

var machines: Dictionary = {}
var crusher_input: int = 0
var crusher_output: int = 0
var stored_turns: int = 0


func place(machine_id: StringName, machine_type: StringName, position: Vector3i) -> bool:
	if machine_id == &"" or machines.has(machine_id):
		return false
	if machine_type not in [TYPE_WORKBENCH, TYPE_SHAFT, TYPE_CRANK, TYPE_CRUSHER]:
		return false
	for row: Dictionary in machines.values():
		if Vector3i(row.position) == position:
			return false
	machines[machine_id] = {"type": machine_type, "position": position}
	return true


func remove(machine_id: StringName) -> bool:
	return machines.erase(machine_id)


func insert_stone(amount: int) -> int:
	var accepted: int = mini(maxi(amount, 0), 16 - crusher_input)
	crusher_input += accepted
	return accepted


func crank(turns: int) -> Dictionary:
	stored_turns = mini(stored_turns + maxi(turns, 0), 32)
	return network_report()


func process() -> bool:
	var report: Dictionary = network_report()
	if bool(report.overstressed) or float(report.source_rpm) <= 0.0:
		return false
	if crusher_input < 2 or stored_turns < 4:
		return false
	crusher_input -= 2
	crusher_output += 3
	stored_turns -= 4
	return true


func collect_output() -> int:
	var amount: int = crusher_output
	crusher_output = 0
	return amount


func network_report() -> Dictionary:
	var network := KineticNetwork.new()
	var connected: bool = _has_connected_chain()
	network.configure_source(24.0 if connected and stored_turns > 0 else 0.0, 1.0)
	if connected:
		network.add_consumer(&"stone_crusher", 1.0, 0.55)
	var report: Dictionary = network.report()
	report["connected"] = connected
	report["stored_turns"] = stored_turns
	return report


func _has_connected_chain() -> bool:
	var crank_id: StringName = _first_id_of_type(TYPE_CRANK)
	var crusher_id: StringName = _first_id_of_type(TYPE_CRUSHER)
	if crank_id == &"" or crusher_id == &"":
		return false
	var visited: Dictionary = {crank_id: true}
	var frontier: Array[StringName] = [crank_id]
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		if current == crusher_id:
			return true
		var current_position: Vector3i = machines[current].position
		for candidate_variant: Variant in machines.keys():
			var candidate := StringName(candidate_variant)
			if visited.has(candidate):
				continue
			var candidate_type := StringName(machines[candidate].type)
			if candidate_type not in [TYPE_SHAFT, TYPE_CRANK, TYPE_CRUSHER]:
				continue
			var delta: Vector3i = Vector3i(machines[candidate].position) - current_position
			if absi(delta.x) + absi(delta.y) + absi(delta.z) != 1:
				continue
			visited[candidate] = true
			frontier.append(candidate)
	return false


func _first_id_of_type(machine_type: StringName) -> StringName:
	var ids: Array = machines.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var id := StringName(id_variant)
		if StringName(machines[id].type) == machine_type:
			return id
	return &""


func encode() -> Dictionary:
	var rows: Array[Dictionary] = []
	var ids: Array = machines.keys()
	ids.sort()
	for id_variant: Variant in ids:
		var id := StringName(id_variant)
		var row: Dictionary = machines[id]
		var position: Vector3i = row.position
		rows.append({"id": str(id), "type": str(row.type), "position": [position.x, position.y, position.z]})
	return {"schema": SCHEMA, "machines": rows, "crusher_input": crusher_input, "crusher_output": crusher_output, "stored_turns": stored_turns}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", -1)) != SCHEMA:
		return false
	var restored := TeknikKineticMachineState.new()
	var rows: Variant = payload.get("machines", [])
	if not rows is Array:
		return false
	for value: Variant in rows:
		if not value is Dictionary:
			return false
		var row: Dictionary = value
		var encoded_position: Variant = row.get("position", [])
		if not encoded_position is Array or (encoded_position as Array).size() != 3:
			return false
		var position := Vector3i(int(encoded_position[0]), int(encoded_position[1]), int(encoded_position[2]))
		if not restored.place(StringName(str(row.get("id", ""))), StringName(str(row.get("type", ""))), position):
			return false
	restored.crusher_input = clampi(int(payload.get("crusher_input", 0)), 0, 16)
	restored.crusher_output = maxi(int(payload.get("crusher_output", 0)), 0)
	restored.stored_turns = clampi(int(payload.get("stored_turns", 0)), 0, 32)
	machines = restored.machines
	crusher_input = restored.crusher_input
	crusher_output = restored.crusher_output
	stored_turns = restored.stored_turns
	return true
