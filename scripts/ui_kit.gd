class_name UIKit
extends RefCounted
## أدوات الواجهة المشتركة (نفس ستايل الكراج)

const GOLD := Color(1, 0.78, 0.32)
const BG := Color(0.05, 0.06, 0.08)
const CARD := Color(0.1, 0.11, 0.14)


static func style(c: Color, r := 12, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	sb.content_margin_left = pad + 2
	sb.content_margin_right = pad + 2
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func label(t: String, s: int, c := Color.WHITE, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(t: String, col: Color, s := 18, h := 46.0) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", s)
	b.add_theme_stylebox_override("normal", style(col, 10, 8))
	b.add_theme_stylebox_override("hover", style(col.lightened(0.15), 10, 8))
	b.add_theme_stylebox_override("pressed", style(col.darkened(0.2), 10, 8))
	b.add_theme_stylebox_override("disabled", style(Color(0.18, 0.18, 0.2), 10, 8))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func panel(col := Color(0.05, 0.06, 0.08, 0.88), r := 16, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(col, r, pad))
	return p


static func bar(col: Color, w := 200.0, h := 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.add_theme_stylebox_override("background", style(Color(0, 0, 0, 0.5), 5, 0))
	b.add_theme_stylebox_override("fill", style(col, 5, 0))
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll_list(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v


## خلفية ثلاثية الأبعاد بسيطة: أرضية، إضاءة، وموديل يدور
static func showroom(parent: Node3D, dark := true) -> Dictionary:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.07) if dark else Color(0.5, 0.6, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.05, 0.055, 0.07)
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.6, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	parent.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-6, 6, 6)
	fill.omni_range = 30.0
	fill.light_energy = 1.2
	fill.light_color = Color(1, 0.8, 0.55)
	parent.add_child(fill)
	var fl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 30.0
	cm.bottom_radius = 30.0
	cm.height = 0.2
	cm.radial_segments = 64
	fl.mesh = cm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.13, 0.15)
	fm.metallic = 0.5
	fm.roughness = 0.3
	fl.material_override = fm
	fl.position.y = -0.1
	parent.add_child(fl)
	var turn := Node3D.new()
	parent.add_child(turn)
	var cam := Camera3D.new()
	parent.add_child(cam)
	return {"turn": turn, "cam": cam, "env": env}
