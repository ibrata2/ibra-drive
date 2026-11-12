class_name IbraCar
extends RigidBody3D
## سيارة أركيد بفيزياء raycast: عوارض لكل تاير، تماسك جانبي، تفحيط، نيترو، وقود

var car_id := "pickup"
var stats := {}
var model := {}
var wheels: Array = []
var rest_len := 0.45
var wheel_r := 0.42
var spring_k := 0.0
var damp_c := 0.0
var steer_angle := 0.0
var throttle_in := 0.0
var brake_in := 0.0
var steer_in := 0.0
var handbrake := false
var nitro_on := false
var fuel := 100.0
var nitro := 0.0
var max_nitro := 0.0
var controls := true
var surface_grip := 1.0
var water_level := -1000.0
var water_depth := -10.0
var speed := 0.0
var slip := 0.0
var grounded_count := 0
var lights_on := false
var headlights: Array = []
var tail_mat: StandardMaterial3D
var driven_count := 4
var prev_vel := Vector3.ZERO
# الحمولة والمقطورات (تتغير من عالم الطريق)
var base_mass := 1000.0
var load_mass := 0.0
var brake_load := 0.6
var fuel_load := 1.0
# أعطال وتعب: انفجار تاير، سحب التوجيه، تحديد السرعة
var burst_wheel := -1
var steer_bias := 0.0
var speed_mult := 1.0
var horn_t := 0.0
var roll_coef := 0.05
var fuel_mult := 1.0


func setup(id: String, paint: Color) -> void:
	car_id = id
	stats = Game.car_stats(id)
	mass = stats["mass"]
	base_mass = mass
	model = CarModel.build(stats["body"], paint, Game.car_deco(id))
	add_child(model["root"])
	wheel_r = model["radius"]
	rest_len = model["rest"]
	tail_mat = model["tail_mat"]
	var per_wheel: float = mass * 9.8 / 4.0
	spring_k = per_wheel / (rest_len * 0.45)
	damp_c = 2.0 * sqrt(spring_k * mass / 4.0) * 0.3 * stats["susp"]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = model["box_size"]
	cs.shape = bs
	cs.position = model["box_center"]
	add_child(cs)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, model["com_y"], 0)
	angular_damp = 0.6
	linear_damp = 0.02
	can_sleep = false
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.05
	physics_material_override = pm
	driven_count = 4 if stats["drive"] == "awd" else 2
	for i in 4:
		var wp: Vector3 = model["wheel_pos"][i]
		var ray := RayCast3D.new()
		ray.position = Vector3(wp.x, wp.y + rest_len * 0.55, wp.z)
		ray.target_position = Vector3(0, -(rest_len + wheel_r), 0)
		ray.add_exception(self)
		ray.enabled = true
		add_child(ray)
		wheels.append({
			"ray": ray, "front": i < 2, "driven": stats["drive"] == "awd" or i >= 2,
			"pivot": model["wheels"][i]["pivot"], "spin_node": model["wheels"][i]["spin"],
			"spin": 0.0, "grounded": false, "contact": Vector3.ZERO, "normal": Vector3.UP,
			"mount_y": wp.y + rest_len * 0.55, "lat_v": 0.0,
		})
	fuel = stats["fuel"]
	max_nitro = stats["nitro"]
	nitro = max_nitro
	for hp in model["head_pos"]:
		var sl := SpotLight3D.new()
		sl.position = hp
		sl.spot_range = 55.0
		sl.spot_angle = 32.0
		sl.spot_attenuation = 0.8
		sl.light_energy = 7.0
		sl.light_color = Color(1, 0.95, 0.82)
		sl.shadow_enabled = false
		sl.visible = false
		sl.rotation = Vector3(-0.08, 0, 0)
		add_child(sl)
		headlights.append(sl)


## وزن الحمولة: السيارة تصير أثكل (تسارع أبطأ، فرامل أطول، بانزين أكثر) والعوارض تتعدل حتى ما تنزل
func set_load(m: float, brake_factor := 0.6) -> void:
	load_mass = maxf(m, 0.0)
	brake_load = brake_factor
	mass = base_mass + load_mass
	var per_wheel: float = mass * 9.8 / 4.0
	spring_k = per_wheel / (rest_len * 0.45)
	damp_c = 2.0 * sqrt(spring_k * mass / 4.0) * 0.3 * float(stats["susp"])
	fuel_load = 1.0 + load_mass / base_mass * 0.5


func set_lights(on: bool) -> void:
	lights_on = on
	for h in headlights:
		h.visible = on


func reset_upright(pos: Vector3 = Vector3.INF) -> void:
	var f := -global_basis.z
	f.y = 0
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var yaw := atan2(-f.x, -f.z)
	var p := global_position + Vector3(0, 2.0, 0) if pos == Vector3.INF else pos
	global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func is_flipped() -> bool:
	return global_basis.y.y < 0.3


func _read_input() -> void:
	if not controls:
		throttle_in = 0.0
		brake_in = 0.0
		steer_in = 0.0
		handbrake = true
		nitro_on = false
		return
	throttle_in = Input.get_action_strength("accelerate")
	brake_in = Input.get_action_strength("brake")
	steer_in = clampf(Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left") + steer_bias, -1.0, 1.0)
	handbrake = Input.is_action_pressed("handbrake")
	nitro_on = max_nitro > 0.0 and nitro > 0.05 and Input.is_action_pressed("nitro") and throttle_in > 0.1 and fuel > 0.0


func _physics_process(delta: float) -> void:
	prev_vel = linear_velocity
	_read_input()
	var up := global_basis.y
	var fwd_body := -global_basis.z
	var top: float = stats["top_speed"] * (1.3 if nitro_on else 1.0) * speed_mult
	speed = linear_velocity.dot(fwd_body)
	var engine: float = stats["accel"] * base_mass * 6.5 * (1.7 if nitro_on else 1.0)
	if fuel <= 0.0:
		engine = 0.0
	var off: float = clampf(stats["offroad"], 0.3, 1.3)
	var surf := lerpf(surface_grip, 1.0, clampf((off - 0.4) * 0.55, 0.0, 0.6))
	var max_steer := 0.55 * lerpf(1.0, 0.3, clampf(absf(speed) / top, 0.0, 1.0))
	steer_angle = move_toward(steer_angle, -steer_in * max_steer, delta * 2.8)
	grounded_count = 0
	slip = 0.0
	var brake_mass := base_mass + load_mass * brake_load
	var wi := -1
	for w in wheels:
		wi += 1
		var ray: RayCast3D = w["ray"]
		ray.force_raycast_update()
		var origin := ray.global_position
		var pivot: Node3D = w["pivot"]
		if ray.is_colliding():
			grounded_count += 1
			var hit := ray.get_collision_point()
			var n := ray.get_collision_normal()
			var dist := origin.distance_to(hit)
			var comp := clampf(rest_len + wheel_r - dist, 0.0, rest_len)
			var pv := linear_velocity + angular_velocity.cross(origin - global_position)
			var fs := comp * spring_k - up.dot(pv) * damp_c
			if comp > rest_len * 0.95:
				fs += mass * 9.8 * 0.6
			fs = maxf(fs, 0.0)
			apply_force(up * fs, origin - global_position)
			var wdir := fwd_body
			if w["front"]:
				wdir = fwd_body.rotated(up, steer_angle)
			var f := (wdir - n * wdir.dot(n)).normalized()
			var r := f.cross(n).normalized()
			var lat_v := pv.dot(r)
			var lon_v := pv.dot(f)
			var mu: float = stats["grip"] * surf * 1.3
			if not w["front"]:
				mu *= 1.06
				if handbrake:
					mu *= 0.42
			if wi == burst_wheel:
				mu *= 0.4
			var max_f := fs * mu
			var lat_f := clampf(-lat_v * (mass / 4.0) / delta * 0.3, -max_f, max_f)
			slip = maxf(slip, absf(lat_v))
			var lon_f := 0.0
			if w["driven"]:
				if throttle_in > 0.0:
					var sf := clampf(1.0 - pow(maxf(speed, 0.0) / top, 2.0), 0.0, 1.0)
					lon_f += throttle_in * engine / driven_count * sf
				if brake_in > 0.0 and speed < 1.0:
					var rf := clampf(1.0 - pow(absf(minf(speed, 0.0)) / (top * 0.3), 2.0), 0.0, 1.0)
					lon_f -= brake_in * engine * 0.5 / driven_count * rf
			if brake_in > 0.0 and speed > 1.0:
				lon_f -= signf(lon_v) * brake_in * brake_mass * 9.0 / 4.0
			if handbrake and not w["front"] and absf(lon_v) > 0.3:
				lon_f -= signf(lon_v) * brake_mass * 5.0 / 4.0
			lon_f -= lon_v * mass * (roll_coef + (1.0 - surf) * 0.18) / 4.0
			if throttle_in < 0.05 and brake_in < 0.05 and absf(lon_v) < 1.5:
				lon_f -= lon_v * mass * 1.5 / 4.0
			lon_f = clampf(lon_f, -max_f * 1.15, max_f * 1.15)
			apply_force(r * lat_f + f * lon_f, (hit + n * 0.2) - global_position)
			pivot.position.y = w["mount_y"] - (dist - wheel_r)
			w["spin"] += lon_v / wheel_r * delta
			w["grounded"] = true
			w["contact"] = hit
			w["normal"] = n
			w["lat_v"] = lat_v
		else:
			pivot.position.y = lerpf(pivot.position.y, w["mount_y"] - rest_len, 0.2)
			w["spin"] += (throttle_in * 30.0) * delta
			w["grounded"] = false
			w["lat_v"] = 0.0
		if w["front"]:
			pivot.rotation.y = steer_angle
		(w["spin_node"] as Node3D).rotation.x = -w["spin"]
	if grounded_count == 0:
		angular_velocity *= 0.995
		apply_torque(global_basis.x * (throttle_in - brake_in) * base_mass * 0.6)
	else:
		apply_central_force(-up * absf(speed) * mass * 0.03)
	# الوقود والنيترو
	var use := ((throttle_in + brake_in * 0.4) * 0.42 + 0.03) * fuel_load * fuel_mult
	if nitro_on:
		use *= 2.0
		nitro = maxf(nitro - delta, 0.0)
	elif max_nitro > 0.0:
		nitro = minf(max_nitro, nitro + delta * 0.1)
	fuel = maxf(fuel - use * delta, 0.0)
	# الماي
	water_depth = water_level - global_position.y
	if water_depth > -0.4:
		var k := clampf(water_depth + 0.4, 0.0, 1.6)
		apply_central_force(-linear_velocity * mass * 0.35 * k)
		# دفعة تساعد السيارة تطلع من الماي
		if throttle_in > 0.1 or brake_in > 0.1:
			var fw := fwd_body
			fw.y = 0.0
			var dirn := 1.0 if throttle_in >= brake_in else -1.0
			apply_central_force((fw.normalized() * dirn * 5.0 + Vector3.UP * 2.5) * mass * k * 0.6)
	# مساعد الصعود: من تكون بطيء على منحدر وتدوس بنزين
	if grounded_count >= 2 and throttle_in > 0.3 and absf(speed) < 7.0 and up.y < 0.95 and fuel > 0.0:
		apply_central_force(fwd_body * base_mass * 3.5 * throttle_in * clampf((1.0 - up.y) * 6.0, 0.3, 1.0))
	# أضواء البريك
	if tail_mat:
		tail_mat.emission_energy_multiplier = 4.0 if (brake_in > 0.1 and speed > 0.5) or handbrake else (1.5 if lights_on else 0.6)
