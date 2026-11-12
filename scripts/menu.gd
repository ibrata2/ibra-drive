extends Node3D
## القائمة الرئيسية: وضع القصة • أركيد (الاستكشاف الحر + توصيل بين المحافظات) • مدرسة السياقة

var ui: Control
var turn: Node3D
var cam: Camera3D
var t := 0.0
var arcade_box: VBoxContainer
var popup: Control


func _ready() -> void:
	var sr := UIKit.showroom(self)
	turn = sr["turn"]
	cam = sr["cam"]
	var cab: String = Jobs.truck()["cab"]
	var m := CarModel.build(Game.get_car(cab)["body"], Game.car_paint(cab), Game.car_deco(cab))
	turn.add_child(m["root"])
	var tr := TruckTrailer.new()
	turn.add_child(tr)
	tr.setup("box", Color(0.8, 0.2, 0.1), Jobs.trailer_color(), false, false, {"label": "نقليات الرافدين"})
	tr.position = Vector3(0, 0, (m["hitch"] as Vector3).z + tr.L)
	tr.body.queue_free()
	tr.area.queue_free()
	var side := CarModel.build("jeep", Game.car_paint("jeep"))
	(side["root"] as Node3D).position = Vector3(5.5, 0, 6.0)
	(side["root"] as Node3D).rotation.y = 0.5
	turn.add_child(side["root"])
	var side2 := CarModel.build("sedan", Game.car_paint("sedan"))
	(side2["root"] as Node3D).position = Vector3(-5.5, 0, 9.0)
	(side2["root"] as Node3D).rotation.y = -0.4
	turn.add_child(side2["root"])
	_build_ui()
	if not bool(Game.data.get("asked_skill", false)):
		_ask_skill()


func _process(delta: float) -> void:
	t += delta
	var a := t * 0.12 + 0.6
	cam.position = Vector3(sin(a) * 19.0, 5.5 + sin(t * 0.2) * 0.8, cos(a) * 19.0 + 5.0)
	var tgt := Vector3(0, 1.4, 5.0)
	var right := (tgt - cam.position).cross(Vector3.UP).normalized()
	cam.look_at(tgt - right * 7.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.layout_direction = Control.LAYOUT_DIRECTION_RTL
	layer.add_child(ui)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.02, 0.025, 0.035, 0.95))
	gr.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	gt.gradient = gr
	gt.fill_from = Vector2(1, 0)
	gt.fill_to = Vector2(0.35, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(grad)
	var v := VBoxContainer.new()
	v.anchor_left = 1.0
	v.anchor_right = 1.0
	v.anchor_top = 0.0
	v.anchor_bottom = 1.0
	v.offset_left = -560
	v.offset_right = -60
	v.offset_top = 60
	v.offset_bottom = -40
	v.add_theme_constant_override("separation", 14)
	ui.add_child(v)
	var logo := UIKit.label("IBRA DRIVE", 72, UIKit.GOLD)
	logo.layout_direction = Control.LAYOUT_DIRECTION_LTR
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(logo)
	v.add_child(UIKit.label("مغامرات بالسيارات على طرق العراق", 22, Color(0.85, 0.87, 0.92)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	var b_story := UIKit.button("وضع القصة", Color(0.82, 0.42, 0.08), 26, 70)
	b_story.pressed.connect(func(): Game.goto("story"))
	v.add_child(b_story)
	v.add_child(UIKit.label("لكل سيارة قصة: سائق التريلة، دليل البادية، فلاح البساتين، ورالي الرافدين...", 15, Color(0.65, 0.68, 0.75), true))
	var b_arc := UIKit.button("أركيد", Color(0.18, 0.42, 0.7), 26, 70)
	v.add_child(b_arc)
	arcade_box = VBoxContainer.new()
	arcade_box.add_theme_constant_override("separation", 8)
	arcade_box.visible = false
	v.add_child(arcade_box)
	var a1 := UIKit.button("توصيل حمولات بين المحافظات  (شاحنات ومقطورات)", Color(0.14, 0.3, 0.5), 19, 52)
	a1.pressed.connect(func(): Game.goto("truck"))
	arcade_box.add_child(a1)
	var a2 := UIKit.button("الاستكشاف الحر  (١٢٠ مكان، كنوز وتطوير)", Color(0.14, 0.3, 0.5), 19, 52)
	a2.pressed.connect(func(): Game.goto("garage"))
	arcade_box.add_child(a2)
	b_arc.pressed.connect(func(): arcade_box.visible = not arcade_box.visible)
	var school_txt := "مدرسة السياقة"
	if School.has_license():
		school_txt += "  ✓ عندك إجازة"
	var b_school := UIKit.button(school_txt, Color(0.15, 0.48, 0.3), 24, 62)
	b_school.pressed.connect(func(): Game.goto("school"))
	v.add_child(b_school)
	var b_quit := UIKit.button("خروج", Color(0.2, 0.21, 0.25), 20, 50)
	b_quit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_quit)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var info := UIKit.label("فلوس %d  •  السمعة %d (%s)  •  مستوى الاستكشاف %d" % [int(Game.data["coins"]), Jobs.rep(), Jobs.rep_title(), Game.level()], 17, Color(1, 0.82, 0.35))
	v.add_child(info)
	var ver := UIKit.label("v2.0.0  •  برمجة وتطوير إبراهيم الخزرجي\nتليكرام: t.me/ibraprogram  •  تيك توك: ibraprogram", 15, Color(0.62, 0.65, 0.72))
	v.add_child(ver)


func _ask_skill() -> void:
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var p := UIKit.panel(Color(0.06, 0.07, 0.1, 0.97), 18, 24)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(620, 0)
	popup.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UIKit.label("هلا بيك بـ IBRA DRIVE!", 32, UIKit.GOLD))
	v.add_child(UIKit.label("قبل لا نبدي: تعرف تسوق؟\nإذا لا، عدنا مدرسة سياقة تعلمك كل شي خطوة خطوة، وبالأخير تاخذ إجازة سوق. وإذا تعرف، تكدر تبدي مباشرة.", 19, Color(0.85, 0.87, 0.92), true))
	v.add_child(UIKit.label("اسمك (يطلع على إجازة السوق):", 16, Color(0.7, 0.74, 0.8)))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "مثلاً: إبراهيم"
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.text = Game.data.get("player_name", "")
	v.add_child(name_edit)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var yes := UIKit.button("إي أعرف أسوق", Color(0.18, 0.42, 0.7), 20, 54)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var no := UIKit.button("لا، علمني (مدرسة السياقة)", Color(0.15, 0.48, 0.3), 20, 54)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(yes)
	h.add_child(no)
	var save := func():
		Game.data["asked_skill"] = true
		Game.data["player_name"] = name_edit.text.strip_edges()
		Game.save_game()
	yes.pressed.connect(func():
		save.call()
		popup.queue_free())
	no.pressed.connect(func():
		save.call()
		Game.goto("school"))
