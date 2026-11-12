extends Node
## مدرسة IBRA لتعليم السياقة: دروس لكل نوع سيارة، وامتحان، وإجازة سوق. مو شرط — بس اللي ما يعرف يسوق يتعلم

const LESSONS := [
	{"id": "basics", "title": "المشي والوقوف", "car": "sedan", "class": "خصوصي", "trailers": 0,
		"desc": "W تمشي، S فرامل. امشِ بين الأقماع ووكّف داخل المربع الأخضر.",
		"intro": [["الأستاذ أبو سيف", "هلا بيك بمدرسة IBRA! أول شي: W تمشي، وS تفرمل. إذا وكفت وضغطت S ترجع ريوس."],
			["الأستاذ أبو سيف", "امشِ بين الأقماع، وبالمربع الأخضر وكّف تماماً. لا تخاف، كلنا بدينا هيج."]]},
	{"id": "steer", "title": "التوجيه بين الأقماع", "car": "sedan", "class": "خصوصي", "trailers": 0,
		"desc": "A و D للتوجيه. لف حوالي الأقماع مرة يمين ومرة يسار.",
		"intro": [["الأستاذ أبو سيف", "A يسار، D يمين. الأقماع الحمرة مرة من يمينها ومرة من يسارها، مثل الأفعى."],
			["الأستاذ أبو سيف", "خفف السرعة قبل المنعطف، مو وانت بنصه."]]},
	{"id": "reverse", "title": "الريوس", "car": "sedan", "class": "خصوصي", "trailers": 0,
		"desc": "ارجع للخلف بين الأقماع لحد المربع. بالريوس التوجيه بالعكس!",
		"intro": [["الأستاذ أبو سيف", "هسة ريوس. وكّف، واضغط S وتمسك. السيارة ترجع لورا."],
			["الأستاذ أبو سيف", "انتبه: بالريوس إذا تريد الصندوق يروح يمين، وجّه يمين. شوف المراية... يعني الكاميرا هههه."]]},
	{"id": "park", "title": "الركن بين سيارتين", "car": "sedan", "class": "خصوصي", "trailers": 0,
		"desc": "اركن بالمكان الفارغ بين السيارتين بدون ما تضربهن، والسيارة مستقيمة.",
		"intro": [["الأستاذ أبو سيف", "شايف المكان الفارغ بين السيارتين؟ ادخل بيه بهدوء، وخلي السيارة عدلة."]]},
	{"id": "handbrake", "title": "اللفة بالهاند بريك", "car": "rally", "class": "خصوصي", "trailers": 0,
		"desc": "روح للقمع البعيد، لف حواليه بسرعة بالهاند بريك (Space) وارجع للمربع خلال 35 ثانية.",
		"intro": [["الأستاذ أبو سيف", "درس الأبطال! Space هو الهاند بريك. تدوس عليه بالمنعطف وتوجّه، والسيارة تلف بمكانها."],
			["الأستاذ أبو سيف", "بس بالشارع لا تسويها، هاي للطوارئ والرالي."]]},
	{"id": "truck_turn", "title": "الشاحنة بالمنعطف", "car": "semi_rafidain", "class": "حمل ثقيل", "trailers": 1, "trailer_kind": "box",
		"desc": "المقطورة تلف أوسع من الشاحنة. خذ المنعطف من بعيد حتى ما توكع الأقماع.",
		"intro": [["الأسطة كريم", "هلا بالسائق الجديد. هاي التريلة: الرأس يسحب، والمقطورة تمشي وراه بس تقص المنعطف."],
			["الأسطة كريم", "يعني لازم تفتح المنعطف: روح لبعيد شوية وبعدين لف. إذا وكعت أكثر من 3 أقماع تعيد."]]},
	{"id": "truck_dock", "title": "ريوس المقطورة للرصيف", "car": "semi_rafidain", "class": "حمل ثقيل", "trailers": 1, "trailer_kind": "box",
		"desc": "ارجع المقطورة ريوس لحد ما يدخل ذيلها بالمربع جنب الحايط.",
		"intro": [["الأسطة كريم", "أصعب شي بالشاحنات: الريوس بالمقطورة. توجّه بالعكس، وبحركات صغيرة."],
			["الأسطة كريم", "إذا المقطورة انطوت، امشِ قدام شوية وعدّلها وارجع. الصبر مفتاح الفرج."]]},
	{"id": "double", "title": "مقطورتين", "car": "semi_dijla", "class": "حمل ثقيل", "trailers": 2, "trailer_kind": "box",
		"desc": "سوق بمقطورتين بين البوابات ووكّف بالمربع والمقطورات عدلة.",
		"intro": [["الأسطة كريم", "مقطورتين يعني قطار صغير! كل حركة توجيه تتضاعف بالمقطورة الثانية. هدوء وبس."]]},
	{"id": "offroad", "title": "الدفع الرباعي والتلول", "car": "jeep", "class": "دفع رباعي", "trailers": 0,
		"desc": "اصعد التل، وكّف على القمة، وانزل للمربع.",
		"intro": [["الأستاذ أبو سيف", "الجيب دفع رباعي. بالصعود دوس بثبات، وبالنزول خفف ولا تفرمل بقوة."]]},
]

const EXAM := {"kind": "exam", "goal": "deliver", "style": "rural", "from": "hillah", "to": "karbala", "car": "sedan",
	"trailers": 0, "hour": 9.0, "weather": "clear", "title": "امتحان إجازة السوق", "seed": 4242}


func done(id: String) -> bool:
	return bool(Game.data.get("school", {}).get(id, false))


func mark(id: String) -> bool:
	if not (Game.data.get("school") is Dictionary):
		Game.data["school"] = {}
	var first := not done(id)
	Game.data["school"][id] = true
	if first:
		Game.data["coins"] = int(Game.data["coins"]) + 150
	Game.save_game()
	return first


func lesson(id: String) -> Dictionary:
	for l in LESSONS:
		if l["id"] == id:
			return l
	return LESSONS[0]


func lesson_index(id: String) -> int:
	for i in LESSONS.size():
		if LESSONS[i]["id"] == id:
			return i
	return 0


func spec_for(id: String) -> Dictionary:
	var l := lesson(id)
	return {"kind": "lesson", "lesson": id, "goal": "lesson", "style": "yard", "length": 400.0, "car": l["car"],
		"trailers": int(l["trailers"]), "trailer_kind": l.get("trailer_kind", ""), "hour": 10.0, "weather": "clear",
		"season": "spring", "title": "درس: " + l["title"], "seed": 900 + lesson_index(id)}


func classes() -> Array:
	var out: Array = []
	for l in LESSONS:
		if done(l["id"]) and not out.has(l["class"]):
			out.append(l["class"])
	if out.is_empty():
		out.append("خصوصي")
	return out


func has_license() -> bool:
	return not Game.data.get("license", {}).is_empty()


func award_license() -> void:
	var nm: String = Game.data.get("player_name", "")
	Game.data["license"] = {"name": nm if nm != "" else "سائق IBRA", "date": Time.get_date_string_from_system(),
		"no": "IB-%06d" % (randi() % 1000000), "classes": classes()}
	Game.data["coins"] = int(Game.data["coins"]) + 500
	Game.save_game()
