extends SceneTree

const MachineState = preload("res://src/simulation/kinetic_machine_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_atomic_starter_assembly()
	_test_explicit_processing_loop()
	_test_disconnected_network()
	_test_shipping_runtime()
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


func _test_shipping_runtime() -> void:
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var runtime: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	_expect(scene_text.contains("kinetic_machine_main.gd"), "shipping scene enables functional kinetic machines")
	_expect(runtime.contains("AssembleStarterKinetics"), "machine assembly is a separate player action")
	_expect(runtime.contains("LoadCrusherStone"), "crusher loading is a separate player action")
	_expect(runtime.contains("TurnHandCrank"), "hand cranking is a separate player action")
	_expect(runtime.contains("CollectCrusherOutput"), "machine output collection is a separate player action")
	_expect(runtime.contains("ITEM_STONE_CRUSHER"), "assembly requires the crafted crusher item")
	_expect(runtime.contains("QA_KINETIC_MACHINE_PASS"), "recorded gameplay verifies the complete kinetic loop")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
