class_name CarModel
extends RefCounted
## يبني شكل كل سيارة من قطع بسيطة (Low-poly)

static var _mats := {}


static func mat(kind: String, col: Color = Color.WHITE) -> StandardMaterial3D:
	var key := kind + col.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match kind:
		"paint":
			m.albedo_color = col
			m.metallic = 0.35
			m.roughness = 0.32
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
		"glass":
			m.albedo_color = Color(0.08, 0.11, 0.15)
			m.metallic = 0.7
			m.roughness = 0.08
		"black":
			m.albedo_color = Color(0.06, 0.06, 0.065)
			m.roughness = 0.7
		"chrome":
			m.albedo_color = Color(0.8, 0.8, 0.82)
			m.metallic = 1.0
			m.roughness = 0.2
		"tire":
			m.albedo_color = Color(0.05, 0.05, 0.05)
			m.roughness = 0.95
		"rim":
			m.albedo_color = Color(0.55, 0.56, 0.58)
			m.metallic = 0.8
			m.roughness = 0.35
		"head":
			m.albedo_color = Color(1, 0.97, 0.85)
			m.emission_enabled = true
			m.emission = Color(1, 0.95, 0.8)
			m.emission_energy_multiplier = 1.5
		"tail":
			m.albedo_color = Color(0.6, 0.02, 0.02)
			m.emission_enabled = true
			m.emission = Color(1, 0.05, 0.03)
			m.emission_energy_multiplier = 0.8
		"plain":
			m.albedo_color = col
			m.roughness = 0.8
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _wheel(r: float, w: float) -> Dictionary:
	var pivot := Node3D.new()
	var spin := Node3D.new()
	pivot.add_child(spin)
	_cyl(spin, r, w, Vector3.ZERO, mat("tire"), Vector3(0, 0, PI / 2), 16)
	_cyl(spin, r * 0.62, w + 0.02, Vector3.ZERO, mat("rim"), Vector3(0, 0, PI / 2), 8)
	_box(spin, Vector3(w + 0.04, r * 1.1, 0.08), Vector3.ZERO, mat("black"))
	return {"pivot": pivot, "spin": spin}


## يرجع: root, wheels(pivot/spin), wheel_pos, radius, rest, box_size, box_center, com_y, head_pos, tail_mat
static func build(body: String, paint: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Model"
	var P := mat("paint", paint)
	var G := mat("glass")
	var B := mat("black")
	var C := mat("chrome")
	var H := mat("head")
	var T: StandardMaterial3D = mat("tail").duplicate()
	var r := 0.42
	var wx := 0.9
	var wzf := -1.45
	var wzr := 1.35
	var rest := 0.45
	var box := Vector3(1.9, 1.0, 4.6)
	var box_c := Vector3(0, 1.05, 0)
	var com := 0.55
	var head := [Vector3(-0.65, 1.0, -2.36), Vector3(0.65, 1.0, -2.36)]
	match body:
		"pickup":
			_box(root, Vector3(1.9, 0.55, 4.7), Vector3(0, 0.88, 0), P)
			_box(root, Vector3(1.76, 0.62, 1.9), Vector3(0, 1.45, -0.35), G)
			_box(root, Vector3(1.8, 0.08, 1.75), Vector3(0, 1.79, -0.32), P)
			_box(root, Vector3(1.82, 0.62, 0.12), Vector3(0, 1.45, 0.62), P)
			_box(root, Vector3(0.1, 0.35, 1.8), Vector3(0.9, 1.33, 1.4), P)
			_box(root, Vector3(0.1, 0.35, 1.8), Vector3(-0.9, 1.33, 1.4), P)
			_box(root, Vector3(1.9, 0.35, 0.1), Vector3(0, 1.33, 2.3), P)
			_box(root, Vector3(1.7, 0.06, 1.8), Vector3(0, 1.17, 1.4), B)
			_box(root, Vector3(2.0, 0.25, 0.16), Vector3(0, 0.68, -2.38), B)
			_box(root, Vector3(1.4, 0.32, 0.05), Vector3(0, 0.98, -2.36), B)
			_box(root, Vector3(2.0, 0.22, 0.16), Vector3(0, 0.7, 2.38), B)
			_box(root, Vector3(1.5, 0.08, 0.12), Vector3(0, 1.86, -0.9), B)
			for x in [-0.7, -0.35, 0.0, 0.35, 0.7]:
				_box(root, Vector3(0.18, 0.08, 0.06), Vector3(x, 1.86, -0.97), H)
			_box(root, Vector3(0.36, 0.12, 0.05), Vector3(-0.65, 1.0, -2.37), H)
			_box(root, Vector3(0.36, 0.12, 0.05), Vector3(0.65, 1.0, -2.37), H)
			_box(root, Vector3(0.2, 0.25, 0.05), Vector3(-0.82, 1.15, 2.37), T)
			_box(root, Vector3(0.2, 0.25, 0.05), Vector3(0.82, 1.15, 2.37), T)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.12, 0.08, 1.4), Vector3(0.98 * s, 0.62, -0.1), B)
				_box(root, Vector3(0.05, 0.16, 0.12), Vector3(0.93 * s, 1.55, -1.25), B)
		"buggy":
			r = 0.5
			wx = 0.95
			wzf = -1.25
			wzr = 1.2
			rest = 0.5
			box = Vector3(1.5, 0.9, 3.3)
			box_c = Vector3(0, 1.05, 0)
			com = 0.6
			_box(root, Vector3(1.4, 0.18, 3.0), Vector3(0, 0.72, 0), B)
			_box(root, Vector3(1.5, 0.35, 1.1), Vector3(0, 0.9, -1.4), P, Vector3(-0.25, 0, 0))
			_box(root, Vector3(1.3, 0.5, 0.9), Vector3(0, 1.05, 1.25), P)
			_box(root, Vector3(0.5, 0.6, 0.5), Vector3(-0.32, 1.1, 0.1), B)
			_box(root, Vector3(0.5, 0.6, 0.5), Vector3(0.32, 1.1, 0.1), B)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.07, 1.1, 0.07), Vector3(0.65 * s, 1.35, -0.5), C, Vector3(0.35, 0, 0))
				_box(root, Vector3(0.07, 1.0, 0.07), Vector3(0.65 * s, 1.35, 0.7), C)
				_box(root, Vector3(0.07, 0.07, 1.3), Vector3(0.65 * s, 1.85, 0.08), C)
				_box(root, Vector3(0.6, 0.08, 0.6), Vector3(1.0 * s, 1.0, -1.25), P)
				_box(root, Vector3(0.6, 0.08, 0.7), Vector3(1.0 * s, 1.08, 1.2), P)
			_box(root, Vector3(1.37, 0.07, 0.07), Vector3(0, 1.85, -0.55), C)
			_box(root, Vector3(1.37, 0.07, 0.07), Vector3(0, 1.85, 0.72), C)
			_box(root, Vector3(1.0, 0.1, 0.08), Vector3(0, 1.9, -0.6), B)
			for x in [-0.3, 0.0, 0.3]:
				_box(root, Vector3(0.2, 0.1, 0.05), Vector3(x, 1.9, -0.65), H)
			head = [Vector3(-0.3, 1.9, -0.7), Vector3(0.3, 1.9, -0.7)]
			_box(root, Vector3(0.2, 0.15, 0.05), Vector3(-0.5, 1.1, 1.71), T)
			_box(root, Vector3(0.2, 0.15, 0.05), Vector3(0.5, 1.1, 1.71), T)
		"sedan", "rally":
			r = 0.37 if body == "sedan" else 0.39
			wx = 0.85
			wzf = -1.45
			wzr = 1.4
			rest = 0.35 if body == "sedan" else 0.42
			box = Vector3(1.85, 0.85, 4.5)
			box_c = Vector3(0, 0.88, 0)
			com = 0.45
			var y0 := 0.0 if body == "sedan" else 0.05
			_box(root, Vector3(1.85, 0.5, 4.5), Vector3(0, 0.68 + y0, 0), P)
			_box(root, Vector3(1.6, 0.46, 2.2), Vector3(0, 1.15 + y0, 0.15), G)
			_box(root, Vector3(1.58, 0.06, 1.6), Vector3(0, 1.4 + y0, 0.2), P)
			_box(root, Vector3(1.85, 0.08, 1.3), Vector3(0, 0.95 + y0, -1.55), P, Vector3(0.06, 0, 0))
			_box(root, Vector3(1.95, 0.2, 0.14), Vector3(0, 0.52 + y0, -2.27), B)
			_box(root, Vector3(1.95, 0.2, 0.14), Vector3(0, 0.52 + y0, 2.27), B)
			_box(root, Vector3(0.4, 0.1, 0.05), Vector3(-0.6, 0.8 + y0, -2.26), H)
			_box(root, Vector3(0.4, 0.1, 0.05), Vector3(0.6, 0.8 + y0, -2.26), H)
			_box(root, Vector3(0.45, 0.12, 0.05), Vector3(-0.6, 0.82 + y0, 2.26), T)
			_box(root, Vector3(0.45, 0.12, 0.05), Vector3(0.6, 0.82 + y0, 2.26), T)
			head = [Vector3(-0.6, 0.8 + y0, -2.3), Vector3(0.6, 0.8 + y0, -2.3)]
			if body == "rally":
				var W := mat("plain", Color(0.95, 0.95, 0.95))
				_box(root, Vector3(0.35, 0.02, 4.52), Vector3(0, 0.94 + y0, 0), W)
				_box(root, Vector3(0.35, 0.02, 1.62), Vector3(0, 1.44 + y0, 0.2), W)
				_box(root, Vector3(1.7, 0.06, 0.4), Vector3(0, 1.32 + y0, 2.15), P)
				_box(root, Vector3(0.06, 0.3, 0.2), Vector3(-0.7, 1.15 + y0, 2.15), B)
				_box(root, Vector3(0.06, 0.3, 0.2), Vector3(0.7, 1.15 + y0, 2.15), B)
				_box(root, Vector3(0.5, 0.12, 0.6), Vector3(0, 1.48 + y0, 0.0), B)
				for s in [-1.0, 1.0]:
					_box(root, Vector3(0.1, 0.35, 0.9), Vector3(0.93 * s, 0.85 + y0, -1.45), P)
					_box(root, Vector3(0.1, 0.35, 0.9), Vector3(0.93 * s, 0.85 + y0, 1.4), P)
				for x in [-0.45, -0.15, 0.15, 0.45]:
					_box(root, Vector3(0.22, 0.22, 0.06), Vector3(x, 0.78 + y0, -2.32), H)
		"jeep":
			r = 0.46
			wx = 0.9
			wzf = -1.35
			wzr = 1.3
			rest = 0.5
			box = Vector3(1.9, 1.3, 4.1)
			box_c = Vector3(0, 1.3, 0)
			com = 0.65
			_box(root, Vector3(1.85, 0.7, 4.1), Vector3(0, 1.0, 0), P)
			_box(root, Vector3(1.8, 0.8, 2.5), Vector3(0, 1.75, 0.35), G)
			_box(root, Vector3(1.82, 0.1, 2.55), Vector3(0, 2.18, 0.35), P)
			_box(root, Vector3(1.83, 0.8, 0.12), Vector3(0, 1.75, 1.55), P)
			_box(root, Vector3(1.6, 0.12, 2.0), Vector3(0, 2.3, 0.4), B)
			_box(root, Vector3(2.05, 0.3, 0.2), Vector3(0, 0.75, -2.1), B)
			_box(root, Vector3(1.5, 0.45, 0.06), Vector3(0, 1.05, -2.06), B)
			_cyl(root, 0.15, 0.06, Vector3(-0.68, 1.1, -2.07), H, Vector3(PI / 2, 0, 0))
			_cyl(root, 0.15, 0.06, Vector3(0.68, 1.1, -2.07), H, Vector3(PI / 2, 0, 0))
			head = [Vector3(-0.68, 1.1, -2.1), Vector3(0.68, 1.1, -2.1)]
			_cyl(root, 0.44, 0.28, Vector3(0, 1.4, 2.22), mat("tire"), Vector3(PI / 2, 0, 0), 14)
			_box(root, Vector3(0.18, 0.3, 0.05), Vector3(-0.8, 1.15, 2.07), T)
			_box(root, Vector3(0.18, 0.3, 0.05), Vector3(0.8, 1.15, 2.07), T)
			_box(root, Vector3(0.1, 1.2, 0.1), Vector3(0.98, 1.7, -1.05), B)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.25, 0.08, 0.95), Vector3(1.0 * s, 1.36, -1.35), B)
				_box(root, Vector3(0.25, 0.08, 0.95), Vector3(1.0 * s, 1.36, 1.3), B)
		"truck":
			r = 0.56
			wx = 1.05
			wzf = -2.3
			wzr = 2.0
			rest = 0.5
			box = Vector3(2.4, 2.5, 6.4)
			box_c = Vector3(0, 2.05, 0)
			com = 0.9
			_box(root, Vector3(2.0, 0.4, 6.4), Vector3(0, 1.0, 0), B)
			_box(root, Vector3(2.3, 1.5, 1.8), Vector3(0, 1.95, -2.25), P)
			_box(root, Vector3(2.2, 0.7, 0.08), Vector3(0, 2.25, -3.16), G)
			_box(root, Vector3(2.32, 0.5, 1.82), Vector3(0, 2.25, -2.25), G)
			_box(root, Vector3(2.34, 0.12, 1.86), Vector3(0, 2.75, -2.25), P)
			_box(root, Vector3(2.45, 2.2, 4.1), Vector3(0, 2.35, 1.05), mat("plain", Color(0.92, 0.92, 0.9)))
			_box(root, Vector3(2.47, 0.25, 4.12), Vector3(0, 1.55, 1.05), P)
			_box(root, Vector3(2.4, 0.35, 0.2), Vector3(0, 1.05, -3.2), C)
			_box(root, Vector3(0.4, 0.18, 0.05), Vector3(-0.8, 1.45, -3.17), H)
			_box(root, Vector3(0.4, 0.18, 0.05), Vector3(0.8, 1.45, -3.17), H)
			head = [Vector3(-0.8, 1.45, -3.2), Vector3(0.8, 1.45, -3.2)]
			_box(root, Vector3(0.25, 0.3, 0.05), Vector3(-1.0, 1.4, 3.12), T)
			_box(root, Vector3(0.25, 0.3, 0.05), Vector3(1.0, 1.4, 3.12), T)
			_cyl(root, 0.08, 1.6, Vector3(1.15, 2.9, -1.4), C)
		"monster":
			r = 0.95
			wx = 1.3
			wzf = -1.55
			wzr = 1.5
			rest = 0.7
			box = Vector3(2.0, 1.2, 4.4)
			box_c = Vector3(0, 2.25, 0)
			com = 1.3
			var y := 1.05
			_box(root, Vector3(1.4, 0.3, 3.6), Vector3(0, 1.1, 0), B)
			_box(root, Vector3(0.15, 0.15, 3.2), Vector3(0, 0.95, 0), C)
			_box(root, Vector3(1.95, 0.55, 4.4), Vector3(0, 0.95 + y, 0), P)
			_box(root, Vector3(1.75, 0.6, 1.8), Vector3(0, 1.5 + y, -0.25), G)
			_box(root, Vector3(1.78, 0.08, 1.65), Vector3(0, 1.83 + y, -0.2), P)
			_box(root, Vector3(0.1, 0.32, 1.7), Vector3(0.93, 1.38 + y, 1.3), P)
			_box(root, Vector3(0.1, 0.32, 1.7), Vector3(-0.93, 1.38 + y, 1.3), P)
			_box(root, Vector3(0.36, 0.12, 0.05), Vector3(-0.62, 1.05 + y, -2.22), H)
			_box(root, Vector3(0.36, 0.12, 0.05), Vector3(0.62, 1.05 + y, -2.22), H)
			head = [Vector3(-0.62, 1.05 + y, -2.25), Vector3(0.62, 1.05 + y, -2.25)]
			_box(root, Vector3(0.2, 0.25, 0.05), Vector3(-0.8, 1.15 + y, 2.22), T)
			_box(root, Vector3(0.2, 0.25, 0.05), Vector3(0.8, 1.15 + y, 2.22), T)
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.12, 0.9, 0.12), Vector3(0.75 * s, 1.5, -1.55), C, Vector3(0, 0, 0.5 * s))
				_box(root, Vector3(0.12, 0.9, 0.12), Vector3(0.75 * s, 1.5, 1.5), C, Vector3(0, 0, 0.5 * s))
	# العجلات
	var wheels := []
	var wpos := [Vector3(-wx, r, wzf), Vector3(wx, r, wzf), Vector3(-wx, r, wzr), Vector3(wx, r, wzr)]
	var ww := 0.34 if body != "monster" else 0.75
	if body == "buggy":
		ww = 0.42
	for i in 4:
		var wh := _wheel(r, ww)
		wh["pivot"].position = wpos[i]
		root.add_child(wh["pivot"])
		wheels.append(wh)
	# نتأكد إن جسم التصادم أعلى من الأرض
	var bottom := box_c.y - box.y * 0.5
	if bottom < 0.32:
		box_c.y += 0.32 - bottom
	return {"root": root, "wheels": wheels, "wheel_pos": wpos, "radius": r, "rest": rest,
		"box_size": box, "box_center": box_c, "com_y": com, "head_pos": head, "tail_mat": T}
