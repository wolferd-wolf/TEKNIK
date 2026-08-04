extends RefCounted

const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const SCHEMA = 1
const TYPE_WORKBENCH = "workbench"
const TYPE_SHAFT = "shaft"
const TYPE_CRANK = "hand_crank"
const TYPE_CRUSHER = "stone_crusher"
const MAX_CRUSHER_INPUT: int = 16
const MAX_CRUSHER_OUTPUT: int = 24
const MAX_STORED_TURNS: int = 32
const PROCESS_INPUT: int = 2
const PROCESS_OUTPUT: int = 3
const PROCESS_TURNS: int = 4

var machines = {}
var crusher_input = 0
var crusher_output = 0
var stored_turns = 0


func place(machine_id, machine_type, position):
	machine_id = str(machine_id)
	machine_type = str(machine_type)
	if machine_id.is_empty() or machines.has(machine_id):
		return false
	if not machine_type in [TYPE_WORKBENCH, TYPE_SHAFT, TYPE_CRANK, TYPE_CRUSHER]:
		return false
	for row in machines.values():
		if row["position"] == position:
			return false
	machines[machine_id] = {"type": machine_type, "position": position}
	return true


func assemble_starter(origin: Vector3i) -> bool:
	if not machines.is_empty():
		return false
	var layout := {
		"crank": {"type": TYPE_CRANK, "position": origin},
		"shaft_a": {"type": TYPE_SHAFT, "position": origin + Vector3i.RIGHT},
		"crusher": {"type": TYPE_CRUSHER, "position": origin + Vector3i.RIGHT * 2},
		"workbench": {"type": TYPE_WORKBENCH, "position": origin + Vector3i.FORWARD},
	}
	var occupied := {}
	for row: Dictionary in layout.values():
		var position: Vector3i = row["position"]
		if occupied.has(position):
			return false
		occupied[position] = true
	machines = layout
	return true


func is_assembled() -> bool:
	return (
		_has_type(TYPE_WORKBENCH)
		and _has_type(TYPE_SHAFT)
		and _has_type(TYPE_CRANK)
		and _has_type(TYPE_CRUSHER)
		and _has_connected_chain()
	)


func remove(machine_id):
	machine_id = str(machine_id)
	if not machines.has(machine_id):
		return false
	machines.erase(machine_id)
	return true


func insert_stone(amount):
	if not _has_type(TYPE_CRUSHER):
		return 0
	var accepted = min(max(int(amount), 0), MAX_CRUSHER_INPUT - crusher_input)
	crusher_input += accepted
	return accepted


func crank(turns):
	var connected: bool = _has_connected_chain()
	var added: int = 0
	if connected:
		added = min(max(int(turns), 0), MAX_STORED_TURNS - stored_turns)
		stored_turns += added
	var report = network_report()
	report["turns_added"] = added
	return report


func process():
	var report = network_report()
	if report["overstressed"] or report["source_rpm"] <= 0.0:
		return false
	if crusher_input < PROCESS_INPUT or stored_turns < PROCESS_TURNS:
		return false
	if crusher_output + PROCESS_OUTPUT > MAX_CRUSHER_OUTPUT:
		return false
	crusher_input -= PROCESS_INPUT
	crusher_output += PROCESS_OUTPUT
	stored_turns -= PROCESS_TURNS
	return true


func collect_output(max_amount: int = -1):
	var amount: int = crusher_output if max_amount < 0 else mini(crusher_output, maxi(max_amount, 0))
	crusher_output -= amount
	return amount


func network_report():
	var network = KineticNetwork.new()
	var connected = _has_connected_chain()
	network.configure_source(24.0 if connected and stored_turns > 0 else 0.0, 1.0)
	if connected:
		network.add_consumer("stone_crusher", 1.0, 0.55)
	var report = network.report()
	report["assembled"] = is_assembled()
	report["connected"] = connected
	report["stored_turns"] = stored_turns
	return report


func _has_connected_chain():
	var crank_id = _first_id_of_type(TYPE_CRANK)
	var crusher_id = _first_id_of_type(TYPE_CRUSHER)
	if crank_id.is_empty() or crusher_id.is_empty():
		return false
	var visited = {crank_id: true}
	var frontier = [crank_id]
	while not frontier.is_empty():
		var current = frontier.pop_front()
		if current == crusher_id:
			return true
		var current_position = machines[current]["position"]
		for candidate in machines.keys():
			if visited.has(candidate):
				continue
			var row = machines[candidate]
			if not row["type"] in [TYPE_SHAFT, TYPE_CRANK, TYPE_CRUSHER]:
				continue
			var delta = row["position"] - current_position
			if abs(delta.x) + abs(delta.y) + abs(delta.z) != 1:
				continue
			visited[candidate] = true
			frontier.append(candidate)
	return false


func _has_type(machine_type) -> bool:
	return not _first_id_of_type(machine_type).is_empty()


func _first_id_of_type(machine_type):
	var ids = machines.keys()
	ids.sort()
	for machine_id in ids:
		if machines[machine_id]["type"] == machine_type:
			return machine_id
	return ""


func encode():
	var rows = []
	var ids = machines.keys()
	ids.sort()
	for machine_id in ids:
		var row = machines[machine_id]
		var position = row["position"]
		rows.append({"id": machine_id, "type": row["type"], "position": [position.x, position.y, position.z]})
	return {"schema": SCHEMA, "machines": rows, "crusher_input": crusher_input, "crusher_output": crusher_output, "stored_turns": stored_turns}


func decode(payload):
	if not payload is Dictionary or int(payload.get("schema", -1)) != SCHEMA:
		return false
	var rows = payload.get("machines", [])
	if not rows is Array:
		return false
	var restored = {}
	var occupied = {}
	for row in rows:
		if not row is Dictionary:
			return false
		var machine_id = str(row.get("id", ""))
		var machine_type = str(row.get("type", ""))
		var position_data = row.get("position", [])
		if machine_id.is_empty() or restored.has(machine_id):
			return false
		if not machine_type in [TYPE_WORKBENCH, TYPE_SHAFT, TYPE_CRANK, TYPE_CRUSHER]:
			return false
		if not position_data is Array or position_data.size() != 3:
			return false
		var position = Vector3i(int(position_data[0]), int(position_data[1]), int(position_data[2]))
		if occupied.has(position):
			return false
		occupied[position] = true
		restored[machine_id] = {"type": machine_type, "position": position}
	machines = restored
	crusher_input = clamp(int(payload.get("crusher_input", 0)), 0, MAX_CRUSHER_INPUT)
	crusher_output = clamp(int(payload.get("crusher_output", 0)), 0, MAX_CRUSHER_OUTPUT)
	stored_turns = clamp(int(payload.get("stored_turns", 0)), 0, MAX_STORED_TURNS)
	return true
