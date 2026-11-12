extends CanvasLayer
## واجهة القيادة: السرعة، الوقود، النيترو، الساعة، الجو، الغنائم، الخريطة الصغيرة، قائمة الإيقاف

signal resume_pressed
signal garage_pressed
signal camera_pressed
signal quit_pressed

var world: Node
var root: Control
var lbl_place: Label
var lbl_sub: Label
var lbl_clock: Label
var lbl_speed: Label
var lbl_cam: Label
var fuel_bar: ProgressBar
var nitro_bar: ProgressBar
var nitro_box: Control
var loot_labels := {}
var lbl_items: Label
var toasts: VBoxContainer
var prompt: Label
var pause_panel: Control
var minimap: MiniMap
var hint: Label


class MiniMap extends Control:
	var tex: Texture2D
	var world: Node
	var size_m := 400.0

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
		if tex:
			draw_texture_rect(tex, Rect2(Vector2(4, 4), s - Vector2(8, 8)), false, Color(1, 1, 1, 0.92))
		if world == null or world.car == null:
			return
		var inner := s - Vector2(8, 8)
		var to_px := func(p: Vector3) -> Vector2:
			return Vector2(4, 4) + Vector2((p.x / size_m + 0.5) * inner.x, (p.z / size_m + 0.5) * inner.y)
		var cp: Vector3 = world.car.global_position
		for it in world.items:
			if it["taken"] or it["kind"] == "treasure":
				continue
			var ip: Vector3 = it["pos"]
			if ip.distance_to(cp) < 110.0:
				draw_circle(to_px.call(ip), 3.2, it["color"])
		var g: Vector2 = to_px.call(world.spawn)
		draw_rect(Rect2(g - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 1.0, 0.45))
		draw_rect(Rect2(g - Vector2(5, 5), Vector2(10, 10)), Color(0, 0, 0), false, 1.5)
		var c: Vector2 = to_px.call(cp)
		var f: Vector3 = -world.car.global_basis.z
		var ang := atan2(f.z, f.x)
		var pts := PackedVector2Array([
			c + Vector2(cos(ang), sin(ang)) * 9.0,
			c + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * 6.0,
			c + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * 6.0,
		])
		draw_colored_polygon(pts, Color(1, 0.95, 0.3))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0), 1.5)
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.25), false, 2.0)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_info()
	_build_loot()
	_build_gauges()
	_build_minimap()
	_build_center()
	_build_pause()


func _panel_style(alpha := 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, alpha)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _label(txt: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_info() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-20, 20)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	lbl_place = _label("", 26, Color(1, 0.86, 0.5))
	lbl_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(lbl_place)
	lbl_sub = _label("", 16, Color(0.85, 0.88, 0.92))
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(lbl_sub)
	lbl_clock = _label("", 20, Color(0.75, 0.9, 1.0))
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(lbl_clock)


func _build_loot() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.position = Vector2(20, 20)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := _label("غنائم الرحلة", 15, Color(0.7, 0.72, 0.78))
	v.add_child(t)
	for k in Game.RES_ORDER:
		var l := _label("", 18, Game.RES_COLORS[k])
		v.add_child(l)
		loot_labels[k] = l
	lbl_items = _label("", 15, Color(0.8, 0.8, 0.85))
	v.add_child(lbl_items)


func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(260, 14)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(7)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(7)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_gauges() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.position.y = -20
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	var sv := VBoxContainer.new()
	h.add_child(sv)
	lbl_speed = _label("0", 44, Color.WHITE)
	lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(lbl_speed)
	var u := _label("كم/س", 14, Color(0.7, 0.72, 0.78))
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(u)
	var bars := VBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(bars)
	bars.add_child(_label("الوقود", 14, Color(1, 0.6, 0.4)))
	fuel_bar = _bar(Color(1.0, 0.45, 0.2))
	bars.add_child(fuel_bar)
	nitro_box = VBoxContainer.new()
	bars.add_child(nitro_box)
	nitro_box.add_child(_label("النيترو (Shift)", 14, Color(0.4, 0.8, 1)))
	nitro_bar = _bar(Color(0.25, 0.75, 1.0))
	nitro_box.add_child(nitro_bar)
	lbl_cam = _label("", 13, Color(0.65, 0.68, 0.72))
	bars.add_child(lbl_cam)


func _build_minimap() -> void:
	minimap = MiniMap.new()
	minimap.custom_minimum_size = Vector2(230, 230)
	minimap.size = Vector2(230, 230)
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position = Vector2(-250, -250)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	hint = _label("W/S قيادة • A/D توجيه • Space هاند بريك • Shift نيترو • C كاميرا • L أضواء • R تعديل • E الكراج • T سحب • Esc قائمة", 13, Color(0.8, 0.82, 0.86, 0.85))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, -34)
	root.add_child(hint)


func _build_center() -> void:
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-300, 90)
	toasts.custom_minimum_size = Vector2(600, 0)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	prompt = _label("", 24, Color(1, 1, 0.75))
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.position = Vector2(-450, 120)
	prompt.custom_minimum_size = Vector2(900, 0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(prompt)


func _menu_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(380, 54)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(0.9))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := _label("متوقف", 34, Color(1, 0.86, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := _menu_button("استمرار")
	b1.pressed.connect(func(): resume_pressed.emit())
	v.add_child(b1)
	var b2 := _menu_button("تغيير الكاميرا")
	b2.pressed.connect(func(): camera_pressed.emit())
	v.add_child(b2)
	var b3 := _menu_button("سحب للكراج (تخسر 40% من الغنائم)")
	b3.pressed.connect(func(): garage_pressed.emit())
	v.add_child(b3)
	var b4 := _menu_button("طلوع من اللعبة")
	b4.pressed.connect(func(): quit_pressed.emit())
	v.add_child(b4)
	var info := _label("ارجع بنفسك للكراج (المربع الأخضر) حتى تحفظ كل الغنائم", 15, Color(0.7, 0.75, 0.8))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and world and world.has_method("_toggle_pause"):
		world._toggle_pause()
		get_viewport().set_input_as_handled()


func show_pause(on: bool) -> void:
	pause_panel.visible = on


func toast(txt: String, col := Color.WHITE, dur := 2.6) -> void:
	var l := _label(txt, 22, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toasts.add_child(l)
	if toasts.get_child_count() > 5:
		toasts.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func set_prompt(txt: String) -> void:
	if prompt.text != txt:
		prompt.text = txt


func update_hud(info: Dictionary) -> void:
	lbl_place.text = info["place"]
	lbl_sub.text = info["sub"]
	lbl_clock.text = info["clock"]
	lbl_speed.text = str(int(round(info["speed"])))
	fuel_bar.max_value = info["fuel_max"]
	fuel_bar.value = info["fuel"]
	nitro_box.visible = info["nitro_max"] > 0.0
	nitro_bar.max_value = maxf(info["nitro_max"], 0.01)
	nitro_bar.value = info["nitro"]
	lbl_cam.text = "الكاميرا: " + info["cam"]
	for k in Game.RES_ORDER:
		loot_labels[k].text = "%s: %d" % [Game.RES_NAMES[k], int(Game.run.get(k, 0))]
	lbl_items.text = "أغراض: %d / %d" % [int(info["taken"]), int(info["total"])]
	minimap.queue_redraw()
