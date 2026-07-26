extends SceneTree

const MachineState = preload("res://src/simulation/kinetic_machine_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_atomic_starter_assembly()
	_test_individual_engineering_placement()
	_test_explicit_processing_loop()
	_test_disconnected_network()
	if _failures == 0:
		print("KINETIC_MACHINE_TEST_RESULT PASS")
		quit(0)
	else:
		print("KINETIC_MACHINE_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_atomic_starter_assembly() -> void:
	var state := MachineState.new()
	_expect(state.assemble_starter(Vector3i.ZERO), "starter assembly places all machine roles atomically")
	_expect(state.machines.size() == 4, "starter assembly has four placed machines")
	_expect(state.is_assembled(), "starter assembly forms a connected machine line")
	var before: Dictionary = state.encode()
	_expect(not state.assemble_starter(Vector3i(10, 0, 0)), "second starter assembly is rejected")
	_expect(state.encode() == before, "rejected assembly leaves state unchanged")
	_expect(not state.place(&"duplicate", MachineState.TYPE_SHAFT, Vector3i.RIGHT), "occupied machine position is rejected")


func _test_individual_engineering_placement() -> void:
	var state := MachineState.new()
	_expect(state.place(&"crank", MachineState.TYPE_CRANK, Vector3i.ZERO), "hand crank places as an individual world object")
	_expect(state.place(&"shaft", MachineState.TYPE_SHAFT, Vector3i.RIGHT), "shaft places beside the crank")
	_expect(state.place(&"crusher", MachineState.TYPE_CRUSHER, Vector3i.RIGHT * 2), "crusher places beside the shaft")
	_expect(state.place(&"workbench", MachineState.TYPE_WORKBENCH, Vector3i.FORWARD), "workbench places as a separate station")
	_expect(not state.place(&"overlap", MachineState.TYPE_SHAFT, Vector3i.RIGHT), "individual placement rejects occupied positions")
	_expect(state.machines.size() == 4, "individual placement creates four persisted objects")
	_expect(state.is_assembled(), "individually placed adjacent parts form a connected machine")
	var payload: Dictionary = state.encode()
	var restored := MachineState.new()
	_expect(restored.decode(payload), "individual machine placement payload decodes")
	_expect(restored.encode() == payload, "individual machine placement survives save and reload")
	_expect(restored.remove(&"workbench"), "placed engineering object can be removed")
	_expect(restored.machines.size() == 3, "removed object leaves the persisted registry")


func _test_explicit_processing_loop() -> void:
	var state := MachineState.new()
	state.assemble_starter(Vector3i.ZERO)
	_expect(state.insert_stone(2) == 2, "crusher accepts two stone input")
	_expect(not state.process(), "crusher cannot process before the crank turns")
	var report: Dictionary = state.crank(MachineState.PROCESS_TURNS)
	_expect(bool(report.connected), "crank shaft crusher chain connects")
	_expect(bool(report.assembled), "network reports complete assembly")
	_expect(int(report.turns_added) == MachineState.PROCESS_TURNS, "connected crank stores deterministic turns")
	_expect(float(report.source_rpm) == 24.0, "connected crank provides deterministic rpm")
	_expect(not bool(report.overstressed), "starter crusher network is within capacity")
	_expect(state.process(), "powered crusher processes one batch")
	_expect(state.crusher_output == MachineState.PROCESS_OUTPUT, "processed output waits inside the crusher")
	_expect(state.collect_output(2) == 2, "output can be collected partially")
	_expect(state.crusher_output == 1, "uncollected output remains stored")
	_expect(state.collect_output() == 1, "remaining output can be collected")
	var payload: Dictionary = state.encode()
	var restored := MachineState.new()
	_expect(restored.decode(payload), "machine save decodes")
	_expect(restored.encode() == payload, "machine save round trips exactly")


func _test_disconnected_network() -> void:
	var disconnected := MachineState.new()
	disconnected.place(&"crank", MachineState.TYPE_CRANK, Vector3i.ZERO)
	disconnected.place(&"crusher", MachineState.TYPE_CRUSHER, Vector3i(3, 0, 0))
	_expect(disconnected.insert_stone(2) == 2, "disconnected crusher can hold input")
	var report: Dictionary = disconnected.crank(MachineState.PROCESS_TURNS)
	_expect(not bool(report.connected), "separated crank and crusher remain disconnected")
	_expect(int(report.turns_added) == 0, "disconnected crank cannot bank usable power")
	_expect(disconnected.stored_turns == 0, "disconnected power state remains empty")
	_expect(not disconnected.process(), "disconnected crusher cannot process")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
