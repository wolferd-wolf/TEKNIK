extends "res://src/main/placement_preview_main.gd"

const SurvivalVitalsState = preload("res://src/survival/survival_vitals_state.gd")

const VITALS_PATH: String = "user://teknik-survival-vitals.json"
const VITALS_SAVE_INTERVAL_MS: int = 3000

var _vitals: TeknikSurvivalVitalsState = SurvivalVitalsState.new()
var _next_vitals_save_ms: int = 0
var _health_bar: ProgressBar
var _hunger_bar: ProgressBar
var _stamina_bar: ProgressBar


func _ready() -> void:
	_load_vitals()
	super._ready()
	_build_vitals_hud()
	_refresh_vitals_hud()
	_next_vitals_save_ms = Time.get_ticks_msec() + VITALS_SAVE_INTERVAL_MS
	_runtime_log.event("info", "survival", "vitals_ready", _vitals.encode())


func _process(delta: float) -> void:
	super._process(delta)
	var moving: bool = false
	if is_instance_valid(_player):
		moving = Vector2(_player.velocity.x, _player.velocity.z).length_squared() > 0.09
	_vitals.update(delta, moving)
	_refresh_vitals_hud()
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= _next_vitals_save_ms:
		_save_vitals_now()
		_next_vitals_save_ms = now_ms + VITALS_SAVE_INTERVAL_MS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_vitals_now()
	super._notification(what)


func _build_vitals_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SurvivalVitalsHUD"
	layer.layer = 7
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 238.0)
	panel.custom_minimum_size = Vector2(250.0, 108.0)
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	panel.add_child(rows)
	_health_bar = _add_vital_row(rows, "HEALTH", Color(0.82, 0.18, 0.16, 1.0))
	_hunger_bar = _add_vital_row(rows, "HUNGER", Color(0.88, 0.58, 0.12, 1.0))
	_stamina_bar = _add_vital_row(rows, "STAMINA", Color(0.22, 0.72, 0.38, 1.0))


func _add_vital_row(parent: VBoxContainer, label_text: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(72.0, 24.0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150.0, 20.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


func _refresh_vitals_hud() -> void:
	if _health_bar != null:
		_health_bar.value = _vitals.health
		_health_bar.tooltip_text = "Health %.0f / %.0f" % [_vitals.health, SurvivalVitalsState.MAX_HEALTH]
	if _hunger_bar != null:
		_hunger_bar.value = _vitals.hunger
		_hunger_bar.tooltip_text = "Hunger %.0f / %.0f" % [_vitals.hunger, SurvivalVitalsState.MAX_HUNGER]
	if _stamina_bar != null:
		_stamina_bar.value = _vitals.stamina
		_stamina_bar.tooltip_text = "Stamina %.0f / %.0f" % [_vitals.stamina, SurvivalVitalsState.MAX_STAMINA]


func _load_vitals() -> void:
	if not FileAccess.file_exists(VITALS_PATH):
		return
	var file := FileAccess.open(VITALS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _vitals.decode(parsed):
		return
	push_warning("SURVIVAL vitals save was invalid; using defaults")
	_vitals = SurvivalVitalsState.new()


func _save_vitals_now() -> void:
	var temporary_path: String = VITALS_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("SURVIVAL vitals save could not open temporary file")
		return
	file.store_string(JSON.stringify(_vitals.encode(), "\t"))
	file.flush()
	file = null
	var absolute_target: String = ProjectSettings.globalize_path(VITALS_PATH)
	var absolute_temporary: String = ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(VITALS_PATH):
		DirAccess.remove_absolute(absolute_target)
	var result: Error = DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if result != OK:
		push_error("SURVIVAL vitals save rename failed: %s" % error_string(result))
		return
	_runtime_log.event("info", "survival", "vitals_saved", _vitals.encode())


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	_vitals.apply_damage(24.0)
	_vitals.hunger = 72.0
	_vitals.stamina = 41.0
	_save_vitals_now()
	var restored := SurvivalVitalsState.new()
	var persisted: bool = false
	var file := FileAccess.open(VITALS_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		persisted = parsed is Dictionary and restored.decode(parsed) and restored.encode() == _vitals.encode()
	if not persisted or _health_bar == null or _hunger_bar == null or _stamina_bar == null:
		push_error("QA_SURVIVAL_VITALS persistence or HUD failed")
		get_tree().quit(1)
		return
	_refresh_vitals_hud()
	print(
		"QA_SURVIVAL_VITALS_PASS health=", _vitals.health,
		" hunger=", _vitals.hunger,
		" stamina=", _vitals.stamina,
		" persisted=", persisted,
		" hud=", true
	)
