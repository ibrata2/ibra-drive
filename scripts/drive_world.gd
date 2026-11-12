extends "res://scripts/world.gd"
## IBRA DRIVE — عالم الطريق: رحلة طويلة بين المحافظات (أو بادية/جبال/أهوار) تنبني قطعة قطعة وانت تسوق
## المهمات: توصيل حمولة، سباق حلقات، إنقاذ وسحب • مقطورة وحدة أو ثنتين • محطات، سيطرات، مطاعم، كراجات، أحداث

const MissionHud := preload("res://scripts/mission_hud.gd")
const CourseScript := preload("res://scripts/school_course.gd")

const TILE := 128.0
const TRES := 64
const TCELL := TILE / TRES
const AHEAD := 720.0
const BEHIND := 240.0
const SIDE := 300.0
const RS := 2.0          # دقة عينات الطريق
const S_MIN := -420.0
const SEG := 64.0        # طول قطعة الإسفلت

# شكل الطبيعة لكل منطقة
const REGIONS := {
	"south": {"amp": 1.6, "freq": 0.012, "dunes": 0.0, "g1": Color(0.78, 0.66, 0.47), "g2": Color(0.55, 0.55, 0.32), "rock": Color(0.6, 0.52, 0.4),
		"props": [["palm", 34], ["dry_bush", 14], ["grass_dry", 120], ["house", 1], ["wreck", 0.3], ["mudhif", 0.2]], "grove": 0.15, "biome": "farm"},
	"marsh": {"amp": 2.6, "freq": 0.02, "dunes": 0.0, "g1": Color(0.48, 0.47, 0.32), "g2": Color(0.42, 0.52, 0.3), "rock": Color(0.45, 0.42, 0.32),
		"props": [["reed", 380], ["palm", 10], ["boat", 1.2], ["mudhif", 0.6], ["grass", 120]], "grove": 0.3, "biome": "marsh", "water": true},
	"middle": {"amp": 1.4, "freq": 0.01, "dunes": 0.0, "g1": Color(0.5, 0.42, 0.28), "g2": Color(0.42, 0.55, 0.26), "rock": Color(0.5, 0.45, 0.36),
		"props": [["palm", 42], ["tree", 6], ["grass", 200], ["house", 1.2], ["hay", 1.5], ["wall", 1]], "grove": -0.05, "fields": true, "biome": "farm"},
	"desert": {"amp": 5.0, "freq": 0.009, "dunes": 1.0, "g1": Color(0.86, 0.7, 0.47), "g2": Color(0.93, 0.8, 0.58), "rock": Color(0.75, 0.58, 0.4),
		"props": [["dry_bush", 22], ["dune_grass", 160], ["rock", 6], ["tent", 0.35], ["wreck", 0.25], ["dead_tree", 2]], "grove": 2.0, "biome": "desert"},
	"north": {"amp": 9.0, "freq": 0.006, "dunes": 0.0, "g1": Color(0.66, 0.6, 0.4), "g2": Color(0.5, 0.56, 0.3), "rock": Color(0.55, 0.5, 0.42),
		"props": [["grass_dry", 260], ["rock", 9], ["bush", 12], ["house", 0.5], ["tree", 2]], "grove": 2.0, "biome": "savanna"},
	"kurd": {"amp": 26.0, "freq": 0.006, "dunes": 0.0, "g1": Color(0.36, 0.47, 0.25), "g2": Color(0.5, 0.52, 0.4), "rock": Color(0.5, 0.48, 0.44),
		"props": [["pine", 30], ["rock", 18], ["grass", 220], ["cabin", 0.4], ["bush", 14]], "grove": 2.0, "biome": "mountains", "mountain": true},
}

var spec: Dictionary = {}
var style := "highway"
var goal := "deliver"
var route_len := 5000.0
var road_half := 5.0
var paved := true
var has_road_mesh := true
var route_cities: Array = []    # [{id, name, s}]
var total_km := 100.0
var segs: Array = []           # [{s0, s1, region}]
var features: Array = []
var pads: Array = []           # {s0, s1, u0, u1, y, kind}
var rivers: Array = []         # {s, w, name}
var xc_arr := PackedFloat32Array()
var xd_arr := PackedFloat32Array()
var yr_arr := PackedFloat32Array()
var s_max := 6000.0
var route_seed := 1
var rnoise := FastNoiseLite.new()
var tnoise := FastNoiseLite.new()
var dnoise := FastNoiseLite.new()
var dest_name := ""
var origin_name := ""
var single_region := ""

# البث (القطع)
var tiles := {}                # key -> Node3D
var tile_pending := {}         # key -> true (بالخيط)
var tile_results := {}         # key -> data
var tile_mutex := Mutex.new()
var road_nodes := {}
var last_stream_pos := Vector3(1e9, 0, 0)
var prop_meshes := {}
var prop_mats := {}
var road_shader_mat: ShaderMaterial
var water_mi: MeshInstance3D
var horizon_mi: MeshInstance3D
var lamp_heads: Array = []

# المهمة
var mhud
var trailers: Array = []
var cargo: Dictionary = {}
var cargo_tons := 0.0
var damage := 0.0
var car_damage := 0.0
var fatigue := 0.0
var deadline_hour := -1.0
var start_hour := 12.0
var hours_elapsed := 0.0
var fines := 0
var fuel_cost := 0
var repairs := 0
var food := 0
var checkpoint_ok := 0
var broken_props := 0
var finished := false
var race_time := 0.0
var rings_done := 0
var towing := false
var spare_used := false
var change_tire_t := 0.0
var last_v := Vector3.ZERO
var slosh := 0.0
var slosh_v := 0.0
var surge := 0.0
var surge_v := 0.0
var jack_warn_t := 0.0
var fatigue_blink := 0.0
var drift_t := 0.0
var car_s := 0.0
var car_u := 0.0
var max_s := 0.0
var station_here: Dictionary = {}
var active_check: Dictionary = {}
var sheep_groups: Array = []
var prompt_override := ""
var exam_mode := false
var exam_speed_t := 0.0
var exam_faults: Array = []
var hold_e := 0.0
var flipped_once := false
var lesson_id := ""
var autopilot := false
var debug_fps := false
var _dbg_t := 0.0
var auto_kmh := 70.0
var course
var yard_hills: Array = []


# ================================================================ التجهيز
func _ready() -> void:
	if spec.is_empty():
		spec = Game.drive_spec
	goal = spec.get("goal", "deliver")
	exam_mode = spec.get("kind", "") == "exam"
	lesson_id = spec.get("lesson", "")
	if lesson_id != "":
		yard_hills = CourseScript.hills_for(lesson_id)
	route_seed = int(spec.get("seed", randi() % 100000))
	rng.seed = route_seed
	_build_route()
	_setup_noise_route()
	_layout_features()
	_setup_place()
	_bake_arrays()
	_make_materials()
	spawn = _route_pos(-26.0, 0.0)
	spawn_h = ground_h(spawn.x, spawn.z)
	spawn.y = spawn_h
	wcur = Places.WEATHER[weather].duplicate()
	weather_timer = 1e9 if spec.get("weather", "") != "" else rng.randf_range(200.0, 320.0)
	_build_environment()
	_build_weather_fx()
	_build_bursts()
	_build_fx_pools()
	_build_tracks()
	_build_water_and_horizon()
	var tf := Time.get_ticks_msec()
	_build_static_features()
	debug_fps = OS.get_cmdline_user_args().has("--fps")
	if debug_fps:
		print("FEATURES n=%d ms=%d len=%.0f" % [features.size(), Time.get_ticks_msec() - tf, route_len])
	if OS.get_cmdline_user_args().has("--fps"):
		for f in features:
			print("  F ", f["type"], " s=", int(f["s"]))
	# السيارة: نستعمل نفس دالة العالم الأصلي مع سيارة المهمة
	var keep := Game.test_car
	Game.test_car = spec.get("car", Game.active_car())
	_spawn_car()
	Game.test_car = keep
	car.reset_upright(Vector3(spawn.x, spawn_h + 1.4, spawn.z))
	# على الطرق الطويلة نشيل مقاومة الهوا الافتراضية حتى السيارات توصل سرعتها الحقيقية
	car.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	car.linear_damp = 0.02
	car.roll_coef = 0.022
	var has_fuel := false
	for f in features:
		if f["type"] == "fuel":
			has_fuel = true
	car.fuel_mult = 0.8 if has_fuel else 0.5
	car.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(-26.0)), Vector3(spawn.x, spawn_h + 1.4, spawn.z))
	safe_hist.clear()
	hud.minimap.visible = false
	if Game.is_mobile():
		hud.hint.visible = false
	hud.hint.text = "W/S قيادة • A/D توجيه • Space هاند بريك • H زمّور • C كاميرا • L أضواء • E تفاعل • R تعديل • T مساعدة الطريق • P صورة • Esc قائمة"
	cam.far = 1400.0
	hud.loot_panel.visible = false
	hud.toasts.position.y = 175
	hud.btn_tow.text = "مساعدة الطريق: تعديل وبانزين (١٥٠)"
	hud.btn_extra.text = "انسحاب من المهمة"
	hud.btn_extra.visible = true
	hud.extra_pressed.connect(abandon)
	hud.info_label.text = "T مرتين = مساعدة الطريق • E بالمحطات والسيطرات والتسليم • H زمّور • P صورة"
	var t0 := Time.get_ticks_msec()
	_stream(true)
	if debug_fps:
		print("STREAM sync tiles=%d ms=%d" % [tiles.size(), Time.get_ticks_msec() - t0])
	_setup_cargo_and_trailers()
	mhud = MissionHud.new()
	mhud.world = self
	add_child(mhud)
	if lesson_id != "":
		course = CourseScript.new()
		course.world = self
		course.lid = lesson_id
		add_child(course)
		course.setup()
		hud.btn_tow.text = "إعادة الدرس"
		var intro: Array = School.lesson(lesson_id).get("intro", [])
		if not intro.is_empty():
			car.controls = false
			mhud.show_dialog(intro, func(): car.controls = true)
	elif exam_mode:
		car.controls = false
		mhud.show_dialog([["الفاحص أبو مهدي", "السلام عليكم. اليوم امتحان الإجازة: طريق ريفي من الحلة لكربلاء."],
			["الفاحص أبو مهدي", "بالمدن السرعة ٦٠، وبرا ٩٠. بالسيطرة توكف. ولا تضرب شي. أكثر من غلطتين وما تنجح."],
			["الفاحص أبو مهدي", "شد حزامك... وتوكل على الله."]], func(): car.controls = true)
	_update_daylight(0.0)
	start_hour = hour
	if float(spec.get("deadline", -1.0)) > 0.0:
		deadline_hour = float(spec["deadline"])
	if goal == "race":
		race_time = float(spec.get("time_limit", 180.0))
	last_v = car.linear_velocity
	_intro_toasts()
	for a in OS.get_cmdline_user_args():
		if a == "--autopilot":
			autopilot = true
		elif a == "--fps":
			debug_fps = true
		elif a.begins_with("--auto-kmh="):
			auto_kmh = float(a.get_slice("=", 1))
		elif a.begins_with("--start-s="):
			var ss := float(a.get_slice("=", 1))
			var sp2 := _route_pos(ss, road_half * 0.45)
			car.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(ss)), Vector3(sp2.x, ground_h(sp2.x, sp2.z) + 1.4, sp2.z))
			_place_trailers()
			_stream(true)
		elif a == "--finish-now":
			get_tree().create_timer(1.5).timeout.connect(_deliver)
		elif a == "--fail-now":
			get_tree().create_timer(1.5).timeout.connect(func(): _fail("خلص الوقت!"))
		elif a.begins_with("--hour-set="):
			hour = float(a.get_slice("=", 1))


func _setup_place() -> void:
	var reg: String = single_region if single_region != "" else segs[0]["region"]
	var rdef: Dictionary = REGIONS[reg]
	var b: Dictionary = Places.get_biome(rdef["biome"]).duplicate(true)
	b["birds"] = false
	b["dunes"] = reg == "desert"
	b["low"] = rdef["g1"]
	b["dust"] = rdef["g1"].lightened(0.15)
	b["track"] = Color(0.12, 0.11, 0.1) if paved else rdef["g1"].darkened(0.45)
	if reg == "desert":
		b["ambient"] = ""
	biome = b
	season = spec.get("season", "")
	if season == "":
		season = "winter" if (reg == "kurd" and rng.randf() < 0.4) else ["summer", "spring", "autumn", "summer"][rng.randi() % 4]
	weather = spec.get("weather", "")
	if weather == "" or not Places.WEATHER.has(weather):
		var pool := Places.weathers_for(biome, season)
		weather = pool[rng.randi() % pool.size()] if rng.randf() < 0.5 else "clear"
	hour = float(spec.get("hour", 9.0))
	var title := str(spec.get("title", ""))
	if title == "":
		title = "%s ← %s" % [dest_name, origin_name] if origin_name != "" else dest_name
	place = {"name": "طريق " + Jobs.REGION_NAMES.get(reg, ""), "biome": b["id"], "season": season, "weather": weather, "hour": hour,
		"seed": route_seed, "req_level": 1}
	city_density = 0.01
	has_water = false
	for sgm in segs:
		if REGIONS[sgm["region"]].get("water", false):
			has_water = true
	if not rivers.is_empty():
		has_water = true
	water_kind = "lake" if has_water else "none"
	if style == "marsh":
		water_kind = "marsh"
	water_level = 0.0 if has_water else -1000.0
	base_snow = 0.55 if (season == "winter" and (style == "mountain" or reg == "kurd")) else 0.0
	if weather == "snow":
		base_snow = maxf(base_snow, 0.4)


func _setup_noise_route() -> void:
	rnoise.seed = route_seed
	rnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rnoise.frequency = 0.0012
	rnoise.fractal_octaves = 2
	tnoise.seed = route_seed + 5
	tnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	tnoise.frequency = 0.01
	tnoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	tnoise.fractal_octaves = 4
	dnoise.seed = route_seed + 9
	dnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dnoise.frequency = 0.03
	dnoise.fractal_octaves = 2
	noise_c.seed = route_seed + 23
	noise_c.frequency = 0.02
	noise_c.fractal_octaves = 2


# ================================================================ الطريق
func _build_route() -> void:
	style = spec.get("style", "highway")
	var from: String = spec.get("from", "")
	var to: String = spec.get("to", "")
	if from != "" and to != "" and Jobs.CITIES.has(from) and Jobs.CITIES.has(to):
		var p: Dictionary = Jobs.path(from, to)
		total_km = float(p["total"])
		route_len = float(spec.get("length", Jobs.game_length(total_km)))
		var cities: Array = p["cities"]
		var kms: Array = p["km"]
		for i in cities.size():
			var s := float(kms[i]) / maxf(total_km, 1.0) * route_len
			route_cities.append({"id": cities[i], "name": Jobs.city_name(cities[i]), "s": s})
		origin_name = Jobs.city_name(from)
		dest_name = Jobs.city_name(to)
		# كل جزء من الطريق ياخذ طبيعة المدينة اللي رايحله
		for i in range(1, cities.size()):
			var reg: String = Jobs.CITIES[cities[i]]["region"]
			if style == "rural" and reg in ["kurd"]:
				reg = "north"
			segs.append({"s0": route_cities[i - 1]["s"], "s1": route_cities[i]["s"], "region": reg})
		if Jobs.CITIES[from]["region"] != segs[0]["region"] and segs.size() > 0:
			segs[0]["s0"] = route_cities[0]["s"]
	else:
		route_len = float(spec.get("length", 3000.0))
		total_km = route_len / 9.0
		var reg2 := "desert"
		match style:
			"mountain":
				reg2 = "kurd"
			"marsh":
				reg2 = "marsh"
			"dirt", "rural":
				reg2 = spec.get("region", "middle")
			"yard":
				reg2 = "middle"
		single_region = reg2
		segs.append({"s0": 0.0, "s1": route_len, "region": reg2})
		dest_name = spec.get("dest", "خط النهاية")
		origin_name = ""
	match style:
		"highway":
			road_half = 5.2
		"rural":
			road_half = 3.8
		"dirt":
			road_half = 3.6
			paved = false
		"desert":
			road_half = 4.0
			paved = false
			has_road_mesh = false
		"mountain":
			road_half = 4.2
		"marsh":
			road_half = 4.0
			paved = false
		"yard":
			road_half = 5.0
			has_road_mesh = false
	s_max = route_len + 700.0


func region_at(s: float) -> String:
	if single_region != "":
		return single_region
	for sg in segs:
		if s <= float(sg["s1"]):
			return sg["region"]
	return segs[segs.size() - 1]["region"]


## معاملات الطبيعة مع دمج ناعم عند حدود المناطق
func region_params(s: float) -> Dictionary:
	var r := region_at(s)
	return REGIONS[r]


func _curve_params() -> Array:
	match style:
		"highway":
			return [55.0, 430.0, 32.0, 160.0]
		"rural":
			return [45.0, 270.0, 22.0, 95.0]
		"dirt":
			return [70.0, 210.0, 30.0, 72.0]
		"mountain":
			return [75.0, 190.0, 28.0, 66.0]
		"desert":
			return [120.0, 520.0, 45.0, 190.0]
		"marsh":
			return [50.0, 240.0, 20.0, 90.0]
		"yard":
			return [0.0, 100.0, 0.0, 100.0]
	return [50.0, 400.0, 25.0, 150.0]


func _bake_arrays() -> void:
	var n := int((s_max - S_MIN) / RS) + 2
	xc_arr.resize(n)
	xd_arr.resize(n)
	yr_arr.resize(n)
	var cp := _curve_params()
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var base_y := 4.0
	var y_amp := 2.5
	var y_freq := 0.0015
	match style:
		"mountain":
			base_y = 40.0
			y_amp = 34.0
			y_freq = 0.0011
		"desert":
			base_y = 6.0
			y_amp = 3.0
		"marsh":
			base_y = 1.25
			y_amp = 0.0
		"yard":
			base_y = 2.0
			y_amp = 0.0
	for i in n:
		var s := S_MIN + i * RS
		# انحناء الطريق، ومستقيم يم المخازن والمدن
		var straight := smoothstep(60.0, 260.0, s) * (1.0 - smoothstep(route_len - 260.0, route_len - 40.0, s))
		for c in route_cities:
			var cs := float(c["s"])
			if cs > 10.0 and cs < route_len - 10.0:
				straight *= smoothstep(150.0, 330.0, absf(s - cs))
		for f in features:
			if f["type"] in ["bridge", "check", "fuel", "food", "garage", "block", "stuck"]:
				straight *= smoothstep(45.0, 120.0, absf(s - float(f["s"])))
		var x := (float(cp[0]) * sin(s / float(cp[1]) + ph1) + float(cp[2]) * sin(s / float(cp[3]) + ph2)) * straight
		xc_arr[i] = x
		var y := base_y
		if y_amp > 0.0:
			var yy := rnoise.get_noise_1d(s * y_freq / 0.0012) * y_amp + rnoise.get_noise_1d(s * 2.7 + 300.0) * y_amp * 0.18
			y += yy * smoothstep(-100.0, 150.0, s) * (1.0 - smoothstep(route_len - 150.0, route_len + 60.0, s))
		yr_arr[i] = y
	# الجسور والسيطرات: الطريق مستوي يمهن
	for f in features:
		if f["type"] in ["bridge", "check", "fuel", "food", "garage"]:
			var fs := float(f["s"])
			var span := 90.0 if f["type"] == "bridge" else 60.0
			var i0 := int((fs - S_MIN) / RS)
			var yref := yr_arr[clampi(i0, 0, n - 1)]
			for i in n:
				var s2 := S_MIN + i * RS
				var k := 1.0 - smoothstep(span, span + 90.0, absf(s2 - fs))
				yr_arr[i] = lerpf(yr_arr[i], yref, k)
	# المطبات قبل السيطرات
	for f in features:
		if f["type"] == "check":
			for off in [-34.0, -22.0]:
				var bs: float = float(f["s"]) + float(off)
				for i in n:
					var s3 := S_MIN + i * RS
					var dd := absf(s3 - bs)
					if dd < 2.6:
						yr_arr[i] += 0.13 * (0.5 + 0.5 * cos(dd / 2.6 * PI))
	for i in n:
		var a := xc_arr[maxi(i - 1, 0)]
		var b := xc_arr[mini(i + 1, n - 1)]
		xd_arr[i] = (b - a) / (RS * 2.0)


func _ai(s: float) -> float:
	return clampf((s - S_MIN) / RS, 0.0, float(xc_arr.size() - 2))


func xc(s: float) -> float:
	var f := _ai(s)
	var i := int(f)
	return lerpf(xc_arr[i], xc_arr[i + 1], f - i)


func xd(s: float) -> float:
	var f := _ai(s)
	var i := int(f)
	return lerpf(xd_arr[i], xd_arr[i + 1], f - i)


func yr(s: float) -> float:
	var f := _ai(s)
	var i := int(f)
	return lerpf(yr_arr[i], yr_arr[i + 1], f - i)


## من إحداثيات العالم لإحداثيات الطريق: s على طول الطريق، u بعيد عن الوسط (يمين +)
func to_route(x: float, z: float) -> Vector2:
	var s := -z
	for _k in 2:
		var d := xd(s)
		var nrm := sqrt(1.0 + d * d)
		var u := (x - xc(s)) / nrm
		s = -z + u * d / nrm
	var d2 := xd(s)
	var nrm2 := sqrt(1.0 + d2 * d2)
	return Vector2(s, (x - xc(s)) / nrm2)


func _route_pos(s: float, u: float) -> Vector3:
	var d := xd(s)
	var nrm := sqrt(1.0 + d * d)
	var x := xc(s) + u / nrm
	var z := -s + u * d / nrm
	return Vector3(x, 0.0, z)


func route_point(s: float, u: float) -> Vector3:
	var p := _route_pos(s, u)
	p.y = ground_h(p.x, p.z)
	return p


func road_yaw(s: float) -> float:
	return atan2(-xd(s), 1.0)


func road_basis(s: float) -> Basis:
	return Basis(Vector3.UP, road_yaw(s))


# ================================================================ التضاريس
func terrain_h(x: float, z: float) -> float:
	var ru := to_route(x, z)
	var s := ru.x
	var u := ru.y
	var d := absf(u)
	var base := yr(s)
	var rp := region_params(s)
	var amp: float = rp["amp"]
	var n1 := tnoise.get_noise_2d(x, z)
	var nat := base - 1.1
	match style:
		"mountain":
			var dir := signf(rnoise.get_noise_1d(s * 1.7 + 77.0) + 0.0001)
			var rise := (d - road_half - 3.0) * 0.62 * (1.0 if signf(u) == dir else -0.5)
			nat = base + rise + n1 * 12.0 + absf(dnoise.get_noise_2d(x, z)) * 6.0
		"desert":
			var dunes := (sin(x * 0.03 + z * 0.011 + noise_c.get_noise_2d(x, z) * 4.0) * 0.5 + 0.5) * 5.5
			nat = base - 1.0 + (n1 * 0.5 + 0.5) * amp + dunes
		"marsh":
			nat = -0.9 + n1 * 2.4 + dnoise.get_noise_2d(x, z) * 0.6
		"yard":
			nat = base
			for hl in yard_hills:
				var hd := Vector2(x - float(hl[0]), z - float(hl[1])).length()
				var hr: float = hl[2]
				nat += float(hl[3]) * smoothstep(hr, hr * 0.22, hd)
		_:
			if bool(rp.get("mountain", false)):
				var dir2 := signf(rnoise.get_noise_1d(s * 1.3 + 33.0) + 0.0001)
				var rise2 := maxf(d - road_half - 8.0, 0.0) * 0.35 * (1.0 if signf(u) == dir2 else -0.25)
				nat = base + rise2 + n1 * amp * 0.4
			elif bool(rp.get("water", false)):
				nat = base - 1.6 + n1 * 2.2 + dnoise.get_noise_2d(x, z) * 0.7
			else:
				nat = base - 1.1 + (n1 * 0.5 + 0.5) * amp
				if float(rp["dunes"]) > 0.0:
					nat += (sin(x * 0.03 + z * 0.011) * 0.5 + 0.5) * 3.0
	var h: float
	if style == "desert":
		var t := smoothstep(road_half * 0.5, road_half + 14.0, d)
		h = lerpf(base + (nat - base) * 0.2, nat, t)
	else:
		var t2 := smoothstep(road_half + 1.2, road_half + (9.0 if style != "mountain" else 6.0), d)
		h = lerpf(base, nat, t2) if style != "yard" else nat
	# المناطق المستوية: محطات، مخازن، مدن، تحويلات
	for p in pads:
		var ps0: float = p["s0"]
		var ps1: float = p["s1"]
		if s < ps0 - 30.0 or s > ps1 + 30.0:
			continue
		var pu0: float = p["u0"]
		var pu1: float = p["u1"]
		var ds := maxf(maxf(ps0 - s, s - ps1), 0.0)
		var du := maxf(maxf(pu0 - u, u - pu1), 0.0)
		var out := sqrt(ds * ds + du * du)
		var py: float = p["y"]
		if p.get("ramp", false):
			py = yr(s) - 0.05
		h = lerpf(py, h, smoothstep(0.0, float(p.get("m", 14.0)), out))
	# الأنهار تحت الجسور
	for rv in rivers:
		var rd := absf(s - float(rv["s"]))
		var half := float(rv["w"]) * 0.5
		if rd < half + 30.0:
			var dip := 1.0 - smoothstep(half, half + 22.0, rd)
			var bed := -3.2 + absf(dnoise.get_noise_2d(x, z)) * 1.2
			h = lerpf(h, bed, dip)
	if has_water and style != "marsh" and not bool(rp.get("water", false)):
		var near_river := false
		for rv in rivers:
			if absf(s - float(rv["s"])) < float(rv["w"]) * 0.5 + 40.0:
				near_river = true
		if not near_river:
			h = maxf(h, 0.7)
	# حافات العالم: سدة ترابية عالية
	h += smoothstep(SIDE - 50.0, SIDE, d) * 30.0
	h += smoothstep(-90.0 if style != "yard" else -170.0, -220.0 if style != "yard" else -260.0, s) * 30.0
	h += smoothstep(route_len + 140.0, route_len + 260.0, s) * 30.0
	return h


## الأرض اللي تمشي عليها السيارة (الجسور فوق النهر)
func ground_h(x: float, z: float) -> float:
	if not rivers.is_empty():
		var ru := to_route(x, z)
		if absf(ru.y) < road_half + 1.2:
			for rv in rivers:
				if absf(ru.x - float(rv["s"])) < float(rv["w"]) * 0.5 + 26.0:
					return yr(ru.x)
	return terrain_h(x, z)


func h_at(x: float, z: float) -> float:
	return ground_h(x, z)


func on_road(x: float, z: float) -> bool:
	if not paved:
		return false
	var ru := to_route(x, z)
	if absf(ru.y) < road_half + 0.6:
		return true
	for p in pads:
		if p.get("paved", false) and ru.x >= float(p["s0"]) and ru.x <= float(p["s1"]) and ru.y >= float(p["u0"]) and ru.y <= float(p["u1"]):
			return true
	return false


func _ground_col(x: float, z: float, h: float, slope: float) -> Color:
	var ru := to_route(x, z)
	var s := ru.x
	var d := absf(ru.y)
	var rp := region_params(s)
	var g1: Color = rp["g1"]
	var g2: Color = rp["g2"]
	var nn := tnoise.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5
	var c := g1.lerp(g2, clampf(nn * 1.2 - 0.1 + float(rp["grove"]) * -0.2, 0.0, 1.0))
	if bool(rp.get("fields", false)):
		var stripe := sin((x * 0.7 + z * 0.3) * 0.25)
		var plot := dnoise.get_noise_2d(x * 0.2, z * 0.2)
		if plot > 0.05 and d > road_half + 14.0:
			c = Color(0.36, 0.52, 0.2).lerp(Color(0.6, 0.55, 0.28), 0.5 + 0.5 * signf(stripe))
	if style == "marsh" or bool(rp.get("water", false)):
		if h < 0.4:
			c = Color(0.35, 0.33, 0.24)
	if slope > 0.35:
		c = c.lerp(rp["rock"], smoothstep(0.35, 0.6, slope))
	# كتف الطريق
	if d < road_half + 2.6 and style not in ["desert"]:
		var gravel := Color(0.52, 0.49, 0.44) if paved else g1.darkened(0.2)
		c = c.lerp(gravel, 1.0 - smoothstep(road_half + 1.0, road_half + 2.6, d))
	if style == "desert" and d < road_half + 2.0:
		c = c.darkened(0.12 * (1.0 - smoothstep(road_half * 0.5, road_half + 2.0, d)))
	for p in pads:
		if s >= float(p["s0"]) - 2.0 and s <= float(p["s1"]) + 2.0 and ru.y >= float(p["u0"]) - 2.0 and ru.y <= float(p["u1"]) + 2.0:
			match str(p.get("kind", "")):
				"concrete":
					c = Color(0.55, 0.55, 0.53)
				"dirt":
					c = g1.darkened(0.25)
				"town":
					c = c.lerp(Color(0.62, 0.57, 0.48), 0.55)
	for rv in rivers:
		if absf(s - float(rv["s"])) < float(rv["w"]) * 0.5 + 10.0 and h < 0.8:
			c = Color(0.4, 0.38, 0.3)
	if d > SIDE - 50.0:
		c = c.lerp(rp["rock"], smoothstep(SIDE - 50.0, SIDE - 20.0, d) * 0.6)
	return c


# ================================================================ مخطط الرحلة
func _far_from(s: float, gap: float, types: Array = []) -> bool:
	for f in features:
		if types.is_empty() or f["type"] in types:
			if absf(float(f["s"]) - s) < gap:
				return false
	return true


func _add_pad(s0: float, s1: float, u0: float, u1: float, kind: String, ramp: bool, paved_pad := false, m := 14.0) -> void:
	pads.append({"s0": s0, "s1": s1, "u0": u0, "u1": u1, "y": -9999.0, "kind": kind, "ramp": ramp, "paved": paved_pad, "m": m})


func _layout_features() -> void:
	if style == "yard":
		return
	var L := route_len
	var wild := style in ["desert", "marsh"]
	var racing := goal == "race"
	# البداية والنهاية
	if wild or racing or style == "dirt":
		features.append({"type": "camp_start", "s": 0.0})
		_add_pad(-60.0, 20.0, -24.0, 24.0, "dirt", false)
		features.append({"type": "camp_end", "s": L})
		_add_pad(L - 25.0, L + 70.0, -30.0, 30.0, "dirt", false)
	else:
		features.append({"type": "depot_start", "s": 0.0})
		_add_pad(-80.0, 22.0, -40.0, 40.0, "concrete", false, true)
		features.append({"type": "depot_end", "s": L})
		_add_pad(L - 22.0, L + 100.0, -44.0, 44.0, "concrete", false, true)
	# المدن بالطريق
	if not wild:
		for i in route_cities.size():
			var c: Dictionary = route_cities[i]
			var cs: float = c["s"]
			if i == 0:
				features.append({"type": "town", "s": 150.0, "s0": 40.0, "s1": 280.0, "city": c["id"], "small": true})
				_add_pad(40.0, 280.0, -70.0, 70.0, "town", true, false, 18.0)
			elif i == route_cities.size() - 1:
				features.append({"type": "town", "s": L - 170.0, "s0": L - 330.0, "s1": L - 35.0, "city": c["id"], "small": false})
				_add_pad(L - 330.0, L - 35.0, -70.0, 70.0, "town", true, false, 18.0)
			elif cs > 400.0 and cs < L - 400.0:
				features.append({"type": "town", "s": cs, "s0": cs - 190.0, "s1": cs + 190.0, "city": c["id"], "small": false})
				_add_pad(cs - 190.0, cs + 190.0, -70.0, 70.0, "town", true, false, 18.0)
				features.append({"type": "welcome", "s": cs - 230.0, "city": c["id"]})
		# الأنهار والجسور قبل المدن اللي على نهر
		for i in range(1, route_cities.size()):
			var c2: Dictionary = route_cities[i]
			var rv: String = Jobs.CITIES[c2["id"]].get("river", "")
			if rv == "":
				continue
			var rs := float(c2["s"]) - 400.0 if i < route_cities.size() - 1 else L - 440.0
			if rs > 380.0 and rs < L - 380.0 and _far_from(rs, 160.0):
				features.append({"type": "bridge", "s": rs, "w": 44.0, "name": rv})
				rivers.append({"s": rs, "w": 44.0, "name": rv})
		if style == "marsh":
			pass
		# السيطرات عند مداخل المدن
		if paved:
			for i in range(1, route_cities.size()):
				var c3: Dictionary = route_cities[i]
				var base_s := float(c3["s"]) if i < route_cities.size() - 1 else L
				for off in [560.0, 740.0, 900.0, 640.0]:
					var ks: float = base_s - float(off)
					if ks > 450.0 and _far_from(ks, 170.0):
						features.append({"type": "check", "s": ks, "city": c3["id"]})
						break
			if L > 4500.0:
				var mid := L * 0.5
				if _far_from(mid, 500.0, ["check"]) and _far_from(mid, 170.0):
					features.append({"type": "check", "s": mid, "city": ""})
	# محطات الطريق
	if not wild and not racing:
		var cyc := ["fuel", "food", "garage", "fuel", "garage", "food"]
		var k := 0
		var s := 820.0
		while s < L - 600.0:
			var placed := false
			for off in [0.0, 120.0, -120.0, 240.0, -240.0, 360.0]:
				var ss: float = s + off
				if ss > 500.0 and ss < L - 500.0 and _far_from(ss, 230.0):
					var tp: String = cyc[k % cyc.size()]
					if style == "mountain" and tp == "garage" and k % 2 == 0:
						tp = "fuel"
					features.append({"type": tp, "s": ss, "side": 1.0})
					_add_pad(ss - 42.0, ss + 42.0, road_half + 0.5, road_half + 40.0, "concrete", true, true, 12.0)
					k += 1
					placed = true
					break
			s += 1350.0 if placed else 300.0
	# لوحات المسافات
	if not wild:
		var sg := 600.0
		while sg < L - 300.0:
			if _far_from(sg, 60.0):
				features.append({"type": "sign", "s": sg})
			sg += 1000.0
	# الحلقات (سباق أو دليل بالبادية)
	if racing or wild or style == "dirt":
		var step := 320.0 if racing else 460.0
		var rs2 := 260.0
		var idx := 0
		while rs2 < L - 80.0:
			features.append({"type": "ring", "s": rs2, "u": rng.randf_range(-1.0, 1.0) * road_half * 0.4, "idx": idx, "done": false, "race": racing})
			idx += 1
			rs2 += step
	# الإنقاذ
	if goal == "rescue":
		var ss2 := L * 0.55
		var uu := 0.0 if wild else (road_half + 16.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		features.append({"type": "stuck", "s": ss2, "u": uu})
		if not wild:
			_add_pad(ss2 - 18.0, ss2 + 18.0, minf(uu, 0.0) - 6.0, maxf(uu, 0.0) + 6.0, "dirt", true, false, 10.0)
	# الأحداث
	var evs: Array = spec.get("events", [])
	for e in evs:
		var es := 0.0
		for _t in 30:
			es = rng.randf_range(L * 0.25, L * 0.75)
			if _far_from(es, 280.0):
				break
		match str(e):
			"blowout":
				features.append({"type": "blowout", "s": es, "done": false})
			"sheep":
				features.append({"type": "sheep", "s": es, "done": false, "spawned": false})
			"roadblock":
				if paved:
					features.append({"type": "block", "s": es})
					_add_pad(es - 95.0, es + 95.0, road_half + 2.5, road_half + 13.0, "dirt", true, false, 8.0)


func _finish_pads() -> void:
	for p in pads:
		if float(p["y"]) < -9000.0:
			p["y"] = yr((float(p["s0"]) + float(p["s1"])) * 0.5)


# ================================================================ المواد
func _make_materials() -> void:
	_finish_pads()
	road_shader_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
#include "res://shaders/noise.gdshaderinc"
uniform float dirt = 0.0;
uniform float wet = 0.0;
uniform float snow = 0.0;
uniform vec3 dirt_color : source_color = vec3(0.45, 0.37, 0.27);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float x = UV.x;
	float s = UV.y;
	float n = vnoise(wpos.xz * 1.3) * 0.5 + vnoise(wpos.xz * 7.0) * 0.3 + vnoise(wpos.xz * 0.15) * 0.2;
	vec3 asphalt = vec3(0.16, 0.16, 0.17) * (0.82 + n * 0.32);
	float patch = smoothstep(0.62, 0.66, vnoise(wpos.xz * 0.08));
	asphalt = mix(asphalt, vec3(0.11, 0.11, 0.115), patch * 0.7);
	vec3 dc = dirt_color * (0.8 + n * 0.35);
	float rut = smoothstep(0.08, 0.0, abs(x - 0.3)) + smoothstep(0.08, 0.0, abs(x - 0.7));
	dc *= 1.0 - rut * 0.18;
	vec3 c = mix(asphalt, dc, dirt);
	float line = 0.0;
	if (dirt < 0.5) {
		float edge = step(0.035, x) * step(x, 0.055) + step(0.945, x) * step(x, 0.965);
		float center = step(abs(x - 0.5), 0.009) * step(fract(s / 12.0), 0.45);
		line = clamp(edge + center, 0.0, 1.0) * (0.75 + 0.25 * vnoise(wpos.xz * 3.0));
	}
	c = mix(c, vec3(0.92, 0.9, 0.82), line);
	c = mix(c, vec3(0.92, 0.94, 0.98), snow * smoothstep(0.3, 0.7, n) * 0.8);
	float w = wet * (1.0 - snow);
	c *= mix(1.0, 0.6, w);
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = mix(0.9, 0.18, w);
	SPECULAR = mix(0.3, 0.75, w);
}
"""
	road_shader_mat.shader = sh
	road_shader_mat.set_shader_parameter("dirt", 0.0 if paved else 1.0)
	var rp := region_params(route_len * 0.5)
	road_shader_mat.set_shader_parameter("dirt_color", (rp["g1"] as Color).darkened(0.15))
	road_shader_mat.set_shader_parameter("snow", clampf(base_snow, 0.0, 1.0) * 0.6)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GroundShader
	ground_mat.set_shader_parameter("ripples", 1.0 if style == "desert" else 0.0)
	building_mat = ShaderMaterial.new()
	building_mat.shader = BuildingShader
	lamp_head_mat = StandardMaterial3D.new()
	lamp_head_mat.vertex_color_use_as_albedo = true
	lamp_head_mat.vertex_color_is_srgb = true
	lamp_head_mat.emission_enabled = true
	lamp_head_mat.emission = Color(1.0, 0.8, 0.5)
	lamp_head_mat.emission_energy_multiplier = 0.0
	# موديلات الأشياء (مرة وحدة)
	var fols := _foliage_colors()
	var snowy := base_snow > 0.3
	var kinds := {}
	for r in REGIONS:
		for e in REGIONS[r]["props"]:
			kinds[e[0]] = true
	kinds["pole"] = true
	kinds["lamp"] = true
	kinds["tires"] = true
	kinds["crates"] = true
	for kind in kinds:
		var vars := 3 if kind in ["tree", "grass", "bush"] else 1
		var arr: Array = []
		for v in vars:
			var p := {"foliage": fols[v % fols.size()], "rock": (REGIONS[region_at(route_len * 0.5)]["rock"] as Color), "snowy": snowy, "variant": v,
				"bare": false, "flower": Color(0.9, 0.1, 0.1)}
			arr.append(PropLib.build(kind, p))
		prop_meshes[kind] = arr
		prop_mats[kind] = _prop_material(kind in PropLib.GRASSY, kind)
	prop_meshes["lamp_head"] = [PropLib.build("lamp_head", {})]


func _foliage_colors() -> Array:
	match season:
		"autumn":
			return [Color(0.85, 0.42, 0.12), Color(0.9, 0.65, 0.15), Color(0.7, 0.2, 0.1)]
		"winter":
			return [Color(0.3, 0.4, 0.28), Color(0.38, 0.42, 0.3), Color(0.32, 0.36, 0.26)]
		"spring":
			return [Color(0.32, 0.62, 0.2), Color(0.42, 0.7, 0.25), Color(0.28, 0.55, 0.22)]
	return [Color(0.26, 0.5, 0.18), Color(0.34, 0.55, 0.2), Color(0.3, 0.46, 0.17)]


func _build_water_and_horizon() -> void:
	if has_water:
		water_mi = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1400, 1400)
		pm.subdivide_width = 80
		pm.subdivide_depth = 80
		water_mi.mesh = pm
		var wm := ShaderMaterial.new()
		wm.shader = WaterShader
		if style == "marsh" or water_kind == "marsh":
			wm.set_shader_parameter("murky", 0.6)
			wm.set_shader_parameter("shallow_color", Color(0.35, 0.55, 0.45))
			wm.set_shader_parameter("deep_color", Color(0.12, 0.25, 0.22))
			wm.set_shader_parameter("wave_amp", 0.03)
		else:
			wm.set_shader_parameter("shallow_color", Color(0.32, 0.55, 0.5))
			wm.set_shader_parameter("deep_color", Color(0.12, 0.26, 0.28))
			wm.set_shader_parameter("murky", 0.35)
			wm.set_shader_parameter("wave_amp", 0.05)
		water_mi.material_override = wm
		water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water_mi.position = Vector3(0, water_level, 0)
		add_child(water_mi)
	horizon_mi = MeshInstance3D.new()
	var hp := PlaneMesh.new()
	hp.size = Vector2(5000, 5000)
	horizon_mi.mesh = hp
	var hm := StandardMaterial3D.new()
	hm.albedo_color = (REGIONS[region_at(0.0)]["g1"] as Color).darkened(0.1)
	hm.roughness = 1.0
	horizon_mi.material_override = hm
	horizon_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var miny := 1e9
	for i in range(0, yr_arr.size(), 20):
		miny = minf(miny, yr_arr[i])
	horizon_mi.position = Vector3(0, minf(miny - 9.0, -4.0), 0)
	add_child(horizon_mi)


func _build_tracks() -> void:
	track_mm = MultiMesh.new()
	track_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.36, 0.62)
	track_mm.mesh = pm
	track_mm.instance_count = 4000
	track_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = track_mm
	var m := StandardMaterial3D.new()
	var tc: Color = biome["track"]
	m.albedo_color = Color(tc.r, tc.g, tc.b, 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-3000, -300, -route_len - 3000), Vector3(6000, 900, route_len + 6000))
	add_child(mmi)
	for i in 4:
		track_last.append(Vector3.INF)


# ================================================================ البث: قطع الأرض والإسفلت
func _needed_tiles(center: Vector3) -> Dictionary:
	var need := {}
	var z_hi := minf(center.z + BEHIND, 260.0)
	var z_lo := maxf(center.z - AHEAD, -route_len - 300.0)
	var iz0 := int(floor(z_lo / TILE))
	var iz1 := int(floor(z_hi / TILE))
	for iz in range(iz0, iz1 + 1):
		var za := iz * TILE
		var zb := za + TILE
		var xs := [xc(-za), xc(-zb), xc(-(za + zb) * 0.5)]
		var xmin: float = xs.min() - SIDE
		var xmax: float = xs.max() + SIDE
		# القطع البعيدة عرضياً ما نحتاجها إذا السيارة بعيدة عنها
		for ix in range(int(floor(xmin / TILE)), int(floor(xmax / TILE)) + 1):
			var cxp := ix * TILE + TILE * 0.5
			var czp := iz * TILE + TILE * 0.5
			if absf(cxp - center.x) > SIDE + 260.0 and absf(czp - center.z) > 300.0:
				continue
			need[Vector2i(ix, iz)] = true
	return need


func _stream(sync := false) -> void:
	var cp := car.global_position if car else spawn
	if not sync and cp.distance_to(last_stream_pos) < 12.0 and tile_pending.is_empty() and tile_results.is_empty():
		return
	last_stream_pos = cp
	var need := _needed_tiles(cp)
	# نشيل البعيدة
	for key in tiles.keys():
		if not need.has(key):
			var cz := float(key.y) * TILE + TILE * 0.5
			if absf(cz - cp.z) > AHEAD + 200.0 or absf(float(key.x) * TILE + TILE * 0.5 - cp.x) > SIDE + 420.0:
				(tiles[key] as Node).queue_free()
				tiles.erase(key)
	# نرتب الأقرب أول
	var missing: Array = []
	for key in need:
		if not tiles.has(key) and not tile_pending.has(key):
			missing.append(key)
	missing.sort_custom(func(a, b): return Vector2(a.x * TILE, a.y * TILE).distance_squared_to(Vector2(cp.x, cp.z)) < Vector2(b.x * TILE, b.y * TILE).distance_squared_to(Vector2(cp.x, cp.z)))
	if sync:
		for key in missing:
			_finish_tile(key, _gen_tile(key))
	else:
		var running := tile_pending.size()
		for key in missing:
			if running >= 3:
				break
			tile_pending[key] = true
			WorkerThreadPool.add_task(_gen_task.bind(key), false, "tile")
			running += 1
		# النتايج الجاهزة (وحدة لكل فريم حتى ما يتقطع)
		tile_mutex.lock()
		var ready_keys := tile_results.keys()
		tile_mutex.unlock()
		if not ready_keys.is_empty():
			var key2: Vector2i = ready_keys[0]
			tile_mutex.lock()
			var data: Dictionary = tile_results[key2]
			tile_results.erase(key2)
			tile_mutex.unlock()
			tile_pending.erase(key2)
			if need.has(key2) and not tiles.has(key2):
				_finish_tile(key2, data)
	_stream_roads(cp)


func _gen_task(key: Vector2i) -> void:
	var data := _gen_tile(key)
	tile_mutex.lock()
	tile_results[key] = data
	tile_mutex.unlock()


## يحسب ارتفاعات وألوان وأشياء القطعة (يشتغل بخيط ثاني)
func _gen_tile(key: Vector2i) -> Dictionary:
	var n := TRES + 1
	var x0 := key.x * TILE
	var z0 := key.y * TILE
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = terrain_h(x0 + i * TCELL, z0 + j * TCELL)
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	norms.resize(n * n)
	cols.resize(n * n)
	for j in n:
		for i in n:
			var hl := hs[j * n + maxi(i - 1, 0)]
			var hr := hs[j * n + mini(i + 1, TRES)]
			var hd := hs[maxi(j - 1, 0) * n + i]
			var hu := hs[mini(j + 1, TRES) * n + i]
			var nm := Vector3(hl - hr, 2.0 * TCELL, hd - hu).normalized()
			norms[j * n + i] = nm
			cols[j * n + i] = _ground_col(x0 + i * TCELL, z0 + j * TCELL, hs[j * n + i], 1.0 - nm.y)
	# الأشياء
	var trng := RandomNumberGenerator.new()
	trng.seed = hash(Vector3i(key.x, key.y, route_seed))
	var props := {}
	var cs := -(z0 + TILE * 0.5)
	var rp := region_params(cs)
	if style != "yard":
		for e in rp["props"]:
			var kind: String = e[0]
			var cnt := float(e[1])
			if season == "winter" and kind == "palm" and style == "mountain":
				continue
			var count := int(cnt) + (1 if trng.randf() < cnt - floor(cnt) else 0)
			var grassy := kind in PropLib.GRASSY
			var clumped := kind in ["palm", "reed", "grass", "grass_dry", "dune_grass", "bush"]
			var list: Array = []
			var tries := count * 3
			while list.size() < count and tries > 0:
				tries -= 1
				var x := x0 + trng.randf() * TILE
				var z := z0 + trng.randf() * TILE
				var ru := to_route(x, z)
				var d := absf(ru.y)
				if d < road_half + (3.0 if grassy else 9.0) or d > SIDE - 40.0:
					continue
				if ru.x < -70.0 or ru.x > route_len + 110.0:
					continue
				if _in_pad(ru, 3.0) or _near_feature(ru.x, kind):
					continue
				if clumped and noise_c.get_noise_2d(x * 1.5, z * 1.5) < float(rp["grove"]) * 0.5 - 0.1:
					continue
				var h := _h_from(hs, x - x0, z - z0)
				if kind == "reed":
					if not has_water or h > water_level + 1.2 or h < water_level - 0.8:
						continue
				elif kind == "boat":
					if not has_water or h > water_level - 0.3 or h < water_level - 2.5:
						continue
					h = water_level - 0.15
				elif has_water and h < water_level + 0.3:
					continue
				var nm2 := _n_from(hs, x - x0, z - z0)
				if not grassy and nm2.y < 0.8 and kind not in ["rock", "pine", "dead_tree"]:
					continue
				var sc := trng.randf_range(0.75, 1.3)
				var basis := Basis(Vector3.UP, trng.randf() * TAU)
				if kind == "rock":
					basis = basis.scaled(Vector3(sc * trng.randf_range(0.8, 2.2), sc * trng.randf_range(0.6, 1.6), sc * trng.randf_range(0.8, 2.2)))
				elif kind in ["house", "cabin", "mudhif", "tent", "wall", "hay"]:
					basis = Basis(Vector3.UP, road_yaw(ru.x) + (trng.randi() % 4) * PI / 2.0)
				else:
					basis = basis.scaled(Vector3(sc, sc, sc))
				list.append(Transform3D(basis, Vector3(x, h - (0.05 if grassy else 0.25), z)))
			if not list.is_empty():
				props[kind] = list
		# أعمدة الكهرباء على طول الطريق
		if paved and style != "mountain":
			var plist: Array = []
			var s_hi := -z0
			var s_lo := -(z0 + TILE)
			var ps := ceilf(s_lo / 55.0) * 55.0
			while ps <= s_hi:
				var ru2 := Vector2(ps, road_half + 7.5)
				if ps > 30.0 and ps < route_len - 30.0 and not _in_pad(ru2, 2.0) and not _near_feature(ps, "pole"):
					var p := _route_pos(ps, road_half + 7.5)
					if p.x >= x0 and p.x < x0 + TILE and p.z >= z0 and p.z < z0 + TILE:
						p.y = _h_from(hs, p.x - x0, p.z - z0)
						plist.append(Transform3D(Basis(Vector3.UP, road_yaw(ps)), p))
				ps += 55.0
			if not plist.is_empty():
				props["pole"] = plist
	return {"h": hs, "n": norms, "c": cols, "props": props}


func _h_from(hs: PackedFloat32Array, lx: float, lz: float) -> float:
	var n := TRES + 1
	var fx := clampf(lx / TCELL, 0.0, TRES - 0.001)
	var fz := clampf(lz / TCELL, 0.0, TRES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	return lerpf(lerpf(hs[j * n + i], hs[j * n + i + 1], tx), lerpf(hs[(j + 1) * n + i], hs[(j + 1) * n + i + 1], tx), tz)


func _n_from(hs: PackedFloat32Array, lx: float, lz: float) -> Vector3:
	var e := TCELL
	return Vector3(_h_from(hs, lx - e, lz) - _h_from(hs, lx + e, lz), 2.0 * e, _h_from(hs, lx, lz - e) - _h_from(hs, lx, lz + e)).normalized()


func _in_pad(ru: Vector2, m: float) -> bool:
	for p in pads:
		if ru.x >= float(p["s0"]) - m and ru.x <= float(p["s1"]) + m and ru.y >= float(p["u0"]) - m and ru.y <= float(p["u1"]) + m:
			return true
	for rv in rivers:
		if absf(ru.x - float(rv["s"])) < float(rv["w"]) * 0.5 + 30.0 and absf(ru.y) < 40.0:
			return true
	return false


func _near_feature(s: float, kind: String) -> bool:
	for f in features:
		var t: String = f["type"]
		if t in ["check", "bridge", "block"] and absf(s - float(f["s"])) < 70.0:
			return true
		if kind == "pole" and t in ["sign", "welcome"] and absf(s - float(f["s"])) < 12.0:
			return true
	return false


## يبني القطعة بالمشهد (الخيط الرئيسي)
func _finish_tile(key: Vector2i, data: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	tiles[key] = node
	var n := TRES + 1
	var x0 := key.x * TILE
	var z0 := key.y * TILE
	var hs: PackedFloat32Array = data["h"]
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(x0 + i * TCELL, hs[j * n + i], z0 + j * TCELL)
	var idx := PackedInt32Array()
	idx.resize(TRES * TRES * 6)
	var k := 0
	for j in TRES:
		for i in TRES:
			var a := j * n + i
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = a + n
			idx[k + 3] = a + 1
			idx[k + 4] = a + n + 1
			idx[k + 5] = a + n
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = data["n"]
	arr[Mesh.ARRAY_COLOR] = data["c"]
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ground_mat
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.position = Vector3(x0 + TILE * 0.5, 0, z0 + TILE * 0.5)
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(hs.size())
	for i in hs.size():
		scaled[i] = hs[i] / TCELL
	hm.map_data = scaled
	cs.shape = hm
	cs.scale = Vector3(TCELL, TCELL, TCELL)
	body.add_child(cs)
	body.set_meta("terrain", true)
	node.add_child(body)
	if terrain_body == null:
		terrain_body = body
	# الأشياء
	var pbody := StaticBody3D.new()
	pbody.set_meta("chunk_props", true)
	node.add_child(pbody)
	var props: Dictionary = data["props"]
	for kind in props:
		var xfs: Array = props[kind]
		var meshes: Array = prop_meshes.get(kind, [])
		if meshes.is_empty():
			continue
		var grassy: bool = kind in PropLib.GRASSY
		var vis := 160.0 if grassy else (260.0 if kind in ["dry_bush", "bush", "tires", "reed"] else 0.0)
		var per := int(ceil(float(xfs.size()) / meshes.size()))
		var refs: Array = []
		for v in meshes.size():
			var part := xfs.slice(v * per, mini((v + 1) * per, xfs.size()))
			if part.is_empty():
				continue
			if meshes[v] == null:
				push_warning("NULL MESH " + kind)
				continue
			refs.append_array(_tile_multimesh(node, meshes[v], prop_mats[kind], part, vis, not grassy))
		_tile_collisions(pbody, kind, xfs, refs)


func _tile_multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array, vis_range: float, shadows: bool) -> Array:
	var refs: Array = []
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		refs.append([mm, i, mat])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if vis_range > 0.0:
		mmi.visibility_range_end = vis_range
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return refs


func _tile_collisions(pbody: StaticBody3D, kind: String, xforms: Array, refs: Array) -> void:
	if not PropLib.SOLID.has(kind):
		return
	var info: Array = PropLib.SOLID[kind]
	for k in xforms.size():
		var t: Transform3D = xforms[k]
		var sc := t.basis.get_scale()
		var cs := CollisionShape3D.new()
		if info[0] == "box":
			var bs := BoxShape3D.new()
			var sz: Vector3 = info[1]
			bs.size = sz * sc
			cs.shape = bs
			cs.position = t.origin + Vector3(0, bs.size.y * 0.5, 0)
			cs.basis = t.basis.orthonormalized()
		elif info[0] == "cyl":
			var cyl := CylinderShape3D.new()
			var d: Vector2 = info[1]
			cyl.radius = d.x * sc.x
			cyl.height = d.y * sc.y
			cs.shape = cyl
			cs.position = t.origin + Vector3(0, cyl.height * 0.5, 0)
		else:
			continue
		var meta := {"kind": kind, "xf": t, "refs": []}
		if k < refs.size() and refs[k] != null:
			meta["refs"] = [refs[k]]
		cs.set_meta("prop", meta)
		pbody.add_child(cs)


## قطع الإسفلت (64 متر) حوالين السيارة
func _stream_roads(cp: Vector3) -> void:
	if not has_road_mesh:
		return
	var cs := -cp.z
	var i0 := int(floor(maxf(cs - BEHIND - 60.0, -70.0) / SEG))
	var i1 := int(floor(minf(cs + AHEAD + 60.0, route_len + 100.0) / SEG))
	for key in road_nodes.keys():
		if int(key) < i0 - 1 or int(key) > i1 + 1:
			(road_nodes[key] as Node).queue_free()
			road_nodes.erase(key)
	for i in range(i0, i1 + 1):
		if not road_nodes.has(i):
			road_nodes[i] = _build_road_seg(i)


func _build_road_seg(i: int) -> Node3D:
	var s0 := i * SEG
	var s1 := s0 + SEG
	var steps := int(SEG / RS)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var w := road_half
	var lift := 0.045
	for k in steps + 1:
		var s := s0 + k * RS
		var y := yr(s) + lift
		var a := _route_pos(s, -w)
		var b := _route_pos(s, w)
		verts.append(Vector3(a.x, y, a.z))
		verts.append(Vector3(b.x, y, b.z))
		uvs.append(Vector2(0.0, s))
		uvs.append(Vector2(1.0, s))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
	for k in steps:
		var a2 := k * 2
		idx.append_array([a2, a2 + 2, a2 + 1, a2 + 1, a2 + 2, a2 + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = road_shader_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ================================================================ المعالم الثابتة
var _mat_cache := {}


func _m(c: Color, emis := 0.0, metal := 0.0, rough := 0.8) -> StandardMaterial3D:
	var key := c.to_html() + str(emis) + str(metal)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	_mat_cache[key] = m
	return m


## صندوق بإحداثيات الطريق (s, u, ارتفاع فوك الأرض) ويدور ويه الطريق
func _rbox(parent: Node3D, body: StaticBody3D, s: float, u: float, y: float, size: Vector3, mat: Material, yaw_off := 0.0, ground := -9999.0) -> MeshInstance3D:
	var p := _route_pos(s, u)
	var gy := ground if ground > -9000.0 else ground_h(p.x, p.z)
	var xf := Transform3D(Basis(Vector3.UP, road_yaw(s) + yaw_off), Vector3(p.x, gy + y + size.y * 0.5, p.z))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_transform = xf
	if body:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		cs.global_transform = xf
	return mi


func _label3d(parent: Node3D, txt: String, pos: Vector3, yaw: float, size := 96, col := Color.WHITE, px := 0.012) -> Label3D:
	var lb := Label3D.new()
	lb.text = txt
	lb.font = Game.arabic_font
	lb.font_size = size
	lb.pixel_size = px
	lb.modulate = col
	lb.outline_size = 12
	lb.outline_modulate = Color(0, 0, 0, 0.6)
	lb.double_sided = true
	parent.add_child(lb)
	lb.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return lb


## لوحة طريق خضرة على عمودين
func _road_sign(parent: Node3D, s: float, u: float, text: String, col := Color(0.05, 0.38, 0.2), w := 5.0, h := 2.4) -> void:
	var gy := ground_h(_route_pos(s, u).x, _route_pos(s, u).z)
	var pole := _m(Color(0.6, 0.62, 0.64), 0.0, 0.6, 0.4)
	_rbox(parent, null, s, u - w * 0.35, 0.0, Vector3(0.14, 3.2 + h, 0.14), pole, 0.0, gy)
	_rbox(parent, null, s, u + w * 0.35, 0.0, Vector3(0.14, 3.2 + h, 0.14), pole, 0.0, gy)
	_rbox(parent, null, s, u, 3.1, Vector3(w, h, 0.12), _m(col), 0.0, gy)
	var p := _route_pos(s - 0.08, u)
	_label3d(parent, text, Vector3(p.x, gy + 3.1 + h * 0.5, p.z), road_yaw(s), 80, Color(1, 1, 1), 0.011)


func _build_static_features() -> void:
	for f in features:
		match str(f["type"]):
			"depot_start", "depot_end":
				_build_depot(f)
			"camp_start", "camp_end":
				_build_camp(f)
			"town":
				_build_town(f)
			"welcome":
				var c: Dictionary = Jobs.CITIES[f["city"]]
				_road_sign(self, float(f["s"]), road_half + 4.0, "أهلاً بكم في %s\nمحافظة %s" % [c["name"], c["gov"]], Color(0.1, 0.3, 0.55), 7.0, 2.6)
			"bridge":
				_build_bridge(f)
			"check":
				_build_checkpoint(f)
			"fuel", "food", "garage":
				_build_station(f)
			"sign":
				var s := float(f["s"])
				var left_km := int(round((route_len - s) / route_len * total_km))
				var txt := "%s  %s كم" % [dest_name, Jobs.ar_num(left_km)]
				var nxt := _next_town_after(s)
				if nxt != "" and nxt != dest_name:
					var nk := int(round((_town_s(nxt) - s) / route_len * total_km))
					txt = "%s  %s كم\n%s  %s كم" % [nxt, Jobs.ar_num(maxi(nk, 1)), dest_name, Jobs.ar_num(left_km)]
				_road_sign(self, s, road_half + 4.0, txt, Color(0.05, 0.38, 0.2), 5.6, 2.4)
			"ring":
				_build_ring(f)
			"stuck":
				_build_stuck(f)
			"block":
				_build_block(f)


func _next_town_after(s: float) -> String:
	for c in route_cities:
		if float(c["s"]) > s + 50.0:
			return c["name"]
	return ""


func _town_s(name: String) -> float:
	for c in route_cities:
		if c["name"] == name:
			return float(c["s"])
	return route_len


func _build_depot(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("chunk_props", true)
	node.add_child(body)
	var start: bool = f["type"] == "depot_start"
	var s0 := float(f["s"])
	var city_id: String = spec.get("from" if start else "to", "")
	var cname := Jobs.city_name(city_id) if city_id != "" else (origin_name if start else dest_name)
	var wall := _m(Color(0.72, 0.73, 0.74), 0.0, 0.3, 0.6)
	var roof := _m(Color(0.45, 0.47, 0.5), 0.0, 0.4, 0.5)
	var door := _m(Color(0.2, 0.22, 0.25))
	var gy := yr(s0)
	if start:
		_rbox(node, body, s0 - 58.0, -26.0, 0.0, Vector3(26.0, 8.0, 18.0), wall, 0.0, gy)
		_rbox(node, null, s0 - 58.0, -26.0, 8.0, Vector3(27.0, 0.6, 19.0), roof, 0.0, gy)
		for k in 3:
			_rbox(node, null, s0 - 66.0 + k * 8.0, -16.9, 0.0, Vector3(5.0, 5.0, 0.2), door, PI / 2.0, gy)
		var p := _route_pos(s0 - 58.0, -16.6)
		_label3d(node, "مخازن %s" % cname, Vector3(p.x, gy + 9.4, p.z), road_yaw(s0) - PI / 2.0, 140, Color(1, 0.8, 0.3), 0.014)
		# بوابة المخزن
		var arch := _m(Color(0.85, 0.2, 0.12))
		_rbox(node, body, s0 + 14.0, -road_half - 2.2, 0.0, Vector3(0.6, 7.0, 0.6), arch, 0.0, gy)
		_rbox(node, body, s0 + 14.0, road_half + 2.2, 0.0, Vector3(0.6, 7.0, 0.6), arch, 0.0, gy)
		_rbox(node, null, s0 + 14.0, 0.0, 6.6, Vector3(road_half * 2.0 + 5.0, 1.4, 0.4), arch, 0.0, gy)
		var gp := _route_pos(s0 + 13.7, 0.0)
		_label3d(node, "نقليات الرافدين — %s" % cname, Vector3(gp.x, gy + 7.3, gp.z), road_yaw(s0), 110, Color(1, 1, 1), 0.012)
	else:
		_rbox(node, body, s0 + 82.0, 0.0, 0.0, Vector3(70.0, 9.0, 22.0), wall, 0.0, gy)
		_rbox(node, null, s0 + 82.0, 0.0, 9.0, Vector3(71.0, 0.6, 23.0), roof, 0.0, gy)
		# رصيف التحميل
		_rbox(node, body, s0 + 70.0, 0.0, 0.0, Vector3(66.0, 1.3, 2.4), _m(Color(0.5, 0.5, 0.5)), 0.0, gy)
		var yellow := _m(Color(0.95, 0.75, 0.1))
		for bu in [-16.0, 0.0, 16.0]:
			_rbox(node, null, s0 + 71.2, bu, 0.0, Vector3(4.2, 4.2, 0.2), door, 0.0, gy)
			for side in [-1.9, 1.9]:
				_rbox(node, null, s0 + 52.0, bu + side, 0.0, Vector3(0.15, 0.03, 34.0), yellow, 0.0, gy + 0.02)
			var lp := _route_pos(s0 + 68.6, bu)
			_label3d(node, "رصيف %s" % Jobs.ar_num(int(bu / 16.0) + 2), Vector3(lp.x, gy + 5.2, lp.z), road_yaw(s0), 90, Color(1, 0.85, 0.3), 0.012)
		var p2 := _route_pos(s0 + 70.8, 0.0)
		_label3d(node, "مخازن %s — استلام البضاعة" % cname, Vector3(p2.x, gy + 10.4, p2.z), road_yaw(s0), 150, Color(1, 0.8, 0.3), 0.014)
		f["bays"] = [-16.0, 0.0, 16.0]
		f["dock_s"] = s0 + 68.8
	# حاويات
	var cols := [Color(0.75, 0.2, 0.15), Color(0.15, 0.4, 0.65), Color(0.2, 0.55, 0.3), Color(0.85, 0.6, 0.15)]
	for k in 6:
		var cs := s0 - 40.0 + k * 9.0 if start else s0 + 20.0 + k * 8.0
		var cu := 28.0 if start else 34.0
		_rbox(node, body, cs, cu, 0.0 if k % 3 != 2 else 2.6, Vector3(6.1, 2.6, 2.45), _m(cols[k % 4], 0.0, 0.3, 0.6), PI / 2.0, gy)
	# أعمدة إنارة الساحة
	for k in 4:
		var ls := (s0 - 60.0 + k * 22.0) if start else (s0 + 5.0 + k * 22.0)
		_lamp(node, ls, -36.0 if start else -40.0, gy, true)


func _lamp(parent: Node3D, s: float, u: float, gy: float, light := false) -> void:
	var p := _route_pos(s, u)
	var yaw := road_yaw(s) + (PI / 2.0 if u < 0.0 else -PI / 2.0)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy, p.z))
	var mi := MeshInstance3D.new()
	mi.mesh = prop_meshes["lamp"][0]
	mi.material_override = prop_mats["lamp"]
	parent.add_child(mi)
	mi.global_transform = xf
	var hd := MeshInstance3D.new()
	hd.mesh = prop_meshes["lamp_head"][0]
	hd.material_override = lamp_head_mat
	parent.add_child(hd)
	hd.global_transform = xf
	if light and lamp_lights.size() < 40:
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.8, 0.5)
		ol.omni_range = 18.0
		ol.light_energy = 2.0
		ol.shadow_enabled = false
		ol.visible = false
		parent.add_child(ol)
		ol.global_position = xf * Vector3(0, 5.6, -1.4)
		lamp_lights.append(ol)


func _build_camp(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("chunk_props", true)
	node.add_child(body)
	var s0 := float(f["s"])
	var gy := yr(s0)
	var start: bool = f["type"] == "camp_start"
	var tent := PropLib.build("tent", {})
	for k in (2 if start else 4):
		var su := s0 + (-30.0 if start else 30.0) + k * 9.0
		var uu := -14.0 if k % 2 == 0 else 14.0
		var p := _route_pos(su, uu)
		var mi := MeshInstance3D.new()
		mi.mesh = tent
		mi.material_override = _prop_material(false, "tent")
		node.add_child(mi)
		mi.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(su) + PI / 2.0), Vector3(p.x, ground_h(p.x, p.z) - 0.2, p.z))
	var flag_pole := _m(Color(0.4, 0.35, 0.3))
	_rbox(node, null, s0 + (5.0 if start else 0.0), -8.0, 0.0, Vector3(0.15, 6.0, 0.15), flag_pole, 0.0, gy)
	_rbox(node, null, s0 + (5.0 if start else 0.0), -7.2, 4.8, Vector3(1.6, 1.0, 0.05), _m(Color(0.9, 0.2, 0.1)), 0.0, gy)
	if not start:
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.55, 0.2)
		fire.omni_range = 14.0
		fire.light_energy = 2.5
		node.add_child(fire)
		var fp := _route_pos(s0 + 20.0, 0.0)
		fire.global_position = Vector3(fp.x, ground_h(fp.x, fp.z) + 1.0, fp.z)
		_rbox(node, null, s0 + 20.0, 0.0, 0.0, Vector3(1.0, 0.4, 1.0), _m(Color(1.0, 0.45, 0.1), 3.0), 0.0)
		# حلقة الوصول
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 8.0
		tm.outer_radius = 9.0
		tm.rings = 48
		tm.ring_segments = 6
		ring.mesh = tm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.2, 1.0, 0.45, 0.7)
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.emission_enabled = true
		rmat.emission = Color(0.2, 1.0, 0.45)
		rmat.emission_energy_multiplier = 2.0
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = rmat
		ring.scale = Vector3(1, 0.15, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var rp := _route_pos(s0, 0.0)
		ring.global_position = Vector3(rp.x, ground_h(rp.x, rp.z) + 0.15, rp.z)
		var lp := _route_pos(s0 + 8.0, -8.0)
		_label3d(node, dest_name, Vector3(lp.x, gy + 6.0, lp.z), road_yaw(s0), 140, Color(1, 0.85, 0.4), 0.015)


func _build_town(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("chunk_props", true)
	node.add_child(body)
	var s0 := float(f["s0"])
	var s1 := float(f["s1"])
	var small: bool = f.get("small", false)
	var xfs: Array = []
	var trng := RandomNumberGenerator.new()
	trng.seed = route_seed + int(s0)
	for side in [-1.0, 1.0]:
		var s := s0 + 10.0
		while s < s1 - 10.0:
			var skip := false
			for g in features:
				if g["type"] in ["fuel", "food", "garage", "check", "bridge", "block", "sign", "welcome"] and absf(float(g["s"]) - s) < 50.0 and (side > 0.0 or g["type"] in ["check", "bridge", "block"]):
					skip = true
			var w := trng.randf_range(9.0, 16.0)
			if not skip and trng.randf() < (0.55 if small else 0.85):
				var dpt := trng.randf_range(9.0, 15.0)
				var hgt := trng.randf_range(4.0, 8.0 if small else 15.0)
				var u: float = float(side) * (road_half + 12.0 + dpt * 0.5 + trng.randf_range(0.0, 6.0))
				var p := _route_pos(s, u)
				var gy := ground_h(p.x, p.z) - 0.4
				var xf := Transform3D(Basis(Vector3.UP, road_yaw(s)).scaled(Vector3(dpt, hgt + 0.4, w)), Vector3(p.x, gy + (hgt + 0.4) * 0.5, p.z))
				xfs.append(xf)
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(dpt, hgt + 0.4, w)
				cs.shape = bs
				body.add_child(cs)
				cs.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s)), xf.origin)
				cs.set_meta("prop", {"kind": "building", "holes": 0})
				# لوحات محلات
				if trng.randf() < 0.45:
					var shops := ["أسواق", "مطعم", "صيدلية", "كهربائيات", "حلويات", "عطارية", "مخبز", "اتصالات"]
					var lp := _route_pos(s, u - side * (dpt * 0.5 + 0.08))
					_label3d(node, shops[trng.randi() % shops.size()], Vector3(lp.x, gy + 3.4, lp.z), road_yaw(s) + PI / 2.0 * side, 64, Color(1, 0.95, 0.8), 0.012)
			s += w + trng.randf_range(2.0, 7.0)
		# إنارة
		var ls := s0 + 15.0
		while ls < s1 - 10.0:
			_lamp(node, ls, side * (road_half + 2.2), yr(ls), trng.randf() < 0.3)
			ls += 34.0
	if not xfs.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bm
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = building_mat
		node.add_child(mmi)
	# نخيل بين البيوت
	if region_at(f["s"]) in ["south", "middle", "marsh"]:
		var palms: Array = []
		for k in 24:
			var ps := trng.randf_range(s0, s1)
			var pu := (road_half + trng.randf_range(4.0, 9.0)) * (1.0 if trng.randf() < 0.5 else -1.0)
			var pp := _route_pos(ps, pu)
			palms.append(Transform3D(Basis(Vector3.UP, trng.randf() * TAU), Vector3(pp.x, ground_h(pp.x, pp.z) - 0.2, pp.z)))
		var refs := _tile_multimesh(node, prop_meshes["palm"][0], prop_mats["palm"], palms, 0.0, true)
		_tile_collisions(body, "palm", palms, refs)


func _build_bridge(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	node.add_child(body)
	var s0 := float(f["s"])
	var half := float(f["w"]) * 0.5 + 26.0
	var deck := _m(Color(0.55, 0.55, 0.53))
	var rail := _m(Color(0.75, 0.75, 0.72), 0.0, 0.5, 0.4)
	var s := s0 - half
	while s < s0 + half:
		var y := yr(s + 2.0)
		_rbox(node, body, s + 2.0, 0.0, -0.9, Vector3(road_half * 2.0 + 2.4, 0.9, 4.15), deck, 0.0, y)
		_rbox(node, body, s + 2.0, road_half + 0.9, 0.0, Vector3(0.25, 1.1, 4.1), rail, 0.0, y)
		_rbox(node, body, s + 2.0, -road_half - 0.9, 0.0, Vector3(0.25, 1.1, 4.1), rail, 0.0, y)
		s += 4.0
	for k in 5:
		var ps := s0 - half + 10.0 + k * (half * 2.0 - 20.0) / 4.0
		var y2 := yr(ps)
		_rbox(node, null, ps, 0.0, -9.0 - (y2 - 0.0), Vector3(3.0, y2 + 8.2, 2.2), deck, 0.0, 0.0)
	var lp := _route_pos(s0 - half - 8.0, road_half + 3.0)
	_road_sign(node, s0 - half - 8.0, road_half + 3.5, "جسر %s" % f["name"], Color(0.1, 0.3, 0.55), 4.4, 1.6)


func _build_checkpoint(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("chunk_props", true)
	node.add_child(body)
	var s0 := float(f["s"])
	var gy := yr(s0)
	var white := _m(Color(0.92, 0.92, 0.9))
	var red := _m(Color(0.8, 0.12, 0.1))
	# كتل كونكريت على الجانبين
	var s := s0 - 46.0
	var k := 0
	while s < s0 + 18.0:
		for side in [-1.0, 1.0]:
			_rbox(node, body, s, side * (road_half + 0.9), 0.0, Vector3(0.6, 0.85, 2.9), red if k % 2 == 0 else white, 0.0, yr(s))
		s += 3.1
		k += 1
	# كشكات
	var booth := _m(Color(0.42, 0.45, 0.35))
	for side in [-1.0, 1.0]:
		_rbox(node, body, s0, side * (road_half + 4.2), 0.0, Vector3(2.6, 2.7, 2.6), booth, 0.0, gy)
		_rbox(node, null, s0, side * (road_half + 4.2), 2.7, Vector3(3.2, 0.25, 3.2), _m(Color(0.3, 0.32, 0.25)), 0.0, gy)
		_rbox(node, null, s0 - 1.31, side * (road_half + 4.2), 1.2, Vector3(1.6, 0.9, 0.06), _m(Color(0.2, 0.3, 0.4), 0.0, 0.5, 0.1), 0.0, gy)
		# جنود
		var sol := _m(Color(0.35, 0.38, 0.28))
		var skin := _m(Color(0.75, 0.55, 0.42))
		_rbox(node, null, s0 - 3.0, side * (road_half + 2.6), 0.0, Vector3(0.5, 1.25, 0.35), sol, 0.0, gy)
		_rbox(node, null, s0 - 3.0, side * (road_half + 2.6), 1.25, Vector3(0.28, 0.3, 0.28), skin, 0.0, gy)
		_rbox(node, null, s0 - 3.0, side * (road_half + 2.6), 1.52, Vector3(0.34, 0.1, 0.34), sol, 0.0, gy)
	# علم العراق
	_rbox(node, null, s0 + 2.0, road_half + 7.0, 0.0, Vector3(0.12, 7.0, 0.12), _m(Color(0.7, 0.7, 0.7), 0.0, 0.6, 0.4), 0.0, gy)
	_rbox(node, null, s0 + 2.0, road_half + 7.85, 6.5, Vector3(1.6, 0.33, 0.04), red, 0.0, gy)
	_rbox(node, null, s0 + 2.0, road_half + 7.85, 6.17, Vector3(1.6, 0.33, 0.04), white, 0.0, gy)
	_rbox(node, null, s0 + 2.0, road_half + 7.85, 5.84, Vector3(1.6, 0.33, 0.04), _m(Color(0.05, 0.05, 0.05)), 0.0, gy)
	_rbox(node, null, s0 + 2.0, road_half + 7.85, 6.25, Vector3(0.7, 0.14, 0.05), _m(Color(0.05, 0.45, 0.2)), 0.0, gy)
	# ذراع السيطرة
	var arm_root := Node3D.new()
	node.add_child(arm_root)
	var ap := _route_pos(s0 - 1.5, road_half + 0.4)
	arm_root.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s0)), Vector3(ap.x, gy + 1.05, ap.z))
	var arm := Node3D.new()
	arm_root.add_child(arm)
	for i in 8:
		var bm := BoxMesh.new()
		bm.size = Vector3(road_half * 2.0 / 8.0, 0.14, 0.14)
		var seg := MeshInstance3D.new()
		seg.mesh = bm
		seg.material_override = red if i % 2 == 0 else white
		seg.position = Vector3(-(i + 0.5) * road_half * 2.0 / 8.0, 0, 0)
		arm.add_child(seg)
	f["arm"] = arm
	f["state"] = "wait"
	f["t"] = 0.0
	# المطبات (خطوط صفرة)
	for off in [-34.0, -22.0]:
		_rbox(node, null, s0 + off, 0.0, 0.0, Vector3(road_half * 2.0, 0.03, 0.5), _m(Color(0.95, 0.8, 0.1)), 0.0, yr(s0 + off) + 0.12)
	_road_sign(node, s0 - 170.0, road_half + 3.5, "سيطرة أمامك\nخفف السرعة", Color(0.7, 0.45, 0.05), 4.6, 2.0)
	_road_sign(node, s0 - 14.0, road_half + 2.8, "قف — تفتيش", Color(0.75, 0.1, 0.08), 3.4, 1.3)


func _build_station(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	body.set_meta("chunk_props", true)
	node.add_child(body)
	var s0 := float(f["s"])
	var gy := yr(s0)
	var cu := road_half + 18.0
	var names := {"fuel": ["محطة وقود الفرات", "محطة وقود دجلة", "محطة الرافدين للوقود", "محطة بابل"],
		"food": ["مطعم وكافتريا أبو علي", "مطعم الطريق السريع", "كباب أبو جاسم", "استراحة المسافرين"],
		"garage": ["كراج تصليح وبنچر", "تصليح شاحنات أبو حسين", "كراج الطريق", "بنچرچي الخير"]}
	var tp: String = f["type"]
	var nm: String = names[tp][int(s0) % names[tp].size()]
	f["name"] = nm
	match tp:
		"fuel":
			var brand := _m(Color(0.1, 0.55, 0.3))
			for a in [-7.0, 7.0]:
				for b in [-4.0, 4.0]:
					_rbox(node, body, s0 + a, cu + b, 0.0, Vector3(0.45, 5.4, 0.45), _m(Color(0.85, 0.85, 0.85)), 0.0, gy)
			_rbox(node, null, s0, cu, 5.4, Vector3(10.5, 0.7, 18.0), _m(Color(0.95, 0.95, 0.95)), 0.0, gy)
			_rbox(node, null, s0, cu, 5.35, Vector3(10.7, 0.25, 18.2), brand, 0.0, gy)
			for a2 in [-5.0, 0.0, 5.0]:
				_rbox(node, body, s0 + a2, cu, 0.0, Vector3(0.9, 1.8, 0.6), _m(Color(0.9, 0.9, 0.88)), 0.0, gy)
				_rbox(node, null, s0 + a2, cu, 1.8, Vector3(0.95, 0.3, 0.65), brand, 0.0, gy)
			_rbox(node, body, s0 + 18.0, cu + 10.0, 0.0, Vector3(12.0, 4.0, 8.0), _m(Color(0.9, 0.88, 0.82)), PI / 2.0, gy)
		"food":
			_rbox(node, body, s0 + 4.0, cu + 8.0, 0.0, Vector3(16.0, 4.5, 10.0), _m(Color(0.88, 0.8, 0.62)), PI / 2.0, gy)
			for k in 6:
				_rbox(node, null, s0 - 4.0 + k * 3.0, cu + 2.2, 3.4, Vector3(2.9, 0.12, 2.6), _m(Color(0.8, 0.15, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.9)), 0.0, gy)
			for k2 in 4:
				_rbox(node, null, s0 - 3.0 + k2 * 4.0, cu + 1.0, 0.0, Vector3(1.1, 0.75, 1.1), _m(Color(0.95, 0.95, 0.95)), 0.0, gy)
			var cl := OmniLight3D.new()
			cl.light_color = Color(1.0, 0.85, 0.6)
			cl.omni_range = 16.0
			cl.light_energy = 1.6
			node.add_child(cl)
			var lp2 := _route_pos(s0 + 4.0, cu + 1.5)
			cl.global_position = Vector3(lp2.x, gy + 3.0, lp2.z)
			lamp_lights.append(cl)
			cl.visible = false
		"garage":
			var gw := _m(Color(0.55, 0.57, 0.6), 0.0, 0.3, 0.6)
			_rbox(node, body, s0, cu + 9.5, 0.0, Vector3(14.0, 5.5, 0.4), gw, 0.0, gy)
			_rbox(node, body, s0 - 7.0, cu + 4.5, 0.0, Vector3(0.4, 5.5, 10.0), gw, 0.0, gy)
			_rbox(node, body, s0 + 7.0, cu + 4.5, 0.0, Vector3(0.4, 5.5, 10.0), gw, 0.0, gy)
			_rbox(node, null, s0, cu + 4.5, 5.5, Vector3(14.6, 0.4, 10.6), _m(Color(0.4, 0.42, 0.45)), 0.0, gy)
			var tires := PropLib.build("tires", {})
			for k3 in 5:
				var tp3 := _route_pos(s0 - 11.0, cu + k3 * 1.6)
				var mi := MeshInstance3D.new()
				mi.mesh = tires
				mi.material_override = prop_mats["tires"]
				node.add_child(mi)
				mi.global_transform = Transform3D(Basis(), Vector3(tp3.x, gy, tp3.z))
	# لوحة المحطة
	var sp := _route_pos(s0 - 26.0, road_half + 4.0)
	_rbox(node, null, s0 - 26.0, road_half + 4.0, 0.0, Vector3(0.3, 6.5, 0.3), _m(Color(0.6, 0.6, 0.62)), 0.0, gy)
	var sign_col := {"fuel": Color(0.1, 0.55, 0.3), "food": Color(0.75, 0.25, 0.1), "garage": Color(0.2, 0.3, 0.55)}
	_rbox(node, null, s0 - 26.0, road_half + 4.0, 5.0, Vector3(5.0, 1.8, 0.2), _m(sign_col[tp], 0.4), 0.0, gy)
	var lp3 := _route_pos(s0 - 26.12, road_half + 4.0)
	_label3d(node, nm, Vector3(lp3.x, gy + 5.9, lp3.z), road_yaw(s0), 72, Color(1, 1, 1), 0.012)
	_lamp(node, s0 + 22.0, road_half + 2.5, gy, true)
	f["zone"] = [s0 - 34.0, s0 + 34.0, road_half + 1.5, road_half + 36.0]
	# لوحة تنبيه قبلها
	var ahead_txt := {"fuel": "محطة وقود بعد ٥٠٠ م", "food": "مطعم واستراحة بعد ٥٠٠ م", "garage": "تصليح شاحنات بعد ٥٠٠ م"}
	if _far_from(s0 - 260.0, 40.0, ["sign", "check", "bridge", "welcome"]):
		_road_sign(node, s0 - 260.0, road_half + 3.5, ahead_txt[tp], Color(0.1, 0.3, 0.55), 4.6, 1.4)


func _build_ring(f: Dictionary) -> void:
	var s0 := float(f["s"])
	var u := float(f["u"])
	var p := _route_pos(s0, u)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 6.2
	tm.outer_radius = 7.0
	tm.rings = 40
	tm.ring_segments = 8
	mi.mesh = tm
	var col := Color(1.0, 0.8, 0.15) if f["race"] else Color(0.3, 0.85, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s0)) * Basis(Vector3.RIGHT, PI / 2.0), Vector3(p.x, ground_h(p.x, p.z) + 5.0, p.z))
	f["node"] = mi
	f["mat"] = mat


func _build_stuck(f: Dictionary) -> void:
	var s0 := float(f["s"])
	var u := float(f["u"])
	var p := _route_pos(s0, u)
	var m := CarModel.build("pickup" if style != "marsh" else "jeep", Color(0.7, 0.66, 0.6))
	var r: Node3D = m["root"]
	add_child(r)
	r.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s0) + 0.6) * Basis(Vector3.FORWARD, 0.12), Vector3(p.x, ground_h(p.x, p.z) - 0.35, p.z))
	var pm = m.get("paint_mat")
	if pm is ShaderMaterial:
		(pm as ShaderMaterial).set_shader_parameter("dust", 0.8)
	f["node"] = r
	var tri := _m(Color(1.0, 0.3, 0.1), 1.5)
	var tp := _route_pos(s0 - 7.0, u)
	var tmi := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(0.7, 0.6, 0.05)
	tmi.mesh = pr
	tmi.material_override = tri
	add_child(tmi)
	tmi.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s0)), Vector3(tp.x, ground_h(tp.x, tp.z) + 0.3, tp.z))
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.5, 0.1)
	beacon.omni_range = 12.0
	beacon.light_energy = 2.0
	add_child(beacon)
	beacon.global_position = Vector3(p.x, ground_h(p.x, p.z) + 2.5, p.z)
	f["beacon"] = beacon


func _build_block(f: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := StaticBody3D.new()
	node.add_child(body)
	var s0 := float(f["s"])
	var gy := yr(s0)
	var red := _m(Color(0.85, 0.15, 0.1))
	var white := _m(Color(0.95, 0.95, 0.93))
	var k := 0
	var u := -road_half - 1.0
	while u < road_half + 1.5:
		_rbox(node, body, s0, u, 0.0, Vector3(1.8, 0.9, 0.6), red if k % 2 == 0 else white, 0.0, gy)
		u += 1.9
		k += 1
	var cone := _m(Color(1.0, 0.45, 0.05))
	for i in 8:
		_rbox(node, null, s0 - 30.0 + i * 3.5, -road_half + 0.5 + i * (road_half * 2.0 - 1.0) / 8.0, 0.0, Vector3(0.35, 0.7, 0.35), cone, 0.0, yr(s0 - 30.0 + i * 3.5))
	_road_sign(node, s0 - 120.0, road_half + 3.5, "الطريق مغلق أمامك\nتحويلة يمين ←", Color(0.85, 0.5, 0.05), 4.8, 2.0)
	_road_sign(node, s0 - 6.0, -road_half - 3.0, "تحويلة ←", Color(0.85, 0.5, 0.05), 3.0, 1.2)


# ================================================================ الحمولة والمقطورات
func _setup_cargo_and_trailers() -> void:
	var cid: String = spec.get("cargo", "")
	cargo = Jobs.CARGO.get(cid, {})
	var ntr := int(spec.get("trailers", 0))
	var kind: String = spec.get("trailer_kind", cargo.get("trailer", ""))
	cargo_tons = float(cargo.get("tons", 0.0))
	if ntr >= 2:
		cargo_tons *= 1.6
	var is_semi: bool = str(car.stats.get("body", "")).begins_with("semi")
	if ntr >= 1 and kind != "":
		var double := ntr >= 2 and kind != "water_small"
		var paint := Jobs.trailer_color() if is_semi else Color(0.85, 0.85, 0.82)
		var opts := {"cargo": cid, "label": "نقليات الرافدين" if spec.get("kind", "") != "contract" else "IBRA نقليات"}
		for d in Game.car_deco(car.car_id):
			if str(d).begins_with("slogan:"):
				opts["slogan"] = CarModel.SLOGANS[clampi(int(str(d).get_slice(":", 1)), 0, CarModel.SLOGANS.size() - 1)]
		var ccol: Color = cargo.get("color", Color(0.8, 0.2, 0.1))
		var t1 := TruckTrailer.new()
		add_child(t1)
		t1.setup(kind, ccol, paint, false, double, opts)
		trailers.append(t1)
		if double:
			var t2 := TruckTrailer.new()
			add_child(t2)
			t2.setup(kind, ccol, paint, true, true, opts)
			trailers.append(t2)
	_place_trailers()
	for t in trailers:
		_link_trailer(t)
	_apply_load()
	# حمولة بالحوض بدون مقطورة
	if trailers.is_empty() and cid != "" and car.stats.get("body", "") in ["pickup", "truck", "jeep", "monster"]:
		var bed := Node3D.new()
		car.model["root"].add_child(bed)
		var cc: Color = cargo.get("color", Color(0.8, 0.6, 0.3))
		var y := 1.45 if car.stats["body"] != "monster" else 2.5
		var zc := 1.45 if car.stats["body"] != "truck" else 0.8
		for i in 4:
			CarModel._box(bed, Vector3(0.7, 0.45, 0.6), Vector3(-0.38 + (i % 2) * 0.76, y + 0.23 + int(i / 2) * 0.0, zc - 0.35 + int(i / 2) * 0.68), CarModel.mat("plain", cc))


func _link_trailer(t: TruckTrailer) -> void:
	t.body.add_collision_exception_with(car)
	car.add_collision_exception_with(t.body)
	for o in trailers:
		if o != t:
			t.body.add_collision_exception_with(o.body)
	t.hit_prop.connect(_on_trailer_hit.bind(t))


func _apply_load() -> void:
	var load := 0.0
	for t in trailers:
		load += t.mass_empty
	load += cargo_tons * 1000.0
	if towing:
		load += 1300.0
	var lvl := Game.upgrade_level(car.car_id, "brakes")
	car.set_load(load * 0.6, 0.55 + 0.08 * lvl)


func _place_trailers() -> void:
	var prev := car.global_transform * (car.model["hitch"] as Vector3)
	var fwd := -car.global_basis.z
	for t in trailers:
		t.place(prev, fwd, self)
		prev = t.rear_hitch_world()
		fwd = t.forward()


func _update_trailers(delta: float) -> void:
	if trailers.is_empty():
		return
	var prev := car.global_transform * (car.model["hitch"] as Vector3)
	var pfwd := -car.global_basis.z
	var braking := car.brake_in > 0.1 and car.speed > 0.5
	for i in trailers.size():
		var t: TruckTrailer = trailers[i]
		t.step(prev, self, delta)
		# حد الانطواء
		var a2 := Vector2(pfwd.x, pfwd.z).normalized()
		var b2 := Vector2(t.forward().x, t.forward().z).normalized()
		var ang := a2.angle_to(b2)
		var lim := deg_to_rad(82.0 if t.kind != "car" else 70.0)
		if absf(ang) > lim:
			var dir := a2.rotated(signf(ang) * lim)
			t.axle2 = Vector2(prev.x, prev.z) - dir * t.L
			t.step(prev, self, 0.0)
			jack_warn_t = 1.5
			if absf(car.speed) > 2.0:
				damage = minf(damage + 0.0015 * float(cargo.get("fragile", 0.5)), 1.0)
		elif absf(ang) > deg_to_rad(65.0):
			jack_warn_t = maxf(jack_warn_t, 0.4)
		t.set_brake_light(braking, car.lights_on)
		t.set_slosh(slosh)
		prev = t.rear_hitch_world()
		pfwd = t.forward()
	# تمايل السائل: يدفع الشاحنة يم برا المنعطف
	if cargo.get("liquid", false):
		var right := car.global_basis.x
		var fwd := -car.global_basis.z
		var acc := (car.linear_velocity - last_v) / maxf(delta, 0.001)
		var lat := acc.dot(right)
		var lon := acc.dot(fwd)
		slosh_v += (-9.0 * slosh - 1.6 * slosh_v - lat * 0.16) * delta
		slosh = clampf(slosh + slosh_v * delta, -1.0, 1.0)
		surge_v += (-7.0 * surge - 1.4 * surge_v - lon * 0.12) * delta
		surge = clampf(surge + surge_v * delta, -1.0, 1.0)
		var liq := cargo_tons * 1000.0
		var hitch := car.global_transform * (car.model["hitch"] as Vector3)
		car.apply_force(right * slosh * liq * 1.3 + fwd * surge * liq * 0.8, hitch - car.global_position)


func _on_trailer_hit(b: Node, shape_idx: int, spd: float, t: TruckTrailer) -> void:
	if finished or b == null or not b.has_meta("chunk_props") or not (b is StaticBody3D):
		return
	var sb := b as StaticBody3D
	var owner_id := sb.shape_find_owner(shape_idx)
	var cs := sb.shape_owner_get_owner(owner_id) as CollisionShape3D
	if cs == null or not cs.has_meta("prop") or cs.has_meta("broken"):
		return
	var info: Dictionary = cs.get_meta("prop")
	var kind: String = info["kind"]
	if not BREAK.has(kind) or kind == "building":
		if absf(spd) > 2.0:
			damage = minf(damage + 0.02 * float(cargo.get("fragile", 0.5)), 1.0)
			_damage_toast()
		return
	if absf(spd) * 3.6 < 4.0:
		return
	cs.set_meta("broken", true)
	var rule: Array = BREAK[kind]
	var keep_v := car.linear_velocity / maxf(float(rule[2]), 0.1)
	call_deferred("_break_prop", cs, info, keep_v, rule)
	damage = minf(damage + 0.012 * float(cargo.get("fragile", 0.5)), 1.0)
	_damage_toast()


var _dmg_shown := 0.0
var _dmg_toast_t := 0.0


func _damage_toast() -> void:
	if cargo.is_empty():
		return
	if damage - _dmg_shown > 0.01 and _dmg_toast_t <= 0.0:
		hud.toast("تضررت الحمولة! سلامتها %d%%" % int(round((1.0 - damage) * 100.0)), Color(1, 0.55, 0.4), 2.0)
		_dmg_shown = damage
		_dmg_toast_t = 1.5


var settle_t := 2.5


func _cargo_damage(delta: float) -> void:
	var dv := car.linear_velocity - last_v
	var a := dv.length() / maxf(delta, 0.001)
	last_v = car.linear_velocity
	if settle_t > 0.0:
		settle_t -= delta
		return
	var fr := float(cargo.get("fragile", 0.0))
	var straps := 1.0 - 0.12 * Jobs.trailer_level("straps") if not trailers.is_empty() else 1.0
	var susp := 1.0 - 0.05 * Game.upgrade_level(car.car_id, "suspension")
	if a > 15.0 and fr > 0.0:
		damage = minf(damage + (a - 15.0) * 0.00011 * fr * straps * susp, 1.0)
	if a > 55.0:
		car_damage = minf(car_damage + (a - 55.0) * 0.0003, 1.0)
	if car.is_flipped() and not flipped_once and car.linear_velocity.length() < 4.0:
		flipped_once = true
		if fr > 0.0:
			damage = minf(damage + 0.3 * clampf(fr, 0.3, 1.5), 1.0)
		car_damage = minf(car_damage + 0.2, 1.0)
		if exam_mode:
			exam_faults.append("انقلبت السيارة")
	if not car.is_flipped():
		flipped_once = false
	_dmg_toast_t = maxf(_dmg_toast_t - delta, 0.0)
	_damage_toast()
	if damage >= 0.999 and fr > 0.0 and goal == "deliver" and not finished:
		_fail("الحمولة تلفت بالكامل!")


# ================================================================ كل فريم
var _last_car_pos := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if car == null:
		return
	super(delta)
	if finished:
		car.controls = false
		return
	# إذا انتقلت السيارة فجأة (إنقاذ أو تعديل) نرجّع المقطورات مستقيمة وراها
	if car.global_position.distance_to(_last_car_pos) > 5.0 and _last_car_pos != Vector3.ZERO:
		_place_trailers()
	_last_car_pos = car.global_position
	_update_trailers(delta)
	_cargo_damage(delta)
	_route_logic(delta)
	_update_sheep(delta)
	if autopilot:
		_autopilot()


func _process(delta: float) -> void:
	if car == null:
		return
	super(delta)
	if not finished:
		hours_elapsed += delta / DAY_SECONDS_PER_HOUR
		var moving := absf(car.speed) > 2.0
		if moving and not exam_mode and goal != "race":
			fatigue = minf(fatigue + delta / DAY_SECONDS_PER_HOUR / 9.0, 1.0)
	_stream()
	var cp := car.global_position
	if water_mi:
		water_mi.global_position = Vector3(snappedf(cp.x, 8.0), water_level, snappedf(cp.z, 8.0))
	if horizon_mi:
		horizon_mi.global_position = Vector3(cp.x, horizon_mi.global_position.y, cp.z)
	for ew in car.model.get("extra_wheels", []):
		var src: Dictionary = car.wheels[int(ew["src"])]
		(ew["spin"] as Node3D).rotation.x = -float(src["spin"])
	# تعب: رمش ونعاس وسحب بسيط للسكان
	if fatigue > 0.7 and not finished:
		drift_t -= delta
		if drift_t <= 0.0:
			drift_t = randf_range(6.0, 14.0) * (1.4 - fatigue)
			fatigue_blink = 0.9
			if fatigue > 0.85:
				car.steer_bias = randf_range(-0.12, 0.12)
				get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(car): car.steer_bias = _burst_bias())
	fatigue_blink = maxf(fatigue_blink - delta * 1.4, 0.0)
	jack_warn_t = maxf(jack_warn_t - delta, 0.0)
	for f in features:
		if f["type"] == "ring" and f.has("node") and not f["done"]:
			var n: Node3D = f["node"]
			n.rotate_object_local(Vector3.UP, delta * 0.8)
	if mhud:
		mhud.refresh(delta)
	if debug_fps:
		_dbg_t += delta
		if _dbg_t > 2.0:
			_dbg_t = 0.0
			print("FPS %d  s=%.0f u=%.1f kmh=%.0f tiles=%d pend=%d dmg=%.3f fuel=%.0f hour=%.1f" % [Engine.get_frames_per_second(), car_s, car_u, absf(car.speed) * 3.6, tiles.size(), tile_pending.size(), damage, car.fuel, hour])
			print("   thr=%.2f brk=%.2f gnd=%d slip=%.2f grip=%.2f mass=%.0f base=%.0f vel=%s sm=%.2f top=%.1f hb=%s ctrl=%s" % [car.throttle_in, car.brake_in, car.grounded_count, car.slip, car.surface_grip, car.mass, car.base_mass, str(car.linear_velocity), car.speed_mult, car.stats["top_speed"], str(car.handbrake), str(car.controls)])


func _burst_bias() -> float:
	if car.burst_wheel < 0:
		return 0.0
	return 0.05 if car.burst_wheel % 2 == 1 else -0.05


func surface_update() -> void:
	var p := car.global_position
	var ru := to_route(p.x, p.z)
	var g: float = biome["grip"]
	if paved and absf(ru.y) < road_half + 0.8:
		g = 1.0
	elif _in_pad(ru, 0.0):
		g = maxf(g, 0.9)
	if style == "marsh" and car.water_depth > -0.3:
		g = 0.55
	g *= lerpf(1.0, 0.8, wet_acc)
	g *= lerpf(1.0, 0.85, clampf(snow_acc + base_snow * 0.5, 0.0, 1.0))
	g *= 1.0 + 0.03 * Game.upgrade_level(car.car_id, "tires")
	car.surface_grip = g


func _near_garage() -> bool:
	return false


func _spot_ok(p: Vector3, min_up: float) -> bool:
	var h := ground_h(p.x, p.z)
	if has_water and h < water_level + 0.6:
		return false
	return normal_at(p.x, p.z).y >= min_up


func _is_safe_spot(p: Vector3) -> bool:
	return _spot_ok(p, 0.9)


## الإنقاذ: نرجعك على الطريق بالسايد الأيمن، باتجاه السفر
func _rescue(msg: String, penalty: bool) -> void:
	var p := car.global_position
	var ru := to_route(p.x, p.z)
	var s := clampf(ru.x - 12.0, -30.0, route_len + 40.0)
	var u := road_half * 0.45 if style not in ["desert"] else 0.0
	var tp := _route_pos(s, u)
	var y := ground_h(tp.x, tp.z) + 1.5
	car.global_transform = Transform3D(Basis(Vector3.UP, road_yaw(s)), Vector3(tp.x, y, tp.z))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	still_ref = car.global_position
	still_timer = 0.0
	stuck_timer = 0.0
	water_timer = 0.0
	drown_timer = 0.0
	flip_timer = 0.0
	if penalty:
		car.fuel = maxf(car.fuel - car.stats["fuel"] * 0.05, 0.0)
	_place_trailers()
	_last_car_pos = car.global_position
	hud.toast(msg, Color(1, 0.6, 0.4), 3.0)
	audio.play("error")


## T مرتين أو من القائمة: مساعدة الطريق (تعديل + بانزين) بأجرة
func _tow() -> void:
	get_tree().paused = false
	paused = false
	hud.show_pause(false)
	if finished:
		return
	if lesson_id != "":
		Game.goto("drive", spec)
		return
	car.fuel = maxf(car.fuel, car.stats["fuel"] * 0.3)
	repairs += 150
	_rescue("وصلت مساعدة الطريق: عدّلوك وعبّولك بانزين (١٥٠)", false)


func _break_reward(kind: String) -> void:
	broken_props += 1
	if kind in ["house", "barn", "shack", "cabin", "mudhif", "building"]:
		fines += 80
		hud.toast("خربت ملك الناس! غرامة ٨٠", Color(1, 0.5, 0.4), 2.5)
		if exam_mode:
			exam_faults.append("صدمت بناية")
	elif kind in ["pole", "lamp", "palm", "tree"]:
		fines += 25
		if exam_mode and exam_faults.size() < 12:
			exam_faults.append("صدمت عمود أو شجرة")


func _on_car_hit(rid: RID, body: Node, body_shape_index: int, local: int) -> void:
	if body != null and body.has_meta("chunk_props"):
		props_body = body as StaticBody3D
	super(rid, body, body_shape_index, local)


# ================================================================ منطق الرحلة
func _route_logic(delta: float) -> void:
	var p := car.global_position
	var ru := to_route(p.x, p.z)
	car_s = ru.x
	car_u = ru.y
	max_s = maxf(max_s, car_s)
	if lesson_id != "":
		return
	var kmh := absf(car.speed) * 3.6
	station_here = {}
	for f in features:
		var tp: String = f["type"]
		match tp:
			"fuel", "food", "garage":
				var z: Array = f.get("zone", [])
				if not z.is_empty() and car_s > float(z[0]) and car_s < float(z[1]) and car_u > float(z[2]) and car_u < float(z[3]):
					station_here = f
			"check":
				_checkpoint_logic(f, kmh, delta)
			"ring":
				if not f["done"]:
					var fs := float(f["s"])
					if absf(car_s - fs) < 5.0 and absf(car_u - float(f["u"])) < 7.5:
						f["done"] = true
						rings_done += 1
						(f["node"] as Node3D).visible = false
						audio.play("pickup")
						if f["race"]:
							race_time += 4.0
							hud.toast("حلقة! +٤ ثواني", Color(1, 0.85, 0.3), 1.2)
					elif car_s > fs + 18.0 and f["race"]:
						f["done"] = true
						(f["node"] as Node3D).visible = false
						race_time -= 6.0
						hud.toast("فاتتك حلقة! -٦ ثواني", Color(1, 0.5, 0.4), 2.0)
						audio.play("error")
			"blowout":
				if not f["done"] and car_s > float(f["s"]):
					f["done"] = true
					car.burst_wheel = 2 + (randi() % 2)
					car.speed_mult = 0.78
					car.steer_bias = _burst_bias()
					audio.play("crash", 2.0)
					hud.toast("طاااخ! انفجر تاير!", Color(1, 0.45, 0.3), 3.0)
					hud.toast("بدّله بأقرب كراج، أو وكّف واضغط E مطولاً حتى تركّب الاحتياطي", Color(1, 0.85, 0.6), 6.0)
			"sheep":
				if not f["spawned"] and car_s > float(f["s"]) - 330.0:
					_spawn_sheep(f)
	# تبديل التاير الاحتياطي (E مطولاً وأنت واكف)
	if car.burst_wheel >= 0 and not spare_used and kmh < 2.0 and station_here.is_empty() and Input.is_action_pressed("interact"):
		hold_e += delta
		if hold_e >= 4.0:
			hold_e = 0.0
			spare_used = true
			_fix_tire()
			hud.toast("ركّبت التاير الاحتياطي ✓", Color(0.6, 1, 0.7), 3.0)
	else:
		hold_e = 0.0
	# امتحان: السرعة
	if exam_mode:
		var limit := 60.0 if _in_town(car_s) else 90.0
		if kmh > limit + 8.0:
			exam_speed_t += delta
			if exam_speed_t > 2.0:
				exam_speed_t = -6.0
				exam_faults.append("تجاوزت السرعة (%d كم/س)" % int(limit))
				hud.toast("الفاحص: خفف! السرعة هنا %d" % int(limit), Color(1, 0.5, 0.4), 3.0)
		elif exam_speed_t > 0.0:
			exam_speed_t = 0.0
		else:
			exam_speed_t = minf(exam_speed_t + delta, 0.0)
	# السباق
	if goal == "race":
		race_time -= delta
		if race_time <= 0.0:
			_fail("خلص الوقت!")
			return
		if car_s >= route_len and absf(car_u) < 14.0:
			_deliver()
			return
	if car.global_position.y < -40.0:
		_rescue("رجعناك للطريق", false)


func _in_town(s: float) -> bool:
	for f in features:
		if f["type"] == "town" and s > float(f["s0"]) and s < float(f["s1"]):
			return true
	return false


func _checkpoint_logic(f: Dictionary, kmh: float, delta: float) -> void:
	var fs := float(f["s"])
	var st: String = f["state"]
	if st == "wait":
		if car_s > fs - 26.0 and car_s < fs - 2.0 and absf(car_u) < road_half and kmh < 4.0:
			f["state"] = "inspect"
			f["t"] = 2.6
			hud.toast("الجندي: السلام عليكم... هويتك أخي", Color(0.85, 0.95, 1.0), 2.4)
		elif car_s > fs + 1.0:
			f["state"] = "passed"
			fines += 100
			hud.toast("عبرت السيطرة بدون توقف! غرامة ١٠٠", Color(1, 0.4, 0.3), 4.0)
			audio.play("error")
			_open_arm(f)
			if exam_mode:
				exam_faults.append("ما وكفت بالسيطرة")
	elif st == "inspect":
		if kmh > 6.0:
			f["state"] = "wait"
			hud.toast("الجندي: وكّف! بعدنا ما خلصنا التفتيش", Color(1, 0.7, 0.4), 2.5)
		else:
			f["t"] = float(f["t"]) - delta
			if float(f["t"]) <= 0.0:
				f["state"] = "open"
				checkpoint_ok += 1
				_open_arm(f)
				var lines := ["الله وياك، تفضل", "مع السلامة أخي، طريقك أخضر", "تسلم، انتبه للطريق", "الله يحفظك، تفضل"]
				hud.toast("الجندي: " + lines[randi() % lines.size()], Color(0.6, 1, 0.7), 3.0)
				audio.play("fuel")


func _open_arm(f: Dictionary) -> void:
	var arm: Node3D = f.get("arm")
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation:z", -1.35, 1.0).set_trans(Tween.TRANS_SINE)


func _fix_tire() -> void:
	car.burst_wheel = -1
	car.speed_mult = 1.0 if car_damage < 0.5 else 0.88
	car.steer_bias = 0.0


# ================================================================ المواشي
func _spawn_sheep(f: Dictionary) -> void:
	f["spawned"] = true
	var root := Node3D.new()
	add_child(root)
	var wool := _m(Color(0.92, 0.9, 0.85))
	var dark := _m(Color(0.12, 0.1, 0.09))
	var list: Array = []
	var fs := float(f["s"])
	var dir := 1.0 if randf() < 0.5 else -1.0
	for i in 18:
		var n := Node3D.new()
		root.add_child(n)
		CarModel._box(n, Vector3(0.55, 0.5, 0.95), Vector3(0, 0.62, 0), wool)
		CarModel._box(n, Vector3(0.25, 0.28, 0.3), Vector3(0, 0.82, -0.58), dark)
		for lx in [-0.18, 0.18]:
			for lz in [-0.32, 0.32]:
				CarModel._box(n, Vector3(0.09, 0.4, 0.09), Vector3(lx, 0.2, lz), dark)
		var s := fs + randf_range(-9.0, 9.0)
		var u := -dir * (road_half + randf_range(6.0, 22.0))
		list.append({"node": n, "s": s, "u": u, "alive": true, "spd": randf_range(0.9, 1.4), "ph": randf() * TAU})
	# الراعي
	var sh := Node3D.new()
	root.add_child(sh)
	CarModel._box(sh, Vector3(0.6, 1.4, 0.45), Vector3(0, 0.7, 0), _m(Color(0.35, 0.3, 0.25)))
	CarModel._box(sh, Vector3(0.32, 0.32, 0.32), Vector3(0, 1.58, 0), _m(Color(0.7, 0.52, 0.4)))
	CarModel._box(sh, Vector3(0.4, 0.12, 0.4), Vector3(0, 1.78, 0), _m(Color(0.85, 0.85, 0.82)))
	CarModel._box(sh, Vector3(0.05, 1.6, 0.05), Vector3(0.38, 0.8, -0.1), dark)
	list.append({"node": sh, "s": fs - 12.0, "u": -dir * (road_half + 24.0), "alive": true, "spd": 1.0, "ph": 0.0, "shepherd": true})
	sheep_groups.append({"list": list, "dir": dir, "boost": 0.0})
	hud.toast("انتبه! غنم تعبر الطريق — خفف واضغط H (زمّور)", Color(1, 0.85, 0.4), 4.0)


func _update_sheep(delta: float) -> void:
	for g in sheep_groups:
		g["boost"] = maxf(float(g["boost"]) - delta, 0.0)
		var dir: float = g["dir"]
		var mult := 2.4 if float(g["boost"]) > 0.0 else 1.0
		for sp in g["list"]:
			var n: Node3D = sp["node"]
			if not sp["alive"]:
				continue
			var target := dir * (road_half + 26.0)
			var u: float = sp["u"]
			if absf(target - u) > 0.5:
				u = move_toward(u, target, float(sp["spd"]) * mult * delta)
				sp["u"] = u
			var s2: float = sp["s"] + sin(Time.get_ticks_msec() / 900.0 + float(sp["ph"])) * 0.02
			sp["s"] = s2
			var pos := _route_pos(s2, u)
			pos.y = ground_h(pos.x, pos.z)
			var yaw := road_yaw(s2) + (-PI / 2.0 if dir > 0.0 else PI / 2.0)
			n.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
			if sp.get("shepherd", false):
				continue
			# دهس
			var hit := false
			if Vector2(pos.x - car.global_position.x, pos.z - car.global_position.z).length() < 2.4 and absf(car.speed) > 1.5:
				hit = true
			for t in trailers:
				var tt: TruckTrailer = t
				var lp: Vector3 = tt.global_transform.affine_inverse() * pos
				if absf(lp.x) < tt.body_w * 0.5 + 0.4 and lp.z > tt.front_z and lp.z < tt.rear_z and absf(tt.speed) > 1.5:
					hit = true
			if hit:
				sp["alive"] = false
				fines += 60
				damage = minf(damage + 0.01 * float(cargo.get("fragile", 0.3)), 1.0)
				hud.toast("دهست غنمة! صاحبها زعلان — غرامة ٦٠", Color(1, 0.45, 0.35), 3.0)
				audio.play("crash", -4.0)
				if exam_mode:
					exam_faults.append("دهست غنمة")
				var tw := create_tween()
				var away := (pos - car.global_position).normalized() * 5.0 + Vector3.UP * 2.5
				tw.tween_property(n, "global_position", pos + away, 0.5)
				tw.parallel().tween_property(n, "rotation:z", 2.6, 0.5)
				tw.tween_property(n, "global_position:y", pos.y + 0.1, 0.3)


func _horn() -> void:
	audio.play("horn", -2.0)
	for g in sheep_groups:
		var first: Dictionary = g["list"][0]
		var sp := _route_pos(first["s"], first["u"])
		if Vector2(sp.x - car.global_position.x, sp.z - car.global_position.z).length() < 90.0:
			g["boost"] = 5.0


# ================================================================ التفاعل
func _input(event: InputEvent) -> void:
	if finished or paused:
		if paused:
			super(event)
		return
	if event.is_action_pressed("horn"):
		_horn()
		return
	if event.is_action_pressed("photo"):
		_photo()
		return
	if event.is_action_pressed("interact"):
		_interact()
		return
	super(event)


func _interact() -> void:
	var kmh := absf(car.speed) * 3.6
	if not station_here.is_empty():
		if kmh > 5.0:
			hud.toast("وكّف أول", Color(1, 0.8, 0.5), 1.5)
			return
		match str(station_here["type"]):
			"fuel":
				var mx: float = car.stats["fuel"]
				var missing := mx - car.fuel
				var cost := int(ceil(missing * 0.6))
				if cost < 2:
					hud.toast("الخزان مليان", Color(0.8, 0.9, 1.0), 1.5)
				else:
					car.fuel = mx
					fuel_cost += cost
					audio.play("fuel")
					hud.toast("عبّيت بانزين بـ %d دينار باللعبة" % cost, Color(0.6, 1, 0.7), 2.5)
			"food":
				if fatigue < 0.12:
					hud.toast("بعدك مرتاح، كمّل طريقك", Color(0.8, 0.9, 1.0), 2.0)
				else:
					fatigue = 0.0
					food += 20
					hour = fmod(hour + 0.75, 24.0)
					hours_elapsed += 0.75
					if mhud:
						mhud.fade("استراحة... استكان چاي وكباب")
					hud.toast("ارتحت! التعب راح (+٤٥ دقيقة)", Color(0.6, 1, 0.7), 3.0)
			"garage":
				var cost2 := (90 if car.burst_wheel >= 0 else 0) + int(car_damage * 500.0)
				if cost2 <= 0:
					hud.toast("الشاحنة سليمة، ما تحتاج تصليح", Color(0.8, 0.9, 1.0), 2.0)
				else:
					_fix_tire()
					car_damage = 0.0
					car.speed_mult = 1.0
					repairs += cost2
					audio.play("fuel")
					if mhud:
						mhud.fade("الفيتر يشتغل...")
					hud.toast("تصلّحت السيارة بـ %d" % cost2, Color(0.6, 1, 0.7), 3.0)
		return
	# ربط السيارة العالقة
	for f in features:
		if f["type"] == "stuck" and not towing and f.has("node"):
			var n: Node3D = f["node"]
			if n.global_position.distance_to(car.global_position) < 11.0 and kmh < 6.0:
				_attach_tow(f)
				return
	if _in_end_zone() and kmh < 4.0:
		if goal == "rescue" and not towing:
			hud.toast("لازم تجيب السيارة العالقة وياك أول", Color(1, 0.7, 0.4), 2.5)
			return
		_deliver()


func _attach_tow(f: Dictionary) -> void:
	var n: Node3D = f["node"]
	n.queue_free()
	f.erase("node")
	if f.has("beacon"):
		(f["beacon"] as Node).queue_free()
	towing = true
	var t := TruckTrailer.new()
	add_child(t)
	t.setup("car", Color.WHITE, Color.WHITE, false, false, {"body": "pickup" if style != "marsh" else "jeep", "paint": Color(0.7, 0.66, 0.6)})
	trailers.append(t)
	_place_trailers()
	_link_trailer(t)
	_apply_load()
	audio.play("rare")
	hud.toast("ربطت الحبل! هسة اسحبها لـ %s" % dest_name, Color(0.6, 1, 0.7), 4.0)


func _in_end_zone() -> bool:
	if features.is_empty():
		return false
	for f in features:
		if f["type"] == "depot_end":
			return car_s > route_len - 18.0 and car_s < route_len + 95.0 and absf(car_u) < 44.0
		if f["type"] == "camp_end":
			var rp := _route_pos(route_len, 0.0)
			return Vector2(rp.x - car.global_position.x, rp.z - car.global_position.z).length() < 12.0
	return false


func _dock_ok() -> bool:
	if trailers.is_empty() or towing:
		return false
	var t: TruckTrailer = trailers[trailers.size() - 1]
	var rear := t.global_transform * Vector3(0, 0, t.rear_z)
	var front := t.global_transform * Vector3(0, 0, t.front_z)
	var rr := to_route(rear.x, rear.z)
	var fr := to_route(front.x, front.z)
	if rr.x < fr.x + 4.0:
		return false
	for f in features:
		if f["type"] == "depot_end":
			var ds := float(f.get("dock_s", route_len + 68.8))
			if rr.x < ds - 4.0 or rr.x > ds + 0.5:
				return false
			for bu in f.get("bays", []):
				if absf(rr.y - float(bu)) < 1.8 and absf(fr.y - float(bu)) < 3.0:
					return true
	return false


func _update_prompt() -> void:
	var txt := ""
	var kmh := absf(car.speed) * 3.6
	if finished:
		hud.set_prompt("")
		return
	if lesson_id != "":
		hud.set_prompt(prompt_override)
		return
	if not station_here.is_empty():
		match str(station_here["type"]):
			"fuel":
				txt = "%s — اضغط E حتى تعبّي بانزين (%d)" % [station_here.get("name", ""), int(ceil((car.stats["fuel"] - car.fuel) * 0.6))]
			"food":
				txt = "%s — اضغط E حتى ترتاح وتاكل (٢٠)" % station_here.get("name", "")
			"garage":
				txt = "%s — اضغط E حتى تصلّح (%d)" % [station_here.get("name", ""), (90 if car.burst_wheel >= 0 else 0) + int(car_damage * 500.0)]
		if kmh > 5.0:
			txt = "وكّف بالمحطة: " + txt
	elif hold_e > 0.0:
		txt = "تركيب التاير الاحتياطي... %d%%" % int(hold_e / 4.0 * 100.0)
	elif _in_end_zone():
		if goal == "rescue" and not towing:
			txt = "جيب السيارة العالقة أول!"
		elif not trailers.is_empty() and not towing and not _dock_ok():
			txt = "اضغط E حتى تسلّم — أو ارجع المقطورة ريوس على رصيف التحميل لمكافأة إضافية"
		elif _dock_ok():
			txt = "ممتاز! المقطورة على الرصيف — اضغط E حتى تسلّم"
		else:
			txt = "اضغط E حتى تسلّم وتكمل المهمة"
		if kmh > 4.0:
			txt = "وكّف حتى تسلّم"
	else:
		for f in features:
			if f["type"] == "stuck" and f.has("node") and not towing:
				if (f["node"] as Node3D).global_position.distance_to(car.global_position) < 14.0:
					txt = "اضغط E حتى تربط حبل السحب"
			if f["type"] == "check" and f["state"] == "inspect":
				txt = "التفتيش... لا تتحرك"
			elif f["type"] == "check" and f["state"] == "wait" and car_s > float(f["s"]) - 60.0 and car_s < float(f["s"]):
				txt = "سيطرة! وكّف قبل الذراع"
		if txt == "":
			if car.fuel <= 0.0:
				txt = "خلص البانزين! اضغط T مرتين لمساعدة الطريق"
			elif flip_timer > 1.5:
				txt = "انقلبت — اضغط R"
			elif water_timer > 1.5:
				txt = "انت بالماي! اضغط R"
			elif jack_warn_t > 0.0:
				txt = "انتبه! المقطورة راح تنطوي — عدّل التوجيه"
			elif car.burst_wheel >= 0 and kmh < 2.0 and not spare_used:
				txt = "اضغط E مطولاً حتى تركّب التاير الاحتياطي"
	hud.set_prompt(txt)


func _photo() -> void:
	hud.visible = false
	if mhud:
		mhud.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	if mhud:
		mhud.visible = true
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("IBRA DRIVE")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := dir.path_join("IBRA_DRIVE_%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))
	img.save_png(f)
	hud.toast("انحفظت الصورة: Pictures/IBRA DRIVE", Color(0.7, 0.9, 1.0), 3.0)


func _intro_toasts() -> void:
	if lesson_id != "":
		return
	match goal:
		"race":
			hud.toast("السباق بدأ! عدّي من الحلقات الصفرة", Color(1, 0.85, 0.3), 4.0)
		"rescue":
			hud.toast("روح للسيارة العالقة (الضوء البرتقالي) واربطها", Color(1, 0.85, 0.4), 5.0)
		_:
			if not cargo.is_empty():
				hud.toast("الحمولة: %s — وصّلها لـ %s" % [cargo["name"], dest_name], Color(1, 0.86, 0.5), 5.0)
			else:
				hud.toast("الوجهة: %s" % dest_name, Color(1, 0.86, 0.5), 5.0)
	if not trailers.is_empty() and not towing:
		hud.toast("المقطورة تلف أوسع من الشاحنة — خذ المنعطفات من بعيد", Color(0.85, 0.9, 1.0), 6.0)
	if exam_mode:
		hud.toast("الفاحص: يلا نشوف. التزم بالسرعة، ووكّف بالسيطرة", Color(0.85, 0.95, 1.0), 6.0)


# ================================================================ النهاية
func _result_dict() -> Dictionary:
	var late := -999.0
	if deadline_hour > 0.0:
		late = hours_elapsed - deadline_hour
	return {"delivered": true, "damage": damage if not cargo.is_empty() else 0.0, "late_h": late, "fuel_cost": fuel_cost,
		"fines": fines, "repairs": repairs, "food": food, "dock": _dock_ok(), "checkpoint_ok": checkpoint_ok}


func _deliver() -> void:
	if finished:
		return
	finished = true
	car.controls = false
	audio.play("rare", 0.0)
	var res := _result_dict()
	var kind: String = spec.get("kind", "contract")
	var data := {"ok": true, "title": "", "lines": [], "total": 0, "buttons": [], "stats": _trip_stats()}
	match kind:
		"contract":
			var st: Dictionary = Jobs.settle(spec, res)
			data["title"] = "وصلت الحمولة لـ %s!" % dest_name
			data["lines"] = st["lines"]
			data["total"] = st["total"]
			data["rep"] = "السمعة: %d (%s%d) — %s" % [int(st["rep"]), "+" if int(st["rep_d"]) >= 0 else "", int(st["rep_d"]), Jobs.rep_title()]
			if not st["unlocked"].is_empty():
				data["unlocked"] = "انفتحت مدن جديدة: " + "، ".join(PackedStringArray(st["unlocked"]))
			var t := Jobs.truck()
			t["chain_bonus"] = mini(int(t.get("chain_bonus", 0)) + 1, 5)
			var offers: Array = Jobs.refresh_board(true)
			data["offers"] = offers.slice(0, 3)
		"story":
			var base := float(spec.get("pay", 500))
			var dmg := float(res["damage"])
			var lines: Array = [["مكافأة الفصل", int(base)]]
			var total := base
			if dmg > 0.005:
				lines.append(["أضرار الحمولة %d%%" % int(round(dmg * 100.0)), -int(base * dmg * 0.5)])
				total -= base * dmg * 0.5
			if goal == "race":
				var tb := int(maxf(race_time, 0.0) * 4.0)
				lines.append(["الوقت الباقي %d ثانية" % int(race_time), tb])
				total += tb
			if float(res["late_h"]) > -900.0:
				if float(res["late_h"]) <= 0.0:
					lines.append(["وصلت بالوقت", int(base * 0.2)])
					total += base * 0.2
				else:
					lines.append(["تأخرت", -int(base * 0.25)])
					total -= base * 0.25
			for k in [["fuel_cost", "بانزين"], ["fines", "غرامات"], ["repairs", "تصليح"], ["food", "أكل"]]:
				if int(res[k[0]]) > 0:
					lines.append([k[1], -int(res[k[0]])])
					total -= int(res[k[0]])
			var final := maxi(int(total), 0)
			Game.data["coins"] = int(Game.data["coins"]) + final
			var sc: String = spec.get("story_car", "")
			var ch := int(spec.get("chapter", 0))
			Story.set_progress(sc, ch + 1)
			if sc.begins_with("semi"):
				var tr := Jobs.truck()
				tr["rep"] = int(tr["rep"]) + 3
			Game.save_game()
			data["title"] = "خلص الفصل: %s" % spec.get("title", "")
			data["lines"] = lines
			data["total"] = final
			data["outro"] = Story.story_for(sc)["chapters"][ch].get("outro", [])
			data["story_car"] = sc
			data["chapter"] = ch
		"free":
			data["title"] = "وصلت %s" % dest_name
			if Jobs.CITIES.has(spec.get("to", "")):
				Jobs.truck()["city"] = spec["to"]
			data["lines"] = [["سفرة حرة — ماكو أجرة", 0]]
			var xp := int(total_km / 6.0)
			Game.data["xp"] = int(Game.data["xp"]) + xp
			Game.save_game()
		"exam":
			var passed := exam_faults.size() <= 2
			data["ok"] = passed
			data["title"] = "نجحت بالامتحان!" if passed else "ما نجحت هالمرة"
			var lines2: Array = []
			if exam_faults.is_empty():
				lines2.append(["ولا غلطة! الفاحص منبهر", 0])
			for e in exam_faults:
				lines2.append(["غلطة: " + str(e), 0])
			data["lines"] = lines2
			data["exam"] = passed
			if passed:
				School.award_license()
	if debug_fps:
		print("DELIVERED ", data.get("title", ""), " total=", data.get("total", 0), " lines=", data.get("lines", []))
	mhud.show_summary(data, spec)


func _trip_stats() -> String:
	var mins := int(hours_elapsed * 60.0)
	return "المسافة %s كم • الوقت باللعبة %d:%02d • كسرت %d شي" % [Jobs.ar_num(int(total_km * clampf(max_s / route_len, 0.0, 1.0))), mins / 60, mins % 60, broken_props]


func _fail(reason: String) -> void:
	if finished:
		return
	finished = true
	car.controls = false
	audio.play("error", 0.0)
	var kind: String = spec.get("kind", "contract")
	if kind == "contract":
		var res := _result_dict()
		res["delivered"] = false
		Jobs.settle(spec, res)
		Jobs.truck()["chain_bonus"] = 0
		Game.save_game()
	if debug_fps:
		print("FAILED ", reason)
	mhud.show_summary({"ok": false, "title": reason, "lines": [["المهمة ما انكملت", 0]], "total": 0, "stats": _trip_stats()}, spec)


func abandon() -> void:
	get_tree().paused = false
	paused = false
	hud.show_pause(false)
	_fail("انسحبت من المهمة")



func lesson_finished(ok: bool, reason: String, knocked: int) -> void:
	if finished:
		return
	finished = true
	car.controls = false
	var lines: Array = []
	if ok:
		audio.play("rare", 0.0)
		var first := School.mark(lesson_id)
		lines.append(["خلصت الدرس بنجاح", 0])
		if knocked > 0:
			lines.append(["أقماع وكعت: %d" % knocked, 0])
		lines.append(["الوقت: %d ثانية" % int(course.timer), 0])
		if first:
			lines.append(["مكافأة أول مرة", 150])
	else:
		audio.play("error", 0.0)
		lines.append([reason, 0])
	var praise := ["الأستاذ: عفية! إيدك خفيفة", "الأستاذ: هيچ السياقة لو بلاش", "الأستاذ: أحسنت، صرت تعرف", "الأستاذ: والله ممتاز"]
	mhud.show_summary({"ok": ok, "title": (praise[randi() % praise.size()] if ok else "ما زبطت هالمرة"), "lines": lines, "total": 0,
		"stats": School.lesson(lesson_id)["title"]}, spec)



## للتجربة فقط: يسوق وحده على الطريق
func _autopilot() -> void:
	var kmh := absf(car.speed) * 3.6
	var look := clampf(kmh * 0.45, 14.0, 40.0)
	var tgt := _route_pos(car_s + look, road_half * 0.45 if paved else 0.0)
	for f in features:
		if f["type"] == "ring" and not f["done"] and float(f["s"]) > car_s:
			tgt = _route_pos(float(f["s"]) if float(f["s"]) - car_s < look else car_s + look, float(f["u"]) if float(f["s"]) - car_s < look * 1.5 else 0.0)
			break
	var lp := car.global_transform.affine_inverse() * tgt
	var st := clampf(lp.x / (look * 0.35), -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if st > 0.02:
		Input.action_press("steer_right", st)
	elif st < -0.02:
		Input.action_press("steer_left", -st)
	var want := auto_kmh
	for f in features:
		if f["type"] == "check" and f["state"] in ["wait", "inspect"] and float(f["s"]) - car_s < 90.0 and float(f["s"]) > car_s - 2.0:
			want = 0.0 if float(f["s"]) - car_s < 12.0 else (12.0 if float(f["s"]) - car_s < 40.0 else 25.0)
	if _in_end_zone():
		want = 0.0
	if kmh < want - 3.0:
		Input.action_press("accelerate", 0.8)
		Input.action_release("brake")
	elif kmh > want + 6.0:
		Input.action_release("accelerate")
		Input.action_press("brake", 0.7)
	else:
		Input.action_release("accelerate")
		Input.action_release("brake")
	if _in_end_zone() and kmh < 3.0 and not finished:
		_interact()
