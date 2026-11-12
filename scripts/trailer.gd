class_name TruckTrailer
extends Node3D
## مقطورة بحركة "كينماتيك" مثل المقطورات الحقيقية: تنسحب من نقطة الربط وتلف أوسع من الشاحنة (off-tracking)
## الأنواع: box صندوق • reefer مبرّدة • flat مسطحة • tank تانكر • pipes طويلة • water_small عربانة ماي • car سيارة مسحوبة

signal hit_prop(body: Node, shape_idx: int, speed: float)

var kind := "box"
var L := 9.0                 # من نقطة الربط لمركز المحاور
var hitch_y := 1.3           # ارتفاع نقطة الربط عن الأرض
var rear_z := 2.4            # نهاية المقطورة
var rear_hitch := Vector3(0, 0.9, 3.0)  # نقطة ربط المقطورة الثانية (بالإحداثيات المحلية)
var wheel_r := 0.5
var body_w := 2.5
var body_len := 12.0
var front_z := -9.6
var axle2 := Vector2.ZERO    # مركز المحاور (x, z) بالعالم
var ground_y := 0.0
var spin := 0.0
var wheel_nodes: Array = []
var tail_mat: StandardMaterial3D
var slosh_node: Node3D
var body: AnimatableBody3D
var area: Area3D
var cargo_root: Node3D
var speed := 0.0
var last_pos := Vector3.ZERO
var mass_empty := 6000.0
var is_second := false
var cargo_visible := true


static func spec(kind_id: String, second: bool, double: bool) -> Dictionary:
	# أبعاد كل نوع
	if kind_id == "water_small":
		return {"L": 3.4, "hy": 0.72, "front": -2.8, "rear": 0.9, "w": 1.7, "r": 0.38, "axles": [0.0], "mass": 500.0}
	if kind_id == "car":
		return {"L": 6.6, "hy": 0.75, "front": -4.6, "rear": 0.9, "w": 1.9, "r": 0.4, "axles": [], "mass": 1300.0}
	if double:
		if second:
			return {"L": 8.6, "hy": 0.95, "front": -6.3, "rear": 1.6, "w": 2.5, "r": 0.5, "axles": [-0.65, 0.65], "dolly": -5.4, "mass": 4200.0}
		return {"L": 6.2, "hy": 1.3, "front": -6.9, "rear": 1.7, "w": 2.5, "r": 0.5, "axles": [-0.65, 0.65], "mass": 4200.0}
	if kind_id == "pipes":
		return {"L": 11.2, "hy": 1.3, "front": -11.8, "rear": 3.4, "w": 2.5, "r": 0.5, "axles": [-1.3, 0.0, 1.3], "mass": 6500.0}
	if kind_id == "tank":
		return {"L": 8.4, "hy": 1.3, "front": -9.0, "rear": 2.0, "w": 2.5, "r": 0.5, "axles": [-1.3, 0.0, 1.3], "mass": 6000.0}
	return {"L": 9.0, "hy": 1.3, "front": -9.6, "rear": 2.4, "w": 2.5, "r": 0.5, "axles": [-1.3, 0.0, 1.3], "mass": 6500.0}


func setup(kind_id: String, cargo_col: Color, paint: Color, second := false, double := false, opts := {}) -> void:
	kind = kind_id
	is_second = second
	var sp := spec(kind_id, second, double)
	L = sp["L"]
	hitch_y = sp["hy"]
	front_z = sp["front"]
	rear_z = sp["rear"]
	body_w = sp["w"]
	wheel_r = sp["r"]
	mass_empty = sp["mass"]
	body_len = rear_z - front_z
	rear_hitch = Vector3(0, 0.95, rear_z + 0.45)
	var P := CarModel.paint_mat(paint)
	(P as ShaderMaterial).set_shader_parameter("dust", 0.15)
	var B := CarModel.mat("black")
	var C := CarModel.mat("chrome")
	tail_mat = CarModel.mat("tail").duplicate()
	cargo_root = Node3D.new()
	add_child(cargo_root)
	var deck_y := 1.35
	if kind == "water_small":
		deck_y = 0.7
	# الشاصي والمحاور
	if kind != "car":
		CarModel._box(self, Vector3(1.0, 0.25, body_len - 0.3), Vector3(0, deck_y - 0.2, (front_z + rear_z) * 0.5), B)
		for az in sp["axles"]:
			_axle(float(az), B, C)
		if sp.has("dolly"):
			_axle(float(sp["dolly"]), B, C)
			CarModel._box(self, Vector3(1.6, 0.2, 1.4), Vector3(0, deck_y - 0.35, float(sp["dolly"])), B)
		# ذراع الربط للمقطورة الثانية / عربانة
		if second or kind == "water_small":
			var drawbar_len := absf(-L - front_z)
			CarModel._box(self, Vector3(0.14, 0.14, drawbar_len + 0.4), Vector3(0, hitch_y, -L + drawbar_len * 0.5 - 0.1), B)
		for s in [-1.0, 1.0]:
			CarModel._box(self, Vector3(0.2, 0.3, 0.06), Vector3((body_w * 0.5 - 0.15) * s, deck_y - 0.05, rear_z + 0.02), tail_mat)
			if kind != "water_small":
				CarModel._box(self, Vector3(0.5, 0.06, 1.0 if sp["axles"].size() < 3 else 3.6), Vector3((body_w * 0.5 - 0.25) * s, deck_y - 0.02, (float(sp["axles"][0]) + float(sp["axles"][sp["axles"].size() - 1])) * 0.5), B)
	match kind:
		"box", "reefer":
			var h := 2.7 if not double else 2.5
			var col := paint if kind == "box" else Color(0.95, 0.95, 0.96)
			var BM := CarModel.paint_mat(col)
			(BM as ShaderMaterial).set_shader_parameter("dust", 0.18)
			CarModel._box(self, Vector3(body_w, h, body_len), Vector3(0, deck_y + h * 0.5, (front_z + rear_z) * 0.5), BM)
			# خطوط ولوحة جانبية
			for s in [-1.0, 1.0]:
				CarModel._box(self, Vector3(0.03, 0.18, body_len - 0.6), Vector3(body_w * 0.5 * s + 0.01 * s, deck_y + 0.35, (front_z + rear_z) * 0.5), CarModel.mat("plain", cargo_col.darkened(0.2)))
				var lb := Label3D.new()
				lb.text = opts.get("label", "نقليات الرافدين")
				lb.font_size = 120
				lb.pixel_size = 0.009
				lb.modulate = cargo_col.darkened(0.35) if kind == "reefer" else Color(1, 0.95, 0.85)
				lb.outline_size = 14
				lb.outline_modulate = Color(0, 0, 0, 0.5)
				lb.position = Vector3((body_w * 0.5 + 0.02) * s, deck_y + h * 0.6, (front_z + rear_z) * 0.5)
				lb.rotation.y = PI / 2.0 * s
				add_child(lb)
			CarModel._box(self, Vector3(body_w - 0.1, h - 0.1, 0.05), Vector3(0, deck_y + h * 0.5, rear_z + 0.01), CarModel.mat("plain", Color(0.5, 0.5, 0.52)))
			CarModel._box(self, Vector3(0.05, h - 0.2, 0.06), Vector3(0, deck_y + h * 0.5, rear_z + 0.04), B)
			if kind == "reefer":
				CarModel._box(self, Vector3(1.9, 1.4, 0.5), Vector3(0, deck_y + h - 0.8, front_z - 0.25), CarModel.mat("plain", Color(0.75, 0.77, 0.8)))
			if opts.has("slogan"):
				var sl := Label3D.new()
				sl.text = opts["slogan"]
				sl.font_size = 90
				sl.pixel_size = 0.008
				sl.modulate = Color(0.1, 0.1, 0.1)
				sl.outline_size = 8
				sl.outline_modulate = Color(1, 1, 1, 0.8)
				sl.position = Vector3(0, deck_y + h * 0.55, rear_z + 0.09)
				add_child(sl)
		"flat", "pipes":
			CarModel._box(self, Vector3(body_w, 0.18, body_len), Vector3(0, deck_y, (front_z + rear_z) * 0.5), CarModel.mat("plain", Color(0.35, 0.3, 0.25)))
			for s in [-1.0, 1.0]:
				var z := front_z + 0.6
				while z < rear_z:
					CarModel._box(self, Vector3(0.08, 0.6, 0.08), Vector3((body_w * 0.5 - 0.05) * s, deck_y + 0.35, z), B)
					z += 1.6
			_flat_cargo(deck_y + 0.1, cargo_col, opts)
		"tank":
			var tm: Material = CarModel.mat("chrome") if opts.get("chrome_tank", true) else CarModel.paint_mat(paint)
			slosh_node = Node3D.new()
			slosh_node.position = Vector3(0, deck_y + 1.15, (front_z + rear_z) * 0.5)
			add_child(slosh_node)
			var tank := CarModel._cyl(slosh_node, 1.15, body_len - 0.4, Vector3.ZERO, tm, Vector3(PI / 2, 0, 0), 28)
			tank.scale = Vector3(1.08, 1.0, 0.92)
			for z2 in [-body_len * 0.33, 0.0, body_len * 0.33]:
				CarModel._cyl(slosh_node, 1.19, 0.12, Vector3(0, 0, z2), B, Vector3(PI / 2, 0, 0), 28)
			CarModel._box(slosh_node, Vector3(0.6, 0.2, body_len * 0.7), Vector3(0, 1.15, 0), B)
			var stripe := CarModel.mat("plain", cargo_col)
			for s in [-1.0, 1.0]:
				CarModel._box(slosh_node, Vector3(0.03, 0.3, body_len * 0.6), Vector3(1.24 * s, 0.0, 0), stripe)
		"water_small":
			slosh_node = Node3D.new()
			slosh_node.position = Vector3(0, deck_y + 0.62, (front_z + rear_z) * 0.5)
			add_child(slosh_node)
			CarModel._cyl(slosh_node, 0.62, body_len - 0.2, Vector3.ZERO, CarModel.paint_mat(Color(0.2, 0.45, 0.8)), Vector3(PI / 2, 0, 0), 20)
			CarModel._cyl(slosh_node, 0.18, 0.2, Vector3(0, 0.66, 0), B)
		"car":
			_towed_car(opts)
	# التصادم: جسم يتحرك ويدفع الأنقاض، ومنطقة تكشف الأشياء اللي تضربها المقطورة
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var bh := 2.9 if kind in ["box", "reefer", "tank"] else 1.4
	if kind == "car":
		bh = 1.3
	if kind == "water_small":
		bh = 1.2
	bs.size = Vector3(body_w, bh, body_len)
	cs.shape = bs
	cs.position = Vector3(0, deck_y - 0.2 + bh * 0.5, (front_z + rear_z) * 0.5)
	body.add_child(cs)
	area = Area3D.new()
	area.monitorable = false
	add_child(area)
	var acs := CollisionShape3D.new()
	var abs2 := BoxShape3D.new()
	abs2.size = bs.size + Vector3(0.3, 0.0, 0.2)
	acs.shape = abs2
	acs.position = cs.position + Vector3(0, 0.15, 0)
	area.add_child(acs)
	area.body_shape_entered.connect(_on_area_hit)


func _axle(z: float, B: Material, C: Material) -> void:
	for s in [-1.0, 1.0]:
		var w := CarModel._wheel(wheel_r, 0.42 if kind != "water_small" else 0.28)
		var pv: Node3D = w["pivot"]
		pv.position = Vector3((body_w * 0.5 - 0.3) * s, wheel_r, z)
		add_child(pv)
		wheel_nodes.append(w["spin"])
	CarModel._cyl(self, 0.07, body_w - 0.5, Vector3(0, wheel_r, z), B, Vector3(0, 0, PI / 2), 8)


func _flat_cargo(y: float, col: Color, opts: Dictionary) -> void:
	var cargo_id: String = opts.get("cargo", "")
	var z0 := front_z + 0.5
	var z1 := rear_z - 0.3
	match cargo_id:
		"pipes", "poles":
			var pm := CarModel.mat("plain", col)
			var r := 0.28 if cargo_id == "pipes" else 0.2
			var rows := [[-0.85, 0], [-0.28, 0], [0.28, 0], [0.85, 0], [-0.56, 1], [0.0, 1], [0.56, 1], [-0.28, 2], [0.28, 2]]
			var ln := body_len + 1.6
			for rw in rows:
				CarModel._cyl(cargo_root, r, ln, Vector3(float(rw[0]), y + r + float(rw[1]) * r * 1.75, (front_z + rear_z) * 0.5 + 0.8), pm, Vector3(PI / 2, 0, 0), 12)
			var flag := CarModel.mat("plain", Color(0.95, 0.15, 0.1))
			CarModel._box(cargo_root, Vector3(0.4, 0.4, 0.02), Vector3(0, y + 0.6, rear_z + 1.62), flag)
			for z in [z0 + 1.5, (z0 + z1) * 0.5, z1 - 1.5]:
				CarModel._box(cargo_root, Vector3(2.52, 0.05, 0.08), Vector3(0, y + r * 4.5, z), CarModel.mat("plain", Color(0.9, 0.6, 0.1)))
		"steel":
			var sm := CarModel.mat("plain", Color(0.38, 0.27, 0.2))
			for x in [-0.7, 0.0, 0.7]:
				CarModel._box(cargo_root, Vector3(0.6, 0.45, body_len - 0.6), Vector3(x, y + 0.25, (z0 + z1) * 0.5), sm)
		_:
			var cm := CarModel.mat("plain", col)
			var pal := CarModel.mat("plain", Color(0.55, 0.42, 0.28))
			var z := z0 + 0.7
			while z < z1 - 0.6:
				CarModel._box(cargo_root, Vector3(2.2, 0.12, 1.1), Vector3(0, y + 0.06, z), pal)
				CarModel._box(cargo_root, Vector3(2.1, 0.95, 1.05), Vector3(0, y + 0.6, z), cm)
				z += 1.25


func _towed_car(opts: Dictionary) -> void:
	var m := CarModel.build(opts.get("body", "pickup"), opts.get("paint", Color(0.55, 0.5, 0.45)))
	var r: Node3D = m["root"]
	# السيارة المسحوبة: الوجه يم الساحبة، المحور الخلفي على مركز المقطورة
	r.position = Vector3(0, 0, -1.4)
	add_child(r)
	var pm = m.get("paint_mat")
	if pm is ShaderMaterial:
		(pm as ShaderMaterial).set_shader_parameter("dust", 0.75)
	for w in m["wheels"]:
		wheel_nodes.append(w["spin"])
	tail_mat = m["tail_mat"]
	var rope := CarModel.mat("plain", Color(0.9, 0.75, 0.2))
	CarModel._box(self, Vector3(0.06, 0.06, 2.2), Vector3(0, 0.75, -L + 1.1), rope)


## يحط المقطورة مستقيمة ورا نقطة الربط
func place(hitch: Vector3, forward: Vector3, world: Node) -> void:
	var f := Vector2(forward.x, forward.z).normalized()
	axle2 = Vector2(hitch.x, hitch.z) - f * L
	_apply(hitch, world, 0.0)
	last_pos = global_position


## كل فريم فيزياء: نسحب المحاور باتجاه نقطة الربط
func step(hitch: Vector3, world: Node, delta: float) -> void:
	var h2 := Vector2(hitch.x, hitch.z)
	var d := h2 - axle2
	if d.length() > 0.001:
		axle2 = h2 - d.normalized() * L
	_apply(hitch, world, delta)


func _apply(hitch: Vector3, world: Node, delta: float) -> void:
	ground_y = world.ground_h(axle2.x, axle2.y)
	var n: Vector3 = world.normal_at(axle2.x, axle2.y)
	if n.y < 0.5:
		n = Vector3.UP
	var origin := Vector3(axle2.x, ground_y, axle2.y)
	var fw := (hitch - (origin + n * hitch_y))
	if fw.length() < 0.01:
		fw = -global_basis.z
	fw = fw.normalized()
	var right := fw.cross(n).normalized()
	var up := right.cross(fw).normalized()
	global_transform = Transform3D(Basis(right, up, -fw), origin)
	if delta > 0.0:
		var moved := global_position - last_pos
		speed = moved.dot(fw) / delta
		spin += moved.dot(fw) / wheel_r
		for w in wheel_nodes:
			(w as Node3D).rotation.x = -spin
		last_pos = global_position
	if body:
		body.global_transform = global_transform


func rear_hitch_world() -> Vector3:
	return global_transform * rear_hitch


func forward() -> Vector3:
	return -global_basis.z


func set_brake_light(on: bool, lights: bool) -> void:
	if tail_mat:
		tail_mat.emission_energy_multiplier = 4.0 if on else (1.5 if lights else 0.6)


func set_slosh(v: float) -> void:
	if slosh_node:
		slosh_node.rotation.z = clampf(v, -1.0, 1.0) * 0.06


func set_cargo_visible(on: bool) -> void:
	cargo_visible = on
	if cargo_root:
		cargo_root.visible = on


func _on_area_hit(_rid: RID, b: Node, shape_idx: int, _local: int) -> void:
	if b == null or b is RigidBody3D or b is AnimatableBody3D:
		return
	hit_prop.emit(b, shape_idx, absf(speed))
