extends Node3D
## كراج الشاحنات: لوحة الطلبات، خريطة العراق، رؤوس التريلات والتطوير، المقطورات، التزيين

var ui: Control
var turn: Node3D
var cam: Camera3D
var holder: Node3D
var tabs: TabContainer
var top_info: Label
var board_list: VBoxContainer
var cab_list: VBoxContainer
var trailer_list: VBoxContainer
var deco_list: VBoxContainer
var map_ctl: IraqMap
var map_info: VBoxContainer
var toast_l: Label
var preview_double := false


class IraqMap extends Control:
	const OUTLINE := [[38.8, 33.4], [39.3, 32.25], [40.4, 31.95], [42.0, 31.1], [44.7, 29.2], [46.55, 29.1], [47.45, 29.6], [47.7, 30.1],
		[48.0, 29.98], [48.55, 29.95], [48.3, 30.4], [47.7, 31.0], [47.85, 31.8], [47.4, 32.4], [46.1, 33.0], [45.6, 33.9], [45.4, 34.5],
		[45.8, 35.0], [46.15, 35.25], [45.8, 35.8], [45.35, 36.4], [44.8, 37.1], [43.4, 37.3], [42.4, 37.1], [41.8, 36.6], [41.3, 36.1],
		[41.2, 34.8], [41.0, 34.4], [38.8, 33.4]]
	var selected := ""
	var hub

	func _to(lon: float, lat: float) -> Vector2:
		var s := minf(size.x / 10.6, size.y / 8.8)
		var off := (size - Vector2(10.6, 8.8) * s) * 0.5
		return off + Vector2((lon - 38.4) * s, (37.6 - lat) * s)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.12, 1.0))
		var poly := PackedVector2Array()
		for p in OUTLINE:
			poly.append(_to(p[0], p[1]))
		draw_colored_polygon(poly, Color(0.62, 0.53, 0.38))
		# الأنهار (تقريبية)
		var tigris := [[42.7, 37.1], [43.13, 36.34], [43.3, 35.5], [43.68, 34.6], [44.0, 33.9], [44.36, 33.31], [45.0, 32.9], [45.82, 32.51], [46.6, 32.0], [47.15, 31.84], [47.4, 31.0], [47.78, 30.51], [48.3, 30.1]]
		var euph := [[41.0, 34.4], [42.0, 34.1], [43.3, 33.42], [43.8, 33.0], [44.3, 32.6], [44.4, 32.0], [45.28, 31.31], [46.26, 31.04], [47.0, 30.95], [47.4, 31.0]]
		for rv in [tigris, euph]:
			var pts := PackedVector2Array()
			for p in rv:
				pts.append(_to(p[0], p[1]))
			draw_polyline(pts, Color(0.3, 0.55, 0.8, 0.85), 3.0, true)
		draw_polyline(poly, Color(0.95, 0.85, 0.6, 0.9), 2.0, true)
		var cur: String = Jobs.truck()["city"]
		var path_set := {}
		if selected != "" and selected != cur:
			var pth: Dictionary = Jobs.path(cur, selected)
			var cs: Array = pth["cities"]
			for i in range(1, cs.size()):
				path_set[cs[i - 1] + cs[i]] = true
				path_set[cs[i] + cs[i - 1]] = true
		for r in Jobs.ROADS:
			var a: Dictionary = Jobs.CITIES[r[0]]
			var b: Dictionary = Jobs.CITIES[r[1]]
			var on := path_set.has(str(r[0]) + str(r[1]))
			draw_line(_to(a["lon"], a["lat"]), _to(b["lon"], b["lat"]), Color(1, 0.75, 0.2) if on else Color(0.2, 0.2, 0.22, 0.85), 5.0 if on else 2.5, true)
		var font := ThemeDB.fallback_font
		if Game.arabic_font:
			font = Game.arabic_font
		for id in Jobs.CITIES:
			var c: Dictionary = Jobs.CITIES[id]
			var p2 := _to(c["lon"], c["lat"])
			var unlocked := Jobs.city_unlocked(id)
			var col := Color(1, 1, 1) if unlocked else Color(0.35, 0.35, 0.38)
			if id == cur:
				col = Color(1, 0.75, 0.2)
				draw_circle(p2, 13.0, Color(1, 0.75, 0.2, 0.35))
			if id == selected:
				draw_arc(p2, 12.0, 0, TAU, 24, Color(0.3, 1, 0.5), 3.0)
			draw_circle(p2, 7.0, Color(0, 0, 0, 0.7))
			draw_circle(p2, 5.5, col)
			var txt: String = c["name"]
			draw_string(font, p2 + Vector2(-60, -12), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 1, 1) if unlocked else Color(0.6, 0.6, 0.62))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var best := ""
			var bd := 24.0
			for id in Jobs.CITIES:
				var c: Dictionary = Jobs.CITIES[id]
				var d := _to(c["lon"], c["lat"]).distance_to(e.position)
				if d < bd:
					bd = d
					best = id
			if best != "":
				selected = best
				queue_redraw()
				if hub:
					hub._map_selected(best)


func _ready() -> void:
	Jobs.ensure()
	var sr := UIKit.showroom(self)
	turn = sr["turn"]
	cam = sr["cam"]
	holder = Node3D.new()
	turn.add_child(holder)
	_build_ui()
	_refresh_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tab="):
			tabs.current_tab = int(a.get_slice("=", 1))


func _process(delta: float) -> void:
	turn.rotation.y += delta * 0.18
	cam.position = Vector3(-14.0, 5.5, 20.0)
	cam.look_at(Vector3(-7.0, 1.4, 4.0))


func _show_rig() -> void:
	for c in holder.get_children():
		c.queue_free()
	holder.position = Vector3(-7.0, 0, 0.0)
	var cab: String = Jobs.truck()["cab"]
	var m := CarModel.build(Game.get_car(cab)["body"], Game.car_paint(cab), Game.car_deco(cab))
	holder.add_child(m["root"])
	var double := preview_double and bool(Jobs.truck()["dolly"])
	var opts := {"label": "نقليات الرافدين"}
	for d in Game.car_deco(cab):
		if str(d).begins_with("slogan:"):
			opts["slogan"] = CarModel.SLOGANS[clampi(int(str(d).get_slice(":", 1)), 0, CarModel.SLOGANS.size() - 1)]
	var tr := TruckTrailer.new()
	holder.add_child(tr)
	tr.setup("box", Color(0.8, 0.2, 0.1), Jobs.trailer_color(), false, double, opts)
	tr.position = Vector3(0, 0, (m["hitch"] as Vector3).z + tr.L)
	tr.body.queue_free()
	tr.area.queue_free()
	if double:
		var t2 := TruckTrailer.new()
		holder.add_child(t2)
		t2.setup("box", Color(0.8, 0.2, 0.1), Jobs.trailer_color(), true, true, opts)
		t2.position = Vector3(0, 0, tr.position.z + tr.rear_hitch.z + t2.L)
		t2.body.queue_free()
		t2.area.queue_free()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.layout_direction = Control.LAYOUT_DIRECTION_RTL
	layer.add_child(ui)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UIKit.style(Color(0.04, 0.05, 0.07, 0.85), 0, 10))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 16)
	top.add_child(th)
	th.add_child(UIKit.label("نقليات IBRA", 28, UIKit.GOLD))
	top_info = UIKit.label("", 18, Color(0.85, 0.88, 0.95))
	th.add_child(top_info)
	th.add_child(UIKit.spacer())
	var back := UIKit.button("القائمة الرئيسية", Color(0.22, 0.24, 0.28), 16, 40)
	back.custom_minimum_size.x = 170
	back.pressed.connect(func(): Game.goto("menu"))
	th.add_child(back)
	var side := UIKit.panel(Color(0.05, 0.06, 0.08, 0.9), 16, 10)
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -760
	side.offset_right = -16
	side.offset_top = 70
	side.offset_bottom = -16
	ui.add_child(side)
	tabs = TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 18)
	side.add_child(tabs)
	board_list = _tab("لوحة الطلبات")
	var mp := VBoxContainer.new()
	mp.name = "خريطة العراق"
	tabs.add_child(mp)
	map_ctl = IraqMap.new()
	map_ctl.hub = self
	map_ctl.custom_minimum_size = Vector2(0, 520)
	map_ctl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_ctl.layout_direction = Control.LAYOUT_DIRECTION_LTR
	mp.add_child(map_ctl)
	map_info = VBoxContainer.new()
	mp.add_child(map_info)
	cab_list = _tab("الشاحنة")
	trailer_list = _tab("المقطورات")
	deco_list = _tab("التزيين")
	toast_l = UIKit.label("", 24, Color(0.6, 1, 0.7))
	toast_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_l.position = Vector2(-300, 80)
	toast_l.custom_minimum_size = Vector2(600, 0)
	toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(toast_l)


func _tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v


func _toast(t: String, col := Color(0.6, 1, 0.7)) -> void:
	toast_l.text = t
	toast_l.add_theme_color_override("font_color", col)
	toast_l.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(toast_l, "modulate:a", 0.0, 0.6)


func _refresh_all() -> void:
	var t := Jobs.truck()
	top_info.text = "فلوس %d  •  السمعة %d — %s  •  موقعك: %s  •  توصيلات %d  •  %s كم" % [int(Game.data["coins"]), Jobs.rep(), Jobs.rep_title(), Jobs.city_name(t["city"]), int(t["deliveries"]), Jobs.ar_num(int(t["km"]))]
	_show_rig()
	_fill_board()
	_fill_cabs()
	_fill_trailers()
	_fill_deco()
	map_ctl.queue_redraw()
	if map_ctl.selected == "":
		_map_selected(t["city"])


# ---------------------------------------------------------------- لوحة الطلبات
func _fill_board() -> void:
	for c in board_list.get_children():
		c.queue_free()
	var t := Jobs.truck()
	var hdr := HBoxContainer.new()
	board_list.add_child(hdr)
	hdr.add_child(UIKit.label("عقود من %s" % Jobs.city_name(t["city"]), 22, UIKit.GOLD))
	hdr.add_child(UIKit.spacer())
	var rb := UIKit.button("تحديث اللوحة", Color(0.22, 0.3, 0.4), 15, 38)
	rb.custom_minimum_size.x = 140
	rb.pressed.connect(func():
		Jobs.refresh_board(true)
		_fill_board())
	hdr.add_child(rb)
	for c in Jobs.refresh_board():
		var cc: Dictionary = c
		var cg: Dictionary = Jobs.CARGO[cc["cargo"]]
		var need_rep := Jobs.rep() < int(cc["rep_req"])
		var need_dolly := int(cc["trailers"]) >= 2 and not bool(t["dolly"])
		var p := UIKit.panel(Color(0.1, 0.11, 0.14, 0.95), 12, 10)
		board_list.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		var h1 := HBoxContainer.new()
		v.add_child(h1)
		h1.add_child(UIKit.label(Jobs.contract_title(cc), 21, Color(1, 0.9, 0.7)))
		h1.add_child(UIKit.spacer())
		h1.add_child(UIKit.label("%d فلوس" % int(cc["pay"]), 21, Color(1, 0.82, 0.25)))
		v.add_child(UIKit.label("%s • %s طن • مقطورة %s%s • %s كم" % [cg["name"], str(snappedf(float(cg["tons"]) * (1.6 if int(cc["trailers"]) >= 2 else 1.0), 0.1)), Jobs.TRAILER_NAMES.get(cg["trailer"], ""), " ×٢" if int(cc["trailers"]) >= 2 else "", Jobs.ar_num(int(cc["km"]))], 16, Color(0.8, 0.83, 0.9)))
		var tags := Jobs.contract_tags(cc)
		if not tags.is_empty():
			v.add_child(UIKit.label("  •  ".join(tags), 15, Color(0.6, 0.85, 1.0)))
		var h2 := HBoxContainer.new()
		v.add_child(h2)
		var why := ""
		if need_rep:
			why = "تحتاج سمعة %d" % int(cc["rep_req"])
		elif need_dolly:
			why = "تحتاج دولي ومقطورة ثانية (من تبويب المقطورات)"
		h2.add_child(UIKit.label(why, 15, Color(1, 0.55, 0.45)))
		h2.add_child(UIKit.spacer())
		var go := UIKit.button("قبول العقد ◀", Color(0.2, 0.55, 0.3), 17, 42)
		go.custom_minimum_size.x = 170
		go.disabled = need_rep or need_dolly
		go.pressed.connect(func():
			var spec := cc.duplicate(true)
			spec["car"] = Jobs.truck()["cab"]
			spec["seed"] = randi() % 100000
			Game.goto("drive", spec))
		h2.add_child(go)


# ---------------------------------------------------------------- الخريطة
func _map_selected(id: String) -> void:
	for c in map_info.get_children():
		c.queue_free()
	var t := Jobs.truck()
	var c: Dictionary = Jobs.CITIES[id]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	map_info.add_child(h)
	h.add_child(UIKit.label("%s — محافظة %s • %s" % [c["name"], c["gov"], Jobs.REGION_NAMES[c["region"]]], 19, UIKit.GOLD))
	h.add_child(UIKit.spacer())
	if id == t["city"]:
		h.add_child(UIKit.label("انت هنا", 18, Color(0.6, 1, 0.7)))
		return
	if not Jobs.city_unlocked(id):
		h.add_child(UIKit.label("تنفتح بسمعة %d" % int(c["rep"]), 17, Color(1, 0.55, 0.45)))
		return
	var p: Dictionary = Jobs.path(t["city"], id)
	var names: PackedStringArray = []
	for cid in p["cities"]:
		names.append(Jobs.city_name(cid))
	map_info.add_child(UIKit.label("الطريق: %s  (%s كم)" % [" ← ".join(names), Jobs.ar_num(int(p["total"]))], 15, Color(0.8, 0.83, 0.9), true))
	var free := UIKit.button("سفرة حرة لـ %s (بلا حمولة، تنقل شاحنتك)" % c["name"], Color(0.18, 0.42, 0.7), 17, 44)
	free.pressed.connect(func():
		Game.goto("drive", {"kind": "free", "goal": "deliver", "from": t["city"], "to": id, "car": t["cab"], "trailers": 0,
			"hour": float(randi_range(6, 18)), "weather": "", "seed": randi() % 100000, "km": int(p["total"])}))
	map_info.add_child(free)


# ---------------------------------------------------------------- الشاحنة
func _fill_cabs() -> void:
	for c in cab_list.get_children():
		c.queue_free()
	var t := Jobs.truck()
	cab_list.add_child(UIKit.label("رؤوس التريلات", 22, UIKit.GOLD))
	for id in Jobs.CABS:
		var car: Dictionary = Game.get_car(id)
		var owned := Game.owns(id)
		var p := UIKit.panel(Color(0.1, 0.11, 0.14, 0.95) if id != t["cab"] else Color(0.28, 0.2, 0.08, 0.95), 12, 10)
		cab_list.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(UIKit.label(car["name"], 21, Color(1, 0.9, 0.7)))
		h.add_child(UIKit.spacer())
		var st := Game.car_stats(id)
		h.add_child(UIKit.label("سرعة %d • سحب %s • خزان %d" % [int(st["top_speed"] * 3.6), str(snappedf(st["accel"], 0.01)), int(st["fuel"])], 15, Color(0.75, 0.8, 0.88)))
		v.add_child(UIKit.label(car["desc"], 15, Color(0.75, 0.78, 0.84), true))
		var b: Button
		if id == t["cab"]:
			b = UIKit.button("✓ شاحنتك الحالية", Color(0.25, 0.25, 0.28), 16, 40)
			b.disabled = true
		elif owned:
			b = UIKit.button("اختارها", Color(0.2, 0.45, 0.7), 16, 40)
			b.pressed.connect(func():
				t["cab"] = id
				Game.save_game()
				_refresh_all())
		else:
			b = UIKit.button("اشتري: " + Game.cost_text(car["price"]), Color(0.2, 0.55, 0.3), 16, 40)
			b.disabled = not Game.can_afford(car["price"])
			b.pressed.connect(func():
				Game.pay(car["price"])
				Game.data["owned"].append(id)
				t["cab"] = id
				Game.save_game()
				_toast("مبروك! اشتريت %s" % car["name"])
				_refresh_all())
		v.add_child(b)
	cab_list.add_child(UIKit.label("تطوير %s" % Game.get_car(t["cab"])["name"], 22, UIKit.GOLD))
	for u in Jobs.TRUCK_UPGRADES:
		var uid: String = u["id"]
		var lvl := Game.upgrade_level(t["cab"], uid)
		var h2 := HBoxContainer.new()
		cab_list.add_child(h2)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(vv)
		vv.add_child(UIKit.label("%s  %s" % [u["name"], "●".repeat(lvl) + "○".repeat(Game.MAX_LEVEL - lvl)], 18, Color(0.9, 0.92, 0.96)))
		vv.add_child(UIKit.label(u["desc"], 14, Color(0.65, 0.7, 0.78)))
		if lvl < Game.MAX_LEVEL:
			var cost := Game.upgrade_cost(t["cab"], uid, lvl + 1)
			var b2 := UIKit.button(Game.cost_text(cost), Color(0.2, 0.45, 0.3), 15, 40)
			b2.custom_minimum_size.x = 230
			b2.disabled = not Game.can_afford(cost)
			b2.pressed.connect(func():
				if Game.buy_upgrade(t["cab"], uid):
					_toast("تطور %s!" % u["name"])
					_refresh_all())
			h2.add_child(b2)
		else:
			h2.add_child(UIKit.label("أعلى مستوى", 15, Color(0.6, 1, 0.7)))


# ---------------------------------------------------------------- المقطورات
func _fill_trailers() -> void:
	for c in trailer_list.get_children():
		c.queue_free()
	var t := Jobs.truck()
	trailer_list.add_child(UIKit.label("مقطورة وحدة أو ثنتين", 22, UIKit.GOLD))
	if bool(t["dolly"]):
		trailer_list.add_child(UIKit.label("✓ عندك دولي ومقطورة ثانية — العقود الكبيرة صارت متاحة (أجرة ×١.٨٥)", 16, Color(0.6, 1, 0.7), true))
		var pv := UIKit.button("عرض: %s" % ("مقطورتين" if not preview_double else "مقطورة وحدة"), Color(0.22, 0.3, 0.4), 15, 40)
		pv.pressed.connect(func():
			preview_double = not preview_double
			_show_rig()
			_fill_trailers())
		trailer_list.add_child(pv)
	else:
		trailer_list.add_child(UIKit.label("بمقطورتين تكدر تاخذ عقود حنطة وتانكرات مضاعفة بأجرة أكبر. بس السياقة أصعب: الريوس شبه مستحيل والمنعطفات أوسع.", 15, Color(0.75, 0.78, 0.84), true))
		var b := UIKit.button("اشتري دولي ومقطورة ثانية: %d فلوس" % Jobs.DOLLY_PRICE, Color(0.2, 0.55, 0.3), 17, 46)
		b.disabled = int(Game.data["coins"]) < Jobs.DOLLY_PRICE
		b.pressed.connect(func():
			Game.data["coins"] = int(Game.data["coins"]) - Jobs.DOLLY_PRICE
			t["dolly"] = true
			preview_double = true
			Jobs.refresh_board(true)
			Game.save_game()
			_toast("صار عندك مقطورتين!")
			_refresh_all())
		trailer_list.add_child(b)
	trailer_list.add_child(UIKit.label("تطوير المقطورة", 22, UIKit.GOLD))
	for u in Jobs.TRAILER_UPGRADES:
		var uid: String = u["id"]
		var lvl := Jobs.trailer_level(uid)
		var mx := int(u["max"])
		var h := HBoxContainer.new()
		trailer_list.add_child(h)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vv)
		vv.add_child(UIKit.label("%s  %s" % [u["name"], "●".repeat(lvl) + "○".repeat(mx - lvl)], 18, Color(0.9, 0.92, 0.96)))
		vv.add_child(UIKit.label(u["desc"], 14, Color(0.65, 0.7, 0.78)))
		if lvl < mx:
			var cost := Jobs.trailer_up_cost(uid, lvl + 1)
			var b2 := UIKit.button("%d فلوس" % cost, Color(0.2, 0.45, 0.3), 15, 40)
			b2.custom_minimum_size.x = 150
			b2.disabled = int(Game.data["coins"]) < cost
			b2.pressed.connect(func():
				if Jobs.buy_trailer_up(uid):
					_toast("تطورت المقطورة!")
					_refresh_all())
			h.add_child(b2)
		else:
			h.add_child(UIKit.label("أعلى مستوى", 15, Color(0.6, 1, 0.7)))
	trailer_list.add_child(UIKit.label("لون المقطورة", 22, UIKit.GOLD))
	trailer_list.add_child(_color_grid(func(col: Color):
		t["trailer_paint"] = col.to_html(false)
		Game.save_game()
		_refresh_all()))


func _color_grid(cb: Callable) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	var cols: Array = Game.PAINTS.duplicate()
	cols.append_array([Color(0.95, 0.95, 0.95), Color(0.55, 0.08, 0.1), Color(0.05, 0.25, 0.15), Color(0.85, 0.85, 0.2), Color(0.6, 0.35, 0.15), Color(0.95, 0.4, 0.6)])
	for c in cols:
		var col: Color = c
		var b := Button.new()
		b.custom_minimum_size = Vector2(80, 44)
		b.add_theme_stylebox_override("normal", UIKit.style(col, 8, 0))
		b.add_theme_stylebox_override("hover", UIKit.style(col.lightened(0.2), 8, 0))
		b.add_theme_stylebox_override("pressed", UIKit.style(col.darkened(0.2), 8, 0))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): cb.call(col))
		g.add_child(b)
	return g


# ---------------------------------------------------------------- التزيين
func _fill_deco() -> void:
	for c in deco_list.get_children():
		c.queue_free()
	var t := Jobs.truck()
	var cab: String = t["cab"]
	if not (t.get("deco_owned") is Array):
		t["deco_owned"] = []
	var owned: Array = t["deco_owned"]
	var active: Array = Game.car_deco(cab).duplicate()
	deco_list.add_child(UIKit.label("صبغ الكابينة", 22, UIKit.GOLD))
	deco_list.add_child(_color_grid(func(col: Color):
		Game.set_paint(cab, col)
		_refresh_all()))
	deco_list.add_child(UIKit.label("إكسسوارات (تشتريها مرة وتشغلها وتطفيها براحتك)", 22, UIKit.GOLD))
	for d in Jobs.DECOS:
		var id: String = d["id"]
		var h := HBoxContainer.new()
		deco_list.add_child(h)
		var on := active.has(id)
		h.add_child(UIKit.label(("✓ " if on else "") + d["name"], 18, Color(0.9, 0.92, 0.96) if not on else Color(0.6, 1, 0.7)))
		h.add_child(UIKit.spacer())
		var b: Button
		if owned.has(id):
			b = UIKit.button("شيلها" if on else "ركّبها", Color(0.3, 0.3, 0.34) if on else Color(0.2, 0.45, 0.7), 15, 38)
			b.pressed.connect(func():
				if on:
					active.erase(id)
				else:
					active.append(id)
				Game.set_deco(cab, active)
				_refresh_all())
		else:
			b = UIKit.button("اشتري %d" % int(d["price"]), Color(0.2, 0.55, 0.3), 15, 38)
			b.disabled = int(Game.data["coins"]) < int(d["price"])
			b.pressed.connect(func():
				Game.data["coins"] = int(Game.data["coins"]) - int(d["price"])
				owned.append(id)
				active.append(id)
				Game.set_deco(cab, active)
				_toast("تركّبت: %s" % d["name"])
				_refresh_all())
		b.custom_minimum_size.x = 140
		h.add_child(b)
	deco_list.add_child(UIKit.label("عبارة على الشاحنة والمقطورة (%d فلوس)" % Jobs.SLOGAN_PRICE, 22, UIKit.GOLD))
	var cur_sl := -1
	for a in active:
		if str(a).begins_with("slogan:"):
			cur_sl = int(str(a).get_slice(":", 1))
	for i in CarModel.SLOGANS.size():
		var idx := i
		var b2 := UIKit.button(("✓ " if idx == cur_sl else "") + "«%s»" % CarModel.SLOGANS[i], Color(0.12, 0.13, 0.16) if idx != cur_sl else Color(0.3, 0.22, 0.08), 16, 40)
		b2.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b2.pressed.connect(func():
			var new_active: Array = []
			for a in active:
				if not str(a).begins_with("slogan:"):
					new_active.append(a)
			if idx != cur_sl:
				if not owned.has("slogan"):
					if int(Game.data["coins"]) < Jobs.SLOGAN_PRICE:
						_toast("ما عندك فلوس كافية", Color(1, 0.55, 0.45))
						return
					Game.data["coins"] = int(Game.data["coins"]) - Jobs.SLOGAN_PRICE
					owned.append("slogan")
				new_active.append("slogan:%d" % idx)
			Game.set_deco(cab, new_active)
			_refresh_all())
		deco_list.add_child(b2)
