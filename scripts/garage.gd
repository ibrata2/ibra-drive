extends Node3D
## الكراج: اختيار السيارات، شراؤها، تطويرها، صبغها

var preview_id := ""
var turntable: Node3D
var car_holder: Node3D
var cam: Camera3D
var ui: Control
var res_box: HBoxContainer
var lvl_label: Label
var xp_bar: ProgressBar
var cars_list: VBoxContainer
var up_list: VBoxContainer
var paint_grid: GridContainer
var name_label: Label
var desc_label: Label
var stats_box: VBoxContainer
var action_btn: Button
var tabs: TabContainer
var popup: Control


func _ready() -> void:
	preview_id = Game.data["car"]
	_build_room()
	_build_ui()
	_refresh()
	if not Game.last_result.is_empty():
		_show_result(Game.last_result)
		Game.last_result = {}


func _process(delta: float) -> void:
	if turntable:
		turntable.rotation.y += delta * 0.35


# ---------------------------------------------------------------- الغرفة
func _mat(c: Color, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _build_room() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.ssao_enabled = true
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	we.environment = env
	add_child(we)
	var floor_m := _mat(Color(0.22, 0.23, 0.25), 0.3, 0.35)
	_box(Vector3(40, 0.2, 40), Vector3(0, -0.1, 0), floor_m)
	var wall_m := _mat(Color(0.16, 0.17, 0.2), 0.2, 0.6)
	_box(Vector3(40, 12, 0.4), Vector3(0, 6, -9), wall_m)
	_box(Vector3(0.4, 12, 40), Vector3(-12, 6, 0), wall_m)
	_box(Vector3(0.4, 12, 40), Vector3(14, 6, 0), wall_m)
	var stripe := _mat(Color(0.95, 0.65, 0.15))
	stripe.emission_enabled = true
	stripe.emission = Color(0.95, 0.6, 0.15)
	stripe.emission_energy_multiplier = 0.8
	_box(Vector3(40, 0.15, 0.1), Vector3(0, 3.2, -8.78), stripe)
	_box(Vector3(0.1, 0.15, 40), Vector3(-11.78, 3.2, 0), stripe)
	var lamp_m := _mat(Color(1, 1, 1))
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(1, 0.97, 0.9)
	lamp_m.emission_energy_multiplier = 3.0
	for x in [-6.0, 0.0, 6.0]:
		_box(Vector3(0.3, 0.08, 6), Vector3(x, 8.5, 0), lamp_m)
	# شعار على الحايط
	var sign := Label3D.new()
	sign.text = "IBRA GARAGE"
	sign.font = Game.arabic_font
	sign.font_size = 160
	sign.pixel_size = 0.01
	sign.modulate = Color(1, 0.75, 0.3)
	sign.outline_size = 0
	sign.position = Vector3(-1.5, 4.6, -8.75)
	add_child(sign)
	# رفوف وأدوات
	var shelf_m := _mat(Color(0.35, 0.3, 0.25))
	for i in 3:
		_box(Vector3(0.6, 0.08, 4), Vector3(-11.4, 1.0 + i * 1.1, -4), shelf_m)
	for i in 6:
		var t := _box(Vector3(0.4, 0.5, 0.5), Vector3(-11.3, 1.3 + (i % 3) * 1.1, -5.5 + (i / 3) * 1.4), _mat(Color(0.8, 0.15 + i * 0.1, 0.1), 0.5, 0.4))
		t.rotation.y = i * 0.3
	var tire_m := _mat(Color(0.05, 0.05, 0.05), 0.0, 0.9)
	for i in 4:
		var tm := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.3
		tor.outer_radius = 0.6
		tm.mesh = tor
		tm.material_override = tire_m
		tm.position = Vector3(-9.5, 0.15 + i * 0.32, -7.5)
		add_child(tm)
	# المنصة الدوارة
	turntable = Node3D.new()
	turntable.position = Vector3(-1.5, 0, 0)
	add_child(turntable)
	var plat := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0
	cm.bottom_radius = 4.1
	cm.height = 0.2
	cm.radial_segments = 48
	plat.mesh = cm
	plat.material_override = _mat(Color(0.12, 0.12, 0.14), 0.8, 0.25)
	plat.position.y = 0.1
	turntable.add_child(plat)
	var ring_m := _mat(Color(1, 0.7, 0.2))
	ring_m.emission_enabled = true
	ring_m.emission = Color(1, 0.65, 0.2)
	ring_m.emission_energy_multiplier = 2.0
	var rim := MeshInstance3D.new()
	var tor2 := TorusMesh.new()
	tor2.inner_radius = 4.0
	tor2.outer_radius = 4.12
	tor2.rings = 64
	rim.mesh = tor2
	rim.material_override = ring_m
	rim.position.y = 0.2
	rim.scale = Vector3(1, 0.3, 1)
	turntable.add_child(rim)
	car_holder = Node3D.new()
	car_holder.position.y = 0.2
	turntable.add_child(car_holder)
	# أضواء
	var key := SpotLight3D.new()
	key.position = Vector3(3, 9, 6)
	key.spot_range = 25
	key.spot_angle = 35
	key.light_energy = 18
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(-1.5, 0.5, 0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 4, 5)
	fill.omni_range = 18
	fill.light_energy = 1.5
	fill.light_color = Color(0.6, 0.75, 1.0)
	add_child(fill)
	var rimlight := OmniLight3D.new()
	rimlight.position = Vector3(-1.5, 3, -6)
	rimlight.omni_range = 12
	rimlight.light_energy = 3.0
	rimlight.light_color = Color(1, 0.7, 0.4)
	add_child(rimlight)
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.position = Vector3(5.0, 3.6, 11.0)
	cam.look_at(Vector3(-2.6, 1.6, 0))
	cam.make_current()


func _show_car(id: String) -> void:
	for c in car_holder.get_children():
		c.queue_free()
	var m := CarModel.build(Game.get_car(id)["body"], Game.car_paint(id))
	car_holder.add_child(m["root"])


# ---------------------------------------------------------------- الواجهة
func _style(c: Color, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
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
	return l


func _button(t: String, col: Color, s := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", s)
	b.add_theme_stylebox_override("normal", _style(col, 10))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.15), 10))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.2), 10))
	b.add_theme_stylebox_override("disabled", _style(Color(0.2, 0.2, 0.22), 10))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.layout_direction = Control.LAYOUT_DIRECTION_RTL
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# الشريط العلوي
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.07, 0.8), 0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 18)
	top.add_child(th)
	th.add_child(_label("IBRA DRIVE", 28, Color(1, 0.75, 0.3)))
	th.add_child(_label("الكراج", 22, Color(0.8, 0.82, 0.88)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)
	res_box = HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 16)
	th.add_child(res_box)
	var lv := VBoxContainer.new()
	th.add_child(lv)
	lvl_label = _label("", 18, Color(0.6, 1.0, 0.7))
	lv.add_child(lvl_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(160, 8)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 4))
	xp_bar.add_theme_stylebox_override("fill", _style(Color(0.3, 0.9, 0.5), 4))
	lv.add_child(xp_bar)
	# اللوحة اليمين
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.08, 0.86), 16))
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_left = -560
	side.offset_right = -20
	side.offset_top = 80
	side.offset_bottom = -20
	ui.add_child(side)
	tabs = TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 18)
	side.add_child(tabs)
	cars_list = _scroll_tab("السيارات")
	up_list = _scroll_tab("التطوير")
	var pt := _scroll_tab("الصبغ")
	paint_grid = GridContainer.new()
	paint_grid.columns = 4
	paint_grid.add_theme_constant_override("h_separation", 10)
	paint_grid.add_theme_constant_override("v_separation", 10)
	pt.add_child(paint_grid)
	# معلومات السيارة (يسار تحت)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.08, 0.8), 16))
	info.anchor_left = 0.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 20
	info.offset_right = 520
	info.offset_bottom = -20
	info.offset_top = -370
	info.layout_direction = Control.LAYOUT_DIRECTION_RTL
	ui.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	name_label = _label("", 30, Color(1, 0.86, 0.5))
	iv.add_child(name_label)
	desc_label = _label("", 15, Color(0.75, 0.78, 0.84))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(desc_label)
	stats_box = VBoxContainer.new()
	iv.add_child(stats_box)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	iv.add_child(bh)
	action_btn = _button("", Color(0.2, 0.55, 0.3), 20)
	action_btn.custom_minimum_size = Vector2(200, 50)
	action_btn.pressed.connect(_on_action)
	bh.add_child(action_btn)
	var go := _button("انطلق للخريطة  ◀", Color(0.9, 0.5, 0.1), 22)
	go.custom_minimum_size = Vector2(240, 50)
	go.pressed.connect(func(): Game.goto("map"))
	bh.add_child(go)


func _scroll_tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v


func _refresh() -> void:
	_show_car(preview_id)
	# الموارد
	for c in res_box.get_children():
		c.queue_free()
	for k in Game.RES_ORDER:
		res_box.add_child(_label("%s %d" % [Game.RES_NAMES[k], int(Game.data[k])], 19, Game.RES_COLORS[k]))
	var lvl := Game.level()
	lvl_label.text = "المستوى %d" % lvl
	var a := Game.xp_for_level(lvl)
	var b := Game.xp_for_level(lvl + 1)
	xp_bar.max_value = b - a
	xp_bar.value = int(Game.data["xp"]) - a
	_refresh_cars()
	_refresh_info()
	_refresh_upgrades()
	_refresh_paint()


func _refresh_cars() -> void:
	for c in cars_list.get_children():
		c.queue_free()
	for car in Game.CARS:
		var id: String = car["id"]
		var owned := Game.owns(id)
		var col := Color(0.12, 0.13, 0.16)
		if id == preview_id:
			col = Color(0.3, 0.22, 0.08)
		var b := _button("", col)
		b.custom_minimum_size = Vector2(0, 66)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var status := ""
		if id == Game.data["car"]:
			status = "✓ مختارة"
		elif owned:
			status = "مملوكة"
		else:
			status = Game.cost_text(car["price"])
		b.text = "%s\n%s" % [car["name"], status]
		b.pressed.connect(func():
			preview_id = id
			_refresh())
		cars_list.add_child(b)


func _stat_row(label: String, v: float, maxv: float, col: Color) -> void:
	var h := HBoxContainer.new()
	var l := _label(label, 15, Color(0.8, 0.82, 0.86))
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = maxv
	bar.value = v
	bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5), 6))
	var fill := _style(col, 6)
	bar.add_theme_stylebox_override("fill", fill)
	h.add_child(bar)
	stats_box.add_child(h)


func _refresh_info() -> void:
	var car := Game.get_car(preview_id)
	var s := Game.car_stats(preview_id)
	name_label.text = car["name"]
	desc_label.text = car["desc"]
	for c in stats_box.get_children():
		c.queue_free()
	_stat_row("السرعة", s["top_speed"], 60.0, Color(1, 0.5, 0.2))
	_stat_row("التسارع", s["accel"], 2.1, Color(1, 0.8, 0.2))
	_stat_row("التماسك", s["grip"], 1.2, Color(0.3, 0.8, 1))
	_stat_row("الطرق الوعرة", s["offroad"], 1.6, Color(0.6, 0.9, 0.3))
	_stat_row("الوقود", s["fuel"], 450.0, Color(1, 0.4, 0.3))
	_stat_row("النيترو", s["nitro"], 8.0, Color(0.3, 0.6, 1))
	if preview_id == Game.data["car"]:
		action_btn.text = "✓ هاي سيارتك"
		action_btn.disabled = true
	elif Game.owns(preview_id):
		action_btn.text = "اختارها"
		action_btn.disabled = false
	else:
		action_btn.text = "اشتريها"
		action_btn.disabled = not Game.can_afford(car["price"])


func _on_action() -> void:
	if Game.owns(preview_id):
		Game.select_car(preview_id)
	elif Game.buy_car(preview_id):
		_toast_popup("مبروك! اشتريت %s" % Game.get_car(preview_id)["name"])
	_refresh()


func _refresh_upgrades() -> void:
	for c in up_list.get_children():
		c.queue_free()
	if not Game.owns(preview_id):
		up_list.add_child(_label("اشتري السيارة أول حتى تقدر تطورها", 18, Color(0.9, 0.6, 0.4)))
		return
	up_list.add_child(_label("تطوير: " + Game.get_car(preview_id)["name"], 20, Color(1, 0.86, 0.5)))
	for u in Game.UPGRADES:
		var uid: String = u["id"]
		var lvl := Game.upgrade_level(preview_id, uid)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _style(Color(0.1, 0.11, 0.14), 10))
		up_list.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(_label(u["name"], 20, Color.WHITE))
		var pips := ""
		for i in Game.MAX_LEVEL:
			pips += "■" if i < lvl else "□"
		h.add_child(_label("  " + pips, 18, Color(1, 0.75, 0.3)))
		v.add_child(_label(u["desc"], 14, Color(0.7, 0.72, 0.78)))
		var h2 := HBoxContainer.new()
		v.add_child(h2)
		if lvl >= Game.MAX_LEVEL:
			h2.add_child(_label("وصل للحد الأعلى", 15, Color(0.5, 1, 0.6)))
		else:
			var cost := Game.upgrade_cost(preview_id, uid, lvl + 1)
			var ok := Game.can_afford(cost)
			var cl := _label(Game.cost_text(cost), 14, Color(0.85, 0.85, 0.9) if ok else Color(1, 0.45, 0.4))
			cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h2.add_child(cl)
			var b := _button("طوّر", Color(0.2, 0.5, 0.85))
			b.disabled = not ok
			b.custom_minimum_size = Vector2(90, 38)
			b.pressed.connect(func():
				if Game.buy_upgrade(preview_id, uid):
					_refresh())
			h2.add_child(b)


func _refresh_paint() -> void:
	for c in paint_grid.get_children():
		c.queue_free()
	if not Game.owns(preview_id):
		paint_grid.add_child(_label("اشتري السيارة أول", 16, Color(0.9, 0.6, 0.4)))
		return
	for col in Game.PAINTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 70)
		var sb := _style(col, 10)
		sb.border_color = Color(1, 1, 1, 0.8) if Game.car_paint(preview_id).is_equal_approx(col) else Color(0, 0, 0, 0)
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", _style(col.lightened(0.2), 10))
		b.add_theme_stylebox_override("pressed", sb)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			Game.set_paint(preview_id, col)
			_refresh())
		paint_grid.add_child(b)


func _toast_popup(text: String) -> void:
	var l := _label(text, 26, Color(0.6, 1, 0.7))
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position = Vector2(-300, 100)
	l.custom_minimum_size = Vector2(600, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _show_result(r: Dictionary) -> void:
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.06, 0.07, 0.1, 0.96), 18))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(520, 0)
	popup.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var title := "رجعت للكراج بسلامة!" if r["how"] == "garage" else "سيارة السحب رجعتك (خسرت 40%)"
	var t := _label(title, 28, Color(1, 0.86, 0.5) if r["how"] == "garage" else Color(1, 0.6, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_label("المكان: " + Places.get_place(int(r["place"]))["name"], 17, Color(0.8, 0.82, 0.86)))
	v.add_child(_label("جمعت %d غرض  •  +%d خبرة" % [int(r["items"]), int(r["xp"])], 17, Color(0.8, 0.82, 0.86)))
	for k in Game.RES_ORDER:
		var n := int(r["got"].get(k, 0))
		if n > 0:
			v.add_child(_label("+%d %s" % [n, Game.RES_NAMES[k]], 22, Game.RES_COLORS[k]))
	if r["treasure"]:
		v.add_child(_label("★ لكيت كنز هذا المكان!", 22, Color(1, 0.8, 0.3)))
	if r["level_up"]:
		v.add_child(_label("▲ وصلت المستوى %d — انفتحت أماكن جديدة!" % int(r["new_level"]), 22, Color(0.5, 1, 0.6)))
	var ok := _button("تمام", Color(0.2, 0.55, 0.3), 20)
	ok.custom_minimum_size = Vector2(0, 46)
	ok.pressed.connect(func(): popup.queue_free())
	v.add_child(ok)
