extends Node3D
## وضع القصة: تختار سيارة، تشوف قصتها وفصولها. play_arg = {car, chapter} يشغّل الحوار وبعدين المهمة

const MH := preload("res://scripts/mission_hud.gd")

var play_arg: Variant = null
var ui: Control
var turn: Node3D
var cam: Camera3D
var holder: Node3D
var chapters_box: VBoxContainer
var title_lbl: Label
var tag_lbl: Label
var sel := ""
var t := 0.0


func _ready() -> void:
	var sr := UIKit.showroom(self)
	turn = sr["turn"]
	cam = sr["cam"]
	holder = Node3D.new()
	turn.add_child(holder)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.layout_direction = Control.LAYOUT_DIRECTION_RTL
	layer.add_child(ui)
	if play_arg is Dictionary:
		_play_intro(play_arg)
		return
	_build()
	var first := ""
	for s in Story.STORIES:
		var p := Story.progress(s["car"])
		if p > 0 and p < s["chapters"].size():
			first = s["car"]
			break
	_select(first if first != "" else Story.STORIES[0]["car"])


func _process(delta: float) -> void:
	t += delta
	turn.rotation.y += delta * 0.25
	cam.position = Vector3(-9.0, 4.2, 15.0)
	cam.look_at(Vector3(-4.0, 1.2, 2.0))


func _show_model(car_id: String) -> void:
	for c in holder.get_children():
		c.queue_free()
	var m := CarModel.build(Game.get_car(car_id)["body"], Game.car_paint(car_id), Game.car_deco(car_id))
	holder.add_child(m["root"])
	holder.position = Vector3(-4.0, 0, 2.0)
	if car_id.begins_with("semi"):
		var tr := TruckTrailer.new()
		holder.add_child(tr)
		tr.setup("box", Color(0.8, 0.2, 0.1), Jobs.trailer_color(), false, false, {})
		tr.position = Vector3(0, 0, (m["hitch"] as Vector3).z + tr.L)
		tr.body.queue_free()
		tr.area.queue_free()


func _build() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.add_theme_constant_override("separation", 16)
	ui.add_child(top)
	top.add_child(UIKit.label("وضع القصة", 36, UIKit.GOLD))
	top.add_child(UIKit.label("كل سيارة إلها قصة مختلفة", 18, Color(0.75, 0.78, 0.85)))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.label("فلوس %d" % int(Game.data["coins"]), 20, Color(1, 0.82, 0.3)))
	var back := UIKit.button("رجوع للقائمة", Color(0.22, 0.24, 0.28), 17, 44)
	back.custom_minimum_size.x = 170
	back.pressed.connect(func(): Game.goto("menu"))
	top.add_child(back)
	# القصص (يمين)
	var lp := UIKit.panel()
	lp.anchor_left = 1.0
	lp.anchor_right = 1.0
	lp.anchor_bottom = 1.0
	lp.offset_left = -470
	lp.offset_right = -20
	lp.offset_top = 80
	lp.offset_bottom = -20
	ui.add_child(lp)
	var list := UIKit.scroll_list(lp)
	for s in Story.STORIES:
		var car_id: String = s["car"]
		var n: int = s["chapters"].size()
		var p := Story.progress(car_id)
		var b := UIKit.button("", (s["color"] as Color).darkened(0.62), 17, 86)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var status := "✓ خلصت" if p >= n else ("%d/%d" % [p, n])
		b.text = "%s  —  %s\n%s • البطل: %s • %s" % [s["title"], status, Game.get_car(car_id)["name"], s["hero"], "جديدة" if p == 0 else "كمّل"]
		b.pressed.connect(func(): _select(car_id))
		list.add_child(b)
	# الفصول (يسار)
	var rp := UIKit.panel()
	rp.anchor_top = 1.0
	rp.anchor_bottom = 1.0
	rp.offset_left = 20
	rp.offset_right = 600
	rp.offset_top = -470
	rp.offset_bottom = -20
	ui.add_child(rp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	rp.add_child(v)
	title_lbl = UIKit.label("", 30, UIKit.GOLD)
	v.add_child(title_lbl)
	tag_lbl = UIKit.label("", 16, Color(0.8, 0.82, 0.88), true)
	v.add_child(tag_lbl)
	chapters_box = UIKit.scroll_list(v)


func _select(car_id: String) -> void:
	sel = car_id
	_show_model(car_id)
	var s := Story.story_for(car_id)
	title_lbl.text = "%s — %s" % [s["title"], Game.get_car(car_id)["name"]]
	tag_lbl.text = s["tagline"]
	for c in chapters_box.get_children():
		c.queue_free()
	var p := Story.progress(car_id)
	var nch: int = s["chapters"].size()
	for i in nch:
		var ch: Dictionary = s["chapters"][i]
		var m: Dictionary = ch["mission"]
		var where := ""
		if m.has("from"):
			where = "%s ← %s" % [Jobs.city_name(m["to"]), Jobs.city_name(m["from"])]
		else:
			where = {"desert": "البادية", "mountain": "جبال كردستان", "marsh": "الأهوار", "dirt": "طريق ترابي", "rural": "طريق ريفي"}.get(m.get("style", ""), "")
		var goal_t: String = {"deliver": "توصيل", "race": "سباق", "rescue": "إنقاذ"}.get(m.get("goal", "deliver"), "")
		var locked := i > p
		var col := Color(0.12, 0.3, 0.18) if i < p else (Color(0.55, 0.32, 0.08) if i == p else Color(0.15, 0.15, 0.17))
		var mark := "✓ " if i < p else ("▶ " if i == p else "(مقفل) ")
		var b := UIKit.button("%sالفصل %d: %s\n%s • %s • مكافأة %d" % [mark, i + 1, ch["title"], goal_t, where, int(ch["reward"])], col, 17, 66)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.disabled = locked
		var idx := i
		b.pressed.connect(func(): Game.goto("story_play", {"car": car_id, "chapter": idx}))
		chapters_box.add_child(b)


func _play_intro(arg: Dictionary) -> void:
	var car_id: String = arg["car"]
	var idx := int(arg["chapter"])
	_show_model(car_id)
	var s := Story.story_for(car_id)
	var ch: Dictionary = s["chapters"][idx]
	var cover := VBoxContainer.new()
	cover.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cover.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cover.position.y = 70
	ui.add_child(cover)
	var a := UIKit.label(s["title"], 24, Color(0.8, 0.82, 0.88))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(a)
	var b := UIKit.label("الفصل %d: %s" % [idx + 1, ch["title"]], 48, UIKit.GOLD)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(b)
	var skip := UIKit.button("تخطّي ◀", Color(0.2, 0.22, 0.26), 16, 40)
	skip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skip.position = Vector2(24, 20)
	skip.custom_minimum_size.x = 130
	var go := func(): Game.goto("drive", Story.mission_for(car_id, idx))
	skip.pressed.connect(go)
	ui.add_child(skip)
	var dl = MH.Dialog.new()
	dl.lines = ch.get("intro", [])
	dl.done = go
	ui.add_child(dl)
