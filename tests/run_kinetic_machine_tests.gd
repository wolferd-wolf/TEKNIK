extends SceneTree

const MachineState = preload("res://src/simulation/kinetic_machine_state.gd")

var _failures: int = 0


func _init() -> void:
	var state := MachineState.new()
	_expect(state.place(&"crank", MachineState.TYPE_CRANK, Vector3i.ZERO), "places crank")
	_expect(state.place(&"shaft", MachineState.TYPE_SHAFT, Vector3i.RIGHT), "places adjacent shaft")
	_expect(state.place(&"crusher", MachineState.TYPE_CRUSHER, Vector3i.RIGHT * 2), "places crusher")
	_expect(not state.place(&"duplicate", MachineState.TYPE_SHAFT, Vector3i.RIGHT), "rejects occupied position")
	_expect(state.insert_stone(2) == 2, "accepts crusher input")
	var report: Dictionary = state.crank(4)
	_expect(bool(report.connected), "adjacent crank shaft crusher chain connects")
	_expect(float(report.source_rpm) == 24.0, "connected crank provides deterministic rpm")
	_expect(not bool(report.overstressed), "starter crusher network is within capacity")
	_expect(state.process(), "powered crusher processes input")
	_expect(state.collect_output() == 3, "crusher produces deterministic output")
	var payload: Dictionary = state.encode()
	var restored := MachineState.new()
	_expect(restored.decode(payload), "machine save decodes")
	_expect(restored.encode() == payload, "machine save round trips exactly")
	var disconnected := MachineState.new()
	disconnected.place(&"crank", MachineState.TYPE_CRANK, Vector3i.ZERO)
	disconnected.place(&"crusher", MachineState.TYPE_CRUSHER, Vector3i(3, 0, 0))
	disconnected.insert_stone(2)
	disconnected.crank(4)
	_expect(not disconnected.process(), "disconnected crusher cannot process")
	if _failures == 0:
		print("KINETIC_MACHINE_TEST_RESULT PASS")
		quit(0)
	else:
		print("KINETIC_MACHINE_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
