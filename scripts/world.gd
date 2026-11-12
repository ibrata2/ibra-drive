extends Node3D
## IBRA DRIVE — يبني أي مكان من الـ120: تضاريس، ماي، نباتات، مدن، جو، ليل ونهار، أغراض

const SIZE := 400.0
const RES := 200
const CELL := SIZE / RES
const DAY_SECONDS_PER_HOUR := 30.0

const ITEM_TYPES := {
	"scrap": {"name": "خردة", "color": Color(0.78, 0.8, 0.84), "w": 38},
	"coins": {"name": "فلوس", "color": Color(1.0, 0.8, 0.2), "w": 26},
	"parts": {"name": "قطع غيار", "color": Color(0.3, 0.7, 1.0), "w": 20},
	"fuel": {"name": "جليكان بانزين", "color": Color(1.0, 0.3, 0.2), "w": 11},
	"crystal": {"name": "حجر نادر", "color": Color(0.85, 0.45, 1.0), "w": 5},
}

const GroundShader := preload("res://shaders/ground.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")
const BuildingShader := preload("res://shaders/building.gdshader")
const SkyShader := preload("res://shaders/sky.gdshader")
const HudScript := preload("res://scripts/hud.gd")
const CamScript := preload("res://scripts/drone_cam.gd")
const AudioScript := preload("res://scripts/audio.gd")

var place_idx := 0
var place: Dictionary
var biome: Dictionary
var season := "summer"
var shape := "none"
var water_kind := "none"
var has_water := false
var water_level := -1000.0
var rng := RandomNumberGenerator.new()
var noise_a := FastNoiseLite.new()
var noise_b := FastNoiseLite.new()
var noise_c := FastNoiseLite.new()
var heights := PackedFloat32Array()
var spawn := Vector3.ZERO
var spawn_h := 0.0
var lake_center := Vector2(100, 80)
var lake_radius := 55.0

# مدينة / حقول
var city_density := 0.0
var road_rects: Array = []
var building_rects: Array = []
var field_rects: Array = []
var block_size := 64.0
const TRACK_W := 10.0
var has_track := false
var track_base := 110.0
var track_phase := 0.0
var road_w := 14.0

# العقد
var car: IbraCar
var cam: Camera3D
var hud
var audio
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var flash: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var grass_mats: Array = []
var building_mat: ShaderMaterial
var road_mat: StandardMaterial3D
var lamp_head_mat: StandardMaterial3D
var lamp_lights: Array = []
var window_lights: Array = []
var items: Array = []
var birds: Array = []
var dust_emitters: Array = []
var splash: GPUParticles3D
var rain_fx: GPUParticles3D
var snow_fx: GPUParticles3D
var sand_fx: GPUParticles3D
var ambient_fx: GPUParticles3D
var track_mm: MultiMesh
var track_count := 0
var track_last: Array = []
var ring: MeshInstance3D
var props_body: StaticBody3D
var minimap_tex: ImageTexture

# الوقت والجو
var hour := 12.0
var weather := "clear"
var wcur := {}
var weather_timer := 200.0
var snow_acc := 0.0
var wet_acc := 0.0
var base_snow := 0.0
var lightning_timer := 6.0
var flash_t := 0.0
var cloud_off := Vector2.ZERO
var loot_mult := 1.0

# حالة اللعب
var paused := false
var flip_timer := 0.0
var drown_timer := 0.0
var tow_confirm := 0.0
var safe_hist: Array = []
var safe_timer := 0.0
var stuck_timer := 0.0
var water_timer := 0.0
var fuel_warned := false
var treasure_hint_t := 0.0
var taken_count := 0
var night_lights_on := false
var auto_lights := true


func _ready() -> void:
	place = Places.get_place(place_idx)
	biome = Places.get_biome(place["biome"])
	season = place["season"]
	shape = biome["shape"]
	water_kind = biome["water"]
	has_water = water_kind != "none"
	city_density = biome.get("city", 0.0)
	rng.seed = place["seed"]
	hour = place["hour"]
	weather = place["weather"]
	loot_mult = 1.0 + float(place["req_level"] - 1) * 0.08
	wcur = Places.WEATHER[weather].duplicate()
	_setup_noise()
	_layout()
	_build_heights()
	_build_terrain()
	if has_water:
		_build_water()
	if city_density > 0.0:
		_build_city()
	if field_rects.size() > 0:
		_build_fields()
	_build_props()
	_build_track_props()
	_build_garage()
	_build_bounds()
	_spawn_items()
	_build_environment()
	_build_weather_fx()
	_build_bursts()
	_build_fx_pools()
	_build_tracks()
	_spawn_birds()
	_spawn_car()
	_build_minimap_tex()
	_update_daylight(0.0)
	hud.toast("أهلاً بيك في %s" % place["name"], Color(1, 0.86, 0.5), 4.0)
	if Game.test_car != "":
		hud.toast("تجربة سيارة: %s" % Game.get_car(Game.test_car)["name"], Color(0.5, 0.9, 1.0), 5.0)
	hud.toast("اجمع الأغراض وارجع للكراج (المربع الأخضر) حتى تحفظها", Color(0.85, 0.9, 1.0), 6.0)


# ================================================================ التضاريس
func _setup_noise() -> void:
	noise_a.seed = place["seed"]
	noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_a.frequency = biome["freq"]
	noise_a.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_a.fractal_octaves = 4
	noise_b.seed = place["seed"] + 11
	noise_b.frequency = 0.045
	noise_b.fractal_octaves = 2
	noise_c.seed = place["seed"] + 23
	noise_c.frequency = 0.02
	noise_c.fractal_octaves = 2


func _layout() -> void:
	match water_kind:
		"sea", "lake", "lava", "ice":
			water_level = 0.0
		"marsh":
			water_level = biome["amp"] * 0.42
	if shape == "lake":
		var a := rng.randf() * TAU
		var d := rng.randf_range(85.0, 120.0)
		lake_center = Vector2(cos(a), sin(a)) * d
		lake_radius = rng.randf_range(42.0, 62.0)
	if city_density > 0.0:
		if city_density >= 0.9:
			block_size = 64.0
			road_w = 14.0
			spawn = Vector3(32, 0, 22)
		else:
			block_size = 128.0
			road_w = 12.0
			spawn = Vector3(30, 0, 22)
		var k := -int(SIZE / 2.0 / block_size)
		while k * block_size <= SIZE / 2.0:
			var c := k * block_size
			road_rects.append(Rect2(c - road_w / 2.0, -SIZE / 2.0, road_w, SIZE))
			road_rects.append(Rect2(-SIZE / 2.0, c - road_w / 2.0, SIZE, road_w))
			k += 1
	has_track = biome.get("rally", false)
	if has_track:
		track_base = rng.randf_range(95.0, 125.0)
		track_phase = rng.randf() * TAU
	var nf: int = biome.get("fields", 0)
	if nf > 0:
		var tries := 0
		while field_rects.size() < nf and tries < 200:
			tries += 1
			var w := rng.randf_range(24.0, 44.0)
			var h := rng.randf_range(30.0, 52.0)
			var x := rng.randf_range(-180.0, 180.0 - w)
			var z := rng.randf_range(-180.0, 180.0 - h)
			var r := Rect2(x, z, w, h)
			if r.grow(20).has_point(Vector2(spawn.x, spawn.z)):
				continue
			var ok := true
			for o in field_rects:
				if (o as Rect2).grow(6).intersects(r):
					ok = false
					break
			if ok:
				field_rects.append(r)
	# ارتفاع البداية
	spawn_h = _raw_h(spawn.x, spawn.z, false)
	if has_water:
		spawn_h = maxf(spawn_h, water_level + 1.6)


func _raw_h(x: float, z: float, flatten := true) -> float:
	var amp: float = biome["amp"]
	var n := noise_a.get_noise_2d(x, z)
	var h := 0.0
	if biome["ridge"]:
		var r := 1.0 - absf(n)
		h = r * r * amp
	else:
		h = (n * 0.5 + 0.5) * amp
	h += noise_b.get_noise_2d(x, z) * amp * 0.12
	if biome["dunes"]:
		h += (sin(x * 0.035 + z * 0.012 + noise_c.get_noise_2d(x, z) * 4.0) * 0.5 + 0.5) * amp * 0.35
	match shape:
		"coast":
			var shore := -60.0 + noise_c.get_noise_2d(x * 0.5, 7.0) * 35.0
			var d := z - shore
			h = 1.2 + h * smoothstep(0.0, 70.0, d)
			h -= (1.0 - smoothstep(-55.0, 8.0, d)) * 9.0
		"island":
			var r := Vector2(x, z).length() / 175.0 + noise_c.get_noise_2d(x, z) * 0.18
			h = 1.2 + h * (1.0 - smoothstep(0.45, 0.9, r))
			h -= smoothstep(0.72, 1.02, r) * 9.0
		"lake":
			var d := Vector2(x, z).distance_to(lake_center) / (lake_radius + noise_c.get_noise_2d(x, z) * 18.0)
			var dep := 1.0 - smoothstep(0.6, 1.2, d)
			h = lerpf(h + 1.5, -4.5, dep)
		"river":
			var line := sin(x * 0.017) * 55.0 + 60.0 + noise_c.get_noise_2d(x, 3.0) * 12.0
			var d := absf(z - line)
			var dep := 1.0 - smoothstep(6.0, 20.0, d)
			h = lerpf(h + 1.5, -3.5, dep)
	if city_density > 0.0:
		h *= 0.4
	if has_track:
		var td := track_dist(x, z)
		if td < TRACK_W:
			var smooth_h := (noise_a.get_noise_2d(x * 0.5, z * 0.5) * 0.5 + 0.5) * float(biome["amp"]) * 0.6
			h = lerpf(smooth_h, h, smoothstep(TRACK_W * 0.4, TRACK_W, td))
	for f in field_rects:
		if (f as Rect2).grow(4).has_point(Vector2(x, z)):
			h *= 0.5
	if flatten:
		var ds := Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z))
		h = lerpf(spawn_h, h, smoothstep(16.0, 36.0, ds))
		if not has_water or water_kind == "lava" or water_kind == "ice":
			var edge := maxf(absf(x), absf(z))
			h += smoothstep(SIZE * 0.5 - 30.0, SIZE * 0.5, edge) * 14.0
	return h


func _build_heights() -> void:
	var n := RES + 1
	heights.resize(n * n)
	for j in n:
		for i in n:
			var x := -SIZE / 2.0 + i * CELL
			var z := -SIZE / 2.0 + j * CELL
			heights[j * n + i] = _raw_h(x, z)


func h_at(x: float, z: float) -> float:
	var n := RES + 1
	var fx := clampf((x + SIZE / 2.0) / CELL, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE / 2.0) / CELL, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * n + i]
	var h10 := heights[j * n + i + 1]
	var h01 := heights[(j + 1) * n + i]
	var h11 := heights[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	return Vector3(h_at(x - e, z) - h_at(x + e, z), 2.0 * e, h_at(x, z - e) - h_at(x, z + e)).normalized()


func on_road(x: float, z: float) -> bool:
	for r in road_rects:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


func in_building(x: float, z: float, margin := 0.0) -> bool:
	for r in building_rects:
		if (r as Rect2).grow(margin).has_point(Vector2(x, z)):
			return true
	return false


func in_field(x: float, z: float, margin := 0.0) -> bool:
	for r in field_rects:
		if (r as Rect2).grow(margin).has_point(Vector2(x, z)):
			return true
	return false


func is_underwater(x: float, z: float, margin := 0.0) -> bool:
	return has_water and h_at(x, z) < water_level + margin


func _season_tint(c: Color) -> Color:
	if not biome["veg"]:
		return c
	match season:
		"autumn":
			return c.lerp(Color(0.6, 0.47, 0.25), 0.35)
		"summer":
			return c.lerp(Color(0.66, 0.6, 0.36), 0.2)
		"winter":
			return c.lerp(Color(0.5, 0.5, 0.46), 0.3)
		"spring":
			return c.lerp(Color(0.3, 0.6, 0.22), 0.15)
	return c


func _ground_color(x: float, z: float, h: float, slope: float) -> Color:
	var amp: float = maxf(biome["amp"], 1.0)
	var t := clampf(h / amp * 0.7 + noise_c.get_noise_2d(x * 2.0, z * 2.0) * 0.35 + 0.2, 0.0, 1.0)
	var low: Color = biome["low"]
	var c: Color = low.lerp(biome["high"], t)
	c = c.lerp(biome["steep"], smoothstep(0.25, 0.6, slope))
	c = _season_tint(c)
	if has_water and water_kind != "lava":
		var dw := h - water_level
		if dw < 1.6:
			var wet: Color = c.darkened(0.25)
			if water_kind == "sea":
				wet = Color(0.72, 0.58, 0.4)
			c = c.lerp(wet, clampf(1.0 - dw / 1.6, 0.0, 1.0))
		if dw < 0.0:
			c = c.darkened(clampf(-dw * 0.08, 0.0, 0.4))
	if water_kind == "lava":
		var dw2 := h - water_level
		if dw2 < 3.0:
			c = c.lerp(Color(0.08, 0.05, 0.04), clampf(1.0 - dw2 / 3.0, 0.0, 1.0))
	for f in field_rects:
		var r := f as Rect2
		if r.has_point(Vector2(x, z)):
			var row := sin((x - r.position.x) * TAU / 1.6) * 0.5 + 0.5
			var soil := Color(0.36, 0.26, 0.17) if season != "winter" else Color(0.3, 0.22, 0.15)
			c = soil.lerp(soil.darkened(0.25), row)
		elif r.grow(3).has_point(Vector2(x, z)):
			c = c.lerp(Color(0.45, 0.36, 0.25), 0.5)
	if city_density > 0.0:
		c = c.lerp(Color(0.62, 0.6, 0.56), 0.55 * city_density)
	if has_track:
		var td2 := track_dist(x, z)
		if td2 < TRACK_W * 0.75:
			var packed: Color = (biome["high"] as Color).lightened(0.12)
			var berm := smoothstep(TRACK_W * 0.35, TRACK_W * 0.6, td2)
			c = c.lerp(packed.lerp(c.darkened(0.08), berm), 0.85)
	return c


func _build_terrain() -> void:
	var n := RES + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	for j in n:
		for i in n:
			var x := -SIZE / 2.0 + i * CELL
			var z := -SIZE / 2.0 + j * CELL
			var h := heights[j * n + i]
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, RES)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, RES) * n + i]
			var nm := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			verts[j * n + i] = Vector3(x, h, z)
			norms[j * n + i] = nm
			cols[j * n + i] = _ground_color(x, z, h, 1.0 - nm.y)
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GroundShader
	ground_mat.set_shader_parameter("ripples", 1.0 if biome["dunes"] else 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ground_mat
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for k in heights.size():
		scaled[k] = heights[k] / CELL
	hs.map_data = scaled
	cs.shape = hs
	cs.scale = Vector3(CELL, CELL, CELL)
	body.add_child(cs)
	add_child(body)
	# الثلج الأساسي حسب الفصل
	if season == "winter" and biome["id"] not in ["snow", "desert", "saltflat", "oasis", "beach", "island", "city", "outskirts"]:
		base_snow = 0.55
	if biome["id"] == "tundra":
		base_snow = 0.45


func _build_water() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE * 2.5, SIZE * 2.5)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	mi.mesh = pm
	mi.position = Vector3(0, water_level, 0)
	if water_kind == "ice":
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.75, 0.88, 0.97, 0.92)
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		im.roughness = 0.08
		im.metallic = 0.2
		mi.material_override = im
		pm.subdivide_width = 1
		pm.subdivide_depth = 1
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(SIZE, 1.0, SIZE)
		cs.shape = bs
		cs.position = Vector3(0, water_level - 0.5, 0)
		body.add_child(cs)
		add_child(body)
	else:
		var wm := ShaderMaterial.new()
		wm.shader = WaterShader
		match water_kind:
			"lava":
				wm.set_shader_parameter("lava", 1.0)
				wm.set_shader_parameter("wave_amp", 0.05)
				wm.set_shader_parameter("wave_speed", 0.3)
			"marsh":
				wm.set_shader_parameter("murky", 0.6)
				wm.set_shader_parameter("shallow_color", Color(0.35, 0.55, 0.45))
				wm.set_shader_parameter("deep_color", Color(0.12, 0.25, 0.22))
				wm.set_shader_parameter("wave_amp", 0.03)
				wm.set_shader_parameter("foam_width", 0.4)
			"lake":
				wm.set_shader_parameter("shallow_color", Color(0.3, 0.65, 0.6))
				wm.set_shader_parameter("deep_color", Color(0.05, 0.2, 0.3))
				wm.set_shader_parameter("wave_amp", 0.05)
				wm.set_shader_parameter("foam_width", 0.7)
		mi.material_override = wm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_bounds() -> void:
	var body := StaticBody3D.new()
	for s in [[Vector3(0, 0, -SIZE / 2.0 - 1.0), Vector3(SIZE + 4, 200, 2)], [Vector3(0, 0, SIZE / 2.0 + 1.0), Vector3(SIZE + 4, 200, 2)],
			[Vector3(-SIZE / 2.0 - 1.0, 0, 0), Vector3(2, 200, SIZE + 4)], [Vector3(SIZE / 2.0 + 1.0, 0, 0), Vector3(2, 200, SIZE + 4)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.position = s[0]
		body.add_child(cs)
	add_child(body)


# ================================================================ الأشياء
func _prop_material(grassy: bool, kind: String) -> Material:
	if grassy:
		var gm := ShaderMaterial.new()
		gm.shader = GrassShader
		gm.set_shader_parameter("snow", base_snow * 0.6)
		grass_mats.append(gm)
		return gm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "crystals":
		m.emission_enabled = true
		m.emission = Color(0.6, 0.25, 0.9)
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.2
	return m


func _foliage_colors() -> Array:
	var veg_season := season
	if biome.has("force_season"):
		veg_season = biome["force_season"]
	match veg_season:
		"autumn":
			return [Color(0.85, 0.42, 0.12), Color(0.9, 0.65, 0.15), Color(0.7, 0.2, 0.1)]
		"winter":
			return [Color(0.3, 0.4, 0.28), Color(0.38, 0.42, 0.3), Color(0.32, 0.36, 0.26)]
		"spring":
			return [Color(0.32, 0.62, 0.2), Color(0.42, 0.7, 0.25), Color(0.28, 0.55, 0.22)]
	return [Color(0.26, 0.5, 0.18), Color(0.34, 0.55, 0.2), Color(0.3, 0.46, 0.17)]


## يوزع نوع من الأشياء على الخريطة ويرجع قائمة التحويلات
func _scatter(kind: String, count: int) -> Array:
	var out: Array = []
	var tries := count * 4
	var grassy := kind in PropLib.GRASSY
	var clumped := kind in ["dune_grass", "grass", "grass_dry", "flower", "reed", "bush"]
	while out.size() < count and tries > 0:
		tries -= 1
		var x := rng.randf_range(-SIZE / 2.0 + 6.0, SIZE / 2.0 - 6.0)
		var z := rng.randf_range(-SIZE / 2.0 + 6.0, SIZE / 2.0 - 6.0)
		var ds := Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z))
		if ds < (14.0 if grassy else 24.0):
			continue
		var h := h_at(x, z)
		if kind == "reed":
			if not has_water or h < water_level - 0.7 or h > water_level + 1.5:
				continue
		elif kind == "boat":
			if not has_water or h > water_level - 0.2 or h < water_level - 2.5:
				continue
			h = water_level - 0.15
		elif has_water and h < water_level + (0.1 if grassy else 0.4):
			continue
		if clumped and noise_c.get_noise_2d(x * 2.5, z * 2.5) < -0.05:
			continue
		if city_density > 0.0 and (on_road(x, z) or in_building(x, z, 2.0)):
			continue
		if in_field(x, z, 2.0) and kind != "hay":
			continue
		if has_track and not grassy and track_dist(x, z) < TRACK_W:
			continue
		var nm := normal_at(x, z)
		if not grassy and nm.y < 0.8 and kind not in ["rock", "pine", "pine_snow", "dead_tree", "crystals"]:
			continue
		var s := rng.randf_range(0.75, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if kind == "rock":
			basis = basis.scaled(Vector3(s * rng.randf_range(0.8, 2.2), s * rng.randf_range(0.6, 1.6), s * rng.randf_range(0.8, 2.2)))
		elif kind in ["house", "cabin", "shack", "mudhif", "tent", "wall", "barn", "crates", "ramp"]:
			basis = Basis(Vector3.UP, (rng.randi() % 4) * PI / 2.0 + rng.randf_range(-0.2, 0.2))
		else:
			basis = basis.scaled(Vector3(s, s, s))
		var sink := 0.05 if grassy else 0.25
		out.append(Transform3D(basis, Vector3(x, h - sink, z)))
	return out


## يرجع لكل تحويل [multimesh, رقم النسخة, المادة] حتى نكدر نخفيه من يتكسر
func _add_multimesh(mesh: Mesh, mat: Material, xforms: Array, vis_range := 0.0, shadows := true) -> Array:
	var refs: Array = []
	refs.resize(xforms.size())
	if xforms.is_empty():
		return refs
	# نقسم على مربعات حتى يشتغل الإخفاء البعيد
	var chunk := 100.0
	var buckets := {}
	for k in xforms.size():
		var xf: Transform3D = xforms[k]
		var key := Vector2i(int(floor(xf.origin.x / chunk)), int(floor(xf.origin.z / chunk)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(k)
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, xforms[list[i]])
			refs[list[i]] = [mm, i, mat]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		if vis_range > 0.0:
			mmi.visibility_range_end = vis_range
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	return refs


func _add_collisions(kind: String, xforms: Array, refs: Array = [], extra: Array = []) -> void:
	if not PropLib.SOLID.has(kind):
		return
	if props_body == null:
		props_body = StaticBody3D.new()
		add_child(props_body)
	var info: Array = PropLib.SOLID[kind]
	for k in xforms.size():
		var t: Transform3D = xforms[k]
		var sc := t.basis.get_scale()
		var cs := CollisionShape3D.new()
		if info[0] == "wedge":
			var ws: Vector3 = info[1]
			var cp := ConvexPolygonShape3D.new()
			var hx := ws.x / 2.0
			var hz := ws.z / 2.0
			cp.points = PackedVector3Array([Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
				Vector3(-hx, ws.y, -hz), Vector3(hx, ws.y, -hz), Vector3(-hx, -1.0, hz), Vector3(hx, -1.0, hz), Vector3(hx, -1.0, -hz), Vector3(-hx, -1.0, -hz)])
			cs.shape = cp
			cs.transform = Transform3D(t.basis.orthonormalized(), t.origin + Vector3(0, 0.2, 0))
		elif info[0] == "box":
			var bs := BoxShape3D.new()
			var sz: Vector3 = info[1]
			bs.size = sz * sc
			cs.shape = bs
			cs.position = t.origin + Vector3(0, bs.size.y * 0.5, 0)
			cs.basis = t.basis.orthonormalized()
		else:
			var cyl := CylinderShape3D.new()
			var d: Vector2 = info[1]
			cyl.radius = d.x * sc.x
			cyl.height = d.y * sc.y
			cs.shape = cyl
			cs.position = t.origin + Vector3(0, cyl.height * 0.5, 0)
		var meta := {"kind": kind, "xf": t, "refs": []}
		if k < refs.size() and refs[k] != null:
			meta["refs"] = [refs[k]] if refs[k][0] is MultiMesh else refs[k]
		if k < extra.size() and extra[k] is Dictionary:
			meta.merge(extra[k])
		cs.set_meta("prop", meta)
		props_body.add_child(cs)


func _build_props() -> void:
	var fols := _foliage_colors()
	var snowy: bool = base_snow > 0.3 or biome["id"] == "snow"
	var bare: bool = season == "winter" and biome["id"] in ["forest", "meadow", "village", "farm", "savanna"]
	var rockc: Color = biome["steep"].lerp(Color(0.55, 0.52, 0.48), 0.5)
	if biome["id"] == "volcanic":
		rockc = Color(0.15, 0.13, 0.12)
	elif biome["id"] == "snow":
		rockc = Color(0.45, 0.47, 0.52)
	for entry in biome["props"]:
		var kind: String = entry[0]
		var count: int = entry[1]
		if kind == "flower" and season != "spring" and biome["id"] != "meadow":
			count = int(count * 0.2)
		var grassy := kind in PropLib.GRASSY
		var variants := 3 if kind in ["tree", "tree_big", "flower", "bush", "grass"] else 1
		var all := _scatter(kind, count)
		var per := int(ceil(float(all.size()) / variants))
		var all_refs: Array = []
		for v in variants:
			var part := all.slice(v * per, mini((v + 1) * per, all.size()))
			if part.is_empty():
				continue
			var p := {"foliage": fols[v % fols.size()], "rock": rockc, "snowy": snowy, "variant": v,
				"bare": bare and kind in ["tree", "tree_big"],
				"flower": [Color(0.9, 0.08, 0.08), Color(1.0, 0.85, 0.15), Color(0.95, 0.95, 0.95)][v % 3]}
			var mesh := PropLib.build(kind, p)
			var vis := 0.0
			if grassy:
				vis = 150.0
			elif kind in ["dry_bush", "bush", "tires", "log"]:
				vis = 220.0
			all_refs.append_array(_add_multimesh(mesh, _prop_material(grassy, kind), part, vis, not grassy))
		_add_collisions(kind, all, all_refs)


func _build_city() -> void:
	road_mat = StandardMaterial3D.new()
	road_mat.vertex_color_use_as_albedo = true
	road_mat.vertex_color_is_srgb = true
	road_mat.roughness = 0.85
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var asphalt := Color(0.16, 0.16, 0.17) if city_density >= 0.9 else Color(0.22, 0.21, 0.2)
	var seg := 8.0
	for r in road_rects:
		var rr := r as Rect2
		var along_x := rr.size.x > rr.size.y
		var length := rr.size.x if along_x else rr.size.y
		var steps := int(length / seg)
		for s in steps:
			var p0: Vector2
			var p1: Vector2
			if along_x:
				p0 = Vector2(rr.position.x + s * seg, rr.position.y)
				p1 = Vector2(rr.position.x + (s + 1) * seg, rr.end.y)
			else:
				p0 = Vector2(rr.position.x, rr.position.y + s * seg)
				p1 = Vector2(rr.end.x, rr.position.y + (s + 1) * seg)
			var a := Vector3(p0.x, h_at(p0.x, p0.y) + 0.07, p0.y)
			var b := Vector3(p1.x, h_at(p1.x, p0.y) + 0.07, p0.y)
			var c := Vector3(p1.x, h_at(p1.x, p1.y) + 0.07, p1.y)
			var d := Vector3(p0.x, h_at(p0.x, p1.y) + 0.07, p1.y)
			for v in [a, b, c, a, c, d]:
				st.set_color(asphalt)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var rm := MeshInstance3D.new()
	rm.mesh = st.commit()
	rm.material_override = road_mat
	add_child(rm)
	# خطوط الشارع
	var dashes: Array = []
	var k := -int(SIZE / 2.0 / block_size)
	while k * block_size <= SIZE / 2.0:
		var c0 := k * block_size
		var t := -SIZE / 2.0
		while t < SIZE / 2.0:
			if absf(fmod(t - c0 + 1000.0 * block_size, block_size) - block_size / 2.0) < block_size / 2.0 - road_w * 0.6:
				dashes.append(Transform3D(Basis(), Vector3(c0, h_at(c0, t) + 0.09, t)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(t, h_at(t, c0) + 0.09, c0)))
			t += 7.0
		k += 1
	var dm := BoxMesh.new()
	dm.size = Vector3(0.25, 0.02, 3.0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.95, 0.92, 0.8)
	_add_multimesh(dm, dmat, dashes, 160.0, false)
	# العمارات
	building_mat = ShaderMaterial.new()
	building_mat.shader = BuildingShader
	var bxf: Array = []
	var k2 := -int(SIZE / 2.0 / block_size) - 1
	while k2 * block_size <= SIZE / 2.0:
		var k3 := -int(SIZE / 2.0 / block_size) - 1
		while k3 * block_size <= SIZE / 2.0:
			var bx0 := k2 * block_size + road_w / 2.0 + 4.0
			var bz0 := k3 * block_size + road_w / 2.0 + 4.0
			var inner := block_size - road_w - 8.0
			var lots := 2 if city_density >= 0.9 else 3
			var lot := inner / lots
			for li in lots:
				for lj in lots:
					if rng.randf() > city_density + 0.1:
						continue
					var fw := lot * rng.randf_range(0.6, 0.92)
					var fd := lot * rng.randf_range(0.6, 0.92)
					var cx := bx0 + li * lot + lot / 2.0
					var cz := bz0 + lj * lot + lot / 2.0
					if absf(cx) > SIZE / 2.0 - 10.0 or absf(cz) > SIZE / 2.0 - 10.0:
						continue
					if Vector2(cx, cz).distance_to(Vector2(spawn.x, spawn.z)) < 26.0:
						continue
					var hgt := rng.randf_range(7.0, 26.0) if city_density >= 0.9 else rng.randf_range(4.0, 10.0)
					var gy := minf(minf(h_at(cx - fw / 2, cz - fd / 2), h_at(cx + fw / 2, cz + fd / 2)), h_at(cx, cz)) - 0.5
					var xf := Transform3D(Basis().scaled(Vector3(fw, hgt + 0.5, fd)), Vector3(cx, gy + (hgt + 0.5) / 2.0, cz))
					bxf.append(xf)
					building_rects.append(Rect2(cx - fw / 2.0, cz - fd / 2.0, fw, fd))
					if props_body == null:
						props_body = StaticBody3D.new()
						add_child(props_body)
					var cs := CollisionShape3D.new()
					var bs := BoxShape3D.new()
					bs.size = Vector3(fw, hgt + 0.5, fd)
					cs.shape = bs
					cs.position = xf.origin
					cs.set_meta("prop", {"kind": "building", "holes": 0})
					props_body.add_child(cs)
			k3 += 1
		k2 += 1
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	_add_multimesh(bm, building_mat, bxf)
	# أعمدة الإنارة
	var lamps: Array = []
	var heads: Array = []
	var lamp_extra: Array = []
	for r in road_rects:
		var rr := r as Rect2
		var along_x := rr.size.x > rr.size.y
		var t2 := -SIZE / 2.0 + 10.0
		while t2 < SIZE / 2.0 - 10.0:
			var pos: Vector3
			var rot := 0.0
			if along_x:
				pos = Vector3(t2, 0, rr.end.y + 0.8)
				rot = PI
			else:
				pos = Vector3(rr.end.x + 0.8, 0, t2)
				rot = -PI / 2.0
			if not on_road(pos.x, pos.z) and not in_building(pos.x, pos.z, 0.5):
				pos.y = h_at(pos.x, pos.z)
				var xf := Transform3D(Basis(Vector3.UP, rot), pos)
				lamps.append(xf)
				heads.append(xf)
				lamp_extra.append({})
				if lamp_lights.size() < 70 and rng.randf() < 0.6:
					var ol := OmniLight3D.new()
					ol.light_color = Color(1.0, 0.8, 0.5)
					ol.omni_range = 16.0
					ol.light_energy = 2.2
					ol.shadow_enabled = false
					ol.position = xf * Vector3(0, 5.6, -1.4)
					ol.visible = false
					add_child(ol)
					lamp_lights.append(ol)
					lamp_extra[lamp_extra.size() - 1] = {"light": ol}
			t2 += 26.0
	var lamp_refs := _add_multimesh(PropLib.build("lamp", {}), _prop_material(false, "lamp"), lamps, 240.0)
	lamp_head_mat = StandardMaterial3D.new()
	lamp_head_mat.vertex_color_use_as_albedo = true
	lamp_head_mat.vertex_color_is_srgb = true
	lamp_head_mat.emission_enabled = true
	lamp_head_mat.emission = Color(1.0, 0.8, 0.5)
	lamp_head_mat.emission_energy_multiplier = 0.0
	var head_refs := _add_multimesh(PropLib.build("lamp_head", {}), lamp_head_mat, heads, 240.0)
	var both: Array = []
	for i in lamp_refs.size():
		both.append([lamp_refs[i], head_refs[i]])
	_add_collisions("lamp", lamps, both, lamp_extra)
	# سيارات واقفة
	var parked: Array = []
	for i in int(70 * city_density):
		var r: Rect2 = road_rects[rng.randi() % road_rects.size()]
		var along_x := r.size.x > r.size.y
		var t3 := rng.randf_range(-SIZE / 2.0 + 15.0, SIZE / 2.0 - 15.0)
		var pos: Vector3
		var yaw := 0.0
		if along_x:
			pos = Vector3(t3, 0, r.position.y + 1.6)
			yaw = PI / 2.0
		else:
			pos = Vector3(r.position.x + 1.6, 0, t3)
		var cross := false
		for o in road_rects:
			var oo := o as Rect2
			if oo != r and oo.grow(3).has_point(Vector2(pos.x, pos.z)):
				cross = true
		if cross or Vector2(pos.x, pos.z).distance_to(Vector2(spawn.x, spawn.z)) < 20.0:
			continue
		pos.y = h_at(pos.x, pos.z) - 0.15
		parked.append(Transform3D(Basis(Vector3.UP, yaw), pos))
	var pr := _add_multimesh(PropLib.build("wreck", {"variant": 2}), _prop_material(false, "wreck"), parked, 260.0)
	_add_collisions("wreck", parked, pr)


func _build_fields() -> void:
	var kind := "crop"
	match season:
		"spring", "winter":
			kind = "crop_green"
	var xfs: Array = []
	var hay: Array = []
	for f in field_rects:
		var r := f as Rect2
		if season == "autumn" and rng.randf() < 0.6:
			for i in 8:
				var x := rng.randf_range(r.position.x + 2, r.end.x - 2)
				var z := rng.randf_range(r.position.y + 2, r.end.y - 2)
				hay.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, h_at(x, z) - 0.1, z)))
			continue
		var x0 := r.position.x + 0.8
		while x0 < r.end.x - 0.5:
			var z0 := r.position.y + 0.6
			while z0 < r.end.y - 0.5:
				var s := rng.randf_range(0.8, 1.15) * (0.55 if season == "winter" else 1.0)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x0 + rng.randf_range(-0.15, 0.15), h_at(x0, z0) - 0.05, z0)))
				z0 += rng.randf_range(0.9, 1.3)
			x0 += 1.6
	_add_multimesh(PropLib.build(kind, {}), _prop_material(true, kind), xfs, 170.0, false)
	if not hay.is_empty():
		var hr := _add_multimesh(PropLib.build("hay", {}), _prop_material(false, "hay"), hay, 0.0)
		_add_collisions("hay", hay, hr)


func _build_garage() -> void:
	var g := Node3D.new()
	g.position = Vector3(spawn.x, spawn_h, spawn.z + 10.0)
	add_child(g)
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.32, 0.34, 0.38)
	wall.metallic = 0.4
	wall.roughness = 0.5
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.95, 0.65, 0.15)
	var body := StaticBody3D.new()
	g.add_child(body)
	var parts := [
		[Vector3(0.5, 5.0, 10.0), Vector3(-5.0, 2.5, 0)], [Vector3(0.5, 5.0, 10.0), Vector3(5.0, 2.5, 0)],
		[Vector3(10.5, 5.0, 0.5), Vector3(0, 2.5, 5.0)], [Vector3(10.6, 0.4, 10.6), Vector3(0, 5.1, 0)],
		[Vector3(10.6, 1.2, 0.4), Vector3(0, 4.7, -5.0)],
	]
	for pp in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pp[0]
		mi.mesh = bm
		mi.material_override = wall
		mi.position = pp[1]
		g.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = pp[0]
		cs.shape = bs
		cs.position = pp[1]
		body.add_child(cs)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(10.7, 0.25, 0.45)
	stripe.mesh = sm
	stripe.material_override = trim
	stripe.position = Vector3(0, 4.25, -5.05)
	g.add_child(stripe)
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(10, 0.1, 10)
	floor_mi.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.4, 0.4, 0.42)
	floor_mi.material_override = fmat
	floor_mi.position = Vector3(0, 0.02, 0)
	g.add_child(floor_mi)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 4.2, 0)
	lamp.omni_range = 12.0
	lamp.light_energy = 1.6
	lamp.light_color = Color(1, 0.9, 0.7)
	g.add_child(lamp)
	var sign := Label3D.new()
	sign.text = "IBRA GARAGE\nكراج إبرا"
	sign.font = Game.arabic_font
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = Color(1, 0.8, 0.3)
	sign.outline_size = 18
	sign.position = Vector3(0, 6.4, -5.2)
	sign.rotation = Vector3(0, PI, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.double_sided = true
	g.add_child(sign)
	# حلقة الرجوع
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.6
	tm.outer_radius = 5.2
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
	ring.position = Vector3(spawn.x, spawn_h + 0.1, spawn.z)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


# ================================================================ الأغراض
func _soft_texture() -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	return gt


func _item_visual(kind: String, col: Color) -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.5
	mat.roughness = 0.35
	mat.metallic = 0.3
	var mi := MeshInstance3D.new()
	match kind:
		"coins":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 0.14
			mi.mesh = cm
			mi.rotation = Vector3(PI / 2, 0, 0)
			mat.metallic = 1.0
		"crystal":
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.0
			cm2.bottom_radius = 0.45
			cm2.height = 1.4
			cm2.radial_segments = 5
			mi.mesh = cm2
			mat.emission_energy_multiplier = 2.0
		"fuel":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.6, 0.85, 0.3)
			mi.mesh = bm
		"treasure":
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(1.3, 0.8, 0.9)
			mi.mesh = bm2
			mat.albedo_color = Color(0.45, 0.28, 0.12)
			mat.emission = Color(1, 0.75, 0.2)
			mat.emission_energy_multiplier = 0.25
			var lid := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(1.35, 0.15, 0.95)
			lid.mesh = lm
			var gold := StandardMaterial3D.new()
			gold.albedo_color = Color(1, 0.78, 0.2)
			gold.metallic = 1.0
			gold.roughness = 0.25
			lid.material_override = gold
			lid.position = Vector3(0, 0.45, 0)
			n.add_child(lid)
		_:
			var bm3 := BoxMesh.new()
			bm3.size = Vector3(0.9, 0.9, 0.9)
			mi.mesh = bm3
	mi.material_override = mat
	n.add_child(mi)
	if kind != "treasure":
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.22
		cyl.height = 26.0
		cyl.radial_segments = 8
		cyl.cap_top = false
		cyl.cap_bottom = false
		beam.mesh = cyl
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bmat.albedo_color = Color(col.r, col.g, col.b, 0.13)
		bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bmat
		beam.position = Vector3(0, 13.0, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(beam)
	return n


func _pick_item_kind() -> String:
	var total := 0
	for k in ITEM_TYPES:
		total += ITEM_TYPES[k]["w"]
	var r := rng.randi() % total
	for k in ITEM_TYPES:
		r -= ITEM_TYPES[k]["w"]
		if r < 0:
			return k
	return "scrap"


func _free_spot(min_spawn: float, avoid: Array, min_gap: float) -> Vector3:
	for _t in 300:
		var x := rng.randf_range(-SIZE / 2.0 + 15.0, SIZE / 2.0 - 15.0)
		var z := rng.randf_range(-SIZE / 2.0 + 15.0, SIZE / 2.0 - 15.0)
		if Vector2(x, z).distance_to(Vector2(spawn.x, spawn.z)) < min_spawn:
			continue
		if is_underwater(x, z, 0.5):
			continue
		if city_density > 0.0 and in_building(x, z, 2.5):
			continue
		if normal_at(x, z).y < 0.75:
			continue
		var ok := true
		for a in avoid:
			if Vector2(x, z).distance_to(Vector2(a.x, a.z)) < min_gap:
				ok = false
				break
		if ok:
			return Vector3(x, h_at(x, z), z)
	return Vector3.INF


func _spawn_items() -> void:
	var placed: Array = []
	for i in 30:
		var p := _free_spot(28.0, placed, 14.0)
		if p == Vector3.INF:
			continue
		placed.append(p)
		var kind := _pick_item_kind()
		var col: Color = ITEM_TYPES[kind]["color"]
		var node := _item_visual(kind, col)
		node.position = p + Vector3(0, 1.0, 0)
		add_child(node)
		items.append({"kind": kind, "node": node, "pos": p + Vector3(0, 1.0, 0), "taken": false, "color": col, "phase": rng.randf() * TAU})
	if not Game.has_treasure(place_idx):
		var tp := _free_spot(130.0, placed, 20.0)
		if tp == Vector3.INF:
			tp = _free_spot(80.0, placed, 10.0)
		if tp != Vector3.INF:
			var node2 := _item_visual("treasure", Color(1, 0.8, 0.3))
			node2.position = tp + Vector3(0, 0.4, 0)
			node2.rotation.y = rng.randf() * TAU
			add_child(node2)
			items.append({"kind": "treasure", "node": node2, "pos": tp + Vector3(0, 0.4, 0), "taken": false, "color": Color(1, 0.8, 0.3), "phase": 0.0})


func _collect(it: Dictionary) -> void:
	it["taken"] = true
	taken_count += 1
	var n: Node3D = it["node"]
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	var bonus: float = (1.0 + float(car.stats.get("loot_bonus", 0.0))) * loot_mult
	Game.run_add("items", 1)
	match it["kind"]:
		"scrap":
			var a := int(round(rng.randi_range(3, 7) * bonus))
			Game.run_add("scrap", a)
			Game.run_add("xp", 4)
			hud.toast("+%d خردة" % a, ITEM_TYPES["scrap"]["color"])
			audio.play("pickup")
		"coins":
			var a2 := int(round(rng.randi_range(15, 45) * bonus))
			Game.run_add("coins", a2)
			Game.run_add("xp", 4)
			hud.toast("+%d فلوس" % a2, ITEM_TYPES["coins"]["color"])
			audio.play("pickup")
		"parts":
			var a3 := int(round(rng.randi_range(1, 3) * bonus))
			Game.run_add("parts", a3)
			Game.run_add("xp", 8)
			hud.toast("+%d قطع غيار" % a3, ITEM_TYPES["parts"]["color"])
			audio.play("pickup")
		"crystal":
			Game.run_add("crystals", 1)
			Game.run_add("xp", 25)
			hud.toast("+1 حجر نادر!", ITEM_TYPES["crystal"]["color"])
			audio.play("rare")
		"fuel":
			var max_f: float = car.stats["fuel"]
			car.fuel = minf(car.fuel + max_f * 0.4, max_f)
			Game.run_add("xp", 2)
			hud.toast("+40% بانزين", ITEM_TYPES["fuel"]["color"])
			audio.play("fuel")
		"treasure":
			var c := int(300 * loot_mult)
			Game.run_add("coins", c)
			Game.run_add("parts", 10)
			Game.run_add("crystals", 3)
			Game.run_add("xp", 120)
			Game.mark_treasure(place_idx)
			hud.toast("لكيت الكنز! +%d فلوس +10 قطع +3 أحجار" % c, Color(1, 0.85, 0.3), 5.0)
			audio.play("rare", 0.0)


# ================================================================ البيئة
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SkyShader
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.5
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	add_child(moon)
	flash = DirectionalLight3D.new()
	flash.light_color = Color(0.85, 0.9, 1.0)
	flash.light_energy = 0.0
	flash.rotation = Vector3(-1.2, 0.4, 0)
	flash.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(flash)


func _make_particles(amount: int, lifetime: float, mesh: Mesh, pm: ParticleProcessMaterial) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.draw_pass_1 = mesh
	p.process_material = pm
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount_ratio = 0.0
	p.preprocess = 0.0
	add_child(p)
	return p


func _particle_mat(col: Color, tex: Texture2D, billboard: int, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m


func _build_weather_fx() -> void:
	var soft := _soft_texture()
	# المطر
	var rpm := ParticleProcessMaterial.new()
	rpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rpm.emission_box_extents = Vector3(38, 1, 38)
	rpm.direction = Vector3(0.1, -1, 0.05)
	rpm.spread = 2.0
	rpm.initial_velocity_min = 24.0
	rpm.initial_velocity_max = 30.0
	rpm.gravity = Vector3(0, -9.8, 0)
	var rq := QuadMesh.new()
	rq.size = Vector2(0.035, 1.0)
	rq.material = _particle_mat(Color(0.78, 0.82, 0.92, 0.45), null, BaseMaterial3D.BILLBOARD_FIXED_Y, true)
	rain_fx = _make_particles(6000, 1.3, rq, rpm)
	# الثلج
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spm.emission_box_extents = Vector3(42, 1, 42)
	spm.direction = Vector3(0, -1, 0)
	spm.spread = 15.0
	spm.initial_velocity_min = 1.5
	spm.initial_velocity_max = 3.0
	spm.gravity = Vector3(0.4, -1.2, 0)
	spm.turbulence_enabled = true
	spm.turbulence_noise_strength = 2.0
	spm.turbulence_influence_min = 0.05
	spm.turbulence_influence_max = 0.15
	spm.scale_min = 0.6
	spm.scale_max = 1.4
	var sq := QuadMesh.new()
	sq.size = Vector2(0.16, 0.16)
	sq.material = _particle_mat(Color(1, 1, 1, 0.95), soft, BaseMaterial3D.BILLBOARD_PARTICLES, true)
	snow_fx = _make_particles(4000, 8.0, sq, spm)
	# العاصفة الترابية
	var dpm := ParticleProcessMaterial.new()
	dpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dpm.emission_box_extents = Vector3(45, 8, 45)
	dpm.direction = Vector3(1, 0, 0.3)
	dpm.spread = 10.0
	dpm.initial_velocity_min = 10.0
	dpm.initial_velocity_max = 18.0
	dpm.gravity = Vector3.ZERO
	dpm.scale_min = 0.6
	dpm.scale_max = 1.8
	var dq := QuadMesh.new()
	dq.size = Vector2(5, 5)
	var dcol: Color = biome["dust"]
	dq.material = _particle_mat(Color(dcol.r, dcol.g, dcol.b, 0.16), soft, BaseMaterial3D.BILLBOARD_PARTICLES)
	sand_fx = _make_particles(700, 4.0, dq, dpm)
	# جزيئات البيئة (أوراق الخريف / يراعات / رماد)
	var amb: String = biome["ambient"]
	if season == "autumn" and biome["veg"]:
		amb = "leaves"
	if amb != "":
		var apm := ParticleProcessMaterial.new()
		apm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		apm.emission_box_extents = Vector3(40, 6, 40)
		apm.turbulence_enabled = true
		apm.turbulence_noise_strength = 3.0
		var aq := QuadMesh.new()
		match amb:
			"leaves":
				apm.gravity = Vector3(0.5, -0.8, 0.2)
				apm.angular_velocity_min = -180
				apm.angular_velocity_max = 180
				aq.size = Vector2(0.22, 0.16)
				aq.material = _particle_mat(Color(0.9, 0.5, 0.12), null, BaseMaterial3D.BILLBOARD_PARTICLES)
			"fireflies":
				apm.gravity = Vector3.ZERO
				apm.emission_box_extents = Vector3(40, 2, 40)
				aq.size = Vector2(0.12, 0.12)
				var fm := _particle_mat(Color(0.8, 1.0, 0.4), soft, BaseMaterial3D.BILLBOARD_PARTICLES, true)
				fm.emission_enabled = true
				fm.emission = Color(0.8, 1.0, 0.3)
				fm.emission_energy_multiplier = 4.0
				aq.material = fm
			"ash":
				apm.gravity = Vector3(0.2, -0.5, 0)
				aq.size = Vector2(0.12, 0.12)
				aq.material = _particle_mat(Color(0.35, 0.33, 0.32), soft, BaseMaterial3D.BILLBOARD_PARTICLES)
		ambient_fx = _make_particles(260, 8.0, aq, apm)
		ambient_fx.set_meta("kind", amb)
	# غبار التايرات
	var dust_col: Color = biome["dust"]
	if base_snow > 0.3:
		dust_col = dust_col.lerp(Color(0.96, 0.97, 1.0), 0.75)
	for i in 4:
		var wpm := ParticleProcessMaterial.new()
		wpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		wpm.emission_sphere_radius = 0.35
		wpm.direction = Vector3(0, 1, 0)
		wpm.spread = 70.0
		wpm.initial_velocity_min = 0.5
		wpm.initial_velocity_max = 2.6
		wpm.gravity = Vector3(0, -0.35, 0)
		wpm.damping_min = 0.6
		wpm.damping_max = 1.2
		wpm.scale_min = 1.0
		wpm.scale_max = 2.4
		var curve := Curve.new()
		curve.max_value = 2.0
		curve.add_point(Vector2(0, 0.35))
		curve.add_point(Vector2(1, 1.8))
		var ct := CurveTexture.new()
		ct.curve = curve
		wpm.scale_curve = ct
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.0))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		grad.add_point(0.08, Color(1, 1, 1, 0.7))
		var gtex := GradientTexture1D.new()
		gtex.gradient = grad
		wpm.color_ramp = gtex
		wpm.color = dust_col
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 1.2)
		q.material = _particle_mat(Color(1, 1, 1, 1), soft, BaseMaterial3D.BILLBOARD_PARTICLES)
		var dp := _make_particles(140, 2.8, q, wpm)
		dust_emitters.append(dp)
	# رشاش الماي
	var spl := ParticleProcessMaterial.new()
	spl.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spl.emission_sphere_radius = 1.2
	spl.direction = Vector3(0, 1, 0)
	spl.spread = 50.0
	spl.initial_velocity_min = 2.0
	spl.initial_velocity_max = 5.0
	spl.gravity = Vector3(0, -9.8, 0)
	spl.scale_min = 0.5
	spl.scale_max = 1.2
	var sq2 := QuadMesh.new()
	sq2.size = Vector2(0.5, 0.5)
	var scol := Color(0.95, 0.97, 1.0, 0.7)
	if water_kind == "lava":
		scol = Color(1.0, 0.5, 0.1, 0.9)
	sq2.material = _particle_mat(scol, soft, BaseMaterial3D.BILLBOARD_PARTICLES, true)
	splash = _make_particles(200, 1.2, sq2, spl)


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
	mmi.custom_aabb = AABB(Vector3(-SIZE, -100, -SIZE), Vector3(SIZE * 2, 300, SIZE * 2))
	add_child(mmi)
	for i in 4:
		track_last.append(Vector3.INF)


func _spawn_birds() -> void:
	if not biome["birds"]:
		return
	var bm := PrismMesh.new()
	bm.size = Vector3(0.7, 0.12, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95) if water_kind == "sea" else Color(0.15, 0.13, 0.12)
	for f in 7:
		var p := _free_spot(35.0, [], 0.0)
		if p == Vector3.INF:
			continue
		var flock := []
		for i in rng.randi_range(3, 7):
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = mat
			var off := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			mi.position = p + off + Vector3(0, 0.15, 0)
			mi.rotation.y = rng.randf() * TAU
			add_child(mi)
			flock.append({"node": mi, "vel": Vector3.ZERO, "phase": rng.randf() * TAU, "home": mi.position})
		birds.append({"birds": flock, "center": p, "state": "idle", "t": 0.0})


func _spawn_car() -> void:
	car = IbraCar.new()
	car.setup(Game.active_car(), Game.car_paint(Game.active_car()))
	add_child(car)
	car.reset_upright(Vector3(spawn.x, spawn_h + 1.2, spawn.z))
	safe_hist.append([Vector3(spawn.x, spawn_h + 0.5, spawn.z), 0.0])
	car.water_level = water_level
	car.contact_monitor = true
	car.max_contacts_reported = 8
	car.body_shape_entered.connect(_on_car_hit)
	surface_update()
	cam = CamScript.new()
	cam.far = 900.0
	cam.target = car
	cam.world = self
	add_child(cam)
	cam.make_current()
	cam.snap()
	if city_density >= 0.9:
		cam.mode = 1
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	hud.resume_pressed.connect(_toggle_pause)
	hud.camera_pressed.connect(func(): hud.toast("الكاميرا: " + cam.cycle()))
	hud.garage_pressed.connect(func(): _tow())
	hud.quit_pressed.connect(func(): get_tree().quit())
	audio = AudioScript.new()
	add_child(audio)


func _build_minimap_tex() -> void:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	for j in s:
		for i in s:
			var x := -SIZE / 2.0 + (i + 0.5) * SIZE / s
			var z := -SIZE / 2.0 + (j + 0.5) * SIZE / s
			var h := h_at(x, z)
			var c := _ground_color(x, z, h, 1.0 - normal_at(x, z).y)
			if has_water and h < water_level:
				c = Color(0.85, 0.3, 0.05) if water_kind == "lava" else (Color(0.75, 0.88, 0.95) if water_kind == "ice" else Color(0.15, 0.5, 0.65))
			if city_density > 0.0:
				if on_road(x, z):
					c = Color(0.18, 0.18, 0.2)
				elif in_building(x, z):
					c = Color(0.45, 0.45, 0.5)
			img.set_pixel(i, j, c)
	minimap_tex = ImageTexture.create_from_image(img)
	hud.minimap.tex = minimap_tex
	hud.minimap.world = self


# ================================================================ كل فريم
func surface_update() -> void:
	var p := car.global_position
	var g: float = biome["grip"]
	if city_density > 0.0:
		g = 1.0 if on_road(p.x, p.z) else maxf(g * 0.85, 0.7)
	if water_kind == "ice" and h_at(p.x, p.z) < water_level - 0.05:
		g = 0.3
	if in_field(p.x, p.z):
		g = 0.65
	if has_track and track_dist(p.x, p.z) < TRACK_W * 0.5:
		g = maxf(g, 0.88)
	g *= lerpf(1.0, 0.82, wet_acc)
	g *= lerpf(1.0, 0.85, clampf(snow_acc + base_snow * 0.5, 0.0, 1.0))
	car.surface_grip = g


func _input(event: InputEvent) -> void:
	if paused:
		return
	if event.is_action_pressed("camera"):
		hud.toast("الكاميرا: " + cam.cycle(), Color(0.8, 0.9, 1.0), 1.5)
	elif event.is_action_pressed("headlights"):
		auto_lights = false
		car.set_lights(not car.lights_on)
	elif event.is_action_pressed("reset_car"):
		if stuck_timer > 1.5 or car.water_depth > -0.3 or car.fuel <= 0.0:
			_rescue("رجعناك لمكان آمن", false)
		else:
			car.reset_upright()
	elif event.is_action_pressed("interact"):
		if _near_garage():
			Game.end_trip(1.0, "garage")
	elif event.is_action_pressed("tow"):
		if tow_confirm > 0.0:
			_tow()
		else:
			tow_confirm = 3.0
			hud.toast("اضغط T مرة ثانية حتى تجيك سيارة السحب (تخسر 40% من الغنائم)", Color(1, 0.7, 0.4), 3.0)


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	hud.show_pause(paused)


func _tow() -> void:
	get_tree().paused = false
	Game.end_trip(0.6, "tow")


func _near_garage() -> bool:
	return car.global_position.distance_to(Vector3(spawn.x, spawn_h, spawn.z)) < 7.5 and absf(car.speed) < 7.0


func _physics_process(delta: float) -> void:
	if car == null:
		return
	surface_update()
	_update_tracks_and_dust()
	_update_items(delta)
	_check_hazards(delta)


func _process(delta: float) -> void:
	if car == null:
		return
	hour = fmod(hour + delta / DAY_SECONDS_PER_HOUR, 24.0)
	_update_weather(delta)
	_update_daylight(delta)
	_update_birds(delta)
	_update_audio()
	_update_debris()
	tow_confirm = maxf(tow_confirm - delta, 0.0)
	var cp := car.global_position
	_update_car_dust(delta)
	for gm in grass_mats:
		(gm as ShaderMaterial).set_shader_parameter("car_pos", cp)
	var follow := cp + Vector3(car.linear_velocity.x, 0, car.linear_velocity.z) * 0.6
	rain_fx.global_position = follow + Vector3(0, 22, 0)
	snow_fx.global_position = follow + Vector3(0, 16, 0)
	sand_fx.global_position = follow + Vector3(-30, 5, -10)
	if ambient_fx:
		ambient_fx.global_position = follow + Vector3(0, 6, 0)
	if ring:
		ring.rotation.y += delta * 0.6
	_update_prompt()
	var p := place
	hud.update_hud({
		"place": p["name"],
		"sub": "%s • %s • %s" % [biome["name"], Places.SEASONS[season], Places.WEATHER[weather]["name"]],
		"clock": "%s  %s" % [Places.hour_text(hour), Places.time_name(hour)],
		"speed": absf(car.speed) * 3.6, "fuel": car.fuel, "fuel_max": car.stats["fuel"],
		"nitro": car.nitro, "nitro_max": car.max_nitro, "cam": cam.MODES[cam.mode]["name"],
		"taken": taken_count, "total": items.size(),
	})


func _update_prompt() -> void:
	var txt := ""
	if _near_garage():
		txt = "اضغط E حتى تدخل الكراج وتحفظ كل الغنائم"
	elif car.fuel <= 0.0:
		txt = "خلص البانزين! دوّر جليكان أحمر قريب أو اضغط T حتى تسحبك سيارة السحب"
	elif flip_timer > 1.5:
		txt = "السيارة انقلبت — اضغط R حتى تعدلها"
	elif water_timer > 1.5:
		txt = "انت بالماي! اطلع منه أو اضغط R حتى ترجع لمكان آمن (يرجعك وحده بعد %d ثواني)" % int(ceil(6.0 - water_timer))
	elif stuck_timer > 3.0:
		txt = "علكت؟ اضغط R حتى ترجع لمكان آمن"
	elif treasure_hint_t > 0.0:
		txt = "الكنز قريب منك! دوّر حواليك..."
	hud.set_prompt(txt)


func _update_tracks_and_dust() -> void:
	var wheels := car.wheels
	var spd := car.linear_velocity.length()
	var dusty: float = biome["dusty"]
	var on_asphalt := city_density > 0.0 and on_road(car.global_position.x, car.global_position.z)
	if on_asphalt:
		dusty = 0.08
	var in_water := car.water_depth > -0.5 and water_kind != "ice"
	for i in 4:
		var w: Dictionary = wheels[i]
		var dp: GPUParticles3D = dust_emitters[i]
		if w["grounded"]:
			var cpos: Vector3 = w["contact"]
			dp.global_position = cpos + Vector3(0, 0.3, 0)
			var slipv := absf(float(w["lat_v"]))
			var amt := clampf((spd - 2.0) / 22.0 + slipv * 0.12, 0.0, 1.0) * dusty
			if not w["front"]:
				amt *= 1.3
			else:
				amt *= 0.5
			if in_water:
				amt = 0.0
			dp.amount_ratio = clampf(amt, 0.0, 1.0)
			var leave := not on_asphalt or slipv > 4.0
			if in_water or (has_water and cpos.y < water_level - 0.1 and water_kind != "ice"):
				leave = false
			var last: Vector3 = track_last[i]
			if leave and (last == Vector3.INF or last.distance_to(cpos) > 0.5):
				if last != Vector3.INF and last.distance_to(cpos) < 3.0:
					var fwd := (cpos - last).normalized()
					var n: Vector3 = w["normal"]
					var right := fwd.cross(n).normalized()
					var f2 := n.cross(right).normalized()
					var xf := Transform3D(Basis(right, n, -f2), cpos + n * 0.06)
					track_mm.set_instance_transform(track_count % 4000, xf)
					track_count += 1
					track_mm.visible_instance_count = mini(track_count, 4000)
				track_last[i] = cpos
			elif not leave:
				track_last[i] = Vector3.INF
		else:
			dp.amount_ratio = 0.0
			track_last[i] = Vector3.INF
	splash.global_position = car.global_position
	splash.amount_ratio = clampf(spd / 12.0, 0.0, 1.0) if (in_water and car.water_depth < 1.5) else 0.0


func _update_items(delta: float) -> void:
	var cp := car.global_position
	var magnet: float = car.stats["magnet"]
	var t := Time.get_ticks_msec() / 1000.0
	treasure_hint_t = maxf(treasure_hint_t - delta, 0.0)
	for it in items:
		if it["taken"]:
			continue
		var n: Node3D = it["node"]
		var pos: Vector3 = it["pos"]
		var d := pos.distance_to(cp)
		if it["kind"] == "treasure":
			if d < 35.0:
				treasure_hint_t = 0.5
		else:
			n.rotation.y += delta * 1.5
			n.position.y = pos.y + sin(t * 2.0 + it["phase"]) * 0.2
			if magnet > 0.0 and d < magnet:
				pos = pos.move_toward(cp, delta * 18.0)
				it["pos"] = pos
				n.position.x = pos.x
				n.position.z = pos.z
		if d < 3.2:
			_collect(it)


func _check_hazards(delta: float) -> void:
	# انقلاب
	if car.is_flipped() and car.linear_velocity.length() < 3.0:
		flip_timer += delta
	else:
		flip_timer = 0.0
	var hspeed := Vector2(car.linear_velocity.x, car.linear_velocity.z).length()
	var in_water := has_water and water_kind != "ice" and water_kind != "lava" and car.water_depth > 0.15
	# علكة: يدوس بنزين وما يتحرك
	if (car.throttle_in > 0.3 or car.brake_in > 0.3) and hspeed < 1.5:
		stuck_timer += delta
	elif hspeed > 3.0:
		stuck_timer = maxf(stuck_timer - delta * 3.0, 0.0)
	water_timer = water_timer + delta if in_water else 0.0
	# حمم = رجوع فوري
	if water_kind == "lava" and car.water_depth > -0.3:
		_rescue("احترقت السيارة بالحمم! رجعناك لمكان آمن", true)
		return
	# غرق عميق
	if in_water and car.water_depth > 1.2:
		drown_timer += delta
		if drown_timer > 1.5:
			_rescue("السيارة غرقت! رجعناك لمكان آمن", true)
			return
	else:
		drown_timer = 0.0
	# بالماي فترة طويلة أو عالكة: رجوع تلقائي
	if water_timer > 6.0:
		_rescue("السيارة علكت بالماي، رجعناك لمكان آمن", false)
		return
	if stuck_timer > 9.0 or (car.fuel <= 0.0 and in_water):
		_rescue("السيارة علكت، رجعناك لمكان آمن", false)
		return
	# نسجل الأماكن الآمنة (مستوية، بعيدة عن الماي، والسيارة واقفة على تاياراتها)
	safe_timer += delta
	if safe_timer > 1.0:
		safe_timer = 0.0
		_record_safe()
	if car.fuel <= 0.0 and not fuel_warned:
		fuel_warned = true
		hud.toast("خلص البانزين!", Color(1, 0.4, 0.3), 4.0)
		audio.play("error")
	if car.fuel > 0.0:
		fuel_warned = false
	# طاح برا العالم
	if car.global_position.y < -40.0:
		_rescue("رجعناك لمكان آمن", false)


func _is_safe_spot(p: Vector3) -> bool:
	if absf(p.x) > SIZE / 2.0 - 25.0 or absf(p.z) > SIZE / 2.0 - 25.0:
		return false
	var h := h_at(p.x, p.z)
	if has_water:
		# لازم يكون أعلى من الماي وما بيه ماي قريب (3 أمتار حواليه)
		for o in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
			if h_at(p.x + o.x, p.z + o.y) < water_level + 0.8:
				return false
	if normal_at(p.x, p.z).y < 0.9:
		return false
	if city_density > 0.0 and in_building(p.x, p.z, 2.0):
		return false
	return h > -30.0


func _record_safe() -> void:
	if car.grounded_count < 3 or car.is_flipped() or car.water_depth > -0.8:
		return
	var p := car.global_position
	if not _is_safe_spot(p):
		return
	if not safe_hist.is_empty() and (safe_hist[safe_hist.size() - 1][0] as Vector3).distance_to(p) < 4.0:
		return
	var f := -car.global_basis.z
	safe_hist.append([p, atan2(-f.x, -f.z)])
	if safe_hist.size() > 30:
		safe_hist.pop_front()


## يرجّع السيارة لمكان آمن قديم شوية (مو آخر نقطة حتى ما ترجع تطيح)
func _rescue(msg: String, penalty: bool) -> void:
	var target := Vector3(spawn.x, spawn_h, spawn.z)
	var yaw := 0.0
	while not safe_hist.is_empty():
		var idx := maxi(safe_hist.size() - 4, 0)
		var e: Array = safe_hist[idx]
		safe_hist.resize(idx)
		var p: Vector3 = e[0]
		if _is_safe_spot(p) and p.distance_to(car.global_position) > 6.0:
			target = p
			yaw = e[1]
			break
	target.y = h_at(target.x, target.z) + 1.3
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), target)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	stuck_timer = 0.0
	water_timer = 0.0
	drown_timer = 0.0
	flip_timer = 0.0
	if penalty:
		car.fuel = maxf(car.fuel - car.stats["fuel"] * 0.05, 0.0)
	if car.fuel < car.stats["fuel"] * 0.15:
		car.fuel = car.stats["fuel"] * 0.15
	hud.toast(msg, Color(1, 0.6, 0.4), 3.0)
	audio.play("error")


# ================================================================ الجو والوقت
func _update_weather(delta: float) -> void:
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = rng.randf_range(150.0, 280.0)
		var pool := Places.weathers_for(biome, season)
		var next: String = pool[rng.randi() % pool.size()]
		if rng.randf() < 0.4:
			next = weather
		if next != weather:
			weather = next
			hud.toast("الجو يتغير: " + Places.WEATHER[weather]["name"], Color(0.8, 0.9, 1.0), 3.5)
	var target: Dictionary = Places.WEATHER[weather]
	var k := 1.0 - exp(-0.12 * delta)
	for key in target:
		if key == "name":
			continue
		wcur[key] = lerpf(wcur.get(key, 0.0), target[key], k)
	var raining: float = wcur["rain"]
	var snowing: float = wcur["snow"]
	rain_fx.amount_ratio = clampf(raining * 0.7, 0.0, 1.0)
	rain_fx.emitting = raining > 0.02
	snow_fx.amount_ratio = clampf(snowing, 0.0, 1.0)
	snow_fx.emitting = snowing > 0.02
	sand_fx.amount_ratio = clampf(wcur["sand"], 0.0, 1.0)
	sand_fx.emitting = wcur["sand"] > 0.02
	if ambient_fx:
		var akind: String = ambient_fx.get_meta("kind")
		var night := 1.0 - _day_factor()
		if akind == "fireflies":
			ambient_fx.amount_ratio = clampf(night * (1.0 - raining), 0.0, 1.0) if season != "winter" else 0.0
		else:
			ambient_fx.amount_ratio = 0.7
	# تراكم المطر والثلج
	wet_acc = move_toward(wet_acc, wcur["wet"], delta * (0.05 if wcur["wet"] > wet_acc else 0.01))
	if snowing > 0.3:
		snow_acc = minf(snow_acc + delta * 0.006 * snowing, 0.8)
	elif season != "winter":
		snow_acc = maxf(snow_acc - delta * 0.002, 0.0)
	ground_mat.set_shader_parameter("wetness", wet_acc)
	ground_mat.set_shader_parameter("snow_cover", clampf(base_snow + snow_acc, 0.0, 1.0))
	for gm in grass_mats:
		(gm as ShaderMaterial).set_shader_parameter("wind", wcur["wind"])
		(gm as ShaderMaterial).set_shader_parameter("snow", clampf(base_snow * 0.6 + snow_acc, 0.0, 1.0))
		(gm as ShaderMaterial).set_shader_parameter("wet", wet_acc)
	if building_mat:
		building_mat.set_shader_parameter("wet", wet_acc)
	if road_mat:
		road_mat.roughness = lerpf(0.85, 0.2, wet_acc)
		road_mat.metallic_specular = lerpf(0.5, 0.9, wet_acc)
	# البرق
	if raining > 1.2:
		lightning_timer -= delta
		if lightning_timer <= 0.0:
			lightning_timer = rng.randf_range(5.0, 14.0)
			flash_t = 0.35
			get_tree().create_timer(rng.randf_range(0.5, 2.0)).timeout.connect(_thunder)
	flash_t = maxf(flash_t - delta, 0.0)
	flash.light_energy = (3.5 if fmod(flash_t, 0.12) > 0.05 else 0.0) if flash_t > 0.0 else 0.0
	cloud_off += Vector2(0.004, 0.002) * delta * (0.5 + wcur["wind"])


func _thunder() -> void:
	if is_instance_valid(audio):
		audio.play("thunder", 2.0)


func _sun_angle() -> float:
	# الشمس تطلع 5:30 وتغيب 19:00
	var h := fmod(hour - 5.5 + 24.0, 24.0)
	if h <= 13.5:
		return h / 13.5 * PI
	return PI + (h - 13.5) / 10.5 * PI


func _day_factor() -> float:
	return smoothstep(-0.18, 0.12, sin(_sun_angle()))


func _update_daylight(_delta: float) -> void:
	var a := _sun_angle()
	var e := sin(a)
	var day := smoothstep(-0.18, 0.12, e)
	var warm := (1.0 - smoothstep(0.0, 0.45, absf(e))) * smoothstep(-0.25, 0.0, e)
	var light_w: float = wcur["light"]
	var clouds: float = wcur["clouds"]
	var dir_sun := Vector3(cos(a), sin(a) * 0.9, 0.42).normalized()
	sun.basis = Basis.looking_at(-dir_sun, Vector3.UP)
	var dir_moon := Vector3(-cos(a), -sin(a) * 0.9, 0.42).normalized()
	moon.basis = Basis.looking_at(-dir_moon, Vector3.UP)
	sun.light_color = Color(1.0, 0.52, 0.28).lerp(Color(1.0, 0.96, 0.9), smoothstep(0.05, 0.5, e))
	sun.light_energy = smoothstep(-0.03, 0.15, e) * 1.3 * light_w
	sun.shadow_enabled = e > 0.0
	moon.light_energy = (1.0 - day) * 0.28 * lerpf(1.0, 0.5, clouds)
	moon.shadow_enabled = day < 0.5
	var night_top := Color(0.01, 0.015, 0.045)
	var night_hz := Color(0.035, 0.045, 0.085)
	var top := night_top.lerp(Color(0.2, 0.43, 0.82), day)
	var hz := night_hz.lerp(Color(0.68, 0.8, 0.93), day)
	hz = hz.lerp(Color(0.98, 0.56, 0.3), warm * 0.8)
	top = top.lerp(Color(0.35, 0.3, 0.55), warm * 0.35)
	var grey := Color(0.55, 0.58, 0.62) * lerpf(0.08, 1.0, day)
	top = top.lerp(grey * 0.9, clouds * 0.75)
	hz = hz.lerp(grey, clouds * 0.6)
	if wcur["sand"] > 0.01:
		var dc: Color = biome["dust"]
		hz = hz.lerp(dc * lerpf(0.15, 1.0, day), wcur["sand"] * 0.85)
		top = top.lerp(dc * lerpf(0.1, 0.8, day), wcur["sand"] * 0.6)
	var ground_c: Color = biome["low"]
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hz)
	sky_mat.set_shader_parameter("ground_color", ground_c.darkened(0.3) * lerpf(0.1, 1.0, day))
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("stars", (1.0 - day) * (1.0 - clouds))
	sky_mat.set_shader_parameter("clouds", clouds)
	sky_mat.set_shader_parameter("cloud_color", Color(1, 1, 1).lerp(hz, 0.4) * lerpf(0.12, 1.0, day) * lerpf(1.0, 0.7, clouds))
	sky_mat.set_shader_parameter("cloud_offset", cloud_off)
	sky_mat.set_shader_parameter("sun_visible", (1.0 - clouds * 0.9) * smoothstep(-0.05, 0.05, e))
	sky_mat.set_shader_parameter("moon_visible", (1.0 - day) * (1.0 - clouds))
	env.ambient_light_color = Color(0.13, 0.16, 0.27).lerp(hz.lerp(top, 0.5), day)
	env.ambient_light_energy = lerpf(0.5, 0.75, day)
	env.fog_light_color = hz
	env.fog_density = wcur["fog"] * (1.0 + (1.0 - day) * 0.3)
	env.fog_light_energy = lerpf(0.3, 1.0, day)
	# الأضواء الليلية
	var dark: bool = day < 0.35 or (wcur["fog"] > 0.02) or (light_w < 0.35 and day < 0.7)
	if auto_lights and car and dark != car.lights_on:
		car.set_lights(dark)
	var night_city := day < 0.4
	if night_city != night_lights_on:
		night_lights_on = night_city
		for l in lamp_lights:
			(l as OmniLight3D).visible = night_city
		if lamp_head_mat:
			lamp_head_mat.emission_energy_multiplier = 3.0 if night_city else 0.0
	if building_mat:
		building_mat.set_shader_parameter("night", 1.0 - day)


func _update_birds(delta: float) -> void:
	if birds.is_empty():
		return
	var cp := car.global_position
	var t := Time.get_ticks_msec() / 1000.0
	for fl in birds:
		var c: Vector3 = fl["center"]
		match fl["state"]:
			"idle":
				if cp.distance_to(c) < 22.0:
					fl["state"] = "fly"
					fl["t"] = 0.0
					var away := (c - cp)
					away.y = 0
					away = away.normalized()
					for b in fl["birds"]:
						b["vel"] = (away * rng.randf_range(7, 11) + Vector3(rng.randf_range(-3, 3), rng.randf_range(4, 7), rng.randf_range(-3, 3)))
				else:
					for b in fl["birds"]:
						var n: Node3D = b["node"]
						n.rotation.x = sin(t * 6.0 + b["phase"]) * 0.2
			"fly":
				fl["t"] += delta
				for b in fl["birds"]:
					var n2: Node3D = b["node"]
					var v: Vector3 = b["vel"]
					v.y = maxf(v.y - delta * 0.6, 1.0)
					b["vel"] = v
					n2.position += v * delta
					n2.look_at(n2.position + v, Vector3.UP)
					n2.scale = Vector3(1.0 + sin(t * 18.0 + b["phase"]) * 0.45, 1, 1)
				if fl["t"] > 14.0:
					fl["state"] = "away"
					for b in fl["birds"]:
						(b["node"] as Node3D).visible = false
			"away":
				fl["t"] += delta
				if fl["t"] > 40.0 and cp.distance_to(c) > 60.0:
					fl["state"] = "idle"
					for b in fl["birds"]:
						var n3: Node3D = b["node"]
						n3.visible = true
						n3.position = b["home"]
						n3.rotation = Vector3(0, rng.randf() * TAU, 0)
						n3.scale = Vector3.ONE


func _update_audio() -> void:
	var top: float = car.stats["top_speed"]
	var s := absf(car.speed) / top
	var gears := 5.0
	var g := clampf(s * gears, 0.0, gears - 0.001)
	var within: float = g - floor(g)
	audio.rpm = clampf(0.15 + within * 0.75 + (0.1 if car.throttle_in > 0.1 else 0.0) + floor(g) * 0.04, 0.0, 1.2)
	audio.engine_load = car.throttle_in
	audio.engine_on = car.fuel > 0.0
	audio.rain = wcur["rain"]
	audio.wind = wcur["wind"] + wcur["sand"] * 2.0
	var near_sea := 0.0
	if water_kind == "sea" or water_kind == "lake":
		var cp := car.global_position
		var lowest := h_at(cp.x, cp.z)
		for o in [Vector2(25, 0), Vector2(-25, 0), Vector2(0, 25), Vector2(0, -25)]:
			lowest = minf(lowest, h_at(cp.x + o.x, cp.z + o.y))
		near_sea = 1.0 if lowest < water_level else 0.0
	audio.waves = lerpf(audio.waves, near_sea, 0.02)


# ================================================================ التكسير والهدم
# [النوع, أقل سرعة كم/س حتى ينكسر, نسبة السرعة اللي تبقى للسيارة]
const BREAK := {
	"tree": ["topple", 20.0, 0.75], "tree_big": ["topple", 38.0, 0.55], "pine": ["topple", 20.0, 0.75],
	"pine_snow": ["topple", 20.0, 0.75], "palm": ["topple", 18.0, 0.8], "acacia": ["topple", 20.0, 0.75],
	"dead_tree": ["topple", 6.0, 0.92], "pole": ["topple", 10.0, 0.88], "lamp": ["topple", 10.0, 0.88],
	"house": ["structure", 14.0, 0.6], "cabin": ["structure", 12.0, 0.65], "shack": ["structure", 8.0, 0.75],
	"tent": ["shatter", 8.0, 0.88], "mudhif": ["shatter", 20.0, 0.65], "snowman": ["shatter", 4.0, 0.95],
	"crystals": ["shatter", 15.0, 0.8], "wall": ["bricks", 12.0, 0.75],
	"wreck": ["push", 5.0, 0.8], "hay": ["push", 3.0, 0.9], "tires": ["push", 3.0, 0.92], "log": ["push", 5.0, 0.85],
	"building": ["dent", 25.0, 0.0],
	"barn": ["structure", 10.0, 0.7], "crates": ["crates", 3.0, 0.85], "marker": ["topple", 2.0, 0.97],
}
const SHATTER_COLORS := {
	"house": [Color(0.82, 0.72, 0.56), Color(0.7, 0.6, 0.46), Color(0.15, 0.2, 0.25)],
	"cabin": [Color(0.45, 0.3, 0.18), Color(0.3, 0.2, 0.15)],
	"shack": [Color(0.55, 0.43, 0.32), Color(0.5, 0.48, 0.45)],
	"tent": [Color(0.2, 0.15, 0.12), Color(0.6, 0.15, 0.12)],
	"mudhif": [Color(0.78, 0.66, 0.42), Color(0.65, 0.55, 0.35)],
	"snowman": [Color(0.95, 0.97, 1.0), Color(1, 0.45, 0.05)],
	"crystals": [Color(0.75, 0.35, 1.0), Color(0.9, 0.6, 1.0)],
	"building": [Color(0.78, 0.72, 0.62), Color(0.6, 0.6, 0.62), Color(0.3, 0.38, 0.45)],
}
const MAX_DEBRIS := 360

var debris: Array = []
var bursts: Array = []
var burst_i := 0
var debris_mats := {}
var broken_count := 0
var fx_pools := {}
var fx_idx := {}


func _on_car_hit(_rid: RID, body: Node, body_shape_index: int, _local: int) -> void:
	if body != null and body.has_meta("structure"):
		var v0: Vector3 = car.prev_vel
		if v0.length() * 3.6 >= 8.0:
			call_deferred("_hit_structure", body.get_meta("structure"), v0)
		return
	if props_body == null or body != props_body:
		return
	var owner_id := props_body.shape_find_owner(body_shape_index)
	var cs := props_body.shape_owner_get_owner(owner_id) as CollisionShape3D
	if cs == null or not cs.has_meta("prop") or cs.has_meta("broken"):
		return
	var info: Dictionary = cs.get_meta("prop")
	if not BREAK.has(info["kind"]):
		return
	var rule: Array = BREAK[info["kind"]]
	var v: Vector3 = car.prev_vel
	if v.length() * 3.6 < rule[1]:
		return
	if rule[0] != "dent":
		cs.set_meta("broken", true)
	call_deferred("_break_prop", cs, info, v, rule)


func _break_prop(cs: CollisionShape3D, info: Dictionary, v: Vector3, rule: Array) -> void:
	if not is_instance_valid(cs):
		return
	var kind: String = info["kind"]
	var dir := Vector3(v.x, 0, v.z)
	dir = dir.normalized() if dir.length() > 0.1 else -car.global_basis.z
	var spd := v.length()
	var hit_pos := cs.global_position
	if OS.get_cmdline_user_args().has("--debug-break"):
		print("BREAK ", kind, " ", rule[0], " kmh=", int(spd * 3.6), " t=", Time.get_ticks_msec())
	match rule[0]:
		"dent":
			_dent(cs, info, dir, spd)
			audio.play("crash", 0.0)
			return
		"topple":
			_topple(info, dir, spd)
			audio.play("crack", -2.0)
		"shatter":
			_shatter(info, dir, spd)
			audio.play("crash", 0.0)
		"bricks":
			_bricks(info, dir, spd)
			audio.play("crash", 0.0)
		"push":
			_push(info, dir, spd)
			audio.play("crash", -6.0)
		"structure":
			_build_structure(info, dir, spd)
			audio.play("crash", 0.0)
		"crates":
			_crates(info, dir, spd)
			audio.play("crack", -3.0)
	for r in info["refs"]:
		_hide_instance(r)
	if info.has("light") and is_instance_valid(info["light"]):
		lamp_lights.erase(info["light"])
		(info["light"] as Node).queue_free()
	cs.queue_free()
	car.linear_velocity = v * float(rule[2])
	_burst(hit_pos + Vector3(0, 0.6, 0))
	_break_reward(kind)


func _hide_instance(r: Variant) -> void:
	if r == null or not (r is Array):
		return
	var mm: MultiMesh = r[0]
	mm.set_instance_transform(r[1], Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -500, 0)))


func _debris_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not debris_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		debris_mats[key] = m
	return debris_mats[key]


func _register_debris(rb: RigidBody3D, life: float) -> void:
	rb.set_meta("born", Time.get_ticks_msec() / 1000.0)
	rb.set_meta("life", life)
	debris.append(rb)
	while debris.size() > MAX_DEBRIS:
		var old = debris.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _chunk(size: Vector3, col: Color, pos: Vector3, mass_kg: float, rot := Basis(), life := 60.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 3
	rb.mass = mass_kg
	rb.transform = Transform3D(rot, pos)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _debris_mat(col)
	rb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	add_child(rb)
	_register_debris(rb, life)
	return rb


func _prop_meshes_into(rb: Node3D, info: Dictionary, sc: Vector3) -> void:
	for r in info["refs"]:
		if r == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = (r[0] as MultiMesh).mesh
		mi.material_override = r[2]
		mi.scale = sc
		rb.add_child(mi)


## شجرة أو عمود: تنكسر من الجذع ويبقى الكعب، وتطيح بهدوء باتجاه السيارة
func _topple(info: Dictionary, dir: Vector3, spd: float) -> void:
	var kind: String = info["kind"]
	var t: Transform3D = info["xf"]
	var sc := t.basis.get_scale()
	var d: Vector2 = PropLib.SOLID[kind][1]
	var h := d.y * sc.y
	var rad := maxf(d.x * sc.x, 0.12)
	var is_tree := kind not in ["pole", "lamp"]
	var cut := 0.55 if is_tree else 0.35
	# الكعب اللي يبقى بالأرض
	var stump := Node3D.new()
	stump.position = t.origin
	add_child(stump)
	var wood := Color(0.36, 0.25, 0.16) if is_tree else Color(0.3, 0.28, 0.27)
	var sm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rad * 0.95
	cm.bottom_radius = rad * 1.2
	cm.height = cut
	cm.radial_segments = 8
	sm.mesh = cm
	sm.material_override = _debris_mat(wood)
	sm.position.y = cut * 0.5
	stump.add_child(sm)
	for j in 4:
		var sp := MeshInstance3D.new()
		var sp_m := CylinderMesh.new()
		sp_m.top_radius = 0.0
		sp_m.bottom_radius = rad * 0.35
		sp_m.height = rng.randf_range(0.15, 0.4)
		sp_m.radial_segments = 4
		sp.mesh = sp_m
		sp.material_override = _debris_mat(Color(0.75, 0.62, 0.45) if is_tree else wood)
		var a := TAU * j / 4.0 + rng.randf()
		sp.position = Vector3(cos(a) * rad * 0.5, cut + sp_m.height * 0.4, sin(a) * rad * 0.5)
		stump.add_child(sp)
	# الجزء اللي يطيح
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 3
	rb.mass = 140.0 if not is_tree or kind == "dead_tree" else 420.0
	rb.angular_damp = 0.4
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.05
	rb.physics_material_override = pm
	rb.transform = Transform3D(t.basis.orthonormalized(), t.origin + Vector3(0, cut * 0.15, 0))
	_prop_meshes_into(rb, info, sc)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rad
	cyl.height = h - cut
	cs.shape = cyl
	cs.position = Vector3(0, cut + (h - cut) * 0.5, 0)
	rb.add_child(cs)
	if is_tree and kind != "dead_tree":
		var crown := CollisionShape3D.new()
		var cb := BoxShape3D.new()
		cb.size = Vector3(2.2, 1.8, 2.2) * sc
		crown.shape = cb
		crown.position = Vector3(0, h * 0.72, 0)
		rb.add_child(crown)
	rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	rb.center_of_mass = Vector3(0, h * 0.55, 0)
	add_child(rb)
	# يبدي يميل باتجاه الضربة والجاذبية تكمل الطيحة
	var axis := Vector3.UP.cross(dir).normalized()
	rb.angular_velocity = axis * clampf(spd * 0.06, 0.45, 1.3)
	rb.linear_velocity = dir * minf(spd * 0.12, 2.0)
	_register_debris(rb, 60.0)
	var top := t.origin + Vector3(0, h * 0.75, 0)
	if is_tree:
		_leaves(top, info, 1.0)
		_splinters(t.origin + Vector3(0, cut, 0), Color(0.6, 0.48, 0.32))
		get_tree().create_timer(1.6).timeout.connect(func():
			if is_instance_valid(rb):
				_burst(rb.global_position + rb.global_basis.y * h * 0.6)
				_leaves(rb.global_position + rb.global_basis.y * h * 0.7, info, 0.7))
	else:
		_splinters(t.origin + Vector3(0, cut, 0), wood)
		if kind == "lamp":
			_sparks(t.origin + Vector3(0, 5.6, 0))


## بيت أو كوخ أو خيمة: يتفلش لقطع
func _shatter(info: Dictionary, dir: Vector3, spd: float) -> void:
	var kind: String = info["kind"]
	var t: Transform3D = info["xf"]
	var sc := t.basis.get_scale()
	var solid: Array = PropLib.SOLID[kind]
	var sz: Vector3
	if solid[0] == "box":
		sz = (solid[1] as Vector3) * sc
	else:
		var d: Vector2 = solid[1]
		sz = Vector3(d.x * 2.0 * sc.x, d.y * sc.y, d.x * 2.0 * sc.x)
	var cols: Array = SHATTER_COLORS.get(kind, [Color(0.6, 0.55, 0.5)])
	var big := sz.length() > 4.0
	var n := 22 if big else 9
	var rot := t.basis.orthonormalized()
	var k := clampf(sz.length() / 8.0, 0.35, 1.0)
	for i in n:
		var csize := Vector3(rng.randf_range(0.5, 1.5), rng.randf_range(0.3, 1.0), rng.randf_range(0.3, 1.3)) * k
		var lp := Vector3(rng.randf_range(-0.42, 0.42) * sz.x, rng.randf_range(0.15, 0.9) * sz.y, rng.randf_range(-0.42, 0.42) * sz.z)
		var rb := _chunk(csize, cols[i % cols.size()], t.origin + rot * lp, 50.0 * k, Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU), 16.0)
		var out := (rot * lp - Vector3(0, sz.y * 0.4, 0)).normalized()
		rb.apply_central_impulse((dir * spd * 0.5 + out * 3.5 + Vector3(0, rng.randf_range(2.0, 5.0), 0)) * rb.mass)
		rb.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * rb.mass * 1.5)
	if big:
		_rubble(t.origin, rot, Vector2(sz.x, sz.z), cols)


## أنقاض تبقى بالأرض (بدون تصادم)
func _rubble(center: Vector3, rot: Basis, area: Vector2, cols: Array) -> void:
	var node := Node3D.new()
	node.transform = Transform3D(rot, center)
	add_child(node)
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.2, 0.6), rng.randf_range(0.5, 1.4))
		mi.mesh = bm
		mi.material_override = _debris_mat((cols[i % cols.size()] as Color).darkened(0.15))
		mi.position = Vector3(rng.randf_range(-0.45, 0.45) * area.x, 0.25, rng.randf_range(-0.45, 0.45) * area.y)
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		node.add_child(mi)


## حايط طابوق: الطابوق القريب من الضربة يطير والباقي يبقى أو يوكع
func _bricks(info: Dictionary, dir: Vector3, spd: float) -> void:
	var t: Transform3D = info["xf"]
	var rot := t.basis.orthonormalized()
	var bc := Color(0.78, 0.7, 0.58)
	var impact := car.global_position
	var i := 0
	for br in PropLib.wall_bricks():
		var p: Vector3 = t.origin + rot * ((br[0] as Vector3) + Vector3(0, 0.3, 0))
		var shade := 0.9 + float((i * 7) % 5) * 0.035
		var rb := _chunk((br[1] as Vector3) - Vector3(0.02, 0.02, 0.0), Color(bc.r * shade, bc.g * shade, bc.b * shade), p, 25.0, rot, 30.0)
		var dd := Vector2(p.x - impact.x, p.z - impact.z).length()
		var f := clampf(1.0 - dd / 3.2, 0.0, 1.0)
		if f > 0.0:
			rb.apply_central_impulse((dir * spd * 0.7 * f + Vector3(rng.randf_range(-1, 1), 2.5 * f, rng.randf_range(-1, 1))) * rb.mass)
		else:
			rb.sleeping = true
		i += 1


## سيارة واقفة، تبن، تايرات، جذع: تندفع وتتدحرج
func _push(info: Dictionary, dir: Vector3, spd: float) -> void:
	var kind: String = info["kind"]
	var t: Transform3D = info["xf"]
	var sc := t.basis.get_scale()
	var solid: Array = PropLib.SOLID[kind]
	var sz: Vector3
	if solid[0] == "box":
		sz = (solid[1] as Vector3) * sc
	else:
		var d: Vector2 = solid[1]
		sz = Vector3(d.x * 2.0 * sc.x, d.y * sc.y, d.x * 2.0 * sc.x)
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 3
	rb.mass = 900.0 if kind == "wreck" else 120.0
	rb.transform = Transform3D(t.basis.orthonormalized(), t.origin + Vector3(0, 0.3, 0))
	_prop_meshes_into(rb, info, sc)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = Vector3(0, sz.y * 0.5, 0)
	rb.add_child(cs)
	add_child(rb)
	rb.apply_impulse((dir * spd * 0.55 + Vector3(0, 2.5, 0)) * rb.mass, Vector3(0, sz.y * 0.7, 0))
	_register_debris(rb, 70.0)


## عمارة: ينهدم جزء من الواجهة وين ما ضربت
func _dent(cs: CollisionShape3D, info: Dictionary, dir: Vector3, spd: float) -> void:
	var holes: int = info.get("holes", 0)
	if holes >= 4:
		return
	info["holes"] = holes + 1
	cs.set_meta("prop", info)
	var bs := cs.shape as BoxShape3D
	var half := bs.size * 0.5
	var c := cs.global_position
	var cp := car.global_position
	var lp := cp - c
	var normal: Vector3
	var fp: Vector3
	if absf(lp.x) / half.x > absf(lp.z) / half.z:
		normal = Vector3(signf(lp.x), 0, 0)
		fp = Vector3(c.x + normal.x * half.x, 0, clampf(cp.z, c.z - half.z + 2.0, c.z + half.z - 2.0))
	else:
		normal = Vector3(0, 0, signf(lp.z))
		fp = Vector3(clampf(cp.x, c.x - half.x + 2.0, c.x + half.x - 2.0), 0, c.z + normal.z * half.z)
	var ground := c.y - half.y + 0.5
	fp.y = ground + 1.6
	var hole := Node3D.new()
	add_child(hole)
	hole.global_position = fp + normal * 0.03
	hole.global_basis = Basis.looking_at(normal, Vector3.UP)
	var dark := _debris_mat(Color(0.05, 0.045, 0.04))
	var pieces := [[Vector3(3.2, 2.9, 0.06), Vector3(0, 0, 0)]]
	for j in 6:
		pieces.append([Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.5, 1.2), 0.06),
			Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.2, 1.8), 0)])
	for pc in pieces:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pc[0]
		mi.mesh = bm
		mi.material_override = dark
		mi.position = pc[1]
		mi.rotation.z = rng.randf_range(-0.4, 0.4)
		hole.add_child(mi)
	var cols: Array = SHATTER_COLORS["building"]
	for j in 14:
		var p := fp + normal * 0.6 + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.3), rng.randf_range(-1.5, 1.5)) * Vector3(1 - absf(normal.x), 1, 1 - absf(normal.z))
		var rb := _chunk(Vector3(rng.randf_range(0.3, 0.9), rng.randf_range(0.25, 0.7), rng.randf_range(0.3, 0.8)), cols[j % cols.size()], p, 30.0, Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU), 18.0)
		rb.apply_central_impulse((normal * rng.randf_range(2.0, 5.0) - dir * spd * 0.1 + Vector3(0, rng.randf_range(1.0, 3.0), 0)) * rb.mass)
	var rub_rot := Basis.looking_at(normal, Vector3.UP)
	_rubble(Vector3(fp.x, h_at(fp.x, fp.z), fp.z) + normal * 1.6, rub_rot, Vector2(3.5, 2.5), cols)
	_burst(fp + normal * 1.0)
	hud.toast("انهدم جزء من العمارة!", Color(1, 0.7, 0.45), 1.8)


func _build_bursts() -> void:
	var soft := _soft_texture()
	var dcol: Color = biome["dust"]
	if city_density > 0.0:
		dcol = Color(0.7, 0.68, 0.64)
	if base_snow > 0.3:
		dcol = dcol.lerp(Color(0.96, 0.97, 1.0), 0.75)
	for i in 3:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 1.5
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 80.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 5.0
		pm.gravity = Vector3(0, -0.6, 0)
		pm.damping_min = 1.0
		pm.damping_max = 2.0
		pm.scale_min = 1.0
		pm.scale_max = 2.2
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 0.45))
		grad.set_color(1, Color(1, 1, 1, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		pm.color = dcol
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		q.material = _particle_mat(Color(1, 1, 1, 1), soft, BaseMaterial3D.BILLBOARD_PARTICLES)
		var p := _make_particles(60, 2.6, q, pm)
		p.one_shot = true
		p.explosiveness = 0.92
		p.emitting = false
		p.amount_ratio = 1.0
		bursts.append(p)


func _burst(pos: Vector3) -> void:
	if bursts.is_empty():
		return
	var p: GPUParticles3D = bursts[burst_i % bursts.size()]
	burst_i += 1
	p.global_position = pos
	p.restart()
	p.emitting = true


func _break_reward(kind: String) -> void:
	broken_count += 1
	Game.run_add("xp", 1)
	match kind:
		"wreck":
			var a := rng.randi_range(2, 4)
			Game.run_add("scrap", a)
			hud.toast("+%d خردة من السيارة المحطمة" % a, ITEM_TYPES["scrap"]["color"], 1.8)
		"house", "cabin", "shack", "mudhif":
			var a2 := rng.randi_range(1, 3)
			Game.run_add("scrap", a2)
			hud.toast("+%d خردة من الأنقاض" % a2, ITEM_TYPES["scrap"]["color"], 1.8)
		"crystals":
			Game.run_add("crystals", 1)
			hud.toast("+1 حجر نادر من البلورات!", ITEM_TYPES["crystal"]["color"], 2.2)
			audio.play("rare")


func _update_debris() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(debris.size() - 1, -1, -1):
		var rb = debris[i]
		if not is_instance_valid(rb):
			debris.remove_at(i)
			continue
		if now - float(rb.get_meta("born")) > float(rb.get_meta("life")):
			debris.remove_at(i)
			rb.freeze = true
			var tw := create_tween()
			tw.tween_property(rb, "position:y", rb.position.y - 3.0, 2.5)
			tw.tween_callback(rb.queue_free)



# ---------------------------------------------------------------- هدم البيوت قطعة قطعة
## البيت يتحول لقطع ثابتة؛ اللي قريبة من الضربة تنكسر وتطيح، والسقف يوكع إذا انكسرت حيطان كافية
func _build_structure(info: Dictionary, dir: Vector3, spd: float) -> void:
	var kind: String = info["kind"]
	var t: Transform3D = info["xf"]
	var rot := t.basis.orthonormalized()
	var body := StaticBody3D.new()
	add_child(body)
	var rec := {"body": body, "pieces": [], "walls": 0, "gone": 0, "roof_down": false, "porch_down": false, "kind": kind}
	body.set_meta("structure", rec)
	for pc in PropLib.structure(kind):
		var xf := Transform3D(rot * Basis.from_euler(pc["rot"]), t.origin + rot * (pc["pos"] as Vector3))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pc["size"]
		mi.mesh = bm
		mi.material_override = _debris_mat(pc["col"])
		mi.transform = xf
		add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = pc["size"]
		cs.shape = bs
		cs.transform = xf
		body.add_child(cs)
		var entry := {"mi": mi, "cs": cs, "xf": xf, "size": pc["size"], "col": pc["col"], "type": pc["type"], "mass": pc["mass"], "alive": true}
		rec["pieces"].append(entry)
		if pc["type"] == "wall":
			rec["walls"] += 1
	_hit_structure(rec, dir * spd)


func _hit_structure(rec: Dictionary, v: Vector3) -> void:
	if not is_instance_valid(rec["body"]):
		return
	var spd := v.length()
	var dir := Vector3(v.x, 0, v.z)
	dir = dir.normalized() if dir.length() > 0.1 else -car.global_basis.z
	var impact := car.global_position + dir * 2.2 + Vector3(0, 0.6, 0)
	var radius := 1.3 + spd * 0.075
	var broke := 0
	var wood: bool = rec["kind"] != "house"
	for e in rec["pieces"]:
		if not e["alive"] or e["type"] == "roof" or e["type"] == "porch_roof":
			continue
		var p: Vector3 = (e["xf"] as Transform3D).origin
		var dd := Vector3(p.x - impact.x, (p.y - impact.y) * 0.6, p.z - impact.z).length()
		if dd > radius:
			continue
		var f := 1.0 - dd / radius
		var rb := _free_piece(rec, e)
		rb.apply_central_impulse((dir * spd * (0.35 + 0.5 * f) + Vector3(rng.randf_range(-1, 1), 1.2 * f, rng.randf_range(-1, 1))) * rb.mass)
		rb.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * rb.mass * 0.8)
		broke += 1
	if broke == 0:
		return
	audio.play("crack" if wood else "crash", -2.0)
	_burst(impact)
	_burst(impact + dir * 1.5 + Vector3(0, 1.0, 0))
	_splinters(impact, Color(0.62, 0.48, 0.32) if wood else Color(0.8, 0.72, 0.58))
	_check_collapse(rec)


func _free_piece(rec: Dictionary, e: Dictionary) -> RigidBody3D:
	e["alive"] = false
	(e["mi"] as Node).queue_free()
	(e["cs"] as Node).queue_free()
	if e["type"] == "wall":
		rec["gone"] += 1
	if e["type"] == "post":
		rec["porch_down"] = true
	var xf: Transform3D = e["xf"]
	var size: Vector3 = e["size"]
	# الألواح الطويلة تنكسر لقطعتين أو ثلاث
	if e["type"] == "wall" and size.y > 1.6:
		var n := 3 if size.y > 2.6 else 2
		var seg := size.y / n
		var first: RigidBody3D = null
		for k in n:
			var off := Vector3(0, -size.y / 2.0 + seg * (k + 0.5), 0)
			var sz := Vector3(size.x, seg * rng.randf_range(0.8, 0.97), size.z)
			var b := xf.basis * Basis.from_euler(Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.12, 0.12)))
			var rb := _chunk(sz, e["col"], xf.origin + xf.basis * off, e["mass"] / n, b, 150.0)
			if first == null:
				first = rb
			else:
				rb.apply_central_impulse(Vector3(rng.randf_range(-1, 1), 0.5, rng.randf_range(-1, 1)) * rb.mass * 1.5)
		return first
	return _chunk(size, e["col"], xf.origin, e["mass"], xf.basis, 150.0)


func _check_collapse(rec: Dictionary) -> void:
	var walls: int = rec["walls"]
	var ratio := float(rec["gone"]) / maxf(walls, 1.0)
	if rec["porch_down"]:
		for e in rec["pieces"]:
			if e["alive"] and e["type"] == "porch_roof":
				_free_piece(rec, e)
	if not rec["roof_down"] and ratio > 0.22:
		rec["roof_down"] = true
		get_tree().create_timer(0.35).timeout.connect(func(): _collapse_roof(rec))


func _collapse_roof(rec: Dictionary) -> void:
	if not is_instance_valid(rec["body"]):
		return
	var center := Vector3.ZERO
	var n := 0
	for e in rec["pieces"]:
		if e["alive"] and e["type"] == "roof":
			var rb := _free_piece(rec, e)
			rb.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * rb.mass * 0.6)
			center += rb.global_position
			n += 1
	# حيطان فوك (الصف العلوي) توكع ويه السقف
	for e in rec["pieces"]:
		if e["alive"] and e["type"] == "wall" and rng.randf() < 0.35:
			var rb2 := _free_piece(rec, e)
			rb2.apply_central_impulse(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * rb2.mass * 1.5)
	if n > 0:
		center /= n
		audio.play("crash", 2.0)
		get_tree().create_timer(0.9).timeout.connect(func():
			_burst(center + Vector3(0, -2.0, 0))
			_burst(center + Vector3(1.5, -2.5, 1.0))
			_burst(center + Vector3(-1.5, -2.5, -1.0)))


# ---------------------------------------------------------------- جزيئات: ورق، شظايا، شرار
func _build_fx_pools() -> void:
	for kind2 in ["leaves", "splinters", "sparks"]:
		var arr: Array = []
		for i in 3:
			var pm := ParticleProcessMaterial.new()
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 180.0
			var q := QuadMesh.new()
			var amount := 60
			var life := 3.0
			match kind2:
				"leaves":
					pm.emission_sphere_radius = 2.0
					pm.initial_velocity_min = 1.0
					pm.initial_velocity_max = 4.0
					pm.gravity = Vector3(0.3, -1.2, 0.2)
					pm.damping_min = 0.8
					pm.damping_max = 1.6
					pm.angular_velocity_min = -300
					pm.angular_velocity_max = 300
					pm.turbulence_enabled = true
					pm.turbulence_noise_strength = 2.0
					q.size = Vector2(0.22, 0.15)
					q.material = _particle_mat(Color(1, 1, 1, 1), null, BaseMaterial3D.BILLBOARD_PARTICLES)
					amount = 90
					life = 4.0
				"splinters":
					pm.emission_sphere_radius = 0.6
					pm.initial_velocity_min = 3.0
					pm.initial_velocity_max = 8.0
					pm.gravity = Vector3(0, -9.8, 0)
					pm.angular_velocity_min = -600
					pm.angular_velocity_max = 600
					pm.scale_min = 0.5
					pm.scale_max = 1.4
					q.size = Vector2(0.06, 0.3)
					q.material = _particle_mat(Color(1, 1, 1, 1), null, BaseMaterial3D.BILLBOARD_PARTICLES)
					amount = 50
					life = 1.8
				"sparks":
					pm.emission_sphere_radius = 0.2
					pm.initial_velocity_min = 3.0
					pm.initial_velocity_max = 7.0
					pm.gravity = Vector3(0, -9.8, 0)
					q.size = Vector2(0.06, 0.06)
					var sm := _particle_mat(Color(1, 0.8, 0.3, 1), null, BaseMaterial3D.BILLBOARD_PARTICLES, true)
					sm.emission_enabled = true
					sm.emission = Color(1, 0.7, 0.2)
					sm.emission_energy_multiplier = 6.0
					q.material = sm
					amount = 40
					life = 1.0
			var p := _make_particles(amount, life, q, pm)
			p.one_shot = true
			p.explosiveness = 0.9
			p.emitting = false
			p.amount_ratio = 1.0
			arr.append(p)
		fx_pools[kind2] = arr


func _emit(kind2: String, pos: Vector3, col: Color) -> void:
	if not fx_pools.has(kind2):
		return
	var arr: Array = fx_pools[kind2]
	var i: int = fx_idx.get(kind2, 0)
	fx_idx[kind2] = i + 1
	var p: GPUParticles3D = arr[i % arr.size()]
	(p.process_material as ParticleProcessMaterial).color = col
	p.global_position = pos
	p.restart()
	p.emitting = true


func _leaves(pos: Vector3, info: Dictionary, _amt: float) -> void:
	var col := Color(0.35, 0.5, 0.2)
	if not info["refs"].is_empty() and info["refs"][0] != null:
		var cols := _foliage_colors()
		col = cols[rng.randi() % cols.size()]
	if info["kind"] == "pine_snow" or base_snow > 0.3:
		col = Color(0.95, 0.97, 1.0)
	_emit("leaves", pos, col)


func _splinters(pos: Vector3, col: Color) -> void:
	_emit("splinters", pos, col)


func _sparks(pos: Vector3) -> void:
	_emit("sparks", pos, Color(1, 0.8, 0.3))



## صناديق: كل صندوق يطير لحاله
func _crates(info: Dictionary, dir: Vector3, spd: float) -> void:
	var t: Transform3D = info["xf"]
	var rot := t.basis.orthonormalized()
	var k := 0
	for cr in PropLib.crate_layout():
		var col := Color(0.62, 0.45, 0.26).darkened(0.06 * (k % 3))
		if k == 6:
			col = Color(0.15, 0.35, 0.55)
		var rb := _chunk(cr[1], col, t.origin + rot * ((cr[0] as Vector3) + Vector3(0, 0.27, 0)), 25.0, rot, 120.0)
		rb.apply_central_impulse((dir * spd * rng.randf_range(0.3, 0.7) + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(1.0, 3.0), rng.randf_range(-1.5, 1.5))) * rb.mass)
		rb.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * rb.mass)
		k += 1
	_splinters(t.origin + Vector3(0, 0.8, 0), Color(0.62, 0.45, 0.26))


# ---------------------------------------------------------------- مسار الرالي
func _track_r(a: float) -> float:
	return track_base + 28.0 * sin(2.0 * a + track_phase) + 14.0 * sin(3.0 * a + track_phase * 1.7)


func track_dist(x: float, z: float) -> float:
	if not has_track:
		return 1e9
	var a := atan2(z, x)
	return absf(Vector2(x, z).length() - _track_r(a))


func _build_track_props() -> void:
	if not has_track:
		return
	var markers: Array = []
	var ramps: Array = []
	var n := 150
	for i in n:
		var a := TAU * i / n
		var r := _track_r(a)
		var c := Vector2(cos(a), sin(a)) * r
		var a2 := TAU * (i + 1) / n
		var c2 := Vector2(cos(a2), sin(a2)) * _track_r(a2)
		var tang := (c2 - c).normalized()
		var nrm := Vector2(-tang.y, tang.x)
		if i % 2 == 0:
			for sgn in [-1.0, 1.0]:
				var p: Vector2 = c + nrm * (TRACK_W * 0.5 + 0.8) * sgn
				if is_underwater(p.x, p.y, 0.3):
					continue
				markers.append(Transform3D(Basis(), Vector3(p.x, h_at(p.x, p.y) - 0.1, p.y)))
		if i % 37 == 18:
			var yaw := atan2(-tang.x, -tang.y)
			if not is_underwater(c.x, c.y, 0.5) and normal_at(c.x, c.y).y > 0.9:
				ramps.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, h_at(c.x, c.y) - 0.15, c.y)))
	var mr := _add_multimesh(PropLib.build("marker", {}), _prop_material(false, "marker"), markers, 230.0)
	_add_collisions("marker", markers, mr)
	var rr := _add_multimesh(PropLib.build("ramp", {}), _prop_material(false, "ramp"), ramps, 0.0)
	_add_collisions("ramp", ramps, rr)



var _dust_dist := 0.0


## السيارة تتوسخ بغبار المكان كلما تسوق أكثر، والمطر يغسلها
func _update_car_dust(delta: float) -> void:
	var pm = car.model.get("paint_mat")
	if pm == null:
		return
	var spd := Vector2(car.linear_velocity.x, car.linear_velocity.z).length()
	var on_dust: float = biome["dusty"]
	if city_density > 0.0 and on_road(car.global_position.x, car.global_position.z):
		on_dust = 0.05
	_dust_dist += spd * delta * on_dust
	_dust_dist = maxf(_dust_dist - delta * 25.0 * float(wcur.get("rain", 0.0)), 0.0)
	if car.water_depth > 0.0:
		_dust_dist = maxf(_dust_dist - delta * 120.0, 0.0)
	var dc: Color = biome["dust"]
	if base_snow > 0.3:
		dc = dc.lerp(Color(0.92, 0.94, 0.97), 0.6)
	(pm as ShaderMaterial).set_shader_parameter("dust_color", dc)
	(pm as ShaderMaterial).set_shader_parameter("dust", clampf(0.1 + _dust_dist / 1800.0, 0.1, 0.8))
