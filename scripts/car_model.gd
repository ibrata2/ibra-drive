class_name CarModel
extends RefCounted
## يبني شكل كل سيارة بأجسام انسيابية (loft) مو مربعات

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
	if kind in ["paint", "glass", "black", "plain"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
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


## جسم انسيابي: كل محطة = [z, نص العرض تحت, نص العرض فوك, y تحت, y فوك]
## power = 2 دائري، 4 مدوّر، 8 أقرب للمربع
static func _loft(parent: Node3D, stations: Array, m: Material, power := 4.0, seg := 28, yoff := 0.0, roof_y := -1.0) -> MeshInstance3D:
	var rings: Array = []
	var centers: Array = []
	var masks: Array = []
	for s in stations:
		var z: float = s[0]
		var hb: float = s[1]
		var ht: float = s[2]
		var yb: float = s[3] + yoff
		var yt: float = s[4] + yoff
		var cy := (yb + yt) * 0.5
		var hh := maxf((yt - yb) * 0.5, 0.004)
		var ring := PackedVector3Array()
		var glass_ring: bool = s.size() > 5 and float(s[5]) > 0.5
		var mk := PackedFloat32Array()
		for i in seg:
			var th := TAU * i / seg
			var c := cos(th)
			var sn := sin(th)
			var ex := signf(c) * pow(absf(c), 2.0 / power)
			var ey := signf(sn) * pow(absf(sn), 2.0 / power)
			var hw := lerpf(hb, ht, (ey + 1.0) * 0.5)
			var py := cy + ey * hh
			ring.append(Vector3(ex * hw, py, z))
			# زجاج: بين خط الحزام وخط السقف
			mk.append(0.0 if (glass_ring and roof_y > 0.0 and py > yb + 0.05 and py < roof_y + yoff - 0.07) else 1.0)
		rings.append(ring)
		masks.append(mk)
		centers.append(Vector3(0, cy, z))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var nr := rings.size()
	for k in nr:
		var ring: PackedVector3Array = rings[k]
		var prev: PackedVector3Array = rings[maxi(k - 1, 0)]
		var next: PackedVector3Array = rings[mini(k + 1, nr - 1)]
		for i in seg:
			var p := ring[i]
			var around := ring[(i + 1) % seg] - ring[(i - 1 + seg) % seg]
			var along := next[i] - prev[i]
			var n := around.cross(along)
			if n.length() < 0.000001:
				n = p - (centers[k] as Vector3)
			n = n.normalized()
			if n.dot(p - (centers[k] as Vector3)) < 0.0:
				n = -n
			verts.append(p)
			norms.append(n)
			var mv: float = (masks[k] as PackedFloat32Array)[i]
			cols.append(Color(mv, mv, mv))
	for k in nr - 1:
		for i in seg:
			var a := k * seg + i
			var b := k * seg + (i + 1) % seg
			var c2 := (k + 1) * seg + (i + 1) % seg
			var d := (k + 1) * seg + i
			_tri_idx(idx, verts, norms, a, b, c2)
			_tri_idx(idx, verts, norms, a, c2, d)
	for end in [0, nr - 1]:
		var ring2: PackedVector3Array = rings[end]
		var cn := Vector3(0, 0, -1) if end == 0 else Vector3(0, 0, 1)
		var base := verts.size()
		verts.append(centers[end])
		norms.append(cn)
		cols.append(Color.WHITE)
		for i in seg:
			verts.append(ring2[i])
			norms.append(cn)
			cols.append(Color.WHITE)
		for i in seg:
			_tri_idx(idx, verts, norms, base, base + 1 + i, base + 1 + (i + 1) % seg)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = m
	parent.add_child(mi)
	return mi


## Godot يعتبر الوجه الأمامي باتجاه عقارب الساعة؛ نرتب المثلث حسب النورمال
static func _tri_idx(idx: PackedInt32Array, verts: PackedVector3Array, norms: PackedVector3Array, a: int, b: int, c: int) -> void:
	var g := (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if g.dot(norms[a] + norms[b] + norms[c]) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


## سقف مصبوغ فوك الزجاج (من محطات الكابينة)
static func _roof_from(cabin: Array) -> Array:
	var out: Array = []
	for s in cabin:
		var h: float = s[4] - s[3]
		if h < 0.3:
			continue
		out.append([s[0], s[2] * 1.03, s[2] * 0.98, s[4] - 0.11, s[4] + 0.025])
	if out.size() >= 2:
		var f: Array = out[0].duplicate()
		f[0] -= 0.03
		f[3] = f[4] - 0.01
		var l: Array = out[out.size() - 1].duplicate()
		l[0] += 0.03
		l[3] = l[4] - 0.01
		out.push_front(f)
		out.push_back(l)
	return out


## شريط على سطح الجسم
static func _stripe_from(stations: Array, half_w: float) -> Array:
	var out: Array = []
	for s in stations:
		out.append([s[0], half_w, half_w * 0.9, s[4] - 0.04, s[4] + 0.012])
	return out


static func _scale_st(stations: Array, sx: float) -> Array:
	var out: Array = []
	for s in stations:
		out.append([s[0], s[1] * sx, s[2] * sx, s[3], s[4]])
	return out


static func _wheel(r: float, w: float) -> Dictionary:
	var pivot := Node3D.new()
	var spin := Node3D.new()
	pivot.add_child(spin)
	_cyl(spin, r * 0.93, w, Vector3.ZERO, mat("tire"), Vector3(0, 0, PI / 2), 20)
	_cyl(spin, r, w * 0.78, Vector3.ZERO, mat("tire"), Vector3(0, 0, PI / 2), 20)
	_cyl(spin, r * 0.6, w + 0.02, Vector3.ZERO, mat("rim"), Vector3(0, 0, PI / 2), 16)
	_cyl(spin, r * 0.16, w + 0.05, Vector3.ZERO, mat("chrome"), Vector3(0, 0, PI / 2), 8)
	for i in 5:
		var a := TAU * i / 5.0
		_box(spin, Vector3(w + 0.03, r * 0.42, 0.07), Vector3(0, cos(a) * r * 0.3, sin(a) * r * 0.3), mat("chrome"), Vector3(a, 0, 0))
	return {"pivot": pivot, "spin": spin}



## صبغ السيارة مع غبار يتراكم على الأجزاء السفلية (يتغير وانت تسوق)
static func paint_mat(col: Color) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _paint_shader()
	sm.set_shader_parameter("paint", col)
	sm.set_shader_parameter("dust_color", Color(0.78, 0.66, 0.48))
	sm.set_shader_parameter("dust", 0.12)
	return sm


static var _ps: Shader


static func _paint_shader() -> Shader:
	if _ps == null:
		_ps = Shader.new()
		_ps.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 paint : source_color = vec3(1.0);
uniform vec3 dust_color : source_color = vec3(0.78, 0.66, 0.48);
uniform float dust = 0.1;
varying vec3 lp;
varying vec3 ln;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	float low = 1.0 - smoothstep(0.25, 1.1, lp.y);
	float top = smoothstep(0.6, 1.0, ln.y) * 0.6;
	float nz = n2(lp.xz * 6.0 + lp.y * 3.0) * 0.6 + n2(lp.xz * 23.0) * 0.4;
	float d = clamp(dust * (0.35 + low * 1.2 + top) + (nz - 0.5) * dust * 0.8, 0.0, 0.95);
	float glass = 1.0 - smoothstep(0.42, 0.58, COLOR.r);
	d *= 1.0 - glass * 0.7;
	vec3 glass_c = vec3(0.02, 0.03, 0.045);
	ALBEDO = mix(mix(paint, dust_color, d), mix(glass_c, dust_color, d), glass);
	METALLIC = mix(mix(0.35, 0.0, d), 0.6, glass);
	ROUGHNESS = mix(mix(0.28, 0.95, d), mix(0.05, 0.8, d), glass);
	CLEARCOAT = (1.0 - d);
	CLEARCOAT_ROUGHNESS = 0.15;
}
"""
	return _ps


## مضلعات مستوية (كل وجه 4 نقاط) بنورمال للخارج
static func _faces(parent: Node3D, quads: Array, m: Material, center: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		var n := (b - a).cross(c - a)
		if n.length() < 0.000001:
			n = (c - a).cross(d - a)
		n = n.normalized()
		if n.dot((a + b + c + d) * 0.25 - center) < 0.0:
			n = -n
		var order := [a, b, c, a, c, d]
		if (b - a).cross(c - a).dot(n) > 0.0:
			order = [a, c, b, a, d, c]
		for v in order:
			st.set_normal(n)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	parent.add_child(mi)
	return mi


## نقطة داخل وجه رباعي (u على العرض، v على الارتفاع) مع دفعة للخارج
static func _qp(q: Array, u: float, v: float, out: Vector3) -> Vector3:
	var bottom: Vector3 = (q[0] as Vector3).lerp(q[1], u)
	var top: Vector3 = (q[3] as Vector3).lerp(q[2], u)
	return bottom.lerp(top, v) + out


static func _window(parent: Node3D, face: Array, u0: float, u1: float, v0: float, v1: float, m: Material, center: Vector3) -> void:
	var a: Vector3 = face[0]
	var n := ((face[1] as Vector3) - a).cross((face[3] as Vector3) - a).normalized()
	var mid: Vector3 = ((face[0] as Vector3) + (face[1] as Vector3) + (face[2] as Vector3) + (face[3] as Vector3)) * 0.25
	if n.dot(mid - center) < 0.0:
		n = -n
	var o := n * 0.012
	_faces(parent, [[_qp(face, u0, v0, o), _qp(face, u1, v0, o), _qp(face, u1, v1, o), _qp(face, u0, v1, o)]], m, center)


## سيدان كلاسيكية بثلاث صناديق (غطاء محرك + كابينة + صندوق خلفي) مثل سيارات الثمانينات والتسعينات
static func _classic_sedan(root: Node3D, P: Material, G: Material, B: Material, C: Material, H: Material, T: Material, y := 0.0) -> void:
	var O := mat("plain", Color(1.0, 0.55, 0.1))
	# الجسم السفلي
	_loft(root, [[-2.36, 0.84, 0.82, 0.33 + y, 0.78 + y], [-2.3, 0.88, 0.86, 0.29 + y, 0.81 + y], [-1.9, 0.89, 0.87, 0.28 + y, 0.83 + y],
		[-0.95, 0.89, 0.87, 0.28 + y, 0.87 + y], [1.45, 0.89, 0.87, 0.28 + y, 0.89 + y], [2.28, 0.89, 0.87, 0.3 + y, 0.89 + y],
		[2.35, 0.85, 0.83, 0.33 + y, 0.86 + y]], P, 10.0, 40)
	# الكابينة (وجوه مستوية حادة مثل الواقع)
	var by := 0.865 + y
	var ty := 1.43 + y
	var b0 := Vector3(-0.85, by, -0.98)
	var b1 := Vector3(0.85, by, -0.98)
	var b2 := Vector3(0.85, by, 1.48)
	var b3 := Vector3(-0.85, by, 1.48)
	var t0 := Vector3(-0.71, ty, -0.32)
	var t1 := Vector3(0.71, ty, -0.32)
	var t2 := Vector3(0.71, ty, 0.92)
	var t3 := Vector3(-0.71, ty, 0.92)
	var cc := Vector3(0, (by + ty) * 0.5, 0.25)
	var front := [b0, b1, t1, t0]
	var rear := [b2, b3, t3, t2]
	var left := [b0, b3, t3, t0]
	var right := [b1, b2, t2, t1]
	_faces(root, [front, rear, left, right, [t0, t1, t2, t3]], P, cc)
	# الزجاج: زجاج أمامي، خلفي، وشبابيك جانبية مقسومة بعمود وسطي
	_window(root, front, 0.06, 0.94, 0.06, 0.94, G, cc)
	_window(root, rear, 0.07, 0.93, 0.08, 0.92, G, cc)
	for side in [left, right]:
		_window(root, side, 0.24, 0.5, 0.1, 0.9, G, cc)
		_window(root, side, 0.53, 0.8, 0.1, 0.9, G, cc)
	# الوجه الأمامي: شبكة وأربع مصابيح
	_box(root, Vector3(0.62, 0.2, 0.04), Vector3(0, 0.63 + y, -2.37), B)
	for i in 4:
		_box(root, Vector3(0.6, 0.012, 0.045), Vector3(0, 0.56 + y + i * 0.045, -2.38), C)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.2, 0.15, 0.04), Vector3(0.43 * sx, 0.64 + y, -2.37), H)
		_box(root, Vector3(0.2, 0.15, 0.04), Vector3(0.66 * sx, 0.64 + y, -2.36), H)
		_box(root, Vector3(0.12, 0.08, 0.04), Vector3(0.8 * sx, 0.5 + y, -2.36), O)
		# أضواء خلفية عريضة
		_box(root, Vector3(0.56, 0.17, 0.04), Vector3(0.55 * sx, 0.73 + y, 2.355), T)
		_box(root, Vector3(0.14, 0.17, 0.045), Vector3(0.82 * sx, 0.73 + y, 2.35), O)
		# مرايات
		_box(root, Vector3(0.1, 0.09, 0.15), Vector3(0.93 * sx, 0.98 + y, -0.85), P)
		_box(root, Vector3(0.12, 0.03, 0.06), Vector3(0.88 * sx, 0.93 + y, -0.85), B)
		# خط كروم جانبي ومقابض وخطوط الأبواب
		_box(root, Vector3(0.02, 0.035, 4.4), Vector3(0.895 * sx, 0.6 + y, 0.0), C)
		for z in [-0.97, 0.26, 1.47]:
			_box(root, Vector3(0.012, 0.56, 0.012), Vector3(0.893 * sx, 0.58 + y, z), B)
		for z in [0.05, 1.25]:
			_box(root, Vector3(0.025, 0.03, 0.14), Vector3(0.9 * sx, 0.78 + y, z), C)
		# أقواس العجلات
		for z in [-1.4, 1.36]:
			_cyl(root, 0.42, 0.04, Vector3(0.875 * sx, 0.34 + y, z), B, Vector3(0, 0, PI / 2), 24)
	# صدامات كروم ومطاط
	for zz in [-2.42, 2.42]:
		_box(root, Vector3(1.84, 0.13, 0.12), Vector3(0, 0.42 + y, zz), C)
		_box(root, Vector3(1.85, 0.05, 0.13), Vector3(0, 0.42 + y, zz), B)
	_box(root, Vector3(0.52, 0.12, 0.02), Vector3(0, 0.55 + y, 2.37), mat("plain", Color(0.95, 0.95, 0.9)))
	# فتحات تهوية على الغطاء مثل الفيديو + مساحات
	for i in 5:
		_box(root, Vector3(0.42, 0.02, 0.035), Vector3(0, 0.855 + y + i * 0.004, -1.55 + i * 0.09), B)
	for sx in [-0.3, 0.25]:
		_box(root, Vector3(0.5, 0.015, 0.02), Vector3(sx, 0.885 + y, -0.95), B, Vector3(0, 0.15, 0))
	_cyl(root, 0.006, 0.7, Vector3(0.6, 1.2 + y, 1.9), B, Vector3(0.2, 0, 0), 4)


## عمود (مثل أعمدة الزجاج) بين نقطتين
static func _bar(parent: Node3D, p0: Vector3, p1: Vector3, thick: float, width: float, m: Material) -> void:
	var d := p1 - p0
	var y := d.normalized()
	var x := Vector3.FORWARD.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, d.length(), width)
	mi.mesh = bm
	mi.material_override = m
	mi.transform = Transform3D(Basis(x, y, z), (p0 + p1) * 0.5)
	parent.add_child(mi)


## سيدان فخمة انسيابية (خطوط ناعمة، زجاج مدوّر، صندوق خلفي ناعم)
static func _sleek_sedan(root: Node3D, P: Material, G: Material, B: Material, C: Material, H: Material, T: Material) -> void:
	var O := mat("plain", Color(1.0, 0.55, 0.1))
	var lower := [[-2.4, 0.6, 0.48, 0.37, 0.6], [-2.34, 0.81, 0.7, 0.3, 0.69], [-2.16, 0.88, 0.79, 0.28, 0.75],
		[-1.6, 0.9, 0.81, 0.27, 0.8], [-1.0, 0.9, 0.82, 0.27, 0.865], [0.0, 0.91, 0.83, 0.27, 0.9],
		[1.3, 0.91, 0.83, 0.28, 0.925], [1.9, 0.9, 0.82, 0.3, 0.945], [2.25, 0.86, 0.77, 0.33, 0.935],
		[2.37, 0.77, 0.67, 0.38, 0.88], [2.42, 0.58, 0.48, 0.46, 0.8]]
	_loft(root, lower, P, 3.0, 40)
	# الكابينة سطح واحد ناعم: زجاج ملوّن مدمج ويه السقف والأعمدة
	var cabin := [[-1.08, 0.82, 0.8, 0.84, 0.87, 0], [-1.04, 0.82, 0.8, 0.84, 0.9, 0], [-1.0, 0.82, 0.79, 0.84, 0.93, 1],
		[-0.78, 0.82, 0.76, 0.84, 1.1, 1], [-0.4, 0.82, 0.71, 0.84, 1.36, 1], [0.0, 0.82, 0.69, 0.86, 1.43, 1],
		[0.24, 0.82, 0.69, 0.87, 1.43, 1], [0.26, 0.82, 0.69, 0.87, 1.43, 0], [0.36, 0.82, 0.69, 0.87, 1.43, 0],
		[0.38, 0.82, 0.69, 0.87, 1.43, 1], [0.72, 0.82, 0.69, 0.88, 1.42, 1], [1.12, 0.82, 0.72, 0.9, 1.26, 1],
		[1.4, 0.82, 0.75, 0.92, 1.02, 1], [1.44, 0.82, 0.76, 0.92, 0.98, 0], [1.5, 0.82, 0.76, 0.92, 0.95, 0]]
	_loft(root, cabin, P, 2.6, 48, 0.0, 1.43)
	for sx in [-1.0, 1.0]:
		# مصابيح نحيفة + إشارة
		_box(root, Vector3(0.36, 0.08, 0.05), Vector3(0.55 * sx, 0.6, -2.33), H, Vector3(0, -0.22 * sx, 0))
		_box(root, Vector3(0.1, 0.04, 0.05), Vector3(0.76 * sx, 0.59, -2.25), O, Vector3(0, -0.6 * sx, 0))
		# أضواء خلفية ملتفة
		_box(root, Vector3(0.42, 0.11, 0.04), Vector3(0.52 * sx, 0.76, 2.4), T, Vector3(0, 0.12 * sx, 0))
		_box(root, Vector3(0.03, 0.1, 0.26), Vector3(0.855 * sx, 0.76, 2.2), T)
		# مرايات مدورة
		_sphere_m(root, 0.09, Vector3(0.93 * sx, 0.95, -0.9), P, Vector3(1.0, 0.8, 1.5))
		# مقابض وخطوط أبواب ناعمة
		for z in [0.05, 1.18]:
			_box(root, Vector3(0.02, 0.025, 0.15), Vector3(0.905 * sx, 0.8, z), C)
		for z in [-1.0, 0.31, 1.45]:
			_bar(root, Vector3(0.905 * sx, 0.33, z), Vector3(0.88 * sx, 0.87, z - 0.04), 0.008, 0.01, B)
		# خط جانبي ناعم وأقواس العجلات
		_box(root, Vector3(0.015, 0.03, 3.6), Vector3(0.91 * sx, 0.55, 0.05), B)
		for z in [-1.42, 1.38]:
			_cyl(root, 0.4, 0.04, Vector3(0.885 * sx, 0.34, z), B, Vector3(0, 0, PI / 2), 28)
	# مقدمة: فتحة هوا سفلية + شبك نحيف
	_loft(root, [[-2.43, 0.45, 0.42, 0.36, 0.48], [-2.36, 0.55, 0.52, 0.34, 0.5]], B, 4.0, 20)
	_box(root, Vector3(0.5, 0.06, 0.06), Vector3(0, 0.66, -2.36), B)
	_box(root, Vector3(1.6, 0.02, 0.05), Vector3(0, 0.5, -2.33), C)
	_box(root, Vector3(0.48, 0.11, 0.02), Vector3(0, 0.56, 2.42), mat("plain", Color(0.95, 0.95, 0.9)))
	_box(root, Vector3(1.5, 0.02, 0.04), Vector3(0, 0.66, 2.41), C)


static func _sphere_m(parent: Node3D, r: float, pos: Vector3, m: Material, sc: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)


## يرجع: root, wheels(pivot/spin), wheel_pos, radius, rest, box_size, box_center, com_y, head_pos, tail_mat
static func build(body: String, paint: Color) -> Dictionary:
	var root := Node3D.new()
	root.name = "Model"
	var P := paint_mat(paint)
	var G := mat("glass")
	var B := mat("black")
	var C := mat("chrome")
	var H := mat("head")
	var T: StandardMaterial3D = mat("tail").duplicate()
	var W := mat("plain", Color(0.95, 0.95, 0.95))
	var r := 0.42
	var wx := 0.9
	var wzf := -1.5
	var wzr := 1.4
	var rest := 0.45
	var box := Vector3(1.95, 1.0, 4.8)
	var box_c := Vector3(0, 1.05, 0)
	var com := 0.55
	var head := []
	match body:
		"pickup", "monster":
			var y := 0.0
			wx = 0.95
			if body == "monster":
				y = 1.05
				r = 0.95
				wx = 1.3
				wzf = -1.6
				wzr = 1.5
				rest = 0.7
				box = Vector3(2.0, 1.1, 4.8)
				box_c = Vector3(0, 2.1, 0)
				com = 1.3
			var lower := [[-2.5, 0.7, 0.55, 0.62, 0.92], [-2.42, 0.92, 0.75, 0.52, 1.05], [-2.1, 0.98, 0.82, 0.49, 1.12],
				[-1.4, 0.99, 0.86, 0.48, 1.19], [-0.9, 0.99, 0.88, 0.48, 1.24], [0.0, 0.99, 0.9, 0.48, 1.27], [2.2, 0.99, 0.9, 0.48, 1.3],
				[2.42, 0.95, 0.86, 0.52, 1.28], [2.5, 0.78, 0.7, 0.6, 1.18]]
			var cabin := [[-1.2, 0.86, 0.74, 1.18, 1.23], [-0.62, 0.88, 0.7, 1.18, 1.88], [0.5, 0.88, 0.7, 1.18, 1.92],
				[0.72, 0.88, 0.74, 1.18, 1.86], [0.8, 0.88, 0.78, 1.18, 1.24]]
			_loft(root, lower, P, 3.2, 32, y)
			_loft(root, cabin, G, 3.0, 28, y)
			_loft(root, _roof_from(cabin), P, 3.0, 28, y)
			_box(root, Vector3(1.8, 0.04, 1.5), Vector3(0, 1.31 + y, 1.5), B)
			_box(root, Vector3(0.07, 0.26, 1.62), Vector3(0.93, 1.42 + y, 1.52), P)
			_box(root, Vector3(0.07, 0.26, 1.62), Vector3(-0.93, 1.42 + y, 1.52), P)
			_box(root, Vector3(1.9, 0.26, 0.07), Vector3(0, 1.42 + y, 2.36), P)
			_loft(root, [[-2.6, 0.82, 0.82, 0.47, 0.72], [-2.5, 1.0, 1.0, 0.44, 0.76], [-2.3, 1.0, 1.0, 0.44, 0.76]], B, 4.0, 20, y)
			_loft(root, [[2.3, 1.0, 1.0, 0.46, 0.74], [2.52, 1.0, 1.0, 0.46, 0.74], [2.6, 0.84, 0.84, 0.49, 0.7]], B, 4.0, 20, y)
			_box(root, Vector3(1.25, 0.3, 0.06), Vector3(0, 0.95 + y, -2.42), B, Vector3(-0.15, 0, 0))
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.44, 0.08, 0.08), Vector3(0.64 * s, 1.08 + y, -2.36), H, Vector3(-0.2, 0, 0))
				_box(root, Vector3(0.1, 0.38, 0.06), Vector3(0.9 * s, 1.05 + y, 2.46), T)
				_box(root, Vector3(0.06, 0.16, 1.7), Vector3(0.99 * s, 0.56 + y, -0.1), B)
				_box(root, Vector3(0.12, 0.1, 0.18), Vector3(1.0 * s, 1.45 + y, -0.98), P)
				_loft(root, [[-2.0, 0.08, 0.08, 1.05, 1.08], [-1.85, 0.12, 0.1, 1.0, 1.22], [-0.95, 0.12, 0.1, 1.0, 1.28], [-0.85, 0.08, 0.08, 1.05, 1.1]], B, 6.0, 12, y).position.x = 0.95 * s
				_loft(root, [[0.85, 0.08, 0.08, 1.05, 1.1], [0.95, 0.12, 0.1, 1.0, 1.3], [1.85, 0.12, 0.1, 1.0, 1.3], [2.0, 0.08, 0.08, 1.05, 1.1]], B, 6.0, 12, y).position.x = 0.95 * s
			_box(root, Vector3(1.5, 0.07, 0.12), Vector3(0, 1.95 + y, -0.66), B)
			for x in [-0.6, -0.3, 0.0, 0.3, 0.6]:
				_box(root, Vector3(0.2, 0.06, 0.04), Vector3(x, 1.95 + y, -0.73), H)
			head = [Vector3(-0.64, 1.08 + y, -2.42), Vector3(0.64, 1.08 + y, -2.42)]
			if body == "monster":
				_box(root, Vector3(1.4, 0.3, 3.6), Vector3(0, 1.15, 0), B)
				for s in [-1.0, 1.0]:
					_box(root, Vector3(0.12, 1.0, 0.12), Vector3(0.75 * s, 1.5, -1.6), C, Vector3(0, 0, 0.5 * s))
					_box(root, Vector3(0.12, 1.0, 0.12), Vector3(0.75 * s, 1.5, 1.5), C, Vector3(0, 0, 0.5 * s))
		"sedan":
			r = 0.34
			wx = 0.79
			wzf = -1.4
			wzr = 1.36
			rest = 0.32
			wx = 0.8
			wzf = -1.42
			wzr = 1.38
			box = Vector3(1.8, 0.7, 4.75)
			box_c = Vector3(0, 0.66, 0)
			com = 0.42
			_sleek_sedan(root, P, G, B, C, H, T)
			head = [Vector3(-0.56, 0.69, -2.32), Vector3(0.56, 0.69, -2.32)]
		"rally":
			var sx := 1.04
			r = 0.39
			wx = 0.89 * sx
			wzf = -1.42
			wzr = 1.38
			rest = 0.42
			box = Vector3(1.85, 0.75, 4.6)
			box_c = Vector3(0, 0.8, 0)
			com = 0.42
			var y2 := 0.06
			var lower2 := _scale_st([[-2.36, 0.66, 0.5, 0.4, 0.62], [-2.26, 0.88, 0.7, 0.3, 0.72], [-1.75, 0.93, 0.78, 0.28, 0.8],
				[-1.0, 0.94, 0.8, 0.28, 0.88], [0.8, 0.94, 0.82, 0.28, 0.94], [1.8, 0.93, 0.8, 0.3, 0.98],
				[2.22, 0.88, 0.74, 0.36, 0.96], [2.34, 0.7, 0.58, 0.45, 0.88]], sx)
			var cabin2 := _scale_st([[-1.05, 0.8, 0.64, 0.84, 0.89], [-0.6, 0.8, 0.62, 0.84, 1.22], [-0.2, 0.8, 0.6, 0.84, 1.38], [0.55, 0.8, 0.58, 0.84, 1.4],
				[1.1, 0.8, 0.62, 0.84, 1.22], [1.6, 0.8, 0.7, 0.86, 0.96]], sx)
			_loft(root, lower2, P, 2.8, 32, y2)
			_loft(root, cabin2, G, 2.6, 28, y2)
			_loft(root, _roof_from(cabin2), P, 2.6, 28, y2)
			_box(root, Vector3(1.1, 0.16, 0.06), Vector3(0, 0.55 + y2, -2.3), B, Vector3(-0.3, 0, 0))
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.48, 0.07, 0.1), Vector3(0.6 * s, 0.76 + y2, -2.22), H, Vector3(-0.35, 0.25 * s, 0))
				_box(root, Vector3(0.5, 0.08, 0.06), Vector3(0.58 * s, 0.86 + y2, 2.3), T, Vector3(0.3, 0, 0))
				_box(root, Vector3(0.12, 0.09, 0.16), Vector3(0.93 * sx * s, 1.0 + y2, -0.75), P)
				_box(root, Vector3(0.05, 0.12, 1.9), Vector3(0.95 * sx * s, 0.35 + y2, 0.0), B)
			_loft(root, [[-2.42, 0.88, 0.88, 0.25, 0.42], [-2.25, 0.95, 0.95, 0.22, 0.44], [-2.0, 0.95, 0.95, 0.22, 0.4]], B, 4.0, 20, y2)
			head = [Vector3(-0.6, 0.76 + y2, -2.3), Vector3(0.6, 0.76 + y2, -2.3)]
			if body == "rally":
				_loft(root, _stripe_from(lower2, 0.17), W, 4.0, 16, y2)
				_loft(root, _stripe_from(_roof_from(cabin2), 0.17), W, 4.0, 16, y2)
				_box(root, Vector3(1.85, 0.05, 0.38), Vector3(0, 1.3 + y2, 2.12), P, Vector3(-0.1, 0, 0))
				for s in [-1.0, 1.0]:
					_box(root, Vector3(0.05, 0.3, 0.22), Vector3(0.62 * s, 1.13 + y2, 2.12), B)
					_box(root, Vector3(0.05, 0.36, 0.5), Vector3(0.93 * s, 1.25 + y2, 2.12), P)
				_loft(root, [[-0.55, 0.22, 0.18, 1.38, 1.4], [-0.3, 0.25, 0.2, 1.38, 1.53], [0.05, 0.25, 0.2, 1.38, 1.55], [0.1, 0.22, 0.18, 1.38, 1.42]], B, 4.0, 16, y2)
				for x in [-0.42, -0.14, 0.14, 0.42]:
					_cyl(root, 0.11, 0.06, Vector3(x, 0.62 + y2, -2.36), H, Vector3(PI / 2, 0, 0), 10)
		"jeep":
			r = 0.46
			wx = 0.92
			wzf = -1.35
			wzr = 1.3
			rest = 0.5
			box = Vector3(1.95, 1.3, 4.2)
			box_c = Vector3(0, 1.3, 0)
			com = 0.65
			var lower3 := [[-2.14, 0.88, 0.84, 0.64, 1.18], [-2.04, 0.97, 0.94, 0.58, 1.32], [-1.2, 0.98, 0.96, 0.58, 1.36],
				[1.95, 0.98, 0.96, 0.58, 1.38], [2.07, 0.94, 0.92, 0.62, 1.34]]
			var cabin3 := [[-0.98, 0.95, 0.88, 1.3, 1.36], [-0.68, 0.96, 0.88, 1.3, 2.16], [1.92, 0.96, 0.9, 1.3, 2.2], [2.04, 0.95, 0.9, 1.3, 1.36]]
			_loft(root, lower3, P, 5.0, 32)
			_loft(root, cabin3, G, 5.0, 28)
			_loft(root, _roof_from(cabin3), P, 5.0, 28)
			_box(root, Vector3(1.6, 0.1, 2.0), Vector3(0, 2.3, 0.45), B)
			_box(root, Vector3(1.5, 0.45, 0.06), Vector3(0, 1.0, -2.12), B)
			_loft(root, [[-2.3, 1.0, 1.0, 0.62, 0.86], [-2.12, 1.05, 1.05, 0.6, 0.88]], B, 6.0, 16)
			for s in [-1.0, 1.0]:
				_cyl(root, 0.15, 0.06, Vector3(0.66 * s, 1.12, -2.13), H, Vector3(PI / 2, 0, 0), 14)
				_box(root, Vector3(0.16, 0.3, 0.06), Vector3(0.82 * s, 1.15, 2.09), T)
				_loft(root, [[-1.95, 0.14, 0.12, 1.2, 1.3], [-1.75, 0.16, 0.14, 1.15, 1.42], [-0.95, 0.16, 0.14, 1.15, 1.42], [-0.75, 0.14, 0.12, 1.2, 1.3]], B, 6.0, 12).position.x = 1.0 * s
				_loft(root, [[0.75, 0.14, 0.12, 1.2, 1.3], [0.95, 0.16, 0.14, 1.15, 1.42], [1.75, 0.16, 0.14, 1.15, 1.42], [1.95, 0.14, 0.12, 1.2, 1.3]], B, 6.0, 12).position.x = 1.0 * s
			_cyl(root, 0.44, 0.28, Vector3(0, 1.45, 2.24), mat("tire"), Vector3(PI / 2, 0, 0), 18)
			_cyl(root, 0.08, 1.4, Vector3(0.98, 1.75, -1.0), B)
			head = [Vector3(-0.66, 1.12, -2.16), Vector3(0.66, 1.12, -2.16)]
		"truck":
			r = 0.56
			wx = 1.05
			wzf = -2.3
			wzr = 2.0
			rest = 0.5
			box = Vector3(2.45, 2.5, 6.6)
			box_c = Vector3(0, 2.05, 0)
			com = 0.9
			_box(root, Vector3(2.0, 0.4, 6.4), Vector3(0, 1.0, 0), B)
			_loft(root, [[-3.34, 0.95, 0.8, 0.95, 1.9], [-3.22, 1.12, 0.95, 0.85, 2.5], [-2.8, 1.16, 1.02, 0.85, 2.8], [-1.45, 1.17, 1.05, 0.85, 2.88], [-1.38, 1.1, 1.0, 0.9, 2.82]], P, 4.0, 32)
			_box(root, Vector3(2.05, 0.75, 0.06), Vector3(0, 2.2, -3.25), G, Vector3(-0.12, 0, 0))
			for s in [-1.0, 1.0]:
				_box(root, Vector3(0.06, 0.6, 1.1), Vector3(1.16 * s, 2.25, -2.3), G)
				_box(root, Vector3(0.08, 0.35, 0.1), Vector3(1.25 * s, 2.35, -3.1), B)
				_box(root, Vector3(0.36, 0.16, 0.08), Vector3(0.75 * s, 1.35, -3.32), H)
				_box(root, Vector3(0.22, 0.3, 0.06), Vector3(1.0 * s, 1.5, 3.1), T)
			_loft(root, [[-1.25, 1.15, 1.12, 1.35, 3.35], [-1.18, 1.23, 1.2, 1.3, 3.42], [2.98, 1.23, 1.2, 1.3, 3.42], [3.05, 1.15, 1.12, 1.35, 3.35]], W, 7.0, 32)
			_loft(root, [[-1.21, 1.235, 1.235, 1.45, 1.75], [3.01, 1.235, 1.235, 1.45, 1.75]], P, 12.0, 28)
			_box(root, Vector3(2.4, 0.4, 0.22), Vector3(0, 1.05, -3.3), C)
			_cyl(root, 0.08, 1.6, Vector3(1.15, 3.1, -1.5), C)
			head = [Vector3(-0.75, 1.35, -3.36), Vector3(0.75, 1.35, -3.36)]
		"buggy":
			r = 0.5
			wx = 0.95
			wzf = -1.25
			wzr = 1.2
			rest = 0.5
			box = Vector3(1.5, 0.9, 3.4)
			box_c = Vector3(0, 1.05, 0)
			com = 0.6
			_loft(root, [[-1.95, 0.35, 0.3, 0.72, 0.84], [-1.7, 0.65, 0.55, 0.62, 1.02], [-0.7, 0.72, 0.6, 0.6, 1.08], [-0.55, 0.72, 0.6, 0.62, 0.75]], P, 3.5, 24)
			_loft(root, [[0.6, 0.6, 0.5, 0.75, 0.85], [0.8, 0.68, 0.55, 0.7, 1.25], [1.55, 0.68, 0.55, 0.7, 1.2], [1.75, 0.55, 0.45, 0.78, 0.95]], P, 3.5, 24)
			_box(root, Vector3(1.3, 0.16, 3.0), Vector3(0, 0.66, 0), B)
			_box(root, Vector3(0.48, 0.65, 0.5), Vector3(-0.3, 1.05, 0.05), B)
			_box(root, Vector3(0.48, 0.65, 0.5), Vector3(0.3, 1.05, 0.05), B)
			for s in [-1.0, 1.0]:
				_cyl(root, 0.04, 1.2, Vector3(0.62 * s, 1.4, -0.55), C, Vector3(0.45, 0, 0), 8)
				_cyl(root, 0.04, 1.05, Vector3(0.62 * s, 1.35, 0.65), C, Vector3(-0.15, 0, 0), 8)
				_cyl(root, 0.04, 1.25, Vector3(0.62 * s, 1.88, 0.05), C, Vector3(PI / 2, 0, 0), 8)
				_loft(root, [[-1.6, 0.18, 0.15, 0.9, 0.95], [-1.4, 0.2, 0.17, 0.85, 1.08], [-0.95, 0.2, 0.17, 0.85, 1.08], [-0.8, 0.18, 0.15, 0.9, 0.95]], P, 3.0, 12).position.x = 1.0 * s
				_box(root, Vector3(0.18, 0.12, 0.05), Vector3(0.5 * s, 1.0, 1.77), T)
			_cyl(root, 0.04, 1.3, Vector3(0, 1.88, -0.55), C, Vector3(0, 0, PI / 2), 8)
			_cyl(root, 0.04, 1.3, Vector3(0, 1.83, 0.65), C, Vector3(0, 0, PI / 2), 8)
			_box(root, Vector3(1.0, 0.1, 0.1), Vector3(0, 1.94, -0.6), B)
			for x in [-0.3, 0.0, 0.3]:
				_box(root, Vector3(0.2, 0.09, 0.05), Vector3(x, 1.94, -0.66), H)
			head = [Vector3(-0.3, 1.94, -0.7), Vector3(0.3, 1.94, -0.7)]
	# العجلات
	var wheels := []
	var wpos := [Vector3(-wx, r, wzf), Vector3(wx, r, wzf), Vector3(-wx, r, wzr), Vector3(wx, r, wzr)]
	var ww := 0.34
	if body == "sedan":
		ww = 0.24
	if body == "monster":
		ww = 0.75
	elif body == "buggy":
		ww = 0.42
	elif body == "truck":
		ww = 0.4
	for i in 4:
		var wh := _wheel(r, ww)
		wh["pivot"].position = wpos[i]
		root.add_child(wh["pivot"])
		wheels.append(wh)
	var bottom := box_c.y - box.y * 0.5
	if bottom < 0.32:
		box_c.y += 0.32 - bottom
	return {"root": root, "wheels": wheels, "wheel_pos": wpos, "radius": r, "rest": rest,
		"box_size": box, "box_center": box_c, "com_y": com, "head_pos": head, "tail_mat": T, "paint_mat": P}
