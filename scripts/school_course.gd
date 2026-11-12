extends Node3D
## ساحة مدرسة السياقة: أقماع، مربعات وقوف، سيارات واقفة، رصيف، تل — وكل درس إله هدفه

var world
var lid := "basics"
var cones: Array = []
var stage := 0
var timer := 0.0
var hold := 0.0
var knock_limit := 4
var knocked := 0
var zones: Array = []
var gates: Array = []
var gate_i := 0
var prev_car_z := 0.0
var started := false
var obstacles: Array = []
var center_top := Vector3.ZERO
var done := false
const Y := 2.0


static func hills_for(id: String) -> Array:
	if id == "offroad":
		return [[0.0, -75.0, 40.0, 13.0]]
	return []


func setup() -> void:
	_build_yard()
	match lid:
		"basics":
			for z in [12.0, -6.0, -24.0, -42.0, -60.0]:
				_cone(-3.6, z)
				_cone(3.6, z)
			zones.append(_zone(Vector3(0, Y, -82.0), Vector2(4.2, 7.0), 0.0))
			knock_limit = 8
		"steer":
			for i in 8:
				_cone(0.0, -10.0 - i * 18.0, true)
				gates.append({"z": -10.0 - i * 18.0, "side": 1.0 if i % 2 == 0 else -1.0})
			zones.append(_zone(Vector3(0, Y, -172.0), Vector2(4.2, 7.0), 0.0))
		"reverse":
			var z := 34.0
			while z < 82.0:
				_cone(-2.5, z)
				_cone(2.5, z)
				z += 6.0
			zones.append(_zone(Vector3(0, Y, 91.0), Vector2(3.8, 6.6), 0.0))
		"park":
			for zz in [-28.0, -35.0, -49.0, -56.0]:
				_parked(Vector3(9.0, Y, zz), PI / 2.0)
			zones.append(_zone(Vector3(9.0, Y, -42.0), Vector2(5.4, 2.9), PI / 2.0))
			knock_limit = 99
		"handbrake":
			_cone(0.0, -70.0, true)
			for k in 6:
				var a := TAU * k / 6.0
				_cone(cos(a) * 1.5, -70.0 + sin(a) * 1.5)
			zones.append(_zone(Vector3(0, Y, 22.0), Vector2(5.5, 9.0), 0.0))
			knock_limit = 99
		"truck_turn":
			var zz2 := 12.0
			while zz2 > -60.0:
				_cone(-6.5, zz2)
				_cone(6.5, zz2)
				zz2 -= 7.0
			for k2 in 9:
				var th := PI + k2 / 8.0 * PI * 0.5
				_cone(25.0 + 31.5 * cos(th), -60.0 + 31.5 * sin(th))
				if k2 % 2 == 0:
					_cone(25.0 + 18.5 * cos(th), -60.0 + 18.5 * sin(th))
			var xx := 32.0
			while xx < 118.0:
				_cone(xx, -91.5)
				_cone(xx, -78.5)
				xx += 8.0
			zones.append(_zone(Vector3(97.0, Y, -85.0), Vector2(32.0, 10.0), PI / 2.0))
			knock_limit = 3
		"truck_dock":
			_wall(Vector3(-35.0, Y, -45.0), Vector3(1.2, 1.4, 50.0))
			for zb in [-49.0, -41.0]:
				_paint(Vector3(-25.0, Y, zb), Vector3(20.0, 0.03, 0.2), Color(0.95, 0.8, 0.15))
			zones.append(_zone(Vector3(-31.0, Y, -45.0), Vector2(6.0, 5.2), 0.0, false))
			knock_limit = 99
		"double":
			for g in [[-25.0, 0.0], [-80.0, 8.0], [-135.0, 0.0]]:
				_cone(float(g[1]) - 5.0, float(g[0]), true)
				_cone(float(g[1]) + 5.0, float(g[0]), true)
				gates.append({"z": float(g[0]), "x0": float(g[1]) - 5.0, "x1": float(g[1]) + 5.0})
			zones.append(_zone(Vector3(0, Y, -192.0), Vector2(7.0, 34.0), 0.0))
			knock_limit = 4
		"offroad":
			center_top = Vector3(0, Y + 13.0, -75.0)
			var flag := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.06
			cm.height = 4.0
			flag.mesh = cm
			flag.material_override = _mat(Color(0.8, 0.8, 0.8))
			add_child(flag)
			flag.global_position = center_top + Vector3(3.0, 2.0, 0)
			var fb := _box(Vector3(1.4, 0.8, 0.05), center_top + Vector3(3.7, 3.5, 0), _mat(Color(0.1, 0.7, 0.3)))
			fb.name = "flag"
			_ring(center_top, 7.0)
			zones.append(_zone(Vector3(0, Y, -150.0), Vector2(5.0, 8.0), 0.0))
			knock_limit = 99
	prev_car_z = world.car.global_position.z


# ---------------------------------------------------------------- بناء
func _mat(c: Color, em := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if em > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = em
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	return mi


func _build_yard() -> void:
	var off := lid == "offroad"
	var asph := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 130) if off else Vector2(200, 320)
	asph.mesh = pm
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.2, 0.2, 0.21)
	am.roughness = 0.85
	asph.material_override = am
	add_child(asph)
	asph.global_position = Vector3(35.0, Y + 0.03, 40.0 if off else -50.0)
	# خطوط الساحة
	var line := _mat(Color(0.9, 0.9, 0.85))
	for k in 6:
		_box(Vector3(0.15, 0.02, 3.0), Vector3(0, Y + 0.05, 40.0 - k * 8.0), line)
	# بناية المدرسة
	var b := StaticBody3D.new()
	add_child(b)
	var bpos := Vector3(-48.0, Y, 50.0)
	_box(Vector3(26, 7, 14), bpos + Vector3(0, 3.5, 0), _mat(Color(0.9, 0.86, 0.75)))
	_box(Vector3(27, 0.5, 15), bpos + Vector3(0, 7.2, 0), _mat(Color(0.2, 0.45, 0.65)))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(26, 7, 14)
	cs.shape = bs
	b.add_child(cs)
	cs.global_position = bpos + Vector3(0, 3.5, 0)
	var lb := Label3D.new()
	lb.text = "مدرسة IBRA لتعليم السياقة"
	lb.font = Game.arabic_font
	lb.font_size = 150
	lb.pixel_size = 0.016
	lb.modulate = Color(0.15, 0.3, 0.55)
	lb.outline_size = 10
	lb.outline_modulate = Color(1, 1, 1)
	add_child(lb)
	lb.global_position = bpos + Vector3(0, 5.5, -7.1)
	lb.rotation.y = 0.0
	lb.double_sided = true


func _cone(x: float, z: float, big := false) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 4.0 if not big else 8.0
	add_child(rb)
	var h := 0.75 if not big else 1.1
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.24 if not big else 0.34
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = _mat(Color(1.0, 0.42, 0.05) if not big else Color(0.9, 0.12, 0.08), 0.15)
	rb.add_child(mi)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = cm.bottom_radius * 0.62
	bm.bottom_radius = cm.bottom_radius * 0.72
	bm.height = h * 0.14
	band.mesh = bm
	band.material_override = _mat(Color(0.95, 0.95, 0.95))
	band.position.y = h * 0.08
	rb.add_child(band)
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(cm.bottom_radius * 2.4, 0.05, cm.bottom_radius * 2.4)
	base.mesh = bb
	base.material_override = _mat(Color(0.1, 0.1, 0.1))
	base.position.y = -h * 0.5 + 0.025
	rb.add_child(base)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = cm.bottom_radius * 0.8
	cy.height = h
	cs.shape = cy
	rb.add_child(cs)
	var gy: float = world.ground_h(x, z)
	rb.global_position = Vector3(x, gy + h * 0.5 + 0.02, z)
	cones.append({"rb": rb, "origin": rb.global_position, "knocked": false})


func _zone(c: Vector3, size: Vector2, yaw: float, paint := true) -> Dictionary:
	var gy: float = world.ground_h(c.x, c.z)
	var center := Vector3(c.x, gy, c.z)
	var z := {"c": center, "size": size, "yaw": yaw, "nodes": []}
	if paint:
		var m := _mat(Color(0.2, 1.0, 0.4), 1.5)
		var bas := Basis(Vector3.UP, yaw)
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		for e in [[Vector3(0, 0, -hz), Vector3(size.x, 0.03, 0.18)], [Vector3(0, 0, hz), Vector3(size.x, 0.03, 0.18)],
				[Vector3(-hx, 0, 0), Vector3(0.18, 0.03, size.y)], [Vector3(hx, 0, 0), Vector3(0.18, 0.03, size.y)]]:
			var mi := _box(e[1], center + bas * (e[0] as Vector3) + Vector3(0, 0.06, 0), m)
			mi.basis = bas
			z["nodes"].append(mi)
	return z


func _in_zone(z: Dictionary, p: Vector3) -> bool:
	var lp := Basis(Vector3.UP, float(z["yaw"])).inverse() * (p - (z["c"] as Vector3))
	var sz: Vector2 = z["size"]
	return absf(lp.x) <= sz.x * 0.5 and absf(lp.z) <= sz.y * 0.5


func _parked(pos: Vector3, yaw: float) -> void:
	var m := CarModel.build(["sedan", "pickup", "rally"][obstacles.size() % 3], [Color(0.2, 0.3, 0.6), Color(0.8, 0.8, 0.78), Color(0.6, 0.15, 0.12), Color(0.3, 0.3, 0.32)][obstacles.size() % 4])
	var body := StaticBody3D.new()
	add_child(body)
	body.add_child(m["root"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = m["box_size"]
	cs.shape = bs
	cs.position = m["box_center"]
	body.add_child(cs)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, world.ground_h(pos.x, pos.z), pos.z))
	obstacles.append(body)


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var gy: float = world.ground_h(pos.x, pos.z)
	_box(size, Vector3(pos.x, gy + size.y * 0.5, pos.z), _mat(Color(0.55, 0.55, 0.55)))
	_box(Vector3(size.x + 0.05, 0.25, size.z), Vector3(pos.x, gy + size.y - 0.1, pos.z), _mat(Color(0.95, 0.75, 0.1)))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	cs.global_position = Vector3(pos.x, gy + size.y * 0.5, pos.z)
	obstacles.append(body)


func _paint(pos: Vector3, size: Vector3, c: Color) -> void:
	_box(size, Vector3(pos.x, world.ground_h(pos.x, pos.z) + 0.05, pos.z), _mat(c, 0.5))


func _ring(pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.5
	tm.outer_radius = r
	mi.mesh = tm
	mi.material_override = _mat(Color(0.2, 1.0, 0.45), 2.0)
	mi.scale = Vector3(1, 0.1, 1)
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.1, 0)


# ---------------------------------------------------------------- المتابعة
func _car_points() -> Array:
	var car: IbraCar = world.car
	var bz: float = (car.model["box_size"] as Vector3).z * 0.5 - 0.2
	var bc: Vector3 = car.model["box_center"]
	return [car.global_transform * Vector3(0, 0, bc.z - bz), car.global_transform * Vector3(0, 0, bc.z + bz)]


func _rig_points() -> Array:
	var pts := _car_points()
	if not world.trailers.is_empty():
		var t: TruckTrailer = world.trailers[world.trailers.size() - 1]
		pts[1] = t.global_transform * Vector3(0, 0, t.rear_z - 0.3)
	return pts


func _trailers_straight(limit_deg: float) -> bool:
	var prev: Vector3 = -world.car.global_basis.z
	for t in world.trailers:
		var a := Vector2(prev.x, prev.z).angle_to(Vector2(t.forward().x, t.forward().z))
		if absf(rad_to_deg(a)) > limit_deg:
			return false
		prev = t.forward()
	return true


func _physics_process(delta: float) -> void:
	if done or world == null or world.car == null or world.finished:
		return
	var car: IbraCar = world.car
	var kmh := absf(car.speed) * 3.6
	if not started and (kmh > 2.0 or car.throttle_in > 0.1 or car.brake_in > 0.1):
		started = true
	if started:
		timer += delta
	# الأقماع اللي وكعت
	for c in cones:
		if c["knocked"]:
			continue
		var rb: RigidBody3D = c["rb"]
		if rb.global_basis.y.y < 0.75 or rb.global_position.distance_to(c["origin"]) > 0.7:
			c["knocked"] = true
			knocked += 1
			world.hud.toast("وكع قمع! (%d)" % knocked, Color(1, 0.6, 0.4), 1.5)
			if knocked > knock_limit:
				_finish(false, "وكّعت أقماع هواية! جرّب مرة ثانية على كيفك")
				return
	var cp := car.global_position
	var msg := ""
	match lid:
		"basics", "reverse", "park":
			var z: Dictionary = zones[0]
			var pts := _car_points()
			var inside: bool = _in_zone(z, pts[0]) and _in_zone(z, pts[1])
			if lid == "reverse" and inside and (-car.global_basis.z).z > -0.8:
				inside = false
				msg = "لازم تدخل ريوس (ظهرك للمربع)"
			if lid == "park":
				for o in obstacles:
					if o in car.get_colliding_bodies() and kmh > 1.0:
						_finish(false, "ضربت السيارة الواكفة! الأستاذ: يا ساتر...")
						return
				var fx := absf((-car.global_basis.z).x)
				if inside and fx < 0.93:
					inside = false
					msg = "عدّل السيارة، خليها مستقيمة بالمكان"
			if inside and kmh < 1.0:
				hold += delta
				msg = "ممتاز... ثبّت (%d%%)" % int(hold / 1.5 * 100.0)
				if hold >= 1.5:
					_finish(true, "")
					return
			else:
				hold = 0.0
				if msg == "":
					msg = {"basics": "امشِ بين الأقماع ووكّف داخل المربع الأخضر", "reverse": "ارجع ريوس (S) بين الأقماع للمربع الأخضر",
						"park": "اركن بالمكان الفارغ بين السيارتين (يمين)"}[lid]
					if inside:
						msg = "وكّف تماماً"
		"steer":
			if gate_i < gates.size():
				var g: Dictionary = gates[gate_i]
				var gz: float = g["z"]
				if prev_car_z > gz and cp.z <= gz:
					if signf(cp.x) != float(g["side"]):
						_finish(false, "عبرت القمع من الصوب الغلط! مرة يمين ومرة يسار")
						return
					gate_i += 1
					world.audio.play("pickup", -8.0)
				msg = "عبّر القمع رقم %d من %s" % [gate_i + 1, "يمينه" if float(g["side"]) > 0.0 else "يساره"]
			else:
				var pts2 := _car_points()
				if _in_zone(zones[0], pts2[0]) and _in_zone(zones[0], pts2[1]) and kmh < 1.0:
					hold += delta
					if hold > 1.2:
						_finish(true, "")
						return
				else:
					hold = 0.0
				msg = "وكّف بالمربع الأخضر"
		"handbrake":
			if stage == 0:
				msg = "روح للقمع الأحمر ولف حواليه بالهاند بريك (Space) — %d ثانية" % int(maxf(35.0 - timer, 0.0))
				if cp.z < -76.0:
					stage = 1
					world.audio.play("pickup")
			else:
				msg = "ارجع للمربع الأخضر ووكّف — %d ثانية" % int(maxf(35.0 - timer, 0.0))
				var pts3 := _car_points()
				if _in_zone(zones[0], pts3[0]) and _in_zone(zones[0], pts3[1]) and kmh < 1.5:
					_finish(true, "")
					return
			if timer > 35.0:
				_finish(false, "خلص الوقت! استخدم الهاند بريك حتى تلف أسرع")
				return
		"truck_turn", "double":
			if lid == "double" and gate_i < gates.size():
				var g2: Dictionary = gates[gate_i]
				var gz2: float = g2["z"]
				if prev_car_z > gz2 and cp.z <= gz2:
					if cp.x < float(g2["x0"]) or cp.x > float(g2["x1"]):
						_finish(false, "فاتتك بوابة! لازم تعبر بين القمعين الحمر")
						return
					gate_i += 1
					world.audio.play("pickup", -8.0)
			var rp := _rig_points()
			var ins: bool = _in_zone(zones[0], rp[0]) and _in_zone(zones[0], rp[1])
			if ins and kmh < 1.0:
				if _trailers_straight(14.0):
					hold += delta
					msg = "ثبّت..."
					if hold > 1.2:
						_finish(true, "")
						return
				else:
					msg = "عدّل المقطورات تكون عدلة ويه الشاحنة"
			else:
				hold = 0.0
				msg = "خذ المنعطف واسع ووكّف الشاحنة والمقطورة كلها بالمربع الأخضر" if lid == "truck_turn" else "عبّر بين البوابات (%d/3) ووكّف بالمربع" % gate_i
		"truck_dock":
			var t: TruckTrailer = world.trailers[0]
			var rear := t.global_transform * Vector3(0, 0, t.rear_z - 0.2)
			var aligned := t.forward().x > 0.9
			if _in_zone(zones[0], rear) and aligned and kmh < 1.0:
				hold += delta
				msg = "ثبّت..."
				if hold > 1.2:
					_finish(true, "")
					return
			else:
				hold = 0.0
				msg = "ارجع المقطورة ريوس لحد الرصيف (ذيلها بين الخطوط الصفرة)"
				if _in_zone(zones[0], rear) and not aligned:
					msg = "المقطورة مايلة — امشِ شوية قدام وعدّلها"
		"offroad":
			if stage == 0:
				msg = "اصعد التل ووكّف داخل الدائرة على القمة"
				if Vector2(cp.x - center_top.x, cp.z - center_top.z).length() < 7.0 and kmh < 1.5:
					hold += delta
					if hold > 1.0:
						stage = 1
						hold = 0.0
						world.audio.play("pickup")
						world.hud.toast("وصلت القمة! هسة انزل بهدوء", Color(0.6, 1, 0.7), 3.0)
				else:
					hold = 0.0
			else:
				msg = "انزل ووكّف بالمربع الأخضر"
				var pts4 := _car_points()
				if _in_zone(zones[0], pts4[0]) and _in_zone(zones[0], pts4[1]) and kmh < 1.0:
					hold += delta
					if hold > 1.2:
						_finish(true, "")
						return
				else:
					hold = 0.0
	prev_car_z = cp.z
	world.prompt_override = msg


func _finish(ok: bool, reason: String) -> void:
	done = true
	world.lesson_finished(ok, reason, knocked)
