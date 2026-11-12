extends Node
## IBRA DRIVE — وضع القصة: لكل سيارة قصة وفصول. كل فصل = مهمة على الطريق مع حوار قبل وبعد

# الأسلوب style: highway طريق سريع • rural طريق ريفي • dirt ترابي • desert بادية بلا طريق • mountain جبلي • marsh أهوار
# الهدف goal: deliver توصيل • race سباق بحلقات ووقت • rescue إنقاذ سيارة عالقة وسحبها
const STORIES := [
	{"car": "semi_rafidain", "title": "طريق المحافظات", "hero": "حيدر",
		"tagline": "شاحنة أبوك أمانة برقبتك. من البصرة لكردستان، كل حمولة توصلها تكبّر اسم نقليات الرافدين.",
		"color": Color(0.85, 0.2, 0.12),
		"chapters": [
			{"title": "أول حمولة", "reward": 600,
				"mission": {"goal": "deliver", "from": "basra", "to": "nasiriyah", "cargo": "dates", "trailers": 1, "hour": 7.0, "weather": "clear"},
				"intro": [["الحاج كاظم", "حيدر ابني، أبوك صار عمره سبعين سنة، وهاي الشاحنة أمانة برقبتك من اليوم."],
					["الحاج كاظم", "حمولة تمر للناصرية. على كيفك بالمنعطفات، المقطورة تلف أوسع من الشاحنة."],
					["حيدر", "لا تشيل هم يابه، أوصلها وأرجعلك بالسلامة."],
					["الحاج كاظم", "وتذكر: بالسيطرة توكف، وتسلّم عالشباب، وتمشي بهدوء."]],
				"outro": [["تاجر التمر", "عاشت إيدك! أول مرة سائق جديد يوصل بهالترتيب."], ["الحاج كاظم", "(بالتلفون) سمعت عنك خير يا ولدي. هسة صدكت صرت سائق."]]},
			{"title": "زجاج للعمارة", "reward": 800,
				"mission": {"goal": "deliver", "from": "basra", "to": "amarah", "cargo": "glass", "trailers": 1, "hour": 9.0, "weather": "clear", "events": ["blowout"]},
				"intro": [["أبو مرتضى (المقاول)", "هذا زجاج شبابيك لمستشفى العمارة. كل طسّة وكل مطب يكسر لوح."],
					["حيدر", "يعني لا سرعة ولا مطبات... فهمت عليك."], ["أبو مرتضى", "وإذا انكسر شي، من أجرتك."]],
				"outro": [["أبو مرتضى", "ولا لوح مكسور؟! والله ما توقعتها. خذ رقمي، عندي شغل هواية."]]},
			{"title": "تانكر الماي", "reward": 900,
				"mission": {"goal": "deliver", "from": "nasiriyah", "to": "samawah", "cargo": "water", "trailers": 1, "hour": 13.0, "weather": "clear", "season": "summer"},
				"intro": [["مدير الماء", "الحر خمسين درجة والسماوة ناقصها ماي صالح للشرب."],
					["الحاج كاظم", "انتبه يا حيدر، الماي بالتانكر يتمايل ويسحبك يم المنعطف. خفف قبل لا تلف، مو وانت لاف."]],
				"outro": [["طفل من السماوة", "عمو! جبت الماي؟ الله يخليك!"], ["حيدر", "هاي الأجرة الحقيقية..."]]},
			{"title": "سيطرة الليل", "reward": 1000,
				"mission": {"goal": "deliver", "from": "samawah", "to": "diwaniyah", "cargo": "electronics", "trailers": 1, "hour": 21.0, "weather": "clear"},
				"intro": [["أبو علي (سائق قديم)", "الطريق بالليل غير شكل. شغّل الضوايات، وبالسيطرة وكّف زين."],
					["حيدر", "وإذا تعبت؟"], ["أبو علي", "توكف بالمطعم وتشرب استكان چاي. التعب يقتل أكثر من السرعة."]],
				"outro": [["جندي بالسيطرة", "الله وياك أخي. سائق مرتب، نتمنى الكل مثلك."]]},
			{"title": "أدوية مستعجلة", "reward": 1300,
				"mission": {"goal": "deliver", "from": "diwaniyah", "to": "hillah", "cargo": "medicine", "trailers": 1, "hour": 10.0, "weather": "rain", "deadline": 3.5},
				"intro": [["دكتورة زينب", "مستشفى الحلة محتاجة هاي الأدوية قبل الظهر. كل ساعة تفرق."],
					["حيدر", "والمطر؟"], ["دكتورة زينب", "سوق بعقل، بس لا توكف بلا داعي."]],
				"outro": [["دكتورة زينب", "وصلت بالوقت! أنقذت ناس اليوم يا حيدر، والله ما ننسى."]]},
			{"title": "عجاج الأنبار", "reward": 1500,
				"mission": {"goal": "deliver", "from": "baghdad", "to": "ramadi", "cargo": "pipes", "trailers": 1, "hour": 15.0, "weather": "sandstorm", "events": ["roadblock"]},
				"intro": [["مهندس النفط", "أنابيب طويلة للحقل. المقطورة طويلة، فخذ المنعطفات من بعيد."],
					["أبو علي", "وبالعجاج ما تشوف قدامك عشرين متر. ضوايات، وسرعة قليلة، وعينك عالخط الأبيض."]],
				"outro": [["مهندس النفط", "عبرت العجاج والتحويلة بهالطول؟ أنت سائق مو طبيعي!"]]},
			{"title": "مقطورتين لبغداد", "reward": 2000,
				"mission": {"goal": "deliver", "from": "hillah", "to": "baghdad", "cargo": "grain", "trailers": 2, "hour": 8.0, "weather": "clear", "events": ["sheep"]},
				"intro": [["الحاج كاظم", "اشتريتلك دولي ومقطورة ثانية. حنطة لسايلوات بغداد، مقطورتين مرة وحدة."],
					["الحاج كاظم", "مقطورتين يعني الريوس صعب جداً، والمنعطفات أصعب. وانتبه للمواشي بالطريق الريفي."],
					["حيدر", "يابه، صرت أحس الشاحنة جزء مني."]],
				"outro": [["الحاج كاظم", "مقطورتين وما طاحت حبة حنطة؟ ارفع راسي يا ولدي."]]},
			{"title": "الطريق للشمال", "reward": 3000,
				"mission": {"goal": "deliver", "from": "baghdad", "to": "erbil", "cargo": "steel", "trailers": 1, "hour": 6.0, "weather": "rain", "season": "winter"},
				"intro": [["الحاج كاظم", "آخر امتحان: حديد لأربيل. طريق طويل، ومطر، وبعدين جبال."],
					["الحاج كاظم", "إذا وصلتها، الشركة من اليوم باسمك."], ["حيدر", "توكلت على الله."]],
				"outro": [["الحاج كاظم", "نقليات الرافدين صارت نقليات حيدر. الطريق كله إلك يا بطل."],
					["", "خلصت القصة! كمّل بعقود حرة من وضع الأركيد، وطوّر وزيّن شاحنتك."]]},
		]},
	{"car": "jeep", "title": "دليل البادية", "hero": "سلمان",
		"tagline": "البادية ما بيها طريق. بس النجوم، والبوصلة، وسلمان اللي يعرف كل تلّة.",
		"color": Color(0.85, 0.6, 0.3),
		"chapters": [
			{"title": "عبور بادية السماوة", "reward": 500,
				"mission": {"goal": "deliver", "style": "desert", "length": 3200.0, "cargo": "supplies", "hour": 7.0, "weather": "clear", "dest": "مخيم أبو فهد"},
				"intro": [["سلمان", "هنا ماكو شارع. الحلقات الصفرة هي الدرب، والسهم يدلك."], ["الشيخ أبو فهد", "(بالراديو) يا سلمان، نتريّا المؤن قبل الظهر."]],
				"outro": [["الشيخ أبو فهد", "هلا بيك يا سلمان! تفضل على القهوة."]]},
			{"title": "إنقاذ سيارة عالقة", "reward": 700,
				"mission": {"goal": "rescue", "style": "desert", "length": 3000.0, "hour": 16.0, "weather": "clear", "dest": "الطريق العام"},
				"intro": [["سائح ضايع", "(بالراديو) سيارتي غاصت بالرمل وما أعرف وين آني!"], ["سلمان", "لا تتحرك. أجيك وأسحبك. اضغط E من توصل يمه حتى أربط الحبل."]],
				"outro": [["السائح", "لولاك جان بتّ بالبادية. شلون أرد جميلك؟"], ["سلمان", "البادية بيتنا، والضيف ضيف الكل."]]},
			{"title": "ماي للمخيم", "reward": 900,
				"mission": {"goal": "deliver", "style": "desert", "length": 3600.0, "cargo": "tank_small", "trailers": 1, "hour": 11.0, "weather": "clear", "dest": "مخيم الرعاة"},
				"intro": [["راعي غنم", "البير نشف، والغنم عطشانة."], ["سلمان", "ساحب عربانة ماي. بالتلول الماي يتمايل ويدفعني، لازم أصعد بهدوء."]],
				"outro": [["الراعي", "الله يرويك مثل ما رويت غنمنا."]]},
			{"title": "العاصفة الترابية", "reward": 1100,
				"mission": {"goal": "deliver", "style": "desert", "length": 4000.0, "cargo": "medicine", "hour": 17.0, "weather": "sandstorm", "deadline": 4.0, "dest": "مستوصف النخيب"},
				"intro": [["ممرض المستوصف", "عندنا مريض يحتاج دوا الليلة!"], ["سلمان", "العجاج جاي... بس الدوا لازم يوصل."]],
				"outro": [["ممرض المستوصف", "وصلت بهالعاصفة؟ أنت مو دليل، أنت بطل."]]},
			{"title": "طريق الرطبة", "reward": 1600,
				"mission": {"goal": "deliver", "style": "desert", "length": 5500.0, "cargo": "supplies", "hour": 22.0, "weather": "clear", "dest": "الرطبة"},
				"intro": [["سلمان", "أطول درب بالبادية، وبالليل. النجوم وياي."]],
				"outro": [["", "خلصت قصة دليل البادية! جيبك صار أسطورة الرمل."]]},
		]},
	{"car": "pickup", "title": "خيرات البساتين", "hero": "أبو جاسم",
		"tagline": "فلاح من بساتين الفرات، وبيك أب عتيگ يشيل خير الأرض للأسواق.",
		"color": Color(0.4, 0.65, 0.25),
		"chapters": [
			{"title": "تمر للسوق", "reward": 400,
				"mission": {"goal": "deliver", "style": "rural", "from": "karbala", "to": "hillah", "cargo": "crates", "hour": 6.5, "weather": "clear"},
				"intro": [["أم جاسم", "الصناديق مليانة، والسوق يفتح الصبح. لا تتأخر!"], ["أبو جاسم", "البيك أب عتيگ بس قلبه شاب."]],
				"outro": [["بيّاع بالسوق", "تمرك أطيب تمر بالحلة يا أبو جاسم!"]]},
			{"title": "طبكات البيض", "reward": 600,
				"mission": {"goal": "deliver", "style": "rural", "from": "diwaniyah", "to": "najaf", "cargo": "eggs", "hour": 9.0, "weather": "clear", "events": ["sheep"]},
				"intro": [["أبو جاسم", "بيض! كل مطب يعني عشر بيضات مكسورة."], ["أم جاسم", "والغنم بالطريق، لا تنسى."]],
				"outro": [["صاحب المطعم", "بيض سالم؟ معقولة! من اليوم أنت المورّد."]]},
			{"title": "بعد المطر", "reward": 800,
				"mission": {"goal": "deliver", "style": "dirt", "length": 3000.0, "cargo": "crates", "hour": 15.0, "weather": "rain", "dest": "سوق الهندية", "region": "middle"},
				"intro": [["أبو جاسم", "الطريق الترابي صار طين. إذا زلقت، خفف ولا تدوس فرامل بقوة."]],
				"outro": [["أبو جاسم", "الطين ما يغلب ابن البساتين!"]]},
			{"title": "لحك السوق قبل الفجر", "reward": 1000,
				"mission": {"goal": "deliver", "style": "rural", "from": "hillah", "to": "baghdad", "cargo": "crates", "hour": 3.0, "weather": "fog", "deadline": 4.5},
				"intro": [["أبو جاسم", "سوق جميلة ببغداد يفتح الفجر. الضباب كثيف بس لازم نلحك."]],
				"outro": [["", "خلصت قصة خيرات البساتين! أبو جاسم صار أشهر فلاح بالفرات."]]},
		]},
	{"car": "sedan", "title": "مشاوير العائلة", "hero": "مصطفى",
		"tagline": "عرس، وزيارة، وسفرة طويلة. العائلة بالسيارة، والمسؤولية أكبر من أي حمولة.",
		"color": Color(0.85, 0.82, 0.75),
		"chapters": [
			{"title": "كيكة العرس", "reward": 500,
				"mission": {"goal": "deliver", "from": "baghdad", "to": "hillah", "cargo": "cake", "hour": 16.0, "weather": "clear", "deadline": 3.0},
				"intro": [["أم مصطفى", "مصطفى! الكيكة بالسيارة والعرس بعد ساعات بالحلة!"], ["مصطفى", "كيكة سبع طوابق... الله يستر من المطبات."]],
				"outro": [["العريس", "وصلت الكيكة سالمة! أنت أحسن هدية بالعرس."]]},
			{"title": "زيارة كربلاء", "reward": 700,
				"mission": {"goal": "deliver", "from": "baghdad", "to": "karbala", "cargo": "family", "hour": 20.5, "weather": "clear"},
				"intro": [["أبو مصطفى", "سوق على راحتك ابني، جدتك وياك ببالسيارة."], ["الجدة", "يمه مصطفى، لا تسرع، قلبي ما يتحمل."]],
				"outro": [["الجدة", "الله يحفظك يمه، وصلتنا مثل الحرير."]]},
			{"title": "سفرة البصرة", "reward": 1100,
				"mission": {"goal": "deliver", "from": "baghdad", "to": "basra", "cargo": "family", "hour": 10.0, "weather": "rain"},
				"intro": [["مصطفى", "أطول سفرة: بغداد للبصرة، والمطر ما يوكف."], ["أخت مصطفى", "خلي نوكف بمطعم بالطريق، جوعانين!"]],
				"outro": [["", "خلصت قصة مشاوير العائلة! كل العائلة وصلت سالمة."]]},
		]},
	{"car": "buggy", "title": "ملك الكثبان", "hero": "رامي",
		"tagline": "سباقات الكثبان: حلقات، وقت، وقفزات. منو أسرع واحد بالبادية؟",
		"color": Color(1.0, 0.55, 0.1),
		"chapters": [
			{"title": "سباق الكثبان الأول", "reward": 600,
				"mission": {"goal": "race", "style": "desert", "length": 2600.0, "hour": 9.0, "weather": "clear", "time_limit": 150.0},
				"intro": [["منظم السباق", "عدّي من كل الحلقات قبل لا يخلص الوقت. كل حلقة تزيدك ثواني."]],
				"outro": [["منظم السباق", "مو بطال للبداية! بس البطولة أصعب."]]},
			{"title": "سباق الغروب", "reward": 900,
				"mission": {"goal": "race", "style": "desert", "length": 3400.0, "hour": 17.5, "weather": "clear", "time_limit": 185.0},
				"intro": [["رامي", "الشمس تغيب والكثبان تصير ذهب. وقت السرعة."]],
				"outro": [["الجمهور", "رامي! رامي! رامي!"]]},
			{"title": "بطولة البادية", "reward": 1500,
				"mission": {"goal": "race", "style": "desert", "length": 4600.0, "hour": 14.0, "weather": "sandstorm", "time_limit": 270.0},
				"intro": [["منظم السباق", "النهائي، وبعجاج. الحلقات تضوي، ركّز عليها."]],
				"outro": [["", "خلصت قصة ملك الكثبان! أنت بطل البادية."]]},
		]},
	{"car": "rally", "title": "رالي الرافدين", "hero": "نور",
		"tagline": "مراحل رالي على طرق ترابية بين البساتين والجبال. كل ثانية تفرق.",
		"color": Color(0.85, 0.1, 0.12),
		"chapters": [
			{"title": "مرحلة البساتين", "reward": 700,
				"mission": {"goal": "race", "style": "dirt", "length": 3000.0, "hour": 10.0, "weather": "clear", "time_limit": 165.0, "region": "middle"},
				"intro": [["مدربة نور", "طريق ترابي بين النخيل. استخدم الهاند بريك بالمنعطفات الضيقة."]],
				"outro": [["المعلق", "نور تدخل التصنيف من أول مرحلة!"]]},
			{"title": "مرحلة المطر", "reward": 1000,
				"mission": {"goal": "race", "style": "dirt", "length": 3500.0, "hour": 15.0, "weather": "rain", "time_limit": 205.0, "region": "south"},
				"intro": [["مدربة نور", "الطين يغير كل شي. فرامل بدري، وتفحيط محسوب."]],
				"outro": [["المعلق", "تحت المطر وبهالسرعة؟ نور تتصدر!"]]},
			{"title": "مرحلة جبال كردستان", "reward": 1600,
				"mission": {"goal": "race", "style": "mountain", "length": 4400.0, "hour": 8.0, "weather": "clear", "time_limit": 255.0, "season": "spring"},
				"intro": [["نور", "منعطفات جبلية ووادي على صفحة. لحظة غلط وأطير."]],
				"outro": [["", "خلصت قصة رالي الرافدين! نور بطلة العراق بالرالي."]]},
		]},
	{"car": "truck", "title": "إغاثة الشمال", "hero": "كاوه",
		"tagline": "قرى جبلية مقطوعة بالثلج، وشاحنة إغاثة ما توكف.",
		"color": Color(0.95, 0.75, 0.15),
		"chapters": [
			{"title": "مؤن للقرية", "reward": 800,
				"mission": {"goal": "deliver", "style": "mountain", "length": 3400.0, "cargo": "supplies", "hour": 9.0, "weather": "snow", "season": "winter", "dest": "قرية بالجبل"},
				"intro": [["مختار القرية", "(بالراديو) الطريق مسكّر بالثلج من أسبوع، والأكل خلص."], ["كاوه", "جايكم. الجبل ما يوكفني."]],
				"outro": [["مختار القرية", "الله يحفظك يا كاوه، القرية كلها تدعيلك."]]},
			{"title": "بطانيات قبل العاصفة", "reward": 1100,
				"mission": {"goal": "deliver", "style": "mountain", "length": 4000.0, "cargo": "supplies", "hour": 15.0, "weather": "snow", "season": "winter", "deadline": 4.0, "dest": "مدرسة القرية"},
				"intro": [["معلمة المدرسة", "العاصفة جاية الليلة والأطفال بالمدرسة بلا بطانيات."]],
				"outro": [["الأطفال", "شكراً كاوه!"]]},
			{"title": "إنقاذ على الجبل", "reward": 1400,
				"mission": {"goal": "rescue", "style": "mountain", "length": 3800.0, "hour": 12.0, "weather": "fog", "season": "winter", "dest": "مركز الإسعاف"},
				"intro": [["الإسعاف", "سيارة انزلقت على الطريق الجبلي. اسحبها للمركز."]],
				"outro": [["", "خلصت قصة إغاثة الشمال!"]]},
		]},
	{"car": "monster", "title": "وحش الأهوار", "hero": "جبار",
		"tagline": "مونستر تراك بين القصب والماي. الأهوار ما تعرف المستحيل.",
		"color": Color(0.1, 0.75, 0.35),
		"chapters": [
			{"title": "عبور الأهوار", "reward": 700,
				"mission": {"goal": "deliver", "style": "marsh", "length": 3000.0, "cargo": "supplies", "hour": 8.0, "weather": "clear", "dest": "مضيف الجبايش"},
				"intro": [["جبار", "السدة الترابية بين الماي. إذا طحت، المونستر يطلع... إن شاء الله."]],
				"outro": [["صاحب المضيف", "أول مرة سيارة توصل لهنا بلا مشحوف!"]]},
			{"title": "سحب المشحوف", "reward": 1000,
				"mission": {"goal": "rescue", "style": "marsh", "length": 3200.0, "hour": 14.0, "weather": "cloudy", "dest": "قرية الصيادين"},
				"intro": [["صياد", "سيارتي علكت بالطين يم الماي!"], ["جبار", "المونستر يسحب جبل."]],
				"outro": [["الصياد", "تسلم يا جبار، هاي سمچة الغدا عليّ."]]},
			{"title": "سباق القصب", "reward": 1400,
				"mission": {"goal": "race", "style": "marsh", "length": 3600.0, "hour": 17.0, "weather": "clear", "time_limit": 215.0},
				"intro": [["جبار", "سباق بين القصب. الحلقات بين الماي والسدة."]],
				"outro": [["", "خلصت قصة وحش الأهوار!"]]},
		]},
]


func story_for(car_id: String) -> Dictionary:
	for s in STORIES:
		if s["car"] == car_id:
			return s
	return {}


func progress(car_id: String) -> int:
	return int(Game.data.get("story", {}).get(car_id, 0))


func set_progress(car_id: String, n: int) -> void:
	if not (Game.data.get("story") is Dictionary):
		Game.data["story"] = {}
	Game.data["story"][car_id] = maxi(n, progress(car_id))
	Game.save_game()


## يحول فصل لمهمة جاهزة لعالم الطريق
func mission_for(car_id: String, idx: int) -> Dictionary:
	var st := story_for(car_id)
	var ch: Dictionary = st["chapters"][idx]
	var m: Dictionary = ch["mission"].duplicate(true)
	m["kind"] = "story"
	m["car"] = car_id
	m["story_car"] = car_id
	m["chapter"] = idx
	m["title"] = ch["title"]
	m["pay"] = int(ch["reward"])
	if not m.has("trailers"):
		m["trailers"] = 0
	if m.has("cargo") and Jobs.CARGO.has(m["cargo"]):
		m["trailer_kind"] = Jobs.CARGO[m["cargo"]]["trailer"]
	if m.has("from") and m.has("to"):
		var p: Dictionary = Jobs.path(m["from"], m["to"])
		m["km"] = int(p["total"])
	m["seed"] = 7000 + idx * 131 + hash(car_id) % 1000
	return m
