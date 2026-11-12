extends Node
## IBRA DRIVE — شركة النقل: المحافظات، الطرق، الحمولات، العقود، السمعة، الشاحنة والمقطورات والتزيين

# ---------------------------------------------------------------- المحافظات
# lon/lat تقريبية للرسم على خريطة العراق • region يحدد شكل الطريق والطبيعة حواليه • river = المدينة على نهر (جسر قبلها)
const CITIES := {
	"basra": {"name": "البصرة", "gov": "البصرة", "lon": 47.78, "lat": 30.51, "region": "south", "rep": 0, "river": "شط العرب"},
	"nasiriyah": {"name": "الناصرية", "gov": "ذي قار", "lon": 46.26, "lat": 31.04, "region": "south", "rep": 0, "river": "الفرات"},
	"amarah": {"name": "العمارة", "gov": "ميسان", "lon": 47.15, "lat": 31.84, "region": "marsh", "rep": 0, "river": "دجلة"},
	"samawah": {"name": "السماوة", "gov": "المثنى", "lon": 45.28, "lat": 31.31, "region": "desert", "rep": 4, "river": "الفرات"},
	"kut": {"name": "الكوت", "gov": "واسط", "lon": 45.82, "lat": 32.51, "region": "middle", "rep": 4, "river": "دجلة"},
	"diwaniyah": {"name": "الديوانية", "gov": "القادسية", "lon": 44.92, "lat": 31.99, "region": "middle", "rep": 8, "river": ""},
	"najaf": {"name": "النجف", "gov": "النجف", "lon": 44.33, "lat": 32.0, "region": "desert", "rep": 8, "river": ""},
	"hillah": {"name": "الحلة", "gov": "بابل", "lon": 44.43, "lat": 32.48, "region": "middle", "rep": 12, "river": "شط الحلة"},
	"karbala": {"name": "كربلاء", "gov": "كربلاء", "lon": 44.02, "lat": 32.62, "region": "middle", "rep": 12, "river": ""},
	"baghdad": {"name": "بغداد", "gov": "بغداد", "lon": 44.36, "lat": 33.31, "region": "middle", "rep": 16, "river": "دجلة"},
	"baqubah": {"name": "بعقوبة", "gov": "ديالى", "lon": 44.65, "lat": 33.75, "region": "middle", "rep": 22, "river": "ديالى"},
	"ramadi": {"name": "الرمادي", "gov": "الأنبار", "lon": 43.3, "lat": 33.42, "region": "desert", "rep": 22, "river": "الفرات"},
	"tikrit": {"name": "تكريت", "gov": "صلاح الدين", "lon": 43.68, "lat": 34.6, "region": "north", "rep": 30, "river": "دجلة"},
	"kirkuk": {"name": "كركوك", "gov": "كركوك", "lon": 44.39, "lat": 35.47, "region": "north", "rep": 36, "river": ""},
	"mosul": {"name": "الموصل", "gov": "نينوى", "lon": 43.13, "lat": 36.34, "region": "north", "rep": 44, "river": "دجلة"},
	"erbil": {"name": "أربيل", "gov": "أربيل", "lon": 44.01, "lat": 36.19, "region": "kurd", "rep": 44, "river": ""},
	"sulaymaniyah": {"name": "السليمانية", "gov": "السليمانية", "lon": 45.43, "lat": 35.56, "region": "kurd", "rep": 52, "river": ""},
	"duhok": {"name": "دهوك", "gov": "دهوك", "lon": 42.99, "lat": 36.87, "region": "kurd", "rep": 60, "river": ""},
}

# الطرق السريعة بين المدن (كم تقريبية)
const ROADS := [
	["basra", "nasiriyah", 200], ["basra", "amarah", 180], ["amarah", "kut", 190], ["nasiriyah", "samawah", 120],
	["nasiriyah", "kut", 190], ["samawah", "diwaniyah", 70], ["diwaniyah", "najaf", 70], ["diwaniyah", "hillah", 85],
	["najaf", "karbala", 80], ["karbala", "hillah", 45], ["hillah", "baghdad", 100], ["karbala", "baghdad", 105],
	["kut", "baghdad", 180], ["baghdad", "baqubah", 60], ["baghdad", "ramadi", 110], ["baghdad", "tikrit", 175],
	["tikrit", "kirkuk", 115], ["tikrit", "mosul", 225], ["kirkuk", "erbil", 95], ["kirkuk", "sulaymaniyah", 115],
	["erbil", "mosul", 85], ["erbil", "sulaymaniyah", 170], ["mosul", "duhok", 75], ["baqubah", "kirkuk", 200],
	["najaf", "samawah", 140], ["ramadi", "karbala", 150],
]

const REGION_NAMES := {"south": "سهول الجنوب والنخيل", "marsh": "الأهوار", "middle": "بساتين الوسط", "desert": "البادية",
	"north": "سهوب الشمال", "kurd": "جبال كردستان"}

# ---------------------------------------------------------------- الحمولات
# trailer: box صندوق • flat مسطحة • tank تانكر • pipes طويلة • reefer مبرّدة
# fragile = قد إيش تتضرر من الضربات والمطبات • liquid = تتمايل • long = مقطورة طويلة • tons = الوزن
const CARGO := {
	"dates": {"name": "تمر زهدي وبرحي", "trailer": "box", "tons": 16.0, "pay": 1.0, "fragile": 0.6, "color": Color(0.55, 0.32, 0.12)},
	"rice": {"name": "رز وطحين للأسواق", "trailer": "box", "tons": 22.0, "pay": 0.95, "fragile": 0.4, "color": Color(0.95, 0.92, 0.85)},
	"cement": {"name": "سمنت وطابوق", "trailer": "flat", "tons": 26.0, "pay": 1.0, "fragile": 0.3, "color": Color(0.62, 0.62, 0.6)},
	"steel": {"name": "حديد تسليح", "trailer": "flat", "tons": 28.0, "pay": 1.15, "fragile": 0.2, "color": Color(0.35, 0.3, 0.28)},
	"glass": {"name": "زجاج شبابيك", "trailer": "box", "tons": 12.0, "pay": 1.6, "fragile": 2.6, "color": Color(0.6, 0.85, 0.95)},
	"electronics": {"name": "أدوات كهربائية", "trailer": "box", "tons": 10.0, "pay": 1.5, "fragile": 2.0, "color": Color(0.25, 0.3, 0.4)},
	"fuel": {"name": "بانزين (تانكر)", "trailer": "tank", "tons": 24.0, "pay": 1.45, "fragile": 0.5, "liquid": true, "color": Color(0.9, 0.9, 0.92)},
	"water": {"name": "ماي صالح للشرب", "trailer": "tank", "tons": 22.0, "pay": 1.1, "fragile": 0.3, "liquid": true, "color": Color(0.3, 0.55, 0.85)},
	"pipes": {"name": "أنابيب نفط طويلة", "trailer": "pipes", "tons": 20.0, "pay": 1.4, "fragile": 0.5, "long": true, "color": Color(0.3, 0.3, 0.32)},
	"poles": {"name": "أعمدة كهرباء", "trailer": "pipes", "tons": 18.0, "pay": 1.35, "fragile": 0.6, "long": true, "color": Color(0.7, 0.7, 0.68)},
	"medicine": {"name": "أدوية للمستشفى", "trailer": "reefer", "tons": 8.0, "pay": 1.9, "fragile": 1.5, "urgent": true, "color": Color(0.95, 0.95, 0.97)},
	"vegetables": {"name": "خضرة طازجة", "trailer": "reefer", "tons": 14.0, "pay": 1.25, "fragile": 1.0, "urgent": true, "color": Color(0.3, 0.7, 0.3)},
	"grain": {"name": "حنطة وشعير", "trailer": "box", "tons": 24.0, "pay": 1.0, "fragile": 0.2, "color": Color(0.85, 0.7, 0.35)},
	# حمولات صغيرة بحوض السيارة (القصص)
	"eggs": {"name": "طبكات بيض", "trailer": "", "tons": 0.6, "pay": 1.0, "fragile": 3.2, "color": Color(0.95, 0.9, 0.8), "board": false},
	"cake": {"name": "كيكة العرس", "trailer": "", "tons": 0.05, "pay": 1.0, "fragile": 3.8, "color": Color(1, 0.95, 0.97), "board": false},
	"family": {"name": "العائلة (ركاب)", "trailer": "", "tons": 0.3, "pay": 1.0, "fragile": 1.2, "color": Color(0.9, 0.8, 0.6), "board": false},
	"supplies": {"name": "مؤن وبطانيات", "trailer": "", "tons": 0.9, "pay": 1.0, "fragile": 0.5, "color": Color(0.5, 0.45, 0.35), "board": false},
	"crates": {"name": "صناديق فواكه", "trailer": "", "tons": 0.8, "pay": 1.0, "fragile": 1.4, "color": Color(0.85, 0.5, 0.2), "board": false},
	"tank_small": {"name": "ماي للمخيم (عربانة)", "trailer": "water_small", "tons": 2.5, "pay": 1.0, "fragile": 0.3, "liquid": true, "color": Color(0.3, 0.55, 0.85), "board": false},
}

const TRAILER_NAMES := {"box": "صندوق", "flat": "مسطحة", "tank": "تانكر", "pipes": "طويلة", "reefer": "مبرّدة"}

# ---------------------------------------------------------------- الشاحنة
const CABS := ["semi_rafidain", "semi_dijla", "semi_babil"]
const TRUCK_UPGRADES := [
	{"id": "engine", "name": "المحرك", "desc": "سحب أقوى بالحمولات الثكيلة والصعود"},
	{"id": "tires", "name": "التايرات", "desc": "تماسك أحسن بالمطر والرمل"},
	{"id": "suspension", "name": "العوارض", "desc": "المطبات تأثر أقل على الحمولة"},
	{"id": "tank", "name": "خزان الوقود", "desc": "مسافة أطول قبل محطة الوقود"},
	{"id": "brakes", "name": "فرامل المقطورة", "desc": "توقف أقصر وأنت محمّل"},
]
const TRAILER_UPGRADES := [
	{"id": "capacity", "name": "سعة المقطورة", "desc": "كل مستوى +10% على أجرة كل عقد", "max": 3, "base": 1500},
	{"id": "straps", "name": "أحزمة وتثبيت", "desc": "الحمولة تتضرر أقل (-12% لكل مستوى)", "max": 3, "base": 1200},
	{"id": "lights", "name": "إنارة المقطورة", "desc": "رؤية أحسن بالليل والعجاج", "max": 1, "base": 900},
]
const DOLLY_PRICE := 6000

const DECOS := [
	{"id": "chrome", "name": "صدام وشبك كروم", "price": 1200},
	{"id": "visor", "name": "مظلة شمس", "price": 600},
	{"id": "lightbar", "name": "شريط أضواء على السقف", "price": 900},
	{"id": "horns", "name": "أبواق كروم", "price": 700},
	{"id": "flags", "name": "أعلام العراق", "price": 400},
	{"id": "sidelights", "name": "أضواء جانبية برتقالية", "price": 800},
	{"id": "mudflaps", "name": "شوادر طين", "price": 350},
	{"id": "stripes", "name": "خطوط ذهبية", "price": 500},
]
const SLOGAN_PRICE := 300

const REP_TIERS := [[0, "سائق جديد"], [10, "سائق"], [30, "سائق محترف"], [60, "خبير طرق"], [100, "أسطورة الطريق"]]

# الطرق تنحوّل لمسافة باللعبة: 1800م + 9م لكل كم حقيقي (البصرة-بغداد ≈ 6.5 كم سياقة)
const M_BASE := 1800.0
const M_PER_KM := 9.0
const M_MAX := 11000.0

var board: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	ensure()


# ---------------------------------------------------------------- الحفظ
func ensure() -> void:
	var d: Dictionary = Game.data
	if not (d.get("truck") is Dictionary):
		d["truck"] = {}
	var t: Dictionary = d["truck"]
	var defaults := {"cab": "semi_rafidain", "dolly": false, "city": "basra", "rep": 0, "deliveries": 0, "km": 0,
		"earned": 0, "trailer_up": {}, "trailer_paint": "", "board_city": "", "chain_bonus": 0}
	for k in defaults:
		if not t.has(k):
			t[k] = defaults[k]
	if not Game.owns("semi_rafidain"):
		d["owned"].append("semi_rafidain")
	for k in ["story", "school", "license", "deco"]:
		if not (d.get(k) is Dictionary):
			d[k] = {}


func truck() -> Dictionary:
	ensure()
	return Game.data["truck"]


func rep() -> int:
	return int(truck()["rep"])


func rep_title(r: int = -1) -> String:
	if r < 0:
		r = rep()
	var t := "سائق جديد"
	for tier in REP_TIERS:
		if r >= int(tier[0]):
			t = tier[1]
	return t


func city_unlocked(id: String) -> bool:
	return rep() >= int(CITIES[id]["rep"])


func city_name(id: String) -> String:
	return CITIES[id]["name"] if CITIES.has(id) else id


func trailer_level(id: String) -> int:
	return int(truck()["trailer_up"].get(id, 0))


func trailer_up_cost(id: String, next: int) -> int:
	for u in TRAILER_UPGRADES:
		if u["id"] == id:
			return int(u["base"]) * next
	return 99999


func buy_trailer_up(id: String) -> bool:
	var mx := 1
	for u in TRAILER_UPGRADES:
		if u["id"] == id:
			mx = int(u["max"])
	var lvl := trailer_level(id)
	if lvl >= mx:
		return false
	var c := trailer_up_cost(id, lvl + 1)
	if int(Game.data["coins"]) < c:
		return false
	Game.data["coins"] = int(Game.data["coins"]) - c
	truck()["trailer_up"][id] = lvl + 1
	Game.save_game()
	return true


func trailer_color() -> Color:
	var s: String = truck().get("trailer_paint", "")
	if s == "":
		return Color(0.92, 0.92, 0.9)
	return Color.from_string(s, Color(0.92, 0.92, 0.9))


# ---------------------------------------------------------------- الطرق
func neighbors(id: String) -> Array:
	var out: Array = []
	for r in ROADS:
		if r[0] == id:
			out.append([r[1], int(r[2])])
		elif r[1] == id:
			out.append([r[0], int(r[2])])
	return out


## أقصر طريق (ديكسترا): يرجع {"cities": [...], "km": [...تراكمي], "total": كم}
func path(a: String, b: String) -> Dictionary:
	var dist := {a: 0}
	var prev := {}
	var open: Array = [a]
	var done := {}
	while not open.is_empty():
		var best := ""
		var bd := 1 << 30
		for c in open:
			if int(dist[c]) < bd:
				bd = int(dist[c])
				best = c
		open.erase(best)
		if best == b:
			break
		done[best] = true
		for nb in neighbors(best):
			var n: String = nb[0]
			if done.has(n):
				continue
			var nd := bd + int(nb[1])
			if not dist.has(n) or nd < int(dist[n]):
				dist[n] = nd
				prev[n] = best
				if not open.has(n):
					open.append(n)
	var cities: Array = [b]
	var cur := b
	while prev.has(cur):
		cur = prev[cur]
		cities.push_front(cur)
	if cities[0] != a:
		return {"cities": [a, b], "km": [0, 100], "total": 100}
	var km: Array = [0]
	for i in range(1, cities.size()):
		var seg := 0
		for nb in neighbors(cities[i - 1]):
			if nb[0] == cities[i]:
				seg = int(nb[1])
		km.append(int(km[i - 1]) + seg)
	return {"cities": cities, "km": km, "total": int(km[km.size() - 1])}


func game_length(total_km: float) -> float:
	return clampf(M_BASE + total_km * M_PER_KM, 1600.0, M_MAX)


# ---------------------------------------------------------------- العقود
func make_contract(from: String, to: String, cargo_id: String, trailers := 1, mods := {}) -> Dictionary:
	var p := path(from, to)
	var cg: Dictionary = CARGO[cargo_id]
	var km := float(p["total"])
	var pay := (350.0 + km * 4.2) * float(cg["pay"])
	if trailers >= 2:
		pay *= 1.85
	var c := {
		"kind": "contract", "goal": "deliver", "from": from, "to": to, "cargo": cargo_id,
		"trailers": trailers, "trailer_kind": cg["trailer"], "km": int(km),
		"hour": float(_rng.randi_range(6, 15)), "weather": "", "deadline": -1.0, "night": false,
		"events": [], "rep_req": 0, "pay": 0, "car": truck()["cab"],
	}
	if cg.get("urgent", false):
		c["deadline"] = snappedf(game_length(km) / 21.0 / 30.0 * 1.35 + 0.5, 0.5)
		pay *= 1.2
	for k in mods:
		c[k] = mods[k]
	if c["night"]:
		c["hour"] = float(_rng.randi_range(20, 23))
		pay *= 1.15
	if c["weather"] in ["rain", "storm", "sandstorm", "fog"]:
		pay *= 1.2
	c["pay"] = int(round(pay / 10.0)) * 10
	c["rep_req"] = clampi(int(maxf(km - 220.0, 0.0) / 45.0) + (6 if trailers >= 2 else 0) + (3 if float(cg["fragile"]) >= 1.5 else 0), 0, 60)
	return c


## لوحة الطلبات من المدينة الحالية
func refresh_board(force := false) -> Array:
	var t := truck()
	var city: String = t["city"]
	if not force and t["board_city"] == city and not board.is_empty():
		return board
	t["board_city"] = city
	board.clear()
	var targets: Array = []
	for id in CITIES:
		if id != city and city_unlocked(id):
			targets.append(id)
	if targets.size() < 2:
		for id in CITIES:
			if id != city and not targets.has(id) and path(city, id)["total"] < 260:
				targets.append(id)
	targets.shuffle()
	targets.sort_custom(func(x, y): return path(city, x)["total"] < path(city, y)["total"])
	var near := targets.slice(0, 9)
	near.shuffle()
	var cargo_ids: Array = []
	for k in CARGO:
		if CARGO[k].get("board", true):
			cargo_ids.append(k)
	var weathers := ["", "", "", "rain", "fog", "sandstorm", "storm"]
	for i in 7:
		var to: String = near[i % near.size()]
		var cid: String = cargo_ids[_rng.randi() % cargo_ids.size()]
		var tr := 1
		if bool(t["dolly"]) and _rng.randf() < 0.4 and not CARGO[cid].get("long", false):
			tr = 2
		var mods := {}
		var r := _rng.randf()
		if r < 0.22:
			mods["night"] = true
		elif r < 0.5:
			var w: String = weathers[_rng.randi() % weathers.size()]
			if w == "sandstorm" and CITIES[to]["region"] not in ["desert", "south", "middle"]:
				w = "rain"
			if w == "storm" and CITIES[to]["region"] in ["desert"]:
				w = "sandstorm"
			mods["weather"] = w
		if _rng.randf() < 0.35:
			mods["events"] = [["blowout", "sheep", "roadblock"][_rng.randi() % 3]]
		board.append(make_contract(city, to, cid, tr, mods))
	board.sort_custom(func(x, y): return int(x["rep_req"]) < int(y["rep_req"]))
	return board


func contract_title(c: Dictionary) -> String:
	return "%s ← %s" % [city_name(c["to"]), city_name(c["from"])]


func contract_tags(c: Dictionary) -> PackedStringArray:
	var tags: PackedStringArray = []
	var cg: Dictionary = CARGO.get(c.get("cargo", ""), {})
	if int(c.get("trailers", 1)) >= 2:
		tags.append("مقطورتين")
	if cg.get("liquid", false):
		tags.append("سائل يتمايل")
	if cg.get("long", false):
		tags.append("حمولة طويلة")
	if float(cg.get("fragile", 0.0)) >= 1.5:
		tags.append("حساسة للكسر")
	if float(c.get("deadline", -1.0)) > 0.0:
		tags.append("مستعجلة: %s ساعة" % str(c["deadline"]))
	if c.get("night", false):
		tags.append("ليلية")
	match str(c.get("weather", "")):
		"rain":
			tags.append("مطر")
		"storm":
			tags.append("عاصفة رعدية")
		"fog":
			tags.append("ضباب")
		"sandstorm":
			tags.append("عجاج")
	for e in c.get("events", []):
		match str(e):
			"blowout":
				tags.append("طريق متعب")
			"sheep":
				tags.append("طريق مواشي")
			"roadblock":
				tags.append("تحويلات بالطريق")
	return tags


# ---------------------------------------------------------------- نهاية الرحلة
## يحسب الأجرة النهائية ويحفظ: result = {delivered, damage(0-1), late_h, fuel_cost, fines, repairs, dock, broken, km}
func settle(c: Dictionary, result: Dictionary) -> Dictionary:
	var t := truck()
	var base := float(c.get("pay", 0))
	var lines: Array = []
	var total := 0.0
	var rep_d := 0
	if result.get("delivered", false):
		var cap := 1.0 + 0.1 * trailer_level("capacity")
		var dmg := clampf(float(result.get("damage", 0.0)), 0.0, 1.0)
		var paid := base * cap
		lines.append(["أجرة التوصيل", int(paid)])
		if cap > 1.0:
			lines.append(["(فيها سعة المقطورة +%d%%)" % int(round((cap - 1.0) * 100.0)), 0])
		var dmg_cut := -paid * dmg
		if dmg > 0.005:
			lines.append(["أضرار الحمولة %d%%" % int(round(dmg * 100.0)), int(dmg_cut)])
		total = paid + dmg_cut
		var dl := float(c.get("deadline", -1.0))
		if dl > 0.0:
			var late := float(result.get("late_h", 0.0))
			if late <= 0.0:
				var early := -late
				var b := paid * clampf(0.1 + early * 0.08, 0.1, 0.4)
				lines.append(["مكافأة الوصول بالوقت", int(b)])
				total += b
				rep_d += 1
			else:
				var pen := -paid * clampf(late * 0.25, 0.1, 0.6)
				lines.append(["تأخير %s ساعة" % str(snappedf(late, 0.1)), int(pen)])
				total += pen
				rep_d -= 1
		if result.get("dock", false):
			lines.append(["ركن المقطورة على الرصيف", int(base * 0.08)])
			total += base * 0.08
		if int(result.get("checkpoint_ok", 0)) > 0:
			var cb := 25 * int(result["checkpoint_ok"])
			lines.append(["وقفت صح بالسيطرات", cb])
			total += cb
		if int(t.get("chain_bonus", 0)) > 0:
			var chb := base * 0.05 * float(t["chain_bonus"])
			lines.append(["عقود متتالية ×%d" % int(t["chain_bonus"]), int(chb)])
			total += chb
		rep_d += 2
		if dmg < 0.05:
			rep_d += 1
		if dmg > 0.5:
			rep_d -= 2
		t["deliveries"] = int(t["deliveries"]) + 1
		t["km"] = int(t["km"]) + int(c.get("km", 0))
	else:
		lines.append(["العقد ما انكمل", 0])
		rep_d -= 1
	for k in [["fuel_cost", "بانزين بالطريق"], ["fines", "غرامات"], ["repairs", "تصليح بالطريق"], ["food", "أكل واستراحة"]]:
		var v := int(result.get(k[0], 0))
		if v > 0:
			lines.append([k[1], -v])
			total -= v
	var final_pay := int(round(total))
	var rep_before := rep()
	t["rep"] = maxi(0, rep_before + rep_d)
	Game.data["coins"] = maxi(0, int(Game.data["coins"]) + final_pay)
	if final_pay > 0:
		t["earned"] = int(t["earned"]) + final_pay
	Game.data["xp"] = int(Game.data["xp"]) + maxi(0, int(c.get("km", 0)) / 4)
	if result.get("delivered", false) and c.get("kind", "") == "contract":
		t["city"] = c["to"]
	var unlocked: Array = []
	for id in CITIES:
		var need := int(CITIES[id]["rep"])
		if rep_before < need and rep() >= need:
			unlocked.append(CITIES[id]["name"])
	Game.save_game()
	return {"lines": lines, "total": final_pay, "rep_d": rep_d, "rep": rep(), "unlocked": unlocked}


# ---------------------------------------------------------------- أرقام عربية للوحات
func ar_num(n: int) -> String:
	var digits := "٠١٢٣٤٥٦٧٨٩"
	var s := str(n)
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += digits[int(ch)]
		else:
			out += ch
	return out
