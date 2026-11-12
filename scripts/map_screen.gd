extends Control
## خريطة العالم: كل الأماكن، فلترة حسب البيئة، قفل حسب المستوى

var grid: GridContainer
var filter := ""
var info_label: Label


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var main := VBoxContainer.new()
	main.anchor_right = 1.0
	main.anchor_bottom = 1.0
	main.offset_left = 24
	main.offset_right = -24
	main.offset_top = 16
	main.offset_bottom = -16
	main.add_theme_constant_override("separation", 12)
	add_child(main)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	main.add_child(top)
	top.add_child(_label("خريطة العالم", 32, Color(1, 0.8, 0.35)))
	info_label = _label("", 17, Color(0.7, 0.75, 0.82))
	top.add_child(info_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var back := _button("رجوع للكراج", Color(0.25, 0.27, 0.32))
	back.custom_minimum_size = Vector2(170, 44)
	back.pressed.connect(func(): Game.goto("garage"))
	top.add_child(back)
	var flow := GridContainer.new()
	flow.columns = 7
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	main.add_child(flow)
	var all_b := _button("الكل", Color(0.3, 0.3, 0.35), 15)
	all_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_b.pressed.connect(func(): _set_filter(""))
	flow.add_child(all_b)
	for b in Places.BIOMES:
		var id: String = b["id"]
		var fb := _button(b["name"], (b["card"] as Color).darkened(0.35), 15)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func(): _set_filter(id))
		flow.add_child(fb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	_fill()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	if OS.get_cmdline_user_args().has("--debug-map"):
		await get_tree().process_frame
		await get_tree().process_frame
		print("grid children ", grid.get_child_count(), " grid size ", grid.size, " sc size ", sc.size, " self ", size, " main ", main.size, " vp ", get_viewport_rect().size)
		if grid.get_child_count() > 0:
			print("card size ", (grid.get_child(0) as Control).size)


func _on_resize() -> void:
	if grid:
		grid.columns = clampi(int(get_viewport_rect().size.x / 380.0), 2, 6)


func _style(c: Color, r := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _label(t: String, s: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, col: Color, s := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", s)
	b.add_theme_stylebox_override("normal", _style(col, 10))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15), 10))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.2), 10))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _set_filter(id: String) -> void:
	filter = id
	_fill()


func _fill() -> void:
	for c in grid.get_children():
		c.queue_free()
	var lvl := Game.level()
	var unlocked := 0
	var found := 0
	for p in Places.list:
		if Places.is_unlocked(p["idx"]):
			unlocked += 1
		if Game.has_treasure(p["idx"]):
			found += 1
	info_label.text = "مستواك %d  •  %d / %d مكان مفتوح  •  %d كنز" % [lvl, unlocked, Places.list.size(), found]
	for p in Places.list:
		if filter != "" and p["biome"] != filter:
			continue
		grid.add_child(_card(p))


func _card(p: Dictionary) -> Control:
	var b: Dictionary = Places.get_biome(p["biome"])
	var idx: int = p["idx"]
	var open := Places.is_unlocked(idx)
	var col: Color = b["card"]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 150)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var base := col.darkened(0.55) if open else Color(0.1, 0.1, 0.12)
	var sb := _style(base, 14)
	sb.border_width_right = 6
	sb.border_color = col if open else Color(0.25, 0.25, 0.28)
	btn.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = base.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.disabled = not open
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -18
	v.offset_top = 10
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	btn.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	h.add_child(_label("#%d" % (idx + 1), 14, Color(1, 1, 1, 0.45)))
	var nm := _label(p["name"], 22, Color.WHITE if open else Color(0.5, 0.5, 0.55))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	v.add_child(_label("%s  •  %s" % [b["name"], Places.SEASONS[p["season"]]], 15, col.lightened(0.35) if open else Color(0.45, 0.45, 0.5)))
	v.add_child(_label("الجو: %s  •  الوقت: %s %s" % [Places.WEATHER[p["weather"]]["name"], Places.hour_text(p["hour"]), Places.time_name(p["hour"])], 14, Color(0.75, 0.78, 0.84) if open else Color(0.4, 0.4, 0.45)))
	var status := ""
	if not open:
		status = "مقفول — يحتاج المستوى %d" % int(p["req_level"])
	else:
		var vis := Game.visits(idx)
		status = "زيارات: %d" % vis if vis > 0 else "مكان جديد!"
		if Game.has_treasure(idx):
			status += "   ★ الكنز"
	v.add_child(_label(status, 15, Color(1, 0.8, 0.35) if open else Color(0.9, 0.45, 0.4)))
	btn.pressed.connect(func(): Game.start_trip(idx))
	return btn
