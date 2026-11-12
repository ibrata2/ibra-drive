class_name PropLib
extends RefCounted
## يبني موديلات الأشياء (صخور، أشجار، نخيل، بيوت، قصب...) كـ ArrayMesh بألوان مدمجة

# معلومات التصادم: [نوع, أبعاد] بوحدة الموديل قبل التكبير
const SOLID := {
	"rock": ["box", Vector3(1.7, 1.3, 1.7)],
	"tree": ["cyl", Vector2(0.35, 5.0)], "tree_big": ["cyl", Vector2(0.6, 8.0)],
	"pine": ["cyl", Vector2(0.35, 6.0)], "pine_snow": ["cyl", Vector2(0.35, 6.0)],
	"palm": ["cyl", Vector2(0.3, 7.0)], "acacia": ["cyl", Vector2(0.3, 4.0)],
	"dead_tree": ["cyl", Vector2(0.25, 4.0)], "pole": ["cyl", Vector2(0.18, 8.0)],
	"house": ["box", Vector3(6.4, 3.6, 5.4)], "cabin": ["box", Vector3(5.2, 3.0, 4.2)],
	"shack": ["box", Vector3(4.2, 3.2, 3.6)], "tent": ["box", Vector3(5.0, 1.8, 3.6)],
	"wreck": ["box", Vector3(1.9, 1.2, 4.2)], "mudhif": ["box", Vector3(5.2, 2.6, 9.0)],
	"snowman": ["cyl", Vector2(0.7, 2.0)], "crystals": ["box", Vector3(1.6, 2.0, 1.6)],
	"hay": ["box", Vector3(1.6, 1.6, 1.6)], "tires": ["cyl", Vector2(0.5, 1.0)],
	"log": ["box", Vector3(0.7, 0.6, 5.0)], "lamp": ["cyl", Vector2(0.12, 6.0)],
	"wall": ["box", Vector3(6.0, 1.8, 0.35)],
	"barn": ["box", Vector3(7.2, 3.6, 6.2)], "crates": ["box", Vector3(2.6, 1.9, 1.7)],
	"marker": ["cyl", Vector2(0.09, 1.3)], "ramp": ["wedge", Vector3(4.0, 1.4, 6.0)],
}

# الأشياء الصغيرة (عشب) بدون تصادم، تستخدم شيدر الهوا
const GRASSY := ["grass", "grass_dry", "dune_grass", "reed", "flower", "crop", "crop_green"]


static func _add_prim(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, col: Color, flat := false) -> void:
	var arr := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for i in verts.size():
			idx[i] = i
	var nb := xf.basis.inverse().transposed()
	var tri := 0
	while tri + 2 < idx.size():
		var ids := [idx[tri], idx[tri + 1], idx[tri + 2]]
		var fn := Vector3.ZERO
		if flat:
			fn = (nb * (norms[ids[0]] + norms[ids[1]] + norms[ids[2]])).normalized()
		for j in 3:
			st.set_color(col)
			st.set_normal(fn if flat else (nb * norms[ids[j]]).normalized())
			st.add_vertex(xf * verts[ids[j]])
		tri += 3


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - center) < 0.0:
		n = -n
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_add_prim(st, bm, Transform3D(Basis.from_euler(rot), pos), col, true)


static func _cyl(st: SurfaceTool, rt: float, rb: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, segs := 7, flat := true) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	_add_prim(st, cm, Transform3D(Basis.from_euler(rot), pos), col, flat)


static func _sphere(st: SurfaceTool, r: float, pos: Vector3, col: Color, scale := Vector3.ONE, segs := 7, rings := 4) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = rings
	_add_prim(st, sm, Transform3D(Basis().scaled(scale), pos), col, true)


static func _blades(st: SurfaceTool, rng: RandomNumberGenerator, count: int, h: float, w: float, spread: float, c0: Color, c1: Color, lean := 0.35) -> void:
	for i in count:
		var ang := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * spread
		var base := Vector3(cos(ang) * rr, 0, sin(ang) * rr)
		var hh := h * rng.randf_range(0.6, 1.15)
		var dir := Vector3(cos(ang + 1.3), 0, sin(ang + 1.3))
		var tipoff := Vector3(cos(ang), 0, sin(ang)) * hh * lean * rng.randf_range(0.3, 1.0)
		var a := base - dir * w * 0.5
		var b := base + dir * w * 0.5
		var c := base + Vector3(0, hh, 0) + tipoff
		var n := Vector3(cos(ang), 1.5, sin(ang)).normalized()
		st.set_color(c0)
		st.set_normal(n)
		st.add_vertex(a)
		st.set_color(c0)
		st.set_normal(n)
		st.add_vertex(b)
		st.set_color(c1)
		st.set_normal(n)
		st.add_vertex(c)


## طابوق الحايط: [المكان, الحجم] — نفسه يستخدم للرسم وللتكسير
static func wall_bricks() -> Array:
	var out: Array = []
	for row in 4:
		var y := 0.225 + row * 0.45
		var x := -3.0
		var first := 0.375 if row % 2 == 1 else 0.75
		var w := first
		while x < 2.999:
			w = minf(w, 3.0 - x)
			out.append([Vector3(x + w * 0.5, y, 0), Vector3(w, 0.45, 0.35)])
			x += w
			w = 0.75
	return out


## صناديق مكدسة: [مكان, حجم]
static func crate_layout() -> Array:
	return [[Vector3(-0.66, 0.31, 0), Vector3(0.62, 0.62, 0.62)], [Vector3(0.0, 0.31, 0.05), Vector3(0.62, 0.62, 0.62)],
		[Vector3(0.66, 0.31, -0.05), Vector3(0.62, 0.62, 0.62)], [Vector3(-0.33, 0.93, 0), Vector3(0.62, 0.62, 0.62)],
		[Vector3(0.33, 0.93, 0.03), Vector3(0.62, 0.62, 0.62)], [Vector3(0.0, 1.55, 0), Vector3(0.62, 0.62, 0.62)],
		[Vector3(0.9, 0.42, 0.75), Vector3(0.5, 0.84, 0.5)]]


## قطع البناء للبيوت حتى تنهدم بشكل واقعي.
## كل قطعة: {"size", "pos", "rot" (Vector3), "col", "type": wall/roof/post/porch_roof, "mass"}
static func structure(kind: String) -> Array:
	var out: Array = []
	match kind:
		"house":
			var wall := Color(0.82, 0.72, 0.56)
			# حيطان طابوق/لبن: مربعات 1×1.07
			for face in 4:
				var along_x := face < 2
				var length := 6.0 if along_x else 5.0
				var n := int(length)
				for i in n:
					for row in 3:
						var u := -length / 2.0 + (i + 0.5) * length / n
						var y := 0.53 + row * 1.07
						var pos := Vector3(u, y, -2.5 if face == 0 else 2.5) if along_x else Vector3(-3.0 if face == 2 else 3.0, y, u)
						var size := Vector3(length / n, 1.06, 0.26) if along_x else Vector3(0.26, 1.06, length / n)
						var c := wall
						if face == 0 and i == 3 and row < 2:
							c = Color(0.32, 0.22, 0.15)
						elif (i + row) % 3 == 1 and row == 1:
							c = Color(0.18, 0.22, 0.26)
						var shade := 0.94 + float((i * 5 + row * 3 + face) % 4) * 0.025
						out.append({"size": size, "pos": pos, "rot": Vector3.ZERO, "col": Color(c.r * shade, c.g * shade, c.b * shade), "type": "wall", "mass": 70.0})
			for i in 2:
				for j in 2:
					out.append({"size": Vector3(3.1, 0.32, 2.6), "pos": Vector3(-1.55 + i * 3.1, 3.36, -1.3 + j * 2.6), "rot": Vector3.ZERO,
						"col": wall.darkened(0.1), "type": "roof", "mass": 220.0})
		"barn":
			var red := Color(0.58, 0.16, 0.12)
			for face in 4:
				var along_x := face < 2
				var length := 7.0 if along_x else 6.0
				var n := int(round(length / 0.7))
				for i in n:
					var u := -length / 2.0 + (i + 0.5) * length / n
					var pos := Vector3(u, 1.75, -3.0 if face == 0 else 3.0) if along_x else Vector3(-3.5 if face == 2 else 3.5, 1.75, u)
					var size := Vector3(length / n - 0.02, 3.5, 0.12) if along_x else Vector3(0.12, 3.5, length / n - 0.02)
					var shade := 0.85 + float((i * 7 + face * 3) % 5) * 0.05
					var c := Color(red.r * shade, red.g * shade, red.b * shade)
					if face == 0 and absi(i - n / 2) <= 1:
						c = Color(0.85, 0.82, 0.75) if i == n / 2 else c.darkened(0.3)
					out.append({"size": size, "pos": pos, "rot": Vector3.ZERO, "col": c, "type": "wall", "mass": 22.0})
			for sgn in [-1.0, 1.0]:
				for i in 2:
					out.append({"size": Vector3(3.8, 0.12, 3.5), "pos": Vector3(-1.85 + i * 3.7, 4.35, 1.5 * sgn), "rot": Vector3(-0.5 * sgn, 0, 0),
						"col": Color(0.55, 0.56, 0.58), "type": "roof", "mass": 110.0})
		"cabin", "shack":
			var wood := Color(0.45, 0.3, 0.18) if kind == "cabin" else Color(0.55, 0.43, 0.32)
			var w := 5.0 if kind == "cabin" else 4.0
			var d := 4.0 if kind == "cabin" else 3.4
			var h := 2.6 if kind == "cabin" else 2.8
			for face in 4:
				var along_x := face < 2
				var length := w if along_x else d
				var n := int(round(length / 0.5))
				for i in n:
					var u := -length / 2.0 + (i + 0.5) * length / n
					var pos := Vector3(u, h / 2.0, -d / 2.0 if face == 0 else d / 2.0) if along_x else Vector3(-w / 2.0 if face == 2 else w / 2.0, h / 2.0, u)
					var size := Vector3(length / n - 0.02, h, 0.1) if along_x else Vector3(0.1, h, length / n - 0.02)
					var shade := 0.88 + float((i * 7 + face * 3) % 5) * 0.04
					out.append({"size": size, "pos": pos, "rot": Vector3.ZERO, "col": Color(wood.r * shade, wood.g * shade, wood.b * shade), "type": "wall", "mass": 18.0})
			if kind == "cabin":
				for sgn in [-1.0, 1.0]:
					out.append({"size": Vector3(5.6, 0.14, 2.75), "pos": Vector3(0, 3.45, 1.12 * sgn), "rot": Vector3(-0.55 * sgn, 0, 0),
						"col": Color(0.3, 0.2, 0.15), "type": "roof", "mass": 160.0})
			else:
				for i in 2:
					out.append({"size": Vector3(2.3, 0.12, 4.2), "pos": Vector3(-1.15 + i * 2.3, 3.0, 0.2), "rot": Vector3(0.12, 0, 0),
						"col": Color(0.5, 0.48, 0.45), "type": "roof", "mass": 60.0})
				# شرفة: أرضية ألواح + أعمدة + سقف
				for i in 5:
					out.append({"size": Vector3(0.78, 0.12, 1.6), "pos": Vector3(-1.6 + i * 0.8, 0.3, -2.5), "rot": Vector3.ZERO,
						"col": wood.darkened(0.15 + 0.05 * (i % 2)), "type": "wall", "mass": 12.0})
				for x in [-1.9, 1.9]:
					out.append({"size": Vector3(0.14, 2.5, 0.14), "pos": Vector3(x, 1.45, -3.25), "rot": Vector3.ZERO,
						"col": wood.darkened(0.2), "type": "post", "mass": 15.0})
				out.append({"size": Vector3(4.4, 0.1, 1.9), "pos": Vector3(0, 2.75, -2.55), "rot": Vector3(0.1, 0, 0),
					"col": Color(0.5, 0.48, 0.45), "type": "porch_roof", "mass": 50.0})
	return out


## kind = نوع الشي، p = ألوان حسب البيئة والفصل
static func build(kind: String, p: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + int(p.get("variant", 0)) * 977
	var fol: Color = p.get("foliage", Color(0.3, 0.5, 0.2))
	var trunk: Color = p.get("trunk", Color(0.36, 0.25, 0.16))
	var rockc: Color = p.get("rock", Color(0.6, 0.55, 0.5))
	var snowy: bool = p.get("snowy", false)
	var white := Color(0.95, 0.97, 1.0)
	match kind:
		"rock":
			_sphere(st, 1.0, Vector3(0, 0.2, 0), rockc, Vector3(1.0, 0.75, 0.9), 6, 4)
			_sphere(st, 0.6, Vector3(0.6, 0.1, 0.3), rockc.darkened(0.08), Vector3(1.0, 0.8, 1.0), 5, 3)
			if snowy:
				_sphere(st, 0.8, Vector3(0, 0.55, 0), white, Vector3(1.0, 0.35, 0.9), 6, 3)
		"dry_bush":
			for i in 8:
				var a := TAU * i / 8.0 + rng.randf() * 0.4
				_cyl(st, 0.01, 0.035, 1.0, Vector3(cos(a) * 0.25, 0.4, sin(a) * 0.25), Color(0.45, 0.36, 0.25), Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6), 4)
			_sphere(st, 0.45, Vector3(0, 0.45, 0), Color(0.55, 0.47, 0.32), Vector3(1.2, 0.7, 1.2), 5, 3)
		"dead_tree":
			_cyl(st, 0.1, 0.22, 3.2, Vector3(0, 1.6, 0), Color(0.33, 0.27, 0.22))
			_cyl(st, 0.03, 0.09, 1.6, Vector3(0.45, 2.6, 0), Color(0.33, 0.27, 0.22), Vector3(0, 0, -0.8))
			_cyl(st, 0.03, 0.08, 1.4, Vector3(-0.4, 2.9, 0.2), Color(0.33, 0.27, 0.22), Vector3(0.3, 0, 0.9))
			_cyl(st, 0.02, 0.06, 1.0, Vector3(0.1, 3.3, -0.4), Color(0.33, 0.27, 0.22), Vector3(-0.7, 0, 0))
		"tree", "tree_big":
			var s := 1.0 if kind == "tree" else 1.8
			_cyl(st, 0.16 * s, 0.26 * s, 2.6 * s, Vector3(0, 1.3 * s, 0), trunk)
			if p.get("bare", false):
				_cyl(st, 0.03, 0.1, 1.6, Vector3(0.5, 2.6 * s, 0), trunk, Vector3(0, 0, -0.8))
				_cyl(st, 0.03, 0.1, 1.6, Vector3(-0.5, 2.7 * s, 0.1), trunk, Vector3(0.2, 0, 0.8))
			else:
				_sphere(st, 1.5 * s, Vector3(0, 3.3 * s, 0), fol, Vector3(1, 0.85, 1))
				_sphere(st, 1.1 * s, Vector3(0.8 * s, 3.9 * s, 0.3 * s), fol.lightened(0.08))
				_sphere(st, 1.0 * s, Vector3(-0.7 * s, 3.7 * s, -0.5 * s), fol.darkened(0.08))
				if snowy:
					_sphere(st, 1.2 * s, Vector3(0, 4.1 * s, 0), white, Vector3(1, 0.45, 1))
		"pine", "pine_snow":
			_cyl(st, 0.14, 0.24, 2.0, Vector3(0, 1.0, 0), trunk)
			var pc := fol if kind == "pine" else Color(0.18, 0.32, 0.22)
			for i in 3:
				var rad := 1.7 - i * 0.45
				var y := 1.6 + i * 1.25
				_cyl(st, 0.0, rad, 2.2, Vector3(0, y + 1.1, 0), pc.lightened(i * 0.04), Vector3.ZERO, 8)
				if kind == "pine_snow" or snowy:
					_cyl(st, 0.0, rad * 0.75, 1.0, Vector3(0, y + 1.75, 0), white, Vector3.ZERO, 8)
		"palm":
			var pos := Vector3.ZERO
			var bend := rng.randf_range(0.04, 0.09)
			for i in 7:
				var r := Vector3(0, 0, bend * i)
				var seg := Basis.from_euler(r) * Vector3(0, 1.0, 0)
				_cyl(st, 0.17, 0.21, 1.05, pos + seg * 0.5, Color(0.48, 0.38, 0.26).darkened(0.05 * (i % 2)), r, 6)
				pos += seg
			var lc := fol.lerp(Color(0.25, 0.48, 0.18), 0.5)
			for i in 9:
				var a := TAU * i / 9.0
				var dir := Vector3(cos(a), 0, sin(a))
				var tip := pos + dir * 2.6 + Vector3(0, -0.9, 0)
				var mid := pos + dir * 1.4 + Vector3(0, 0.35, 0)
				var sidev := dir.cross(Vector3.UP).normalized() * 0.42
				_tri(st, pos, mid + sidev, mid - sidev, lc, pos - Vector3(0, 3, 0))
				_tri(st, mid + sidev, tip, mid - sidev, lc.darkened(0.1), pos - Vector3(0, 3, 0))
			_sphere(st, 0.3, pos + Vector3(0, -0.2, 0), Color(0.55, 0.32, 0.1), Vector3(1, 1.2, 1), 5, 3)
		"acacia":
			_cyl(st, 0.12, 0.22, 3.4, Vector3(0.3, 1.7, 0), trunk, Vector3(0, 0, -0.18))
			_cyl(st, 0.08, 0.12, 1.6, Vector3(-0.3, 3.2, 0), trunk, Vector3(0, 0, 0.7))
			_cyl(st, 2.8, 3.2, 0.55, Vector3(0.4, 3.9, 0), fol, Vector3.ZERO, 9)
			_cyl(st, 1.6, 2.0, 0.4, Vector3(-0.9, 3.6, 0.6), fol.darkened(0.06), Vector3.ZERO, 8)
		"bush":
			_sphere(st, 0.7, Vector3(0, 0.45, 0), fol.darkened(0.05), Vector3(1.2, 0.8, 1.1))
			_sphere(st, 0.5, Vector3(0.5, 0.35, 0.2), fol)
			_sphere(st, 0.45, Vector3(-0.4, 0.3, -0.3), fol.lightened(0.05))
		"log":
			_cyl(st, 0.3, 0.3, 4.8, Vector3(0, 0.3, 0), trunk, Vector3(PI / 2, 0, 0), 7)
		"hay":
			_cyl(st, 0.8, 0.8, 1.5, Vector3(0, 0.8, 0), Color(0.86, 0.72, 0.38), Vector3(0, 0, PI / 2), 10, false)
		"house":
			var wall := Color(0.82, 0.72, 0.56)
			_box(st, Vector3(6.0, 3.2, 5.0), Vector3(0, 1.6, 0), wall)
			_box(st, Vector3(6.2, 0.4, 5.2), Vector3(0, 3.35, 0), wall.darkened(0.08))
			_box(st, Vector3(1.0, 2.0, 0.1), Vector3(0.8, 1.0, -2.52), Color(0.32, 0.22, 0.15))
			_box(st, Vector3(0.9, 0.8, 0.1), Vector3(-1.6, 1.8, -2.52), Color(0.15, 0.2, 0.25))
			_box(st, Vector3(0.1, 0.8, 0.9), Vector3(3.02, 1.8, 0.5), Color(0.15, 0.2, 0.25))
			_box(st, Vector3(1.4, 0.5, 1.0), Vector3(-1.8, 3.8, 1.2), Color(0.85, 0.85, 0.85))
		"cabin":
			var wood := Color(0.45, 0.3, 0.18)
			_box(st, Vector3(5.0, 2.6, 4.0), Vector3(0, 1.3, 0), wood)
			var c := Vector3(0, 2.6, 0)
			var a := Vector3(-2.8, 2.6, -2.3)
			var b := Vector3(2.8, 2.6, -2.3)
			var cc := Vector3(2.8, 2.6, 2.3)
			var d := Vector3(-2.8, 2.6, 2.3)
			var r1 := Vector3(-2.8, 4.3, 0)
			var r2 := Vector3(2.8, 4.3, 0)
			var roof := white if snowy else Color(0.3, 0.2, 0.15)
			_tri(st, a, b, r2, roof, c)
			_tri(st, a, r2, r1, roof, c)
			_tri(st, d, cc, r2, roof, c)
			_tri(st, d, r2, r1, roof, c)
			_tri(st, a, d, r1, wood.darkened(0.1), c)
			_tri(st, b, cc, r2, wood.darkened(0.1), c)
			_box(st, Vector3(0.9, 1.8, 0.1), Vector3(0, 0.9, -2.02), Color(0.25, 0.16, 0.1))
			_box(st, Vector3(0.8, 0.7, 0.1), Vector3(1.6, 1.6, -2.02), Color(0.95, 0.75, 0.4))
			_box(st, Vector3(0.5, 1.4, 0.5), Vector3(1.6, 4.0, 1.0), Color(0.4, 0.38, 0.36))
		"shack":
			var wood := Color(0.55, 0.43, 0.32)
			_box(st, Vector3(4.0, 2.8, 3.4), Vector3(0, 1.4, 0), wood)
			_box(st, Vector3(4.6, 0.12, 4.2), Vector3(0, 3.0, 0.2), Color(0.5, 0.48, 0.45), Vector3(0.12, 0, 0))
			_box(st, Vector3(0.9, 1.9, 0.1), Vector3(-0.8, 0.95, -1.72), Color(0.3, 0.22, 0.16))
			_box(st, Vector3(0.8, 0.6, 0.1), Vector3(1.0, 1.7, -1.72), Color(0.12, 0.12, 0.12))
			_box(st, Vector3(4.0, 0.15, 1.6), Vector3(0, 0.3, -2.5), wood.darkened(0.15))
			for x in [-1.9, 1.9]:
				_box(st, Vector3(0.12, 2.4, 0.12), Vector3(x, 1.4, -3.2), wood.darkened(0.2))
		"tent":
			var cloth := Color(0.2, 0.15, 0.12)
			var cen := Vector3(0, 0, 0)
			var pts := [Vector3(-2.5, 0, -1.8), Vector3(2.5, 0, -1.8), Vector3(2.5, 0, 1.8), Vector3(-2.5, 0, 1.8)]
			var ridge := [Vector3(-2.3, 1.8, 0), Vector3(2.3, 1.8, 0)]
			_tri(st, pts[0], pts[1], ridge[1], cloth, cen)
			_tri(st, pts[0], ridge[1], ridge[0], cloth, cen)
			_tri(st, pts[3], pts[2], ridge[1], cloth.lightened(0.05), cen)
			_tri(st, pts[3], ridge[1], ridge[0], cloth.lightened(0.05), cen)
			_tri(st, pts[0], pts[3], ridge[0], cloth.darkened(0.1), cen)
			_box(st, Vector3(1.6, 0.05, 1.2), Vector3(0, 0.03, -2.4), Color(0.6, 0.15, 0.12))
		"pole":
			_cyl(st, 0.1, 0.16, 8.0, Vector3(0, 4.0, 0), Color(0.35, 0.27, 0.2), Vector3.ZERO, 6)
			_box(st, Vector3(2.4, 0.14, 0.14), Vector3(0, 7.3, 0), Color(0.35, 0.27, 0.2))
			for x in [-1.0, 0.0, 1.0]:
				_cyl(st, 0.05, 0.05, 0.2, Vector3(x, 7.45, 0), Color(0.75, 0.75, 0.7), Vector3.ZERO, 5)
		"tires":
			for i in 3:
				var tm := TorusMesh.new()
				tm.inner_radius = 0.22
				tm.outer_radius = 0.48
				tm.rings = 10
				tm.ring_segments = 6
				_add_prim(st, tm, Transform3D(Basis(), Vector3(rng.randf() * 0.1, 0.15 + i * 0.27, 0)), Color(0.07, 0.07, 0.07))
		"wreck":
			var rust := Color(0.45, 0.25, 0.15).lerp(Color(0.3, 0.32, 0.35), rng.randf())
			_box(st, Vector3(1.8, 0.6, 4.2), Vector3(0, 0.55, 0), rust, Vector3(0, 0, 0.06))
			_box(st, Vector3(1.6, 0.5, 2.0), Vector3(0, 1.1, 0.2), rust.darkened(0.2))
			_cyl(st, 0.38, 0.38, 0.3, Vector3(-0.85, 0.3, -1.3), Color(0.08, 0.08, 0.08), Vector3(0, 0, PI / 2))
			_cyl(st, 0.38, 0.38, 0.3, Vector3(0.85, 0.2, 1.3), Color(0.08, 0.08, 0.08), Vector3(0.3, 0, PI / 2))
		"boat":
			var w := Color(0.3, 0.2, 0.12)
			_box(st, Vector3(0.9, 0.35, 5.0), Vector3(0, 0.2, 0), w)
			_box(st, Vector3(0.5, 0.3, 1.6), Vector3(0, 0.35, -3.0), w, Vector3(-0.35, 0, 0))
			_box(st, Vector3(0.5, 0.3, 1.6), Vector3(0, 0.35, 3.0), w, Vector3(0.35, 0, 0))
			_box(st, Vector3(0.05, 0.05, 3.5), Vector3(0.3, 0.6, 0.5), Color(0.6, 0.5, 0.35), Vector3(0.4, 0, 0))
		"mudhif":
			var reedc := Color(0.78, 0.66, 0.42)
			_cyl(st, 2.6, 2.6, 9.0, Vector3(0, 0, 0), reedc, Vector3(PI / 2, 0, 0), 14, false)
			for z in [-3.5, -1.75, 0.0, 1.75, 3.5]:
				_cyl(st, 2.68, 2.68, 0.25, Vector3(0, 0, z), reedc.darkened(0.15), Vector3(PI / 2, 0, 0), 14, false)
			_box(st, Vector3(1.4, 1.8, 0.1), Vector3(0, 0.9, -4.55), Color(0.2, 0.14, 0.08))
		"snowman":
			_sphere(st, 0.75, Vector3(0, 0.65, 0), white, Vector3.ONE, 9, 6)
			_sphere(st, 0.5, Vector3(0, 1.55, 0), white, Vector3.ONE, 9, 6)
			_sphere(st, 0.35, Vector3(0, 2.15, 0), white, Vector3.ONE, 9, 6)
			_cyl(st, 0.0, 0.07, 0.4, Vector3(0, 2.15, -0.5), Color(1, 0.45, 0.05), Vector3(-PI / 2, 0, 0), 6)
			_cyl(st, 0.3, 0.3, 0.35, Vector3(0, 2.55, 0), Color(0.08, 0.08, 0.08), Vector3.ZERO, 10)
			_cyl(st, 0.45, 0.45, 0.04, Vector3(0, 2.38, 0), Color(0.08, 0.08, 0.08), Vector3.ZERO, 10)
		"crystals":
			var cc2: Color = p.get("crystal", Color(0.75, 0.35, 1.0))
			for i in 5:
				var a := TAU * i / 5.0
				_cyl(st, 0.0, 0.25, 1.6 + rng.randf(), Vector3(cos(a) * 0.4, 0.7, sin(a) * 0.4), cc2.lightened(rng.randf() * 0.2), Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4), 5)
			_cyl(st, 0.0, 0.35, 2.4, Vector3(0, 1.1, 0), cc2, Vector3.ZERO, 5)
		"wall":
			var bc: Color = p.get("wallc", Color(0.78, 0.7, 0.58))
			var bi := 0
			for br in wall_bricks():
				var shade := 0.9 + float((bi * 7) % 5) * 0.035
				_box(st, br[1] - Vector3(0.03, 0.03, 0.0), br[0], Color(bc.r * shade, bc.g * shade, bc.b * shade))
				bi += 1
		"barn":
			var red := Color(0.58, 0.16, 0.12)
			_box(st, Vector3(7.0, 3.5, 6.0), Vector3(0, 1.75, 0), red)
			var cen := Vector3(0, 3.5, 0)
			var a := Vector3(-3.6, 3.45, -3.2)
			var b := Vector3(3.6, 3.45, -3.2)
			var c := Vector3(3.6, 3.45, 3.2)
			var d := Vector3(-3.6, 3.45, 3.2)
			var r1 := Vector3(-3.6, 5.2, 0)
			var r2 := Vector3(3.6, 5.2, 0)
			var roof := Color(0.55, 0.56, 0.58)
			_tri(st, a, b, r2, roof, cen)
			_tri(st, a, r2, r1, roof, cen)
			_tri(st, d, c, r2, roof.darkened(0.08), cen)
			_tri(st, d, r2, r1, roof.darkened(0.08), cen)
			_tri(st, a, d, r1, red.darkened(0.15), cen)
			_tri(st, b, c, r2, red.darkened(0.15), cen)
			_box(st, Vector3(2.2, 2.8, 0.06), Vector3(0, 1.4, -3.02), red.darkened(0.3))
			_box(st, Vector3(0.12, 2.8, 0.08), Vector3(0, 1.4, -3.05), Color(0.85, 0.82, 0.75))
			_box(st, Vector3(7.1, 0.12, 6.1), Vector3(0, 0.06, 0), Color(0.35, 0.3, 0.26))
		"crates":
			var cw := Color(0.62, 0.45, 0.26)
			var k := 0
			for cr in crate_layout():
				var col := cw.darkened(0.06 * (k % 3))
				if k == 6:
					col = Color(0.15, 0.35, 0.55)
				_box(st, cr[1], cr[0], col)
				_box(st, (cr[1] as Vector3) * Vector3(1.02, 0.12, 1.02), (cr[0] as Vector3) + Vector3(0, (cr[1] as Vector3).y * 0.3, 0), col.darkened(0.3))
				k += 1
		"marker":
			_cyl(st, 0.07, 0.09, 1.2, Vector3(0, 0.6, 0), Color(0.95, 0.95, 0.92), Vector3.ZERO, 6)
			_cyl(st, 0.075, 0.075, 0.25, Vector3(0, 1.1, 0), Color(0.85, 0.15, 0.1), Vector3.ZERO, 6)
		"ramp":
			var wood2 := Color(0.5, 0.38, 0.25)
			var cc := Vector3(0, 0.3, 0)
			var p0 := Vector3(-2, 0, 3)
			var p1 := Vector3(2, 0, 3)
			var p2 := Vector3(2, 0, -3)
			var p3 := Vector3(-2, 0, -3)
			var t0 := Vector3(-2, 1.4, -3)
			var t1 := Vector3(2, 1.4, -3)
			_tri(st, p0, p1, t1, wood2, cc)
			_tri(st, p0, t1, t0, wood2, cc)
			_tri(st, p3, p2, t1, wood2.darkened(0.25), cc)
			_tri(st, p3, t1, t0, wood2.darkened(0.25), cc)
			_tri(st, p0, p3, t0, wood2.darkened(0.15), cc)
			_tri(st, p1, p2, t1, wood2.darkened(0.15), cc)
			for i in 8:
				var z := 3.0 - (i + 0.5) * 0.75
				var y := 1.4 * (3.0 - z) / 6.0
				_box(st, Vector3(4.02, 0.04, 0.05), Vector3(0, y + 0.02, z), wood2.darkened(0.3), Vector3(0.23, 0, 0))
		"lamp":
			_cyl(st, 0.08, 0.12, 6.0, Vector3(0, 3.0, 0), Color(0.25, 0.27, 0.3), Vector3.ZERO, 6)
			_box(st, Vector3(0.1, 0.1, 1.6), Vector3(0, 5.9, -0.7), Color(0.25, 0.27, 0.3))
		"lamp_head":
			_box(st, Vector3(0.45, 0.15, 0.7), Vector3(0, 5.8, -1.4), Color(1.0, 0.85, 0.55))
		# ---- العشب والزرع
		"grass":
			_blades(st, rng, 14, 0.7, 0.12, 0.45, fol.darkened(0.3), fol.lightened(0.1))
		"grass_dry":
			_blades(st, rng, 14, 0.8, 0.1, 0.45, Color(0.6, 0.5, 0.3), Color(0.85, 0.75, 0.48))
		"dune_grass":
			_blades(st, rng, 18, 0.9, 0.07, 0.55, Color(0.55, 0.45, 0.28), Color(0.78, 0.68, 0.45), 0.55)
		"reed":
			_blades(st, rng, 12, 2.6, 0.08, 0.35, Color(0.35, 0.42, 0.2), Color(0.8, 0.7, 0.45), 0.12)
		"crop":
			_blades(st, rng, 10, 1.0, 0.06, 0.25, Color(0.7, 0.58, 0.3), Color(0.95, 0.82, 0.45), 0.1)
		"crop_green":
			_blades(st, rng, 10, 0.8, 0.07, 0.25, Color(0.2, 0.4, 0.15), Color(0.45, 0.68, 0.25), 0.12)
		"flower":
			_blades(st, rng, 8, 0.45, 0.07, 0.35, fol.darkened(0.3), fol)
			var fc: Color = p.get("flower", Color(0.9, 0.1, 0.1))
			for i in 4:
				var a := rng.randf() * TAU
				var rr := rng.randf() * 0.3
				_sphere(st, 0.09, Vector3(cos(a) * rr, 0.45 + rng.randf() * 0.15, sin(a) * rr), fc, Vector3(1, 0.5, 1), 5, 2)
	return st.commit()
