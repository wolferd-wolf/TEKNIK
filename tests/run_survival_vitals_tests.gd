extends SceneTree

const SurvivalVitalsState = preload("res://src/survival/survival_vitals_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_bounds_and_drain()
	_test_starvation_and_regeneration()
	_test_persistence()
	_test_shipping_stack()
	if _failures == 0:
		print("SURVIVAL_VITALS_TEST_RESULT PASS")
		quit(0)
	else:
		print("SURVIVAL_VITALS_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_bounds_and_drain() -> void:
	var state := SurvivalVitalsState.new()
	state.update(10.0, true)
	_expect(state.hunger < SurvivalVitalsState.MAX_HUNGER, "hunger drains deterministically over time")
	_expect(state.stamina == 0.0, "sustained movement drains bounded stamina")
	state.update(10.0, false)
	_expect(state.stamina == SurvivalVitalsState.MAX_STAMINA, "idle recovery restores bounded stamina")
	state.apply_damage(500.0)
	_expect(state.health == 0.0, "damage cannot reduce health below zero")
	state.eat(500.0)
	_expect(state.hunger == SurvivalVitalsState.MAX_HUNGER, "food cannot exceed maximum hunger")


func _test_starvation_and_regeneration() -> void:
	var starving := SurvivalVitalsState.new()
	starving.hunger = 0.0
	starving.health = 50.0
	starving.update(5.0, false)
	_expect(starving.health == 40.0, "starvation applies deterministic damage")
	var recovering := SurvivalVitalsState.new()
	recovering.health = 40.0
	recovering.hunger = 80.0
	recovering.update(5.0, false)
	_expect(recovering.health == 45.0, "well-fed health regenerates deterministically")


func _test_persistence() -> void:
	var state := SurvivalVitalsState.new()
	state.health = 73.0
	state.hunger = 61.0
	state.stamina = 48.0
	var payload: Dictionary = state.encode()
	var restored := SurvivalVitalsState.new()
	_expect(restored.decode(payload), "versioned vitals payload decodes")
	_expect(restored.encode() == payload, "vitals save round trip is exact")
	_expect(not restored.decode({"schema": 99}), "unknown vitals schema is rejected")


func _test_shipping_stack() -> void:
	var capture: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var runtime: String = FileAccess.get_file_as_string("res://src/main/survival_vitals_main.gd")
	_expect(capture.contains("survival_vitals_main.gd"), "shipping runtime enables survival vitals")
	_expect(runtime.contains("SurvivalVitalsHUD"), "shipping runtime creates a vitals HUD")
	_expect(runtime.contains("QA_SURVIVAL_VITALS_PASS"), "gameplay recording verifies vitals persistence")
	_expect(runtime.contains("placement_preview_main.gd"), "vitals preserve precise placement and targeting stack")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
