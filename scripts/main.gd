extends Node
## يبدّل بين الكراج والخريطة والعالم

const GarageScene := preload("res://scripts/garage.gd")
const MapScene := preload("res://scripts/map_screen.gd")
const WorldScene := preload("res://scripts/world.gd")

var current: Node = null
var loading: CanvasLayer


func _ready() -> void:
	var th := Theme.new()
	th.default_font = Game.arabic_font
	th.default_font_size = 18
	get_tree().root.theme = th
	Game.scene_requested.connect(_on_scene_requested)
	var args := OS.get_cmdline_user_args()
	_debug_args(args)
	for a in args:
		if a.begins_with("--place="):
			Game.start_trip(int(a.get_slice("=", 1)))
			return
		if a == "--test-result":
			Game.data["xp"] = 50
			Game.current_place = 2
			Game.run = {"coins": 120, "scrap": 30, "parts": 5, "crystals": 1, "xp": 80, "items": 9, "treasure": true}
			Game.end_trip(1.0, "garage")
			return
		if a == "--carshow":
			_carshow()
			return
		if a == "--map":
			_on_scene_requested("map", null)
			return
	_on_scene_requested("garage", null)


## أدوات فحص للمطوّر: --shot=file.png --shot-time=6 --drive --steer=0.3 --hour=12 --weather=rain --cam=1
func _debug_args(args: PackedStringArray) -> void:
	var shot := ""
	var t := 6.0
	for a in args:
		if a.begins_with("--shot="):
			shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-time="):
			t = float(a.get_slice("=", 1))
		elif a == "--drive":
			Input.action_press("accelerate", 1.0)
		elif a.begins_with("--steer="):
			var s := float(a.get_slice("=", 1))
			Input.action_press("steer_right" if s > 0 else "steer_left", absf(s))
	if shot != "":
		await get_tree().create_timer(t).timeout
		for a in args:
			if current and current.has_method("h_at"):
				if a.begins_with("--hour="):
					current.hour = float(a.get_slice("=", 1))
				elif a.begins_with("--weather="):
					current.weather = a.get_slice("=", 1)
					current.wcur = Places.WEATHER[current.weather].duplicate()
				elif a.begins_with("--cam="):
					current.cam.mode = int(a.get_slice("=", 1))
		await get_tree().create_timer(1.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot)
		print("SHOT SAVED ", shot)
		get_tree().quit()


func _on_scene_requested(scene_name: String, arg: Variant) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
		current = null
	match scene_name:
		"garage":
			current = GarageScene.new()
			add_child(current)
		"map":
			current = CanvasLayer.new()
			current.add_child(MapScene.new())
			add_child(current)
		"world":
			_show_loading(int(arg))
			await get_tree().process_frame
			await get_tree().process_frame
			var w = WorldScene.new()
			w.place_idx = int(arg)
			current = w
			add_child(w)
			_hide_loading()


func _show_loading(idx: int) -> void:
	var p: Dictionary = Places.get_place(idx)
	var b: Dictionary = Places.get_biome(p["biome"])
	loading = CanvasLayer.new()
	loading.layer = 50
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading.add_child(v)
	var t := Label.new()
	t.text = p["name"]
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", b["card"].lightened(0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "%s • %s • %s\nجاري تجهيز المكان..." % [b["name"], Places.SEASONS[p["season"]], Places.WEATHER[p["weather"]]["name"]]
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	v.add_child(s)
	add_child(loading)


func _hide_loading() -> void:
	if loading:
		var tw := create_tween()
		tw.tween_property(loading.get_child(0), "modulate:a", 0.0, 0.6)
		tw.parallel().tween_property(loading.get_child(1), "modulate:a", 0.0, 0.4)
		tw.tween_callback(loading.queue_free)
		loading = null


func _carshow() -> void:
	var n := Node3D.new()
	add_child(n)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	n.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.7, 0)
	sun.shadow_enabled = true
	n.add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.85, 0.72, 0.5)
	fl.material_override = fm
	n.add_child(fl)
	var i := 0
	var only := OS.get_cmdline_user_args().has("--close")
	var single := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			single = a.get_slice("=", 1)
	if single != "":
		for k in 3:
			var mm := CarModel.build(Game.get_car(single)["body"], Game.get_car(single)["paint"])
			var rr: Node3D = mm["root"]
			rr.position = Vector3(-6.0 + k * 5.5, 0, 0)
			rr.rotation.y = [0.7, 2.6, -1.57][k]
			if k == 2:
				(mm["paint_mat"] as ShaderMaterial).set_shader_parameter("dust", 0.6)
			n.add_child(rr)
		var cam2 := Camera3D.new()
		n.add_child(cam2)
		cam2.position = Vector3(-0.5, 4.2, 8.0)
		cam2.look_at(Vector3(-0.5, 0.6, 0))
		cam2.fov = 50
		cam2.make_current()
		return
	for c in Game.CARS:
		if only and i > 2:
			break
		var m := CarModel.build(c["body"], c["paint"])
		var root: Node3D = m["root"]
		root.position = Vector3(-15.0 + (i % 4) * 9.0, 0, -4.0 + int(i / 4) * 9.0)
		root.rotation.y = 0.9
		n.add_child(root)
		i += 1
	var cam := Camera3D.new()
	n.add_child(cam)
	cam.position = Vector3(-2, 11, 16) if not only else Vector3(-6.5, 5.5, 8.5)
	cam.look_at(Vector3(-2.5, 0.5, 0.5) if not only else Vector3(-6.5, 0.8, -4.0))
	cam.fov = 55
	cam.make_current()
