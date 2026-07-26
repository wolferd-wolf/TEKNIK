extends CanvasLayer

const UPDATE_INTERVAL_SECONDS: float = 0.35
const HOTBAR_PATH := NodePath("GameplayHUD/BottomHotbar")
const INVENTORY_BUTTON_PATH := NodePath("GameplayHUD/InventoryButton")
const ACTION_CONTROL_LIMIT_RATIO: float = 0.75
const HUD_GAP: float = 12.0
const HOTBAR_BOTTOM_MARGIN: float = 8.0
const FALLBACK_HOTBAR_SIZE := Vector2(612.0, 77.0)

var _label: Label
var _elapsed: float = 0.0
var _layout_scene_id: int = 0
var _hud_layout_pending: bool = true


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.name = "FPSCounterLabel"
	_label.position = Vector2(10.0, 8.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = "FPS --"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.94, 0.92))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	get_viewport().size_changed.connect(_request_hud_layout)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= UPDATE_INTERVAL_SECONDS:
		_elapsed = 0.0
		_label.text = "FPS %d" % Engine.get_frames_per_second()

	var scene: Node = get_tree().current_scene
	var scene_id: int = scene.get_instance_id() if scene != null else 0
	if scene_id != _layout_scene_id:
		_layout_scene_id = scene_id
		_hud_layout_pending = true
	if _hud_layout_pending:
		_hud_layout_pending = not _layout_gameplay_hud(scene)


func _request_hud_layout() -> void:
	_hud_layout_pending = true


func _layout_gameplay_hud(scene: Node) -> bool:
	if scene == null:
		return false
	var hotbar := scene.get_node_or_null(HOTBAR_PATH) as Control
	var inventory_button := scene.get_node_or_null(INVENTORY_BUTTON_PATH) as Control
	if hotbar == null or inventory_button == null:
		return false

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var hotbar_size: Vector2 = hotbar.custom_minimum_size
	if hotbar_size.x <= 0.0 or hotbar_size.y <= 0.0:
		hotbar_size = FALLBACK_HOTBAR_SIZE
	var inventory_rect: Rect2 = inventory_button.get_global_rect()
	var minimum_x: float = inventory_rect.end.x + HUD_GAP
	var maximum_x: float = viewport_size.x * ACTION_CONTROL_LIMIT_RATIO - hotbar_size.x - HUD_GAP
	var centered_x: float = (viewport_size.x - hotbar_size.x) * 0.5
	var target_x: float = maxf(0.0, maximum_x)
	if maximum_x >= minimum_x:
		target_x = clampf(centered_x, minimum_x, maximum_x)
	var target_y: float = maxf(0.0, viewport_size.y - hotbar_size.y - HOTBAR_BOTTOM_MARGIN)

	# BottomHotbar is created below a CanvasLayer, not a Control parent. Anchored
	# offsets are therefore ambiguous after later code mutates position.x. Convert
	# it to one explicit viewport-space rectangle and keep that rectangle responsive.
	hotbar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hotbar.grow_horizontal = Control.GROW_DIRECTION_END
	hotbar.grow_vertical = Control.GROW_DIRECTION_END
	hotbar.position = Vector2(target_x, target_y)
	hotbar.size = hotbar_size
	return true
