extends CanvasLayer
## أزرار اللمس للموبايل (أندرويد وآيفون): توجيه، بنزين، فرامل، هاند بريك، نيترو، وأزرار سريعة

var buttons: Array = []   # [TouchScreenButton, anchor(Vector2 0..1), offset(Vector2), radius]
var tex_cache := {}


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	# يسار: التوجيه
	_add("steer_left", "◀", Vector2(0, 1), Vector2(130, -150), 95, Color(0.2, 0.25, 0.35))
	_add("steer_right", "▶", Vector2(0, 1), Vector2(345, -150), 95, Color(0.2, 0.25, 0.35))
	# يمين: البنزين والفرامل
	_add("accelerate", "بنزين", Vector2(1, 1), Vector2(-140, -165), 105, Color(0.15, 0.5, 0.25))
	_add("brake", "فرامل\nريوس", Vector2(1, 1), Vector2(-370, -130), 85, Color(0.6, 0.18, 0.15))
	_add("handbrake", "هاند", Vector2(1, 1), Vector2(-340, -330), 62, Color(0.55, 0.4, 0.1))
	_add("nitro", "نيترو", Vector2(1, 1), Vector2(-140, -385), 62, Color(0.15, 0.4, 0.65))
	# فوك: أزرار سريعة
	var small := [["pause", "إيقاف"], ["camera", "كاميرا"], ["headlights", "ضوء"], ["interact", "E"], ["reset_car", "R"], ["horn", "زمّور"], ["tow", "مساعدة"]]
	for i in small.size():
		_add(small[i][0], small[i][1], Vector2(0, 0), Vector2(70 + i * 112, 250), 46, Color(0.12, 0.13, 0.17))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _circle(r: int, col: Color) -> ImageTexture:
	var key := "%d_%s" % [r, col.to_html()]
	if tex_cache.has(key):
		return tex_cache[key]
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r + 0.5, y - r + 0.5).length()
			var a := clampf(r - d, 0.0, 1.0)
			var edge := 1.0 if d > r - 4.0 else 0.0
			var c := col.lerp(Color(1, 1, 1), edge * 0.5)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a * (0.62 + edge * 0.3)))
	var t := ImageTexture.create_from_image(img)
	tex_cache[key] = t
	return t


func _add(action: String, text: String, anchor: Vector2, off: Vector2, r: int, col: Color) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle(r, col)
	b.texture_pressed = _circle(r, col.lightened(0.35))
	var sh := CircleShape2D.new()
	sh.radius = r
	b.shape = sh
	b.shape_centered = true
	b.action = action
	b.passby_press = action.begins_with("steer") or action in ["accelerate", "brake"]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30 if r > 80 else 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(r * 2, r * 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	add_child(b)
	buttons.append([b, anchor, off, r])


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	for e in buttons:
		var b: TouchScreenButton = e[0]
		var anchor: Vector2 = e[1]
		var off: Vector2 = e[2]
		var r: int = e[3]
		b.position = Vector2(anchor.x * vs.x, anchor.y * vs.y) + off - Vector2(r, r)
