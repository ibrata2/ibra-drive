extends Node
## IBRA DRIVE — الحالة العامة للعبة: الحفظ، السيارات، التطويرات، الرحلة الحالية

signal scene_requested(scene_name: String, arg: Variant)
signal data_changed

const SAVE_PATH := "user://ibra_drive_save.json"
const MAX_LEVEL := 5

const RES_ORDER := ["coins", "scrap", "parts", "crystals"]
const RES_NAMES := {"coins": "فلوس", "scrap": "خردة", "parts": "قطع غيار", "crystals": "أحجار نادرة"}
const RES_COLORS := {
	"coins": Color(1.0, 0.82, 0.25),
	"scrap": Color(0.75, 0.77, 0.8),
	"parts": Color(0.35, 0.72, 1.0),
	"crystals": Color(0.82, 0.45, 1.0),
}

# speed = السرعة القصوى (متر/ثانية)، accel = قوة التسارع، grip = التماسك، offroad = الطرق الوعرة
const CARS := [
	{"id": "pickup", "name": "بيك أب الصحراء", "desc": "سيارة البداية. قوية ومتوازنة وتمشي على الرمل.",
		"price": {}, "body": "pickup", "drive": "awd", "paint": Color(0.93, 0.93, 0.9),
		"speed": 33.0, "accel": 1.0, "grip": 0.82, "offroad": 0.75, "fuel": 100.0, "mass": 1400.0},
	{"id": "buggy", "name": "باگي الرمال", "desc": "خفيفة وسريعة بالتسارع، ملكة الكثبان.",
		"price": {"coins": 700, "scrap": 60}, "body": "buggy", "drive": "rwd", "paint": Color(1.0, 0.55, 0.1),
		"speed": 36.0, "accel": 1.3, "grip": 0.74, "offroad": 0.95, "fuel": 70.0, "mass": 750.0},
	{"id": "sedan", "name": "سيدان فخمة", "desc": "سيدان انسيابية فخمة بخطوط ناعمة — مثل سيارة الفيديو. مجانية ومن البداية.",
		"price": {}, "body": "sedan", "drive": "rwd", "paint": Color(0.93, 0.92, 0.88),
		"speed": 42.0, "accel": 1.15, "grip": 0.9, "offroad": 0.7, "fuel": 95.0, "mass": 1350.0},
	{"id": "jeep", "name": "جيب الجبال", "desc": "دفع رباعي حقيقي، تصعد الجبال وتمشي بالثلج.",
		"price": {"coins": 1500, "parts": 30}, "body": "jeep", "drive": "awd", "paint": Color(0.3, 0.42, 0.25),
		"speed": 32.0, "accel": 1.05, "grip": 0.88, "offroad": 1.05, "fuel": 120.0, "mass": 1600.0},
	{"id": "rally", "name": "سيارة الرالي", "desc": "تفحيط وسرعة بكل الأرضيات.",
		"price": {"coins": 3000, "parts": 60, "crystals": 6}, "body": "rally", "drive": "awd", "paint": Color(0.85, 0.1, 0.12),
		"speed": 47.0, "accel": 1.4, "grip": 0.9, "offroad": 0.85, "fuel": 100.0, "mass": 1100.0},
	{"id": "truck", "name": "شاحنة الاستكشاف", "desc": "خزان ضخم وتجمع غنائم أكثر (+25%).",
		"price": {"coins": 4000, "parts": 90, "crystals": 12}, "body": "truck", "drive": "awd", "paint": Color(0.95, 0.75, 0.15),
		"speed": 29.0, "accel": 0.9, "grip": 0.9, "offroad": 1.0, "fuel": 220.0, "mass": 2800.0, "loot_bonus": 0.25},
	{"id": "monster", "name": "مونستر تراك", "desc": "تايرات عملاقة تعبر أي شي.",
		"price": {"coins": 7000, "parts": 120, "crystals": 25}, "body": "monster", "drive": "awd", "paint": Color(0.1, 0.75, 0.35),
		"speed": 35.0, "accel": 1.25, "grip": 0.85, "offroad": 1.2, "fuel": 150.0, "mass": 2200.0},
	# رؤوس التريلات — تنشرى وتنطور من كراج الشاحنات (ما تطلع بالكراج القديم)
	{"id": "semi_rafidain", "name": "قاطرة الرافدين", "desc": "رأس تريلة بكابينة مسطحة. شاحنة البداية بشركة النقل.",
		"price": {}, "body": "semi", "drive": "rwd", "paint": Color(0.78, 0.1, 0.08), "hidden": true, "truck": true,
		"speed": 26.0, "accel": 1.25, "grip": 0.95, "offroad": 0.7, "fuel": 420.0, "mass": 7500.0},
	{"id": "semi_dijla", "name": "قاطرة دجلة", "desc": "بوز طويل ومحرك أقوى، تسحب مقطورتين براحة.",
		"price": {"coins": 9000}, "body": "semi_long", "drive": "rwd", "paint": Color(0.12, 0.32, 0.62), "hidden": true, "truck": true,
		"speed": 28.0, "accel": 1.6, "grip": 1.0, "offroad": 0.75, "fuel": 540.0, "mass": 8000.0},
	{"id": "semi_babil", "name": "قاطرة بابل V8", "desc": "ملكة الطريق. كروم، محرك V8 وخزان ضخم.",
		"price": {"coins": 22000, "parts": 60}, "body": "semi_v8", "drive": "awd", "paint": Color(0.06, 0.06, 0.07), "hidden": true, "truck": true,
		"speed": 31.0, "accel": 1.95, "grip": 1.05, "offroad": 0.85, "fuel": 680.0, "mass": 8600.0},
]

const UPGRADES := [
	{"id": "engine", "name": "المحرك", "desc": "سرعة قصوى وتسارع أعلى", "mult": 1.3},
	{"id": "tires", "name": "التايرات", "desc": "تماسك أقوى على الرمل والثلج والطين", "mult": 1.0},
	{"id": "suspension", "name": "العوارض", "desc": "ثبات أحسن بالطرق الوعرة والقفزات", "mult": 0.9},
	{"id": "tank", "name": "خزان الوقود", "desc": "تروح أبعد قبل لا يخلص البانزين", "mult": 0.8},
	{"id": "nitro", "name": "النيترو", "desc": "دفعة سرعة بزر Shift", "mult": 1.5},
	{"id": "magnet", "name": "المغناطيس", "desc": "يسحب الأغراض القريبة للسيارة", "mult": 1.1},
]

const PAINTS := [
	Color(0.93, 0.93, 0.9), Color(0.08, 0.08, 0.09), Color(0.85, 0.1, 0.12), Color(0.12, 0.3, 0.7),
	Color(1.0, 0.55, 0.1), Color(0.95, 0.75, 0.15), Color(0.1, 0.75, 0.35), Color(0.3, 0.42, 0.25),
	Color(0.55, 0.2, 0.75), Color(0.35, 0.8, 0.9), Color(0.78, 0.66, 0.48), Color(0.6, 0.62, 0.65),
]

var data: Dictionary = {}
var run: Dictionary = {}
var current_place: int = 0
var last_result: Dictionary = {}
var test_car := ""
var drive_spec: Dictionary = {}
var scene_arg: Variant = null
var arabic_font: SystemFont


func _ready() -> void:
	arabic_font = SystemFont.new()
	arabic_font.font_names = PackedStringArray(["Segoe UI", "Tahoma", "Arial", "Noto Sans Arabic", "Noto Sans", "DejaVu Sans"])
	_setup_input()
	load_game()


# ---------------------------------------------------------------- التحكم
func _setup_input() -> void:
	var keys := {
		"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE], "nitro": [KEY_SHIFT], "camera": [KEY_C],
		"interact": [KEY_E], "reset_car": [KEY_R], "tow": [KEY_T],
		"pause": [KEY_ESCAPE], "headlights": [KEY_L],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.15)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	_joy_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_btn("handbrake", JOY_BUTTON_A)
	_joy_btn("nitro", JOY_BUTTON_X)
	_joy_btn("camera", JOY_BUTTON_Y)
	_joy_btn("interact", JOY_BUTTON_B)
	_joy_btn("reset_car", JOY_BUTTON_BACK)
	_joy_btn("pause", JOY_BUTTON_START)


func _joy_axis(action: String, axis: int, val: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	InputMap.action_add_event(action, ev)


func _joy_btn(action: String, b: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- الحفظ
func default_data() -> Dictionary:
	return {
		"version": 1, "coins": 250, "scrap": 0, "parts": 0, "crystals": 0, "xp": 0,
		"owned": ["pickup", "sedan"], "car": "sedan", "upgrades": {}, "paint": {},
		"treasures": [], "visits": {}, "trips": 0, "items_total": 0,
		"deco": {}, "truck": {}, "story": {}, "school": {}, "license": {}, "player_name": "", "asked_skill": false,
	}


func load_game() -> void:
	data = default_data()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					data[k] = parsed[k]
	for k in RES_ORDER:
		data[k] = int(data[k])
	if not data["owned"].has("sedan"):
		data["owned"].append("sedan")
	data["xp"] = int(data["xp"])


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
	data_changed.emit()


func reset_save() -> void:
	data = default_data()
	save_game()


# ---------------------------------------------------------------- السيارات
func get_car(id: String) -> Dictionary:
	for c in CARS:
		if c["id"] == id:
			return c
	return CARS[0]


func owns(id: String) -> bool:
	return data["owned"].has(id)


func car_paint(id: String) -> Color:
	var p = data["paint"].get(id, null)
	if p is String:
		return Color.from_string(p, get_car(id)["paint"])
	return get_car(id)["paint"]


func car_deco(id: String) -> Array:
	var d = data.get("deco", {}).get(id, [])
	return d if d is Array else []


func set_deco(id: String, list: Array) -> void:
	if not data.has("deco") or not (data["deco"] is Dictionary):
		data["deco"] = {}
	data["deco"][id] = list
	save_game()


func set_paint(id: String, c: Color) -> void:
	data["paint"][id] = c.to_html(false)
	save_game()


func buy_car(id: String) -> bool:
	var c := get_car(id)
	if owns(id) or not can_afford(c["price"]):
		return false
	pay(c["price"])
	data["owned"].append(id)
	data["car"] = id
	save_game()
	return true


func select_car(id: String) -> void:
	if owns(id):
		data["car"] = id
		save_game()


func upgrade_level(car_id: String, up_id: String) -> int:
	var u = data["upgrades"].get(car_id, {})
	return int(u.get(up_id, 0))


func _up_mult(up_id: String) -> float:
	for u in UPGRADES:
		if u["id"] == up_id:
			return u["mult"]
	return 1.0


func upgrade_cost(car_id: String, up_id: String, next_level: int) -> Dictionary:
	var m := _up_mult(up_id)
	var car_tier := 1.0 + float(CARS.find(get_car(car_id))) * 0.12
	m *= car_tier
	var c := {}
	c["coins"] = int(round((60.0 + 70.0 * next_level * next_level) * m / 10.0)) * 10
	c["scrap"] = int(round(12.0 * next_level * m))
	if next_level >= 2:
		c["parts"] = int(round(5.0 * (next_level - 1) * m))
	if next_level >= 4:
		c["crystals"] = (next_level - 3) * 3
	return c


func buy_upgrade(car_id: String, up_id: String) -> bool:
	var lvl := upgrade_level(car_id, up_id)
	if lvl >= MAX_LEVEL:
		return false
	var cost := upgrade_cost(car_id, up_id, lvl + 1)
	if not can_afford(cost):
		return false
	pay(cost)
	if not data["upgrades"].has(car_id):
		data["upgrades"][car_id] = {}
	data["upgrades"][car_id][up_id] = lvl + 1
	save_game()
	return true


func car_stats(car_id: String) -> Dictionary:
	var c := get_car(car_id)
	var e := upgrade_level(car_id, "engine")
	var t := upgrade_level(car_id, "tires")
	var s := upgrade_level(car_id, "suspension")
	var k := upgrade_level(car_id, "tank")
	var n := upgrade_level(car_id, "nitro")
	var m := upgrade_level(car_id, "magnet")
	return {
		"top_speed": c["speed"] * (1.0 + 0.07 * e),
		"accel": c["accel"] * (1.0 + 0.09 * e),
		"grip": c["grip"] + 0.035 * t,
		"offroad": c["offroad"] + 0.06 * t + 0.04 * s,
		"susp": 1.0 + 0.12 * s,
		"fuel": c["fuel"] * (1.0 + 0.25 * k),
		"nitro": 0.0 if n == 0 else 2.0 + n * 1.2,
		"magnet": 0.0 if m == 0 else 5.0 + m * 3.0,
		"mass": c["mass"], "body": c["body"], "drive": c["drive"],
		"loot_bonus": c.get("loot_bonus", 0.0),
	}


# ---------------------------------------------------------------- الموارد
func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(data.get(k, 0)) < int(cost[k]):
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		data[k] = int(data[k]) - int(cost[k])


func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "مجاني"
	var parts: PackedStringArray = []
	for k in RES_ORDER:
		if cost.has(k):
			parts.append("%d %s" % [int(cost[k]), RES_NAMES[k]])
	return " • ".join(parts)


## شنو ينقصك حتى تشتري
func missing_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in RES_ORDER:
		if cost.has(k) and int(data.get(k, 0)) < int(cost[k]):
			parts.append("%d %s" % [int(cost[k]) - int(data.get(k, 0)), RES_NAMES[k]])
	return " • ".join(parts)


func active_car() -> String:
	return test_car if test_car != "" else data["car"]


func level() -> int:
	return 1 + int(floor(sqrt(float(data["xp"]) / 60.0)))


func xp_for_level(l: int) -> int:
	return int(60 * (l - 1) * (l - 1))


func has_treasure(place_idx: int) -> bool:
	for t in data["treasures"]:
		if int(t) == place_idx:
			return true
	return false


func visits(place_idx: int) -> int:
	return int(data["visits"].get(str(place_idx), 0))


# ---------------------------------------------------------------- الرحلة
func start_trip(place_idx: int) -> void:
	current_place = place_idx
	run = {"coins": 0, "scrap": 0, "parts": 0, "crystals": 0, "xp": 0, "items": 0, "treasure": false}
	scene_requested.emit("world", place_idx)


func run_add(k: String, n: int) -> void:
	run[k] = int(run.get(k, 0)) + n


func mark_treasure(place_idx: int) -> void:
	if not has_treasure(place_idx):
		data["treasures"].append(place_idx)
	run["treasure"] = true


## يحفظ غنائم الرحلة. fraction = نسبة اللي توصل (1.0 لو رجعت بنفسك للكراج)
func end_trip(fraction: float, how: String) -> void:
	var got := {}
	for k in RES_ORDER:
		var n := int(floor(float(run.get(k, 0)) * fraction))
		data[k] = int(data[k]) + n
		got[k] = n
	var lvl_before := level()
	data["xp"] = int(data["xp"]) + int(run.get("xp", 0))
	var key := str(current_place)
	data["visits"][key] = int(data["visits"].get(key, 0)) + 1
	data["trips"] = int(data["trips"]) + 1
	data["items_total"] = int(data["items_total"]) + int(run.get("items", 0))
	last_result = {"got": got, "how": how, "items": run.get("items", 0), "xp": run.get("xp", 0),
		"treasure": run.get("treasure", false), "place": current_place,
		"level_up": level() > lvl_before, "new_level": level()}
	save_game()
	scene_requested.emit("garage", null)


func goto(scene_name: String, arg: Variant = null) -> void:
	scene_requested.emit(scene_name, arg)
