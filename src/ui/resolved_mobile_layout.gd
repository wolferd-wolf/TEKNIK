extends Node

# Godot resolves Control minimum sizes after theme overrides. This late layout
# pass pins the styled HUD to the real phone viewport and contains settings in a
# scroll view without taking ownership of gameplay or UI state.
const HOTBAR_MIN_SIZE := Vector2(612.0, 78.0)
const HOTBAR_BOTTOM_MARGIN: float = 12.0
const SETTINGS_POSITION := Vector2(920.0, 120.0)
const SETTINGS_SIZE := Vector2(312.0, 430.0)
const SETTINGS_SCROLL_SIZE := Vector2(286.0, 398.0)

var _world: Node
var _hotbar: PanelContainer
var _settings_panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_finalize_after_theme")


func _finalize_after_theme() -> void:
	# The industrial theme is installed from a sibling deferred call. Two layout
	# frames ensure all style margins and minimum sizes are final before offsets.
	await get_tree().process_frame
	await get_tree().process_frame
	_world = get_parent()
	if _world == null:
		_fail("world root missing")
		return
	_hotbar = _world.get("_bottom_hotbar_panel") as PanelContainer
	_settings_panel = _world.get("_settings_panel") as PanelContainer
	if _hotbar == null or _settings_panel == null:
		_fail("HUD controls unavailable")
		return
	_contain_settings_content()
	_pin_hotbar_to_bottom()
	await get_tree().process_frame
	# Reapply after the settings reparent has completed its own minimum-size pass.
	_pin_hotbar_to_bottom()
	_validate_resolved_layout()


func _contain_settings_content() -> void:
	if _settings_panel.get_node_or_null("SettingsScroll") != null:
		return
	if _settings_panel.get_child_count() == 0:
		return
	var content := _settings_panel.get_child(0) as Control
	if content == null:
		return
	_settings_panel.remove_child(content)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.custom_minimum_size = SETTINGS_SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.follow_focus = true
	_settings_panel.add_child(scroll)
	scroll.add_child(content)
	var content_minimum: Vector2 = content.custom_minimum_size
	content_minimum.x = SETTINGS_SCROLL_SIZE.x - 20.0
	content.custom_minimum_size = content_minimum

	_settings_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_settings_panel.grow_vertical = Control.GROW_DIRECTION_END
	_settings_panel.custom_minimum_size = SETTINGS_SIZE
	_settings_panel.position = SETTINGS_POSITION
	_settings_panel.size = SETTINGS_SIZE


func _pin_hotbar_to_bottom() -> void:
	var resolved_minimum: Vector2 = _hotbar.get_combined_minimum_size()
	var resolved_width: float = ceil(maxf(HOTBAR_MIN_SIZE.x, resolved_minimum.x))
	var resolved_height: float = ceil(maxf(HOTBAR_MIN_SIZE.y, resolved_minimum.y))
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.offset_left = -resolved_width * 0.5
	_hotbar.offset_right = resolved_width * 0.5
	_hotbar.offset_bottom = -HOTBAR_BOTTOM_MARGIN
	_hotbar.offset_top = -HOTBAR_BOTTOM_MARGIN - resolved_height


func _validate_resolved_layout() -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var hotbar_rect: Rect2 = _hotbar.get_global_rect()
	var settings_rect: Rect2 = _settings_panel.get_global_rect()
	var valid: bool = (
		viewport_rect.encloses(hotbar_rect)
		and viewport_rect.encloses(settings_rect)
		and hotbar_rect.end.x <= viewport_rect.size.x * 0.75
		and _settings_panel.get_node_or_null("SettingsScroll") is ScrollContainer
	)
	if not valid:
		_fail(
			"resolved geometry invalid hotbar=%s settings=%s viewport=%s"
			% [hotbar_rect, settings_rect, viewport_rect]
		)
		return
	print(
		"QA_RESOLVED_MOBILE_LAYOUT_PASS hotbar=", hotbar_rect,
		" settings=", settings_rect,
		" right_action_clearance=", viewport_rect.size.x * 0.75 - hotbar_rect.end.x,
		" settings_scrollable=", true
	)


func _fail(reason: String) -> void:
	push_error("RESOLVED_MOBILE_LAYOUT: %s" % reason)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-"):
			get_tree().quit(1)
			return
