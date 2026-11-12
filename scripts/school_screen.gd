extends Control
## مدرسة IBRA لتعليم السياقة: الدروس، الامتحان النهائي، وإجازة السوق

var arg: Variant = null
var lessons_box: VBoxContainer
var card_box: VBoxContainer


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.065, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var main := VBoxContainer.new()
	main.anchor_right = 1.0
	main.anchor_bottom = 1.0
	main.offset_left = 28
	main.offset_right = -28
	main.offset_top = 18
	main.offset_bottom = -18
	main.add_theme_constant_override("separation", 14)
	add_child(main)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	main.add_child(top)
	top.add_child(UIKit.label("مدرسة IBRA لتعليم السياقة", 34, Color(0.45, 0.85, 0.6)))
	top.add_child(UIKit.label("مو شرط — بس اللي ما يعرف يسوق يتعلم هنا، وبالأخير ياخذ إجازة", 17, Color(0.7, 0.74, 0.8)))
	top.add_child(UIKit.spacer())
	var back := UIKit.button("رجوع للقائمة", Color(0.22, 0.24, 0.28), 16, 42)
	back.custom_minimum_size.x = 170
	back.pressed.connect(func(): Game.goto("menu"))
	top.add_child(back)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 20)
	main.add_child(h)
	var lp := UIKit.panel(Color(0.08, 0.09, 0.12, 0.95))
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.3
	h.add_child(lp)
	lessons_box = UIKit.scroll_list(lp)
	var rp := UIKit.panel(Color(0.08, 0.09, 0.12, 0.95))
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rp)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 12)
	rp.add_child(card_box)
	_fill()
	if arg is Dictionary and arg.get("license", false):
		_celebrate()


func _fill() -> void:
	for c in lessons_box.get_children():
		c.queue_free()
	var groups := [["سيارة صغيرة (خصوصي)", "خصوصي"], ["شاحنات ومقطورات (حمل ثقيل)", "حمل ثقيل"], ["دفع رباعي", "دفع رباعي"]]
	var n := 0
	for g in groups:
		lessons_box.add_child(UIKit.label(g[0], 22, UIKit.GOLD))
		for l in School.LESSONS:
			if l["class"] != g[1]:
				continue
			n += 1
			var id: String = l["id"]
			var ok := School.done(id)
			var p := UIKit.panel(Color(0.12, 0.2, 0.15, 0.95) if ok else Color(0.12, 0.13, 0.16, 0.95), 12, 10)
			lessons_box.add_child(p)
			var hh := HBoxContainer.new()
			hh.add_theme_constant_override("separation", 12)
			p.add_child(hh)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hh.add_child(v)
			v.add_child(UIKit.label(("✓ " if ok else "") + "الدرس %d: %s" % [n, l["title"]], 20, Color(0.6, 1, 0.7) if ok else Color(0.95, 0.95, 1.0)))
			v.add_child(UIKit.label(l["desc"], 15, Color(0.72, 0.76, 0.84), true))
			v.add_child(UIKit.label("السيارة: %s%s" % [Game.get_car(l["car"])["name"], " + مقطورتين" if int(l["trailers"]) >= 2 else (" + مقطورة" if int(l["trailers"]) == 1 else "")], 14, Color(0.6, 0.66, 0.75)))
			var b := UIKit.button("إعادة" if ok else "ابدأ ◀", Color(0.2, 0.5, 0.3) if not ok else Color(0.25, 0.3, 0.35), 17, 46)
			b.custom_minimum_size.x = 120
			b.pressed.connect(func(): Game.goto("drive", School.spec_for(id)))
			hh.add_child(b)
	lessons_box.add_child(UIKit.label("الامتحان النهائي", 22, UIKit.GOLD))
	var ex := UIKit.button("امتحان إجازة السوق: طريق ريفي من الحلة لكربلاء ◀", Color(0.75, 0.45, 0.1), 19, 56)
	ex.pressed.connect(func(): Game.goto("drive", School.EXAM))
	lessons_box.add_child(ex)
	lessons_box.add_child(UIKit.label("الفاحص يحسب: السرعة (٦٠ بالمدن، ٩٠ برا)، الوقوف بالسيطرة، والصدمات. أكثر من غلطتين = ما تنجح.", 15, Color(0.72, 0.76, 0.84), true))
	_fill_card()


func _fill_card() -> void:
	for c in card_box.get_children():
		c.queue_free()
	card_box.add_child(UIKit.label("إجازة السوق", 26, UIKit.GOLD))
	if School.has_license():
		card_box.add_child(_license_card())
	else:
		card_box.add_child(UIKit.label("ما عندك إجازة بعد. خلّص الدروس اللي تحتاجها وادخل الامتحان النهائي.", 17, Color(0.75, 0.78, 0.85), true))
	card_box.add_child(UIKit.label("اسمك على الإجازة:", 16, Color(0.7, 0.74, 0.8)))
	var hh := HBoxContainer.new()
	card_box.add_child(hh)
	var le := LineEdit.new()
	le.text = Game.data.get("player_name", "")
	le.placeholder_text = "اكتب اسمك"
	le.add_theme_font_size_override("font_size", 19)
	le.custom_minimum_size = Vector2(0, 44)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(le)
	var sv := UIKit.button("حفظ", Color(0.2, 0.45, 0.7), 16, 44)
	sv.custom_minimum_size.x = 90
	sv.pressed.connect(func():
		Game.data["player_name"] = le.text.strip_edges()
		if School.has_license():
			Game.data["license"]["name"] = le.text.strip_edges()
			Game.data["license"]["classes"] = School.classes()
		Game.save_game()
		_fill_card())
	hh.add_child(sv)
	var done := 0
	for l in School.LESSONS:
		if School.done(l["id"]):
			done += 1
	card_box.add_child(UIKit.label("الدروس المكتملة: %d من %d (كل درس أول مرة +١٥٠ فلوس)" % [done, School.LESSONS.size()], 16, Color(0.6, 0.9, 1.0), true))


func _license_card() -> Control:
	var lic: Dictionary = Game.data["license"]
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.9, 0.84)
	sb.border_color = Color(0.15, 0.45, 0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 260)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", UIKit.style(Color(0.15, 0.45, 0.3), 8, 6))
	v.add_child(hdr)
	var ht := UIKit.label("إجازة سوق — مدرسة IBRA لتعليم السياقة", 19, Color(1, 1, 1))
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(ht)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var photo := PanelContainer.new()
	photo.add_theme_stylebox_override("panel", UIKit.style(Color(0.6, 0.65, 0.62), 8, 4))
	photo.custom_minimum_size = Vector2(110, 130)
	var ph := UIKit.label("IBRA", 30, Color(0.3, 0.33, 0.32))
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	photo.add_child(ph)
	h.add_child(photo)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var dark := Color(0.1, 0.15, 0.12)
	info.add_child(UIKit.label("الاسم: %s" % lic.get("name", ""), 22, dark))
	info.add_child(UIKit.label("الرقم: %s" % lic.get("no", ""), 17, dark))
	info.add_child(UIKit.label("تاريخ الإصدار: %s" % lic.get("date", ""), 17, dark))
	var cl: Array = lic.get("classes", [])
	info.add_child(UIKit.label("الصنف: %s" % "، ".join(PackedStringArray(cl)), 18, Color(0.15, 0.4, 0.25)))
	var sig := UIKit.label("توقيع: الأستاذ أبو سيف", 15, Color(0.25, 0.3, 0.28))
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(sig)
	return p


func _celebrate() -> void:
	var l := UIKit.label("مبروك! استلمت إجازة السوق (+٥٠٠ فلوس)", 34, Color(0.6, 1, 0.7))
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position = Vector2(-450, 90)
	l.custom_minimum_size = Vector2(900, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
