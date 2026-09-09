extends Panel
class_name InventoryScreen

## Full inventory: 9x4 slot grid with tap-to-move stack semantics,
## plus a recipe list. Bench-required recipes unlock near a Crafting Bench.

signal closed

var player: Player
var world: World

var _grid: GridContainer
var _recipe_list: VBoxContainer
var _bench_label: Label
var _picked_from := -1
var _picked_ghost: TextureRect

const SLOT_PX := 56.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(640, 520)
	position = -custom_minimum_size * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.11, 0.96)
	sb.border_color = Color(0.55, 0.55, 0.6, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(16, 8)
	add_child(title)

	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(640 - 46, 8)
	close.size = Vector2(32, 32)
	close.pressed.connect(func() -> void: closed.emit())
	add_child(close)

	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.position = Vector2(16, 44)
	add_child(_grid)
	for i in range(36):
		_grid.add_child(_make_slot(i))

	var hint := Label.new()
	hint.text = "Tap a stack to grab it, tap a slot to drop it."
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.position = Vector2(16, 44 + 4 * (SLOT_PX + 4) + 6)
	add_child(hint)

	var craft_title := Label.new()
	craft_title.text = "Crafting"
	craft_title.add_theme_font_size_override("font_size", 20)
	craft_title.position = Vector2(420, 8)
	add_child(craft_title)

	_bench_label = Label.new()
	_bench_label.text = ""
	_bench_label.add_theme_font_size_override("font_size", 13)
	_bench_label.position = Vector2(420, 34)
	_bench_label.modulate = Color(1.0, 0.85, 0.4)
	add_child(_bench_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(420, 56)
	scroll.size = Vector2(640 - 420 - 12, 520 - 70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_recipe_list)

	_picked_ghost = TextureRect.new()
	_picked_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked_ghost.size = Vector2(SLOT_PX - 8, SLOT_PX - 8)
	_picked_ghost.visible = false
	_picked_ghost.z_index = 10
	add_child(_picked_ghost)

	refresh()


func _make_slot(i: int) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.07)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var sel := sb.duplicate() as StyleBoxFlat
	sel.border_color = Color(1.0, 0.9, 0.4)
	sel.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", sel)
	b.set_meta("slot", i)
	b.pressed.connect(_on_slot_pressed.bind(i))

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	b.add_child(icon)

	var count := Label.new()
	count.name = "Count"
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", 14)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -34
	count.offset_top = -22
	count.offset_right = -4
	count.offset_bottom = -2
	b.add_child(count)
	return b


static func _icon_for(id: int) -> TextureRect:
	var tr := TextureRect.new()
	var tile := ItemRegistry.tile_of(id)
	if tile >= 0:
		var at := AtlasTexture.new()
		at.atlas = ChunkMesher.atlas_texture()
		at.region = Rect2(
			float(tile % AtlasTiles.COLS) * AtlasTiles.TILE_PX,
			float(int(tile / float(AtlasTiles.COLS))) * AtlasTiles.TILE_PX,
			AtlasTiles.TILE_PX, AtlasTiles.TILE_PX)
		tr.texture = at
	return tr


func refresh() -> void:
	if player == null:
		return
	for i in range(36):
		var b := _grid.get_child(i) as Button
		var icon := b.get_node("Icon") as TextureRect
		var count := b.get_node("Count") as Label
		var s := player.inventory.get_slot(i)
		if s.is_empty():
			icon.texture = null
			count.text = ""
		else:
			icon.texture = _icon_for(int(s["id"])).texture
			var n := int(s["count"])
			count.text = str(n) if n > 1 else ""
		# highlight the hotbar row + picked slot
		var sb := b.get_theme_stylebox("focus") as StyleBoxFlat
		sb.border_color = Color(1.0, 0.9, 0.4) if (i == _picked_from) else (
			Color(0.95, 0.85, 0.35, 0.55) if i < 9 else Color(1, 1, 1, 0.25))
		b.queue_redraw()
	_refresh_recipes()


func _on_slot_pressed(i: int) -> void:
	var inv := player.inventory
	if _picked_from == -1:
		if not inv.get_slot(i).is_empty():
			_picked_from = i
			var s0 := inv.get_slot(i)
			_picked_ghost.texture = _icon_for(int(s0["id"])).texture
			_picked_ghost.visible = true
	elif _picked_from == i:
		# split: move half into the first other empty slot
		var s := inv.get_slot(i)
		var cnt := int(s["count"])
		var half := floori(cnt * 0.5)
		if half >= 1 and cnt >= 2:
			for j in range(inv.size):
				if j == i:
					continue
				if inv.get_slot(j).is_empty():
					inv.slots[j] = Inventory.make_stack(int(s["id"]), half, int(s.get("dur", 0)))
					s["count"] = cnt - half
					break
		_picked_from = -1
	else:
		inv.move(_picked_from, i)
		_picked_from = -1
	_picked_ghost.visible = _picked_from >= 0
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _picked_from >= 0:
		var mm := event as InputEventMouseMotion
		_picked_ghost.position = mm.position + Vector2(12, 12)


func _refresh_recipes() -> void:
	if player == null or world == null:
		return
	var near_bench := world.is_bench_near(player.global_position, 4)
	_bench_label.text = "Crafting Bench nearby" if near_bench else "Tools need a Crafting Bench nearby"
	for c in _recipe_list.get_children():
		c.queue_free()
	var held_ids := []
	for i in range(player.inventory.size):
		var id := player.inventory.get_id(i)
		if id != 0 and not held_ids.has(id):
			held_ids.append(id)
	for r: Dictionary in RecipeRegistry.recipes_for(held_ids):
		var row := HBoxContainer.new()
		var can := RecipeRegistry.can_craft(r, player.inventory, near_bench)
		var out_id := int(r["out"][0])
		var out_n := int(r["out"][1])
		var icon := _icon_for(out_id)
		icon.custom_minimum_size = Vector2(36, 36)
		row.add_child(icon)
		var label := Label.new()
		var parts: Array[String] = []
		var need: Dictionary = r["in"]
		for id: int in need:
			parts.append("%dx %s" % [need[id], ItemRegistry.name_of(id)])
		label.text = "%s%s  <-  %s" % [ItemRegistry.name_of(out_id), (" x%d" % out_n) if out_n > 1 else "", ", ".join(parts)]
		label.add_theme_font_size_override("font_size", 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.modulate = Color(1, 1, 1, 1.0 if can else 0.45)
		if bool(r.get("bench", false)) and not near_bench:
			label.modulate = Color(1.0, 0.7, 0.4, 0.7)
		row.add_child(label)
		var btn := Button.new()
		btn.text = "Craft"
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = not can
		btn.pressed.connect(_craft.bind(r, near_bench))
		row.add_child(btn)
		_recipe_list.add_child(row)


func _craft(r: Dictionary, near_bench: bool) -> void:
	if player == null:
		return
	if not RecipeRegistry.can_craft(r, player.inventory, near_bench):
		return
	RecipeRegistry.craft(r, player.inventory)
	refresh()
