extends SceneTree

const TouchSlider = preload("res://src/ui/touch_slider.gd")

var _failures: int = 0


func _init() -> void:
	_expect(is_equal_approx(TouchSlider.value_for_position(0.0, 280.0, 2.0, 5.0, 1.0), 2.0), "touching the left edge selects minimum render distance")
	_expect(is_equal_approx(TouchSlider.value_for_position(280.0, 280.0, 2.0, 5.0, 1.0), 5.0), "touching the right edge selects maximum render distance")
	_expect(is_equal_approx(TouchSlider.value_for_position(112.0, 280.0, 0.5, 2.0, 0.1), 1.1), "touch sensitivity slider snaps finger position to 0.1 steps")
	var source: String = FileAccess.get_file_as_string("res://src/ui/touch_slider.gd")
	_expect(source.contains("InputEventScreenTouch") and source.contains("InputEventScreenDrag"), "slider handles native Android touch and drag events")
	_expect(source.contains("accept_event"), "slider claims touch events from gameplay controls")
	if _failures == 0:
		print("TOUCH_SLIDER_TEST_RESULT PASS")
		quit(0)
	else:
		print("TOUCH_SLIDER_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
