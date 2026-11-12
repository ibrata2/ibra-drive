extends CanvasLayer
## واجهة المهمة على الطريق: الحمولة، المسافة، المحطة الجاية، الموعد، التعب، رادار الطريق، شاشة النهاية والحوار

var world
var root: Control
var lbl_title: Label
var lbl_cargo: Label
var cargo_bar: ProgressBar
var lbl_dist: Label
var lbl_next: Label
var lbl_time: Label
var route_bar: ProgressBar
var fatigue_box: Control
var fatigue_bar: ProgressBar
var lbl_warn: Label
var radar: Radar
var blink: ColorRect
var fade_rect: ColorRect
var fade_lbl: Label
var big_timer: Label
var summary: Control


class Radar extends Control:
	var w
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.04, 0.06, 0.72))
		if w == null or w.car == null:
			return
		var c: Vector2 = s * Vector2(0.5, 0.68)
		var scale := 0.55
		var cp: Vector3 = w.car.global_position
		var f: Vector3 = -w.car.global_basis.z
		var yaw := atan2(f.x, -f.z)
		var to_px := func(p: Vector3) -> Vector2:
			var d := Vector2(p.x - cp.x, p.z - cp.z).rotated(-yaw)
			return c + d * scale
		# الطريق
		var pts := PackedVector2Array()
		var s0: float = w.car_s - 140.0
		while s0 < w.car_s + 300.0:
			var rp: Vector3 = w._route_pos(s0, 0.0)
			pts.append(to_px.call(rp))
			s0 += 8.0
		var roadw := maxf(w.road_half * 2.0 * scale, 3.0)
		if pts.size() > 1:
			draw_polyline(pts, Color(0.55, 0.55, 0.58, 0.9) if w.paved else Color(0.6, 0.5, 0.35, 0.8), roadw, true)
		# المعالم
		for ft in w.features:
			var fs: float = ft["s"]
			if fs < w.car_s - 140.0 or fs > w.car_s + 320.0:
				continue
			var col := Color.WHITE
			var u := 0.0
			match str(ft["type"]):
				"fuel":
					col = Color(0.2, 0.9, 0.4)
					u = w.road_half + 18.0
				"food":
					col = Color(1.0, 0.55, 0.2)
					u = w.road_half + 18.0
				"garage":
					col = Color(0.4, 0.6, 1.0)
					u = w.road_half + 18.0
				"check":
					col = Color(1.0, 0.25, 0.2)
				"ring":
					if ft["done"]:
						continue
					col = Color(1.0, 0.85, 0.2)
					u = ft["u"]
				"stuck":
					if not ft.has("node"):
						continue
					col = Color(1.0, 0.5, 0.1)
					u = ft["u"]
				"depot_end", "camp_end":
					col = Color(0.2, 1.0, 0.5)
				_:
					continue
			var pp: Vector2 = to_px.call(w._route_pos(fs, u))
			draw_circle(pp, 6.0, Color(0, 0, 0, 0.6))
			draw_circle(pp, 4.5, col)
		# المقطورات
		for t in w.trailers:
			var a: Vector2 = to_px.call(t.global_transform * Vector3(0, 0, t.front_z))
			var b: Vector2 = to_px.call(t.global_transform * Vector3(0, 0, t.rear_z))
			draw_line(a, b, Color(0.9, 0.9, 0.95), maxf(t.body_w * scale, 2.5))
		# السيارة
		var tri := PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 7), c + Vector2(-6, 7)])
		draw_colored_polygon(tri, Color(1, 0.85, 0.25))
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0), 1.5)
		# سهم البوصلة للحلقة الجاية أو النهاية (إذا برا الرادار)
		var tgt := Vector3.INF
		for ft in w.features:
			if ft["type"] == "ring" and not ft["done"]:
				tgt = w._route_pos(ft["s"], ft["u"])
				break
		if tgt == Vector3.INF:
			tgt = w._route_pos(w.route_len, 0.0)
		var tp: Vector2 = to_px.call(tgt)
		if not Rect2(Vector2(8, 8), s - Vector2(16, 16)).has_point(tp):
			var dir := (tp - c).normalized()
			var edge := c + dir * (minf(s.x, s.y) * 0.42)
			var ar := PackedVector2Array([edge + dir * 12.0, edge + dir.rotated(2.5) * 9.0, edge + dir.rotated(-2.5) * 9.0])
			draw_colored_polygon(ar, Color(0.3, 1.0, 0.6))
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.22), false, 2.0)


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_bottom()
	blink = ColorRect.new()
	blink.color = Color(0, 0, 0, 0)
	blink.set_anchors_preset(Control.PRESET_FULL_RECT)
	blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blink)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.02, 0.03, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	fade_lbl = _label("", 34, Color(1, 0.86, 0.5))
	fade_lbl.set_anchors_preset(Control.PRESET_CENTER)
	fade_lbl.position = Vector2(-400, -30)
	fade_lbl.custom_minimum_size = Vector2(800, 0)
	fade_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_lbl.modulate.a = 0.0
	root.add_child(fade_lbl)


func _style(c: Color, r := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _label(t: String, s: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(col: Color, w := 300.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 12)
	b.show_percentage = false
	b.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 6))
	b.add_theme_stylebox_override("fill", _style(col, 6))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _build_top() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.07, 0.62)))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 14
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	lbl_title = _label("", 22, Color(1, 0.86, 0.5))
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_title)
	lbl_dist = _label("", 18, Color(0.9, 0.93, 1.0))
	lbl_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_dist)
	route_bar = _bar(Color(0.3, 0.8, 0.5), 420)
	v.add_child(route_bar)
	lbl_next = _label("", 15, Color(0.75, 0.85, 0.95))
	lbl_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_next)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	lbl_cargo = _label("", 15, Color(0.9, 0.85, 0.75))
	h.add_child(lbl_cargo)
	cargo_bar = _bar(Color(0.95, 0.75, 0.25), 160)
	h.add_child(cargo_bar)
	lbl_time = _label("", 16, Color(0.6, 0.9, 1.0))
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl_time)
	big_timer = _label("", 54, Color(1, 0.9, 0.3))
	big_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	big_timer.position = Vector2(-150, 190)
	big_timer.custom_minimum_size = Vector2(300, 0)
	big_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(big_timer)


func _build_bottom() -> void:
	radar = Radar.new()
	radar.w = world
	radar.custom_minimum_size = Vector2(240, 240)
	radar.size = Vector2(240, 240)
	radar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	radar.position = Vector2(-260, -260) if not Game.is_mobile() else Vector2(-260, -700)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar)
	fatigue_box = PanelContainer.new()
	(fatigue_box as PanelContainer).add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.07, 0.55)))
	fatigue_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fatigue_box.position = Vector2(20, -130) if not Game.is_mobile() else Vector2(20, -400)
	fatigue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fatigue_box)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fatigue_box.add_child(v)
	v.add_child(_label("التعب — ارتاح بالمطعم", 14, Color(0.85, 0.75, 1.0)))
	fatigue_bar = _bar(Color(0.65, 0.45, 1.0), 220)
	v.add_child(fatigue_bar)
	lbl_warn = _label("", 15, Color(1, 0.6, 0.4))
	v.add_child(lbl_warn)


func _fmt_time(h: float) -> String:
	return Places.hour_text(fmod(h + 48.0, 24.0))


func refresh(_delta: float) -> void:
	if world == null or world.car == null:
		return
	var w = world
	var sp: Dictionary = w.spec
	var is_lesson: bool = sp.get("kind", "") == "lesson"
	radar.visible = not is_lesson
	route_bar.visible = not is_lesson
	if is_lesson:
		lbl_title.text = sp.get("title", "")
		lbl_dist.text = School.lesson(sp.get("lesson", ""))["desc"]
		lbl_next.visible = false
		lbl_cargo.text = ""
		cargo_bar.visible = false
		lbl_time.visible = false
		big_timer.text = ""
		fatigue_box.visible = false
		blink.color.a = 0.0
		return
	var title: String = sp.get("title", "")
	if title == "":
		title = "%s ← %s" % [w.dest_name, w.origin_name] if w.origin_name != "" else w.dest_name
	lbl_title.text = title
	var frac: float = clampf(w.car_s / w.route_len, 0.0, 1.0)
	route_bar.value = frac * 100.0
	var km_left: int = int(round((1.0 - frac) * w.total_km))
	if w.goal == "race":
		lbl_dist.text = "الحلقات: %d • باقي للنهاية %s كم" % [w.rings_done, Jobs.ar_num(km_left)]
	else:
		lbl_dist.text = "باقي %s كم إلى %s" % [Jobs.ar_num(km_left), w.dest_name]
	# المحطة الجاية
	var nxt := ""
	var best := 1e9
	var names := {"fuel": "محطة وقود", "food": "مطعم", "garage": "كراج تصليح", "check": "سيطرة", "bridge": "جسر", "town": ""}
	for f in w.features:
		var t: String = f["type"]
		if not names.has(t):
			continue
		if t == "town" and str(f.get("city", "")) == str(sp.get("from", "")):
			continue
		var fs: float = f["s"] if t != "town" else float(f["s0"])
		if fs > w.car_s + 5.0 and fs - w.car_s < best:
			best = fs - w.car_s
			var nm: String = names[t]
			if t == "town":
				nm = Jobs.city_name(f["city"])
			nxt = "%s بعد %s كم" % [nm, Jobs.ar_num(maxi(1, int(round(best / w.route_len * w.total_km))))]
	lbl_next.text = nxt
	lbl_next.visible = nxt != ""
	# الحمولة
	if not w.cargo.is_empty():
		lbl_cargo.text = "%s — سلامتها %d%%" % [w.cargo["name"], int(round((1.0 - w.damage) * 100.0))]
		cargo_bar.value = (1.0 - w.damage) * 100.0
		cargo_bar.visible = true
	elif w.goal == "rescue":
		lbl_cargo.text = "السيارة المسحوبة ويّاك ✓" if w.towing else "روح للسيارة العالقة"
		cargo_bar.visible = false
	else:
		lbl_cargo.text = ""
		cargo_bar.visible = false
	# الوقت
	var tt := ""
	if w.deadline_hour > 0.0:
		var left: float = w.deadline_hour - w.hours_elapsed
		var lm := int(absf(left) * 60.0)
		if left >= 0.0:
			tt = "الموعد: قبل %s — باقي %d:%02d" % [_fmt_time(w.start_hour + w.deadline_hour), lm / 60, lm % 60]
		else:
			tt = "متأخر %d:%02d!" % [lm / 60, lm % 60]
	lbl_time.text = tt
	lbl_time.visible = tt != ""
	if w.goal == "race" and not w.finished:
		big_timer.text = "%d" % int(ceil(maxf(w.race_time, 0.0)))
		big_timer.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if w.race_time < 15.0 else Color(1, 0.9, 0.3))
	else:
		big_timer.text = ""
	fatigue_box.visible = w.goal != "race" and not w.exam_mode
	fatigue_bar.value = w.fatigue * 100.0
	var warn := ""
	if w.fatigue > 0.85:
		warn = "نعسان! وكّف بأقرب مطعم"
	elif w.fatigue > 0.7:
		warn = "بديت تتعب..."
	if w.car.burst_wheel >= 0:
		warn += ("\n" if warn != "" else "") + "تاير منفجر"
	if w.car_damage > 0.3:
		warn += ("\n" if warn != "" else "") + "السيارة متضررة %d%%" % int(w.car_damage * 100.0)
	lbl_warn.text = warn
	blink.color.a = w.fatigue_blink * 0.85
	radar.queue_redraw()


func fade(text: String) -> void:
	fade_lbl.text = text
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.92, 0.35)
	tw.parallel().tween_property(fade_lbl, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.3)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.5)
	tw.parallel().tween_property(fade_lbl, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------- الحوار
func show_dialog(lines: Array, done: Callable) -> void:
	var dl := Dialog.new()
	dl.lines = lines
	dl.done = done
	root.add_child(dl)


class Dialog extends Control:
	var lines: Array = []
	var done: Callable
	var i := 0
	var lbl_who: Label
	var lbl_txt: Label
	var shown := 0.0

	func _ready() -> void:
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 1.0
		offset_left = 0
		offset_top = 0
		offset_right = 0
		offset_bottom = 0
		layout_direction = Control.LAYOUT_DIRECTION_RTL
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.45)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.08, 0.95)
		sb.border_color = Color(1, 0.75, 0.3)
		sb.border_width_top = 3
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 18
		sb.content_margin_bottom = 18
		p.add_theme_stylebox_override("panel", sb)
		p.anchor_left = 0.12
		p.anchor_right = 0.88
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.offset_top = -230
		p.offset_bottom = -40
		add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		p.add_child(v)
		lbl_who = Label.new()
		lbl_who.add_theme_font_size_override("font_size", 26)
		lbl_who.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
		v.add_child(lbl_who)
		lbl_txt = Label.new()
		lbl_txt.add_theme_font_size_override("font_size", 24)
		lbl_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(lbl_txt)
		var hint := Label.new()
		hint.text = "اضغط Enter أو كليك ◀"
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(hint)
		_show()

	func _show() -> void:
		if i >= lines.size():
			queue_free()
			if done.is_valid():
				done.call()
			return
		var ln: Array = lines[i]
		lbl_who.text = str(ln[0])
		lbl_who.visible = str(ln[0]) != ""
		lbl_txt.text = str(ln[1])
		lbl_txt.visible_ratio = 0.0
		shown = 0.0

	func _process(delta: float) -> void:
		if lbl_txt and lbl_txt.visible_ratio < 1.0:
			shown += delta
			lbl_txt.visible_ratio = clampf(shown * 40.0 / maxf(lbl_txt.text.length(), 1.0), 0.0, 1.0)

	func _next() -> void:
		if lbl_txt.visible_ratio < 1.0:
			lbl_txt.visible_ratio = 1.0
			shown = 999.0
			return
		i += 1
		_show()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_next()
			accept_event()

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			_next()
			get_viewport().set_input_as_handled()
		elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_A:
			_next()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- شاشة النهاية
func show_summary(data: Dictionary, sp: Dictionary) -> void:
	var outro: Array = data.get("outro", [])
	if data.get("ok", false) and not outro.is_empty():
		show_dialog(outro, func(): _summary_panel(data, sp))
	else:
		_summary_panel(data, sp)


func _btn(t: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_stylebox_override("normal", _style(col, 10))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15), 10))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.2), 10))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _summary_panel(data: Dictionary, sp: Dictionary) -> void:
	summary = Control.new()
	summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary.layout_direction = Control.LAYOUT_DIRECTION_RTL
	root.add_child(summary)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.1, 0.97), 18))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(620, 0)
	summary.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	var ok: bool = data.get("ok", false)
	var t := _label(data.get("title", ""), 30, Color(1, 0.86, 0.5) if ok else Color(1, 0.55, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := _label(data.get("stats", ""), 15, Color(0.7, 0.75, 0.82))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	v.add_child(HSeparator.new())
	for ln in data.get("lines", []):
		var h := HBoxContainer.new()
		v.add_child(h)
		var a := _label(str(ln[0]), 18, Color(0.88, 0.9, 0.95))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		var val := int(ln[1])
		if val != 0:
			h.add_child(_label(("+" if val > 0 else "") + str(val), 18, Color(0.55, 1, 0.65) if val > 0 else Color(1, 0.55, 0.45)))
	if data.has("total") and ok:
		v.add_child(HSeparator.new())
		var tot := _label("المجموع: %d فلوس" % int(data["total"]), 26, Color(1, 0.82, 0.25))
		tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tot)
	if data.has("rep"):
		v.add_child(_label(data["rep"], 17, Color(0.6, 0.9, 1.0)))
	if data.has("unlocked"):
		v.add_child(_label(data["unlocked"], 18, Color(0.5, 1, 0.6)))
	v.add_child(HSeparator.new())
	var kind: String = sp.get("kind", "contract")
	match kind:
		"contract":
			if ok:
				var offers: Array = data.get("offers", [])
				if not offers.is_empty():
					v.add_child(_label("عقود متتالية من %s (مكافأة إضافية):" % Jobs.city_name(Jobs.truck()["city"]), 17, Color(0.85, 0.85, 0.9)))
				for o in offers:
					var oc: Dictionary = o
					var locked := Jobs.rep() < int(oc["rep_req"]) or (int(oc["trailers"]) >= 2 and not bool(Jobs.truck()["dolly"]))
					var txt := "%s • %s • %d فلوس" % [Jobs.contract_title(oc), Jobs.CARGO[oc["cargo"]]["name"], int(oc["pay"])]
					var b := _btn(("(مقفل) " if locked else "") + txt, Color(0.2, 0.45, 0.3) if not locked else Color(0.2, 0.2, 0.22), func():
						if not locked:
							Game.goto("drive", oc))
					b.disabled = locked
					v.add_child(b)
			else:
				v.add_child(_btn("إعادة نفس العقد", Color(0.6, 0.4, 0.1), func(): Game.goto("drive", sp)))
			v.add_child(_btn("كراج الشاحنات ولوحة الطلبات", Color(0.25, 0.35, 0.55), func():
				Jobs.truck()["chain_bonus"] = 0
				Game.goto("truck")))
		"story":
			var sc: String = sp.get("story_car", "")
			var ch := int(sp.get("chapter", 0))
			var story: Dictionary = Story.story_for(sc)
			if ok and ch + 1 < story["chapters"].size():
				v.add_child(_btn("الفصل التالي: %s ◀" % story["chapters"][ch + 1]["title"], Color(0.75, 0.45, 0.1), func(): Game.goto("story_play", {"car": sc, "chapter": ch + 1})))
			if not ok:
				v.add_child(_btn("إعادة الفصل", Color(0.75, 0.45, 0.1), func(): Game.goto("drive", sp)))
			v.add_child(_btn("رجوع للقصص", Color(0.25, 0.35, 0.55), func(): Game.goto("story")))
		"lesson":
			var lid: String = sp.get("lesson", "")
			var li := School.lesson_index(lid)
			if ok and li + 1 < School.LESSONS.size():
				v.add_child(_btn("الدرس التالي: %s ◀" % School.LESSONS[li + 1]["title"], Color(0.2, 0.55, 0.3), func(): Game.goto("drive", School.spec_for(School.LESSONS[li + 1]["id"]))))
			elif ok:
				v.add_child(_btn("الامتحان النهائي ◀", Color(0.75, 0.45, 0.1), func(): Game.goto("drive", School.EXAM)))
			v.add_child(_btn("إعادة الدرس", Color(0.6, 0.4, 0.1), func(): Game.goto("drive", sp)))
			v.add_child(_btn("رجوع لمدرسة السياقة", Color(0.25, 0.35, 0.55), func(): Game.goto("school")))
		"exam":
			if data.get("exam", false):
				v.add_child(_btn("استلم إجازة السوق ◀", Color(0.2, 0.55, 0.3), func(): Game.goto("school", {"license": true})))
			else:
				v.add_child(_btn("إعادة الامتحان", Color(0.75, 0.45, 0.1), func(): Game.goto("drive", sp)))
				v.add_child(_btn("رجوع لمدرسة السياقة", Color(0.25, 0.35, 0.55), func(): Game.goto("school")))
		_:
			v.add_child(_btn("رجوع", Color(0.25, 0.35, 0.55), func(): Game.goto("truck")))
	v.add_child(_btn("القائمة الرئيسية", Color(0.2, 0.22, 0.26), func(): Game.goto("menu")))
