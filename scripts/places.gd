extends Node
## IBRA DRIVE — كل أماكن العالم (20 بيئة × 6 = 120 مكان)

const SEASONS := {"summer": "صيف", "winter": "شتاء", "spring": "ربيع", "autumn": "خريف"}

const WEATHER := {
	"clear": {"name": "صافي", "clouds": 0.08, "light": 1.0, "fog": 0.0010, "rain": 0.0, "snow": 0.0, "sand": 0.0, "wet": 0.0, "wind": 0.6},
	"cloudy": {"name": "غائم", "clouds": 0.75, "light": 0.6, "fog": 0.0025, "rain": 0.0, "snow": 0.0, "sand": 0.0, "wet": 0.0, "wind": 1.1},
	"rain": {"name": "ماطر", "clouds": 0.95, "light": 0.42, "fog": 0.006, "rain": 1.0, "snow": 0.0, "sand": 0.0, "wet": 1.0, "wind": 1.5},
	"storm": {"name": "عاصفة رعدية", "clouds": 1.0, "light": 0.26, "fog": 0.008, "rain": 1.6, "snow": 0.0, "sand": 0.0, "wet": 1.0, "wind": 2.4},
	"snow": {"name": "ثلج", "clouds": 0.85, "light": 0.6, "fog": 0.011, "rain": 0.0, "snow": 1.0, "sand": 0.0, "wet": 0.2, "wind": 1.0},
	"fog": {"name": "ضباب", "clouds": 0.6, "light": 0.62, "fog": 0.03, "rain": 0.0, "snow": 0.0, "sand": 0.0, "wet": 0.3, "wind": 0.3},
	"sandstorm": {"name": "عاصفة ترابية", "clouds": 0.4, "light": 0.55, "fog": 0.035, "rain": 0.0, "snow": 0.0, "sand": 1.0, "wet": 0.0, "wind": 3.0},
}

const HOURS := [6.0, 8.5, 11.0, 13.5, 16.0, 17.8, 20.5, 23.0]

# كل بيئة: ألوان الأرض، شكل التضاريس، الماي، النباتات والأشياء، الأجواء الممكنة
var BIOMES := [
	{"id": "desert", "name": "صحراء", "card": Color(0.86, 0.66, 0.36),
		"low": Color(0.86, 0.69, 0.46), "high": Color(0.96, 0.83, 0.6), "steep": Color(0.78, 0.6, 0.4),
		"amp": 10.0, "freq": 0.011, "ridge": false, "dunes": true, "shape": "none", "water": "none",
		"grip": 0.7, "dust": Color(0.9, 0.78, 0.58), "dusty": 1.0, "track": Color(0.55, 0.42, 0.26), "rally": true, "veg": false,
		"props": [["barn", 3], ["crates", 10], ["ramp", 5], ["wall", 10], ["rock", 70], ["dry_bush", 220], ["dune_grass", 900], ["pole", 16], ["shack", 3], ["tires", 10], ["dead_tree", 30], ["tent", 4], ["wreck", 3]],
		"weathers": ["clear", "clear", "clear", "sandstorm", "cloudy"], "birds": false, "ambient": "",
		"pre": ["كثبان", "صحراء", "بادية", "رمال", "تلال"], "suf": ["الذهب", "السراب", "الريح", "الصقور", "النجوم", "الغروب", "الذئاب", "العطش"]},
	{"id": "beach", "name": "ساحل", "card": Color(0.25, 0.7, 0.75),
		"low": Color(0.86, 0.72, 0.5), "high": Color(0.95, 0.84, 0.63), "steep": Color(0.8, 0.66, 0.46),
		"amp": 7.0, "freq": 0.012, "ridge": false, "dunes": true, "shape": "coast", "water": "sea",
		"grip": 0.74, "dust": Color(0.92, 0.82, 0.62), "dusty": 0.9, "track": Color(0.58, 0.45, 0.3), "veg": false,
		"props": [["dune_grass", 3200], ["palm", 45], ["rock", 30], ["shack", 2], ["boat", 4], ["dry_bush", 80]],
		"weathers": ["clear", "clear", "cloudy", "rain", "storm"], "birds": true, "ambient": "",
		"pre": ["ساحل", "شاطئ", "خليج", "رأس", "مرفأ"], "suf": ["الفيروز", "النوارس", "الأمواج", "اللؤلؤ", "الصيادين", "الشمس", "المرجان"]},
	{"id": "farm", "name": "مزارع وزرع", "card": Color(0.5, 0.65, 0.25),
		"low": Color(0.47, 0.38, 0.26), "high": Color(0.45, 0.55, 0.26), "steep": Color(0.42, 0.34, 0.24),
		"amp": 3.0, "freq": 0.006, "ridge": false, "dunes": false, "shape": "none", "water": "none",
		"grip": 0.8, "dust": Color(0.6, 0.5, 0.36), "dusty": 0.75, "track": Color(0.3, 0.22, 0.14), "veg": true, "fields": 12,
		"props": [["barn", 3], ["crates", 6], ["wall", 18], ["palm", 110], ["house", 4], ["hay", 30], ["pole", 12], ["tree", 40], ["grass", 2500], ["wreck", 1]],
		"weathers": ["clear", "clear", "cloudy", "rain", "fog"], "birds": true, "ambient": "",
		"pre": ["مزارع", "بساتين", "حقول", "سواقي", "ريف"], "suf": ["النخيل", "الحنطة", "الشعير", "البرتقال", "الفلاحين", "النهر", "الخير"]},
	{"id": "city", "name": "شوارع مدينة", "card": Color(0.45, 0.5, 0.6),
		"low": Color(0.52, 0.52, 0.5), "high": Color(0.56, 0.56, 0.54), "steep": Color(0.5, 0.5, 0.48),
		"amp": 0.4, "freq": 0.01, "ridge": false, "dunes": false, "shape": "none", "water": "none",
		"grip": 1.0, "dust": Color(0.6, 0.6, 0.6), "dusty": 0.2, "track": Color(0.08, 0.08, 0.08), "veg": false, "city": 1.0,
		"props": [["tree", 30]],
		"weathers": ["clear", "clear", "cloudy", "rain", "storm", "fog"], "birds": false, "ambient": "",
		"pre": ["شارع", "حي", "مدينة", "منطقة", "ساحة"], "suf": ["الرشيد", "النور", "الأمل", "المنصور", "الجسر", "المحطة", "السوق"]},
	{"id": "forest", "name": "غابة", "card": Color(0.2, 0.5, 0.25),
		"low": Color(0.27, 0.42, 0.19), "high": Color(0.36, 0.5, 0.24), "steep": Color(0.42, 0.36, 0.28),
		"amp": 14.0, "freq": 0.01, "ridge": false, "dunes": false, "shape": "lake", "water": "lake",
		"grip": 0.8, "dust": Color(0.42, 0.34, 0.24), "dusty": 0.45, "track": Color(0.22, 0.16, 0.1), "veg": true,
		"props": [["tree", 380], ["pine", 120], ["bush", 300], ["rock", 60], ["grass", 4500], ["cabin", 2], ["log", 25]],
		"weathers": ["clear", "rain", "fog", "cloudy", "storm"], "birds": true, "ambient": "fireflies",
		"pre": ["غابة", "أحراش", "وادي", "مرتفعات"], "suf": ["البلوط", "الظلال", "الصنوبر", "الغزلان", "الصدى", "الأسرار", "الندى"]},
	{"id": "snow", "name": "ثلوج", "card": Color(0.75, 0.85, 0.95),
		"low": Color(0.9, 0.93, 0.97), "high": Color(1.0, 1.0, 1.0), "steep": Color(0.55, 0.58, 0.63),
		"amp": 24.0, "freq": 0.008, "ridge": false, "dunes": false, "shape": "lake", "water": "ice",
		"grip": 0.58, "dust": Color(0.97, 0.98, 1.0), "dusty": 1.0, "track": Color(0.62, 0.68, 0.78), "veg": false,
		"props": [["pine_snow", 280], ["rock", 70], ["snowman", 3], ["cabin", 3], ["dead_tree", 20]],
		"weathers": ["snow", "snow", "clear", "fog", "cloudy"], "birds": false, "ambient": "",
		"pre": ["قمم", "سهول", "وادي", "جبال", "بحيرة"], "suf": ["الجليد", "الصقيع", "الشتاء", "الثلج الأبيض", "الدببة", "الشمال", "البرد"]},
	{"id": "marsh", "name": "أهوار", "card": Color(0.3, 0.55, 0.45),
		"low": Color(0.42, 0.42, 0.3), "high": Color(0.48, 0.55, 0.3), "steep": Color(0.38, 0.36, 0.26),
		"amp": 4.0, "freq": 0.02, "ridge": false, "dunes": false, "shape": "marsh", "water": "marsh",
		"grip": 0.62, "dust": Color(0.4, 0.34, 0.24), "dusty": 0.3, "track": Color(0.22, 0.18, 0.12), "veg": true,
		"props": [["reed", 4500], ["boat", 10], ["mudhif", 4], ["palm", 30], ["grass", 1500]],
		"weathers": ["clear", "fog", "cloudy", "rain"], "birds": true, "ambient": "",
		"pre": ["أهوار", "مسطحات", "جزر", "قصب"], "suf": ["الجبايش", "الحويزة", "القصب", "الجاموس", "المشاحيف", "الطيور", "الفجر"]},
	{"id": "canyon", "name": "وديان صخرية", "card": Color(0.75, 0.38, 0.22),
		"low": Color(0.72, 0.42, 0.26), "high": Color(0.86, 0.56, 0.36), "steep": Color(0.6, 0.3, 0.2),
		"amp": 26.0, "freq": 0.008, "ridge": true, "dunes": false, "shape": "none", "water": "none",
		"grip": 0.86, "dust": Color(0.78, 0.5, 0.34), "dusty": 0.85, "track": Color(0.45, 0.25, 0.15), "veg": false,
		"props": [["ramp", 4], ["rock", 160], ["dead_tree", 30], ["dry_bush", 160], ["crystals", 10], ["wreck", 2]],
		"weathers": ["clear", "clear", "sandstorm", "cloudy"], "birds": false, "ambient": "",
		"pre": ["وادي", "أخدود", "صخور", "منحدرات"], "suf": ["الحمراء", "النسور", "الصدى", "الأفاعي", "العقارب", "النار"]},
	{"id": "savanna", "name": "سهول السافانا", "card": Color(0.78, 0.66, 0.3),
		"low": Color(0.7, 0.6, 0.32), "high": Color(0.8, 0.7, 0.4), "steep": Color(0.6, 0.5, 0.32),
		"amp": 7.0, "freq": 0.009, "ridge": false, "dunes": false, "shape": "lake", "water": "lake",
		"grip": 0.8, "dust": Color(0.75, 0.62, 0.42), "dusty": 0.8, "track": Color(0.4, 0.32, 0.18), "rally": true, "veg": true,
		"props": [["barn", 2], ["crates", 4], ["wall", 4], ["acacia", 80], ["grass_dry", 5000], ["rock", 40], ["bush", 90]],
		"weathers": ["clear", "clear", "cloudy", "rain", "storm"], "birds": true, "ambient": "",
		"pre": ["سهول", "براري", "مراعي"], "suf": ["الأسود", "الزرافات", "الشمس الحارقة", "الريح", "القطعان", "الأفق"]},
	{"id": "meadow", "name": "مروج الربيع", "card": Color(0.45, 0.75, 0.35),
		"low": Color(0.34, 0.58, 0.24), "high": Color(0.44, 0.66, 0.3), "steep": Color(0.45, 0.42, 0.3),
		"amp": 11.0, "freq": 0.009, "ridge": false, "dunes": false, "shape": "river", "water": "lake",
		"grip": 0.84, "dust": Color(0.5, 0.42, 0.3), "dusty": 0.35, "track": Color(0.25, 0.2, 0.12), "veg": true,
		"props": [["wall", 8], ["flower", 4000], ["grass", 5000], ["tree", 60], ["rock", 30], ["house", 2], ["bush", 60]],
		"weathers": ["clear", "clear", "cloudy", "rain"], "birds": true, "ambient": "fireflies",
		"pre": ["مروج", "تلال", "سهل", "بساتين"], "suf": ["الزهور", "شقائق النعمان", "النسيم", "الفراشات", "الربيع", "العسل"]},
	{"id": "autumn", "name": "غابة الخريف", "card": Color(0.85, 0.45, 0.15),
		"low": Color(0.5, 0.4, 0.22), "high": Color(0.58, 0.45, 0.25), "steep": Color(0.45, 0.36, 0.26),
		"amp": 13.0, "freq": 0.01, "ridge": false, "dunes": false, "shape": "lake", "water": "lake",
		"grip": 0.78, "dust": Color(0.5, 0.38, 0.24), "dusty": 0.5, "track": Color(0.26, 0.18, 0.1), "veg": true, "force_season": "autumn",
		"props": [["tree", 400], ["bush", 200], ["grass_dry", 3500], ["rock", 50], ["cabin", 2], ["log", 30]],
		"weathers": ["clear", "cloudy", "rain", "fog"], "birds": true, "ambient": "leaves",
		"pre": ["غابة", "درب", "تلال", "وادي"], "suf": ["الأوراق الذهبية", "القيقب", "الخريف", "الحطابين", "الضباب", "الكستناء"]},
	{"id": "volcanic", "name": "أرض بركانية", "card": Color(0.55, 0.18, 0.1),
		"low": Color(0.17, 0.15, 0.14), "high": Color(0.28, 0.24, 0.22), "steep": Color(0.12, 0.1, 0.1),
		"amp": 20.0, "freq": 0.009, "ridge": true, "dunes": false, "shape": "lake", "water": "lava",
		"grip": 0.85, "dust": Color(0.3, 0.28, 0.27), "dusty": 0.9, "track": Color(0.08, 0.07, 0.07), "veg": false,
		"props": [["rock", 130], ["dead_tree", 40], ["crystals", 22]],
		"weathers": ["clear", "fog", "cloudy"], "birds": false, "ambient": "ash",
		"pre": ["فوهة", "حمم", "أرض", "جبل"], "suf": ["النار", "الرماد", "التنين", "البركان", "الجحيم", "الكبريت"]},
	{"id": "saltflat", "name": "سبخة ملحية", "card": Color(0.85, 0.85, 0.82),
		"low": Color(0.92, 0.91, 0.87), "high": Color(0.95, 0.94, 0.9), "steep": Color(0.8, 0.78, 0.72),
		"amp": 1.5, "freq": 0.01, "ridge": false, "dunes": false, "shape": "none", "water": "none",
		"grip": 0.92, "dust": Color(0.95, 0.94, 0.92), "dusty": 0.7, "track": Color(0.6, 0.58, 0.52), "rally": true, "veg": false,
		"props": [["ramp", 8], ["crates", 8], ["barn", 1], ["wall", 6], ["rock", 15], ["wreck", 5], ["pole", 14], ["tires", 6]],
		"weathers": ["clear", "clear", "cloudy", "sandstorm"], "birds": false, "ambient": "",
		"pre": ["سبخة", "ملاحة", "سهل"], "suf": ["الملح", "المرايا", "السرعة", "البياض", "الصمت"]},
	{"id": "mountains", "name": "جبال", "card": Color(0.45, 0.5, 0.45),
		"low": Color(0.34, 0.45, 0.24), "high": Color(0.58, 0.58, 0.54), "steep": Color(0.45, 0.43, 0.4),
		"amp": 30.0, "freq": 0.0065, "ridge": true, "dunes": false, "shape": "lake", "water": "lake",
		"grip": 0.82, "dust": Color(0.5, 0.46, 0.4), "dusty": 0.6, "track": Color(0.25, 0.22, 0.18), "veg": true,
		"props": [["pine", 280], ["rock", 160], ["cabin", 2], ["grass", 2500]],
		"weathers": ["clear", "cloudy", "rain", "fog", "snow"], "birds": true, "ambient": "",
		"pre": ["جبال", "قمة", "ممر", "هضبة"], "suf": ["كردستان", "الشلالات", "الغيوم", "النسور", "الحجر", "الكهوف"]},
	{"id": "jungle", "name": "غابة استوائية", "card": Color(0.1, 0.45, 0.2),
		"low": Color(0.2, 0.36, 0.14), "high": Color(0.26, 0.44, 0.18), "steep": Color(0.36, 0.3, 0.2),
		"amp": 12.0, "freq": 0.011, "ridge": false, "dunes": false, "shape": "river", "water": "lake",
		"grip": 0.7, "dust": Color(0.35, 0.28, 0.18), "dusty": 0.3, "track": Color(0.18, 0.13, 0.08), "veg": true,
		"props": [["palm", 150], ["tree_big", 280], ["bush", 600], ["grass", 5000]],
		"weathers": ["rain", "rain", "storm", "cloudy", "clear", "fog"], "birds": true, "ambient": "fireflies",
		"pre": ["أدغال", "غابة", "نهر"], "suf": ["الأمازون", "القرود", "المطر", "الببغاوات", "الكنز المفقود", "الأفاعي"]},
	{"id": "oasis", "name": "واحة", "card": Color(0.4, 0.75, 0.55),
		"low": Color(0.87, 0.71, 0.48), "high": Color(0.95, 0.82, 0.6), "steep": Color(0.78, 0.6, 0.42),
		"amp": 9.0, "freq": 0.012, "ridge": false, "dunes": true, "shape": "lake", "water": "lake",
		"grip": 0.72, "dust": Color(0.9, 0.78, 0.58), "dusty": 1.0, "track": Color(0.55, 0.42, 0.26), "rally": true, "veg": false,
		"props": [["crates", 5], ["ramp", 2], ["wall", 8], ["palm", 130], ["dune_grass", 1500], ["tent", 5], ["rock", 30], ["dry_bush", 100]],
		"weathers": ["clear", "clear", "sandstorm", "cloudy"], "birds": true, "ambient": "",
		"pre": ["واحة", "عين", "بئر"], "suf": ["الغزلان", "النخيل", "القوافل", "الماء العذب", "البدو", "الأمان"]},
	{"id": "island", "name": "جزيرة", "card": Color(0.1, 0.6, 0.8),
		"low": Color(0.88, 0.76, 0.54), "high": Color(0.55, 0.62, 0.32), "steep": Color(0.6, 0.55, 0.42),
		"amp": 12.0, "freq": 0.01, "ridge": false, "dunes": false, "shape": "island", "water": "sea",
		"grip": 0.76, "dust": Color(0.92, 0.84, 0.66), "dusty": 0.8, "track": Color(0.55, 0.44, 0.3), "veg": true,
		"props": [["palm", 110], ["dune_grass", 2000], ["rock", 50], ["shack", 2], ["boat", 5], ["bush", 120]],
		"weathers": ["clear", "clear", "cloudy", "rain", "storm"], "birds": true, "ambient": "",
		"pre": ["جزيرة", "أرخبيل", "شبه جزيرة"], "suf": ["القراصنة", "الكنز", "المحار", "السلاحف", "النخيل", "الأحلام"]},
	{"id": "village", "name": "قرية ريفية", "card": Color(0.7, 0.55, 0.35),
		"low": Color(0.6, 0.5, 0.34), "high": Color(0.5, 0.55, 0.3), "steep": Color(0.5, 0.42, 0.3),
		"amp": 3.5, "freq": 0.008, "ridge": false, "dunes": false, "shape": "river", "water": "lake",
		"grip": 0.8, "dust": Color(0.65, 0.54, 0.38), "dusty": 0.8, "track": Color(0.32, 0.24, 0.15), "veg": true, "fields": 5,
		"props": [["crates", 6], ["wall", 30], ["house", 26], ["palm", 120], ["tree", 40], ["hay", 20], ["pole", 12], ["wreck", 3], ["grass", 2000]],
		"weathers": ["clear", "clear", "cloudy", "rain", "fog"], "birds": true, "ambient": "",
		"pre": ["قرية", "ضيعة", "ناحية"], "suf": ["الطين", "النهر", "الجسر الخشبي", "الطاحونة", "العشيرة", "الصباح"]},
	{"id": "tundra", "name": "تندرا", "card": Color(0.55, 0.6, 0.55),
		"low": Color(0.5, 0.52, 0.42), "high": Color(0.62, 0.62, 0.55), "steep": Color(0.45, 0.45, 0.42),
		"amp": 9.0, "freq": 0.009, "ridge": false, "dunes": false, "shape": "lake", "water": "ice",
		"grip": 0.66, "dust": Color(0.75, 0.75, 0.72), "dusty": 0.6, "track": Color(0.3, 0.3, 0.26), "veg": true, "force_season": "winter",
		"props": [["rock", 90], ["bush", 160], ["pine_snow", 40], ["grass_dry", 2500]],
		"weathers": ["snow", "fog", "cloudy", "clear"], "birds": false, "ambient": "",
		"pre": ["تندرا", "سهوب", "أرض"], "suf": ["الرياح الباردة", "الشفق", "الذئاب البيضاء", "الصمت", "الجليد الأزلي"]},
	{"id": "outskirts", "name": "أطراف المدينة", "card": Color(0.6, 0.55, 0.5),
		"low": Color(0.62, 0.55, 0.42), "high": Color(0.66, 0.6, 0.46), "steep": Color(0.55, 0.48, 0.36),
		"amp": 0.8, "freq": 0.01, "ridge": false, "dunes": false, "shape": "none", "water": "none",
		"grip": 0.95, "dust": Color(0.7, 0.62, 0.48), "dusty": 0.6, "track": Color(0.12, 0.11, 0.1), "veg": false, "city": 0.35,
		"props": [["crates", 14], ["barn", 2], ["ramp", 3], ["wall", 35], ["palm", 40], ["wreck", 6], ["tires", 8], ["dry_bush", 120]],
		"weathers": ["clear", "clear", "cloudy", "sandstorm", "rain"], "birds": false, "ambient": "",
		"pre": ["أطراف", "طريق", "حي", "ضاحية"], "suf": ["المصانع", "الكراجات", "الطريق السريع", "المستودعات", "الجديدة", "الصناعي"]},
]

var list: Array = []


func _ready() -> void:
	_generate()


func _generate() -> void:
	list.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	var used := {}
	var per_biome := 6
	var total := BIOMES.size() * per_biome
	for i in total:
		var b: Dictionary = BIOMES[i % BIOMES.size()]
		var nm := ""
		for _t in 40:
			nm = "%s %s" % [b["pre"][rng.randi() % b["pre"].size()], b["suf"][rng.randi() % b["suf"].size()]]
			if not used.has(nm):
				break
		if used.has(nm):
			nm += " " + str(i + 1)
		used[nm] = true
		var season := _pick_season(b, rng)
		var weathers := weathers_for(b, season)
		list.append({
			"idx": i, "name": nm, "biome": b["id"], "season": season,
			"weather": weathers[rng.randi() % weathers.size()],
			"hour": HOURS[rng.randi() % HOURS.size()],
			"seed": 1000 + i * 7919,
			"req_level": 1 + int(i / 5),
		})


func _pick_season(b: Dictionary, rng: RandomNumberGenerator) -> String:
	if b.has("force_season"):
		return b["force_season"]
	match b["id"]:
		"snow":
			return "winter"
		"desert", "saltflat", "canyon", "oasis":
			return ["summer", "summer", "spring", "autumn"][rng.randi() % 4]
		"meadow":
			return ["spring", "spring", "summer"][rng.randi() % 3]
	return ["summer", "winter", "spring", "autumn"][rng.randi() % 4]


func weathers_for(b: Dictionary, season: String) -> Array:
	var w: Array = b["weathers"].duplicate()
	if season == "winter" and b["id"] in ["forest", "mountains", "meadow", "village", "farm", "autumn", "city", "savanna"]:
		w.append("snow")
		w.append("rain")
	if season == "summer":
		w = w.filter(func(x): return x != "snow" or b["id"] in ["snow", "tundra"])
		if w.is_empty():
			w = ["clear"]
	if season == "spring" and not w.has("rain") and b["veg"]:
		w.append("rain")
	return w


func get_biome(id: String) -> Dictionary:
	for b in BIOMES:
		if b["id"] == id:
			return b
	return BIOMES[0]


func get_place(idx: int) -> Dictionary:
	return list[clampi(idx, 0, list.size() - 1)]


func is_unlocked(idx: int) -> bool:
	return Game.level() >= int(get_place(idx)["req_level"])


func hour_text(h: float) -> String:
	var hh := int(h) % 24
	var mm := int((h - floor(h)) * 60.0)
	return "%02d:%02d" % [hh, mm]


func time_name(h: float) -> String:
	if h < 5.0 or h >= 20.5:
		return "ليل"
	if h < 7.0:
		return "فجر"
	if h < 11.5:
		return "صباح"
	if h < 15.0:
		return "ظهر"
	if h < 18.0:
		return "عصر"
	return "غروب"
