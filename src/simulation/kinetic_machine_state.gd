extends RefCounted

const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const SCHEMA = 1
const TYPE_WORKBENCH = "workbench"
const TYPE_SHAFT = "shaft"
const TYPE_CRANK = "hand_crank"
const TYPE_CRUSHER = "stone_crusher"

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

func remove(machine_id):
	machine_id = str(machine_id)
	if not machines.has(machine_id):
		return false
	machines.erase(machine_id)
	return true

func insert_stone(amount):
	var accepted = min(max(int(amount), 0), 16 - crusher_input)
	crusher_input += accepted
	return accepted

func crank(turns):
	stored_turns = min(stored_turns + max(int(turns), 0), 32)
	return network_report()

func process():
	var report = network_report()
	if report["overstressed"] or report["source_rpm"] <= 0.0:
		return false
	if crusher_input < 2 or stored_turns < 4:
		return false
	crusher_input -= 2
	crusher_output += 3
	stored_turns -= 4
	return true

func collect_output():
	var amount = crusher_output
	crusher_output = 0
	return amount

func network_report():
	var network = KineticNetwork.new()
	var connected = _has_connected_chain()
	network.configure_source(24.0 if connected and stored_turns > 0 else 0.0, 1.0)
	if connected:
		network.add_consumer("stone_crusher", 1.0, 0.55)
	var report = network.report()
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
	crusher_input = clamp(int(payload.get("crusher_input", 0)), 0, 16)
	crusher_output = max(int(payload.get("crusher_output", 0)), 0)
	stored_turns = clamp(int(payload.get("stored_turns", 0)), 0, 32)
	return true
