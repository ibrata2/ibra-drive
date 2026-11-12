extends Camera3D
## كاميرا درون سينمائية مثل الفيديو + كاميرا مطاردة + كاميرا عالية

const MODES := [
	{"name": "درون", "dist": 19.0, "height": 23.0, "yaw_lerp": 0.7, "fov": 50.0, "ahead": 0.35},
	{"name": "مطاردة", "dist": 8.5, "height": 3.4, "yaw_lerp": 4.0, "fov": 68.0, "ahead": 0.15},
	{"name": "عالية", "dist": 9.0, "height": 48.0, "yaw_lerp": 0.4, "fov": 42.0, "ahead": 0.3},
	{"name": "سينمائية", "dist": 30.0, "height": 9.0, "yaw_lerp": 0.25, "fov": 38.0, "ahead": 0.2},
]

var target: RigidBody3D
var world: Node
var mode := 0
var zoom := 1.0
var yaw := 0.0
var t := 0.0
var _snap := true


func cycle() -> String:
	mode = (mode + 1) % MODES.size()
	return MODES[mode]["name"]


func snap() -> void:
	_snap = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.08, 0.45, 2.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.08, 0.45, 2.2)


func _process(delta: float) -> void:
	if target == null:
		return
	t += delta
	var m: Dictionary = MODES[mode]
	var v := target.linear_velocity
	var flat := Vector3(v.x, 0, v.z)
	var heading := flat
	if flat.length() < 3.0:
		heading = -target.global_basis.z
		heading.y = 0
	if heading.length() < 0.01:
		heading = Vector3.FORWARD
	var target_yaw := atan2(-heading.x, -heading.z)
	var k: float = 1.0 - exp(-m["yaw_lerp"] * delta)
	yaw = target_yaw if _snap else lerp_angle(yaw, target_yaw, k)
	var back := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var side := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var sway := Vector3.ZERO
	if mode == 0 or mode == 3:
		sway = side * sin(t * 0.23) * 2.0 + Vector3.UP * sin(t * 0.31) * 0.6
	var desired: Vector3 = target.global_position + back * m["dist"] * zoom + Vector3.UP * m["height"] * zoom + sway
	if world and world.has_method("h_at"):
		desired.y = maxf(desired.y, world.h_at(desired.x, desired.z) + 2.0)
	fov = lerpf(fov, m["fov"] + clampf(flat.length() - 25.0, 0.0, 30.0) * 0.3, 1.0 - exp(-2.0 * delta))
	if _snap:
		global_position = desired
		_snap = false
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-4.5 * delta))
	var look: Vector3 = target.global_position + flat * m["ahead"] * 0.5 + Vector3.UP * 0.8
	if global_position.distance_to(look) > 0.5:
		look_at(look, Vector3.UP)
